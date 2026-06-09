import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class MisBoletasPage extends StatefulWidget {
  final String token;
  const MisBoletasPage({super.key, required this.token});

  @override
  State<MisBoletasPage> createState() => _MisBoletasPageState();
}

class _MisBoletasPageState extends State<MisBoletasPage>
    with SingleTickerProviderStateMixin {
  List allBoletas = [];
  List filteredBoletas = [];
  List<String> years = [];

  String? selectedYear;
  int selectedMonth = 0;
  bool loading = true;

  // Mapa para almacenar los estados de descarga por cada boleta
  Map<String, dynamic> estadosBoletas = {};

  late AnimationController _animController;

  // Configuración de Estilos
  static const Color _navy = Color(0xFF003366);
  static const Color _bg = Color(0xFFF1F5F9);
  static const Color _textDark = Color(0xFF1E293B);

  static const TextStyle _dropdownItemStyle = TextStyle(
    color: _textDark,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  final List<String> mesesNombres = [
    'Todos los meses', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _inicializarDatos();
  }

  Future<void> _inicializarDatos() async {
    await _fetch();
    await _fetchEstados();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE DATOS ---

  String _formatearFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty || fecha == "null" || fecha == "0000-00-00 00:00:00") return "---";
    try {
      DateTime dt = DateTime.parse(fecha);
      String dia = dt.day.toString().padLeft(2, '0');
      String mes = dt.month.toString().padLeft(2, '0');
      String hora = dt.hour.toString().padLeft(2, '0');
      String min = dt.minute.toString().padLeft(2, '0');
      return "$dia/$mes/${dt.year} $hora:$min";
    } catch (e) {
      return fecha;
    }
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    try {
      final res = await Dio().get(
        "https://portal.luvegi.com/api_luvegi/obtener_mis_boletas.php?listar=1",
        options: Options(headers: {"Authorization": "Bearer ${widget.token}"}),
      );
      if (mounted) {
        List data = [];
        if (res.data is List) {
          data = res.data;
        } else if (res.data is Map && res.data['boletas'] != null) {
          data = res.data['boletas'];
        }

        Set<String> uniqueYears = data.map((b) => b['anio'].toString()).toSet();
        List<String> sortedYears = uniqueYears.toList()..sort((a, b) => b.compareTo(a));

        setState(() {
          allBoletas = data;
          years = sortedYears;
          if (selectedYear == null && years.isNotEmpty) selectedYear = years.first;
          _applyFilters();
          loading = false;
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _snack("Error de conexión", isError: true);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      filteredBoletas = allBoletas.where((b) {
        final matchesYear = b['anio'].toString() == selectedYear;
        final matchesMonth = selectedMonth == 0 ||
            int.parse(b['mes'].toString()) == selectedMonth;
        return matchesYear && matchesMonth;
      }).toList();
      filteredBoletas.sort((a, b) => int.parse(b['mes'].toString())
          .compareTo(int.parse(a['mes'].toString())));
    });
  }

  Future<void> _fetchEstados() async {
    try {
      final res = await Dio().get(
        "https://portal.luvegi.com/api_luvegi/obtener_estado_boletas.php",
        options: Options(headers: {"Authorization": "Bearer ${widget.token}"}),
      );
      if (mounted && res.data is Map && res.data['ok'] == true) {
        setState(() {
          estadosBoletas = Map<String, dynamic>.from(res.data['estados']);
        });
      }
    } catch (e) {
      debugPrint("Error estados: $e");
    }
  }

  // --- LÓGICA DE DESCARGA Y REGISTRO ---

  Future<void> _registrarDescarga(Map boleta) async {
    try {
      await Dio().post(
        "https://portal.luvegi.com/api_luvegi/registrar_descarga_boletas.php",
        data: {
          "anio": boleta['anio'].toString(),
          "mes": boleta['mes'].toString(),
        },
        options: Options(headers: {"Authorization": "Bearer ${widget.token}"}),
      );
      await _fetchEstados();
    } catch (e) {
      debugPrint("Error registro: $e");
    }
  }

  Future<void> _descargarPDF(Map boleta) async {
    final mesNum = int.parse(boleta['mes'].toString());
    final anio = boleta['anio'].toString();
    final key = '$anio-$mesNum';

    final bool yaConfirmada = estadosBoletas.containsKey(key) &&
        estadosBoletas[key]['primera'] != null &&
        estadosBoletas[key]['primera'] != "null";

    if (!yaConfirmada) {
      final confirmado = await _mostrarDialogoConfirmacion(mesNum, anio);
      if (confirmado != true) return;
    }

    _ejecutarDescarga(boleta, mesNum, anio);
  }

  Future<void> _ejecutarDescarga(Map boleta, int mes, String anio) async {
    final url = "https://portal.luvegi.com/api_luvegi/obtener_mis_boletas.php?anio=$anio&mes=${boleta['mes']}&token=${widget.token}";

    if (kIsWeb) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
        await _registrarDescarga(boleta);
      }
      return;
    }

    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      final savePath = "${dir.path}/Boleta_${boleta['mes']}_$anio.pdf";

      _showLoadingDialog(mes, anio);

      await Dio().download(url, savePath);
      await _registrarDescarga(boleta);

      if (mounted) {
        Navigator.pop(context);
        _snack("✅ Boleta guardada y recepción registrada");
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _snack("❌ Error al descargar", isError: true);
      }
    }
  }

  // --- DISEÑO DE LA INTERFAZ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("Mis Boletas", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () { _fetch(); _fetchEstados(); },
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sincronizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderFilters(),
          if (!loading) _buildCounterInfo(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: _navy))
                : filteredBoletas.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: _navy,
                        onRefresh: () async {
                          await _fetch();
                          await _fetchEstados();
                        },
                        child: ListView.builder(
                          itemCount: filteredBoletas.length,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          itemBuilder: (c, i) => _buildCardBoleta(filteredBoletas[i], i),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBoleta(Map b, int index) {
    final mes = int.tryParse(b['mes'].toString()) ?? 0;
    
    // 1. SUBIDO: Campo inmutable de la primera carga
    String rawSubida = b['fecha_subida']?.toString() ?? ""; 
    
    // 2. ACTUALIZADO: Campo que cambia con el UPDATE
    String rawActualizacion = b['creado_en']?.toString() ?? "";

    final String fSubida = _formatearFecha(rawSubida);
    final String fActualizacion = _formatearFecha(rawActualizacion);

    // Lógica para detectar si hubo una actualización real
    bool fueActualizada = rawActualizacion.isNotEmpty && 
                         rawActualizacion != "null" && 
                         rawActualizacion != rawSubida;

    return AnimatedBuilder(
      animation: _animController,
      builder: (ctx, child) {
        final delay = (index * 0.08).clamp(0.0, 0.85);
        final t = ((_animController.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 24 * (1 - Curves.easeOutCubic.transform(t))),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _navy.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _descargarPDF(b),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildPdfIcon(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(mesesNombres[mes], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textDark)),
                          const SizedBox(width: 8),
                          _buildYearBadge(b['anio'].toString()),
                        ]),
                        const SizedBox(height: 6),
                        
                        _buildDateRow(Icons.cloud_upload_outlined, "Subido:", fSubida),

                        if (fueActualizada) ...[
                          const SizedBox(height: 2),
                          _buildDateRow(Icons.edit_calendar_outlined, "Actualizado:", fActualizacion),
                        ],

                        const SizedBox(height: 10),
                        _buildChipEstado(b),
                      ],
                    ),
                  ),
                  _buildDownloadActionIcon(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipEstado(Map b) {
    final key = '${b['anio']}-${b['mes']}';
    final datos = estadosBoletas[key];

    if (datos == null || datos['primera'] == null || datos['primera'] == "null" || datos['primera'] == "") {
      return _chipContainer(Colors.grey.shade100, Colors.grey.shade300, Icons.schedule_rounded, "Pendiente de descarga", Colors.grey.shade600);
    }

    final String rawPrimera = datos['primera'].toString();
    final String rawUltima = datos['ultima']?.toString() ?? "";

    final String fPrimera = _formatearFecha(rawPrimera);
    final String fUltima = _formatearFecha(rawUltima);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipContainer(const Color(0xFFECFDF5), const Color(0xFF6EE7B7), Icons.verified_rounded, "Recibida: $fPrimera", const Color(0xFF065F46)),

        if (rawUltima.isNotEmpty && rawUltima != "null" && rawUltima != rawPrimera) ...[
          const SizedBox(height: 4),
          _chipContainer(const Color(0xFFEFF6FF), const Color(0xFF93C5FD), Icons.history_rounded, "Última desc: $fUltima", const Color(0xFF1E40AF)),
        ],
      ],
    );
  }

  // --- COMPONENTES UI AUXILIARES ---

  Widget _buildHeaderFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)), boxShadow: [BoxShadow(color: _navy.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))]),
      child: Row(
        children: [
          Expanded(child: _buildDropdownField<String?>("Año", Icons.calendar_today_rounded, selectedYear, years.map((y) => DropdownMenuItem(value: y, child: Text("Año $y", style: _dropdownItemStyle))).toList(), (val) { setState(() => selectedYear = val); _applyFilters(); })),
          const SizedBox(width: 15),
          Expanded(child: _buildDropdownField<int>("Mes", Icons.date_range_rounded, selectedMonth, List.generate(mesesNombres.length, (i) => DropdownMenuItem(value: i, child: Text(mesesNombres[i], style: _dropdownItemStyle))), (val) { if (val != null) setState(() => selectedMonth = val); _applyFilters(); })),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>(String label, IconData icon, T value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 12, color: _navy), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _navy))]),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: _navy.withOpacity(0.12))),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            items: items,
            onChanged: onChanged,
           dropdownColor: Colors.white,
           borderRadius: BorderRadius.circular(12),
           icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: _navy),
            selectedItemBuilder: (BuildContext context) {
              return items.map<Widget>((DropdownMenuItem<T> item) {
                return Align(
                  alignment: Alignment.centerLeft, 
                  child: Text(
                    (item.child as Text).data!, 
                    style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 13)
                  )
                );
              }).toList();
           },
          ),
        ),
      ),
    ]);
  }

  Widget _buildDateRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 12, color: Colors.blueGrey.withOpacity(0.6)),
      const SizedBox(width: 4),
      Text("$label $value", style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _chipContainer(Color bg, Color border, IconData icon, String text, Color txtCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: txtCol),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: txtCol, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPdfIcon() {
    return Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFFFEBEB), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28));
  }

  Widget _buildYearBadge(String anio) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Text(anio, style: const TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  Widget _buildDownloadActionIcon() {
    return Container(width: 40, height: 40, decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _navy.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))]), child: const Icon(Icons.download_rounded, color: Colors.white, size: 20));
  }

  Widget _buildCounterInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: _navy.withOpacity(0.15))),
        child: Text('${filteredBoletas.length} ${filteredBoletas.length == 1 ? 'boleta' : 'boletas'}', style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_off_rounded, size: 60, color: Colors.grey.shade300), const SizedBox(height: 10), const Text("No hay boletas disponibles", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]));
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : _navy, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _showLoadingDialog(int mes, String anio) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => Theme(data: ThemeData.light(), child: Dialog(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(color: _navy), const SizedBox(height: 16), const Text('Descargando boleta...', style: TextStyle(fontWeight: FontWeight.w600, color: _navy)), const SizedBox(height: 4), Text('${mesesNombres[mes]} $anio', style: const TextStyle(color: Colors.blueGrey, fontSize: 12))])))));
  }

  Future<bool?> _mostrarDialogoConfirmacion(int mes, String anio) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: const Color(0xFFE8F0FB), borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.verified_user_rounded, color: _navy, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Confirmación de recepción', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textDark)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFE8F0FB), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text('Boleta ${mesesNombres[mes]} $anio', style: const TextStyle(fontWeight: FontWeight.w700, color: _navy, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFCD34D))),
                child: const Text(
                  'Al confirmar, declaro haber recibido y tomado conocimiento de mi boleta de pago correspondiente al período indicado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.blueGrey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}