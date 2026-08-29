import 'package:flutter/material.dart';
import '../services/admin_catalogos_acceso_service.dart';

class AdminCatalogosAccesoPage extends StatefulWidget {
  final String token;

  const AdminCatalogosAccesoPage({super.key, required this.token});

  @override
  State<AdminCatalogosAccesoPage> createState() =>
      _AdminCatalogosAccesoPageState();
}

class _AdminCatalogosAccesoPageState
    extends State<AdminCatalogosAccesoPage> {
  final _api = AdminCatalogosAccesoService();
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _permisos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _normalizarCodigo(String texto) {
    const reemplazos = {
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'Ñ': 'N',
    };

    var codigo = texto.trim().toUpperCase();
    reemplazos.forEach((origen, destino) {
      codigo = codigo.replaceAll(origen, destino);
    });
    return codigo
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final result = await Future.wait([
        _api.areas(widget.token),
        _api.permisos(widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _areas = result[0];
        _permisos = result[1];
      });
    } catch (e) {
      if (mounted) _mensaje(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _mensaje(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : const Color(0xFF003366),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _areaDialog([Map<String, dynamic>? item]) async {
    final esNuevo = item == null;
    final formKey = GlobalKey<FormState>();
    final codigo = TextEditingController(
      text: item?['codigo']?.toString() ?? '',
    );
    final nombre = TextEditingController(
      text: item?['nombre']?.toString() ?? '',
    );
    final descripcion = TextEditingController(
      text: item?['descripcion']?.toString() ?? '',
    );

    void actualizarCodigo() {
      if (esNuevo) codigo.text = _normalizarCodigo(nombre.text);
    }

    if (esNuevo) nombre.addListener(actualizarCodigo);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(esNuevo ? 'Nueva área' : 'Editar área'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombre,
                  autofocus: esNuevo,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del área',
                    hintText: 'Servicios Comerciales',
                    helperText: 'Nombre visible para los usuarios.',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa el nombre del área.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codigo,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Identificador técnico',
                    hintText: 'SERVICIOS_COMERCIALES',
                    helperText: esNuevo
                        ? 'Se genera automáticamente a partir del nombre.'
                        : 'El identificador no puede modificarse.',
                    prefixIcon: const Icon(Icons.code),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'El nombre no genera un identificador válido.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descripcion,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Personal perteneciente al área...',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (esNuevo) nombre.removeListener(actualizarCodigo);
    if (ok != true) {
      codigo.dispose();
      nombre.dispose();
      descripcion.dispose();
      return;
    }

    try {
      if (esNuevo) {
        await _api.crearArea(widget.token, {
          'codigo': codigo.text,
          'nombre': nombre.text.trim(),
          'descripcion': descripcion.text.trim(),
        });
        _mensaje('Área creada correctamente.');
      } else {
        await _api.editarArea(widget.token, {
          'id': item['id'],
          'nombre': nombre.text.trim(),
          'descripcion': descripcion.text.trim(),
        });
        _mensaje('Área actualizada correctamente.');
      }
      await _cargar();
    } catch (e) {
      _mensaje(e.toString(), error: true);
    } finally {
      codigo.dispose();
      nombre.dispose();
      descripcion.dispose();
    }
  }

  Future<void> _permisoDialog([Map<String, dynamic>? item]) async {
    final formKey = GlobalKey<FormState>();
    final codigo = TextEditingController(text: item?['codigo']?.toString() ?? '');
    final descripcion = TextEditingController(text: item?['descripcion']?.toString() ?? '');
    final modulo = TextEditingController(text: item?['modulo']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Nuevo permiso / módulo' : 'Editar permiso'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: modulo,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Módulo', hintText: 'RDR'),
                  validator: (v) => _normalizarCodigo(v ?? '').isEmpty ? 'Ingresa el módulo.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codigo,
                  enabled: item == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Código del permiso'),
                  validator: item == null
                      ? (v) => _normalizarCodigo(v ?? '').isEmpty ? 'Ingresa el código.' : null
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descripcion,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa la descripción.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final data = <String, dynamic>{
        'modulo': _normalizarCodigo(modulo.text),
        'descripcion': descripcion.text.trim(),
      };
      if (item == null) {
        data['codigo'] = _normalizarCodigo(codigo.text);
        await _api.crearPermiso(widget.token, data);
      } else {
        data['id'] = item['id'];
        await _api.editarPermiso(widget.token, data);
      }
      await _cargar();
    } catch (e) {
      _mensaje(e.toString(), error: true);
    } finally {
      codigo.dispose();
      descripcion.dispose();
      modulo.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('ÁREAS, MÓDULOS Y PERMISOS'),
          backgroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, c) {
                  final areas = _panel(
                    'Áreas', Icons.apartment, 'Nueva área', () => _areaDialog(),
                    _areas.map((e) => _tile(
                      e['nombre'].toString(), e['codigo'].toString(),
                      _activo(e['activo']), '${e['usuarios']} usuario(s)',
                      () => _areaDialog(e), () async {
                        try {
                          await _api.toggleArea(widget.token, int.parse(e['id'].toString()));
                          await _cargar();
                        } catch (x) { _mensaje(x.toString(), error: true); }
                      },
                    )).toList(),
                  );
                  final permisos = _panel(
                    'Módulos y permisos', Icons.security, 'Nuevo permiso', () => _permisoDialog(),
                    _permisos.map((e) => _tile(
                      e['codigo'].toString(), e['modulo'].toString(),
                      _activo(e['activo']), e['descripcion'].toString(),
                      () => _permisoDialog(e), () async {
                        try {
                          await _api.togglePermiso(widget.token, int.parse(e['id'].toString()));
                          await _cargar();
                        } catch (x) { _mensaje(x.toString(), error: true); }
                      },
                    )).toList(),
                  );
                  return c.maxWidth < 900
                      ? ListView(padding: const EdgeInsets.all(16), children: [areas, const SizedBox(height: 16), permisos])
                      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: areas), Expanded(child: permisos)]);
                },
              ),
      );

  bool _activo(dynamic value) =>
      value == true || value == 1 || value.toString() == '1';

  Widget _panel(String title, IconData icon, String button, VoidCallback add,
          List<Widget> items) =>
      SizedBox(
        height: 650,
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Icon(icon, color: const Color(0xFF003366)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: Text(button)),
              ]),
              const Divider(height: 28),
              Expanded(child: items.isEmpty ? const Center(child: Text('Sin registros')) : ListView(children: items)),
            ]),
          ),
        ),
      );

  Widget _tile(String title, String badge, bool active, String subtitle,
          VoidCallback edit, VoidCallback toggle) =>
      ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$badge · $subtitle'),
        leading: Icon(active ? Icons.check_circle : Icons.pause_circle,
            color: active ? Colors.green : Colors.grey),
        trailing: Wrap(children: [
          IconButton(onPressed: edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: toggle, icon: Icon(active ? Icons.toggle_on : Icons.toggle_off, size: 32)),
        ]),
      );
}
