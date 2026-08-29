import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/rdr_service.dart';

class RegistrarRdrPage extends StatefulWidget {
  final String token;
  final String nombreUsuario;
  final String correoUsuario;
  final String usuarioId;
  final VoidCallback? onRegistrado;

  const RegistrarRdrPage({
    super.key,
    required this.token,
    required this.nombreUsuario,
    required this.correoUsuario,
    required this.usuarioId,
    this.onRegistrado,
  });

  @override
  State<RegistrarRdrPage> createState() => _RegistrarRdrPageState();
}

class _RegistrarRdrPageState extends State<RegistrarRdrPage> {
  final _formKey = GlobalKey<FormState>();
  Timer? _timer;
  DateTime _marcaTemporal = DateTime.now();
  bool _guardando = false;
  bool _cargandoPerfil = true;
  String? _errorPerfil;
  String _nombreEmisor = '';
  String _correoEmisor = '';
  final RdrService _rdrService = RdrService();

  String? _tipoEmisor;
  String? _tipoRegistro;
  String? _tipoProblema;
  String? _areaResponsable;

  DateTime? _fechaIncidente;
  TimeOfDay? _horaIncidente;
  final _pedido = TextEditingController();

  // Campos específicos
  String? _origenIncidente;

  // Servicios Comerciales
  final _scCliente = TextEditingController();
  final _scLugar = TextEditingController();
  final _scMarca = TextEditingController();
  final _scModeloL = TextEditingController();
  final _scModeloF = TextEditingController();
  final _scSerie = TextEditingController();
  final _scHorometro = TextEditingController();
  final _scDescripcion = TextEditingController();
  final _scArea = TextEditingController();
  final _scObservacion = TextEditingController();

  // Proyectos
  final _prPuntuacion = TextEditingController();
  final _prImpactoTiempo = TextEditingController();
  final _prImpactoRecursos = TextEditingController();
  final _prImpactoEconomico = TextEditingController();
  final _prDescripcion = TextEditingController();

  // Operaciones
  final _opSobrecostos = TextEditingController();
  final _opHorasHombreTotal = TextEditingController();
  final _opBreveDescripcion = TextEditingController();

  static const _registros = ['Incidencia', 'Reclamo'];

  static const _problemas = [
    'Comunicación',
    'Cumplimiento de servicio',
    'Cumplimiento de documento',
    'Cumplimiento de producto',
    'Cumplimiento de fábrica',
    'Calidad de servicio',
    'Calidad de producto',
    'Calidad de fábrica',
    'Calidad de documento',
  ];

  static const _areas = [
    'Servicios Comerciales',
    'Proyectos',
    'Operaciones',
  ];

  static const _origenesIncidente = [
    'Cliente',
    'Proveedor',
    'LUVEGI',
    'Fabricante',
    'Otro',
  ];

  List<TextEditingController> get _controllers => [
        _pedido,
        _scCliente,
        _scLugar,
        _scMarca,
        _scModeloL,
        _scModeloF,
        _scSerie,
        _scHorometro,
        _scDescripcion,
        _scArea,
        _scObservacion,
        _prPuntuacion,
        _prImpactoTiempo,
        _prImpactoRecursos,
        _prImpactoEconomico,
        _prDescripcion,
        _opSobrecostos,
        _opHorasHombreTotal,
        _opBreveDescripcion,
      ];

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _marcaTemporal = DateTime.now());
    });
  }

  Future<void> _cargarPerfil() async {
    try {
      final response = await _rdrService.obtenerMiPerfil(token: widget.token);
      final data = Map<String, dynamic>.from(response['data'] as Map);
      if (!mounted) return;
      setState(() {
        final area = (data['area'] ?? '').toString().trim();
        _tipoEmisor = area.isEmpty || area == 'TODAS' ? null : area;
        _nombreEmisor = (data['nombre'] ?? '').toString();
        _correoEmisor = (data['correo'] ?? '').toString();
        _errorPerfil = null;
      });
    } on RdrApiException catch (error) {
      if (mounted) setState(() => _errorPerfil = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorPerfil = 'No se pudo cargar el usuario emisor.');
      }
    } finally {
      if (mounted) setState(() => _cargandoPerfil = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _fecha(DateTime? value) => value == null ? '' : DateFormat('dd/MM/yyyy').format(value);
  String _hora(TimeOfDay? value) => value == null
      ? ''
      : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(DateTime? actual, ValueChanged<DateTime> onChanged) async {
    final value = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (value != null) onChanged(value);
  }

  Future<void> _pickTime(TimeOfDay? actual, ValueChanged<TimeOfDay> onChanged) async {
    final value = await showTimePicker(
      context: context,
      initialTime: actual ?? TimeOfDay.now(),
      helpText: 'Seleccionar hora (24 horas)',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (value != null) onChanged(value);
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);
    try {
      final payload = {
        'marca_temporal': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'usuario_id': widget.usuarioId,
        'nombre_usuario': widget.nombreUsuario,
        'correo_usuario': widget.correoUsuario,
        'tipo_emisor': _tipoEmisor,
        'tipo_registro': _tipoRegistro,
        'tipo_problema': _tipoProblema,
        'area_responsable': _areaResponsable,
        'fecha_incidente': _fechaIncidente == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_fechaIncidente!),
        'hora_incidente': _horaIncidente == null ? null : _hora(_horaIncidente),
        'pedido': _pedido.text.trim(),
        'estado': 'ABIERTO',
        'variables_especificas': _payloadEspecifico(),
      };

      final respuesta = await _rdrService.registrarRdr(
        token: widget.token,
        payload: payload,
      );
      if (!mounted) return;
      final data = respuesta['data'] is Map
          ? Map<String, dynamic>.from(respuesta['data'] as Map)
          : <String, dynamic>{};
      final codigo = (data['codigo'] ?? '').toString();
      _snack('REDIR $codigo registrado correctamente.');

      if (widget.onRegistrado != null) {
        widget.onRegistrado!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.pop(context, true);
      } else {
        _limpiar();
      }
    } on RdrApiException catch (error) {
      if (mounted) _snack(error.message, error: true);
    } catch (error, stackTrace) {
      debugPrint('Error al registrar REDIR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _snack('No se pudo conectar con el servidor.', error: true);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Map<String, dynamic> _payloadEspecifico() {
    if (_tipoEmisor == 'Servicios Comerciales') {
      return {
        'origen_incidente': _origenIncidente,
        'cliente': _scCliente.text.trim(),
        'lugar': _scLugar.text.trim(),
        'marca': _scMarca.text.trim(),
        'modelo_l': _scModeloL.text.trim(),
        'modelo_f': _scModeloF.text.trim(),
        'serie': _scSerie.text.trim(),
        'horometro': _scHorometro.text.trim(),
        'descripcion': _scDescripcion.text.trim(),
        'area': _scArea.text.trim(),
        'observacion': _scObservacion.text.trim(),
      };
    }

    if (_tipoEmisor == 'Proyectos') {
      return {
        'marca_temporal': DateFormat('yyyy-MM-dd HH:mm:ss').format(_marcaTemporal),
        'correo_electronico': widget.correoUsuario,
        'origen_incidente': _origenIncidente,
        'puntuacion': _prPuntuacion.text.trim(),
        'impacto_tiempo_dias': _prImpactoTiempo.text.trim(),
        'impacto_recursos_hh': _prImpactoRecursos.text.trim(),
        'impacto_economico_usd': _prImpactoEconomico.text.trim(),
        'breve_descripcion': _prDescripcion.text.trim(),
      };
    }

    if (_tipoEmisor == 'Operaciones') { 
      return {
        'origen_incidente': _origenIncidente,
        'sobrecostos': _opSobrecostos.text.trim(),
        'horas_hombres_perdidas_total': _opHorasHombreTotal.text.trim(),
        'breve_descripcion': _opBreveDescripcion.text.trim(),
      };
    }

    return {};
  }

  void _limpiar() {
    _formKey.currentState?.reset();
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _tipoRegistro = null;
      _tipoProblema = null;
      _areaResponsable = null;
      _origenIncidente = null;
      _fechaIncidente = null;
      _horaIncidente = null;
    });
  }

  void _snack(String message, {bool error = false}) {
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
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          width: anchoMensaje,
          duration: Duration(seconds: error ? 4 : 2),
          backgroundColor:
              error ? Colors.red.shade700 : const Color(0xFF12395B),
          elevation: 8,
          dismissDirection: DismissDirection.horizontal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;

    return ColoredBox(
      color: LuvegiColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(mobile ? LuvegiSpacing.md : LuvegiSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(mobile),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _section(
                    title: '1. Información general',
                    subtitle: 'Registra los datos generales del incidente o reclamo.',
                    icon: Icons.assignment_outlined,
                    child: Column(
                      children: [
                        _responsive(mobile, [
                          _readOnly('Usuario emisor',
                              _cargandoPerfil
                                  ? 'Cargando…'
                                  : (_nombreEmisor.isEmpty
                                      ? (_errorPerfil ?? 'Usuario no identificado')
                                      : '$_nombreEmisor · $_correoEmisor'),
                              Icons.person_outline_rounded),
                          _readOnly('Área emisora',
                              _cargandoPerfil ? 'Cargando…' : (_tipoEmisor ?? _errorPerfil ?? 'Sin área asignada'),
                              Icons.apartment_outlined),
                          _dropdown('Tipo de registro', 'Incidencia o reclamo', _tipoRegistro, _registros,
                              (v) => setState(() => _tipoRegistro = v), required: true),
                        ]),
                        _gap(),
                        _responsive(mobile, [
                          _dropdown('Tipo de problema', 'Selecciona una categoría', _tipoProblema, _problemas,
                              (v) => setState(() => _tipoProblema = v)),
                          _dropdown('Área responsable', 'Selecciona el área', _areaResponsable, _areas,
                              (v) => setState(() => _areaResponsable = v), required: true),
                        ]),
                        _gap(),
                        _responsive(mobile, [
                          _dateField('Fecha del incidente/reclamo', _fechaIncidente,
                              () => _pickDate(_fechaIncidente, (v) => setState(() => _fechaIncidente = v))),
                          _timeField('Hora del incidente/reclamo', _horaIncidente,
                              () => _pickTime(_horaIncidente, (v) => setState(() => _horaIncidente = v))),
                        ]),
                        _gap(),
                        _field(_pedido, 'Pedido', 'Ingresa el número de pedido'),
                      ],
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _section(
                    title: '2. Descripción',
                    subtitle: _tipoEmisor == null
                        ? 'Selecciona el tipo de emisor para mostrar su formulario.'
                        : 'Formulario correspondiente a $_tipoEmisor.',
                    icon: Icons.tune_rounded,
                    child: _dynamicForm(mobile),
                  ),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _actions(mobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool mobile) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(mobile ? LuvegiSpacing.lg : LuvegiSpacing.xl),
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
              child: const Icon(Icons.add_comment_outlined,
                  color: LuvegiColors.secondary, size: 29),
            ),
            const SizedBox(width: LuvegiSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrar REDIR',
                      style: LuvegiText.title.copyWith(
                          fontSize: mobile ? 20 : 23, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text('Registro de reclamos e incidencias.',
                      style: LuvegiText.caption.copyWith(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _dynamicForm(bool mobile) {
    switch (_tipoEmisor) {
      case 'Servicios Comerciales':
        return _serviciosComerciales(mobile);
      case 'Proyectos':
        return _proyectos(mobile);
      case 'Operaciones':
        return _operaciones(mobile);
      default:
        return _emptyForm();
    }
  }

  Widget _serviciosComerciales(bool mobile) => Column(
        children: [
          _dropdown(
            '¿Cuál fue el origen del incidente?',
            'Selecciona el origen',
            _origenIncidente,
            _origenesIncidente,
            (v) => setState(() => _origenIncidente = v),
          ),
          _gap(),
          _responsive(mobile, [
            _field(_scCliente, 'Cliente', 'Nombre del cliente'),
            _field(_scLugar, 'Lugar', 'Lugar relacionado'),
          ]),
          _gap(),
          _responsive(mobile, [
            _field(_scMarca, 'Marca', 'Marca del equipo'),
            _field(_scModeloL, 'Modelo L.', 'Modelo L.'),
          ]),
          _gap(),
          _responsive(mobile, [
            _field(_scModeloF, 'Modelo F.', 'Modelo F.'),
            _field(_scSerie, 'Serie', 'Número de serie'),
          ]),
          _gap(),
          _responsive(mobile, [
            _field(_scHorometro, 'Horómetro', 'Valor del horómetro',
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _field(_scArea, 'Área', 'Área relacionada'),
          ]),
          _gap(),
          _field(_scDescripcion, 'Descripción', 'Describe el reclamo o incidencia',
              minLines: 4, maxLines: 7),
          _gap(),
          _field(_scObservacion, 'Observación', 'Observaciones adicionales',
              required: false, minLines: 3, maxLines: 6),
        ],
      );

  Widget _proyectos(bool mobile) => Column(
        children: [
          _responsive(mobile, [
            _field(_prPuntuacion, 'Puntuación', 'Ingresa la puntuación',
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _dropdown(
              '¿Cuál fue el origen del incidente?',
              'Selecciona el origen',
              _origenIncidente,
              _origenesIncidente,
              (v) => setState(() => _origenIncidente = v),
            ),
          ]),
          _gap(),
          _responsive(mobile, [
            _field(_prImpactoTiempo, 'Impacto en el proyecto (días)',
                'Coloca 0 si no hubo retraso',
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _field(_prImpactoRecursos, 'Impacto en el equipo (HH)',
                'Ejemplo: 2 ingenieros × 4 horas = 8 HH',
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ]),
          _gap(),
          _field(_prImpactoEconomico, 'Impacto económico en dólares',
              'Ingresa únicamente el monto numérico',
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          _gap(),
          _field(_prDescripcion, 'Breve descripción',
              'Describe brevemente lo sucedido',
              minLines: 4, maxLines: 7),
        ],
      );

  Widget _operaciones(bool mobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dropdown(
            '¿Cuál fue el origen del incidente?',
            'Selecciona el origen',
            _origenIncidente,
            _origenesIncidente,
            (v) => setState(() => _origenIncidente = v),
          ),
          _gap(),
          _responsive(
            mobile,
            [
              _field(
                _opSobrecostos,
                'Sobrecostos',
                'Ingresa el monto total de los sobrecostos',
                keyboard: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validarNumeroNoNegativo(
                  mensaje: 'Ingresa un monto válido.',
                ),
              ),
              _field(
                _opHorasHombreTotal,
                'Horas hombres perdidas total',
                'Número de personas por horas utilizadas en total (incluye el transporte)',
                keyboard: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validarNumeroNoNegativo(
                  mensaje: 'Ingresa una cantidad válida de horas hombre.',
                ),
              ),
            ],
          ),
          _gap(),
          _field(
            _opBreveDescripcion,
            'Breve Descripción',
            'Ingresa una breve descripción de lo sucedido',
            minLines: 3,
            maxLines: 6,
            keyboard: TextInputType.multiline,
          ),
        ],
      );

  String? Function(String?) _validarNumeroNoNegativo({
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

  Widget _emptyForm() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(LuvegiSpacing.xl),
        decoration: BoxDecoration(
          color: LuvegiColors.background,
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
          border: Border.all(color: LuvegiColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.touch_app_outlined,
                size: 34, color: LuvegiColors.textSecondary),
            SizedBox(height: LuvegiSpacing.sm),
            Text('Selecciona un tipo de emisor para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: LuvegiColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(LuvegiSpacing.lg),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: LuvegiColors.secondary),
                const SizedBox(width: LuvegiSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: LuvegiText.title.copyWith(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: LuvegiText.caption),
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

  Widget _responsive(bool mobile, List<Widget> children) {
    if (mobile) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const SizedBox(height: LuvegiSpacing.md),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1)
            const SizedBox(width: LuvegiSpacing.lg),
        ],
      ],
    );
  }

  Widget _dropdown(String label, String hint, String? value,
          List<String> items, ValueChanged<String?> onChanged,
          {bool required = false}) =>
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: _decoration(label, hint, Icons.keyboard_arrow_down_rounded),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        validator: (value) =>
            required && value == null ? 'Selecciona una opción.' : null,
        onChanged: onChanged,
      );

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool required = false,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: validator ??
            (value) => required && (value == null || value.trim().isEmpty)
                ? 'Este campo es obligatorio.'
                : null,
        decoration: _decoration(label, hint,
            minLines > 1 ? Icons.notes_rounded : Icons.edit_outlined,
            alignTop: minLines > 1),
      );

  Widget _dateField(String label, DateTime? value, VoidCallback onTap,
          {bool required = true}) =>
      TextFormField(
        readOnly: true,
        controller: TextEditingController(text: _fecha(value)),
        onTap: onTap,
        validator: (_) => required && value == null ? 'Selecciona una fecha.' : null,
        decoration: _decoration(label, 'DD/MM/AAAA', Icons.calendar_month_outlined),
      );

  Widget _timeField(String label, TimeOfDay? value, VoidCallback onTap,
          {bool required = false}) =>
      TextFormField(
        readOnly: true,
        controller: TextEditingController(text: _hora(value)),
        onTap: onTap,
        validator: (_) => required && value == null ? 'Selecciona una hora.' : null,
        decoration: _decoration(label, 'HH:mm', Icons.access_time_rounded),
      );

  Widget _readOnly(String label, String value, IconData icon) => TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: value,
        readOnly: true,
        decoration: _decoration(label, '', icon)
            .copyWith(fillColor: LuvegiColors.surfaceHover),
      );

  InputDecoration _decoration(String label, String hint, IconData icon,
          {bool alignTop = false}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: alignTop,
        filled: true,
        fillColor: LuvegiColors.surface,
        prefixIcon: Icon(icon, size: 20, color: LuvegiColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: LuvegiSpacing.md, vertical: 17),
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
          borderSide: const BorderSide(color: LuvegiColors.secondary, width: 1.5),
        ),
      );

  Widget _actions(bool mobile) {
    final clear = OutlinedButton.icon(
      onPressed: _guardando ? null : _limpiar,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Limpiar'),
    );
    final save = ElevatedButton.icon(
      onPressed: _guardando ? null : _registrar,
      icon: _guardando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.save_outlined),
      label: Text(_guardando ? 'Registrando...' : 'Registrar REDIR'),
      style: ElevatedButton.styleFrom(
        backgroundColor: LuvegiColors.secondary,
        foregroundColor: Colors.white,
        minimumSize: Size(mobile ? double.infinity : 175, 49),
      ),
    );
    if (mobile) {
      return Column(children: [save, _gap(), SizedBox(width: double.infinity, child: clear)]);
    }
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [clear, _gapW(), save]);
  }

  Widget _gap() => const SizedBox(height: LuvegiSpacing.md);
  Widget _gapW() => const SizedBox(width: LuvegiSpacing.md);

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(color: LuvegiColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x08101828), blurRadius: 16, offset: Offset(0, 5)),
        ],
      );
}