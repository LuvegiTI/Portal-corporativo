import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/encuesta_service.dart';
import 'selector_votantes.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
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
      final lista = await _service.listar(token: widget.token);
      if (!mounted) return;
      setState(() => _encuestas = lista);
    } catch (e) {
      if (mounted) setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _nuevaEncuesta() async {
    final resultado = await _editarEncuestaDialog(context);
    if (resultado == null) return;
    try {
      await _service.crear(
        token: widget.token,
        titulo: resultado.titulo,
        descripcion: resultado.descripcion,
        fechaInicio: resultado.fechaInicio,
        fechaFin: resultado.fechaFin,
      );
      if (!mounted) return;
      _aviso('Encuesta creada. Ahora agrega preguntas y opciones.');
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
        // Mensaje real del backend (ya no aplica el bloqueo de una sola
        // encuesta abierta).
        final msg = MensajeError.desdeExcepcion(e);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Aviso'),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _eliminar(Encuesta encuesta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar encuesta'),
        content: Text('¿Eliminar "${encuesta.titulo}"? Esta acción no se puede deshacer.'),
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

  Widget _header() => Row(
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
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Encuestas', style: LuvegiText.title.copyWith(fontSize: 20)),
            Text(
              'Gestiona preguntas, opciones, participación y resultados.',
              style: LuvegiText.bodySecondary,
            ),
          ],
        ),
      ),
      ElevatedButton.icon(
        onPressed: _nuevaEncuesta,
        icon: const Icon(Icons.add),
        label: const Text('Nueva encuesta'),
        style: ElevatedButton.styleFrom(
          backgroundColor: LuvegiColors.secondary,
          foregroundColor: Colors.white,
        ),
      ),
    ],
  );

  Widget _buildEncuestaCard(Encuesta encuesta) {
    final cerrada = encuesta.estado == 'CERRADA';
    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.md),
      child: _card(
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
                  ),
                ),
                _estadoChip(encuesta.estado),
              ],
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Wrap(
              spacing: LuvegiSpacing.md,
              runSpacing: LuvegiSpacing.sm,
              children: [
                _dato('Preguntas', '${encuesta.preguntas}'),
                _dato('Opciones', '${encuesta.opciones}'),
                _dato('Participantes', '${encuesta.participantes}'),
                if (encuesta.fechaFin != null)
                  _dato('Cierra', encuesta.fechaFin!),
              ],
            ),
            const Divider(height: LuvegiSpacing.xl),
            Wrap(
              spacing: LuvegiSpacing.sm,
              runSpacing: LuvegiSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _abrirDetalle(encuesta),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Preguntas y opciones'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _verParticipacion(encuesta),
                  icon: const Icon(Icons.group_outlined, size: 18),
                  label: const Text('Participación'),
                ),
                OutlinedButton.icon(
                  onPressed: cerrada ? () => _verResultados(encuesta) : null,
                  icon: const Icon(Icons.insert_chart_outlined, size: 18),
                  label: const Text('Resultados'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editar(encuesta),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                FilledButton.icon(
                  onPressed: cerrada ? null : () => _abrirOCerrar(encuesta),
                  icon: Icon(
                    encuesta.estado == 'ABIERTA'
                        ? Icons.lock_outline
                        : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    encuesta.estado == 'ABIERTA'
                        ? 'Cerrar encuesta'
                        : 'Abrir encuesta',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: encuesta.estado == 'ABIERTA'
                        ? LuvegiColors.error
                        : LuvegiColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (encuesta.estado == 'BORRADOR')
                  TextButton.icon(
                    onPressed: () => _eliminar(encuesta),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(
                      foregroundColor: LuvegiColors.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoChip(String estado) {
    final color = switch (estado) {
      'ABIERTA' => LuvegiColors.success,
      'CERRADA' => LuvegiColors.secondary,
      _ => LuvegiColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado,
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
      Text(
        valor,
        style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
      ),
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

class _EncuestaForm {
  final String titulo;
  final String descripcion;
  final String? fechaInicio;
  final String? fechaFin;

  const _EncuestaForm({
    required this.titulo,
    required this.descripcion,
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
    onTap: () => _abrirSelectorDesdeFormulario(context, service, token, encuestaId),
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
                ? 'Encuesta abierta a todo el personal con permiso.'
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
  final inicioCtrl = TextEditingController(text: encuesta?.fechaInicio ?? '');
  final finCtrl = TextEditingController(text: encuesta?.fechaFin ?? '');

  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(encuesta == null ? 'Nueva encuesta' : 'Editar encuesta'),
      // Mismo formato compacto que el alta de usuario: ancho acotado y
      // scroll, para que el dialogo no crezca con el texto.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
                inputFormatters: [
                  LengthLimitingTextInputFormatter(200),
                ],
                decoration: const InputDecoration(labelText: 'Título *'),
              ),
              const SizedBox(height: LuvegiSpacing.md),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 3,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(2000),
                ],
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: LuvegiSpacing.md),
              // Quien puede votar. En una encuesta nueva todavia no existe
              // el id, asi que se configura al editarla.
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
  );

  if (resultado != true) return null;
  final titulo = tituloCtrl.text.trim();
  if (titulo.isEmpty) return null;

  String? normalizar(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  return _EncuestaForm(
    titulo: titulo,
    descripcion: descCtrl.text.trim(),
    fechaInicio: normalizar(inicioCtrl),
    fechaFin: normalizar(finCtrl),
  );
}

class _EncuestaDetallePage extends StatefulWidget {
  final String token;
  final Encuesta encuesta;
  final EncuestaService service;

  const _EncuestaDetallePage({
    required this.token,
    required this.encuesta,
    required this.service,
  });

  @override
  State<_EncuestaDetallePage> createState() => _EncuestaDetallePageState();
}

class _EncuestaDetallePageState extends State<_EncuestaDetallePage> {
  bool _cargando = true;
  bool _sincronizandoFotos = false;
  bool _cargandoVotantes = false;
  int _votantesSeleccionados = 0;
  bool _votantesRestringida = false;
  String? _error;
  String _estado = 'BORRADOR';
  List<EncuestaPregunta> _preguntas = [];
  List<EncuestaUsuario> _usuarios = [];
  bool _cargandoUsuarios = false;
  String? _errorUsuarios;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarUsuarios();
    _cargarVotantes();
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
      // Si no se puede leer, se deja como "sin restriccion".
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
              },
            )
            .toList();
        return EncuestaPregunta.fromJson(p);
      }).toList();

      setState(() {
        _estado = (map['estado'] ?? 'BORRADOR').toString().toUpperCase();
        _preguntas = preguntas;
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
      final usuarios = await widget.service.listarUsuarios(
        token: widget.token,
      );
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
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1)).toUpperCase();
  }

  /// Buscador de usuarios de usuarios_app. Devuelve el usuario elegido.
  Future<EncuestaUsuario?> _seleccionarUsuario() async {
    final filtroCtrl = TextEditingController();

    final resultado = await showDialog<EncuestaUsuario>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
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
              width: 420,
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
                      height: (MediaQuery.of(context).size.height * 0.45)
                          .clamp(160.0, 320.0),
                      child: ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) {
                          final u = filtrados[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: LuvegiColors.secondary.withValues(
                                alpha: 0.12,
                              ),
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

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(pregunta == null ? 'Nueva pregunta' : 'Editar pregunta'),
        // El contenido se acota y hace scroll: el dialogo nunca crece
        // mas alla de la pantalla, por mas texto que se escriba.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
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
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(150),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Texto de la pregunta *',
                    hintText: 'Ej. ¿Cuál es la mejor propuesta?',
                  ),
                ),
                const SizedBox(height: LuvegiSpacing.md),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  minLines: 1,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(255),
                  ],
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
    );
    if (ok != true || !mounted) return;
    if (nombreCtrl.text.trim().isEmpty) return;

    try {
      await widget.service.guardarPregunta(
        token: widget.token,
        encuestaId: widget.encuesta.id,
        id: pregunta?.id,
        nombre: nombreCtrl.text.trim(),
        descripcion: descCtrl.text.trim(),
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
        content: Text(
          'Se eliminarán también las opciones vinculadas a esta pregunta.',
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
    String? areaAutofill =
        (opcion?.usuarioId != null && areaPrevia.isNotEmpty) ? areaPrevia : null;
    final nombrePrevio = opcion?.nombre ?? '';
    String? nombreAutofill =
        (opcion?.usuarioId != null && nombrePrevio.isNotEmpty) ? nombrePrevio : null;
    final fotoPrevia = opcion?.fotoUrl ?? '';
    String? fotoAutofill =
        (opcion?.usuarioId != null && fotoPrevia.isNotEmpty) ? fotoPrevia : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(opcion == null ? 'Nueva opción' : 'Editar opción'),
          // Altura acotada + scroll: el dialogo nunca crece mas alla de
          // la pantalla, por mas texto que se escriba.
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                          : 'Cambiar candidato',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                if (usuarioId != null) ...[
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
                          'Candidato vinculado al personal del portal',
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
                          : 'Configurar quien puede votar',
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
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(200),
                    ],
                    decoration: const InputDecoration(labelText: 'Nombre o Texto de opción *'),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  TextField(
                    controller: areaCtrl,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(150),
                    ],
                    decoration: const InputDecoration(labelText: 'Detalle secundario (Área)'),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  TextField(
                    controller: propCtrl,
                    minLines: 2,
                    maxLines: 3,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(2000),
                    ],
                    decoration: const InputDecoration(labelText: 'Descripción adicional'),
                  ),
                  const SizedBox(height: LuvegiSpacing.md),
                  TextField(
                    controller: fotoCtrl,
                    maxLines: 1,
                    minLines: 1,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(500),
                    ],
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
    if (ok != true || !mounted) return;
    if (nombreCtrl.text.trim().isEmpty) return;

    try {
      await widget.service.guardarOpcion(
        token: widget.token,
        encuestaId: widget.encuesta.id,
        preguntaId: pregunta.id,
        id: opcion?.id,
        nombre: nombreCtrl.text.trim(),
        area: areaCtrl.text.trim(),
        propuesta: propCtrl.text.trim(),
        fotoUrl: fotoCtrl.text.trim(),
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
      await widget.service.eliminarOpcion(
        token: widget.token,
        id: opcion.id,
      );
      await _cargar();
    } catch (e) {
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        backgroundColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        title: Text('Encuesta · ${widget.encuesta.titulo}'),
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
                padding: const EdgeInsets.all(LuvegiSpacing.xl),
                children: [
                  Row(
                    children: [
                      Chip(label: Text('Estado: $_estado')),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _cargandoVotantes ? null : _abrirSelectorVotantes,
                        icon: _cargandoVotantes
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.how_to_vote_outlined, size: 18),
                        label: Text(
                          _votantesRestringida
                              ? 'Votan $_votantesSeleccionados'
                              : 'Personal habilitado',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LuvegiColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _sincronizandoFotos ? null : _sincronizarFotos,
                        icon: _sincronizandoFotos
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text(
                          _sincronizandoFotos
                              ? 'Sincronizando...'
                              : 'Sincronizar fotos',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LuvegiColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                  const SizedBox(height: LuvegiSpacing.lg),
                  if (_preguntas.isEmpty)
                    Text(
                      'Aún no hay preguntas. Agrega la primera para cargar opciones.',
                      style: LuvegiText.bodySecondary,
                    ),
                  ..._preguntas.map(_buildPregunta),
                ],
              ),
      ),
    );
  }

  /// Rellena las fotos de las opciones que ya estaban vinculadas a un
  /// usuario del portal pero que se guardaron antes de tener fotos.
  Future<void> _sincronizarFotos() async {
    setState(() => _sincronizandoFotos = true);
    try {
      final data = await widget.service.sincronizarFotos(
        token: widget.token,
        encuestaId: widget.encuesta.id,
      );
      if (!mounted) return;

      final total = (data['total'] as num?)?.toInt() ?? 0;
      final actualizadas = (data['actualizadas'] as num?)?.toInt() ?? 0;
      final sinCruce = (data['sin_cruce'] as num?)?.toInt() ?? 0;
      final areas = (data['areas'] as num?)?.toInt() ?? 0;

      await _cargar();
      if (!mounted) return;

      _aviso(
        total == 0
            ? 'No hay opciones vinculadas a un usuario del portal.'
            : 'Fotos actualizadas: $actualizadas de $total'
                  '${sinCruce > 0 ? ' | sin cruce: $sinCruce' : ''}'
                  '${areas > 0 ? ' | áreas completadas: $areas' : ''}',
      );
    } catch (e) {
      _aviso(MensajeError.desdeExcepcion(e), error: true);
    } finally {
      if (mounted) setState(() => _sincronizandoFotos = false);
    }
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
                      Text(pregunta.descripcion, style: LuvegiText.bodySecondary),
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
            Text('Sin opciones.', style: LuvegiText.caption)
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
                          'Candidato del portal',
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
                        onPressed: () =>
                            _guardarOpcion(pregunta, opcion: c),
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
      final raw = data['participantes'] != null ? List.from(data['participantes']) : [];
      setState(() {
        _participantes = raw            .whereType()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _totalParticipantes = (data['total_participantes'] as num?)?.toInt() ?? 0;
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
                padding: const EdgeInsets.all(LuvegiSpacing.xl),
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
    final participantes =
        (_data['total_participantes'] as num?)?.toInt() ?? 0;
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
                padding: const EdgeInsets.all(LuvegiSpacing.xl),
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