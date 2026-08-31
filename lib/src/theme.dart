import 'package:flutter/material.dart';

/// Paleta compartida que une el menú con el juego (battle_game.dart).
/// EVA-01 = cian, SACHIEL = rojo; fondo oscuro sci-fi; escudo cian-claro.
abstract final class OvermindColors {
  static const bg = Color(0xFF0A0E16);
  static const bgLighter = Color(0xFF121A2B);
  static const panel = Color(0xFF171F33);
  static const panelBorder = Color(0xFF24304D);

  static const evaCyan = Color(0xFF35B6FF);
  static const sachielRed = Color(0xFFFF4B4B);
  static const shield = Color(0xFFB0F7FF);
  static const yellow = Color(0xFFFFE34D);

  static const text = Color(0xFFE8EEF6);
  static const textDim = Color(0xFF9AA7BF);
}

/// Tema oscuro coherente con la estética del juego.
ThemeData overmindTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: OvermindColors.evaCyan,
    brightness: Brightness.dark,
    surface: OvermindColors.bg,
  ).copyWith(
    primary: OvermindColors.evaCyan,
    secondary: OvermindColors.sachielRed,
    surface: OvermindColors.bg,
    onSurface: OvermindColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: OvermindColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: OvermindColors.text,
    ),
    cardTheme: CardThemeData(
      color: OvermindColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: OvermindColors.panelBorder),
      ),
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: OvermindColors.bgLighter,
        foregroundColor: OvermindColors.text,
        side: const BorderSide(color: OvermindColors.panelBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: OvermindColors.text,
        side: const BorderSide(color: OvermindColors.panelBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
  );
}
