import 'package:flutter/material.dart';
import 'dart:async';
import '../services/admin_usuarios_service.dart';

// =================================================
// 📦 MODELO DE DATOS
// =================================================
class Usuario {
  final int id;
  final String email;
  final String nombre;
  final String rol;
  final bool activo;

  Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.activo,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] ?? 0,
      email: map['usuario'] ?? '',
      nombre: map['nombre'] ?? '',
      rol: map['rol'] ?? 'USUARIO',
      activo: map['activo'] == 1,
    );
  }
}

// ─── Enum de filtro de estado ─────────────────────────────────────────────────
enum FiltroEstado { todos, activos, bajas }

class AdminUsuariosPage extends StatefulWidget {
  final String token;
  const AdminUsuariosPage({super.key, required this.token});

  @override
  State<AdminUsuariosPage> createState() => _AdminUsuariosPageState();
}

class _AdminUsuariosPageState extends State<AdminUsuariosPage> {
  final _service = AdminUsuariosService();
  List<Usuario> _usuarios = [];
  bool _loading = true;
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  final FocusNode _searchFocus = FocusNode();

  // ─── NUEVO: filtro de estado activo ──────────────────────────────────────
  FiltroEstado _filtroEstado = FiltroEstado.todos;

  final _roles = const ['ADMIN', 'ALMACEN', 'USUARIO', 'RRHH'];

  // 🎨 Paleta
  final Color primaryDark = const Color(0xFF0F172A);
  final Color accentBlue = const Color(0xFF2563EB);
  final Color textSecondary = const Color(0xFF475569);
  final Color bgColor = const Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _cargar();
    _searchCtrl.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(
          const Duration(milliseconds: 300), () => setState(() {}));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final data = await _service.listar(widget.token);
      setState(
          () => _usuarios = data.map((m) => Usuario.fromMap(m)).toList());
    } catch (_) {
      _snack('Error al conectar con el servidor', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor:
            error ? const Color(0xFFDC2626) : primaryDark,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: accentBlue, size: 22),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide:
              const BorderSide(color: Color(0xFFCBD5E1), width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: accentBlue, width: 2)),
    );
  }

  // =================================================
  // 🔍 BÚSQUEDA + FILTRO COMBINADOS
  // =================================================
  List<Usuario> _aplicarFiltros() {
    final query = _searchCtrl.text.trim().toLowerCase();

    return _usuarios.where((u) {
      // Filtro de estado
      final pasaEstado = switch (_filtroEstado) {
        FiltroEstado.todos => true,
        FiltroEstado.activos => u.activo,
        FiltroEstado.bajas => !u.activo,
      };

      // Filtro de búsqueda
      final pasaBusqueda = query.isEmpty ||
          u.nombre.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.rol.toLowerCase().contains(query);

      return pasaEstado && pasaBusqueda;
    }).toList();
  }

  // Contadores para los badges de los chips
  int get _totalActivos => _usuarios.where((u) => u.activo).length;
  int get _totalBajas => _usuarios.where((u) => !u.activo).length;

  // =================================================
  // 🛠️ ACCIONES
  // =================================================
  void _crearUsuario() {
    final emailCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String rol = 'USUARIO';
    bool enviando = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Text('Nuevo Usuario',
              style: TextStyle(
                  color: primaryDark, fontWeight: FontWeight.w900)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: _inputStyle(
                        'Email / Usuario', Icons.alternate_email_rounded),
                    style: TextStyle(
                        color: primaryDark, fontWeight: FontWeight.w500),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: _inputStyle('Nombre Completo',
                        Icons.face_retouching_natural_rounded),
                    style: TextStyle(
                        color: primaryDark, fontWeight: FontWeight.w500),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: _inputStyle(
                        'Contraseña', Icons.lock_person_outlined),
                    style: TextStyle(
                        color: primaryDark, fontWeight: FontWeight.w500),
                    validator: (v) =>
                        v!.length < 4 ? 'Muy corta' : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: rol,
                    dropdownColor: Colors.white,
                    style: TextStyle(
                        color: primaryDark, fontWeight: FontWeight.bold),
                    decoration: _inputStyle(
                        'Asignar Rol', Icons.manage_accounts_outlined),
                    items: _roles
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => rol = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(
                      color: textSecondary,
                      fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: enviando
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => enviando = true);
                        final ok = await _service.crear(
                            widget.token,
                            emailCtrl.text.trim(),
                            nombreCtrl.text.trim(),
                            passCtrl.text,
                            rol);
                        if (ok) {
                          Navigator.pop(ctx);
                          _snack('✅ Usuario registrado');
                          _cargar();
                        } else {
                          setDialogState(() => enviando = false);
                          _snack('❌ Error al registrar', error: true);
                        }
                      }
                    },
              child: enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _cambiarRol(Usuario u) {
    String nuevoRol = u.rol;
    bool subiendo = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Text('Actualizar Rol',
              style: TextStyle(
                  color: primaryDark, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cambiando permisos para:',
                  style:
                      TextStyle(color: textSecondary, fontSize: 13)),
              Text(u.nombre,
                  style: TextStyle(
                      color: primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: nuevoRol,
                dropdownColor: Colors.white,
                style: TextStyle(
                    color: primaryDark, fontWeight: FontWeight.bold),
                decoration: _inputStyle('Nivel de Acceso',
                    Icons.admin_panel_settings_rounded),
                items: _roles
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => nuevoRol = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cerrar',
                    style: TextStyle(color: textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white),
              onPressed: subiendo
                  ? null
                  : () async {
                      setDialogState(() => subiendo = true);
                      final ok = await _service.cambiarRol(
                          widget.token, u.id, nuevoRol);
                      if (ok) {
                        Navigator.pop(ctx);
                        _snack('✅ Rol actualizado a $nuevoRol');
                        _cargar();
                      } else {
                        setDialogState(() => subiendo = false);
                        _snack('❌ Error al cambiar rol', error: true);
                      }
                    },
              child: subiendo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _resetPassword(Usuario u) {
    final passCtrl = TextEditingController();
    bool subiendo = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const Text('Nueva Contraseña',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: passCtrl,
            obscureText: true,
            style: TextStyle(color: primaryDark),
            decoration:
                _inputStyle('Clave nueva', Icons.key_outlined),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar',
                    style: TextStyle(color: textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade900,
                  foregroundColor: Colors.white),
              onPressed: subiendo
                  ? null
                  : () async {
                      if (passCtrl.text.isEmpty) return;
                      setDialogState(() => subiendo = true);
                      final ok = await _service.resetPassword(
                          widget.token, u.id, passCtrl.text);
                      if (ok) {
                        Navigator.pop(ctx);
                        _snack('🔑 Contraseña actualizada');
                      } else {
                        setDialogState(() => subiendo = false);
                        _snack('Error al cambiar contraseña',
                            error: true);
                      }
                    },
              child: subiendo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus(Usuario u) async {
    final ok = await _service.toggle(widget.token, u.id);
    if (ok) {
      _snack('Estado de cuenta actualizado');
      _cargar();
    }
  }

  // =================================================
  // 📱 BUILD PRINCIPAL
  // =================================================
  @override
  Widget build(BuildContext context) {
    final display = _aplicarFiltros();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: AnimatedCrossFade(
          firstChild: Text('Usuarios',
              style: TextStyle(
                  color: primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 26)),
          secondChild: SizedBox(
            height: 40,
            child: TextField(
              focusNode: _searchFocus,
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.search, color: textSecondary),
                hintText: 'Buscar por nombre, email o rol',
                hintStyle: TextStyle(color: textSecondary),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                          _searchFocus.requestFocus();
                        },
                      )
                    : null,
              ),
              style: TextStyle(
                  color: primaryDark, fontWeight: FontWeight.w700),
            ),
          ),
          crossFadeState: _searching
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
        actions: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 12),
              child: Chip(
                label: Text('${display.length}'),
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
          IconButton(
            icon: Icon(
                _searching ? Icons.close : Icons.search,
                color: primaryDark),
            onPressed: () => setState(() {
              if (_searching) {
                _searchCtrl.clear();
                _searchFocus.unfocus();
              } else {
                Future.delayed(const Duration(milliseconds: 100),
                    () => _searchFocus.requestFocus());
              }
              _searching = !_searching;
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: accentBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _crearUsuario,
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accentBlue))
          : Column(
              children: [
                // ─── NUEVO: barra de filtros de estado ──────────────────
                _buildFiltroBar(display.length),
                // ─── Lista de usuarios ───────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargar,
                    child: display.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: display.length,
                            itemBuilder: (context, index) =>
                                _UserCardModern(
                              user: display[index],
                              onEditRol: () =>
                                  _cambiarRol(display[index]),
                              onToggle: () =>
                                  _toggleStatus(display[index]),
                              onResetPass: () =>
                                  _resetPassword(display[index]),
                              primaryDark: primaryDark,
                              textSecondary: textSecondary,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Barra de chips de filtro ─────────────────────────────────────────────
  Widget _buildFiltroBar(int resultados) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chips de filtro
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filtroChip(
                  label: 'Todos',
                  count: _usuarios.length,
                  filtro: FiltroEstado.todos,
                  colorActivo: primaryDark,
                  icono: Icons.people_outline_rounded,
                ),
                const SizedBox(width: 8),
                _filtroChip(
                  label: 'Activos',
                  count: _totalActivos,
                  filtro: FiltroEstado.activos,
                  colorActivo: const Color(0xFF059669),
                  icono: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 8),
                _filtroChip(
                  label: 'Bajas',
                  count: _totalBajas,
                  filtro: FiltroEstado.bajas,
                  colorActivo: const Color(0xFFDC2626),
                  icono: Icons.person_off_outlined,
                ),
              ],
            ),
          ),
          // Subtexto de resultados
          if (_filtroEstado != FiltroEstado.todos ||
              _searchCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$resultados resultado${resultados != 1 ? 's' : ''} encontrado${resultados != 1 ? 's' : ''}',
                style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filtroChip({
    required String label,
    required int count,
    required FiltroEstado filtro,
    required Color colorActivo,
    required IconData icono,
  }) {
    final bool seleccionado = _filtroEstado == filtro;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = filtro),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? colorActivo : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: seleccionado
                ? colorActivo
                : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 15,
              color: seleccionado ? Colors.white : colorActivo,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: seleccionado ? Colors.white : colorActivo,
              ),
            ),
            const SizedBox(width: 6),
            // Badge con contador
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: seleccionado
                    ? Colors.white.withOpacity(0.25)
                    : colorActivo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: seleccionado ? Colors.white : colorActivo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Estado vacío ─────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final esFiltroBajas = _filtroEstado == FiltroEstado.bajas;
    final esFiltroActivos = _filtroEstado == FiltroEstado.activos;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            esFiltroActivos
                ? Icons.check_circle_outline_rounded
                : esFiltroBajas
                    ? Icons.person_off_outlined
                    : Icons.search_off_rounded,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            esFiltroActivos
                ? 'Sin usuarios activos'
                : esFiltroBajas
                    ? 'Sin usuarios de baja'
                    : 'Sin resultados',
            style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _searchCtrl.text.isNotEmpty
                ? 'Prueba con otro término de búsqueda'
                : 'Cambia el filtro para ver más usuarios',
            style: TextStyle(
                color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// =================================================
// ✨ TARJETA DE USUARIO
// =================================================
class _UserCardModern extends StatelessWidget {
  final Usuario user;
  final VoidCallback onEditRol;
  final VoidCallback onToggle;
  final VoidCallback onResetPass;
  final Color primaryDark;
  final Color textSecondary;

  const _UserCardModern({
    required this.user,
    required this.onEditRol,
    required this.onToggle,
    required this.onResetPass,
    required this.primaryDark,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        user.activo ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primaryDark.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: user.activo
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2),
                    child: Icon(
                      user.activo
                          ? Icons.verified_user
                          : Icons.gpp_bad,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  title: Text(user.nombre,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: primaryDark,
                          fontSize: 16)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(user.email,
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Badge de rol
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(user.rol,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: primaryDark)),
                          ),
                          const SizedBox(width: 8),
                          // Badge de estado
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.activo
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.activo ? 'ACTIVO' : 'BAJA',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: statusColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10)),
                    child: IconButton(
                      icon: Icon(Icons.more_vert_rounded,
                          color: primaryDark),
                      onPressed: () => _showOptions(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      elevation: 20,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 10),
            _optionTile(Icons.admin_panel_settings_outlined,
                'Cambiar Rol', onEditRol, ctx),
            _optionTile(Icons.lock_reset_rounded,
                'Cambiar Contraseña', onResetPass, ctx),
            _optionTile(
              user.activo
                  ? Icons.person_off_outlined
                  : Icons.person_add_alt_1_outlined,
              user.activo ? 'Desactivar Cuenta' : 'Activar Cuenta',
              onToggle,
              ctx,
              color: user.activo
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String title, VoidCallback onTap,
      BuildContext ctx,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? primaryDark),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color ?? primaryDark)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }
}