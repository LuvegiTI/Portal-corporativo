import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

import '../services/auth_service.dart';
import '../services/rdr_notificaciones_service.dart';
import '../services/rdr_service.dart';
import 'dashboard_page.dart';
import 'admin_usuarios_page.dart';
import 'admin_boletas_page.dart';
import 'reportes_page.dart';
import 'mis_boletas_page.dart';
import 'admin_roles_permisos_page.dart';
import 'admin_catalogo_acceso_page.dart';
import 'perfil_page.dart';
import 'auth_gate.dart';
import 'reporte_pendientes_page.dart';
import 'importar_oc_page.dart';
import 'importar_almacen_page.dart';
import 'importar_solped_page.dart';
import 'reporte_pedido_consumo.dart';
import 'reporte_consolidado_page.dart';
import 'reporte_lineas_venta_page.dart';
import 'reporte_compra_page.dart';
import 'reporte_ventas_compras_page.dart';
import 'pluz_cortes_page.dart';
import '../pages/api_client.dart';
import 'rdr/registrar_rdr_page.dart';
import 'rdr/consultar_rdr_page.dart';
import 'rdr/detalle_rdr_page.dart';

// Módulos disponibles en producción.
// Cambia a true cuando Recursos Humanos esté listo para habilitarse.
const bool moduloRRHHHabilitado = false;

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
  final RdrService _rdrService = RdrService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late List<String> _permisosDinamicos;
  late String _rolDinamico;
  Timer? _timerSincronizacion;
  bool _isSyncing = false;
  int _versionConsultaRdr = 0;

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
        final bool tieneAccesoActual =
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

  Future<void> _abrirRdrDesdeNotificacion(String codigo) async {
    try {
      final response = await _rdrService.obtenerDetalle(
        token: widget.token,
        codigo: codigo,
      );
      final rawDetalle = response['data'];

      if (rawDetalle is! Map) {
        throw const RdrApiException('El detalle recibido no es válido.');
      }
      if (!mounted) return;

      final resultado = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => DetalleRdrPage.desdeJson(
            token: widget.token,
            json: Map<String, dynamic>.from(rawDetalle),
          ),
        ),
      );

      if (resultado == true && mounted) {
        setState(() => _versionConsultaRdr++);
      }
    } on RdrApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      debugPrint('Error abriendo REDIR desde notificación: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el detalle del REDIR.'),
          backgroundColor: Colors.redAccent,
        ),
      );
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

    bool tieneCodigo(String codigo, {String? id}) {
      return nuevosPermisos.any((p) {
        final limpio = p.trim().toUpperCase();
        return limpio == codigo.toUpperCase() || (id != null && limpio == id);
      });
    }

    switch (tab) {
      case 'Mis Boletas':
        return moduloRRHHHabilitado &&
            tieneCodigo('MIS_BOLETAS', id: '6');

      case 'Subir ZIP':
        return moduloRRHHHabilitado &&
            tieneCodigo('SUBIR_ZIP', id: '7');

      case 'Boletas Pendientes':
        return moduloRRHHHabilitado &&
            (tieneCodigo('BOLETAS_PENDIENTES', id: '8') ||
                tieneCodigo('BOLETAS PENDIENTES', id: '8'));

      case 'Reporte de Prueba':
        return tieneCodigo('CONSULTAR_', id: '1');

      case 'Usuarios':
        return tieneCodigo('USUARIOS', id: '9');

      case 'Roles':
        return tieneCodigo('ROLES', id: '10');

      case 'Áreas y módulos':
        return tieneCodigo('ROLES', id: '10');

      case 'Importar OC':
        return tieneCodigo('IMPORTAR_OC', id: '11');

      case 'Importar Almacén':
        return tieneCodigo('IMPORTAR_ALMACEN', id: '4');

      case 'Importar Solicitudes de Compra':
        return tieneCodigo('IMPORTAR_PR', id: '5') ||
            tieneCodigo('IMPORTAR_SOLPED', id: '5');

      case 'Reporte Consumo':
        return tieneCodigo('REPORTE_CONSUMO', id: '12');

      case 'Reporte Consolidado':
        return tieneCodigo('REPORTE_CONSOLIDADO') || tieneCodigo('REPORTE_CONSUMO', id: '12');

      case 'Reporte por Líneas de Venta':
        return tieneCodigo('CONSULTAR_VENTAS');

      case 'Reporte de Órdenes de Compra':
        return tieneCodigo('CONSULTAR_COMPRAS');

      case 'Reporte Ventas y Compras':
        return tieneCodigo('CONSULTAR_VENTAS_COMPRAS') ||
            tieneCodigo('CONSULTAR_VENTAS') ||
            tieneCodigo('CONSULTAR_COMPRAS');

      case 'Registrar REDIR':
        return tieneCodigo('CREAR_RDR');

      case 'Consultar REDIR':
        return tieneCodigo('CONSULTAR_RDR');

      default:
        return true; 
    }
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
        backgroundColor: LuvegiColors.surface,
        surfaceTintColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 80,
        shape: const Border(
          bottom: BorderSide(
            color: LuvegiColors.border,
            width: 1,
          ),
        ),
        leading: isMobile
            ? IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: LuvegiColors.secondary,
                ),
                tooltip: 'Abrir menú',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
        titleSpacing: isMobile ? 8 : 24,
        title: Row(
          children: [
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/Logo 600 x 193 (1).png',
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: LuvegiSpacing.xxl),
              Expanded(child: _buildHorizontalNav()),
            ],
          ],
        ),
        actions: [
          if (!isMobile)
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.only(right: 14),
              color: LuvegiColors.border,
            ),
          _HeaderIconButton(
            icon: Icons.sync_rounded,
            tooltip: 'Sincronizar accesos',
            onPressed: _verificarEstadoYAccesos,
          ),
          if (_tiene('CONSULTAR_RDR')) ...[
            const SizedBox(width: LuvegiSpacing.sm),
            _RdrNotificationBell(
              token: widget.token,
              onOpenRdr: _abrirRdrDesdeNotificacion,
            ),
          ],
          if (!isMobile) ...[
            const SizedBox(width: LuvegiSpacing.sm),
            _buildUserBadge(),
          ],
          const SizedBox(width: LuvegiSpacing.sm),
          _HeaderIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
          const SizedBox(width: LuvegiSpacing.md),
        ],
      ),
      drawer: isMobile ? _buildDrawer() : null,
      body: ColoredBox(
        color: LuvegiColors.background,
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_activeTab) {
      case 'Mis Boletas':
        if (moduloRRHHHabilitado) {
          return MisBoletasPage(token: widget.token);
        }
        return DashboardPage(
          token: widget.token,
          nombre: widget.nombre,
          rol: _rolDinamico,
          permisos: _permisosDinamicos,
          onNavigate: (tab) => setState(() => _activeTab = tab),
        );

      case 'Usuarios':
        return AdminUsuariosPage(token: widget.token);

      case 'Roles':
        return AdminRolesPermisosPage(token: widget.token);

      case 'Áreas y módulos':
        return AdminCatalogosAccesoPage(token: widget.token);

      case 'Subir ZIP':
        if (moduloRRHHHabilitado) {
          return AdminBoletasPage(token: widget.token);
        }
        return DashboardPage(
          token: widget.token,
          nombre: widget.nombre,
          rol: _rolDinamico,
          permisos: _permisosDinamicos,
          onNavigate: (tab) => setState(() => _activeTab = tab),
        );

      case 'Reporte de Prueba':
        return ReportesPage(token: widget.token);

      case 'Boletas Pendientes':
        if (moduloRRHHHabilitado) {
          return ReportePendientesPage(token: widget.token);
        }
        return DashboardPage(
          token: widget.token,
          nombre: widget.nombre,
          rol: _rolDinamico,
          permisos: _permisosDinamicos,
          onNavigate: (tab) => setState(() => _activeTab = tab),
        );

      case 'Importar OC':
        return ImportarOcPage(token: widget.token);

      case 'Importar Almacén':
        return ImportarAlmacenPage(token: widget.token);

      case 'Importar Solicitudes de Compra':
        return ImportarPrPage(token: widget.token);

      case 'Reporte Consumo':
        return ReporteConsumoPage(token: widget.token);

      case 'Reporte Consolidado':
        return ReporteConsolidadoPage(token: widget.token);

      case 'Reporte por Líneas de Venta':
        return ReporteLineasVentaPage(
          token: widget.token,
          permisos: _permisosDinamicos,
        );

      case 'Reporte de Órdenes de Compra':
        return ReporteOrdenCompraPage(
          token: widget.token,
          permisos: _permisosDinamicos,
        );

      case 'Reporte Ventas y Compras':
        return ReporteVentasComprasPage(
          token: widget.token,
          permisos: _permisosDinamicos,
        );

      case 'Registrar REDIR':
        return RegistrarRdrPage(
          token: widget.token,
          nombreUsuario: widget.nombre,
          correoUsuario: widget.correo,
          usuarioId: widget.usuarioId,
          onRegistrado: () {
            setState(() => _activeTab = 'Consultar REDIR');
          },
        );

      case 'Consultar REDIR':
        return ConsultarRdrPage(
          key: ValueKey('consulta-rdr-$_versionConsultaRdr'),
          token: widget.token,
          permisos: _permisosDinamicos,
          onRegistrarRdr: () {
            setState(() => _activeTab = 'Registrar REDIR');
          },
        );

      case 'Cortes Pluz':
        return const PluzCortesPage();

      case 'Inicio':
      default:
        return DashboardPage(
          token: widget.token,
          nombre: widget.nombre,
          rol: _rolDinamico,
          permisos: _permisosDinamicos,
          onNavigate: (tab) => setState(() => _activeTab = tab),
        );
    }
  }

  Widget _buildHorizontalNav() {
    final bool canMisBoletas = _tiene('MIS_BOLETAS', id: '6');
    final bool canSubirZip = _tiene('SUBIR_ZIP', id: '7');
    final bool canVerPendientes =
        _tiene('BOLETAS_PENDIENTES', id: '8') ||
        _tiene('BOLETAS PENDIENTES', id: '8');

    final bool canVerReportes = _tiene('CONSULTAR_REPORTES', id: '1');
    final bool canReporteConsumo = _tiene('REPORTE_CONSUMO', id: '12');
    final bool canReporteConsolidado = _tiene('REPORTE_CONSOLIDADO') || canReporteConsumo;
    final bool canReporteLineasVenta = _tiene('CONSULTAR_VENTAS');
    final bool canReporteOrdenCompra = _tiene('CONSULTAR_COMPRAS');
    final bool canReporteVentasCompras = _tiene('CONSULTAR_VENTAS_COMPRAS') ||
        canReporteLineasVenta ||
        canReporteOrdenCompra;

    final bool canAdminUser = _tiene('USUARIOS', id: '9');
    final bool canAdminRoles = _tiene('ROLES', id: '10');

    final bool canImportarOc = _tiene('IMPORTAR_OC', id: '11');
    final bool canImportarAlmacen = _tiene('IMPORTAR_ALMACEN', id: '4');
    final bool canImportarPr =
        _tiene('IMPORTAR_PR', id: '5') || _tiene('IMPORTAR_SOLPED', id: '5');

    final bool canCrearRdr = _tiene('CREAR_RDR');
    final bool canConsultarRdr = _tiene('CONSULTAR_RDR');

    return Row(
      children: [
        NavBarItem(
          label: 'Inicio',
          isActive: _activeTab == 'Inicio',
          onPressed: () => setState(() => _activeTab = 'Inicio'),
        ),

        NavBarItem(
          label: 'Cortes Pluz',
          isActive: _activeTab == 'Cortes Pluz',
          onPressed: () => setState(() => _activeTab = 'Cortes Pluz'),
        ),

        if (moduloRRHHHabilitado &&
            (canMisBoletas || canSubirZip || canVerPendientes))
          _buildSubMenu(
            label: 'Recursos Humanos',
            isActive: [
              'Mis Boletas',
              'Subir ZIP',
              'Boletas Pendientes',
            ].contains(_activeTab),
            items: {
              if (canMisBoletas) 'Mis Boletas': Icons.description_outlined,
              if (canVerPendientes)
                'Boletas Pendientes': Icons.pending_actions_rounded,
              if (canSubirZip) 'Subir ZIP': Icons.upload_file_rounded,
            },
          ),

        if (canVerReportes ||
            canReporteConsumo ||
            canReporteConsolidado ||
            canReporteLineasVenta ||
            canReporteOrdenCompra ||
            canReporteVentasCompras)
          _buildSubMenu(
            label: 'Reportes',
            isActive: [
              'Reporte de Prueba',
              'Reporte Consumo',
              'Reporte Consolidado',
              'Reporte por Líneas de Venta',
              'Reporte de Órdenes de Compra',
              'Reporte Ventas y Compras',
            ].contains(_activeTab),
            items: {
              if (canVerReportes) 'Reporte de Prueba': Icons.bar_chart_rounded,
              if (canReporteConsolidado)
                'Reporte Consolidado': Icons.receipt_long_rounded,
              if (canReporteConsumo)
                'Reporte Consumo': Icons.table_chart_rounded,
              if (canReporteLineasVenta)
                'Reporte por Líneas de Venta': Icons.receipt_long_rounded,
              if (canReporteOrdenCompra)
                'Reporte de Órdenes de Compra':
                    Icons.shopping_cart_checkout_rounded,
              if (canReporteVentasCompras)
                'Reporte Ventas y Compras': Icons.analytics_rounded,
            },
          ),

        if (canImportarOc || canImportarAlmacen || canImportarPr)
          _buildSubMenu(
            label: 'Herramientas',
            isActive: [
              'Importar OC',
              'Importar Almacén',
              'Importar Solicitudes de Compra',
            ].contains(_activeTab),
            items: {
              if (canImportarOc)
                'Importar OC': Icons.shopping_cart_checkout_rounded,
              if (canImportarAlmacen)
                'Importar Almacén': Icons.inventory_2_rounded,
              if (canImportarPr) 'Importar Solicitudes de Compra': Icons.assignment_add,
            },
          ),

        if (canCrearRdr || canConsultarRdr)
          _buildSubMenu(
            label: 'REDIR',
            isActive: [
              'Registrar REDIR',
              'Consultar REDIR',
            ].contains(_activeTab),
            items: {
              if (canCrearRdr)
                'Registrar REDIR': Icons.add_comment_outlined,
              if (canConsultarRdr)
                'Consultar REDIR': Icons.fact_check_outlined,
            },
          ),

        if (canAdminUser || canAdminRoles)
          _buildSubMenu(
            label: 'Accesos',
            isActive: ['Usuarios', 'Roles', 'Áreas y módulos'].contains(_activeTab),
            items: {
              if (canAdminUser) 'Usuarios': Icons.group_outlined,
              if (canAdminRoles) 'Roles': Icons.security_outlined,
              if (canAdminRoles) 'Áreas y módulos': Icons.account_tree_outlined,
            },
          ),
      ],
    );
  }

  Widget _buildDrawer() {
    final bool canSubirZip = _tiene('SUBIR_ZIP', id: '7');
    final bool canVerPendientes =
        _tiene('BOLETAS_PENDIENTES', id: '8') ||
        _tiene('BOLETAS PENDIENTES', id: '8');
    final bool canMisBoletas = _tiene('MIS_BOLETAS', id: '6');

    final bool canVerReportes = _tiene('CONSULTAR_REPORTES', id: '1');
    final bool canReporteConsumo = _tiene('REPORTE_CONSUMO', id: '12');
    final bool canReporteConsolidado = _tiene('REPORTE_CONSOLIDADO') || canReporteConsumo;
    final bool canReporteLineasVenta = _tiene('CONSULTAR_VENTAS');
    final bool canReporteOrdenCompra = _tiene('CONSULTAR_COMPRAS');
    final bool canReporteVentasCompras = _tiene('CONSULTAR_VENTAS_COMPRAS') ||
        canReporteLineasVenta ||
        canReporteOrdenCompra;

    final bool canAdminUser = _tiene('USUARIOS', id: '9');
    final bool canAdminRoles = _tiene('ROLES', id: '10');

    final bool canImportarOc = _tiene('IMPORTAR_OC', id: '11');
    final bool canImportarAlmacen = _tiene('IMPORTAR_ALMACEN', id: '4');
    final bool canImportarPr =
        _tiene('IMPORTAR_PR', id: '5') ||
        _tiene('IMPORTAR_SOLPED', id: '5');

    final bool canCrearRdr = _tiene('CREAR_RDR');
    final bool canConsultarRdr = _tiene('CONSULTAR_RDR');

    Widget drawerTile({
      required IconData icon,
      required String title,
      required String tab,
    }) {
      final bool selected = _activeTab == tab;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          minLeadingWidth: 28,
          leading: Icon(
            icon,
            size: 20,
            color: selected
                ? LuvegiColors.secondary
                : LuvegiColors.textSecondary,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: selected
                  ? LuvegiColors.secondary
                  : LuvegiColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
          selected: selected,
          selectedTileColor: LuvegiColors.menuHover,
          tileColor: LuvegiColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            side: BorderSide(
              color: selected
                  ? LuvegiColors.menuSelected
                  : Colors.transparent,
            ),
          ),
          onTap: () {
            setState(() => _activeTab = tab);
            Navigator.pop(context);
          },
        ),
      );
    }

    Widget drawerGroup({
      required String title,
      required IconData icon,
      required bool initiallyExpanded,
      required List<Widget> children,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(bottom: 4),
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            leading: Icon(
              icon,
              size: 20,
              color: LuvegiColors.secondary,
            ),
            title: Text(
              title,
              style: LuvegiText.menu.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            ),
            backgroundColor: LuvegiColors.surfaceHover,
            collapsedBackgroundColor: LuvegiColors.surface,
            iconColor: LuvegiColors.secondary,
            collapsedIconColor: LuvegiColors.textSecondary,
            children: children,
          ),
        ),
      );
    }

    final bool rrhhActivo = [
      'Mis Boletas',
      'Subir ZIP',
      'Boletas Pendientes',
    ].contains(_activeTab);

    final bool reportesActivo = [
      'Reporte de Prueba',
      'Reporte Consumo',
      'Reporte Consolidado',
      'Reporte por Líneas de Venta',
      'Reporte de Órdenes de Compra',
      'Reporte Ventas y Compras',
    ].contains(_activeTab);

    final bool herramientasActivo = [
      'Importar OC',
      'Importar Almacén',
      'Importar Solicitudes de Compra',
    ].contains(_activeTab);

    final bool rdrActivo = [
      'Registrar REDIR',
      'Consultar REDIR',
    ].contains(_activeTab);

    final bool accesosActivo = ['Usuarios', 'Roles', 'Áreas y módulos'].contains(_activeTab);

    return Drawer(
      backgroundColor: LuvegiColors.surface,
      surfaceTintColor: LuvegiColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            InkWell(
              onTap: _verPerfil,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                decoration: const BoxDecoration(
                  color: LuvegiColors.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: LuvegiColors.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: LuvegiColors.secondary,
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: LuvegiSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LuvegiText.title.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.correo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LuvegiText.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                children: [
                  drawerTile(
                    icon: Icons.home_outlined,
                    title: 'Inicio',
                    tab: 'Inicio',
                  ),

                  drawerTile(
                    icon: Icons.bolt_rounded,
                    title: 'Cortes Pluz',
                    tab: 'Cortes Pluz',
                  ),

                  if (moduloRRHHHabilitado &&
                      (canMisBoletas ||
                          canSubirZip ||
                          canVerPendientes))
                    drawerGroup(
                      title: 'Recursos Humanos',
                      icon: Icons.badge_outlined,
                      initiallyExpanded: rrhhActivo,
                      children: [
                        if (canMisBoletas)
                          drawerTile(
                            icon: Icons.description_outlined,
                            title: 'Mis Boletas',
                            tab: 'Mis Boletas',
                          ),
                        if (canVerPendientes)
                          drawerTile(
                            icon: Icons.pending_actions_rounded,
                            title: 'Boletas Pendientes',
                            tab: 'Boletas Pendientes',
                          ),
                        if (canSubirZip)
                          drawerTile(
                            icon: Icons.upload_file_rounded,
                            title: 'Subir ZIP',
                            tab: 'Subir ZIP',
                          ),
                      ],
                    ),

                  if (canVerReportes ||
                      canReporteConsumo ||
                      canReporteConsolidado ||
                      canReporteLineasVenta ||
                      canReporteOrdenCompra ||
                      canReporteVentasCompras)
                    drawerGroup(
                      title: 'Reportes',
                      icon: Icons.bar_chart_rounded,
                      initiallyExpanded: reportesActivo,
                      children: [
                        if (canVerReportes)
                          drawerTile(
                            icon: Icons.analytics_outlined,
                            title: 'Reporte de Prueba',
                            tab: 'Reporte de Prueba',
                          ),
                        if (canReporteConsolidado)
                          drawerTile(
                            icon: Icons.receipt_long_rounded,
                            title: 'Reporte Consolidado',
                            tab: 'Reporte Consolidado',
                          ),
                        if (canReporteConsumo)
                          drawerTile(
                            icon: Icons.table_chart_rounded,
                            title: 'Reporte Consumo',
                            tab: 'Reporte Consumo',
                          ),
                        if (canReporteLineasVenta)
                          drawerTile(
                            icon: Icons.receipt_long_rounded,
                            title: 'Reporte por Líneas de Venta',
                            tab: 'Reporte por Líneas de Venta',
                          ),
                        if (canReporteOrdenCompra)
                          drawerTile(
                            icon: Icons.shopping_cart_checkout_rounded,
                            title: 'Reporte de Órdenes de Compra',
                            tab: 'Reporte de Órdenes de Compra',
                          ),
                        if (canReporteVentasCompras)
                          drawerTile(
                            icon: Icons.analytics_rounded,
                            title: 'Reporte Ventas y Compras',
                            tab: 'Reporte Ventas y Compras',
                          ),
                      ],
                    ),

                  if (canImportarOc ||
                      canImportarAlmacen ||
                      canImportarPr)
                    drawerGroup(
                      title: 'Herramientas',
                      icon: Icons.build_outlined,
                      initiallyExpanded: herramientasActivo,
                      children: [
                        if (canImportarOc)
                          drawerTile(
                            icon: Icons.shopping_cart_checkout_rounded,
                            title: 'Importar OC',
                            tab: 'Importar OC',
                          ),
                        if (canImportarAlmacen)
                          drawerTile(
                            icon: Icons.inventory_2_rounded,
                            title: 'Importar Almacén',
                            tab: 'Importar Almacén',
                          ),
                        if (canImportarPr)
                          drawerTile(
                            icon: Icons.assignment_add,
                            title: 'Importar Solicitudes',
                            tab: 'Importar Solicitudes de Compra',
                          ),
                      ],
                    ),

                  if (canCrearRdr || canConsultarRdr)
                    drawerGroup(
                      title: 'REDIR',
                      icon: Icons.report_problem_outlined,
                      initiallyExpanded: rdrActivo,
                      children: [
                        if (canCrearRdr)
                          drawerTile(
                            icon: Icons.add_comment_outlined,
                            title: 'Registrar REDIR',
                            tab: 'Registrar REDIR',
                          ),
                        if (canConsultarRdr)
                          drawerTile(
                            icon: Icons.fact_check_outlined,
                            title: 'Consultar REDIR',
                            tab: 'Consultar REDIR',
                          ),
                      ],
                    ),

                  if (canAdminUser || canAdminRoles)
                    drawerGroup(
                      title: 'Accesos',
                      icon: Icons.security_outlined,
                      initiallyExpanded: accesosActivo,
                      children: [
                        if (canAdminUser)
                          drawerTile(
                            icon: Icons.group_outlined,
                            title: 'Usuarios',
                            tab: 'Usuarios',
                          ),
                        if (canAdminRoles)
                          drawerTile(
                            icon: Icons.admin_panel_settings_outlined,
                            title: 'Roles',
                            tab: 'Roles',
                          ),
                        if (canAdminRoles)
                          drawerTile(
                            icon: Icons.account_tree_outlined,
                            title: 'Áreas y módulos',
                            tab: 'Áreas y módulos',
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
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
      tooltip: '',
      offset: const Offset(0, 50),
      color: LuvegiColors.surface,
      surfaceTintColor: LuvegiColors.surface,
      elevation: 14,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        side: const BorderSide(color: LuvegiColors.border),
      ),
      onSelected: (val) => setState(() => _activeTab = val),
      itemBuilder: (context) => items.entries
          .map(
            (e) {
              final bool selected = _activeTab == e.key;

              return PopupMenuItem<String>(
                value: e.key,
                height: 52,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? LuvegiColors.menuHover : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected
                          ? LuvegiColors.menuSelected
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : LuvegiColors.surfaceHover,
                          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                          border: Border.all(
                            color: selected
                                ? LuvegiColors.menuSelected
                                : LuvegiColors.border,
                          ),
                        ),
                        child: Icon(
                          e.value,
                          size: 18,
                          color: LuvegiColors.secondary,
                        ),
                      ),
                      const SizedBox(width: LuvegiSpacing.md),
                      Expanded(
                        child: Text(
                          e.key,
                          style: TextStyle(
                            color: selected ? LuvegiColors.secondary : LuvegiColors.textPrimary,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: LuvegiColors.secondary,
                        ),
                    ],
                  ),
                ),
              );
            },
          )
          .toList(),
      child: Container(
        height: 42,
        margin: const EdgeInsets.symmetric(vertical: 17, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? LuvegiColors.menuHover : Colors.transparent,
          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          border: Border.all(
            color: isActive ? LuvegiColors.menuSelected : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? LuvegiColors.secondary : LuvegiColors.textPrimary,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isActive ? LuvegiColors.secondary : LuvegiColors.textSecondary,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBadge() {
    return InkWell(
      onTap: _verPerfil,
      borderRadius: BorderRadius.circular(LuvegiRadius.md),
      hoverColor: LuvegiColors.menuHover,
      child: Container(
        height: 48,
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        decoration: BoxDecoration(
          color: LuvegiColors.surfaceHover,
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
          border: Border.all(color: LuvegiColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08101828),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF0B4A82),
                  child: Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: LuvegiColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: LuvegiSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 145),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LuvegiColors.textPrimary,
                      fontSize: 12.5,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rolDinamico,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LuvegiColors.textSecondary,
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: LuvegiColors.textSecondary,
              size: 18,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        hoverColor: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          margin: const EdgeInsets.symmetric(vertical: 17),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: isActive ? LuvegiColors.menuHover : Colors.transparent,
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            border: Border.all(
              color: isActive
                  ? LuvegiColors.menuSelected
                  : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? LuvegiColors.secondary : LuvegiColors.textPrimary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _hovered ? LuvegiColors.menuHover : LuvegiColors.surfaceHover,
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
              border: Border.all(
                color: _hovered ? LuvegiColors.menuSelected : LuvegiColors.border,
              ),
              boxShadow: _hovered
                  ? const [
                      BoxShadow(
                        color: Color(0x12101828),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: _hovered ? LuvegiColors.secondary : LuvegiColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RdrNotificationBell extends StatefulWidget {
  final String token;
  final ValueChanged<String> onOpenRdr;

  const _RdrNotificationBell({
    required this.token,
    required this.onOpenRdr,
  });

  @override
  State<_RdrNotificationBell> createState() => _RdrNotificationBellState();
}

class _RdrNotificationBellState extends State<_RdrNotificationBell> {
  final RdrNotificacionesService _service = RdrNotificacionesService();
  Timer? _timer;
  int _noLeidas = 0;
  List<RdrNotificacion> _items = const [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    _cargando = true;
    try {
      final result = await _service.listar(widget.token);
      if (!mounted) return;
      setState(() {
        _noLeidas = result.noLeidas;
        _items = result.notificaciones;
      });
    } catch (error) {
      debugPrint('No se pudieron cargar notificaciones REDIR: $error');
    } finally {
      _cargando = false;
    }
  }

  Future<void> _abrir() async {
    await _cargar();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.only(top: 82, right: 18, left: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: LuvegiColors.secondary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Notificaciones REDIR',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_noLeidas > 0)
                      TextButton(
                        onPressed: () async {
                          await _service.marcarTodasLeidas(widget.token);
                          if (mounted) setState(() => _noLeidas = 0);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          await _cargar();
                        },
                        child: const Text('Leer todas'),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: _items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(38),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 38,
                              color: LuvegiColors.textSecondary,
                            ),
                            SizedBox(height: 12),
                            Text('No tienes notificaciones REDIR.'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final item = _items[index];
                          return Material(
                            color: item.leida
                                ? Colors.white
                                : const Color(0xFFF0F6FF),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: item.tipo == 'RDR_ATENDIDO'
                                    ? const Color(0xFFE9F8EF)
                                    : const Color(0xFFEAF2FF),
                                child: Icon(
                                  item.tipo == 'RDR_ATENDIDO'
                                      ? Icons.task_alt_rounded
                                      : Icons.add_comment_outlined,
                                  color: item.tipo == 'RDR_ATENDIDO'
                                      ? Colors.green.shade700
                                      : LuvegiColors.secondary,
                                ),
                              ),
                              title: Text(
                                item.titulo,
                                style: TextStyle(
                                  fontWeight: item.leida
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  item.mensaje,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                              ),
                              onTap: () async {
                                if (!item.leida) {
                                  await _service.marcarLeida(
                                    widget.token,
                                    item.id,
                                  );
                                }
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                widget.onOpenRdr(item.codigo);
                                await _cargar();
                              },
                            ),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notificaciones REDIR',
          onPressed: _abrir,
        ),
        if (_noLeidas > 0)
          Positioned(
            right: -4,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                _noLeidas > 99 ? '99+' : '$_noLeidas',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}