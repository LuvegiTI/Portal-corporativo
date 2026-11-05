import 'package:flutter/material.dart';
import '../../services/rdr_service.dart';
import '../../services/auditoria_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_spacing.dart';
import '../../utils/mensaje_error.dart';

class AtenderRdrPage extends StatefulWidget {
  final String token;
  final String codigo;

  const AtenderRdrPage({super.key, required this.token, required this.codigo});

  @override
  State<AtenderRdrPage> createState() => _AtenderRdrPageState();
}

class _AtenderRdrPageState extends State<AtenderRdrPage> {
  final _formKey = GlobalKey<FormState>();
  final RdrService _rdrService = RdrService();
  final AuditoriaService _auditoria = AuditoriaService();

  final _tiempoCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _sucedidoCtrl = TextEditingController();
  final _solucionCtrl = TextEditingController();

  String? _tipoCausa;
  bool _guardando = false;

  static const List<String> _tiposCausa = [
    'Error del cliente',
    'Error de diseño de proveedor',
    'Error de diseño de luvegi',
    'Error de proceso técnico operativo',
    'Error de proceso técnico de fabricación',
    'Error de proceso administrativo por subgerencia',
    'Capacidad de personal',
    'Otros',
  ];

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);
    try {
      await _rdrService.atenderRdr(
        token: widget.token,
        codigo: widget.codigo,
        tipoCausa: _tipoCausa!,
        tiempoSolucionHoras: double.parse(
          _tiempoCtrl.text.replaceAll(',', '.'),
        ),
        costosAsociados: double.parse(_costoCtrl.text.replaceAll(',', '.')),
        descripcionSucedido: _sucedidoCtrl.text.trim(),
        descripcionSolucion: _solucionCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atención guardada correctamente.')),
      );
      try {
        _auditoria
            .registrarActividad(
              widget.token,
              accion: 'ATENDER_RDR',
              entidad: 'rdr',
              detalle: '${widget.codigo} causa=$_tipoCausa horas=$_tiempoCtrl',
            )
            .catchError((_) {});
      } catch (_) {}
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(MensajeError.desdeExcepcion(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Atender ${widget.codigo}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(LuvegiSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _tipoCausa,
                    decoration: const InputDecoration(
                      labelText: '1. Identificación de la Causa',
                    ),
                    items: _tiposCausa
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _tipoCausa = v),
                    validator: (v) => v == null ? 'Campo obligatorio.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tiempoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '2. Tiempo de solución en horas',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _costoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '2. Costos asociados',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sucedidoCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '3. Descripción exacta de lo sucedido',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _solucionCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '4. Solución implementada',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LuvegiColors.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _guardando ? 'Guardando...' : 'Guardar y Cerrar REDIR',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
