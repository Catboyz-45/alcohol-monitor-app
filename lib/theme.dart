import 'package:flutter/material.dart';

import 'device_reading.dart';

// โทนสีหลักและสีสถานะของแอป ใช้ทั้งโหมดสว่างและโหมดมืด
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF1D4ED8);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F6FB),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? const Color(0xFF131C2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF0F1828) : const Color(0xFFF8FAFD),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

extension AlertStatusStyle on AlertStatus {
  Color get color => switch (this) {
    AlertStatus.safe => const Color(0xFF16A34A),
    AlertStatus.warning => const Color(0xFFD97706),
    AlertStatus.danger => const Color(0xFFDC2626),
  };

  IconData get icon => switch (this) {
    AlertStatus.safe => Icons.check_circle_rounded,
    AlertStatus.warning => Icons.error_rounded,
    AlertStatus.danger => Icons.warning_rounded,
  };
}
