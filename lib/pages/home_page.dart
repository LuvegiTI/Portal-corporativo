import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_page.dart';
import 'admin_usuarios_page.dart';
import 'admin_boletas_page.dart';
import 'reportes_page.dart';
import 'mis_boletas_page.dart';
import 'admin_roles_permisos_page.dart';
import 'perfil_page.dart';
import 'auth_gate.dart';
import 'reporte_pendientes_page.dart';
import 'importar_oc_page.dart';
import '../pages/api_client.dart';

const Color luvegiBlue     = Color(0xFF003366);
const Color luvegiRed      = Color.fromARGB(255, 255, 38, 0);
const Color luvegiCyan     = Colors.cyanAccent;
const Color backgroundGray = Color(0xFFF1F5F9);

class HomePage extends StatefulWidget {
  final String token;
  final String rol;
  final String nombre;
  final String correo;
  final String usuarioId;
  final List<String> permisos;

  const HomePage({
    super.key,
    required this.token,
    required this.rol,
    required this.nombre,
    required this.correo,
    required this.usuarioId,
    required this.permisos,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeTab = 'Inicio';
  final AuthService _auth = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late List<String> _permisosDinamicos;
  late String _rolDinamico;
  Timer? _timerSincronizacion;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _permisosDinamicos = List.from(widget.permisos);
    _rolDinamico = widget.rol;

    _auth.iniciarPolling();
    ApiClient().startSessionCheck();

    _timerSincronizacion = Timer.periodic(const Duration(seconds: 10), (_) {
      _verificarEstadoYAccesos();
    });
  }

  @override
  void dispose() {
    _timerSincronizacion?.cancel();
    super.dispose();
  }

  Future<void> _verificarEstadoYAccesos() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final session = await _auth.getSession();
      if (session == null || !mounted) return;

      await _auth.refrescarMisPermisos();

      final sesionFresca = await _auth.getSession();
      if (sesionFresca == null || !mounted) return;

      final List<String> nuevos =
          List<String>.from(sesionFresca['permisos'] ?? []);
      final String nuevoRol = sesionFresca['rol'] ?? _rolDinamico;

      if (!listEquals(_permisosDinamicos, nuevos) ||
          _rolDinamico != nuevoRol) {
        bool tieneAccesoActual =
            _validarAccesoATab(nuevos, nuevoRol, _activeTab);

        setState(() {
          _permisosDinamicos = nuevos;
          _rolDinamico = nuevoRol;

          if (!tieneAccesoActual) {
            _activeTab = 'Inicio';
            debugPrint("🚫 Acceso revocado: Redirigiendo a Inicio");
          }
        });

        debugPrint("🔄 Módulos actualizados automáticamente");
      }
    } catch (e) {
      debugPrint("⚠️ Error en sincronización: $e");
    } finally {
      _isSyncing = false;
    }
  }

  bool _validarAccesoATab(
    List<String> nuevosPermisos,
    String nuevoRol,
    String tab,
  ) {
    if (tab == 'Inicio') return true;

    if (nuevoRol.toUpperCase() == 'ADMIN' ||
        nuevoRol.toUpperCase() == 'ADMINISTRADOR') {
      return true;
    }

    final mapaPermisos = {
      'Mis Boletas': '6',
      'Subir ZIP': '7',
      'Boletas Pendientes': '8',
      'Reportes': '1',
      'Usuarios': '9',
      'Roles': '10',
      'Importar OC': '11',
    };

    String? idNecesario = mapaPermisos[tab];
    if (idNecesario == null) return true;

    return nuevosPermisos.any((p) => p.trim() == idNecesario);
  }

  bool _tiene(String cod, {String? id}) {
    if (_rolDinamico.toUpperCase() == 'ADMIN' ||
        _rolDinamico.toUpperCase() == 'ADMINISTRADOR') {
      return true;
    }

    return _permisosDinamicos.any((p) {
      final pLimpio = p.trim().toUpperCase();
      final codLimpio = cod.trim().toUpperCase();

      return pLimpio == codLimpio || (id != null && pLimpio == id);
    });
  }

  void _verPerfil() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilPage(
          nombre: widget.nombre,
          rol: _rolDinamico,
          correo: widget.correo,
          usuarioId: widget.usuarioId,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1000;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: luvegiBlue,
        elevation: 0,
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        title: Row(
          children: [
            Image.asset(
              'assets/Logo 600 x 193 (1).png',
              height: 50,
              fit: BoxFit.contain,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 30),
              _buildHorizontalNav(),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white54, size: 20),
            onPressed: _verificarEstadoYAccesos,
          ),
          if (!isMobile) _buildUserBadge(),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Cerrar Sesión',
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: isMobile ? _buildDrawer() : null,
      body: Container(
        color: backgroundGray,
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_activeTab) {
      case 'Mis Boletas':
        return MisBoletasPage(token: widget.token);

      case 'Usuarios':
        return AdminUsuariosPage(token: widget.token);

      case 'Roles':
        return AdminRolesPermisosPage(token: widget.token);

      case 'Subir ZIP':
        return AdminBoletasPage(token: widget.token);

      case 'Reportes':
        return ReportesPage(token: widget.token);

      case 'Boletas Pendientes':
        return ReportePendientesPage(token: widget.token);

      case 'Importar OC':
        return ImportarOcPage(token: widget.token);

      case 'Inicio':
      default:
        return DashboardPage(
          token: widget.token,
          nombre: widget.nombre,
          rol: _rolDinamico,
          onNavigate: (tab) => setState(() => _activeTab = tab),
        );
    }
  }

  Widget _buildHorizontalNav() {
    final bool canMisBoletas = _tiene('MIS_BOLETAS', id: '6');
    final bool canSubirZip = _tiene('SUBIR_ZIP', id: '7');
    final bool canVerPendientes = _tiene('BOLETAS PENDIENTES', id: '8');
    final bool canVerReportes = _tiene('CONSULTAR_REPORTES', id: '1');
    final bool canAdminUser = _tiene('USUARIOS', id: '9');
    final bool canAdminRoles = _tiene('ROLES', id: '10');
    final bool canImportarOc = _tiene('IMPORTAR_OC', id: '11');

    return Row(
      children: [
        NavBarItem(
          label: 'INICIO',
          isActive: _activeTab == 'Inicio',
          onPressed: () => setState(() => _activeTab = 'Inicio'),
        ),

        if (canMisBoletas || canSubirZip || canVerPendientes)
          _buildSubMenu(
            label: 'RRHH',
            isActive: [
              'Mis Boletas',
              'Subir ZIP',
              'Boletas Pendientes',
            ].contains(_activeTab),
            items: {
              if (canMisBoletas)
                'Mis Boletas': Icons.description_outlined,
              if (canVerPendientes)
                'Boletas Pendientes': Icons.pending_actions_rounded,
              if (canSubirZip)
                'Subir ZIP': Icons.upload_file_rounded,
            },
          ),

        if (canVerReportes)
          NavBarItem(
            label: 'REPORTES',
            isActive: _activeTab == 'Reportes',
            onPressed: () => setState(() => _activeTab = 'Reportes'),
          ),

        if (canImportarOc)
          _buildSubMenu(
            label: 'LOGÍSTICA',
            isActive: ['Importar OC'].contains(_activeTab),
            items: {
              'Importar OC': Icons.shopping_cart_checkout_rounded,
            },
          ),

        if (canAdminUser || canAdminRoles)
          _buildSubMenu(
            label: 'ACCESOS',
            isActive: ['Usuarios', 'Roles'].contains(_activeTab),
            items: {
              if (canAdminUser) 'Usuarios': Icons.group_outlined,
              if (canAdminRoles) 'Roles': Icons.security_outlined,
            },
          ),
      ],
    );
  }

  Widget _buildDrawer() {
    final bool canSubirZip = _tiene('SUBIR_ZIP', id: '7');
    final bool canVerPendientes = _tiene('BOLETAS PENDIENTES', id: '8');
    final bool canMisBoletas = _tiene('MIS_BOLETAS', id: '6');
    final bool canAdminUser = _tiene('USUARIOS', id: '9');
    final bool canAdminRoles = _tiene('ROLES', id: '10');
    final bool canImportarOc = _tiene('IMPORTAR_OC', id: '11');

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: luvegiBlue),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: luvegiCyan,
              child: Icon(Icons.person, color: luvegiBlue),
            ),
            accountName: Text(
              widget.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(widget.correo),
            onDetailsPressed: _verPerfil,
          ),

          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Inicio'),
            selected: _activeTab == 'Inicio',
            onTap: () {
              setState(() => _activeTab = 'Inicio');
              Navigator.pop(context);
            },
          ),

          if (canMisBoletas || canSubirZip || canVerPendientes) ...[
            const Divider(),
            _buildDrawerGroupTitle("RRHH"),

            if (canMisBoletas)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Mis Boletas'),
                selected: _activeTab == 'Mis Boletas',
                onTap: () {
                  setState(() => _activeTab = 'Mis Boletas');
                  Navigator.pop(context);
                },
              ),

            if (canVerPendientes)
              ListTile(
                leading: const Icon(Icons.pending_actions_rounded),
                title: const Text('Boletas Pendientes'),
                selected: _activeTab == 'Boletas Pendientes',
                onTap: () {
                  setState(() => _activeTab = 'Boletas Pendientes');
                  Navigator.pop(context);
                },
              ),

            if (canSubirZip)
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('Subir ZIP'),
                selected: _activeTab == 'Subir ZIP',
                onTap: () {
                  setState(() => _activeTab = 'Subir ZIP');
                  Navigator.pop(context);
                },
              ),
          ],

          if (_tiene('CONSULTAR_REPORTES', id: '1')) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: const Text('Reportes'),
              selected: _activeTab == 'Reportes',
              onTap: () {
                setState(() => _activeTab = 'Reportes');
                Navigator.pop(context);
              },
            ),
          ],

          if (canImportarOc) ...[
            const Divider(),
            _buildDrawerGroupTitle("LOGÍSTICA"),
            ListTile(
              leading: const Icon(Icons.shopping_cart_checkout_rounded),
              title: const Text('Importar OC'),
              selected: _activeTab == 'Importar OC',
              onTap: () {
                setState(() => _activeTab = 'Importar OC');
                Navigator.pop(context);
              },
            ),
          ],

          if (canAdminUser || canAdminRoles) ...[
            const Divider(),
            _buildDrawerGroupTitle("ACCESOS"),

            if (canAdminUser)
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Usuarios'),
                selected: _activeTab == 'Usuarios',
                onTap: () {
                  setState(() => _activeTab = 'Usuarios');
                  Navigator.pop(context);
                },
              ),

            if (canAdminRoles)
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: const Text('Roles'),
                selected: _activeTab == 'Roles',
                onTap: () {
                  setState(() => _activeTab = 'Roles');
                  Navigator.pop(context);
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSubMenu({
    required String label,
    required bool isActive,
    required Map<String, IconData> items,
  }) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) => setState(() => _activeTab = val),
      itemBuilder: (context) => items.entries
          .map(
            (e) => PopupMenuItem(
              value: e.key,
              child: Row(
                children: [
                  Icon(e.value, size: 18, color: luvegiBlue),
                  const SizedBox(width: 10),
                  Text(
                    e.key,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? luvegiCyan : Colors.white70,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: isActive ? luvegiCyan : Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBadge() {
    return InkWell(
      onTap: _verPerfil,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 10,
              backgroundColor: luvegiCyan,
              child: Icon(Icons.person, size: 14, color: luvegiBlue),
            ),
            const SizedBox(width: 8),
            Text(
              widget.nombre,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavBarItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const NavBarItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? luvegiCyan : Colors.white70,
          fontSize: 12,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}