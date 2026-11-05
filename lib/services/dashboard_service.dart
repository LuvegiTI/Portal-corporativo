import 'package:dio/dio.dart';
import 'dart:convert';

class DashboardService {
  final String _urlStats =
      'https://portal.luvegi.com/api_luvegi/get_dashboard_stats.php';
  final String _urlMisBoletas =
      'https://portal.luvegi.com/api_luvegi/get_mis_ultimas_boletas.php';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.json,
    ),
  );

  Future<Map<String, dynamic>> getStats(String token) async {
    try {
      final response = await _dio.get(
        _urlStats,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${token.trim()}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) data = json.decode(data);
        return data is Map<String, dynamic>
            ? data
            : {'boletas': 0, 'usuarios': 0};
      }
      return {'boletas': 0, 'usuarios': 0};
    } catch (e) {
      return {'boletas': '!', 'usuarios': '!'};
    }
  }

  Future<List<dynamic>> getUltimasBoletas(String token) async {
    try {
      final response = await _dio.get(
        _urlMisBoletas,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${token.trim()}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) data = json.decode(data);
        // Si el PHP devolviera la lista directa, esto la captura correctamente
        return data is List ? data : [];
      }
      return [];
    } catch (e) {
      print("Error en Service Boletas: $e");
      return [];
    }
  }
}
