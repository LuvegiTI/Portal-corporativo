import 'package:flutter/material.dart';

import 'luvegi_colors.dart';
import 'luvegi_radius.dart';
import 'luvegi_text.dart';

class LuvegiTheme {
  LuvegiTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LuvegiColors.primary,
      brightness: Brightness.light,
      primary: LuvegiColors.primary,
      secondary: LuvegiColors.secondary,
      surface: LuvegiColors.surface,
      error: LuvegiColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: LuvegiColors.background,

      fontFamily: 'Roboto',

      textTheme: const TextTheme(
        displayLarge: LuvegiText.display,
        headlineLarge: LuvegiText.heading,
        titleLarge: LuvegiText.title,
        bodyLarge: LuvegiText.body,
        bodyMedium: LuvegiText.body,
        bodySmall: LuvegiText.caption,
        labelLarge: LuvegiText.button,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: LuvegiColors.surface,
        foregroundColor: LuvegiColors.textPrimary,
        surfaceTintColor: LuvegiColors.surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: LuvegiColors.secondary,
        ),
        titleTextStyle: TextStyle(
          color: LuvegiColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: Border(
          bottom: BorderSide(
            color: LuvegiColors.border,
            width: 1,
          ),
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: LuvegiColors.surface,
        surfaceTintColor: LuvegiColors.surface,
        elevation: 8,
      ),

      cardTheme: CardThemeData(
        color: LuvegiColors.card,
        surfaceTintColor: LuvegiColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
          side: const BorderSide(
            color: LuvegiColors.border,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: LuvegiColors.divider,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LuvegiColors.surface,
        hintStyle: const TextStyle(
          color: LuvegiColors.textHint,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: LuvegiColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          borderSide: const BorderSide(
            color: LuvegiColors.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          borderSide: const BorderSide(
            color: LuvegiColors.error,
            width: 2,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LuvegiColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(120, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          ),
          textStyle: LuvegiText.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LuvegiColors.secondary,
          minimumSize: const Size(120, 46),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          side: const BorderSide(
            color: LuvegiColors.secondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LuvegiColors.secondary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LuvegiRadius.sm),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LuvegiColors.primary,
        foregroundColor: Colors.white,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LuvegiColors.secondary;
          }

          return Colors.transparent;
        }),
        side: const BorderSide(
          color: LuvegiColors.border,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LuvegiColors.secondary;
          }

          return LuvegiColors.textSecondary;
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return LuvegiColors.textHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return LuvegiColors.secondary;
          }

          return LuvegiColors.border;
        }),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: LuvegiColors.surface,
        surfaceTintColor: LuvegiColors.surface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.lg),
        ),
        titleTextStyle: LuvegiText.title,
        contentTextStyle: LuvegiText.bodySecondary,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: LuvegiColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.sm),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: LuvegiColors.surface,
        surfaceTintColor: LuvegiColors.surface,
        elevation: 10,
        textStyle: LuvegiText.menu,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuvegiRadius.md),
          side: const BorderSide(
            color: LuvegiColors.border,
          ),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: LuvegiColors.textSecondary,
        textColor: LuvegiColors.textPrimary,
        selectedColor: LuvegiColors.secondary,
        selectedTileColor: LuvegiColors.menuHover,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 2,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LuvegiColors.secondary,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          LuvegiColors.secondary.withOpacity(0.65),
        ),
        trackColor: WidgetStateProperty.all(
          LuvegiColors.border,
        ),
        radius: const Radius.circular(20),
        thickness: WidgetStateProperty.all(8),
      ),
    );
  }
}