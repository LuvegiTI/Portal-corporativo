import 'dart:async';

import 'package:http/http.dart' as http;

const String _apiBase = 'https://portal.luvegi.com/api_luvegi/';

class TarjetaTracking {
  TarjetaTracking._();

  static const Duration _timeout = Duration(seconds: 10);

  static void visita(String? codigo) {
    unawaited(_ping('registrar_visita.php', {'e': codigo}));
  }

  static void clicWhatsapp(String? codigo, String numero, String mensaje) {
    unawaited(
      _ping('ir_wsp.php', {'e': codigo, 'w': numero, 'msg': mensaje}),
    );
  }

  static Future<void> _ping(String ruta, Map<String, String?> parametros) async {
    final limpios = <String, String>{};

    for (final entrada in parametros.entries) {
      final valor = entrada.value?.trim();
      if (valor != null && valor.isNotEmpty) limpios[entrada.key] = valor;
    }

    try {
      final uri =
          Uri.parse('$_apiBase$ruta').replace(queryParameters: limpios);
      await http.get(uri).timeout(_timeout);
    } catch (_) {
      // El conteo nunca debe bloquear ni romper la tarjeta.
    }
  }
}
