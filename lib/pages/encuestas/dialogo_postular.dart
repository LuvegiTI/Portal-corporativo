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
}) async {
  final ctrl = TextEditingController();

  final propuesta = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Postularme'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Te anotaremos como candidato en: "${pregunta.nombre}". '
              'Tus datos (nombre, área y foto) se toman de tu perfil.',
              style: LuvegiText.caption,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Postularme'),
        ),
      ],
    ),
  );

  ctrl.dispose();
  if (propuesta == null || !context.mounted) return false;

  try {
    await service.postular(
      token: token,
      encuestaId: encuestaId,
      preguntaId: pregunta.id,
      propuesta: propuesta,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu postulación quedó registrada.')),
      );
    }
    return true;
  } catch (e) {
    if (!context.mounted) return false;

    // Si no cumple los requisitos, se explica quais le faltan.
    final mensaje = MensajeError.desdeExcepcion(e);
    var detalle = '';
    if (e.toString().contains('NO_CUMPLE_REQUISITOS')) {
      detalle = '\n\nRevisa los requisitos de la encuesta.';
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

/// Tarjeta con los requisitos de postulacion y si la persona los cumple.
Widget tarjetaRequisitos(
  List<RequisitoPostulacion> requisitos, {
  bool compacta = false,
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
                Icon(
                  r.cumple == true
                      ? Icons.check_circle
                      : (r.cumple == false
                          ? Icons.cancel
                          : Icons.help_outline),
                  size: 15,
                  color: r.cumple == true
                      ? LuvegiColors.success
                      : (r.cumple == false
                          ? LuvegiColors.error
                          : LuvegiColors.textHint),
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
