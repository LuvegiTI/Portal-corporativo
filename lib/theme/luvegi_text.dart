import 'package:flutter/material.dart';

import 'luvegi_colors.dart';

class LuvegiText {
  LuvegiText._();

  // Título principal de una pantalla o banner
  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 1.20,
    fontWeight: FontWeight.w800,
    color: LuvegiColors.textPrimary,
  );

  // Encabezado principal de una sección
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w800,
    color: LuvegiColors.textPrimary,
  );

  // Título de tarjetas, diálogos o componentes
  static const TextStyle title = TextStyle(
    fontSize: 18,
    height: 1.30,
    fontWeight: FontWeight.w700,
    color: LuvegiColors.textPrimary,
  );

  // Texto de contenido general
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.50,
    fontWeight: FontWeight.w400,
    color: LuvegiColors.textPrimary,
  );

  // Texto secundario
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    height: 1.50,
    fontWeight: FontWeight.w400,
    color: LuvegiColors.textSecondary,
  );

  // Texto pequeño para detalles o etiquetas
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.40,
    fontWeight: FontWeight.w500,
    color: LuvegiColors.textSecondary,
  );

  // Texto para botones
  static const TextStyle button = TextStyle(
    fontSize: 14,
    height: 1.20,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  // Texto para elementos de menú
  static const TextStyle menu = TextStyle(
    fontSize: 13,
    height: 1.20,
    fontWeight: FontWeight.w600,
    color: LuvegiColors.textPrimary,
  );

  // Texto para menú seleccionado
  static const TextStyle menuSelected = TextStyle(
    fontSize: 13,
    height: 1.20,
    fontWeight: FontWeight.w700,
    color: LuvegiColors.secondary,
  );

  // Etiquetas pequeñas en mayúsculas
  static const TextStyle label = TextStyle(
    fontSize: 11,
    height: 1.20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.7,
    color: LuvegiColors.textSecondary,
  );

  // Valores numéricos de tarjetas o estadísticas
  static const TextStyle statistic = TextStyle(
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: LuvegiColors.textPrimary,
  );
}
