import 'package:flutter/widgets.dart';

import '../keycloak_client.dart';
import 'auth_builder.dart';

class Authenticated extends StatelessWidget {
  final KeycloakClient auth;
  final Widget child;
  final Widget? fallback;

  const Authenticated({
    super.key,
    required this.auth,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return AuthBuilder(
      auth: auth,
      builder: (context, state) {
        if (state.isAuthenticated) return child;
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
