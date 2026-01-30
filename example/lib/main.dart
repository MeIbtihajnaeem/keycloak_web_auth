import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:keycloak_web_auth/keycloak_web_auth.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  final KeycloakClient _auth = KeycloakClient();
  late final KeycloakHttpClient _httpClient = KeycloakHttpClient(auth: _auth);

  late final Future<void> _initFuture;
  bool _ready = false;
  String? _userinfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initFuture = _initAuth();
  }

  Future<void> _initAuth() async {
    final origin = Uri.base.origin;
    final config = KeycloakConfig(
      baseUrl: 'http://localhost:8080',
      realm: 'flutter-web',
      clientId: 'flutter-web-client',
      redirectUri: Uri.base.toString(),
      postLogoutRedirectUri: origin,
      onLoad: KeycloakOnLoad.checkSso,
      silentCheckSsoRedirectUri: '$origin/silent-check-sso.html',
      refreshThresholdSeconds: 30,
      clockSkewSeconds: 10,
      persistence: KeycloakPersistence.sessionStorage,
      enableMultiTabSync: true,
      enableLogging: true,
      enableLegacyImplicitFlow: false,
    );

    try {
      await _auth.init(config);
      setState(() {
        _ready = true;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _callUserInfo() async {
    setState(() {
      _error = null;
      _userinfo = null;
    });
    try {
      final response = await _httpClient.get(
        Uri.parse(
          'http://localhost:8080/realms/flutter-web/protocol/openid-connect/userinfo',
        ),
      );
      setState(() {
        _userinfo = response.body;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keycloak Web Auth Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Keycloak Web Auth Demo')),
        body: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: AuthBuilder(
                auth: _auth,
                builder: (context, state) {
                  if (state.isLoading && !_ready) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final session = state.session;
                  final canInteract = _ready;
                  return ListView(
                    children: [
                      Text('Status: ${state.status}'),
                      if (!_ready) ...[
                        const SizedBox(height: 8),
                        const Text('Initializing Keycloak...'),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: [
                          ElevatedButton(
                            onPressed: canInteract ? _auth.login : null,
                            child: const Text('Login'),
                          ),
                          OutlinedButton(
                            onPressed: canInteract ? _auth.logout : null,
                            child: const Text('Logout'),
                          ),
                          OutlinedButton(
                            onPressed: canInteract
                                ? () => _auth.refreshIfNeeded(force: true)
                                : null,
                            child: const Text('Force Refresh'),
                          ),
                          OutlinedButton(
                            onPressed: canInteract && state.isAuthenticated
                                ? _callUserInfo
                                : null,
                            child: const Text('Call UserInfo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      if (_userinfo != null) Text('UserInfo: $_userinfo'),
                      const SizedBox(height: 16),
                      Text('Authenticated: ${state.isAuthenticated}'),
                      if (session != null) ...[
                        Text(
                          'Access token expires: ${session.accessTokenExpiry}',
                        ),
                        Text('ID token expires: ${session.idTokenExpiry}'),
                        const SizedBox(height: 8),
                        Text('Realm roles: ${_auth.realmRoles().join(', ')}'),
                        Text(
                          'Client roles: ${_auth.clientRoles('flutter-web-client').join(', ')}',
                        ),
                        const SizedBox(height: 8),
                        Text('Claims:'),
                        Text(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(_auth.claims ?? <String, dynamic>{}),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
