import 'package:flutter/material.dart';

import '../../design_system/luvegi_card.dart';
import '../../services/encuesta_service.dart';
import '../../theme/luvegi_colors.dart';
import '../../theme/luvegi_radius.dart';
import '../../theme/luvegi_spacing.dart';
import '../../theme/luvegi_text.dart';
import '../../utils/mensaje_error.dart';

class HistorialEncuestasSection extends StatefulWidget {
  final String token;
  final String titulo;
  final Set<String>? tipos;
  final Set<String>? tiposEncuesta;
  final int refreshKey;

  const HistorialEncuestasSection({
    super.key,
    required this.token,
    this.titulo = 'Historial de participación',
    this.tipos,
    this.tiposEncuesta,
    this.refreshKey = 0,
  });

  @override
  State<HistorialEncuestasSection> createState() =>
      _HistorialEncuestasSectionState();
}

class _HistorialEncuestasSectionState extends State<HistorialEncuestasSection> {
  final EncuestaService _service = EncuestaService();

  bool _cargando = true;
  String? _error;
  List<EncuestaHistorialItem> _items = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant HistorialEncuestasSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final items = await _service.obtenerHistorialEncuestas(
        token: widget.token,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = MensajeError.desdeExcepcion(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<EncuestaHistorialItem> get _visibles {
    final tipos = widget.tipos;
    final tiposEncuesta = widget.tiposEncuesta;
    if (tipos == null && tiposEncuesta == null) return _items;
    return _items.where((e) {
      final porParticipacion =
          tipos == null || tipos.contains(e.tipoParticipacion.toUpperCase());
      final porEncuesta =
          tiposEncuesta == null ||
          tiposEncuesta.contains(e.tipoEncuesta.toUpperCase());
      return porParticipacion && porEncuesta;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: LuvegiSpacing.xl),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.titulo,
                style: LuvegiText.title.copyWith(fontSize: 16),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar historial',
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: LuvegiSpacing.sm),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: LuvegiSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          LuvegiCard(
            padding: const EdgeInsets.all(LuvegiSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!, style: LuvegiText.body),
                const SizedBox(height: LuvegiSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          )
        else if (items.isEmpty)
          LuvegiCard(
            padding: const EdgeInsets.all(LuvegiSpacing.md),
            child: Text(
              'Todavía no tienes participaciones registradas.',
              style: LuvegiText.bodySecondary,
            ),
          )
        else
          ...items.map(_buildItem),
      ],
    );
  }

  Widget _buildItem(EncuestaHistorialItem item) {
    final esVoto = item.esVoto;
    final esCuestionario = item.esCuestionario;
    final estado = item.estadoMostrado.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: LuvegiSpacing.sm),
      child: LuvegiCard(
        padding: const EdgeInsets.all(LuvegiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  esCuestionario
                      ? Icons.quiz_outlined
                      : esVoto
                      ? Icons.how_to_vote_outlined
                      : Icons.how_to_reg_outlined,
                  color: LuvegiColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: LuvegiSpacing.sm),
                Expanded(
                  child: Text(
                    item.titulo.isEmpty
                        ? item.etiquetaTipoEncuesta
                        : item.titulo,
                    style: LuvegiText.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _etiqueta(item.etiquetaParticipacion, LuvegiColors.secondary),
              ],
            ),
            if (item.descripcion.isNotEmpty) ...[
              const SizedBox(height: LuvegiSpacing.xs),
              Text(item.descripcion, style: LuvegiText.bodySecondary),
            ],
            const SizedBox(height: LuvegiSpacing.sm),
            Wrap(
              spacing: LuvegiSpacing.sm,
              runSpacing: LuvegiSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _etiqueta(estado, _colorEstado(estado)),
                Text(
                  'Participaste el ${_fecha(item.fechaParticipacion)}',
                  style: LuvegiText.caption,
                ),
                if (esVoto && item.recibo != null && item.recibo!.isNotEmpty)
                  Text('Recibo: ${item.recibo}', style: LuvegiText.caption),
                if (esCuestionario)
                  Text('Respuesta registrada', style: LuvegiText.caption),
                if (!esVoto)
                  Text(
                    item.retirada
                        ? 'Retiraste tu postulación'
                        : 'Postulación registrada',
                    style: LuvegiText.caption,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        texto,
        style: LuvegiText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'RETIRADA':
      case 'RECHAZADA':
        return LuvegiColors.error;
      case 'APROBADA':
        return LuvegiColors.success;
      case 'ABIERTA':
        return LuvegiColors.info;
      default:
        return LuvegiColors.textSecondary;
    }
  }

  String _fecha(String valor) {
    if (valor.isEmpty) return '—';
    final fecha = DateTime.tryParse(valor.replaceFirst(' ', 'T'))?.toLocal();
    if (fecha == null) return valor;
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $hora:$minuto';
  }
}
