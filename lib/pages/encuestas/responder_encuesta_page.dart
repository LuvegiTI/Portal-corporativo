import 'package:flutter/material.dart';

import '../../services/encuesta_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/mensaje_error.dart';

class ResponderEncuestaPage extends StatefulWidget {
  final String token;

  const ResponderEncuestaPage({super.key, required this.token});

  @override
  State<ResponderEncuestaPage> createState() => _ResponderEncuestaPageState();
}

class _ResponderEncuestaPageState extends State<ResponderEncuestaPage> {
  static const int _abstencion = 0;

  final EncuestaService _service = EncuestaService();

  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  /// Encuestas abiertas. Puede haber varias a la vez y se vota en cada una.
  List<EncuestaVotable> _encuestas = [];

  /// encuestaId -> (preguntaId -> opcionId)
  final Map<int, Map<int, int>> _seleccion = {};

  /// Encuesta que se esta envoyendo en este momento.
  int? _enviandoEncuestaId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _service.obtenerEncuestasAbiertas(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _encuestas = lista;
        _seleccion.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Map<int, int> _seleccionDe(int encuestaId) =>
      _seleccion.putIfAbsent(encuestaId, () => <int, int>{});

  bool _todasRespondidas(EncuestaVotable e) {
    final sel = _seleccionDe(e.encuesta.id);
    return e.preguntas.isNotEmpty &&
        e.preguntas.every((p) => sel.containsKey(p.id));
  }

  Future<void> _confirmarRespuesta(EncuestaVotable e) async {
    if (!_todasRespondidas(e)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una opción en cada pregunta antes de enviar.'),
        ),
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar envío'),
        content: const Text(
          'Tu respuesta es definitiva y no podrá modificarse. '
          'El contenido de tu respuesta permanecerá anónimo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() {
      _enviando = true;
      _enviandoEncuestaId = e.encuesta.id;
    });

    final sel = _seleccionDe(e.encuesta.id);
    try {
      final respuestas = e.preguntas
          .map(
            (p) => <String, dynamic>{
              'pregunta_id': p.id,
              'opcion_id': sel[p.id] == _abstencion ? null : sel[p.id],
            },
          )
          .toList();

      final res = await _service.responder(
        token: widget.token,
        encuestaId: e.encuesta.id,
        respuestas: respuestas,
      );
      if (!mounted) return;

      await _cargar();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['recibo']?.toString() != null
                ? 'Respuesta registrada. Comprobante: ${res['recibo']}'
                : 'Tu respuesta fue registrada correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajeError.desdeExcepcion(e)),
          backgroundColor: LuvegiColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
          _enviandoEncuestaId = null;
        });
      }
    }
  }

  String _fecha(DateTime? fecha) {
    if (fecha == null) return '—';
    final local = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${dos(local.month)}-${dos(local.day)} '
        '${dos(local.hour)}:${dos(local.minute)}';
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
            constraints: const BoxConstraints(maxWidth: 900),
            child: _buildContenido(),
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 120),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _card(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: LuvegiColors.error, size: 42),
            const SizedBox(height: LuvegiSpacing.md),
            Text(_error!, textAlign: TextAlign.center, style: LuvegiText.body),
            const SizedBox(height: LuvegiSpacing.md),
            OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_encuestas.isEmpty) {
      return _card(
        child: Column(
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 48,
              color: LuvegiColors.textHint,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Text('No hay ninguna encuesta activa.', style: LuvegiText.title),
            const SizedBox(height: LuvegiSpacing.xs),
            Text(
              'Cuando RRHH abra una encuesta aparecerá aquí para responder.',
              textAlign: TextAlign.center,
              style: LuvegiText.bodySecondary,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_encuestas.length > 1) ...[
          Text(
            'Encuestas disponibles',
            style: LuvegiText.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: LuvegiSpacing.xs),
          Text(
            'Tienes ${_encuestas.length} encuestas abiertas. Puedes responder en todas.',
            style: LuvegiText.bodySecondary,
          ),
          const SizedBox(height: LuvegiSpacing.lg),
        ],
        ..._encuestas.map(_buildEncuesta),
      ],
    );
  }

  Widget _buildEncuesta(EncuestaVotable e) {
    final sel = _seleccionDe(e.encuesta.id);
    final enviandoEsta = _enviando && _enviandoEncuestaId == e.encuesta.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.assignment_outlined,
                      color: LuvegiColors.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.encuesta.titulo, style: LuvegiText.title),
                    ),
                  ],
                ),
                if (e.encuesta.descripcion.isNotEmpty) ...[
                  const SizedBox(height: LuvegiSpacing.sm),
                  Text(e.encuesta.descripcion, style: LuvegiText.bodySecondary),
                ],
                const SizedBox(height: LuvegiSpacing.sm),
                Text(
                  'Encuesta abierta'
                  '${e.encuesta.fechaFin != null ? ' · cierra ${e.encuesta.fechaFin}' : ''}',
                  style: LuvegiText.caption,
                ),
                if (e.restringida) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: LuvegiColors.secondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Solo el personal habilitado puede votar',
                        style: LuvegiText.caption.copyWith(
                          color: LuvegiColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: LuvegiSpacing.lg),
          if (e.yaRespondio)
            _buildGracias(e)
          else if (!e.puedeResponder)
            _aviso(
              e.restringida
                  ? 'No estás habilitado para votar en esta encuesta.'
                  : 'No tienes permiso para participar en esta encuesta.',
            )
          else if (!e.dentroDeVentana)
            _aviso('La encuesta no está dentro del periodo habilitado.')
          else ...[
            ...e.preguntas.map((p) => _buildPregunta(e, p, sel)),
            const SizedBox(height: LuvegiSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_enviando || !_todasRespondidas(e))
                    ? null
                    : () => _confirmarRespuesta(e),
                icon: enviandoEsta
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  enviandoEsta ? 'Enviando...' : 'Enviar respuesta',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LuvegiColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: LuvegiSpacing.sm),
            Text(
              'Tu respuesta es secreta: RRHH solo verá que participaste, nunca tu selección.',
              style: LuvegiText.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGracias(EncuestaVotable e) {
    return _card(
      child: Column(
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 52,
            color: LuvegiColors.success,
          ),
          const SizedBox(height: LuvegiSpacing.md),
          Text('¡Gracias por participar!', style: LuvegiText.title),
          const SizedBox(height: LuvegiSpacing.xs),
          Text(
            'Tu respuesta quedó registrada de forma anónima.',
            textAlign: TextAlign.center,
            style: LuvegiText.bodySecondary,
          ),
          if (e.recibo != null && e.recibo!.isNotEmpty) ...[
            const SizedBox(height: LuvegiSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: LuvegiColors.surfaceHover,
                borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                border: Border.all(color: LuvegiColors.border),
              ),
              child: Text(
                'Comprobante: ${e.recibo}',
                style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (e.fechaRespuesta != null && e.fechaRespuesta!.isNotEmpty) ...[
            const SizedBox(height: LuvegiSpacing.xs),
            Text(
              'Registrado el ${_fecha(DateTime.tryParse(e.fechaRespuesta!))}',
              style: LuvegiText.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPregunta(
    EncuestaVotable e,
    EncuestaPregunta pregunta,
    Map<int, int> sel,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.lg),
      child: _card(
        child: RadioGroup<int>(
          groupValue: sel[pregunta.id],
          onChanged: (v) => setState(
            () => _seleccionDe(e.encuesta.id)[pregunta.id] = v ?? _abstencion,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pregunta.nombre,
                style: LuvegiText.title.copyWith(fontSize: 16),
              ),
              if (pregunta.descripcion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(pregunta.descripcion, style: LuvegiText.bodySecondary),
              ],
              const SizedBox(height: LuvegiSpacing.md),
              if (pregunta.opciones.isEmpty)
                Text(
                  'Sin opciones registradas para esta pregunta.',
                  style: LuvegiText.caption,
                )
              else
                ...pregunta.opciones.map(
                  (c) => _buildOpcion(e, pregunta, c, sel),
                ),
              RadioListTile<int>(
                value: _abstencion,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Abstenerse / Sin respuesta',
                  style: LuvegiText.body.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              const Divider(height: 20),
              _buildBotonPostularme(e, pregunta),
            ],
          ),
        ),
      ),
    );
  }

  /// Boton para postularse como candidato de esta pregunta (o para retirar
  /// la postulacion si ya se postulo).
  Widget _buildBotonPostularme(EncuestaVotable e, EncuestaPregunta pregunta) {
    final miOpcion = e.misPostulaciones[pregunta.id];

    if (miOpcion != null) {
      return Row(
        children: [
          const Icon(
            Icons.how_to_reg,
            size: 16,
            color: LuvegiColors.success,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Te postulaste como candidato',
              style: LuvegiText.caption.copyWith(
                color: LuvegiColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _enviando
                ? null
                : () => _retirarPostulacion(e, miOpcion),
            style: TextButton.styleFrom(
              foregroundColor: LuvegiColors.textSecondary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Retirar'),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _enviando || !e.puedeResponder
            ? null
            : () => _postularse(e, pregunta),
        icon: const Icon(Icons.how_to_reg_outlined, size: 18),
        label: const Text('Postularme como candidato'),
        style: OutlinedButton.styleFrom(
          foregroundColor: LuvegiColors.secondary,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Dialogo para escribir la propuesta yifficulty la postulacion.
  Future<void> _postularse(EncuestaVotable e, EncuestaPregunta pregunta) async {
    final ctrl = TextEditingController();

    final propuesta = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Postularme'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Te anotaremos como candidato en: "${pregunta.nombre}". '
                'Tus datos (nombre, area y foto) se toman de tu perfil.',
                style: LuvegiText.caption,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Tu propuesta (opcional)',
                  hintText: 'Explica brevemente por qué te postulas',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Postularme'),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (propuesta == null || !mounted) return;

    setState(() => _enviando = true);
    try {
      await _service.postular(
        token: widget.token,
        encuestaId: e.encuesta.id,
        preguntaId: pregunta.id,
        propuesta: propuesta,
      );
      if (!mounted) return;
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu postulación quedó registrada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajeError.desdeExcepcion(e)),
          backgroundColor: LuvegiColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _retirarPostulacion(EncuestaVotable e, int opcionId) async {
    setState(() => _enviando = true);
    try {
      await _service.retirarPostulacion(
        token: widget.token,
        opcionId: opcionId,
      );
      if (!mounted) return;
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu postulación se retiró.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajeError.desdeExcepcion(e)),
          backgroundColor: LuvegiColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _buildOpcion(
    EncuestaVotable e,
    EncuestaPregunta pregunta,
    EncuestaOpcion opcion,
    Map<int, int> sel,
  ) {
    final seleccionado = sel[pregunta.id] == opcion.id;

    return Container(
      margin: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
      child: Material(
        color: seleccionado ? LuvegiColors.menuHover : LuvegiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
          side: BorderSide(
            color: seleccionado
                ? LuvegiColors.menuSelected
                : LuvegiColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: RadioListTile<int>(
          value: opcion.id,
          // Nadie puede votarse a si mismo.
          onChanged: opcion.esMia
              ? null
              : (v) => setState(
                    () => sel[pregunta.id] = v ?? _abstencion,
                  ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          secondary: CircleAvatar(
            backgroundColor: LuvegiColors.secondary.withValues(alpha: 0.12),
            child: opcion.fotoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      opcion.fotoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      headers: {
                        'Authorization': 'Bearer ${widget.token}',
                      },
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_outline,
                        color: LuvegiColors.secondary,
                      ),
                    ),
                  )
                : const Icon(Icons.person_outline, color: LuvegiColors.secondary),
          ),
          title: Text(
            opcion.nombre,
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: opcion.area.isNotEmpty || opcion.propuesta.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (opcion.area.isNotEmpty)
                      Text(opcion.area, style: LuvegiText.caption),
                    if (opcion.propuesta.isNotEmpty)
                      Text(
                        opcion.propuesta,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: LuvegiText.caption,
                      ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  /// Encuesta a la que pertenece una pregunta (para leer su seleccion).
  Widget _aviso(String texto) => _card(
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: LuvegiColors.secondary),
        const SizedBox(width: LuvegiSpacing.md),
        Expanded(child: Text(texto, style: LuvegiText.body)),
      ],
    ),
  );

  Widget _card({required Widget child}) => SizedBox(
    width: double.infinity,
    child: Material(
      color: LuvegiColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        side: const BorderSide(color: LuvegiColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LuvegiSpacing.lg),
        child: child,
      ),
    ),
  );
}
