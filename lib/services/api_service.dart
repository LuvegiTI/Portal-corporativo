import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// Importa donde tengas tu manejo de SharedPreferences o Token

class ApiService {
  late Dio _dio;
  // Usamos una GlobalKey para poder navegar sin necesidad de "context" de un Widget
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://tu-dominio.com/',
      connectTimeout: const Duration(seconds: 5),
    ));

    // AGREGAMOS EL INTERCEPTOR DE SEGURIDAD
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Aquí podrías adjuntar el Token automáticamente en cada petición
        // String? token = await obtenerTokenDeCache();
        // options.headers["Authorization"] = "Bearer $token";
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // Si el PHP mandó ok: false y error: CUENTA_DESACTIVADA (aunque sea 200)
        if (response.data is Map && response.data['error'] == 'CUENTA_DESACTIVADA') {
          _forzarSalida();
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        // Si el PHP mandó un error HTTP 401
        if (e.response?.statusCode == 401) {
          _forzarSalida();
        }
        return handler.next(e);
      },
    ));
  }

  void _forzarSalida() {
    print("🚫 SESIÓN REVOCADA: El usuario ha sido dado de baja.");
    
    // 1. Borrar Token de la memoria del celular
    // Preferencias.token = ""; 

    // 2. Mandar al Login y borrar todo el historial de pantallas
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // Getter para usarlo en toda la app
  Dio get cliente => _dio;
}