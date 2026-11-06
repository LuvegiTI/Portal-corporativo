import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/mensaje_error.dart';

class EncuestaApiException implements Exception, ErrorConCodigo {
  final String message;
  final int? statusCode;
  @override
  final String? codigo;

  const EncuestaApiException(this.message, [this.statusCode, this.codigo]);

  @override
  String toString() => message;
}

int _entero(dynamic valor) {
  if (valor is num) return valor.toInt();
  if (valor is String) {
    final numero = int.tryParse(valor);
    if (numero != null) return numero;
  }
  return 0;
}

class Encuesta {
  final int id;
  final String titulo;
  final String descripcion;
  final String? fechaInicio;
  final String? fechaFin;
  final String estado;
  final int preguntas;
  final int opciones;
  final int participantes;

  const Encuesta({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    required this.preguntas,
    required this.opciones,
    required this.participantes,
  });

  factory Encuesta.fromJson(Map<String, dynamic> json) {
    return Encuesta(
      id: _entero(json['id']),
      titulo: (json['titulo'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      fechaInicio: json['fecha_inicio']?.toString(),
      fechaFin: json['fecha_fin']?.toString(),
      estado: (json['estado'] ?? '').toString(),
      preguntas: _entero(json['preguntas']),
      opciones: _entero(json['opciones']),
      participantes: _entero(json['participantes']),
    );
  }
}

class EncuestaPregunta {
  final int id;
  final int encuestaId;
  final String nombre;
  final String descripcion;
  final int orden;
  final List<EncuestaOpcion> opciones;

  const EncuestaPregunta({
    required this.id,
    required this.encuestaId,
    required this.nombre,
    required this.descripcion,
    required this.orden,
    required this.opciones,
  });

  factory EncuestaPregunta.fromJson(Map<String, dynamic> json) {
    final rawOpciones = json['opciones'] as List<dynamic>? ?? const [];
    return EncuestaPregunta(
      id: _entero(json['id']),
      encuestaId: _entero(json['encuesta_id']),
      nombre: (json['nombre'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      orden: _entero(json['orden']),
      opciones: rawOpciones
          .whereType()
          .map((e) => EncuestaOpcion.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class EncuestaOpcion {
  final int id;
  final int preguntaId;
  final String nombre;
  final String area;
  final String propuesta;
  final String fotoUrl;
  final int orden;
  final bool activo;
  final int? usuarioId;

  const EncuestaOpcion({
    required this.id,
    required this.preguntaId,
    required this.nombre,
    required this.area,
    required this.propuesta,
    required this.fotoUrl,
    required this.orden,
    required this.activo,
    this.usuarioId,
  });

  factory EncuestaOpcion.fromJson(Map<String, dynamic> json) {
    final usuarioId = json['usuario_id'];
    return EncuestaOpcion(
      id: _entero(json['id']),
      preguntaId: _entero(json['pregunta_id']),
      nombre: (json['nombre'] ?? '').toString(),
      area: (json['area'] ?? '').toString(),
      propuesta: (json['propuesta'] ?? '').toString(),
      fotoUrl: (json['foto_url'] ?? '').toString(),
      orden: _entero(json['orden']),
      activo: json['activo'] == 1 || json['activo'] == true,
      usuarioId:
          usuarioId == null ? null : (usuarioId is num ? usuarioId.toInt() : int.tryParse('$usuarioId')),
    );
  }
}

/// Usuario de la tabla usuarios_app, para elegir candidatos de las opciones.
/// [area] y [puesto] vienen de Odoo (hr.employee) cuando hay coincidencia.
class EncuestaUsuario {
  final int id;
  final String nombre;
  final String correo;
  final String rol;
  final String rolNombre;
  final String areas;
  final String area;
  final String puesto;
  final String fotoUrl;

  const EncuestaUsuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.rolNombre,
    required this.areas,
    required this.area,
    required this.puesto,
    required this.fotoUrl,
  });

  factory EncuestaUsuario.fromJson(Map<String, dynamic> json) {
    return EncuestaUsuario(
      id: _entero(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      correo: (json['correo'] ?? '').toString(),
      rol: (json['rol'] ?? '').toString(),
      rolNombre: (json['rol_nombre'] ?? '').toString(),
      areas: (json['areas'] ?? '').toString(),
      area: (json['area'] ?? '').toString(),
      puesto: (json['puesto'] ?? '').toString(),
      fotoUrl: (json['foto_url'] ?? '').toString(),
    );
  }

  /// Detalle secundario para mostrar en la tarjeta del candidato.
  String get detalle {
    if (area.isNotEmpty) return area;
    if (areas.isNotEmpty) return areas;
    if (rolNombre.isNotEmpty) return rolNombre;
    return rol;
  }
}

/// Una encuesta abierta mas el estado del usuario frente a ella.
/// Puede haber varias abiertas a la vez y el usuario vota en cada una.
class EncuestaVotable {
  final Encuesta encuesta;
  final List<EncuestaPregunta> preguntas;
  final bool puedeResponder;
  final bool dentroDeVentana;
  final bool yaRespondio;
  final bool restringida;
  final String? recibo;
  final String? fechaRespuesta;

  const EncuestaVotable({
    required this.encuesta,
    required this.preguntas,
    required this.puedeResponder,
    required this.dentroDeVentana,
    required this.yaRespondio,
    this.restringida = false,
    this.recibo,
    this.fechaRespuesta,
  });

  factory EncuestaVotable.fromJson(Map<String, dynamic> json) {
    final rawPreguntas = json['preguntas'];
    final preguntas = rawPreguntas is List
        ? rawPreguntas
            .whereType<Map>()
            .map((e) => EncuestaPregunta.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <EncuestaPregunta>[];

    return EncuestaVotable(
      encuesta: Encuesta(
        id: _entero(json['id']),
        titulo: (json['titulo'] ?? '').toString(),
        descripcion: (json['descripcion'] ?? '').toString(),
        fechaInicio: json['fecha_inicio']?.toString(),
        fechaFin: json['fecha_fin']?.toString(),
        estado: (json['estado'] ?? '').toString(),
        preguntas: preguntas.length,
        opciones: 0,
        participantes: 0,
      ),
      preguntas: preguntas,
      puedeResponder: json['puede_responder'] != false,
      dentroDeVentana: json['dentro_de_ventana'] != false,
      yaRespondio: json['ya_respondio'] == true,
      restringida: json['restringida'] == true,
      recibo: json['recibo']?.toString(),
      fechaRespuesta: json['fecha_respuesta']?.toString(),
    );
  }
}

class EncuestaService {
  static const String baseUrl = 'https://portal.luvegi.com/api_luvegi';

  static const String _adminUrl = '$baseUrl/admin_encuestas.php';
  static const String _userUrl = '$baseUrl/encuestas_usuario.php';

  static const Duration _timeout = Duration(seconds: 15);

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Exception _handleError(http.Response res) {
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map) {
        final codigo = (data['error'] ?? '').toString().trim();
        final mensaje = (data['mensaje'] ?? '').toString().trim();

        String texto;
        if (codigo.isNotEmpty) {
          final amigable = MensajeError.desdeCodigo(codigo);
          texto = amigable != MensajeError.mensajeGenerico
              ? amigable
              : (mensaje.isNotEmpty ? mensaje : amigable);
        } else {
          texto = mensaje.isNotEmpty ? mensaje : 'Error desconocido en la API';
        }

        return EncuestaApiException(
          texto,
          res.statusCode,
          codigo.isEmpty ? null : codigo,
        );
      }
    } catch (_) {}
    return EncuestaApiException(
      'Error de red o servidor (${res.statusCode}). Intenta más tarde.',
      res.statusCode,
    );
  }

  Map<String, dynamic> _decodificar(http.Response res) {
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    throw EncuestaApiException(
      'El servidor devolvió una respuesta inválida.',
      res.statusCode,
    );
  }

  void _verificarOk(Map<String, dynamic> data, http.Response res) {
    if (data['ok'] == true) return;
    throw _handleError(res);
  }

  Future<List<Encuesta>> listar({required String token}) async {
    final res = await http
        .get(Uri.parse('$_adminUrl?action=listar'), headers: _headers(token))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);

    final rawList = data['encuestas'] as List<dynamic>? ?? const [];
    return rawList
        .whereType()
        .map((e) => Encuesta.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> detalle({
    required String token,
    required int id,
  }) async {
    final res = await http
        .get(Uri.parse('$_adminUrl?action=detalle&id=$id'), headers: _headers(token))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
    return data;
  }

  Future<void> crear({
    required String token,
    required String titulo,
    String? descripcion,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final body = jsonEncode({
      'titulo': titulo,
      if (descripcion != null) 'descripcion': descripcion,
      if (fechaInicio != null) 'fecha_inicio': fechaInicio,
      if (fechaFin != null) 'fecha_fin': fechaFin,
    });
    final res = await http
        .post(Uri.parse('$_adminUrl?action=crear'), headers: _headers(token), body: body)
        .timeout(_timeout);

    if (res.statusCode != 201 && res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  Future<void> actualizar({
    required String token,
    required int id,
    required String titulo,
    String? descripcion,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final body = jsonEncode({
      'id': id,
      'titulo': titulo,
      if (descripcion != null) 'descripcion': descripcion,
      if (fechaInicio != null) 'fecha_inicio': fechaInicio,
      if (fechaFin != null) 'fecha_fin': fechaFin,
    });
    final res = await http
        .post(Uri.parse('$_adminUrl?action=actualizar'), headers: _headers(token), body: body)
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  Future<void> abrir({required String token, required int id}) async {
    final res = await http
        .post(Uri.parse('$_adminUrl?action=abrir'),
            headers: _headers(token), body: jsonEncode({'id': id}))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  Future<void> cerrar({required String token, required int id}) async {
    final res = await http
        .post(Uri.parse('$_adminUrl?action=cerrar'),
            headers: _headers(token), body: jsonEncode({'id': id}))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  Future<void> eliminar({required String token, required int id}) async {
    final res = await http
        .post(Uri.parse('$_adminUrl?action=eliminar'),
            headers: _headers(token), body: jsonEncode({'id': id}))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  Future<void> guardarPregunta({
    required String token,
    required int encuestaId,
    int? id,
    required String nombre,
    String? descripcion,
    int orden = 0,
  }) async {
    final body = jsonEncode({
      if (id != null) 'id': id,
      'encuesta_id': encuestaId,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'orden': orden,
    });
    final res = await http
        .post(Uri.parse('$_adminUrl?action=guardar_pregunta'),
            headers: _headers(token), body: body)
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 201) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  Future<void> eliminarPregunta({required String token, required int id}) async {
    final res = await http
        .post(Uri.parse('$_adminUrl?action=eliminar_pregunta'),
            headers: _headers(token), body: jsonEncode({'id': id}))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  Future<void> guardarOpcion({
    required String token,
    required int encuestaId,
    required int preguntaId,
    int? id,
    required String nombre,
    String? area,
    String? propuesta,
    String? fotoUrl,
    int orden = 0,
    bool activo = true,
    int? usuarioId,
  }) async {
    final body = jsonEncode({
      if (id != null) 'id': id,
      'encuesta_id': encuestaId,
      'pregunta_id': preguntaId,
      'nombre': nombre,
      if (area != null) 'area': area,
      if (propuesta != null) 'propuesta': propuesta,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      'orden': orden,
      'activo': activo,
      'usuario_id': usuarioId,
    });
    final res = await http
        .post(Uri.parse('$_adminUrl?action=guardar_opcion'),
            headers: _headers(token), body: body)
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 201) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  Future<void> eliminarOpcion({required String token, required int id}) async {
    final res = await http
        .post(Uri.parse('$_adminUrl?action=eliminar_opcion'),
            headers: _headers(token), body: jsonEncode({'id': id}))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
  }

  /// Usuarios activos de usuarios_app para elegir candidatos de las opciones.
  Future<List<EncuestaUsuario>> listarUsuarios({
    required String token,
  }) async {
    final res = await http
        .get(Uri.parse('$_adminUrl?action=usuarios'), headers: _headers(token))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);

    final rawList = data['usuarios'] as List<dynamic>? ?? const [];
    return rawList
        .whereType()
        .map((e) => EncuestaUsuario.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Rellena la foto (y el area) de las opciones que ya estan vinculadas a
  /// un usuario del portal pero que se guardaron sin foto.
  Future<Map<String, dynamic>> sincronizarFotos({
    required String token,
    required int encuestaId,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_adminUrl?action=sincronizar_fotos'),
          headers: _headers(token),
          body: jsonEncode({'encuesta_id': encuestaId}),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
    return data;
  }

  Future<Map<String, dynamic>> participacion({
    required String token,
    required int id,
  }) async {    final res = await http
        .get(Uri.parse('$_adminUrl?action=participacion&id=$id'),
            headers: _headers(token))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
    return data;
  }

  Future<Map<String, dynamic>> resultados({
    required String token,
    required int id,
  }) async {
    final res = await http
        .get(Uri.parse('$_adminUrl?action=resultados&id=$id'),
            headers: _headers(token))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
    return data;
  }

  /// Encuestas abiertas ahora mismo. Puede haber varias a la vez.
  Future<List<EncuestaVotable>> obtenerEncuestasAbiertas({
    required String token,
  }) async {
    final res = await http
        .get(Uri.parse('$_userUrl?action=actual'), headers: _headers(token))
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);

    final raw = data['encuestas'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => EncuestaVotable.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Personal habilitado a votar en una encuesta.
  /// Si la lista viene vacia, la encuesta queda abierta a todo el personal
  /// con el permiso VOTAR_ELECCIONES.
  Future<Map<String, dynamic>> guardarVotantes({
    required String token,
    required int encuestaId,
    required List<int> usuarioIds,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_adminUrl?action=guardar_votantes'),
          headers: _headers(token),
          body: jsonEncode({
            'encuesta_id': encuestaId,
            'usuario_ids': usuarioIds,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
    return data;
  }

  /// Lista el personal y quien esta habilitado en esa encuesta.
  Future<Map<String, dynamic>> listarVotantes({
    required String token,
    required int encuestaId,
  }) async {
    final res = await http
        .get(
          Uri.parse('$_adminUrl?action=votantes&encuesta_id=$encuestaId'),
          headers: _headers(token),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
    return data;
  }

  Future<Map<String, dynamic>> responder({
    required String token,
    required int encuestaId,
    required List<Map<String, dynamic>> respuestas,
  }) async {
    final body = jsonEncode({
      'encuesta_id': encuestaId,
      'respuestas': respuestas,
    });
    final res = await http
        .post(Uri.parse('$_userUrl?action=responder'),
            headers: _headers(token), body: body)
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 201) throw _handleError(res);
    final data = _decodificar(res);
    _verificarOk(data, res);
    return data;
  }
}
