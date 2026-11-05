import 'dart:typed_data';
import 'package:dio/dio.dart';

class AdminBoletasService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://portal.luvegi.com/api_luvegi/',
      connectTimeout: const Duration(seconds: 15),
    ),
  );

  // Genera la URL basada en tu estructura de cPanel: boletas/AÑO/MES/archivo
  String getUrlDescarga(int id, String token) {
    return "https://portal.luvegi.com/api_luvegi/admin_boletas.php?download=true&id=$id&token=$token";
  }

  Future<Map<String, dynamic>> getResumen({
    required String token,
    required String anio,
  }) async {
    try {
      final res = await _dio.get(
        "admin_boletas.php",
        // Agregamos el token aquí para que el servidor no lo bloquee
        queryParameters: {"anio": anio, "token": token},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      print("Error en getResumen: $e");
      return {"ok": false, "error": e.toString()};
    }
  }

  Future<Map<String, dynamic>> getDetalleCarga({
    required String token,
    required String anio,
    required int mesId,
  }) async {
    try {
      final res = await _dio.get(
        "admin_boletas.php",
        queryParameters: {
          "anio": anio,
          "mes": mesId,
          "detalle": "true",
          "token": token, // Respaldo
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {"ok": false};
    }
  }

  Future<Map<String, dynamic>> subirZip({
    required String token,
    required int anio,
    required int mes,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        "anio": anio,
        "mes": mes,
        "zip": MultipartFile.fromBytes(fileBytes, filename: fileName),
      });
      // En POST, el token va como query parameter en la misma URL
      final res = await _dio.post(
        "admin_boletas.php?token=$token",
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {"ok": false};
    }
  }

  Future<Map<String, dynamic>> eliminarCarga({
    required String token,
    required int anio,
    required int mes,
  }) async {
    try {
      final res = await _dio.post(
        "admin_boletas.php?delete=true&token=$token",
        data: FormData.fromMap({"anio": anio, "mes": mes}),
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {"ok": false};
    }
  }
}
