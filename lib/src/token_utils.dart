import 'dart:convert';

class TokenUtils {
  static Map<String, dynamic> decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid JWT format');
    }
    final payload = _decodeBase64Url(parts[1]);
    final payloadMap = jsonDecode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw FormatException('Invalid JWT payload');
    }
    return payloadMap;
  }

  static DateTime expiryFromClaims(Map<String, dynamic> claims) {
    final exp = claims['exp'];
    if (exp is! num) {
      throw FormatException('JWT exp claim missing or invalid');
    }
    return DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    ).toLocal();
  }

  static bool isExpired(DateTime expiry, {int skewSeconds = 0}) {
    final now = DateTime.now().toUtc();
    final adjustedExpiry = expiry.toUtc().subtract(
      Duration(seconds: skewSeconds),
    );
    return now.isAfter(adjustedExpiry);
  }

  static bool isWithinThreshold(
    DateTime expiry,
    int thresholdSeconds, {
    int skewSeconds = 0,
  }) {
    final now = DateTime.now().toUtc();
    final adjustedExpiry = expiry.toUtc().subtract(
      Duration(seconds: skewSeconds),
    );
    return adjustedExpiry.isBefore(
      now.add(Duration(seconds: thresholdSeconds)),
    );
  }

  static Set<String> realmRoles(Map<String, dynamic> claims) {
    final realmAccess = claims['realm_access'];
    if (realmAccess is! Map) return {};
    final roles = realmAccess['roles'];
    if (roles is! List) return {};
    return roles.map((role) => role.toString()).toSet();
  }

  static Set<String> clientRoles(Map<String, dynamic> claims, String clientId) {
    final resourceAccess = claims['resource_access'];
    if (resourceAccess is! Map) return {};
    final client = resourceAccess[clientId];
    if (client is! Map) return {};
    final roles = client['roles'];
    if (roles is! List) return {};
    return roles.map((role) => role.toString()).toSet();
  }

  static String _decodeBase64Url(String input) {
    var output = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw FormatException('Invalid base64url string');
    }
    return utf8.decode(base64Url.decode(output));
  }
}
