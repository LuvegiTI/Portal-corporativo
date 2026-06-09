import 'package:flutter/material.dart';
import '../services/reportes_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportesPage extends StatefulWidget {
  final String token;
  const ReportesPage({super.key, required this.token});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final _cuentaCtrl = TextEditingController();
  final _service = ReportesService();
  bool _loading = false;
  List<Map<String, dynamic>> _data = [];
  double _totalGeneral = 0;
  String _vista = 'tabla';

  final Color _azulLuvegi = const Color(0xFF003366);
  final Color _negroPuro = Colors.black;

  static const List<String> _meses = [
    '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  double _toDouble(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

  // --- Lógica de Búsqueda ---
  Future<void> _buscar() async {
    final cuenta = _cuentaCtrl.text.trim();
    if (cuenta.isEmpty) return;

    setState(() { _loading = true; _data = []; _totalGeneral = 0; });

    try {
      final res = await _service.consultar(token: widget.token, cuenta: cuenta);
      
      if (mounted) {
        double suma = 0;
        final processedData = List<Map<String, dynamic>>.from(res['data']).map((item) {
          final row = Map<String, dynamic>.from(item);
          final String ref = (row['referencia'] ?? '').toString().toUpperCase();
          
          // Detectar devoluciones por el formato de albarán o valores negativos
          bool esDevo = ref.contains('/IN/') || _toDouble(row['total']) < 0;
          double cant = _toDouble(row['cantidad']);
          double tot = _toDouble(row['total']);

          if (esDevo) {
            row['c_final'] = cant < 0 ? cant : cant * -1;
            row['t_final'] = tot < 0 ? tot : tot * -1;
            row['color_fila'] = Colors.red.shade900;
          } else {
            row['c_final'] = cant;
            row['t_final'] = tot;
            row['color_fila'] = (row['tipo'] == 'contabilidad') ? Colors.blue.shade900 : _negroPuro;
          }

          suma += row['t_final'];
          return row;
        }).toList();

        setState(() {
          _data = processedData;
          _totalGeneral = suma;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('REPORTE CONSOLIDADO', 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF003366))),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: _data.isEmpty ? null : [
          IconButton(
            icon: Icon(Icons.table_rows, color: _vista == 'tabla' ? _azulLuvegi : Colors.grey), 
            onPressed: () => setState(() => _vista = 'tabla')
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, color: _vista == 'graficos' ? _azulLuvegi : Colors.grey), 
            onPressed: () => setState(() => _vista = 'graficos')
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearch(),
          Expanded(
            child: _loading 
              ? Center(child: CircularProgressIndicator(color: _azulLuvegi))
              : _data.isEmpty 
                ? const Center(child: Text("Sin resultados", style: TextStyle(fontWeight: FontWeight.bold))) 
                : _vista == 'tabla' ? _buildTabla(screenWidth) : _buildGraficos(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _cuentaCtrl,
              decoration: InputDecoration(
                labelText: 'Cuenta Analítica',
                prefixIcon: Icon(Icons.search, color: _azulLuvegi),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
              ),
              onSubmitted: (_) => _buscar(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _loading ? null : _buscar,
            style: ElevatedButton.styleFrom(backgroundColor: _azulLuvegi, padding: const EdgeInsets.all(18)),
            child: const Text('BUSCAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabla(double screenWidth) {
    return SizedBox(
      width: screenWidth,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: screenWidth),
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: MaterialStateProperty.all(const Color(0xFFCFD8DC)),
              columns: const [
                DataColumn(label: Text('FECHA', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('REF / TIPO', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('PRODUCTO / ETIQUETA', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('VER', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _data.map((r) {
                final Color colorTexto = r['color_fila'];
                return DataRow(cells: [
                  DataCell(Text(r['fecha'] ?? '', style: TextStyle(color: colorTexto, fontSize: 11))),
                  DataCell(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(r['referencia'] ?? '', style: TextStyle(color: colorTexto, fontWeight: FontWeight.w900, fontSize: 11)),
                      Text(r['doc_tipo'] ?? '', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  )),
                  DataCell(SizedBox(
                    width: screenWidth * 0.4,
                    child: Text(r['producto'] ?? '', 
                      style: TextStyle(fontSize: 10, color: colorTexto, fontWeight: FontWeight.bold),
                      maxLines: 2, overflow: TextOverflow.ellipsis)
                  )),
                  DataCell(Text('S/. ${r['t_final'].toStringAsFixed(2)}', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorTexto))),
                  DataCell(IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.blue, size: 22), 
                    onPressed: () => _abrirOdoo(r)
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      color: _azulLuvegi,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('TOTAL NETO:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text('S/. ${_totalGeneral.toStringAsFixed(2)}', 
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _abrirOdoo(Map<String, dynamic> r) async {
    final modelo = (r['tipo'] == 'contabilidad') ? 'account.move' : 'stock.picking';
    final url = 'https://luvegi-odoo171.odoo.com/web#id=${r['res_id']}&model=$modelo&view_type=form';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // --- Lógica de Gráficos ---
  Widget _buildGraficos() {
    final puntos = _agruparPorFecha();
    if (puntos.isEmpty) return const Center(child: Text("Sin datos para graficar"));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard('EVOLUCIÓN MENSUAL', BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: puntos.asMap().entries.map((e) => BarChartGroupData(
                x: e.key,
                barRods: [BarChartRodData(toY: e.value.total, color: _azulLuvegi, width: 15)]
              )).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, _) => Text(puntos[val.toInt()].fecha, style: const TextStyle(fontSize: 9))
                ))
              )
            )
          )),
        ],
      ),
    );
  }

  List<_PuntoFecha> _agruparPorFecha() {
    final Map<String, double> acum = {};
    for (final r in _data) {
      final partes = (r['fecha'] ?? '').toString().split('-').take(2).toList();
      if (partes.length < 2) continue;
      final clave = "${partes[0]}-${partes[1]}";
      acum[clave] = (acum[clave] ?? 0) + (_toDouble(r['t_final']));
    }
    final sorted = acum.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      final p = e.key.split('-');
      final etiqueta = "${_meses[int.parse(p[1])]} ${p[0].substring(2)}";
      return _PuntoFecha(fecha: etiqueta, total: e.value);
    }).toList();
  }

  Widget _buildChartCard(String titulo, Widget chart) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200)
      ),
      child: Column(
        children: [
          Text(titulo, style: TextStyle(color: _azulLuvegi, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(child: chart),
        ],
      ),
    );
  }
}

class _PuntoFecha {
  final String fecha;
  final double total;
  const _PuntoFecha({required this.fecha, required this.total});
}