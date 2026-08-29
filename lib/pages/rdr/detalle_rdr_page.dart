import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/rdr_service.dart';

class DetalleRdrPage extends StatefulWidget {
  final String token;
  final String codigo;
  final DateTime fechaRegistro;
  final String tipoEmisor;
  final String tipoRegistro;
  final String tipoProblema;
  final String fechaIncidente;
  final String horaIncidente;
  final String pedido;

  final String categoriaProblema;
  final String categoriaProblemaSecundaria;

  final String area;
  final String usuarioEmisor;
  final String correoEmisor;
  final bool puedeAtender;

  final DateTime? fechaCierre;

  final String? responsableNombre;
  final String? responsableCorreo;
  final String? responsableRol;
  final String? tipoCausa;
  final double? tiempoSolucionHoras;
  final double? costosAsociados;
  final String? descripcionSucedido;
  final String? descripcionSolucion;

  final Map<String, dynamic> variablesEspecificas;

  factory DetalleRdrPage.desdeJson({
    Key? key,
    required String token,
    required Map<String, dynamic> json,
  }) {
    DateTime parseDate(dynamic value) {
      return DateTime.tryParse((value ?? '').toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      final text = (value ?? '').toString().trim();
      return text.isEmpty ? null : DateTime.tryParse(text);
    }

    double? parseDouble(dynamic value) {
      if (value == null || value.toString().trim().isEmpty) return null;
      return double.tryParse(value.toString().replaceAll(',', '.'));
    }

    String texto(Map<String, dynamic> mapa, List<String> claves) {
      for (final clave in claves) {
        final value = mapa[clave];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '—';
    }

    final variablesRaw = json['variables_especificas'];
    final variables = variablesRaw is Map
        ? Map<String, dynamic>.from(variablesRaw)
        : <String, dynamic>{};

    return DetalleRdrPage(
      key: key,
      token: token,
      codigo: (json['codigo'] ?? '').toString(),
      fechaRegistro: parseDate(json['fecha_apertura'] ?? json['creado_en']),
      tipoEmisor: (json['tipo_emisor'] ?? '').toString(),
      tipoRegistro: (json['tipo_registro'] ?? '').toString(),
      tipoProblema: (json['tipo_problema'] ?? '').toString(),
      fechaIncidente: (json['fecha_incidente'] ?? '').toString(),
      horaIncidente: (json['hora_incidente'] ?? '').toString(),
      pedido: (json['pedido'] ?? '').toString(),
      categoriaProblema: texto(
        variables,
        const [
          'categoria_problema',
          'categoria_problema_1',
          'categoria_problema1',
          'categoria_del_problema',
          'categoría_problema',
          'categoría_del_problema'
        ],
      ),
      categoriaProblemaSecundaria: texto(
        variables,
        const [
          'categoria_problema_secundaria',
          'segunda_categoria',
          'segunda_categoría',
          'categoria_secundaria',
          'categoria_problema_2',
          'categoria_problema2'
        ],
      ),
      area: (json['area_responsable'] ?? '').toString(),
      usuarioEmisor: (json['usuario_emisor'] ?? '').toString(),
      correoEmisor: (json['correo_emisor'] ?? '').toString(),
      puedeAtender:
          json['puede_atender'] == true || json['puede_atender'] == 1,
      fechaCierre: parseNullableDate(json['fecha_cierre']),
      responsableNombre: json['responsable_nombre']?.toString(),
      responsableCorreo: json['responsable_correo']?.toString(),
      responsableRol: json['responsable_rol']?.toString(),
      tipoCausa: json['tipo_causa']?.toString(),
      tiempoSolucionHoras: parseDouble(json['tiempo_solucion_horas']),
      costosAsociados: parseDouble(json['costos_asociados']),
      descripcionSucedido: json['descripcion_sucedido']?.toString(),
      descripcionSolucion: json['descripcion_solucion']?.toString(),
      variablesEspecificas: variables,
    );
  }

  const DetalleRdrPage({
    super.key,
    required this.token,
    required this.codigo,
    required this.fechaRegistro,
    required this.tipoEmisor,
    required this.tipoRegistro,
    required this.tipoProblema,
    required this.fechaIncidente,
    required this.horaIncidente,
    required this.pedido,
    required this.categoriaProblema,
    required this.categoriaProblemaSecundaria,
    required this.area,
    required this.usuarioEmisor,
    required this.correoEmisor,
    required this.puedeAtender,
    required this.fechaCierre,
    this.responsableNombre,
    this.responsableCorreo,
    this.responsableRol,
    this.tipoCausa,
    this.tiempoSolucionHoras,
    this.costosAsociados,
    this.descripcionSucedido,
    this.descripcionSolucion,
    required this.variablesEspecificas,
  });

  @override
  State<DetalleRdrPage> createState() => _DetalleRdrPageState();
}

class _DetalleRdrPageState extends State<DetalleRdrPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _tiempoCtrl = TextEditingController();
  final TextEditingController _costoCtrl = TextEditingController();
  final TextEditingController _descripcionHechosCtrl =
      TextEditingController();
  final TextEditingController _solucionCtrl = TextEditingController();

  String? _tipoCausa;
  bool _guardando = false;
  final RdrService _rdrService = RdrService();
  bool _cargandoResponsable = true;
  bool _puedeAdministrarAtencion = false;
  bool _procesandoAdministracion = false;

  String _responsableNombre = '';
  String _responsableCorreo = '';
  String _responsableRol = '';

  static const List<String> _tiposCausa = [
    'Error del cliente',
    'Error de diseño de proveedor',
    'Error de diseño de LUVEGI',
    'Error de proceso técnico operativo',
    'Error de proceso técnico de fabricación',
    'Error de proceso administrativo por subgerencia',
    'Capacidad de personal',
    'Otros',
  ];

  bool get _cerrado => widget.fechaCierre != null;
  bool get _soloLectura => _cerrado || !widget.puedeAtender;

  @override
  void initState() {
    super.initState();
    _verificarAdministracionAtencion();

    if (_soloLectura) {
      _tipoCausa = widget.tipoCausa;
      _tiempoCtrl.text = _numeroVisible(widget.tiempoSolucionHoras);
      _costoCtrl.text = _numeroVisible(widget.costosAsociados);
      _descripcionHechosCtrl.text = widget.descripcionSucedido ?? '';
      _solucionCtrl.text = widget.descripcionSolucion ?? '';
      _responsableNombre = widget.responsableNombre ?? '';
      _responsableCorreo = widget.responsableCorreo ?? '';
      _responsableRol = widget.responsableRol ?? '';
      _cargandoResponsable = false;
    } else {
      _cargarResponsableSesion();
    }
  }

  Future<void> _verificarAdministracionAtencion() async {
    try {
      final permitido = await _rdrService.puedeAdministrarAtenciones(
        token: widget.token,
      );
      if (mounted) {
        setState(() => _puedeAdministrarAtencion = permitido);
      }
    } catch (error) {
      debugPrint('No se pudo validar administración REDIR: $error');
    }
  }

  String _numeroVisible(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  Future<void> _cargarResponsableSesion() async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      final String nombre =
          (prefs.getString('nombre') ?? '').trim();
      final String correo =
          (prefs.getString('correo') ?? '').trim();
      final String rol =
          (prefs.getString('rol') ?? '').trim();

      if (!mounted) return;

      setState(() {
        _responsableNombre = nombre;
        _responsableCorreo = correo;
        _responsableRol = rol;
        _cargandoResponsable = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Error al obtener responsable desde sesión: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _cargandoResponsable = false;
      });
    }
  }

  @override
  void dispose() {
    _tiempoCtrl.dispose();
    _costoCtrl.dispose();
    _descripcionHechosCtrl.dispose();
    _solucionCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmarCierreAtencion() async {
    Offset posicion = Offset.zero;

    final bool? confirmado = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Confirmar cierre del REDIR',
      barrierColor: Colors.black.withOpacity(0.20),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (
        context,
        animation,
        secondaryAnimation,
        child,
      ) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.97,
              end: 1,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (
        dialogContext,
        animation,
        secondaryAnimation,
      ) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final Size pantalla = MediaQuery.sizeOf(context);
            final bool mobile = pantalla.width < 600;
            final double anchoModal =
                mobile ? pantalla.width - 32 : 490;

            void mover(DragUpdateDetails details) {
              final double limiteX =
                  ((pantalla.width - anchoModal) / 2)
                      .clamp(0, double.infinity)
                      .toDouble();
              final double limiteY =
                  (pantalla.height * 0.30)
                      .clamp(70, 260)
                      .toDouble();

              setModalState(() {
                posicion = Offset(
                  (posicion.dx + details.delta.dx)
                      .clamp(-limiteX, limiteX)
                      .toDouble(),
                  (posicion.dy + details.delta.dy)
                      .clamp(-limiteY, limiteY)
                      .toDouble(),
                );
              });
            }

            return Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: Center(
                  child: Transform.translate(
                    offset: posicion,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: anchoModal,
                        maxHeight: pantalla.height - 32,
                      ),
                      child: Material(
                        color: LuvegiColors.surface,
                        elevation: 20,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(
                          LuvegiRadius.lg,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: mover,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: LuvegiSpacing.lg,
                                  vertical: LuvegiSpacing.md,
                                ),
                                color: LuvegiColors.surfaceHover,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.open_with_rounded,
                                      color:
                                          LuvegiColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Confirmar atención',
                                        style:
                                            LuvegiText.heading.copyWith(
                                          color:
                                              LuvegiColors.textPrimary,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    const Tooltip(
                                      message:
                                          'Arrastra para mover el cuadro',
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        color:
                                            LuvegiColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Flexible(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(
                                  LuvegiSpacing.lg,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        LuvegiSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: LuvegiColors.warning
                                            .withOpacity(0.10),
                                        borderRadius:
                                            BorderRadius.circular(
                                          LuvegiRadius.md,
                                        ),
                                        border: Border.all(
                                          color: LuvegiColors.warning
                                              .withOpacity(0.45),
                                        ),
                                      ),
                                      child: const Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons
                                                .warning_amber_rounded,
                                            color:
                                                LuvegiColors.warning,
                                          ),
                                          SizedBox(
                                            width: LuvegiSpacing.sm,
                                          ),
                                          Expanded(
                                            child: Text(
                                              '¿Estás seguro de guardar esta atención? '
                                              'El REDIR quedará cerrado y la solución '
                                              'registrada ya no podrá editarse.',
                                              style: TextStyle(
                                                color: LuvegiColors
                                                    .textPrimary,
                                                fontWeight:
                                                    FontWeight.w700,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      height: LuvegiSpacing.lg,
                                    ),
                                    _filaConfirmacion(
                                      'Código REDIR',
                                      widget.codigo,
                                    ),
                                    _filaConfirmacion(
                                      'Responsable',
                                      _responsableNombre,
                                    ),
                                    _filaConfirmacion(
                                      'Tipo de causa',
                                      (_tipoCausa ?? '')
                                              .trim()
                                              .isNotEmpty
                                          ? _tipoCausa!
                                          : '—',
                                    ),
                                    _filaConfirmacion(
                                      'Tiempo',
                                      _tiempoCtrl.text.trim().isEmpty
                                          ? '—'
                                          : '${_tiempoCtrl.text.trim()} hora(s)',
                                    ),
                                    _filaConfirmacion(
                                      'Costo',
                                      _costoCtrl.text.trim().isEmpty
                                          ? '—'
                                          : _costoCtrl.text.trim(),
                                    ),
                                    const SizedBox(
                                      height: LuvegiSpacing.xs,
                                    ),
                                    Text(
                                      'Arrastra el encabezado del cuadro '
                                      'para revisar los datos registrados '
                                      'en la pantalla.',
                                      style: LuvegiText.body.copyWith(
                                        color: LuvegiColors
                                            .textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(
                                LuvegiSpacing.md,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: LuvegiColors.border,
                                  ),
                                ),
                              ),
                              child: mobile
                                  ? Column(
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child:
                                              ElevatedButton.icon(
                                            onPressed: () =>
                                                Navigator.pop(
                                              dialogContext,
                                              true,
                                            ),
                                            icon: const Icon(
                                              Icons
                                                  .lock_outline_rounded,
                                            ),
                                            label: const Text(
                                              'Sí, guardar y cerrar',
                                            ),
                                            style: ElevatedButton
                                                .styleFrom(
                                              backgroundColor:
                                                  LuvegiColors
                                                      .secondary,
                                              foregroundColor:
                                                  Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: LuvegiSpacing.sm,
                                        ),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                              dialogContext,
                                              false,
                                            ),
                                            child: const Text(
                                              'Seguir revisando',
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () =>
                                              Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                          child: const Text(
                                            'Seguir revisando',
                                          ),
                                        ),
                                        const SizedBox(
                                          width: LuvegiSpacing.sm,
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
                                          icon: const Icon(
                                            Icons
                                                .lock_outline_rounded,
                                          ),
                                          label: const Text(
                                            'Sí, guardar y cerrar',
                                          ),
                                          style: ElevatedButton
                                              .styleFrom(
                                            backgroundColor:
                                                LuvegiColors.secondary,
                                            foregroundColor:
                                                Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return confirmado == true;
  }

  Widget _filaConfirmacion(
    String etiqueta,
    String valor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: LuvegiSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              etiqueta,
              style: LuvegiText.body.copyWith(
                color: LuvegiColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: LuvegiText.body.copyWith(
                color: LuvegiColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarAtencion() async {
    FocusScope.of(context).unfocus();

    if (_soloLectura) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cerrado
                ? 'Este REDIR ya fue cerrado y solo puede visualizarse.'
                : 'Puedes ver este REDIR por ser el emisor, pero solo el área responsable puede atenderlo.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_cargandoResponsable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Espera mientras se identifica al responsable.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_responsableNombre.isEmpty ||
        _responsableCorreo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo identificar la cuenta logueada. '
            'Vuelve a iniciar sesión.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final bool confirmado = await _confirmarCierreAtencion();
    if (!confirmado || !mounted) {
      return;
    }

    setState(() => _guardando = true);

    try {
      final double tiempo = _numeroOpcional(_tiempoCtrl.text) ?? 0.0;
      final double costo = _numeroOpcional(_costoCtrl.text) ?? 0.0;

      await _rdrService.atenderRdr(
        token: widget.token,
        codigo: widget.codigo,
        tipoCausa: _tipoCausa ?? 'Otros',
        tiempoSolucionHoras: tiempo,
        costosAsociados: costo,
        descripcionSucedido: _descripcionHechosCtrl.text.trim(),
        descripcionSolucion: _solucionCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La atención del REDIR fue registrada correctamente.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } on RdrApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error al guardar atención REDIR: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo registrar la atención. '
            'Inténtalo nuevamente.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _editarAtencionComoAdministrador() async {
    final motivoCtrl = TextEditingController();
    final tiempoCtrl = TextEditingController(text: _tiempoCtrl.text);
    final costoCtrl = TextEditingController(text: _costoCtrl.text);
    final sucedidoCtrl =
        TextEditingController(text: _descripcionHechosCtrl.text);
    final solucionCtrl = TextEditingController(text: _solucionCtrl.text);
    String? causa = _tipoCausa;

    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar atención REDIR'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Esta acción es exclusiva del administrador y quedará '
                    'registrada en la auditoría.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _tiposCausa.contains(causa) ? causa : null,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de causa'),
                    items: _tiposCausa
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => causa = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tiempoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Tiempo de solución',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: costoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Costos asociados',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sucedidoCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Descripción de lo sucedido',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: solucionCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Descripción de la solución',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: motivoCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de la edición *',
                      alignLabelWithHint: true,
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
            FilledButton(
              onPressed: () {
                final motivo = motivoCtrl.text.trim();
                if (motivo.isEmpty) return;
                Navigator.pop(dialogContext, {
                  'motivo': motivo,
                  'tipo_causa': causa,
                  'tiempo': double.tryParse(
                    tiempoCtrl.text.trim().replaceAll(',', '.'),
                  ),
                  'costos': double.tryParse(
                    costoCtrl.text.trim().replaceAll(',', '.'),
                  ),
                  'sucedido': sucedidoCtrl.text.trim(),
                  'solucion': solucionCtrl.text.trim(),
                });
              },
              child: const Text('Guardar corrección'),
            ),
          ],
        ),
      ),
    );

    motivoCtrl.dispose();
    tiempoCtrl.dispose();
    costoCtrl.dispose();
    sucedidoCtrl.dispose();
    solucionCtrl.dispose();
    if (datos == null || !mounted) return;

    setState(() => _procesandoAdministracion = true);
    try {
      await _rdrService.editarAtencionRdr(
        token: widget.token,
        codigo: widget.codigo,
        motivo: datos['motivo'] as String,
        tipoCausa: datos['tipo_causa'] as String?,
        tiempoSolucionHoras: datos['tiempo'] as double?,
        costosAsociados: datos['costos'] as double?,
        descripcionSucedido: datos['sucedido'] as String?,
        descripcionSolucion: datos['solucion'] as String?,
      );
      if (!mounted) return;

      setState(() {
        _tipoCausa = datos['tipo_causa'] as String?;
        _tiempoCtrl.text = _numeroVisible(datos['tiempo'] as double?);
        _costoCtrl.text = _numeroVisible(datos['costos'] as double?);
        _descripcionHechosCtrl.text =
            datos['sucedido'] as String? ?? '';
        _solucionCtrl.text =
            datos['solucion'] as String? ?? '';
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Atención actualizada correctamente.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } on RdrApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _procesandoAdministracion = false);
      }
    }
  }

  Future<void> _reabrirYLimpiarComoAdministrador() async {
    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reabrir y limpiar atención'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La solución actual será respaldada en auditoría y eliminada '
                'de la atención activa. El REDIR volverá al estado ABIERTO.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: motivoCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Motivo obligatorio',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () {
              final value = motivoCtrl.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Reabrir y limpiar'),
          ),
        ],
      ),
    );
    motivoCtrl.dispose();
    if (motivo == null || !mounted) return;

    setState(() => _procesandoAdministracion = true);
    try {
      await _rdrService.reabrirYLimpiarAtencionRdr(
        token: widget.token,
        codigo: widget.codigo,
        motivo: motivo,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on RdrApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _procesandoAdministracion = false);
      }
    }
  }

  String _etiquetaAuditoria(String clave) {
    const etiquetas = <String, String>{
      'tipo_causa': 'Tipo de causa',
      'tiempo_solucion_horas': 'Tiempo de solución',
      'costos_asociados': 'Costos asociados',
      'descripcion_sucedido': 'Descripción de lo sucedido',
      'descripcion_solucion': 'Descripción de la solución',
      'estado': 'Estado',
      'atencion': 'Atención',
    };
    return etiquetas[clave] ??
        clave.replaceAll('_', ' ').toUpperCase();
  }

  String _valorAuditoria(dynamic valor) {
    if (valor == null || valor.toString().trim().isEmpty) return '—';
    if (valor is Map) {
      return valor.entries
          .map(
            (e) =>
                '${_etiquetaAuditoria(e.key.toString())}: '
                '${_valorAuditoria(e.value)}',
          )
          .join('\n');
    }
    return valor.toString();
  }

  Widget _datosAuditoria(dynamic datos) {
    if (datos is! Map || datos.isEmpty) {
      return const Text('Sin información.');
    }

    dynamic contenido = datos;
    if (datos['solucion'] is Map) {
      contenido = datos['solucion'];
    }
    if (contenido is! Map || contenido.isEmpty) {
      return const Text('Sin información.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contenido.entries
          .map<Widget>(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${_etiquetaAuditoria(e.key.toString())}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: _valorAuditoria(e.value)),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _mostrarHistorialAuditoria() async {
    final future = _rdrService.obtenerHistorialAtencionRdr(
      token: widget.token,
      codigo: widget.codigo,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 780,
            maxHeight: 680,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.history),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Historial de cambios · ${widget.codigo}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final historial =
                        snapshot.data ?? <Map<String, dynamic>>[];
                    if (historial.isEmpty) {
                      return const Center(
                        child: Text(
                          'Este REDIR todavía no tiene cambios administrativos.',
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: historial.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = historial[index];
                        final fechaRaw =
                            item['creado_en']?.toString() ?? '';
                        final fecha = DateTime.tryParse(fechaRaw);
                        final fechaVisible = fecha == null
                            ? fechaRaw
                            : DateFormat('dd/MM/yyyy HH:mm').format(fecha);

                        return Card(
                          margin: EdgeInsets.zero,
                          child: ExpansionTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.manage_history),
                            ),
                            title: Text(
                              item['accion']?.toString() ?? 'CAMBIO',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${item['administrador_nombre'] ?? 'Administrador'}'
                              ' · $fechaVisible\n'
                              'Motivo: ${item['motivo'] ?? '—'}',
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 18),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const Text(
                                'Información anterior',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _datosAuditoria(item['datos_anteriores']),
                              const SizedBox(height: 12),
                              const Text(
                                'Información nueva',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _datosAuditoria(item['datos_nuevos']),
                            ],
                          ),
                        );
                      },
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

  void _mostrarAccionesAdministrativas() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Administrar atención',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Las modificaciones requieren un motivo y quedan auditadas.',
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Historial de cambios'),
                subtitle: const Text(
                  'Consultar acciones, motivos y valores anteriores.',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _mostrarHistorialAuditoria();
                },
              ),
              if (_cerrado) ...[
                ListTile(
                  leading: const Icon(Icons.edit_note_outlined),
                  title: const Text('Editar atención'),
                  subtitle: const Text(
                    'Corregir causa, tiempo, costos o descripciones.',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editarAtencionComoAdministrador();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.settings_backup_restore,
                    color: Colors.redAccent,
                  ),
                  title: const Text('Reabrir y limpiar atención'),
                  subtitle: const Text(
                    'Respaldar la solución y devolver el REDIR a ABIERTO.',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reabrirYLimpiarComoAdministrador();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;

    final bool mobile = width < 760;
    final bool sideBySide = width >= 1180;

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        backgroundColor: LuvegiColors.surface,
        surfaceTintColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.codigo),
        actions: [
          if (_puedeAdministrarAtencion)
            IconButton(
              onPressed: _procesandoAdministracion
                  ? null
                  : _mostrarAccionesAdministrativas,
              tooltip: 'Administrar atención',
              icon: _procesandoAdministracion
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.admin_panel_settings_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            mobile ? LuvegiSpacing.md : LuvegiSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1500,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(mobile),
                  const SizedBox(
                    height: LuvegiSpacing.lg,
                  ),
                  if (sideBySide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildProblemColumn(mobile),
                        ),
                        const SizedBox(
                          width: LuvegiSpacing.lg,
                        ),
                        Expanded(
                          child: _buildSolutionColumn(mobile),
                        ),
                      ],
                    )
                  else ...[
                    _buildProblemColumn(mobile),
                    const SizedBox(
                      height: LuvegiSpacing.lg,
                    ),
                    _buildSolutionColumn(mobile),
                  ],
                  const SizedBox(
                    height: LuvegiSpacing.lg,
                  ),
                ],
              ),
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
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: LuvegiColors.menuHover,
              borderRadius: BorderRadius.circular(
                LuvegiRadius.md,
              ),
              border: Border.all(
                color: LuvegiColors.menuSelected,
              ),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: LuvegiColors.secondary,
              size: 29,
            ),
          ),
          const SizedBox(
            width: LuvegiSpacing.lg,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro y atención del REDIR',
                  style: LuvegiText.title.copyWith(
                    fontSize: mobile ? 20 : 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.codigo,
                  style: LuvegiText.caption.copyWith(
                    color: LuvegiColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemColumn(bool mobile) {
    return Column(
      children: [
        _buildSection(
          title: 'Registro del problema',
          subtitle:
              'Información original registrada por el emisor. '
              'Estos datos no pueden modificarse.',
          icon: Icons.lock_outline_rounded,
          child: _buildProblemData(mobile),
        ),
        const SizedBox(
          height: LuvegiSpacing.lg,
        ),
        _buildSection(
          title: 'Descripción',
          subtitle:
              'Formulario específico registrado por el área emisora.',
          icon: Icons.tune_rounded,
          child: _buildVariables(mobile),
        ),
      ],
    );
  }

  Widget _buildProblemData(bool mobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInternalSectionHeader(
          title: 'Información General',
          subtitle:
              'Datos principales de identificación del REDIR.',
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(
          height: LuvegiSpacing.md,
        ),
        _responsiveGrid(
          mobile: mobile,
          children: [
            _readOnlyItem(
              'Código REDIR',
              widget.codigo,
            ),
            _readOnlyItem(
              'Usuario emisor',
              widget.usuarioEmisor,
            ),
            _readOnlyItem(
              'Correo del emisor',
              widget.correoEmisor,
            ),
            _readOnlyItem(
              'Fecha de creación',
              DateFormat('dd/MM/yyyy HH:mm').format(widget.fechaRegistro),
            ),
            _readOnlyItem(
              'Área responsable',
              widget.area,
            ),
            _readOnlyItem(
              'Área emisora',
              widget.tipoEmisor,
            ),
          ],
        ),
        const SizedBox(
          height: LuvegiSpacing.xl,
        ),
        const SizedBox(
          height: LuvegiSpacing.md,
        ),
        _responsiveGrid(
          mobile: mobile,
          children: [
            _readOnlyItem(
              'Tipo de registro',
              widget.tipoRegistro,
            ),
            _readOnlyItem(
              'Tipo de problema',
              widget.tipoProblema,
            ),
            _readOnlyItem(
              'Fecha del incidente/reclamo',
              widget.fechaIncidente,
            ),
            _readOnlyItem(
              'Hora del incidente/reclamo',
              widget.horaIncidente,
            ),
            _readOnlyItem(
              'Pedido',
              widget.pedido,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInternalSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: LuvegiSpacing.md,
        vertical: LuvegiSpacing.md,
      ),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(
          LuvegiRadius.md,
        ),
        border: Border.all(
          color: LuvegiColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: LuvegiColors.surface,
              borderRadius: BorderRadius.circular(
                LuvegiRadius.sm,
              ),
              border: Border.all(
                color: LuvegiColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: LuvegiColors.secondary,
            ),
          ),
          const SizedBox(
            width: LuvegiSpacing.md,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: LuvegiColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: LuvegiColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariables(bool mobile) {
    final variables = _variablesOrdenadas();
    const camposAmplios = {
      'Descripción',
      'Observación',
      'Breve descripción',
    };
    final camposGrid = variables
        .where((entry) => !camposAmplios.contains(entry.key))
        .toList();
    final camposTexto = variables
        .where((entry) => camposAmplios.contains(entry.key))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (camposGrid.isNotEmpty)
          _responsiveGrid(
            mobile: mobile,
            children: camposGrid
                .map(
                  (entry) => _readOnlyItem(
                    entry.key,
                    _formatValue(entry.value),
                  ),
                )
                .toList(),
          ),
        for (final entry in camposTexto) ...[
          if (camposGrid.isNotEmpty || entry != camposTexto.first)
            const SizedBox(height: LuvegiSpacing.md),
          _readOnlyItem(
            entry.key,
            _formatValue(entry.value),
          ),
        ],
      ],
    );
  }

  List<MapEntry<String, dynamic>> _variablesOrdenadas() {
    final variables = widget.variablesEspecificas;

    switch (widget.tipoEmisor.trim().toLowerCase()) {
      case 'servicios comerciales':
        return [
          MapEntry(
            'Origen del incidente',
            variables['origen_incidente'],
          ),
          MapEntry('Cliente', variables['cliente']),
          MapEntry('Lugar', variables['lugar']),
          MapEntry('Marca', variables['marca']),
          MapEntry('Modelo L.', variables['modelo_l']),
          MapEntry('Modelo F.', variables['modelo_f']),
          MapEntry('Serie', variables['serie']),
          MapEntry('Horómetro', variables['horometro']),
          MapEntry('Área', variables['area']),
          MapEntry('Descripción', variables['descripcion']),
          MapEntry('Observación', variables['observacion']),
        ];
      case 'proyectos':
        return [
          MapEntry('Puntuación', variables['puntuacion']),
          MapEntry(
            'Origen del incidente',
            variables['origen_incidente'],
          ),
          MapEntry(
            'Impacto en el proyecto (días)',
            variables['impacto_tiempo_dias'],
          ),
          MapEntry(
            'Impacto en el equipo (HH)',
            variables['impacto_recursos_hh'],
          ),
          MapEntry(
            'Impacto económico en dólares',
            variables['impacto_economico_usd'],
          ),
          MapEntry(
            'Breve descripción',
            variables['breve_descripcion'] ?? variables['breve_descripción'],
          ),
        ];
      case 'operaciones':
        return [
          MapEntry(
            'Origen del incidente',
            variables['origen_incidente'],
          ),
          MapEntry('Sobrecostos', variables['sobrecostos']),
          MapEntry(
            'Horas hombres perdidas total',
            variables['horas_hombres_perdidas_total'],
          ),
          MapEntry(
            'Breve descripción',
            variables['breve_descripcion'] ?? variables['breve_descripción'],
          ),
        ];
      default:
        return variables.entries
            .map(
              (entry) => MapEntry(
                _formatLabel(entry.key),
                entry.value,
              ),
            )
            .toList();
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) {
      return '—';
    }

    if (value is bool) {
      return value ? 'Sí' : 'No';
    }

    if (value is DateTime) {
      return DateFormat(
        'dd/MM/yyyy HH:mm:ss',
      ).format(value);
    }

    if (value is List) {
      if (value.isEmpty) {
        return '—';
      }

      return value.map((item) => item.toString()).join(', ');
    }

    if (value is Map) {
      if (value.isEmpty) {
        return '—';
      }

      return value.entries
          .map(
            (entry) =>
                '${_formatLabel(entry.key.toString())}: ${entry.value}',
          )
          .join('\n');
    }

    final String texto = value.toString().trim();

    if (texto.isEmpty ||
        texto.toLowerCase() == 'null' ||
        texto == '[]' ||
        texto == '{}') {
      return '—';
    }

    return texto;
  }

  Widget _buildSolutionColumn(bool mobile) {
    return _buildSection(
      title: 'Atención y solución',
      subtitle:
          'El usuario que completa esta sección quedará registrado '
          'automáticamente como responsable de la solución.',
      icon: Icons.engineering_outlined,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_soloLectura) ...[
              _buildClosedNotice(),
              const SizedBox(height: LuvegiSpacing.lg),
            ],
            _buildResponsableSolucion(),
            const SizedBox(height: LuvegiSpacing.xl),
            _buildStepHeader(
              number: '1',
              title: 'Identificación de la causa',
              subtitle: 'Selecciona el tipo de causa identificado.',
              icon: Icons.manage_search_outlined,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            DropdownButtonFormField<String>(
              value: _tipoCausa,
              isExpanded: true,
              decoration: _inputDecoration(
                label: 'Tipo de causa',
                hint: 'Selecciona una causa',
                icon: Icons.category_outlined,
              ),
              items: _tiposCausa
                  .map(
                    (causa) => DropdownMenuItem<String>(
                      value: causa,
                      child: Text(
                        causa,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              validator: null,
              onChanged: _soloLectura || _guardando
                  ? null
                  : (value) {
                      setState(() => _tipoCausa = value);
                    },
            ),
            const SizedBox(height: LuvegiSpacing.xl),
            _buildStepHeader(
              number: '2',
              title: 'Tiempo y costos de la solución',
              subtitle:
                  'Registra las horas empleadas y los costos asociados.',
              icon: Icons.timer_outlined,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            _responsiveFields(
              mobile: mobile,
              children: [
                TextFormField(
                  controller: _tiempoCtrl,
                  enabled: !_soloLectura && !_guardando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    label: 'Tiempo de solución en horas',
                    hint: 'Ejemplo: 2.5',
                    icon: Icons.schedule_outlined,
                  ),
                  validator: _soloLectura
                      ? null
                      : _validarNumero(
                          mensaje: 'Ingresa un tiempo válido.',
                        ),
                ),
                TextFormField(
                  controller: _costoCtrl,
                  enabled: !_soloLectura && !_guardando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    label: 'Costos asociados',
                    hint: 'Coloca 0 si no hubo costos',
                    icon: Icons.payments_outlined,
                  ),
                  validator: _soloLectura
                      ? null
                      : _validarNumero(
                          mensaje: 'Ingresa un costo válido.',
                        ),
                ),
              ],
            ),
            const SizedBox(height: LuvegiSpacing.xl),
            _buildStepHeader(
              number: '3',
              title: 'Descripción exacta de lo sucedido',
              subtitle:
                  'Detalla los hechos y la causa encontrada durante la atención.',
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextFormField(
              controller: _descripcionHechosCtrl,
              enabled: !_soloLectura && !_guardando,
              minLines: 5,
              maxLines: 8,
              decoration: _inputDecoration(
                label: 'Descripción exacta de lo sucedido',
                hint:
                    'Describe lo ocurrido y la causa que fue identificada.',
                icon: Icons.notes_rounded,
                alignTop: true,
              ),
              validator: null,
            ),
            const SizedBox(height: LuvegiSpacing.xl),
            _buildStepHeader(
              number: '4',
              title: 'Solución implementada',
              subtitle: 'Explica exactamente cómo se resolvió el problema.',
              icon: Icons.task_alt_outlined,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextFormField(
              controller: _solucionCtrl,
              enabled: !_soloLectura && !_guardando,
              minLines: 5,
              maxLines: 8,
              decoration: _inputDecoration(
                label: 'Descripción de cómo se resolvió',
                hint: 'Explica exactamente cómo se solucionó.',
                icon: Icons.task_alt_outlined,
                alignTop: true,
              ),
              validator: null,
            ),
            const SizedBox(height: LuvegiSpacing.xl),
            _buildConfirmationActions(mobile),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsableSolucion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: LuvegiColors.surface,
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
              border: Border.all(color: LuvegiColors.border),
            ),
            child: const Icon(
              Icons.person_pin_outlined,
              color: LuvegiColors.secondary,
              size: 22,
            ),
          ),
          const SizedBox(width: LuvegiSpacing.md),
          Expanded(
            child: _cargandoResponsable
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Responsable de la solución',
                        style: TextStyle(
                          color: LuvegiColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 9),
                      LinearProgressIndicator(minHeight: 3),
                      SizedBox(height: 7),
                      Text(
                        'Identificando la cuenta logueada...',
                        style: TextStyle(
                          color: LuvegiColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Responsable de la solución',
                        style: TextStyle(
                          color: LuvegiColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _responsableNombre.isEmpty
                            ? 'Usuario no identificado'
                            : _responsableNombre,
                        style: const TextStyle(
                          color: LuvegiColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_responsableCorreo.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        SelectableText(
                          _responsableCorreo,
                          style: const TextStyle(
                            color: LuvegiColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (_responsableRol.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: LuvegiColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: LuvegiColors.border),
                          ),
                          child: Text(
                            _responsableRol,
                            style: const TextStyle(
                              color: LuvegiColors.secondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
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

  Widget _buildStepHeader({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: LuvegiColors.secondary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: LuvegiSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: LuvegiColors.secondary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: LuvegiColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: LuvegiColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationActions(bool mobile) {
    if (_soloLectura) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(LuvegiSpacing.lg),
        decoration: BoxDecoration(
          color: LuvegiColors.surfaceHover,
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
          border: Border.all(color: LuvegiColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: LuvegiColors.secondary,
                  size: 21,
                ),
                const SizedBox(width: LuvegiSpacing.sm),
                Expanded(
                  child: Text(
                    _cerrado
                        ? 'Atención registrada el ${DateFormat('dd/MM/yyyy HH:mm').format(widget.fechaCierre!)}. '
                            'La información está bloqueada y disponible únicamente para consulta.'
                        : 'Este REDIR está pendiente. Puedes consultarlo por ser el emisor, pero la atención corresponde exclusivamente al área ${widget.area}.',
                    style: const TextStyle(
                      color: LuvegiColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LuvegiSpacing.lg),
            _buildActions(mobile),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: LuvegiColors.secondary,
                size: 21,
              ),
              SizedBox(width: LuvegiSpacing.sm),
              Expanded(
                child: Text(
                  'Al guardar, el sistema registrará al usuario logueado '
                  'como responsable, generará la fecha de cierre y cambiará '
                  'el estado del REDIR a CERRADO.',
                  style: TextStyle(
                    color: LuvegiColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.lg),
          _buildActions(mobile),
        ],
      ),
    );
  }

  Widget _buildClosedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: LuvegiColors.secondary,
            size: 21,
          ),
          const SizedBox(width: LuvegiSpacing.md),
          Expanded(
            child: Text(
              _cerrado
                  ? 'Este REDIR ya fue atendido y cerrado. La solución no puede modificarse.'
                  : 'Modo consulta: solo el área ${widget.area} puede registrar la atención y cerrar este REDIR.',
              style: const TextStyle(
                color: LuvegiColors.textSecondary,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? Function(String?) _validarNumero({
    required String mensaje,
  }) {
    return (value) {
      final String texto = (value ?? '')
          .trim()
          .replaceAll(',', '.');

      final double? numero = double.tryParse(texto);

      if (texto.isEmpty) {
        return null;
      }

      if (numero == null || numero < 0) {
        return mensaje;
      }

      return null;
    };
  }

  double? _numeroOpcional(String value) {
    final texto = value.trim().replaceAll(',', '.');
    return texto.isEmpty ? null : double.tryParse(texto);
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        LuvegiSpacing.lg,
      ),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  size: 20,
                  color: LuvegiColors.secondary,
                ),
              ),
              const SizedBox(
                width: LuvegiSpacing.md,
              ),
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: LuvegiText.caption.copyWith(
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: LuvegiSpacing.lg,
          ),
          child,
        ],
      ),
    );
  }

  Widget _responsiveGrid({
    required bool mobile,
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = mobile
            ? 1
            : constraints.maxWidth < 700
                ? 2
                : 3;

        const double gap = LuvegiSpacing.md;

        final double itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) /
                columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _responsiveFields({
    required bool mobile,
    required List<Widget> children,
  }) {
    if (mobile) {
      return Column(
        children: [
          for (
            int index = 0;
            index < children.length;
            index++
          ) ...[
            children[index],
            if (index != children.length - 1)
              const SizedBox(
                height: LuvegiSpacing.md,
              ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (
          int index = 0;
          index < children.length;
          index++
        ) ...[
          Expanded(
            child: children[index],
          ),
          if (index != children.length - 1)
            const SizedBox(
              width: LuvegiSpacing.lg,
            ),
        ],
      ],
    );
  }

  Widget _readOnlyItem(
    String label,
    String value,
  ) {
    final String visibleValue =
        value.trim().isEmpty ? '—' : value;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 85,
      ),
      padding: const EdgeInsets.all(
        LuvegiSpacing.md,
      ),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(
          LuvegiRadius.md,
        ),
        border: Border.all(
          color: LuvegiColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: LuvegiColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          SelectableText(
            visibleValue,
            style: const TextStyle(
              color: LuvegiColors.textPrimary,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    bool alignTop = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignTop,
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          LuvegiRadius.md,
        ),
        borderSide: const BorderSide(
          color: LuvegiColors.border,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          LuvegiRadius.md,
        ),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          LuvegiRadius.md,
        ),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildActions(bool mobile) {
    final Widget volver = OutlinedButton.icon(
      onPressed: _guardando ? null : () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('Volver'),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          mobile ? double.infinity : 125,
          49,
        ),
        foregroundColor: LuvegiColors.textPrimary,
        side: const BorderSide(color: LuvegiColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
        ),
      ),
    );

    if (_soloLectura) {
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: mobile ? double.infinity : 150,
          child: volver,
        ),
      );
    }

    final Widget guardar = ElevatedButton.icon(
      onPressed: _guardando ? null : _guardarAtencion,
      icon: _guardando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined),
      label: Text(
        _guardando ? 'Guardando...' : 'Guardar atención',
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(
          mobile ? double.infinity : 180,
          49,
        ),
        backgroundColor: LuvegiColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
        ),
      ),
    );

    if (mobile) {
      return Column(
        children: [
          guardar,
          const SizedBox(height: LuvegiSpacing.sm),
          volver,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        volver,
        const SizedBox(width: LuvegiSpacing.md),
        guardar,
      ],
    );
  }

  String _formatLabel(String value) {
    final String normalized = value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();

    if (normalized.isEmpty) {
      return 'Variable';
    }

    return normalized
        .split(RegExp(r'\s+'))
        .map(
          (word) {
            if (word.isEmpty) {
              return word;
            }

            return '${word[0].toUpperCase()}'
                '${word.substring(1).toLowerCase()}';
          },
        )
        .join(' ');
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