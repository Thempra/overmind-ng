import 'dart:math' as math;

import '../eeg/eeg_data.dart';

/// Filtro EMA + histéresis + criterio sostenido sobre las señales eSense.
///
/// MindWave entrega atención/meditación a ~1 Hz con rampas de 3-8 s y picos
/// de ruido. Los juegos nunca deben premiar un cruce instantáneo: todo paso
/// por aquí (EMA α=0.3 ≈ ventana de 2-3 s, luego histéresis y sostenimiento).
class SignalProcessor {
  SignalProcessor({this.emaAlpha = 0.3});

  final double emaAlpha;

  double _att = 0, _med = 0;
  bool _started = false;

  final attZone = Hysteresis();
  final medZone = Hysteresis();

  double _lastBlinkAt = -10;
  int _lastBlinkSeq = 0;

  double get attention => _att;
  double get meditation => _med;

  /// Alimenta con la última lectura del dispositivo. `t` = reloj del juego (s).
  void sample(EegData? eeg, double t) {
    final a = (eeg?.attention ?? 0).toDouble();
    final m = (eeg?.meditation ?? 0).toDouble();
    if (!_started) {
      _att = a;
      _med = m;
      _started = true;
    } else {
      _att += emaAlpha * (a - _att);
      _med += emaAlpha * (m - _med);
    }
    // Blink: solo eventos NUEVOS con debounce ~900 ms (refractario humano).
    if (eeg != null && eeg.blinkSeq != _lastBlinkSeq) {
      _lastBlinkSeq = eeg.blinkSeq;
      if (t - _lastBlinkAt > 0.9) _lastBlinkAt = t;
    }
  }

  /// True durante ~250 ms tras un parpadeo nuevo (un solo disparo por blink).
  bool blinkPulse(double t) => t - _lastBlinkAt < 0.25;

  /// True en el instante del parpadeo (se consume).
  bool takeBlink(double t) {
    if (t - _lastBlinkAt < 0.25) {
      _lastBlinkAt = -10;
      return true;
    }
    return false;
  }

  static double ema(double prev, double next, [double a = 0.1]) =>
      prev + a * (next - prev);
}

/// Calibrador: 5 s de reposo/consignas para conocer el baseline del jugador.
class Calibrator {
  final List<double> attention = [];
  final List<double> meditation = [];

  void add(double att, double med) {
    attention.add(att);
    meditation.add(med);
  }

  double mean(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  double std(List<double> v) {
    if (v.length < 2) return 6;
    final m = mean(v);
    final varr =
        v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (v.length - 1);
    return math.sqrt(varr);
  }

  double get attMean => mean(attention);
  double get attStd => std(attention).clamp(4.0, 20.0);
  double get medMean => mean(meditation);
  double get medStd => std(meditation).clamp(4.0, 20.0);

  double get attPeak =>
      attention.isEmpty ? 60 : attention.reduce(math.max).clamp(30.0, 95.0);
  double get medPeak =>
      meditation.isEmpty ? 60 : meditation.reduce(math.max).clamp(30.0, 95.0);
}

/// Umbral adaptativo (DDA por flow): arranca en baseline+1σ; si la tasa de
/// éxito mantenida cae por debajo de 40% baja el listón; por encima de 75%
/// lo sube. Actualización cada ~10 s, pasitos de 4 puntos.
class AdaptiveThreshold {
  AdaptiveThreshold(this.value);
  double value;
  double _successMs = 0;
  double _totalMs = 0;

  void tick(double dt, bool inZone, {double min = 25, double max = 90}) {
    _totalMs += dt;
    if (inZone) _successMs += dt;
    if (_totalMs >= 10) {
      final rate = _successMs / _totalMs;
      if (rate < 0.4) value = math.max(min, value - 4);
      if (rate > 0.75) value = math.min(max, value + 4);
      _successMs = 0;
      _totalMs = 0;
    }
  }
}

/// Estado de histéresis por umbral: entra con `on`, sale con `off`.
class Hysteresis {
  bool _on = false;
  bool feed(double value, double on, double off) {
    if (_on && value < off) _on = false;
    if (!_on && value > on) _on = true;
    return _on;
  }
}
