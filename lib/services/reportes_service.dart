import 'package:dio/dio.dart';

class ReportesService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://portal.luvegi.com/api_luvegi'));

  // Cambiado de 'consultarTodo' a 'consultar' para corregir el error de VS Code
  Future<Map<String, dynamic>> consultar({required String token, required String cuenta}) async {
    final resp = await _dio.get(
      '/reportes_odoo.php',
      queryParameters: {'cuenta': cuenta},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    // IMPORTANTE: Se accede a resp.data directamente
    return Map<String, dynamic>.from(resp.data);
  }
}