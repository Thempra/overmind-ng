import 'dart:async';
import 'dart:math';

import '../eeg/eeg_data.dart';

/// Fuente de datos EEG. Puede ser un dispositivo BLE real (Android/iOS) o la
/// simulación (desktop Linux / demo).
abstract class MindSource {
  String get id;
  String get name;

  /// El objeto [EegData] que esta fuente muta con cada captura.
  EegData get eeg;

  /// Stream de datos EEG. Emite cuando hay datos nuevos.
  Stream<EegData> get stream;

  Future<void> connect();
  Future<void> disconnect();
}

/// Fuente simulada: genera valores EEG plausibles con un paseo aleatorio
/// suave, útil en desktop Linux (sin hardware BLE) y como modo demo.
/// Porta el "DEMO PLAY" comentado del original (getValueForDemoMode).
class SimulatedMindSource extends MindSource {
  SimulatedMindSource({this.slot = 0, this.seed})
      : _rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  final int slot;
  final int? seed;
  final Random _rng;
  final _controller = StreamController<EegData>.broadcast();
  Timer? _timer;
  double _attention = 50;
  double _meditation = 50;
  bool _disposed = false;

  final _eeg = EegData(address: 'sim:0', name: 'Simulated Mind', slot: 0);

  @override
  String get id => 'sim:$slot';

  @override
  String get name => 'Simulated Mind';

  @override
  EegData get eeg => _eeg;

  @override
  Stream<EegData> get stream => _controller.stream;

  double _walk(double current, double min, double max, double step) {
    final delta = (_rng.nextDouble() - 0.5) * 2 * step;
    final next = (current + delta).clamp(min, max);
    return next;
  }

  @override
  Future<void> connect() async {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_disposed) return;
      _attention = _walk(_attention, 5, 95, 12);
      _meditation = _walk(_meditation, 5, 95, 8);

      // Ondas: meditación favorece delta/theta/alpha; atención beta/gamma.
      final delta = _walk(40, 10, 90, 6);
      final theta = _walk(45, 10, 90, 6);
      final lalpha = _walk(45 - _attention * 0.3, 5, 90, 8);
      final balpha = _walk(_attention * 0.5, 5, 90, 8);
      final lbeta = _walk(30 + _attention * 0.3, 5, 95, 8);
      final hbeta = _walk(20 + _attention * 0.4, 5, 95, 8);
      final lgamma = _walk(15 + _attention * 0.25, 5, 90, 8);
      final hgamma = _walk(10 + _attention * 0.2, 5, 90, 8);

      // poorSignal casi siempre bueno, de vez en cuando malo.
      final poorSignal = _rng.nextDouble() < 0.05 ? 120 : 0;

      // Parpadeo simulado: ~1 cada 3-6 s, a veces doble.
      final blink = _rng.nextDouble() < 0.22 ? (40 + _rng.nextInt(60)) : 0;
      _eeg.applyCapture(
        signal: poorSignal,
        attention: _attention.round(),
        meditation: _meditation.round(),
        blinkStrength: blink,
        blinkDetected: blink > 60,
        rawDelta: _invPercent(delta),
        rawTheta: _invPercent(theta),
        rawLowAlpha: _invPercent(lalpha),
        rawHighAlpha: _invPercent(balpha),
        rawLowBeta: _invPercent(lbeta),
        rawHighBeta: _invPercent(hbeta),
        rawLowGamma: _invPercent(lgamma),
        rawHighGamma: _invPercent(hgamma),
      );
      if (!_controller.isClosed) _controller.add(_eeg);
    });
  }

  /// Inversa de la normalización del original: dado el % a mostrar,
  /// devuelve un "raw" que lo reproduzca (solo para simulación).
  double _invPercent(double percent) {
    // p = (1/raw)*1e6 ; v = p*100/1800 = raw -> (1/raw)*1e6*100/1800
    // => raw = (1e8) / (v*1800)
    final v = percent.clamp(1.0, 100.0);
    return (1e8) / (v * 1800);
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
  }
}
