import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../pages/api_client.dart';

class AuthService {
  final Dio _dio = ApiClient().dio;
  Timer? _pollingTimer;

  // ---------------- LOGIN ----------------
  Future<Map<String, dynamic>> login({
    required String usuario,
    required String password,
    required String licencia,
    required String hardwareId,
  }) async {
    try {
      final response = await _dio.post(
        'login.php',
        data: {
          'usuario': usuario,
          'password': password,
          'licencia': licencia,
          'hardware_id': hardwareId,
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }

      return {'ok': false, 'error': 'RESPUESTA_INVALIDA'};
    } catch (e) {
      return {'ok': false, 'error': 'ERROR_RED'};
    }
  }

  // ---------------- POLLING ----------------
 void iniciarPolling() {
  _pollingTimer?.cancel();

  _pollingTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
    final session = await getSession();
    if (session == null) {
      timer.cancel();
      return;
    }

    try {
      // 🔑 Llamamos al nuevo endpoint que devuelve los permisos frescos
      final response = await _dio.get(
        'mis_permisos.php',
        options: Options(
          headers: {'Authorization': 'Bearer ${session['token']}'},
        ),
      );

      if (response.data['ok'] == true) {
        final List<String> permisosNuevos =
            List<String>.from(response.data['permisos'] ?? []);

        // ✅ Actualizamos SharedPreferences con los permisos frescos
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('permisos', permisosNuevos);
      }
    } catch (_) {
      // Si responde 401 → interceptor cerrará sesión
    }
  });
}

  // ---------------- SESSION STORAGE ----------------
  Future<void> saveSession({
    required String token,
    required String rol,
    required String nombre,
    required String correo,
    required String usuarioId,
    required List<String> permisos,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLogged', true);
    await prefs.setString('token', token);
    await prefs.setString('rol', rol);
    await prefs.setString('nombre', nombre);
    await prefs.setString('correo', correo);
    await prefs.setString('usuarioId', usuarioId);
    await prefs.setStringList('permisos', permisos);
  }

  Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool('isLogged') ?? false;

    if (!isLogged) return null;

    final token = prefs.getString('token');
    if (token == null || token.isEmpty) return null;

    return {
      'token': token,
      'rol': prefs.getString('rol') ?? 'USUARIO',
      'nombre': prefs.getString('nombre') ?? 'Usuario',
      'correo': prefs.getString('correo') ?? '',
      'usuarioId': prefs.getString('usuarioId') ?? '0',
      'permisos': prefs.getStringList('permisos') ?? <String>[],
    };
  }

  Future<void> logout() async {
    _pollingTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  Future<void> refrescarMisPermisos() async {
  final session = await getSession();
  if (session == null) return;

  try {
    final response = await _dio.get(
      'mis_permisos.php',
      options: Options(
        headers: {'Authorization': 'Bearer ${session['token']}'},
      ),
    );

    if (response.data['ok'] == true) {
      final List<String> permisosNuevos =
          List<String>.from(response.data['permisos'] ?? []);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('permisos', permisosNuevos);
    }
  } catch (_) {}
}
}