import 'dart:convert';
import 'package:http/http.dart' as http;

class CatalogosAccesoException implements Exception {
  final String message;
  const CatalogosAccesoException(this.message);
  @override
  String toString() => message;
}

class AdminCatalogosAccesoService {
  static const baseUrl = 'https://portal.luvegi.com/api_luvegi';

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': 'Bearer $token',
  };

  Future<List<Map<String, dynamic>>> areas(String token) async {
    final data = await _get(token, 'areas');
    return _lista(data['areas']);
  }

  Future<List<Map<String, dynamic>>> permisos(String token) async {
    final data = await _get(token, 'permisos');
    return _lista(data['permisos']);
  }

  Future<List<Map<String, dynamic>>> modulos(String token) async {
    final data = await _get(token, 'modulos');
    return _lista(data['modulos']);
  }

  Future<void> crearArea(String token, Map<String, dynamic> data) =>
      _post(token, 'crear_area', data);
  Future<void> editarArea(String token, Map<String, dynamic> data) =>
      _post(token, 'editar_area', data);
  Future<void> toggleArea(String token, int id) =>
      _post(token, 'toggle_area', {'id': id});
  Future<void> crearPermiso(String token, Map<String, dynamic> data) =>
      _post(token, 'crear_permiso', data);
  Future<void> editarPermiso(String token, Map<String, dynamic> data) =>
      _post(token, 'editar_permiso', data);
  Future<void> togglePermiso(String token, int id) =>
      _post(token, 'toggle_permiso', {'id': id});

  Future<Map<String, dynamic>> _get(String token, String action) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin_catalogos_acceso.php?action=$action'),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Future<void> _post(
    String token,
    String action,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_catalogos_acceso.php?action=$action'),
      headers: _headers(token),
      body: jsonEncode(data),
    );
    _decode(response);
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
        throw CatalogosAccesoException(
          (body['mensaje'] ?? body['error'] ?? 'Operación rechazada.')
              .toString(),
        );
      }
    } on CatalogosAccesoException {
      rethrow;
    } catch (_) {}
    throw const CatalogosAccesoException(
      'El servidor devolvió una respuesta inválida.',
    );
  }

  List<Map<String, dynamic>> _lista(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
}
