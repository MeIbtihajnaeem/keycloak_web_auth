import 'package:keycloak_web_auth/src/auth_state.dart';
import 'package:keycloak_web_auth/src/user_session.dart';
import 'package:test/test.dart';

void main() {
  group('AuthState', () {
    test('authenticated state flags', () {
      final session = UserSession(
        accessToken: 'a',
        idToken: 'b',
        refreshToken: 'c',
        accessTokenClaims: const {},
        idTokenClaims: const {},
        accessTokenExpiry: DateTime.now(),
        idTokenExpiry: DateTime.now(),
      );
      final state = AuthState.authenticated(session);
      expect(state.isAuthenticated, isTrue);
      expect(state.isUnauthenticated, isFalse);
      expect(state.isLoading, isFalse);
    });

    test('unauthenticated state flags', () {
      final state = AuthState.unauthenticated();
      expect(state.isAuthenticated, isFalse);
      expect(state.isUnauthenticated, isTrue);
    });
  });
}
