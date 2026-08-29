import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../services/reporte_ventas_compras_service.dart';

/// Modelo de datos consolidado que une Líneas de Venta y Órdenes de Compra por Pedido
class ReporteVentaCompraConsolidado {
  // Datos de Ventas
  final String concepto;
  final String numeroOrdenVenta;
  final String cliente;
  final String ruc;
  final String ejecutivoLuvegi;
  final String fechaCreacion;
  final String fechaConfirmacionVenta;
  final String unidadNegocioVenta;
  final String pedido;
  final String productoVenta;
  final String monedaVenta;
  final String unidadMedida;
  final String cantidadVenta;
  final String cantidadEntregada;
  final String cantidadPorEntregar;
  final String cantidadFacturada;
  final String precioUnitarioVenta;
  final String descuentoPorcentaje;
  final String descuentoOtorgado;
  final String precioTotalSinImpVenta;
  final String precioTotalConImpVenta;

  // Datos de Compras
  final String ordenCompra;
  final String proveedor;
  final String fechaConfirmacionCompra;
  final String divisaCompra;
  final String productoCompra;
  final String descripcionCompra;
  final String cantidadCompra;
  final String unidadNegocioCompra;
  final String equipo;
  final String precioUnitarioCompra;
  final String sinImpuestoCompra;
  final String conImpuestoCompra;

  const ReporteVentaCompraConsolidado({
    required this.concepto,
    required this.numeroOrdenVenta,
    required this.cliente,
    required this.ruc,
    required this.ejecutivoLuvegi,
    required this.fechaCreacion,
    required this.fechaConfirmacionVenta,
    required this.unidadNegocioVenta,
    required this.pedido,
    required this.productoVenta,
    required this.monedaVenta,
    required this.unidadMedida,
    required this.cantidadVenta,
    required this.cantidadEntregada,
    required this.cantidadPorEntregar,
    required this.cantidadFacturada,
    required this.precioUnitarioVenta,
    required this.descuentoPorcentaje,
    required this.descuentoOtorgado,
    required this.precioTotalSinImpVenta,
    required this.precioTotalConImpVenta,
    required this.ordenCompra,
    required this.proveedor,
    required this.fechaConfirmacionCompra,
    required this.divisaCompra,
    required this.productoCompra,
    required this.descripcionCompra,
    required this.cantidadCompra,
    required this.unidadNegocioCompra,
    required this.equipo,
    required this.precioUnitarioCompra,
    required this.sinImpuestoCompra,
    required this.conImpuestoCompra,
  });

  factory ReporteVentaCompraConsolidado.fromJson(Map<String, dynamic> json) {
    return ReporteVentaCompraConsolidado(
      concepto: (json['concepto'] ?? '—').toString(),
      numeroOrdenVenta: (json['numero_orden_venta'] ?? '—').toString(),
      cliente: (json['cliente'] ?? '—').toString(),
      ruc: (json['ruc'] ?? '—').toString(),
      ejecutivoLuvegi: (json['ejecutivo_luvegi'] ?? '—').toString(),
      fechaCreacion: (json['fecha_creacion'] ?? '—').toString(),
      fechaConfirmacionVenta: (json['fecha_confirmacion_venta'] ?? '—').toString(),
      unidadNegocioVenta: (json['unidad_negocio_venta'] ?? '—').toString(),
      pedido: (json['pedido'] ?? '—').toString(),
      productoVenta: (json['producto_venta'] ?? '—').toString(),
      monedaVenta: (json['moneda_venta'] ?? '—').toString(),
      unidadMedida: (json['unidad_medida'] ?? '—').toString(),
      cantidadVenta: (json['cantidad_venta'] ?? '0').toString(),
      cantidadEntregada: (json['cantidad_entregada'] ?? '0').toString(),
      cantidadPorEntregar: (json['cantidad_por_entregar'] ?? '0').toString(),
      cantidadFacturada: (json['cantidad_facturada'] ?? '0').toString(),
      precioUnitarioVenta: (json['precio_unitario_venta'] ?? '0.00').toString(),
      descuentoPorcentaje: (json['descuento_porcentaje'] ?? '0').toString(),
      descuentoOtorgado: (json['descuento_otorgado'] ?? '0.00').toString(),
      precioTotalSinImpVenta: (json['precio_total_sin_imp_venta'] ?? '0.00').toString(),
      precioTotalConImpVenta: (json['precio_total_con_imp_venta'] ?? '0.00').toString(),
      ordenCompra: (json['orden_compra'] ?? '—').toString(),
      proveedor: (json['proveedor'] ?? '—').toString(),
      fechaConfirmacionCompra: (json['fecha_confirmacion_compra'] ?? '—').toString(),
      divisaCompra: (json['divisa_compra'] ?? '—').toString(),
      productoCompra: (json['producto_compra'] ?? '—').toString(),
      descripcionCompra: (json['descripcion_compra'] ?? '—').toString(),
      cantidadCompra: (json['cantidad_compra'] ?? '0').toString(),
      unidadNegocioCompra: (json['unidad_negocio_compra'] ?? '—').toString(),
      equipo: (json['equipo'] ?? '—').toString(),
      precioUnitarioCompra: (json['precio_unitario_compra'] ?? '0.00').toString(),
      sinImpuestoCompra: (json['sin_impuesto_compra'] ?? '0.00').toString(),
      conImpuestoCompra: (json['con_impuesto_compra'] ?? '0.00').toString(),
    );
  }
}

class ReporteVentasComprasPage extends StatefulWidget {
  final String token;
  final List<String> permisos;

  const ReporteVentasComprasPage({
    super.key,
    required this.token,
    required this.permisos,
  });

  @override
  State<ReporteVentasComprasPage> createState() => _ReporteVentasComprasPageState();
}

class _ReporteVentasComprasPageState extends State<ReporteVentasComprasPage> {
  final _busquedaController = TextEditingController();
  final _serviceConsolidado = ReporteVentasComprasService();

  DateTime? fechaInicio;
  DateTime? fechaFin;
  bool soloPendientesEntrega = false;
  bool cargando = false;
  String? error;

  List<ReporteVentaCompraConsolidado> filasOriginales = [];
  List<ReporteVentaCompraConsolidado> filas = [];

  int page = 1;
  int pageSize = 50;
  int totalPages = 0;
  int totalRegistros = 0;
  double elapsed = 0;

  final DateFormat formatterBackend = DateFormat('yyyy-MM-dd');
  final DateFormat formatterVista = DateFormat('dd/MM/yyyy');

  bool get puedeConsultar => widget.permisos.any(
        (p) => ['CONSULTAR_VENTAS', 'CONSULTAR_COMPRAS'].contains(p.trim().toUpperCase()),
      );

  bool get puedeExportar => widget.permisos.any(
        (p) => p.trim().toUpperCase() == 'EXPORTAR_EXCEL',
      );

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    fechaInicio = DateTime(hoy.year, hoy.month, 1);
    fechaFin = hoy;
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<ReporteVentaCompraConsolidado> _aplicarFiltroPendientes(
    List<ReporteVentaCompraConsolidado> registros,
  ) {
    if (!soloPendientesEntrega) return registros;

    return registros.where((r) {
      final pendiente = double.tryParse(r.cantidadPorEntregar.replaceAll(',', '')) ?? 0;
      return pendiente > 0;
    }).toList();
  }

  Future<void> seleccionarFecha(bool inicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: inicio ? (fechaInicio ?? DateTime.now()) : (fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;

    setState(() {
      if (inicio) {
        fechaInicio = picked;
      } else {
        fechaFin = picked;
      }
    });
  }

  Future<void> buscar({int nuevaPagina = 1}) async {
    if (!puedeConsultar) {
      setState(() => error = 'No tienes permiso para consultar este reporte.');
      return;
    }

    if (fechaInicio == null || fechaFin == null) {
      setState(() => error = 'Selecciona fecha inicio y fecha fin.');
      return;
    }

    if (fechaInicio!.isAfter(fechaFin!)) {
      setState(() => error = 'La fecha inicio no puede ser mayor que la fecha fin.');
      return;
    }

    setState(() {
      cargando = true;
      error = null;
      page = nuevaPagina;
      filasOriginales = [];
      filas = [];
    });

    try {
      final res = await _serviceConsolidado.buscar(
        token: widget.token,
        fechaInicio: formatterBackend.format(fechaInicio!),
        fechaFin: formatterBackend.format(fechaFin!),
        busqueda: _busquedaController.text.trim(),
        page: page,
        pageSize: pageSize,
      );

      if (!mounted) return;

      setState(() {
        filasOriginales = res.data;
        filas = _aplicarFiltroPendientes(res.data);
        page = res.page;
        totalPages = res.totalPages;
        totalRegistros = res.totalRegistros;
        elapsed = res.elapsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filasOriginales = [];
        filas = [];
        totalPages = 0;
        totalRegistros = 0;
        elapsed = 0;
      });
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> exportarExcel() async {
    if (!puedeExportar) {
      setState(() => error = 'No tienes permiso para exportar a Excel.');
      return;
    }

    final fi = formatterBackend.format(fechaInicio!);
    final ff = formatterBackend.format(fechaFin!);
    final busqueda = _busquedaController.text.trim();
    final pendientes = soloPendientesEntrega ? '1' : '0';

    final uri = Uri.https(
      'portal.luvegi.com',
      '/api_luvegi/exportar_ventas_compras.php',
      {
        'fecha_inicio': fi,
        'fecha_fin': ff,
        'busqueda': busqueda,
        'pendientes_entrega': pendientes,
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        setState(() => error = 'No se pudo iniciar la descarga del archivo.');
      }
    }
  }

  String fechaLabel(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar';
    return formatterVista.format(fecha);
  }

  Widget celda(String texto, {TextAlign align = TextAlign.left, Color? textColor}) {
    return Tooltip(
      message: texto,
      waitDuration: const Duration(milliseconds: 600),
      child: Text(
        texto,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: LuvegiText.caption.copyWith(
          color: textColor ?? LuvegiColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  DataColumn columna(String texto, {double width = 140, Color? bgHeader}) {
    return DataColumn2(
      fixedWidth: width,
      label: Text(
        texto,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: LuvegiText.caption.copyWith(
          color: bgHeader ?? LuvegiColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tabla() {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(LuvegiColors.secondary),
        trackColor: WidgetStateProperty.all(LuvegiColors.border),
        radius: const Radius.circular(10),
        thickness: WidgetStateProperty.all(12),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
      ),
      child: DataTable2(
        minWidth: 4800,
        fixedTopRows: 1,
        headingRowHeight: 48,
        dataRowHeight: 52,
        columnSpacing: 10,
        horizontalMargin: 12,
        headingRowColor: WidgetStateProperty.all(LuvegiColors.menuHover),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.hovered)
              ? LuvegiColors.surfaceHover
              : LuvegiColors.surface;
        }),
        border: TableBorder.all(color: LuvegiColors.border),
        columns: [
          // COLUMNAS VENTA
          columna('N° Orden Venta', width: 155),
          columna('Pedido (Clave)', width: 130),
          columna('Cliente', width: 250),
          columna('RUC', width: 110),
          columna('Ejecutivo LUVEGI', width: 150),
          columna('F. Creación Venta', width: 130),
          columna('F. Confirmación Venta', width: 145),
          columna('U. Negocio Venta', width: 140),
          columna('Producto Venta', width: 280),
          columna('Moneda', width: 80),
          columna('U. Medida', width: 110),
          columna('Cant. Venta', width: 100),
          columna('Cant. Entregada', width: 125),
          columna('Cant. por Entregar', width: 135),
          columna('Cant. Facturada', width: 125),
          columna('P. Unit. Sin Imp. (V)', width: 150),
          columna('% Descuento', width: 100),
          columna('P. Total Sin Imp. (V)', width: 150),
          columna('P. Total Con Imp. (V)', width: 150),

          // COLUMNAS COMPRA
          columna('Orden de Compra', width: 140, bgHeader: LuvegiColors.secondary),
          columna('Proveedor', width: 250, bgHeader: LuvegiColors.secondary),
          columna('F. Confirmación Compra', width: 150, bgHeader: LuvegiColors.secondary),
          columna('Divisa Compra', width: 90, bgHeader: LuvegiColors.secondary),
          columna('Producto Compra', width: 250, bgHeader: LuvegiColors.secondary),
          columna('Descripción Compra', width: 300, bgHeader: LuvegiColors.secondary),
          columna('Cant. Compra', width: 110, bgHeader: LuvegiColors.secondary),
          columna('U. Negocio Compra', width: 150, bgHeader: LuvegiColors.secondary),
          columna('Equipo', width: 130, bgHeader: LuvegiColors.secondary),
          columna('P. Unitario Compra', width: 130, bgHeader: LuvegiColors.secondary),
          columna('Sin Impuesto (C)', width: 130, bgHeader: LuvegiColors.secondary),
          columna('Con Impuesto (C)', width: 130, bgHeader: LuvegiColors.secondary),
        ],
        rows: filas.map((r) {
          return DataRow(
            cells: [
              // CELDA VENTA
              DataCell(celda(r.numeroOrdenVenta)),
              DataCell(celda(r.pedido, textColor: LuvegiColors.secondary)),
              DataCell(celda(r.cliente)),
              DataCell(celda(r.ruc)),
              DataCell(celda(r.ejecutivoLuvegi)),
              DataCell(celda(r.fechaCreacion)),
              DataCell(celda(r.fechaConfirmacionVenta)),
              DataCell(celda(r.unidadNegocioVenta)),
              DataCell(celda(r.productoVenta)),
              DataCell(celda(r.monedaVenta)),
              DataCell(celda(r.unidadMedida)),
              DataCell(celda(r.cantidadVenta, align: TextAlign.right)),
              DataCell(celda(r.cantidadEntregada, align: TextAlign.right)),
              DataCell(celda(r.cantidadPorEntregar, align: TextAlign.right)),
              DataCell(celda(r.cantidadFacturada, align: TextAlign.right)),
              DataCell(celda(r.precioUnitarioVenta, align: TextAlign.right)),
              DataCell(celda(r.descuentoPorcentaje, align: TextAlign.right)),
              DataCell(celda(r.precioTotalSinImpVenta, align: TextAlign.right)),
              DataCell(celda(r.precioTotalConImpVenta, align: TextAlign.right)),

              // CELDA COMPRA
              DataCell(celda(r.ordenCompra)),
              DataCell(celda(r.proveedor)),
              DataCell(celda(r.fechaConfirmacionCompra)),
              DataCell(celda(r.divisaCompra)),
              DataCell(celda(r.productoCompra)),
              DataCell(celda(r.descripcionCompra)),
              DataCell(celda(r.cantidadCompra, align: TextAlign.right)),
              DataCell(celda(r.unidadNegocioCompra)),
              DataCell(celda(r.equipo)),
              DataCell(celda(r.precioUnitarioCompra, align: TextAlign.right)),
              DataCell(celda(r.sinImpuestoCompra, align: TextAlign.right)),
              DataCell(celda(r.conImpuestoCompra, align: TextAlign.right)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _filtros(bool compacto) {
    final content = Wrap(
      spacing: LuvegiSpacing.md,
      runSpacing: LuvegiSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FechaBox(
          titulo: 'Fecha inicio',
          valor: fechaLabel(fechaInicio),
          onTap: () => seleccionarFecha(true),
        ),
        _FechaBox(
          titulo: 'Fecha fin',
          valor: fechaLabel(fechaFin),
          onTap: () => seleccionarFecha(false),
        ),
        SizedBox(
          width: 250,
          child: TextField(
            controller: _busquedaController,
            onSubmitted: (_) => buscar(),
            decoration: InputDecoration(
              labelText: 'Búsqueda por Pedido/Desc.',
              hintText: 'Ej. PY2600014',
              prefixIcon: const Icon(Icons.search_rounded, color: LuvegiColors.secondary),
              filled: true,
              fillColor: LuvegiColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                borderSide: const BorderSide(color: LuvegiColors.border),
              ),
            ),
          ),
        ),
        _FilterChipBox(
          value: soloPendientesEntrega,
          label: 'Solo pendientes de entrega',
          onChanged: (value) {
            setState(() {
              soloPendientesEntrega = value;
              filas = _aplicarFiltroPendientes(filasOriginales);
            });
          },
        ),
        LuvegiButton.primary(
          text: cargando ? 'Buscando...' : 'Buscar',
          icon: Icons.search_rounded,
          loading: cargando,
          onPressed: cargando ? null : () => buscar(),
        ),
        LuvegiButton.secondary(
          text: 'Exportar Excel',
          icon: Icons.download_rounded,
          onPressed: cargando || !puedeExportar ? null : exportarExcel,
        ),
      ],
    );

    return LuvegiCard(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      child: content,
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: LuvegiColors.menuHover,
            borderRadius: BorderRadius.circular(LuvegiRadius.md),
          ),
          child: const Icon(
            Icons.analytics_rounded,
            color: LuvegiColors.secondary,
            size: 25,
          ),
        ),
        const SizedBox(width: LuvegiSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reporte consolidado de Ventas y Compras',
                style: LuvegiText.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Cruce de información entre Líneas de Venta y Órdenes de Compra vinculadas por Pedido.',
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _indicadores() {
    return Wrap(
      spacing: LuvegiSpacing.sm,
      runSpacing: LuvegiSpacing.sm,
      children: [
        _InfoChip('Registros', '$totalRegistros'),
        _InfoChip('Página', '$page / $totalPages'),
        _InfoChip('Líneas Visibles', '${filas.length}'),
        _InfoChip('Tiempo', '${elapsed}s'),
      ],
    );
  }

  Widget _paginacion() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaginationButton(
          tooltip: 'Primera página',
          icon: Icons.first_page_rounded,
          onPressed: cargando || page <= 1 ? null : () => buscar(nuevaPagina: 1),
        ),
        _PaginationButton(
          tooltip: 'Anterior',
          icon: Icons.chevron_left_rounded,
          onPressed: cargando || page <= 1 ? null : () => buscar(nuevaPagina: page - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.md),
          child: Text(
            '$page / $totalPages',
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _PaginationButton(
          tooltip: 'Siguiente',
          icon: Icons.chevron_right_rounded,
          onPressed: cargando || page >= totalPages ? null : () => buscar(nuevaPagina: page + 1),
        ),
        _PaginationButton(
          tooltip: 'Última página',
          icon: Icons.last_page_rounded,
          onPressed: cargando || page >= totalPages ? null : () => buscar(nuevaPagina: totalPages),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).width < 800;

    if (!puedeConsultar) {
      return Scaffold(
        backgroundColor: LuvegiColors.background,
        body: Center(
          child: Text(
            'No tienes permiso para acceder a este reporte consolidado.',
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LuvegiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: LuvegiSpacing.lg),
              _filtros(compacto),
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
              if (filas.isNotEmpty) ...[
                const SizedBox(height: LuvegiSpacing.md),
                _indicadores(),
              ],
              const SizedBox(height: LuvegiSpacing.md),
              Expanded(
                child: cargando
                    ? const Center(child: CircularProgressIndicator())
                    : filas.isEmpty
                        ? Center(
                            child: Text(
                              'Selecciona los filtros y presiona Buscar.',
                              style: LuvegiText.bodySecondary,
                            ),
                          )
                        : LuvegiCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(LuvegiRadius.lg),
                              child: _tabla(),
                            ),
                          ),
              ),
              if (filas.isNotEmpty) ...[
                const SizedBox(height: LuvegiSpacing.md),
                _paginacion(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FechaBox extends StatelessWidget {
  final String titulo;
  final String valor;
  final VoidCallback onTap;

  const _FechaBox({required this.titulo, required this.valor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuvegiRadius.sm),
      child: Container(
        width: 170,
        padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.md, vertical: 11),
        decoration: BoxDecoration(
          color: LuvegiColors.surface,
          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          border: Border.all(color: LuvegiColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: LuvegiText.caption),
            const SizedBox(height: LuvegiSpacing.xs),
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: LuvegiColors.secondary, size: 18),
                const SizedBox(width: LuvegiSpacing.sm),
                Expanded(child: Text(valor, style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipBox extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const _FilterChipBox({required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(LuvegiRadius.sm),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.md),
        decoration: BoxDecoration(
          color: value ? LuvegiColors.menuHover : LuvegiColors.surface,
          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          border: Border.all(color: value ? LuvegiColors.menuSelected : LuvegiColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            Text(
              label,
              style: LuvegiText.body.copyWith(
                color: value ? LuvegiColors.secondary : LuvegiColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.md, vertical: LuvegiSpacing.sm),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.xl),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Text(
        '$label: $value',
        style: LuvegiText.caption.copyWith(color: LuvegiColors.textSecondary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PaginationButton({required this.tooltip, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: LuvegiColors.secondary,
      disabledColor: LuvegiColors.textHint,
      style: IconButton.styleFrom(
        backgroundColor: LuvegiColors.surface,
        side: const BorderSide(color: LuvegiColors.border),
      ),
    );
  }
}