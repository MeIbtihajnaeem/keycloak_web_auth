import 'package:meta/meta.dart';

@immutable
class UserSession {
  final String accessToken;
  final String idToken;
  final String refreshToken;
  final Map<String, dynamic> accessTokenClaims;
  final Map<String, dynamic> idTokenClaims;
  final DateTime accessTokenExpiry;
  final DateTime idTokenExpiry;

  const UserSession({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.accessTokenClaims,
    required this.idTokenClaims,
    required this.accessTokenExpiry,
    required this.idTokenExpiry,
  });

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'idToken': idToken,
      'refreshToken': refreshToken,
      'accessTokenClaims': accessTokenClaims,
      'idTokenClaims': idTokenClaims,
      'accessTokenExpiry': accessTokenExpiry.millisecondsSinceEpoch,
      'idTokenExpiry': idTokenExpiry.millisecondsSinceEpoch,
    };
  }

  static UserSession fromJson(Map<String, dynamic> json) {
    return UserSession(
      accessToken: json['accessToken'] as String,
      idToken: json['idToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessTokenClaims: Map<String, dynamic>.from(
        json['accessTokenClaims'] as Map,
      ),
      idTokenClaims: Map<String, dynamic>.from(json['idTokenClaims'] as Map),
      accessTokenExpiry: DateTime.fromMillisecondsSinceEpoch(
        json['accessTokenExpiry'] as int,
      ),
      idTokenExpiry: DateTime.fromMillisecondsSinceEpoch(
        json['idTokenExpiry'] as int,
      ),
    );
  }
}
