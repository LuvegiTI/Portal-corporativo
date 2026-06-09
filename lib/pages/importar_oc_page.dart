import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/importar_oc_service.dart';

class ImportarOcPage extends StatefulWidget {
  final String token;

  const ImportarOcPage({
    super.key,
    required this.token,
  });

  @override
  State<ImportarOcPage> createState() => _ImportarOcPageState();
}

class _ImportarOcPageState extends State<ImportarOcPage> {
  final TextEditingController _ocCtrl = TextEditingController(text: 'OC03951');
  final ImportarOcService _service = ImportarOcService();

  bool _loading = false;
  String _archivoNombre = 'Ningún archivo seleccionado';
  List<Map<String, dynamic>> _lineas = [];

  String _cellValue(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }

  double _toDouble(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  Future<void> _seleccionarExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    final bytes = file.bytes!;

    final lineas = _leerExcel(bytes);

    setState(() {
      _archivoNombre = file.name;
      _lineas = lineas;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excel cargado: ${lineas.length} líneas válidas')),
    );
  }

  List<Map<String, dynamic>> _leerExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];

    if (sheet == null) return [];

    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => _cellValue(e)).toList();

    int col(String name) => headers.indexWhere(
          (h) => h.toLowerCase().trim() == name.toLowerCase().trim(),
        );

    final cProducto = col('Producto');
    final cDescripcion = col('Descripción');
    final cCantidad = col('Cantidad');
    final cPrecio = col('Precio Unitario');
    final cEntrega = col('Entrega Esperada');
    final cImpuestos = col('Impuestos');
    final cAna1 = col('Distribución Analítica1');
    final cAna2 = col('Distribución Analítica2');
    final cAna3 = col('Distribución Analítica3');

    if (cProducto == -1 ||
        cDescripcion == -1 ||
        cCantidad == -1 ||
        cPrecio == -1 ||
        cEntrega == -1) {
      throw Exception('El Excel no tiene las columnas necesarias.');
    }

    final List<Map<String, dynamic>> data = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      String get(int index) {
        if (index == -1 || index >= row.length) return '';
        return _cellValue(row[index]);
      }

      String producto = get(cProducto);

      if (producto.isEmpty || producto.toLowerCase() == 'nan') continue;

      if (producto.endsWith('.0')) {
        producto = producto.substring(0, producto.length - 2);
      }

      data.add({
        'producto': producto,
        'descripcion': get(cDescripcion),
        'cantidad': _toDouble(get(cCantidad)),
        'precio_unitario': _toDouble(get(cPrecio)),
        'entrega_esperada': get(cEntrega),
        'impuestos': get(cImpuestos),
        'analitica1': get(cAna1),
        'analitica2': get(cAna2),
        'analitica3': get(cAna3),
      });
    }

    return data;
  }

  Future<void> _importar() async {
    final oc = _ocCtrl.text.trim();

    if (oc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe la Orden de Compra')),
      );
      return;
    }

    if (_lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona un Excel válido')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await _service.importar(
        token: widget.token,
        ordenCompra: oc,
        lineas: _lineas,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importación exitosa. Líneas procesadas: ${res['procesados']}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception:', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ocCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1F4E78);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importador OC'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Importador de Líneas a Compras',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _ocCtrl,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Orden de Compra destino',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  OutlinedButton.icon(
                    onPressed: _loading ? null : _seleccionarExcel,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('1. Seleccionar Archivo Excel'),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _archivoNombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Líneas detectadas: ${_lineas.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _importar,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.rocket_launch),
                      label: Text(
                        _loading
                            ? 'Importando...'
                            : '2. Iniciar Importación en Odoo',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                      ),
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
}