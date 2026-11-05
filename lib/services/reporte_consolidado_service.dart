import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_reporte_consolidado.dart'; // ⚡ Importa desde el modelo desacoplado

class ReporteConsolidadoException implements Exception {
  final String message;
  final int? statusCode;

  const ReporteConsolidadoException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ReporteConsolidadoResponse {
  final List<ItemReporteConsolidado> items;
  final int totalRegistros;
  final int paginaActual;
  final int totalPaginas;
  final double montoTotalNeto;
  final double montoTotalGeneral;
  final double montoIngresosNeto;
  final double montoEgresosNeto;

  ReporteConsolidadoResponse({
    required this.items,
    required this.totalRegistros,
    required this.paginaActual,
    required this.totalPaginas,
    required this.montoTotalNeto,
    required this.montoTotalGeneral,
    required this.montoIngresosNeto,
    required this.montoEgresosNeto,
  });

  factory ReporteConsolidadoResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return ReporteConsolidadoResponse(
      items: list.map((i) => ItemReporteConsolidado.fromJson(i)).toList(),
      totalRegistros: json['total_registros'] ?? 0,
      paginaActual: json['pagina'] ?? 1,
      totalPaginas: json['total_paginas'] ?? 1,
      montoTotalNeto: double.tryParse('${json['monto_total_neto']}') ?? 0.0,
      montoTotalGeneral:
          double.tryParse('${json['monto_total_general']}') ?? 0.0,
      montoIngresosNeto:
          double.tryParse('${json['monto_ingresos_neto']}') ?? 0.0,
      montoEgresosNeto: double.tryParse('${json['monto_egresos_neto']}') ?? 0.0,
    );
  }
}

class ReporteConsolidadoService {
  static const String baseUrl =
      'https://portal.luvegi.com/api_luvegi/reporte_consolidado.php';

  Future<ReporteConsolidadoResponse> consultarConsolidado(
    String token, {
    required String pedido,
    required String tipoFiltro,
    int pagina = 1,
    int limite = 25,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'pedido': pedido,
        'tipo_filtro': tipoFiltro,
        'pagina': '$pagina',
        'limite': '$limite',
      },
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
      throw ReporteConsolidadoException(
        (body['message'] ??
                body['mensaje'] ??
                body['error'] ??
                'Error al consultar el reporte consolidado.')
            .toString(),
        statusCode: response.statusCode,
      );
    }

    return ReporteConsolidadoResponse.fromJson(body);
  }
}
