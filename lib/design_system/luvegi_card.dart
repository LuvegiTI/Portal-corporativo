import 'package:flutter/material.dart';

import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_shadows.dart';
import '../theme/luvegi_spacing.dart';

class LuvegiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? maxWidth;
  final double? height;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const LuvegiCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.maxWidth,
    this.height,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LuvegiRadius.lg);

    Widget inner = Padding(
      padding: padding ?? const EdgeInsets.all(LuvegiSpacing.lg),
      child: child,
    );

    if (onTap != null) {
      inner = InkWell(onTap: onTap, child: inner);
    }

    return Container(
      width: width,
      height: height,
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth!)
          : null,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: LuvegiShadows.card,
      ),
      child: Material(
        color: backgroundColor ?? LuvegiColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: LuvegiColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: inner,
      ),
    );
  }
}
