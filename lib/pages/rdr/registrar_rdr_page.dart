import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/rdr_service.dart';
import '../../services/auditoria_service.dart';

const String _baseUrl = 'https://portal.luvegi.com/api_luvegi';

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
  bool _guardando = false;
  bool _cargandoAreas = true;
  final RdrService _rdrService = RdrService();
  final AuditoriaService _auditoria = AuditoriaService();

  // Listas Dinámicas desde BD
  List<String> _misAreas = [];
  List<String> _todasAreas = [];

  // Sección 1: Información General
  String? _areaEmisora;
  String? _tipoRegistro;
  String? _tipoProblema;
  String? _areaResponsable;
  DateTime? _fechaIncidente;
  TimeOfDay? _horaIncidente;
  final _pedidoCtrl = TextEditingController();

  // Sección 2: Información del Reclamo/Incidencia
  final _impactoEconomicoCtrl = TextEditingController();
  final _impactoHhCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _puntuacionCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();

  static const List<String> _tiposRegistro = ['Incidencia', 'Reclamo'];
  static const List<String> _tiposProblema = [
    'Comunicación',
    'Cumplimiento de servicio',
    'Cumplimiento de documento',
    'Cumplimiento de producto',
    'Calidad de servicio',
    'Calidad de producto',
    'Cumplimiento de fábrica',
    'Calidad de fábrica',
    'Calidad de documento',
    'Rechazo del servicio',
  ];

  @override
  void initState() {
    super.initState();
    _cargarAreas();
  }

  Future<void> _cargarAreas() async {
    try {
      final url = Uri.parse('$_baseUrl/obtener_mis_areas.php');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['ok'] == true) {
          setState(() {
            _misAreas = List<String>.from(body['data']['mis_areas'] ?? []);
            _todasAreas = List<String>.from(
              body['data']['todas_las_areas'] ?? [],
            );

            // Auto-seleccionar si solo pertenece a 1 área
            if (_misAreas.isNotEmpty && _misAreas.length == 1) {
              _areaEmisora = _misAreas.first;
            }
          });
        } else {
          _mostrarError('Error BD: ${body['mensaje']}');
        }
      }
    } catch (e) {
      _mostrarError('Error de red: $e');
    } finally {
      if (mounted) setState(() => _cargandoAreas = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaIncidente ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _fechaIncidente = picked);
    }
  }

  Future<void> _seleccionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaIncidente ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _horaIncidente = picked);
    }
  }

  Future<void> _registrar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_areaEmisora == null) {
      _mostrarError('Por favor, selecciona tu Área Emisora.');
      return;
    }

    setState(() => _guardando = true);

    try {
      final payload = {
        'usuario_emisor_id': widget.usuarioId,
        'tipo_emisor': _areaEmisora,
        'tipo_registro': _tipoRegistro,
        'tipo_problema': _tipoProblema,
        'area_responsable': _areaResponsable,
        'fecha_incidente': _fechaIncidente == null
            ? ''
            : DateFormat('yyyy-MM-dd').format(_fechaIncidente!),
        'hora_incidente': _horaIncidente == null
            ? ''
            : '${_horaIncidente!.hour.toString().padLeft(2, '0')}:${_horaIncidente!.minute.toString().padLeft(2, '0')}:00',
        'pedido': _pedidoCtrl.text.trim(),
        'impacto_economico': _impactoEconomicoCtrl.text.trim(),
        'impacto_hh': _impactoHhCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'puntuacion': _puntuacionCtrl.text.trim(),
        'marca': _marcaCtrl.text.trim(),
      };

      final resp = await _rdrService.registrarRdr(
        token: widget.token,
        payload: payload,
      );
      if (!mounted) return;

      final codigo = resp['data']['codigo'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('REDIR $codigo registrado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );

      try {
        _auditoria
            .registrarActividad(
              widget.token,
              accion: 'REGISTRAR_REDIR',
              entidad: 'rdr',
              detalle:
                  '$codigo area_emisora=$_areaEmisora problema=$_tipoProblema',
            )
            .catchError((_) {});
      } catch (_) {}

      if (widget.onRegistrado != null) widget.onRegistrado!();
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return ColoredBox(
      color: LuvegiColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? LuvegiSpacing.md : LuvegiSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _buildSeccion1Card(isMobile),
                  const SizedBox(height: LuvegiSpacing.lg),
                  _buildSeccion2Card(isMobile),
                  const SizedBox(height: LuvegiSpacing.xl),
                  _buildBotonGuardar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(LuvegiSpacing.xl),
    decoration: BoxDecoration(
      color: LuvegiColors.surface,
      borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      border: Border.all(color: LuvegiColors.border),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(LuvegiRadius.md),
          ),
          child: const Icon(
            Icons.add_comment_outlined,
            color: LuvegiColors.secondary,
            size: 28,
          ),
        ),
        const SizedBox(width: LuvegiSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrar REDIR',
              style: LuvegiText.title.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 2),
            Text(
              'Registro de reclamos e incidencias.',
              style: LuvegiText.caption,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildSeccion1Card(bool isMobile) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(LuvegiSpacing.xl),
    decoration: BoxDecoration(
      color: LuvegiColors.surface,
      borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      border: Border.all(color: LuvegiColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.assignment_outlined,
              color: LuvegiColors.secondary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              '1. Información general',
              style: LuvegiText.title.copyWith(fontSize: 17),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            'Registra los datos generales del incidente o reclamo.',
            style: LuvegiText.caption,
          ),
        ),
        const SizedBox(height: LuvegiSpacing.xl),

        // Fila: Emisor / Área Emisora / Tipo Registro
        _buildGridRow(isMobile, [
          TextFormField(
            initialValue: '${widget.nombreUsuario} · ${widget.correoUsuario}',
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Usuario emisor',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
          ),

          // Selector Dinámico de Área Emisora
          _cargandoAreas
              ? const Center(child: LinearProgressIndicator())
              : DropdownButtonFormField<String>(
                  initialValue: _areaEmisora,
                  decoration: InputDecoration(
                    labelText: _misAreas.isEmpty
                        ? 'No tienes áreas asignadas'
                        : 'Área emisora (Tu área)',
                  ),
                  items: _misAreas
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: _misAreas.isEmpty
                      ? null
                      : (v) => setState(() => _areaEmisora = v),
                ),

          DropdownButtonFormField<String>(
            initialValue: _tipoRegistro,
            decoration: const InputDecoration(labelText: 'Tipo de registro'),
            items: _tiposRegistro
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _tipoRegistro = v),
          ),
        ]),
        const SizedBox(height: LuvegiSpacing.lg),

        // Fila: Tipo Problema / Área Responsable
        _buildGridRow(isMobile, [
          DropdownButtonFormField<String>(
            initialValue: _tipoProblema,
            decoration: const InputDecoration(labelText: 'Tipo de problema'),
            items: _tiposProblema
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _tipoProblema = v),
          ),

          // Selector Dinámico de Todas las Áreas
          _cargandoAreas
              ? const Center(child: LinearProgressIndicator())
              : DropdownButtonFormField<String>(
                  initialValue: _areaResponsable,
                  decoration: const InputDecoration(
                    labelText: 'Área responsable',
                  ),
                  items: _todasAreas
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (v) => setState(() => _areaResponsable = v),
                ),
        ]),
        const SizedBox(height: LuvegiSpacing.lg),

        // Fila: Fecha / Hora
        _buildGridRow(isMobile, [
          InkWell(
            onTap: _seleccionarFecha,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha del incidente/reclamo',
                prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(
                _fechaIncidente == null
                    ? ''
                    : DateFormat('dd/MM/yyyy').format(_fechaIncidente!),
              ),
            ),
          ),
          InkWell(
            onTap: _seleccionarHora,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Hora del incidente/reclamo',
                prefixIcon: Icon(Icons.access_time_rounded, size: 20),
              ),
              child: Text(
                _horaIncidente == null ? '' : _horaIncidente!.format(context),
              ),
            ),
          ),
        ]),
        const SizedBox(height: LuvegiSpacing.lg),

        // Pedido
        TextFormField(
          controller: _pedidoCtrl,
          decoration: const InputDecoration(
            labelText: 'Pedido',
            prefixIcon: Icon(Icons.edit_outlined, size: 20),
          ),
        ),
      ],
    ),
  );

  Widget _buildSeccion2Card(bool isMobile) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(LuvegiSpacing.xl),
    decoration: BoxDecoration(
      color: LuvegiColors.surface,
      borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      border: Border.all(color: LuvegiColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.tune_rounded,
              color: LuvegiColors.secondary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              '2. Información del Reclamo/Incidencia',
              style: LuvegiText.title.copyWith(fontSize: 17),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            'Completa los datos de impacto y detalle técnico del ticket.',
            style: LuvegiText.caption,
          ),
        ),
        const SizedBox(height: LuvegiSpacing.xl),

        _buildGridRow(isMobile, [
          TextFormField(
            controller: _impactoEconomicoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Impacto económico',
              prefixIcon: Icon(Icons.edit_outlined, size: 20),
            ),
          ),
          TextFormField(
            controller: _impactoHhCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Impacto en equipo (HH)',
              prefixIcon: Icon(Icons.edit_outlined, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: LuvegiSpacing.lg),

        _buildGridRow(isMobile, [
          TextFormField(
            controller: _puntuacionCtrl,
            decoration: const InputDecoration(
              labelText: 'Puntuación',
              prefixIcon: Icon(Icons.edit_outlined, size: 20),
            ),
          ),
          TextFormField(
            controller: _marcaCtrl,
            decoration: const InputDecoration(
              labelText: 'Marca',
              prefixIcon: Icon(Icons.edit_outlined, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: LuvegiSpacing.lg),

        TextFormField(
          controller: _descripcionCtrl,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes_rounded, size: 20),
          ),
        ),
      ],
    ),
  );

  Widget _buildBotonGuardar() => Align(
    alignment: Alignment.centerRight,
    child: ElevatedButton.icon(
      onPressed: _guardando ? null : _registrar,
      icon: _guardando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.save_rounded, size: 20),
      label: Text(_guardando ? 'Guardando...' : 'Guardar y Crear REDIR'),
      style: ElevatedButton.styleFrom(
        backgroundColor: LuvegiColors.secondary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
        ),
      ),
    ),
  );

  Widget _buildGridRow(bool isMobile, List<Widget> children) {
    if (isMobile) {
      return Column(
        children: children
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: LuvegiSpacing.md),
                child: c,
              ),
            )
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: c,
              ),
            ),
          )
          .toList(),
    );
  }
}
