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
          final List<String> permisosNuevos = List<String>.from(
            response.data['permisos'] ?? [],
          );

          // ✅ Actualizamos SharedPreferences con los permisos frescos
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('permisos', permisosNuevos);

          // Expiración deslizante: guardar el token renovado por el servidor
          final tokenNuevo = response.data['token'];
          if (tokenNuevo is String && tokenNuevo.isNotEmpty) {
            await prefs.setString('token', tokenNuevo);
          }
        }
      } catch (_) {
        // Solo el 401 (vía interceptor) cierra sesión.
        // Un 500 transitorio no debe expulsar al usuario.
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
    await prefs.setString(_keyVersionSesion, kVersionSesion);
  }

  // ---------------- VERSION DE SESION ----------------
  // Si este numero cambia, todas las sesiones guardadas en el navegador
  // se invalidan y el usuario tiene que volver a entrar. Sirve para que
  // un despliegue nuevo no herede sesiones viejas.
  //
  // NO lo cambie en cada build: subalo a mano solo cuando quieras
  // cerrar todas las sesiones (por ejemplo, tras un cambio de permisos
  // o si suspecta de un token filtrado).
  static const String kVersionSesion = '2026-10-05-a';
  static const String _keyVersionSesion = 'sesionVersion';

  /// Limpia la sesion si el build actual no coincide con el que la creo.
  Future<bool> _versionValida(SharedPreferences prefs) async {
    final guardada = prefs.getString(_keyVersionSesion);

    // Sin version guardada = sesion creada por un build anterior a este
    // control. Se descarta para no arrastrar tokens viejos sin validar.
    if (guardada == null || guardada != kVersionSesion) {
      await prefs.clear();
      return false;
    }

    return true;
  }

  Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool('isLogged') ?? false;

    if (!isLogged) return null;

    // El build cambio desde que se guardo esta sesion: cerrarla.
    if (!await _versionValida(prefs)) return null;

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
        final List<String> permisosNuevos = List<String>.from(
          response.data['permisos'] ?? [],
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('permisos', permisosNuevos);

        // Expiración deslizante: guardar el token renovado por el servidor
        final tokenNuevo = response.data['token'];
        if (tokenNuevo is String && tokenNuevo.isNotEmpty) {
          await prefs.setString('token', tokenNuevo);
        }
      }
    } catch (_) {}
  }
}
