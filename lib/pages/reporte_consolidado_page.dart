import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:data_table_2/data_table_2.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../design_system/luvegi_loading.dart';
import '../models/item_reporte_consolidado.dart';
import '../pages/api_client.dart';
import '../services/reporte_consolidado_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../utils/mensaje_error.dart';

class ReporteConsolidadoPage extends StatefulWidget {
  final String? token;
  const ReporteConsolidadoPage({super.key, this.token});

  @override
  State<ReporteConsolidadoPage> createState() => _ReporteConsolidadoPageState();
}

class _ReporteConsolidadoPageState extends State<ReporteConsolidadoPage>
    with LuvegiProgresoMixin {
  final _service = ReporteConsolidadoService();
  final _busquedaController = TextEditingController();

  bool cargando = false;
  bool exportando = false;
  String? error;
  List<ItemReporteConsolidado> filas = [];

  int paginaActual = 1;
  int totalPaginas = 1;
  int totalRegistros = 0;

  double montoTotalNeto = 0.0;
  double montoTotalGeneral = 0.0;
  double montoIngresosNeto = 0.0;
  double montoEgresosNeto = 0.0;

  int limitePorPagina = 1000;
  String tipoBusqueda = 'pedido'; // 'pedido', 'unidad'

  @override
  void dispose() {
    cancelarProgresoTimer();
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _buscarConsolidado({int pagina = 1}) async {
    final query = _busquedaController.text.trim();

    if (query.isEmpty) {
      setState(() {
        error = 'Ingresa un valor para consultar.';
        filas = [];
        totalRegistros = 0;
        montoIngresosNeto = 0.0;
        montoEgresosNeto = 0.0;
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
      final res = await _service.consultarConsolidado(
        widget.token ?? '',
        pedido: query,
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
        montoTotalGeneral = res.montoTotalGeneral;
        montoTotalNeto = res.montoTotalNeto;
        montoIngresosNeto = res.montoIngresosNeto;
        montoEgresosNeto = res.montoEgresosNeto;
      });
    } on ReporteConsolidadoException catch (e) {
      if (e.statusCode == 401) {
        await ApiClient().forzarLogoutGlobal();
        if (!mounted) return;
        setState(() {
          error = 'Tu sesión ha expirado.';
          filas = [];
          totalRegistros = 0;
          montoIngresosNeto = 0.0;
          montoEgresosNeto = 0.0;
          totalPaginas = 1;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        error = e.message;
        filas = [];
        totalRegistros = 0;
        montoIngresosNeto = 0.0;
        montoEgresosNeto = 0.0;
        totalPaginas = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filas = [];
        totalRegistros = 0;
        montoIngresosNeto = 0.0;
        montoEgresosNeto = 0.0;
        totalPaginas = 1;
      });
    } finally {
      if (mounted) {
        detenerProgreso();
        setState(() => cargando = false);
      }
    }
  }

  Future<void> _abrirEnOdoo(ItemReporteConsolidado r) async {
    if (r.link.isEmpty) return;
    final uri = Uri.parse(r.link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _exportarAExcel() async {
    if (exportando) return;
    if (_busquedaController.text.trim().isEmpty) return;
    setState(() => exportando = true);
    try {
      final query = _busquedaController.text.trim();
      final res = await _service.consultarConsolidado(
        widget.token ?? '',
        pedido: query,
        tipoFiltro: tipoBusqueda,
        pagina: 1,
        limite: 100000,
      );
      if (!mounted) return;
      final todasLasFilas = res.items;

      if (todasLasFilas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay registros para exportar.')),
          );
        }
        return;
      }

      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Consolidado'];
      excel.delete('Sheet1');

      String tituloColumnaFinal = 'Pedido';
      if (tipoBusqueda == 'equipo') tituloColumnaFinal = 'Equipo';
      if (tipoBusqueda == 'unidad') tituloColumnaFinal = 'Unidad de Negocio';

      sheet.appendRow([
        excel_lib.TextCellValue('Origen'),
        excel_lib.TextCellValue('Contacto'),
        excel_lib.TextCellValue('RUC'),
        excel_lib.TextCellValue('OC / OV Origen'),
        excel_lib.TextCellValue('Tipo Comprobante'),
        excel_lib.TextCellValue('N° Comprobante'),
        excel_lib.TextCellValue('Fecha'),
        excel_lib.TextCellValue(tituloColumnaFinal),
        excel_lib.TextCellValue('Cod. Producto'),
        excel_lib.TextCellValue('Producto'),
        excel_lib.TextCellValue('Descripción'),
        excel_lib.TextCellValue('% Analítico'),
        excel_lib.TextCellValue('Cantidad'),
        excel_lib.TextCellValue('Precio'),
        excel_lib.TextCellValue('Moneda'),
        excel_lib.TextCellValue('Tipo Impuestos'),
        excel_lib.TextCellValue('Con Impuestos excl.'),
        excel_lib.TextCellValue('Con Impuestos inc.'),
        excel_lib.TextCellValue('Tipo de Cambio'),
        excel_lib.TextCellValue('Con Impuestos excl. (PEN)'),
        excel_lib.TextCellValue('Con Impuestos inc. (PEN)'),
      ]);

      for (var r in todasLasFilas) {
        sheet.appendRow([
          excel_lib.TextCellValue(r.tipoRegistro),
          excel_lib.TextCellValue(r.contacto),
          excel_lib.TextCellValue(r.ruc),
          excel_lib.TextCellValue(r.ocOrigen),
          excel_lib.TextCellValue(r.tipoComprobante),
          excel_lib.TextCellValue(r.numeroComprobante),
          excel_lib.TextCellValue(
            r.fechaEmision.isNotEmpty ? r.fechaEmision : r.fechaKardex,
          ),
          excel_lib.TextCellValue(r.pedido),
          excel_lib.TextCellValue(r.codigoProducto),
          excel_lib.TextCellValue(r.producto),
          excel_lib.TextCellValue(r.etiqueta),
          excel_lib.TextCellValue('${r.porcentajeAnalitico.toStringAsFixed(2)}%'),
          excel_lib.DoubleCellValue(r.cantidad),
          excel_lib.DoubleCellValue(r.precioUnitario),
          excel_lib.TextCellValue(r.moneda),
          excel_lib.TextCellValue(r.impuesto),
          excel_lib.DoubleCellValue(r.valorMoneda),
          excel_lib.DoubleCellValue(r.valorConImpuesto),
          excel_lib.DoubleCellValue(r.tipoCambio),
          excel_lib.DoubleCellValue(r.valorMonedaNacional),
          excel_lib.DoubleCellValue(r.valorNacionalConImpuesto),
          excel_lib.TextCellValue(r.pedido),
        ]);
        
        // El índice del Tipo de Cambio está en el 18 según el orden de columnas del Excel
        excel_lib.Data celdaTc = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(
            columnIndex: 18, 
            rowIndex: sheet.maxRows - 1,
          ),
        );
        celdaTc.cellStyle = excel_lib.CellStyle(
          numberFormat: excel_lib.NumFormat.custom(formatCode: '0.0000'),
        );
      }
      final nombreArchivo = 'Consolidado_${query}_Todo.xlsx';
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(MensajeError.desdeExcepcion(e))));
      }
    } finally {
      if (mounted) setState(() => exportando = false);
    }
  }

  Widget celda(String texto, {TextAlign align = TextAlign.left, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        texto,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: LuvegiText.caption.copyWith(
          color: color ?? LuvegiColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget celdaMoneda(double monto, {TextAlign align = TextAlign.right}) {
    final bool esNegativo = monto < 0;
    final Color colorTexto = esNegativo
        ? LuvegiColors.error
        : LuvegiColors.textPrimary;
    return celda(monto.toStringAsFixed(2), align: align, color: colorTexto);
  }

  Widget celdaImpuesto(String impuesto) {
    if (impuesto.isEmpty || impuesto == '—' || impuesto == 'Sin Impuesto') {
      return celda(impuesto, color: LuvegiColors.textSecondary);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Text(
        impuesto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LuvegiText.caption.copyWith(
          color: Colors.deepPurple.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget celdaBadgeOrigen(String tipo) {
    Color bg;
    Color fg;
    switch (tipo.toLowerCase()) {
      case 'cliente':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'proveedor':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      default:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
      ),
      child: Text(
        tipo,
        style: LuvegiText.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
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

  Widget _buildSummaryCard(
    String title,
    String value, {
    required Color color,
    Color? bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor ?? LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(
          color: bgColor != null
              ? color.withValues(alpha: 0.3)
              : LuvegiColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: LuvegiText.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color == LuvegiColors.textPrimary
                  ? LuvegiColors.textSecondary
                  : color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: LuvegiText.title.copyWith(fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenes() {
    return Wrap(
      spacing: LuvegiSpacing.sm,
      runSpacing: LuvegiSpacing.sm,
      children: [
        _buildSummaryCard(
          'REGISTROS',
          '$totalRegistros',
          color: LuvegiColors.textPrimary,
        ),
        _buildSummaryCard(
          'INGRESOS (VENTAS NETAS)',
          'S/ ${montoIngresosNeto.toStringAsFixed(2)}',
          color: Colors.green.shade700,
          bgColor: Colors.green.shade50,
        ),
        _buildSummaryCard(
          'EGRESOS (COMPRAS/STOCK)',
          'S/ -${montoEgresosNeto.toStringAsFixed(2)}',
          color: LuvegiColors.error,
          bgColor: LuvegiColors.error.withValues(alpha: 0.08),
        ),
      ],
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPillButton('Pedido', 'pedido', Icons.receipt_long_rounded),
          Container(width: 1, color: LuvegiColors.border),
          _buildPillButton('U. Negocio', 'unidad', Icons.domain_rounded),
        ],
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
          montoIngresosNeto = 0.0;
          montoEgresosNeto = 0.0;
        });
      },
      borderRadius: BorderRadius.horizontal(
        left: value == 'pedido' ? const Radius.circular(20) : Radius.zero,
        right: value == 'unidad' ? const Radius.circular(20) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFCEAE8) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: value == 'pedido' ? const Radius.circular(20) : Radius.zero,
            right: value == 'unidad' ? const Radius.circular(20) : Radius.zero,
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
          width: 96,
          child: Text(
            label,
            style: LuvegiText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );

  Widget _montoTexto(double monto) => Text(
    monto.toStringAsFixed(2),
    style: LuvegiText.body.copyWith(
      color: monto < 0 ? LuvegiColors.error : LuvegiColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildTarjetasConsolidado(String tituloColumnaFinal) =>
      ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: filas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _tarjetaConsolidado(filas[i], tituloColumnaFinal),
      );

  Widget _tarjetaConsolidado(
    ItemReporteConsolidado r,
    String tituloColumnaFinal,
  ) {
    final String fecha = r.fechaEmision.isNotEmpty
        ? r.fechaEmision
        : r.fechaKardex;
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
              celdaBadgeOrigen(r.tipoRegistro),
              const Spacer(),
              if (fecha.isNotEmpty) Text(fecha, style: LuvegiText.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r.producto.isEmpty ? r.etiqueta : r.producto,
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
            tituloColumnaFinal,
            Text(
              r.pedido.isEmpty ? '—' : r.pedido,
              style: LuvegiText.body.copyWith(
                color: LuvegiColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _filaInfo(
            'Contacto',
            Text(
              r.contacto.isEmpty ? '—' : r.contacto,
              style: LuvegiText.body,
            ),
          ),
          _filaInfo(
            'Comprobante',
            InkWell(
              onTap: r.link.isNotEmpty ? () => _abrirEnOdoo(r) : null,
              child: Text(
                r.link.isNotEmpty
                    ? '${r.numeroComprobante} ↗'
                    : r.numeroComprobante,
                style: LuvegiText.body.copyWith(
                  color: r.link.isNotEmpty ? LuvegiColors.secondary : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (r.tipoComprobante.isNotEmpty)
                Text(r.tipoComprobante, style: LuvegiText.caption),
              if (r.ocOrigen.isNotEmpty)
                Text('OC ${r.ocOrigen}', style: LuvegiText.caption),
              celdaImpuesto(r.impuesto),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _filaInfo(
            'Cantidad',
            Text(r.cantidad.toStringAsFixed(2), style: LuvegiText.body),
          ),
          _filaInfo('Precio', _montoTexto(r.precioUnitario)),
          _filaInfo('Moneda', Text(r.moneda, style: LuvegiText.body)),
          _filaInfo('Total', _montoTexto(r.valorConImpuesto)),
          _filaInfo('Total (PEN)', _montoTexto(r.valorNacionalConImpuesto)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String hintBuscador = 'Ej. PV260266';
    if (tipoBusqueda == 'equipo') hintBuscador = 'Ej. SINEQUI o EQ-123';
    if (tipoBusqueda == 'unidad') hintBuscador = 'Ej. RENTA o UN-123';

    String tituloColumnaFinal = 'Pedido';
    if (tipoBusqueda == 'equipo') tituloColumnaFinal = 'Equipo';
    if (tipoBusqueda == 'unidad') tituloColumnaFinal = 'Unidad de Negocio';

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
                                Icons.receipt_long_rounded,
                                color: LuvegiColors.secondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: LuvegiSpacing.sm),
                            Expanded(
                              child: Text(
                                'Análisis de Pedido',
                                style: LuvegiText.title.copyWith(fontSize: 17),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: LuvegiSpacing.xs),
                        Text(
                          'Ingresos, Egresos y Stock filtrado por cuenta analítica.',
                          style: LuvegiText.bodySecondary,
                        ),
                        const SizedBox(height: LuvegiSpacing.sm),
                        Row(
                          children: [
                            if (filas.isNotEmpty) ...[
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
                                    : () => _buscarConsolidado(pagina: 1),
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
                            Icons.receipt_long_rounded,
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
                                'Análisis de Pedido',
                                style: LuvegiText.title.copyWith(fontSize: 20),
                              ),
                              const SizedBox(height: LuvegiSpacing.xs),
                              Text(
                                'Ingresos, Egresos y Stock filtrado por cuenta analítica.',
                                style: LuvegiText.bodySecondary,
                              ),
                            ],
                          ),
                        ),
                        if (filas.isNotEmpty) ...[
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
                              : () => _buscarConsolidado(pagina: 1),
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
                            onSubmitted: (_) => _buscarConsolidado(pagina: 1),
                            decoration: InputDecoration(
                              labelText: 'Buscar por $tituloColumnaFinal',
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildSegmentedFilter(),
                              const SizedBox(width: LuvegiSpacing.md),
                              Expanded(
                                child: TextField(
                                  controller: _busquedaController,
                                  onSubmitted: (_) =>
                                      _buscarConsolidado(pagina: 1),
                                  decoration: InputDecoration(
                                    labelText: 'Buscar por $tituloColumnaFinal',
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
                              const SizedBox(width: LuvegiSpacing.sm),
                              Flexible(child: _buildResumenes()),
                            ],
                          ),
                        ],
                        if (esMovil) ...[
                          const SizedBox(height: LuvegiSpacing.sm),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildResumenes(),
                          ),
                        ],
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
                              'Selecciona el tipo de filtro y busca.',
                              style: LuvegiText.bodySecondary,
                            ),
                          )
                        : esMovil
                        ? _buildTarjetasConsolidado(tituloColumnaFinal)
                        : LuvegiCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                LuvegiRadius.lg,
                              ),
                              child: DataTable2(
                                minWidth: 3380,
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
                                  columna('Origen', width: 120),
                                  columna('Contacto', width: 220),
                                  columna('RUC', width: 130),
                                  columna('OC / OV Origen', width: 180),
                                  columna('Tipo Comprobante', width: 180),
                                  columna('N° Comprobante', width: 220),
                                  columna('Fecha', width: 120),
                                  columna(tituloColumnaFinal, width: 130),
                                  columna('Cod. Producto', width: 110),
                                  columna('Producto', width: 280),
                                  columna('Descripción', width: 250),
                                  columna('% Analítico', width: 110),
                                  columna('Cantidad', width: 110),
                                  columna('Precio', width: 120),
                                  columna('Moneda', width: 80),
                                  columna('Tipo Impuestos', width: 140),
                                  columna('Con Impuestos excl.', width: 150),
                                  columna('Con Impuestos inc.', width: 150),
                                  columna('Tipo de Cambio', width: 130),
                                  columna('Con Impuestos excl. (PEN)', width: 180),
                                  columna('Con Impuestos inc. (PEN)', width: 180),
                                ],
                                rows: filas.map((ItemReporteConsolidado r) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        celdaBadgeOrigen(r.tipoRegistro),
                                      ),
                                      DataCell(celda(r.contacto)),
                                      DataCell(celda(r.ruc)),
                                      DataCell(
                                        celda(
                                          r.ocOrigen,
                                          color: LuvegiColors.secondary,
                                        ),
                                      ),
                                      DataCell(celda(r.tipoComprobante)),
                                      DataCell(InkWell(
                                        onTap: r.link.isNotEmpty
                                            ? () => _abrirEnOdoo(r)
                                            : null,
                                        child: celda(
                                          r.link.isNotEmpty
                                              ? '${r.numeroComprobante} ↗'
                                              : r.numeroComprobante,
                                          color: r.link.isNotEmpty
                                              ? LuvegiColors.secondary
                                              : null,
                                        ),
                                      )),
                                      DataCell(
                                        celda(
                                          r.fechaEmision.isNotEmpty
                                              ? r.fechaEmision
                                              : r.fechaKardex,
                                        ),
                                      ),
                                      DataCell(
                                        celda(
                                          r.pedido,
                                          color: LuvegiColors.secondary,
                                        ),
                                      ),
                                      DataCell(celda(r.codigoProducto)),
                                      DataCell(celda(r.producto)),
                                      DataCell(celda(r.etiqueta)),
                                      DataCell(
                                        celda(
                                          '${r.porcentajeAnalitico.toStringAsFixed(2)}%',
                                          align: TextAlign.center,
                                        ),
                                      ),
                                      DataCell(
                                        celda(
                                          r.cantidad.toStringAsFixed(2),
                                          align: TextAlign.right,
                                        ),
                                      ),
                                      DataCell(celdaMoneda(r.precioUnitario)),
                                      DataCell(celda(r.moneda)),
                                      DataCell(celdaImpuesto(r.impuesto)),
                                      DataCell(celdaMoneda(r.valorMoneda)),
                                      DataCell(celdaMoneda(r.valorConImpuesto)),
                                      DataCell(
                                        celda(
                                          r.tipoCambio.toStringAsFixed(4),
                                          align: TextAlign.right,
                                        ),
                                      ),
                                      DataCell(
                                        celdaMoneda(r.valorMonedaNacional),
                                      ),
                                      DataCell(
                                        celdaMoneda(r.valorNacionalConImpuesto),
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
                                    ? () => _buscarConsolidado(
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
                                    ? () => _buscarConsolidado(
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
                                items: const [25, 100, 500, 1000].map((
                                  int value,
                                ) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(
                                      value == 1000 ? 'Todos' : '$value',
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
                                          _buscarConsolidado(pagina: 1);
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
                                items: const [25, 100, 500, 1000].map((
                                  int value,
                                ) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(
                                      value == 1000 ? 'Todos' : '$value',
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
                                          _buscarConsolidado(pagina: 1);
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
                                    ? () => _buscarConsolidado(
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
                                    ? () => _buscarConsolidado(
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
}