import 'package:dio/dio.dart';

class AdminUsuariosService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://portal.luvegi.com/api_luvegi/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  // =================================================
  // 🔐 HEADERS CON TOKEN
  // =================================================
  Options _opts(String token) => Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

  // =================================================
  // 📋 LISTAR USUARIOS
  // =================================================
  Future<List<Map<String, dynamic>>> listar(String token) async {
    final res = await _dio.get(
      'admin_usuarios.php',
      queryParameters: {'action': 'listar'},
      options: _opts(token),
    );

    if (res.data == null || res.data['ok'] != true) {
      return [];
    }

    return List<Map<String, dynamic>>.from(res.data['usuarios']);
  }

  // =================================================
  // 📄 LISTAR (PAGINADO + BÚSQUEDA)
  // =================================================
  Future<Map<String, dynamic>> listarPaged(String token, {int page = 1, int perPage = 20, String q = ''}) async {
    try {
      final res = await _dio.get(
        'admin_usuarios.php',
        queryParameters: {
          'action': 'listar',
          'page': page,
          'per_page': perPage,
          if (q.isNotEmpty) 'q': q,
        },
        options: _opts(token),
      );

      if (res.data == null || res.data['ok'] != true) {
        return {'usuarios': <Map<String, dynamic>>[], 'total': 0};
      }

      final usuarios = List<Map<String, dynamic>>.from(res.data['usuarios'] ?? []);
      final total = res.data['total'] ?? usuarios.length;

      return {'usuarios': usuarios, 'total': total};
    } catch (_) {
      return {'usuarios': <Map<String, dynamic>>[], 'total': 0};
    }
  }

  // =================================================
  // ➕ CREAR USUARIO
  // =================================================
  Future<bool> crear(
    String token,
    String usuario,
    String nombre,
    String password,
    String rol,
  ) async {
    try {
      final res = await _dio.post(
        'admin_usuarios.php?action=crear',
        data: {
          'usuario': usuario,
          'nombre': nombre,
          'password': password,
          'rol': rol,
        },
        options: _opts(token),
      );

      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // =================================================
  // 🔁 ACTIVAR / BAJA
  // =================================================
  Future<bool> toggle(String token, int id) async {
    try {
      final res = await _dio.post(
        'admin_usuarios.php?action=toggle',
        data: {'id': id},
        options: _opts(token),
      );

      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // =================================================
  // 🔑 RESET PASSWORD
  // =================================================
  Future<bool> resetPassword(
    String token,
    int id,
    String password,
  ) async {
    try {
      final res = await _dio.post(
        'admin_usuarios.php?action=reset_password',
        data: {
          'id': id,
          'password': password,
        },
        options: _opts(token),
      );

      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // =================================================
  // 🔄 CAMBIAR ROL
  // =================================================
  Future<bool> cambiarRol(
    String token,
    int id,
    String rol,
  ) async {
    try {
      final res = await _dio.post(
        'admin_usuarios.php?action=rol',
        data: {
          'id': id,
          'rol': rol,
        },
        options: _opts(token),
      );

      return res.data != null && res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}