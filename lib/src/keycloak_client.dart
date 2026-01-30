import 'dart:async';
import 'dart:html';

import 'package:js/js.dart';
import 'package:js/js_util.dart';

import 'auth_state.dart';
import 'config.dart';
import 'exceptions.dart';
import 'keycloak_js_interop.dart';
import 'refresh_scheduler.dart';
import 'token_utils.dart';
import 'user_session.dart';
import 'storage/memory_storage.dart';
import 'storage/session_storage.dart';
import 'storage/token_storage.dart';

class KeycloakClient {
  static const String _broadcastChannelName = 'keycloak_web_auth';
  static const String _storageSyncKey = 'keycloak_web_auth.sync';

  final StreamController<AuthState> _authController =
      StreamController<AuthState>.broadcast();
  AuthState _state = const AuthState.loading();
  KeycloakConfig? _config;
  KeycloakJs? _keycloak;
  TokenStorage? _storage;
  RefreshScheduler? _refreshScheduler;
  BroadcastChannel? _broadcastChannel;
  StreamSubscription<MessageEvent>? _broadcastSub;
  StreamSubscription<StorageEvent>? _storageEventSub;
  Completer<void>? _initCompleter;
  Completer<void>? _refreshCompleter;
  bool _disposed = false;
  bool _suppressBroadcast = false;
  bool _initialized = false;

  Stream<AuthState> get authState$ => _authController.stream;
  bool get isAuthenticated => _state.isAuthenticated;

  Map<String, dynamic>? get claims => _state.session?.accessTokenClaims;

  Future<void> init(KeycloakConfig config) async {
    _assertNotDisposed();
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    final completer = Completer<void>();
    _initCompleter = completer;
    _config = config;
    _storage = _createStorage(config.persistence);
    _setupMultiTabSync();
    _setState(const AuthState.loading());

    final storedSession = await _storage!.read();
    try {
      final authenticated = await _initKeycloak(
        storedSession: storedSession,
        useOnLoad: true,
      );
      if (authenticated) {
        await _syncSessionFromKeycloak();
      } else {
        await _applySession(null, broadcast: false);
        _setState(const AuthState.unauthenticated());
      }
      _initialized = true;
      completer.complete();
    } catch (error) {
      _emitError(KeycloakAuthException('Failed to initialize Keycloak', error));
      await _applySession(null, broadcast: false);
      _initialized = false;
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> login() async {
    await _ensureInitialized();
    final redirectUri = _config!.redirectUri ?? _defaultRedirectUri();
    await promiseToFuture<void>(
      _keycloak!.login(jsify({'redirectUri': redirectUri})),
    );
  }

  Future<void> logout() async {
    await _ensureInitialized();
    final redirectUri = _config!.postLogoutRedirectUri ?? _defaultRedirectUri();
    try {
      await promiseToFuture<void>(
        _keycloak!.logout(jsify({'redirectUri': redirectUri})),
      );
    } finally {
      await _applySession(null);
      _setState(const AuthState.unauthenticated());
    }
  }

  Future<String?> getAccessToken({bool forceRefresh = false}) async {
    if (!_state.isAuthenticated) return null;
    await refreshIfNeeded(force: forceRefresh);
    return _state.session?.accessToken;
  }

  String? getIdToken() => _state.session?.idToken;

  Set<String> realmRoles() {
    final session = _state.session;
    if (session == null) return {};
    return TokenUtils.realmRoles(session.accessTokenClaims);
  }

  Set<String> clientRoles(String clientId) {
    final session = _state.session;
    if (session == null) return {};
    return TokenUtils.clientRoles(session.accessTokenClaims, clientId);
  }

  bool hasRole(String role, {String? clientId}) {
    if (clientId != null) {
      return clientRoles(clientId).contains(role);
    }
    return realmRoles().contains(role) ||
        clientRoles(_config?.clientId ?? '').contains(role);
  }

  Future<void> refreshIfNeeded({bool force = false}) async {
    if (!_state.isAuthenticated) return;
    final session = _state.session;
    if (session == null) return;
    final config = _config!;
    final shouldRefresh =
        force ||
        TokenUtils.isWithinThreshold(
          session.accessTokenExpiry,
          config.refreshThresholdSeconds,
          skewSeconds: config.clockSkewSeconds,
        );
    if (!shouldRefresh) return;
    await _refreshToken(
      minValiditySeconds: force ? 0 : config.refreshThresholdSeconds,
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _refreshScheduler?.dispose();
    _refreshScheduler = null;
    _broadcastSub?.cancel();
    _storageEventSub?.cancel();
    _broadcastChannel?.close();
    _authController.close();
    _storage?.dispose();
  }

  Future<bool> _initKeycloak({
    UserSession? storedSession,
    required bool useOnLoad,
  }) async {
    final available = await _waitForKeycloakAdapter(
      timeout: const Duration(seconds: 3),
      interval: const Duration(milliseconds: 50),
    );
    if (!available) {
      throw KeycloakConfigException(
        'Keycloak JS adapter not found. '
        'Add <script type=\"module\" src=\"keycloak_loader.js\"></script> '
        '(loader that sets window.Keycloak) or an inline module that imports '
        'https://unpkg.com/keycloak-js@26.2.2/lib/keycloak.js and assigns window.Keycloak. '
        'to web/index.html and ensure Keycloak is reachable.',
      );
    }
    _keycloak = KeycloakJs(
      KeycloakOptions(
        url: _config!.baseUrl,
        realm: _config!.realm,
        clientId: _config!.clientId,
      ),
    );
    _bindKeycloakHandlers();

    final initOptions = KeycloakInitOptions(
      onLoad: useOnLoad ? _config!.onLoadValue : null,
      pkceMethod: 'S256',
      flow: _config!.enableLegacyImplicitFlow ? 'implicit' : 'standard',
      checkLoginIframe: false,
      silentCheckSsoRedirectUri: _config!.silentCheckSsoRedirectUri,
      redirectUri: _config!.redirectUri ?? _defaultRedirectUri(),
      token: storedSession?.accessToken,
      refreshToken: storedSession?.refreshToken,
      idToken: storedSession?.idToken,
    );
    final result = await promiseToFuture<bool>(_keycloak!.init(initOptions));
    return result;
  }

  void _bindKeycloakHandlers() {
    _keycloak!.onAuthSuccess = allowInterop(() {
      _syncSessionFromKeycloak();
    });
    _keycloak!.onAuthRefreshSuccess = allowInterop(() {
      _syncSessionFromKeycloak();
    });
    _keycloak!.onAuthRefreshError = allowInterop(() {
      _handleRefreshError(KeycloakTokenException('Token refresh failed'));
    });
    _keycloak!.onAuthLogout = allowInterop(() {
      _applySession(null);
      _setState(const AuthState.unauthenticated());
    });
    _keycloak!.onTokenExpired = allowInterop(() {
      refreshIfNeeded(force: true);
    });
    _keycloak!.onAuthError = allowInterop((error) {
      _emitError(KeycloakAuthException('Authentication error', error));
    });
  }

  Future<void> _syncSessionFromKeycloak() async {
    final session = _buildSessionFromKeycloak();
    if (session == null) {
      await _applySession(null);
      _setState(const AuthState.unauthenticated());
      return;
    }
    await _applySession(session);
    _setState(AuthState.authenticated(session));
    _scheduleRefresh(session);
  }

  UserSession? _buildSessionFromKeycloak() {
    final keycloak = _keycloak;
    if (keycloak == null) return null;
    final token = keycloak.token;
    final idToken = keycloak.idToken;
    final refreshToken = keycloak.refreshToken;
    if (token == null || idToken == null || refreshToken == null) {
      return null;
    }
    final accessClaims = _claimsFromParsed(token, keycloak.tokenParsed);
    final idClaims = _claimsFromParsed(idToken, keycloak.idTokenParsed);
    return UserSession(
      accessToken: token,
      idToken: idToken,
      refreshToken: refreshToken,
      accessTokenClaims: accessClaims,
      idTokenClaims: idClaims,
      accessTokenExpiry: TokenUtils.expiryFromClaims(accessClaims),
      idTokenExpiry: TokenUtils.expiryFromClaims(idClaims),
    );
  }

  Map<String, dynamic> _claimsFromParsed(String token, dynamic parsed) {
    if (parsed != null) {
      final dartValue = dartify(parsed);
      if (dartValue is Map) {
        return Map<String, dynamic>.from(dartValue);
      }
    }
    return TokenUtils.decodeJwt(token);
  }

  Future<void> _refreshToken({required int minValiditySeconds}) async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    _refreshCompleter = Completer<void>();
    try {
      await _ensureKeycloakTokens();
      final refreshed = await promiseToFuture<bool>(
        _keycloak!.updateToken(minValiditySeconds),
      );
      if (!refreshed && !_state.isAuthenticated) {
        throw KeycloakTokenException('Token refresh unsuccessful');
      }
      await _syncSessionFromKeycloak();
      _refreshCompleter!.complete();
    } catch (error) {
      _refreshCompleter!.completeError(error);
      await _handleRefreshError(error);
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _handleRefreshError(Object error) async {
    _emitError(KeycloakTokenException('Token refresh failed', error));
    await _applySession(null);
    _setState(AuthState.unauthenticated(error));
  }

  void _scheduleRefresh(UserSession session) {
    _refreshScheduler ??= RefreshScheduler(
      thresholdSeconds: _config!.refreshThresholdSeconds,
      onRefresh: () => refreshIfNeeded(force: false),
      onError: (error) {
        _emitError(KeycloakTokenException('Scheduled refresh failed', error));
      },
    );
    _refreshScheduler!.schedule(session.accessTokenExpiry);
  }

  TokenStorage _createStorage(KeycloakPersistence persistence) {
    switch (persistence) {
      case KeycloakPersistence.memory:
        return MemoryStorage();
      case KeycloakPersistence.sessionStorage:
        return SessionStorage();
    }
  }

  Future<void> _applySession(
    UserSession? session, {
    bool broadcast = true,
  }) async {
    await _storage?.save(session);
    if (broadcast) {
      _notifySync();
    }
  }

  void _notifySync() {
    if (_config == null || !_config!.enableMultiTabSync) return;
    if (_config!.persistence == KeycloakPersistence.memory) return;
    if (_suppressBroadcast) return;
    if (_broadcastChannel != null) {
      _broadcastChannel!.postMessage('sync');
      return;
    }
    window.localStorage[_storageSyncKey] = DateTime.now().toIso8601String();
  }

  void _setupMultiTabSync() {
    if (_config == null || !_config!.enableMultiTabSync) return;
    if (_config!.persistence == KeycloakPersistence.memory) return;

    if (hasProperty(window, 'BroadcastChannel')) {
      _broadcastChannel = BroadcastChannel(_broadcastChannelName);
      _broadcastSub = _broadcastChannel!.onMessage.listen((_) {
        _handleSyncEvent();
      });
    } else {
      _storageEventSub = window.onStorage.listen((event) {
        if (event.key == _storageSyncKey) {
          _handleSyncEvent();
        }
      });
    }
  }

  Future<void> _handleSyncEvent() async {
    if (_storage == null) return;
    _suppressBroadcast = true;
    try {
      final stored = await _storage!.read();
      if (stored == null) {
        _setState(const AuthState.unauthenticated());
        return;
      }
      _setState(AuthState.authenticated(stored));
      _scheduleRefresh(stored);
    } finally {
      _suppressBroadcast = false;
    }
  }

  Future<void> _ensureKeycloakTokens() async {
    if (_keycloak == null) return;
    if (_keycloak!.token != null && _keycloak!.refreshToken != null) return;
    final stored = await _storage?.read();
    if (stored == null) return;
    await _initKeycloak(storedSession: stored, useOnLoad: false);
  }

  void _setState(AuthState state) {
    _state = state;
    if (!_authController.isClosed) {
      _authController.add(state);
    }
  }

  void _emitError(KeycloakAuthException error) {
    if (_config?.enableLogging ?? false) {
      // ignore: avoid_print
      print('KeycloakWebAuth error: ${error.message}');
    }
    if (!_authController.isClosed) {
      _authController.add(AuthState.error(error));
    }
  }

  String _defaultRedirectUri() => Uri.base.toString();

  void _assertInitialized() {
    if (!_initialized ||
        _config == null ||
        _keycloak == null ||
        _storage == null) {
      throw KeycloakConfigException(
        'KeycloakClient not initialized. Call init().',
      );
    }
  }

  Future<void> _ensureInitialized() async {
    final initFuture = _initCompleter?.future;
    if (initFuture != null && !_initialized) {
      await initFuture;
    }
    _assertInitialized();
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('KeycloakClient is disposed');
    }
  }

  Future<bool> _waitForKeycloakAdapter({
    required Duration timeout,
    required Duration interval,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (hasProperty(window, 'Keycloak')) return true;
      await Future<void>.delayed(interval);
    }
    return hasProperty(window, 'Keycloak');
  }
}
