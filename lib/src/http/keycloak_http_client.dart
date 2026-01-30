import 'package:http/http.dart' as http;

import '../keycloak_client.dart';

class KeycloakHttpClient extends http.BaseClient {
  final KeycloakClient auth;
  final http.Client _inner;

  KeycloakHttpClient({required this.auth, http.Client? inner})
    : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();

    Future<http.StreamedResponse> sendWithToken(String? token) async {
      final newRequest = http.Request(request.method, request.url)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection
        ..headers.addAll(request.headers)
        ..bodyBytes = bodyBytes;

      if (token != null && token.isNotEmpty) {
        newRequest.headers['Authorization'] = 'Bearer $token';
      }
      return _inner.send(newRequest);
    }

    final token = await auth.getAccessToken();
    var response = await sendWithToken(token);

    if (response.statusCode == 401) {
      await auth.refreshIfNeeded(force: true);
      final refreshedToken = await auth.getAccessToken();
      response = await sendWithToken(refreshedToken);
    }

    return response;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
