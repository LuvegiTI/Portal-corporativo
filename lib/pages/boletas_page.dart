import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/boletas_service.dart'; // Importante: apunta al service de arriba

class BoletasPage extends StatefulWidget {
  final String token;
  const BoletasPage({super.key, required this.token});

  @override
  State<BoletasPage> createState() => _BoletasPageState();
}

class _BoletasPageState extends State<BoletasPage> {
  final _service = BoletasService();
  List<Map<String, dynamic>> _boletas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await _service.listar(widget.token);
      if (mounted) setState(() => _boletas = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _descargarSilencioso(int anio, int mes) async {
    // Pedir permisos según versión de Android
    if (Platform.isAndroid) {
      await Permission.storage.request();
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }

    final url = 'https://portal.luvegi.com/api_luvegi/descargar_boleta.php?anio=$anio&mes=$mes&token=${widget.token}';
    
    try {
      // Intentar usar carpeta pública de descargas en Android
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String nombreArchivo = "Boleta_${_nombreMes(mes)}_$anio.pdf";
      String rutaFinal = "${directory!.path}/$nombreArchivo";

      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await Dio().download(url, rutaFinal);

      if (!mounted) return;
      Navigator.pop(context); // Quitar indicador

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Guardado en Descargas: $nombreArchivo'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _nombreMes(int mes) {
    const meses = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return (mes >= 1 && mes <= 12) ? meses[mes] : 'Mes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📄 Mis Boletas'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _boletas.isEmpty
              ? const Center(child: Text('No tienes boletas registradas.'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    itemCount: _boletas.length,
                    padding: const EdgeInsets.all(10),
                    itemBuilder: (context, index) {
                      final b = _boletas[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          title: Text('${_nombreMes(b['mes'])} ${b['anio']}'),
                          subtitle: const Text('Toca para bajar a tu celular'),
                          trailing: const Icon(Icons.file_download),
                          onTap: () => _descargarSilencioso(b['anio'], b['mes']),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}