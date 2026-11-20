import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/theme/app_colors.dart';
import 'package:mobile_registry/core/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('paleta obrigatória está aplicada', () {
    expect(AppColors.primary, const Color(0xFF31566A));
    expect(AppColors.accent, const Color(0xFFB51F2E));
    expect(AppColors.background, const Color(0xFFF7F7F4));
    expect(AppColors.support, const Color(0xFFE5EBEE));

    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.secondary, AppColors.accent);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.cardTheme.color, AppColors.support);
  });

  group('contraste mínimo WCAG AA (4,5:1)', () {
    final pairs = <String, List<Color>>{
      'branco sobre cor principal (botões, AppBar)': [AppColors.onDark, AppColors.primary],
      'branco sobre destaque': [AppColors.onDark, AppColors.accent],
      'texto principal sobre fundo': [AppColors.textPrimary, AppColors.background],
      'texto principal sobre cards': [AppColors.textPrimary, AppColors.support],
      'texto secundário sobre fundo': [AppColors.textSecondary, AppColors.background],
      'texto secundário sobre cards': [AppColors.textSecondary, AppColors.support],
      'cor principal sobre fundo (botão de contorno)': [AppColors.primary, AppColors.background],
      'destaque sobre fundo (erros)': [AppColors.accent, AppColors.background],
      'destaque sobre cards (erros)': [AppColors.accent, AppColors.support],
    };

    pairs.forEach((name, colors) {
      test(name, () {
        expect(contrast(colors[0], colors[1]), greaterThanOrEqualTo(4.5));
      });
    });

    test('texto principal tem nível AAA (7:1) sobre o fundo', () {
      expect(contrast(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(7));
    });
  });

  test('botões têm altura mínima grande', () {
    final theme = AppTheme.light();
    expect(AppTheme.buttonHeight, greaterThanOrEqualTo(56));
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
      AppTheme.buttonHeight,
    );
  });
}
