import 'dart:convert';

import 'package:http/http.dart' as http;

class RdrNotificacion {
  final int id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final String codigo;
  final String estado;
  final DateTime? creadaEn;
  final bool leida;

  const RdrNotificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.codigo,
    required this.estado,
    required this.creadaEn,
    required this.leida,
  });

  factory RdrNotificacion.fromJson(Map<String, dynamic> json) {
    return RdrNotificacion(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      tipo: '${json['tipo'] ?? ''}',
      titulo: '${json['titulo'] ?? ''}',
      mensaje: '${json['mensaje'] ?? ''}',
      codigo: '${json['codigo'] ?? ''}',
      estado: '${json['estado'] ?? ''}',
      creadaEn: DateTime.tryParse('${json['creada_en'] ?? ''}'),
      leida: json['leida'] == true ||
          json['leida'] == 1 ||
          '${json['leida']}' == '1',
    );
  }
}

class RdrNotificacionesResultado {
  final int noLeidas;
  final List<RdrNotificacion> notificaciones;

  const RdrNotificacionesResultado({
    required this.noLeidas,
    required this.notificaciones,
  });
}

class RdrNotificacionesService {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<RdrNotificacionesResultado> listar(
    String token, {
    int limit = 15,
  }) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/notificaciones_rdr.php').replace(
            queryParameters: {'action': 'listar', 'limit': '$limit'},
          ),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    final raw = body['data'] as List<dynamic>? ?? const [];
    return RdrNotificacionesResultado(
      noLeidas: int.tryParse('${body['no_leidas'] ?? 0}') ?? 0,
      notificaciones: raw
          .whereType<Map>()
          .map((e) => RdrNotificacion.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }

  Future<void> marcarLeida(String token, int id) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/notificaciones_rdr.php')
              .replace(queryParameters: {'action': 'leer'}),
          headers: _headers(token),
          body: jsonEncode({'id': id}),
        )
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  Future<void> marcarTodasLeidas(String token) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/notificaciones_rdr.php')
              .replace(queryParameters: {'action': 'leer_todas'}),
          headers: _headers(token),
          body: '{}',
        )
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      throw Exception('El servidor devolvió una respuesta inválida.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      throw Exception(
        (body['mensaje'] ?? body['error'] ?? 'Error de notificaciones')
            .toString(),
      );
    }
    return body;
  }
}