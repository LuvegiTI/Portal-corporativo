import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/ticket_service.dart';

class RegistrarTicketPage extends StatefulWidget {
  final String token;
  final VoidCallback onRegistrado;

  const RegistrarTicketPage({
    super.key,
    required this.token,
    required this.onRegistrado,
  });

  @override
  State<RegistrarTicketPage> createState() => _RegistrarTicketPageState();
}

class _RegistrarTicketPageState extends State<RegistrarTicketPage> {
  final TextEditingController _asuntoCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();
  final TicketService _service = TicketService();

  List<TicketCategoria> _categorias = [];

  int? _categoriaId;

  final List<PlatformFile> _adjuntos = [];
  bool _cargandoCatalogos = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final categorias = await _service.listarCategorias(token: widget.token);
      if (!mounted) return;
      setState(() {
        _categorias = categorias.where((c) => c.activo).toList();
        _cargandoCatalogos = false;
        if (_categorias.isNotEmpty) _categoriaId = _categorias.first.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoCatalogos = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is TicketApiException
                ? e.message
                : 'No se pudieron cargar los catálogos.',
          ),
        ),
      );
    }
  }

  Future<void> _agregarAdjuntos() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final rechazos = <String>[];
    final nuevos = <PlatformFile>[];
    for (final archivo in result.files) {
      if (archivo.bytes == null) continue;
      final error = TicketUtils.validarAdjunto(archivo);
      if (error != null) {
        rechazos.add(error);
        continue;
      }
      nuevos.add(archivo);
    }

    if (nuevos.isNotEmpty) {
      setState(() => _adjuntos.addAll(nuevos));
    }
    if (rechazos.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rechazos.join('\n'))),
      );
    }
  }

  void _quitarAdjunto(int index) {
    setState(() => _adjuntos.removeAt(index));
  }

  Future<void> _guardar() async {
    final asunto = _asuntoCtrl.text.trim();
    final descripcion = _descripcionCtrl.text.trim();
    final categoriaId = _categoriaId;

    if (asunto.isEmpty || descripcion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asunto y descripción son obligatorios.'),
        ),
      );
      return;
    }
    if (categoriaId == null) return;

    setState(() => _guardando = true);
    try {
      final respuesta = await _service.crearTicket(
        token: widget.token,
        asunto: asunto,
        descripcion: descripcion,
        categoriaId: categoriaId,
        adjuntos: _adjuntos,
      );
      if (!mounted) return;

      final codigo = (respuesta['codigo'] ?? '').toString();

      await _mostrarConfirmacion(codigo: codigo);
      if (!mounted) return;
      widget.onRegistrado();
    } on TicketApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar el ticket.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _mostrarConfirmacion({required String codigo}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: LuvegiColors.success,
            size: 48,
          ),
          title: const Text('Solicitud recibida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tu ticket fue registrado correctamente.',
                textAlign: TextAlign.center,
              ),
              if (codigo.isNotEmpty) ...[
                const SizedBox(height: LuvegiSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: LuvegiColors.surfaceHover,
                    borderRadius: BorderRadius.circular(LuvegiRadius.md),
                  ),
                  child: Text(
                    codigo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: LuvegiSpacing.lg),
              const Text(
                'El equipo de TI revisará tu solicitud y le asignará la prioridad '
                'correspondiente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: LuvegiSpacing.md),
              const Text(
                'Recibirás aviso en el portal cuando el equipo de TI responda.',
                textAlign: TextAlign.center,
                style: LuvegiText.caption,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(
                backgroundColor: LuvegiColors.secondary,
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Widget _dropdownCategoria() => _cargandoCatalogos
      ? const LinearProgressIndicator()
      : DropdownButtonFormField<int>(
          initialValue: _categoriaId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Categoría *'),
          items: _categorias
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
              .toList(),
          onChanged: (v) => setState(() => _categoriaId = v),
        );

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
            child: Container(
              padding: const EdgeInsets.all(LuvegiSpacing.lg),
              decoration: BoxDecoration(
                color: LuvegiColors.surface,
                borderRadius: BorderRadius.circular(LuvegiRadius.lg),
                border: Border.all(color: LuvegiColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Registrar Ticket',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: LuvegiColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.xl),
                  TextField(
                    controller: _asuntoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Asunto *',
                      hintText: 'Resumen breve del problema o solicitud',
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.lg),
                  TextField(
                    controller: _descripcionCtrl,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Descripción *',
                      hintText: 'Detalla el problema, el equipo, lo que necesitas…',
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _dropdownCategoria(),
                  const SizedBox(height: LuvegiSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: LuvegiColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'El equipo de TI asignará la prioridad de tu solicitud.',
                          style: LuvegiText.caption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: LuvegiSpacing.lg),
                  Text('Archivos adjuntos', style: LuvegiText.title),
                  const SizedBox(height: LuvegiSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _agregarAdjuntos,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Adjuntar archivos'),
                  ),
                  const SizedBox(height: LuvegiSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: LuvegiColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Puedes adjuntar hasta ${TicketUtils.maxAdjuntos} archivos '
                          '(máx. ${TicketUtils.maxAdjuntoMb} MB cada uno).',
                          style: LuvegiText.caption,
                        ),
                      ),
                    ],
                  ),
                  if (_adjuntos.isNotEmpty) ...[
                    const SizedBox(height: LuvegiSpacing.md),
                    ..._adjuntos.asMap().entries.map((entry) {
                      final f = entry.value;
                      return Material(
                        color: LuvegiColors.surface,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.image_outlined,
                            color: LuvegiColors.secondary,
                          ),
                          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: _guardando
                                ? null
                                : () => _quitarAdjunto(entry.key),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: LuvegiSpacing.xl),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Registrar ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LuvegiColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
