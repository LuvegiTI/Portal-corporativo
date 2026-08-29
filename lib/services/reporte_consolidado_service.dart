import 'dart:convert';
import 'package:http/http.dart' as http;
import '../pages/reporte_consolidado_page.dart'; // Importa para ItemReporteConsolidado

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
      montoTotalGeneral: double.tryParse('${json['monto_total_general']}') ?? 0.0,
      montoIngresosNeto: double.tryParse('${json['monto_ingresos_neto']}') ?? 0.0,
      montoEgresosNeto: double.tryParse('${json['monto_egresos_neto']}') ?? 0.0,
    );
  }
}

class ReporteConsolidadoService {
  // Ajusta esta URL a la de tu servidor de producción
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi/reporte_consolidado.php';

  Future<ReporteConsolidadoResponse> consultarConsolidado(
    String token, {
    required String pedido,
    int pagina = 1,
    int limite = 25,
  }) async {
    final url = Uri.parse('$baseUrl?pedido=$pedido&pagina=$pagina&limite=$limite');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        // 'Authorization': 'Bearer $token', // Descomenta si usas token
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return ReporteConsolidadoResponse.fromJson(data);
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'Error desconocido');
      }
    } else {
      throw Exception('Error en el servidor: ${response.statusCode}');
    }
  }
}