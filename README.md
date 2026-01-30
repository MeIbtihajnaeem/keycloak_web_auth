# keycloak_web_auth

Web-only Keycloak authentication for Flutter Web using OAuth2/OIDC Authorization Code + PKCE.

## Features
- Authorization Code Flow + PKCE (default)
- Silent SSO (check-sso)
- Login-required mode
- Full logout with redirect
- Token refresh scheduling
- Simple HTTP client wrapper with retry-on-401
- Optional multi-tab sync (BroadcastChannel/localStorage)

> Web-only: this package targets Flutter Web and uses the Keycloak JS adapter.

## Quick start

### 1) Start Keycloak (Docker)
A minimal dev setup is included.

```bash
cd /path/to/keycloak_web_package

docker compose up -d
```

This loads a realm from `keycloak/import/realm-export.json` with:
- Realm: `flutter-web`
- Client: `flutter-web-client` (public, standard flow, PKCE S256)
- User: `testuser` / `testpassword`
- Roles: realm `user`, client `app-user`

Keycloak console: `http://localhost:8080`

### 2) Include Keycloak JS adapter in your web app
Keycloak no longer ships the JS adapter in the server image, so you must load it yourself.

Option A (recommended for the example): use the bundled adapter in `example/web/keycloak.js` with a small loader.

```html
<script type="module" src="keycloak_loader.js"></script>
```

`web/keycloak_loader.js`:

```js
import Keycloak from './keycloak.js';
globalThis.Keycloak = Keycloak;
```

Option B: load from a CDN (pin a version) with a small inline module loader:

```html
<script type="module">
  import Keycloak from 'https://unpkg.com/keycloak-js@26.2.2/lib/keycloak.js';
  window.Keycloak = Keycloak;
</script>
```

### 3) Add silent SSO helper page
Create `web/silent-check-sso.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>Silent SSO</title>
</head>
<body>
  <script>
    parent.postMessage(location.href, location.origin);
  </script>
</body>
</html>
```

### 4) Initialize in Flutter

```dart
final auth = KeycloakClient();

await auth.init(KeycloakConfig(
  baseUrl: 'http://localhost:8080',
  realm: 'flutter-web',
  clientId: 'flutter-web-client',
  redirectUri: Uri.base.toString(),
  postLogoutRedirectUri: Uri.base.origin,
  onLoad: KeycloakOnLoad.checkSso,
  silentCheckSsoRedirectUri: '${Uri.base.origin}/silent-check-sso.html',
  refreshThresholdSeconds: 30,
  clockSkewSeconds: 10,
));
```

### 5) Use the API

```dart
await auth.login();
final token = await auth.getAccessToken();
final roles = auth.realmRoles();
await auth.logout();
```

## Example app
A full Flutter Web example is in `example/`.

```bash
cd example
flutter run -d chrome --web-port=3000
```

Then login at `http://localhost:3000` with `testuser / testpassword`.

## Configuration

```dart
class KeycloakConfig {
  final String baseUrl;
  final String realm;
  final String clientId;
  final String? redirectUri;
  final String? postLogoutRedirectUri;
  final KeycloakOnLoad onLoad; // loginRequired | checkSso
  final String? silentCheckSsoRedirectUri;
  final int refreshThresholdSeconds;
  final int clockSkewSeconds;
  final KeycloakPersistence persistence; // memory | sessionStorage
  final bool enableMultiTabSync;
  final bool enableLogging;
  final bool enableLegacyImplicitFlow; // default false
}
```

## HTTP client

```dart
final client = KeycloakHttpClient(auth: auth);
final response = await client.get(Uri.parse('https://api.example.com/protected'));
```

The client retries once on 401 after a refresh attempt.

## Testing

```bash
dart test
```

Tests focus on JWT parsing, roles, and refresh timing.

## Notes
- Do not log tokens in production.
- Silent SSO requires the helper HTML file and `onLoad: checkSso`.
- This package intentionally keeps JS interop isolated in `keycloak_js_interop.dart`.
