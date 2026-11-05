import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_boletas_service.dart';
import '../utils/mensaje_error.dart';

class AdminBoletasPage extends StatefulWidget {
  final String token;
  const AdminBoletasPage({super.key, required this.token});

  @override
  State<AdminBoletasPage> createState() => _AdminBoletasPageState();
}

class _AdminBoletasPageState extends State<AdminBoletasPage> {
  final _service = AdminBoletasService();
  late final _anioCtrl = TextEditingController(
    text: DateTime.now().year.toString(),
  );

  final List<Map<String, String>> _todosLosMeses = [
    {"id": "1", "nombre": "Ene"},
    {"id": "2", "nombre": "Feb"},
    {"id": "3", "nombre": "Mar"},
    {"id": "4", "nombre": "Abr"},
    {"id": "5", "nombre": "May"},
    {"id": "6", "nombre": "Jun"},
    {"id": "7", "nombre": "Jul"},
    {"id": "8", "nombre": "Ago"},
    {"id": "9", "nombre": "Sep"},
    {"id": "10", "nombre": "Oct"},
    {"id": "11", "nombre": "Nov"},
    {"id": "12", "nombre": "Dic"},
  ];

  List<int> _mesesCargados = [];
  List<dynamic> _datosTabla = [];
  String? _mesSeleccionado;
  bool _modoActualizacion = false; // ← true cuando selecciona un mes ya cargado
  bool _cargandoResumen = false;
  bool _subiendo = false;
  int? _mesRecienSubido;
  Set<int> _actualizandoMes = {};
  Uint8List? fileBytes;
  String? fileName;

  bool _errorMes = false;
  bool _errorArchivo = false;

  DateTime? _ultimoCambioAnio;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _anioCtrl.addListener(_onAnioChanged);
  }

  @override
  void dispose() {
    _anioCtrl.removeListener(_onAnioChanged);
    _anioCtrl.dispose();
    super.dispose();
  }

  void _onAnioChanged() {
    if (_anioCtrl.text.length != 4) return;
    _ultimoCambioAnio = DateTime.now();
    final captured = _ultimoCambioAnio;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_ultimoCambioAnio == captured && mounted) _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _cargandoResumen = true);
    try {
      final res = await _service.getResumen(
        token: widget.token,
        anio: _anioCtrl.text,
      );
      if (res["ok"] == true) {
        final List ocupados = res["meses_con_boletas"] ?? [];
        setState(() {
          _mesesCargados = ocupados.map<int>((e) => e as int).toList();
          _datosTabla = res["tabla_resumen"] ?? [];
          _mesSeleccionado = null;
          _modoActualizacion = false;
        });
      }
    } catch (e) {
      _snack(MensajeError.desdeExcepcion(e), error: true);
    } finally {
      if (mounted) setState(() => _cargandoResumen = false);
    }
  }

  Future<void> _descargarPdf(int idBoleta) async {
    final uri = Uri.parse(
      "https://portal.luvegi.com/api_luvegi/admin_boletas.php?download=true&id=$idBoleta&token=${widget.token}",
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _snack("No se pudo abrir el archivo", error: true);
      }
    } catch (_) {
      _snack("Error de conexión", error: true);
    }
  }

  Future<void> _subir() async {
    setState(() {
      _errorMes = _mesSeleccionado == null;
      _errorArchivo = fileBytes == null;
    });
    if (_errorMes || _errorArchivo) return;

    // Si es actualización, pedir confirmación
    if (_modoActualizacion) {
      final mesNombre = _nombreMesLargo(int.parse(_mesSeleccionado!));
      final confirmar = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Theme(
          data: ThemeData.light(),
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícono
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.update_rounded,
                      color: Colors.orange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Título
                  const Text(
                    'Actualizar boletas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Mes identificado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF003366),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mesNombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF003366),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Aviso
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      'Solo se reemplazarán las boletas que coincidan con los nombres del ZIP. Las demás se mantendrán sin cambios.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueGrey,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.blueGrey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Actualizar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (confirmar != true) return;
    }

    setState(() => _subiendo = true);
    final res = await _service.subirZip(
      token: widget.token,
      anio: int.parse(_anioCtrl.text),
      mes: int.parse(_mesSeleccionado!),
      fileBytes: fileBytes!,
      fileName: fileName!,
    );
    setState(() => _subiendo = false);

    if (res["ok"] == true) {
      final mesId = int.parse(_mesSeleccionado!);
      setState(() {
        _mesRecienSubido = mesId;
        fileBytes = null;
        fileName = null;
        _modoActualizacion = false;
      });
      await _fetchData();
      final msg = _modoActualizacion
          ? "✅ Boletas actualizadas correctamente"
          : "✅ Proceso completado con éxito";
      _snack(msg);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _mesRecienSubido = null);
      });
    } else {
      _snack(res["error"] ?? "Error en el servidor", error: true);
    }
  }

  // ── Actualizar desde la tabla (botón por fila) ──────────────────────────
  Future<void> _actualizarDesdeTabla(int mesId, String mesNombre) async {
    // Seleccionar el mes en el panel de carga y activar modo actualización
    setState(() {
      _mesSeleccionado = mesId.toString();
      _modoActualizacion = true;
      fileBytes = null;
      fileName = null;
    });
    _snack("Selecciona el ZIP para actualizar $mesNombre");
  }

  String _nombreMesLargo(int mesId) => [
    "Enero",
    "Febrero",
    "Marzo",
    "Abril",
    "Mayo",
    "Junio",
    "Julio",
    "Agosto",
    "Septiembre",
    "Octubre",
    "Noviembre",
    "Diciembre",
  ][mesId - 1];

  void _verDetalle(int mesId, String mesNombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.folder_open_rounded,
                        color: const Color(0xFF003366),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "BOLETAS DEL MES",
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          mesNombre,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: _service.getDetalleCarga(
                    token: widget.token,
                    anio: _anioCtrl.text,
                    mesId: mesId,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData && !snapshot.hasError) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF003366),
                        ),
                      );
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 52,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "No se pudo cargar",
                              style: TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003366),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _verDetalle(mesId, mesNombre);
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text("Reintentar"),
                            ),
                          ],
                        ),
                      );
                    }
                    final lista = (snapshot.data as Map)["detalles"] ?? [];
                    if (lista.isEmpty) {
                      return Center(
                        child: Text(
                          "Sin boletas en $mesNombre",
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      );
                    }
                    return _DetalleConBuscador(
                      listaCompleta: lista,
                      scrollCtrl: scrollCtrl,
                      onDescargar: _descargarPdf,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Gestión de Boletas",
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            Text(
              "Panel Administrativo de RRHH",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh, color: const Color(0xFF003366)),
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 950;
            return isMobile
                ? Column(
                    children: [
                      _panelCarga(),
                      const SizedBox(height: 24),
                      _panelTabla(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _panelCarga()),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: _panelTabla()),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _panelCarga() {
    return _cardBase(
      title: _modoActualizacion ? "Actualizar Boletas" : "Nueva Carga",
      icon: _modoActualizacion
          ? Icons.update_rounded
          : Icons.cloud_upload_outlined,
      child: Column(
        children: [
          // Banner modo actualización
          if (_modoActualizacion)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Actualizando ${_nombreMesLargo(int.parse(_mesSeleccionado!))} — solo se reemplazarán las boletas que coincidan.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _mesSeleccionado = null;
                      _modoActualizacion = false;
                      fileBytes = null;
                      fileName = null;
                    }),
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.orange,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          TextField(
            controller: _anioCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            decoration: _inputStyle("Año Fiscal", Icons.calendar_today),
          ),
          const SizedBox(height: 20),
          _buildMiniCalendario(),
          const SizedBox(height: 20),
          _buildFilePicker(),

          if (_errorMes || _errorArchivo)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMes)
                    _errorHint(
                      "Debes seleccionar un mes",
                      Icons.calendar_month,
                    ),
                  if (_errorArchivo)
                    _errorHint(
                      "Debes seleccionar un archivo ZIP",
                      Icons.folder_zip_outlined,
                    ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _subiendo ? null : _subir,
              style: ElevatedButton.styleFrom(
                backgroundColor: _modoActualizacion
                    ? Colors.orange
                    : const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _subiendo
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _modoActualizacion
                              ? Icons.update_rounded
                              : Icons.bolt,
                          color: _modoActualizacion
                              ? Colors.white
                              : Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _modoActualizacion
                              ? "ACTUALIZAR BOLETAS"
                              : "SUBIR Y PROCESAR",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCalendario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SELECCIONAR MES",
          style: TextStyle(
            color: _errorMes ? Colors.red : Colors.blueGrey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 12,
          itemBuilder: (_, i) {
            final mes = _todosLosMeses[i];
            final mesId = int.parse(mes["id"]!);
            final esCargado = _mesesCargados.contains(mesId);
            final esSeleccionado = _mesSeleccionado == mes["id"];

            Color bgColor, textColor, borderColor;

            if (esSeleccionado && _modoActualizacion) {
              // Modo actualización: naranja
              bgColor = Colors.orange;
              textColor = Colors.white;
              borderColor = Colors.orange;
            } else if (esSeleccionado) {
              bgColor = const Color(0xFF1E293B);
              textColor = Colors.white;
              borderColor = const Color(0xFF1E293B);
            } else if (esCargado) {
              bgColor = Colors.green.withValues(alpha: 0.08);
              textColor = Colors.green.shade700;
              borderColor = Colors.green.shade300;
            } else {
              bgColor = const Color(0xFFF8FAFC);
              textColor = const Color(0xFF64748B);
              borderColor = const Color(0xFFE2E8F0);
            }

            return GestureDetector(
              onTap: () => setState(() {
                _mesSeleccionado = mes["id"];
                _modoActualizacion =
                    esCargado; // ← si ya tiene boletas = modo actualización
                _errorMes = false;
                fileBytes = null;
                fileName = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      mes["nombre"]!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (esCargado && !esSeleccionado)
                      Icon(
                        Icons.check_circle,
                        size: 10,
                        color: Colors.green.shade600,
                      ),
                    if (esCargado && esSeleccionado)
                      Icon(
                        Icons.update_rounded,
                        size: 10,
                        color: _modoActualizacion
                            ? Colors.white
                            : Colors.orange,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _leyenda(color: Colors.green.shade300, label: "Cargado"),
            const SizedBox(width: 10),
            _leyenda(color: Colors.orange, label: "Actualizar"),
            const SizedBox(width: 10),
            _leyenda(color: const Color(0xFF1E293B), label: "Nuevo"),
            const SizedBox(width: 10),
            _leyenda(color: const Color(0xFFE2E8F0), label: "Pendiente"),
          ],
        ),
      ],
    );
  }

  Widget _panelTabla() {
    return _cardBase(
      title: "Historial de Cargas",
      icon: Icons.history_rounded,
      child: _cargandoResumen
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          : _buildTable(),
    );
  }

  Widget _buildTable() {
    if (_datosTabla.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            Text(
              "Sin cargas en ${_anioCtrl.text}",
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Prueba con otro año o sube el primer ZIP",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        columnWidths: const {2: IntrinsicColumnWidth()},
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: [_th("MES"), _th("CANTIDAD"), _th("ACCIONES")],
          ),
          ..._datosTabla.map((item) {
            final mesId = int.parse(item["id"].toString());
            final esReciente = _mesRecienSubido == mesId;
            final mesNombre = _nombreMesLargo(mesId);
            final actualizando = _actualizandoMes.contains(mesId);

            return TableRow(
              decoration: BoxDecoration(
                color: esReciente
                    ? Colors.green.withValues(alpha: 0.06)
                    : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: esReciente
                        ? Colors.green.shade100
                        : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              children: [
                _td(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (esReciente)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.new_releases,
                            size: 14,
                            color: Colors.green.shade600,
                          ),
                        ),
                      Text(
                        mesNombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: esReciente
                              ? Colors.green.shade700
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                _td(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${item["cantidad"]} PDFs",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _td(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ver detalle
                      IconButton(
                        icon: const Icon(
                          Icons.remove_red_eye_outlined,
                          color: const Color(0xFF003366),
                          size: 20,
                        ),
                        onPressed: () => _verDetalle(mesId, mesNombre),
                      ),
                      // Actualizar ← reemplaza al eliminar
                      actualizando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.orange,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.update_rounded,
                                color: Colors.orange,
                                size: 20,
                              ),
                              tooltip: 'Actualizar boletas de $mesNombre',
                              onPressed: () =>
                                  _actualizarDesdeTabla(mesId, mesNombre),
                            ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────
  Widget _cardBase({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: _modoActualizacion
                    ? Colors.orange
                    : const Color(0xFF003366),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18, color: const Color(0xFF003366)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  Widget _buildFilePicker() {
    final selected = fileName != null;
    return InkWell(
      onTap: () async {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
          withData: true,
        );
        if (res != null) {
          setState(() {
            fileBytes = res.files.single.bytes;
            fileName = res.files.single.name;
            _errorArchivo = false;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _errorArchivo
              ? Colors.red.withValues(alpha: 0.04)
              : selected
              ? (_modoActualizacion
                    ? Colors.orange.withValues(alpha: 0.05)
                    : Colors.green.withValues(alpha: 0.05))
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _errorArchivo
                ? Colors.red.shade300
                : selected
                ? (_modoActualizacion ? Colors.orange : Colors.green)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _errorArchivo
                  ? Icons.warning_amber_rounded
                  : selected
                  ? (_modoActualizacion
                        ? Icons.update_rounded
                        : Icons.check_circle_rounded)
                  : Icons.folder_zip_rounded,
              color: _errorArchivo
                  ? Colors.red.shade400
                  : selected
                  ? (_modoActualizacion ? Colors.orange : Colors.green)
                  : Colors.blueGrey,
            ),
            const SizedBox(height: 8),
            Text(
              selected ? fileName! : "Seleccionar archivo ZIP",
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: _errorArchivo
                    ? Colors.red.shade400
                    : selected
                    ? (_modoActualizacion
                          ? Colors.orange.shade800
                          : Colors.green[800])
                    : Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leyenda({required Color color, required String label}) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  Widget _errorHint(String msg, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 13, color: Colors.red.shade400),
        const SizedBox(width: 6),
        Text(
          msg,
          style: TextStyle(
            color: Colors.red.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _th(String t) => Padding(
    padding: const EdgeInsets.all(15),
    child: Center(
      child: Text(
        t,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF003366),
        ),
      ),
    ),
  );

  Widget _td(Widget w) => Padding(
    padding: const EdgeInsets.all(12),
    child: Center(child: w),
  );

  void _snack(String m, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: error ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
}

// ─── Widget buscador detalle ─────────────────────────────────────────────────
class _DetalleConBuscador extends StatefulWidget {
  final List listaCompleta;
  final ScrollController scrollCtrl;
  final void Function(int id) onDescargar;

  const _DetalleConBuscador({
    required this.listaCompleta,
    required this.scrollCtrl,
    required this.onDescargar,
  });

  @override
  State<_DetalleConBuscador> createState() => _DetalleConBuscadorState();
}

class _DetalleConBuscadorState extends State<_DetalleConBuscador> {
  final _searchCtrl = TextEditingController();
  List _filtrados = [];

  @override
  void initState() {
    super.initState();
    _filtrados = widget.listaCompleta;
    _searchCtrl.addListener(_filtrar);
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtrados = q.isEmpty
          ? widget.listaCompleta
          : widget.listaCompleta
                .where(
                  (item) => item["nombre"].toString().toLowerCase().contains(q),
                )
                .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.listaCompleta.length;
    final encontrados = _filtrados.length;
    final buscando = _searchCtrl.text.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xFF003366),
                    size: 20,
                  ),
                  suffixIcon: buscando
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey.shade400,
                            size: 18,
                          ),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: const Color(0xFF003366).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDCE8F8)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 15,
                      color: const Color(0xFF003366),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: buscando
                          ? RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: const Color(0xFF003366),
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(
                                    text: '$encontrados',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' de $total boleta${total != 1 ? 's' : ''}',
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              '$total boleta${total != 1 ? 's' : ''} en este mes',
                              style: TextStyle(
                                color: const Color(0xFF003366),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                    ),
                    if (buscando)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003366),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'FILTRANDO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 52,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Sin resultados para\n"${_searchCtrl.text}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _filtrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = _filtrados[i];
                    final nombre = item["nombre"].toString();
                    // final archivo = item["archivo"].toString();
                    final query = _searchCtrl.text.toUpperCase().trim();
                    final inicial = nombre.isNotEmpty
                        ? nombre[0].toUpperCase()
                        : '?';
                    final colors = [
                      const Color(0xFF003366),
                      Colors.teal,
                      Colors.deepPurple,
                      Colors.blue,
                      Colors.cyan.shade700,
                    ];
                    final color = colors[inicial.codeUnitAt(0) % colors.length];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Text(
                            inicial,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        title: _buildHighlight(nombre, query, color),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 12,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              //Expanded(child: Text(archivo,
                              //style: TextStyle(fontSize: 11,
                              //    color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                              // overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF05CD99,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.download_for_offline_rounded,
                              color: Color(0xFF05CD99),
                              size: 26,
                            ),
                            onPressed: () => widget.onDescargar(
                              int.parse(item["id"].toString()),
                            ),
                          ),
                        ),
                      ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHighlight(String texto, String query, Color color) {
    if (query.isEmpty) {
      return Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      );
    }
    final idx = texto.toUpperCase().indexOf(query);
    if (idx == -1) {
      return Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
        children: [
          TextSpan(text: texto.substring(0, idx)),
          TextSpan(
            text: texto.substring(idx, idx + query.length),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          TextSpan(text: texto.substring(idx + query.length)),
        ],
      ),
    );
  }
}
