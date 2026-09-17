import 'package:flutter/material.dart';

ThemeData buildCadTheme() {
  const seed = Color(0xFF1E88E5);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark, surface: const Color(0xFF1B1F24));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF14171B),
    canvasColor: const Color(0xFF1B1F24),
    visualDensity: VisualDensity.compact,
    dividerColor: const Color(0xFF2B3138),
    textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 12.5), bodySmall: TextStyle(fontSize: 11.5), labelLarge: TextStyle(fontSize: 12.5)),
    inputDecorationTheme: const InputDecorationTheme(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
    dataTableTheme: const DataTableThemeData(headingRowHeight: 30, dataRowMinHeight: 26, dataRowMaxHeight: 30, columnSpacing: 16, horizontalMargin: 8),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
    menuTheme: const MenuThemeData(style: MenuStyle(visualDensity: VisualDensity.compact)),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1F2429)),
  );
}

class CadColors {
  static const background = Color(0xFF14171B);
  static const gridMinor = Color(0xFF20262D);
  static const gridMajor = Color(0xFF2B333C);
  static const axis = Color(0xFF3B4650);
  static const selection = Color(0xFFFFD54F);
  static const hover = Color(0xFF80DEEA);
  static const snap = Color(0xFF69F0AE);
  static const preview = Color(0xFFB0BEC5);
  static const unconnected = Color(0xFFFF1744);
  static const warning = Color(0xFFFFA726);
  static const ok = Color(0xFF66BB6A);
}
