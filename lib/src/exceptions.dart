class KeycloakAuthException implements Exception {
  final String message;
  final Object? cause;

  KeycloakAuthException(this.message, [this.cause]);

  @override
  String toString() => 'KeycloakAuthException: $message';
}

class KeycloakTokenException extends KeycloakAuthException {
  KeycloakTokenException(String message, [Object? cause])
    : super(message, cause);
}

class KeycloakConfigException extends KeycloakAuthException {
  KeycloakConfigException(String message, [Object? cause])
    : super(message, cause);
}
