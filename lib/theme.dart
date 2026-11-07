import 'package:flutter/material.dart';

/// Colours follow design.md: black and white base, blue for actions and the running set,
/// yellow = set paused, red = rest timer and delete/error, green = done/saved,
/// orange = upcoming/needs attention. Never purple or pink.
class AppColors {
  const AppColors({
    required this.text,
    required this.background,
    required this.element,
    required this.selected,
    required this.textSecondary,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.paused,
  });

  final Color text, background, element, selected, textSecondary, border;
  final Color primary, onPrimary, success, warning, danger;

  /// A stopped set waiting to be saved or continued.
  final Color paused;

  /// The rest timer (design.md: red).
  Color get rest => danger;

  static const light = AppColors(
    text: Color(0xFF000000),
    background: Color(0xFFFFFFFF),
    element: Color(0xFFF0F0F3),
    selected: Color(0xFFE0E1E6),
    textSecondary: Color(0xFF60646C),
    border: Color(0xFFD9DADF),
    primary: Color(0xFF1E6FD9),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF1F9D55),
    warning: Color(0xFFE8710A),
    danger: Color(0xFFD93025),
    paused: Color(0xFFD4A000),
  );

  static const dark = AppColors(
    text: Color(0xFFFFFFFF),
    background: Color(0xFF000000),
    element: Color(0xFF1A1B1E),
    selected: Color(0xFF2E3135),
    textSecondary: Color(0xFFB0B4BA),
    border: Color(0xFF2E3135),
    primary: Color(0xFF4C9AFF),
    onPrimary: Color(0xFF000000),
    success: Color(0xFF34C759),
    warning: Color(0xFFFF9F0A),
    danger: Color(0xFFFF453A),
    paused: Color(0xFFFFD60A),
  );

  static AppColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(AppColors c, Brightness brightness) {
  final radius = BorderRadius.circular(12);
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      error: c.danger,
      onError: const Color(0xFFFFFFFF),
      surface: c.background,
      onSurface: c.text,
      surfaceContainerHighest: c.element,
      outline: c.border,
    ),
    scaffoldBackgroundColor: c.background,
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: c.background, indicatorColor: c.selected),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: c.border),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.element,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 0.5),
  );
}
