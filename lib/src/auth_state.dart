import 'package:meta/meta.dart';

import 'user_session.dart';

enum AuthStatus { loading, authenticated, unauthenticated, error }

@immutable
class AuthState {
  final AuthStatus status;
  final UserSession? session;
  final Object? error;

  const AuthState._({required this.status, this.session, this.error});

  const AuthState.loading() : this._(status: AuthStatus.loading);

  const AuthState.authenticated(UserSession session)
    : this._(status: AuthStatus.authenticated, session: session);

  const AuthState.unauthenticated([Object? error])
    : this._(status: AuthStatus.unauthenticated, error: error);

  const AuthState.error(Object error)
    : this._(status: AuthStatus.error, error: error);

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get hasError => status == AuthStatus.error || error != null;

  @override
  String toString() {
    return 'AuthState(status: $status, isAuthenticated: $isAuthenticated, hasError: $hasError)';
  }
}
