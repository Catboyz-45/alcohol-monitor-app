import 'package:flutter/material.dart';

import 'device_reading.dart';

// โทนของแอป: สว่าง ตัดกันชัด อ่านง่ายกลางแจ้ง (ด่านตรวจตอนกลางวัน)
// สีทุกคู่ข้อความ/พื้นผ่าน contrast 4.5:1 และสีสถานะต่างกันทั้งสีและความสว่าง
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.divider,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.safeInk,
    required this.safeSoft,
    required this.warningInk,
    required this.warningSoft,
    required this.dangerInk,
    required this.dangerSoft,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color divider;
  final Color ink;
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color safeInk;
  final Color safeSoft;
  final Color warningInk;
  final Color warningSoft;
  final Color dangerInk;
  final Color dangerSoft;

  static const light = AppColors(
    background: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F5F7),
    border: Color(0xFFE4E7EC),
    divider: Color(0xFFEEF0F3),
    ink: Color(0xFF0F172A),
    muted: Color(0xFF5B6474),
    primary: Color(0xFF1D4ED8),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE8EEFD),
    onPrimarySoft: Color(0xFF1E3A8A),
    safeInk: Color(0xFF0E7A4D),
    safeSoft: Color(0xFFE3F4EC),
    warningInk: Color(0xFF8A5200),
    warningSoft: Color(0xFFFDF1DC),
    dangerInk: Color(0xFFB42318),
    dangerSoft: Color(0xFFFDE8E6),
  );

  static const dark = AppColors(
    background: Color(0xFF0B1220),
    surface: Color(0xFF131C2E),
    surfaceMuted: Color(0xFF1A2438),
    border: Color(0xFF26324A),
    divider: Color(0xFF1F2A3F),
    ink: Color(0xFFF1F4F9),
    muted: Color(0xFFA3ADBF),
    primary: Color(0xFF6E95F5),
    onPrimary: Color(0xFF0B1220),
    primarySoft: Color(0xFF1C2C52),
    onPrimarySoft: Color(0xFFC9D7FB),
    safeInk: Color(0xFF4ACB8E),
    safeSoft: Color(0xFF12301F),
    warningInk: Color(0xFFF7BE5A),
    warningSoft: Color(0xFF3A2A0C),
    dangerInk: Color(0xFFFF8A7E),
    dangerSoft: Color(0xFF3D1512),
  );

  Color statusInk(AlertStatus status) => switch (status) {
    AlertStatus.safe => safeInk,
    AlertStatus.warning => warningInk,
    AlertStatus.danger => dangerInk,
  };

  Color statusSoft(AlertStatus status) => switch (status) {
    AlertStatus.safe => safeSoft,
    AlertStatus.warning => warningSoft,
    AlertStatus.danger => dangerSoft,
  };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  const AppTheme._();

  // ฟอนต์ที่ฝังไว้ใน assets/fonts (ประกาศใน pubspec.yaml)
  static const fontFamily = 'IBMPlexSansThai';

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      outline: c.border,
      outlineVariant: c.divider,
      error: c.dangerInk,
    );
    final radius12 = BorderRadius.circular(12);
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: color, width: width),
        );
    const buttonText = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: c.background,
      extensions: [c],
      dividerColor: c.divider,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: c.muted),
        border: outline(c.border),
        enabledBorder: outline(
          brightness == Brightness.light ? const Color(0xFFCBD2DC) : c.border,
        ),
        focusedBorder: outline(c.primary, 2),
        errorBorder: outline(c.dangerInk),
        focusedErrorBorder: outline(c.dangerInk, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: buttonShape,
          foregroundColor: c.ink,
          side: BorderSide(
            color:
                brightness == Brightness.light
                    ? const Color(0xFFCBD2DC)
                    : c.border,
          ),
          textStyle: buttonText.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? c.primary : c.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? c.primary : c.muted,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

extension AlertStatusStyle on AlertStatus {
  // พื้นเต็มของหน้าผลตรวจและแถบสัดส่วน (ใช้คู่กับ onFill)
  Color get fill => switch (this) {
    AlertStatus.safe => const Color(0xFF0E7A4D),
    AlertStatus.warning => const Color(0xFFF5A524),
    AlertStatus.danger => const Color(0xFFB42318),
  };

  Color get onFill => switch (this) {
    AlertStatus.warning => const Color(0xFF2B1A00),
    _ => Colors.white,
  };

  IconData get icon => switch (this) {
    AlertStatus.safe => Icons.check_circle_rounded,
    AlertStatus.warning => Icons.error_rounded,
    AlertStatus.danger => Icons.warning_rounded,
  };
}
