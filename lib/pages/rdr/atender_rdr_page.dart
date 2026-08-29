import 'package:flutter/material.dart';

import '../../services/rdr_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';

class AtenderRdrPage extends StatefulWidget {
  final String token;
  final String codigo;
  final String tipoEmisor;
  final String tipoRegistro;
  final String tipoProblema;
  final String area;

  const AtenderRdrPage({
    super.key,
    required this.token,
    required this.codigo,
    required this.tipoEmisor,
    required this.tipoRegistro,
    required this.tipoProblema,
    required this.area,
  });

  @override
  State<AtenderRdrPage> createState() => _AtenderRdrPageState();
}

class _AtenderRdrPageState extends State<AtenderRdrPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RdrService _rdrService = RdrService();

  final TextEditingController _tiempoCtrl = TextEditingController();
  final TextEditingController _costoCtrl = TextEditingController();
  final TextEditingController _descripcionHechosCtrl = TextEditingController();
  final TextEditingController _solucionCtrl = TextEditingController();

  String? _tipoCausa;
  bool _guardando = false;

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

  @override
  void dispose() {
    _tiempoCtrl.dispose();
    _costoCtrl.dispose();
    _descripcionHechosCtrl.dispose();
    _solucionCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmarGuardado() async {
    Offset desplazamiento = Offset.zero;

    final bool? confirmado = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Confirmar atención del REDIR',
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final Size pantalla = MediaQuery.sizeOf(context);
            final bool mobile = pantalla.width < 600;
            final double anchoModal =
                mobile ? pantalla.width - 32 : 480;

            void moverModal(DragUpdateDetails details) {
              final double limiteX =
                  ((pantalla.width - anchoModal) / 2)
                      .clamp(0, double.infinity)
                      .toDouble();
              final double limiteY =
                  (pantalla.height * 0.32).clamp(80, 280).toDouble();

              setDialogState(() {
                desplazamiento = Offset(
                  (desplazamiento.dx + details.delta.dx)
                      .clamp(-limiteX, limiteX)
                      .toDouble(),
                  (desplazamiento.dy + details.delta.dy)
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
                    offset: desplazamiento,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: anchoModal,
                        maxHeight: pantalla.height - 32,
                      ),
                      child: Material(
                        color: LuvegiColors.surface,
                        elevation: 18,
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
                              onPanUpdate: moverModal,
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
                                      color: LuvegiColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Confirmar atención',
                                        style: LuvegiText.heading.copyWith(
                                          fontSize: 18,
                                          color: LuvegiColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Tooltip(
                                      message:
                                          'Arrastra esta barra para mover el cuadro',
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        color: LuvegiColors.textSecondary
                                            .withOpacity(0.75),
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
                                            .withOpacity(0.09),
                                        borderRadius: BorderRadius.circular(
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
                                            Icons.warning_amber_rounded,
                                            color: LuvegiColors.warning,
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
                                                color:
                                                    LuvegiColors.textPrimary,
                                                fontWeight: FontWeight.w700,
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
                                    _datoConfirmacion(
                                      'Código REDIR',
                                      widget.codigo,
                                    ),
                                    _datoConfirmacion(
                                      'Tipo de causa',
                                      _tipoCausa ?? '—',
                                    ),
                                    _datoConfirmacion(
                                      'Tiempo de solución',
                                      '${_tiempoCtrl.text.trim()} hora(s)',
                                    ),
                                    _datoConfirmacion(
                                      'Costos asociados',
                                      _costoCtrl.text.trim().isEmpty
                                          ? '—'
                                          : _costoCtrl.text.trim(),
                                    ),
                                    const SizedBox(
                                      height: LuvegiSpacing.sm,
                                    ),
                                    Text(
                                      'Puedes arrastrar el encabezado del cuadro '
                                      'para revisar la información de la pantalla.',
                                      style: LuvegiText.body.copyWith(
                                        color: LuvegiColors.textSecondary,
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
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                Navigator.pop(
                                                  dialogContext,
                                                  true,
                                                ),
                                            icon: const Icon(
                                              Icons.lock_outline_rounded,
                                            ),
                                            label: const Text(
                                              'Sí, guardar y cerrar',
                                            ),
                                            style:
                                                ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  LuvegiColors.secondary,
                                              foregroundColor: Colors.white,
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
                                            Icons.lock_outline_rounded,
                                          ),
                                          label: const Text(
                                            'Sí, guardar y cerrar',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                LuvegiColors.secondary,
                                            foregroundColor: Colors.white,
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

  Widget _datoConfirmacion(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
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

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final bool confirmado = await _confirmarGuardado();
    if (!confirmado || !mounted) return;

    setState(() => _guardando = true);

    try {
      final double tiempo = double.parse(
        _tiempoCtrl.text.trim().replaceAll(',', '.'),
      );
      final double costo = double.parse(
        _costoCtrl.text.trim().replaceAll(',', '.'),
      );

      final response = await _rdrService.atenderRdr(
        token: widget.token,
        codigo: widget.codigo,
        tipoCausa: _tipoCausa!,
        tiempoSolucionHoras: tiempo,
        costosAsociados: costo,
        descripcionSucedido: _descripcionHechosCtrl.text.trim(),
        descripcionSolucion: _solucionCtrl.text.trim(),
      );

      if (!mounted) return;

      if (response['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atención del REDIR registrada correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final String errorMsg = response['mensaje'] ??
            response['error'] ??
            'No se pudo registrar la atención.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on RdrApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al conectar con el servidor: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        backgroundColor: LuvegiColors.surface,
        surfaceTintColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Atender ${widget.codigo}'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          mobile ? LuvegiSpacing.md : LuvegiSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(mobile),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _buildReferenceSection(mobile),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _buildAttentionSection(mobile),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _buildActions(mobile),
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
              borderRadius: BorderRadius.circular(LuvegiRadius.md),
              border: Border.all(color: LuvegiColors.menuSelected),
            ),
            child: const Icon(
              Icons.engineering_outlined,
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
                  'Atención del REDIR',
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

  Widget _buildReferenceSection(bool mobile) {
    return _buildSection(
      title: 'Referencia del registro',
      subtitle:
          'Consulta la clasificación principal antes de completar la atención.',
      icon: Icons.description_outlined,
      child: _responsiveGrid(
        mobile: mobile,
        children: [
          _readOnlyItem('Código REDIR', widget.codigo),
          _readOnlyItem('Tipo de emisor', widget.tipoEmisor),
          _readOnlyItem('Tipo de registro', widget.tipoRegistro),
          _readOnlyItem('Tipo de problema', widget.tipoProblema),
          _readOnlyItem('Área', widget.area),
        ],
      ),
    );
  }

  Widget _buildAttentionSection(bool mobile) {
    return _buildSection(
      title: 'Información de la atención',
      subtitle:
          'Completa los datos requeridos para registrar la solución del REDIR.',
      icon: Icons.task_alt_outlined,
      child: Column(
        children: [
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
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Selecciona el tipo de causa.';
              }
              return null;
            },
            onChanged: (value) {
              setState(() => _tipoCausa = value);
            },
          ),
          const SizedBox(height: LuvegiSpacing.md),
          _responsiveFields(
            mobile: mobile,
            children: [
              TextFormField(
                controller: _tiempoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration(
                  label: 'Tiempo de solución en horas',
                  hint: 'Ejemplo: 2.5',
                  icon: Icons.schedule_outlined,
                ),
                validator: _validarNumeroNoNegativo(
                  mensaje: 'Ingresa un tiempo válido en horas.',
                ),
              ),
              TextFormField(
                controller: _costoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration(
                  label: 'Costos asociados',
                  hint: 'Coloca 0 si no existieron costos',
                  icon: Icons.payments_outlined,
                ),
                validator: _validarNumeroNoNegativo(
                  mensaje: 'Ingresa un costo válido.',
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.md),
          TextFormField(
            controller: _descripcionHechosCtrl,
            minLines: 5,
            maxLines: 8,
            maxLength: 1500,
            decoration: _inputDecoration(
              label: 'Descripción exacta de lo sucedido',
              hint:
                  'Describe exactamente lo ocurrido y la causa identificada.',
              icon: Icons.notes_rounded,
              alignTop: true,
            ),
            validator: _validarDescripcion(
              mensaje:
                  'Describe lo sucedido con al menos 15 caracteres.',
            ),
          ),
          const SizedBox(height: LuvegiSpacing.md),
          TextFormField(
            controller: _solucionCtrl,
            minLines: 5,
            maxLines: 8,
            maxLength: 1500,
            decoration: _inputDecoration(
              label: 'Descripción de cómo se resolvió',
              hint: 'Explica exactamente cómo se solucionó el REDIR.',
              icon: Icons.build_circle_outlined,
              alignTop: true,
            ),
            validator: _validarDescripcion(
              mensaje:
                  'Describe la solución con al menos 15 caracteres.',
            ),
          ),
          const SizedBox(height: LuvegiSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(LuvegiSpacing.md),
            decoration: BoxDecoration(
              color: LuvegiColors.menuHover,
              borderRadius: BorderRadius.circular(LuvegiRadius.md),
              border: Border.all(color: LuvegiColors.menuSelected),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: LuvegiColors.secondary,
                ),
                SizedBox(width: LuvegiSpacing.sm),
                Expanded(
                  child: Text(
                    'La fecha y hora de cierre se generarán automáticamente '
                    'cuando se guarde la atención completa. La hora se '
                    'registrará en formato de 24 horas.',
                    style: TextStyle(
                      color: LuvegiColors.textPrimary,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? Function(String?) _validarNumeroNoNegativo({
    required String mensaje,
  }) {
    return (value) {
      final String text = (value ?? '').trim().replaceAll(',', '.');
      final double? number = double.tryParse(text);

      if (number == null || number < 0) {
        return mensaje;
      }

      return null;
    };
  }

  String? Function(String?) _validarDescripcion({
    required String mensaje,
  }) {
    return (value) {
      if (value == null || value.trim().length < 15) {
        return mensaje;
      }

      return null;
    };
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.lg),
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
                  borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                  border: Border.all(color: LuvegiColors.border),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: LuvegiColors.secondary,
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: LuvegiText.caption.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LuvegiSpacing.lg),
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
            : constraints.maxWidth < 800
                ? 2
                : 3;

        const double gap = LuvegiSpacing.md;
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map(
                (child) => SizedBox(
                  width: width,
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
          for (int index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const SizedBox(height: LuvegiSpacing.md),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int index = 0; index < children.length; index++) ...[
          Expanded(child: children[index]),
          if (index != children.length - 1)
            const SizedBox(width: LuvegiSpacing.lg),
        ],
      ],
    );
  }

  Widget _readOnlyItem(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LuvegiSpacing.md),
      decoration: BoxDecoration(
        color: LuvegiColors.surfaceHover,
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        border: Border.all(color: LuvegiColors.border),
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
          const SizedBox(height: 5),
          Text(
            value.trim().isEmpty ? '—' : value,
            style: const TextStyle(
              color: LuvegiColors.textPrimary,
              fontSize: 13,
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
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        borderSide: const BorderSide(color: LuvegiColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        borderSide: const BorderSide(color: LuvegiColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        borderSide: const BorderSide(
          color: LuvegiColors.secondary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.md),
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
        minimumSize: Size(mobile ? double.infinity : 125, 49),
        foregroundColor: LuvegiColors.textPrimary,
        side: const BorderSide(color: LuvegiColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
        ),
      ),
    );

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
        minimumSize: Size(mobile ? double.infinity : 180, 49),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: LuvegiColors.surface,
      borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      border: Border.all(color: LuvegiColors.border),
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