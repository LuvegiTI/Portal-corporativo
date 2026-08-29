import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/reporte_compra.dart';

class ReporteOrdenCompraService {
  static const String _endpoint =
      'https://portal.luvegi.com/api_luvegi/reporte_compra.php';

  Future<ReporteOrdenCompraResponse> buscar({
    required String token,
    required String tipoBusqueda,
    required String busqueda,
    required int page,
    required int pageSize,
  }) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'tipo_busqueda': tipoBusqueda.trim(),
            'busqueda': busqueda.trim(),
            'page': page,
            'page_size': pageSize,
          }),
        )
        .timeout(const Duration(seconds: 60));

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const FormatException();
      }
      body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw Exception(
        'El servidor devolvió una respuesta inválida (${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      throw Exception(
        (body['mensaje'] ?? body['error'] ?? 'No se pudo consultar el reporte.')
            .toString(),
      );
    }

    return ReporteOrdenCompraResponse.fromJson(body);
  }
}
