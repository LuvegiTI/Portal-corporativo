import 'dart:convert';

import 'package:dio/dio.dart';

class ConteoDispositivo {
  final int visitas;
  final int clics;

  const ConteoDispositivo({this.visitas = 0, this.clics = 0});

  factory ConteoDispositivo.fromJson(Map<String, dynamic> json) {
    return ConteoDispositivo(
      visitas: int.tryParse(json['visitas']?.toString() ?? '0') ?? 0,
      clics: int.tryParse(json['clics']?.toString() ?? '0') ?? 0,
    );
  }
}

Map<String, ConteoDispositivo> _dispositivosDe(dynamic valor) {
  if (valor is! Map) return const <String, ConteoDispositivo>{};

  final salida = <String, ConteoDispositivo>{};
  valor.forEach((clave, conteo) {
    if (conteo is Map) {
      salida[clave.toString()] =
          ConteoDispositivo.fromJson(Map<String, dynamic>.from(conteo));
    }
  });
  return salida;
}

class EstadisticaTarjetaFila {
  final String codigo;
  final String nombre;
  final String cargo;
  final int visitas;
  final int clics;
  final double interaccion;
  final DateTime? ultimaVisita;
  final DateTime? ultimoClic;
  final Map<String, ConteoDispositivo> dispositivos;

  const EstadisticaTarjetaFila({
    required this.codigo,
    required this.nombre,
    required this.cargo,
    required this.visitas,
    required this.clics,
    required this.interaccion,
    this.ultimaVisita,
    this.ultimoClic,
    this.dispositivos = const <String, ConteoDispositivo>{},
  });

  factory EstadisticaTarjetaFila.fromJson(Map<String, dynamic> json) {
    return EstadisticaTarjetaFila(
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      cargo: json['cargo']?.toString() ?? '',
      visitas: int.tryParse(json['visitas']?.toString() ?? '0') ?? 0,
      clics: int.tryParse(json['clics']?.toString() ?? '0') ?? 0,
      interaccion: double.tryParse(
            (json['interaccion'] ?? json['conversion'])?.toString() ?? '0',
          ) ??
          0,
      ultimaVisita: _fecha(json['ultima_visita']),
      ultimoClic: _fecha(json['ultimo_clic']),
      dispositivos: _dispositivosDe(json['dispositivos']),
    );
  }
}

DateTime? _fecha(dynamic valor) {
  final texto = valor?.toString().trim();
  if (texto == null || texto.isEmpty) return null;
  return DateTime.tryParse(texto.replaceFirst(' ', 'T'));
}

class EstadisticaTarjetaDatos {
  final String desde;
  final String hasta;
  final int totalVisitas;
  final int totalClics;
  final double interaccionTotal;
  final Map<String, ConteoDispositivo> dispositivos;
  final List<EstadisticaTarjetaFila> filas;

  const EstadisticaTarjetaDatos({
    required this.desde,
    required this.hasta,
    required this.totalVisitas,
    required this.totalClics,
    required this.interaccionTotal,
    this.dispositivos = const <String, ConteoDispositivo>{},
    required this.filas,
  });
}

class TarjetaEstadisticasService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://portal.luvegi.com/api_luvegi/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );

  Future<EstadisticaTarjetaDatos> consultar(
    String token, {
    required String desde,
    required String hasta,
  }) async {
    try {
      final response = await _dio.get(
        'estadisticas_tarjeta.php',
        queryParameters: {'desde': desde, 'hasta': hasta},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${token.trim()}',
            'Accept': 'application/json',
          },
        ),
      );

      var data = response.data;
      if (data is String) data = json.decode(data);
      if (data is! Map<String, dynamic> || data['ok'] != true) {
        throw Exception(_errorDe(data));
      }

      final totales = data['totales'] is Map
          ? Map<String, dynamic>.from(data['totales'] as Map)
          : <String, dynamic>{};

      final filas = (data['filas'] as List? ?? [])
          .whereType<Map>()
          .map((f) => EstadisticaTarjetaFila.fromJson(Map<String, dynamic>.from(f)))
          .toList();

      return EstadisticaTarjetaDatos(
        desde: data['desde']?.toString() ?? desde,
        hasta: data['hasta']?.toString() ?? hasta,
        totalVisitas:
            int.tryParse(totales['visitas']?.toString() ?? '0') ?? 0,
        totalClics: int.tryParse(totales['clics']?.toString() ?? '0') ?? 0,
        interaccionTotal: double.tryParse(
              (totales['interaccion'] ?? totales['conversion'])?.toString() ??
                  '0',
            ) ??
            0,
        dispositivos: _dispositivosDe(totales['dispositivos']),
        filas: filas,
      );
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map) throw Exception(_errorDe(data));
      throw Exception(_errorDe(null));
    }
  }

  String _errorDe(dynamic data) {
    if (data is Map) {
      final codigo = data['error']?.toString().trim();
      if (codigo != null && codigo.isNotEmpty) return codigo;
      final mensaje = data['mensaje']?.toString().trim();
      if (mensaje != null && mensaje.isNotEmpty) return mensaje;
    }
    return 'ERROR_GENERICO';
  }
}
