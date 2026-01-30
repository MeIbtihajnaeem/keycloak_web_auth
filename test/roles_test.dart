import 'package:keycloak_web_auth/src/token_utils.dart';
import 'package:test/test.dart';

void main() {
  group('TokenUtils roles', () {
    test('extracts realm roles', () {
      final roles = TokenUtils.realmRoles({
        'realm_access': {
          'roles': ['user', 'admin'],
        },
      });
      expect(roles, containsAll(['user', 'admin']));
    });

    test('extracts client roles', () {
      final roles = TokenUtils.clientRoles({
        'resource_access': {
          'my-client': {
            'roles': ['app-user'],
          },
        },
      }, 'my-client');
      expect(roles, contains('app-user'));
    });

    test('returns empty set when roles missing', () {
      final roles = TokenUtils.realmRoles({});
      expect(roles, isEmpty);
    });
  });
}
