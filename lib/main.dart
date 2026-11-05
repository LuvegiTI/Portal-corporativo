import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'pages/auth_gate.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'utils/session_timeout_wrapper.dart';
import 'theme/luvegi_theme.dart';

// Llave maestra para navegar sin BuildContext local.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es';
  initializeDateFormatting('es');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'LUVEGI',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Tema corporativo LUVEGI.
      theme: LuvegiTheme.light,

      builder: (context, child) {
        return SessionTimeoutWrapper(
          duration: const Duration(minutes: 15),
          onTimeout: () async {
            final session = await authService.getSession();

            if (session != null) {
              final rol = (session['rol'] ?? '').toString().toUpperCase();

              if (rol == 'ADMIN' || rol == 'ADMINISTRADOR') {
                debugPrint("✅ Cierre por inactividad no aplica para $rol.");
                return;
              }

              debugPrint(
                "⏰ Inactividad detectada: Cerrando sesión de "
                "${session['nombre']}",
              );

              await authService.logout();

              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );

              final currentContext = navigatorKey.currentContext;

              if (currentContext != null) {
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  const SnackBar(
                    content: Text("Sesión cerrada por inactividad"),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            } else {
              debugPrint("⏳ Usuario en Login: El timeout no aplica.");
            }
          },
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const AuthGate(),
    );
  }
}
