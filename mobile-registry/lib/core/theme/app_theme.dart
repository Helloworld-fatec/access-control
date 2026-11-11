import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Design system inicial (US-21): botões grandes, alto contraste,
/// campos com rótulo sempre visível e fontes que respeitam o tamanho do sistema.
abstract final class AppTheme {
  /// Altura mínima dos botões (acima dos 48 dp recomendados pelo Material).
  static const double buttonHeight = 64;
  static const double radius = 16;

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.onDark,
      error: AppColors.accent,
      onError: AppColors.onDark,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.support,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.primary,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme).textTheme;
    // Tamanhos em px lógicos: o Flutter multiplica pelo textScaler do sistema.
    final textTheme = base
        .copyWith(
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 20, height: 1.4),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 18, height: 1.4),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    const buttonSize = Size(double.infinity, buttonHeight);

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onDark,
        toolbarHeight: 64,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: AppColors.onDark),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onDark,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          foregroundColor: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.support,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        helperMaxLines: 3,
        errorMaxLines: 3,
        errorStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
        border: border(AppColors.primary, 1.5),
        enabledBorder: border(AppColors.primary, 1.5),
        focusedBorder: border(AppColors.primary, 3),
        errorBorder: border(AppColors.accent, 2),
        focusedErrorBorder: border(AppColors.accent, 3),
      ),
      cardTheme: CardThemeData(
        color: AppColors.support,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: buttonShape,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.primary, width: 2),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.support,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.onDark
                : AppColors.textPrimary,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: AppColors.onDark),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
