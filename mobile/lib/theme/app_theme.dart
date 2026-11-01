import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Decorative animated layer a theme can add on top of the app.
enum ThemeDecor { none, leaves, bubbles, petals, monsters, goldDust, stars, candy, clouds }

/// Full colour set for one app theme. Every screen reads colours through
/// [AppColors], which proxies the active palette, so switching themes
/// recolours the whole app.
class AppPalette {
  final String code;
  final Brightness brightness;
  final Color primary, primaryDeep, primaryLight, primarySoft;
  final Color bg, surface, surfaceAlt, line;
  final Color text, textMuted, textFaint;
  final Color ink, ink2, ink3; // hero / dark surfaces
  final List<Color> aurora; // 3 hero blob colours
  final Color accent;
  final ThemeDecor decor;

  const AppPalette({
    required this.code,
    required this.brightness,
    required this.primary,
    required this.primaryDeep,
    required this.primaryLight,
    required this.primarySoft,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.aurora,
    required this.accent,
    this.decor = ThemeDecor.none,
  });

  bool get isDark => brightness == Brightness.dark;

  static const light = AppPalette(
    code: 'LIGHT',
    brightness: Brightness.light,
    primary: Color(0xFFE11D2E),
    primaryDeep: Color(0xFFB0101F),
    primaryLight: Color(0xFFFF5A4E),
    primarySoft: Color(0xFFFFE4E6),
    bg: Color(0xFFF5F6FA),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF8F9FC),
    line: Color(0xFFE7E9F0),
    text: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
    textFaint: Color(0xFF94A3B8),
    ink: Color(0xFF0B1020),
    ink2: Color(0xFF141A2E),
    ink3: Color(0xFF1E2640),
    aurora: [Color(0xFFE11D2E), Color(0xFFD9268A), Color(0xFFFFB020)],
    accent: Color(0xFFFFB020),
  );

  static const dark = AppPalette(
    code: 'DARK',
    brightness: Brightness.dark,
    primary: Color(0xFFF43F5E),
    primaryDeep: Color(0xFFBE123C),
    primaryLight: Color(0xFFFF7A8A),
    primarySoft: Color(0xFF3A1621),
    bg: Color(0xFF0B1020),
    surface: Color(0xFF151B2E),
    surfaceAlt: Color(0xFF1C2438),
    line: Color(0xFF263049),
    text: Color(0xFFF1F5F9),
    textMuted: Color(0xFF94A3B8),
    textFaint: Color(0xFF64748B),
    ink: Color(0xFF05070F),
    ink2: Color(0xFF0D1222),
    ink3: Color(0xFF182038),
    aurora: [Color(0xFFF43F5E), Color(0xFF8B5CF6), Color(0xFFFFB020)],
    accent: Color(0xFFFFB020),
  );

  static const forest = AppPalette(
    code: 'FOREST',
    brightness: Brightness.light,
    primary: Color(0xFF16A34A),
    primaryDeep: Color(0xFF166534),
    primaryLight: Color(0xFF4ADE80),
    primarySoft: Color(0xFFDCFCE7),
    bg: Color(0xFFF2F8F3),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF5FAF6),
    line: Color(0xFFDCE9DF),
    text: Color(0xFF0F1F14),
    textMuted: Color(0xFF5B7262),
    textFaint: Color(0xFF94A99A),
    ink: Color(0xFF0B2216),
    ink2: Color(0xFF123524),
    ink3: Color(0xFF1C4630),
    aurora: [Color(0xFF16A34A), Color(0xFF84CC16), Color(0xFF0EA5E9)],
    accent: Color(0xFFFACC15),
    decor: ThemeDecor.leaves,
  );

  static const ocean = AppPalette(
    code: 'OCEAN',
    brightness: Brightness.light,
    primary: Color(0xFF0284C7),
    primaryDeep: Color(0xFF075985),
    primaryLight: Color(0xFF38BDF8),
    primarySoft: Color(0xFFE0F2FE),
    bg: Color(0xFFF1F7FB),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF4F9FC),
    line: Color(0xFFDBE8F1),
    text: Color(0xFF0B1E33),
    textMuted: Color(0xFF557089),
    textFaint: Color(0xFF93A8BB),
    ink: Color(0xFF061527),
    ink2: Color(0xFF0B1E33),
    ink3: Color(0xFF122B47),
    aurora: [Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF6366F1)],
    accent: Color(0xFF2DD4BF),
    decor: ThemeDecor.bubbles,
  );

  static const sakura = AppPalette(
    code: 'SAKURA',
    brightness: Brightness.light,
    primary: Color(0xFFEC4899),
    primaryDeep: Color(0xFFBE185D),
    primaryLight: Color(0xFFF9A8D4),
    primarySoft: Color(0xFFFCE7F3),
    bg: Color(0xFFFFF5F9),
    surface: Colors.white,
    surfaceAlt: Color(0xFFFFF8FB),
    line: Color(0xFFF7DCE8),
    text: Color(0xFF3B0A24),
    textMuted: Color(0xFF8A5A73),
    textFaint: Color(0xFFC09AAD),
    ink: Color(0xFF2A0619),
    ink2: Color(0xFF3B0A24),
    ink3: Color(0xFF52112F),
    aurora: [Color(0xFFEC4899), Color(0xFFF9A8D4), Color(0xFFA855F7)],
    accent: Color(0xFFFDE68A),
    decor: ThemeDecor.petals,
  );

  static const monster = AppPalette(
    code: 'MONSTER',
    brightness: Brightness.light,
    primary: Color(0xFF8B5CF6),
    primaryDeep: Color(0xFF6D28D9),
    primaryLight: Color(0xFFA78BFA),
    primarySoft: Color(0xFFEDE9FE),
    bg: Color(0xFFF6F3FF),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF9F7FF),
    line: Color(0xFFE6E0FA),
    text: Color(0xFF1E1240),
    textMuted: Color(0xFF6B5F92),
    textFaint: Color(0xFFA79DC6),
    ink: Color(0xFF140C2E),
    ink2: Color(0xFF1E1240),
    ink3: Color(0xFF2C1C5C),
    aurora: [Color(0xFF8B5CF6), Color(0xFF22C55E), Color(0xFFF59E0B)],
    accent: Color(0xFF22C55E),
    decor: ThemeDecor.monsters,
  );

  static const golden = AppPalette(
    code: 'GOLDEN',
    brightness: Brightness.dark,
    primary: Color(0xFFF5B70A),
    primaryDeep: Color(0xFFB45309),
    primaryLight: Color(0xFFFCD34D),
    primarySoft: Color(0xFF3A2E10),
    bg: Color(0xFF0E0C08),
    surface: Color(0xFF1A1710),
    surfaceAlt: Color(0xFF221E15),
    line: Color(0xFF3A3320),
    text: Color(0xFFFDF6E3),
    textMuted: Color(0xFFC8B98F),
    textFaint: Color(0xFF8C7F5C),
    ink: Color(0xFF0A0805),
    ink2: Color(0xFF15110A),
    ink3: Color(0xFF241C0E),
    aurora: [Color(0xFFF5B70A), Color(0xFFB45309), Color(0xFF7C2D12)],
    accent: Color(0xFFFCD34D),
    decor: ThemeDecor.goldDust,
  );

  static const galaxy = AppPalette(
    code: 'GALAXY',
    brightness: Brightness.dark,
    primary: Color(0xFFA78BFA),
    primaryDeep: Color(0xFF7C3AED),
    primaryLight: Color(0xFFC4B5FD),
    primarySoft: Color(0xFF2A2150),
    bg: Color(0xFF070A1A),
    surface: Color(0xFF11152B),
    surfaceAlt: Color(0xFF181D38),
    line: Color(0xFF262C4D),
    text: Color(0xFFEEF0FF),
    textMuted: Color(0xFF9CA3C8),
    textFaint: Color(0xFF6B7299),
    ink: Color(0xFF04050F),
    ink2: Color(0xFF0A0D22),
    ink3: Color(0xFF151A3A),
    aurora: [Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFFDB2777)],
    accent: Color(0xFF38BDF8),
    decor: ThemeDecor.stars,
  );

  static const candy = AppPalette(
    code: 'CANDY',
    brightness: Brightness.light,
    primary: Color(0xFFF472B6),
    primaryDeep: Color(0xFFDB2777),
    primaryLight: Color(0xFFFDA4AF),
    primarySoft: Color(0xFFFFE4F0),
    bg: Color(0xFFFFF7FB),
    surface: Colors.white,
    surfaceAlt: Color(0xFFFFFAFD),
    line: Color(0xFFF8E1EE),
    text: Color(0xFF3A1D33),
    textMuted: Color(0xFF8E6A84),
    textFaint: Color(0xFFC3A6BA),
    ink: Color(0xFF2B1530),
    ink2: Color(0xFF3A1D42),
    ink3: Color(0xFF4C2656),
    aurora: [Color(0xFFF472B6), Color(0xFF60A5FA), Color(0xFFFDE047)],
    accent: Color(0xFF60A5FA),
    decor: ThemeDecor.candy,
  );

  static const sunset = AppPalette(
    code: 'SUNSET',
    brightness: Brightness.light,
    primary: Color(0xFFF97316),
    primaryDeep: Color(0xFFC2410C),
    primaryLight: Color(0xFFFDBA74),
    primarySoft: Color(0xFFFFEDD5),
    bg: Color(0xFFFFF7F0),
    surface: Colors.white,
    surfaceAlt: Color(0xFFFFFAF5),
    line: Color(0xFFF6E2D2),
    text: Color(0xFF2E1408),
    textMuted: Color(0xFF85614B),
    textFaint: Color(0xFFBFA08B),
    ink: Color(0xFF2A0F1F),
    ink2: Color(0xFF3A1428),
    ink3: Color(0xFF521C36),
    aurora: [Color(0xFFF97316), Color(0xFFDB2777), Color(0xFFFACC15)],
    accent: Color(0xFFFACC15),
    decor: ThemeDecor.clouds,
  );

  static const all = {
    'LIGHT': light,
    'DARK': dark,
    'FOREST': forest,
    'OCEAN': ocean,
    'SAKURA': sakura,
    'MONSTER': monster,
    'GOLDEN': golden,
    'GALAXY': galaxy,
    'CANDY': candy,
    'SUNSET': sunset,
  };

  static AppPalette of(String? code) => all[code] ?? light;
}

/// Design tokens. Theme-dependent colours are getters on the active palette;
/// status colours stay constant across themes.
class AppColors {
  AppColors._();

  /// The active palette. Change via [ThemeController].
  static AppPalette palette = AppPalette.light;

  // Brand (follows the theme)
  static Color get red => palette.primary;
  static Color get redDeep => palette.primaryDeep;
  static Color get redSoft => palette.primarySoft;
  static Color get coral => palette.primaryLight;
  static Color get amber => palette.accent;
  static Color get magenta => palette.aurora[1];

  // Ink (dark hero surfaces)
  static Color get ink => palette.ink;
  static Color get ink2 => palette.ink2;
  static Color get ink3 => palette.ink3;

  // Neutrals
  static Color get bg => palette.bg;
  static Color get surface => palette.surface;
  static Color get surfaceAlt => palette.surfaceAlt;
  static Color get line => palette.line;
  static Color get text => palette.text;
  static Color get textMuted => palette.textMuted;
  static Color get textFaint => palette.textFaint;

  // Semantic (constant)
  static const success = Color(0xFF10B981);
  static const successDeep = Color(0xFF047857);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF6366F1);
  static const overtime = Color(0xFF8B5CF6);
}

class AppGradients {
  AppGradients._();

  static LinearGradient get brand => LinearGradient(
        colors: [AppColors.coral, AppColors.red, AppColors.redDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const checkout = LinearGradient(
    colors: [Color(0xFF34D399), AppColors.success, AppColors.successDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get ink => LinearGradient(
        colors: [AppColors.ink3, AppColors.ink2, AppColors.ink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const streak = LinearGradient(
    colors: [Color(0xFFFFC94D), Color(0xFFFF7A1A), Color(0xFFE11D2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const overtime = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED), Color(0xFF4C1D95)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: (AppColors.palette.isDark ? Colors.black : const Color(0xFF0F172A)).withValues(alpha: AppColors.palette.isDark ? 0.35 : 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> glow(Color c, {double strength = 0.35}) => [
        BoxShadow(color: c.withValues(alpha: strength), blurRadius: 24, offset: const Offset(0, 10)),
      ];
}

class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);

  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const spring = Curves.easeOutBack;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => build(AppPalette.light);

  static ThemeData build(AppPalette p) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        primary: p.primary,
        surface: p.surface,
        brightness: p.brightness,
      ),
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.surface,
      dividerColor: p.line,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: p.text,
      displayColor: p.text,
    );

    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

    return base.copyWith(
      textTheme: textTheme,
      iconTheme: IconThemeData(color: p.textMuted),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(allowEnterRouteSnapshotting: true),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.text,
        iconTheme: IconThemeData(color: p.text),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4, color: p.text),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: p.textFaint, fontSize: 13),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        border: border(p.line),
        enabledBorder: border(p.line),
        focusedBorder: border(p.primary, 1.6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      datePickerTheme: DatePickerThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
      listTileTheme: ListTileThemeData(textColor: p.text, iconColor: p.textMuted),
    );
  }
}
