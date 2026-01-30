import '../user_session.dart';
import 'memory_storage.dart';
import 'token_storage.dart';

class SessionStorage implements TokenStorage {
  final MemoryStorage _fallback = MemoryStorage();

  @override
  Future<void> save(UserSession? session) => _fallback.save(session);

  @override
  Future<UserSession?> read() => _fallback.read();

  @override
  Future<void> clear() => _fallback.clear();

  @override
  Stream<UserSession?> get changes => _fallback.changes;

  @override
  void dispose() => _fallback.dispose();
}
