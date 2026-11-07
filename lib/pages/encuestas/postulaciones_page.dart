import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _service.obtenerEncuestasAbiertas(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() => _encuestas = lista);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
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
            const Icon(Icons.error_outline, color: LuvegiColors.error, size: 42),
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
              'Cuando RRHH abra una encuesta aparecra aqui para postularte.',
              textAlign: TextAlign.center,
              style: LuvegiText.bodySecondary,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Postulaciones', style: LuvegiText.title.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          'Elige en que encuesta te quieres postular como candidato.',
          style: LuvegiText.bodySecondary,
        ),
        const SizedBox(height: LuvegiSpacing.lg),
        ..._encuestas.map(_buildEncuesta),
      ],
    );
  }

  Widget _buildEncuesta(EncuestaVotable e) {
    final cumple = e.cumpleRequisitos;
    final yaPostulo = e.misPostulaciones.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.lg),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(e.encuesta.titulo, style: LuvegiText.title),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cumple
                        ? LuvegiColors.success.withValues(alpha: 0.12)
                        : LuvegiColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cumple ? 'Puedes postularte' : 'No cumples los requisitos',
                    style: LuvegiText.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cumple ? LuvegiColors.success : LuvegiColors.error,
                    ),
                  ),
                ),
              ],
            ),
            if (e.encuesta.descripcion.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.sm),
              Text(e.encuesta.descripcion, style: LuvegiText.bodySecondary),
            ],
            if (e.requisitos.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.md),
              tarjetaRequisitos(e.requisitos),
            ],
            if (yaPostulo) ...[
              const SizedBox(height: LuvegiSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.how_to_reg,
                    size: 16,
                    color: LuvegiColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ya te postulaste en ${e.misPostulaciones.length} '
                      'pregunta(s) de esta encuesta.',
                      style: LuvegiText.caption.copyWith(
                        color: LuvegiColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (e.preguntas.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.md),
              ...e.preguntas.map((p) => _buildPregunta(e, p)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPregunta(EncuestaVotable e, EncuestaPregunta pregunta) {
    final miOpcion = e.misPostulaciones[pregunta.id];
    final puede = e.cumpleRequisitos && e.puedeResponder;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LuvegiColors.surface,
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: LuvegiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pregunta.nombre,
            style: LuvegiText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (miOpcion != null)
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: LuvegiColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Te postulaste como candidato',
                    style: LuvegiText.caption.copyWith(
                      color: LuvegiColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _retirar(e, miOpcion),
                  style: TextButton.styleFrom(
                    foregroundColor: LuvegiColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Retirar'),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: puede ? () => _postular(e, pregunta) : null,
                icon: const Icon(Icons.how_to_reg_outlined, size: 16),
                label: const Text('Postularme en esta pregunta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LuvegiColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _postular(EncuestaVotable e, EncuestaPregunta pregunta) async {
    final ok = await mostrarDialogoPostular(
      context: context,
      service: _service,
      token: widget.token,
      encuestaId: e.encuesta.id,
      pregunta: pregunta,
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
