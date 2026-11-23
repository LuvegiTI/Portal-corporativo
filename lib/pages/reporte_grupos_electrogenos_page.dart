import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../design_system/luvegi_loading.dart';
import '../design_system/luvegi_text_field.dart';
import '../models/reporte_grupo_electrogeno.dart';
import '../services/reporte_grupos_electrogenos_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../utils/mensaje_error.dart';

class ReporteGruposElectrogenosPage extends StatefulWidget {
  final String token;
  final List<String> permisos;
  final String? rol;

  const ReporteGruposElectrogenosPage({
    super.key,
    required this.token,
    required this.permisos,
    this.rol,
  });

  @override
  State<ReporteGruposElectrogenosPage> createState() =>
      _ReporteGruposElectrogenosPageState();
}

class _ReporteGruposElectrogenosPageState
    extends State<ReporteGruposElectrogenosPage>
    with LuvegiProgresoMixin {
  final _service = ReporteGruposElectrogenosService();
  final _categoriaCtrl = TextEditingController(text: '01-GRUPOS ELECTROGEN');

  bool cargando = false;
  bool exportando = false;
  String? error;
  List<ReporteGrupoElectrogeno> filas = [];
  String categoriaConsultada = '';

  bool get _esAdmin {
    final r = (widget.rol ?? '').trim().toUpperCase();
    return r == 'ADMIN' || r == 'ADMINISTRADOR';
  }

  bool get puedeConsultar =>
      _esAdmin ||
      widget.permisos.any(
        (p) => p.trim().toUpperCase() == 'REPORTE_GRUPOS_ELECTROGENOS',
      );

  bool get puedeExportar =>
      _esAdmin ||
      widget.permisos.any((p) => p.trim().toUpperCase() == 'EXPORTAR_EXCEL');

  @override
  void dispose() {
    cancelarProgresoTimer();
    _categoriaCtrl.dispose();
    super.dispose();
  }

  Future<void> buscar() async {
    FocusScope.of(context).unfocus();
    final categoria = _categoriaCtrl.text.trim();

    if (!puedeConsultar) {
      setState(() => error = 'No tienes permiso para consultar este reporte.');
      return;
    }

    setState(() {
      cargando = true;
      error = null;
      filas = [];
    });

    iniciarProgreso();

    try {
      final res = await _service.consultar(
        token: widget.token,
        categoria: categoria,
      );

      if (!mounted) return;
      setState(() {
        filas = res.data;
        categoriaConsultada = res.categoria;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        filas = [];
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

    if (!puedeExportar) {
      setState(() => error = 'No tienes permiso para exportar a Excel.');
      return;
    }

    if (filas.isEmpty) {
      setState(() => error = 'Consulta el reporte antes de exportar.');
      return;
    }

    setState(() => exportando = true);
    try {
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Grupos Electrogenos'];
      excel.delete('Sheet1');

      sheet.appendRow([
        excel_lib.TextCellValue('Categoría'),
        excel_lib.TextCellValue('Producto'),
        excel_lib.TextCellValue('A la mano'),
        excel_lib.TextCellValue('Entrante'),
        excel_lib.TextCellValue('Saliente'),
        excel_lib.TextCellValue('Cantidad Disponible'),
        excel_lib.TextCellValue('Lista de Precios'),
        excel_lib.TextCellValue('Precio Fijo'),
      ]);

      for (final r in filas) {
        sheet.appendRow([
          excel_lib.TextCellValue(r.categoria),
          excel_lib.TextCellValue(r.producto),
          excel_lib.TextCellValue(r.aLaMano.toString()),
          excel_lib.TextCellValue(r.entrante.toString()),
          excel_lib.TextCellValue(r.saliente.toString()),
          excel_lib.TextCellValue(r.disponible.toString()),
          excel_lib.TextCellValue(r.listaPrecios),
          excel_lib.TextCellValue(r.precioFijo.toString()),
        ]);
      }

      const nombreArchivo = 'Reporte_Grupos_Electrogenos.xlsx';
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

  String _numero(double valor) => valor.toStringAsFixed(2);

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
          _errorCard(),
        ],
        if (filas.isNotEmpty) ...[
          const SizedBox(height: LuvegiSpacing.md),
          _resumen(),
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
                  ],
                ),
              ),
      ),
    );
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
            Icons.bolt_rounded,
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
                'Grupos Electrógenos',
                style: LuvegiText.title.copyWith(fontSize: esMovil ? 17 : 20),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Stock y listas de precios por categoría de producto.',
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filtros(bool compacto) {
    final contenido = Wrap(
      spacing: LuvegiSpacing.md,
      runSpacing: LuvegiSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LuvegiTextField(
          controller: _categoriaCtrl,
          label: 'Categoría',
          hint: 'Ej. 01-GRUPOS ELECTROGEN',
          prefixIcon: Icons.category_outlined,
          textInputAction: TextInputAction.search,
          width: compacto ? double.infinity : 320,
          onSubmitted: (_) => buscar(),
        ),
        LuvegiButton.primary(
          text: cargando ? 'Buscando...' : 'Buscar',
          icon: Icons.search_rounded,
          loading: cargando,
          onPressed: cargando ? null : buscar,
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
      child: contenido,
    );
  }

  Widget _errorCard() {
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

  Widget _resumen() {
    return Wrap(
      spacing: LuvegiSpacing.sm,
      runSpacing: LuvegiSpacing.sm,
      children: [
        _chip('Registros', '${filas.length}'),
        _chip('Categoría', categoriaConsultada),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
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
                'Ingresa una categoría y presiona Buscar.',
                textAlign: TextAlign.center,
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
        ),
      );
    }
    if (compacto) return _tarjetas();
    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        child: _tabla(),
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
        minWidth: 1500,
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
          _columna('Categoría', 220),
          _columna('Producto', 360),
          _columna('A la mano', 110),
          _columna('Entrante', 110),
          _columna('Saliente', 110),
          _columna('Disponible', 130),
          _columna('Lista de Precios', 220),
          _columna('Precio Fijo', 130),
        ],
        rows: filas.map((r) {
          return DataRow(
            cells: [
              DataCell(_celda(r.categoria)),
              DataCell(_celda(r.producto)),
              DataCell(_celda(_numero(r.aLaMano), align: TextAlign.right)),
              DataCell(_celda(_numero(r.entrante), align: TextAlign.right)),
              DataCell(_celda(_numero(r.saliente), align: TextAlign.right)),
              DataCell(_celda(_numero(r.disponible), align: TextAlign.right)),
              DataCell(_celda(r.listaPrecios)),
              DataCell(_celda(_numero(r.precioFijo), align: TextAlign.right)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _tarjetas() => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: filas.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, i) => _tarjeta(filas[i]),
  );

  Widget _tarjeta(ReporteGrupoElectrogeno r) {
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
            r.producto.isEmpty ? '—' : r.producto,
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(r.categoria, style: LuvegiText.caption),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _fila('A la mano', _numero(r.aLaMano)),
          _fila('Entrante', _numero(r.entrante)),
          _fila('Saliente', _numero(r.saliente)),
          _fila('Disponible', _numero(r.disponible)),
          _fila('Lista de precios', r.listaPrecios),
          _fila('Precio fijo', _numero(r.precioFijo)),
        ],
      ),
    );
  }

  Widget _fila(String label, String value) => Padding(
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
        Expanded(child: Text(value, style: LuvegiText.body)),
      ],
    ),
  );

  DataColumn2 _columna(String texto, double width) {
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
}
