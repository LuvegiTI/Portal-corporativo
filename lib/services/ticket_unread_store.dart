import 'package:shared_preferences/shared_preferences.dart';

/// Guarda en el dispositivo el id del último mensaje de chat visto por ticket.
/// Sirve para marcar en la lista los tickets con respuestas nuevas sin abrir.
class TicketUnreadStore {
  TicketUnreadStore._();

  static const String _prefijo = 'ticket_last_seen_';

  static String _clave(String codigo) => '$_prefijo$codigo';

  /// Id del último mensaje visto para un ticket (0 si nunca se abrió).
  static Future<int> ultimoVisto(String codigo) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_clave(codigo)) ?? 0;
  }

  /// Mapa codigo -> último id visto, para toda la lista.
  static Future<Map<String, int>> ultimosVistos() async {
    final prefs = await SharedPreferences.getInstance();
    final resultado = <String, int>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefijo)) continue;
      resultado[key.substring(_prefijo.length)] = prefs.getInt(key) ?? 0;
    }
    return resultado;
  }

  /// Marca como visto hasta [mensajeId] (solo avanza, nunca retrocede).
  static Future<void> marcarVisto(String codigo, int mensajeId) async {
    if (codigo.isEmpty || mensajeId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final actual = prefs.getInt(_clave(codigo)) ?? 0;
    if (mensajeId > actual) {
      await prefs.setInt(_clave(codigo), mensajeId);
    }
  }
}
