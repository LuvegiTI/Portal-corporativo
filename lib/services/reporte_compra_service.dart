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
            'Accept-Encoding': 'gzip',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'tipo_filtro': tipoBusqueda.trim(),
            'busqueda': busqueda.trim(),
            'pagina': page,
            'limite': pageSize,
          }),
        )
        .timeout(const Duration(seconds: 30));

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

    return ReporteOrdenCompraResponse.fromJson(body);
  }
}

class ReporteOrdenCompraResponse {
  final List<ReporteOrdenCompra> data;
  final int pagina;
  final int limite;
  final int totalPaginas;
  final int totalRegistros;
  final double totalSinImpuesto;
  final double totalConImpuesto;

  ReporteOrdenCompraResponse({
    required this.data,
    required this.pagina,
    required this.limite,
    required this.totalPaginas,
    required this.totalRegistros,
    required this.totalSinImpuesto,
    required this.totalConImpuesto,
  });

  factory ReporteOrdenCompraResponse.fromJson(Map<String, dynamic> json) {
    return ReporteOrdenCompraResponse(
      data:
          (json['data'] as List?)
              ?.map((item) => ReporteOrdenCompra.fromJson(item))
              .toList() ??
          [],
      pagina: json['pagina'] ?? 1,
      limite: json['limite'] ?? 25,
      totalPaginas: json['total_paginas'] ?? 0,
      totalRegistros: json['total_registros'] ?? 0,
      totalSinImpuesto: (json['total_sin_impuesto'] ?? 0).toDouble(),
      totalConImpuesto: (json['total_con_impuesto'] ?? 0).toDouble(),
    );
  }
}
