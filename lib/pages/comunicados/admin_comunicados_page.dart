import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/luvegi_button.dart';
import '../../services/comunicado_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';

class AdminComunicadosPage extends StatefulWidget {
  final String token;

  const AdminComunicadosPage({super.key, required this.token});

  @override
  State<AdminComunicadosPage> createState() => _AdminComunicadosPageState();
}

class _AdminComunicadosPageState extends State<AdminComunicadosPage> {
  final ComunicadoService _service = ComunicadoService();

  List<Comunicado> _comunicados = [];
  bool _cargando = true;
  String? _error;
  bool _procesando = false;

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
      final lista = await _service.adminListar(token: widget.token);
      if (!mounted) return;
      setState(() => _comunicados = lista);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _fecha(String valor) {
    if (valor.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(valor.replaceFirst(' ', 'T'));
    if (parsed == null) return valor;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
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

  Future<void> _nuevo() async {
    final resultado = await showDialog<_ComunicadoFormResult>(
      context: context,
      builder: (_) => const _ComunicadoFormDialog(),
    );
    if (resultado == null) return;

    setState(() => _procesando = true);
    try {
      await _service.crear(
        token: widget.token,
        titulo: resultado.titulo,
        contenido: resultado.contenido,
        importante: resultado.importante,
        imagenBytes: resultado.imagenBytes,
        imagenNombre: resultado.imagenNombre,
        archivos: resultado.archivos,
      );
      _aviso('Comunicado publicado.');
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _editar(Comunicado c) async {
    final resultado = await showDialog<_ComunicadoFormResult>(
      context: context,
      builder: (_) => _ComunicadoFormDialog(comunicado: c),
    );
    if (resultado == null) return;

    setState(() => _procesando = true);
    try {
      await _service.actualizar(
        token: widget.token,
        id: c.id,
        titulo: resultado.titulo,
        contenido: resultado.contenido,
        importante: resultado.importante,
        imagenBytes: resultado.imagenBytes,
        imagenNombre: resultado.imagenNombre,
        archivos: resultado.archivos,
        eliminarAdjuntos: resultado.eliminarAdjuntos,
        quitarImagen: resultado.quitarImagen,
        quitarArchivo: resultado.quitarArchivo,
      );
      _aviso('Comunicado actualizado.');
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _toggle(Comunicado c) async {
    setState(() => _procesando = true);
    try {
      await _service.toggle(token: widget.token, id: c.id);
      _aviso(c.activo ? 'Comunicado oculto.' : 'Comunicado publicado.');
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _eliminar(Comunicado c) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comunicado'),
        content: Text(
          '¿Deseas eliminar "${c.titulo}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: LuvegiColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      await _service.eliminar(token: widget.token, id: c.id);
      _aviso('Comunicado eliminado.');
      await _cargar();
    } catch (e) {
      _aviso(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
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
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
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
                        Icons.campaign,
                        color: LuvegiColors.secondary,
                      ),
                    ),
                    const SizedBox(width: LuvegiSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administrar Comunicados',
                            style: LuvegiText.title.copyWith(fontSize: 20),
                          ),
                          Text(
                            'Publica fotos y avisos visibles para todo el personal.',
                            style: LuvegiText.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                    if (_procesando)
                      const Padding(
                        padding: EdgeInsets.only(right: LuvegiSpacing.md),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    LuvegiButton.primary(
                      text: 'Nuevo comunicado',
                      icon: Icons.add,
                      onPressed: _procesando ? null : _nuevo,
                    ),
                  ],
                ),
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
                else if (_comunicados.isEmpty)
                  _card(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.campaign_outlined,
                          size: 48,
                          color: LuvegiColors.textHint,
                        ),
                        const SizedBox(height: LuvegiSpacing.md),
                        Text(
                          'Aún no hay comunicados.',
                          style: LuvegiText.title,
                        ),
                        const SizedBox(height: LuvegiSpacing.xs),
                        Text(
                          'Crea el primero para que el personal lo vea.',
                          style: LuvegiText.bodySecondary,
                        ),
                      ],
                    ),
                  )
                else
                  ..._comunicados.map(_buildFila),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFila(Comunicado c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.md),
      child: _card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
              child: SizedBox(
                width: 88,
                height: 88,
                child: c.tieneImagen
                    ? Image.network(
                        _service.imagenUrl(c.id, widget.token),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _SinImagen(),
                      )
                    : const _SinImagen(),
              ),
            ),
            const SizedBox(width: LuvegiSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (c.importante) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LuvegiSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: LuvegiColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.sm,
                            ),
                          ),
                          child: Text(
                            'IMPORTANTE',
                            style: LuvegiText.caption.copyWith(
                              color: LuvegiColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: LuvegiSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          c.titulo,
                          style: LuvegiText.title.copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: LuvegiSpacing.xs),
                  Text(
                    [
                      if (c.autor.isNotEmpty) c.autor,
                      if (_fecha(c.creadoEn).isNotEmpty) _fecha(c.creadoEn),
                      if (c.archivos.length > 1)
                        '${c.archivos.length} adjuntos',
                      c.activo ? 'Publicado' : 'Oculto',
                    ].join(' · '),
                    style: LuvegiText.caption,
                  ),
                  if (c.contenido.trim().isNotEmpty) ...[
                    const SizedBox(height: LuvegiSpacing.xs),
                    Text(
                      c.contenido,
                      style: LuvegiText.bodySecondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LuvegiSpacing.md),
            Wrap(
              spacing: LuvegiSpacing.xs,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  onPressed: _procesando ? null : () => _editar(c),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: c.activo ? 'Ocultar' : 'Publicar',
                  onPressed: _procesando ? null : () => _toggle(c),
                  icon: Icon(
                    c.activo
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: c.activo
                        ? LuvegiColors.textSecondary
                        : LuvegiColors.success,
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: _procesando ? null : () => _eliminar(c),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: LuvegiColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

class _SinImagen extends StatelessWidget {
  const _SinImagen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LuvegiColors.surfaceHover,
      child: const Icon(Icons.image_outlined, color: LuvegiColors.textHint),
    );
  }
}

class _ComunicadoFormResult {
  final String titulo;
  final String contenido;
  final bool importante;
  final Uint8List? imagenBytes;
  final String? imagenNombre;
  final List<ArchivoSubida> archivos;
  final List<int> eliminarAdjuntos;
  final bool quitarImagen;
  final bool quitarArchivo;

  const _ComunicadoFormResult({
    required this.titulo,
    required this.contenido,
    required this.importante,
    required this.imagenBytes,
    required this.imagenNombre,
    required this.archivos,
    required this.eliminarAdjuntos,
    required this.quitarImagen,
    required this.quitarArchivo,
  });
}

class _ComunicadoFormDialog extends StatefulWidget {
  final Comunicado? comunicado;

  const _ComunicadoFormDialog({this.comunicado});

  @override
  State<_ComunicadoFormDialog> createState() => _ComunicadoFormDialogState();
}

class _ComunicadoFormDialogState extends State<_ComunicadoFormDialog> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _contenidoCtrl;
  late bool _importante;

  Uint8List? _imagenBytes;
  String? _imagenNombre;
  final List<ArchivoSubida> _archivosNuevos = [];
  final Set<int> _adjuntosEliminar = {};
  bool _quitarImagen = false;
  bool _quitarArchivo = false;
  String? _error;

  bool get _esEdicion => widget.comunicado != null;

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.comunicado?.titulo ?? '');
    _contenidoCtrl = TextEditingController(
      text: widget.comunicado?.contenido ?? '',
    );
    _importante = widget.comunicado?.importante ?? false;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirImagen() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      withData: true,
    );
    final archivo = res?.files.single;
    if (archivo == null || archivo.bytes == null) return;
    setState(() {
      _imagenBytes = archivo.bytes;
      _imagenNombre = archivo.name;
      _quitarImagen = false;
      _error = null;
    });
  }

  Future<void> _elegirArchivos() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (res == null) return;
    final nuevos = res.files
        .where((a) => a.bytes != null)
        .map((a) => ArchivoSubida(bytes: a.bytes!, nombre: a.name))
        .toList();
    if (nuevos.isEmpty) return;
    setState(() {
      _archivosNuevos.addAll(nuevos);
      _quitarArchivo = false;
      _error = null;
    });
  }

  List<ComunicadoArchivo> get _adjuntosActuales =>
      (widget.comunicado?.archivos ?? const <ComunicadoArchivo>[])
          .where((a) => !_adjuntosEliminar.contains(a.id))
          .toList();

  void _quitarAdjuntoActual(ComunicadoArchivo adjunto) {
    setState(() {
      if (adjunto.esLegacy) {
        _quitarArchivo = true;
      } else {
        _adjuntosEliminar.add(adjunto.id);
      }
    });
  }

  Widget _filaAdjunto({
    required String nombre,
    required VoidCallback onQuitar,
  }) {
    return Row(
      children: [
        const Icon(Icons.attach_file, color: LuvegiColors.secondary, size: 18),
        const SizedBox(width: LuvegiSpacing.sm),
        Expanded(
          child: Text(
            nombre,
            style: LuvegiText.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Quitar',
          visualDensity: VisualDensity.compact,
          onPressed: onQuitar,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }

  void _guardar() {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      setState(() => _error = 'El título es obligatorio.');
      return;
    }
    Navigator.of(context).pop(
      _ComunicadoFormResult(
        titulo: titulo,
        contenido: _contenidoCtrl.text.trim(),
        importante: _importante,
        imagenBytes: _imagenBytes,
        imagenNombre: _imagenNombre,
        archivos: List<ArchivoSubida>.unmodifiable(_archivosNuevos),
        eliminarAdjuntos: _adjuntosEliminar.toList(),
        quitarImagen: _quitarImagen,
        quitarArchivo: _quitarArchivo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final tieneImagenActual =
        _esEdicion && widget.comunicado!.tieneImagen && !_quitarImagen;

    return Dialog(
      insetPadding: const EdgeInsets.all(LuvegiSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ancho < 600 ? ancho - 32 : 640,
          maxHeight: 760,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(LuvegiSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _esEdicion ? 'Editar comunicado' : 'Nuevo comunicado',
                      style: LuvegiText.title.copyWith(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(LuvegiSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _tituloCtrl,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: LuvegiSpacing.sm),
                    TextField(
                      controller: _contenidoCtrl,
                      minLines: 4,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'Contenido',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _importante,
                      onChanged: (v) => setState(() => _importante = v),
                      title: const Text('Marcar como importante'),
                      subtitle: Text(
                        'Aparecerá primero y con una etiqueta destacada.',
                        style: LuvegiText.caption,
                      ),
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    Text('Imagen', style: LuvegiText.label),
                    const SizedBox(height: LuvegiSpacing.sm),
                    if (_imagenBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(LuvegiRadius.md),
                        child: Image.memory(
                          _imagenBytes!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (tieneImagenActual)
                      Row(
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            color: LuvegiColors.secondary,
                          ),
                          const SizedBox(width: LuvegiSpacing.sm),
                          const Expanded(child: Text('Imagen actual cargada')),
                          TextButton(
                            onPressed: () =>
                                setState(() => _quitarImagen = true),
                            child: const Text('Quitar'),
                          ),
                        ],
                      ),
                    const SizedBox(height: LuvegiSpacing.sm),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _elegirImagen,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _imagenBytes == null
                                ? 'Seleccionar imagen'
                                : 'Cambiar imagen',
                          ),
                        ),
                        if (_imagenNombre != null) ...[
                          const SizedBox(width: LuvegiSpacing.sm),
                          Expanded(
                            child: Text(
                              _imagenNombre!,
                              style: LuvegiText.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    Text('Archivos adjuntos', style: LuvegiText.label),
                    const SizedBox(height: LuvegiSpacing.xs),
                    Text(
                      'Puedes adjuntar varios archivos (máx. 8 MB cada uno).',
                      style: LuvegiText.caption,
                    ),
                    const SizedBox(height: LuvegiSpacing.sm),
                    if (_esEdicion && !_quitarArchivo)
                      ..._adjuntosActuales.map(
                        (adjunto) => _filaAdjunto(
                          nombre: adjunto.nombre,
                          onQuitar: () => _quitarAdjuntoActual(adjunto),
                        ),
                      ),
                    ...List<Widget>.generate(_archivosNuevos.length, (i) {
                      final archivo = _archivosNuevos[i];
                      return _filaAdjunto(
                        nombre: archivo.nombre,
                        onQuitar: () =>
                            setState(() => _archivosNuevos.removeAt(i)),
                      );
                    }),
                    const SizedBox(height: LuvegiSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _elegirArchivos,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Agregar archivos'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: LuvegiSpacing.md),
                      Text(
                        _error!,
                        style: LuvegiText.caption.copyWith(
                          color: LuvegiColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(LuvegiSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: LuvegiSpacing.sm),
                  LuvegiButton.primary(
                    text: _esEdicion ? 'Guardar cambios' : 'Publicar',
                    onPressed: _guardar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
