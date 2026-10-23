import 'dart:ui';

import '../eeg/signal_quality.dart';

/// Geometría y colores del chip de calidad de señal del HUD.
///
/// Se calcula en una función PURA ([layoutSignalChip]) para que los tests
/// puedan comprobar sin Canvas que "desconectado" nunca pinta barras llenas.
/// El HUD solo recorre [bars]/[fills] y dibuja.
class SignalChipLayout {
  const SignalChipLayout({
    required this.chipRect,
    required this.bars,
    required this.fills,
    required this.label,
    required this.labelPosition,
    required this.quality,
    required this.isDemo,
  });

  /// Fondo del chip (rectángulo redondeado).
  final Rect chipRect;

  /// Rectángulos de las 4 barras (de menor a mayor altura).
  final List<Rect> bars;

  /// Color de cada barra; `null` = barra vacía (no encendida).
  final List<Color?> fills;

  /// Etiqueta corta ("SIN SEÑAL", "DEMO", "EUR"…).
  final String label;
  final Offset labelPosition;

  final SignalQuality quality;
  final bool isDemo;

  /// Nº de barras encendidas (0-4). Para tests y para el render.
  int get filledBars => fills.where((c) => c != null).length;

  /// `true` si el chip representa "sin contacto / sin datos".
  bool get showsDisconnected => !quality.hasContact;
}

/// Colores del chip de señal.
class SignalChipColors {
  static const good = Color(0xFF3BE07A);
  static const fair = Color(0xFFB8E04A);
  static const poor = Color(0xFFFFB300);
  static const weak = Color(0xFFE05A3B);
  static const empty = Color(0x33FFFFFF);
  static const demo = Color(0xFF9E9E9E);
  static const background = Color(0x99000000);
  static const outline = Color(0x55FFFFFF);
}

/// Ancho del chip a escala 1 (4 barras + etiqueta).
const double kSignalChipWidth = 150;

/// Alto del chip a escala 1.
const double kSignalChipHeight = 22;

/// Reparte las barras de `[quality]` sobre una caja de [width] px.
///
/// [origin] es la esquina superior izquierda del chip; con [alignRight] el chip
/// se ancla por su borde derecho (útil para el jugador de la derecha).
///
/// Reglas duras (el bug que arreglamos):
///  * `unknown`/`offline` ⇒ **cero** barras encendidas, siempre.
///  * `demo` ⇒ etiqueta `DEMO` y color gris, aunque la señal sea perfecta.
SignalChipLayout layoutSignalChip({
  required SignalQuality quality,
  required Offset origin,
  double scale = 1,
  bool isDemo = false,
  bool alignRight = false,
  String? disconnectedLabel,
  String? demoLabel,
}) {
  final s = scale <= 0 ? 1.0 : scale;
  final w = kSignalChipWidth * s;
  final h = kSignalChipHeight * s;
  final left = alignRight ? origin.dx - w : origin.dx;
  final chipRect = Rect.fromLTWH(left, origin.dy, w, h);

  // 4 barras de anchura fija con hueco decreciente, todas ancladas abajo.
  final barW = 7.0 * s;
  final gap = 3.0 * s;
  final pad = 5.0 * s;
  final maxBarH = h - pad * 2;
  final bars = <Rect>[];
  for (var i = 0; i < 4; i++) {
    final bh = maxBarH * (0.35 + 0.2167 * i); // 35 %, 57 %, 78 %, 100 %
    final x = left + pad + i * (barW + gap);
    bars.add(Rect.fromLTWH(x, origin.dy + h - pad - bh, barW, bh));
  }

  final lit = isDemo ? 0 : quality.bars;
  final color = isDemo
      ? SignalChipColors.demo
      : switch (quality) {
          SignalQuality.good => SignalChipColors.good,
          SignalQuality.fair => SignalChipColors.fair,
          SignalQuality.poor => SignalChipColors.poor,
          SignalQuality.weak => SignalChipColors.weak,
          SignalQuality.offline => SignalChipColors.weak,
          SignalQuality.unknown => SignalChipColors.weak,
        };

  final fills = List<Color?>.generate(
    4,
    (i) => i < lit ? color : null,
    growable: false,
  );

  final String label;
  if (isDemo) {
    label = demoLabel ?? 'DEMO';
  } else if (quality == SignalQuality.unknown) {
    label = disconnectedLabel ?? '—';
  } else if (quality == SignalQuality.offline) {
    label = disconnectedLabel ?? 'SIN SEÑAL';
  } else {
    label = '${(quality.bars * 25)}%';
  }

  return SignalChipLayout(
    chipRect: chipRect,
    bars: bars,
    fills: fills,
    label: label,
    labelPosition:
        Offset(left + pad + 4 * (barW + gap) + 2 * s, origin.dy + h * 0.16),
    quality: quality,
    isDemo: isDemo,
  );
}
