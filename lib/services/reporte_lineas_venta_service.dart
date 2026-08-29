import 'package:dio/dio.dart';
import '../models/reporte_linea_venta.dart';

class ReporteLineasVentaResponse {
  final List<ReporteLineaVenta> data;
  final int page;
  final int pageSize;
  final int totalOrdenes;
  final int totalPages;
  final int returned;
  final double elapsed;

  ReporteLineasVentaResponse({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.totalOrdenes,
    required this.totalPages,
    required this.returned,
    required this.elapsed,
  });
}

class ReporteLineasVentaService {
  final Dio _dio = Dio();

  Future<ReporteLineasVentaResponse> buscar({
    required String token,
    required String fechaInicio,
    required String fechaFin,
    required int page,
    int pageSize = 100,
  }) async {
    final response = await _dio.get(
      'https://portal.luvegi.com/api_luvegi/reporte_lineas_venta.php',
      queryParameters: {
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
        'page': page,
        'page_size': pageSize,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    final json = response.data;

    if (json['ok'] != true) {
      throw Exception(json['error'] ?? 'Error al obtener reporte.');
    }

    final rows = (json['data'] as List)
        .map(
          (e) => ReporteLineaVenta.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();

    return ReporteLineasVentaResponse(
      data: rows,
      page: int.tryParse(json['page'].toString()) ?? page,
      pageSize: int.tryParse(json['page_size'].toString()) ?? pageSize,
      totalOrdenes: int.tryParse(json['total_ordenes'].toString()) ?? 0,
      totalPages: int.tryParse(json['total_pages'].toString()) ?? 0,
      returned: int.tryParse(json['returned'].toString()) ?? 0,
      elapsed: double.tryParse(json['elapsed'].toString()) ?? 0,
    );
  }
}