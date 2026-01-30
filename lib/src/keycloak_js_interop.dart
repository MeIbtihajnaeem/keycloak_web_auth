@JS()
library keycloak_js_interop;

import 'package:js/js.dart';

@JS()
@anonymous
class KeycloakOptions {
  external String get url;
  external String get realm;
  external String get clientId;

  external factory KeycloakOptions({
    required String url,
    required String realm,
    required String clientId,
  });
}

@JS()
@anonymous
class KeycloakInitOptions {
  external String? get onLoad;
  external String? get pkceMethod;
  external String? get flow;
  external bool? get checkLoginIframe;
  external String? get silentCheckSsoRedirectUri;
  external String? get redirectUri;
  external String? get token;
  external String? get refreshToken;
  external String? get idToken;

  external factory KeycloakInitOptions({
    String? onLoad,
    String? pkceMethod,
    String? flow,
    bool? checkLoginIframe,
    String? silentCheckSsoRedirectUri,
    String? redirectUri,
    String? token,
    String? refreshToken,
    String? idToken,
  });
}

@JS('Keycloak')
class KeycloakJs {
  external factory KeycloakJs(KeycloakOptions options);

  external bool? get authenticated;
  external String? get token;
  external String? get idToken;
  external String? get refreshToken;
  external dynamic get tokenParsed;
  external dynamic get idTokenParsed;
  external dynamic get realmAccess;
  external dynamic get resourceAccess;
  external String? get subject;

  external Object init(KeycloakInitOptions options);
  external Object login([dynamic options]);
  external Object logout([dynamic options]);
  external Object updateToken(int minValidity);
  external void clearToken();

  external set onAuthSuccess(Function? handler);
  external set onAuthLogout(Function? handler);
  external set onAuthRefreshSuccess(Function? handler);
  external set onAuthRefreshError(Function? handler);
  external set onTokenExpired(Function? handler);
  external set onAuthError(Function? handler);
}
