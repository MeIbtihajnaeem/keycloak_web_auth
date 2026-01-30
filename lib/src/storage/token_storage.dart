import 'dart:async';

import '../user_session.dart';

abstract class TokenStorage {
  Future<void> save(UserSession? session);
  Future<UserSession?> read();
  Future<void> clear();
  Stream<UserSession?> get changes;
  void dispose();
}
