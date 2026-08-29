import 'package:flutter/material.dart';

import '../design_system/luvegi_card.dart';
import '../services/dashboard_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

class DashboardPage extends StatefulWidget {
  final String token;
  final String nombre;
  final String rol;
  final List<String> permisos;
  final Function(String) onNavigate;

  const DashboardPage({
    super.key,
    required this.token,
    required this.nombre,
    required this.rol,
    required this.permisos,
    required this.onNavigate,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();

  bool _cargando = true;
  String? _error;
  int _usuariosRegistrados = 0;

  bool get _esAdminSistema => widget.permisos.any(
        (permiso) => permiso.trim().toUpperCase() == 'ADMIN_SISTEMA',
      );

  @override
  void initState() {
    super.initState();
    if (_esAdminSistema) {
      _cargarUsuarios();
    } else {
      _cargando = false;
    }
  }

  Future<void> _cargarUsuarios() async {
    // Los usuarios sin administración general no deben consultar esta cifra.
    if (!_esAdminSistema) return;
    if (!mounted) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final stats = await _dashboardService.getStats(widget.token);

      if (!mounted) return;

      setState(() {
        _usuariosRegistrados = int.tryParse(
              stats['usuarios']?.toString() ?? '0',
            ) ??
            0;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool mobile = width < 760;
    final double horizontalPadding =
        mobile ? LuvegiSpacing.md : LuvegiSpacing.xl;

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      body: RefreshIndicator(
        color: LuvegiColors.secondary,
        onRefresh: () async {
          if (_esAdminSistema) await _cargarUsuarios();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            LuvegiSpacing.lg,
            horizontalPadding,
            LuvegiSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeBanner(mobile),
                  const SizedBox(height: LuvegiSpacing.xl),

                  if (_esAdminSistema) ...[
                    Text(
                      'Resumen del Sistema',
                      style: LuvegiText.heading.copyWith(
                        fontSize: 22,
                        color: LuvegiColors.secondary,
                      ),
                    ),
                    const SizedBox(height: LuvegiSpacing.md),
                    if (_error != null) ...[
                      _buildErrorCard(),
                      const SizedBox(height: LuvegiSpacing.md),
                    ],
                    _buildUsersCard(mobile),
                    const SizedBox(height: 64),
                  ] else
                    const SizedBox(height: LuvegiSpacing.xl),

                  _buildSecurityCard(mobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(bool mobile) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: mobile ? 22 : 32,
      vertical: mobile ? 22 : 26,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFFE8E8E8),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeText(mobile),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildRoleBadge(),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _buildWelcomeText(mobile),
              ),
              _buildRoleBadge(),
            ],
          ),
  );
}
 Widget _buildWelcomeText(bool mobile) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Bienvenido, ${widget.nombre}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LuvegiText.display.copyWith(
          fontSize: mobile ? 24 : 30,
          fontWeight: FontWeight.w700,
          color: LuvegiColors.textPrimary,
        ),
      ),

      const SizedBox(height: 6),

      Text(
        'Portal LUVEGI · Plataforma Corporativa',
        style: LuvegiText.body.copyWith(
          color: LuvegiColors.textSecondary,
          fontSize: mobile ? 14 : 15,
        ),
      ),
    ],
  );
}
  Widget _buildRoleBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 8,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7F3),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: LuvegiColors.success.withOpacity(.35),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: LuvegiColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          widget.rol.toUpperCase(),
          style: LuvegiText.label.copyWith(
            color: LuvegiColors.success,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
      ],
    ),
  );
}
  Widget _buildUsersCard(bool mobile) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: mobile ? double.infinity : 280,
        child: LuvegiCard(
          padding: const EdgeInsets.all(LuvegiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: LuvegiColors.secondary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: LuvegiColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(height: LuvegiSpacing.md),
              Text(
                _cargando ? '...' : '$_usuariosRegistrados',
                style: LuvegiText.display.copyWith(
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: LuvegiSpacing.xs),
              Text(
                'Usuarios registrados',
                style: LuvegiText.body.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityCard(bool mobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        mobile ? LuvegiSpacing.lg : LuvegiSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(
          color: LuvegiColors.info.withOpacity(0.55),
          width: 1.4,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: LuvegiColors.menuHover,
              borderRadius: BorderRadius.circular(LuvegiRadius.md),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: LuvegiColors.secondary,
              size: 27,
            ),
          ),
          const SizedBox(width: LuvegiSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus datos están protegidos',
                  style: TextStyle(
                    color: LuvegiColors.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: LuvegiSpacing.xs),
                Text(
                  'Este portal garantiza que solo tú puedas acceder a tu información de forma segura.',
                  style: TextStyle(
                    color: LuvegiColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(
          color: LuvegiColors.warning.withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: LuvegiColors.warning,
          ),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Text(
              'No se pudo actualizar el total de usuarios. ${_error ?? ''}',
              style: LuvegiText.body.copyWith(
                color: LuvegiColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
