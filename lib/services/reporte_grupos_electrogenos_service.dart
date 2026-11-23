import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/reporte_grupo_electrogeno.dart';

class ReporteGruposElectrogenosService {
  static const String _endpoint =
      'https://portal.luvegi.com/api_luvegi/reporte_grupos_electrogenos.php';

  Future<ReporteGruposElectrogenosResponse> consultar({
    required String token,
    required String categoria,
  }) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'categoria': categoria.trim()}),
        )
        .timeout(const Duration(seconds: 120));

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
        (body['message'] ?? body['error'] ?? 'No se pudo consultar el reporte.')
            .toString(),
      );
    }

    return ReporteGruposElectrogenosResponse.fromJson(body);
  }
}

class ReporteGruposElectrogenosResponse {
  final List<ReporteGrupoElectrogeno> data;
  final int totalRegistros;
  final String categoria;

  ReporteGruposElectrogenosResponse({
    required this.data,
    required this.totalRegistros,
    required this.categoria,
  });

  factory ReporteGruposElectrogenosResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReporteGruposElectrogenosResponse(
      data:
          (json['data'] as List?)
              ?.map((item) => ReporteGrupoElectrogeno.fromJson(item))
              .toList() ??
          [],
      totalRegistros: json['total_registros'] ?? 0,
      categoria: (json['categoria'] ?? '').toString(),
    );
  }
}
