import 'package:flutter/material.dart';

import '../../design_system/luvegi_button.dart';
import '../../design_system/luvegi_card.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../services/mis_ot_renta_service.dart';

class MisOtRentaPage extends StatefulWidget {
  const MisOtRentaPage({super.key});

  @override
  State<MisOtRentaPage> createState() => _MisOtRentaPageState();
}

class _MisOtRentaPageState extends State<MisOtRentaPage> {
  final _service = MisOtRentaService();
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.listar();
      setState(() {
        _items = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        title: const Text('Mis Órdenes de Trabajo'),
        backgroundColor: LuvegiColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: LuvegiText.body))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: LuvegiSpacing.xl * 2),
                            Center(
                              child: Text(
                                'No tienes OT asignadas',
                                style: LuvegiText.body,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(LuvegiSpacing.md),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final ot = _items[index] as Map<String, dynamic>;
                            final stage = ot['stage_id'];
                            final stageName = stage is Map ? (stage['display_name'] ?? '') : '';
                            return Padding(
                              padding: EdgeInsets.only(bottom: LuvegiSpacing.md),
                              child: LuvegiCard(
                                child: InkWell(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MisOtRentaDetallePage(otId: ot['id']),
                                      ),
                                    );
                                    _cargar();
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(LuvegiSpacing.md),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(ot['name'] ?? '', style: LuvegiText.title),
                                            Text(stageName, style: LuvegiText.caption),
                                          ],
                                        ),
                                        SizedBox(height: LuvegiSpacing.sm),
                                        Text(ot['razon_social'] ?? '', style: LuvegiText.body),
                                        SizedBox(height: LuvegiSpacing.xs),
                                        Text('RUC: ${ot['ruc'] ?? ''}', style: LuvegiText.caption),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class MisOtRentaDetallePage extends StatefulWidget {
  final int otId;
  const MisOtRentaDetallePage({super.key, required this.otId});

  @override
  State<MisOtRentaDetallePage> createState() => _MisOtRentaDetallePageState();
}

class _MisOtRentaDetallePageState extends State<MisOtRentaDetallePage> {
  final _service = MisOtRentaService();
  bool _loading = true;
  bool _guardando = false;
  Map<String, dynamic>? _ot;

  final llegadaOperador = TextEditingController();
  final llegadaCliente = TextEditingController();
  final arranqueGe = TextEditingController();
  final apagadoGe = TextEditingController();
  final salidaCliente = TextEditingController();
  final hCulminacion = TextEditingController();
  final hInicial = TextEditingController();
  final hFin = TextEditingController();
  final hTrabajadas = TextEditingController();
  final hTrabajoArrApa = TextEditingController();
  final cargaArranque = TextEditingController();
  final cargaInt1 = TextEditingController();
  final cargaInt2 = TextEditingController();
  final cargaApagado = TextEditingController();
  final cantCombustible = TextEditingController();
  final obsTecnico = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final data = await _service.detalle(widget.otId);
      setState(() {
        _ot = data;
        _set(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _set(Map<String, dynamic> d) {
    llegadaOperador.text = d['llegada_operardor']?.toString() ?? '';
    llegadaCliente.text = d['llegada_cliente']?.toString() ?? '';
    arranqueGe.text = d['arranque_ge']?.toString() ?? '';
    apagadoGe.text = d['apagado_ge']?.toString() ?? '';
    salidaCliente.text = d['salida_cliente']?.toString() ?? '';
    hCulminacion.text = d['h_culminacion_date']?.toString() ?? '';
    hInicial.text = d['h_inicial']?.toString() ?? '';
    hFin.text = d['h_fin']?.toString() ?? '';
    hTrabajadas.text = d['h_trabajadas']?.toString() ?? '';
    hTrabajoArrApa.text = d['h_trabajo_arr_apa']?.toString() ?? '';
    cargaArranque.text = d['carga_arranque']?.toString() ?? '';
    cargaInt1.text = d['carga_int_1']?.toString() ?? '';
    cargaInt2.text = d['carga_int_2']?.toString() ?? '';
    cargaApagado.text = d['carga_apagado']?.toString() ?? '';
    cantCombustible.text = d['cant_combustible']?.toString() ?? '';
    obsTecnico.text = d['obs_tecnico']?.toString() ?? '';
  }

  Map<String, dynamic> _campos() {
    return {
      'llegada_operardor': llegadaOperador.text,
      'llegada_cliente': llegadaCliente.text,
      'arranque_ge': arranqueGe.text,
      'apagado_ge': apagadoGe.text,
      'salida_cliente': salidaCliente.text,
      'h_culminacion_date': hCulminacion.text,
      'h_inicial': hInicial.text,
      'h_fin': hFin.text,
      'h_trabajadas': hTrabajadas.text,
      'h_trabajo_arr_apa': hTrabajoArrApa.text,
      'carga_arranque': cargaArranque.text,
      'carga_int_1': cargaInt1.text,
      'carga_int_2': cargaInt2.text,
      'carga_apagado': cargaApagado.
text,
      'cant_combustible': cantCombustible.text,
      'obs_tecnico': obsTecnico.text,
    };
  }

  Future<void> _guardar(bool finalizar) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      if (finalizar) {
        await _service.finalizar(widget.otId, _campos());
      } else {
        await _service.guardar(widget.otId, _campos());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(finalizar ? 'OT finalizada (ATENDIDO)' : 'Guardado correctamente')),
        );
        if (finalizar) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      setState(() => _guardando = false);
    }
  }

  Widget _info(String label, dynamic value) {
    final v = value is Map ? (value['display_name'] ?? value.toString()) : (value?.toString() ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LuvegiText.body),
        SizedBox(height: LuvegiSpacing.xs),
        Text(v.isEmpty ? '-' : v, style: LuvegiText.body),
        SizedBox(height: LuvegiSpacing.md),
      ],
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LuvegiText.body),
        SizedBox(height: LuvegiSpacing.xs),
        TextField(controller: c, decoration: const InputDecoration(border: OutlineInputBorder())),
        SizedBox(height: LuvegiSpacing.md),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ot = _ot;
    return Scaffold(
      backgroundColor: LuvegiColors.background,
      appBar: AppBar(
        title: Text(ot?['name'] ?? 'OT'),
        backgroundColor: LuvegiColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ot == null
              ? const Center(child: Text('Sin datos'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(LuvegiSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Datos de la OT', style: LuvegiText.title),
                      SizedBox(height: LuvegiSpacing.md),
                      LuvegiCard(
                        child: Padding(
                          padding: EdgeInsets.all(LuvegiSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _info('N° OT', ot['name']),
                              _info('Estado', ot['stage_id']),
                              _info('Razón Social', ot['razon_social']),
                              _info('RUC', ot['ruc']),
                              _info('Dirección de servicio', ot['direccion_servicio']),
                              _info('Contacto comercial', ot['nombre_contacto']),
                              _info('Teléfono', ot['telefono_contacto']),
                              _info('Equipo', ot['equipment_id']),
                              _info('Guía Rem.', ot['guia_rem']),
                              _info('Pedido', ot['pedido_ff']),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: LuvegiSpacing.lg),
                      Text('Reporte del técnico', style: LuvegiText.title),
                      SizedBox(height: LuvegiSpacing.md),
                      LuvegiCard(
                        child: Padding(
                          padding: EdgeInsets.all(LuvegiSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _field('Fecha/Hora llegada operario a LUVEGI', llegadaOperador),
                              _field('Fecha/Hora llegada a Cliente', llegadaCliente),
                              _field('Fecha/Hora arranque GE', arranqueGe),
                              _field('Fecha/Hora apagado GE', apagadoGe),
                              _field('Fecha/Hora salida Cliente', salidaCliente),
                              _field('Fecha/Hora culminación del trabajo', hCulminacion),
                              _field('Horómetro Inicial', hInicial),
                              _field('Horómetro Final', hFin),
                              _field('Horas trabajadas según Horómetro', hTrabajadas),
                              _field('Hrs trabajo según arranque/apagado', hTrabajoArrApa),
                              _field('Carga de arranque', cargaArranque),
                              _field('Carga int. 1', cargaInt1),
                              _field('Carga int. 2', cargaInt2),
                              _field('Carga de apagado', cargaApagado),
                              _field('Cantidad de combustible', cantCombustible),
                              _field('Observaciones', obsTecnico),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: LuvegiSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: LuvegiButton(
                              text: _guardando ? 'Guardando...' : 'Guardar',
                              onPressed: _guardando ? () {} : () => _guardar(false),
                            ),
                          ),
                          SizedBox(width: LuvegiSpacing.md),
                          Expanded(
                            child: LuvegiButton(
                              text: _guardando ? 'Finalizando...' : 'Finalizar OT (ATENDIDO)',
                              onPressed: _guardando ? () {} : () => _guardar(true),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: LuvegiSpacing.xl),
                    ],
                  ),
                ),
    );
  }
}
