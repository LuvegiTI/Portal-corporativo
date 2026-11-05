import 'dart:convert';

import 'package:http/http.dart' as http;

class AuditoriaException implements Exception {
  final String message;
  const AuditoriaException(this.message);
  @override
  String toString() => message;
}

class AuditoriaService {
  static const baseUrl = 'https://portal.luvegi.com/api_luvegi';

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': 'Bearer $token',
  };

  // Registra un intento de login (éxito o fallo). No requiere token.
  Future<void> registrarIntentoLogin({
    required String usuario,
    required bool exito,
    String motivo = '',
    String dispositivo = 'WEB',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auditoria.php?action=registrar_intento'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'usuario': usuario,
        'exito': exito ? 1 : 0,
        'motivo': motivo,
        'dispositivo': dispositivo,
      }),
    );
    _decode(response);
  }

  // Registra una acción de actividad con el usuario del token.
  Future<void> registrarActividad(
    String token, {
    required String accion,
    String entidad = 'general',
    String detalle = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auditoria.php?action=registrar'),
      headers: _headers(token),
      body: jsonEncode({
        'accion': accion,
        'entidad': entidad,
        'detalle': detalle,
      }),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> consultar(
    String token, {
    String tipo = 'actividad',
    String usuario = '',
    String desde = '',
    String hasta = '',
    String accion = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/auditoria.php?action=consultar&tipo=$tipo'
        '&usuario=${Uri.encodeQueryComponent(usuario)}'
        '&desde=$desde&hasta=$hasta'
        '&accion=${Uri.encodeQueryComponent(accion)}'
        '&page=$page&page_size=$pageSize',
      ),
      headers: _headers(token),
    );
    return _decode(response);
  }

  // Lista de usuarios con actividad en la bitácora (para el filtro).
  Future<List<String>> listarUsuarios(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auditoria.php?action=usuarios'),
      headers: _headers(token),
    );
    final data = _decode(response);
    final usuarios = data['usuarios'];
    if (usuarios is List) {
      return usuarios.whereType<String>().toList();
    }
    return <String>[];
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map &&
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body['ok'] == true) {
        return Map<String, dynamic>.from(body);
      }
      if (body is Map) {
        throw AuditoriaException(
          (body['mensaje'] ?? body['error'] ?? 'Operación rechazada.')
              .toString(),
        );
      }
    } on AuditoriaException {
      rethrow;
    } catch (_) {}
    throw const AuditoriaException(
      'El servidor devolvió una respuesta inválida.',
    );
  }
}
