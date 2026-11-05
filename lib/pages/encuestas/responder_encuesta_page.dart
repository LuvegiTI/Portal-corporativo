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

  Encuesta? _encuesta;
  bool _puedeResponder = true;
  bool _dentroDeVentana = true;
  bool _yaRespondio = false;
  String? _recibo;
  String? _fechaRespuesta;

  final Map<int, int> _seleccion = {};

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
      final data = await _service.obtenerEncuestaActual(token: widget.token);
      if (!mounted) return;

      final rawEncuesta = data['encuesta'];
      Encuesta? encuesta;
      List<EncuestaPregunta> preguntas = [];

      if (rawEncuesta is Map) {
        final map = Map<String, dynamic>.from(rawEncuesta);
        final rawPreguntas = map['preguntas'] as List<dynamic>? ?? const [];
        preguntas = rawPreguntas
            .whereType()
            .map((e) => EncuestaPregunta.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        encuesta = Encuesta(
          id: _asInt(map['id']),
          titulo: (map['titulo'] ?? '').toString(),
          descripcion: (map['descripcion'] ?? '').toString(),
          fechaInicio: map['fecha_inicio']?.toString(),
          fechaFin: map['fecha_fin']?.toString(),
          estado: (map['estado'] ?? '').toString(),
          preguntas: preguntas.length,
          opciones: 0,
          participantes: 0,
        );
        _encuestaPreguntas = preguntas;
      }

      setState(() {
        _encuesta = encuesta;
        _puedeResponder = data['puede_responder'] == true;
        _dentroDeVentana = data['dentro_de_ventana'] != false;
        _yaRespondio = data['ya_respondio'] == true;
        _recibo = data['recibo']?.toString();
        _fechaRespuesta = data['fecha_respuesta']?.toString();
        _seleccion.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<EncuestaPregunta> _encuestaPreguntas = [];

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool get _todasRespondidas =>
      _encuestaPreguntas.isNotEmpty &&
      _encuestaPreguntas.every((p) => _seleccion.containsKey(p.id));

  Future<void> _confirmarRespuesta() async {
    if (!_todasRespondidas) {
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

    setState(() => _enviando = true);
    try {
      final respuestas = _encuestaPreguntas
          .map(
            (p) => <String, dynamic>{
              'pregunta_id': p.id,
              'opcion_id': _seleccion[p.id] == _abstencion
                  ? null
                  : _seleccion[p.id],
            },
          )
          .toList();

      final res = await _service.responder(
        token: widget.token,
        encuestaId: _encuesta!.id,
        respuestas: respuestas,
      );
      if (!mounted) return;
      setState(() {
        _yaRespondio = true;
        _recibo = res['recibo']?.toString() ?? _recibo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu respuesta fue registrada correctamente.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajeError.desdeExcepcion(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
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
    if (_encuesta == null) {
      return _card(
        child: Column(
          children: [
            const Icon(
              Icons.how_to_vote_outlined,
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
    if (_yaRespondio) {
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
            if (_recibo != null && _recibo!.isNotEmpty) ...[
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
                  'Comprobante: $_recibo',
                  style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            if (_fechaRespuesta != null && _fechaRespuesta!.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Registrado el ${_fecha(DateTime.tryParse(_fechaRespuesta!))}',
                style: LuvegiText.caption,
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.how_to_vote_outlined,
                    color: LuvegiColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_encuesta!.titulo, style: LuvegiText.title),
                  ),
                ],
              ),
              if (_encuesta!.descripcion.isNotEmpty) ...[
                const SizedBox(height: LuvegiSpacing.sm),
                Text(_encuesta!.descripcion, style: LuvegiText.bodySecondary),
              ],
              const SizedBox(height: LuvegiSpacing.sm),
              Text(
                'Encuesta abierta'
                '${_encuesta!.fechaFin != null ? ' · cierra ${_encuesta!.fechaFin}' : ''}',
                style: LuvegiText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: LuvegiSpacing.lg),
        if (!_puedeResponder)
          _aviso('No tienes permiso para participar en esta encuesta.')
        else if (!_dentroDeVentana)
          _aviso('La encuesta no está dentro del periodo habilitado.')
        else ...[
          ..._encuestaPreguntas.map(_buildPregunta),
          const SizedBox(height: LuvegiSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _confirmarRespuesta,
              icon: _enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_enviando ? 'Enviando...' : 'Enviar respuesta'),
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
    );
  }

  Widget _buildPregunta(EncuestaPregunta pregunta) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.lg),
      child: _card(
        child: RadioGroup<int>(
          groupValue: _seleccion[pregunta.id],
          onChanged: (v) =>
              setState(() => _seleccion[pregunta.id] = v ?? _abstencion),
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
                ...pregunta.opciones.map((c) => _buildOpcion(pregunta, c)),
              RadioListTile<int>(
                value: _abstencion,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Abstenerse / Sin respuesta',
                  style: LuvegiText.body.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpcion(EncuestaPregunta pregunta, EncuestaOpcion opcion) {
    final seleccionado = _seleccion[pregunta.id] == opcion.id;
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
