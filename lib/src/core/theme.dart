import 'package:flutter/material.dart';

ThemeData buildClawTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4ED6B3),
    brightness: brightness,
    primary: const Color(0xFF4ED6B3),
    secondary: const Color(0xFF6CB6FF),
    surface: isDark ? const Color(0xFF11161D) : const Color(0xFFF4F7FA),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF090C12)
        : const Color(0xFFE8EEF5),
    canvasColor: Colors.transparent,
    cardTheme: CardThemeData(
      color: isDark
          ? const Color(0xFF111A24).withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFCAD8E6),
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark
          ? const Color(0xFF0E141C)
          : Colors.white.withValues(alpha: 0.9),
      indicatorColor: colorScheme.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? const Color(0xFF151C25)
          : Colors.white.withValues(alpha: 0.92),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFD5E0EA),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    ),
  );
}
