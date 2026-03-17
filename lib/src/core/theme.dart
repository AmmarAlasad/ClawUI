import 'package:flutter/material.dart';

ThemeData buildClawTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  const Color openClawAccent = Color(0xFFFF5A52);
  const Color openClawAccentSoft = Color(0xFFF3A28F);
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: openClawAccent,
    brightness: brightness,
    primary: openClawAccent,
    secondary: openClawAccentSoft,
    surface: isDark ? const Color(0xFF12141B) : const Color(0xFFF5F4F6),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF0D0F14)
        : const Color(0xFFF5F4F6),
    canvasColor: Colors.transparent,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: isDark
          ? const Color(0xFF171A22).withValues(alpha: 0.98)
          : const Color(0xFFFCFBFC).withValues(alpha: 0.98),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF2A2E38)
              : const Color(0xFFE8E1DE),
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark
          ? const Color(0xFF141720)
          : Colors.white.withValues(alpha: 0.95),
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
          ? const Color(0xFF181B24)
          : const Color(0xFFFCFBFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: isDark
              ? const Color(0xFF2A2E38)
              : const Color(0xFFE6DEDA),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
      selectedColor: colorScheme.primary.withValues(alpha: 0.18),
      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.18)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF171A22) : const Color(0xFFFCFBFC),
      contentTextStyle: TextStyle(color: colorScheme.onSurface),
    ),
    dividerColor: isDark ? const Color(0xFF262A34) : const Color(0xFFE5E0DD),
  );
}
