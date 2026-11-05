import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ComunicadoApiException implements Exception {
  final String message;
  final int? statusCode;

  const ComunicadoApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ComunicadoArchivo {
  final int id;
  final String nombre;
  final String mime;
  final int tamano;

  const ComunicadoArchivo({
    required this.id,
    required this.nombre,
    required this.mime,
    required this.tamano,
  });

  factory ComunicadoArchivo.fromJson(Map<String, dynamic> json) =>
      ComunicadoArchivo(
        id: ComunicadoService.entero(json['id']),
        nombre: (json['nombre'] ?? '').toString(),
        mime: (json['mime'] ?? '').toString(),
        tamano: ComunicadoService.entero(json['tamano']),
      );

  bool get esLegacy => id <= 0;
}

class ArchivoSubida {
  final Uint8List bytes;
  final String nombre;

  const ArchivoSubida({required this.bytes, required this.nombre});
}

class Comunicado {
  final int id;
  final String titulo;
  final String contenido;
  final bool importante;
  final bool activo;
  final String autor;
  final String creadoEn;
  final bool tieneImagen;
  final bool tieneArchivo;
  final String archivoNombre;
  final int archivoTamano;
  final List<ComunicadoArchivo> archivos;
  final ComunicadoReacciones reacciones;

  const Comunicado({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.importante,
    required this.activo,
    required this.autor,
    required this.creadoEn,
    required this.tieneImagen,
    required this.tieneArchivo,
    required this.archivoNombre,
    required this.archivoTamano,
    required this.archivos,
    this.reacciones = const ComunicadoReacciones(),
  });

  factory Comunicado.fromJson(Map<String, dynamic> json) {
    final rawArchivos = json['archivos'];
    final archivos = rawArchivos is List
        ? rawArchivos
              .whereType<Map>()
              .map(
                (e) => ComunicadoArchivo.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <ComunicadoArchivo>[];
    if (archivos.isEmpty && json['tiene_archivo'] == true) {
      archivos.add(
        ComunicadoArchivo(
          id: 0,
          nombre: (json['archivo_nombre'] ?? '').toString(),
          mime: '',
          tamano: ComunicadoService.entero(json['archivo_tamano']),
        ),
      );
    }
    return Comunicado(
      id: ComunicadoService.entero(json['id']),
      titulo: (json['titulo'] ?? '').toString(),
      contenido: (json['contenido'] ?? '').toString(),
      importante: ComunicadoService.entero(json['importante']) == 1,
      activo: ComunicadoService.entero(json['activo']) == 1,
      autor: (json['autor'] ?? '').toString(),
      creadoEn: (json['creado_en'] ?? '').toString(),
      tieneImagen: json['tiene_imagen'] == true,
      tieneArchivo: json['tiene_archivo'] == true || archivos.isNotEmpty,
      archivoNombre:
          (json['archivo_nombre'] ??
                  (archivos.isNotEmpty ? archivos.first.nombre : ''))
              .toString(),
      archivoTamano: ComunicadoService.entero(json['archivo_tamano']),
      archivos: archivos,
      reacciones: json['reacciones'] is Map
          ? ComunicadoReacciones.fromJson(
              Map<String, dynamic>.from(json['reacciones'] as Map),
            )
          : const ComunicadoReacciones(),
    );
  }
}

/// Persona que reacciono a un comunicado.
class Reaccor {
  final int id;
  final String nombre;

  const Reaccor({required this.id, required this.nombre});

  factory Reaccor.fromJson(Map<String, dynamic> json) => Reaccor(
        id: ComunicadoService.entero(json['id']),
        nombre: (json['nombre'] ?? '').toString(),
      );
}

/// Reacciones de un comunicado (tipo Facebook).
/// [conteos] = cuantos reaccionaron por tipo, [mias] = los tipos que puso
/// el usuario en sesion (solo uno), [usuarios] = quienes reaccionaron.
class ComunicadoReacciones {
  final Map<String, int> conteos;
  final List<String> mias;
  final List<Reaccor> usuarios;
  final int total;

  const ComunicadoReacciones({
    this.conteos = const {},
    this.mias = const [],
    this.usuarios = const [],
    this.total = 0,
  });

  factory ComunicadoReacciones.fromJson(Map<String, dynamic> json) {
    final rawConteos = json['conteos'];
    final conteos = <String, int>{};
    if (rawConteos is Map) {
      rawConteos.forEach((k, v) {
        conteos[k.toString()] = v is num ? v.toInt() : 0;
      });
    }
    final rawMias = json['mias'];
    final mias = rawMias is List
        ? rawMias.map((e) => e.toString()).toList()
        : <String>[];
    final rawUsuarios = json['usuarios'];
    final usuarios = rawUsuarios is List
        ? rawUsuarios
            .whereType<Map>()
            .map((e) => Reaccor.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Reaccor>[];
    final total = json['total'] is num
        ? (json['total'] as num).toInt()
        : conteos.values.fold(0, (a, b) => a + b);

    return ComunicadoReacciones(
      conteos: conteos,
      mias: mias,
      usuarios: usuarios,
      total: total,
    );
  }

  bool tiene(String tipo) => mias.contains(tipo);

  int cuenta(String tipo) => conteos[tipo] ?? 0;

  /// Copia con el tipo agregado o quitado (para el update optimista).
  /// Cada persona tiene una sola reaccion: se reemplaza la anterior.
  ComunicadoReacciones alternando(String tipo) {
    final nuevosConteos = Map<String, int>.from(conteos);
    final nuevasMias = List<String>.from(mias);

    // Se quita la reaccion anterior de esta persona (si habia).
    for (final anterior in nuevasMias) {
      nuevosConteos[anterior] = (nuevosConteos[anterior] ?? 1) - 1;
      if (nuevosConteos[anterior]! <= 0) nuevosConteos.remove(anterior);
    }
    nuevasMias.clear();

    if (tiene(tipo)) {
      // Era la misma: queda sin reaccion.
    } else {
      nuevasMias.add(tipo);
      nuevosConteos[tipo] = (nuevosConteos[tipo] ?? 0) + 1;
    }

    return ComunicadoReacciones(
      conteos: nuevosConteos,
      mias: nuevasMias,
      usuarios: usuarios,
      total: nuevosConteos.values.fold(0, (a, b) => a + b),
    );
  }
}

/// Tipos de reaccion. Deben coincidir con com_tipos_reaccion() del PHP.
const Map<String, String> tiposReaccion = {
  'me_gusta': '👍',
  'me_encanta': '❤️',
  'util': '💡',
  'aplauso': '👏',
  'jeje': '😄',
};

class ComunicadoService {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  static int entero(dynamic valor) {
    if (valor is num) return valor.toInt();
    if (valor is String) {
      final numero = num.tryParse(valor);
      if (numero != null) return numero.toInt();
    }
    return 0;
  }

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  String imagenUrl(int id, String token) =>
      '$baseUrl/comunicado_archivo.php?tipo=imagen&id=$id&t=${Uri.encodeComponent(token)}';

  String archivoUrl(int id, String token, {int adjuntoId = 0}) {
    final adjunto = adjuntoId > 0 ? '&adjunto=$adjuntoId' : '';
    return '$baseUrl/comunicado_archivo.php?tipo=archivo&id=$id$adjunto&t=${Uri.encodeComponent(token)}';
  }

  Future<List<Comunicado>> listar({
    required String token,
    String buscar = '',
  }) async {
    final uri = Uri.parse('$baseUrl/comunicados.php').replace(
      queryParameters: {
        'action': 'listar',
        if (buscar.trim().isNotEmpty) 'buscar': buscar.trim(),
      },
    );
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    final raw = body['comunicados'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => Comunicado.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Agrega o quita la reaccion del usuario (tipo Facebook).
  /// Devuelve las reacciones ya actualizadas por el servidor.
  Future<ComunicadoReacciones> reaccionar({
    required String token,
    required int comunicadoId,
    required String tipo,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/comunicados.php?action=reaccionar'),
          headers: _headers(token),
          body: jsonEncode({'comunicado_id': comunicadoId, 'tipo': tipo}),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    final raw = body['reacciones'];
    if (raw is Map) {
      return ComunicadoReacciones.fromJson(Map<String, dynamic>.from(raw));
    }
    return const ComunicadoReacciones();
  }

  Future<List<Comunicado>> adminListar({required String token}) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/admin_comunicados.php?action=listar'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    final raw = body['comunicados'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => Comunicado.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> crear({
    required String token,
    required String titulo,
    String contenido = '',
    bool importante = false,
    Uint8List? imagenBytes,
    String? imagenNombre,
    List<ArchivoSubida> archivos = const [],
  }) async {
    final body = await _enviarMultipart(
      token: token,
      accion: 'crear',
      campos: {
        'titulo': titulo,
        'contenido': contenido,
        'importante': importante ? '1' : '0',
      },
      imagenBytes: imagenBytes,
      imagenNombre: imagenNombre,
      archivos: archivos,
    );
    return entero(body['id']);
  }

  Future<void> actualizar({
    required String token,
    required int id,
    required String titulo,
    String contenido = '',
    bool importante = false,
    Uint8List? imagenBytes,
    String? imagenNombre,
    List<ArchivoSubida> archivos = const [],
    List<int> eliminarAdjuntos = const [],
    bool quitarImagen = false,
    bool quitarArchivo = false,
  }) async {
    await _enviarMultipart(
      token: token,
      accion: 'actualizar',
      campos: {
        'id': '$id',
        'titulo': titulo,
        'contenido': contenido,
        'importante': importante ? '1' : '0',
        if (quitarImagen) 'quitar_imagen': '1',
        if (quitarArchivo) 'quitar_archivo': '1',
        if (eliminarAdjuntos.any((e) => e > 0))
          'eliminar_adjuntos': eliminarAdjuntos.where((e) => e > 0).join(','),
      },
      imagenBytes: imagenBytes,
      imagenNombre: imagenNombre,
      archivos: archivos,
    );
  }

  Future<void> toggle({required String token, required int id}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_comunicados.php?action=toggle'),
      headers: {
        ..._headers(token),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({'id': id}),
    );
    _decode(response);
  }

  Future<void> eliminar({required String token, required int id}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_comunicados.php?action=eliminar'),
      headers: {
        ..._headers(token),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({'id': id}),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> _enviarMultipart({
    required String token,
    required String accion,
    required Map<String, String> campos,
    Uint8List? imagenBytes,
    String? imagenNombre,
    List<ArchivoSubida> archivos = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/admin_comunicados.php?action=$accion');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(token))
      ..fields.addAll(campos);

    if (imagenBytes != null && imagenNombre != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'imagen',
          imagenBytes,
          filename: imagenNombre,
        ),
      );
    }
    for (final archivo in archivos) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'archivos[]',
          archivo.bytes,
          filename: archivo.nombre,
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw ComunicadoApiException(
        'El servidor devolvió una respuesta inválida.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      final message =
          (body['mensaje'] ??
                  body['error'] ??
                  'No se pudo completar la operación.')
              .toString();
      throw ComunicadoApiException(message, statusCode: response.statusCode);
    }
    return body;
  }
}
