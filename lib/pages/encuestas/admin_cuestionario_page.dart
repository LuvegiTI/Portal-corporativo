import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/encuesta_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/dialog_controllers.dart';
import '../../utils/mensaje_error.dart';

class AdminCuestionarioPage extends StatefulWidget {
  final String token;
  final Encuesta encuesta;
  final EncuestaService service;

  const AdminCuestionarioPage({
    super.key,
    required this.token,
    required this.encuesta,
    required this.service,
  });

  @override
  State<AdminCuestionarioPage> createState() => _AdminCuestionarioPageState();
}

class _AdminCuestionarioPageState extends State<AdminCuestionarioPage> {
  bool _cargando = true;
  String? _error;
  String _estado = 'BORRADOR';
  List<EncuestaPregunta> _preguntas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
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
      final raw = data['encuesta'];
      if (raw is! Map) throw const EncuestaApiException('Detalle inválido.');
      final map = Map<String, dynamic>.from(raw);
      final rawPreguntas = map['preguntas'] as List<dynamic>? ?? const [];
      final rawOpciones = map['opciones'] as List<dynamic>? ?? const [];
      final opciones = rawOpciones
          .whereType()
          .map((e) => EncuestaOpcion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final preguntas = rawPreguntas.whereType().map((e) {
        final pregunta = Map<String, dynamic>.from(e);
        final preguntaId = pregunta['id'] is num
            ? (pregunta['id'] as num).toInt()
            : int.tryParse('${pregunta['id']}') ?? 0;
        pregunta['opciones'] = opciones
            .where((opcion) => opcion.preguntaId == preguntaId)
            .map(
              (opcion) => {
                'id': opcion.id,
                'pregunta_id': opcion.preguntaId,
                'nombre': opcion.nombre,
                'area': opcion.area,
                'propuesta': opcion.propuesta,
                'foto_url': opcion.fotoUrl,
                'orden': opcion.orden,
                'activo': opcion.activo ? 1 : 0,
                'usuario_id': opcion.usuarioId,
                'estado': opcion.estado,
                'motivo_rechazo': opcion.motivoRechazo,
                'es_mia': opcion.esMia,
                'es_requisito': opcion.esRequisito,
                'dni': opcion.dni,
              },
            )
            .toList();
        return EncuestaPregunta.fromJson(pregunta);
      }).toList();
      if (!mounted) return;
      setState(() {
        _estado = (map['estado'] ?? 'BORRADOR').toString().toUpperCase();
        _preguntas = preguntas;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
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

  Future<void> _guardarPregunta({EncuestaPregunta? pregunta}) async {
    final nombreCtrl = TextEditingController(text: pregunta?.nombre ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogControllers(
        controllers: [nombreCtrl],
        builder: (ctx, _) => AlertDialog(
          title: Text(pregunta == null ? 'Nueva pregunta' : 'Editar pregunta'),
          content: SizedBox(
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
                    decoration: const InputDecoration(
                      labelText: 'Pregunta *',
                      hintText: 'Ej. ¿Qué propuesta prefieres?',
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
    if (ok != true || !mounted) return;
    if (nombre.isEmpty) {
      _aviso('El texto de la pregunta es obligatorio.', error: true);
      return;
    }
    try {
      await widget.service.guardarPregunta(
        token: widget.token,
        encuestaId: widget.encuesta.id,
        id: pregunta?.id,
        nombre: nombre,
        orden: pregunta?.orden ?? _preguntas.length,
      );
      await _cargar();
    } catch (e) {
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  Future<void> _eliminarPregunta(EncuestaPregunta pregunta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pregunta'),
        content: const Text(
          'Se eliminarán también las respuestas vinculadas a esta pregunta.',
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogControllers(
        controllers: [nombreCtrl],
        builder: (ctx, _) => AlertDialog(
          title: Text(opcion == null ? 'Nueva respuesta' : 'Editar respuesta'),
          content: SizedBox(
            width: (MediaQuery.sizeOf(ctx).width - 80).clamp(240.0, 400.0),
            child: TextField(
              controller: nombreCtrl,
              autofocus: true,
              maxLines: 1,
              minLines: 1,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              decoration: const InputDecoration(
                labelText: 'Respuesta *',
                hintText: 'Ej. Sí',
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
    if (ok != true || !mounted) return;
    if (nombre.isEmpty) {
      _aviso('El texto de la respuesta es obligatorio.', error: true);
      return;
    }
    try {
      await widget.service.guardarOpcion(
        token: widget.token,
        encuestaId: widget.encuesta.id,
        preguntaId: pregunta.id,
        id: opcion?.id,
        nombre: nombre,
        orden: opcion?.orden ?? pregunta.opciones.length,
        activo: opcion?.activo ?? true,
        usuarioId: null,
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

  Future<void> _abrirOCerrar() async {
    final abrir = _estado != 'ABIERTA';
    if (!abrir) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cerrar encuesta'),
          content: const Text('Nadie podrá responderlo después de cerrarlo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      if (abrir) {
        await widget.service.abrir(token: widget.token, id: widget.encuesta.id);
      } else {
        await widget.service.cerrar(
          token: widget.token,
          id: widget.encuesta.id,
        );
      }
      await _cargar();
      _aviso(abrir ? 'Encuesta abierta.' : 'Encuesta cerrada.');
    } catch (e) {
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalOpciones = _preguntas.fold<int>(
      0,
      (total, pregunta) => total + pregunta.opciones.length,
    );

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        backgroundColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        title: Text(
          'Encuesta · ${widget.encuesta.titulo}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(LuvegiSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_error!, style: LuvegiText.body),
                            const SizedBox(height: LuvegiSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: _cargar,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.quiz_outlined,
                                color: LuvegiColors.primary,
                              ),
                              const SizedBox(width: LuvegiSpacing.sm),
                              Text(
                                _estado,
                                style: LuvegiText.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: LuvegiColors.primary,
                                ),
                              ),
                            ],
                          ),
                          if (widget.encuesta.descripcion.isNotEmpty) ...[
                            const SizedBox(height: LuvegiSpacing.sm),
                            Text(
                              widget.encuesta.descripcion,
                              style: LuvegiText.bodySecondary,
                            ),
                          ],
                          const SizedBox(height: LuvegiSpacing.md),
                          Wrap(
                            spacing: LuvegiSpacing.lg,
                            runSpacing: LuvegiSpacing.sm,
                            children: [
                              Text(
                                '${_preguntas.length} preguntas',
                                style: LuvegiText.caption,
                              ),
                              Text(
                                '$totalOpciones respuestas',
                                style: LuvegiText.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    Wrap(
                      spacing: LuvegiSpacing.sm,
                      runSpacing: LuvegiSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _guardarPregunta(),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Agregar pregunta'),
                        ),
                        if (_estado != 'CERRADA')
                          OutlinedButton.icon(
                            onPressed: _abrirOCerrar,
                            icon: Icon(
                              _estado == 'ABIERTA'
                                  ? Icons.lock_outline
                                  : Icons.play_arrow,
                              size: 18,
                            ),
                            label: Text(
                              _estado == 'ABIERTA'
                                  ? 'Cerrar encuesta'
                                  : 'Abrir encuesta',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: LuvegiSpacing.lg),
                    if (_preguntas.isEmpty)
                      _card(
                        child: Text(
                          'Agrega al menos una pregunta y una respuesta antes '
                          'de abrir la encuesta.',
                          style: LuvegiText.bodySecondary,
                        ),
                      )
                    else
                      ..._preguntas.map(_buildPregunta),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
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
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar pregunta',
                onPressed: () => _guardarPregunta(pregunta: pregunta),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Eliminar pregunta',
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
            Text('Sin respuestas registradas.', style: LuvegiText.caption)
          else
            ...pregunta.opciones.map(
              (opcion) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: LuvegiColors.primary.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.format_list_bulleted,
                    color: LuvegiColors.primary,
                  ),
                ),
                title: Text(
                  opcion.nombre,
                  style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar respuesta',
                      onPressed: () => _guardarOpcion(pregunta, opcion: opcion),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Eliminar respuesta',
                      onPressed: () => _eliminarOpcion(opcion),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: LuvegiColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: LuvegiSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _guardarOpcion(pregunta),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Agregar respuesta'),
          ),
        ],
      ),
    );
  }
}
