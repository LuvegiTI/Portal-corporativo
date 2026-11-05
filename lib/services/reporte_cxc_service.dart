import 'package:dio/dio.dart';
import '../models/reporte_cxc.dart';

class ReporteCxcService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 300),
    ),
  );

  Future<ReporteCxcResponse> consultar({
    required String token,
    required String modo,
    String fecha = '',
    String desde = '',
    String hasta = '',
  }) async {
    final params = <String, dynamic>{'modo': modo};

    if (modo == 'rango') {
      params['desde'] = desde;
      params['hasta'] = hasta;
    } else {
      params['fecha'] = fecha;
    }

    final response = await _dio.get(
      'https://portal.luvegi.com/api_luvegi/reporte_cxc_vencidas.php',
      queryParameters: params,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    final json = response.data;

    if (json is! Map<String, dynamic>) {
      throw Exception('Respuesta inesperada del servidor.');
    }

    if (json['ok'] != true) {
      throw Exception(
        json['mensaje'] ?? json['error'] ?? 'Error al obtener el reporte.',
      );
    }

    final rows = (json['rows'] as List? ?? const [])
        .map((e) => ReporteCxcFila.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ReporteCxcResponse(
      fecha: json['fecha']?.toString() ?? '',
      modo: json['modo']?.toString() ?? modo,
      desde: json['desde']?.toString() ?? '',
      hasta: json['hasta']?.toString() ?? '',
      count: int.tryParse(json['count'].toString()) ?? rows.length,
      rows: rows,
      totales: ReporteCxcTotales.fromJson(
        Map<String, dynamic>.from(json['totales'] as Map? ?? const {}),
      ),
    );
  }
}
