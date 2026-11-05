import 'dart:typed_data';
import 'package:data_table_2/data_table_2.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../design_system/luvegi_loading.dart';
import '../services/reporte_pedido_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../utils/mensaje_error.dart';

class ItemReporteConsumo {
  final String fecha;
  final String proveedor;
  final String tipoOperacionComprobante;
  final String refComprobante;
  final String refOrigen;
  final String codigoProducto;
  final String producto;
  final String etiqueta;
  final double cantidad;
  final String moneda;
  final double tipoCambio;
  final double precioUnitario;
  final double importePen;
  final String cuentaAnalitica;
  final String unidadNegocio;
  final String equipo;
  final String pedido;

  ItemReporteConsumo({
    required this.fecha,
    required this.proveedor,
    required this.tipoOperacionComprobante,
    required this.refComprobante,
    required this.refOrigen,
    required this.codigoProducto,
    required this.producto,
    required this.etiqueta,
    required this.cantidad,
    required this.moneda,
    required this.tipoCambio,
    required this.precioUnitario,
    required this.importePen,
    required this.cuentaAnalitica,
    required this.unidadNegocio,
    required this.equipo,
    required this.pedido,
  });

  factory ItemReporteConsumo.fromJson(Map<String, dynamic> json) {
    return ItemReporteConsumo(
      fecha: (json['FECHA'] ?? '').toString(),
      proveedor: (json['PROVEEDOR'] ?? '').toString(),
      tipoOperacionComprobante: (json['TIPO OPERACION / COMPROBANTE'] ?? '')
          .toString(),
      refComprobante: (json['REF. COMPROBANTE'] ?? '').toString(),
      refOrigen: (json['REF. ORIGEN'] ?? '').toString(),
      codigoProducto: (json['CODIGO PRODUCTO'] ?? '').toString(),
      producto: (json['PRODUCTO'] ?? '').toString(),
      etiqueta: (json['ETIQUETA'] ?? '').toString(),
      cantidad: double.tryParse('${json['CANTIDAD']}') ?? 0.0,
      moneda: (json['MONEDA'] ?? 'PEN').toString(),
      tipoCambio: double.tryParse('${json['TIPO CAMBIO']}') ?? 1.0,
      precioUnitario: double.tryParse('${json['PRECIO UNITARIO']}') ?? 0.0,
      importePen: double.tryParse('${json['IMPORTE (PEN)']}') ?? 0.0,
      cuentaAnalitica: (json['CUENTA ANALITICA'] ?? '').toString(),
      unidadNegocio: (json['UNIDAD DE NEGOCIO'] ?? '').toString(),
      equipo: (json['EQUIPO'] ?? '').toString(),
      pedido: (json['PEDIDO'] ?? '').toString(),
    );
  }
}

class ReporteConsumoPage extends StatefulWidget {
  final String? token;

  const ReporteConsumoPage({super.key, this.token});

  @override
  State<ReporteConsumoPage> createState() => _ReporteConsumoPageState();
}

class _ReporteConsumoPageState extends State<ReporteConsumoPage>
    with LuvegiProgresoMixin {
  final _service = ReporteConsumoService();
  final _busquedaController = TextEditingController();

  bool cargando = false;
  bool exportando = false;
  String? error;
  List<ItemReporteConsumo> filas = [];

  int paginaActual = 1;
  int totalPaginas = 1;
  int totalRegistros = 0;
  double gastoTotalGeneral = 0.0;
  int limitePorPagina = 25;

  String tipoBusqueda = 'pedido';

  @override
  void dispose() {
    cancelarProgresoTimer();
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _buscarConsumo({int pagina = 1}) async {
    final query = _busquedaController.text.trim();

    if (query.isEmpty) {
      setState(() {
        error = 'Ingresa un valor para consultar.';
        filas = [];
        totalRegistros = 0;
        gastoTotalGeneral = 0.0;
        totalPaginas = 1;
      });
      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });

    iniciarProgreso();

    try {
      final res = await _service.consultarConsumo(
        widget.token ?? '',
        busqueda: query,
        tipoFiltro: tipoBusqueda,
        pagina: pagina,
        limite: limitePorPagina,
      );
      if (!mounted) return;
      setState(() {
        filas = res.items;
        paginaActual = res.paginaActual;
        totalPaginas = res.totalPaginas == 0 ? 1 : res.totalPaginas;
        totalRegistros = res.totalRegistros;
        gastoTotalGeneral = res.gastoTotalGeneral;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filas = [];
        totalRegistros = 0;
        gastoTotalGeneral = 0.0;
        totalPaginas = 1;
      });
    } finally {
      if (mounted) {
        detenerProgreso();
        setState(() => cargando = false);
      }
    }
  }

  Future<void> _exportarAExcel() async {
    if (_busquedaController.text.trim().isEmpty) return;
    setState(() => exportando = true);
    try {
      final query = _busquedaController.text.trim();
      List<ItemReporteConsumo> todasLasFilas = [];
      int pagina = 1;
      int totalPaginas = 1;

      while (pagina <= totalPaginas) {
        final res = await _service.consultarConsumo(
          widget.token ?? '',
          busqueda: query,
          tipoFiltro: tipoBusqueda,
          pagina: pagina,
          limite: 1000,
        );
        if (!mounted) return;
        todasLasFilas.addAll(res.items);
        totalPaginas = res.totalPaginas == 0 ? 1 : res.totalPaginas;
        pagina++;
      }

      if (todasLasFilas.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay registros para exportar.')),
          );
        return;
      }

      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Consumo'];
      excel.delete('Sheet1');

      sheet.appendRow([
        excel_lib.TextCellValue('FECHA'),
        excel_lib.TextCellValue('PROVEEDOR'),
        excel_lib.TextCellValue('TIPO OPERACION / COMPROBANTE'),
        excel_lib.TextCellValue('REF. COMPROBANTE'),
        excel_lib.TextCellValue('REF. ORIGEN'),
        excel_lib.TextCellValue('CODIGO PRODUCTO'),
        excel_lib.TextCellValue('PRODUCTO'),
        excel_lib.TextCellValue('ETIQUETA'),
        excel_lib.TextCellValue('CANTIDAD'),
        excel_lib.TextCellValue('MONEDA'),
        excel_lib.TextCellValue('TIPO CAMBIO'),
        excel_lib.TextCellValue('PRECIO UNITARIO'),
        excel_lib.TextCellValue('IMPORTE (PEN)'),
        excel_lib.TextCellValue('CUENTA ANALITICA'),
        excel_lib.TextCellValue('UNIDAD DE NEGOCIO'),
        excel_lib.TextCellValue('EQUIPO'),
        excel_lib.TextCellValue('PEDIDO'),
      ]);

      for (var r in todasLasFilas) {
        sheet.appendRow([
          excel_lib.TextCellValue(r.fecha),
          excel_lib.TextCellValue(r.proveedor),
          excel_lib.TextCellValue(r.tipoOperacionComprobante),
          excel_lib.TextCellValue(r.refComprobante),
          excel_lib.TextCellValue(r.refOrigen),
          excel_lib.TextCellValue(r.codigoProducto),
          excel_lib.TextCellValue(r.producto),
          excel_lib.TextCellValue(r.etiqueta),
          excel_lib.DoubleCellValue(r.cantidad),
          excel_lib.TextCellValue(r.moneda),
          excel_lib.DoubleCellValue(r.tipoCambio),
          excel_lib.DoubleCellValue(r.precioUnitario),
          excel_lib.DoubleCellValue(r.importePen),
          excel_lib.TextCellValue(r.cuentaAnalitica),
          excel_lib.TextCellValue(r.unidadNegocio),
          excel_lib.TextCellValue(r.equipo),
          excel_lib.TextCellValue(r.pedido),
        ]);
      }
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final nombreArchivo = 'Consumo_${query}_Todo.xlsx';
        await FileSaver.instance.saveFile(
          name: nombreArchivo,
          bytes: Uint8List.fromList(fileBytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(MensajeError.desdeExcepcion(e))));
    } finally {
      if (mounted) setState(() => exportando = false);
    }
  }

  Widget celda(String texto, {TextAlign align = TextAlign.left, Color? color}) {
    return Tooltip(
      message: texto,
      waitDuration: const Duration(milliseconds: 500),
      child: Text(
        texto,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: LuvegiText.caption.copyWith(
          color: color ?? LuvegiColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  DataColumn columna(String texto, {double width = 130}) {
    return DataColumn2(
      fixedWidth: width,
      label: Text(
        texto,
        style: LuvegiText.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: LuvegiColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSegmentedFilter() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        border: Border.all(color: LuvegiColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPillButton('Pedido', 'pedido', Icons.receipt_long_rounded),
            Container(width: 1, color: LuvegiColors.border),
            _buildPillButton('Equipo', 'equipo', Icons.build_circle_outlined),
            Container(width: 1, color: LuvegiColors.border),
            _buildPillButton('U. Negocio', 'unidad', Icons.domain_rounded),
            Container(width: 1, color: LuvegiColors.border),
            _buildPillButton(
              'Descripción',
              'descripcion',
              Icons.text_snippet_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillButton(String text, String value, IconData defaultIcon) {
    final isSelected = tipoBusqueda == value;
    return InkWell(
      onTap: () {
        setState(() {
          tipoBusqueda = value;
          filas = [];
          totalRegistros = 0;
          gastoTotalGeneral = 0.0;
        });
      },
      borderRadius: BorderRadius.horizontal(
        left: value == 'pedido' ? const Radius.circular(20) : Radius.zero,
        right: value == 'descripcion' ? const Radius.circular(20) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFCEAE8) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: value == 'pedido' ? const Radius.circular(20) : Radius.zero,
            right: value == 'descripcion'
                ? const Radius.circular(20)
                : Radius.zero,
          ),
        ),
        child: Center(
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_rounded : defaultIcon,
                size: 16,
                color: isSelected
                    ? LuvegiColors.secondary
                    : LuvegiColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: LuvegiText.caption.copyWith(
                  color: isSelected
                      ? LuvegiColors.secondary
                      : LuvegiColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaInfo(String label, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: LuvegiText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );

  Widget _buildTarjetasConsumo() => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: filas.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, i) => _tarjetaConsumo(filas[i]),
  );

  Widget _tarjetaConsumo(ItemReporteConsumo r) {
    final String titulo = r.producto.isNotEmpty ? r.producto : r.etiqueta;
    return Container(
      width: double.infinity,
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
              Expanded(
                child: Text(
                  r.pedido.isEmpty ? '—' : r.pedido,
                  style: LuvegiText.title.copyWith(
                    fontSize: 16,
                    color: LuvegiColors.secondary,
                  ),
                ),
              ),
              if (r.fecha.isNotEmpty)
                Text(r.fecha, style: LuvegiText.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            titulo.isEmpty ? '—' : titulo,
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (r.codigoProducto.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Cód. ${r.codigoProducto}', style: LuvegiText.caption),
          ],
          const SizedBox(height: 8),
          _filaInfo(
            'Proveedor',
            Text(
              r.proveedor.isEmpty ? '—' : r.proveedor,
              style: LuvegiText.body,
            ),
          ),
          _filaInfo(
            'Comprobante',
            Text(
              r.refComprobante.isEmpty ? '—' : r.refComprobante,
              style: LuvegiText.body,
            ),
          ),
          if (r.tipoOperacionComprobante.isNotEmpty)
            _filaInfo(
              'Tipo',
              Text(r.tipoOperacionComprobante, style: LuvegiText.body),
            ),
          if (r.unidadNegocio.isNotEmpty)
            _filaInfo(
              'U. Negocio',
              Text(r.unidadNegocio, style: LuvegiText.body),
            ),
          if (r.equipo.isNotEmpty)
            _filaInfo('Equipo', Text(r.equipo, style: LuvegiText.body)),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _filaInfo(
            'Cantidad',
            Text(r.cantidad.toString(), style: LuvegiText.body),
          ),
          _filaInfo(
            'Precio',
            Text(r.precioUnitario.toString(), style: LuvegiText.body),
          ),
          _filaInfo(
            'Importe (PEN)',
            Text(
              r.importePen.toString(),
              style: LuvegiText.body.copyWith(
                fontWeight: FontWeight.w700,
                color: LuvegiColors.secondary,
              ),
            ),
          ),
          _filaInfo('Moneda', Text(r.moneda, style: LuvegiText.body)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String hintBuscador = 'Ej. GE00088';
    String tituloBusqueda = 'Número de Pedido';
    if (tipoBusqueda == 'equipo') {
      hintBuscador = 'Ej. SINEQUI o EQ-123';
      tituloBusqueda = 'Equipo';
    } else if (tipoBusqueda == 'unidad') {
      hintBuscador = 'Ej. RENTA o UN-123';
      tituloBusqueda = 'Unidad de Negocio';
    } else if (tipoBusqueda == 'descripcion') {
      hintBuscador = 'Ej. Repuesto motor, Filtro...';
      tituloBusqueda = 'Descripción de Etiqueta';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool esMovil = constraints.maxWidth < 768;

        return Scaffold(
          backgroundColor: LuvegiColors.background,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(
                esMovil ? LuvegiSpacing.md : LuvegiSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (esMovil) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: LuvegiColors.menuHover,
                                borderRadius: BorderRadius.circular(
                                  LuvegiRadius.md,
                                ),
                              ),
                              child: const Icon(
                                Icons.table_chart_rounded,
                                color: LuvegiColors.secondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: LuvegiSpacing.sm),
                            Expanded(
                              child: Text(
                                'Reporte por Consumo',
                                style: LuvegiText.title.copyWith(fontSize: 17),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: LuvegiSpacing.xs),
                        Text(
                          'Consolidado analítico de movimientos de almacén.',
                          style: LuvegiText.bodySecondary,
                        ),
                        const SizedBox(height: LuvegiSpacing.sm),
                        Row(
                          children: [
                            if (totalRegistros > 0) ...[
                              IconButton.filledTonal(
                                onPressed: exportando ? null : _exportarAExcel,
                                tooltip: 'Exportar a Excel',
                                icon: exportando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.download_rounded,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                              ),
                              const SizedBox(width: LuvegiSpacing.sm),
                            ],
                            Expanded(
                              child: LuvegiButton.primary(
                                text: cargando ? 'Buscando...' : 'Buscar',
                                icon: Icons.search_rounded,
                                loading: cargando,
                                onPressed: cargando
                                    ? null
                                    : () => _buscarConsumo(pagina: 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: LuvegiColors.menuHover,
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                          child: const Icon(
                            Icons.table_chart_rounded,
                            color: LuvegiColors.secondary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: LuvegiSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reporte por Consumo',
                                style: LuvegiText.title.copyWith(fontSize: 20),
                              ),
                              const SizedBox(height: LuvegiSpacing.xs),
                              Text(
                                'Consolidado analítico de movimientos de almacén optimizado.',
                                style: LuvegiText.bodySecondary,
                              ),
                            ],
                          ),
                        ),
                        if (totalRegistros > 0) ...[
                          IconButton.filledTonal(
                            onPressed: exportando ? null : _exportarAExcel,
                            tooltip: 'Exportar a Excel',
                            icon: exportando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.download_rounded,
                                    color: Colors.green,
                                  ),
                          ),
                          const SizedBox(width: LuvegiSpacing.sm),
                        ],
                        LuvegiButton.primary(
                          text: cargando ? 'Buscando...' : 'Buscar',
                          icon: Icons.search_rounded,
                          loading: cargando,
                          onPressed: cargando
                              ? null
                              : () => _buscarConsumo(pagina: 1),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: LuvegiSpacing.md),
                  LuvegiCard(
                    padding: EdgeInsets.all(
                      esMovil ? LuvegiSpacing.sm : LuvegiSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (esMovil) ...[
                          _buildSegmentedFilter(),
                          const SizedBox(height: LuvegiSpacing.sm),
                          TextField(
                            controller: _busquedaController,
                            onSubmitted: (_) => _buscarConsumo(pagina: 1),
                            decoration: InputDecoration(
                              labelText: tituloBusqueda,
                              hintText: hintBuscador,
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: LuvegiColors.secondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  LuvegiRadius.sm,
                                ),
                                borderSide: const BorderSide(
                                  color: LuvegiColors.border,
                                ),
                              ),
                              filled: true,
                              fillColor: LuvegiColors.surface,
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              _buildSegmentedFilter(),
                              const SizedBox(width: LuvegiSpacing.md),
                              Expanded(
                                child: TextField(
                                  controller: _busquedaController,
                                  onSubmitted: (_) => _buscarConsumo(pagina: 1),
                                  decoration: InputDecoration(
                                    labelText: tituloBusqueda,
                                    hintText: hintBuscador,
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: LuvegiColors.secondary,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        LuvegiRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        color: LuvegiColors.border,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: LuvegiColors.surface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: LuvegiSpacing.md),
                        Wrap(
                          spacing: LuvegiSpacing.sm,
                          runSpacing: LuvegiSpacing.sm,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: LuvegiColors.surfaceHover,
                                borderRadius: BorderRadius.circular(
                                  LuvegiRadius.sm,
                                ),
                                border: Border.all(color: LuvegiColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'REGISTROS',
                                    style: LuvegiText.caption.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: LuvegiColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$totalRegistros',
                                    style: LuvegiText.title.copyWith(
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: LuvegiColors.secondary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  LuvegiRadius.sm,
                                ),
                                border: Border.all(
                                  color: LuvegiColors.secondary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GASTO TOTAL (PEN)',
                                    style: LuvegiText.caption.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: LuvegiColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'S/ ${formatearConComas(gastoTotalGeneral)}',
                                    style: LuvegiText.title.copyWith(
                                      fontSize: 17,
                                      color: LuvegiColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: LuvegiSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(LuvegiSpacing.md),
                      decoration: BoxDecoration(
                        color: LuvegiColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                        border: Border.all(
                          color: LuvegiColors.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        error!,
                        style: LuvegiText.body.copyWith(
                          color: LuvegiColors.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: LuvegiSpacing.md),
                  Expanded(
                    child: cargando
                        ? buildProgreso()
                        : filas.isEmpty
                        ? Center(
                            child: Text(
                              'Sin resultados. Verifica el texto o la categoría.',
                              style: LuvegiText.bodySecondary,
                            ),
                          )
                        : esMovil
                        ? _buildTarjetasConsumo()
                        : LuvegiCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                LuvegiRadius.lg,
                              ),
                              child: DataTable2(
                                minWidth: 2680,
                                fixedTopRows: 1,
                                headingRowHeight: 48,
                                dataRowHeight: 52,
                                columnSpacing: 10,
                                horizontalMargin: 12,
                                headingRowColor: WidgetStateProperty.all(
                                  LuvegiColors.menuHover,
                                ),
                                border: TableBorder.all(
                                  color: LuvegiColors.border,
                                ),
                                columns: [
                                  columna('FECHA', width: 100),
                                  columna('PROVEEDOR', width: 220),
                                  columna(
                                    'TIPO OPERACION / COMPROBANTE',
                                    width: 220,
                                  ),
                                  columna('REF. COMPROBANTE', width: 160),
                                  columna('REF. ORIGEN', width: 130),
                                  columna('CODIGO PRODUCTO', width: 140),
                                  columna('PRODUCTO', width: 280),
                                  columna('ETIQUETA', width: 220),
                                  columna('CANTIDAD', width: 100),
                                  columna('MONEDA', width: 80),
                                  columna('TIPO CAMBIO', width: 100),
                                  columna('PRECIO UNITARIO', width: 120),
                                  columna('IMPORTE (PEN)', width: 120),
                                  columna('CUENTA ANALITICA', width: 140),
                                  columna('UNIDAD DE NEGOCIO', width: 150),
                                  columna('EQUIPO', width: 120),
                                  columna('PEDIDO', width: 140),
                                ],
                                rows: filas.map((r) {
                                  return DataRow(
                                    cells: [
                                      DataCell(celda(r.fecha)),
                                      DataCell(celda(r.proveedor)),
                                      DataCell(
                                        celda(r.tipoOperacionComprobante),
                                      ),
                                      DataCell(celda(r.refComprobante)),
                                      DataCell(celda(r.refOrigen)),
                                      DataCell(celda(r.codigoProducto)),
                                      DataCell(celda(r.producto)),
                                      DataCell(celda(r.etiqueta)),
                                      DataCell(
                                        celda(
                                          r.cantidad.toString(),
                                          align: TextAlign.right,
                                        ),
                                      ),
                                      DataCell(celda(r.moneda)),
                                      DataCell(
                                        celda(
                                          r.tipoCambio.toString(),
                                          align: TextAlign.right,
                                        ),
                                      ),
                                      DataCell(
                                        celda(
                                          r.precioUnitario.toString(),
                                          align: TextAlign.right,
                                        ),
                                      ),
                                      DataCell(
                                        celda(
                                          r.importePen.toString(),
                                          align: TextAlign.right,
                                          color: LuvegiColors.secondary,
                                        ),
                                      ),
                                      DataCell(celda(r.cuentaAnalitica)),
                                      DataCell(celda(r.unidadNegocio)),
                                      DataCell(celda(r.equipo)),
                                      DataCell(
                                        celda(
                                          r.pedido,
                                          color: LuvegiColors.secondary,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                  if (totalRegistros > 0) ...[
                    const SizedBox(height: LuvegiSpacing.sm),
                    if (esMovil) ...[
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded),
                                onPressed: paginaActual > 1 && !cargando
                                    ? () => _buscarConsumo(
                                        pagina: paginaActual - 1,
                                      )
                                    : null,
                              ),
                              Text(
                                '$paginaActual / $totalPaginas',
                                style: LuvegiText.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded),
                                onPressed:
                                    paginaActual < totalPaginas && !cargando
                                    ? () => _buscarConsumo(
                                        pagina: paginaActual + 1,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: LuvegiSpacing.xs),
                          Wrap(
                            spacing: LuvegiSpacing.sm,
                            runSpacing: LuvegiSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Mostrar:',
                                style: LuvegiText.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              DropdownButton<int>(
                                value: limitePorPagina,
                                isDense: true,
                                underline: const SizedBox(),
                                items: const [25, 100, 500, 1000, 999999].map((
                                  int value,
                                ) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(
                                      value == 999999 ? 'Todos' : '$value',
                                      style: LuvegiText.caption,
                                    ),
                                  );
                                }).toList(),
                                onChanged: cargando
                                    ? null
                                    : (nuevoLimite) {
                                        if (nuevoLimite != null &&
                                            nuevoLimite != limitePorPagina) {
                                          setState(
                                            () => limitePorPagina = nuevoLimite,
                                          );
                                          _buscarConsumo(pagina: 1);
                                        }
                                      },
                              ),
                              Text(
                                '(${filas.length} vis. de $totalRegistros)',
                                style: LuvegiText.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Mostrar: ',
                                style: LuvegiText.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              DropdownButton<int>(
                                value: limitePorPagina,
                                isDense: true,
                                underline: const SizedBox(),
                                items: const [25, 100, 500, 1000, 999999].map((
                                  int value,
                                ) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(
                                      value == 999999 ? 'Todos' : '$value',
                                      style: LuvegiText.caption,
                                    ),
                                  );
                                }).toList(),
                                onChanged: cargando
                                    ? null
                                    : (nuevoLimite) {
                                        if (nuevoLimite != null &&
                                            nuevoLimite != limitePorPagina) {
                                          setState(
                                            () => limitePorPagina = nuevoLimite,
                                          );
                                          _buscarConsumo(pagina: 1);
                                        }
                                      },
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Página $paginaActual de $totalPaginas (${filas.length} vis. de $totalRegistros)',
                                style: LuvegiText.caption.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded),
                                onPressed: paginaActual > 1 && !cargando
                                    ? () => _buscarConsumo(
                                        pagina: paginaActual - 1,
                                      )
                                    : null,
                              ),
                              Text(
                                '$paginaActual',
                                style: LuvegiText.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded),
                                onPressed:
                                    paginaActual < totalPaginas && !cargando
                                    ? () => _buscarConsumo(
                                        pagina: paginaActual + 1,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Función para agregar comas a los números grandes (ej. 2,238,600.188347)
  String formatearConComas(double numero) {
    List<String> partes = numero.toString().split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String enteros = partes[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return partes.length > 1 ? '$enteros.${partes[1]}' : enteros;
  }
}
