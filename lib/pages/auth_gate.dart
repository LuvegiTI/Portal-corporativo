import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService().getSession(),
      builder: (context, snapshot) {
        // 🔄 Cargando sesión
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data;

        // ❌ Si no hay sesión válida → Login
        if (session == null ||
            session['token'] == null ||
            session['token'].toString().isEmpty) {
          return const LoginPage();
        }

        // =====================================================
        // 🔐 MANEJO SEGURO DE PERMISOS (String o List)
        // =====================================================

        final dynamic permisosRaw = session['permisos'];

        List<String> listaPermisos = [];

        if (permisosRaw is String) {
          listaPermisos = permisosRaw.isNotEmpty ? permisosRaw.split(',') : [];
        } else if (permisosRaw is List) {
          listaPermisos = permisosRaw.map((e) => e.toString()).toList();
        }

        // =====================================================
        // 🚀 Ir al Home
        // =====================================================

        return HomePage(
          token: session['token'].toString(),
          rol: session['rol']?.toString() ?? 'USUARIO',
          nombre: session['nombre']?.toString() ?? 'Usuario',
          correo: session['correo']?.toString() ?? 'usuario@luvegi.com',
          usuarioId: session['usuarioId']?.toString() ?? '0',
          permisos: listaPermisos,
        );
      },
    );
  }
}
