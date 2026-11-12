// lib/app/auth_gate.dart
//
// Genérico sobre T (no atado a firebase_auth.User) a propósito -- lo único
// que importa aquí es "¿hay sesión?" (valor no nulo) o no, nunca qué
// representa ese valor. Mismo criterio que registrarSincronizacionDeClaims
// en REPARA: permite testear la puerta de autenticación con un stream
// falso, sin construir un User real de Firebase Auth.
import 'package:flutter/material.dart';

class AuthGate<T extends Object> extends StatelessWidget {
  const AuthGate({
    required this.authStateChanges,
    required this.onAutenticado,
    required this.onSinSesion,
    super.key,
  });

  final Stream<T?> authStateChanges;
  final WidgetBuilder onAutenticado;
  final WidgetBuilder onSinSesion;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T?>(
      stream: authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data != null ? onAutenticado(context) : onSinSesion(context);
      },
    );
  }
}
