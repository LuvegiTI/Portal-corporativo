import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../design_system/luvegi_loading.dart';
import '../models/reporte_cxc.dart';
import '../services/reporte_cxc_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../utils/mensaje_error.dart';

class ReporteCxcPage extends StatefulWidget {
  final String token;
  final List<String> permisos;
  final String? rol;
  final ReporteCxcService? servicio;

  const ReporteCxcPage({
    super.key,
    required this.token,
    required this.permisos,
    this.rol,
    this.servicio,
  });

  @override
  State<ReporteCxcPage> createState() => _ReporteCxcPageState();
}

class _ReporteCxcPageState extends State<ReporteCxcPage>
    with LuvegiProgresoMixin {
  late final ReporteCxcService _service = widget.servicio ?? ReporteCxcService();

  final DateFormat formatterBackend = DateFormat('yyyy-MM-dd');
  final DateFormat formatterVista = DateFormat('dd/MM/yyyy');

  String modo = 'single';

  DateTime? fechaCorte;
  DateTime? fechaDesde;
  DateTime? fechaHasta;

  bool cargando = false;
  bool exportando = false;
  String? error;

  List<ReporteCxcFila> filas = [];
  ReporteCxcTotales? totales;
  String fechaEtiqueta = '';

  static const int _porPagina = 50;
  int _pagina = 0;

  bool get _esAdmin {
    final r = (widget.rol ?? '').trim().toUpperCase();
    return r == 'ADMIN' || r == 'ADMINISTRADOR';
  }

  bool get puedeConsultar =>
      _esAdmin ||
      widget.permisos.any((p) => p.trim().toUpperCase() == 'REPORTE_CXC');

  bool get puedeExportar =>
      widget.permisos.any((p) => p.trim().toUpperCase() == 'EXPORTAR_EXCEL');

  @override
  void initState() {
    super.initState();

    final hoy = DateTime.now();
    fechaCorte = hoy;
    fechaDesde = DateTime(hoy.year, hoy.month, 1);
    fechaHasta = hoy;
  }

  @override
  void dispose() {
    cancelarProgresoTimer();
    super.dispose();
  }

  String _fechaLabel(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar';
    return formatterVista.format(fecha);
  }

  String _montos(double numero) {
    final negativo = numero < 0;
    final partes = numero.abs().toStringAsFixed(2).split('.');
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final enteros = partes[0].replaceAllMapped(reg, (m) => '${m[1]},');
    return '${negativo ? '-' : ''}S/ $enteros.${partes[1]}';
  }

  Future<void> _seleccionarFecha(int campo) async {
    DateTime? actual;

    switch (campo) {
      case 0:
        actual = fechaCorte;
        break;
      case 1:
        actual = fechaDesde;
        break;
      default:
        actual = fechaHasta;
        break;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked == null) return;

    setState(() {
      switch (campo) {
        case 0:
          fechaCorte = picked;
          break;
        case 1:
          fechaDesde = picked;
          break;
        default:
          fechaHasta = picked;
          break;
      }
    });
  }

  Future<void> buscar() async {
    if (!puedeConsultar) {
      setState(() {
        error = 'No tienes permiso para consultar este reporte.';
      });
      return;
    }

    if (modo == 'single') {
      if (fechaCorte == null) {
        setState(() {
          error = 'Selecciona la fecha de corte.';
        });
        return;
      }
    } else {
      if (fechaDesde == null || fechaHasta == null) {
        setState(() {
          error = 'Selecciona fecha desde y fecha hasta.';
        });
        return;
      }

      if (fechaDesde!.isAfter(fechaHasta!)) {
        setState(() {
          error = 'La fecha desde no puede ser mayor que la fecha hasta.';
        });
        return;
      }
    }

    setState(() {
      cargando = true;
      error = null;
      filas = [];
      totales = null;
      fechaEtiqueta = '';
      _pagina = 0;
    });

    iniciarProgreso();

    try {
      final res = await _service.consultar(
        token: widget.token,
        modo: modo,
        fecha: modo == 'single' && fechaCorte != null
            ? formatterBackend.format(fechaCorte!)
            : '',
        desde: modo == 'rango' && fechaDesde != null
            ? formatterBackend.format(fechaDesde!)
            : '',
        hasta: modo == 'rango' && fechaHasta != null
            ? formatterBackend.format(fechaHasta!)
            : '',
      );

      if (!mounted) return;

      setState(() {
        filas = res.rows;
        totales = res.totales;
        fechaEtiqueta = res.fecha;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = MensajeError.desdeExcepcion(e);
        filas = [];
        totales = null;
        fechaEtiqueta = '';
      });
    } finally {
      if (mounted) {
        detenerProgreso();
        setState(() => cargando = false);
      } else {
        cancelarProgresoTimer();
      }
    }
  }

  Future<void> exportarExcel() async {
    if (exportando) return;

    if (!puedeExportar) {
      setState(() {
        error = 'No tienes permiso para exportar a Excel.';
      });
      return;
    }

    if (filas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }

    setState(() => exportando = true);

    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['CxC Vencidas'];
      excel.delete('Sheet1');

      const encabezados = [
        'Cuentas por cobrar vencidas',
        'Tipo de Comprobante',
        'Número de Documento',
        'Unidad de Negocio',
        'Equipo',
        'Pedido',
        'Fecha de factura',
        'Fecha esperada',
        'Moneda',
        'Cuenta',
        'Divisa del importe',
        'A la fecha',
        '1-30',
        '31-60',
        '61-90',
        '91-120',
        'Antiguos',
        'Total',
      ];

      final borde = excel_lib.Border(
        borderStyle: excel_lib.BorderStyle.Thin,
        borderColorHex: 'FFBDC3C7'.excelColor,
      );

      final estiloEncabezado = excel_lib.CellStyle(
        fontColorHex: 'FFFFFFFF'.excelColor,
        backgroundColorHex: 'FF34495E'.excelColor,
        bold: true,
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
        textWrapping: excel_lib.TextWrapping.WrapText,
        leftBorder: borde,
        rightBorder: borde,
        topBorder: borde,
        bottomBorder: borde,
      );

      final estiloTotales = excel_lib.CellStyle(
        bold: true,
        backgroundColorHex: 'FFF2F4F4'.excelColor,
        horizontalAlign: excel_lib.HorizontalAlign.Center,
        verticalAlign: excel_lib.VerticalAlign.Center,
        leftBorder: borde,
        rightBorder: borde,
        topBorder: borde,
        bottomBorder: borde,
      );

      final estiloTexto = excel_lib.CellStyle(
        verticalAlign: excel_lib.VerticalAlign.Center,
        leftBorder: borde,
        rightBorder: borde,
        topBorder: borde,
        bottomBorder: borde,
      );

      final estiloNumero = excel_lib.CellStyle(
        verticalAlign: excel_lib.VerticalAlign.Center,
        horizontalAlign: excel_lib.HorizontalAlign.Right,
        numberFormat: excel_lib.NumFormat.custom(formatCode: '"S/" #,##0.00'),
        leftBorder: borde,
        rightBorder: borde,
        topBorder: borde,
        bottomBorder: borde,
      );

      // Fila 1: fecha de corte fusionada J1:P1
      sheet.updateCell(
        excel_lib.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0),
        excel_lib.TextCellValue(fechaEtiqueta),
        cellStyle: excel_lib.CellStyle(
          bold: true,
          horizontalAlign: excel_lib.HorizontalAlign.Center,
          verticalAlign: excel_lib.VerticalAlign.Center,
        ),
      );
      sheet.merge(
        excel_lib.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0),
        excel_lib.CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 0),
      );

      // Fila 2: encabezados
      for (var i = 0; i < encabezados.length; i++) {
        sheet.updateCell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
          excel_lib.TextCellValue(encabezados[i]),
          cellStyle: estiloEncabezado,
        );
      }

      // Fila 3: totales
      final t = totales;
      final totalesFila = <excel_lib.CellValue?>[
        excel_lib.TextCellValue('Total'),
        for (var i = 0; i < 10; i++) null,
        if (t != null)
          excel_lib.DoubleCellValue(t.aLaFecha)
        else
          excel_lib.DoubleCellValue(0),
        if (t != null)
          excel_lib.DoubleCellValue(t.rango130)
        else
          excel_lib.DoubleCellValue(0),
        if (t != null)
          excel_lib.DoubleCellValue(t.rango3160)
        else
          excel_lib.DoubleCellValue(0),
        if (t != null)
          excel_lib.DoubleCellValue(t.rango6190)
        else
          excel_lib.DoubleCellValue(0),
        if (t != null)
          excel_lib.DoubleCellValue(t.rango91120)
        else
          excel_lib.DoubleCellValue(0),
        if (t != null)
          excel_lib.DoubleCellValue(t.antiguos)
        else
          excel_lib.DoubleCellValue(0),
        if (t != null)
          excel_lib.DoubleCellValue(t.total)
        else
          excel_lib.DoubleCellValue(0),
      ];

      for (var i = 0; i < totalesFila.length; i++) {
        final valor = totalesFila[i];
        if (valor == null) {
          sheet.updateCell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
            null,
            cellStyle: estiloTotales,
          );
        } else {
          sheet.updateCell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
            valor,
            cellStyle: estiloTotales.copyWith(
              numberFormat: excel_lib.NumFormat.custom(
                formatCode: '"S/" #,##0.00',
              ),
            ),
          );
        }
      }

      // Filas 4 en adelante: datos
      for (var fila = 0; fila < filas.length; fila++) {
        final r = filas[fila];
        final valores = <excel_lib.CellValue>[
          excel_lib.TextCellValue(r.cliente),
          excel_lib.TextCellValue(r.tipoComprobante),
          excel_lib.TextCellValue(r.numeroDocumento),
          excel_lib.TextCellValue(r.unidadNegocio),
          excel_lib.TextCellValue(r.equipo),
          excel_lib.TextCellValue(r.pedido),
          excel_lib.TextCellValue(r.fechaFactura),
          excel_lib.TextCellValue(r.fechaEsperada),
          excel_lib.TextCellValue(r.moneda),
          excel_lib.TextCellValue(r.cuenta),
          excel_lib.DoubleCellValue(r.divisaImporte),
          excel_lib.DoubleCellValue(r.aLaFecha),
          excel_lib.DoubleCellValue(r.rango130),
          excel_lib.DoubleCellValue(r.rango3160),
          excel_lib.DoubleCellValue(r.rango6190),
          excel_lib.DoubleCellValue(r.rango91120),
          excel_lib.DoubleCellValue(r.antiguos),
          excel_lib.DoubleCellValue(r.total),
        ];

        for (var c = 0; c < valores.length; c++) {
          sheet.updateCell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: c,
              rowIndex: fila + 3,
            ),
            valores[c],
            cellStyle: c < 10 ? estiloTexto : estiloNumero,
          );
        }
      }

      const anchos = <int, double>{
        0: 45,
        1: 22,
        2: 22,
        3: 30,
        4: 30,
        5: 30,
        6: 15,
        7: 15,
        8: 15,
        9: 15,
      };
      anchos.forEach((columna, ancho) {
        sheet.setColumnWidth(columna, ancho);
      });
      for (var c = 10; c <= 17; c++) {
        sheet.setColumnWidth(c, 16);
      }

      final fechaArchivo = fechaEtiqueta
          .replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final nombreArchivo =
          'CxC_Vencidas_${fechaArchivo.isEmpty ? 'reporte' : fechaArchivo}.xlsx';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajeError.desdeExcepcion(e))),
        );
      }
    } finally {
      if (mounted) setState(() => exportando = false);
    }
  }

  DataColumn columna(String texto, {double width = 140}) {
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

  Widget celda(String texto, {TextAlign align = TextAlign.left, bool negrita = false}) {
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
          fontWeight: negrita ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }

  int get _totalPaginas =>
      filas.isEmpty ? 1 : ((filas.length + _porPagina - 1) ~/ _porPagina);

  List<ReporteCxcFila> get _filasVisibles {
    if (filas.length <= _porPagina) return filas;
    final inicio = _pagina * _porPagina;
    if (inicio >= filas.length) return filas;
    return filas.skip(inicio).take(_porPagina).toList();
  }

  Widget _tabla() {
    final t = totales;
    final visibles = _filasVisibles;

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(LuvegiColors.secondary),
        trackColor: WidgetStateProperty.all(LuvegiColors.border),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(10),
        thickness: WidgetStateProperty.all(12),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
      ),
      child: DataTable2(
        minWidth: 2560,
        fixedTopRows: 1,
        headingRowHeight: 48,
        dataRowHeight: 52,
        columnSpacing: 10,
        horizontalMargin: 12,
        headingRowColor: WidgetStateProperty.all(LuvegiColors.menuHover),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return LuvegiColors.surfaceHover;
          }

          return LuvegiColors.surface;
        }),
        border: TableBorder.all(color: LuvegiColors.border, width: 1),
        columns: [
          columna('Cuentas por cobrar vencidas', width: 250),
          columna('Tipo de Comprobante', width: 150),
          columna('Número de Documento', width: 150),
          columna('Unidad de Negocio', width: 150),
          columna('Equipo', width: 150),
          columna('Pedido', width: 130),
          columna('Fecha de factura', width: 120),
          columna('Fecha esperada', width: 120),
          columna('Moneda', width: 80),
          columna('Cuenta', width: 190),
          columna('Divisa del importe', width: 130),
          columna('A la fecha', width: 115),
          columna('1-30', width: 115),
          columna('31-60', width: 115),
          columna('61-90', width: 115),
          columna('91-120', width: 115),
          columna('Antiguos', width: 115),
          columna('Total', width: 115),
        ],
        rows: [
          for (final r in visibles)
            DataRow(
              cells: [
                DataCell(celda(r.cliente)),
                DataCell(celda(r.tipoComprobante)),
                DataCell(celda(r.numeroDocumento)),
                DataCell(celda(r.unidadNegocio)),
                DataCell(celda(r.equipo)),
                DataCell(celda(r.pedido)),
                DataCell(celda(r.fechaFactura)),
                DataCell(celda(r.fechaEsperada)),
                DataCell(celda(r.moneda)),
                DataCell(celda(r.cuenta)),
                DataCell(celda(_montos(r.divisaImporte), align: TextAlign.right)),
                DataCell(celda(_montos(r.aLaFecha), align: TextAlign.right)),
                DataCell(celda(_montos(r.rango130), align: TextAlign.right)),
                DataCell(celda(_montos(r.rango3160), align: TextAlign.right)),
                DataCell(celda(_montos(r.rango6190), align: TextAlign.right)),
                DataCell(celda(_montos(r.rango91120), align: TextAlign.right)),
                DataCell(celda(_montos(r.antiguos), align: TextAlign.right)),
                DataCell(celda(_montos(r.total), align: TextAlign.right)),
              ],
            ),
          if (t != null)
            DataRow(
              color: WidgetStateProperty.all(LuvegiColors.menuHover),
              cells: [
                DataCell(celda('Total', negrita: true)),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                const DataCell(SizedBox.shrink()),
                DataCell(
                  celda(_montos(t.aLaFecha), align: TextAlign.right, negrita: true),
                ),
                DataCell(
                  celda(_montos(t.rango130), align: TextAlign.right, negrita: true),
                ),
                DataCell(
                  celda(_montos(t.rango3160), align: TextAlign.right, negrita: true),
                ),
                DataCell(
                  celda(_montos(t.rango6190), align: TextAlign.right, negrita: true),
                ),
                DataCell(
                  celda(_montos(t.rango91120), align: TextAlign.right, negrita: true),
                ),
                DataCell(
                  celda(_montos(t.antiguos), align: TextAlign.right, negrita: true),
                ),
                DataCell(
                  celda(_montos(t.total), align: TextAlign.right, negrita: true),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _resumen() {
    final t = totales;
    if (t == null) return const SizedBox.shrink();

    return Wrap(
      spacing: LuvegiSpacing.sm,
      runSpacing: LuvegiSpacing.sm,
      children: [
        _InfoChip('Registros', '${filas.length}'),
        _InfoChip('Fecha', fechaEtiqueta),
        _InfoChip('Divisa del importe', _montos(t.divisaImporte)),
        _InfoChip('A la fecha', _montos(t.aLaFecha)),
        _InfoChip('1-30', _montos(t.rango130)),
        _InfoChip('31-60', _montos(t.rango3160)),
        _InfoChip('61-90', _montos(t.rango6190)),
        _InfoChip('91-120', _montos(t.rango91120)),
        _InfoChip('Antiguos', _montos(t.antiguos)),
        _InfoChip('Total', _montos(t.total)),
      ],
    );
  }

  Widget _paginacion() {
    if (filas.isEmpty) return const SizedBox.shrink();

    final total = filas.length;
    final totalPaginas = _totalPaginas;
    final fin = (_pagina + 1) * _porPagina;
    final hasta = fin < total ? fin : total;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: LuvegiSpacing.sm,
      runSpacing: LuvegiSpacing.xs,
      children: [
        Text(
          'Mostrando ${_pagina * _porPagina + 1}–$hasta de $total registros',
          style: LuvegiText.caption.copyWith(
            color: LuvegiColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        LuvegiButton.secondary(
          text: 'Anterior',
          icon: Icons.chevron_left_rounded,
          onPressed: _pagina > 0
              ? () => setState(() => _pagina--)
              : null,
        ),
        Text(
          'Página ${_pagina + 1} de $totalPaginas',
          style: LuvegiText.caption.copyWith(
            color: LuvegiColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        LuvegiButton.secondary(
          text: 'Siguiente',
          icon: Icons.chevron_right_rounded,
          onPressed: _pagina + 1 < totalPaginas
              ? () => setState(() => _pagina++)
              : null,
        ),
      ],
    );
  }

  Widget _modoSelector() {
    return Wrap(
      spacing: LuvegiSpacing.sm,
      runSpacing: LuvegiSpacing.sm,
      children: [
        _ModoOpcion(
          seleccionado: modo == 'single',
          titulo: 'Al',
          subtitulo: 'Fecha de corte',
          onTap: () => setState(() => modo = 'single'),
        ),
        _ModoOpcion(
          seleccionado: modo == 'rango',
          titulo: 'Desde / Hasta',
          subtitulo: 'Por rango',
          onTap: () => setState(() => modo = 'rango'),
        ),
      ],
    );
  }

  Widget _buildFilters(bool compacto) {
    final contenido = Wrap(
      spacing: LuvegiSpacing.md,
      runSpacing: LuvegiSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _modoSelector(),
        if (modo == 'single') ...[
          _FechaCampo(
            titulo: 'Al',
            valor: _fechaLabel(fechaCorte),
            onTap: () => _seleccionarFecha(0),
          ),
        ] else ...[
          _FechaCampo(
            titulo: 'Desde',
            valor: _fechaLabel(fechaDesde),
            onTap: () => _seleccionarFecha(1),
          ),
          _FechaCampo(
            titulo: 'Hasta',
            valor: _fechaLabel(fechaHasta),
            onTap: () => _seleccionarFecha(2),
          ),
        ],
        LuvegiButton.primary(
          text: cargando ? 'Consultando...' : 'Consultar',
          icon: Icons.search_rounded,
          loading: cargando,
          onPressed: cargando ? null : buscar,
        ),
        LuvegiButton.secondary(
          text: exportando ? 'Exportando...' : 'Exportar Excel',
          icon: Icons.download_rounded,
          loading: exportando,
          onPressed: cargando || exportando || !puedeExportar
              ? null
              : exportarExcel,
        ),
      ],
    );

    if (!compacto) {
      return LuvegiCard(
        padding: const EdgeInsets.all(LuvegiSpacing.lg),
        child: contenido,
      );
    }

    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
            style: LuvegiText.title.copyWith(fontSize: 15),
          ),
          children: [contenido],
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
            borderRadius: BorderRadius.circular(LuvegiRadius.md),
          ),
          child: const Icon(
            Icons.payments_outlined,
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
                'Cuentas por cobrar vencidas',
                style: LuvegiText.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Reporte de Odoo',
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

  Widget _buildEmptyState() {
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
              'Selecciona las fechas y presiona Consultar.',
              textAlign: TextAlign.center,
              style: LuvegiText.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsBody({bool tarjetas = false}) {
    if (cargando) {
      return buildProgreso();
    }

    if (filas.isEmpty) {
      return _buildEmptyState();
    }

    if (tarjetas) return _tarjetasCxc();

    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        child: _tabla(),
      ),
    );
  }

  Widget _campoDato(String etiqueta, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: LuvegiText.caption.copyWith(
            color: LuvegiColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          valor.isEmpty ? '—' : valor,
          style: LuvegiText.caption.copyWith(color: LuvegiColors.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _filaDatos(List<Widget> campos) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < campos.length; i++) ...[
            if (i > 0) const SizedBox(width: LuvegiSpacing.sm),
            Expanded(child: campos[i]),
          ],
        ],
      ),
    );
  }

  Widget _tarjetasCxc() => ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: filas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _tarjetaCxc(filas[i]),
      );

  Widget _tarjetaCxc(ReporteCxcFila r) {
    final montos = <Widget>[
      _montoChip('Divisa del importe', r.divisaImporte),
      _montoChip('A la fecha', r.aLaFecha),
      _montoChip('1-30', r.rango130),
      _montoChip('31-60', r.rango3160),
      _montoChip('61-90', r.rango6190),
      _montoChip('91-120', r.rango91120),
      _montoChip('Antiguos', r.antiguos),
      _montoChip('Total', r.total, destacado: true),
    ];

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
          Text(
            r.cliente.isEmpty ? 'Sin cliente' : r.cliente,
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          _campoDato('Tipo de comprobante', r.tipoComprobante),
          const SizedBox(height: LuvegiSpacing.sm),
          _filaDatos([
            _campoDato('N° documento', r.numeroDocumento),
            _campoDato('Fecha factura', r.fechaFactura),
          ]),
          _filaDatos([
            _campoDato('Fecha esperada', r.fechaEsperada),
            _campoDato('Moneda', r.moneda),
          ]),
          _filaDatos([
            _campoDato('Unidad de negocio', r.unidadNegocio),
            _campoDato('Equipo', r.equipo),
          ]),
          _filaDatos([
            _campoDato('Pedido', r.pedido),
            _campoDato('Cuenta', r.cuenta),
          ]),
          const SizedBox(height: LuvegiSpacing.xs),
          Wrap(
            spacing: LuvegiSpacing.sm,
            runSpacing: LuvegiSpacing.sm,
            children: montos,
          ),
        ],
      ),
    );
  }

  Widget _montoChip(String etiqueta, double valor, {bool destacado = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LuvegiSpacing.sm,
        vertical: LuvegiSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: destacado ? LuvegiColors.menuHover : LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(
          color: destacado ? LuvegiColors.secondary : LuvegiColors.border,
        ),
      ),
      child: Text(
        '$etiqueta  ${_montos(valor)}',
        style: LuvegiText.caption.copyWith(
          color: destacado ? LuvegiColors.secondary : LuvegiColors.textPrimary,
          fontWeight: FontWeight.w700,
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
                maxWidth: 420,
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
                      'No tienes permiso para ver el reporte de cuentas por cobrar.',
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
        child: compacto ? _buildMobileLayout() : _buildDesktopLayout(),
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
            _resumen(),
          ],

          const SizedBox(height: LuvegiSpacing.md),

          Expanded(child: _buildResultsBody()),

          const SizedBox(height: LuvegiSpacing.sm),
          _paginacion(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      color: LuvegiColors.secondary,
      onRefresh: () async {
        if (fechaCorte != null) {
          await buscar();
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
              _resumen(),
            ],

            const SizedBox(height: LuvegiSpacing.md),

            SizedBox(
              height: filas.isEmpty ? 300 : 700,
              child: _buildResultsBody(tarjetas: true),
            ),

            const SizedBox(height: LuvegiSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _ModoOpcion extends StatelessWidget {
  final bool seleccionado;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _ModoOpcion({
    required this.seleccionado,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuvegiRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LuvegiSpacing.md,
          vertical: LuvegiSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: seleccionado
              ? LuvegiColors.secondary
              : LuvegiColors.surface,
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
          border: Border.all(
            color: seleccionado
                ? LuvegiColors.secondary
                : LuvegiColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              style: LuvegiText.caption.copyWith(
                color: seleccionado
                    ? LuvegiColors.surface
                    : LuvegiColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitulo,
              style: LuvegiText.caption.copyWith(
                color: seleccionado
                    ? LuvegiColors.surface
                    : LuvegiColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FechaCampo extends StatelessWidget {
  final String titulo;
  final String valor;
  final VoidCallback onTap;

  const _FechaCampo({
    required this.titulo,
    required this.valor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuvegiRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LuvegiSpacing.md,
          vertical: LuvegiSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: LuvegiColors.surface,
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
          border: Border.all(color: LuvegiColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: LuvegiText.caption.copyWith(
                    color: LuvegiColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  valor,
                  style: LuvegiText.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: LuvegiSpacing.sm),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: LuvegiColors.secondary,
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
      padding: const EdgeInsets.symmetric(
        horizontal: LuvegiSpacing.md,
        vertical: LuvegiSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Wrap(
        spacing: LuvegiSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            label,
            style: LuvegiText.caption.copyWith(
              color: LuvegiColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: LuvegiText.caption.copyWith(
              color: LuvegiColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
