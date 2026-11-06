import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../services/auditoria_service.dart';
import '../utils/mensaje_error.dart';

const String _baseUrl = 'https://portal.luvegi.com/api_luvegi';

class AdminUsuariosPage extends StatefulWidget {
  final String token;

  const AdminUsuariosPage({super.key, required this.token});

  @override
  State<AdminUsuariosPage> createState() => _AdminUsuariosPageState();
}

class _AdminUsuariosPageState extends State<AdminUsuariosPage> {
  bool _cargando = true;
  bool _sincronizandoCesados = false;
  bool _buscandoDni = false;
  Map<String, dynamic>? _dniEncontrado;
  Timer? _debounceDni;
  String _filtroEstado = 'TODOS';
  String _busqueda = '';

  List<dynamic> _usuarios = [];
  List<dynamic> _areasDisponibles = [];
  List<dynamic> _rolesDisponibles = [];
  final TextEditingController _busquedaController = TextEditingController();
  final AuditoriaService _auditoria = AuditoriaService();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // --- MÉTODOS DE API ---
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final url = Uri.parse('$_baseUrl/admin_usuarios.php?action=listar');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['ok'] == true) {
          final datos = body['data'] ?? {};
          setState(() {
            _usuarios = datos['usuarios'] ?? [];
            _areasDisponibles = datos['areas'] ?? [];
            _rolesDisponibles = datos['roles'] ?? [];
          });
          final conFoto = (datos['con_foto'] as num?)?.toInt() ?? 0;
          debugPrint(
            'Usuarios: ${_usuarios.length} | con foto Odoo: $conFoto',
          );
        }
      }
    } catch (e) {
      debugPrint('Error cargando usuarios: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Busca la persona en Odoo por DNI. Devuelve null si no existe.
  Future<Map<String, dynamic>?> _buscarPorDni(String dni) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/admin_usuarios.php?action=buscar_dni&dni=$dni',
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body);
      if (body['ok'] != true || body['encontrado'] != true) return null;
      return Map<String, dynamic>.from(body);
    } catch (e) {
      debugPrint('Error buscando DNI en Odoo: $e');
      return null;
    }
  }

  /// Rellena el DNI con los datos que devuelve el backend. Devuelve el mapa
  /// con la persona encontrada (o null) para que el dialogo la muestre.
  Future<Map<String, dynamic>?> _autocompletarPorDni(
    String dni,
    TextEditingController nombreCtrl,
    void Function(Map<String, dynamic>?) onResultado,
  ) async {
    final data = await _buscarPorDni(dni);
    if (!mounted) return null;
    onResultado(data);
    if (data != null && nombreCtrl.text.trim().isEmpty) {
      nombreCtrl.text = (data['nombre'] ?? '').toString();
    }
    return data;
  }

  /// Sincroniza con Odoo los usuarios que tienen la etiqueta "Cesado" y da
  /// de baja en el portal a los que corresponden. Primero muestra una vista
  /// previa: nada se da de baja hasta que se confirma.
  Future<void> _sincronizarCesados() async {
    setState(() => _sincronizandoCesados = true);
    Map<String, dynamic>? vista;
    try {
      final url = Uri.parse(
        '$_baseUrl/admin_usuarios.php?action=sincronizar_cesados',
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );
      final body = json.decode(response.body);
      if (!mounted) return;

      if (response.statusCode != 200 || body['ok'] != true) {
        final mensaje = body['mensaje']?.toString() ??
            MensajeError.desdeCodigo(body['error']?.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: LuvegiColors.error),
        );
        return;
      }
      vista = Map<String, dynamic>.from(body);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajeError.desdeExcepcion(e)),
          backgroundColor: LuvegiColors.error,
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _sincronizandoCesados = false);
    }

    final aBaja = (vista!['a_baja'] as List?) ?? const [];
    final sinCruce = (vista['sin_cruce'] as List?) ?? const [];
    final yaBaja = (vista['ya_baja'] as List?) ?? const [];
    final totalOdoo = (vista['cesados_odoo'] as num?)?.toInt() ?? 0;

    if (!mounted) return;
    final aplicar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sincronizar cesados con Odoo'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Odoo tiene $totalOdoo empleado(s) con la etiqueta "Cesado".',
                  style: LuvegiText.body,
                ),
                const SizedBox(height: 12),
                if (aBaja.isEmpty)
                  Text(
                    'No hay usuarios del portal por dar de baja.',
                    style: LuvegiText.bodySecondary,
                  )
                else ...[
                  Text(
                    'Se dará de baja:',
                    style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...aBaja.map(
                    (x) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.person_off_outlined,
                            size: 18,
                            color: LuvegiColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (x['usuario'] ?? '').toString(),
                                  style: LuvegiText.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${(x['correo'] ?? '').toString()} · '
                                  'Odoo: ${(x['empleado'] ?? '').toString()} · '
                                  'por ${(x['emparejado_por'] ?? '').toString()}',
                                  style: LuvegiText.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (yaBaja.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Ya estaban de baja: ${yaBaja.length}',
                    style: LuvegiText.caption,
                  ),
                ],
                if (sinCruce.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Sin coincidencia en el portal: ${sinCruce.length}',
                    style: LuvegiText.caption.copyWith(
                      color: LuvegiColors.error,
                    ),
                  ),
                  ...sinCruce.map(
                    (x) => Text(
                      '· ${(x['empleado'] ?? '').toString()}'
                      '${(x['dni'] ?? '').toString().isEmpty ? '' : ' (DNI ${(x['dni'])})'}',
                      style: LuvegiText.caption,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'La baja es efectiva de inmediato: al invalidar el usuario, '
                  'su sesión deja de servir en la siguiente petición.',
                  style: LuvegiText.caption,
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
            onPressed: aBaja.isEmpty ? null : () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: LuvegiColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              aBaja.isEmpty
                  ? 'Nada que dar de baja'
                  : 'Dar de baja (${aBaja.length})',
            ),
          ),
        ],
      ),
    );

    if (aplicar != true || !mounted) return;

    setState(() => _sincronizandoCesados = true);
    try {
      final url = Uri.parse(
        '$_baseUrl/admin_usuarios.php?action=sincronizar_cesados',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'aplicar': 1}),
      );
      final body = json.decode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200 && body['ok'] == true) {
        final dados = (body['dados_de_baja'] as num?)?.toInt() ?? 0;
        await _cargarDatos();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dados == 0
                  ? 'No había usuarios por dar de baja.'
                  : '$dados usuario(s) dado(s) de baja.',
            ),
            backgroundColor: LuvegiColors.success,
          ),
        );
      } else {
        final mensaje = body['mensaje']?.toString() ??
            MensajeError.desdeCodigo(body['error']?.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: LuvegiColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajeError.desdeExcepcion(e)),
          backgroundColor: LuvegiColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sincronizandoCesados = false);
    }
  }

  Future<void> _guardarAccesosUsuario({
    required int usuarioId,
    required int rolId,
    required List<int> areasIds,
    String? nombre,
    String? usuario,
    String? dni,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/admin_usuarios.php?action=guardar');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': usuarioId,
          'rol_id': rolId,
          'areas_ids': areasIds,
          if (nombre != null && nombre.trim().isNotEmpty)
            'nombre': nombre.trim(),
          if (usuario != null && usuario.trim().isNotEmpty)
            'usuario': usuario.trim(),
          if (dni != null) 'dni': dni.trim(),
        }),
      );

      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Accesos actualizados.')));
        _registrar(
          'EDITAR_USUARIO',
          'usuario',
          'usuario_id=$usuarioId rol_id=$rolId areas=${areasIds.join(',')}',
        );
        _cargarDatos();
      } else {
        throw Exception(MensajeError.desdeCodigo(body['mensaje']?.toString()));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MensajeError.desdeExcepcion(e)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _crearUsuario(
    String nombre,
    String correo,
    String password,
    int rolId, {
    String? dni,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/admin_usuarios.php?action=crear_usuario',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'nombre': nombre,
          'correo': correo,
          'password': password,
          'rol_id': rolId,
          if (dni != null && dni.trim().isNotEmpty) 'dni': dni.trim(),
        }),
      );

      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['ok'] == true) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario creado con éxito.')),
          );
        _registrar('CREAR_USUARIO', 'usuario', '$nombre ($correo)');
        _cargarDatos();
      } else {
        throw Exception(MensajeError.desdeCodigo(body['mensaje']?.toString()));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajeError.desdeExcepcion(e)), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _cambiarPassword(int usuarioId, String nuevaPassword) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/admin_usuarios.php?action=cambiar_password',
      );
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'id': usuarioId, 'password': nuevaPassword}),
      );

      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['ok'] == true) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contraseña actualizada.')),
          );
        _registrar('CAMBIAR_PASSWORD', 'usuario', 'usuario_id=$usuarioId');
      } else {
        throw Exception(MensajeError.desdeCodigo(body['mensaje']?.toString()));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajeError.desdeExcepcion(e)), backgroundColor: Colors.red),
        );
    }
  }

  // --- MODALES ---
  void _abrirModalEditar(Map<String, dynamic> usuario) {
    _debounceDni?.cancel();
    setState(() {
      _dniEncontrado = null;
      _buscandoDni = false;
    });
    int fallbackRol = _rolesDisponibles.isNotEmpty
        ? int.parse(_rolesDisponibles.first['id'].toString())
        : 3;
    int rolSeleccionado =
        int.tryParse(usuario['rol_id'].toString()) ?? fallbackRol;

    bool rolExiste = _rolesDisponibles.any(
      (r) => r['id'].toString() == rolSeleccionado.toString(),
    );
    if (!rolExiste && _rolesDisponibles.isNotEmpty) {
      rolSeleccionado = fallbackRol;
    }

    final TextEditingController nombreCtrl = TextEditingController(
      text: usuario['nombre']?.toString() ?? '',
    );
    final TextEditingController usuarioCtrl = TextEditingController(
      text: usuario['usuario']?.toString() ?? '',
    );
    final TextEditingController dniCtrl = TextEditingController(
      text: usuario['dni']?.toString() ?? '',
    );
    // Si el usuario cruza con Odoo, el nombre lo pone Odoo: se muestra
    // pero no se edita a mano.
    final bool nombreDesdeOdoo = usuario['tiene_odoo'] == true;

    List<int> areasSeleccionadas = [];
    if (usuario['areas_ids'] != null &&
        usuario['areas_ids'].toString().isNotEmpty) {
      areasSeleccionadas = usuario['areas_ids']
          .toString()
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .where((id) => id > 0)
          .toList();
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LuvegiRadius.lg),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editar Usuario',
                    style: LuvegiText.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    usuario['nombre']?.toString() ?? '',
                    style: LuvegiText.caption,
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datos del Usuario',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nombreCtrl,
                        enabled: !nombreDesdeOdoo,
                        decoration: InputDecoration(
                          labelText: nombreDesdeOdoo
                              ? 'Nombre (desde Odoo)'
                              : 'Nombre Completo',
                          hintText: 'Ej. Juan Pérez',
                          helperText: nombreDesdeOdoo
                              ? 'El nombre se toma de Odoo según el DNI. Para corregirlo, borra el DNI.'
                              : null,
                          helperMaxLines: 2,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usuarioCtrl,
                        decoration: InputDecoration(
                          labelText: 'Correo / Usuario',
                          hintText: 'usuario@luvegi.com',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dniCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          _debounceDni?.cancel();
                          final dni = v.replaceAll(RegExp(r'\D'), '');
                          if (dni.length < 8) {
                            setModalState(() {
                              _dniEncontrado = null;
                              _buscandoDni = false;
                            });
                            return;
                          }
                          setModalState(() => _buscandoDni = true);
                          _debounceDni = Timer(
                            const Duration(milliseconds: 450),
                            () => _autocompletarPorDni(
                              dni,
                              nombreCtrl,
                              (data) => setModalState(() {
                                _dniEncontrado = data;
                                _buscandoDni = false;
                              }),
                            ),
                          );
                        },
                        decoration: InputDecoration(
                          labelText: 'DNI',
                          hintText: 'Opcional. Empareja con la foto de Odoo',
                          helperText: nombreDesdeOdoo
                              ? 'El nombre se toma de Odoo según el DNI. Para corregirlo, borra el DNI.'
                              : 'Con el DNI la foto del personal se empareja de forma exacta.',
                          helperMaxLines: 2,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                      ),
                      if (_buscandoDni) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      if (_dniEncontrado != null) ...[
                        const SizedBox(height: 12),
                        _vistaPreviaOdoo(_dniEncontrado!),
                      ],
                      const Divider(height: 28),
                      const Text(
                        '1. Rol del Sistema',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: rolSeleccionado,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: _rolesDisponibles.map((rol) {
                          return DropdownMenuItem<int>(
                            value: int.parse(rol['id'].toString()),
                            child: Text(rol['nombre'].toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null)
                            setModalState(() => rolSeleccionado = val);
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '2. Área(s) Laboral(es)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Selecciona las áreas para la visibilidad de REDIR.',
                        style: LuvegiText.caption.copyWith(fontSize: 12),
                      ),
                      const Divider(height: 20),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          border: Border.all(color: LuvegiColors.border),
                          borderRadius: BorderRadius.circular(LuvegiRadius.md),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (
                                var i = 0;
                                i < _areasDisponibles.length;
                                i++
                              ) ...[
                                if (i > 0) const Divider(height: 1),
                                Builder(
                                  builder: (_) {
                                    final area = _areasDisponibles[i];
                                    final int areaId = int.parse(
                                      area['id'].toString(),
                                    );
                                    final bool check = areasSeleccionadas
                                        .contains(areaId);
                                    return CheckboxListTile(
                                      dense: true,
                                      activeColor: LuvegiColors.secondary,
                                      title: Text(
                                        area['nombre'].toString(),
                                        style: const TextStyle(fontSize: 13.5),
                                      ),
                                      value: check,
                                      onChanged: (bool? selected) {
                                        setModalState(() {
                                          if (selected == true) {
                                            areasSeleccionadas.add(areaId);
                                          } else {
                                            areasSeleccionadas.remove(areaId);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _guardarAccesosUsuario(
                      usuarioId: int.parse(usuario['id'].toString()),
                      rolId: rolSeleccionado,
                      areasIds: areasSeleccionadas,
                      nombre: nombreCtrl.text,
                      usuario: usuarioCtrl.text,
                      dni: dniCtrl.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LuvegiColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirModalCrearUsuario() {
    _debounceDni?.cancel();
    setState(() {
      _dniEncontrado = null;
      _buscandoDni = false;
    });
    final TextEditingController nombreCtrl = TextEditingController();
    final TextEditingController correoCtrl = TextEditingController();
    final TextEditingController dniCtrl = TextEditingController();
    final TextEditingController passCtrl = TextEditingController();

    int rolSeleccionado = _rolesDisponibles.isNotEmpty
        ? int.parse(_rolesDisponibles.first['id'].toString())
        : 3;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LuvegiRadius.lg),
              ),
              title: Text(
                'Crear Nuevo Usuario',
                style: LuvegiText.title.copyWith(fontSize: 18),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DNI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: dniCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          _debounceDni?.cancel();
                          final dni = v.replaceAll(RegExp(r'\D'), '');
                          if (dni.length < 8) {
                            setModalState(() {
                              _dniEncontrado = null;
                              _buscandoDni = false;
                            });
                            return;
                          }
                          setModalState(() => _buscandoDni = true);
                          _debounceDni = Timer(
                            const Duration(milliseconds: 450),
                            () => _autocompletarPorDni(
                              dni,
                              nombreCtrl,
                              (data) => setModalState(() {
                                _dniEncontrado = data;
                                _buscandoDni = false;
                              }),
                            ),
                          );
                        },
                        decoration: InputDecoration(
                          hintText: 'Ej. 70558609',
                          helperText:
                              'Con el DNI se toman el nombre y la foto desde Odoo.',
                          helperMaxLines: 2,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                      ),
                      if (_buscandoDni) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      if (_dniEncontrado != null) ...[
                        const SizedBox(height: 12),
                        _vistaPreviaOdoo(_dniEncontrado!),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Correo Electrónico',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: correoCtrl,
                        decoration: InputDecoration(
                          hintText: 'usuario@luvegi.com',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nombre (solo si no hay DNI)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nombreCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ej. Juan Pérez',
                          helperText:
                              'Si escribes un DNI, el nombre se completa solo.',
                          helperMaxLines: 2,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Contraseña Inicial',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Rol del Sistema',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: rolSeleccionado,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                        items: _rolesDisponibles.map((rol) {
                          return DropdownMenuItem<int>(
                            value: int.parse(rol['id'].toString()),
                            child: Text(rol['nombre'].toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null)
                            setModalState(() => rolSeleccionado = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _crearUsuario(
                      nombreCtrl.text,
                      correoCtrl.text,
                      passCtrl.text,
                      rolSeleccionado,
                      dni: dniCtrl.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LuvegiColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Crear Usuario'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirModalPassword(Map<String, dynamic> usuario) {
    final TextEditingController passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cambiar Contraseña',
              style: LuvegiText.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(usuario['nombre'] ?? '', style: LuvegiText.caption),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nueva Contraseña',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Ingresa la nueva contraseña',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LuvegiRadius.md),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _cambiarPassword(
                int.parse(usuario['id'].toString()),
                passCtrl.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: LuvegiColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalEstado(Map<String, dynamic> usuario) {
    final bool esActivo = usuario['activo'].toString() == '1';
    final String nombre = usuario['nombre']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esActivo ? 'Dar de Baja' : 'Activar Usuario',
              style: LuvegiText.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(nombre, style: LuvegiText.caption),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            esActivo
                ? 'El usuario no podrá iniciar sesión ni recibir notificaciones. '
                    '¿Deseas continuar?'
                : 'El usuario volverá a poder iniciar sesión y recibir notificaciones. '
                    '¿Deseas continuar?',
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _toggleUsuario(int.parse(usuario['id'].toString()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: esActivo
                  ? Colors.red.shade600
                  : LuvegiColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: Text(esActivo ? 'Dar de Baja' : 'Activar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUsuario(int usuarioId) async {
    try {
      final url = Uri.parse('$_baseUrl/admin_usuarios.php?action=toggle');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'id': usuarioId}),
      );

      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['ok'] == true) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['message']?.toString() ?? 'Estado actualizado.'),
            ),
          );
        _registrar(
          body['activo'] == 1 ? 'ACTIVAR_USUARIO' : 'DAR_BAJA_USUARIO',
          'usuario',
          'usuario_id=$usuarioId',
        );
        _cargarDatos();
      } else {
        throw Exception(MensajeError.desdeCodigo(body['mensaje']?.toString()));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MensajeError.desdeExcepcion(e)), backgroundColor: Colors.red),
        );
    }
  }

  List<dynamic> get _usuariosFiltrados {
    return _usuarios.where((u) {
      final bool esActivo = u['activo'].toString() == '1';
      if (_filtroEstado == 'ACTIVOS' && !esActivo) return false;
      if (_filtroEstado == 'BAJAS' && esActivo) return false;

      if (_busqueda.isNotEmpty) {
        final term = _busqueda.toLowerCase();
        final nombre = (u['nombre'] ?? '').toString().toLowerCase();
        final correo = (u['usuario'] ?? '').toString().toLowerCase();
        return nombre.contains(term) || correo.contains(term);
      }
      return true;
    }).toList();
  }

  /// Avatar del usuario: foto de Odoo (hr.employee) cuando existe,
  /// iniciales si no, y el icono de siempre para los usuarios inactivos.
  Widget _avatarUsuario(Map<String, dynamic> user) {
    final activo = user['activo'].toString() == '1';
    final fotoUrl = (user['foto_url'] ?? '').toString();
    final nombre = (user['nombre'] ?? '').toString();

    if (!activo) {
      return Icon(
        Icons.person_outline_rounded,
        color: Colors.red.shade800,
      );
    }

    if (fotoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          fotoUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          headers: {
            'Authorization': 'Bearer ${widget.token}',
          },
          errorBuilder: (_, _, _) => _inicialesUsuario(nombre),
        ),
      );
    }

    return _inicialesUsuario(nombre);
  }

  /// Vista previa de la persona encontrada en Odoo por DNI.
  Widget _vistaPreviaOdoo(Map<String, dynamic> persona) {
    final nombre = (persona['nombre'] ?? '').toString();
    final area = (persona['area'] ?? '').toString();
    final puesto = (persona['puesto'] ?? '').toString();
    final fotoUrl = (persona['foto_url'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LuvegiColors.menuHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.menuSelected),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: LuvegiColors.secondary.withValues(alpha: 0.12),
            child: fotoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      fotoUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      headers: {
                        'Authorization': 'Bearer ${widget.token}',
                      },
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_outline,
                        color: LuvegiColors.secondary,
                      ),
                    ),
                  )
                : const Icon(Icons.person_outline, color: LuvegiColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                if (area.isNotEmpty || puesto.isNotEmpty)
                  Text(
                    [area, puesto].where((t) => t.isNotEmpty).join(' · '),
                    style: LuvegiText.caption,
                  ),
                const SizedBox(height: 2),
                Text(
                  'Encontrado en Odoo. Se usará este nombre.',
                  style: LuvegiText.caption.copyWith(
                    color: LuvegiColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: LuvegiColors.success),
        ],
      ),
    );
  }

  Widget _inicialesUsuario(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) {
      return Icon(
        Icons.person_outline_rounded,
        color: Colors.green.shade800,
      );
    }
    String dos(String s) => s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    final texto = partes.length >= 2
        ? dos(partes[0][0] + partes[partes.length - 1][0])
        : dos(partes.first.substring(0, 1));
    return Text(
      texto,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Colors.green.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final filtrados = _usuariosFiltrados;

    return ColoredBox(
      color: LuvegiColors.background,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? LuvegiSpacing.md : LuvegiSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: LuvegiSpacing.lg,
              runSpacing: LuvegiSpacing.md,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuarios',
                      style: LuvegiText.title.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gestión de roles y áreas.',
                      style: LuvegiText.caption,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: isMobile ? 160 : 240,
                      child: TextField(
                        controller: _busquedaController,
                        onChanged: (v) => setState(() => _busqueda = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Buscar usuario...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: _cargarDatos,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Actualizar',
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: _sincronizandoCesados
                          ? null
                          : _sincronizarCesados,
                      icon: _sincronizandoCesados
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_off_outlined, size: 18),
                      label: Text(
                        _sincronizandoCesados
                            ? 'Sincronizando...'
                            : 'Cesados (Odoo)',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LuvegiColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: LuvegiColors.secondary,
                        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Crear Usuario',
                        onPressed: _abrirModalCrearUsuario,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: LuvegiSpacing.lg),

            Row(
              children: [
                _buildFilterChip('Todos', 'TODOS', _usuarios.length),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Activos',
                  'ACTIVOS',
                  _usuarios.where((u) => u['activo'].toString() == '1').length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Bajas',
                  'BAJAS',
                  _usuarios.where((u) => u['activo'].toString() == '0').length,
                ),
              ],
            ),
            const SizedBox(height: LuvegiSpacing.lg),

            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : filtrados.isEmpty
                  ? const Center(child: Text('No se encontraron usuarios.'))
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final user = filtrados[index];
                        final String areasTexto = (user['areas_nombres'] ?? '')
                            .toString();

                        return Container(
                          padding: const EdgeInsets.all(LuvegiSpacing.lg),
                          decoration: BoxDecoration(
                            color: LuvegiColors.surface,
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.md,
                            ),
                            border: Border.all(color: LuvegiColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    user['activo'].toString() == '1'
                                    ? const Color(0xFFE9F8EF)
                                    : const Color(0xFFFFEAEA),
                                child: _avatarUsuario(user),
                              ),
                              const SizedBox(width: LuvegiSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['nombre'] ?? '',
                                      style: LuvegiText.title.copyWith(
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user['usuario'] ?? '',
                                      style: LuvegiText.caption,
                                    ),
                                    if ((user['dni'] ?? '').toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'DNI: ${user['dni']}',
                                        style: LuvegiText.caption.copyWith(
                                          color: LuvegiColors.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (areasTexto.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.apartment_rounded,
                                            size: 14,
                                            color: LuvegiColors.secondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Áreas: $areasTexto',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: LuvegiColors.secondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: LuvegiColors.surfaceHover,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: LuvegiColors.border,
                                  ),
                                ),
                                child: Text(
                                  user['rol_nombre'] ?? 'USUARIO',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (value) {
                                  Future<void>.delayed(
                                    const Duration(milliseconds: 120),
                                    () {
                                      if (value == 'editar')
                                        _abrirModalEditar(
                                          Map<String, dynamic>.from(user),
                                        );
                                      else if (value == 'password')
                                        _abrirModalPassword(
                                          Map<String, dynamic>.from(user),
                                        );
                                      else if (value == 'estado')
                                        _abrirModalEstado(
                                          Map<String, dynamic>.from(user),
                                        );
                                    },
                                  );
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'editar',
                                    child: Text('Editar Usuario'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'password',
                                    child: Text('Cambiar Contraseña'),
                                  ),
                                  if (user['activo'].toString() == '1')
                                    const PopupMenuItem(
                                      value: 'estado',
                                      child: Text('Dar de Baja'),
                                    )
                                  else
                                    const PopupMenuItem(
                                      value: 'estado',
                                      child: Text('Activar'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final bool active = _filtroEstado == value;
    return ChoiceChip(
      label: Text('$label $count'),
      selected: active,
      selectedColor: LuvegiColors.secondary,
      labelStyle: TextStyle(
        color: active ? Colors.white : LuvegiColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _filtroEstado = value),
    );
  }

  // Registra actividad en la bitácora sin bloquear la UI.
  void _registrar(String accion, String entidad, String detalle) {
    try {
      _auditoria
          .registrarActividad(
            widget.token,
            accion: accion,
            entidad: entidad,
            detalle: detalle,
          )
          .catchError((_) {});
    } catch (_) {}
  }
}
