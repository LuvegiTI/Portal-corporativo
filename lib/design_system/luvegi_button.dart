import 'package:flutter/material.dart';

import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_spacing.dart';
import '../theme/luvegi_text.dart';

enum LuvegiButtonType { primary, secondary, outline, danger }

class LuvegiButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final LuvegiButtonType type;
  final double? width;

  const LuvegiButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.type = LuvegiButtonType.primary,
    this.width,
  });

  const LuvegiButton.primary({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.width,
  }) : type = LuvegiButtonType.primary;

  const LuvegiButton.secondary({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.width,
  }) : type = LuvegiButtonType.secondary;

  const LuvegiButton.outline({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.width,
  }) : type = LuvegiButtonType.outline;

  const LuvegiButton.danger({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.width,
  }) : type = LuvegiButtonType.danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    final backgroundColor = switch (type) {
      LuvegiButtonType.primary => LuvegiColors.primary,
      LuvegiButtonType.secondary => LuvegiColors.secondary,
      LuvegiButtonType.outline => Colors.transparent,
      LuvegiButtonType.danger => LuvegiColors.error,
    };

    final foregroundColor = switch (type) {
      LuvegiButtonType.outline => LuvegiColors.secondary,
      _ => Colors.white,
    };

    final borderColor = switch (type) {
      LuvegiButtonType.outline => LuvegiColors.secondary,
      _ => Colors.transparent,
    };

    return SizedBox(
      width: width,
      height: 46,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: LuvegiColors.border,
          disabledForegroundColor: LuvegiColors.textHint,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: LuvegiSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            side: BorderSide(color: borderColor),
          ),
          textStyle: LuvegiText.button,
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: LuvegiSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
