import 'dart:async';
import 'dart:convert';
import 'dart:html';

import '../user_session.dart';
import 'token_storage.dart';

class SessionStorage implements TokenStorage {
  static const String _key = 'keycloak_web_auth.session';
  final StreamController<UserSession?> _controller =
      StreamController<UserSession?>.broadcast();

  @override
  Future<void> save(UserSession? session) async {
    if (session == null) {
      window.sessionStorage.remove(_key);
    } else {
      window.sessionStorage[_key] = jsonEncode(session.toJson());
    }
    _controller.add(session);
  }

  @override
  Future<UserSession?> read() async {
    final raw = window.sessionStorage[_key];
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    window.sessionStorage.remove(_key);
    _controller.add(null);
  }

  @override
  Stream<UserSession?> get changes => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }
}
