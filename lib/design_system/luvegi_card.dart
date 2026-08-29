import 'package:flutter/material.dart';

import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_shadows.dart';
import '../theme/luvegi_spacing.dart';

class LuvegiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const LuvegiCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: width,
      height: height,
      padding: padding ??
          const EdgeInsets.all(
            LuvegiSpacing.lg,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? LuvegiColors.card,
        borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        border: Border.all(
          color: LuvegiColors.border,
        ),
        boxShadow: LuvegiShadows.card,
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuvegiRadius.lg),
      child: content,
    );
  }
}