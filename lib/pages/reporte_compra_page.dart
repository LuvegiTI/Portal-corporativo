import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../models/reporte_compra.dart';
import '../services/reporte_compra_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

enum TipoBusquedaCompra {
  descripcion,
  pedido,
}

class ReporteOrdenCompraPage extends StatefulWidget {
  final String token;
  final List<String> permisos;

  const ReporteOrdenCompraPage({
    super.key,
    required this.token,
    required this.permisos,
  });

  @override
  State<ReporteOrdenCompraPage> createState() =>
      _ReporteOrdenCompraPageState();
}

class _ReporteOrdenCompraPageState extends State<ReporteOrdenCompraPage> {
  final _service = ReporteOrdenCompraService();
  final _descripcionController = TextEditingController();
  TipoBusquedaCompra _tipoBusqueda = TipoBusquedaCompra.descripcion;

  bool cargando = false;
  String? error;
  List<ReporteOrdenCompra> filas = [];

  int page = 1;
  int pageSize = 50;
  int totalPages = 0;
  int totalLineas = 0;
  double elapsed = 0;
  double totalSinImpuesto = 0;
  double totalConImpuesto = 0;

  bool get puedeConsultar => widget.permisos.any(
        (p) => p.trim().toUpperCase() == 'CONSULTAR_COMPRAS',
      );

  bool get puedeExportar => widget.permisos.any(
        (p) => p.trim().toUpperCase() == 'EXPORTAR_EXCEL',
      );

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> buscar({int nuevaPagina = 1}) async {
    FocusScope.of(context).unfocus();

    final busqueda = _descripcionController.text.trim();

    if (!puedeConsultar) {
      setState(() => error = 'No tienes permiso para consultar este reporte.');
      return;
    }

    if (busqueda.isEmpty) {
      setState(() {
        error = _tipoBusqueda == TipoBusquedaCompra.descripcion
            ? 'Ingresa una descripción para realizar la búsqueda.'
            : 'Ingresa un pedido para realizar la búsqueda.';
      });
      return;
    }

    setState(() {
      cargando = true;
      error = null;
      filas = [];
      page = nuevaPagina;
    });

    try {
      final res = await _service.buscar(
        token: widget.token,
        tipoBusqueda: _tipoBusqueda.name,
        busqueda: busqueda,
        page: nuevaPagina,
        pageSize: pageSize,
      );

      if (!mounted) return;
      setState(() {
        filas = res.data;
        page = res.page;
        pageSize = res.pageSize;
        totalPages = res.totalPages;
        totalLineas = res.totalLineas;
        elapsed = res.elapsed;
        totalSinImpuesto = res.totalSinImpuesto;
        totalConImpuesto = res.totalConImpuesto;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filas = [];
        totalPages = 0;
        totalLineas = 0;
        elapsed = 0;
        totalSinImpuesto = 0;
        totalConImpuesto = 0;
      });
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> exportarExcel() async {
    final busqueda = _descripcionController.text.trim();

    if (!puedeExportar) {
      setState(() => error = 'No tienes permiso para exportar a Excel.');
      return;
    }

    if (busqueda.isEmpty) {
      setState(() {
        error = 'Ingresa un valor antes de exportar.';
      });
      return;
    }

    final uri = Uri.https(
      'portal.luvegi.com',
      '/api_luvegi/exportar_compra.php',
      {
        'tipo_busqueda': _tipoBusqueda.name,
        'busqueda': busqueda,
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        setState(() => error = 'No se pudo iniciar la descarga del archivo.');
      }
    }
  }

  String _importe(double value) => value.toStringAsFixed(2);

  Widget _celda(String texto, {TextAlign align = TextAlign.left}) {
    return Tooltip(
      message: texto,
      waitDuration: const Duration(milliseconds: 600),
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

  DataColumn _columna(String texto, double width) {
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
        thumbColor: WidgetStateProperty.all(LuvegiColors.secondary),
        trackColor: WidgetStateProperty.all(LuvegiColors.border),
        radius: const Radius.circular(10),
        thickness: WidgetStateProperty.all(12),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
      ),
      child: DataTable2(
        minWidth: 2170,
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
          _columna('Orden de Compra', 135),
          _columna('Proveedor', 250),
          _columna('Fecha de confirmación', 150),
          _columna('Divisa', 80),
          _columna('Producto', 240),
          _columna('Descripción', 330),
          _columna('Cantidad', 110),
          _columna('Unidad de negocio', 155),
          _columna('Equipo', 135),
          _columna('Pedido', 135),
          _columna('Precio unitario', 130),
          _columna('Sin impuesto', 130),
          _columna('Con impuesto', 130),
        ],
        rows: filas.map((r) {
          return DataRow(
            cells: [
              DataCell(_celda(r.ordenCompra)),
              DataCell(_celda(r.proveedor)),
              DataCell(_celda(r.fechaConfirmacion)),
              DataCell(_celda(r.divisa)),
              DataCell(_celda(r.producto)),
              DataCell(_celda(r.descripcion)),
              DataCell(_celda(r.cantidad, align: TextAlign.right)),
              DataCell(_celda(r.unidadNegocio)),
              DataCell(_celda(r.equipo)),
              DataCell(_celda(r.pedido)),
              DataCell(_celda(r.precioUnitario, align: TextAlign.right)),
              DataCell(_celda(r.sinImpuesto, align: TextAlign.right)),
              DataCell(_celda(r.conImpuesto, align: TextAlign.right)),
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
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SegmentedButton<TipoBusquedaCompra>(
          segments: const [
            ButtonSegment<TipoBusquedaCompra>(
              value: TipoBusquedaCompra.descripcion,
              label: Text('Descripción'),
              icon: Icon(Icons.description_outlined),
            ),
            ButtonSegment<TipoBusquedaCompra>(
              value: TipoBusquedaCompra.pedido,
              label: Text('Pedido'),
              icon: Icon(Icons.assignment_outlined),
            ),
          ],
          selected: {_tipoBusqueda},
          onSelectionChanged: cargando
              ? null
              : (seleccion) {
                  setState(() {
                    _tipoBusqueda = seleccion.first;
                    _descripcionController.clear();
                    filas = [];
                    error = null;
                  });
                },
        ),
        _CampoFiltro(
          controller: _descripcionController,
          label: _tipoBusqueda == TipoBusquedaCompra.descripcion
              ? 'Descripción'
              : 'Pedido',
          hint: _tipoBusqueda == TipoBusquedaCompra.descripcion
              ? 'Ej. maletín amarillo'
              : 'Ej. LUVEGI',
          icon: _tipoBusqueda == TipoBusquedaCompra.descripcion
              ? Icons.description_outlined
              : Icons.assignment_outlined,
          width: compacto ? 320 : 360,
          onSubmitted: (_) => buscar(),
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
            Icons.shopping_cart_checkout_rounded,
            color: LuvegiColors.secondary,
          ),
        ),
        const SizedBox(width: LuvegiSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reporte de órdenes de compra',
                style: LuvegiText.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Consulta las órdenes de compra por descripción o pedido.',
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _error() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.error.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: LuvegiColors.error),
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

  Widget _resultados() {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(color: LuvegiColors.secondary),
      );
    }

    if (filas.isEmpty) {
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
                'Selecciona Descripción o Pedido e ingresa un valor.',
                textAlign: TextAlign.center,
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      );
    }

    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        child: _tabla(),
      ),
    );
  }

  Widget _indicadores() {
    return Wrap(
      spacing: LuvegiSpacing.sm,
      runSpacing: LuvegiSpacing.sm,
      children: [
        _InfoChip('Líneas', '$totalLineas'),
        _InfoChip('Página', '$page / $totalPages'),
        _InfoChip('Sin impuesto', _importe(totalSinImpuesto)),
        _InfoChip('Con impuesto', _importe(totalConImpuesto)),
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
          onPressed:
              cargando || page <= 1 ? null : () => buscar(nuevaPagina: page - 1),
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

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).width < 800;

    if (!puedeConsultar) {
      return Scaffold(
        backgroundColor: LuvegiColors.background,
        body: Center(
          child: Text(
            'No tienes permiso para acceder al reporte de compras.',
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: LuvegiSpacing.lg),
        _filtros(compacto),
        if (error != null) ...[
          const SizedBox(height: LuvegiSpacing.md),
          _error(),
        ],
        if (filas.isNotEmpty) ...[
          const SizedBox(height: LuvegiSpacing.md),
          _indicadores(),
        ],
        const SizedBox(height: LuvegiSpacing.md),
      ],
    );

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      body: SafeArea(
        child: compacto
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(LuvegiSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    contenido,
                    SizedBox(height: filas.isEmpty ? 300 : 540, child: _resultados()),
                    if (filas.isNotEmpty) ...[
                      const SizedBox(height: LuvegiSpacing.md),
                      _paginacion(),
                    ],
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(LuvegiSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    contenido,
                    Expanded(child: _resultados()),
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

class _CampoFiltro extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final double width;
  final ValueChanged<String>? onSubmitted;

  const _CampoFiltro({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.width,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: LuvegiColors.secondary),
          filled: true,
          fillColor: LuvegiColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            borderSide: const BorderSide(color: LuvegiColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            borderSide: const BorderSide(color: LuvegiColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            borderSide: const BorderSide(
              color: LuvegiColors.secondary,
              width: 1.5,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: LuvegiSpacing.md,
        vertical: LuvegiSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.xl),
        border: Border.all(color: LuvegiColors.border),
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
        side: const BorderSide(color: LuvegiColors.border),
      ),
    );
  }
}
