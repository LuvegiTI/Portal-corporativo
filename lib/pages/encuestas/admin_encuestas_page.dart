import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/encuesta_service.dart';
import 'dialogo_requisitos.dart';
import 'selector_votantes.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/dialog_controllers.dart';
import '../../utils/mensaje_error.dart';

class AdminEncuestasPage extends StatefulWidget {
  final String token;

  const AdminEncuestasPage({super.key, required this.token});

  @override
  State<AdminEncuestasPage> createState() => _AdminEncuestasPageState();
}

class _AdminEncuestasPageState extends State<AdminEncuestasPage> {
  final EncuestaService _service = EncuestaService();

  List<Encuesta> _encuestas = [];
  bool _cargando = true;
  String? _error;
  Timer? _temporizador;
  Map<String, dynamic> _servidor = {};

  @override
  void initState() {
    super.initState();
    _cargar();
    // Refresco silencioso: las encuestas programadas se abren solas y
    // RRHH ve el cambio sin recargar la pagina.
    _temporizador = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _cargando) return;
      _cargar(silencioso: true);
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silencioso) _cargando = true;
      _error = null;
    });
    try {
      final lista = await _service.listar(token: widget.token);
      if (!mounted) return;
      // En el refresco periodico solo se repinta si algo cambio: repintar
      // sin cambios rompe los clics que esten en curso.
      if (silencioso && _mismaLista(_encuestas, lista)) return;
      setState(() {
        _encuestas = lista;
        _servidor = _service.ultimoServidor;
      });
    } catch (e) {
      if (mounted) setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted && !silencioso) setState(() => _cargando = false);
    }
  }

  /// Compara dos listados de encuestas por lo que el usuario ve.
  bool _mismaLista(List<Encuesta> a, List<Encuesta> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].estado != b[i].estado) return false;
      if (a[i].tipo != b[i].tipo) return false;
      if (a[i].requisitos != b[i].requisitos) return false;
      if (a[i].preguntas != b[i].preguntas) return false;
      if (a[i].opciones != b[i].opciones) return false;
      if (a[i].participantes != b[i].participantes) return false;
      if (a[i].motivoApertura != b[i].motivoApertura) return false;
      if (a[i].votacionInicio != b[i].votacionInicio) return false;
      if (a[i].votacionFin != b[i].votacionFin) return false;
      if (a[i].inscripcionInicio != b[i].inscripcionInicio) return false;
      if (a[i].inscripcionFin != b[i].inscripcionFin) return false;
    }
    return true;
  }

  Future<void> _nuevaEncuesta() async {
    final resultado = await _editarEncuestaDialog(context);
    if (resultado == null) return;
    try {
      await _service.crear(
        token: widget.token,
        titulo: resultado.titulo,
        descripcion: resultado.descripcion,
        tipo: resultado.tipo,
        fechaInicio: resultado.fechaInicio,
        fechaFin: resultado.fechaFin,
      );
      if (!mounted) return;
      _aviso(
        resultado.tipo == 'POSTULACION'
            ? 'Postulación creada. Registra los requisitos para que el '
                  'personal pueda inscribirse.'
            : 'Encuesta creada. Agrega preguntas, opciones y prográmala.',
      );
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  Future<void> _editar(Encuesta encuesta) async {
    final resultado = await _editarEncuestaDialog(
      context,
      encuesta: encuesta,
      service: _service,
      token: widget.token,
    );
    if (resultado == null) return;
    try {
      await _service.actualizar(
        token: widget.token,
        id: encuesta.id,
        titulo: resultado.titulo,
        descripcion: resultado.descripcion,
        tipo: resultado.tipo,
        fechaInicio: resultado.fechaInicio,
        fechaFin: resultado.fechaFin,
      );
      if (!mounted) return;
      _aviso('Encuesta actualizada.');
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  Future<void> _abrirOCerrar(Encuesta encuesta) async {
    final abrir = encuesta.estado != 'ABIERTA';
    if (!abrir) {
      try {
        await _service.cerrar(token: widget.token, id: encuesta.id);
        _aviso('Encuesta cerrada.');
        await _cargar();
      } catch (e) {
        if (mounted) _aviso(MensajeError.desdeExcepcion(e), error: true);
      }
      return;
    }

    try {
      await _service.abrir(token: widget.token, id: encuesta.id);
      _aviso('Encuesta abierta.');
      await _cargar();
    } catch (e) {
      if (mounted) {
        final msg = MensajeError.desdeExcepcion(e);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Aviso'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _programarEncuesta(Encuesta encuesta) async {
    if (encuesta.cerrada) return;
    final esPostulacion =
        encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0;

    DateTime? insInicio = _parseFecha(encuesta.inscripcionInicio);
    DateTime? insFin = _parseFecha(encuesta.inscripcionFin);
    DateTime? votInicio = _parseFecha(encuesta.votacionInicio);
    DateTime? votFin = _parseFecha(encuesta.votacionFin);
    final ahora = DateTime.now();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            esPostulacion ? 'Programar postulación' : 'Programar encuesta',
          ),
          content: SizedBox(
            // Ancho fijo: el AlertDialog calcula el ancho intrinseco del
            // contenido y un viewport (scroll) no lo soporta.
            width: (MediaQuery.sizeOf(ctx).width - 80).clamp(240.0, 420.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (esPostulacion) ...[
                    Text(
                      'Postulaciones',
                      style: LuvegiText.title.copyWith(fontSize: 15),
                    ),
                    ...[
                      _filaFechaHora(
                        etiqueta: 'Apertura',
                        icono: Icons.event_outlined,
                        valor: insInicio,
                        porDefecto: DateTime(
                          ahora.year,
                          ahora.month,
                          ahora.day,
                        ),
                        onElegir: (v) => setDialogState(() => insInicio = v),
                      ),
                      _filaFechaHora(
                        etiqueta: 'Cierre',
                        icono: Icons.event_busy_outlined,
                        valor: insFin,
                        porDefecto: DateTime(
                          ahora.year,
                          ahora.month,
                          ahora.day,
                          23,
                          59,
                        ),
                        onElegir: (v) => setDialogState(() => insFin = v),
                      ),
                    ],
                  ],
                  if (!esPostulacion) ...[
                    const SizedBox(height: LuvegiSpacing.md),
                    Text(
                      'Votación',
                      style: LuvegiText.title.copyWith(fontSize: 15),
                    ),
                    _filaFechaHora(
                      etiqueta: 'Apertura',
                      icono: Icons.how_to_vote_outlined,
                      valor: votInicio,
                      porDefecto: DateTime(ahora.year, ahora.month, ahora.day),
                      onElegir: (v) => setDialogState(() => votInicio = v),
                    ),
                    _filaFechaHora(
                      etiqueta: 'Cierre',
                      icono: Icons.event_busy_outlined,
                      valor: votFin,
                      porDefecto: DateTime(
                        ahora.year,
                        ahora.month,
                        ahora.day,
                        23,
                        59,
                      ),
                      onElegir: (v) => setDialogState(() => votFin = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'La votación se abrirá y cerrará automáticamente en esas '
                      'fechas.',
                      style: LuvegiText.caption,
                    ),
                  ],
                  if (_servidor.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Las horas son las tuyas (${_desfaseLocal()}); el '
                      'servidor las convierte a su zona '
                      '(${_servidor['zona'] ?? ''} ${_servidor['desfase'] ?? ''}) '
                      'y abre en el momento correcto.',
                      style: LuvegiText.caption,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (resultado != true || !mounted) return;

    final ahoraValidacion = DateTime.now();
    final tieneInscripcion = insInicio != null && insFin != null;
    final tieneVotacion = votInicio != null && votFin != null;

    if (esPostulacion) {
      if (!tieneInscripcion) {
        _aviso(
          'Indica la apertura y el cierre de las postulaciones.',
          error: true,
        );
        return;
      }
      if (insInicio!.isBefore(ahoraValidacion) ||
          insFin!.isBefore(ahoraValidacion)) {
        _aviso(
          'La apertura y el cierre de las postulaciones no pueden ser pasados.',
          error: true,
        );
        return;
      }
      if (!insFin!.isAfter(insInicio!)) {
        _aviso(
          'El cierre de la inscripción debe ser posterior a la apertura.',
          error: true,
        );
        return;
      }
    } else {
      if (!tieneVotacion) {
        _aviso('Indica la apertura y el cierre de la votación.', error: true);
        return;
      }
      if (votInicio!.isBefore(ahoraValidacion) ||
          votFin!.isBefore(ahoraValidacion)) {
        _aviso(
          'La apertura y el cierre de la votación no pueden ser pasados.',
          error: true,
        );
        return;
      }
      if (tieneInscripcion && !insFin!.isAfter(insInicio!)) {
        _aviso(
          'El cierre de la inscripción debe ser posterior a la apertura.',
          error: true,
        );
        return;
      }
      if (tieneVotacion && !votFin!.isAfter(votInicio!)) {
        _aviso(
          'El cierre de la votación debe ser posterior a la apertura.',
          error: true,
        );
        return;
      }
      if (tieneInscripcion && tieneVotacion && !votInicio!.isAfter(insFin!)) {
        _aviso(
          'La votación debe empezar después de que termine la inscripción.',
          error: true,
        );
        return;
      }
    }

    try {
      await _service.actualizar(
        token: widget.token,
        id: encuesta.id,
        titulo: encuesta.titulo,
        descripcion: encuesta.descripcion,
        // Al reprogramar vuelve a borrador: se abre sola al llegar la hora.
        estado: 'BORRADOR',
        tzOffset: _desfaseLocal(esPostulacion ? insInicio : votInicio),
        incluirFechas: true,
        fechaInicio: encuesta.fechaInicio,
        fechaFin: encuesta.fechaFin,
        inscripcionInicio: esPostulacion ? _serializarFecha(insInicio) : null,
        inscripcionFin: esPostulacion ? _serializarFecha(insFin) : null,
        votacionInicio: esPostulacion ? null : _serializarFecha(votInicio),
        votacionFin: esPostulacion ? null : _serializarFecha(votFin),
      );
      _aviso(
        esPostulacion
            ? 'Postulación programada para el '
                  '${_formatearFecha(insInicio!)} (tu hora). Se abrirá '
                  'automáticamente.'
            : 'Encuesta programada para el '
                  '${_formatearFecha(votInicio!)} (tu hora). Se abrirá '
                  'automáticamente.',
      );
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  Widget _filaFechaHora({
    required String etiqueta,
    required IconData icono,
    required DateTime? valor,
    required DateTime porDefecto,
    required ValueChanged<DateTime?> onElegir,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono),
      title: Text(etiqueta),
      subtitle: Text(valor == null ? 'Sin definir' : _formatearFecha(valor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (valor != null)
            IconButton(
              tooltip: 'Quitar fecha',
              onPressed: () => onElegir(null),
              icon: const Icon(Icons.close, size: 18),
            ),
          TextButton(
            onPressed: () async {
              final fecha = await _elegirFechaHora(valor ?? porDefecto);
              if (fecha != null) onElegir(fecha);
            },
            child: const Text('Elegir'),
          ),
        ],
      ),
    );
  }

  DateTime? _parseFecha(String? valor) {
    if (valor == null || valor.trim().isEmpty) return null;
    // El backend devuelve la fecha con su zona; se pasa a la hora local.
    return DateTime.tryParse(valor.replaceFirst(' ', 'T'))?.toLocal();
  }

  /// Desfase del dispositivo (por ejemplo -06:00) para que el servidor
  /// interprete la hora capturada en la zona de la oficina.
  String _desfaseLocal([DateTime? referencia]) {
    final off = (referencia ?? DateTime.now()).timeZoneOffset;
    final signo = off.isNegative ? '-' : '+';
    final h = off.inHours.abs().toString().padLeft(2, '0');
    final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$signo$h:$m';
  }

  /// Hora local del dispositivo (HH:MM:SS).
  String _horaLocal() {
    final n = DateTime.now();
    String dos(int v) => v.toString().padLeft(2, '0');
    return '${dos(n.hour)}:${dos(n.minute)}:${dos(n.second)}';
  }

  String _formatearFecha(DateTime fecha) {
    final local = fecha.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} $h:$min';
  }

  String _fechaLegible(String? valor) {
    final fecha = _parseFecha(valor);
    return fecha == null ? (valor ?? '—') : _formatearFecha(fecha);
  }

  String _serializarFecha(DateTime? fecha) {
    if (fecha == null) return '';
    final local = fecha.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$m-$d $h:$min:00';
  }

  /// Pide fecha y hora. Devuelve null si se cancela cualquiera de las dos.
  Future<DateTime?> _elegirFechaHora(DateTime inicial) async {
    final ahora = DateTime.now();
    final minimo = DateTime(ahora.year, ahora.month, ahora.day);
    final maximo = DateTime(ahora.year + 3, 12, 31);
    final inicialAjustada = inicial.isBefore(minimo)
        ? minimo
        : (inicial.isAfter(maximo) ? maximo : inicial);
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicialAjustada,
      firstDate: minimo,
      lastDate: maximo,
      helpText: 'Selecciona la fecha',
    );
    if (fecha == null || !mounted) return null;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
      helpText: 'Selecciona la hora',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (hora == null) return null;

    return DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
  }

  Future<void> _eliminar(Encuesta encuesta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar encuesta'),
        content: Text(
          '¿Eliminar "${encuesta.titulo}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: LuvegiColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.eliminar(token: widget.token, id: encuesta.id);
      _aviso('Encuesta eliminada.');
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? LuvegiColors.error : LuvegiColors.success,
      ),
    );
  }

  Future<void> _abrirDetalle(Encuesta encuesta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EncuestaDetallePage(
          token: widget.token,
          encuesta: encuesta,
          service: _service,
        ),
      ),
    );
    await _cargar();
  }

  Future<void> _verParticipacion(Encuesta encuesta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ParticipacionPage(
          token: widget.token,
          encuesta: encuesta,
          service: _service,
        ),
      ),
    );
  }

  Future<void> _verResultados(Encuesta encuesta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ResultadosPage(
          token: widget.token,
          encuesta: encuesta,
          service: _service,
        ),
      ),
    );
  }

  Future<void> _verInscritos(Encuesta encuesta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EncuestaDetallePage(
          token: widget.token,
          encuesta: encuesta,
          service: _service,
          soloInscritos: true,
        ),
      ),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return ColoredBox(
      color: LuvegiColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(mobile ? LuvegiSpacing.md : LuvegiSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: LuvegiSpacing.lg),
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _card(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: LuvegiColors.error,
                        ),
                        const SizedBox(width: LuvegiSpacing.md),
                        Expanded(child: Text(_error!, style: LuvegiText.body)),
                        OutlinedButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                else if (_encuestas.isEmpty)
                  _card(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: LuvegiColors.textHint,
                        ),
                        const SizedBox(height: LuvegiSpacing.md),
                        Text(
                          'Aún no hay encuestas registradas.',
                          style: LuvegiText.title,
                        ),
                        const SizedBox(height: LuvegiSpacing.xs),
                        Text(
                          'Crea una encuesta para comenzar.',
                          style: LuvegiText.bodySecondary,
                        ),
                      ],
                    ),
                  )
                else
                  ..._encuestas.map(_buildEncuestaCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final compacto = MediaQuery.sizeOf(context).width < 620;

    final titulo = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Encuestas', style: LuvegiText.title.copyWith(fontSize: 20)),
          Text(
            'Gestiona encuestas de votación y procesos de postulación.',
            style: LuvegiText.bodySecondary,
          ),
          if (_servidor.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Servidor: ${_servidor['ahora'] ?? ''} '
              '(${_servidor['zona'] ?? ''} ${_servidor['desfase'] ?? ''})'
              ' · Tu hora: ${_horaLocal()} (${_desfaseLocal()})',
              style: LuvegiText.caption,
            ),
          ],
        ],
      ),
    );

    final boton = ElevatedButton.icon(
      onPressed: _nuevaEncuesta,
      icon: const Icon(Icons.add),
      label: const Text('Nueva encuesta'),
      style: ElevatedButton.styleFrom(
        backgroundColor: LuvegiColors.secondary,
        foregroundColor: Colors.white,
      ),
    );

    if (compacto) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: LuvegiColors.menuHover,
                  borderRadius: BorderRadius.circular(LuvegiRadius.md),
                ),
                child: const Icon(
                  Icons.assignment,
                  color: LuvegiColors.secondary,
                ),
              ),
              const SizedBox(width: LuvegiSpacing.md),
              titulo,
            ],
          ),
          const SizedBox(height: LuvegiSpacing.md),
          SizedBox(width: double.infinity, child: boton),
        ],
      );
    }

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: LuvegiColors.menuHover,
            borderRadius: BorderRadius.circular(LuvegiRadius.md),
          ),
          child: const Icon(Icons.assignment, color: LuvegiColors.secondary),
        ),
        const SizedBox(width: LuvegiSpacing.md),
        titulo,
        boton,
      ],
    );
  }

  Widget _buildEncuestaCard(Encuesta encuesta) {
    final cerrada = encuesta.cerrada;
    final esPostulacion =
        encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0;
    return Padding(
      // Clave estable: el refresco periodico no debe recrear la tarjeta
      // (se romperian los menus abiertos).
      key: ValueKey('enc-${encuesta.id}'),
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.md),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final titulo = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      encuesta.titulo,
                      style: LuvegiText.title.copyWith(fontSize: 16),
                    ),
                    if (encuesta.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        encuesta.descripcion,
                        style: LuvegiText.bodySecondary,
                      ),
                    ],
                  ],
                );

                final chips = Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(
                      _estadoVisible(encuesta),
                      encuesta.cerrada
                          ? LuvegiColors.secondary
                          : encuesta.estado == 'ABIERTA'
                          ? LuvegiColors.success
                          : LuvegiColors.textSecondary,
                    ),
                    _chip(
                      encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0
                          ? 'Postulación'
                          : 'Encuesta',
                      encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0
                          ? LuvegiColors.warning
                          : LuvegiColors.secondary,
                    ),
                  ],
                );

                // En pantallas estrechas los chips pasan debajo del titulo.
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titulo,
                      const SizedBox(height: LuvegiSpacing.sm),
                      chips,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titulo),
                    const SizedBox(width: LuvegiSpacing.md),
                    chips,
                  ],
                );
              },
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Wrap(
              spacing: LuvegiSpacing.md,
              runSpacing: LuvegiSpacing.sm,
              children: [
                if (!esPostulacion) _dato('Preguntas', '${encuesta.preguntas}'),
                _dato(
                  esPostulacion ? 'Postulantes' : 'Opciones',
                  '${encuesta.opciones}',
                ),
                if (!esPostulacion)
                  _dato('Participantes', '${encuesta.participantes}'),
                if (encuesta.inscripcionInicio != null)
                  _dato(
                    'Abre postulaciones',
                    _fechaLegible(encuesta.inscripcionInicio),
                  ),
                if (encuesta.inscripcionFin != null)
                  _dato(
                    'Cierra postulaciones',
                    _fechaLegible(encuesta.inscripcionFin),
                  ),
                if (!esPostulacion && encuesta.votacionInicio != null)
                  _dato(
                    'Abre votación',
                    _fechaLegible(encuesta.votacionInicio),
                  ),
                if (!esPostulacion && encuesta.votacionFin != null)
                  _dato('Cierra votación', _fechaLegible(encuesta.votacionFin)),
              ],
            ),
            const Divider(height: LuvegiSpacing.xl),
            if (_avisoVotacionBloqueada(encuesta)) ...[
              _avisoVotacion(encuesta),
              const SizedBox(height: LuvegiSpacing.md),
            ],
            if (encuesta.motivoApertura != null &&
                encuesta.motivoApertura!.isNotEmpty &&
                encuesta.estado != 'ABIERTA' &&
                !encuesta.cerrada) ...[
              _avisoMotivo(encuesta),
              const SizedBox(height: LuvegiSpacing.md),
            ],
            if (_sinHabilitados(encuesta)) ...[
              _avisoSinHabilitados(encuesta),
              const SizedBox(height: LuvegiSpacing.md),
            ],
            if (!cerrada) ...[
              _checklistConfiguracion(encuesta),
              const SizedBox(height: LuvegiSpacing.md),
            ],
            Wrap(
              spacing: LuvegiSpacing.sm,
              runSpacing: LuvegiSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _botonPrincipal(encuesta),
                OutlinedButton.icon(
                  onPressed: () => esPostulacion
                      ? _abrirRequisitos(encuesta)
                      : _abrirDetalle(encuesta),
                  icon: Icon(
                    esPostulacion ? Icons.rule : Icons.list_alt,
                    size: 18,
                  ),
                  label: const Text('Configurar'),
                ),
                if (esPostulacion && !cerrada)
                  OutlinedButton.icon(
                    onPressed: () => _verInscritos(encuesta),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Ver inscritos'),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Más acciones',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (accion) => _accionEncuesta(accion, encuesta),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined, size: 18),
                        title: Text('Editar'),
                      ),
                    ),
                    if (!cerrada)
                      const PopupMenuItem(
                        value: 'programar',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.event_outlined, size: 18),
                          title: Text('Programación'),
                        ),
                      ),
                    if (!esPostulacion)
                      const PopupMenuItem(
                        value: 'participacion',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.group_outlined, size: 18),
                          title: Text('Participación'),
                        ),
                      ),
                    // "Abrir postulaciones" solo aparece cuando ya hay
                    // requisitos registrados.
                    if (!cerrada &&
                        encuesta.estado != 'ABIERTA' &&
                        (!esPostulacion || (encuesta.requisitos ?? 0) > 0))
                      PopupMenuItem(
                        value: 'abrir',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.play_arrow, size: 18),
                          title: Text(
                            esPostulacion
                                ? 'Abrir postulaciones'
                                : 'Abrir ahora',
                          ),
                        ),
                      ),
                    if (encuesta.estado == 'BORRADOR')
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: LuvegiColors.error,
                          ),
                          title: Text(
                            'Eliminar',
                            style: TextStyle(color: LuvegiColors.error),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Boton principal: siempre la siguiente accion logica del proceso.
  Widget _botonPrincipal(Encuesta encuesta) {
    final estilo = FilledButton.styleFrom(
      backgroundColor: LuvegiColors.secondary,
      foregroundColor: Colors.white,
    );
    final esPostulacion =
        encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0;

    if (encuesta.cerrada) {
      if (esPostulacion) {
        return FilledButton.icon(
          onPressed: () => _verInscritos(encuesta),
          icon: const Icon(Icons.groups_outlined, size: 18),
          label: const Text('Ver inscritos'),
          style: FilledButton.styleFrom(
            backgroundColor: LuvegiColors.secondary,
            foregroundColor: Colors.white,
          ),
        );
      }
      return FilledButton.icon(
        onPressed: () => _verResultados(encuesta),
        icon: const Icon(Icons.insert_chart_outlined, size: 18),
        label: const Text('Ver resultados'),
        style: FilledButton.styleFrom(
          backgroundColor: LuvegiColors.secondary,
          foregroundColor: Colors.white,
        ),
      );
    }

    if (encuesta.estado == 'ABIERTA') {
      return FilledButton.icon(
        onPressed: () => _abrirOCerrar(encuesta),
        icon: const Icon(Icons.lock_outline, size: 18),
        label: Text(esPostulacion ? 'Cerrar postulaciones' : 'Cerrar votación'),
        style: FilledButton.styleFrom(
          backgroundColor: LuvegiColors.error,
          foregroundColor: Colors.white,
        ),
      );
    }

    // En una postulacion el proceso es: requisitos -> abrir -> el personal
    // se inscribe. No hay fase de validacion.
    if (esPostulacion) {
      if ((encuesta.requisitos ?? 0) <= 0) {
        return FilledButton.icon(
          onPressed: () => _abrirRequisitos(encuesta),
          icon: const Icon(Icons.rule, size: 18),
          label: const Text('Registrar requisitos'),
          style: estilo,
        );
      }
      return FilledButton.icon(
        onPressed: () => _abrirOCerrar(encuesta),
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('Abrir postulaciones'),
        style: estilo,
      );
    }

    return FilledButton.icon(
      onPressed: () => _programarEncuesta(encuesta),
      icon: const Icon(Icons.event_available_outlined, size: 18),
      label: const Text('Programar'),
      style: estilo,
    );
  }

  /// Texto del aviso de apertura, siempre en la hora del usuario.
  Widget _avisoMotivo(Encuesta encuesta) {
    final motivo = encuesta.motivoApertura ?? '';
    final esPostulacion =
        encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0;
    final inicio = esPostulacion
        ? encuesta.inscripcionInicio
        : encuesta.votacionInicio;
    final fin = esPostulacion ? encuesta.inscripcionFin : encuesta.votacionFin;
    final apertura = _fechaLegible(inicio);
    final cierre = _fechaLegible(fin);

    final texto = esPostulacion
        ? switch (motivo) {
            'VENCIDO' =>
              'El plazo de inscripción ya venció (cerraba el $cierre); vuelve '
                  'a programarla.',
            'SIN_FECHA' =>
              'No tiene fecha de apertura programada. Puedes abrirla a mano '
                  'desde el menú ⋯.',
            'CERRADA' => 'La postulación ya está cerrada.',
            _ =>
              'No se abrió automáticamente. Revisa que los requisitos estén '
                  'registrados y la fecha guardada ($apertura), o abre la '
                  'postulación a mano desde el menú ⋯.',
          }
        : switch (motivo) {
            'VENCIDO' =>
              'El plazo de votación ya venció (cerraba el $cierre); vuelve a '
                  'programarla.',
            'SIN_FECHA' => 'No tiene fecha de apertura programada.',
            'CERRADA' => 'La encuesta ya está cerrada.',
            _ =>
              'No se abrió automáticamente. Revisa la fecha guardada '
                  '($apertura) o abre la fase a mano desde el menú ⋯.',
          };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(
          color: LuvegiColors.secondary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: LuvegiColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: LuvegiText.caption)),
        ],
      ),
    );
  }

  /// Sin personal habilitado el servidor no muestra la encuesta a nadie,
  /// asi que tampoco se puede postular.
  /// En una Encuesta sin personal habilitado nadie puede votar. En una
  /// Postulacion puede votar todo el personal, asi que no avisa.
  bool _sinHabilitados(Encuesta encuesta) {
    if (encuesta.cerrada) return false;
    if (encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0) return false;
    if (!encuesta.postulacionesAbiertas) return false;
    final votantes = encuesta.votantes;
    if (votantes == null || votantes > 0) return false;
    return true;
  }

  Widget _avisoSinHabilitados(Encuesta encuesta) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 18,
            color: LuvegiColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nadie está habilitado para votar: hasta que marques “Personal '
              'que puede votar”, el personal no podrá votar en esta encuesta.',
              style: LuvegiText.caption,
            ),
          ),
        ],
      ),
    );
  }

  /// La votacion se abre sola al llegar la hora, siempre que haya
  /// candidatos aprobados. Sin ellos la encuesta espera.
  /// La votacion se abre sola al llegar la hora, siempre que la encuesta
  /// tenga opciones para votar.
  bool _avisoVotacionBloqueada(Encuesta encuesta) {
    if (encuesta.cerrada) return false;
    if (encuesta.estado == 'ABIERTA') return false;

    final inicio = _parseFecha(encuesta.votacionInicio);
    if (inicio == null || DateTime.now().isBefore(inicio)) return false;

    // Sin opciones no hay nada que votar.
    return encuesta.opciones <= 0;
  }

  Widget _avisoVotacion(Encuesta encuesta) {
    const texto =
        'La votación no se abrió automáticamente: la encuesta todavía no '
        'tiene opciones para votar. Agrega al menos una opción o abre la '
        'votación a mano desde el menú ⋯.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_bottom,
            size: 18,
            color: LuvegiColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: LuvegiText.caption)),
        ],
      ),
    );
  }

  /// Pasos pendientes antes de poder abrir la encuesta.
  Widget _checklistConfiguracion(Encuesta encuesta) {
    final esPostulacion =
        encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0;
    final pasos = <(bool, String, VoidCallback)>[
      if (esPostulacion) ...[
        (
          (encuesta.requisitos ?? 0) > 0,
          'Define los requisitos de postulación',
          () => _abrirRequisitos(encuesta),
        ),
        if ((encuesta.requisitos ?? 0) > 0)
          (
            encuesta.estado == 'ABIERTA' || encuesta.programada,
            'Programa o abre la postulación manualmente',
            () => _programarEncuesta(encuesta),
          ),
      ] else ...[
        (
          encuesta.preguntas > 0,
          'Agrega al menos una pregunta',
          () => _abrirDetalle(encuesta),
        ),
        (
          encuesta.opciones > 0,
          'Agrega al menos una opción',
          () => _abrirDetalle(encuesta),
        ),
        if (encuesta.votantes != null)
          (
            encuesta.votantes! > 0,
            'Indica quién puede votar',
            () => _abrirDetalle(encuesta),
          ),
        (
          encuesta.votacionInicio != null && encuesta.votacionFin != null,
          'Programa la apertura y el cierre de la votación',
          () => _programarEncuesta(encuesta),
        ),
      ],
    ];
    final faltantes = pasos.where((p) => !p.$1).toList();
    if (faltantes.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Falta configurar (${faltantes.length})',
            style: LuvegiText.caption.copyWith(
              color: LuvegiColors.warning,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          ...faltantes.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: LuvegiColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.$2, style: LuvegiText.caption)),
                  TextButton(
                    onPressed: p.$3,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: LuvegiColors.secondary,
                    ),
                    child: const Text('Configurar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Estado que ve el usuario: un solo concepto, sin fases sueltas.
  String _estadoVisible(Encuesta encuesta) {
    final esPostulacion =
        encuesta.esPostulacion || (encuesta.requisitos ?? 0) > 0;
    if (encuesta.cerrada) return 'Cerrada';
    if (encuesta.estado == 'ABIERTA') {
      return esPostulacion ? 'Inscripción abierta' : 'En votación';
    }
    if (encuesta.programada) return 'Programada';
    return 'Borrador';
  }

  Future<void> _accionEncuesta(String accion, Encuesta encuesta) async {
    if (accion == 'editar') {
      await _editar(encuesta);
    } else if (accion == 'programar') {
      await _programarEncuesta(encuesta);
    } else if (accion == 'participacion') {
      await _verParticipacion(encuesta);
    } else if (accion == 'abrir') {
      await _abrirOCerrar(encuesta);
    } else if (accion == 'eliminar') {
      await _eliminar(encuesta);
    }
  }

  /// Abre el editor de requisitos de postulacion.
  Future<void> _abrirRequisitos(Encuesta encuesta) async {
    await mostrarDialogoRequisitos(
      context: context,
      service: _service,
      token: widget.token,
      encuestaId: encuesta.id,
    );
    if (!mounted) return;
    await _cargar();
  }

  Widget _chip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: LuvegiText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _dato(String label, String valor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: LuvegiText.caption.copyWith(
          fontSize: 10,
          color: LuvegiColors.textSecondary,
        ),
      ),
      Text(valor, style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700)),
    ],
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(LuvegiSpacing.lg),
    decoration: BoxDecoration(
      color: LuvegiColors.surface,
      borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      border: Border.all(color: LuvegiColors.border),
    ),
    child: child,
  );
}

/// Padding segun el tamano de pantalla (mas compacto en moviles).
double _padding(BuildContext context) {
  final ancho = MediaQuery.sizeOf(context).width;
  if (ancho < 600) return LuvegiSpacing.md;
  if (ancho < 1000) return LuvegiSpacing.lg;
  return LuvegiSpacing.xl;
}

class _EncuestaForm {
  final String titulo;
  final String descripcion;
  final String tipo;
  final String? fechaInicio;
  final String? fechaFin;

  const _EncuestaForm({
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaFin,
  });
}

/// Fila compacta para elegir el personal que puede votar.
Widget _filaVotantes(
  BuildContext context,
  EncuestaService service,
  String token,
  int encuestaId,
) {
  return InkWell(
    onTap: () =>
        _abrirSelectorDesdeFormulario(context, service, token, encuestaId),
    borderRadius: BorderRadius.circular(LuvegiRadius.sm),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LuvegiColors.menuHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.menuSelected),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.how_to_vote_outlined,
            size: 18,
            color: LuvegiColors.secondary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Personal que puede votar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: LuvegiColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}

/// Abre el selector desde el formulario y guarda el resultado.
Future<void> _abrirSelectorDesdeFormulario(
  BuildContext context,
  EncuestaService service,
  String token,
  int encuestaId,
) async {
  final resultado = await mostrarSelectorVotantes(
    context: context,
    service: service,
    token: token,
    encuestaId: encuestaId,
  );
  if (resultado == null) return;

  try {
    await service.guardarVotantes(
      token: token,
      encuestaId: encuestaId,
      usuarioIds: resultado,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado.isEmpty
                ? 'Nadie podrá votar hasta que marques personal habilitado.'
                : '${resultado.length} persona(s) habilitadas para votar.',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajeError.desdeExcepcion(e)),
          backgroundColor: LuvegiColors.error,
        ),
      );
    }
  }
}

Future<_EncuestaForm?> _editarEncuestaDialog(
  BuildContext context, {
  Encuesta? encuesta,
  EncuestaService? service,
  String? token,
}) async {
  final tituloCtrl = TextEditingController(text: encuesta?.titulo ?? '');
  final descCtrl = TextEditingController(text: encuesta?.descripcion ?? '');
  String tipo = encuesta?.tipo ?? 'ENCUESTA';
  final inicioCtrl = TextEditingController(text: encuesta?.fechaInicio ?? '');
  final finCtrl = TextEditingController(text: encuesta?.fechaFin ?? '');

  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => DialogControllers(
      controllers: [tituloCtrl, descCtrl, inicioCtrl, finCtrl],
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(
          encuesta == null
              ? (tipo == 'POSTULACION' ? 'Nueva postulación' : 'Nueva encuesta')
              : (tipo == 'POSTULACION'
                    ? 'Editar postulación'
                    : 'Editar encuesta'),
        ),
        // Mismo formato compacto que el alta de usuario: ancho acotado y
        // scroll, para que el dialogo no crezca con el texto.
        content: SizedBox(
          // Ancho fijo: el AlertDialog calcula el ancho intrinseco del
          // contenido y un viewport (scroll) no lo soporta.
          width: (MediaQuery.sizeOf(ctx).width - 80).clamp(240.0, 400.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: tituloCtrl,
                  autofocus: true,
                  maxLines: 1,
                  minLines: 1,
                  inputFormatters: [LengthLimitingTextInputFormatter(200)],
                  decoration: const InputDecoration(labelText: 'Título *'),
                ),
                const SizedBox(height: LuvegiSpacing.md),
                TextField(
                  controller: descCtrl,
                  minLines: 2,
                  maxLines: 3,
                  inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: LuvegiSpacing.md),
                Text(
                  'Tipo de proceso',
                  style: LuvegiText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: LuvegiSpacing.sm,
                  runSpacing: LuvegiSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Encuesta'),
                      avatar: const Icon(Icons.poll_outlined, size: 18),
                      selected: tipo == 'ENCUESTA',
                      onSelected: (_) =>
                          setDialogState(() => tipo = 'ENCUESTA'),
                    ),
                    ChoiceChip(
                      label: const Text('Postulación'),
                      avatar: const Icon(Icons.how_to_reg_outlined, size: 18),
                      selected: tipo == 'POSTULACION',
                      onSelected: (_) =>
                          setDialogState(() => tipo = 'POSTULACION'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tipo == 'ENCUESTA'
                      ? 'Votación directa: el personal habilitado elige una '
                            'opción en cada pregunta.'
                      : 'El personal se registra marcando los requisitos y su '
                            'postulación queda guardada con su usuario y DNI.',
                  style: LuvegiText.caption,
                ),
                const SizedBox(height: LuvegiSpacing.md),
                const SizedBox(height: LuvegiSpacing.md),
                // Quien puede votar. Solo aplica a las encuestas de votacion
                // directa; en una postulacion se vota despues si corresponde.
                if (tipo == 'ENCUESTA') ...[
                  if (encuesta != null && service != null && token != null)
                    _filaVotantes(context, service, token, encuesta.id)
                  else
                    Row(
                      children: [
                        const Icon(
                          Icons.how_to_vote_outlined,
                          size: 16,
                          color: LuvegiColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Podras elegir quien puede votar al editar la encuesta.',
                            style: LuvegiText.caption,
                          ),
                        ),
                      ],
                    ),
                ],
                // Las fechas de inicio y cierre no se capturan: el periodo se
                // maneja desde el backend. Los controladores se conservan para
                // no borrar las fechas que ya tuviera la encuesta.
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );

  String? normalizar(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  final titulo = tituloCtrl.text.trim();
  final descripcion = descCtrl.text.trim();
  final fechaInicio = normalizar(inicioCtrl);
  final fechaFin = normalizar(finCtrl);

  if (resultado != true) return null;
  if (titulo.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El título de la encuesta es obligatorio.'),
        ),
      );
    }
    return null;
  }

  return _EncuestaForm(
    titulo: titulo,
    descripcion: descripcion,
    tipo: tipo,
    fechaInicio: fechaInicio,
    fechaFin: fechaFin,
  );
}

class _EncuestaDetallePage extends StatefulWidget {
  final String token;
  final Encuesta encuesta;
  final EncuestaService service;

  /// Muestra solo el listado de inscritos (postulaciones), sin los
  /// controles de configuracion.
  final bool soloInscritos;

  const _EncuestaDetallePage({
    required this.token,
    required this.encuesta,
    required this.service,
    this.soloInscritos = false,
  });

  @override
  State<_EncuestaDetallePage> createState() => _EncuestaDetallePageState();
}

class _EncuestaDetallePageState extends State<_EncuestaDetallePage> {
  /// Tipo de flujo guardado en el servidor (ENCUESTA / POSTULACION).
  String _tipo = 'ENCUESTA';

  /// Cuantos requisitos hay registrados.
  int _requisitos = 0;

  /// En una Encuesta (votacion directa) no hay postulaciones ni requisitos.
  /// Si ya hay requisitos cargados, el flujo se trata como postulacion.
  bool get _esPostulacion =>
      widget.soloInscritos || _tipo == 'POSTULACION' || _tieneRequisitos;

  /// Si ya hay requisitos cargados, el flujo es de postulacion aunque el
  /// tipo no se haya cambiado.
  bool get _tieneRequisitos => _requisitos > 0;

  bool _cargando = true;
  bool _cargandoVotantes = false;
  int _votantesSeleccionados = 0;
  bool _votantesRestringida = false;
  String? _error;
  String _estado = 'BORRADOR';
  List<EncuestaPregunta> _preguntas = [];
  List<EncuestaOpcion> _postulaciones = [];
  List<EncuestaUsuario> _usuarios = [];
  bool _cargandoUsuarios = false;
  String? _errorUsuarios;

  /// Pasos del proceso electoral, para saber en que etapa esta la encuesta.
  @override
  void initState() {
    super.initState();
    _tipo = widget.encuesta.tipo;
    _requisitos = widget.encuesta.requisitos ?? 0;
    _cargar();
    if (!_esPostulacion) {
      _cargarUsuarios();
      _cargarVotantes();
    }
  }

  /// Carga quien esta habilitado a votar en esta encuesta.
  Future<void> _cargarVotantes() async {
    try {
      final data = await widget.service.listarVotantes(
        token: widget.token,
        encuestaId: widget.encuesta.id,
      );
      if (!mounted) return;
      setState(() {
        _votantesSeleccionados = (data['seleccionados'] as num?)?.toInt() ?? 0;
        _votantesRestringida = data['restringida'] == true;
      });
    } catch (_) {
      // Si no se puede leer, se asume que nadie esta habilitado.
    }
  }

  /// Abre el selector de personal que puede votar (dialogo compartido con
  /// el formulario de alta de encuesta).
  Future<void> _abrirSelectorVotantes() async {
    final resultado = await mostrarSelectorVotantes(
      context: context,
      service: widget.service,
      token: widget.token,
      encuestaId: widget.encuesta.id,
    );
    if (resultado == null || !mounted) return;

    setState(() => _cargandoVotantes = true);
    try {
      final data = await widget.service.guardarVotantes(
        token: widget.token,
        encuestaId: widget.encuesta.id,
        usuarioIds: resultado,
      );
      if (!mounted) return;
      await _cargarVotantes();
      if (!mounted) return;
      _aviso((data['message'] ?? 'Personal actualizado.').toString());
    } catch (e) {
      if (!mounted) return;
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    } finally {
      if (mounted) setState(() => _cargandoVotantes = false);
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await widget.service.detalle(
        token: widget.token,
        id: widget.encuesta.id,
      );
      if (!mounted) return;
      final postulaciones = _esPostulacion
          ? await widget.service.postulaciones(
              token: widget.token,
              encuestaId: widget.encuesta.id,
            )
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      final raw = data['encuesta'];
      if (raw is! Map) throw const EncuestaApiException('Detalle inválido.');
      final map = Map<String, dynamic>.from(raw);
      final rawPreguntas = map['preguntas'] as List<dynamic>? ?? const [];
      final rawOpciones = map['opciones'] as List<dynamic>? ?? const [];

      final opciones = rawOpciones
          .whereType()
          .map((e) => EncuestaOpcion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final postulacionesList = postulaciones
          .map((p) => EncuestaOpcion.fromJson(p))
          .toList();

      final preguntas = rawPreguntas.whereType().map((e) {
        final p = Map<String, dynamic>.from(e);
        final pid = p['id'] is num
            ? (p['id'] as num).toInt()
            : int.tryParse('${p['id']}') ?? 0;
        p['opciones'] = opciones
            .where((c) => c.preguntaId == pid)
            .map(
              (c) => {
                'id': c.id,
                'pregunta_id': c.preguntaId,
                'nombre': c.nombre,
                'area': c.area,
                'propuesta': c.propuesta,
                'foto_url': c.fotoUrl,
                'orden': c.orden,
                'activo': c.activo ? 1 : 0,
                'usuario_id': c.usuarioId,
                'estado': c.estado,
                'motivo_rechazo': c.motivoRechazo,
                'es_mia': c.esMia,
                'es_requisito': c.esRequisito,
                'dni': c.dni,
              },
            )
            .toList();
        return EncuestaPregunta.fromJson(p);
      }).toList();

      setState(() {
        _estado = (map['estado'] ?? 'BORRADOR').toString().toUpperCase();
        _preguntas = preguntas;
        _postulaciones = postulacionesList;
        // El tipo puede cambiar al registrar requisitos: el servidor lo
        // convierte en postulacion.
        _tipo = (map['tipo'] ?? _tipo).toString().toUpperCase();
      });
    } catch (e) {
      if (mounted) setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Carga el padrón de usuarios de usuarios_app para poder elegirlos como
  /// candidatos. Si falla, el resto del módulo sigue funcionando (el nombre
  /// de la opción se puede escribir a mano).
  Future<void> _cargarUsuarios() async {
    setState(() {
      _cargandoUsuarios = true;
      _errorUsuarios = null;
    });
    try {
      final usuarios = await widget.service.listarUsuarios(token: widget.token);
      if (!mounted) return;
      setState(() => _usuarios = usuarios);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorUsuarios = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargandoUsuarios = false);
    }
  }

  String _iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }

  /// Buscador de usuarios de usuarios_app. Devuelve el usuario elegido.
  Future<EncuestaUsuario?> _seleccionarUsuario() async {
    final filtroCtrl = TextEditingController();

    final resultado = await showDialog<EncuestaUsuario>(
      context: context,
      builder: (dialogContext) => DialogControllers(
        controllers: [filtroCtrl],
        builder: (dialogContext, setDialogState) {
          final q = filtroCtrl.text.trim().toLowerCase();
          final filtrados = q.isEmpty
              ? _usuarios
              : _usuarios.where((u) {
                  return u.nombre.toLowerCase().contains(q) ||
                      u.correo.toLowerCase().contains(q) ||
                      u.area.toLowerCase().contains(q) ||
                      u.areas.toLowerCase().contains(q) ||
                      u.puesto.toLowerCase().contains(q) ||
                      u.rol.toLowerCase().contains(q);
                }).toList();

          return AlertDialog(
            title: const Text('Elegir candidato'),
            content: SizedBox(
              // Ancho fijo: el AlertDialog calcula el ancho intrinseco del
              // contenido y un viewport (scroll) no lo soporta.
              width: (MediaQuery.sizeOf(dialogContext).width - 80).clamp(
                240.0,
                420.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: filtroCtrl,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre, correo o área',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  if (_cargandoUsuarios)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: LuvegiSpacing.xl),
                      child: CircularProgressIndicator(),
                    )
                  else if (_errorUsuarios != null)
                    Text(
                      _errorUsuarios!,
                      textAlign: TextAlign.center,
                      style: LuvegiText.bodySecondary,
                    )
                  else if (_usuarios.isEmpty)
                    Text(
                      'No hay usuarios activos registrados.',
                      style: LuvegiText.bodySecondary,
                    )
                  else if (filtrados.isEmpty)
                    Text('Sin resultados.', style: LuvegiText.bodySecondary)
                  else
                    SizedBox(
                      // La lista se adapta a la altura de la pantalla: en un
                      // movil pequeño el dialogo no se sale de la vista.
                      height: (MediaQuery.of(context).size.height * 0.45).clamp(
                        160.0,
                        320.0,
                      ),
                      child: ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) {
                          final u = filtrados[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: LuvegiColors.secondary
                                  .withValues(alpha: 0.12),
                              child: u.fotoUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        u.fotoUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        headers: {
                                          'Authorization':
                                              'Bearer ${widget.token}',
                                        },
                                        errorBuilder: (_, _, _) => Text(
                                          _iniciales(u.nombre),
                                          style: LuvegiText.caption.copyWith(
                                            color: LuvegiColors.secondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      _iniciales(u.nombre),
                                      style: LuvegiText.caption.copyWith(
                                        color: LuvegiColors.secondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                            title: Text(
                              u.nombre,
                              style: LuvegiText.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              u.puesto.isNotEmpty
                                  ? '${u.detalle} · ${u.puesto}'
                                  : u.detalle,
                              style: LuvegiText.caption,
                            ),
                            onTap: () => Navigator.pop(dialogContext, u),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );

    return resultado;
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? LuvegiColors.error : LuvegiColors.success,
      ),
    );
  }

  Future<void> _guardarPregunta({EncuestaPregunta? pregunta}) async {
    final nombreCtrl = TextEditingController(text: pregunta?.nombre ?? '');
    final descCtrl = TextEditingController(text: pregunta?.descripcion ?? '');
    final etiqueta = _esPostulacion ? 'cargo' : 'pregunta';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogControllers(
        controllers: [nombreCtrl, descCtrl],
        builder: (ctx, _) => AlertDialog(
          title: Text(
            pregunta == null ? 'Nuevo $etiqueta' : 'Editar $etiqueta',
          ),
          // El contenido se acota y hace scroll: el dialogo nunca crece
          // mas alla de la pantalla, por mas texto que se escriba.
          content: SizedBox(
            // Ancho fijo: el AlertDialog calcula el ancho intrinseco del
            // contenido y un viewport (scroll) no lo soporta.
            width: (MediaQuery.sizeOf(ctx).width - 80).clamp(240.0, 400.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    autofocus: true,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: [LengthLimitingTextInputFormatter(150)],
                    decoration: InputDecoration(
                      labelText: _esPostulacion
                          ? 'Nombre del cargo *'
                          : 'Texto de la pregunta *',
                      hintText: _esPostulacion
                          ? 'Ej. Presidente'
                          : 'Ej. ¿Cuál es la mejor propuesta?',
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    minLines: 1,
                    inputFormatters: [LengthLimitingTextInputFormatter(255)],
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Instrucciones',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final nombre = nombreCtrl.text.trim();
    final descripcion = descCtrl.text.trim();
    if (ok != true || !mounted) return;
    if (nombre.isEmpty) {
      _aviso('El nombre del $etiqueta es obligatorio.', error: true);
      return;
    }

    try {
      await widget.service.guardarPregunta(
        token: widget.token,
        encuestaId: widget.encuesta.id,
        id: pregunta?.id,
        nombre: nombre,
        descripcion: descripcion,
        orden: pregunta?.orden ?? _preguntas.length,
      );
      await _cargar();
    } catch (e) {
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  Future<void> _eliminarPregunta(EncuestaPregunta pregunta) async {
    final etiqueta = _esPostulacion ? 'cargo' : 'pregunta';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar $etiqueta'),
        content: Text(
          _esPostulacion
              ? 'Se eliminarán también las postulaciones vinculadas a este cargo.'
              : 'Se eliminarán también las opciones vinculadas a esta pregunta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: LuvegiColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.service.eliminarPregunta(
        token: widget.token,
        id: pregunta.id,
      );
      await _cargar();
    } catch (e) {
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  Future<void> _guardarOpcion(
    EncuestaPregunta pregunta, {
    EncuestaOpcion? opcion,
  }) async {
    final nombreCtrl = TextEditingController(text: opcion?.nombre ?? '');
    final areaCtrl = TextEditingController(text: opcion?.area ?? '');
    final propCtrl = TextEditingController(text: opcion?.propuesta ?? '');
    final fotoCtrl = TextEditingController(text: opcion?.fotoUrl ?? '');
    bool activo = opcion?.activo ?? true;
    int? usuarioId = opcion?.usuarioId;

    // Guarda el ultimo valor que escribimos nosotros en el campo de area.
    // Si el contenido actual coincide con el, el campo fue autocompletado y
    // se puede sobrescribir al cambiar de candidato. Si difiere, el usuario
    // lo edito a mano y se respeta esa edicion.
    final areaPrevia = opcion?.area ?? '';
    String? areaAutofill = (opcion?.usuarioId != null && areaPrevia.isNotEmpty)
        ? areaPrevia
        : null;
    final nombrePrevio = opcion?.nombre ?? '';
    String? nombreAutofill =
        (opcion?.usuarioId != null && nombrePrevio.isNotEmpty)
        ? nombrePrevio
        : null;
    final fotoPrevia = opcion?.fotoUrl ?? '';
    String? fotoAutofill = (opcion?.usuarioId != null && fotoPrevia.isNotEmpty)
        ? fotoPrevia
        : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogControllers(
        controllers: [nombreCtrl, areaCtrl, propCtrl, fotoCtrl],
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(opcion == null ? 'Nueva opción' : 'Editar opción'),
          // Altura acotada + scroll: el dialogo nunca crece mas alla de
          // la pantalla, por mas texto que se escriba.
          content: SizedBox(
            // Ancho fijo: el AlertDialog calcula el ancho intrinseco del
            // contenido y un viewport (scroll) no lo soporta.
            width: (MediaQuery.sizeOf(ctx).width - 80).clamp(240.0, 400.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pregunta: ${pregunta.nombre}',
                    style: LuvegiText.caption,
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final elegido = await _seleccionarUsuario();
                      if (elegido == null) return;
                      if (!ctx.mounted) return;
                      setDialogState(() {
                        usuarioId = elegido.id;
                        nombreCtrl.text = elegido.nombre;
                        nombreAutofill = elegido.nombre;
                        final actual = areaCtrl.text.trim();
                        if (actual.isEmpty || areaAutofill == actual) {
                          areaCtrl.text = elegido.detalle;
                          areaAutofill = elegido.detalle;
                        }
                        if (elegido.fotoUrl.isNotEmpty) {
                          fotoCtrl.text = elegido.fotoUrl;
                          fotoAutofill = elegido.fotoUrl;
                        }
                      });
                    },
                    icon: const Icon(Icons.people_alt_outlined, size: 18),
                    label: Text(
                      usuarioId == null
                          ? 'Elegir de usuarios_app'
                          : 'Cambiar persona',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  if (_esPostulacion && usuarioId != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: LuvegiColors.success,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Vinculado al personal del portal',
                            style: LuvegiText.caption,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setDialogState(() {
                            usuarioId = null;
                            if (nombreAutofill != null &&
                                nombreCtrl.text.trim() == nombreAutofill) {
                              nombreCtrl.clear();
                            }
                            if (areaAutofill != null &&
                                areaCtrl.text.trim() == areaAutofill) {
                              areaCtrl.clear();
                            }
                            if (fotoAutofill != null &&
                                fotoCtrl.text.trim() == fotoAutofill) {
                              fotoCtrl.clear();
                            }
                            nombreAutofill = null;
                            areaAutofill = null;
                            fotoAutofill = null;
                          }),
                          child: const Text('Quitar'),
                        ),
                      ],
                    ),
                  ],
                  // Atajo contextual: quien esta armando el grupo de
                  // candidatos tambien configura aqui quien puede votar.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _abrirSelectorVotantes,
                      icon: const Icon(Icons.how_to_vote_outlined, size: 16),
                      label: Text(
                        _votantesRestringida
                            ? 'Votan $_votantesSeleccionados personas'
                            : 'Nadie puede votar aún: configurar personal',
                        style: LuvegiText.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: LuvegiColors.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  TextField(
                    controller: nombreCtrl,
                    autofocus: true,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: [LengthLimitingTextInputFormatter(200)],
                    decoration: const InputDecoration(
                      labelText: 'Nombre o Texto de opción *',
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  TextField(
                    controller: areaCtrl,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: [LengthLimitingTextInputFormatter(150)],
                    decoration: const InputDecoration(
                      labelText: 'Detalle secundario (Área)',
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  TextField(
                    controller: propCtrl,
                    minLines: 2,
                    maxLines: 3,
                    inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                    decoration: const InputDecoration(
                      labelText: 'Descripción adicional',
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  TextField(
                    controller: fotoCtrl,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: [LengthLimitingTextInputFormatter(500)],
                    decoration: const InputDecoration(
                      labelText: 'URL de imagen de la opción',
                      hintText: 'Opcional',
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.sm),
                  SwitchListTile(
                    value: activo,
                    onChanged: (v) => setDialogState(() => activo = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Opción activa'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final nombre = nombreCtrl.text.trim();
    final area = areaCtrl.text.trim();
    final propuesta = propCtrl.text.trim();
    final fotoUrl = fotoCtrl.text.trim();
    if (ok != true || !mounted) return;
    if (nombre.isEmpty) {
      _aviso('El nombre de la opción es obligatorio.', error: true);
      return;
    }

    try {
      await widget.service.guardarOpcion(
        token: widget.token,
        encuestaId: widget.encuesta.id,
        preguntaId: pregunta.id,
        id: opcion?.id,
        nombre: nombre,
        area: area,
        propuesta: propuesta,
        fotoUrl: fotoUrl,
        orden: opcion?.orden ?? pregunta.opciones.length,
        activo: activo,
        usuarioId: usuarioId,
      );
      await _cargar();
    } catch (e) {
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  Future<void> _eliminarOpcion(EncuestaOpcion opcion) async {
    try {
      await widget.service.eliminarOpcion(token: widget.token, id: opcion.id);
      await _cargar();
    } catch (e) {
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.soloInscritos) {
      return Scaffold(
        backgroundColor: LuvegiColors.background,
        appBar: AppBar(
          backgroundColor: LuvegiColors.surface,
          foregroundColor: LuvegiColors.textPrimary,
          title: Text(
            'Inscritos · ${widget.encuesta.titulo}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(LuvegiSpacing.xl),
                    child: Text(_error!, style: LuvegiText.body),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.all(_padding(context)),
                  children: [_buildPostulaciones()],
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        backgroundColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        title: Text(
          '${_esPostulacion ? 'Postulación' : 'Encuesta'} · ${widget.encuesta.titulo}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(LuvegiSpacing.xl),
                  child: Text(_error!, style: LuvegiText.body),
                ),
              )
            : ListView(
                padding: EdgeInsets.all(_padding(context)),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Estado: $_estado',
                              overflow: TextOverflow.ellipsis,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      const SizedBox(height: LuvegiSpacing.md),
                      // Los botones fluyen a otra linea en pantallas
                      // estrechas en vez de desbordarse.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!_esPostulacion)
                            OutlinedButton.icon(
                              onPressed: _cargandoVotantes
                                  ? null
                                  : _abrirSelectorVotantes,
                              icon: _cargandoVotantes
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.how_to_vote_outlined,
                                      size: 18,
                                    ),
                              label: Text(
                                _votantesRestringida
                                    ? 'Votan $_votantesSeleccionados'
                                    : 'Nadie habilitado',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _votantesRestringida
                                    ? LuvegiColors.secondary
                                    : LuvegiColors.error,
                              ),
                            ),
                          if (!_esPostulacion)
                            ElevatedButton.icon(
                              onPressed: () => _guardarPregunta(),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar pregunta'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LuvegiColors.secondary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: LuvegiSpacing.lg),
                  if (_esPostulacion) ...[
                    _buildPostulaciones(),
                  ] else ...[
                    if (_preguntas.isEmpty)
                      Text(
                        'Aún no hay preguntas. Agrega la primera para cargar opciones.',
                        style: LuvegiText.bodySecondary,
                      ),
                    ..._preguntas.map(_buildPregunta),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildPostulaciones() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.how_to_reg_outlined,
                color: LuvegiColors.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.soloInscritos ? 'Inscritos' : 'Postulaciones',
                  style: LuvegiText.title.copyWith(fontSize: 16),
                ),
              ),
              Text(
                '${_postulaciones.length}',
                style: LuvegiText.body.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.xs),
          Text(
            'El personal se registra desde el menú Postulaciones. Aquí se '
            'guarda su registro con su nombre, área y DNI.',
            style: LuvegiText.bodySecondary,
          ),
          const Divider(height: LuvegiSpacing.lg),
          if (_postulaciones.isEmpty)
            Text(
              'Aún no hay postulaciones registradas.',
              style: LuvegiText.bodySecondary,
            )
          else
            ..._postulaciones.map(_buildPostulacion),
        ],
      ),
    );
  }

  Widget _buildPostulacion(EncuestaOpcion c) {
    return Container(
      margin: const EdgeInsets.only(bottom: LuvegiSpacing.md),
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: LuvegiColors.secondary.withValues(alpha: 0.12),
                child: c.fotoUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          c.fotoUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          headers: {'Authorization': 'Bearer ${widget.token}'},
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_outline,
                            color: LuvegiColors.secondary,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_outline,
                        color: LuvegiColors.secondary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombre,
                      style: LuvegiText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      c.dni.isNotEmpty
                          ? 'DNI: ${c.dni}'
                          : 'DNI: no registrado en su ficha',
                      style: LuvegiText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.dni.isEmpty
                            ? LuvegiColors.warning
                            : LuvegiColors.textPrimary,
                      ),
                    ),
                    if (c.area.isNotEmpty)
                      Text(c.area, style: LuvegiText.caption),
                    Text(
                      'Registro guardado',
                      style: LuvegiText.caption.copyWith(
                        color: LuvegiColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.propuesta.isNotEmpty) ...[
            const SizedBox(height: LuvegiSpacing.sm),
            Text(
              c.propuesta,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: LuvegiText.bodySecondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPregunta(EncuestaPregunta pregunta) {
    return Container(
      margin: const EdgeInsets.only(bottom: LuvegiSpacing.lg),
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pregunta.nombre,
                      style: LuvegiText.title.copyWith(fontSize: 16),
                    ),
                    if (pregunta.descripcion.isNotEmpty)
                      Text(
                        pregunta.descripcion,
                        style: LuvegiText.bodySecondary,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _esPostulacion ? 'Editar cargo' : 'Editar pregunta',
                onPressed: () => _guardarPregunta(pregunta: pregunta),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: _esPostulacion
                    ? 'Eliminar cargo'
                    : 'Eliminar pregunta',
                onPressed: () => _eliminarPregunta(pregunta),
                icon: const Icon(
                  Icons.delete_outline,
                  color: LuvegiColors.error,
                ),
              ),
            ],
          ),
          const Divider(height: LuvegiSpacing.lg),
          if (pregunta.opciones.isEmpty)
            Text(
              _esPostulacion ? 'Sin postulantes.' : 'Sin opciones.',
              style: LuvegiText.caption,
            )
          else
            ...pregunta.opciones.map(
              (c) => Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: LuvegiColors.secondary.withValues(
                      alpha: 0.12,
                    ),
                    child: c.fotoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              c.fotoUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              headers: {
                                'Authorization': 'Bearer ${widget.token}',
                              },
                              errorBuilder: (_, _, _) => Icon(
                                c.usuarioId != null
                                    ? Icons.person
                                    : Icons.format_list_bulleted,
                                color: LuvegiColors.secondary,
                              ),
                            ),
                          )
                        : Icon(
                            c.usuarioId != null
                                ? Icons.person
                                : Icons.format_list_bulleted,
                            color: LuvegiColors.secondary,
                          ),
                  ),
                  title: Text(
                    c.nombre,
                    style: LuvegiText.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.area.isNotEmpty) Text(c.area),
                      if (c.usuarioId != null)
                        Text(
                          'Personal del portal',
                          style: LuvegiText.caption.copyWith(
                            color: LuvegiColors.secondary,
                          ),
                        ),
                      if (!c.activo)
                        Text(
                          'Inactiva',
                          style: LuvegiText.caption.copyWith(
                            color: LuvegiColors.error,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar opción',
                        onPressed: () => _guardarOpcion(pregunta, opcion: c),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Eliminar opción',
                        onPressed: () => _eliminarOpcion(c),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: LuvegiColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: LuvegiSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _guardarOpcion(pregunta),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Agregar opción'),
          ),
        ],
      ),
    );
  }
}

class _ParticipacionPage extends StatefulWidget {
  final String token;
  final Encuesta encuesta;
  final EncuestaService service;

  const _ParticipacionPage({
    required this.token,
    required this.encuesta,
    required this.service,
  });

  @override
  State<_ParticipacionPage> createState() => _ParticipacionPageState();
}

class _ParticipacionPageState extends State<_ParticipacionPage> {
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _participantes = [];
  int _totalParticipantes = 0;
  int _totalElegibles = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await widget.service.participacion(
        token: widget.token,
        id: widget.encuesta.id,
      );
      if (!mounted) return;
      final raw = data['participantes'] != null
          ? List.from(data['participantes'])
          : [];
      setState(() {
        _participantes = raw
            .whereType()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _totalParticipantes =
            (data['total_participantes'] as num?)?.toInt() ?? 0;
        _totalElegibles = (data['total_elegibles'] as num?)?.toInt() ?? 0;
      });
    } catch (e) {
      if (mounted) setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _totalElegibles > 0
        ? (_totalParticipantes / _totalElegibles * 100).toStringAsFixed(1)
        : '0.0';
    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        backgroundColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        title: const Text('Participación'),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: LuvegiText.body))
            : Padding(
                padding: EdgeInsets.all(_padding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.encuesta.titulo,
                      style: LuvegiText.title.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: LuvegiSpacing.sm),
                    Text(
                      '$_totalParticipantes de $_totalElegibles personas han participado ($pct%).',
                      style: LuvegiText.bodySecondary,
                    ),
                    const SizedBox(height: LuvegiSpacing.xs),
                    Text(
                      'Por privacidad solo se muestra QUIÉN participó, nunca sus respuestas.',
                      style: LuvegiText.caption.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: LuvegiSpacing.lg),
                    Expanded(
                      child: _participantes.isEmpty
                          ? Center(
                              child: Text(
                                'Todavía nadie ha participado.',
                                style: LuvegiText.bodySecondary,
                              ),
                            )
                          : ListView.separated(
                              itemCount: _participantes.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final v = _participantes[i];
                                final nombre = (v['nombre'] ?? '').toString();
                                final correo = (v['correo'] ?? '').toString();
                                final rol = (v['rol'] ?? '').toString();
                                final recibo = (v['recibo'] ?? '').toString();
                                final fecha = (v['fecha'] ?? '').toString();
                                return ListTile(
                                  leading: const Icon(
                                    Icons.check_circle_outline,
                                    color: LuvegiColors.success,
                                  ),
                                  title: Text(nombre),
                                  subtitle: Text(
                                    [
                                      if (correo.isNotEmpty) correo,
                                      if (rol.isNotEmpty) rol,
                                      if (fecha.isNotEmpty) fecha,
                                      if (recibo.isNotEmpty)
                                        'Comprobante: $recibo',
                                    ].join(' · '),
                                    style: LuvegiText.caption,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ResultadosPage extends StatefulWidget {
  final String token;
  final Encuesta encuesta;
  final EncuestaService service;

  const _ResultadosPage({
    required this.token,
    required this.encuesta,
    required this.service,
  });

  @override
  State<_ResultadosPage> createState() => _ResultadosPageState();
}

class _ResultadosPageState extends State<_ResultadosPage> {
  bool _cargando = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await widget.service.resultados(
        token: widget.token,
        id: widget.encuesta.id,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preguntas = (_data['preguntas'] as List<dynamic>? ?? const []);
    final totalRespuestas = (_data['total_respuestas'] as num?)?.toInt() ?? 0;
    final participantes = (_data['total_participantes'] as num?)?.toInt() ?? 0;
    final elegibles = (_data['total_elegibles'] as num?)?.toInt() ?? 0;
    final pct = (_data['porcentaje_participacion'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        backgroundColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        title: const Text('Resultados'),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: LuvegiText.body))
            : ListView(
                padding: EdgeInsets.all(_padding(context)),
                children: [
                  Text(
                    widget.encuesta.titulo,
                    style: LuvegiText.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: LuvegiSpacing.sm),
                  Text(
                    '$totalRespuestas respuestas emitidas · $participantes de $elegibles '
                    'participantes (${pct.toStringAsFixed(1)}%)',
                    style: LuvegiText.bodySecondary,
                  ),
                  const SizedBox(height: LuvegiSpacing.lg),
                  ...preguntas.whereType().map(
                    (p) => _buildPregunta(Map<String, dynamic>.from(p)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPregunta(Map<String, dynamic> pregunta) {
    final opciones = (pregunta['opciones'] as List<dynamic>? ?? const []);
    final total = (pregunta['total_respuestas'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: LuvegiSpacing.lg),
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (pregunta['pregunta'] ?? '').toString(),
                  style: LuvegiText.title.copyWith(fontSize: 16),
                ),
              ),
              Text('$total respuestas', style: LuvegiText.caption),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.md),
          ...opciones.whereType().map((c) {
            final m = Map<String, dynamic>.from(c);
            final respuestasCount = (m['respuestas'] as num?)?.toInt() ?? 0;
            final porcentaje = (m['porcentaje'] as num?)?.toDouble() ?? 0;
            final masElegido = m['mas_elegido'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (masElegido)
                        const Icon(
                          Icons.star,
                          color: LuvegiColors.secondary,
                          size: 18,
                        ),
                      if (masElegido) const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (m['nombre'] ?? '').toString(),
                          style: LuvegiText.body.copyWith(
                            fontWeight: masElegido
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '$respuestasCount (${porcentaje.toStringAsFixed(1)}%)',
                        style: LuvegiText.body,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: porcentaje / 100,
                      minHeight: 10,
                      backgroundColor: LuvegiColors.surfaceHover,
                      color: masElegido
                          ? LuvegiColors.secondary
                          : LuvegiColors.textHint,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
