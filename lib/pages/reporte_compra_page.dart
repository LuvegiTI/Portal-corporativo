import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../design_system/luvegi_loading.dart';
import '../models/reporte_compra.dart';
import '../services/reporte_compra_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../utils/mensaje_error.dart';

enum TipoBusquedaCompra { pedido, equipo, unidad, descripcion }

class ReporteOrdenCompraPage extends StatefulWidget {
  final String token;
  final List<String> permisos;

  const ReporteOrdenCompraPage({
    super.key,
    required this.token,
    required this.permisos,
  });

  @override
  State<ReporteOrdenCompraPage> createState() => _ReporteOrdenCompraPageState();
}

class _ReporteOrdenCompraPageState extends State<ReporteOrdenCompraPage>
    with LuvegiProgresoMixin {
  final _service = ReporteOrdenCompraService();
  final _busquedaController = TextEditingController();
  TipoBusquedaCompra _tipoBusqueda = TipoBusquedaCompra.pedido;

  bool cargando = false;
  bool exportando = false;
  String? error;
  List<ReporteOrdenCompra> filas = [];

  int page = 1;
  int pageSize = 1000;
  int totalPages = 1;
  int totalRegistros = 0;
  double totalSinImpuesto = 0;

  bool get puedeConsultar =>
      widget.permisos.any((p) => p.trim().toUpperCase() == 'CONSULTAR_COMPRAS');
  bool get puedeExportar =>
      widget.permisos.any((p) => p.trim().toUpperCase() == 'EXPORTAR_EXCEL');

  @override
  void dispose() {
    cancelarProgresoTimer();
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> buscar({int nuevaPagina = 1}) async {
    FocusScope.of(context).unfocus();
    final busqueda = _busquedaController.text.trim();

    if (!puedeConsultar) {
      setState(() => error = 'No tienes permiso para consultar este reporte.');
      return;
    }

    if (busqueda.isEmpty) {
      setState(() => error = 'Ingresa un valor para realizar la búsqueda.');
      return;
    }

    setState(() {
      cargando = true;
      error = null;
      filas = [];
      page = nuevaPagina;
    });

    iniciarProgreso();

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
        page = res.pagina;
        totalPages = res.totalPaginas;
        totalRegistros = res.totalRegistros;
        totalSinImpuesto = res.totalSinImpuesto;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filas = [];
        totalPages = 0;
        totalRegistros = 0;
        totalSinImpuesto = 0;
      });
    } finally {
      if (mounted) {
        detenerProgreso();
        setState(() => cargando = false);
      }
    }
  }

  Future<void> exportarExcel() async {
    if (exportando) return;
    final busqueda = _busquedaController.text.trim();

    if (!puedeExportar) {
      setState(() => error = 'No tienes permiso para exportar a Excel.');
      return;
    }

    if (busqueda.isEmpty) {
      setState(() => error = 'Ingresa un valor antes de exportar.');
      return;
    }

    setState(() => exportando = true);
    try {
      List<ReporteOrdenCompra> todasLasFilas = [];
      int pagina = 1;
      int totalPaginas = 1;

      while (pagina <= totalPaginas) {
        final res = await _service.buscar(
          token: widget.token,
          tipoBusqueda: _tipoBusqueda.name,
          busqueda: busqueda,
          page: pagina,
          pageSize: 1000,
        );
        if (!mounted) return;
        todasLasFilas.addAll(res.data);
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
      final sheet = excel['Ordenes de Compra'];
      excel.delete('Sheet1');

      sheet.appendRow([
        excel_lib.TextCellValue('Orden de Compra'),
        excel_lib.TextCellValue('Proveedor'),
        excel_lib.TextCellValue('Fecha de confirmación'),
        excel_lib.TextCellValue('Producto'),
        excel_lib.TextCellValue('Descripción'),
        excel_lib.TextCellValue('Cantidad'),
        excel_lib.TextCellValue('Unidad de negocio'),
        excel_lib.TextCellValue('Equipo'),
        excel_lib.TextCellValue('Pedido'),
        excel_lib.TextCellValue('Divisa'),
        excel_lib.TextCellValue('Tipo cambio'),
        excel_lib.TextCellValue('Precio unitario'),
        excel_lib.TextCellValue('Impuesto / IGV'),
        excel_lib.TextCellValue('Importe Sin Impuesto (PEN)'),
      ]);

      for (var r in todasLasFilas) {
        sheet.appendRow([
          excel_lib.TextCellValue(r.ordenCompra),
          excel_lib.TextCellValue(r.proveedor),
          excel_lib.TextCellValue(r.fechaConfirmacion),
          excel_lib.TextCellValue(r.producto),
          excel_lib.TextCellValue(r.descripcion),
          excel_lib.TextCellValue(r.cantidad.toString()),
          excel_lib.TextCellValue(r.unidadNegocio),
          excel_lib.TextCellValue(r.equipo),
          excel_lib.TextCellValue(r.pedido),
          excel_lib.TextCellValue(r.divisa),
          excel_lib.TextCellValue(r.tipoCambio.toString()),
          excel_lib.TextCellValue(r.precioUnitario.toString()),
          excel_lib.TextCellValue(r.impuesto),
          excel_lib.TextCellValue(r.sinImpuesto.toString()),
        ]);
      }
      final nombreArchivo = 'OrdenesCompra_${busqueda}_Todo.xlsx';
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(MensajeError.desdeExcepcion(e))));
    } finally {
      if (mounted) setState(() => exportando = false);
    }
  }

  String _importe(double numero) {
    List<String> partes = numero.toString().split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String enteros = partes[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return partes.length > 1 ? 'S/ $enteros.${partes[1]}' : 'S/ $enteros';
  }

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
        minWidth: 2460,
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
          _columna('Producto', 240),
          _columna('Descripción', 330),
          _columna('Cantidad', 110),
          _columna('Unidad de negocio', 155),
          _columna('Equipo', 135),
          _columna('Pedido', 135),
          _columna('Divisa', 80),
          _columna('Tipo cambio', 100),
          _columna('Precio unitario', 130),
          _columna('Impuesto / IGV', 160),
          _columna('Importe Sin Impuesto (PEN)', 180),
        ],
        rows: filas.map((r) {
          return DataRow(
            cells: [
              DataCell(_celda(r.ordenCompra)),
              DataCell(_celda(r.proveedor)),
              DataCell(_celda(r.fechaConfirmacion)),
              DataCell(_celda(r.producto)),
              DataCell(_celda(r.descripcion)),
              DataCell(_celda(r.cantidad.toString(), align: TextAlign.right)),
              DataCell(_celda(r.unidadNegocio)),
              DataCell(_celda(r.equipo)),
              DataCell(_celda(r.pedido)),
              DataCell(_celda(r.divisa)),
              DataCell(_celda(r.tipoCambio.toString(), align: TextAlign.right)),
              DataCell(
                _celda(r.precioUnitario.toString(), align: TextAlign.right),
              ),
              DataCell(_celda(r.impuesto)),
              DataCell(
                _celda(r.sinImpuesto.toString(), align: TextAlign.right),
              ),
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
              value: TipoBusquedaCompra.pedido,
              label: Text('Pedido'),
              icon: Icon(Icons.receipt_long_rounded),
            ),
            ButtonSegment<TipoBusquedaCompra>(
              value: TipoBusquedaCompra.equipo,
              label: Text('Equipo'),
              icon: Icon(Icons.build_circle_outlined),
            ),
            ButtonSegment<TipoBusquedaCompra>(
              value: TipoBusquedaCompra.unidad,
              label: Text('U. Negocio'),
              icon: Icon(Icons.domain_rounded),
            ),
            ButtonSegment<TipoBusquedaCompra>(
              value: TipoBusquedaCompra.descripcion,
              label: Text('Descripción'),
              icon: Icon(Icons.text_snippet_rounded),
            ),
          ],
          selected: {_tipoBusqueda},
          onSelectionChanged: cargando
              ? null
              : (seleccion) {
                  setState(() {
                    _tipoBusqueda = seleccion.first;
                    _busquedaController.clear();
                    filas = [];
                    error = null;
                  });
                },
        ),
        _CampoFiltro(
          controller: _busquedaController,
          label: _getLabelFiltro(),
          hint: _getHintFiltro(),
          icon: _getIconFiltro(),
          width: compacto ? double.infinity : 360,
          onSubmitted: (_) => buscar(),
        ),
        LuvegiButton.primary(
          text: cargando ? 'Buscando...' : 'Buscar',
          icon: Icons.search_rounded,
          loading: cargando,
          onPressed: cargando ? null : () => buscar(),
        ),
        LuvegiButton.secondary(
          text: exportando ? 'Exportando...' : 'Exportar Excel',
          icon: exportando ? null : Icons.download_rounded,
          onPressed: cargando || exportando || !puedeExportar
              ? null
              : exportarExcel,
        ),
      ],
    );

    return LuvegiCard(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      child: content,
    );
  }

  String _getLabelFiltro() {
    switch (_tipoBusqueda) {
      case TipoBusquedaCompra.pedido:
        return 'Pedido';
      case TipoBusquedaCompra.equipo:
        return 'Equipo';
      case TipoBusquedaCompra.unidad:
        return 'Unidad de Negocio';
      case TipoBusquedaCompra.descripcion:
        return 'Descripción de Etiqueta';
    }
  }

  String _getHintFiltro() {
    switch (_tipoBusqueda) {
      case TipoBusquedaCompra.pedido:
        return 'Ej. LUVEGI';
      case TipoBusquedaCompra.equipo:
        return 'Ej. SINEQUI o EQ-123';
      case TipoBusquedaCompra.unidad:
        return 'Ej. RENTA o UN-123';
      case TipoBusquedaCompra.descripcion:
        return 'Ej. Repuesto motor, Filtro...';
    }
  }

  IconData _getIconFiltro() {
    switch (_tipoBusqueda) {
      case TipoBusquedaCompra.pedido:
        return Icons.receipt_long_rounded;
      case TipoBusquedaCompra.equipo:
        return Icons.build_circle_outlined;
      case TipoBusquedaCompra.unidad:
        return Icons.domain_rounded;
      case TipoBusquedaCompra.descripcion:
        return Icons.text_snippet_rounded;
    }
  }

  Widget _header({bool esMovil = false}) {
    return Row(
      children: [
        Container(
          width: esMovil ? 40 : 46,
          height: esMovil ? 40 : 46,
          decoration: BoxDecoration(
            color: LuvegiColors.menuHover,
            borderRadius: BorderRadius.circular(LuvegiRadius.md),
          ),
          child: Icon(
            Icons.shopping_cart_checkout_rounded,
            color: LuvegiColors.secondary,
            size: esMovil ? 22 : 24,
          ),
        ),
        const SizedBox(width: LuvegiSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reporte de órdenes de compra',
                style: LuvegiText.title.copyWith(fontSize: esMovil ? 17 : 20),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Consulta las órdenes de compra consolidadas.',
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
        color: LuvegiColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.error.withValues(alpha: 0.35)),
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

  Widget _resultados(bool compacto) {
    if (cargando) return buildProgreso();
    if (filas.isEmpty) {
      return Center(
        child: LuvegiCard(
          maxWidth: 430,
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
                'Selecciona el tipo de filtro y busca.',
                textAlign: TextAlign.center,
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      );
    }
    if (compacto) return _tarjetasCompra();
    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        child: _tabla(),
      ),
    );
  }

  Widget _filaInfoCompra(String label, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: LuvegiText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );

  Widget _tarjetasCompra() => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: filas.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, i) => _tarjetaCompra(filas[i]),
  );

  Widget _tarjetaCompra(ReporteOrdenCompra r) {
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
                  r.ordenCompra.isEmpty ? '—' : r.ordenCompra,
                  style: LuvegiText.title.copyWith(
                    fontSize: 16,
                    color: LuvegiColors.secondary,
                  ),
                ),
              ),
              if (r.fechaConfirmacion.isNotEmpty)
                Text(r.fechaConfirmacion, style: LuvegiText.caption),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r.producto.isEmpty ? '—' : r.producto,
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (r.descripcion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              r.descripcion,
              style: LuvegiText.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          _filaInfoCompra(
            'Proveedor',
            Text(
              r.proveedor.isEmpty ? '—' : r.proveedor,
              style: LuvegiText.body,
            ),
          ),
          if (r.unidadNegocio.isNotEmpty)
            _filaInfoCompra(
              'U. Negocio',
              Text(r.unidadNegocio, style: LuvegiText.body),
            ),
          if (r.equipo.isNotEmpty)
            _filaInfoCompra('Equipo', Text(r.equipo, style: LuvegiText.body)),
          if (r.pedido.isNotEmpty)
            _filaInfoCompra('Pedido', Text(r.pedido, style: LuvegiText.body)),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _filaInfoCompra(
            'Cantidad',
            Text(r.cantidad.toString(), style: LuvegiText.body),
          ),
          _filaInfoCompra(
            'Precio unit.',
            Text(r.precioUnitario.toString(), style: LuvegiText.body),
          ),
          _filaInfoCompra('Divisa', Text(r.divisa, style: LuvegiText.body)),
          _filaInfoCompra(
            'Tipo cambio',
            Text(r.tipoCambio.toString(), style: LuvegiText.body),
          ),
          _filaInfoCompra('Impuesto', Text(r.impuesto, style: LuvegiText.body)),
          _filaInfoCompra(
            'Sin imp. (PEN)',
            Text(
              r.sinImpuesto.toString(),
              style: LuvegiText.body.copyWith(
                fontWeight: FontWeight.w700,
                color: LuvegiColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicadores() {
    return Wrap(
      spacing: LuvegiSpacing.sm,
      runSpacing: LuvegiSpacing.sm,
      children: [
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: LuvegiColors.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            border: Border.all(
              color: LuvegiColors.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL SIN IMPUESTO (PEN)',
                style: LuvegiText.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: LuvegiColors.secondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _importe(totalSinImpuesto),
                style: LuvegiText.title.copyWith(
                  fontSize: 17,
                  color: LuvegiColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paginacion() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool esMovil = constraints.maxWidth < 768;
        if (esMovil) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                    value: pageSize,
                    isDense: true,
                    underline: const SizedBox(),
                    items: const [25, 100, 500, 1000]
                        .map(
                          (int value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              value == 1000 ? 'Todos' : '$value',
                              style: LuvegiText.caption,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: cargando
                        ? null
                        : (nuevoLimite) {
                            if (nuevoLimite != null &&
                                nuevoLimite != pageSize) {
                              setState(() => pageSize = nuevoLimite);
                              buscar(nuevaPagina: 1);
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
          );
        }
        return Row(
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
                  value: pageSize,
                  isDense: true,
                  underline: const SizedBox(),
                  items: const [25, 100, 500, 1000]
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            value == 1000 ? 'Todos' : '$value',
                            style: LuvegiText.caption,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: cargando
                      ? null
                      : (nuevoLimite) {
                          if (nuevoLimite != null && nuevoLimite != pageSize) {
                            setState(() => pageSize = nuevoLimite);
                            buscar(nuevaPagina: 1);
                          }
                        },
                ),
                const SizedBox(width: 16),
                Text(
                  'Página $page de $totalPages (${filas.length} vis. de $totalRegistros)',
                  style: LuvegiText.caption.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
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
                    '$page',
                    style: LuvegiText.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _PaginationButton(
                  tooltip: 'Siguiente',
                  icon: Icons.chevron_right_rounded,
                  onPressed: cargando || page >= totalPages
                      ? null
                      : () => buscar(
                          nuevaPagina: totalPages > page ? page + 1 : page,
                        ),
                ),
                _PaginationButton(
                  tooltip: 'Última página',
                  icon: Icons.last_page_rounded,
                  onPressed: cargando || page >= totalPages
                      ? null
                      : () => buscar(nuevaPagina: totalPages),
                ),
              ],
            ),
          ],
        );
      },
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
            'No tienes permiso para acceder al reporte.',
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(esMovil: compacto),
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
                    SizedBox(
                      height: filas.isEmpty ? 300 : 540,
                      child: _resultados(compacto),
                    ),
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
                    Expanded(child: _resultados(compacto)),
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
