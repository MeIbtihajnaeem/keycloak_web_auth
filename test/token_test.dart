import 'dart:convert';

import 'package:keycloak_web_auth/src/token_utils.dart';
import 'package:test/test.dart';

String _jwt(Map<String, dynamic> payload) {
  final header = {'alg': 'none', 'typ': 'JWT'};
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(header)}.${encode(payload)}.';
}

void main() {
  group('TokenUtils', () {
    test('decodes JWT payload', () {
      final token = _jwt({'sub': '123', 'exp': 1700000000});
      final claims = TokenUtils.decodeJwt(token);
      expect(claims['sub'], '123');
    });

    test('expiryFromClaims returns DateTime', () {
      final exp = 1700000000;
      final expiry = TokenUtils.expiryFromClaims({'exp': exp});
      expect(expiry.millisecondsSinceEpoch, exp * 1000);
    });

    test('decodeJwt throws on invalid token', () {
      expect(() => TokenUtils.decodeJwt('invalid'), throwsFormatException);
    });
  });
}
