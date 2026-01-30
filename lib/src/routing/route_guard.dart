import '../keycloak_client.dart';

class KeycloakRouteGuard {
  final KeycloakClient auth;

  KeycloakRouteGuard(this.auth);

  Future<bool> canActivate({bool loginIfNeeded = true}) async {
    if (auth.isAuthenticated) return true;
    if (!loginIfNeeded) return false;
    await auth.login();
    return auth.isAuthenticated;
  }
}
