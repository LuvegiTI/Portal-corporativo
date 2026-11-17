import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/encuesta_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/mensaje_error.dart';
import 'dialogo_postular.dart';

/// Pagina del menu "Postulaciones": muestra las encuestas abiertas a las que
/// el personal puede postularse como candidato, y si cumple sus requisitos.
class PostulacionesPage extends StatefulWidget {
  final String token;

  const PostulacionesPage({super.key, required this.token});

  @override
  State<PostulacionesPage> createState() => _PostulacionesPageState();
}

class _PostulacionesPageState extends State<PostulacionesPage> {
  final EncuestaService _service = EncuestaService();

  bool _cargando = true;
  String? _error;
  List<EncuestaVotable> _encuestas = [];

  /// encuestaId -> ids de requisitos que el usuario declaro cumplir.
  final Map<int, Set<int>> _requisitosMarcados = {};

  /// Nombre del usuario en sesion, para mostrarlo al postularse.
  String _miNombre = '';

  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
    _cargar();
    // Refresco silencioso: cuando la postulacion se abre sola por la hora
    // programada, el personal la ve sin recargar la pagina.
    _temporizador = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _cargando) return;
      _cargar(silencioso: true);
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _cargarNombre() async {
    final sesion = await AuthService().getSession();
    if (!mounted || sesion == null) return;
    setState(() => _miNombre = (sesion['nombre'] ?? '').toString());
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silencioso) _cargando = true;
      _error = null;
    });
    try {
      final lista = await _service.obtenerEncuestasAbiertas(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        // Solo aparecen las postulaciones que RRHH ya abrio (con los
        // requisitos registrados). Si el personal ya se inscribio, se
        // muestra aunque se cierre, para poder ver o retirar su registro.
        _encuestas = lista
            .where(
              (e) =>
                  e.esPostulacion &&
                  (e.misPostulaciones.isNotEmpty ||
                      (e.encuesta.estado == 'ABIERTA' &&
                          e.encuesta.postulacionesAbiertas)),
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      // Un fallo del refresco silencioso no debe borrar lo que ya se ve.
      if (!silencioso) {
        setState(() => _error = MensajeError.desdeExcepcion(e));
      }
    } finally {
      if (mounted && !silencioso) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 760;

    return ColoredBox(
      color: LuvegiColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(mobile ? LuvegiSpacing.md : LuvegiSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _buildContenido(),
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 120),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _card(
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: LuvegiColors.error,
              size: 42,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Text(_error!, textAlign: TextAlign.center, style: LuvegiText.body),
            const SizedBox(height: LuvegiSpacing.md),
            OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_encuestas.isEmpty) {
      return _card(
        child: Column(
          children: [
            const Icon(
              Icons.how_to_reg_outlined,
              size: 48,
              color: LuvegiColors.textHint,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Text('No hay encuestas abiertas', style: LuvegiText.title),
            const SizedBox(height: LuvegiSpacing.xs),
            Text(
              'Para postularte debe haber una postulación con requisitos '
              'registrados y la inscripción abierta. Si crees que es un '
              'error, comunícate con RRHH.',
              textAlign: TextAlign.center,
              style: LuvegiText.bodySecondary,
            ),
          ],
        ),
      );
    }

    // Las encuestas en las que ya te postulaste salen de la lista principal:
    // se resumen al final para que puedas ver el estado o retirarla.
    final pendientes = _encuestas
        .where((e) => e.misPostulaciones.isEmpty)
        .toList();
    final realizadas = _encuestas
        .where((e) => e.misPostulaciones.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Postulaciones',
                style: LuvegiText.title.copyWith(fontSize: 20),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: () => _cargar(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          pendientes.isEmpty
              ? 'Ya te postulaste en todas las encuestas disponibles.'
              : 'Elige en que encuesta te quieres postular como candidato.',
          style: LuvegiText.bodySecondary,
        ),
        const SizedBox(height: LuvegiSpacing.lg),
        ...pendientes.map(_buildEncuesta),
        if (realizadas.isNotEmpty) ...[
          const SizedBox(height: LuvegiSpacing.lg),
          _buildSeccionPostuladas(realizadas),
        ],
      ],
    );
  }

  /// Resumen de las encuestas en las que ya se postuló el usuario.
  Widget _buildSeccionPostuladas(List<EncuestaVotable> lista) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tus postulaciones',
          style: LuvegiText.title.copyWith(fontSize: 16),
        ),
        const SizedBox(height: LuvegiSpacing.sm),
        ...lista.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.encuesta.titulo,
                    style: LuvegiText.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: LuvegiSpacing.sm),
                  _buildEstadoPostulacion(e),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEncuesta(EncuestaVotable e) {
    // Clave estable para que el refresco no recree la tarjeta.
    final yaPostulo = e.misPostulaciones.isNotEmpty;
    final enInscripcion = e.encuesta.postulacionesAbiertas;
    final marcados = _requisitosMarcados[e.encuesta.id] ?? {};
    final requisitosObligatorios = e.requisitos
        .where((r) => r.obligatorio)
        .toList();
    final todosMarcados = requisitosObligatorios.every(
      (r) => marcados.contains(r.id),
    );
    final puedePostular = !yaPostulo && enInscripcion && todosMarcados;

    // Texto y color del estado segun donde este el proceso.
    final String chipTexto;
    final Color estadoChipColor;
    if (yaPostulo) {
      chipTexto = 'Ya postulado';
      estadoChipColor = LuvegiColors.secondary;
    } else if (!enInscripcion) {
      chipTexto = 'Inscripción cerrada';
      estadoChipColor = LuvegiColors.textSecondary;
    } else if (!todosMarcados) {
      chipTexto = 'Marca los requisitos';
      estadoChipColor = LuvegiColors.warning;
    } else {
      chipTexto = 'Puedes postularte';
      estadoChipColor = LuvegiColors.success;
    }

    return Padding(
      key: ValueKey('post-${e.encuesta.id}'),
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.lg),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final titulo = Text(e.encuesta.titulo, style: LuvegiText.title);
                final chip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: estadoChipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    chipTexto,
                    style: LuvegiText.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: estadoChipColor,
                    ),
                  ),
                );

                // En pantallas estrechas el estado pasa debajo del titulo.
                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titulo,
                      const SizedBox(height: LuvegiSpacing.sm),
                      chip,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: titulo),
                    const SizedBox(width: LuvegiSpacing.sm),
                    chip,
                  ],
                );
              },
            ),
            if (e.encuesta.descripcion.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.sm),
              Text(e.encuesta.descripcion, style: LuvegiText.bodySecondary),
            ],
            if (!yaPostulo && e.requisitos.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.md),
              tarjetaRequisitos(
                e.requisitos,
                marcados: marcados,
                onCambio: (id, activo) {
                  setState(() {
                    final actual = _requisitosMarcados[e.encuesta.id] ?? {};
                    if (activo) {
                      actual.add(id);
                    } else {
                      actual.remove(id);
                    }
                    _requisitosMarcados[e.encuesta.id] = actual;
                  });
                },
              ),
            ],
            if (yaPostulo) ...[
              const SizedBox(height: LuvegiSpacing.md),
              _buildEstadoPostulacion(e),
            ] else if (enInscripcion) ...[
              const SizedBox(height: LuvegiSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: puedePostular ? () => _postular(e) : null,
                  icon: const Icon(Icons.how_to_reg_outlined, size: 16),
                  label: const Text('Postularme en esta encuesta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LuvegiColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (!todosMarcados && requisitosObligatorios.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Marca todos los requisitos obligatorios para poder postularte.',
                    style: LuvegiText.caption.copyWith(
                      color: LuvegiColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
            if (!yaPostulo && !enInscripcion) ...[
              const SizedBox(height: LuvegiSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
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
                      Icons.lock_outline,
                      size: 20,
                      color: LuvegiColors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'La inscripción de esta encuesta ya está cerrada.',
                        style: LuvegiText.bodySecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoPostulacion(EncuestaVotable e) {
    final postulacion = e.misPostulaciones.entries.first;
    // La postulacion no pasa por validacion: queda registrada tal cual.
    final titulo = 'Postulación registrada';
    final detalle =
        'Tu registro quedó guardado con tu usuario y número de DNI.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LuvegiColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 22,
            color: LuvegiColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: LuvegiText.body.copyWith(
                    color: LuvegiColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(detalle, style: LuvegiText.bodySecondary),
                if (e.puedeRetirar) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _retirar(e, postulacion.value),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Retirar postulación'),
                      style: TextButton.styleFrom(
                        foregroundColor: LuvegiColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _postular(EncuestaVotable e) async {
    final preguntaRequisitos = e.preguntas.isNotEmpty
        ? e.preguntas.first
        : null;
    final opcionesRequisito = e.requisitos.isEmpty && preguntaRequisitos != null
        ? requisitosDesdeOpciones(preguntaRequisitos)
        : const <EncuestaOpcion>[];
    final ok = await mostrarDialogoPostular(
      context: context,
      service: _service,
      token: widget.token,
      encuestaId: e.encuesta.id,
      pregunta: EncuestaPregunta(
        id: 0,
        encuestaId: e.encuesta.id,
        nombre: e.encuesta.titulo,
        descripcion: '',
        orden: 0,
        opciones: const [],
      ),
      requisitos: e.requisitos,
      opcionesRequisito: opcionesRequisito,
      requisitosPreviamenteMarcados:
          _requisitosMarcados[e.encuesta.id]?.toList() ?? const [],
      nombreUsuario: e.miNombre.isNotEmpty ? e.miNombre : _miNombre,
      dniUsuario: e.miDni,
    );
    if (!ok || !mounted) return;
    await _cargar();
  }

  Future<void> _retirar(EncuestaVotable e, int opcionId) async {
    try {
      await _service.retirarPostulacion(
        token: widget.token,
        opcionId: opcionId,
      );
      if (!mounted) return;
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu postulación se retiró.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajeError.desdeExcepcion(e)),
          backgroundColor: LuvegiColors.error,
        ),
      );
    }
  }

  Widget _card({required Widget child}) => SizedBox(
    width: double.infinity,
    child: Material(
      color: LuvegiColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        side: const BorderSide(color: LuvegiColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LuvegiSpacing.lg),
        child: child,
      ),
    ),
  );
}
