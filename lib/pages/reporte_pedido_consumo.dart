import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../services/reporte_pedido_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

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
  final double precioOrigen;
  final double tipoCambio;
  final double precioPen;
  final String cuentaAnalitica;
  final String unidadNegocio;
  final String equipo;
  final String pedido;
  final String origen;

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
    required this.precioOrigen,
    required this.tipoCambio,
    required this.precioPen,
    required this.cuentaAnalitica,
    required this.unidadNegocio,
    required this.equipo,
    required this.pedido,
    required this.origen,
  });

  factory ItemReporteConsumo.fromJson(Map<String, dynamic> json) {
    return ItemReporteConsumo(
      fecha: (json['FECHA'] ?? '').toString(),
      proveedor: (json['PROVEEDOR'] ?? '').toString(),
      tipoOperacionComprobante: (json['TIPO OPERACION / COMPROBANTE'] ?? '').toString(),
      refComprobante: (json['REF. COMPROBANTE'] ?? '').toString(),
      refOrigen: (json['REF. ORIGEN'] ?? '').toString(),
      codigoProducto: (json['CODIGO PRODUCTO'] ?? '').toString(),
      producto: (json['PRODUCTO'] ?? '').toString(),
      etiqueta: (json['ETIQUETA'] ?? '').toString(),
      cantidad: double.tryParse('${json['CANTIDAD']}') ?? 0.0,
      moneda: (json['MONEDA'] ?? 'PEN').toString(),
      precioOrigen: double.tryParse('${json['PRECIO ORIGEN']}') ?? 0.0,
      tipoCambio: double.tryParse('${json['TIPO CAMBIO']}') ?? 1.0,
      precioPen: double.tryParse('${json['PRECIO (PEN)']}') ?? 0.0,
      cuentaAnalitica: (json['CUENTA ANALITICA'] ?? '').toString(),
      unidadNegocio: (json['UNIDAD DE NEGOCIO'] ?? '').toString(),
      equipo: (json['EQUIPO'] ?? '').toString(),
      pedido: (json['PEDIDO'] ?? '').toString(),
      origen: (json['ORIGEN'] ?? '').toString(),
    );
  }
}

class ReporteConsumoPage extends StatefulWidget {
  final String? token;

  const ReporteConsumoPage({super.key, this.token});

  @override
  State<ReporteConsumoPage> createState() => _ReporteConsumoPageState();
}

class _ReporteConsumoPageState extends State<ReporteConsumoPage> {
  final _service = ReporteConsumoService();
  final _busquedaController = TextEditingController();

  bool cargando = false;
  String? error;
  List<ItemReporteConsumo> filas = [];

  // Paginación
  int paginaActual = 1;
  int totalPaginas = 1;
  int totalRegistros = 0;
  double gastoTotalGeneral = 0.0;
  int limitePorPagina = 25;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _buscarConsumo({int pagina = 1}) async {
    final query = _busquedaController.text.trim();

    if (query.isEmpty) {
      setState(() {
        error = 'Ingresa un número de pedido para consultar (Ej: GE00088).';
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

    try {
      final res = await _service.consultarConsumo(
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
      if (mounted) setState(() => cargando = false);
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
                          'Reporte por Consumo (V26)',
                          style: LuvegiText.title.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: LuvegiSpacing.xs),
                        Text(
                          'Consolidado analítico optimizado por número de pedido.',
                          style: LuvegiText.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  LuvegiButton.primary(
                    text: cargando ? 'Buscando...' : 'Buscar',
                    icon: Icons.search_rounded,
                    loading: cargando,
                    onPressed: cargando ? null : () => _buscarConsumo(pagina: 1),
                  ),
                ],
              ),
              const SizedBox(height: LuvegiSpacing.md),
              LuvegiCard(
                padding: const EdgeInsets.all(LuvegiSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _busquedaController,
                        onSubmitted: (_) => _buscarConsumo(pagina: 1),
                        decoration: InputDecoration(
                          labelText: 'Número de Pedido',
                          hintText: 'Ej. GE00088',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: LuvegiColors.secondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                            borderSide: const BorderSide(color: LuvegiColors.border),
                          ),
                          filled: true,
                          fillColor: LuvegiColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: LuvegiSpacing.lg),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: LuvegiColors.surfaceHover,
                        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
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
                            style: LuvegiText.title.copyWith(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: LuvegiSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: LuvegiColors.secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                        border: Border.all(color: LuvegiColors.secondary.withOpacity(0.3)),
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
                            'S/ ${gastoTotalGeneral.toStringAsFixed(2)}',
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
                              child: DataTable2(
                                minWidth: 2800,
                                fixedTopRows: 1,
                                headingRowHeight: 48,
                                dataRowHeight: 52,
                                columnSpacing: 10,
                                horizontalMargin: 12,
                                headingRowColor: WidgetStateProperty.all(LuvegiColors.menuHover),
                                border: TableBorder.all(color: LuvegiColors.border),
                                columns: [
                                  columna('FECHA', width: 100),
                                  columna('PROVEEDOR', width: 220),
                                  columna('TIPO OPERACION / COMPROBANTE', width: 220),
                                  columna('REF. COMPROBANTE', width: 160),
                                  columna('REF. ORIGEN', width: 130),
                                  columna('CODIGO PRODUCTO', width: 140),
                                  columna('PRODUCTO', width: 280),
                                  columna('ETIQUETA', width: 220),
                                  columna('CANTIDAD', width: 100),
                                  columna('MONEDA', width: 80),
                                  columna('PRECIO ORIGEN', width: 120),
                                  columna('TIPO CAMBIO', width: 100),
                                  columna('PRECIO (PEN)', width: 120),
                                  columna('CUENTA ANALITICA', width: 140),
                                  columna('UNIDAD DE NEGOCIO', width: 150),
                                  columna('EQUIPO', width: 120),
                                  columna('PEDIDO', width: 140),
                                  columna('ORIGEN', width: 120),
                                ],
                                rows: filas.map((r) {
                                  return DataRow(cells: [
                                    DataCell(celda(r.fecha)),
                                    DataCell(celda(r.proveedor)),
                                    DataCell(celda(r.tipoOperacionComprobante)),
                                    DataCell(celda(r.refComprobante)),
                                    DataCell(celda(r.refOrigen)),
                                    DataCell(celda(r.codigoProducto)),
                                    DataCell(celda(r.producto)),
                                    DataCell(celda(r.etiqueta)),
                                    DataCell(celda(r.cantidad.toStringAsFixed(2), align: TextAlign.right)),
                                    DataCell(celda(r.moneda)),
                                    DataCell(celda(r.precioOrigen.toStringAsFixed(2), align: TextAlign.right)),
                                    DataCell(celda(r.tipoCambio.toStringAsFixed(4), align: TextAlign.right)),
                                    DataCell(celda(r.precioPen.toStringAsFixed(2), align: TextAlign.right)),
                                    DataCell(celda(r.cuentaAnalitica)),
                                    DataCell(celda(r.unidadNegocio)),
                                    DataCell(celda(r.equipo)),
                                    DataCell(celda(r.pedido, color: LuvegiColors.secondary)),
                                    DataCell(celda(r.origen)),
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
                    Text(
                      'Página $paginaActual de $totalPaginas',
                      style: LuvegiText.caption.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: paginaActual > 1 && !cargando
                              ? () => _buscarConsumo(pagina: paginaActual - 1)
                              : null,
                        ),
                        Text(
                          '$paginaActual',
                          style: LuvegiText.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: paginaActual < totalPaginas && !cargando
                              ? () => _buscarConsumo(pagina: paginaActual + 1)
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