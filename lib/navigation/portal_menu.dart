import 'package:flutter/material.dart';

// Módulos disponibles en producción.
const bool moduloRRHHHabilitado = false;

class PortalAccess {
  final String label;
  final String grupo;
  final IconData icon;

  const PortalAccess(this.label, this.grupo, this.icon);
}

typedef PermisoFn = bool Function(String codigo, {String? id});

List<PortalAccess> buildPortalAccesses({required PermisoFn tiene}) {
  final accesos = <PortalAccess>[];

  if (tiene('VER_COMUNICADOS') || tiene('GESTIONAR_COMUNICADOS')) {
    accesos.add(
      const PortalAccess('Comunicados', 'Comunicados', Icons.campaign_outlined),
    );
  }
  if (tiene('GESTIONAR_COMUNICADOS')) {
    accesos.add(
      const PortalAccess(
        'Administrar Comunicados',
        'Comunicados',
        Icons.edit_note_rounded,
      ),
    );
  }

  if (tiene('CORTES_PLUZ')) {
    accesos.add(
      const PortalAccess('Cortes Pluz', 'Cortes Pluz', Icons.bolt_rounded),
    );
  }

  if (moduloRRHHHabilitado) {
    if (tiene('MIS_BOLETAS', id: '6')) {
      accesos.add(
        const PortalAccess(
          'Mis Boletas',
          'Recursos Humanos',
          Icons.description_outlined,
        ),
      );
    }
    if (tiene('BOLETAS_PENDIENTES', id: '8') ||
        tiene('BOLETAS PENDIENTES', id: '8')) {
      accesos.add(
        const PortalAccess(
          'Boletas Pendientes',
          'Recursos Humanos',
          Icons.pending_actions_rounded,
        ),
      );
    }
    if (tiene('SUBIR_ZIP', id: '7')) {
      accesos.add(
        const PortalAccess(
          'Subir ZIP',
          'Recursos Humanos',
          Icons.upload_file_rounded,
        ),
      );
    }
  }

  if (tiene('CONSULTAR_REPORTES', id: '1')) {
    accesos.add(
      const PortalAccess(
        'Reporte de Prueba',
        'Reportes',
        Icons.bar_chart_rounded,
      ),
    );
  }
  if (tiene('REPORTE_CONSOLIDADO')) {
    accesos.add(
      const PortalAccess(
        'Reporte Consolidado',
        'Reportes',
        Icons.receipt_long_rounded,
      ),
    );
    accesos.add(
      const PortalAccess(
        'Reporte Detalle Anual',
        'Reportes',
        Icons.calendar_month_rounded,
      ),
    );
  }
  if (tiene('REPORTE_CONSUMO', id: '12')) {
    accesos.add(
      const PortalAccess(
        'Reporte Consumo',
        'Reportes',
        Icons.table_chart_rounded,
      ),
    );
  }
  if (tiene('CONSULTAR_VENTAS')) {
    accesos.add(
      const PortalAccess(
        'Reporte por Líneas de Venta',
        'Reportes',
        Icons.receipt_long_rounded,
      ),
    );
  }
  if (tiene('CONSULTAR_COMPRAS')) {
    accesos.add(
      const PortalAccess(
        'Reporte de Órdenes de Compra',
        'Reportes',
        Icons.shopping_cart_checkout_rounded,
      ),
    );
  }
  if (tiene('VER_ESTADISTICAS_TARJETA')) {
    accesos.add(
      const PortalAccess(
        'Estadísticas Tarjetas',
        'Reportes',
        Icons.insights_rounded,
      ),
    );
  }
  if (tiene('REPORTE_CXC')) {
    accesos.add(
      const PortalAccess(
        'Cuentas por Cobrar Vencidas',
        'Reportes',
        Icons.payments_outlined,
      ),
    );
  }
  if (tiene('REPORTE_GRUPOS_ELECTROGENOS')) {
    accesos.add(
      const PortalAccess('Grupos Electrógenos', 'Reportes', Icons.bolt_rounded),
    );
  }

  if (tiene('MIS_OT')) {
    accesos.add(
      const PortalAccess(
        'Mis Órdenes de Trabajo',
        'Operaciones',
        Icons.assignment_rounded,
      ),
    );
  }

  if (tiene('IMPORTAR_OC', id: '11')) {
    accesos.add(
      const PortalAccess(
        'Importar OC',
        'Herramientas',
        Icons.shopping_cart_checkout_rounded,
      ),
    );
  }
  if (tiene('IMPORTAR_ALMACEN', id: '4')) {
    accesos.add(
      const PortalAccess(
        'Importar Almacén',
        'Herramientas',
        Icons.inventory_2_rounded,
      ),
    );
  }
  if (tiene('IMPORTAR_PR', id: '5') || tiene('IMPORTAR_SOLPED', id: '5')) {
    accesos.add(
      const PortalAccess(
        'Importar Solicitudes de Compra',
        'Herramientas',
        Icons.assignment_add,
      ),
    );
  }

  if (tiene('CREAR_RDR')) {
    accesos.add(
      const PortalAccess(
        'Registrar REDIR',
        'REDIR',
        Icons.add_comment_outlined,
      ),
    );
  }
  if (tiene('CONSULTAR_RDR')) {
    accesos.add(
      const PortalAccess('Consultar REDIR', 'REDIR', Icons.fact_check_outlined),
    );
  }

  if (tiene('CREAR_TICKET')) {
    accesos.add(
      const PortalAccess(
        'Registrar Ticket',
        'Tickets',
        Icons.add_comment_outlined,
      ),
    );
  }
  if (tiene('CONSULTAR_TICKET')) {
    accesos.add(
      const PortalAccess(
        'Consultar Tickets',
        'Tickets',
        Icons.confirmation_number_outlined,
      ),
    );
  }
  if (tiene('ADMIN_TICKETS')) {
    accesos.add(
      const PortalAccess(
        'Configurar Tickets',
        'Tickets',
        Icons.settings_suggest_outlined,
      ),
    );
  }

  if (tiene('GESTION_RUC')) {
    accesos.add(
      const PortalAccess(
        'Verificación RUC',
        'Proveedores',
        Icons.fact_check_outlined,
      ),
    );
  }

  if (tiene('VOTAR_ELECCIONES')) {
    accesos.add(
      const PortalAccess(
        'Mis Encuestas',
        'Encuesta',
        Icons.how_to_vote_outlined,
      ),
    );
    accesos.add(
      const PortalAccess(
        'Mis Postulaciones',
        'Encuesta',
        Icons.how_to_reg_outlined,
      ),
    );
  }
  if (tiene('GESTIONAR_ELECCIONES')) {
    accesos.add(
      const PortalAccess(
        'Administrar Encuestas',
        'Encuesta',
        Icons.ballot_outlined,
      ),
    );
  }

  if (tiene('USUARIOS', id: '9')) {
    accesos.add(
      const PortalAccess('Usuarios', 'Accesos', Icons.group_outlined),
    );
  }
  if (tiene('ROLES', id: '10')) {
    accesos.add(
      const PortalAccess('Roles', 'Accesos', Icons.security_outlined),
    );
    accesos.add(
      const PortalAccess(
        'Áreas y módulos',
        'Accesos',
        Icons.account_tree_outlined,
      ),
    );
    accesos.add(
      const PortalAccess('Auditoría', 'Accesos', Icons.manage_search_outlined),
    );
  }

  return accesos;
}

Map<String, List<PortalAccess>> agruparAccesos(List<PortalAccess> accesos) {
  final grupos = <String, List<PortalAccess>>{};
  for (final acceso in accesos) {
    grupos.putIfAbsent(acceso.grupo, () => []).add(acceso);
  }
  return grupos;
}

IconData iconoGrupoPortal(String grupo) {
  switch (grupo) {
    case 'Comunicados':
      return Icons.campaign_outlined;
    case 'Cortes Pluz':
      return Icons.bolt_rounded;
    case 'Recursos Humanos':
      return Icons.badge_outlined;
    case 'Reportes':
      return Icons.bar_chart_rounded;
    case 'Operaciones':
      return Icons.assignment_rounded;
    case 'Herramientas':
      return Icons.build_outlined;
    case 'REDIR':
      return Icons.fact_check_outlined;
    case 'Tickets':
      return Icons.confirmation_number_outlined;
    case 'Proveedores':
      return Icons.verified_user_outlined;
    case 'Encuesta':
      return Icons.how_to_vote_outlined;
    case 'Accesos':
      return Icons.admin_panel_settings_outlined;
    default:
      return Icons.folder_outlined;
  }
}
