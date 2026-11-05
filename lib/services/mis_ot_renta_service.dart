import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/api_client.dart';

class MisOtRentaService {
  static const String _baseUrl = 'https://portal.luvegi.com/api_luvegi/mis_ot_renta.php';

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> listar() async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {'accion': 'listar'});
    final resp = await http.get(uri, headers: await _headers());
    final data = jsonDecode(resp.body);
    if (data['ok'] == true && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    throw Exception(data['error'] ?? 'Error al listar OT');
  }

  Future<Map<String, dynamic>> detalle(int otId) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {'accion': 'detalle'});
    final resp = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'ot_id': otId}),
    );
    final data = jsonDecode(resp.body);
    if (data['ok'] == true && data['data'] is Map) {
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception(data['error'] ?? 'Error al obtener detalle');
  }

  Future<void> guardar(int otId, Map<String, dynamic> campos) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {'accion': 'guardar'});
    final body = {'ot_id': otId, ...campos};
    final resp = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(resp.body);
    if (data['ok'] == true) return;
    throw Exception(data['mensaje'] ?? data['error'] ?? 'Error al guardar');
  }

  Future<void> finalizar(int otId, Map<String, dynamic> campos) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {'accion': 'finalizar'});
    final body = {'ot_id': otId, ...campos};
    final resp = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(resp.body);
    if (data['ok'] == true) return;
    throw Exception(data['mensaje'] ?? data['error'] ?? 'Error al finalizar');
  }
}
