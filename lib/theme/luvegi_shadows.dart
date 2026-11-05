import 'package:flutter/material.dart';

import 'luvegi_colors.dart';

class LuvegiShadows {
  LuvegiShadows._();

  static const card = [
    BoxShadow(color: LuvegiColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const hover = [
    BoxShadow(
      color: LuvegiColors.shadow,
      blurRadius: 25,
      offset: Offset(0, 10),
    ),
  ];
}
