import 'dart:typed_data';
import 'package:data_table_2/data_table_2.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../services/reporte_consolidado_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

class ItemReporteConsolidado {
  final String tipoRegistro;
  final String contacto;
  final String ruc;
  final String etiqueta;
  final String tipoComprobante;
  final String numeroComprobante;
  final String refOrigen;
  final String producto;
  final double cantidad;
  final double precioUnitario;
  final String impuesto;
  final String moneda;
  final double valorMoneda;
  final double valorMonedaNacional;
  final double valorConImpuesto;
  final double valorNacionalConImpuesto;
  final double tipoCambio;
  final String pedido;

  ItemReporteConsolidado({
    required this.tipoRegistro,
    required this.contacto,
    required this.ruc,
    required this.etiqueta,
    required this.tipoComprobante,
    required this.numeroComprobante,
    required this.refOrigen,
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    required this.impuesto,
    required this.moneda,
    required this.valorMoneda,
    required this.valorMonedaNacional,
    required this.valorConImpuesto,
    required this.valorNacionalConImpuesto,
    required this.tipoCambio,
    required this.pedido,
  });

  factory ItemReporteConsolidado.fromJson(Map<String, dynamic> json) {
    return ItemReporteConsolidado(
      tipoRegistro: (json['TIPO REGISTRO'] ?? '—').toString(),
      contacto: (json['CONTACTO'] ?? '').toString(),
      ruc: (json['RUC'] ?? '').toString(),
      etiqueta: (json['ETIQUETA'] ?? '—').toString(),
      tipoComprobante: (json['TIPO COMPROBANTE'] ?? '').toString(),
      numeroComprobante: (json['NUMERO COMPROBANTE'] ?? '').toString(),
      refOrigen: (json['REF. ORIGEN'] ?? '').toString(),
      producto: (json['PRODUCTO'] ?? '').toString(),
      cantidad: double.tryParse('${json['CANTIDAD']}') ?? 0.0,
      precioUnitario: double.tryParse('${json['PRECIO UNITARIO']}') ?? 0.0,
      impuesto: (json['IMPUESTO'] ?? '—').toString(),
      moneda: (json['MONEDA'] ?? 'PEN').toString(),
      valorMoneda: double.tryParse('${json['VALOR EN MONEDA']}') ?? 0.0,
      valorMonedaNacional: double.tryParse('${json['VALOR EN MONEDA NACIONAL']}') ?? 0.0,
      valorConImpuesto: double.tryParse('${json['VALOR CON IMPUESTO']}') ?? 0.0,
      valorNacionalConImpuesto: double.tryParse('${json['VALOR NACIONAL CON IMPUESTO']}') ?? 0.0,
      tipoCambio: double.tryParse('${json['TIPO DE CAMBIO']}') ?? 1.0,
      pedido: (json['PEDIDO'] ?? '').toString(),
    );
  }
}

class ReporteConsolidadoPage extends StatefulWidget {
  final String? token;

  const ReporteConsolidadoPage({super.key, this.token});

  @override
  State<ReporteConsolidadoPage> createState() => _ReporteConsolidadoPageState();
}

class _ReporteConsolidadoPageState extends State<ReporteConsolidadoPage> {
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

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _buscarConsolidado({int pagina = 1}) async {
    final query = _busquedaController.text.trim();

    if (query.isEmpty) {
      setState(() {
        error = 'Ingresa un número de pedido para consultar.';
        filas = [];
        totalRegistros = 0;
        montoTotalNeto = 0.0;
        montoTotalGeneral = 0.0;
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

    try {
      final res = await _service.consultarConsolidado(
        widget.token ?? '',
        pedido: query,
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filas = [];
        totalRegistros = 0;
        montoTotalNeto = 0.0;
        montoTotalGeneral = 0.0;
        montoIngresosNeto = 0.0;
        montoEgresosNeto = 0.0;
        totalPaginas = 1;
      });
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _exportarAExcel() async {
    if (filas.isEmpty) return;

    setState(() => exportando = true);

    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Consolidado'];
      excel.delete('Sheet1');

      sheet.appendRow([
        excel_lib.TextCellValue('Origen'),
        excel_lib.TextCellValue('Contacto'),
        excel_lib.TextCellValue('RUC'),
        excel_lib.TextCellValue('Etiqueta'),
        excel_lib.TextCellValue('Tipo Comprobante'),
        excel_lib.TextCellValue('N° Comprobante'),
        excel_lib.TextCellValue('Ref. Origen'),
        excel_lib.TextCellValue('Producto'),
        excel_lib.TextCellValue('Cantidad'),
        excel_lib.TextCellValue('Precio'),
        excel_lib.TextCellValue('Moneda'),
        excel_lib.TextCellValue('Impuestos'),
        excel_lib.TextCellValue('Impuestos excl.'),
        excel_lib.TextCellValue('Impuestos inc.'),
        excel_lib.TextCellValue('Tipo de Cambio'),
        excel_lib.TextCellValue('Impuestos excl. (PEN)'),
        excel_lib.TextCellValue('Impuestos inc. (PEN)'),
        excel_lib.TextCellValue('Pedido'),
      ]);

      for (var r in filas) {
        sheet.appendRow([
          excel_lib.TextCellValue(r.tipoRegistro),
          excel_lib.TextCellValue(r.contacto),
          excel_lib.TextCellValue(r.ruc),
          excel_lib.TextCellValue(r.etiqueta),
          excel_lib.TextCellValue(r.tipoComprobante),
          excel_lib.TextCellValue(r.refOrigen),
          excel_lib.TextCellValue(r.numeroComprobante),
          excel_lib.TextCellValue(r.producto),
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
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final nombreArchivo = 'Consolidado_${_busquedaController.text.trim()}_Todo.xlsx';
        await FileSaver.instance.saveFile(
          name: nombreArchivo,
          bytes: Uint8List.fromList(fileBytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => exportando = false);
    }
  }

  // OPTIMIZACIÓN: Quitamos el Tooltip de la celda normal. 
  // Tooltip en 375x18 columnas = 6,750 widgets ocultos escuchando el mouse. ¡Eso mata el rendimiento!
  Widget celda(String texto, {TextAlign align = TextAlign.left, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        texto,
        textAlign: align,
        maxLines: 2, // Le decimos que máximo 2 líneas para que no calcule alturas locas
        overflow: TextOverflow.ellipsis, // Si es muy largo, pone "..."
        style: LuvegiText.caption.copyWith(
          color: color ?? LuvegiColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget celdaMoneda(double monto, {TextAlign align = TextAlign.right}) {
    final bool esNegativo = monto < 0;
    final Color colorTexto = esNegativo ? LuvegiColors.error : LuvegiColors.textPrimary;
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
      case 'inventario':
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

  Widget _buildSummaryCard(String title, String value, {required Color color, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor ?? LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: bgColor != null ? color.withOpacity(0.3) : LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: LuvegiText.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color == LuvegiColors.textPrimary ? LuvegiColors.textSecondary : color,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuvegiColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LuvegiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: LuvegiColors.menuHover,
                      borderRadius: BorderRadius.circular(LuvegiRadius.md),
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
                          'Reporte Financiero por Pedido',
                          style: LuvegiText.title.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: LuvegiSpacing.xs),
                        Text(
                          'Ingresos, Egresos y Stock (Incluye Venta Nacional según Op. SUNAT).',
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, color: Colors.green),
                    ),
                    const SizedBox(width: LuvegiSpacing.sm),
                  ],
                  LuvegiButton.primary(
                    text: cargando ? 'Buscando...' : 'Buscar',
                    icon: Icons.search_rounded,
                    loading: cargando,
                    onPressed: cargando ? null : () => _buscarConsolidado(pagina: 1),
                  ),
                ],
              ),
              const SizedBox(height: LuvegiSpacing.md),

              LuvegiCard(
                padding: const EdgeInsets.all(LuvegiSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _busquedaController,
                            onSubmitted: (_) => _buscarConsolidado(pagina: 1),
                            decoration: InputDecoration(
                              labelText: 'Número de Pedido',
                              hintText: 'Ej. PV260266',
                              prefixIcon: const Icon(Icons.search_rounded, color: LuvegiColors.secondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                                borderSide: const BorderSide(color: LuvegiColors.border),
                              ),
                              filled: true,
                              fillColor: LuvegiColors.surface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    Wrap(
                      spacing: LuvegiSpacing.sm,
                      runSpacing: LuvegiSpacing.sm,
                      children: [
                        _buildSummaryCard('REGISTROS', '$totalRegistros', color: LuvegiColors.textPrimary),
                        _buildSummaryCard('INGRESOS (VENTAS NETAS)', 'S/ ${montoIngresosNeto.toStringAsFixed(2)}', color: Colors.green.shade700, bgColor: Colors.green.shade50),
                        _buildSummaryCard('EGRESOS (COMPRAS/STOCK)', 'S/ -${montoEgresosNeto.toStringAsFixed(2)}', color: LuvegiColors.error, bgColor: LuvegiColors.error.withOpacity(0.08)),
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
                    color: LuvegiColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                    border: Border.all(color: LuvegiColors.error.withOpacity(0.35)),
                  ),
                  child: Text(error!, style: LuvegiText.body.copyWith(color: LuvegiColors.error)),
                ),
              ],

              const SizedBox(height: LuvegiSpacing.md),

              Expanded(
                child: cargando
                    ? const Center(child: CircularProgressIndicator())
                    : filas.isEmpty
                        ? Center(
                            child: Text(
                              'Ingresa un número de pedido arriba y presiona "Buscar".',
                              style: LuvegiText.bodySecondary,
                            ),
                          )
                        : LuvegiCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(LuvegiRadius.lg),
                              // OPTIMIZACIÓN EXTREMA: Agregamos parámetros de rendimiento al DataTable2
                             child: DataTable2(
                                minWidth: 3250,
                                fixedTopRows: 1,
                                headingRowHeight: 48,
                                dataRowHeight: 52, // Esto es lo que realmente hace que el scroll vuele 🚀
                                columnSpacing: 10,
                                horizontalMargin: 12,
                                headingRowColor: WidgetStateProperty.all(LuvegiColors.menuHover),
                                border: TableBorder.all(color: LuvegiColors.border),
                                // Quitamos las dos líneas que daban error
                                columns: [
                                  columna('Origen', width: 120),
                                  columna('Contacto', width: 220),
                                  columna('Ruc', width: 130),
                                  columna('Etiqueta', width: 250),
                                  columna('Tipo Comprobante', width: 180),
                                  columna('N° Comprobante', width: 220),
                                  columna('Ref. Origen', width: 250),
                                  columna('Producto', width: 280),
                                  columna('Cantidad', width: 110),
                                  columna('Precio', width: 120),
                                  columna('Moneda', width: 80),
                                  columna('Impuestos', width: 140),
                                  columna('Impuestos excl.', width: 150),
                                  columna('Impuestos inc.', width: 150),
                                  columna('Tipo de Cambio', width: 130),
                                  columna('Impuestos excl. (PEN)', width: 170),
                                  columna('Impuestos inc. (PEN)', width: 170),
                                  columna('Pedido', width: 130),
                                ],
                                rows: filas.map((r) {
                                  return DataRow(cells: [
                                    DataCell(celdaBadgeOrigen(r.tipoRegistro)),
                                    DataCell(celda(r.contacto)),
                                    DataCell(celda(r.ruc)),
                                    DataCell(celda(r.etiqueta)),
                                    DataCell(celda(r.tipoComprobante)),
                                    DataCell(celda(r.refOrigen, color: LuvegiColors.secondary)),
                                    DataCell(celda(r.numeroComprobante)),
                                    DataCell(celda(r.producto)),
                                    DataCell(celda(r.cantidad.toStringAsFixed(2), align: TextAlign.right)),
                                    DataCell(celdaMoneda(r.precioUnitario)),
                                    DataCell(celda(r.moneda)),
                                    DataCell(celdaImpuesto(r.impuesto)),
                                    DataCell(celdaMoneda(r.valorMoneda)),
                                    DataCell(celdaMoneda(r.valorConImpuesto)),
                                    DataCell(celda(r.tipoCambio.toStringAsFixed(4), align: TextAlign.right)),
                                    DataCell(celdaMoneda(r.valorMonedaNacional)),
                                    DataCell(celdaMoneda(r.valorNacionalConImpuesto)),
                                    DataCell(celda(r.pedido, color: LuvegiColors.secondary)),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
              ),

              if (totalRegistros > 0) ...[
                const SizedBox(height: LuvegiSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Mostrar: ',
                          style: LuvegiText.caption.copyWith(fontWeight: FontWeight.bold),
                        ),
                        DropdownButton<int>(
                          value: limitePorPagina,
                          isDense: true,
                          underline: const SizedBox(),
                          items: const [25, 100, 500, 1000].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value == 1000 ? 'Todos' : '$value', style: LuvegiText.caption),
                            );
                          }).toList(),
                          onChanged: cargando
                              ? null
                              : (nuevoLimite) {
                                  if (nuevoLimite != null && nuevoLimite != limitePorPagina) {
                                    setState(() => limitePorPagina = nuevoLimite);
                                    _buscarConsolidado(pagina: 1);
                                  }
                                },
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Página $paginaActual de $totalPaginas (${filas.length} vis. de $totalRegistros)',
                          style: LuvegiText.caption.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: paginaActual > 1 && !cargando
                              ? () => _buscarConsolidado(pagina: paginaActual - 1)
                              : null,
                        ),
                        Text(
                          '$paginaActual',
                          style: LuvegiText.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: paginaActual < totalPaginas && !cargando
                              ? () => _buscarConsolidado(pagina: paginaActual + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}