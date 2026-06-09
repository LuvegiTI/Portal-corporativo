import 'package:dio/dio.dart';

class BoletasService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://portal.luvegi.com/api_luvegi/boletas_usuario.php';

  Future<List<Map<String, dynamic>>> listar(String token) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['ok'] == true) {
        return List<Map<String, dynamic>>.from(response.data['boletas']);
      }
      return [];
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }
}