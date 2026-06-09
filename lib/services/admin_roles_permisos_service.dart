import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminRolesPermisosService {
  final String baseUrl = "https://portal.luvegi.com/api_luvegi/admin_roles_permisos.php";

  Future<List<Map<String, dynamic>>> usuarios(String token) async {
    try {
      final res = await http.get(Uri.parse("$baseUrl?action=usuarios"), 
          headers: {"Authorization": "Bearer $token"});
      final data = json.decode(res.body);
      if (data['ok'] == true) {
        return List<Map<String, dynamic>>.from(data['usuarios']);
      }
      debugPrint("Error PHP Usuarios: ${data['error']}");
      return [];
    } catch (e) { 
      debugPrint("Error conexión Usuarios: $e");
      return []; 
    }
  }

  Future<List<Map<String, dynamic>>> permisos(String token) async {
    try {
      final res = await http.get(Uri.parse("$baseUrl?action=permisos"), 
          headers: {"Authorization": "Bearer $token"});
      final data = json.decode(res.body);
      if (data['ok'] == true) {
        return List<Map<String, dynamic>>.from(data['permisos']);
      }
      return [];
    } catch (e) { return []; }
  }

  Future<List<int>> permisosPorUsuario(String token, int usuarioId) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl?action=por_usuario&usuario_id=$usuarioId"),
        headers: {"Authorization": "Bearer $token"},
      );
      final data = json.decode(res.body);
      // Convertimos los IDs a enteros por si vienen como strings desde la BD
      final list = data['permisos'] as List? ?? [];
      return list.map((id) => int.parse(id.toString())).toList();
    } catch (e) { return []; }
  }

  Future<bool> guardar(String token, int uid, List<int> pids) async {
    try {
      final res = await http.post(Uri.parse("$baseUrl?action=guardar"),
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
          body: json.encode({"usuario_id": uid, "permisos": pids}));
      final data = json.decode(res.body);
      return data['ok'] == true;
    } catch (e) { return false; }
  }
}