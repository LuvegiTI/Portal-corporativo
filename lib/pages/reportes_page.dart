import 'package:data_table_2/data_table_2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/luvegi_button.dart';
import '../design_system/luvegi_card.dart';
import '../design_system/luvegi_text_field.dart';
import '../services/reportes_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

class ReportesPage extends StatefulWidget {
  final String token;

  const ReportesPage({
    super.key,
    required this.token,
  });

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final TextEditingController _cuentaCtrl = TextEditingController();
  final ReportesService _service = ReportesService();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _data = [];
  double _totalGeneral = 0;
  String _vista = 'tabla';

  static const List<String> _meses = [
    '',
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    return double.tryParse(
          value.toString().replaceAll(',', ''),
        ) ??
        0.0;
  }

  Future<void> _buscar() async {
    final cuenta = _cuentaCtrl.text.trim();

    if (cuenta.isEmpty) {
      setState(() {
        _error = 'Ingrese una cuenta analítica.';
        _data = [];
        _totalGeneral = 0;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _data = [];
      _totalGeneral = 0;
    });

    try {
      final response = await _service.consultar(
        token: widget.token,
        cuenta: cuenta,
      );

      if (!mounted) return;

      double suma = 0;

      final processedData =
          List<Map<String, dynamic>>.from(response['data']).map((item) {
        final row = Map<String, dynamic>.from(item);
        final referencia =
            (row['referencia'] ?? '').toString().toUpperCase();

        final esDevolucion =
            referencia.contains('/IN/') || _toDouble(row['total']) < 0;

        final cantidad = _toDouble(row['cantidad']);
        final total = _toDouble(row['total']);

        if (esDevolucion) {
          row['c_final'] = cantidad < 0 ? cantidad : cantidad * -1;
          row['t_final'] = total < 0 ? total : total * -1;
          row['tipo_visual'] = 'devolucion';
        } else {
          row['c_final'] = cantidad;
          row['t_final'] = total;
          row['tipo_visual'] = row['tipo'] == 'contabilidad'
              ? 'contabilidad'
              : 'almacen';
        }

        suma += _toDouble(row['t_final']);
        return row;
      }).toList();

      setState(() {
        _data = processedData;
        _totalGeneral = suma;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _data = [];
        _totalGeneral = 0;
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _abrirOdoo(Map<String, dynamic> row) async {
    final modelo = row['tipo'] == 'contabilidad'
        ? 'account.move'
        : 'stock.picking';

    final url =
        'https://luvegi-odoo171.odoo.com/web#id=${row['res_id']}&model=$modelo&view_type=form';

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  void dispose() {
    _cuentaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool compacto = width < 800;

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      body: Padding(
        padding: EdgeInsets.all(
          compacto ? LuvegiSpacing.md : LuvegiSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: LuvegiSpacing.lg),
            _buildFilters(compacto),

            if (_error != null) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _buildErrorCard(),
            ],

            if (_data.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _buildSummary(compacto),
            ],

            const SizedBox(height: LuvegiSpacing.md),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: LuvegiColors.secondary,
                      ),
                    )
                  : _data.isEmpty
                      ? _buildEmptyState()
                      : _vista == 'tabla'
                          ? _buildTabla()
                          : _buildGraficos(),
            ),
          ],
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
            Icons.analytics_outlined,
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
                'Reporte consolidado',
                style: LuvegiText.title.copyWith(
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Consulta movimientos consolidados por cuenta analítica.',
                style: LuvegiText.bodySecondary,
              ),
            ],
          ),
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
        LuvegiTextField(
          controller: _cuentaCtrl,
          label: 'Cuenta analítica',
          hint: 'Ingrese cuenta',
          prefixIcon: Icons.search_rounded,
          textInputAction: TextInputAction.search,
          width: compacto ? 260 : 300,
          onSubmitted: (_) => _buscar(),
        ),
        LuvegiButton.primary(
          text: _loading ? 'Buscando...' : 'Buscar',
          icon: Icons.search_rounded,
          loading: _loading,
          onPressed: _loading ? null : _buscar,
        ),
        if (_data.isNotEmpty)
          LuvegiButton.outline(
            text: 'Tabla',
            icon: Icons.table_rows_rounded,
            onPressed: () {
              setState(() => _vista = 'tabla');
            },
          ),
        if (_data.isNotEmpty)
          LuvegiButton.secondary(
            text: 'Gráfico',
            icon: Icons.bar_chart_rounded,
            onPressed: () {
              setState(() => _vista = 'graficos');
            },
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
          children: [contenido],
        ),
      ),
    );
  }

  Widget _buildSummary(bool compacto) {
    final chips = [
      _InfoChip(
        label: 'Registros',
        value: '${_data.length}',
      ),
      _InfoChip(
        label: 'Total neto',
        value: 'S/ ${_totalGeneral.toStringAsFixed(2)}',
      ),
      _InfoChip(
        label: 'Vista',
        value: _vista == 'tabla' ? 'Tabla' : 'Gráfico',
      ),
    ];

    if (compacto) {
      return Wrap(
        spacing: LuvegiSpacing.sm,
        runSpacing: LuvegiSpacing.sm,
        children: chips,
      );
    }

    return Row(children: chips);
  }

  Widget _buildErrorCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: LuvegiColors.error,
          ),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Text(
              _error!,
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
              'Ingrese una cuenta analítica y presione Buscar.',
              textAlign: TextAlign.center,
              style: LuvegiText.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabla() {
    return LuvegiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          LuvegiRadius.lg,
        ),
        child: ScrollbarTheme(
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
            minWidth: 1200,
            fixedTopRows: 1,
            headingRowHeight: 48,
            dataRowHeight: 54,
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
              _columna('FECHA', width: 110),
              _columna('REF / TIPO', width: 190),
              _columna('PRODUCTO / ETIQUETA', width: 520),
              _columna('TOTAL', width: 130),
              _columna('VER', width: 80),
            ],
            rows: _data.map((row) {
              final tipoVisual =
                  (row['tipo_visual'] ?? '').toString();

              final colorTexto = tipoVisual == 'devolucion'
                  ? LuvegiColors.error
                  : tipoVisual == 'contabilidad'
                      ? LuvegiColors.secondary
                      : LuvegiColors.textPrimary;

              return DataRow(
                cells: [
                  DataCell(
                    _celda(
                      row['fecha'] ?? '',
                      color: colorTexto,
                    ),
                  ),
                  DataCell(
                    Tooltip(
                      message:
                          '${row['referencia'] ?? ''}\n${row['doc_tipo'] ?? ''}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            row['referencia'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LuvegiText.caption.copyWith(
                              color: colorTexto,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            row['doc_tipo'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LuvegiText.caption.copyWith(
                              color: LuvegiColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    _celda(
                      row['producto'] ?? '',
                      color: colorTexto,
                    ),
                  ),
                  DataCell(
                    _celda(
                      'S/ ${_toDouble(row['t_final']).toStringAsFixed(2)}',
                      color: colorTexto,
                      align: TextAlign.right,
                    ),
                  ),
                  DataCell(
                    IconButton(
                      tooltip: 'Abrir en Odoo',
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        color: LuvegiColors.secondary,
                        size: 21,
                      ),
                      onPressed: () => _abrirOdoo(row),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn2 _columna(
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

  Widget _celda(
    String texto, {
    TextAlign align = TextAlign.left,
    Color color = LuvegiColors.textPrimary,
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
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGraficos() {
    final puntos = _agruparPorFecha();

    if (puntos.isEmpty) {
      return Center(
        child: Text(
          'Sin datos para graficar.',
          style: LuvegiText.bodySecondary,
        ),
      );
    }

    return SingleChildScrollView(
      child: _buildChartCard(
        'EVOLUCIÓN MENSUAL',
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            barGroups: puntos.asMap().entries.map((entry) {
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.total,
                    color: LuvegiColors.secondary,
                    width: 15,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();

                    if (index < 0 || index >= puntos.length) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        puntos[index].fecha,
                        style: LuvegiText.caption.copyWith(
                          color: LuvegiColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) {
                return const FlLine(
                  color: LuvegiColors.border,
                  strokeWidth: 1,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<_PuntoFecha> _agruparPorFecha() {
    final Map<String, double> acumulado = {};

    for (final row in _data) {
      final partes =
          (row['fecha'] ?? '').toString().split('-').take(2).toList();

      if (partes.length < 2) continue;

      final clave = '${partes[0]}-${partes[1]}';

      acumulado[clave] =
          (acumulado[clave] ?? 0) + _toDouble(row['t_final']);
    }

    final ordenado = acumulado.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ordenado.map((entry) {
      final partes = entry.key.split('-');
      final mes = int.tryParse(partes[1]) ?? 0;

      final etiqueta = mes > 0 && mes < _meses.length
          ? '${_meses[mes]} ${partes[0].substring(2)}'
          : entry.key;

      return _PuntoFecha(
        fecha: etiqueta,
        total: entry.value,
      );
    }).toList();
  }

  Widget _buildChartCard(
    String titulo,
    Widget chart,
  ) {
    return LuvegiCard(
      width: double.infinity,
      height: 360,
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      child: Column(
        children: [
          Text(
            titulo,
            style: LuvegiText.title.copyWith(
              color: LuvegiColors.secondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: LuvegiSpacing.lg),
          Expanded(child: chart),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

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

class _PuntoFecha {
  final String fecha;
  final double total;

  const _PuntoFecha({
    required this.fecha,
    required this.total,
  });
}
