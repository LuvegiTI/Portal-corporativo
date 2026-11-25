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
  String? errorCarga;

  try {
    requisitos = await service.listarRequisitos(
      token: token,
      encuestaId: encuestaId,
    );
  } catch (e) {
    // Si no se pudieron cargar, el dialogo se abre igual mostrando el
    // error: nunca se queda sin ventana.
    errorCarga = MensajeError.desdeExcepcion(e);
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Requisitos de postulacion'),
          content: SizedBox(
            // Ancho fijo: el AlertDialog calcula el ancho intrinseco del
            // contenido y un viewport (scroll) no lo soporta.
            width: (MediaQuery.sizeOf(ctx).width - 80).clamp(240.0, 460.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorCarga != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: LuvegiColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
                        border: Border.all(
                          color: LuvegiColors.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: LuvegiColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No se pudieron cargar los requisitos: '
                              '$errorCarga',
                              style: LuvegiText.caption.copyWith(
                                color: LuvegiColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                      'El personal vera estos requisitos al postularse y debera '
                      'marcar todos para que su postulacion se guarde. Si la '
                      'encuesta no tiene ninguno, puede postularse cualquiera '
                      'con permiso de votar.',
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
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requisitos.length,
                      itemBuilder: (_, i) {
                        final r = requisitos[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: LuvegiColors.surface,
                            borderRadius: BorderRadius.circular(
                              LuvegiRadius.sm,
                            ),
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
                                    final nuevos = await service
                                        .listarRequisitos(
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
                  const SizedBox(height: 8),
                  _FormularioAgregar(
                    onAgregar: (tipo, valor, descripcion, obligatorio) async {
                      try {
                        await service.guardarRequisito(
                          token: token,
                          encuestaId: encuestaId,
                          tipo: tipo,
                          valor: valor,
                          descripcion: descripcion,
                          obligatorio: obligatorio,
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
                    },
                  ),
                ],
              ),
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
class _FormularioAgregar extends StatefulWidget {
  final Future<void> Function(
    String tipo,
    String valor,
    String descripcion,
    bool obligatorio,
  )
  onAgregar;

  const _FormularioAgregar({required this.onAgregar});

  @override
  State<_FormularioAgregar> createState() => _FormularioAgregarState();
}

class _FormularioAgregarState extends State<_FormularioAgregar> {
  final TextEditingController descCtrl = TextEditingController();
  static const String _tipoManual = 'MANUAL';
  bool guardando = false;
  bool obligatorio = true;

  @override
  void dispose() {
    descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        TextField(
          controller: descCtrl,
          decoration: const InputDecoration(
            labelText: 'Descripcion del requisito',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: obligatorio,
              onChanged: (v) => setState(() => obligatorio = v ?? true),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            const Text(
              'Obligatorio (debe marcarlo al postularse)',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () async {
                    setState(() => guardando = true);
                    await widget.onAgregar(
                      _tipoManual,
                      '',
                      descCtrl.text.trim(),
                      obligatorio,
                    );
                    if (!mounted) return;
                    descCtrl.clear();
                    setState(() {
                      guardando = false;
                      obligatorio = true;
                    });
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
    case 'MANUAL':
      return 'Requisito manual';
    default:
      return tipo;
  }
}
