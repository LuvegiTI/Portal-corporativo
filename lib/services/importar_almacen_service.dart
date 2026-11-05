import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/mensaje_error.dart';

class ImportarAlmacenService {
  static const String _url =
      'https://portal.luvegi.com/api_luvegi/importar_almacen.php';

  Future<Map<String, dynamic>> importar({
    required String token,
    required String picking,
    required List<Map<String, dynamic>> lineas,
  }) async {
    final res = await http.post(
      Uri.parse(_url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'picking': picking.trim(), 'lineas': lineas}),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(MensajeError.desdeCodigo(data['error']?.toString()));
    }

    return Map<String, dynamic>.from(data);
  }
}
