import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../services/rdr_service.dart';
import '../../services/auditoria_service.dart';
import '../../utils/mensaje_error.dart';

class DetalleRdrPage extends StatefulWidget {
  final String token;
  final String codigo;
  final String estado;
  final DateTime fechaRegistro;
  final String tipoEmisor;
  final String tipoRegistro;
  final String tipoProblema;
  final String fechaIncidente;
  final String horaIncidente;
  final String pedido;

  final String impactoEconomico;
  final String impactoHh;
  final String descripcion;
  final String puntuacion;
  final String marca;

  final String area;
  final String usuarioEmisor;
  final String correoEmisor;
  final bool puedeAtender;

  final DateTime? fechaCierre;

  final String? responsableNombre;
  final String? responsableCorreo;
  final String? tipoCausa;
  final double? tiempoSolucionHoras;
  final double? costosAsociados;
  final String? descripcionSucedido;
  final String? descripcionSolucion;
  final bool puedeExportar;

  factory DetalleRdrPage.desdeJson({
    Key? key,
    required String token,
    required Map<String, dynamic> json,
    bool puedeExportar = false,
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

    return DetalleRdrPage(
      key: key,
      token: token,
      codigo: (json['codigo'] ?? '').toString(),
      estado: (json['estado'] ?? 'ABIERTO').toString(),
      fechaRegistro: parseDate(json['fecha_apertura'] ?? json['creado_en']),
      tipoEmisor: (json['tipo_emisor'] ?? '').toString(),
      tipoRegistro: (json['tipo_registro'] ?? '').toString(),
      tipoProblema: (json['tipo_problema'] ?? '').toString(),
      fechaIncidente: (json['fecha_incidente'] ?? '').toString(),
      horaIncidente: (json['hora_incidente'] ?? '').toString(),
      pedido: (json['pedido'] ?? '').toString(),
      impactoEconomico: (json['impacto_economico'] ?? '—').toString(),
      impactoHh: (json['impacto_hh'] ?? '—').toString(),
      descripcion: (json['descripcion'] ?? '—').toString(),
      puntuacion: (json['puntuacion'] ?? '—').toString(),
      marca: (json['marca'] ?? '—').toString(),
      area: (json['area_responsable'] ?? '').toString(),
      usuarioEmisor: (json['emisor_nombre'] ?? json['usuario_emisor'] ?? '')
          .toString(),
      correoEmisor: (json['emisor_correo'] ?? json['correo_emisor'] ?? '')
          .toString(),
      puedeAtender: json['puede_atender'] == true || json['puede_atender'] == 1,
      fechaCierre: parseNullableDate(json['fecha_cierre']),
      responsableNombre: json['responsable_nombre']?.toString(),
      responsableCorreo: json['responsable_correo']?.toString(),
      tipoCausa: json['tipo_causa']?.toString(),
      tiempoSolucionHoras: parseDouble(json['tiempo_solucion_horas']),
      costosAsociados: parseDouble(json['costos_asociados']),
      descripcionSucedido: json['descripcion_sucedido']?.toString(),
      descripcionSolucion: json['descripcion_solucion']?.toString(),
      puedeExportar: puedeExportar,
    );
  }

  const DetalleRdrPage({
    super.key,
    required this.token,
    required this.codigo,
    this.estado = 'ABIERTO',
    required this.fechaRegistro,
    required this.tipoEmisor,
    required this.tipoRegistro,
    required this.tipoProblema,
    required this.fechaIncidente,
    required this.horaIncidente,
    required this.pedido,
    required this.impactoEconomico,
    required this.impactoHh,
    required this.descripcion,
    required this.puntuacion,
    required this.marca,
    required this.area,
    required this.usuarioEmisor,
    required this.correoEmisor,
    required this.puedeAtender,
    required this.fechaCierre,
    this.responsableNombre,
    this.responsableCorreo,
    this.tipoCausa,
    this.tiempoSolucionHoras,
    this.costosAsociados,
    this.descripcionSucedido,
    this.descripcionSolucion,
    this.puedeExportar = false,
  });

  @override
  State<DetalleRdrPage> createState() => _DetalleRdrPageState();
}

class _DetalleRdrPageState extends State<DetalleRdrPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _tiempoCtrl = TextEditingController();
  final TextEditingController _costoCtrl = TextEditingController();
  final TextEditingController _descripcionHechosCtrl = TextEditingController();
  final TextEditingController _solucionCtrl = TextEditingController();

  String? _tipoCausa;
  bool _guardando = false;
  bool _exportando = false;
  bool _puedeAdministrar = false;
  bool _adminCheckCargando = false;
  final RdrService _rdrService = RdrService();

  List<Map<String, dynamic>> _historial = [];
  bool _cargandoHistorial = false;

  String _responsableNombre = '';
  String _responsableCorreo = '';

  static const List<String> _areasLista = [
    'Ventas',
    'Renta',
    'Mantenimiento',
    'Proyectos',
    'Operaciones',
    'Producción',
    'Tesorería',
    'TI',
    'SST',
    'RRHH',
    'Contabilidad',
    'Almacén',
    'Compras',
    'Planeamiento',
    'Servicios Comerciales',
  ];

  // Lista dinámica fusionada con todas las áreas
  final List<String> _tiposCausa = [
    'Error del cliente',
    'Error de diseño de proveedor',
    'Error de diseño de luvegi',
    'Error de proceso técnico operativo',
    'Error de proceso técnico de fabricación',
    ..._areasLista.map((area) => 'Error de proceso administrativo por $area'),
    'Capacidad de personal',
    'Otros',
  ];

  bool get _cerrado =>
      widget.fechaCierre != null ||
      widget.estado.trim().toUpperCase() == 'CERRADO';
  bool get _soloLectura => _cerrado || !widget.puedeAtender;

  @override
  void initState() {
    super.initState();
    _tipoCausa = widget.tipoCausa;
    _tiempoCtrl.text = widget.tiempoSolucionHoras?.toString() ?? '';
    _costoCtrl.text = widget.costosAsociados?.toString() ?? '';
    _descripcionHechosCtrl.text = widget.descripcionSucedido ?? '';
    _solucionCtrl.text = widget.descripcionSolucion ?? '';
    _responsableNombre = widget.responsableNombre ?? '';
    _responsableCorreo = widget.responsableCorreo ?? '';
    if (!_soloLectura) {
      _cargarResponsableSesion();
    }
    if (_cerrado) {
      _verificarAdministracion();
    }
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargandoHistorial = true);
    try {
      final items = await _rdrService.obtenerHistorialAtencionRdr(
        token: widget.token,
        codigo: widget.codigo,
      );
      if (!mounted) return;
      setState(() => _historial = items);
    } catch (_) {
      // Sin permiso o error al cargar historial: se deja vacío.
    } finally {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  Future<void> _verificarAdministracion() async {
    setState(() => _adminCheckCargando = true);
    try {
      final puede = await _rdrService.puedeAdministrarAtenciones(
        token: widget.token,
      );
      if (mounted) setState(() => _puedeAdministrar = puede);
    } catch (_) {
      if (mounted) setState(() => _puedeAdministrar = false);
    } finally {
      if (mounted) setState(() => _adminCheckCargando = false);
    }
  }

  Future<void> _cargarResponsableSesion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      if (_responsableNombre.trim().isEmpty) {
        _responsableNombre = (prefs.getString('nombre') ?? '').trim();
      }
      if (_responsableCorreo.trim().isEmpty) {
        _responsableCorreo = (prefs.getString('correo') ?? '').trim();
      }
    });
  }

  @override
  void dispose() {
    _tiempoCtrl.dispose();
    _costoCtrl.dispose();
    _descripcionHechosCtrl.dispose();
    _solucionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarAtencion() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);
    try {
      final double tiempo =
          double.tryParse(_tiempoCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final double costo =
          double.tryParse(_costoCtrl.text.replaceAll(',', '.')) ?? 0.0;

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
          content: Text('Atención del REDIR registrada correctamente.'),
        ),
      );
      try {
        AuditoriaService()
            .registrarActividad(
              widget.token,
              accion: 'ATENDER_RDR',
              entidad: 'rdr',
              detalle: '${widget.codigo} causa=$_tipoCausa',
            )
            .catchError((_) {});
      } catch (_) {}
      Navigator.pop(context, true);
    } on RdrApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarReabrir() async {
    final TextEditingController motivoCtrl = TextEditingController();
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir REDIR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El REDIR está cerrado. Al reabrirlo se limpiará la atención '
              'registrada para que el área responsable pueda atenderlo '
              'nuevamente.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextField(
              controller: motivoCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Motivo de la reapertura',
                hintText: 'Obligatorio',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final motivo = motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe indicar el motivo de la reapertura.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await _rdrService.reabrirYLimpiarAtencionRdr(
        token: widget.token,
        codigo: widget.codigo,
        motivo: motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('REDIR reabierto correctamente.')),
      );
      try {
        AuditoriaService()
            .registrarActividad(
              widget.token,
              accion: 'REABRIR_RDR',
              entidad: 'rdr',
              detalle: '${widget.codigo} motivo=$motivo',
            )
            .catchError((_) {});
      } catch (_) {}
      Navigator.pop(context, true);
    } on RdrApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _texto(dynamic valor) {
    final texto = (valor ?? '').toString().trim();
    return texto.isEmpty || texto == 'null' ? '—' : texto;
  }

  String _fecha(DateTime? fecha) {
    if (fecha == null) return '—';
    final local = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${dos(local.month)}-${dos(local.day)} '
        '${dos(local.hour)}:${dos(local.minute)}';
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
        foregroundColor: LuvegiColors.textPrimary,
        title: Text('Detalle REDIR · ${widget.codigo}'),
        actions: const [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(mobile ? LuvegiSpacing.md : LuvegiSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                children: [
                  if (sideBySide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildProblemColumn(mobile)),
                        const SizedBox(width: LuvegiSpacing.lg),
                        Expanded(child: _buildSolutionColumn(mobile)),
                      ],
                    )
                  else ...[
                    _buildProblemColumn(mobile),
                    const SizedBox(height: LuvegiSpacing.lg),
                    _buildSolutionColumn(mobile),
                  ],
                  const SizedBox(height: LuvegiSpacing.lg),
                  _buildHistorial(mobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProblemColumn(bool mobile) {
    return Column(
      children: [
        _buildSection(
          title: '1. Información General',
          subtitle: 'Datos de registro del incidente o reclamo.',
          icon: Icons.info_outline,
          child: Column(
            children: [
              _grid(mobile, [
                _item('Código REDIR', widget.codigo),
                _item('Usuario Emisor', widget.usuarioEmisor),
                _item('Área Emisora', widget.tipoEmisor),
                _item('Tipo Registro', widget.tipoRegistro),
                _item('Tipo Problema', widget.tipoProblema),
                _item('Área Responsable', widget.area),
                _item('Fecha Incidente', widget.fechaIncidente),
                _item('Hora Incidente', widget.horaIncidente),
                _item('Pedido', widget.pedido),
              ]),
            ],
          ),
        ),
        const SizedBox(height: LuvegiSpacing.lg),
        _buildSection(
          title: '2. Información del Reclamo / Incidencia',
          subtitle: 'Impactos y descripción del evento.',
          icon: Icons.tune_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grid(mobile, [
                _item('Impacto Económico', widget.impactoEconomico),
                _item('Impacto HH', widget.impactoHh),
                _item('Puntuación', widget.puntuacion),
                _item('Marca', widget.marca),
              ]),
              const SizedBox(height: LuvegiSpacing.md),
              _item('Descripción', widget.descripcion),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSolutionColumn(bool mobile) {
    return _buildSection(
      title: 'Estructura de Atención y Solución',
      subtitle: 'Completar por el Área Responsable (REQ-135).',
      icon: Icons.engineering_outlined,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(LuvegiSpacing.md),
              decoration: BoxDecoration(
                color: LuvegiColors.surfaceHover,
                borderRadius: BorderRadius.circular(LuvegiRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_pin_outlined,
                    color: LuvegiColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Responsable de la Solución:',
                        style: TextStyle(
                          fontSize: 11,
                          color: LuvegiColors.textSecondary,
                        ),
                      ),
                      Text(
                        _responsableNombre.isEmpty
                            ? 'Sin asignar'
                            : _responsableNombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: LuvegiSpacing.lg),

            if (_soloLectura)
              TextFormField(
                initialValue: _tipoCausa ?? 'Sin registrar',
                enabled: false,
                decoration: const InputDecoration(
                  labelText: '1. Identificación de la Causa',
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _tipoCausa,
                isExpanded:
                    true, // Evita errores de renderizado si el texto es muy largo
                decoration: const InputDecoration(
                  labelText: '1. Identificación de la Causa',
                ),
                items: _tiposCausa
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          overflow: TextOverflow.ellipsis,
                        ), // Previene desbordamiento
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _tipoCausa = v),
                validator: (v) => v == null ? 'Campo obligatorio.' : null,
              ),

            const SizedBox(height: LuvegiSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tiempoCtrl,
                    enabled: !_soloLectura,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Tiempo solución (Horas)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _costoCtrl,
                    enabled: !_soloLectura,
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
            const SizedBox(height: LuvegiSpacing.md),
            TextFormField(
              controller: _descripcionHechosCtrl,
              enabled: !_soloLectura,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '3. Descripción exacta de lo sucedido',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: LuvegiSpacing.md),
            TextFormField(
              controller: _solucionCtrl,
              enabled: !_soloLectura,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '4. Solución implementada',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: LuvegiSpacing.xl),
            if (!_soloLectura)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardarAtencion,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _guardando ? 'Guardando...' : 'Guardar y Cerrar REDIR',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LuvegiColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            if (_soloLectura && _cerrado && _puedeAdministrar) ...[
              const SizedBox(height: LuvegiSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (!_guardando && !_adminCheckCargando)
                      ? _confirmarReabrir
                      : null,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Reabrir REDIR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LuvegiColors.error,
                    side: BorderSide(color: LuvegiColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(LuvegiSpacing.lg),
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
            Icon(icon, color: LuvegiColors.secondary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: LuvegiColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: LuvegiSpacing.lg),
        child,
      ],
    ),
  );

  Widget _buildHistorial(bool mobile) {
    return _buildSection(
      title: 'Historial de Atención',
      subtitle: 'Aperturas, atenciones, reaperturas y ediciones del REDIR.',
      icon: Icons.history,
      child: _cargandoHistorial
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(LuvegiSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            )
          : _historial.isEmpty
          ? const Text(
              'Sin movimientos registrados.',
              style: TextStyle(fontSize: 13, color: LuvegiColors.textSecondary),
            )
          : Column(children: _historial.map(_buildHistorialItem).toList()),
    );
  }

  Widget _buildHistorialItem(Map<String, dynamic> item) {
    final accion = (item['accion'] ?? 'MOVIMIENTO').toString().toUpperCase();
    final fecha =
        (item['fecha'] ?? item['fecha_hora'] ?? item['creado_en'] ?? '')
            .toString();
    final autor =
        (item['administrador_nombre'] ??
                item['usuario_nombre'] ??
                item['usuario'] ??
                '')
            .toString();
    final detalle = (item['detalle'] ?? item['descripcion'] ?? '').toString();
    final motivo = (item['motivo'] ?? '').toString();

    final (icon, color) = switch (accion) {
      'ATENDIDO' => (Icons.check_circle_outline, LuvegiColors.success),
      'REABIERTO' ||
      'REABRIR' => (Icons.lock_open_outlined, LuvegiColors.error),
      'EDITADO' => (Icons.edit_outlined, LuvegiColors.secondary),
      'REGISTRADO' => (Icons.add_circle_outline, LuvegiColors.secondary),
      _ => (Icons.circle_outlined, LuvegiColors.textSecondary),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(LuvegiSpacing.md),
        decoration: BoxDecoration(
          color: LuvegiColors.surfaceHover,
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
          border: Border.all(color: LuvegiColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    accion,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (autor.isNotEmpty)
                    Text(
                      'Por: $autor',
                      style: const TextStyle(
                        fontSize: 12,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                  if (fecha.isNotEmpty)
                    Text(
                      fecha,
                      style: const TextStyle(
                        fontSize: 12,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                  if (detalle.isNotEmpty && detalle != 'null')
                    const SizedBox(height: 4),
                  if (detalle.isNotEmpty && detalle != 'null')
                    Text(detalle, style: const TextStyle(fontSize: 12)),
                  if (motivo.isNotEmpty)
                    Text(
                      'Motivo: $motivo',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: LuvegiColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(bool mobile, List<Widget> children) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: children
        .map((c) => SizedBox(width: mobile ? double.infinity : 200, child: c))
        .toList(),
  );

  Widget _item(String label, String value) => Container(
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
            fontSize: 11,
            color: LuvegiColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.trim().isEmpty ? '—' : value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    ),
  );
}
