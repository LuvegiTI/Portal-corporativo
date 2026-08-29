import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../models/reporte_linea_venta.dart';
import '../services/reporte_lineas_venta_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

class ReporteLineasVentaPage extends StatefulWidget {
  final String token;
  final List<String> permisos;

  const ReporteLineasVentaPage({
    super.key,
    required this.token,
    required this.permisos,
  });

  @override
  State<ReporteLineasVentaPage> createState() =>
      _ReporteLineasVentaPageState();
}

class _ReporteLineasVentaPageState extends State<ReporteLineasVentaPage> {
  final ReporteLineasVentaService _service = ReporteLineasVentaService();

  DateTime? fechaInicio;
  DateTime? fechaFin;

  bool cargando = false;
  bool soloPendientesEntrega = false;
  String? error;

  List<ReporteLineaVenta> filasOriginales = [];
  List<ReporteLineaVenta> filas = [];

  int page = 1;
  int pageSize = 50;
  int totalPages = 0;
  int totalOrdenes = 0;
  int returned = 0;
  double elapsed = 0;

  final DateFormat formatterBackend = DateFormat('yyyy-MM-dd');
  final DateFormat formatterVista = DateFormat('dd/MM/yyyy');

  bool get puedeConsultar =>
      widget.permisos.any((p) => p.trim().toUpperCase() == 'CONSULTAR_VENTAS');

  bool get puedeExportar =>
      widget.permisos.any((p) => p.trim().toUpperCase() == 'EXPORTAR_EXCEL');

  @override
  void initState() {
    super.initState();

    final hoy = DateTime.now();
    fechaInicio = DateTime(hoy.year, hoy.month, 1);
    fechaFin = hoy;
  }

  List<ReporteLineaVenta> _aplicarFiltroPendientes(
    List<ReporteLineaVenta> registros,
  ) {
    if (!soloPendientesEntrega) return registros;

    return registros.where((r) {
      final pendiente =
          double.tryParse(r.cantidadPorEntregar.replaceAll(',', '')) ?? 0;

      return pendiente > 0;
    }).toList();
  }

  Future<void> seleccionarFecha(bool inicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: inicio
          ? (fechaInicio ?? DateTime.now())
          : (fechaFin ?? DateTime.now()),
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
      setState(() {
        error = 'No tienes permiso para consultar este reporte.';
      });
      return;
    }

    if (fechaInicio == null || fechaFin == null) {
      setState(() {
        error = 'Selecciona fecha inicio y fecha fin.';
      });
      return;
    }

    if (fechaInicio!.isAfter(fechaFin!)) {
      setState(() {
        error = 'La fecha inicio no puede ser mayor que la fecha fin.';
      });
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
      final res = await _service.buscar(
        token: widget.token,
        fechaInicio: formatterBackend.format(fechaInicio!),
        fechaFin: formatterBackend.format(fechaFin!),
        page: page,
        pageSize: pageSize,
      );

      if (!mounted) return;

      setState(() {
        filasOriginales = res.data;
        filas = _aplicarFiltroPendientes(res.data);
        page = res.page;
        pageSize = res.pageSize;
        totalPages = res.totalPages;
        totalOrdenes = res.totalOrdenes;
        returned = filas.length;
        elapsed = res.elapsed;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filasOriginales = [];
        filas = [];
        totalPages = 0;
        totalOrdenes = 0;
        returned = 0;
        elapsed = 0;
      });
    } finally {
      if (!mounted) return;
      setState(() => cargando = false);
    }
  }

  Future<void> exportarExcel() async {
    if (!puedeExportar) {
      setState(() {
        error = 'No tienes permiso para exportar a Excel.';
      });
      return;
    }

    if (fechaInicio == null || fechaFin == null) {
      setState(() {
        error = 'Selecciona fecha inicio y fecha fin para exportar.';
      });
      return;
    }

    if (fechaInicio!.isAfter(fechaFin!)) {
      setState(() {
        error = 'La fecha inicio no puede ser mayor que la fecha fin.';
      });
      return;
    }

    final fi = formatterBackend.format(fechaInicio!);
    final ff = formatterBackend.format(fechaFin!);
    final pendientes = soloPendientesEntrega ? '1' : '0';

    final url = Uri.parse(
      'https://portal.luvegi.com/api_luvegi/exportar_reporte_lineas_venta.php'
      '?fecha_inicio=$fi'
      '&fecha_fin=$ff'
      '&pendientes_entrega=$pendientes',
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  String fechaLabel(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar';
    return formatterVista.format(fecha);
  }

  Widget celda(
    String texto, {
    TextAlign align = TextAlign.left,
  }) {
    return Tooltip(
      message: texto,
      waitDuration: const Duration(milliseconds: 700),
      child: Text(
        texto,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: LuvegiText.caption.copyWith(
          color: LuvegiColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  DataColumn columna(
    String texto, {
    double width = 140,
  }) {
    return DataColumn2(
      fixedWidth: width,
      label: Text(
        texto,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: LuvegiText.caption.copyWith(
          color: LuvegiColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tabla() {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          LuvegiColors.secondary,
        ),
        trackColor: WidgetStateProperty.all(
          LuvegiColors.border,
        ),
        trackBorderColor: WidgetStateProperty.all(
          Colors.transparent,
        ),
        radius: const Radius.circular(10),
        thickness: WidgetStateProperty.all(12),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
      ),
      child: DataTable2(
        minWidth: 3150,
        fixedTopRows: 1,
        headingRowHeight: 48,
        dataRowHeight: 52,
        columnSpacing: 10,
        horizontalMargin: 12,
        headingRowColor: WidgetStateProperty.all(
          LuvegiColors.menuHover,
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return LuvegiColors.surfaceHover;
          }

          return LuvegiColors.surface;
        }),
        border: TableBorder.all(
          color: LuvegiColors.border,
          width: 1,
        ),
        columns: [
          columna('Concepto', width: 115),
          columna('Número de orden de venta', width: 155),
          columna('Cliente', width: 260),
          columna('RUC', width: 105),
          columna('Ejecutivo LUVEGI', width: 145),
          columna('Fecha de creación', width: 125),
          columna('Fecha de confirmación', width: 145),
          columna('Unidad de Negocio', width: 135),
          columna('Pedido', width: 110),
          columna('Producto', width: 310),
          columna('Moneda', width: 75),
          columna('Unidad de Medida', width: 125),
          columna('Cantidad', width: 95),
          columna('Cantidad Entregada', width: 135),
          columna('Cantidad por Entregar', width: 145),
          columna('Cantidad Facturada', width: 135),
          columna('Precio unitario (sin imp.)', width: 165),
          columna('% descuento', width: 105),
          columna('Descuento Otorgado', width: 145),
          columna('Precio total (sin imp.)', width: 155),
          columna('Precio total (con imp.)', width: 165),
        ],
        rows: filas.map((r) {
          return DataRow(
            cells: [
              DataCell(celda(r.concepto)),
              DataCell(celda(r.numeroOrdenVenta)),
              DataCell(celda(r.cliente)),
              DataCell(celda(r.ruc)),
              DataCell(celda(r.ejecutivoLuvegi)),
              DataCell(celda(r.fechaCreacion)),
              DataCell(celda(r.fechaConfirmacion)),
              DataCell(celda(r.unidadNegocio)),
              DataCell(celda(r.pedido)),
              DataCell(celda(r.producto)),
              DataCell(celda(r.moneda)),
              DataCell(celda(r.unidadMedida)),
              DataCell(celda(r.cantidad, align: TextAlign.right)),
              DataCell(celda(r.cantidadEntregada, align: TextAlign.right)),
              DataCell(celda(r.cantidadPorEntregar, align: TextAlign.right)),
              DataCell(celda(r.cantidadFacturada, align: TextAlign.right)),
              DataCell(celda(r.precioUnitario, align: TextAlign.right)),
              DataCell(celda(r.descuentoPorcentaje, align: TextAlign.right)),
              DataCell(celda(r.descuentoOtorgado, align: TextAlign.right)),
              DataCell(celda(r.precioTotalSinImp, align: TextAlign.right)),
              DataCell(celda(r.precioTotalConImp, align: TextAlign.right)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _paginacion() {
    return Row(
      children: [
        _InfoChip('Órdenes', '$totalOrdenes'),
        _InfoChip('Página', '$page / $totalPages'),
        _InfoChip('Líneas', '$returned'),
        _InfoChip('Tiempo', '${elapsed}s'),
        if (soloPendientesEntrega)
          const _InfoChip('Filtro', 'Pendientes'),
        const Spacer(),
        _PaginationButton(
          tooltip: 'Primera página',
          icon: Icons.first_page_rounded,
          onPressed: cargando || page <= 1
              ? null
              : () => buscar(nuevaPagina: 1),
        ),
        _PaginationButton(
          tooltip: 'Página anterior',
          icon: Icons.chevron_left_rounded,
          onPressed: cargando || page <= 1
              ? null
              : () => buscar(nuevaPagina: page - 1),
        ),
        _PaginationButton(
          tooltip: 'Página siguiente',
          icon: Icons.chevron_right_rounded,
          onPressed: cargando || page >= totalPages
              ? null
              : () => buscar(nuevaPagina: page + 1),
        ),
        _PaginationButton(
          tooltip: 'Última página',
          icon: Icons.last_page_rounded,
          onPressed: cargando || page >= totalPages
              ? null
              : () => buscar(nuevaPagina: totalPages),
        ),
      ],
    );
  }

  Widget _buildFilters(bool compacto) {
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
        _FilterChipBox(
          value: soloPendientesEntrega,
          label: 'Solo pendientes por entregar',
          onChanged: (value) {
            setState(() {
              soloPendientesEntrega = value;
              filas = _aplicarFiltroPendientes(filasOriginales);
              returned = filas.length;
              error = null;
            });
          },
        ),
        LuvegiButton.primary(
          text: cargando ? 'Buscando...' : 'Buscar',
          icon: Icons.search_rounded,
          loading: cargando,
          onPressed: cargando
              ? null
              : () => buscar(nuevaPagina: 1),
        ),
        LuvegiButton.secondary(
          text: 'Exportar Excel',
          icon: Icons.download_rounded,
          onPressed: cargando || !puedeExportar
              ? null
              : exportarExcel,
        ),
      ],
    );

    if (!compacto) {
      return LuvegiCard(
        padding: const EdgeInsets.all(LuvegiSpacing.lg),
        child: content,
      );
    }

    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: LuvegiSpacing.md,
            vertical: LuvegiSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            LuvegiSpacing.md,
            0,
            LuvegiSpacing.md,
            LuvegiSpacing.md,
          ),
          leading: const Icon(
            Icons.filter_alt_outlined,
            color: LuvegiColors.secondary,
          ),
          title: Text(
            'Filtros',
            style: LuvegiText.title.copyWith(
              fontSize: 15,
            ),
          ),
          children: [content],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: LuvegiColors.menuHover,
            borderRadius: BorderRadius.circular(
              LuvegiRadius.md,
            ),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
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
                'Reporte por líneas de venta',
                style: LuvegiText.title.copyWith(
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Consulta órdenes de venta, entregas y facturación.',
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(
          LuvegiRadius.sm,
        ),
        border: Border.all(
          color: LuvegiColors.error.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: LuvegiColors.error,
          ),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Text(
              error!,
              style: LuvegiText.body.copyWith(
                color: LuvegiColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = soloPendientesEntrega && filasOriginales.isNotEmpty
        ? 'No hay pendientes por entregar en esta página.'
        : 'Selecciona un rango de fechas y presiona Buscar.';

    return Center(
      child: LuvegiCard(
        width: 430,
        padding: const EdgeInsets.all(LuvegiSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_rounded,
              size: 42,
              color: LuvegiColors.textHint,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LuvegiText.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool compacto = width < 800;

    if (!puedeConsultar) {
      return Scaffold(
        backgroundColor: LuvegiColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(LuvegiSpacing.md),
              child: LuvegiCard(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: LuvegiColors.error,
                      size: 40,
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    Text(
                      'No tienes permiso para acceder al reporte de ventas.',
                      textAlign: TextAlign.center,
                      style: LuvegiText.body.copyWith(
                        fontWeight: FontWeight.w700,
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

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      body: SafeArea(
        child: compacto
            ? _buildMobileLayout()
            : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: LuvegiSpacing.lg),
          _buildFilters(false),

          if (error != null) ...[
            const SizedBox(height: LuvegiSpacing.md),
            _buildError(),
          ],

          if (filas.isNotEmpty) ...[
            const SizedBox(height: LuvegiSpacing.md),
            _paginacion(),
          ],

          const SizedBox(height: LuvegiSpacing.md),

          Expanded(
            child: _buildResultsBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      color: LuvegiColors.secondary,
      onRefresh: () async {
        if (filasOriginales.isNotEmpty) {
          await buscar(nuevaPagina: page);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LuvegiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: LuvegiSpacing.md),

            _buildFilters(true),

            if (error != null) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _buildError(),
            ],

            if (filas.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.md),
              Wrap(
                spacing: LuvegiSpacing.sm,
                runSpacing: LuvegiSpacing.sm,
                children: [
                  _InfoChip('Órdenes', '$totalOrdenes'),
                  _InfoChip('Página', '$page / $totalPages'),
                  _InfoChip('Líneas', '$returned'),
                  _InfoChip('Tiempo', '${elapsed}s'),
                  if (soloPendientesEntrega)
                    const _InfoChip('Filtro', 'Pendientes'),
                ],
              ),
            ],

            const SizedBox(height: LuvegiSpacing.md),

            SizedBox(
              height: filas.isEmpty ? 300 : 540,
              child: _buildResultsBody(),
            ),

            if (filas.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _buildMobilePagination(),
            ],

            const SizedBox(height: LuvegiSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsBody() {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(
          color: LuvegiColors.secondary,
        ),
      );
    }

    if (filas.isEmpty) {
      return _buildEmptyState();
    }

    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          LuvegiRadius.lg,
        ),
        child: _tabla(),
      ),
    );
  }

  Widget _buildMobilePagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaginationButton(
          tooltip: 'Primera página',
          icon: Icons.first_page_rounded,
          onPressed: cargando || page <= 1
              ? null
              : () => buscar(nuevaPagina: 1),
        ),
        _PaginationButton(
          tooltip: 'Anterior',
          icon: Icons.chevron_left_rounded,
          onPressed: cargando || page <= 1
              ? null
              : () => buscar(nuevaPagina: page - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LuvegiSpacing.md,
          ),
          child: Text(
            '$page / $totalPages',
            style: LuvegiText.body.copyWith(
              color: LuvegiColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _PaginationButton(
          tooltip: 'Siguiente',
          icon: Icons.chevron_right_rounded,
          onPressed: cargando || page >= totalPages
              ? null
              : () => buscar(nuevaPagina: page + 1),
        ),
        _PaginationButton(
          tooltip: 'Última página',
          icon: Icons.last_page_rounded,
          onPressed: cargando || page >= totalPages
              ? null
              : () => buscar(nuevaPagina: totalPages),
        ),
      ],
    );
  }

}

class _FechaBox extends StatelessWidget {
  final String titulo;
  final String valor;
  final VoidCallback onTap;

  const _FechaBox({
    required this.titulo,
    required this.valor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        LuvegiRadius.sm,
      ),
      child: Container(
        width: 170,
        padding: const EdgeInsets.symmetric(
          horizontal: LuvegiSpacing.md,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: LuvegiColors.surface,
          borderRadius: BorderRadius.circular(
            LuvegiRadius.sm,
          ),
          border: Border.all(
            color: LuvegiColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: LuvegiText.caption,
            ),
            const SizedBox(height: LuvegiSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: LuvegiColors.secondary,
                  size: 18,
                ),
                const SizedBox(width: LuvegiSpacing.sm),
                Expanded(
                  child: Text(
                    valor,
                    style: LuvegiText.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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

  const _FilterChipBox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(
        LuvegiRadius.sm,
      ),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(
          horizontal: LuvegiSpacing.md,
        ),
        decoration: BoxDecoration(
          color: value
              ? LuvegiColors.menuHover
              : LuvegiColors.surface,
          borderRadius: BorderRadius.circular(
            LuvegiRadius.sm,
          ),
          border: Border.all(
            color: value
                ? LuvegiColors.menuSelected
                : LuvegiColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Text(
              label,
              style: LuvegiText.body.copyWith(
                color: value
                    ? LuvegiColors.secondary
                    : LuvegiColors.textPrimary,
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
      margin: const EdgeInsets.only(
        right: LuvegiSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: LuvegiSpacing.md,
        vertical: LuvegiSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(
          LuvegiRadius.xl,
        ),
        border: Border.all(
          color: LuvegiColors.border,
        ),
      ),
      child: Text(
        '$label: $value',
        style: LuvegiText.caption.copyWith(
          color: LuvegiColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PaginationButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

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
        side: const BorderSide(
          color: LuvegiColors.border,
        ),
      ),
    );
  }
}
