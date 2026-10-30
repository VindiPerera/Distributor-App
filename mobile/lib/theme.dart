import 'package:flutter/material.dart';

/// Matches the admin web portal's palette: white surfaces, deep green accent.
class AppColors {
  static const accent = Color(0xFF0B8F5F);
  static const accentHover = Color(0xFF087A52);
  static const accentDark = Color(0xFF056041);
  static const accentLight = Color(0xFF34C58A);
  static const accentSoft = Color(0xFFE5F6EE);

  /// Soft mint page background so white cards stand out.
  static const background = Color(0xFFF4FAF7);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accent, accentDark],
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: accentDark.withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static const ink = Color(0xFF1C2321);
  static const inkSoft = Color(0xFF4B5450);
  static const paper = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE1ECE6);
  static const lineSoft = Color(0xFFF1F6F3);

  static const good = Color(0xFF2E7D4F);
  static const goodSoft = Color(0xFFE7F4EB);
  static const warn = Color(0xFFB8792A);
  static const warnSoft = Color(0xFFFBF0E0);
  static const critical = Color(0xFFC23B3B);
  static const criticalSoft = Color(0xFFFBE9E9);
}

/// Field label with a trailing red asterisk, for use as an [InputDecoration.label]
/// on required form fields (mirrors the admin web portal's `x-input-label :required`).
class RequiredLabel extends StatelessWidget {
  final String text;

  const RequiredLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.critical),
          ),
        ],
      ),
    );
  }
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    error: AppColors.critical,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: AppColors.ink),
      bodyMedium: TextStyle(color: AppColors.ink),
      bodySmall: TextStyle(color: AppColors.inkSoft),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.critical, width: 1.2),
      ),
      labelStyle: const TextStyle(color: AppColors.inkSoft),
      hintStyle: const TextStyle(color: AppColors.inkSoft),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    iconTheme: const IconThemeData(color: AppColors.inkSoft),

    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.inkSoft,
        selectedBackgroundColor: AppColors.accent,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.inkSoft,
      textColor: AppColors.ink,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
  );
}
