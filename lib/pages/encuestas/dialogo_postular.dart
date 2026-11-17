import 'package:flutter/material.dart';

import '../../services/encuesta_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/mensaje_error.dart';

/// Dialogo para postularse como candidato de una pregunta.
/// Devuelve true si la postulacion quedo registrada.
Future<bool> mostrarDialogoPostular({
  required BuildContext context,
  required EncuestaService service,
  required String token,
  required int encuestaId,
  required EncuestaPregunta pregunta,
  List<RequisitoPostulacion> requisitos = const [],
  List<EncuestaOpcion> opcionesRequisito = const [],
  List<int> requisitosPreviamenteMarcados = const [],
  String nombreUsuario = '',
  String dniUsuario = '',
}) async {
  final ctrl = TextEditingController();
  final marcados = <int>{}..addAll(requisitosPreviamenteMarcados);
  final marcadosOpciones = <int>{};

  final resultado =
      await showDialog<
        ({String propuesta, List<int> requisitos, List<int> opciones})
      >(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            final obligatorios = requisitos.where((r) => r.obligatorio);
            final todosMarcados =
                obligatorios.every((r) => marcados.contains(r.id)) &&
                opcionesRequisito.every((o) => marcadosOpciones.contains(o.id));
            final hayRequisitos =
                requisitos.isNotEmpty || opcionesRequisito.isNotEmpty;
            final faltanObligatorios = hayRequisitos && !todosMarcados;

            return AlertDialog(
              title: const Text('Postularme'),
              content: SizedBox(
                // Ancho fijo: el AlertDialog calcula el ancho intrinseco del
                // contenido y un viewport (scroll) no lo soporta.
                width: (MediaQuery.sizeOf(ctx).width - 80).clamp(240.0, 440.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registraremos tu postulación a "${pregunta.nombre}". '
                        'Tus datos (nombre, DNI, área y foto) se toman de tu '
                        'perfil al guardar.',
                        style: LuvegiText.caption,
                      ),
                      if (nombreUsuario.isNotEmpty ||
                          dniUsuario.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: LuvegiColors.menuHover,
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.sm,
                            ),
                            border: Border.all(color: LuvegiColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DATOS DEL POSTULANTE',
                                style: LuvegiText.caption.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: LuvegiColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nombreUsuario.isEmpty
                                    ? 'Nombre: se tomará de tu perfil'
                                    : nombreUsuario,
                                style: LuvegiText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                dniUsuario.isEmpty
                                    ? 'DNI: no está registrado en tu perfil'
                                    : 'DNI: $dniUsuario',
                                style: LuvegiText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (hayRequisitos) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Marca los requisitos que cumples. Debes marcar todos '
                          'los obligatorios para que tu postulación se guarde.',
                          style: LuvegiText.caption.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      ...requisitos.map(
                        (r) => CheckboxListTile(
                          value: marcados.contains(r.id),
                          onChanged: (v) => setDialogState(() {
                            if (v == true) {
                              marcados.add(r.id);
                            } else {
                              marcados.remove(r.id);
                            }
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            r.descripcion,
                            style: LuvegiText.body.copyWith(fontSize: 13),
                          ),
                          subtitle: _detalleRequisito(r),
                        ),
                      ),
                      ...opcionesRequisito.map(
                        (o) => CheckboxListTile(
                          value: marcadosOpciones.contains(o.id),
                          onChanged: (v) => setDialogState(() {
                            if (v == true) {
                              marcadosOpciones.add(o.id);
                            } else {
                              marcadosOpciones.remove(o.id);
                            }
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            o.nombre,
                            style: LuvegiText.body.copyWith(fontSize: 13),
                          ),
                        ),
                      ),
                      if (faltanObligatorios)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Faltan requisitos obligatorios por marcar.',
                            style: LuvegiText.caption.copyWith(
                              color: LuvegiColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: ctrl,
                        autofocus: true,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Tu propuesta (opcional)',
                          hintText: 'Explica brevemente por qué te postulas',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: !faltanObligatorios
                      ? () => Navigator.pop(ctx, (
                          propuesta: ctrl.text.trim(),
                          requisitos: marcados.toList(),
                          opciones: marcadosOpciones.toList(),
                        ))
                      : null,
                  child: const Text('Postularme'),
                ),
              ],
            );
          },
        ),
      );

  ctrl.dispose();
  if (resultado == null || !context.mounted) return false;

  try {
    await service.postular(
      token: token,
      encuestaId: encuestaId,
      preguntaId: pregunta.id,
      propuesta: resultado.propuesta,
      requisitosCumplidos: resultado.requisitos,
      opcionesCumplidas: resultado.opciones,
      nombre: nombreUsuario,
      dni: dniUsuario,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu postulación quedó registrada.')),
      );
    }
    return true;
  } catch (e) {
    if (!context.mounted) return false;

    // Si no cumple los requisitos, se explica cuáles le faltan.
    final mensaje = MensajeError.desdeExcepcion(e);
    var detalle = '';
    if (e.toString().contains('NO_CUMPLE_REQUISITOS')) {
      detalle = '\n\nMarca todos los requisitos obligatorios del proceso.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$mensaje$detalle'),
        backgroundColor: LuvegiColors.error,
        duration: const Duration(seconds: 5),
      ),
    );
    return false;
  }
}

/// Texto secundario con la obligatoriedad y el detalle del requisito.
Widget? _detalleRequisito(RequisitoPostulacion r) {
  final partes = <String>[
    if (!r.obligatorio) 'Opcional',
    if (r.detalle.isNotEmpty) r.detalle,
  ];
  if (partes.isEmpty) return null;
  return Text(partes.join(' · '), style: LuvegiText.caption);
}

/// Requisitos que RRHH cargo como opciones de una pregunta de requisitos.
/// Las opciones vinculadas a un usuario son postulaciones, no requisitos.
List<EncuestaOpcion> requisitosDesdeOpciones(EncuestaPregunta pregunta) {
  if (!pregunta.nombre.toLowerCase().contains('requisit')) return const [];
  return pregunta.opciones.where((o) {
    if (o.esRequisito) return true;
    if (o.esMia || o.usuarioId != null) return false;
    return o.area.isEmpty && o.propuesta.isEmpty && o.fotoUrl.isEmpty;
  }).toList();
}

/// Tarjeta con los requisitos de postulacion y si la persona los cumple.
Widget tarjetaRequisitos(
  List<RequisitoPostulacion> requisitos, {
  bool compacta = false,
  Set<int> marcados = const {},
  void Function(int id, bool activo)? onCambio,
}) {
  if (requisitos.isEmpty) return const SizedBox.shrink();

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: LuvegiColors.surfaceHover,
      borderRadius: BorderRadius.circular(LuvegiRadius.sm),
      border: Border.all(color: LuvegiColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REQUISITOS PARA POSTULARSE',
          style: LuvegiText.caption.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: LuvegiColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...requisitos.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: marcados.contains(r.id),
                  onChanged: onCambio == null
                      ? null
                      : (v) => onCambio(r.id, v == true),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.descripcion,
                        style: LuvegiText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: r.obligatorio
                              ? LuvegiColors.textPrimary
                              : LuvegiColors.textSecondary,
                        ),
                      ),
                      if (r.obligatorio)
                        Text(
                          'Obligatorio',
                          style: LuvegiText.caption.copyWith(
                            fontSize: 10,
                            color: LuvegiColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (!compacta && r.detalle.isNotEmpty)
                        Text(
                          r.detalle,
                          style: LuvegiText.caption.copyWith(
                            fontSize: 11,
                            color: LuvegiColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
