import 'dart:convert';
import 'package:http/http.dart' as http;
import '../pages/reporte_ventas_compras_page.dart';

class ReporteVentasComprasResultado {
  final List<ReporteVentaCompraConsolidado> data;
  final int page;
  final int pageSize;
  final int totalPages;
  final int totalRegistros;
  final double elapsed;

  const ReporteVentasComprasResultado({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.totalRegistros,
    required this.elapsed,
  });
}

class ReporteVentasComprasService {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<ReporteVentasComprasResultado> buscar({
    required String token,
    required String fechaInicio,
    required String fechaFin,
    String busqueda = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final query = <String, String>{
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'busqueda': busqueda.trim(),
      'page': '$page',
      'page_size': '$pageSize',
    };

    final uri = Uri.parse('$baseUrl/reporte_ventas_compras.php').replace(
      queryParameters: query,
    );

    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 60));

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode < 200 || response.statusCode >= 300 || body['ok'] != true) {
      throw Exception(
        body['error'] ?? body['mensaje'] ?? 'Error al consultar el reporte consolidado.',
      );
    }

    final rawList = body['data'] as List<dynamic>? ?? const [];
    final items = rawList
        .whereType<Map>()
        .map((e) => ReporteVentaCompraConsolidado.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ReporteVentasComprasResultado(
      data: items,
      page: int.tryParse('${body['page'] ?? 1}') ?? 1,
      pageSize: int.tryParse('${body['page_size'] ?? 50}') ?? 50,
      totalPages: int.tryParse('${body['total_pages'] ?? 0}') ?? 0,
      totalRegistros: int.tryParse('${body['total_registros'] ?? 0}') ?? 0,
      elapsed: double.tryParse('${body['elapsed'] ?? 0}') ?? 0.0,
    );
  }
}