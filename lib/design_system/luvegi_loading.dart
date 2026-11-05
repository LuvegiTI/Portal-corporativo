import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

class LuvegiProgresoReporte extends StatelessWidget {
  final double valor;
  final int paso;
  final List<String> pasos;

  const LuvegiProgresoReporte({
    super.key,
    required this.valor,
    required this.paso,
    required this.pasos,
  });

  @override
  Widget build(BuildContext context) {
    final indice = paso.clamp(0, pasos.length - 1);

    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(LuvegiSpacing.lg),
        decoration: BoxDecoration(
          color: LuvegiColors.surface,
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
          border: Border.all(
            color: LuvegiColors.secondary.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.analytics_outlined,
              color: LuvegiColors.secondary,
              size: 32,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Text(
              'Generando reporte',
              style: LuvegiText.title.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LuvegiSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(LuvegiRadius.sm),
              child: LinearProgressIndicator(
                value: valor,
                minHeight: 8,
                backgroundColor: LuvegiColors.secondary.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  LuvegiColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: LuvegiSpacing.md),
            Text(
              '${pasos[indice]}…',
              style: LuvegiText.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

mixin LuvegiProgresoMixin<T extends StatefulWidget> on State<T> {
  Timer? _progresoTimer;
  int _pasoProgreso = 0;
  double _valorProgreso = 0;

  static const List<String> _pasosProgreso = [
    'Conectando con Odoo',
    'Analizando requisitos',
    'Analizando datos calculados',
    'Mejorando análisis de datos',
    'Organizando datos',
    'Estructurando tabla de datos',
    'Enviando información de Odoo al Portal LUVEGI',
    'Mostrando resultados',
  ];

  void iniciarProgreso() {
    cancelarProgresoTimer();
    setState(() {
      _pasoProgreso = 0;
      _valorProgreso = 0;
    });

    _progresoTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() {
        final totalPasos = _pasosProgreso.length;
        if (_pasoProgreso < totalPasos - 1) {
          _pasoProgreso++;
        }
        _valorProgreso = (_pasoProgreso + 1) / totalPasos;
      });
    });
  }

  void detenerProgreso() {
    cancelarProgresoTimer();
  }

  void cancelarProgresoTimer() {
    _progresoTimer?.cancel();
    _progresoTimer = null;
  }

  Widget buildProgreso() {
    return LuvegiProgresoReporte(
      valor: _valorProgreso,
      paso: _pasoProgreso,
      pasos: _pasosProgreso,
    );
  }
}
