import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/ticket_service.dart';
import '../../services/ticket_unread_store.dart';

class DetalleTicketPage extends StatefulWidget {
  final String token;
  final String codigo;
  final bool esAdminTickets;

  const DetalleTicketPage({
    super.key,
    required this.token,
    required this.codigo,
    this.esAdminTickets = false,
  });

  @override
  State<DetalleTicketPage> createState() => _DetalleTicketPageState();
}

class _DetalleTicketPageState extends State<DetalleTicketPage> {
  final TicketService _service = TicketService();
  final TextEditingController _mensajeCtrl = TextEditingController();
  final TextEditingController _notaCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  TicketDetalle? _detalle;
  bool _cargando = true;
  bool _guardando = false;
  bool _enviando = false;
  bool _guardandoNota = false;
  bool _descargandoInforme = false;
  String? _error;

  List<TicketTecnico> _tecnicos = [];
  List<TicketCategoria> _categorias = [];
  List<TicketPrioridad> _prioridades = [];
  List<TicketMensaje> _mensajes = [];
  List<TicketNota> _notas = [];
  bool _cargandoMensajes = true;
  bool _cargandoNotas = false;
  final List<PlatformFile> _adjuntosPendientes = [];

  /// Subida directa de archivos adjuntos en el chat.
  static const bool _permitirAdjuntos = true;
  DateTime? _notaFechaInicio;
  DateTime? _notaFechaFin;
  TimeOfDay? _notaHoraInicio;
  TimeOfDay? _notaHoraFin;
  Timer? _timer;
  Timer? _ticker;
  int _ultimoConteo = 0;
  DateTime? _ultimaActualizacion;
  bool _huboCambios = false;

  bool get _ticketCerrado => _detalle?.ticket.estado == 'CERRADO';
  bool get _esCreador => _detalle?.esCreador ?? false;
  bool get _esTecnico => _detalle?.esTecnico ?? false;

  bool get _puedeEditar {
    final detalle = _detalle;
    if (detalle == null) return false;
    if (!(_esCreador || _esTecnico || widget.esAdminTickets)) {
      return false;
    }
    if (_ticketCerrado && !widget.esAdminTickets) return false;
    return true;
  }

  bool get _puedeReabrir =>
      _ticketCerrado && (widget.esAdminTickets || _esTecnico);

  bool get _mostrarAcciones =>
      _puedeEditar || _puedeReabrir || widget.esAdminTickets || _esTecnico;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarMensajes();
    if (widget.esAdminTickets) {
      _cargarTecnicos();
      _cargarNotas();
    }
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cargarMensajes(silencioso: true);
      if (widget.esAdminTickets) _cargarNotas(silencioso: true);
    });
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _ultimaActualizacion != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker?.cancel();
    _mensajeCtrl.dispose();
    _notaCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final detalle = await _service.obtenerDetalle(
        token: widget.token,
        codigo: widget.codigo,
      );
      if (!mounted) return;
      setState(() {
        _detalle = detalle;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detalle = null;
        _error = _mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  Future<void> _cargarMensajes({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargandoMensajes = true);
    try {
      final mensajes = await _service.listarMensajes(
        token: widget.token,
        codigo: widget.codigo,
      );
      if (!mounted) return;
      if (mensajes.isNotEmpty) {
        final maxId = mensajes.map((m) => m.id).reduce((a, b) => a > b ? a : b);
        await TicketUnreadStore.marcarVisto(widget.codigo, maxId);
      }
      final crecio = mensajes.length > _ultimoConteo;
      _ultimoConteo = mensajes.length;
      setState(() {
        _mensajes = mensajes;
        _cargandoMensajes = false;
        _ultimaActualizacion = DateTime.now();
      });
      if (crecio && _scrollCtrl.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {
      if (mounted && !silencioso) setState(() => _cargandoMensajes = false);
    }
  }

  Future<void> _cargarNotas({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargandoNotas = true);
    try {
      final notas = await _service.listarNotasInternas(
        token: widget.token,
        codigo: widget.codigo,
      );
      if (!mounted) return;
      setState(() {
        _notas = notas;
        _cargandoNotas = false;
      });
    } catch (_) {
      if (mounted && !silencioso) setState(() => _cargandoNotas = false);
    }
  }

  Future<void> _agregarNota() async {
    if (_guardandoNota) return;
    final texto = _notaCtrl.text.trim();
    if (texto.isEmpty) return;

    setState(() => _guardandoNota = true);
    try {
      final nota = await _service.crearNotaInterna(
        token: widget.token,
        codigo: widget.codigo,
        nota: texto,
        fechaInicio: _notaFechaInicio,
        fechaFin: _notaFechaFin,
        horaInicio: _notaHoraInicio,
        horaFin: _notaHoraFin,
      );
      if (!mounted) return;
      setState(() {
        _notas = [..._notas, nota];
        _notaCtrl.clear();
        _notaFechaInicio = null;
        _notaFechaFin = null;
        _notaHoraInicio = null;
        _notaHoraFin = null;
        _guardandoNota = false;
      });
    } on TicketApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardandoNota = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardandoNota = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la nota.')),
      );
    }
  }

  String _mensajeDeError(Object e) {
    if (e is TicketApiException) return e.message;
    return 'No se pudo cargar el detalle. Intenta más tarde.';
  }

  Future<String?> _cargarTecnicos() async {
    try {
      final tecnicos = await _service.listarTecnicos(token: widget.token);
      if (mounted) setState(() => _tecnicos = tecnicos);
      return null;
    } on TicketApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'No se pudo obtener la lista de técnicos.';
    }
  }

  Future<bool> _cargarCatalogos() async {
    try {
      final categorias = await _service.listarCategorias(token: widget.token);
      final prioridades = await _service.listarPrioridades(token: widget.token);
      if (!mounted) return false;
      setState(() {
        _categorias = categorias;
        _prioridades = prioridades;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _editar() async {
    final detalle = _detalle;
    if (detalle == null || _guardando) return;

    if (_categorias.isEmpty || _prioridades.isEmpty) {
      final ok = await _cargarCatalogos();
      if (!mounted) return;
      if (!ok || _categorias.isEmpty || _prioridades.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron cargar las categorías o prioridades.',
            ),
          ),
        );
        return;
      }
    }

    final asuntoCtrl = TextEditingController(text: detalle.ticket.asunto);
    final descripcionOriginal = detalle.descripcion;
    int? categoriaId = detalle.ticket.categoriaId > 0
        ? detalle.ticket.categoriaId
        : null;
    int? prioridadId = detalle.ticket.prioridadId > 0
        ? detalle.ticket.prioridadId
        : null;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final valido =
              asuntoCtrl.text.trim().isNotEmpty && categoriaId != null;
          return AlertDialog(
            title: const Text('Editar ticket'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: asuntoCtrl,
                      enabled: !_guardando,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(labelText: 'Asunto'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController(
                        text: descripcionOriginal,
                      ),
                      enabled: false,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (no editable)',
                        helperText:
                            'La descripción no puede modificarse una vez creado el ticket.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: categoriaId,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: _categorias
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nombre),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => categoriaId = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: !valido
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (guardar != true || !mounted) {
      asuntoCtrl.dispose();
      return;
    }

    setState(() => _guardando = true);
    try {
      await _service.editarTicket(
        token: widget.token,
        codigo: widget.codigo,
        asunto: asuntoCtrl.text.trim(),
        descripcion: descripcionOriginal,
        categoriaId: categoriaId!,
        prioridadId: prioridadId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket actualizado.'),
          backgroundColor: LuvegiColors.success,
        ),
      );
      await _cargar();
    } on TicketApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _guardando = false);
      asuntoCtrl.dispose();
    }
  }

  Future<void> _cambiarPrioridad() async {
    final detalle = _detalle;
    if (detalle == null || _guardando) return;

    if (_prioridades.isEmpty) {
      final ok = await _cargarCatalogos();
      if (!mounted) return;
      if (!ok || _prioridades.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar las prioridades.'),
          ),
        );
        return;
      }
    }

    final activas = _prioridades.where((p) => p.activo).toList();
    final actualId = detalle.ticket.prioridadId;
    final motivoCtrl = TextEditingController();

    final seleccion = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        int? elegido = actualId > 0 ? actualId : null;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            icon: const Icon(
              Icons.priority_high_rounded,
              color: LuvegiColors.secondary,
            ),
            title: const Text('Asignar prioridad'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Define la prioridad de atención de este ticket.',
                  style: LuvegiText.caption,
                ),
                const SizedBox(height: LuvegiSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: elegido,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Prioridad *'),
                  items: activas
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => elegido = v),
                ),
                const SizedBox(height: LuvegiSpacing.md),
                TextField(
                  controller: motivoCtrl,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del cambio',
                    hintText: 'Detalla por qué se cambia la prioridad',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, elegido),
                style: FilledButton.styleFrom(
                  backgroundColor: LuvegiColors.secondary,
                ),
                child: const Text('Asignar'),
              ),
            ],
          ),
        );
      },
    );

    final motivo = motivoCtrl.text.trim();
    motivoCtrl.dispose();

    if (seleccion == null || seleccion <= 0) return;
    if (seleccion == actualId) return;

    setState(() => _guardando = true);
    try {
      await _service.cambiarPrioridadTicket(
        token: widget.token,
        codigo: widget.codigo,
        prioridadId: seleccion,
        motivo: motivo.isEmpty ? null : motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prioridad asignada correctamente.'),
          backgroundColor: LuvegiColors.success,
        ),
      );
      await _cargar();
    } on TicketApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo asignar la prioridad.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarSubcategoria() async {
    final detalle = _detalle;
    if (detalle == null || _guardando) return;

    final categoriaId = detalle.ticket.categoriaId;
    if (categoriaId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El ticket no tiene una categoría general asignada.'),
        ),
      );
      return;
    }

    List<TicketCategoria> subcategorias;
    try {
      subcategorias = await _service.listarSubcategorias(
        token: widget.token,
        padreId: categoriaId,
      );
    } on TicketApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar las subcategorías.'),
        ),
      );
      return;
    }
    if (!mounted) return;

    if (subcategorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La categoría no tiene subcategorías configuradas.'),
        ),
      );
      return;
    }

    final actualId = detalle.ticket.subcategoriaId;

    final seleccion = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        int? elegido = actualId > 0 ? actualId : null;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            icon: const Icon(
              Icons.account_tree_outlined,
              color: LuvegiColors.secondary,
            ),
            title: const Text('Asignar subcategoría'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categoría: ${detalle.ticket.categoria}',
                  style: LuvegiText.caption,
                ),
                const SizedBox(height: LuvegiSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: elegido,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Subcategoría *',
                  ),
                  items: subcategorias
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => elegido = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, elegido),
                style: FilledButton.styleFrom(
                  backgroundColor: LuvegiColors.secondary,
                ),
                child: const Text('Asignar'),
              ),
            ],
          ),
        );
      },
    );

    if (seleccion == null || seleccion <= 0) return;
    if (seleccion == actualId) return;

    setState(() => _guardando = true);
    try {
      await _service.cambiarSubcategoriaTicket(
        token: widget.token,
        codigo: widget.codigo,
        subcategoriaId: seleccion,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subcategoría asignada correctamente.'),
          backgroundColor: LuvegiColors.success,
        ),
      );
      await _cargar();
    } on TicketApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo asignar la subcategoría.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarEstado(
    String estado, {
    String? titulo,
    String? mensaje,
  }) async {
    if (_guardando || _detalle == null) return;
    if (_detalle!.ticket.estado == estado) return;

    final requiereMotivo = estado == 'CERRADO';
    final motivoCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          titulo ?? 'Cambiar estado a “${TicketUtils.etiquetaEstado(estado)}”',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensaje ??
                  (requiereMotivo
                      ? 'Indica la solución o motivo de la resolución. Quedará en el historial del ticket.'
                      : '¿Confirmas el cambio de estado del ticket?'),
            ),
            if (requiereMotivo) ...[
              const SizedBox(height: LuvegiSpacing.md),
              TextField(
                controller: motivoCtrl,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la resolución *',
                  hintText:
                      'Ej.: Se reinstaló el sistema y se verificó con el usuario.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (requiereMotivo && motivoCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('El motivo de la resolución es obligatorio.'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    final comentario = motivoCtrl.text.trim();
    motivoCtrl.dispose();

    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await _service.cambiarEstado(
        token: widget.token,
        codigo: widget.codigo,
        estado: estado,
        comentario: comentario,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado actualizado.'),
          backgroundColor: LuvegiColors.success,
        ),
      );
      await _cargar();
      if (!mounted) return;
      setState(() => _huboCambios = true);
    } on TicketApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _asignar() async {
    if (_guardando || _detalle == null) return;
    if (_tecnicos.isEmpty) {
      final error = await _cargarTecnicos();
      if (_tecnicos.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'No hay técnicos disponibles.')),
        );
        return;
      }
    }

    final tecnicoActual = _detalle!.ticket.tecnico;
    final esReasignacion = tecnicoActual.isNotEmpty;
    int? tecnicoId;
    final comentarioCtrl = TextEditingController();

    if (!mounted) return;
    final resultado = await showDialog<(int, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final comentarioOk =
              !esReasignacion || comentarioCtrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              esReasignacion ? 'Reasignar técnico' : 'Asignar técnico',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (esReasignacion)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Técnico actual: $tecnicoActual',
                        style: LuvegiText.caption,
                      ),
                    ),
                  ),
                DropdownButtonFormField<int>(
                  initialValue: tecnicoId,
                  decoration: const InputDecoration(labelText: 'Nuevo técnico'),
                  items: _tecnicos
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => tecnicoId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: comentarioCtrl,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: esReasignacion
                        ? 'Motivo de la reasignación'
                        : 'Comentario (opcional)',
                    hintText: esReasignacion
                        ? 'Explica por qué se pasa a otro nivel o técnico'
                        : 'Detalle de la asignación',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: tecnicoId == null || !comentarioOk
                    ? null
                    : () => Navigator.pop(dialogContext, (
                        tecnicoId!,
                        comentarioCtrl.text.trim(),
                      )),
                child: Text(esReasignacion ? 'Reasignar' : 'Asignar'),
              ),
            ],
          );
        },
      ),
    );

    if (resultado == null || !mounted) return;
    final (nuevoTecnico, comentario) = resultado;

    setState(() => _guardando = true);
    try {
      await _service.asignarTicket(
        token: widget.token,
        codigo: widget.codigo,
        tecnicoId: nuevoTecnico,
        comentario: comentario,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket asignado correctamente.'),
          backgroundColor: LuvegiColors.success,
        ),
      );
      await _cargar();
    } on TicketApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarAdjuntos() async {
    if (_ticketCerrado) return;
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
      if (_adjuntosPendientes.length + nuevos.length >=
          TicketUtils.maxAdjuntos) {
        rechazos.add('Máximo ${TicketUtils.maxAdjuntos} archivos por mensaje.');
        break;
      }
      final error = TicketUtils.validarAdjunto(archivo);
      if (error != null) {
        rechazos.add(error);
        continue;
      }
      nuevos.add(archivo);
    }

    if (nuevos.isNotEmpty) {
      setState(() => _adjuntosPendientes.addAll(nuevos));
    }
    if (rechazos.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(rechazos.join('\n'))));
    }
  }

  void _quitarAdjunto(int index) {
    setState(() => _adjuntosPendientes.removeAt(index));
  }

  Future<void> _enviarMensaje() async {
    if (_enviando || _ticketCerrado) return;
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty && _adjuntosPendientes.isEmpty) return;

    final enlaceInvalido = _primerEnlaceInvalido(texto);
    if (enlaceInvalido != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El enlace "$enlaceInvalido" no es válido.')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final mensaje = await _service.enviarMensaje(
        token: widget.token,
        codigo: widget.codigo,
        mensaje: texto,
        adjuntos: List.of(_adjuntosPendientes),
      );
      if (!mounted) return;
      setState(() {
        _mensajes = [..._mensajes, mensaje];
        _ultimoConteo = _mensajes.length;
        _mensajeCtrl.clear();
        _adjuntosPendientes.clear();
        _enviando = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } on TicketApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje.')),
      );
    }
  }

  /// Devuelve el primer enlace inválido del texto, o null si todos son válidos.
  String? _primerEnlaceInvalido(String texto) {
    final matches = RegExp(r'\bhttps?://\S+').allMatches(texto);
    for (final m in matches) {
      final valor = m.group(0);
      if (valor == null) continue;
      final uri = Uri.tryParse(valor);
      if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
        return valor;
      }
    }
    return null;
  }

  Future<void> _abrirAdjunto({required String tipo, required int id}) async {
    if (id <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Adjunto no disponible.')));
      return;
    }
    try {
      final bytes = await _service.descargarAdjunto(
        token: widget.token,
        tipo: tipo,
        id: id,
      );
      // Guardar o abrir según caso. Usamos FileSaver para forzar descarga.
      await FileSaver.instance.saveFile(
        name: 'Adjunto_$tipo$id',
        bytes: Uint8List.fromList(bytes),
        ext: '',
        mimeType: MimeType.other,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _descargarInforme() async {
    if (_descargandoInforme) return;
    setState(() => _descargandoInforme = true);
    try {
      final bytes = await _service.descargarInforme(
        token: widget.token,
        codigo: widget.codigo,
      );
      final nombre = 'Informe_${widget.codigo}';
      await FileSaver.instance.saveFile(
        name: nombre,
        bytes: Uint8List.fromList(bytes),
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe descargado.'),
          backgroundColor: LuvegiColors.success,
        ),
      );
    } on TicketApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el informe.')),
      );
    } finally {
      if (mounted) setState(() => _descargandoInforme = false);
    }
  }

  String _formatearFecha(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _textoTiempoAtencion() {
    final t = _detalle!.ticket;
    final inicio = t.creadoEn;
    if (inicio == null) return '';
    var duracion = (t.fechaCierre ?? DateTime.now()).difference(inicio);
    if (duracion.isNegative) duracion = Duration.zero;
    final etiqueta = t.fechaCierre != null ? 'Atención' : 'En curso';
    return '$etiqueta: ${_formatearDuracion(duracion)}';
  }

  String _formatearDuracion(Duration d) {
    final dias = d.inDays;
    final horas = d.inHours % 24;
    final minutos = d.inMinutes % 60;
    if (dias > 0) return '$dias d $horas h';
    if (d.inHours > 0) return '${d.inHours} h $minutos min';
    if (d.inMinutes > 0) return '$minutos min';
    return 'menos de 1 min';
  }

  String _textoActualizado() {
    final fecha = _ultimaActualizacion;
    if (fecha == null) return '';
    final segundos = DateTime.now().difference(fecha).inSeconds;
    if (segundos < 5) return 'Actualizado ahora';
    if (segundos < 60) return 'Actualizado hace $segundos s';
    final minutos = segundos ~/ 60;
    if (minutos < 60) return 'Actualizado hace $minutos min';
    final horas = minutos ~/ 60;
    return 'Actualizado hace $horas h';
  }

  String _formatearDia(DateTime? dt) {
    if (dt == null) return '';
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    return '$dia/$mes/${dt.year}';
  }

  Future<void> _elegirFechaNota({required bool inicio}) async {
    final ahora = DateTime.now();
    final base = (inicio ? _notaFechaInicio : _notaFechaFin) ?? ahora;
    final elegida = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(ahora.year - 3),
      lastDate: DateTime(ahora.year + 3),
    );
    if (elegida == null || !mounted) return;
    setState(() {
      if (inicio) {
        _notaFechaInicio = elegida;
        if (_notaFechaFin != null && _notaFechaFin!.isBefore(elegida)) {
          _notaFechaFin = elegida;
        }
      } else {
        _notaFechaFin = elegida;
        if (_notaFechaInicio != null && elegida.isBefore(_notaFechaInicio!)) {
          _notaFechaInicio = elegida;
        }
      }
    });
  }

  String _formatearHora(TimeOfDay? hora) {
    if (hora == null) return '';
    final hh = hora.hour.toString().padLeft(2, '0');
    final mm = hora.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _textoPeriodo(TicketNota n) {
    final inicio = [
      if (_formatearDia(n.fechaInicio).isNotEmpty) _formatearDia(n.fechaInicio),
      if ((n.horaInicio ?? '').isNotEmpty) n.horaInicio!,
    ].join(' ');
    final fin = [
      if (_formatearDia(n.fechaFin).isNotEmpty) _formatearDia(n.fechaFin),
      if ((n.horaFin ?? '').isNotEmpty) n.horaFin!,
    ].join(' ');
    if (inicio.isEmpty && fin.isEmpty) return '';
    if (inicio.isEmpty) return 'Hasta $fin';
    if (fin.isEmpty) return 'Desde $inicio';
    return '$inicio - $fin';
  }

  Future<void> _elegirHora({required bool inicio}) async {
    final base =
        (inicio ? _notaHoraInicio : _notaHoraFin) ??
        const TimeOfDay(hour: 8, minute: 0);
    final elegida = await showTimePicker(context: context, initialTime: base);
    if (elegida == null || !mounted) return;
    setState(() {
      if (inicio) {
        _notaHoraInicio = elegida;
      } else {
        _notaHoraFin = elegida;
      }
    });
  }

  Widget _buildSelectorCampo({
    required String label,
    required String valor,
    required bool vacio,
    required IconData icono,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: _guardandoNota ? null : onTap,
      borderRadius: BorderRadius.circular(LuvegiRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: onClear == null
              ? Icon(icono, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClear,
                  tooltip: 'Quitar',
                ),
        ),
        child: Text(
          vacio ? 'Sin definir' : valor,
          style: TextStyle(
            color: vacio
                ? LuvegiColors.textSecondary
                : LuvegiColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final padding = EdgeInsets.all(
      mobile ? LuvegiSpacing.md : LuvegiSpacing.xl,
    );

    return PopScope<dynamic>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: LuvegiColors.background,
        appBar: AppBar(
          backgroundColor: LuvegiColors.surface,
          surfaceTintColor: LuvegiColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).pop(_huboCambios),
          ),
          title: Text(
            _detalle == null
                ? 'Ticket ${widget.codigo}'
                : _detalle!.ticket.codigo,
          ),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _detalle == null
            ? _buildError()
            : Column(
                children: [
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollCtrl,
                      thumbVisibility: !mobile,
                      child: SingleChildScrollView(
                        controller: _scrollCtrl,
                        padding: padding,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: LuvegiSpacing.lg),
                                _buildDetalle(),
                                const SizedBox(height: LuvegiSpacing.lg),
                                _buildAdjuntos(),
                                const SizedBox(height: LuvegiSpacing.lg),
                                _buildConversacion(),
                                const SizedBox(height: LuvegiSpacing.lg),
                                if (widget.esAdminTickets) ...[
                                  _buildNotasInternas(),
                                  const SizedBox(height: LuvegiSpacing.lg),
                                  _buildActividad(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildComposer(mobile),
                ],
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(LuvegiSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: LuvegiColors.error,
              ),
              const SizedBox(height: LuvegiSpacing.md),
              const Text(
                'No se pudo cargar el ticket',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: LuvegiColors.textPrimary,
                ),
              ),
              const SizedBox(height: LuvegiSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(LuvegiSpacing.md),
                decoration: BoxDecoration(
                  color: LuvegiColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(LuvegiRadius.md),
                  border: Border.all(color: LuvegiColors.error),
                ),
                child: Text(
                  _error ?? 'Motivo desconocido.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: LuvegiSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _cargar();
                      _cargarMensajes();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final t = _detalle!.ticket;
    return Container(
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
                  t.asunto,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: LuvegiColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: TicketUtils.colorEstado(
                    t.estado,
                  ).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  TicketUtils.etiquetaEstado(t.estado),
                  style: TextStyle(
                    color: TicketUtils.colorEstado(t.estado),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.md),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _infoChip(Icons.category_outlined, t.categoria),
              if (t.subcategoria.trim().isNotEmpty)
                _infoChip(
                  Icons.account_tree_outlined,
                  t.subcategoria,
                  color: LuvegiColors.secondary,
                ),
              _infoChip(
                Icons.priority_high_outlined,
                t.prioridad.trim().isEmpty ? 'Sin prioridad' : t.prioridad,
                color: t.prioridad.trim().isEmpty
                    ? LuvegiColors.textSecondary
                    : TicketUtils.colorPrioridad(t.prioridad, t.prioridadColor),
              ),
              _infoChip(
                Icons.person_pin_outlined,
                t.tecnico.isEmpty ? 'Sin asignar' : t.tecnico,
              ),
              if (t.fechaAsignacion != null)
                _infoChip(
                  Icons.assignment_ind_outlined,
                  'Asignado ${_formatearFecha(t.fechaAsignacion)}',
                ),
              _infoChip(Icons.person_outline, t.creador),
              _infoChip(
                Icons.event_outlined,
                _formatearFecha(t.creadoEn).isEmpty
                    ? ''
                    : 'Creado ${_formatearFecha(t.creadoEn)}',
              ),
              if (t.creadoEn != null)
                _infoChip(
                  Icons.timer_outlined,
                  _textoTiempoAtencion(),
                  color: t.fechaCierre != null
                      ? LuvegiColors.success
                      : LuvegiColors.warning,
                ),
            ],
          ),
          if (_mostrarAcciones) ...[
            const SizedBox(height: LuvegiSpacing.lg),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (widget.esAdminTickets)
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _editar,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                if (_puedeReabrir)
                  OutlinedButton.icon(
                    onPressed: _guardando
                        ? null
                        : () => _cambiarEstado(
                            'EN_ATENCION',
                            titulo: 'Reabrir ticket',
                            mensaje:
                                'El ticket volverá al estado “En atención” y la '
                                'conversación se reactivará. ¿Continuar?',
                          ),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Reabrir'),
                  ),
                if (widget.esAdminTickets || _esTecnico)
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _asignar,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Asignar técnico'),
                  ),
                if (widget.esAdminTickets)
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _cambiarPrioridad,
                    icon: const Icon(Icons.priority_high_rounded),
                    label: const Text('Cambiar prioridad'),
                  ),
                if (widget.esAdminTickets)
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _cambiarSubcategoria,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(
                      t.subcategoriaId > 0
                          ? 'Cambiar subcategoría'
                          : 'Asignar subcategoría',
                    ),
                  ),
                if (widget.esAdminTickets)
                  OutlinedButton.icon(
                    onPressed: _guardando
                        ? null
                        : () => _mostrarCambioEstado(t.estado),
                    icon: const Icon(Icons.change_circle_outlined),
                    label: const Text('Cambiar estado'),
                  ),
                if (_ticketCerrado)
                  OutlinedButton.icon(
                    onPressed: _descargandoInforme ? null : _descargarInforme,
                    icon: _descargandoInforme
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Informe PDF'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Estados disponibles en el menú "Cambiar estado". Se muestran todos
  /// siempre (incluido el actual) para poder elegir cualquiera.
  static const List<({String estado, String etiqueta})> _estadosDisponibles = [
    (estado: 'NUEVO', etiqueta: 'Nuevo'),
    (estado: 'EN_ATENCION', etiqueta: 'En atención'),
    (estado: 'ESPERA_USUARIO', etiqueta: 'Espera de respuesta de usuario'),
    (estado: 'ESPERA_PROVEEDOR', etiqueta: 'Espera de respuesta de proveedor'),
    (estado: 'ESPERA_VALIDACION', etiqueta: 'Validación de usuario'),
    (estado: 'CERRADO', etiqueta: 'Resuelto'),
    (estado: 'BLOQUEADO', etiqueta: 'Bloqueado'),
  ];

  Future<void> _mostrarCambioEstado(String estadoActual) async {
    final opciones = _estadosDisponibles;
    if (opciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este ticket no admite cambios de estado.'),
        ),
      );
      return;
    }

    final elegido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: LuvegiColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LuvegiSpacing.lg,
                  0,
                  LuvegiSpacing.lg,
                  LuvegiSpacing.sm,
                ),
                child: Text(
                  'Estado actual: ${TicketUtils.etiquetaEstado(estadoActual)}',
                  style: LuvegiText.caption,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final opcion in opciones)
                      ListTile(
                        leading: CircleAvatar(
                          radius: 8,
                          backgroundColor: TicketUtils.colorEstado(
                            opcion.estado,
                          ),
                        ),
                        title: Text(opcion.etiqueta),
                        trailing: opcion.estado == estadoActual
                            ? const Icon(
                                Icons.check_rounded,
                                color: LuvegiColors.success,
                              )
                            : null,
                        onTap: () => Navigator.pop(sheetContext, opcion.estado),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: LuvegiSpacing.sm),
            ],
          ),
        ),
      ),
    );

    if (elegido == null || !mounted) return;
    await _cambiarEstado(elegido);
  }

  Widget _infoChip(IconData icon, String texto, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? LuvegiColors.textSecondary),
        const SizedBox(width: 5),
        Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            color: color ?? LuvegiColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetalle() {
    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Descripción', style: LuvegiText.title),
          const SizedBox(height: LuvegiSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: LuvegiSpacing.md),
          Text(
            _detalle!.descripcion.isEmpty
                ? 'Sin descripción.'
                : _detalle!.descripcion,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjuntos() {
    final adjuntos = _detalle!.adjuntos;
    if (adjuntos.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adjuntos de la solicitud', style: LuvegiText.title),
          const SizedBox(height: LuvegiSpacing.sm),
          ...adjuntos.map(
            (a) => Material(
              color: LuvegiColors.surface,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.attach_file_rounded,
                  color: LuvegiColors.secondary,
                ),
                title: Text(
                  a.nombreArchivo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Abrir',
                  onPressed: () => _abrirAdjunto(tipo: 'ticket', id: a.id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversacion() {
    return Container(
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
              const Icon(
                Icons.forum_outlined,
                size: 20,
                color: LuvegiColors.secondary,
              ),
              const SizedBox(width: 8),
              const Text('Conversación', style: LuvegiText.title),
              const Spacer(),
              if (_cargandoMensajes)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                if (_ultimaActualizacion != null)
                  Text(_textoActualizado(), style: LuvegiText.caption),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _cargarMensajes(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Actualizar conversación',
                  visualDensity: VisualDensity.compact,
                  color: LuvegiColors.secondary,
                ),
              ],
            ],
          ),
          const SizedBox(height: LuvegiSpacing.md),
          if (_mensajes.isEmpty && !_cargandoMensajes)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: LuvegiSpacing.md),
              child: Text(
                'Aún no hay mensajes. Escribe abajo para iniciar la conversación con el soporte de TI.',
                style: TextStyle(color: LuvegiColors.textSecondary),
              ),
            )
          else
            ..._buildMensajesAgrupados(),
        ],
      ),
    );
  }

  /// Construye la conversación agrupando mensajes consecutivos del mismo
  /// autor e insertando un separador cuando cambia el día.
  List<Widget> _buildMensajesAgrupados() {
    final widgets = <Widget>[];
    DateTime? diaActual;
    int? autorAnterior;

    for (final m in _mensajes) {
      final dia = m.creadoEn == null
          ? null
          : DateTime(m.creadoEn!.year, m.creadoEn!.month, m.creadoEn!.day);
      if (dia != null && (diaActual == null || dia != diaActual)) {
        widgets.add(_buildSeparadorDia(dia));
        diaActual = dia;
        autorAnterior = null;
      }

      final esMismoAutor = autorAnterior == m.autorId;
      widgets.add(_buildBurbuja(m, compacta: esMismoAutor));
      autorAnterior = m.autorId;
    }
    return widgets;
  }

  Widget _buildSeparadorDia(DateTime dia) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final ayer = hoy.subtract(const Duration(days: 1));
    final String etiqueta;
    if (dia == hoy) {
      etiqueta = 'Hoy';
    } else if (dia == ayer) {
      etiqueta = 'Ayer';
    } else {
      etiqueta = _formatearDia(dia);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LuvegiSpacing.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              etiqueta,
              style: LuvegiText.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Color _colorAvatar(String rol) {
    switch (rol) {
      case 'SOPORTE':
        return LuvegiColors.secondary;
      default:
        return LuvegiColors.secondaryLight;
    }
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primera = partes.first.substring(0, 1).toUpperCase();
    if (partes.length == 1) return primera;
    final ultima = partes.last.substring(0, 1).toUpperCase();
    return '$primera$ultima';
  }

  Widget _buildBurbuja(TicketMensaje m, {bool compacta = false}) {
    final esSoporte = m.rol == 'SOPORTE';
    final colorFondo = m.esMio
        ? LuvegiColors.secondary
        : LuvegiColors.surfaceHover;
    final colorTexto = m.esMio ? Colors.white : LuvegiColors.textPrimary;
    final colorSutil = m.esMio
        ? Colors.white.withValues(alpha: 0.85)
        : LuvegiColors.textSecondary;
    final autor = m.autor.isEmpty
        ? (esSoporte ? 'Soporte TI' : 'Usuario')
        : m.autor;

    return Row(
      mainAxisAlignment: m.esMio
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!m.esMio) ...[
          if (compacta)
            const SizedBox(width: 36)
          else
            CircleAvatar(
              radius: 18,
              backgroundColor: _colorAvatar(m.rol),
              child: Text(
                _iniciales(autor),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: EdgeInsets.only(
              bottom: compacta ? 4 : LuvegiSpacing.md,
              top: compacta ? 0 : 0,
            ),
            padding: const EdgeInsets.all(LuvegiSpacing.md),
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(LuvegiRadius.md),
              border: m.esMio ? null : Border.all(color: LuvegiColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compacta)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        autor,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorTexto,
                        ),
                      ),
                      if (esSoporte) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorSutil.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Soporte TI',
                            style: TextStyle(fontSize: 10, color: colorSutil),
                          ),
                        ),
                      ],
                    ],
                  ),
                if (m.mensaje.trim().isNotEmpty) ...[
                  if (!compacta) const SizedBox(height: 8),
                  Text(
                    m.mensaje,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: colorTexto,
                    ),
                  ),
                ] else if (m.adjuntos.isNotEmpty) ...[
                  if (!compacta) const SizedBox(height: 8),
                  Text(
                    'Archivo adjunto',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: colorSutil,
                    ),
                  ),
                ],
                if (m.adjuntos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: m.adjuntos
                        .map((a) => _buildChipAdjunto(a, esMio: m.esMio))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _formatearFecha(m.creadoEn),
                  style: TextStyle(fontSize: 11, color: colorSutil),
                ),
              ],
            ),
          ),
        ),
        if (m.esMio) const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildChipAdjunto(TicketMensajeAdjunto a, {required bool esMio}) {
    final fondo = esMio
        ? Colors.white.withValues(alpha: 0.22)
        : LuvegiColors.secondaryLight.withValues(alpha: 0.12);
    final borde = esMio
        ? Colors.white.withValues(alpha: 0.45)
        : LuvegiColors.secondaryLight.withValues(alpha: 0.5);
    final colorIcono = esMio ? Colors.white : LuvegiColors.secondary;
    final colorTexto = esMio ? Colors.white : LuvegiColors.textPrimary;

    return Material(
      color: fondo,
      shape: StadiumBorder(side: BorderSide(color: borde)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirAdjunto(tipo: 'mensaje', id: a.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_file_rounded, size: 16, color: colorIcono),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  a.nombreArchivo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorTexto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotasInternas() {
    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: BoxDecoration(
        color: LuvegiColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: LuvegiColors.warning,
              ),
              const SizedBox(width: 8),
              const Text(
                'Acciones realizadas (solo TI)',
                style: LuvegiText.title,
              ),
              const Spacer(),
              if (_cargandoNotas)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Estas acciones no son visibles para el usuario que creó el ticket.',
            style: LuvegiText.caption,
          ),
          const SizedBox(height: LuvegiSpacing.md),
          if (_notas.isEmpty && !_cargandoNotas)
            const Padding(
              padding: EdgeInsets.only(bottom: LuvegiSpacing.md),
              child: Text(
                'Aún no hay acciones registradas.',
                style: TextStyle(color: LuvegiColors.textSecondary),
              ),
            )
          else
            ..._notas.map(_buildNota),
          const SizedBox(height: LuvegiSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildSelectorCampo(
                  label: 'Fecha inicio',
                  valor: _formatearDia(_notaFechaInicio),
                  vacio: _notaFechaInicio == null,
                  icono: Icons.calendar_today_outlined,
                  onTap: () => _elegirFechaNota(inicio: true),
                  onClear: _notaFechaInicio == null
                      ? null
                      : () => setState(() => _notaFechaInicio = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSelectorCampo(
                  label: 'Fecha fin',
                  valor: _formatearDia(_notaFechaFin),
                  vacio: _notaFechaFin == null,
                  icono: Icons.calendar_today_outlined,
                  onTap: () => _elegirFechaNota(inicio: false),
                  onClear: _notaFechaFin == null
                      ? null
                      : () => setState(() => _notaFechaFin = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildSelectorCampo(
                  label: 'Hora inicio',
                  valor: _formatearHora(_notaHoraInicio),
                  vacio: _notaHoraInicio == null,
                  icono: Icons.schedule_outlined,
                  onTap: () => _elegirHora(inicio: true),
                  onClear: _notaHoraInicio == null
                      ? null
                      : () => setState(() => _notaHoraInicio = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSelectorCampo(
                  label: 'Hora fin',
                  valor: _formatearHora(_notaHoraFin),
                  vacio: _notaHoraFin == null,
                  icono: Icons.schedule_outlined,
                  onTap: () => _elegirHora(inicio: false),
                  onClear: _notaHoraFin == null
                      ? null
                      : () => setState(() => _notaHoraFin = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          TextField(
            controller: _notaCtrl,
            enabled: !_guardandoNota,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Registra lo que se ha realizado en este ticket…',
            ),
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _guardandoNota ? null : _agregarNota,
              icon: _guardandoNota
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.note_add_outlined, size: 18),
              label: const Text('Agregar acción'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LuvegiColors.warning,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNota(TicketNota n) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: LuvegiSpacing.md),
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.support_agent,
                size: 15,
                color: LuvegiColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  n.autor.isEmpty ? 'Soporte TI' : n.autor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LuvegiColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatearFecha(n.creadoEn), style: LuvegiText.caption),
            ],
          ),
          const SizedBox(height: 6),
          if (_textoPeriodo(n).isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.date_range_outlined,
                  size: 14,
                  color: LuvegiColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Periodo: ${_textoPeriodo(n)}',
                    style: LuvegiText.caption,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text(n.nota, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildActividad() {
    final historial = _detalle!.historial;
    return Material(
      color: LuvegiColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        side: const BorderSide(color: LuvegiColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: LuvegiSpacing.lg,
          vertical: LuvegiSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          LuvegiSpacing.lg,
          0,
          LuvegiSpacing.lg,
          LuvegiSpacing.lg,
        ),
        leading: const Icon(
          Icons.history_rounded,
          color: LuvegiColors.secondary,
        ),
        title: const Text('Actividad del ticket', style: LuvegiText.title),
        subtitle: historial.isEmpty
            ? null
            : Text(
                historial.length == 1
                    ? '1 movimiento'
                    : '${historial.length} movimientos',
                style: LuvegiText.caption,
              ),
        children: [
          if (historial.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sin movimientos.',
                style: TextStyle(color: LuvegiColors.textSecondary),
              ),
            )
          else
            ..._buildTimeline(historial),
        ],
      ),
    );
  }

  /// Construye una línea de tiempo vertical con un nodo por movimiento.
  List<Widget> _buildTimeline(List<Map<String, dynamic>> historial) {
    final total = historial.length;
    // Se muestran del más reciente al más antiguo.
    final ordenado = historial.reversed.toList();
    final widgets = <Widget>[];

    for (var i = 0; i < total; i++) {
      final h = ordenado[i];
      final accion = (h['accion'] ?? '').toString();
      final descripcion = (h['descripcion'] ?? '').toString();
      final usuario = (h['usuario'] ?? '').toString();
      final fecha = _formatearFechaAmigable(
        h['created_at'] ?? h['fecha'] ?? '',
      );
      final color = _colorAccion(accion);
      final esUltimo = i == total - 1;

      widgets.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(_iconoAccion(accion), size: 14, color: color),
                    ),
                    if (!esUltimo)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          color: LuvegiColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: esUltimo ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _etiquetaAccion(accion),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      if (descripcion.isNotEmpty &&
                          descripcion != _etiquetaAccion(accion)) ...[
                        const SizedBox(height: 3),
                        Text(
                          descripcion,
                          style: const TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 12,
                            color: LuvegiColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              usuario.isEmpty ? 'Sistema' : usuario,
                              style: LuvegiText.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.schedule,
                            size: 12,
                            color: LuvegiColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(fecha, style: LuvegiText.caption),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  IconData _iconoAccion(String accion) {
    final a = accion.toUpperCase();
    if (a.contains('CREAD') || a == 'TICKET_CREADO')
      return Icons.add_circle_outline;
    if (a.contains('CERRADO')) return Icons.check_circle_outline;
    if (a.contains('REABIERTO')) return Icons.lock_open_rounded;
    if (a.contains('ASIGNAD')) return Icons.person_add_alt_1_outlined;
    if (a.contains('COMENTARIO') || a.contains('MENSAJE'))
      return Icons.chat_bubble_outline;
    if (a.contains('ADJUNT')) return Icons.attach_file_rounded;
    if (a.contains('BLOQUEADO')) return Icons.block;
    if (a.contains('ESPERA')) return Icons.hourglass_empty_rounded;
    if (a.contains('PRIORIDAD')) return Icons.flag_outlined;
    if (a.contains('ESTADO')) return Icons.sync_alt_rounded;
    return Icons.circle_outlined;
  }

  String _etiquetaAccion(String accion) {
    final a = accion.toUpperCase();
    if (a.contains('CREADO') || a.contains('CREAD')) return 'Ticket creado';
    if (a.contains('REABIERTO')) return 'Ticket reabierto';
    if (a.contains('ASIGNAD')) return 'Técnico asignado';
    if (a.contains('COMENTARIO') || a.contains('MENSAJE'))
      return 'Comentario agregado';
    if (a.contains('ADJUNT')) return 'Adjunto agregado';
    if (a.contains('PRIORIDAD')) return 'Prioridad modificada';
    if (a.startsWith('ESTADO_')) {
      final estado = a.substring('ESTADO_'.length);
      return 'Estado: ${TicketUtils.etiquetaEstado(estado)}';
    }
    return accion
        .replaceAll('_', ' ')
        .toLowerCase()
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());
  }

  Color _colorAccion(String accion) {
    final a = accion.toUpperCase();
    if (a.contains('CERRADO')) return LuvegiColors.success;
    if (a.contains('REABIERTO')) return LuvegiColors.warning;
    if (a.contains('BLOQUEADO')) return LuvegiColors.error;
    if (a.contains('ESPERA')) return LuvegiColors.warning;
    if (a.contains('CREADO') || a.contains('CREAD'))
      return LuvegiColors.secondary;
    return LuvegiColors.secondaryLight;
  }

  String _formatearFechaAmigable(dynamic valor) {
    final texto = valor.toString().trim();
    if (texto.isEmpty) return '';
    final parsed = DateTime.tryParse(texto.replaceAll(' ', 'T'));
    if (parsed == null) return texto;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(parsed.year, parsed.month, parsed.day);
    String dos(int n) => n.toString().padLeft(2, '0');
    final hora = '${dos(parsed.hour)}:${dos(parsed.minute)}';
    if (dia == hoy) return 'Hoy $hora';
    if (dia == hoy.subtract(const Duration(days: 1))) return 'Ayer $hora';
    return '${dos(parsed.day)}/${dos(parsed.month)}/${parsed.year} $hora';
  }

  Widget _buildComposer(bool mobile) {
    if (_ticketCerrado) {
      return Container(
        decoration: const BoxDecoration(
          color: LuvegiColors.surface,
          border: Border(top: BorderSide(color: LuvegiColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? LuvegiSpacing.md : LuvegiSpacing.xl,
              vertical: LuvegiSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: LuvegiColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Este ticket está resuelto. La conversación ya no admite mensajes.',
                    style: LuvegiText.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: LuvegiColors.surface,
        border: Border(top: BorderSide(color: LuvegiColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? LuvegiSpacing.md : LuvegiSpacing.xl,
            vertical: LuvegiSpacing.md,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_permitirAdjuntos && _adjuntosPendientes.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _adjuntosPendientes.asMap().entries.map((e) {
                        return InputChip(
                          avatar: const Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: LuvegiColors.textPrimary,
                          ),
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              e.value.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onDeleted: _enviando
                              ? null
                              : () => _quitarAdjunto(e.key),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: LuvegiSpacing.sm),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_permitirAdjuntos) ...[
                        IconButton(
                          onPressed: _enviando ? null : _agregarAdjuntos,
                          icon: const Icon(Icons.attach_file_rounded),
                          tooltip: 'Adjuntar archivo',
                          color: LuvegiColors.secondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _mensajeCtrl,
                          enabled: !_enviando,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Escribe una respuesta…',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _enviando ? null : _enviarMensaje,
                        icon: _enviando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: mobile
                            ? const SizedBox.shrink()
                            : const Text('Enviar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LuvegiColors.secondary,
                          foregroundColor: Colors.white,
                          padding: mobile
                              ? const EdgeInsets.all(14)
                              : const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                        ),
                      ),
                    ],
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
