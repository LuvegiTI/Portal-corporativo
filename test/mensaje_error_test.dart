import 'package:flutter_test/flutter_test.dart';
import 'package:luvegi/utils/mensaje_error.dart';

void main() {
  group('MensajeError.desdeCodigo', () {
    test('nunca devuelve el codigo crudo del backend', () {
      const codigos = [
        'TOKEN_INVALIDO',
        'TOKEN_REQUERIDO',
        'NO_TOKEN',
        'USUARIO_NO_ENCONTRADO',
        'CREDENCIALES_INVALIDAS',
        'SIN_PERMISO',
        'NO_AUTORIZADO',
        'USUARIO_EXISTE',
        'CODIGO_REQUERIDO',
        'RDR_NO_ENCONTRADO',
        'ERROR_INTERNO',
        'ERROR_SERVIDOR',
        'RPC_ERROR',
        'METODO_NO_PERMITIDO',
        'INPUT_INVALIDO',
        'JSON_INVALIDO',
      ];
      for (final c in codigos) {
        final m = MensajeError.desdeCodigo(c);
        expect(m, isNot(equals(c)), reason: 'filtró el código $c');
        expect(m, isNot(matches(RegExp(r'[A-Z]{4,}'))),
            reason: 'parece código técnico: $c -> $m');
      }
    });

    test('no distingue usuario inexistente de contraseña incorrecta', () {
      expect(
        MensajeError.desdeCodigo('USUARIO_NO_ENCONTRADO'),
        equals(MensajeError.desdeCodigo('CREDENCIALES_INVALIDAS')),
        reason: 'permite enumerar qué correos existen',
      );
    });

    test('sin coneccion no menciona backend ni red', () {
      final m = MensajeError.desdeCodigo('SIN_CONEXION');
      expect(m.toLowerCase(), isNot(contains('backend')));
      expect(m.toLowerCase(), isNot(contains('servidor')));
    });

    test('null o vacio cae en el generico', () {
      expect(MensajeError.desdeCodigo(null), isNotEmpty);
      expect(MensajeError.desdeCodigo('   '), isNotEmpty);
    });
  });

  group('MensajeError.desdeExcepcion', () {
    test('nunca filtra URLs', () {
      final casos = [
        Exception(
            'DioException [connection error]: Request: POST https://portal.luvegi.com/api_luvegi/login.php'),
        'Failed host lookup: portal.luvegi.com',
        Exception('SocketException: Connection failed (OS Error: Connection refused)'),
      ];
      for (final e in casos) {
        final m = MensajeError.desdeExcepcion(e);
        expect(m, isNot(contains('http')),
            reason: 'filtró URL: $m');
        expect(m, isNot(matches(RegExp(r'luvegi|portal'))),
            reason: 'filtró dominio: $m');
        expect(m, isNot(contains('Exception')),
            reason: 'filtró tipo de excepción: $m');
      }
    });

    test('nunca filtra SQL ni host de base de datos', () {
      final m = MensajeError.desdeExcepcion(
        Exception('SQLSTATE[HY000] [2002] Connection refused for 10.0.0.5'),
      );
      expect(m, isNot(contains('SQLSTATE')));
      expect(m, isNot(contains('10.0.0.5')));
      expect(m, isNot(matches(RegExp(r'\d+\.\d+\.\d+\.\d+'))));
    });

    test('extrae el codigo cuando viene envuelto en Exception:', () {
      expect(
        MensajeError.desdeExcepcion(Exception('Exception: TOKEN_INVALIDO')),
        equals(MensajeError.desdeCodigo('TOKEN_INVALIDO')),
      );
    });

    test('null cae en el generico', () {
      expect(MensajeError.desdeExcepcion(null), isNotEmpty);
    });
  });

  group('MensajeError.esCodigoDeSesion', () {
    test('detecta los codigos de sesion', () {
      expect(MensajeError.esCodigoDeSesion('TOKEN_INVALIDO'), isTrue);
      expect(MensajeError.esCodigoDeSesion('NO_TOKEN'), isTrue);
      expect(MensajeError.esCodigoDeSesion('SESION_INVALIDA'), isTrue);
      expect(MensajeError.esCodigoDeSesion('USUARIO_EXISTE'), isFalse);
      expect(MensajeError.esCodigoDeSesion(null), isFalse);
    });
  });

  group('MensajeError codigos de encuestas', () {
    const codigos = [
      'YA_HAY_ENCUESTA_ABIERTA',
      'ENCUESTA_NO_ENCONTRADA',
      'ENCUESTA_INCOMPLETA',
      'ENCUESTA_NO_ELIMINABLE',
      'ENCUESTA_NO_ABIERTA',
      'RESULTADOS_NO_DISPONIBLES',
      'PREGUNTA_INVALIDA',
      'OPCION_INVALIDA',
      'RESPUESTAS_INVALIDAS',
      'VOTACION_NO_INICIADA',
      'VOTACION_CERRADA',
      'YA_RESPONDIO',
      'TABLA_NO_EXISTE',
    ];

    test('mapea los errores del modulo a un mensaje entendible', () {
      for (final c in codigos) {
        final m = MensajeError.desdeCodigo(c);
        expect(m, isNot(equals(c)), reason: 'filtró el código $c');
        expect(m, isNot(matches(RegExp(r'[A-Z]{4,}'))),
            reason: 'parece código técnico: $c -> $m');
        expect(m, isNot(equals(MensajeError.mensajeGenerico)),
            reason: 'cayó en el genérico: $c');
      }
    });

    test('SIN_PERMISO con sufijo sigue siendo falta de permisos', () {
      expect(
        MensajeError.desdeCodigo('SIN_PERMISO_VOTAR_ELECCIONES'),
        equals(MensajeError.desdeCodigo('SIN_PERMISO')),
      );
    });

    test('usa el codigo de la excepcion cuando el mensaje es largo', () {
      final e = _ErrorFalso('Error: ENCUESTA_NO_ENCONTRADA', 'ENCUESTA_NO_ENCONTRADA');
      expect(
        MensajeError.desdeExcepcion(e),
        equals(MensajeError.desdeCodigo('ENCUESTA_NO_ENCONTRADA')),
      );
    });

    test('si el codigo es desconocido devuelve el mensaje del servidor', () {
      final e = _ErrorFalso('La encuesta ya fue eliminada.', 'CODIGO_NUEVO_XYZ');
      expect(MensajeError.desdeExcepcion(e), contains('eliminada'));
    });
  });
}

class _ErrorFalso implements Exception, ErrorConCodigo {
  final String mensaje;
  @override
  final String? codigo;

  _ErrorFalso(this.mensaje, this.codigo);

  @override
  String toString() => mensaje;
}