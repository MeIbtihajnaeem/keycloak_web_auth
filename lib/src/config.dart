import 'package:meta/meta.dart';

enum KeycloakOnLoad { loginRequired, checkSso }

enum KeycloakPersistence { memory, sessionStorage }

@immutable
class KeycloakConfig {
  final String baseUrl;
  final String realm;
  final String clientId;
  final String? redirectUri;
  final String? postLogoutRedirectUri;
  final KeycloakOnLoad onLoad;
  final String? silentCheckSsoRedirectUri;
  final int refreshThresholdSeconds;
  final int clockSkewSeconds;
  final KeycloakPersistence persistence;
  final bool enableMultiTabSync;
  final bool enableLogging;
  final bool enableLegacyImplicitFlow;

  const KeycloakConfig({
    required this.baseUrl,
    required this.realm,
    required this.clientId,
    this.redirectUri,
    this.postLogoutRedirectUri,
    this.onLoad = KeycloakOnLoad.checkSso,
    this.silentCheckSsoRedirectUri,
    this.refreshThresholdSeconds = 30,
    this.clockSkewSeconds = 0,
    this.persistence = KeycloakPersistence.sessionStorage,
    this.enableMultiTabSync = true,
    this.enableLogging = false,
    this.enableLegacyImplicitFlow = false,
  });

  String get onLoadValue =>
      onLoad == KeycloakOnLoad.loginRequired ? 'login-required' : 'check-sso';
}
