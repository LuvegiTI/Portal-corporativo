import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../design_system/luvegi_card.dart';
import '../services/auditoria_service.dart';
import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_shadows.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';
import '../utils/mensaje_error.dart';

class AdminAuditoriaPage extends StatefulWidget {
  final String token;

  const AdminAuditoriaPage({super.key, required this.token});

  @override
  State<AdminAuditoriaPage> createState() => _AdminAuditoriaPageState();
}

class _AdminAuditoriaPageState extends State<AdminAuditoriaPage> {
  final AuditoriaService _api = AuditoriaService();

  final TextEditingController _desdeCtrl = TextEditingController();
  final TextEditingController _hastaCtrl = TextEditingController();

  String _tipo = 'actividad';
  String _accionFiltro = '';
  List<String> _acciones = [];
  List<String> _usuariosDisponibles = [];
  String _usuarioFiltro = '';

  bool _cargando = false;
  String? _error;
  List<Map<String, dynamic>> _registros = [];
  List<Map<String, dynamic>> _logins = [];
  int _total = 0;
  int _pagina = 1;
  int _totalPaginas = 1;
  static const int _pageSize = 20;

  int get _exitos => _logins.where((r) => r['exito']?.toString() == '1').length;

  int get _fallos => _logins.length - _exitos;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
    _cargar();
  }

  @override
  void dispose() {
    _desdeCtrl.dispose();
    _hastaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    try {
      final usuarios = await _api.listarUsuarios(widget.token);
      if (!mounted) return;
      setState(() => _usuariosDisponibles = usuarios);
    } catch (_) {}
  }

  Future<void> _cargar({int pagina = 1}) async {
    setState(() {
      _cargando = true;
      _error = null;
      _pagina = pagina;
    });
    try {
      final data = await _api.consultar(
        widget.token,
        tipo: _tipo,
        usuario: _usuarioFiltro,
        desde: _desdeCtrl.text.trim(),
        hasta: _hastaCtrl.text.trim(),
        accion: _accionFiltro,
        page: pagina,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        final raw = data['registros'];
        final registros = raw is List
            ? raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : <Map<String, dynamic>>[];
        if (_tipo == 'login') {
          _logins = registros;
          _registros = [];
        } else {
          _registros = registros;
          _logins = [];
          _acciones = data['acciones'] is List
              ? data['acciones'].whereType<String>().toList()
              : _acciones;
        }
        _total = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
        _totalPaginas =
            int.tryParse(data['total_paginas']?.toString() ?? '1') ?? 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _seleccionarTipo(String tipo) {
    if (_tipo == tipo) return;
    setState(() {
      _tipo = tipo;
      _accionFiltro = '';
    });
    _cargar(pagina: 1);
  }

  Future<void> _elegirFecha(TextEditingController ctrl) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Selecciona la fecha',
    );
    if (picked == null) return;
    setState(() {
      ctrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
    _cargar(pagina: 1);
  }

  // ============================================================
  // CABECERA
  // ============================================================

  PreferredSize _appBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: AppBar(
        backgroundColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        elevation: 0,
        titleSpacing: LuvegiSpacing.md,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: LuvegiColors.secondary,
                borderRadius: BorderRadius.circular(LuvegiRadius.md),
              ),
              child: const Icon(
                Icons.manage_search_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: LuvegiSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Auditoría', style: LuvegiText.title),
                  Text(
                    'Bitácora de actividad e inicios de sesión',
                    style: LuvegiText.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: () => _cargar(pagina: _pagina),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: LuvegiSpacing.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: LuvegiColors.divider),
        ),
      ),
    );
  }

  // ============================================================
  // TABS SEGMENTADOS
  // ============================================================

  Widget _segmentos() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: LuvegiColors.border),
        boxShadow: LuvegiShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmento('Actividad', 'actividad', Icons.history_rounded),
          _segmento('Inicios de sesión', 'login', Icons.login_rounded),
        ],
      ),
    );
  }

  Widget _segmento(String label, String valor, IconData icon) {
    final seleccionado = _tipo == valor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: seleccionado ? LuvegiColors.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: seleccionado ? LuvegiShadows.card : null,
      ),
      child: InkWell(
        onTap: () => _seleccionarTipo(valor),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LuvegiSpacing.lg,
            vertical: 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: seleccionado ? Colors.white : LuvegiColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: LuvegiText.caption.copyWith(
                  color: seleccionado ? Colors.white : LuvegiColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESUMEN (tarjetas de estadísticas)
  // ============================================================

  Widget _resumen() {
    final esLogin = _tipo == 'login';
    return Row(
      children: [
        _miniStat(
          icon: Icons.receipt_long_rounded,
          label: 'Registros',
          color: LuvegiColors.secondary,
          value: Text('$_total', style: LuvegiText.title),
        ),
        const SizedBox(width: LuvegiSpacing.sm),
        _miniStat(
          icon: Icons.menu_book_rounded,
          label: 'Página',
          color: LuvegiColors.info,
          value: Text('$_pagina / $_totalPaginas', style: LuvegiText.title),
        ),
        const SizedBox(width: LuvegiSpacing.sm),
        if (esLogin) ...[
          _miniStat(
            icon: Icons.done_all_rounded,
            label: 'Resultado (vista)',
            color: LuvegiColors.success,
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _puntoColor(LuvegiColors.success),
                const SizedBox(width: 4),
                Text('$_exitos', style: LuvegiText.title),
                const SizedBox(width: 10),
                _puntoColor(LuvegiColors.error),
                const SizedBox(width: 4),
                Text('$_fallos', style: LuvegiText.title),
              ],
            ),
          ),
        ] else ...[
          _miniStat(
            icon: Icons.category_rounded,
            label: 'Acciones',
            color: LuvegiColors.warning,
            value: Text('${_acciones.length}', style: LuvegiText.title),
          ),
        ],
      ],
    );
  }

  Widget _puntoColor(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String label,
    required Widget value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LuvegiSpacing.md,
          vertical: LuvegiSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: LuvegiColors.surface,
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
          border: Border.all(color: LuvegiColors.border),
          boxShadow: LuvegiShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(LuvegiRadius.sm),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: LuvegiSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: LuvegiText.caption),
                  const SizedBox(height: 1),
                  value,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTROS
  // ============================================================

  Widget _buildFiltros(bool compacto) {
    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
        boxShadow: LuvegiShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_rounded,
                size: 17,
                color: LuvegiColors.textSecondary,
              ),
              const SizedBox(width: LuvegiSpacing.sm),
              Text('Filtros', style: LuvegiText.label),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.sm + 4),
          if (compacto) ...[
            _filaUsuario(),
            const SizedBox(height: LuvegiSpacing.sm),
            Row(
              children: [
                _botonFecha(_desdeCtrl, 'Desde', Icons.calendar_month_outlined),
                const SizedBox(width: LuvegiSpacing.sm),
                _botonFecha(_hastaCtrl, 'Hasta', Icons.calendar_today_outlined),
              ],
            ),
            if (_tipo == 'actividad') ...[
              const SizedBox(height: LuvegiSpacing.sm),
              _filaAccion(),
            ],
          ] else ...[
            Row(
              children: [
                _filaUsuario(),
                if (_tipo == 'actividad') ...[
                  const SizedBox(width: LuvegiSpacing.sm),
                  _filaAccion(),
                ],
                const SizedBox(width: LuvegiSpacing.sm),
                _botonFecha(_desdeCtrl, 'Desde', Icons.calendar_month_outlined),
                const SizedBox(width: LuvegiSpacing.sm),
                _botonFecha(_hastaCtrl, 'Hasta', Icons.calendar_today_outlined),
              ],
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _decoracion(String label, {Widget? prefijo, Widget? sufijo}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefijo,
      suffixIcon: sufijo,
      filled: true,
      fillColor: LuvegiColors.surfaceHover,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        borderSide: const BorderSide(color: LuvegiColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        borderSide: const BorderSide(color: LuvegiColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        borderSide: const BorderSide(color: LuvegiColors.secondary, width: 1.5),
      ),
    );
  }

  Widget _filaUsuario() {
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: _usuarioFiltro.isEmpty ? null : _usuarioFiltro,
        isExpanded: true,
        decoration: _decoracion('Usuario'),
        icon: const Icon(Icons.arrow_drop_down_rounded),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text(
              'Todos los usuarios',
              style: TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ..._usuariosDisponibles.map(
            (u) => DropdownMenuItem<String>(
              value: u.toString(),
              child: Text(
                u.toString(),
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (v) {
          setState(() => _usuarioFiltro = v ?? '');
          _cargar(pagina: 1);
        },
      ),
    );
  }

  Widget _filaAccion() {
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: _accionFiltro.isEmpty ? null : _accionFiltro,
        decoration: _decoracion('Acción'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todas')),
          ..._acciones.map((a) => DropdownMenuItem(value: a, child: Text(a))),
        ],
        onChanged: (v) {
          setState(() => _accionFiltro = v ?? '');
          _cargar(pagina: 1);
        },
      ),
    );
  }

  Widget _botonFecha(TextEditingController ctrl, String label, IconData icon) {
    return Expanded(
      child: InkWell(
        onTap: () => _elegirFecha(ctrl),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LuvegiSpacing.md,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: LuvegiColors.surfaceHover,
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            border: Border.all(
              color: ctrl.text.isNotEmpty
                  ? LuvegiColors.secondary
                  : LuvegiColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: ctrl.text.isNotEmpty
                    ? LuvegiColors.secondary
                    : LuvegiColors.textHint,
                size: 18,
              ),
              const SizedBox(width: LuvegiSpacing.sm),
              Expanded(
                child: Text(
                  ctrl.text.isEmpty ? label : ctrl.text,
                  overflow: TextOverflow.ellipsis,
                  style: LuvegiText.body.copyWith(
                    color: ctrl.text.isEmpty
                        ? LuvegiColors.textHint
                        : LuvegiColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    ctrl.clear();
                    _cargar(pagina: 1);
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: LuvegiColors.textHint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABLAS
  // ============================================================

  Color _colorAccion(String accion) {
    final a = accion.toUpperCase();
    if (a.contains('LOGIN') || a.contains('INICIO')) {
      return LuvegiColors.info;
    }
    if (a.contains('IMPORTAR')) {
      return LuvegiColors.success;
    }
    if (a.contains('REDIR')) {
      return LuvegiColors.warning;
    }
    if (a.contains('PERMISO') ||
        a.contains('PASSWORD') ||
        a.contains('USUARIO')) {
      return LuvegiColors.info;
    }
    if (a.contains('AREA') || a.contains('ROL')) {
      return LuvegiColors.primary;
    }
    return LuvegiColors.secondary;
  }

  Widget _badgeAction(String? accion) {
    final texto = accion?.toString() ?? '—';
    final color = _colorAccion(texto);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        texto,
        style: LuvegiText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _wrapTable(Widget table) {
    return LuvegiCard(
      padding: EdgeInsets.zero,
      backgroundColor: LuvegiColors.surface,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        child: table,
      ),
    );
  }

  DataRow _filaSimple(int index, List<Widget> celdas, {Color? color}) {
    return DataRow(
      color: WidgetStatePropertyAll(
        index.isOdd ? LuvegiColors.surfaceHover : Colors.white,
      ),
      cells: [for (final c in celdas) DataCell(c)],
    );
  }

  Widget _buildActividadTable(bool compacto) {
    final filas = _registros;
    return LayoutBuilder(
      builder: (context, constraints) {
        return _wrapTable(
          SizedBox(
            width: constraints.maxWidth,
            child: DataTable2(
              headingRowColor: WidgetStatePropertyAll(
                LuvegiColors.secondary.withValues(alpha: 0.06),
              ),
              headingTextStyle: LuvegiText.label.copyWith(
                color: LuvegiColors.secondary,
              ),
              dataTextStyle: LuvegiText.body.copyWith(fontSize: 13),
              columns: const [
                DataColumn2(label: Text('Fecha'), size: ColumnSize.S),
                DataColumn2(label: Text('Usuario'), size: ColumnSize.S),
                DataColumn2(label: Text('Acción'), size: ColumnSize.S),
                DataColumn2(label: Text('Entidad'), size: ColumnSize.S),
                DataColumn2(label: Text('Detalle'), size: ColumnSize.L),
                DataColumn2(label: Text('IP'), size: ColumnSize.S),
              ],
              rows: [
                for (var i = 0; i < filas.length; i++) ...[
                  _filaSimple(i, [
                    Text(
                      _fmtFecha(filas[i]['creado_en']),
                      style: LuvegiText.body.copyWith(
                        fontSize: 13,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                    Text(
                      filas[i]['usuario']?.toString() ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    GestureDetector(
                      onTap: () => _abrirDetalle(filas[i]),
                      child: _badgeAction(filas[i]['accion']?.toString()),
                    ),
                    Text(
                      filas[i]['entidad']?.toString() ?? '—',
                      style: LuvegiText.body.copyWith(
                        fontSize: 13,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                    Text(
                      filas[i]['detalle']?.toString() ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      filas[i]['ip']?.toString() ?? '—',
                      style: LuvegiText.body.copyWith(
                        fontSize: 13,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                  ], color: LuvegiColors.secondary.withValues(alpha: 0.15)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginTable(bool compacto) {
    final filas = _logins;
    return LayoutBuilder(
      builder: (context, constraints) {
        return _wrapTable(
          SizedBox(
            width: constraints.maxWidth,
            child: DataTable2(
              headingRowColor: WidgetStatePropertyAll(
                LuvegiColors.secondary.withValues(alpha: 0.06),
              ),
              headingTextStyle: LuvegiText.label.copyWith(
                color: LuvegiColors.secondary,
              ),
              dataTextStyle: LuvegiText.body.copyWith(fontSize: 13),
              columns: const [
                DataColumn2(label: Text('Fecha'), size: ColumnSize.S),
                DataColumn2(label: Text('Usuario'), size: ColumnSize.S),
                DataColumn2(label: Text('Resultado'), size: ColumnSize.S),
                DataColumn2(label: Text('Motivo'), size: ColumnSize.L),
                DataColumn2(label: Text('IP'), size: ColumnSize.S),
                DataColumn2(label: Text('Dispositivo'), size: ColumnSize.S),
              ],
              rows: [
                for (var i = 0; i < filas.length; i++) ...[
                  _filaSimple(i, [
                    Text(
                      _fmtFecha(filas[i]['creado_en']),
                      style: LuvegiText.body.copyWith(
                        fontSize: 13,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                    Text(
                      filas[i]['usuario']?.toString() ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    _badgeResultado(filas[i]),
                    Text(
                      filas[i]['motivo']?.toString() ?? '—',
                      style: LuvegiText.body.copyWith(
                        fontSize: 13,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                    Text(
                      filas[i]['ip']?.toString() ?? '—',
                      style: LuvegiText.body.copyWith(
                        fontSize: 13,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                    Text(
                      filas[i]['dispositivo']?.toString() ?? '—',
                      style: LuvegiText.body.copyWith(
                        fontSize: 13,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _badgeResultado(Map<String, dynamic> r) {
    final exito = r['exito']?.toString() == '1';
    final color = exito ? LuvegiColors.success : LuvegiColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            exito ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            exito ? 'Éxito' : 'Fallo',
            style: LuvegiText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TARJETAS MÓVILES
  // ============================================================

  Widget _buildActividadCards() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
      itemCount: _registros.length,
      separatorBuilder: (_, __) => const SizedBox(height: LuvegiSpacing.sm),
      itemBuilder: (context, i) {
        final r = _registros[i];
        return LuvegiCard(
          padding: const EdgeInsets.all(LuvegiSpacing.md),
          onTap: () => _abrirDetalle(r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fmtFecha(r['creado_en']),
                      style: LuvegiText.caption,
                    ),
                  ),
                  _badgeAction(r['accion']?.toString()),
                ],
              ),
              const SizedBox(height: LuvegiSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 16,
                    color: LuvegiColors.textHint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r['usuario']?.toString() ?? '—',
                      style: LuvegiText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if ((r['entidad']?.toString() ?? '').isNotEmpty)
                    Text(
                      r['entidad'].toString(),
                      style: LuvegiText.caption.copyWith(
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                ],
              ),
              if ((r['detalle']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  r['detalle'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LuvegiText.bodySecondary.copyWith(fontSize: 13),
                ),
              ],
              const SizedBox(height: LuvegiSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 14,
                    color: LuvegiColors.textHint,
                  ),
                  const SizedBox(width: 5),
                  Text(r['ip']?.toString() ?? '—', style: LuvegiText.caption),
                  const Spacer(),
                  Text(
                    'Ver detalle',
                    style: LuvegiText.caption.copyWith(
                      color: LuvegiColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: LuvegiColors.secondary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginCards() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
      itemCount: _logins.length,
      separatorBuilder: (_, __) => const SizedBox(height: LuvegiSpacing.sm),
      itemBuilder: (context, i) {
        final r = _logins[i];
        return LuvegiCard(
          padding: const EdgeInsets.all(LuvegiSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fmtFecha(r['creado_en']),
                      style: LuvegiText.caption,
                    ),
                  ),
                  _badgeResultado(r),
                ],
              ),
              const SizedBox(height: LuvegiSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 16,
                    color: LuvegiColors.textHint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r['usuario']?.toString() ?? '—',
                      style: LuvegiText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if ((r['motivo']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  r['motivo'].toString(),
                  style: LuvegiText.bodySecondary.copyWith(fontSize: 13),
                ),
              ],
              const SizedBox(height: LuvegiSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 14,
                    color: LuvegiColors.textHint,
                  ),
                  const SizedBox(width: 5),
                  Text(r['ip']?.toString() ?? '—', style: LuvegiText.caption),
                  const Spacer(),
                  const Icon(
                    Icons.phone_android_rounded,
                    size: 14,
                    color: LuvegiColors.textHint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    r['dispositivo']?.toString() ?? '—',
                    style: LuvegiText.caption,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // ESTADOS (vacío / error / carga)
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: LuvegiColors.menuHover,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 34,
              color: LuvegiColors.secondary,
            ),
          ),
          const SizedBox(height: LuvegiSpacing.md),
          Text('Sin registros', style: LuvegiText.title),
          const SizedBox(height: LuvegiSpacing.xs),
          const Text(
            'No hay datos con los filtros seleccionados.\nCambia la fecha o los filtros.',
            textAlign: TextAlign.center,
            style: LuvegiText.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: LuvegiColors.error,
            size: 20,
          ),
          const SizedBox(width: LuvegiSpacing.sm + 4),
          Expanded(
            child: Text(
              _error!,
              style: LuvegiText.body.copyWith(color: LuvegiColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCargando() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LuvegiSpacing.xl,
          vertical: LuvegiSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: LuvegiColors.surface,
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
          border: Border.all(color: LuvegiColors.border),
          boxShadow: LuvegiShadows.card,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: LuvegiColors.secondary,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(width: LuvegiSpacing.md),
            Text('Consultando bitácora…', style: LuvegiText.body),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAGINACIÓN
  // ============================================================

  Widget _paginacion() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$_total registro(s) · Página $_pagina de $_totalPaginas',
          style: LuvegiText.caption,
        ),
        Row(
          children: [
            _botonPagina(
              icon: Icons.chevron_left_rounded,
              habilitado: _pagina > 1,
              onTap: () => _cargar(pagina: _pagina - 1),
            ),
            const SizedBox(width: LuvegiSpacing.sm),
            _botonPagina(
              icon: Icons.chevron_right_rounded,
              habilitado: _pagina < _totalPaginas,
              onTap: () => _cargar(pagina: _pagina + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _botonPagina({
    required IconData icon,
    required bool habilitado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: habilitado ? onTap : null,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: habilitado
              ? LuvegiColors.secondary
              : LuvegiColors.surfaceHover,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: habilitado ? LuvegiColors.secondary : LuvegiColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: habilitado ? Colors.white : LuvegiColors.textHint,
        ),
      ),
    );
  }

  // ============================================================
  // DETALLE
  // ============================================================

  void _abrirDetalle(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: LuvegiColors.menuHover,
                borderRadius: BorderRadius.circular(LuvegiRadius.sm),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: LuvegiColors.secondary,
              ),
            ),
            const SizedBox(width: LuvegiSpacing.sm + 4),
            const Text('Detalle del evento'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detalleFila('Fecha', _fmtFecha(r['creado_en'])),
              _detalleFila('Usuario', r['usuario']?.toString() ?? '—'),
              _detalleFila('Acción', r['accion']?.toString() ?? '—'),
              _detalleFila('Entidad', r['entidad']?.toString() ?? '—'),
              _detalleFila('IP', r['ip']?.toString() ?? '—'),
              const Divider(height: 24),
              Text(
                'DETALLE',
                style: LuvegiText.label.copyWith(color: LuvegiColors.secondary),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(LuvegiSpacing.md),
                decoration: BoxDecoration(
                  color: LuvegiColors.surfaceHover,
                  borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                ),
                child: Text(
                  r['detalle']?.toString() ?? '—',
                  style: LuvegiText.body,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: LuvegiColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _detalleFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: LuvegiText.caption.copyWith(
                color: LuvegiColors.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: LuvegiText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtFecha(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(dt.day)}/${dos(dt.month)}/${dt.year} '
        '${dos(dt.hour)}:${dos(dt.minute)}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).width < 800;

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: _appBar(),
      body: Padding(
        padding: EdgeInsets.all(compacto ? LuvegiSpacing.md : LuvegiSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _segmentos(),
            const SizedBox(height: LuvegiSpacing.md),
            _resumen(),
            const SizedBox(height: LuvegiSpacing.md),
            _buildFiltros(compacto),
            if (_error != null) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _buildError(),
            ],
            const SizedBox(height: LuvegiSpacing.md),
            Expanded(
              child: _cargando
                  ? _buildCargando()
                  : _tipo == 'login'
                  ? (_logins.isEmpty
                        ? _buildEmptyState()
                        : compacto
                        ? _buildLoginCards()
                        : _buildLoginTable(compacto))
                  : (_registros.isEmpty
                        ? _buildEmptyState()
                        : compacto
                        ? _buildActividadCards()
                        : _buildActividadTable(compacto)),
            ),
            if (_totalPaginas > 1 || _total > 0) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _paginacion(),
            ],
          ],
        ),
      ),
    );
  }
}
