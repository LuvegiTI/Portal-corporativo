import 'package:dio/dio.dart';

/// Marca una excepción que expone el código de error devuelto por el
/// servidor, para poder mostrar el mensaje amigable correspondiente.
abstract class ErrorConCodigo {
  String? get codigo;
}

class MensajeError {
  MensajeError._();

  static const String _generico =
      'No pudimos completar la operación. Intenta más tarde.';
  static const String mensajeGenerico = _generico;
  static const String _sesionExpirada =
      'Tu sesión expiró. Vuelve a iniciar sesión.';
  static const String _credenciales = 'Usuario o contraseña incorrectos.';
  static const String _sinPermiso =
      'No tienes permisos para realizar esta acción.';
  static const String _duplicado = 'Ese valor ya está registrado.';
  static const String _obligatorio = 'Te falta completar un campo obligatorio.';
  static const String _noEncontrado = 'No encontramos el registro solicitado.';
  static const String _sinConexion =
      'Sin conexión. Revisa tu conexión e inténtalo de nuevo.';

  static const Set<String> _codigosSesion = {
    'TOKEN_INVALIDO',
    'TOKEN_REQUERIDO',
    'TOKEN_SIN_ID',
    'FORMATO_TOKEN_INVALIDO',
    'NO_TOKEN',
    'NO_TOKEN_ENCONTRADO',
    'SESION_INVALIDA',
  };

  static const Set<String> _codigosCredenciales = {
    'USUARIO_NO_ENCONTRADO',
    'USUARIO_NO_EXISTE',
    'USUARIO_INVALIDO',
    'CREDENCIALES_INVALIDAS',
    'INPUT_INVALIDO',
    'USUARIO_BLOQUEADO',
    'CUENTA_DESACTIVADA',
  };

  static const Set<String> _codigosPermiso = {
    'NO_AUTORIZADO',
    'SIN_PERMISO',
    'PERMISO_INVALIDO',
    'PERMISO_NO_EXISTE',
    'AREA_REDIR_NO_ASIGNADA',
  };

  static const Set<String> _codigosDuplicado = {
    'USUARIO_EXISTE',
    'NOMBRE_DUPLICADO',
    'CODIGO_DUPLICADO',
    'CATEGORIA_EXISTE',
    'PRIORIDAD_EXISTE',
  };

  static const Set<String> _codigosObligatorio = {
    'CODIGO_REQUERIDO',
    'MOTIVO_OBLIGATORIO',
    'CSV_REQUERIDO',
    'CSV_VACIO',
    'CAMPOS_VACIOS',
    'DATOS_INCOMPLETOS',
  };

  static const Set<String> _codigosNoEncontrado = {
    'NO_ENCONTRADO',
    'AREA_NO_EXISTE',
    'TICKET_NO_EXISTE',
    'RDR_NO_ENCONTRADO',
    'REDIR_NO_ENCONTRADO',
    'NOTIFICACION_NO_ENCONTRADA',
    'ACCION_NO_ENCONTRADA',
  };

  static const Map<String, String> _codigosUtiles = {
    'YA_HAY_ENCUESTA_ABIERTA':
        'No se puede abrir otra encuesta mientras haya una encuesta abierta. Debes cerrar la actual antes de abrir una nueva.',
    'ENCUESTA_NO_ENCONTRADA': 'No encontramos la encuesta solicitada.',
    'ENCUESTA_INCOMPLETA':
        'Agrega al menos una pregunta y una opción antes de abrir la encuesta.',
    'ENCUESTA_NO_ELIMINABLE': 'Solo se pueden eliminar encuestas en borrador.',
    'ENCUESTA_NO_ABIERTA': 'La encuesta no está abierta.',
    'RESULTADOS_NO_DISPONIBLES':
        'Los resultados se habilitan al cerrar la encuesta.',
    'PREGUNTA_INVALIDA': 'La pregunta no pertenece a la encuesta.',
    'OPCION_INVALIDA': 'La opción no pertenece a la pregunta.',
    'USUARIO_INVALIDO': 'El usuario seleccionado no es válido.',
    'RESPUESTAS_INVALIDAS': 'Las respuestas enviadas no son válidas.',
    'VOTACION_NO_INICIADA': 'La encuesta aún no ha comenzado.',
    'VOTACION_CERRADA': 'El plazo de votación finalizó.',
    'YA_RESPONDIO': 'Ya registraste tu respuesta en esta encuesta.',
    'NO_HABILITADO': 'No estás habilitado para participar en esta encuesta.',
    'CANDIDATO_NO_APROBADO': 'Solo se puede votar por candidatos aprobados.',
    'REQUISITOS_NECESARIOS':
        'Define los requisitos de postulación antes de iniciar la inscripción.',
    'FECHA_INVALIDA': 'La fecha ingresada no es válida.',
    'ACCION_NO_VALIDA': 'La acción solicitada no es válida.',
    'METODO_NO_PERMITIDO': 'La operación no está permitida por este medio.',
    'USUARIO_INACTIVO':
        'Tu cuenta está desactivada. Contacta al administrador.',
    'USUARIO_BLOQUEADO': 'Tu cuenta está bloqueada. Contacta al administrador.',
    'PERMISO_PROTEGIDO': 'Ese permiso está protegido y no se puede modificar.',
    'AUTO_BAJA': 'No puedes darte de baja a ti mismo.',
    'AREA_CON_USUARIOS_ACTIVOS': 'Esa área tiene usuarios activos asignados.',
    'REDIR_YA_CERRADO': 'Ese REDIR ya está cerrado.',
    'REDIR_NO_CERRADO': 'Cierra el REDIR antes de continuar.',
    'ATENCION_NO_EDITABLE': 'Esa atención ya no se puede editar.',
    'CSV_SIN_DATOS': 'El archivo no tiene filas para procesar.',
    'NOMBRE_LARGO': 'El nombre es demasiado largo.',
    'CAMPO_DEMASIADO_LARGO': 'Algún valor es demasiado largo.',
    'NUMERO_INVALIDO': 'Revisa los números ingresados.',
    'CODIGO_REDIR_INVALIDO': 'El código REDIR no es válido.',
    'TECNICO_INVALIDO': 'El técnico seleccionado no es válido.',
    'ESTADO_NO_VALIDO': 'No se puede cambiar el estado actual.',
    'MOTIVO_CIERRE_REQUERIDO': 'Debes indicar el motivo del cierre del ticket.',
    'TIPO_NO_VALIDO': 'El tipo seleccionado no es válido.',
    'ACCION_INVALIDA': 'La acción no es válida.',
    'TABLA_NO_EXISTE':
        'Falta crear la tabla de métricas de tarjetas en el servidor. Contacta con TI.',
    'FALTA_COLUMNA_DISPOSITIVO':
        'Falta actualizar la tabla de métricas en el servidor. Contacta con TI.',
    'ERROR_BASE_DATOS':
        'El servidor no pudo consultar los datos. Intenta más tarde o avisa a TI.',
    'ERROR_SERVIDOR': 'Ocurrió un error inesperado en el servidor. Avisa a TI.',
    'EXTENSION_NO_PERMITIDA':
        'Uno de los archivos tiene un formato no permitido.',
    'ARCHIVO_DEMASIADO_GRANDE':
        'Uno de los archivos supera el tamaño máximo permitido.',
    'DEMASIADOS_ADJUNTOS': 'Adjuntaste demasiados archivos en un solo envío.',
    'NO_SE_PUDO_GUARDAR_ARCHIVO':
        'No se pudo guardar el archivo. Intenta de nuevo.',
    'ERROR_LISTAR_TECNICOS':
        'No se pudo obtener el personal de TI. Avisa a TI.',
    'TICKET_CERRADO':
        'Este ticket está cerrado. Reábrelo para poder responder.',
    'TICKET_NO_EDITABLE':
        'Este ticket ya no se puede editar en su estado actual.',
    'ESTADO_TICKET_INVALIDO': 'El cambio de estado solicitado no es válido.',
    'INFORME_NO_DISPONIBLE':
        'El informe estará disponible cuando el ticket se cierre.',
    'ERROR_GENERAR_INFORME': 'No se pudo generar el informe. Avisa a TI.',
    'SIN_CONEXION': _sinConexion,
    'ERROR_GENERICO': _generico,
  };

  static bool esCodigoDeSesion(String? codigo) {
    if (codigo == null) return false;
    final c = _normalizar(codigo);
    return _codigosSesion.contains(c) ||
        c.startsWith('TOKEN_') ||
        c.contains('SESION_INVALIDA');
  }

  static String desdeCodigo(String? codigo) {
    if (codigo == null || codigo.trim().isEmpty) return _generico;

    final c = _normalizar(codigo);

    if (_codigosSesion.contains(c)) return _sesionExpirada;
    if (c.startsWith('TOKEN_')) return _sesionExpirada;
    if (_codigosCredenciales.contains(c)) return _credenciales;
    if (_codigosPermiso.contains(c)) return _sinPermiso;
    if (c.startsWith('SIN_PERMISO')) return _sinPermiso;
    if (_codigosDuplicado.contains(c)) return _duplicado;
    if (_codigosObligatorio.contains(c)) return _obligatorio;
    if (_codigosNoEncontrado.contains(c)) return _noEncontrado;

    final util = _codigosUtiles[c];
    if (util != null) return util;

    if (_pareceCodigo(c)) return _generico;
    return _sanear(codigo);
  }

  static String desdeExcepcion(Object? e) {
    if (e == null) return _generico;

    if (e is DioException) return _desdeDio(e);

    if (e is ErrorConCodigo) {
      final codigo = e.codigo;
      if (codigo != null && codigo.trim().isNotEmpty) {
        final amigable = desdeCodigo(codigo);
        if (amigable != _generico) return amigable;
        final detalle = e.toString().trim();
        if (detalle.isNotEmpty && !_pareceCodigo(_normalizar(detalle))) {
          return detalle;
        }
      }
    }

    final texto = e.toString();

    final desde = texto.indexOf(':');
    if (desde > -1) {
      final posible = _normalizar(texto.substring(desde + 1));
      if (_pareceCodigo(posible)) return desdeCodigo(posible);
    }

    final normalizado = _normalizar(texto);
    for (final codigo in {..._codigosSesion, ..._codigosCredenciales}) {
      if (normalizado.contains(codigo)) {
        return desdeCodigo(codigo);
      }
    }

    return _generico;
  }

  static String _desdeDio(DioException e) {
    // Se despacha con if/else y no con switch a proposito: DioExceptionType
    // gana casos entre versiones (la 5.10 agrego transformTimeout) y un
    // switch sobre el enum deja de compilar cuando aparece uno nuevo.
    final tipo = e.type;

    if (tipo == DioExceptionType.badResponse) {
      final data = e.response?.data;
      if (data is Map) {
        final codigo = data['error']?.toString();
        if (codigo != null && codigo.trim().isNotEmpty) {
          return desdeCodigo(codigo);
        }
        final mensaje = data['mensaje']?.toString();
        if (mensaje != null && mensaje.trim().isNotEmpty) {
          return desdeCodigo(mensaje);
        }
      }
      return _generico;
    }

    if (tipo == DioExceptionType.connectionTimeout ||
        tipo == DioExceptionType.sendTimeout ||
        tipo == DioExceptionType.receiveTimeout ||
        tipo == DioExceptionType.connectionError ||
        tipo == DioExceptionType.unknown) {
      final data = e.response?.data;
      if (data is Map) {
        final codigo = data['error']?.toString();
        if (codigo != null && codigo.trim().isNotEmpty) {
          return desdeCodigo(codigo);
        }
        final mensaje = data['mensaje']?.toString();
        if (mensaje != null && mensaje.trim().isNotEmpty) {
          return desdeCodigo(mensaje);
        }
      }
      return _sinConexion;
    }

    // cancel, badCertificate y cualquier tipo nuevo que agregue dio.
    return _generico;
  }

  static String _normalizar(String v) =>
      v.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '_');

  static bool _pareceCodigo(String v) =>
      RegExp(r'^[A-Z][A-Z0-9_]{3,}$').hasMatch(v);

  static String _sanear(String v) {
    var s = v.trim();
    s = s.replaceAll(RegExp(r'https?://\S+'), '');
    s = s.replaceAll(RegExp(r'\bException:?\s*'), '');
    s = s.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    s = s.trim();

    if (s.isEmpty || s.length > 90) return _generico;
    if (RegExp(r'[{}<>]').hasMatch(s)) return _generico;
    if (RegExp(
      r'(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)\b',
      caseSensitive: false,
    ).hasMatch(s)) {
      return _generico;
    }
    return s;
  }
}
