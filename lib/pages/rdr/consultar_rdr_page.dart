import 'dart:async';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/rdr_service.dart';
import '../../utils/mensaje_error.dart';
import 'detalle_rdr_page.dart';

class ConsultarRdrPage extends StatefulWidget {
  final String token;
  final List<String> permisos;
  final bool puedeExportarRdr;
  final VoidCallback onRegistrarRdr;
  final String areaUsuario;
  final String? codigoInicial;
  final VoidCallback? onCodigoInicialConsumido;

  const ConsultarRdrPage({
    super.key,
    required this.token,
    required this.permisos,
    this.puedeExportarRdr = false,
    required this.onRegistrarRdr,
    this.areaUsuario = '',
    this.codigoInicial,
    this.onCodigoInicialConsumido,
  });

  @override
  State<ConsultarRdrPage> createState() => _ConsultarRdrPageState();
}

class _RdrDemo {
  final String codigo;
  final String estado;
  final String tipoEmisor;
  final String tipoRegistro;
  final String tipoProblema;
  final String area;
  final bool puedeAtender;
  final Map<String, dynamic> jsonOriginal;

  const _RdrDemo({
    required this.codigo,
    required this.estado,
    required this.tipoEmisor,
    required this.tipoRegistro,
    required this.tipoProblema,
    required this.area,
    required this.puedeAtender,
    required this.jsonOriginal,
  });

  factory _RdrDemo.fromJson(Map<String, dynamic> json) => _RdrDemo(
    codigo: (json['codigo'] ?? '').toString(),
    estado: (json['estado'] ?? 'ABIERTO').toString(),
    tipoEmisor: (json['tipo_emisor'] ?? '').toString(),
    tipoRegistro: (json['tipo_registro'] ?? '').toString(),
    tipoProblema: (json['tipo_problema'] ?? '').toString(),
    area: (json['area_responsable'] ?? '').toString(),
    puedeAtender: json['puede_atender'] == true || json['puede_atender'] == 1,
    jsonOriginal: json,
  );
}

class _ConsultarRdrPageState extends State<ConsultarRdrPage> {
  final TextEditingController _codigoCtrl = TextEditingController();
  final ScrollController _hScrollCtrl = ScrollController();
  final RdrService _rdrService = RdrService();

  String? _estado;
  String? _areaFiltro;

  List<_RdrDemo> _filtrados = [];
  bool _cargando = true;
  Timer? _timer;
  DateTime? _ultimaActualizacion;
  bool _refrescando = false;
  bool _exportando = false;

  static const int _pageSize = 20;
  int _pagina = 1;
  int _totalPaginas = 1;
  int _totalRegistros = 0;

  static const List<String> _areasLista = [
    'Ventas',
    'Renta',
    'Mantenimiento',
    'Proyectos',
    'Operaciones',
    'Producción',
    'Tesorería',
    'TI',
    'SST',
    'RRHH',
    'Contabilidad',
    'Almacén',
    'Compras',
    'Planeamiento',
  ];

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refrescarSilencioso(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarRegistros() {
    _pagina = 1;
    return _consultar(mostrarCarga: true);
  }



  Future<void> _refrescarSilencioso() => _consultar(mostrarCarga: false);

  Future<void> _consultar({required bool mostrarCarga}) async {
    if (_refrescando) return;
    _refrescando = true;
    if (mostrarCarga && mounted) setState(() => _cargando = true);
    try {
      final response = await _rdrService.consultarRdr(
        token: widget.token,
        page: _pagina,
        pageSize: _pageSize,
        filtros: {
          'codigo': _codigoCtrl.text.trim(),
          'estado': _estado,
          'area_responsable': _areaFiltro,
        },
      );
      final raw = response['data'] as List<dynamic>? ?? const [];
      final totalRaw = response['total'] ?? response['total_count'];
      final total = totalRaw is num ? totalRaw.toInt() : 0;
      if (!mounted) return;
      setState(() {
        _filtrados = raw
            .whereType<Map>()
            .map((e) => _RdrDemo.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _totalRegistros = total;
        _totalPaginas = total <= 0 ? 1 : (total / _pageSize).ceil();
        _ultimaActualizacion = DateTime.now();
      });
    } catch (_) {
      if (mostrarCarga && mounted) {
        ScaffoldMessenger.of(context)?.showSnackBar(
          const SnackBar(content: Text('Error al cargar registros REDIR.')),
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

  String _valor(Map<String, dynamic> json, List<String> claves) {
    for (final clave in claves) {
      final valor = json[clave];
      if (valor != null && valor.toString().trim().isNotEmpty) {
        return valor.toString().trim();
      }
    }
    return '';
  }

  Future<void> _exportarDetalleExcel() async {
    if (_exportando) return;

    if (!widget.puedeExportarRdr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para exportar el detalle.')),
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
        final response = await _rdrService.consultarRdr(
          token: widget.token,
          page: pagina,
          pageSize: tamano,
          filtros: {
            'codigo': _codigoCtrl.text.trim(),
            'estado': _estado,
            'area_responsable': _areaFiltro,
          },
        );
        if (!mounted) return;
        final raw = response['data'] as List<dynamic>? ?? const [];
        todas.addAll(
          raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
        final totalRaw = response['total'] ?? response['total_count'];
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
      final sheet = excel['Detalle REDIR'];
      excel.delete('Sheet1');

      sheet.appendRow([
        excel_lib.TextCellValue('Código REDIR'),
        excel_lib.TextCellValue('Estado'),
        excel_lib.TextCellValue('Fecha Registro'),
        excel_lib.TextCellValue('Área Emisora'),
        excel_lib.TextCellValue('Tipo Registro'),
        excel_lib.TextCellValue('Tipo Problema'),
        excel_lib.TextCellValue('Área Responsable'),
        excel_lib.TextCellValue('Fecha Incidente'),
        excel_lib.TextCellValue('Hora Incidente'),
        excel_lib.TextCellValue('Pedido'),
        excel_lib.TextCellValue('Impacto Económico'),
        excel_lib.TextCellValue('Impacto HH'),
        excel_lib.TextCellValue('Descripción'),
        excel_lib.TextCellValue('Puntuación'),
        excel_lib.TextCellValue('Marca'),
        excel_lib.TextCellValue('Usuario Emisor'),
        excel_lib.TextCellValue('Fecha Cierre'),
        excel_lib.TextCellValue('Responsable'),
        excel_lib.TextCellValue('Tipo Causa'),
        excel_lib.TextCellValue('Tiempo Solución (Horas)'),
        excel_lib.TextCellValue('Costos Asociados'),
        excel_lib.TextCellValue('Descripción de lo sucedido'),
        excel_lib.TextCellValue('Solución implementada'),
      ]);

      for (final r in todas) {
        sheet.appendRow([
          excel_lib.TextCellValue(_valor(r, const ['codigo'])),
          excel_lib.TextCellValue(_valor(r, const ['estado'])),
          excel_lib.TextCellValue(
            _valor(r, const ['fecha_apertura', 'creado_en']),
          ),
          excel_lib.TextCellValue(_valor(r, const ['tipo_emisor'])),
          excel_lib.TextCellValue(_valor(r, const ['tipo_registro'])),
          excel_lib.TextCellValue(_valor(r, const ['tipo_problema'])),
          excel_lib.TextCellValue(_valor(r, const ['area_responsable'])),
          excel_lib.TextCellValue(_valor(r, const ['fecha_incidente'])),
          excel_lib.TextCellValue(_valor(r, const ['hora_incidente'])),
          excel_lib.TextCellValue(_valor(r, const ['pedido'])),
          excel_lib.TextCellValue(_valor(r, const ['impacto_economico'])),
          excel_lib.TextCellValue(_valor(r, const ['impacto_hh'])),
          excel_lib.TextCellValue(_valor(r, const ['descripcion'])),
          excel_lib.TextCellValue(_valor(r, const ['puntuacion'])),
          excel_lib.TextCellValue(_valor(r, const ['marca'])),
          excel_lib.TextCellValue(
            _valor(r, const ['emisor_nombre', 'usuario_emisor']),
          ),
          excel_lib.TextCellValue(_valor(r, const ['fecha_cierre'])),
          excel_lib.TextCellValue(_valor(r, const ['responsable_nombre'])),
          excel_lib.TextCellValue(_valor(r, const ['tipo_causa'])),
          excel_lib.TextCellValue(
            _valor(r, const ['tiempo_solucion_horas']),
          ),
          excel_lib.TextCellValue(_valor(r, const ['costos_asociados'])),
          excel_lib.TextCellValue(_valor(r, const ['descripcion_sucedido'])),
          excel_lib.TextCellValue(_valor(r, const ['descripcion_solucion'])),
        ]);
      }

      final fecha = DateTime.now();
      String dos(int n) => n.toString().padLeft(2, '0');
      final nombreArchivo =
          'DetalleREDIR_${fecha.year}${dos(fecha.month)}${dos(fecha.day)}'
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
            content: Text('Se exportaron ${todas.length} registros a Excel.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajeError.desdeExcepcion(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  String _horaResumen(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fechaTexto(DateTime? fecha) {
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
            constraints: const BoxConstraints(maxWidth: 1350),
            child: Column(
              children: [
                _buildFiltros(mobile),
                const SizedBox(height: LuvegiSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _ultimaActualizacion == null
                        ? 'Cargando...'
                        : 'Actualizado ${_horaResumen(_ultimaActualizacion!)}',
                    style: LuvegiText.caption,
                  ),
                ),
                const SizedBox(height: LuvegiSpacing.xs),
                if (_cargando)
                  const CircularProgressIndicator()
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

  Widget _dropdownEstado() => DropdownButtonFormField<String>(
    initialValue: _estado,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Estado'),
    items: const [
      DropdownMenuItem(value: null, child: Text('Todos')),
      DropdownMenuItem(value: 'ABIERTO', child: Text('Pendiente')),
      DropdownMenuItem(value: 'CERRADO', child: Text('Cerrado')),
    ],
    onChanged: (v) => setState(() => _estado = v),
  );

  Widget _dropdownArea() => DropdownButtonFormField<String>(
    initialValue: _areaFiltro,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Área Responsable'),
    items: [
      const DropdownMenuItem(value: null, child: Text('Todas')),
      ..._areasLista.map(
        (a) => DropdownMenuItem(value: a, child: Text(a)),
      ),
    ],
    onChanged: (v) => setState(() => _areaFiltro = v),
  );

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
          TextField(
            controller: _codigoCtrl,
            decoration: const InputDecoration(labelText: 'Código REDIR'),
          ),
          const SizedBox(height: LuvegiSpacing.md),
          _dropdownEstado(),
          const SizedBox(height: LuvegiSpacing.md),
          _dropdownArea(),
        ] else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(labelText: 'Código REDIR'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _dropdownEstado()),
              const SizedBox(width: 10),
              Expanded(child: _dropdownArea()),
            ],
          ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            if (widget.puedeExportarRdr)
              OutlinedButton.icon(
                onPressed: (_cargando || _exportando)
                    ? null
                    : _exportarDetalleExcel,
                icon: _exportando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _exportando ? 'Exportando...' : 'Exportar detalle en Excel',
                ),
              ),
            ElevatedButton.icon(
              onPressed: _cargarRegistros,
              icon: const Icon(Icons.search),
              label: const Text('Buscar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LuvegiColors.secondary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildTabla(bool mobile) {
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
          child: DataTable(
        columns: const [
          DataColumn(label: Text('Acción')),
          DataColumn(label: Text('Código')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Área Emisora')),
          DataColumn(label: Text('Tipo Registro')),
          DataColumn(label: Text('Tipo Problema')),
          DataColumn(label: Text('Área Responsable')),
        ],
        rows: _filtrados.map((r) {
          // LÓGICA DE ATENCIÓN: Solo es editable/atendible si está ABIERTO y el usuario puede atender
          final bool esAtendible =
              (r.estado.toUpperCase() == 'ABIERTO') && r.puedeAtender;

          return DataRow(
            cells: [
              DataCell(
                ElevatedButton(
                  onPressed: () => _abrirDetalle(r),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: esAtendible
                        ? LuvegiColors.secondary
                        : Colors.grey.shade300,
                    foregroundColor: esAtendible
                        ? Colors.white
                        : Colors.black87,
                  ),
                  child: Text(esAtendible ? 'Atender' : 'Ver detalle'),
                ),
              ),
              DataCell(
                Text(
                  r.codigo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(r.estado)),
              DataCell(Text(r.tipoEmisor)),
              DataCell(Text(r.tipoRegistro)),
              DataCell(Text(r.tipoProblema)),
              DataCell(Text(r.area)),
            ],
          );
          }).toList(),
        ),
      ),
      ),
    );
  }

  Widget _buildTarjetas() => Column(
    children: [
      for (var i = 0; i < _filtrados.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        _tarjetaRdr(_filtrados[i]),
      ],
    ],
  );

  Widget _tarjetaRdr(_RdrDemo r) {
    final bool esAtendible =
        (r.estado.toUpperCase() == 'ABIERTO') && r.puedeAtender;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
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
                  r.codigo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _etiqueta(r.estado, _colorEstado(r.estado)),
            ],
          ),
          if (r.tipoProblema.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.tipoProblema,
              style: LuvegiText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (r.tipoEmisor.isNotEmpty)
                _infoTexto('Emisora: ${r.tipoEmisor}'),
              if (r.tipoRegistro.isNotEmpty)
                _infoTexto('Registro: ${r.tipoRegistro}'),
              if (r.area.isNotEmpty) _infoTexto('Responsable: ${r.area}'),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _abrirDetalle(r),
              style: ElevatedButton.styleFrom(
                backgroundColor: esAtendible
                    ? LuvegiColors.secondary
                    : Colors.grey.shade300,
                foregroundColor: esAtendible ? Colors.white : Colors.black87,
              ),
              child: Text(esAtendible ? 'Atender' : 'Ver detalle'),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) => estado.toUpperCase() == 'CERRADO'
      ? LuvegiColors.success
      : LuvegiColors.warning;

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

  Future<void> _abrirDetalle(_RdrDemo r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleRdrPage.desdeJson(
          token: widget.token,
          json: r.jsonOriginal,
          puedeExportar: widget.puedeExportarRdr,
        ),
      ),
    );
    _cargarRegistros();
  }
}
