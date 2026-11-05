import 'dart:convert';
import 'package:http/http.dart' as http;

class RdrApiException implements Exception {
  final String message;
  final int? statusCode;

  const RdrApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class RdrService {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> registrarRdr({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/registrar_rdr.php'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> obtenerMiPerfil({required String token}) async {
    final response = await http
        .get(Uri.parse('$baseUrl/mi_perfil_rdr.php'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<Map<String, dynamic>> consultarRdr({
    required String token,
    int page = 1,
    int pageSize = 100,
    Map<String, String?> filtros = const {},
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      for (final entry in filtros.entries)
        if ((entry.value ?? '').trim().isNotEmpty)
          entry.key: entry.value!.trim(),
    };

    final response = await http.get(
      Uri.parse('$baseUrl/consultar_rdr.php').replace(queryParameters: query),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> obtenerDetalle({
    required String token,
    required String codigo,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/detalle_rdr.php',
      ).replace(queryParameters: {'codigo': codigo, 'codigo_redir': codigo}),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> atenderRdr({
    required String token,
    required String codigo,
    required String tipoCausa,
    required double tiempoSolucionHoras,
    required double costosAsociados,
    required String descripcionSucedido,
    required String descripcionSolucion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/atender_rdr.php'),
      headers: _headers(token),
      body: jsonEncode({
        'codigo_redir': codigo,
        'codigo_rdir': codigo,
        'codigo_rdr': codigo,
        'tipo_causa': tipoCausa,
        'tiempo_solucion_horas': tiempoSolucionHoras,
        'costos_asociados': costosAsociados,
        'descripcion_sucedido': descripcionSucedido,
        'descripcion_solucion': descripcionSolucion,
      }),
    );
    return _decode(response);
  }

  Future<bool> puedeAdministrarAtenciones({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin_atenciones_rdr.php?action=verificar'),
        headers: _headers(token),
      );
      final body = _decode(response);
      return body['puede_administrar'] == true;
    } on RdrApiException catch (error) {
      if (error.statusCode == 403) return false;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> editarAtencionRdr({
    required String token,
    required String codigo,
    required String motivo,
    String? tipoCausa,
    double? tiempoSolucionHoras,
    double? costosAsociados,
    String? descripcionSucedido,
    String? descripcionSolucion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_atenciones_rdr.php?action=editar'),
      headers: _headers(token),
      body: jsonEncode({
        'codigo_redir': codigo,
        'codigo_rdir': codigo,
        'codigo_rdr': codigo,
        'motivo': motivo,
        'tipo_causa': tipoCausa,
        'tiempo_solucion_horas': tiempoSolucionHoras,
        'costos_asociados': costosAsociados,
        'descripcion_sucedido': descripcionSucedido,
        'descripcion_solucion': descripcionSolucion,
      }),
    );
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialAtencionRdr({
    required String token,
    required String codigo,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin_atenciones_rdr.php',
      ).replace(queryParameters: {'action': 'historial', 'codigo': codigo}),
      headers: _headers(token),
    );
    final body = _decode(response);
    final historial = body['historial'];
    if (historial is! List) return <Map<String, dynamic>>[];
    return historial
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> reabrirYLimpiarAtencionRdr({
    required String token,
    required String codigo,
    required String motivo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_atenciones_rdr.php?action=reabrir'),
      headers: _headers(token),
      body: jsonEncode({
        'codigo_redir': codigo,
        'codigo_rdir': codigo,
        'codigo_rdr': codigo,
        'motivo': motivo,
      }),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw RdrApiException(
        'El servidor devolvió una respuesta inválida.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      final baseMessage =
          (body['mensaje'] ??
                  body['error'] ??
                  'No se pudo completar la operación.')
              .toString();
      final diagnostico = body['diagnostico'];
      final detalle = diagnostico is Map
          ? (diagnostico['detalle'] ?? '').toString().trim()
          : '';
      final message = detalle.isEmpty ? baseMessage : '$baseMessage\n$detalle';
      throw RdrApiException(message, statusCode: response.statusCode);
    }
    return body;
  }
}
