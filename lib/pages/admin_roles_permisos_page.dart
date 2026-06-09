import 'package:flutter/material.dart';
import '../services/admin_roles_permisos_service.dart';
import '../services/auth_service.dart';
class AdminRolesPermisosPage extends StatefulWidget {
  final String token;
  const AdminRolesPermisosPage({super.key, required this.token});

  @override
  State<AdminRolesPermisosPage> createState() => _AdminRolesPermisosPageState();
}

class _AdminRolesPermisosPageState extends State<AdminRolesPermisosPage> {
  final _service = AdminRolesPermisosService();

  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _permisos = [];
  int? _usuarioId;
  int? _usuarioBaseId;
  final Map<int, bool> _checks = {};
  Map<int, bool> _checksGuardados = {}; // snapshot del último guardado/carga
  bool _loading = true;
  bool _saving = false;
  bool _savedOk = false; // para animar el botón de guardado

  // ─── Paleta "Facherito White" ─────────────────────────────────────────────
  final Color _primaryBlue = const Color(0xFF003366);
  final Color _bgPureWhite = Colors.white;
  final Color _inputGray   = const Color(0xFFFBFBFB);
  final Color _textDeep    = const Color(0xFF0F172A);
  final Color _textLight   = const Color(0xFF64748B);

  // ─── Guard: cambios pendientes ────────────────────────────────────────────
  bool get _hayPendientes =>
      _checks.entries.any((e) => _checksGuardados[e.key] != e.value);

  void _snapshotGuardado() => _checksGuardados = Map.from(_checks);

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _cargarInicial();
  }

  Future<void> _cargarInicial() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final uData = await _service.usuarios(widget.token);
      final pData = await _service.permisos(widget.token);

      setState(() {
        _usuarios = uData;
        _permisos = pData;
        for (var p in _permisos) { _checks[p['id']] = false; }
        if (_usuarios.isNotEmpty) _usuarioId = _usuarios.first['id'];
      });

      if (_usuarioId != null) {
        await _cargarPermisosUsuario(_usuarioId!, esCopia: false);
      }
    } catch (e) {
      debugPrint('Error carga inicial: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cargarPermisosUsuario(int id, {required bool esCopia}) async {
    try {
      final activos = await _service.permisosPorUsuario(widget.token, id);
      setState(() {
        for (var key in _checks.keys) { _checks[key] = activos.contains(key); }
        // Solo reseteamos el snapshot cuando es una carga real (no una copia)
        if (!esCopia) _snapshotGuardado();
      });
    } catch (e) {
      debugPrint('Error carga permisos: $e');
    }
  }

  // ─── Guardar con animación de éxito ──────────────────────────────────────
  Future<void> _guardar() async {
    if (_usuarioId == null) return;
    
    // Obtenemos la lista de IDs seleccionados
    final seleccionados =
        _checks.entries.where((e) => e.value).map((e) => e.key).toList();

    // DEBUG: Revisa esto en tu terminal de VS Code / Android Studio
    debugPrint('*** ENVIANDO A BACKEND ***');
    debugPrint('Usuario ID: $_usuarioId');
    debugPrint('Permisos IDs: $seleccionados');

    setState(() { _saving = true; _savedOk = false; });

    try {
      final ok = await _service.guardar(widget.token, _usuarioId!, seleccionados);
      
     if (ok) {
    debugPrint('Servidor respondió: OK');
   _snapshotGuardado();

    // Refresco instantáneo si me estoy editando a mí mismo
   final session = await AuthService().getSession();
    if (session != null && session['usuarioId'].toString() == _usuarioId.toString()) {
    await AuthService().refrescarMisPermisos();
   }

  setState(() => _savedOk = true);
        // El botón muestra "¡LISTO!" durante 2 segundos y luego vuelve al normal
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _savedOk = false);
      } else {
        debugPrint('Servidor respondió: ERROR (ok=false)');
        _snack('❌ Error al guardar en BD', isError: true);
      }
    } catch (e) {
      debugPrint('Error de red/excepción: $e');
      _snack('❌ Error de conexión', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Cambio de usuario con guard de cambios pendientes ────────────────────
  Future<void> _cambiarUsuario(int nuevoId) async {
    if (_hayPendientes) {
      final descarta = await _showConfirmDialog(
        title: '¿Descartar cambios?',
        body: 'Tienes permisos modificados sin guardar.\nSi continúas, se perderán.',
        confirmLabel: 'DESCARTAR',
        confirmColor: Colors.redAccent,
      );
      if (descarta != true) return;
    }
    setState(() {
      _usuarioId = nuevoId;
      _usuarioBaseId = null; // limpiar clon al cambiar usuario
    });
    await _cargarPermisosUsuario(nuevoId, esCopia: false);
  }

  // ─── Clonar con diálogo de confirmación ──────────────────────────────────
  Future<void> _clonarDesde(int baseId) async {
    final usuario = _usuarios.firstWhere(
      (u) => u['id'] == baseId,
      orElse: () => {'usuario': 'desconocido'},
    );

    final confirma = await _showConfirmDialog(
      title: 'Clonar permisos',
      body: 'Se reemplazarán los permisos actuales con los de '
            '"${usuario['usuario'].toString().toUpperCase()}".\n\n'
            'Los cambios no se guardan hasta que pulses GUARDAR.',
      confirmLabel: 'CLONAR',
      confirmColor: Colors.amber.shade800,
    );

    if (confirma != true) {
      setState(() => _usuarioBaseId = null);
      return;
    }
    setState(() => _usuarioBaseId = baseId);
    await _cargarPermisosUsuario(baseId, esCopia: true);
  }

  // ─── Selección masiva por grupo ───────────────────────────────────────────
  void _toggleGrupo(List<Map<String, dynamic>> permisos, bool value) {
    setState(() {
      for (var p in permisos) { _checks[p['id']] = value; }
    });
  }

  // ─── Diálogo de confirmación genérico ────────────────────────────────────
  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: TextStyle(
                color: _primaryBlue, fontWeight: FontWeight.w900)),
        content: Text(body,
            style: TextStyle(color: _textLight, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: isError ? Colors.redAccent : _primaryBlue,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ─── Build principal ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totalActivos = _checks.values.where((v) => v).length;
    final total = _checks.length;

    return Scaffold(
      backgroundColor: _bgPureWhite,
      appBar: AppBar(
        backgroundColor: _bgPureWhite,
        elevation: 0,
        centerTitle: true,
        title: Text('GESTIÓN DE ACCESOS',
            style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1)),
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      body: _loading
          ? _buildSkeleton()
          : Column(
              children: [
                // 1. Banner de cambios sin guardar
                if (_hayPendientes) _buildPendingBanner(),
                // 2. Header con dropdowns y botón
                _buildControlHeader(),
                // 3. Barra resumen de permisos totales
                _buildResumenBar(totalActivos, total),
                // 4. Lista de grupos
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    children: _getGrupos()
                        .entries
                        .map((g) => _buildGroupCard(g))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Skeleton de carga ────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBox(height: 50),
          const SizedBox(height: 10),
          _skeletonBox(height: 42),
          const SizedBox(height: 20),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: _skeletonBox(height: 110),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // ─── Banner de cambios pendientes ─────────────────────────────────────────
  Widget _buildPendingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tienes cambios sin guardar',
              style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _guardar,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12),
            ),
            child: const Text('GUARDAR AHORA'),
          ),
        ],
      ),
    );
  }

  // ─── Barra resumen global ─────────────────────────────────────────────────
  Widget _buildResumenBar(int activos, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.04),
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 14, color: _primaryBlue),
          const SizedBox(width: 6),
          Text(
            '$activos de $total permisos activos',
            style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 12),
          ),
          const Spacer(),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: total > 0 ? activos / total : 0,
              backgroundColor: Colors.grey.shade200,
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header de control ────────────────────────────────────────────────────
  Widget _buildControlHeader() {
    final bool existeId = _usuarios.any((u) => u['id'] == _usuarioId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgPureWhite,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONFIGURACIÓN DE USUARIO',
              style: TextStyle(
                  color: _textLight,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              // Campo buscador de usuario (abre modal al tocar)
              Expanded(child: _buildUserSearchField(existeId)),
              const SizedBox(width: 12),
              // Botón GUARDAR con estados: normal / cargando / éxito / deshabilitado
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_saving || !_hayPendientes) ? null : _guardar,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _savedOk
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          size: 18),
                  label: Text(_savedOk ? '¡LISTO!' : 'GUARDAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _savedOk ? Colors.green.shade600 : _primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildCloneBar(),
        ],
      ),
    );
  }

  // ─── Barra clonar ─────────────────────────────────────────────────────────
  Widget _buildCloneBar() {
    final bool existeBase = _usuarios.any((u) => u['id'] == _usuarioBaseId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.copy_all_outlined, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Text('CLONAR:',
              style: TextStyle(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
          const SizedBox(width: 10),
          Expanded(child: _buildCloneSearchField(existeBase)),
        ],
      ),
    );
  }

  // ─── Card de grupo con checkbox masivo y badge ────────────────────────────
  Widget _buildGroupCard(
      MapEntry<String, List<Map<String, dynamic>>> grupo) {
    final permisos     = grupo.value;
    final activosGrupo = permisos.where((p) => _checks[p['id']] == true).length;
    final totalGrupo   = permisos.length;
    final todosActivos = activosGrupo == totalGrupo;
    final algunoActivo = activosGrupo > 0 && !todosActivos;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Theme(
          data:
              Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            iconColor: _primaryBlue,
            title: Row(
              children: [
                // Checkbox de selección masiva con estado tristate
                Semantics(
                  label:
                      'Seleccionar todos los permisos de ${grupo.key}',
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: todosActivos
                          ? true
                          : (algunoActivo ? null : false),
                      tristate: true,
                      activeColor: _primaryBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) =>
                          _toggleGrupo(permisos, !todosActivos),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(grupo.key,
                      style: TextStyle(
                          color: _primaryBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                ),
                // Badge contador por grupo
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$activosGrupo/$totalGrupo',
                    style: TextStyle(
                        color: _primaryBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            children:
                permisos.map((p) => _buildPermissionRow(p)).toList(),
          ),
        ),
      ),
    );
  }

  // ─── Fila de permiso con Semantics ───────────────────────────────────────
  Widget _buildPermissionRow(Map<String, dynamic> p) {
    final bool selected = _checks[p['id']] ?? false;
    return Semantics(
      label:
          '${p['codigo']}: ${p['descripcion']}. Estado: ${selected ? 'activo' : 'inactivo'}',
      child: InkWell(
        onTap: () => setState(() => _checks[p['id']] = !selected),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.grey.shade50))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['codigo'],
                        style: TextStyle(
                            color: _textDeep,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text(p['descripcion'],
                        style:
                            TextStyle(color: _textLight, fontSize: 11)),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: selected,
                  activeColor: _primaryBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: (v) =>
                      setState(() => _checks[p['id']] = v ?? false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Agrupación por módulo ────────────────────────────────────────────────
  Map<String, List<Map<String, dynamic>>> _getGrupos() {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (var p in _permisos) {
      final String mod =
          (p['modulo'] ?? 'OTROS').toString().toUpperCase();
      if (!grupos.containsKey(mod)) grupos[mod] = [];
      grupos[mod]!.add(p);
    }
    return grupos;
  }

  // ─── Campo visual que abre el modal de búsqueda de usuario ───────────────
  Widget _buildUserSearchField(bool existeId) {
    final nombreActual = existeId
        ? _usuarios
            .firstWhere((u) => u['id'] == _usuarioId)['usuario']
            .toString()
            .toUpperCase()
        : 'Seleccionar usuario...';
    return GestureDetector(
      onTap: () => _abrirModalBusqueda(
        titulo: 'Buscar usuario',
        usuarios: _usuarios,
        onSeleccionado: (id) => _cambiarUsuario(id),
        colorPrincipal: _primaryBlue,
        colorTexto: _textDeep,
        colorHint: _textLight,
      ),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: _inputGray,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.person_search_outlined, color: _primaryBlue, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                nombreActual,
                style: TextStyle(
                    color: existeId ? _textDeep : _textLight,
                    fontWeight:
                        existeId ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down_circle_outlined,
                color: _primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Campo visual para clonar que abre el modal ───────────────────────────
  Widget _buildCloneSearchField(bool existeBase) {
    final nombreBase = existeBase
        ? _usuarios
            .firstWhere((u) => u['id'] == _usuarioBaseId)['usuario']
            .toString()
            .toUpperCase()
        : null;
    return GestureDetector(
      onTap: () => _abrirModalBusqueda(
        titulo: 'Clonar permisos de...',
        usuarios: _usuarios.where((u) => u['id'] != _usuarioId).toList(),
        onSeleccionado: (id) => _clonarDesde(id),
        colorPrincipal: Colors.amber.shade700,
        colorTexto: Colors.amber.shade900,
        colorHint: Colors.amber.shade400,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nombreBase ?? 'Elegir origen...',
              style: TextStyle(
                  color: nombreBase != null
                      ? Colors.amber.shade900
                      : Colors.amber.shade400,
                  fontWeight: nombreBase != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.search, color: Colors.amber.shade700, size: 18),
        ],
      ),
    );
  }

  // ─── Modal genérico con buscador en tiempo real ───────────────────────────
  Future<void> _abrirModalBusqueda({
    required String titulo,
    required List<Map<String, dynamic>> usuarios,
    required void Function(int id) onSeleccionado,
    required Color colorPrincipal,
    required Color colorTexto,
    required Color colorHint,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalBuscadorUsuario(
        titulo: titulo,
        usuarios: usuarios,
        colorPrincipal: colorPrincipal,
        colorTexto: colorTexto,
        colorHint: colorHint,
        onSeleccionado: (id) {
          Navigator.pop(ctx);
          onSeleccionado(id);
        },
      ),
    );
  }
}

// ─── Widget stateful del modal buscador ──────────────────────────────────────
class _ModalBuscadorUsuario extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> usuarios;
  final Color colorPrincipal;
  final Color colorTexto;
  final Color colorHint;
  final void Function(int id) onSeleccionado;
  const _ModalBuscadorUsuario({
    required this.titulo,
    required this.usuarios,
    required this.colorPrincipal,
    required this.colorTexto,
    required this.colorHint,
    required this.onSeleccionado,
  });

  @override
  State<_ModalBuscadorUsuario> createState() => _ModalBuscadorUsuarioState();
}

class _ModalBuscadorUsuarioState extends State<_ModalBuscadorUsuario> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtrados = [];

  @override
  void initState() {
    super.initState();
    _filtrados = widget.usuarios;
    _searchController.addListener(_filtrar);
  }

  void _filtrar() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtrados = q.isEmpty
          ? widget.usuarios
          : widget.usuarios
              .where((u) =>
                  u['usuario'].toString().toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.manage_accounts_outlined,
                      color: widget.colorPrincipal, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.titulo,
                    style: TextStyle(
                        color: widget.colorPrincipal,
                        fontWeight: FontWeight.w900,
                        fontSize: 15),
                  ),
                  const Spacer(),
                  Text(
                    '${_filtrados.length} resultado${_filtrados.length != 1 ? 's' : ''}',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Escribe para filtrar...',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: widget.colorPrincipal, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: Colors.grey.shade400, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: widget.colorPrincipal.withOpacity(0.4),
                        width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _filtrados.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('Sin resultados',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: _filtrados.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (_, i) {
                        final u = _filtrados[i];
                        final nombre = u['usuario'].toString().toUpperCase();
                        final query = _searchController.text.toUpperCase().trim();
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                widget.colorPrincipal.withOpacity(0.1),
                            child: Text(
                              nombre.isNotEmpty ? nombre[0] : '?',
                              style: TextStyle(
                                  color: widget.colorPrincipal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          title: _buildHighlightedText(
                              nombre, query, widget.colorTexto,
                              widget.colorPrincipal),
                          onTap: () =>
                              widget.onSeleccionado(u['id'] as int),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
      String texto, String query, Color colorBase, Color colorResaltado) {
    if (query.isEmpty) {
      return Text(texto,
          style: TextStyle(
              color: colorBase, fontWeight: FontWeight.bold, fontSize: 13));
    }
    final idx = texto.indexOf(query);
    if (idx == -1) {
      return Text(texto,
          style: TextStyle(
              color: colorBase, fontWeight: FontWeight.bold, fontSize: 13));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
            color: colorBase, fontWeight: FontWeight.bold, fontSize: 13),
        children: [
          TextSpan(text: texto.substring(0, idx)),
          TextSpan(
            text: texto.substring(idx, idx + query.length),
            style: TextStyle(
                color: colorResaltado,
                fontWeight: FontWeight.w900,
                backgroundColor: colorResaltado.withOpacity(0.12)),
          ),
          TextSpan(text: texto.substring(idx + query.length)),
        ],
      ),
    );
  }
}