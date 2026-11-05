import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/ruc_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';

class VerificacionRucPage extends StatefulWidget {
  final String token;

  const VerificacionRucPage({super.key, required this.token});

  @override
  State<VerificacionRucPage> createState() => _VerificacionRucPageState();
}

class _VerificacionRucPageState extends State<VerificacionRucPage> {
  final RucService _service = RucService();
  final TextEditingController _busquedaCtrl = TextEditingController();

  RucResumen _resumen = const RucResumen();
  List<RucControlItem> _items = [];
  bool _cargando = true;
  bool _refrescando = false;
  String _filtro = 'todos';
  String _q = '';
  int _page = 1;
  int _total = 0;
  static const int _pageSize = 40;
  String? _error;
  Timer? _debounce;
  final Set<int> _verificando = {};
  bool _ejecutando = false;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    if (!_refrescando) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final resultados = await Future.wait([
        _service.resumen(token: widget.token),
        _service.listar(
          token: widget.token,
          filtro: _filtro,
          q: _q,
          page: _page,
          pageSize: _pageSize,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _resumen = resultados[0] as RucResumen;
        final listado = resultados[1] as RucListado;
        _items = listado.items;
        _total = listado.total;
        _cargando = false;
        _refrescando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _refrescando = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _cargarListado({bool resetPagina = false}) async {
    if (resetPagina) _page = 1;
    setState(() => _refrescando = true);
    await _cargarTodo();
  }

  void _cambiarFiltro(String filtro) {
    if (_filtro == filtro) return;
    setState(() => _filtro = filtro);
    _cargarListado(resetPagina: true);
  }

  void _buscar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _q = valor.trim());
      _cargarListado(resetPagina: true);
    });
  }

  Future<void> _verificarAhora(RucControlItem item) async {
    if (_verificando.contains(item.partnerId)) return;
    setState(() => _verificando.add(item.partnerId));
    try {
      final resultado = await _service.verificar(
        token: widget.token,
        partnerId: item.partnerId,
      );
      if (!mounted) return;
      final detalle = <String>[
        if (resultado.estado.isNotEmpty) resultado.estado,
        if (resultado.condicion.isNotEmpty) resultado.condicion,
      ].join(' · ');
      _mostrarMensaje(
        resultado.alerta
            ? 'RUC con alerta: ${item.vat} ($detalle)'
            : 'RUC verificado: ${item.vat} ($detalle)',
        error: resultado.alerta,
      );
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _verificando.remove(item.partnerId));
    }
  }

  Future<void> _verHistorial(RucControlItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LuvegiColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LuvegiRadius.lg),
        ),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: _HistorialSheet(
            service: _service,
            token: widget.token,
            item: item,
          ),
        );
      },
    );
  }

  void _mostrarMensaje(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? LuvegiColors.error : LuvegiColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int _aInt(dynamic valor) {
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? 0;
    return 0;
  }

  Future<void> _ejecutarVerificacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ejecutar verificación de RUC'),
        content: const Text(
          'Se sincronizará el padrón de proveedores con Odoo y se verificarán en SUNAT los proveedores pendientes de revisar (>= 15 días).\n\nEste proceso puede tardar varios minutos. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: LuvegiColors.secondary),
            child: const Text('Ejecutar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _ejecutando = true);

    try {
      final res = await _service.ejecutarVerificacion(
        token: widget.token,
        limite: 50,
      );
      if (!mounted) return;

      final procesados = _aInt(res['procesados']);
      final alertas = _aInt(res['alertas']);
      final errores = _aInt(res['errores']);
      final pendientes = _aInt(res['pendientes']);
      final sincronizados = _aInt(res['sincronizados']);

      String msg = 'Finalizado: $procesados procesados';
      if (sincronizados > 0) msg += ' | $sincronizados proveedores sincronizados';
      if (alertas > 0) msg += ' | $alertas alertas';
      if (errores > 0) msg += ' | $errores errores';
      if (pendientes > 0) msg += ' | $pendientes pendientes';

      _mostrarMensaje(msg, error: alertas > 0 || errores > 0);
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _ejecutando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;

    return ColoredBox(
      color: LuvegiColors.background,
      child: RefreshIndicator(
        onRefresh: () => _cargarListado(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(mobile ? LuvegiSpacing.md : LuvegiSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1350),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(mobile),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _buildResumen(),
                  const SizedBox(height: LuvegiSpacing.md),
                  _buildAviso(),
                  const SizedBox(height: LuvegiSpacing.md),
                  _buildFiltros(),
                  const SizedBox(height: LuvegiSpacing.md),
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: LuvegiSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    _buildError()
                  else if (_items.isEmpty)
                    _buildVacio()
                  else
                    ..._items.map(_buildItem),
                  if (!_cargando && _error == null && _total > _pageSize)
                    _buildPaginacion(),
                  const SizedBox(height: LuvegiSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool mobile) {
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verificación de RUC', style: LuvegiText.heading),
        const SizedBox(height: 2),
        Text(
          'Control periódico de proveedores en SUNAT',
          style: LuvegiText.caption,
        ),
      ],
    );

    final botonEjecutar = OutlinedButton.icon(
      onPressed: _ejecutando ? null : _ejecutarVerificacion,
      icon: _ejecutando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow_rounded, size: 18),
      label: Text(_ejecutando ? 'Ejecutando...' : 'Ejecutar verificación'),
    );

    final boton = OutlinedButton.icon(
      onPressed: _refrescando ? null : () => _cargarListado(),
      icon: _refrescando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Actualizar'),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titulo,
          const SizedBox(height: LuvegiSpacing.md),
          SizedBox(width: double.infinity, child: botonEjecutar),
          const SizedBox(height: LuvegiSpacing.sm),
          SizedBox(width: double.infinity, child: boton),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titulo),
        botonEjecutar,
        const SizedBox(width: LuvegiSpacing.sm),
        boton,
      ],
    );
  }

  Widget _buildResumen() {
    final tarjetas = [
      _ResumenDato(
        titulo: 'Padrón',
        valor: '${_resumen.total}',
        icono: Icons.people_alt_outlined,
        color: LuvegiColors.secondary,
      ),
      _ResumenDato(
        titulo: 'Alertas',
        valor: '${_resumen.alertas}',
        icono: Icons.warning_amber_rounded,
        color: LuvegiColors.error,
      ),
      _ResumenDato(
        titulo: 'Pendientes',
        valor: '${_resumen.pendientes}',
        icono: Icons.schedule_rounded,
        color: LuvegiColors.warning,
      ),
      _ResumenDato(
        titulo: 'Últimas 24 h',
        valor: '${_resumen.ultimas24h}',
        icono: Icons.verified_outlined,
        color: LuvegiColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final ancho = (constraints.maxWidth - (columnas - 1) * 12) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tarjetas
              .map((dato) => SizedBox(width: ancho, child: _datoCard(dato)))
              .toList(),
        );
      },
    );
  }

  Widget _datoCard(_ResumenDato dato) {
    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: dato.color.withAlpha(24),
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            ),
            child: Icon(dato.icono, color: dato.color, size: 22),
          ),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dato.titulo, style: LuvegiText.caption),
                Text(
                  dato.valor,
                  style: LuvegiText.heading.copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAviso() {
    final dias = _resumen.diasEntreConsultas > 0
        ? _resumen.diasEntreConsultas
        : 15;
    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.info.withAlpha(14),
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.info.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: LuvegiColors.info, size: 20),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Text(
              'Cada proveedor con RUC se consulta en SUNAT vía Odoo cuando '
              'pasan $dias días desde su última verificación. Si el estado o '
              'la condición dejan de ser válidos, aparece aquí como alerta '
              '(SUNAT no acepta ese comprobante como costo o gasto).',
              style: LuvegiText.caption.copyWith(color: LuvegiColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    const filtros = {
      'todos': 'Todas',
      'alertas': 'Alertas',
      'pendientes': 'Pendientes',
      'verificados': 'Verificadas',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _busquedaCtrl,
          onChanged: (valor) {
            setState(() {});
            _buscar(valor);
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar por RUC o razón social',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _busquedaCtrl.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _busquedaCtrl.clear();
                      _buscar('');
                      setState(() {});
                    },
                  ),
            filled: true,
            fillColor: LuvegiColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
              borderSide: const BorderSide(color: LuvegiColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
              borderSide: const BorderSide(color: LuvegiColors.border),
            ),
          ),
        ),
        const SizedBox(height: LuvegiSpacing.sm),
        Wrap(
          spacing: LuvegiSpacing.sm,
          runSpacing: LuvegiSpacing.xs,
          children: filtros.entries.map((entry) {
            final seleccionado = _filtro == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: seleccionado,
              onSelected: (_) => _cambiarFiltro(entry.key),
              labelStyle: LuvegiText.caption.copyWith(
                color: seleccionado ? Colors.white : LuvegiColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: LuvegiColors.secondary,
              backgroundColor: LuvegiColors.surface,
              side: BorderSide(
                color: seleccionado
                    ? LuvegiColors.secondary
                    : LuvegiColors.border,
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildItem(RucControlItem item) {
    final verificando = _verificando.contains(item.partnerId);
    final colorEstado = _colorEstado(item);
    final actualizado = item.ultimaVerificacion.isEmpty
        ? 'Sin verificar'
        : _fecha(item.ultimaVerificacion);

    return Container(
      margin: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(
          color: item.alerta
              ? LuvegiColors.error.withAlpha(90)
              : LuvegiColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorEstado.withAlpha(22),
                  borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                ),
                child: Icon(
                  item.alerta
                      ? Icons.gpp_bad_outlined
                      : Icons.verified_user_outlined,
                  color: colorEstado,
                  size: 20,
                ),
              ),
              const SizedBox(width: LuvegiSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre.isEmpty ? 'Sin razón social' : item.nombre,
                      style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text('RUC ${item.vat}', style: LuvegiText.caption),
                  ],
                ),
              ),
              const SizedBox(width: LuvegiSpacing.sm),
              _chipEstado(
                item.estado.isEmpty ? 'SIN ESTADO' : item.estado,
                colorEstado,
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          Wrap(
            spacing: LuvegiSpacing.xs,
            runSpacing: LuvegiSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.condicion.isNotEmpty)
                _chipEstado(item.condicion, LuvegiColors.secondary),
              if (item.alerta)
                _chipEstado('ALERTA SUNAT', LuvegiColors.error),
              if (!item.alerta && item.ultimoResultado == 'CAMBIO')
                _chipEstado('CAMBIO', LuvegiColors.warning),
              if (item.ultimoResultado == 'ERROR')
                _chipEstado('ERROR', LuvegiColors.error),
            ],
          ),
          if (item.ultimoMensaje.isNotEmpty) ...[
            const SizedBox(height: LuvegiSpacing.xs),
            Text(
              item.ultimoMensaje,
              style: LuvegiText.caption.copyWith(color: LuvegiColors.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: LuvegiSpacing.sm),
          Wrap(
            spacing: LuvegiSpacing.sm,
            runSpacing: LuvegiSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Última verificación: $actualizado',
                style: LuvegiText.caption,
              ),
              TextButton.icon(
                onPressed: verificando ? null : () => _verHistorial(item),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Historial'),
              ),
              FilledButton.icon(
                onPressed: verificando ? null : () => _verificarAhora(item),
                style: FilledButton.styleFrom(
                  backgroundColor: LuvegiColors.secondary,
                  foregroundColor: Colors.white,
                ),
                icon: verificando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(verificando ? 'Verificando…' : 'Verificar ahora'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipEstado(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        texto,
        style: LuvegiText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _colorEstado(RucControlItem item) {
    if (item.alerta) return LuvegiColors.error;
    final estado = item.estado.toUpperCase();
    if (estado == 'ACTIVO') return LuvegiColors.success;
    if (estado.isEmpty) return LuvegiColors.textHint;
    return LuvegiColors.warning;
  }

  Widget _buildPaginacion() {
    final totalPaginas = (_total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: LuvegiSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Anterior',
            onPressed: _page <= 1 || _refrescando
                ? null
                : () {
                    _page--;
                    _cargarListado();
                  },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Flexible(
            child: Text(
              'Página $_page de $totalPaginas · $_total registros',
              style: LuvegiText.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Siguiente',
            onPressed: _page >= totalPaginas || _refrescando
                ? null
                : () {
                    _page++;
                    _cargarListado();
                  },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LuvegiSpacing.xl),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: LuvegiColors.textHint,
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          Text(
            _error ?? 'No se pudo cargar la información.',
            textAlign: TextAlign.center,
            style: LuvegiText.bodySecondary,
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          OutlinedButton.icon(
            onPressed: _cargarListado,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LuvegiSpacing.xxl),
      child: Column(
        children: [
          const Icon(
            Icons.manage_search_rounded,
            size: 42,
            color: LuvegiColors.textHint,
          ),
          const SizedBox(height: LuvegiSpacing.sm),
          Text(
            _filtro == 'alertas'
                ? 'No hay alertas de RUC por ahora.'
                : 'No se encontraron registros con ese criterio.',
            textAlign: TextAlign.center,
            style: LuvegiText.bodySecondary,
          ),
        ],
      ),
    );
  }

  String _fecha(String raw) {
    final limpio = raw.trim();
    if (limpio.isEmpty) return '';
    if (limpio.length >= 16) return limpio.substring(0, 16);
    return limpio;
  }
}

class _ResumenDato {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  const _ResumenDato({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });
}

class _HistorialSheet extends StatefulWidget {
  final RucService service;
  final String token;
  final RucControlItem item;

  const _HistorialSheet({
    required this.service,
    required this.token,
    required this.item,
  });

  @override
  State<_HistorialSheet> createState() => _HistorialSheetState();
}

class _HistorialSheetState extends State<_HistorialSheet> {
  late Future<RucHistorial> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = widget.service.historial(
      token: widget.token,
      partnerId: widget.item.partnerId,
      pageSize: 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LuvegiSpacing.md,
        LuvegiSpacing.md,
        LuvegiSpacing.md,
        LuvegiSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.nombre.isEmpty
                          ? 'Historial de verificaciones'
                          : widget.item.nombre,
                      style: LuvegiText.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('RUC ${widget.item.vat}', style: LuvegiText.caption),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const Divider(height: LuvegiSpacing.lg),
          Expanded(
            child: FutureBuilder<RucHistorial>(
              future: _futuro,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: LuvegiText.bodySecondary,
                    ),
                  );
                }
                final historial = snapshot.data;
                final items = historial?.items ?? const <RucHistorialItem>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aún no hay historial de este proveedor.',
                      style: LuvegiText.bodySecondary,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _historialItem(items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _historialItem(RucHistorialItem item) {
    final color = item.resultado == 'ERROR'
        ? LuvegiColors.error
        : item.resultado == 'ALERTA'
        ? LuvegiColors.error
        : item.resultado == 'CAMBIO'
        ? LuvegiColors.warning
        : LuvegiColors.success;

    final antes = [item.estadoAnterior, item.condicionAnterior]
        .where((e) => e.isNotEmpty)
        .join(' · ');
    final despues = [item.estadoNuevo, item.condicionNuevo]
        .where((e) => e.isNotEmpty)
        .join(' · ');

    return Container(
      padding: const EdgeInsets.all(LuvegiSpacing.sm),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.resultado.isEmpty ? 'VERIFICACIÓN' : item.resultado} · ${_fecha(item.verificadoEn)}',
                  style: LuvegiText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (despues.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    antes.isEmpty ? despues : '$antes → $despues',
                    style: LuvegiText.caption.copyWith(
                      color: LuvegiColors.textPrimary,
                    ),
                  ),
                ],
                if (item.mensaje.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.mensaje,
                    style: LuvegiText.caption.copyWith(
                      color: LuvegiColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fecha(String raw) {
    final limpio = raw.trim();
    if (limpio.isEmpty) return '';
    if (limpio.length >= 16) return limpio.substring(0, 16);
    return limpio;
  }
}
