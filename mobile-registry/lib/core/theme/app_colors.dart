import 'package:flutter/material.dart';

/// Paleta oficial do app. Os pares texto/fundo usados no tema têm contraste
/// mínimo de 4,5:1 (WCAG AA) — ver test/core/theme/contrast_test.dart.
abstract final class AppColors {
  /// Cor principal (AppBar, botões primários).
  static const Color primary = Color(0xFF31566A);

  /// Detalhes e destaques (erros, ações de atenção).
  static const Color accent = Color(0xFFB51F2E);

  /// Fundo das telas.
  static const Color background = Color(0xFFF7F7F4);

  /// Áreas de apoio, cards e elementos secundários.
  static const Color support = Color(0xFFE5EBEE);

  /// Texto principal (alto contraste sobre fundo e cards).
  static const Color textPrimary = Color(0xFF1B2A33);

  /// Texto secundário (dicas e legendas).
  static const Color textSecondary = Color(0xFF3F5560);

  /// Texto sobre a cor principal ou sobre o destaque.
  static const Color onDark = Color(0xFFFFFFFF);
}
