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
    required String busqueda,
    required String tipoFiltro, // 'pedido', 'equipo', 'unidad', 'descripcion'
    int pagina = 1,
    int limite = 25,
  }) async {
    final query = <String, String>{
      if (busqueda.trim().isNotEmpty) 'busqueda': busqueda.trim(),
      'tipo_filtro': tipoFiltro,
      'pagina': '$pagina',
      'limite': '$limite',
    };

    final uri = Uri.parse(
      '$baseUrl/reporte_luvegi_buscarpedido.php',
    ).replace(queryParameters: query);

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
        (body['error'] ??
                body['message'] ??
                'Error al consultar el reporte de consumo.')
            .toString(),
      );
    }

    final List rawList = body['data'] ?? [];
    final items = rawList.map((e) => ItemReporteConsumo.fromJson(e)).toList();

    return ResultadoConsumoPaginado(
      items: items,
      totalRegistros: int.tryParse('${body['total_registros']}') ?? 0,
      gastoTotalGeneral:
          double.tryParse('${body['gasto_total_general']}') ?? 0.0,
      totalPaginas: int.tryParse('${body['total_paginas']}') ?? 0,
      paginaActual: int.tryParse('${body['pagina']}') ?? pagina,
    );
  }
}
