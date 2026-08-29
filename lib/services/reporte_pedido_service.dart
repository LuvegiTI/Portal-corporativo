import 'dart:convert';
import 'package:http/http.dart' as http;
import '../pages/reporte_pedido_consumo.dart';

class ResultadoConsumoPaginado {
  final List<ItemReporteConsumo> items;
  final int totalRegistros;
  final double gastoTotalGeneral;
  final int totalPaginas;
  final int paginaActual;

  ResultadoConsumoPaginado({
    required this.items,
    required this.totalRegistros,
    required this.gastoTotalGeneral,
    required this.totalPaginas,
    required this.paginaActual,
  });
}

class ReporteConsumoService {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  Future<ResultadoConsumoPaginado> consultarConsumo(
    String token, {
    required String pedido,
    int pagina = 1,
    int limite = 25,
  }) async {
    final query = <String, String>{
      if (pedido.trim().isNotEmpty) 'pedido': pedido.trim(),
      'pagina': '$pagina',
      'limite': '$limite',
    };

    final uri = Uri.parse('$baseUrl/reporte_luvegi_buscarpedido.php').replace(
      queryParameters: query,
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 45));

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode != 200 || body['ok'] != true) {
      throw Exception(
        body['error'] ?? 'Error al consultar el reporte de consumo.',
      );
    }

    final List rawList = body['data'] ?? [];
    final items = rawList.map((e) => ItemReporteConsumo.fromJson(e)).toList();

    return ResultadoConsumoPaginado(
      items: items,
      totalRegistros: int.tryParse('${body['total_registros']}') ?? 0,
      gastoTotalGeneral: double.tryParse('${body['gasto_total_general']}') ?? 0.0,
      totalPaginas: int.tryParse('${body['total_paginas']}') ?? 0,
      paginaActual: int.tryParse('${body['pagina']}') ?? pagina,
    );
  }
}