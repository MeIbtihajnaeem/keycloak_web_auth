import 'dart:async';

import '../user_session.dart';
import 'token_storage.dart';

class MemoryStorage implements TokenStorage {
  UserSession? _session;
  final StreamController<UserSession?> _controller =
      StreamController<UserSession?>.broadcast();

  @override
  Future<void> save(UserSession? session) async {
    _session = session;
    _controller.add(_session);
  }

  @override
  Future<UserSession?> read() async => _session;

  @override
  Future<void> clear() async {
    _session = null;
    _controller.add(null);
  }

  @override
  Stream<UserSession?> get changes => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }
}
