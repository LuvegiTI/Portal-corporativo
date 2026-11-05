import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/mensaje_error.dart';

int _entero(dynamic valor) {
  if (valor is num) return valor.toInt();
  if (valor is String) {
    final numero = num.tryParse(valor);
    if (numero != null) return numero.toInt();
  }
  return 0;
}

String _texto(dynamic valor) => valor == null ? '' : valor.toString();

class RucApiException implements Exception {
  final String message;
  final int? statusCode;

  const RucApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class RucResumen {
  final int total;
  final int verificados;
  final int pendientes;
  final int alertas;
  final int ultimas24h;
  final String ultimaSincronizacion;
  final int diasEntreConsultas;

  const RucResumen({
    this.total = 0,
    this.verificados = 0,
    this.pendientes = 0,
    this.alertas = 0,
    this.ultimas24h = 0,
    this.ultimaSincronizacion = '',
    this.diasEntreConsultas = 15,
  });

  factory RucResumen.fromJson(Map<String, dynamic> json) {
    return RucResumen(
      total: _entero(json['total']),
      verificados: _entero(json['verificados']),
      pendientes: _entero(json['pendientes']),
      alertas: _entero(json['alertas']),
      ultimas24h: _entero(json['ultimas_24h']),
      ultimaSincronizacion: _texto(json['ultima_sincronizacion']),
      diasEntreConsultas: _entero(json['dias_entre_consultas']),
    );
  }
}

class RucControlItem {
  final int partnerId;
  final String vat;
  final String nombre;
  final String estado;
  final String condicion;
  final String ultimaVerificacion;
  final String ultimoResultado;
  final String ultimoMensaje;
  final bool alerta;
  final String alertaDesde;
  final int intentos;

  const RucControlItem({
    required this.partnerId,
    required this.vat,
    required this.nombre,
    this.estado = '',
    this.condicion = '',
    this.ultimaVerificacion = '',
    this.ultimoResultado = '',
    this.ultimoMensaje = '',
    this.alerta = false,
    this.alertaDesde = '',
    this.intentos = 0,
  });

  factory RucControlItem.fromJson(Map<String, dynamic> json) {
    return RucControlItem(
      partnerId: _entero(json['partner_id']),
      vat: _texto(json['vat']),
      nombre: _texto(json['nombre']),
      estado: _texto(json['estado']),
      condicion: _texto(json['condicion']),
      ultimaVerificacion: _texto(json['ultima_verificacion']),
      ultimoResultado: _texto(json['ultimo_resultado']),
      ultimoMensaje: _texto(json['ultimo_mensaje']),
      alerta: _entero(json['alerta']) == 1,
      alertaDesde: _texto(json['alerta_desde']),
      intentos: _entero(json['intentos']),
    );
  }
}

class RucHistorialItem {
  final int id;
  final int partnerId;
  final String vat;
  final String nombre;
  final String estadoAnterior;
  final String condicionAnterior;
  final String estadoNuevo;
  final String condicionNuevo;
  final String resultado;
  final String mensaje;
  final String verificadoEn;

  const RucHistorialItem({
    required this.id,
    required this.partnerId,
    required this.vat,
    required this.nombre,
    this.estadoAnterior = '',
    this.condicionAnterior = '',
    this.estadoNuevo = '',
    this.condicionNuevo = '',
    this.resultado = '',
    this.mensaje = '',
    this.verificadoEn = '',
  });

  factory RucHistorialItem.fromJson(Map<String, dynamic> json) {
    return RucHistorialItem(
      id: _entero(json['id']),
      partnerId: _entero(json['partner_id']),
      vat: _texto(json['vat']),
      nombre: _texto(json['nombre']),
      estadoAnterior: _texto(json['estado_anterior']),
      condicionAnterior: _texto(json['condicion_anterior']),
      estadoNuevo: _texto(json['estado_nuevo']),
      condicionNuevo: _texto(json['condicion_nuevo']),
      resultado: _texto(json['resultado']),
      mensaje: _texto(json['mensaje']),
      verificadoEn: _texto(json['verificado_en']),
    );
  }
}

class RucListado {
  final List<RucControlItem> items;
  final int total;
  final int page;
  final int pageSize;

  const RucListado({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 50,
  });
}

class RucHistorial {
  final List<RucHistorialItem> items;
  final int total;
  final int page;
  final int pageSize;

  const RucHistorial({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 50,
  });
}

class RucVerificacionResultado {
  final bool alerta;
  final String estadoAnterior;
  final String condicionAnterior;
  final String estado;
  final String condicion;
  final String resultado;

  const RucVerificacionResultado({
    this.alerta = false,
    this.estadoAnterior = '',
    this.condicionAnterior = '',
    this.estado = '',
    this.condicion = '',
    this.resultado = '',
  });

  factory RucVerificacionResultado.fromJson(Map<String, dynamic> json) {
    return RucVerificacionResultado(
      alerta: json['alerta'] == true || _entero(json['alerta']) == 1,
      estadoAnterior: _texto(json['estado_anterior']),
      condicionAnterior: _texto(json['condicion_anterior']),
      estado: _texto(json['estado']),
      condicion: _texto(json['condicion']),
      resultado: _texto(json['resultado']),
    );
  }
}

class RucService {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw RucApiException(
        'El servidor devolvió una respuesta inválida.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      final codigo = (body['error'] ?? body['mensaje'] ?? '').toString();
      throw RucApiException(
        MensajeError.desdeCodigo(
          codigo.trim().isEmpty ? 'ERROR_GENERICO' : codigo,
        ),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<RucResumen> resumen({required String token}) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/ruc_verificaciones.php?action=resumen'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 30));
    final body = _decode(response);
    final raw = body['resumen'];
    return RucResumen.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  Future<RucListado> listar({
    required String token,
    String filtro = 'todos',
    String q = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/ruc_verificaciones.php').replace(
      queryParameters: {
        'action': 'listar',
        'filtro': filtro,
        'q': q,
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 30));
    final body = _decode(response);
    final raw = body['items'] as List<dynamic>? ?? const [];
    return RucListado(
      items: raw
          .whereType<Map>()
          .map((e) => RucControlItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: _entero(body['total']),
      page: _entero(body['page']),
      pageSize: _entero(body['page_size']),
    );
  }

  Future<RucHistorial> historial({
    required String token,
    int partnerId = 0,
    String q = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'action': 'historial',
      'q': q,
      'page': '$page',
      'page_size': '$pageSize',
    };
    if (partnerId > 0) params['partner_id'] = '$partnerId';
    final uri = Uri.parse(
      '$baseUrl/ruc_verificaciones.php',
    ).replace(queryParameters: params);
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 30));
    final body = _decode(response);
    final raw = body['items'] as List<dynamic>? ?? const [];
    return RucHistorial(
      items: raw
          .whereType<Map>()
          .map((e) => RucHistorialItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: _entero(body['total']),
      page: _entero(body['page']),
      pageSize: _entero(body['page_size']),
    );
  }

  Future<RucVerificacionResultado> verificar({
    required String token,
    required int partnerId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/ruc_verificaciones.php?action=verificar'),
          headers: _headers(token),
          body: jsonEncode({'partner_id': partnerId}),
        )
        .timeout(const Duration(seconds: 90));
    final body = _decode(response);
    final raw = body['resultado'];
    return RucVerificacionResultado.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> ejecutarVerificacion({
    required String token,
    int limite = 50,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/ruc_verificaciones.php?action=ejecutar'),
          headers: _headers(token),
          body: jsonEncode({'limite': limite}),
        )
        .timeout(const Duration(minutes: 12));
    return _decode(response);
  }
}

