import 'dart:typed_data';
import 'package:data_table_2/data_table_2.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../design_system/luvegi_loading.dart';
import '../models/item_reporte_detalle_anual.dart';
import '../services/reporte_detalle_anual_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../utils/mensaje_error.dart';

class ReporteDetalleAnualPage extends StatefulWidget {
  final String? token;
  const ReporteDetalleAnualPage({super.key, this.token});

  @override
  State<ReporteDetalleAnualPage> createState() => _ReporteDetalleAnualPageState();
}

class _ReporteDetalleAnualPageState extends State<ReporteDetalleAnualPage>
    with LuvegiProgresoMixin {
  final _service = ReporteDetalleAnualService();

  bool cargando = false;
  bool exportando = false;
  String? error;
  int anio = 2026;
  List<ItemReporteDetalleAnual> filas = [];

  int totalPedidos = 0;
  double montoTotalIngresos = 0.0;
  double montoTotalEgresos = 0.0;
  double montoTotalMargen = 0.0;

  @override
  void dispose() {
    cancelarProgresoTimer();
    super.dispose();
  }

  Future<void> _buscarAnual() async {
    setState(() {
      cargando = true;
      error = null;
    });

    iniciarProgreso();

    try {
      final res = await _service.consultarAnual(
        widget.token ?? '',
        anio: '$anio',
      );
      if (!mounted) return;
      setState(() {
        filas = res.items;
        totalPedidos = res.totalPedidos;
        montoTotalIngresos = res.montoTotalIngresos;
        montoTotalEgresos = res.montoTotalEgresos;
        montoTotalMargen = res.montoTotalMargen;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filas = [];
        totalPedidos = 0;
        montoTotalIngresos = 0.0;
        montoTotalEgresos = 0.0;
        montoTotalMargen = 0.0;
      });
    } finally {
      if (mounted) {
        detenerProgreso();
        setState(() => cargando = false);
      }
    }
  }

  Future<void> _exportarAExcel() async {
    setState(() => exportando = true);
    try {
      final res = await _service.consultarAnual(
        widget.token ?? '',
        anio: '$anio',
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
      final sheet = excel['Detalle Anual'];
      excel.delete('Sheet1');

      sheet.appendRow([
        excel_lib.TextCellValue('Pedido'),
        excel_lib.TextCellValue('Ingreso (Neto PEN)'),
        excel_lib.TextCellValue('Egreso (Neto PEN)'),
        excel_lib.TextCellValue('Margen'),
        excel_lib.TextCellValue('Margen %'),
      ]);

      for (var r in todasLasFilas) {
        sheet.appendRow([
          excel_lib.TextCellValue(r.pedido),
          excel_lib.DoubleCellValue(r.ingreso),
          excel_lib.DoubleCellValue(r.egreso),
          excel_lib.DoubleCellValue(r.margen),
          excel_lib.DoubleCellValue(r.porcentajeMargen),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final nombreArchivo = 'DetalleAnual_$anio.xlsx';
        await FileSaver.instance.saveFile(
          name: nombreArchivo,
          bytes: Uint8List.fromList(fileBytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
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

  DataColumn columna(String texto) {
    return DataColumn2(
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
          'PEDIDOS',
          '$totalPedidos',
          color: LuvegiColors.textPrimary,
        ),
        _buildSummaryCard(
          'INGRESOS (NETO PEN)',
          'S/ ${montoTotalIngresos.toStringAsFixed(2)}',
          color: Colors.green.shade700,
          bgColor: Colors.green.shade50,
        ),
        _buildSummaryCard(
          'EGRESOS (NETO PEN)',
          'S/ ${montoTotalEgresos.toStringAsFixed(2)}',
          color: LuvegiColors.error,
          bgColor: LuvegiColors.error.withValues(alpha: 0.08),
        ),
        _buildSummaryCard(
          'MARGEN',
          'S/ ${montoTotalMargen.toStringAsFixed(2)}',
          color: montoTotalMargen < 0
              ? LuvegiColors.error
              : LuvegiColors.secondary,
          bgColor: montoTotalMargen < 0
              ? LuvegiColors.error.withValues(alpha: 0.08)
              : LuvegiColors.secondary.withValues(alpha: 0.08),
        ),
      ],
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

  Widget _montoTexto(double monto, {Color? color}) => Text(
    monto.toStringAsFixed(2),
    style: LuvegiText.body.copyWith(
      color: color ?? (monto < 0 ? LuvegiColors.error : LuvegiColors.textPrimary),
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildTarjetasAnual() => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: filas.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, i) => _tarjetaAnual(filas[i]),
  );

  Widget _tarjetaAnual(ItemReporteDetalleAnual r) {
    final bool margenNegativo = r.margen < 0;
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      (margenNegativo
                              ? LuvegiColors.error
                              : LuvegiColors.success)
                          .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${r.porcentajeMargen.toStringAsFixed(2)} %',
                  style: LuvegiText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: margenNegativo
                        ? LuvegiColors.error
                        : LuvegiColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _filaInfo('Ingreso (Neto)', _montoTexto(r.ingreso)),
          _filaInfo('Egreso (Neto)', _montoTexto(r.egreso)),
          _filaInfo(
            'Margen',
            _montoTexto(
              r.margen,
              color: margenNegativo
                  ? LuvegiColors.error
                  : LuvegiColors.success,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          Icons.calendar_month_rounded,
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
                              'Reporte de Detalle Anual',
                              style: LuvegiText.title.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: LuvegiSpacing.xs),
                            Text(
                              'Ingresos, Egresos y Margen por pedido del año seleccionado.',
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
                        onPressed: cargando ? null : _buscarAnual,
                      ),
                    ],
                  ),
                  const SizedBox(height: LuvegiSpacing.md),

                  LuvegiCard(
                    padding: EdgeInsets.all(
                      esMovil ? LuvegiSpacing.sm : LuvegiSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (esMovil) ...[
                          DropdownButtonFormField<int>(
                            initialValue: anio,
                            decoration: InputDecoration(
                              labelText: 'Año',
                              prefixIcon: const Icon(
                                Icons.calendar_month_rounded,
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
                            items: [2024, 2025, 2026, 2027].map((int valor) {
                              return DropdownMenuItem<int>(
                                value: valor,
                                child: Text('$valor'),
                              );
                            }).toList(),
                            onChanged: cargando
                                ? null
                                : (nuevoAnio) {
                                    if (nuevoAnio != null) {
                                      setState(() => anio = nuevoAnio);
                                    }
                                  },
                          ),
                          const SizedBox(height: LuvegiSpacing.sm),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildResumenes(),
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<int>(
                                  initialValue: anio,
                                  decoration: InputDecoration(
                                    labelText: 'Año',
                                    prefixIcon: const Icon(
                                      Icons.calendar_month_rounded,
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
                                  items: [2024, 2025, 2026, 2027]
                                      .map((int valor) {
                                    return DropdownMenuItem<int>(
                                      value: valor,
                                      child: Text('$valor'),
                                    );
                                  }).toList(),
                                  onChanged: cargando
                                      ? null
                                      : (nuevoAnio) {
                                          if (nuevoAnio != null) {
                                            setState(() => anio = nuevoAnio);
                                          }
                                        },
                                ),
                              ),
                              const SizedBox(width: LuvegiSpacing.md),
                              Expanded(child: _buildResumenes()),
                            ],
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
                              'Selecciona el año y busca.',
                              style: LuvegiText.bodySecondary,
                            ),
                          )
                        : esMovil
                        ? _buildTarjetasAnual()
                        : LuvegiCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                LuvegiRadius.lg,
                              ),
                              child: DataTable2(
                                minWidth: 900,
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
                                  columna('Pedido'),
                                  columna('Ingreso (Neto PEN)'),
                                  columna('Egreso (Neto PEN)'),
                                  columna('Margen'),
                                  columna('Margen %'),
                                ],
                                rows: filas.map((ItemReporteDetalleAnual r) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        celda(
                                          r.pedido,
                                          color: LuvegiColors.secondary,
                                        ),
                                      ),
                                      DataCell(celdaMoneda(r.ingreso)),
                                      DataCell(celdaMoneda(r.egreso)),
                                      DataCell(celdaMoneda(r.margen)),
                                      DataCell(
                                        celda(
                                          '${r.porcentajeMargen.toStringAsFixed(2)} %',
                                          align: TextAlign.right,
                                          color: r.porcentajeMargen < 0
                                              ? LuvegiColors.error
                                              : LuvegiColors.success,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}