import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_reporte_detalle_anual.dart';

class ReporteDetalleAnualService {
  static const String baseUrl =
      'https://portal.luvegi.com/api_luvegi/reporte_detalle_anual.php';

  Future<ReporteDetalleAnualResponse> consultarAnual(
    String token, {
    required String anio,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {'anio': anio},
    );

    final response = await http
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Accept-Encoding': 'gzip',
            'Authorization': 'Bearer $token',
          },
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
        (body['message'] ??
                body['error'] ??
                'Error al consultar el reporte anual.')
            .toString(),
      );
    }

    return ReporteDetalleAnualResponse.fromJson(body);
  }
}