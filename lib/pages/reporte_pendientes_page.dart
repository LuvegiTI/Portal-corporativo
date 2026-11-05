import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../design_system/luvegi_loading.dart';

class ReportePendientesPage extends StatefulWidget {
  final String token;
  const ReportePendientesPage({super.key, required this.token});

  @override
  State<ReportePendientesPage> createState() => _ReportePendientesPageState();
}

class _ReportePendientesPageState extends State<ReportePendientesPage>
    with SingleTickerProviderStateMixin, LuvegiProgresoMixin {
  static const Color _navy = Color(0xFF003366);
  static const Color _lightBlue = Color(0xFFE2E8F0);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _accentRed = Color(0xFFDC2626);
  static const Color _accentGreen = Color(0xFF059669);

  late TabController _tabController;
  bool loading = true;
  int? selectedYear;
  int selectedMonth = 0;

  List<int> years = [];
  List pendientes = [];
  List descargadas = [];

  final List<String> mesesNombres = [
    'Todos',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    cancelarProgresoTimer();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    iniciarProgreso();
    try {
      final Map<String, dynamic> params = {};
      if (selectedYear != null) params['anio'] = selectedYear;
      if (selectedMonth > 0) params['mes'] = selectedMonth;

      final res = await Dio().get(
        "https://portal.luvegi.com/api_luvegi/reporte_boletas_pendientes.php",
        queryParameters: params,
        options: Options(headers: {"Authorization": "Bearer ${widget.token}"}),
      );

      if (mounted && res.data['ok'] == true) {
        setState(() {
          years = List<int>.from(res.data['anios_disponibles'] ?? []);
          if (selectedYear == null && years.isNotEmpty)
            selectedYear = years.first;

          // AQUÍ ESTABA EL DETALLE: Ahora el PHP manda listas de empleados
          pendientes = res.data['pendientes'] ?? [];
          descargadas = res.data['descargadas'] ?? [];
          loading = false;
        });
        detenerProgreso();
      }
    } catch (e) {
      if (mounted) {
        detenerProgreso();
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "Control de Boletas",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0.5,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _navy,
          unselectedLabelColor: Colors.blueGrey,
          indicatorColor: _navy,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Pendientes (${pendientes.length})'),
            Tab(text: 'Recibidas (${descargadas.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: loading
                ? buildProgreso()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAgrupadoList(pendientes, true),
                      _buildAgrupadoList(descargadas, false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- LISTA AGRUPADA (Para que RRHH no se maree) ---
  Widget _buildAgrupadoList(List employees, bool isPendiente) {
    if (employees.isEmpty) {
      return const Center(child: Text("No hay registros para este periodo"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: employees.length,
      itemBuilder: (ctx, i) {
        final emp = employees[i];
        final Color statusColor = isPendiente ? _accentRed : _accentGreen;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _lightBlue.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    emp['nombre'][0],
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              title: Text(
                emp['nombre'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _navy,
                ),
              ),
              subtitle: Text(
                "${emp['total_boletas']} boletas ${isPendiente ? 'pendientes' : 'recibidas'}",
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                ...List.generate(emp['meses'].length, (index) {
                  final m = emp['meses'][index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      "${mesesNombres[m['mes']]} ${m['anio']}",
                      style: const TextStyle(fontSize: 13, color: _navy),
                    ),
                    trailing: Icon(
                      isPendiente ? Icons.hourglass_top : Icons.check_circle,
                      color: statusColor,
                      size: 16,
                    ),
                  );
                }),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _dropdown(
              "Año",
              selectedYear,
              years
                  .map((y) => DropdownMenuItem(value: y, child: Text("$y")))
                  .toList(),
              (v) {
                setState(() => selectedYear = v);
                _fetch();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _dropdown(
              "Mes",
              selectedMonth,
              List.generate(
                mesesNombres.length,
                (i) => DropdownMenuItem(value: i, child: Text(mesesNombres[i])),
              ),
              (v) {
                setState(() => selectedMonth = v!);
                _fetch();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _lightBlue),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              items: items,
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down, color: _navy),
              style: const TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
