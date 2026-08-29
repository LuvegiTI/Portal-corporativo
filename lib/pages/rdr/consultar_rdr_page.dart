import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/rdr_service.dart';
import 'detalle_rdr_page.dart';

class ConsultarRdrPage extends StatefulWidget {
  final String token;
  final List<String> permisos;
  final VoidCallback onRegistrarRdr;
  final String areaUsuario;
  final String? codigoInicial;
  final VoidCallback? onCodigoInicialConsumido;

  const ConsultarRdrPage({
    super.key,
    required this.token,
    required this.permisos,
    required this.onRegistrarRdr,
    this.areaUsuario = '',
    this.codigoInicial,
    this.onCodigoInicialConsumido,
  });

  @override
  State<ConsultarRdrPage> createState() => _ConsultarRdrPageState();
}

class _ConsultarRdrPageState extends State<ConsultarRdrPage> {
  final TextEditingController _codigoCtrl = TextEditingController();
  final ScrollController _horizontalTableCtrl = ScrollController();

  String? _estado;

  final RdrService _rdrService = RdrService();
  List<_RdrDemo> _registros = [];
  List<_RdrDemo> _filtrados = [];
  bool _cargando = true;
  String? _errorCarga;

  static const List<String> _estados = [
    'PENDIENTE',
    'CERRADO',
  ];

  @override
  void initState() {
    super.initState();
    final codigo = (widget.codigoInicial ?? '').trim();
    if (codigo.isNotEmpty) {
      _cargarDesdeNotificacion(codigo);
    } else {
      _cargarRegistros();
    }
  }

  Future<void> _cargarDesdeNotificacion(String codigo) async {
    await _cargarRegistros();
    if (!mounted) return;

    final int indice = _registros.indexWhere(
      (rdr) => rdr.codigo.toUpperCase() == codigo.toUpperCase(),
    );

    if (indice < 0) {
      widget.onCodigoInicialConsumido?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El REDIR de la notificación ya no está disponible.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _verDetalle(_registros[indice]);
      if (!mounted) return;

      _codigoCtrl.clear();
      setState(() => _estado = null);
      await _cargarRegistros();

      if (mounted) {
        widget.onCodigoInicialConsumido?.call();
      }
    });
  }

  Future<void> _cargarRegistros({
    bool aplicarFiltros = false,
  }) async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final response = await _rdrService.consultarRdr(
        token: widget.token,
        pageSize: 100,
        filtros: aplicarFiltros
            ? {
                'codigo': _codigoCtrl.text.trim(),
                'estado': _estado,
              }
            : const {},
      );
      final raw = response['data'] as List<dynamic>? ?? const [];
      final registros = raw
          .whereType<Map>()
          .map((item) => _RdrDemo.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        _registros = registros;
        _filtrados = List<_RdrDemo>.from(registros);
      });
    } on RdrApiException catch (error) {
      if (mounted) setState(() => _errorCarga = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorCarga = 'No se pudo conectar con el servidor.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _horizontalTableCtrl.dispose();
    super.dispose();
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final anchoMensaje = anchoPantalla > 430 ? 390.0 : anchoPantalla - 32;

    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensaje,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          width: anchoMensaje,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF12395B),
          elevation: 8,
          dismissDirection: DismissDirection.horizontal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  String _obtenerVariable(
    Map<String, dynamic> variables,
    List<String> posiblesClaves,
  ) {
    for (final String clave in posiblesClaves) {
      final dynamic valor = variables[clave];

      if (valor == null) continue;

      final String texto = valor.toString().trim();

      if (texto.isNotEmpty) {
        return texto;
      }
    }

    return '—';
  }

  String _estadoRdr(_RdrDemo rdr) {
    return rdr.fechaCierre == null ? 'PENDIENTE' : 'CERRADO';
  }

  Future<void> _buscar() async {
    FocusScope.of(context).unfocus();
    await _cargarRegistros(aplicarFiltros: true);
  }

  Future<void> _limpiar() async {
    _codigoCtrl.clear();

    setState(() {
      _estado = null;
    });
    await _cargarRegistros();
  }

  Future<void> _verDetalle(_RdrDemo rdr) async {
    try {
      final response = await _rdrService.obtenerDetalle(
        token: widget.token,
        codigo: rdr.codigo,
      );
      final rawDetalle = response['data'];
      if (rawDetalle is! Map) {
        throw const RdrApiException('El detalle recibido no es válido.');
      }
      final detalle = _RdrDemo.fromJson(
        Map<String, dynamic>.from(rawDetalle),
      );

      final dynamic resultado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleRdrPage(
            token: widget.token,
            codigo: detalle.codigo,
            fechaRegistro: detalle.fechaRegistro,
            tipoEmisor: detalle.tipoEmisor,
            tipoRegistro: detalle.tipoRegistro,
            tipoProblema: detalle.tipoProblema,
            fechaIncidente: detalle.fechaIncidente.isNotEmpty
                ? detalle.fechaIncidente
                : _obtenerVariable(
                    detalle.variablesEspecificas,
                    const ['fecha_incidente', 'fecha'],
                  ),
            horaIncidente: detalle.horaIncidente.isNotEmpty
                ? detalle.horaIncidente
                : _obtenerVariable(
                    detalle.variablesEspecificas,
                    const ['hora_incidente'],
                  ),
            pedido: detalle.pedido.isNotEmpty
                ? detalle.pedido
                : _obtenerVariable(
                    detalle.variablesEspecificas,
                    const ['pedido', 'numero_pedido', 'proyecto_afectado'],
                  ),
            categoriaProblema: '—',
            categoriaProblemaSecundaria: '—',
            area: detalle.area,
            usuarioEmisor: detalle.usuarioEmisor,
            correoEmisor: detalle.correoEmisor,
            fechaCierre: detalle.fechaCierre,
            responsableNombre: detalle.responsable,
            responsableCorreo: detalle.responsableCorreo,
            responsableRol: detalle.responsableRol,
            tipoCausa: detalle.tipoCausa,
            tiempoSolucionHoras: detalle.tiempoSolucionHoras,
            costosAsociados: detalle.costosAsociados,
            descripcionSucedido: detalle.descripcionSucedido,
            descripcionSolucion: detalle.descripcionSolucion,
            variablesEspecificas: detalle.variablesEspecificas,
            puedeAtender: detalle.puedeAtender,
          ),
        ),
      );

      if (resultado == true && mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();

        await _cargarRegistros();

        _mostrarExito(
          'La atención del REDIR fue registrada correctamente.',
        );
      }
    } on RdrApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.redAccent),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el detalle del REDIR.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool mobile = width < 760;

    return ColoredBox(
      color: LuvegiColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          mobile ? LuvegiSpacing.md : LuvegiSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(mobile),
                const SizedBox(height: LuvegiSpacing.lg),
                _buildResumen(mobile),
                const SizedBox(height: LuvegiSpacing.lg),
                _buildFiltros(mobile),
                const SizedBox(height: LuvegiSpacing.lg),
                _buildResultados(mobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool mobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        mobile ? LuvegiSpacing.lg : LuvegiSpacing.xl,
      ),
      decoration: _cardDecoration(),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerTitle(mobile),
                const SizedBox(height: LuvegiSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: _registrarButton(),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _headerTitle(mobile)),
                const SizedBox(width: LuvegiSpacing.lg),
                _registrarButton(),
              ],
            ),
    );
  }

  Widget _headerTitle(bool mobile) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: LuvegiColors.menuHover,
            borderRadius: BorderRadius.circular(LuvegiRadius.md),
            border: Border.all(
              color: LuvegiColors.menuSelected,
            ),
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            color: LuvegiColors.secondary,
            size: 29,
          ),
        ),
        const SizedBox(width: LuvegiSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consultar REDIR',
                style: LuvegiText.title.copyWith(
                  fontSize: mobile ? 20 : 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Consulta, atención y seguimiento de reclamos e incidencias.',
                style: LuvegiText.caption.copyWith(
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _registrarButton() {
    return ElevatedButton.icon(
      onPressed: widget.onRegistrarRdr,
      icon: const Icon(Icons.add_comment_outlined),
      label: const Text('Registrar REDIR'),
      style: ElevatedButton.styleFrom(
        backgroundColor: LuvegiColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            LuvegiRadius.md,
          ),
        ),
      ),
    );
  }

  Widget _buildResumen(bool mobile) {
    final int total = _filtrados.length;
    final int pendientes = _filtrados
        .where((rdr) => _estadoRdr(rdr) == 'PENDIENTE')
        .length;
    final int cerrados = _filtrados
        .where((rdr) => _estadoRdr(rdr) == 'CERRADO')
        .length;

    final List<Widget> tarjetas = [
      _resumenCard(
        title: 'Total de REDIR',
        value: total.toString(),
        icon: Icons.folder_copy_outlined,
      ),
      _resumenCard(
        title: 'Pendientes de atención',
        value: pendientes.toString(),
        icon: Icons.pending_actions_outlined,
      ),
      _resumenCard(
        title: 'REDIR cerrados',
        value: cerrados.toString(),
        icon: Icons.task_alt_outlined,
      ),
    ];

    if (mobile) {
      return Column(
        children: [
          for (int index = 0; index < tarjetas.length; index++) ...[
            tarjetas[index],
            if (index != tarjetas.length - 1)
              const SizedBox(height: LuvegiSpacing.md),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int index = 0; index < tarjetas.length; index++) ...[
          Expanded(child: tarjetas[index]),
          if (index != tarjetas.length - 1)
            const SizedBox(width: LuvegiSpacing.md),
        ],
      ],
    );
  }

  Widget _resumenCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: LuvegiColors.surfaceHover,
              borderRadius: BorderRadius.circular(LuvegiRadius.md),
              border: Border.all(color: LuvegiColors.border),
            ),
            child: Icon(
              icon,
              color: LuvegiColors.secondary,
              size: 23,
            ),
          ),
          const SizedBox(width: LuvegiSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: LuvegiColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: LuvegiColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros(bool mobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.filter_alt_outlined,
            title: 'Filtros de consulta',
            subtitle:
                'Busca rápidamente por código REDIR o estado.',
          ),
          const SizedBox(height: LuvegiSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final int columns = mobile ? 1 : 2;

              const double gap = LuvegiSpacing.md;

              final double itemWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;

              final List<Widget> fields = [
                _textField(
                  controller: _codigoCtrl,
                  label: 'Código REDIR',
                  hint: 'REDIR-000001',
                  icon: Icons.tag_outlined,
                ),
                _dropdown(
                  label: 'Estado',
                  value: _estado,
                  items: _estados,
                  onChanged: (value) {
                    setState(() {
                      _estado = value;
                    });
                  },
                ),
              ];

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: fields
                    .map(
                      (field) => SizedBox(
                        width: itemWidth,
                        child: field,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: LuvegiSpacing.lg),
          mobile
              ? Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _buscarButton(),
                    ),
                    const SizedBox(height: LuvegiSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: _limpiarButton(),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _limpiarButton(),
                    const SizedBox(width: LuvegiSpacing.md),
                    _buscarButton(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildResultados(bool mobile) {
    if (_cargando) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: _cardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorCarga != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(LuvegiSpacing.xl),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 34),
            const SizedBox(height: LuvegiSpacing.md),
            Text(_errorCarga!, textAlign: TextAlign.center),
            const SizedBox(height: LuvegiSpacing.lg),
            ElevatedButton.icon(
              onPressed: _cargarRegistros,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_filtrados.isEmpty) {
      return _buildEmpty();
    }

    if (mobile) {
      return Column(
        children: [
          for (int index = 0; index < _filtrados.length; index++) ...[
            _buildMobileCard(_filtrados[index]),
            if (index != _filtrados.length - 1)
              const SizedBox(height: LuvegiSpacing.md),
          ],
        ],
      );
    }

    return _buildTable();
  }

  Widget _buildTable() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(LuvegiSpacing.lg),
            child: _sectionTitle(
              icon: Icons.table_rows_outlined,
              title: 'Registros encontrados',
              subtitle:
                  '${_filtrados.length} registro(s) mostrado(s).',
            ),
          ),
          const Divider(height: 1, color: LuvegiColors.border),
          Scrollbar(
            controller: _horizontalTableCtrl,
            thumbVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _horizontalTableCtrl,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1540),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    LuvegiColors.surfaceHover,
                  ),
                  dataRowMinHeight: 66,
                  dataRowMaxHeight: 82,
                  columnSpacing: 20,
                  horizontalMargin: 16,
                  dividerThickness: 0.7,
                  headingTextStyle: const TextStyle(
                    color: LuvegiColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                  dataTextStyle: const TextStyle(
                    color: LuvegiColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  columns: const [
                    DataColumn(label: Text('Acciones')),
                    DataColumn(label: Text('Código REDIR')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Fecha de registro')),
                    DataColumn(label: Text('Tipo de emisor')),
                    DataColumn(label: Text('Tipo de registro')),
                    DataColumn(label: Text('Tipo de problema')),
                    DataColumn(label: Text('Área responsable')),
                    DataColumn(label: Text('Usuario emisor')),
                    DataColumn(label: Text('Responsable de solución')),
                    DataColumn(label: Text('Fecha de cierre')),
                  ],
                  rows: _filtrados.map((rdr) {
                    final bool cerrado = rdr.fechaCierre != null;
                    final bool puedeAtender = !cerrado && rdr.puedeAtender;

                    return DataRow(
                      cells: [
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () {
                              _verDetalle(rdr);
                            },
                            icon: Icon(
                              puedeAtender
                                  ? Icons.handyman_outlined
                                  : Icons.visibility_outlined,
                              size: 17,
                            ),
                            label: Text(
                              puedeAtender ? 'Atender' : 'Ver detalle',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: puedeAtender
                                  ? LuvegiColors.secondary
                                  : LuvegiColors.surfaceHover,
                              foregroundColor: puedeAtender
                                  ? Colors.white
                                  : LuvegiColors.secondary,
                              elevation: 0,
                              side: !puedeAtender
                                  ? const BorderSide(
                                      color: LuvegiColors.menuSelected,
                                    )
                                  : BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            rdr.codigo,
                            style: const TextStyle(
                              color: LuvegiColors.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        DataCell(_estadoChip(_estadoRdr(rdr))),
                        DataCell(
                          Text(
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(rdr.fechaRegistro),
                          ),
                        ),
                        DataCell(Text(rdr.tipoEmisor)),
                        DataCell(Text(rdr.tipoRegistro)),
                        DataCell(
                          SizedBox(
                            width: 175,
                            child: Text(
                              rdr.tipoProblema,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(rdr.area)),
                        DataCell(Text(rdr.usuarioEmisor)),
                        DataCell(
                          SizedBox(
                            width: 170,
                            child: Text(
                              rdr.responsable.isEmpty
                                  ? 'Pendiente de atención'
                                  : rdr.responsable,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: rdr.responsable.isEmpty
                                    ? LuvegiColors.textSecondary
                                    : LuvegiColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            rdr.fechaCierre == null
                                ? '—'
                                : DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(rdr.fechaCierre!),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoChip(String estado) {
    final bool cerrado = estado == 'CERRADO';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: cerrado
            ? LuvegiColors.surfaceHover
            : LuvegiColors.menuHover,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cerrado
              ? LuvegiColors.border
              : LuvegiColors.menuSelected,
        ),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: cerrado
              ? LuvegiColors.textSecondary
              : LuvegiColors.secondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMobileCard(_RdrDemo rdr) {
    final bool cerrado = rdr.fechaCierre != null;
    final bool puedeAtender = !cerrado && rdr.puedeAtender;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rdr.codigo,
                  style: const TextStyle(
                    color: LuvegiColors.secondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _estadoChip(_estadoRdr(rdr)),
            ],
          ),
          const Divider(color: LuvegiColors.border),
          _mobileItem(
            'Fecha de registro',
            DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(rdr.fechaRegistro),
          ),
          _mobileItem('Tipo de emisor', rdr.tipoEmisor),
          _mobileItem('Tipo de registro', rdr.tipoRegistro),
          _mobileItem('Tipo de problema', rdr.tipoProblema),
          _mobileItem('Área responsable', rdr.area),
          _mobileItem('Usuario emisor', rdr.usuarioEmisor),
          _mobileItem(
            'Responsable',
            rdr.responsable.isEmpty
                ? 'Pendiente de atención'
                : rdr.responsable,
          ),
          _mobileItem(
            'Fecha de cierre',
            rdr.fechaCierre == null
                ? '—'
                : DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(rdr.fechaCierre!),
          ),
          const SizedBox(height: LuvegiSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _verDetalle(rdr);
              },
              icon: Icon(
                puedeAtender
                    ? Icons.handyman_outlined
                    : Icons.visibility_outlined,
              ),
              label: Text(
                puedeAtender
                    ? 'Atender este REDIR'
                    : 'Ver detalle del REDIR',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: puedeAtender
                    ? LuvegiColors.secondary
                    : LuvegiColors.surfaceHover,
                foregroundColor: puedeAtender
                    ? Colors.white
                    : LuvegiColors.secondary,
                elevation: 0,
                side: !puedeAtender
                    ? const BorderSide(
                        color: LuvegiColors.menuSelected,
                      )
                    : BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: LuvegiColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: LuvegiSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: LuvegiColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: LuvegiSpacing.xl,
        vertical: 48,
      ),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.find_in_page_outlined,
            size: 42,
            color: LuvegiColors.textSecondary,
          ),
          const SizedBox(height: LuvegiSpacing.md),
          const Text(
            'No se encontraron registros REDIR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LuvegiColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Revisa los filtros ingresados o registra un nuevo REDIR.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LuvegiColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: LuvegiSpacing.lg),
          _registrarButton(),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: LuvegiColors.surfaceHover,
            borderRadius: BorderRadius.circular(
              LuvegiRadius.sm,
            ),
            border: Border.all(
              color: LuvegiColors.border,
            ),
          ),
          child: Icon(
            icon,
            color: LuvegiColors.secondary,
            size: 20,
          ),
        ),
        const SizedBox(width: LuvegiSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: LuvegiText.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: LuvegiText.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      onSubmitted: (_) {
        _buscar();
      },
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _inputDecoration(
        label: label,
        hint: 'Todos',
        icon: Icons.keyboard_arrow_down_rounded,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Todos'),
        ),
        ...items.map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: LuvegiColors.surface,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: LuvegiColors.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LuvegiSpacing.md,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          LuvegiRadius.md,
        ),
        borderSide: const BorderSide(
          color: LuvegiColors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          LuvegiRadius.md,
        ),
        borderSide: const BorderSide(
          color: LuvegiColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          LuvegiRadius.md,
        ),
        borderSide: const BorderSide(
          color: LuvegiColors.secondary,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buscarButton() {
    return ElevatedButton.icon(
      onPressed: _buscar,
      icon: const Icon(Icons.search_rounded),
      label: const Text('Buscar'),
      style: ElevatedButton.styleFrom(
        backgroundColor: LuvegiColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _limpiarButton() {
    return OutlinedButton.icon(
      onPressed: _limpiar,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Limpiar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: LuvegiColors.textPrimary,
        side: const BorderSide(
          color: LuvegiColors.border,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 16,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: LuvegiColors.surface,
      borderRadius: BorderRadius.circular(
        LuvegiRadius.lg,
      ),
      border: Border.all(
        color: LuvegiColors.border,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08101828),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    );
  }
}

class _RdrDemo {
  final String codigo;
  final DateTime fechaRegistro;
  final String tipoEmisor;
  final String tipoRegistro;
  final String tipoProblema;
  final String area;
  final String usuarioEmisor;
  final String correoEmisor;
  final String fechaIncidente;
  final String horaIncidente;
  final String pedido;

  final String responsable;
  final String responsableCorreo;
  final String? responsableRol;
  final String? tipoCausa;
  final double? tiempoSolucionHoras;
  final double? costosAsociados;
  final String? descripcionSucedido;
  final String? descripcionSolucion;

  final DateTime? fechaCierre;
  final Map<String, dynamic> variablesEspecificas;
  final bool puedeAtender;

  const _RdrDemo({
    required this.codigo,
    required this.fechaRegistro,
    required this.tipoEmisor,
    required this.tipoRegistro,
    required this.tipoProblema,
    required this.area,
    required this.usuarioEmisor,
    this.correoEmisor = '',
    this.fechaIncidente = '',
    this.horaIncidente = '',
    this.pedido = '',
    required this.responsable,
    required this.responsableCorreo,
    this.responsableRol,
    this.tipoCausa,
    this.tiempoSolucionHoras,
    this.costosAsociados,
    this.descripcionSucedido,
    this.descripcionSolucion,
    required this.fechaCierre,
    this.variablesEspecificas = const {},
    this.puedeAtender = false,
  });

  factory _RdrDemo.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      return DateTime.tryParse((value ?? '').toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      final text = (value ?? '').toString().trim();
      return text.isEmpty ? null : DateTime.tryParse(text);
    }

    double? parseDouble(dynamic value) {
      if (value == null || value.toString().trim().isEmpty) return null;
      return double.tryParse(value.toString());
    }

    final variablesRaw = json['variables_especificas'];
    final variables = variablesRaw is Map
        ? Map<String, dynamic>.from(variablesRaw)
        : <String, dynamic>{};

    return _RdrDemo(
      codigo: (json['codigo'] ?? '').toString(),
      fechaRegistro: parseDate(json['fecha_apertura'] ?? json['creado_en']),
      tipoEmisor: (json['tipo_emisor'] ?? '').toString(),
      tipoRegistro: (json['tipo_registro'] ?? '').toString(),
      tipoProblema: (json['tipo_problema'] ?? '').toString(),
      area: (json['area_responsable'] ?? '').toString(),
      usuarioEmisor: (json['usuario_emisor'] ?? '').toString(),
      correoEmisor: (json['correo_emisor'] ?? '').toString(),
      fechaIncidente: (json['fecha_incidente'] ?? '').toString(),
      horaIncidente: (json['hora_incidente'] ?? '').toString(),
      pedido: (json['pedido'] ?? '').toString(),
      responsable: (json['responsable_nombre'] ?? '').toString(),
      responsableCorreo: (json['responsable_correo'] ?? '').toString(),
      responsableRol: json['responsable_rol']?.toString(),
      tipoCausa: json['tipo_causa']?.toString(),
      tiempoSolucionHoras: parseDouble(json['tiempo_solucion_horas']),
      costosAsociados: parseDouble(json['costos_asociados']),
      descripcionSucedido: json['descripcion_sucedido']?.toString(),
      descripcionSolucion: json['descripcion_solucion']?.toString(),
      fechaCierre: parseNullableDate(json['fecha_cierre']),
      variablesEspecificas: variables,
      puedeAtender: json['puede_atender'] == true || json['puede_atender'] == 1,
    );
  }
}