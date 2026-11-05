import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/mensaje_error.dart';

/// Convierte a `int` un valor numerico llegado de JSON sin lanzar.
///
/// El servidor puede devolver `null` en cualquier columna (p. ej.
/// `detalle_ticket.php` no selecciona `adjuntos`, algo que si hace
/// `consultar_ticket.php`), por lo que el patron clasico
/// `(x ?? 0) is num ? (x as num).toInt() : 0` revienta: la condicion evalua
/// el valor coalescido pero el cuerpo casthea el crudo, y `null as num`
/// lanza `TypeError: type 'Null' is not a subtype of type 'num'`.
int _entero(dynamic valor) {
  if (valor is num) return valor.toInt();
  if (valor is String) {
    final numero = num.tryParse(valor);
    if (numero != null) return numero.toInt();
  }
  return 0;
}

class TicketApiException implements Exception {
  final String message;
  final int? statusCode;

  const TicketApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class TicketAdjunto {
  final int id;
  final String nombreArchivo;
  final String ruta;
  final String mime;
  final int tamano;

  const TicketAdjunto({
    this.id = 0,
    required this.nombreArchivo,
    required this.ruta,
    required this.mime,
    required this.tamano,
  });

  factory TicketAdjunto.fromJson(Map<String, dynamic> json) {
    return TicketAdjunto(
      id: _entero(json['id']),
      nombreArchivo: (json['nombre_archivo'] ?? '').toString(),
      ruta: (json['ruta'] ?? '').toString(),
      mime: (json['mime'] ?? '').toString(),
      tamano: _entero(json['tamano']),
    );
  }
}

class TicketItem {
  final int id;
  final String codigo;
  final String asunto;
  final String estado;
  final int categoriaId;
  final String categoria;
  final int subcategoriaId;
  final String subcategoria;
  final int prioridadId;
  final String prioridad;
  final String? prioridadColor;
  final String tecnico;
  final String creador;
  final DateTime? creadoEn;
  final DateTime? fechaCierre;
  final DateTime? fechaAsignacion;
  final int adjuntos;
  final int ultimoMensajeId;
  final bool ultimoMensajeMio;

  const TicketItem({
    required this.id,
    required this.codigo,
    required this.asunto,
    required this.estado,
    this.categoriaId = 0,
    required this.categoria,
    this.subcategoriaId = 0,
    this.subcategoria = '',
    this.prioridadId = 0,
    required this.prioridad,
    this.prioridadColor,
    required this.tecnico,
    required this.creador,
    this.creadoEn,
    this.fechaCierre,
    this.fechaAsignacion,
    required this.adjuntos,
    this.ultimoMensajeId = 0,
    this.ultimoMensajeMio = false,
  });

  factory TicketItem.fromJson(Map<String, dynamic> json) {
    final estado = (json['estado'] ?? '').toString();
    return TicketItem(
      id: _entero(json['id']),
      codigo: (json['codigo'] ?? '').toString(),
      asunto: (json['asunto'] ?? '').toString(),
      estado: TicketUtils.normalizarEstado(estado),
      categoriaId: _entero(json['categoria_id']),
      categoria: (json['categoria'] ?? '').toString(),
      subcategoriaId: _entero(json['subcategoria_id']),
      subcategoria: (json['subcategoria'] ?? '').toString(),
      prioridadId: _entero(json['prioridad_id']),
      prioridad: (json['prioridad'] ?? '').toString(),
      prioridadColor: (json['prioridad_color'] ?? '').toString().isEmpty
          ? null
          : (json['prioridad_color'] ?? '').toString(),
      tecnico: (json['tecnico'] ?? '').toString(),
      creador: (json['creador'] ?? '').toString(),
      creadoEn: _parseFecha(json['created_at']),
      fechaCierre: _parseFecha(json['fecha_cierre']),
      fechaAsignacion: _parseFecha(json['fecha_asignacion']),
      adjuntos: _entero(json['adjuntos']),
      ultimoMensajeId: _entero(json['ultimo_mensaje_id']),
      ultimoMensajeMio: json['ultimo_mensaje_mio'] == true,
    );
  }

  static DateTime? _parseFecha(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class TicketDetalle {
  final TicketItem ticket;
  final String descripcion;
  final List<TicketAdjunto> adjuntos;
  final List<Map<String, dynamic>> historial;
  final bool esCreador;
  final bool esTecnico;

  const TicketDetalle({
    required this.ticket,
    required this.descripcion,
    required this.adjuntos,
    required this.historial,
    this.esCreador = false,
    this.esTecnico = false,
  });
}

class TicketMensajeAdjunto {
  final int id;
  final String nombreArchivo;
  final String ruta;
  final String mime;
  final int tamano;

  const TicketMensajeAdjunto({
    required this.id,
    required this.nombreArchivo,
    required this.ruta,
    required this.mime,
    required this.tamano,
  });

  factory TicketMensajeAdjunto.fromJson(Map<String, dynamic> json) {
    return TicketMensajeAdjunto(
      id: _entero(json['id']),
      nombreArchivo: (json['nombre_archivo'] ?? '').toString(),
      ruta: (json['ruta'] ?? '').toString(),
      mime: (json['mime'] ?? '').toString(),
      tamano: _entero(json['tamano']),
    );
  }
}

class TicketMensaje {
  final int id;
  final int autorId;
  final String autor;
  final String rol;
  final String mensaje;
  final DateTime? creadoEn;
  final bool esMio;
  final List<TicketMensajeAdjunto> adjuntos;

  const TicketMensaje({
    required this.id,
    required this.autorId,
    required this.autor,
    required this.rol,
    required this.mensaje,
    this.creadoEn,
    required this.esMio,
    required this.adjuntos,
  });

  factory TicketMensaje.fromJson(Map<String, dynamic> json) {
    final rawAdjuntos = json['adjuntos'] as List<dynamic>? ?? const [];
    return TicketMensaje(
      id: _entero(json['id']),
      autorId: _entero(json['autor_id']),
      autor: (json['autor_nombre'] ?? '').toString(),
      rol: (json['rol'] ?? 'USUARIO').toString().toUpperCase(),
      mensaje: (json['mensaje'] ?? '').toString(),
      creadoEn: TicketItem._parseFecha(json['creado_en']),
      esMio: json['es_mio'] == true,
      adjuntos: rawAdjuntos
          .whereType<Map>()
          .map(
            (e) => TicketMensajeAdjunto.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class TicketNota {
  final int id;
  final int autorId;
  final String autor;
  final String nota;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? horaInicio;
  final String? horaFin;
  final DateTime? creadoEn;
  final bool esMio;

  const TicketNota({
    required this.id,
    required this.autorId,
    required this.autor,
    required this.nota,
    this.fechaInicio,
    this.fechaFin,
    this.horaInicio,
    this.horaFin,
    this.creadoEn,
    required this.esMio,
  });

  factory TicketNota.fromJson(Map<String, dynamic> json) {
    return TicketNota(
      id: _entero(json['id']),
      autorId: _entero(json['autor_id']),
      autor: (json['autor_nombre'] ?? '').toString(),
      nota: (json['nota'] ?? '').toString(),
      fechaInicio: TicketItem._parseFecha(json['fecha_inicio']),
      fechaFin: TicketItem._parseFecha(json['fecha_fin']),
      horaInicio: _horaCorta(json['hora_inicio']),
      horaFin: _horaCorta(json['hora_fin']),
      creadoEn: TicketItem._parseFecha(json['creado_en']),
      esMio: json['es_mio'] == true,
    );
  }

  /// MySQL devuelve TIME como "08:30:00"; aquí lo dejamos como "08:30".
  static String? _horaCorta(dynamic valor) {
    final texto = (valor ?? '').toString();
    if (texto.isEmpty) return null;
    return texto.length >= 5 ? texto.substring(0, 5) : texto;
  }
}

class TicketCategoria {
  final int id;
  final String nombre;
  final String descripcion;
  final bool activo;
  final int padreId;
  final String padreNombre;

  const TicketCategoria({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activo,
    this.padreId = 0,
    this.padreNombre = '',
  });

  bool get esSubcategoria => padreId > 0;

  factory TicketCategoria.fromJson(Map<String, dynamic> json) {
    return TicketCategoria(
      id: _entero(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      activo: (json['activo'] ?? 1) == 1,
      padreId: _entero(json['padre_id']),
      padreNombre: (json['padre_nombre'] ?? '').toString(),
    );
  }
}

class TicketPrioridad {
  final int id;
  final String nombre;
  final int nivel;
  final String color;
  final int slaHoras;
  final bool activo;

  const TicketPrioridad({
    required this.id,
    required this.nombre,
    required this.nivel,
    required this.color,
    this.slaHoras = 0,
    required this.activo,
  });

  factory TicketPrioridad.fromJson(Map<String, dynamic> json) {
    return TicketPrioridad(
      id: _entero(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      nivel: _entero(json['nivel']),
      color: (json['color'] ?? '#E64833').toString(),
      slaHoras: _entero(json['sla_horas']),
      activo: (json['activo'] ?? 1) == 1,
    );
  }
}

class TicketTecnico {
  final int id;
  final String nombre;
  final String correo;

  const TicketTecnico({
    required this.id,
    required this.nombre,
    required this.correo,
  });

  factory TicketTecnico.fromJson(Map<String, dynamic> json) {
    return TicketTecnico(
      id: _entero(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      correo: (json['correo'] ?? '').toString(),
    );
  }
}

class TicketRegla {
  final int id;
  final int categoriaId;
  final int tecnicoId;

  const TicketRegla({
    required this.id,
    required this.categoriaId,
    required this.tecnicoId,
  });

  factory TicketRegla.fromJson(Map<String, dynamic> json) {
    return TicketRegla(
      id: _entero(json['id']),
      categoriaId: _entero(json['categoria_id']),
      tecnicoId: _entero(json['tecnico_id']),
    );
  }
}

/// Utilidades de presentación del módulo de Tickets.
class TicketUtils {
  TicketUtils._();

  static const int maxAdjuntoMb = 15;
  static const int maxAdjuntos = 3;

  /// Devuelve el motivo del rechazo o null si el archivo es válido.
  static String? validarAdjunto(PlatformFile archivo) {
    if (archivo.size > maxAdjuntoMb * 1024 * 1024) {
      return 'El archivo ${archivo.name} supera los $maxAdjuntoMb MB.';
    }
    return null;
  }

  static const Map<String, String> _estados = {
    'NUEVO': 'Nuevo',
    'EN_ATENCION': 'En atención',
    'ESPERA_USUARIO': 'Espera de respuesta de usuario',
    'ESPERA_PROVEEDOR': 'Espera de respuesta de proveedor',
    'ESPERA_VALIDACION': 'Validación de usuario',
    'CERRADO': 'Resuelto',
    'BLOQUEADO': 'Bloqueado',
  };

  static final Map<String, String> _estadosColor = {
    'NUEVO': '#7A5AF8',
    'EN_ATENCION': '#2563EB',
    'ESPERA_USUARIO': '#7A5AF8',
    'ESPERA_PROVEEDOR': '#0EA5E9',
    'ESPERA_VALIDACION': '#F79009',
    'CERRADO': '#12B76A',
    'BLOQUEADO': '#DC2626',
  };

  static List<String> get estados {
    final labels = <String>[];
    for (final entry in _estados.entries) {
      labels.add('${entry.key}|${entry.value}');
    }
    return labels;
  }

  static String normalizarEstado(String estado) {
    final key = estado.trim().toUpperCase().replaceAll(' ', '_');
    return _estados.containsKey(key) ? key : estado.trim().toUpperCase();
  }

  static String etiquetaEstado(String estado) {
    return _estados[estado] ?? estado;
  }

  static Color colorEstado(String estado) {
    final hex = _estadosColor[estado] ?? '#667085';
    return _colorDesdeHex(hex);
  }

  static Color colorPrioridad(String nombre, String? hex) {
    if (hex != null && hex.isNotEmpty) return _colorDesdeHex(hex);
    switch (nombre.trim().toUpperCase()) {
      case 'ALTA':
        return const Color(0xFFE64833);
      case 'MEDIA':
        return const Color(0xFFF79009);
      case 'BAJA':
        return const Color(0xFF12B76A);
      default:
        return const Color(0xFF667085);
    }
  }

  static Color _colorDesdeHex(String hex) {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(
      value.length == 8 ? value : 'FF667085',
      radix: 16,
    );
    if (parsed == null) return const Color(0xFF667085);
    return Color(parsed);
  }
}

class TicketService {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  static String _fechaSolo(DateTime? fecha) {
    if (fecha == null) return '';
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  static String _horaSolo(TimeOfDay? hora) {
    if (hora == null) return '';
    final hh = hora.hour.toString().padLeft(2, '0');
    final mm = hora.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> crearTicket({
    required String token,
    required String asunto,
    required String descripcion,
    required int categoriaId,
    int? prioridadId,
    List<PlatformFile> adjuntos = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/registrar_ticket.php'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['asunto'] = asunto;
    request.fields['descripcion'] = descripcion;
    request.fields['categoria_id'] = '$categoriaId';
    if (prioridadId != null && prioridadId > 0) {
      request.fields['prioridad_id'] = '$prioridadId';
    }

    for (var i = 0; i < adjuntos.length; i++) {
      final adjunto = adjuntos[i];
      final bytes = adjunto.bytes;
      if (bytes == null) continue;
      request.files.add(
        http.MultipartFile.fromBytes(
          'adjuntos[]',
          bytes,
          filename: adjunto.name.isNotEmpty ? adjunto.name : 'adjunto_$i',
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<List<TicketCategoria>> listarCategorias({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ticket_catalogos.php?tipo=categorias'),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['categorias'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketCategoria.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TicketPrioridad>> listarPrioridades({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ticket_catalogos.php?tipo=prioridades'),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['prioridades'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketPrioridad.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TicketCategoria>> listarCategoriasAdmin({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin_tickets.php?action=categorias'),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['categorias'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketCategoria.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Subcategorías activas de una categoría general (para el detalle del ticket).
  Future<List<TicketCategoria>> listarSubcategorias({
    required String token,
    required int padreId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/ticket_catalogos.php?tipo=subcategorias&padre_id=$padreId',
      ),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['subcategorias'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketCategoria.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TicketCategoria>> listarSubcategoriasAdmin({
    required String token,
    int padreId = 0,
  }) async {
    final query = padreId > 0 ? '&padre_id=$padreId' : '';
    final response = await http.get(
      Uri.parse('$baseUrl/admin_tickets.php?action=subcategorias$query'),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['subcategorias'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketCategoria.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> crearSubcategoria({
    required String token,
    required int padreId,
    required String nombre,
    String descripcion = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=crear_subcategoria'),
      headers: _headers(token),
      body: jsonEncode({
        'padre_id': padreId,
        'nombre': nombre,
        'descripcion': descripcion,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> editarSubcategoria({
    required String token,
    required int id,
    required int padreId,
    required String nombre,
    String descripcion = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=editar_subcategoria'),
      headers: _headers(token),
      body: jsonEncode({
        'id': id,
        'padre_id': padreId,
        'nombre': nombre,
        'descripcion': descripcion,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> toggleSubcategoria({
    required String token,
    required int id,
    required bool activo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=toggle_subcategoria'),
      headers: _headers(token),
      body: jsonEncode({'id': id, 'activo': activo ? 1 : 0}),
    );
    return _decode(response);
  }

  Future<List<TicketPrioridad>> listarPrioridadesAdmin({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin_tickets.php?action=prioridades'),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['prioridades'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketPrioridad.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> editarCategoria({
    required String token,
    required int id,
    required String nombre,
    String descripcion = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=editar_categoria'),
      headers: _headers(token),
      body: jsonEncode({
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> toggleCategoria({
    required String token,
    required int id,
    required bool activo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=toggle_categoria'),
      headers: _headers(token),
      body: jsonEncode({'id': id, 'activo': activo ? 1 : 0}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> editarPrioridad({
    required String token,
    required int id,
    required String nombre,
    required int nivel,
    String color = '#E64833',
    int slaHoras = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=editar_prioridad'),
      headers: _headers(token),
      body: jsonEncode({
        'id': id,
        'nombre': nombre,
        'nivel': nivel,
        'color': color,
        'sla_horas': slaHoras,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> togglePrioridad({
    required String token,
    required int id,
    required bool activo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=toggle_prioridad'),
      headers: _headers(token),
      body: jsonEncode({'id': id, 'activo': activo ? 1 : 0}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> consultarTickets({
    required String token,
    int page = 1,
    int pageSize = 50,
    Map<String, String?> filtros = const {},
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      for (final entry in filtros.entries)
        if ((entry.value ?? '').trim().isNotEmpty)
          entry.key: entry.value!.trim(),
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl/consultar_ticket.php',
      ).replace(queryParameters: query),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Future<TicketDetalle> obtenerDetalle({
    required String token,
    required String codigo,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/detalle_ticket.php',
      ).replace(queryParameters: {'codigo': codigo}),
      headers: _headers(token),
    );
    final body = _decode(response);
    final rawTicket = body['ticket'];
    if (rawTicket is! Map) {
      throw const TicketApiException('El detalle del ticket no es válido.');
    }
    final ticketMap = Map<String, dynamic>.from(rawTicket);

    final adjuntosRaw = body['adjuntos'] as List<dynamic>? ?? const [];
    final historialRaw = body['historial'] as List<dynamic>? ?? const [];

    return TicketDetalle(
      ticket: TicketItem.fromJson(ticketMap),
      descripcion: (ticketMap['descripcion'] ?? '').toString(),
      adjuntos: adjuntosRaw
          .whereType<Map>()
          .map((e) => TicketAdjunto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      historial: historialRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      esCreador: body['es_creador'] == true,
      esTecnico: body['es_tecnico'] == true,
    );
  }

  Future<List<TicketMensaje>> listarMensajes({
    required String token,
    required String codigo,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/ticket_mensajes.php',
      ).replace(queryParameters: {'codigo': codigo}),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['mensajes'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketMensaje.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<TicketMensaje> enviarMensaje({
    required String token,
    required String codigo,
    required String mensaje,
    List<PlatformFile> adjuntos = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/ticket_mensajes.php',
      ).replace(queryParameters: {'codigo': codigo}),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['codigo'] = codigo;
    request.fields['mensaje'] = mensaje;

    for (var i = 0; i < adjuntos.length; i++) {
      final adjunto = adjuntos[i];
      final bytes = adjunto.bytes;
      if (bytes == null) continue;
      request.files.add(
        http.MultipartFile.fromBytes(
          'adjuntos[]',
          bytes,
          filename: adjunto.name.isNotEmpty ? adjunto.name : 'adjunto_$i',
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response);
    final raw = body['mensaje'];
    if (raw is! Map) {
      throw const TicketApiException(
        'El servidor no devolvió el mensaje enviado.',
      );
    }
    return TicketMensaje.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<List<TicketNota>> listarNotasInternas({
    required String token,
    required String codigo,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/ticket_notas.php',
      ).replace(queryParameters: {'codigo': codigo}),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['notas'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketNota.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<TicketNota> crearNotaInterna({
    required String token,
    required String codigo,
    required String nota,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    TimeOfDay? horaInicio,
    TimeOfDay? horaFin,
  }) async {
    final hoy = DateTime.now();
    final response = await http.post(
      Uri.parse(
        '$baseUrl/ticket_notas.php',
      ).replace(queryParameters: {'codigo': codigo}),
      headers: _headers(token),
      body: jsonEncode({
        'codigo': codigo,
        'nota': nota,
        'fecha_inicio': _fechaSolo(
          fechaInicio ?? (horaInicio != null ? hoy : null),
        ),
        'fecha_fin': _fechaSolo(fechaFin ?? (horaFin != null ? hoy : null)),
        'hora_inicio': _horaSolo(horaInicio),
        'hora_fin': _horaSolo(horaFin),
      }),
    );
    final body = _decode(response);
    final raw = body['nota'];
    if (raw is! Map) {
      throw const TicketApiException(
        'El servidor no devolvió la nota registrada.',
      );
    }
    return TicketNota.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<Map<String, dynamic>> cambiarEstado({
    required String token,
    required String codigo,
    required String estado,
    required String comentario,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/atender_ticket.php?action=cambiar_estado'),
      headers: _headers(token),
      body: jsonEncode({
        'codigo': codigo,
        'estado': estado,
        'comentario': comentario,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> cambiarPrioridadTicket({
    required String token,
    required String codigo,
    required int prioridadId,
    String? motivo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/atender_ticket.php'),
      headers: _headers(token),
      body: jsonEncode({
        'action': 'cambiar_prioridad',
        'codigo': codigo,
        'prioridad_id': prioridadId,
        if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> cambiarSubcategoriaTicket({
    required String token,
    required String codigo,
    required int subcategoriaId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/atender_ticket.php'),
      headers: _headers(token),
      body: jsonEncode({
        'action': 'cambiar_subcategoria',
        'codigo': codigo,
        'subcategoria_id': subcategoriaId,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> asignarTicket({
    required String token,
    required String codigo,
    required int tecnicoId,
    String? comentario,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/asignar_ticket.php'),
      headers: _headers(token),
      body: jsonEncode({
        'codigo': codigo,
        'tecnico_id': tecnicoId,
        'comentario': comentario ?? '',
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> editarTicket({
    required String token,
    required String codigo,
    required String asunto,
    required String descripcion,
    required int categoriaId,
    int? prioridadId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/editar_ticket.php'),
      headers: _headers(token),
      body: jsonEncode({
        'codigo': codigo,
        'asunto': asunto,
        'descripcion': descripcion,
        'categoria_id': categoriaId,
        if (prioridadId != null) 'prioridad_id': prioridadId,
      }),
    );
    return _decode(response);
  }

  Future<bool> puedeAdministrar({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin_tickets.php?action=verificar'),
        headers: _headers(token),
      );
      final body = _decode(response);
      return body['puede_administrar'] == true;
    } on TicketApiException catch (error) {
      if (error.statusCode == 403) return false;
      rethrow;
    }
  }

  Future<List<TicketTecnico>> listarTecnicos({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ticket_catalogos.php?tipo=tecnicos'),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['tecnicos'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketTecnico.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TicketRegla>> listarReglas({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin_tickets.php?action=reglas'),
      headers: _headers(token),
    );
    final body = _decode(response);
    final raw = body['reglas'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => TicketRegla.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> guardarRegla({
    required String token,
    required int categoriaId,
    required int tecnicoId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=guardar_regla'),
      headers: _headers(token),
      body: jsonEncode({'categoria_id': categoriaId, 'tecnico_id': tecnicoId}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> crearCategoria({
    required String token,
    required String nombre,
    String descripcion = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=crear_categoria'),
      headers: _headers(token),
      body: jsonEncode({'nombre': nombre, 'descripcion': descripcion}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> crearPrioridad({
    required String token,
    required String nombre,
    required int nivel,
    String color = '#E64833',
    int slaHoras = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_tickets.php?action=crear_prioridad'),
      headers: _headers(token),
      body: jsonEncode({
        'nombre': nombre,
        'nivel': nivel,
        'color': color,
        'sla_horas': slaHoras,
      }),
    );
    return _decode(response);
  }

  /// Descarga el informe PDF del ticket cerrado. Devuelve los bytes del PDF.
  Future<List<int>> descargarInforme({
    required String token,
    required String codigo,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/generar_informe_ticket.php?codigo=${Uri.encodeComponent(codigo)}',
      ),
      headers: {'Accept': 'application/pdf', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String mensaje = 'No se pudo generar el informe.';
      try {
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final codigoError = (body['error'] ?? body['mensaje'] ?? '').toString();
        if (codigoError.trim().isNotEmpty) {
          mensaje = MensajeError.desdeCodigo(codigoError);
        }
      } catch (_) {}
      throw TicketApiException(mensaje, statusCode: response.statusCode);
    }

    return response.bodyBytes;
  }

  Future<List<int>> descargarAdjunto({
    required String token,
    required String tipo,
    required int id,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/descargar_adjunto.php?tipo=${Uri.encodeComponent(tipo)}&id=$id',
    );
    final res = await http
        .get(uri, headers: {'Accept': '*/*', 'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      throw const TicketApiException(
        'Sesión expirada. Vuelve a iniciar sesión.',
      );
    }
    if (res.statusCode == 403) {
      throw const TicketApiException(
        'No tienes permiso para ver este adjunto.',
      );
    }
    if (res.statusCode == 404) {
      throw const TicketApiException('Adjunto no encontrado.');
    }
    if (res.statusCode != 200) {
      throw const TicketApiException('No se pudo descargar el adjunto.');
    }
    if (res.bodyBytes.isEmpty) {
      throw const TicketApiException('El adjunto está vacío.');
    }
    return res.bodyBytes;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw TicketApiException(
        'El servidor devolvió una respuesta inválida.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      final codigo = (body['error'] ?? body['mensaje'] ?? '').toString();
      final message = MensajeError.desdeCodigo(
        codigo.trim().isEmpty ? 'ERROR_GENERICO' : codigo,
      );
      throw TicketApiException(message, statusCode: response.statusCode);
    }
    return body;
  }
}
