import 'package:flutter/foundation.dart';

/// Datos EEG de un dispositivo MindWave (NeuroSky ThinkGear).
///
/// Port directo del modelo [Eeg] del proyecto Android original
/// (overmind/src/net/thempra/overmind/Eeg.java), ampliado con valores
/// crudos de banda y la normalización porcentual que usaba el original.
class EegData extends ChangeNotifier {
  EegData({
    required this.address,
    required this.name,
    required this.slot,
  });

  String address;
  String name;
  int slot;

  /// Calidad de señal: 0 = buena, 200 = sin señal (Poor Signal de ThinkGear).
  int signal = 0;

  int attention = 0;
  int meditation = 0;

  /// Parpadeo: fuerza 0-100 del ultimo blink y flag del ASIC. El juego lo
  /// consume via `takeBlink()` para no procesar el mismo parpadeo dos veces.
  int blinkStrength = 0;
  bool blinkDetected = false;
  int _blinkSeq = 0;

  // Valores crudos (ASIC_EEG_POWER) por banda.
  double rawDelta = 0;
  double rawTheta = 0;
  double rawLowAlpha = 0;
  double rawHighAlpha = 0;
  double rawLowBeta = 0;
  double rawHighBeta = 0;
  double rawLowGamma = 0;
  double rawHighGamma = 0;

  /// Normalización original del proyecto Android:
  /// prodelta = (1/rawdelta) * 1_000_000   y luego  * 100 / 1800.
  double _proc(double raw) {
    if (raw <= 0) return 0;
    final p = (1 / raw) * 1000000;
    final v = (p * 100) / 1800;
    return v.clamp(0.0, 100.0);
  }

  double get delta => _proc(rawDelta);
  double get theta => _proc(rawTheta);
  double get lalpha => _proc(rawLowAlpha);
  double get halpha => _proc(rawHighAlpha);
  double get lbeta => _proc(rawLowBeta);
  double get hbeta => _proc(rawHighBeta);
  double get lgamma => _proc(rawLowGamma);
  double get hgamma => _proc(rawHighGamma);

  /// Aplica una nueva captura (versión corregida del parser ThinkGear).
  void applyCapture({
    required int signal,
    required int attention,
    required int meditation,
    required double rawDelta,
    required double rawTheta,
    required double rawLowAlpha,
    required double rawHighAlpha,
    required double rawLowBeta,
    required double rawHighBeta,
    required double rawLowGamma,
    required double rawHighGamma,
    int blinkStrength = 0,
    bool blinkDetected = false,
  }) {
    // El original solo actualizaba si la señal era "buena" (signal > 0,
    // porque en aquel formato signal = 200 - poorSignal). Aquí tratamos
    // poorSignal directamente: si es mala, seguimos mostrando nuevos datos
    // pero con señal marcada; mantenemos el comportamiento de cero cuando
    // no hay señal real (poorSignal >= 200).
    this.signal = signal;
    if (signal >= 200) {
      reset();
      return;
    }
    this.attention = attention;
    this.meditation = meditation;
    this.blinkStrength = blinkStrength;
    this.rawDelta = rawDelta;
    this.rawTheta = rawTheta;
    this.rawLowAlpha = rawLowAlpha;
    this.rawHighAlpha = rawHighAlpha;
    this.rawLowBeta = rawLowBeta;
    this.rawHighBeta = rawHighBeta;
    this.rawLowGamma = rawLowGamma;
    this.rawHighGamma = rawHighGamma;
    if (blinkDetected || blinkStrength > 30) {
      this.blinkDetected = true;
      _blinkSeq++;
      _blinkPending = true;
    } else {
      this.blinkDetected = false;
    }
    notifyListeners();
  }

  /// Secuencia que incrementa solo cuando hay un parpadeo NUEVO.
  int get blinkSeq => _blinkSeq;

  /// Consume el parpadeo pendiente: true una sola vez por parpadeo.
  bool takeBlink() {
    if (!_blinkPending) return false;
    _blinkPending = false;
    return true;
  }

  bool _blinkPending = false;

  void reset() {
    signal = 0;
    attention = 0;
    meditation = 0;
    blinkStrength = 0;
    blinkDetected = false;
    rawDelta = rawTheta = rawLowAlpha = rawHighAlpha = 0;
    rawLowBeta = rawHighBeta = rawLowGamma = rawHighGamma = 0;
    notifyListeners();
  }

  /// Poder del jugador usado por el juego: (atención + meditación) / 2.
  int get power => (attention + meditation) ~/ 2;

  Map<String, double> get bands => {
        'Signal': signal.toDouble(),
        'Attention': attention.toDouble(),
        'Meditation': meditation.toDouble(),
        'Blink': blinkStrength.toDouble(),
        'Delta': delta,
        'Theta': theta,
        'Low Alpha': lalpha,
        'High Alpha': halpha,
        'Low Beta': lbeta,
        'High Beta': hbeta,
        'Low Gamma': lgamma,
        'High Gamma': hgamma,
      };
}
