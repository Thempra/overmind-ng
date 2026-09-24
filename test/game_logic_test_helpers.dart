// Helpers compartidos por las suites de lógica de juegos.
import 'package:overmind/src/eeg/eeg_data.dart';
import 'package:overmind/src/game/signal_processor.dart';

EegData eegWith({int att = 50, int med = 50, int blink = 0}) {
  final e = EegData(address: 'a', name: 'n', slot: 0);
  e.applyCapture(
    signal: 0,
    attention: att,
    meditation: med,
    rawDelta: 100,
    rawTheta: 80,
    rawLowAlpha: 64,
    rawHighAlpha: 48,
    rawLowBeta: 32,
    rawHighBeta: 16,
    rawLowGamma: 10,
    rawHighGamma: 5,
    blinkStrength: blink,
  );
  return e;
}

void blinkNow(EegData e) {
  e.applyCapture(
    signal: 0,
    attention: e.attention,
    meditation: e.meditation,
    rawDelta: 100,
    rawTheta: 80,
    rawLowAlpha: 64,
    rawHighAlpha: 48,
    rawLowBeta: 32,
    rawHighBeta: 16,
    rawLowGamma: 10,
    rawHighGamma: 5,
    blinkDetected: true,
  );
}

Calibrator calBaseline() => Calibrator()
  ..add(50, 50)
  ..add(52, 48)
  ..add(48, 52);
