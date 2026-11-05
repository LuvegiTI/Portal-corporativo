import 'dart:async';

import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/ticket_service.dart';
import '../../services/ticket_unread_store.dart';
import 'detalle_ticket_page.dart';

class ConsultarTicketsPage extends StatefulWidget {
  final String token;
  final List<String> permisos;
  final bool esAdminTickets;
  final bool puedeExportar;
  final VoidCallback onRegistrarTicket;

  const ConsultarTicketsPage({
    super.key,
    required this.token,
    required this.permisos,
    this.esAdminTickets = false,
    this.puedeExportar = false,
    required this.onRegistrarTicket,
  });

  @override
  State<ConsultarTicketsPage> createState() => _ConsultarTicketsPageState();
}

class _ConsultarTicketsPageState extends State<ConsultarTicketsPage> {
  final TextEditingController _busquedaCtrl = TextEditingController();
  final TicketService _service = TicketService();
  final ScrollController _hScrollCtrl = ScrollController();

  String? _estado;
  String? _prioridad;
  int? _categoriaId;
  int? _tecnicoId;
  DateTime? _desde;
  DateTime? _hasta;
  String _vistaRapida = 'todas';

  List<TicketCategoria> _categorias = [];
  List<TicketTecnico> _tecnicos = [];

  List<TicketItem> _tickets = [];
  Set<String> _noLeidos = {};
  bool _cargando = true;
  bool _refrescando = false;
  bool _exportando = false;
  Timer? _timer;
  Timer? _ticker;
  Timer? _debounce;
  DateTime? _ultimaActualizacion;

  static const int _pageSize = 20;
  int _pagina = 1;
  int _totalPaginas = 1;
  int _totalRegistros = 0;

  @override
  void initState() {
    super.initState();
    _cargarTickets();
    _cargarCatalogos();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _consultar(mostrarCarga: false),
    );
    _ticker = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (mounted && _ultimaActualizacion != null) setState(() {});
      },
    );
  }

  Future<void> _cargarCatalogos() async {
    try {
      final categorias = await _service.listarCategorias(token: widget.token);
      final tecnicos = widget.esAdminTickets
          ? await _service.listarTecnicos(token: widget.token)
          : <TicketTecnico>[];
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _tecnicos = tecnicos;
      });
    } catch (_) {
      // Silencioso: los filtros de catálogo son opcionales.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker?.cancel();
    _debounce?.cancel();
    _hScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTickets() {
    _pagina = 1;
    return _consultar(mostrarCarga: true);
  }

  Future<void> _consultar({required bool mostrarCarga}) async {
    if (_refrescando) return;
    _refrescando = true;
    if (mostrarCarga && mounted) setState(() => _cargando = true);
    try {
      final response = await _service.consultarTickets(
        token: widget.token,
        page: _pagina,
        pageSize: _pageSize,
        filtros: {
          'busqueda': _busquedaCtrl.text.trim(),
          'estado': _estado,
          'prioridad': _prioridad,
          'categoria_id': _categoriaId?.toString(),
          'tecnico_id': _tecnicoId?.toString(),
          'desde': _fechaISO(_desde),
          'hasta': _fechaISO(_hasta),
        },
      );
      final raw = response['data'] as List<dynamic>? ?? const [];
      final totalRaw = response['total'] ?? response['total_registros'];
      final total = totalRaw is num ? totalRaw.toInt() : 0;
      final tickets = raw
          .whereType<Map>()
          .map((e) => TicketItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final vistos = await TicketUnreadStore.ultimosVistos();
      final noLeidos = <String>{
        for (final t in tickets)
          if (t.ultimoMensajeId > 0 &&
              !t.ultimoMensajeMio &&
              t.ultimoMensajeId > (vistos[t.codigo] ?? 0))
            t.codigo,
      };
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _noLeidos = noLeidos;
        _totalRegistros = total;
        _totalPaginas = total <= 0 ? 1 : (total / _pageSize).ceil();
        _ultimaActualizacion = DateTime.now();
      });
    } catch (e) {
      if (mostrarCarga && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is TicketApiException ? e.message : 'Error al cargar tickets.',
            ),
          ),
        );
      }
    } finally {
      _refrescando = false;
      if (mounted && mostrarCarga) setState(() => _cargando = false);
    }
  }

  void _cambiarPagina(int nueva) {
    setState(() => _pagina = nueva);
    _consultar(mostrarCarga: true);
  }

  String? _fechaISO(DateTime? fecha) {
    if (fecha == null) return null;
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  String _formatearDia(DateTime? fecha) {
    if (fecha == null) return '';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
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

  Future<void> _elegirFecha({required bool desde}) async {
    final ahora = DateTime.now();
    final base = (desde ? _desde : _hasta) ?? ahora;
    final elegida = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(ahora.year - 5),
      lastDate: DateTime(ahora.year + 5),
    );
    if (elegida == null || !mounted) return;
    setState(() {
      if (desde) {
        _desde = elegida;
        if (_hasta != null && _hasta!.isBefore(elegida)) _hasta = elegida;
      } else {
        _hasta = elegida;
        if (_desde != null && elegida.isBefore(_desde!)) _desde = elegida;
      }
    });
  }

  String _valor(Map<String, dynamic> fila, List<String> claves) {
    for (final clave in claves) {
      final valor = fila[clave];
      if (valor != null && valor.toString().trim().isNotEmpty) {
        return _celdaSegura(valor.toString());
      }
    }
    return '';
  }

  /// Evita que Excel interprete como fórmula un texto que empieza con
  /// = + - @ (inyección de fórmulas). Se antepone un apóstrofo.
  String _celdaSegura(String texto) {
    final t = texto.trimLeft();
    if (t.isEmpty) return texto;
    if (t.startsWith('=') ||
        t.startsWith('+') ||
        t.startsWith('-') ||
        t.startsWith('@')) {
      return "'$texto";
    }
    return texto;
  }

  Future<void> _exportarExcel() async {
    if (_exportando) return;

    if (!widget.puedeExportar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para exportar los tickets.')),
      );
      return;
    }

    setState(() => _exportando = true);
    try {
      const int tamano = 500;
      final List<Map<String, dynamic>> todas = [];
      int pagina = 1;
      int totalPaginas = 1;

      while (pagina <= totalPaginas) {
        final response = await _service.consultarTickets(
          token: widget.token,
          page: pagina,
          pageSize: tamano,
          filtros: {
            'busqueda': _busquedaCtrl.text.trim(),
            'estado': _estado,
            'prioridad': _prioridad,
            'categoria_id': _categoriaId?.toString(),
            'tecnico_id': _tecnicoId?.toString(),
            'desde': _fechaISO(_desde),
            'hasta': _fechaISO(_hasta),
          },
        );
        if (!mounted) return;
        final raw = response['data'] as List<dynamic>? ?? const [];
        todas.addAll(
          raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
        final totalRaw = response['total'] ?? response['total_registros'];
        final total = totalRaw is num ? totalRaw.toInt() : 0;
        totalPaginas = total <= 0 ? 1 : (total / tamano).ceil();
        if (raw.isEmpty) break;
        pagina++;
      }

      if (todas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay registros para exportar.')),
          );
        }
        return;
      }

      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Tickets'];
      excel.delete('Sheet1');

      sheet.appendRow([
        excel_lib.TextCellValue('Código'),
        excel_lib.TextCellValue('Asunto'),
        excel_lib.TextCellValue('Categoría'),
        excel_lib.TextCellValue('Prioridad'),
        excel_lib.TextCellValue('Estado'),
        excel_lib.TextCellValue('Técnico'),
        excel_lib.TextCellValue('Creador'),
        excel_lib.TextCellValue('Fecha creación'),
        excel_lib.TextCellValue('Fecha resolución'),
      ]);

      for (final r in todas) {
        sheet.appendRow([
          excel_lib.TextCellValue(_valor(r, const ['codigo'])),
          excel_lib.TextCellValue(_valor(r, const ['asunto'])),
          excel_lib.TextCellValue(_valor(r, const ['categoria'])),
          excel_lib.TextCellValue(_valor(r, const ['prioridad'])),
          excel_lib.TextCellValue(
            TicketUtils.etiquetaEstado(_valor(r, const ['estado'])),
          ),
          excel_lib.TextCellValue(_valor(r, const ['tecnico'])),
          excel_lib.TextCellValue(_valor(r, const ['creador'])),
          excel_lib.TextCellValue(_valor(r, const ['created_at'])),
          excel_lib.TextCellValue(_valor(r, const ['fecha_cierre'])),
        ]);
      }

      final fecha = DateTime.now();
      String dos(int n) => n.toString().padLeft(2, '0');
      final nombreArchivo =
          'Tickets_${fecha.year}${dos(fecha.month)}${dos(fecha.day)}'
          '_${dos(fecha.hour)}${dos(fecha.minute)}.xlsx';

      if (kIsWeb) {
        excel.save(fileName: nombreArchivo);
      } else {
        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileSaver.instance.saveFile(
            name: nombreArchivo.replaceAll('.xlsx', ''),
            bytes: Uint8List.fromList(fileBytes),
            ext: 'xlsx',
            mimeType: MimeType.microsoftExcel,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se exportaron ${todas.length} tickets a Excel.'),
            backgroundColor: LuvegiColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is TicketApiException ? e.message : 'No se pudo exportar.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _abrirDetalle(TicketItem ticket) async {
    final resultado = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => DetalleTicketPage(
          token: widget.token,
          codigo: ticket.codigo,
          esAdminTickets: widget.esAdminTickets,
        ),
      ),
    );
    if (resultado == true && mounted) {
      _cargarTickets();
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
            constraints: const BoxConstraints(maxWidth: 1350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mobile) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tickets', style: LuvegiText.heading),
                      const SizedBox(height: 2),
                      Text(
                        'Gestiona las solicitudes de soporte',
                        style: LuvegiText.caption,
                      ),
                      const SizedBox(height: LuvegiSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onRegistrarTicket,
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Nuevo ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LuvegiColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tickets', style: LuvegiText.heading),
                            const SizedBox(height: 2),
                            Text(
                              'Gestiona las solicitudes de soporte',
                              style: LuvegiText.caption,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: widget.onRegistrarTicket,
                        icon: const Icon(Icons.add_comment_outlined),
                        label: const Text('Nuevo ticket'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LuvegiColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: LuvegiSpacing.lg),
                _buildVistasRapidas(),
                const SizedBox(height: LuvegiSpacing.md),
                _buildFiltros(mobile),
                if (widget.esAdminTickets &&
                    !_cargando &&
                    _urgentesSinAsignarCount > 0 &&
                    _vistaRapida != 'urgentes') ...[
                  const SizedBox(height: LuvegiSpacing.md),
                  _buildAlertaUrgentes(),
                ],
                const SizedBox(height: LuvegiSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_ultimaActualizacion != null && !_cargando) ...[
                      Flexible(
                        child: Text(
                          _textoActualizado(),
                          style: LuvegiText.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _cargarTickets,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: 'Actualizar',
                        visualDensity: VisualDensity.compact,
                        color: LuvegiColors.secondary,
                      ),
                    ],
                    const Spacer(),
                    Flexible(
                      child: Text(
                        _totalRegistros == 0
                            ? ''
                            : _vistaRapida == 'todas'
                            ? '$_totalRegistros tickets · Página $_pagina de $_totalPaginas'
                            : '${_ticketsVisibles.length} de $_totalRegistros tickets',
                        style: LuvegiText.caption,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LuvegiSpacing.xs),
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.all(LuvegiSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _buildTabla(mobile),
                  if (_totalRegistros > _pageSize)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: LuvegiSpacing.md,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$_totalRegistros registros · Página $_pagina de $_totalPaginas',
                            style: LuvegiText.caption,
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _pagina > 1
                                    ? () => _cambiarPagina(_pagina - 1)
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _pagina < _totalPaginas
                                    ? () => _cambiarPagina(_pagina + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoBusqueda() => TextField(
    controller: _busquedaCtrl,
    onChanged: _onBusquedaCambia,
    onSubmitted: (_) => _cargarTickets(),
    decoration: InputDecoration(
      labelText: 'Buscar por código o asunto',
      suffixIcon: _busquedaCtrl.text.isEmpty
          ? const Icon(Icons.search)
          : IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Limpiar búsqueda',
              onPressed: () {
                _busquedaCtrl.clear();
                _debounce?.cancel();
                _cargarTickets();
              },
            ),
    ),
  );

  void _onBusquedaCambia(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _cargarTickets();
    });
    setState(() {});
  }

  Widget _campoEstado() => DropdownButtonFormField<String>(
    initialValue: _estado,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Estado'),
    items: [
      const DropdownMenuItem(value: null, child: Text('Todos')),
      ...TicketUtils.estados.map((e) {
        final parts = e.split('|');
        return DropdownMenuItem(value: parts[0], child: Text(parts[1]));
      }),
    ],
    onChanged: (v) => setState(() => _estado = v),
  );

  Widget _campoPrioridad() => DropdownButtonFormField<String>(
    initialValue: _prioridad,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Prioridad'),
    items: const [
      DropdownMenuItem(value: null, child: Text('Todas')),
      DropdownMenuItem(value: 'Alta', child: Text('Alta')),
      DropdownMenuItem(value: 'Media', child: Text('Media')),
      DropdownMenuItem(value: 'Baja', child: Text('Baja')),
    ],
    onChanged: (v) => setState(() => _prioridad = v),
  );

  Widget _campoCategoria() => DropdownButtonFormField<int>(
    initialValue: _categoriaId,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Categoría'),
    items: [
      const DropdownMenuItem(value: null, child: Text('Todas')),
      ..._categorias.map(
        (c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)),
      ),
    ],
    onChanged: (v) => setState(() => _categoriaId = v),
  );

  Widget _campoTecnico() => DropdownButtonFormField<int>(
    initialValue: _tecnicoId,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Técnico'),
    items: [
      const DropdownMenuItem(value: null, child: Text('Todos')),
      ..._tecnicos.map(
        (t) => DropdownMenuItem(value: t.id, child: Text(t.nombre)),
      ),
    ],
    onChanged: (v) => setState(() => _tecnicoId = v),
  );

  Widget _botonesFiltros() => Wrap(
    alignment: WrapAlignment.end,
    spacing: 10,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () {
          _busquedaCtrl.clear();
          setState(() {
            _estado = null;
            _prioridad = null;
            _categoriaId = null;
            _tecnicoId = null;
            _desde = null;
            _hasta = null;
          });
          _cargarTickets();
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Actualizar'),
      ),
      if (widget.puedeExportar)
        OutlinedButton.icon(
          onPressed: (_cargando || _exportando) ? null : _exportarExcel,
          icon: _exportando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(_exportando ? 'Exportando...' : 'Exportar Excel'),
        ),
      ElevatedButton.icon(
        onPressed: _cargarTickets,
        icon: const Icon(Icons.search),
        label: const Text('Buscar'),
        style: ElevatedButton.styleFrom(
          backgroundColor: LuvegiColors.secondaryLight,
          foregroundColor: Colors.white,
        ),
      ),
    ],
  );

  /// Accesos rápidos que aplican una combinación habitual de filtros.
  static const List<({String id, String etiqueta, IconData icono})>
  _vistasRapidasDef = [
    (id: 'todas', etiqueta: 'Todas', icono: Icons.list_alt_rounded),
    (id: 'sin_asignar', etiqueta: 'Sin asignar', icono: Icons.person_off_outlined),
    (id: 'altas', etiqueta: 'Altas abiertas', icono: Icons.local_fire_department_outlined),
    (id: 'sin_cerrar', etiqueta: 'Abiertos', icono: Icons.mark_email_unread_outlined),
  ];

  void _aplicarVistaRapida(String id) {
    setState(() {
      _vistaRapida = id;
      _estado = null;
      _prioridad = null;
      _tecnicoId = null;
      switch (id) {
        case 'altas':
          _prioridad = 'Alta';
          break;
        default:
          break;
      }
    });
    _cargarTickets();
  }

  bool _ticketUrgenteSinAsignar(TicketItem t) =>
      t.prioridad.trim().toLowerCase() == 'alta' &&
      t.tecnico.trim().isEmpty &&
      t.estado != 'CERRADO';

  /// Lista final según la vista rápida seleccionada (algunos filtros de
  /// nicho se aplican en cliente sobre la página cargada).
  List<TicketItem> get _ticketsVisibles {
    switch (_vistaRapida) {
      case 'sin_asignar':
        return _tickets.where((t) => t.tecnico.trim().isEmpty).toList();
      case 'urgentes':
        return _tickets.where(_ticketUrgenteSinAsignar).toList();
      case 'sin_cerrar':
        return _tickets.where((t) => t.estado != 'CERRADO').toList();
      default:
        return _tickets;
    }
  }

  int get _urgentesSinAsignarCount =>
      _tickets.where(_ticketUrgenteSinAsignar).length;

  Widget _buildVistasRapidas() {
    final vistas = _vistasRapidasDef.where((v) {
      if (widget.esAdminTickets) return true;
      // Las vistas de seguimiento operativo son solo para el personal de TI.
      return v.id != 'sin_asignar';
    });
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final vista in vistas)
          ChoiceChip(
            selected: _vistaRapida == vista.id,
            onSelected: (_) => _aplicarVistaRapida(vista.id),
            avatar: Icon(
              vista.icono,
              size: 16,
              color: _vistaRapida == vista.id
                  ? Colors.white
                  : LuvegiColors.textSecondary,
            ),
            label: Text(vista.etiqueta),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _vistaRapida == vista.id
                  ? Colors.white
                  : LuvegiColors.textPrimary,
            ),
            selectedColor: LuvegiColors.secondary,
            backgroundColor: LuvegiColors.surface,
            side: const BorderSide(color: LuvegiColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertaUrgentes() {
    final n = _urgentesSinAsignarCount;
    return Material(
      color: LuvegiColors.error.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        onTap: () => _aplicarVistaRapida('urgentes'),
        child: Container(
          padding: const EdgeInsets.all(LuvegiSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LuvegiRadius.lg),
            border: Border.all(
              color: LuvegiColors.error.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: LuvegiColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n == 1
                      ? 'Hay 1 ticket de prioridad Alta sin asignar.'
                      : 'Hay $n tickets de prioridad Alta sin asignar.',
                  style: TextStyle(
                    color: LuvegiColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _aplicarVistaRapida('urgentes'),
                style: TextButton.styleFrom(
                  foregroundColor: LuvegiColors.error,
                ),
                child: const Text('Ver urgentes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltros(bool mobile) => Container(
    padding: const EdgeInsets.all(LuvegiSpacing.lg),
    decoration: BoxDecoration(
      color: LuvegiColors.surface,
      borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      border: Border.all(color: LuvegiColors.border),
    ),
    child: Column(
      children: [
        if (mobile) ...[
          _campoBusqueda(),
          const SizedBox(height: LuvegiSpacing.md),
          _campoEstado(),
          const SizedBox(height: LuvegiSpacing.md),
          _campoPrioridad(),
          const SizedBox(height: LuvegiSpacing.md),
          _campoCategoria(),
          if (widget.esAdminTickets) ...[
            const SizedBox(height: LuvegiSpacing.md),
            _campoTecnico(),
          ],
          const SizedBox(height: LuvegiSpacing.md),
          Row(
            children: [
              Expanded(child: _dateFilterField(desde: true)),
              const SizedBox(width: 10),
              Expanded(child: _dateFilterField(desde: false)),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(flex: 2, child: _campoBusqueda()),
              const SizedBox(width: 10),
              Expanded(child: _campoEstado()),
              const SizedBox(width: 10),
              Expanded(child: _campoPrioridad()),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.md),
          Row(
            children: [
              Expanded(child: _campoCategoria()),
              if (widget.esAdminTickets) ...[
                const SizedBox(width: 10),
                Expanded(child: _campoTecnico()),
              ],
              const SizedBox(width: 10),
              Expanded(child: _dateFilterField(desde: true)),
              const SizedBox(width: 10),
              Expanded(child: _dateFilterField(desde: false)),
            ],
          ),
        ],
        const SizedBox(height: LuvegiSpacing.md),
        _botonesFiltros(),
      ],
    ),
  );

  Widget _dateFilterField({required bool desde}) {
    final fecha = desde ? _desde : _hasta;
    return InkWell(
      onTap: () => _elegirFecha(desde: desde),
      borderRadius: BorderRadius.circular(LuvegiRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: desde ? 'Desde' : 'Hasta',
          isDense: true,
          suffixIcon: fecha == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() {
                    if (desde) {
                      _desde = null;
                    } else {
                      _hasta = null;
                    }
                  }),
                  tooltip: 'Quitar',
                ),
        ),
        child: Text(
          fecha == null ? 'Sin definir' : _formatearDia(fecha),
          style: TextStyle(
            color: fecha == null
                ? LuvegiColors.textSecondary
                : LuvegiColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTabla(bool mobile) {
    final visibles = _ticketsVisibles;
    if (visibles.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: LuvegiColors.surface,
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
          border: Border.all(color: LuvegiColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(LuvegiSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                size: 42,
                color: LuvegiColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                _tickets.isEmpty
                    ? 'No tienes tickets registrados.'
                    : 'Ningún ticket coincide con esta vista.',
                style: const TextStyle(color: LuvegiColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (mobile) return _buildTarjetas();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Scrollbar(
        controller: _hScrollCtrl,
        thumbVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          controller: _hScrollCtrl,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 14),
          child: DataTable(
            dataRowMinHeight: 52,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStatePropertyAll(
              LuvegiColors.surfaceHover,
            ),
            columns: const [
              DataColumn(label: Text('Acción')),
              DataColumn(label: Text('Código')),
              DataColumn(label: Text('Asunto')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Prioridad')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Técnico')),
              DataColumn(label: Text('Fecha')),
            ],
            rows: _ticketsVisibles.map((t) {
              final urgente =
                  widget.esAdminTickets && _ticketUrgenteSinAsignar(t);
              return DataRow(
                color: urgente
                    ? WidgetStatePropertyAll(
                        LuvegiColors.error.withValues(alpha: 0.05),
                      )
                    : null,
                cells: [
                  DataCell(
                    OutlinedButton(
                      onPressed: () => _abrirDetalle(t),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LuvegiColors.secondary,
                      ),
                      child: const Text('Ver'),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        if (_noLeidos.contains(t.codigo)) ...[
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: LuvegiColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          t.codigo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _noLeidos.contains(t.codigo)
                                ? LuvegiColors.textPrimary
                                : null,
                          ),
                        ),
                        if (urgente) ...[
                          const SizedBox(width: 6),
                          _badgeUrgente(),
                        ],
                      ],
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        t.asunto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(t.categoria)),
                  DataCell(
                    _etiqueta(
                      t.prioridad,
                      TicketUtils.colorPrioridad(t.prioridad, t.prioridadColor),
                    ),
                  ),
                  DataCell(
                    _etiqueta(
                      TicketUtils.etiquetaEstado(t.estado),
                      TicketUtils.colorEstado(t.estado),
                    ),
                  ),
                  DataCell(Text(t.tecnico.isEmpty ? 'Sin asignar' : t.tecnico)),
                  DataCell(
                    Text(
                      t.creadoEn == null
                          ? ''
                          : '${t.creadoEn!.day}/${t.creadoEn!.month}/${t.creadoEn!.year}',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetas() {
    final visibles = _ticketsVisibles;
    return Column(
      children: [
        for (var i = 0; i < visibles.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _tarjetaTicket(visibles[i]),
        ],
      ],
    );
  }

  Widget _tarjetaTicket(TicketItem t) {
    final noLeido = _noLeidos.contains(t.codigo);
    final urgente = widget.esAdminTickets && _ticketUrgenteSinAsignar(t);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(
          color: urgente ? LuvegiColors.error : LuvegiColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (noLeido) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: LuvegiColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  t.codigo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: noLeido ? LuvegiColors.textPrimary : null,
                  ),
                ),
              ),
              if (urgente) ...[
                _badgeUrgente(),
                const SizedBox(width: 8),
              ],
              _etiqueta(
                TicketUtils.etiquetaEstado(t.estado),
                TicketUtils.colorEstado(t.estado),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.asunto,
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _etiqueta(
                t.prioridad,
                TicketUtils.colorPrioridad(t.prioridad, t.prioridadColor),
              ),
              _infoTexto(
                t.subcategoria.trim().isEmpty
                    ? t.categoria
                    : '${t.categoria} › ${t.subcategoria}',
              ),
              _infoTexto(t.tecnico.isEmpty ? 'Sin asignar' : t.tecnico),
              _infoTexto(
                t.creadoEn == null
                    ? ''
                    : '${t.creadoEn!.day}/${t.creadoEn!.month}/${t.creadoEn!.year}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => _abrirDetalle(t),
              style: OutlinedButton.styleFrom(
                foregroundColor: LuvegiColors.secondary,
              ),
              child: const Text('Ver'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      texto,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _infoTexto(String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.circle, size: 5, color: LuvegiColors.textSecondary),
      const SizedBox(width: 5),
      Text(texto, style: LuvegiText.caption),
    ],
  );

  /// Distintivo para tickets de prioridad Alta abiertos y sin técnico.
  Widget _badgeUrgente() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: LuvegiColors.error.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: LuvegiColors.error.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 12, color: LuvegiColors.error),
        const SizedBox(width: 3),
        Text(
          'URGENTE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: LuvegiColors.error,
          ),
        ),
      ],
    ),
  );
}