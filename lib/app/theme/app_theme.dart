import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => _buildLight();
  static ThemeData get darkTheme => _buildDark();

  // Compatibilidade com os pontos de uso existentes.
  static ThemeData get light => lightTheme;
  static ThemeData get dark => darkTheme;

  static ThemeData withAccessibility(
    ThemeData theme, {
    required bool highContrast,
    required bool reduceBrightness,
  }) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final adjustedScheme = scheme.copyWith(
      surface: reduceBrightness && isDark ? const Color(0xFF090E18) : null,
      surfaceContainerLow: reduceBrightness && isDark
          ? const Color(0xFF101927)
          : null,
      surfaceContainer: reduceBrightness && isDark
          ? const Color(0xFF162131)
          : null,
      onSurface: highContrast ? (isDark ? Colors.white : Colors.black) : null,
      onSurfaceVariant: highContrast
          ? (isDark ? const Color(0xFFF0F3F8) : const Color(0xFF17191D))
          : null,
      outline: highContrast ? (isDark ? Colors.white : Colors.black) : null,
      outlineVariant: highContrast
          ? (isDark ? const Color(0xFFBEC6D4) : const Color(0xFF30343B))
          : null,
    );
    return theme.copyWith(
      colorScheme: adjustedScheme,
      scaffoldBackgroundColor: adjustedScheme.surface,
      dividerTheme: DividerThemeData(color: adjustedScheme.outlineVariant),
      cardTheme: theme.cardTheme.copyWith(
        color: adjustedScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: adjustedScheme.outlineVariant,
            width: highContrast ? 1.5 : 1,
          ),
        ),
      ),
    );
  }

  static ThemeData _buildLight() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF155EEF),
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return _build(colorScheme);
  }

  static ThemeData _buildDark() {
    // Paleta própria: azul mantido, superfícies azul-acinzentadas e contraste
    // confortável, sem recorrer a preto ou branco puros.
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF9DB8FF),
      onPrimary: Color(0xFF002A78),
      primaryContainer: Color(0xFF0D3B98),
      onPrimaryContainer: Color(0xFFDCE6FF),
      secondary: Color(0xFFA9C7FF),
      onSecondary: Color(0xFF0A315D),
      secondaryContainer: Color(0xFF183F70),
      onSecondaryContainer: Color(0xFFD7E5FF),
      tertiary: Color(0xFFC6C2FF),
      onTertiary: Color(0xFF2D2A65),
      tertiaryContainer: Color(0xFF45417D),
      onTertiaryContainer: Color(0xFFE4E0FF),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF111827),
      onSurface: Color(0xFFE5EAF2),
      surfaceContainerLowest: Color(0xFF0C121E),
      surfaceContainerLow: Color(0xFF182132),
      surfaceContainer: Color(0xFF1C2637),
      surfaceContainerHigh: Color(0xFF273246),
      surfaceContainerHighest: Color(0xFF323D51),
      onSurfaceVariant: Color(0xFFC3CAD8),
      outline: Color(0xFF8D96A8),
      outlineVariant: Color(0xFF414B5C),
      inverseSurface: Color(0xFFE0E7F1),
      onInverseSurface: Color(0xFF192130),
      inversePrimary: Color(0xFF155EEF),
    );
    return _build(colorScheme);
  }

  static ThemeData _build(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        modalBackgroundColor: colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        headerBackgroundColor: colorScheme.primaryContainer,
        headerForegroundColor: colorScheme.onPrimaryContainer,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        dialBackgroundColor: colorScheme.surfaceContainer,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
