import 'package:flutter/material.dart';

import '../../services/encuesta_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/mensaje_error.dart';

/// Dialogo para registrar los requisitos que el personal debe cumplir
/// para poder postularse como candidato en una encuesta.
Future<void> mostrarDialogoRequisitos({
  required BuildContext context,
  required EncuestaService service,
  required String token,
  required int encuestaId,
}) async {
  List<RequisitoPostulacion> requisitos = [];

  try {
    requisitos = await service.listarRequisitos(
      token: token,
      encuestaId: encuestaId,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(MensajeError.desdeExcepcion(e)),
        backgroundColor: LuvegiColors.error,
      ),
    );
    return;
  }
  if (!context.mounted) return;

  final tipos = _tiposDisponibles;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Requisitos de postulacion'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: LuvegiColors.menuHover,
                    borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                  ),
                  child: Text(
                    'El personal solo puede postularse si cumple TODOS estos '
                    'requisitos. Si la encuesta no tiene ninguno, puede '
                    'postularse cualquiera con permiso de votar.',
                    style: LuvegiText.caption,
                  ),
                ),
                const SizedBox(height: 12),
                if (requisitos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Todavia no hay requisitos en esta encuesta.',
                      style: LuvegiText.bodySecondary,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      itemCount: requisitos.length,
                      itemBuilder: (_, i) {
                        final r = requisitos[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: LuvegiColors.surface,
                            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                            border: Border.all(color: LuvegiColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.rule,
                                size: 16,
                                color: LuvegiColors.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.descripcion,
                                      style: LuvegiText.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      _etiquetaTipo(r.tipo),
                                      style: LuvegiText.caption.copyWith(
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  try {
                                    await service.eliminarRequisito(
                                      token: token,
                                      id: r.id,
                                    );
                                    final nuevos =
                                        await service.listarRequisitos(
                                      token: token,
                                      encuestaId: encuestaId,
                                    );
                                    setDialogState(() => requisitos = nuevos);
                                  } catch (e) {
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          MensajeError.desdeExcepcion(e),
                                        ),
                                        backgroundColor: LuvegiColors.error,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: LuvegiColors.error,
                                ),
                                tooltip: 'Quitar requisito',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                _formularioAgregar(tipos, (tipo, valor, descripcion) async {
                  try {
                    await service.guardarRequisito(
                      token: token,
                      encuestaId: encuestaId,
                      tipo: tipo,
                      valor: valor,
                      descripcion: descripcion,
                    );
                    final nuevos = await service.listarRequisitos(
                      token: token,
                      encuestaId: encuestaId,
                    );
                    setDialogState(() => requisitos = nuevos);
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(MensajeError.desdeExcepcion(e)),
                        backgroundColor: LuvegiColors.error,
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    ),
  );
}

/// Formulario para agregar un requisito nuevo.
Widget _formularioAgregar(
  Map<String, String> tipos,
  Future<void> Function(String tipo, String valor, String descripcion) onAgregar,
) {
  var tipo = tipos.keys.first;
  final valorCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  var guardando = false;

  return StatefulBuilder(
    builder: (ctx, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'AGREGAR REQUISITO',
            style: LuvegiText.caption.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: LuvegiColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: tipo,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de requisito',
              isDense: true,
            ),
            items: tipos.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => tipo = v ?? tipo),
          ),
          const SizedBox(height: 10),
          if (tipo != 'NO_CESADO')
            TextField(
              controller: valorCtrl,
              decoration: InputDecoration(
                labelText: _pistaValor(tipo),
                isDense: true,
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripcion (opcional)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: guardando
                  ? null
                  : () async {
                      setState(() => guardando = true);
                      await onAgregar(tipo, valorCtrl.text.trim(), descCtrl.text.trim());
                      valorCtrl.clear();
                      descCtrl.clear();
                      setState(() => guardando = false);
                    },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar requisito'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LuvegiColors.secondary,
              ),
            ),
          ),
        ],
      );
    },
  );
}

String _pistaValor(String tipo) {
  switch (tipo) {
    case 'EDAD_MIN':
      return 'Anos minimos (ej. 18)';
    case 'ANTIGUEDAD_MIN':
      return 'Anos minimos en la empresa (ej. 2)';
    case 'TIPO_CONTRATO':
      return 'Tipo de contrato (employee, trainee, contractor...)';
    case 'AREA':
      return 'Area requerida (ej. MANTENIMIENTO)';
    case 'PUESTO':
      return 'Puesto requerido';
    default:
      return 'Valor';
  }
}

String _etiquetaTipo(String tipo) {
  switch (tipo) {
    case 'EDAD_MIN':
      return 'Edad';
    case 'ANTIGUEDAD_MIN':
      return 'Antiguedad';
    case 'TIPO_CONTRATO':
      return 'Tipo de contrato';
    case 'NO_CESADO':
      return 'No cesado';
    case 'AREA':
      return 'Area';
    case 'PUESTO':
      return 'Puesto';
    default:
      return tipo;
  }
}

const Map<String, String> _tiposDisponibles = {
  'EDAD_MIN': 'Edad minima',
  'ANTIGUEDAD_MIN': 'Antiguedad minima en la empresa',
  'TIPO_CONTRATO': 'Tipo de contrato',
  'NO_CESADO': 'No estar cesado',
  'AREA': 'Area',
  'PUESTO': 'Puesto',
};
