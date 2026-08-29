import 'package:flutter/material.dart';

import '../theme/luvegi_colors.dart';
import '../theme/luvegi_radius.dart';
import '../theme/luvegi_text.dart';

class LuvegiTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscureText;
  final double? width;

  const LuvegiTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        cursorColor: LuvegiColors.secondary,
        style: LuvegiText.body.copyWith(
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: LuvegiColors.surface,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(
                  prefixIcon,
                  color: LuvegiColors.textSecondary,
                ),
          labelStyle: LuvegiText.caption.copyWith(
            color: LuvegiColors.textSecondary,
          ),
          hintStyle: LuvegiText.bodySecondary.copyWith(
            color: LuvegiColors.textHint,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            borderSide: const BorderSide(
              color: LuvegiColors.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            borderSide: const BorderSide(
              color: LuvegiColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
            borderSide: const BorderSide(
              color: LuvegiColors.secondary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}