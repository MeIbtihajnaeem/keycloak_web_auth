import 'package:flutter/widgets.dart';

import '../auth_state.dart';
import '../keycloak_client.dart';

class AuthBuilder extends StatelessWidget {
  final KeycloakClient auth;
  final Widget Function(BuildContext context, AuthState state) builder;

  const AuthBuilder({super.key, required this.auth, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: auth.authState$,
      initialData: const AuthState.loading(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const AuthState.loading();
        return builder(context, state);
      },
    );
  }
}
