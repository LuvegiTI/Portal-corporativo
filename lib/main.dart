import 'package:flutter/material.dart';
import 'pages/auth_gate.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'utils/session_timeout_wrapper.dart';


// 1. Llave maestra para navegar sin necesidad de un BuildContext local
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Instanciamos el servicio para verificar la sesión en el timeout
    final authService = AuthService();

    return MaterialApp(
      title: 'LUVEGI',
      // 2. Registramos la llave de navegación
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // 3. El builder envuelve toda la aplicación (Login y pantallas internas)
      builder: (context, child) {
        return SessionTimeoutWrapper(
          duration: const Duration(minutes: 5), // <--- Tiempo de inactividad
          onTimeout: () async {
            // Verificamos si hay una sesión activa en SharedPreferences
            final session = await authService.getSession();
            // Solo ejecutamos el cierre si el usuario ya había pasado el AuthGate
            if (session != null) {
              debugPrint("⏰ Inactividad detectada: Cerrando sesión de ${session['nombre']}");
              // Limpiamos el token, permisos e ID del almacenamiento local
              await authService.logout();
              // Redirigimos al Login eliminando todas las pantallas anteriores
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
              // Mostramos un aviso visual al usuario
              if (navigatorKey.currentContext != null) {
                ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                  const SnackBar(
                    content: Text("Sesión cerrada por inactividad"),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            } else {
              // Si está en el Login, el temporizador se reinicia silenciosamente
              debugPrint("⏳ Usuario en Login: El timeout no aplica.");
            }
          },
          child: child!,
        );
      },

      // La puerta de entrada que decide si mostrar Login o Home
      home: const AuthGate(),
    );
  }
}