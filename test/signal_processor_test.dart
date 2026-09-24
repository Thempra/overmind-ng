import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/eeg/eeg_data.dart';
import 'package:overmind/src/game/signal_processor.dart';

EegData eegWith({int att = 0, int med = 0, int blink = 0}) {
  final e = EegData(address: 'a', name: 'n', slot: 0);
  if (att != 0 || med != 0 || blink != 0) {
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
  }
  return e;
}

void main() {
  group('SignalProcessor', () {
    test('primera muestra inicializa EMA, luego suaviza', () {
      final p = SignalProcessor(emaAlpha: 0.5);
      p.sample(eegWith(att: 80, med: 40), 0);
      expect(p.attention, 80);
      expect(p.meditation, 40);
      p.sample(eegWith(att: 60, med: 60), 1);
      expect(p.attention, 70); // 80 + 0.5*(60-80)
      expect(p.meditation, 50);
    });

    test('muestra null cuenta como 0', () {
      final p = SignalProcessor(emaAlpha: 1);
      p.sample(null, 0);
      expect(p.attention, 0);
      expect(p.meditation, 0);
    });

    test('blink: pulso de 250ms, refractario de 900ms, un solo disparo', () {
      final p = SignalProcessor();
      final e = eegWith();
      // parpadeo nuevo en t=1
      e.applyCapture(
        signal: 0, attention: 1, meditation: 1,
        rawDelta: 1, rawTheta: 1, rawLowAlpha: 1, rawHighAlpha: 1,
        rawLowBeta: 1, rawHighBeta: 1, rawLowGamma: 1, rawHighGamma: 1,
        blinkDetected: true,
      );
      p.sample(e, 1);
      expect(p.blinkPulse(1.1), isTrue);
      expect(p.takeBlink(1.2), isTrue);
      expect(p.takeBlink(1.3), isFalse); // ya consumido
      // mismo blinkSeq no re-dispara
      p.sample(e, 2.5);
      expect(p.blinkPulse(2.6), isFalse);
      // blink nuevo pero dentro del refractario (<900ms) se ignora
      e.applyCapture(
        signal: 0, attention: 1, meditation: 1,
        rawDelta: 1, rawTheta: 1, rawLowAlpha: 1, rawHighAlpha: 1,
        rawLowBeta: 1, rawHighBeta: 1, rawLowGamma: 1, rawHighGamma: 1,
        blinkDetected: true,
      );
      p.sample(e, 2.6); // seq nuevo, solo 1.4s tras el anterior... >0.9 -> vale
      expect(p.blinkPulse(2.7), isTrue);
    });

    test('blink dentro del periodo refractario no actualiza', () {
      final p = SignalProcessor();
      final e = eegWith();
      void blink(double t) => e.applyCapture(
        signal: 0, attention: 1, meditation: 1,
        rawDelta: 1, rawTheta: 1, rawLowAlpha: 1, rawHighAlpha: 1,
        rawLowBeta: 1, rawHighBeta: 1, rawLowGamma: 1, rawHighGamma: 1,
        blinkDetected: true,
      );
      blink(1);
      p.sample(e, 1);
      blink(1.2); // seq nuevo, solo 0.2s después -> descartado
      p.sample(e, 1.2);
      expect(p.blinkPulse(1.1), isTrue); // sigue siendo el de t=1
      expect(p.blinkPulse(1.15), isTrue);
      expect(p.blinkPulse(2.5), isFalse);
    });

    test('ema estático', () {
      expect(SignalProcessor.ema(0, 10, 0.1), closeTo(1, 1e-9));
      expect(SignalProcessor.ema(10, 20), closeTo(11, 1e-9)); // a por defecto
    });
  });

  group('Calibrator', () {
    test('vacío: medias 0, picos 60, desviación mínima', () {
      final c = Calibrator();
      expect(c.attMean, 0);
      expect(c.attStd, 6); // length<2 -> 6, clamp(4,20)
      expect(c.attPeak, 60);
      expect(c.medPeak, 60);
    });

    test('calcula media, std y picos con clamp', () {
      final c = Calibrator();
      c.add(50, 70);
      c.add(60, 50);
      c.add(70, 30);
      expect(c.attMean, closeTo(60, 1e-9));
      expect(c.medMean, closeTo(50, 1e-9));
      expect(c.attStd, closeTo(10, 1e-9));
      expect(c.attPeak, 70);
      // picos clampeados a 30..95
      final c2 = Calibrator()..add(120, 5);
      expect(c2.attPeak, 95);
      expect(c2.medPeak, 30);
      // std clampeada a min 4
      final c3 = Calibrator()
        ..add(50, 50)
        ..add(50.1, 50);
      expect(c3.attStd, 4);
    });
  });

  group('AdaptiveThreshold', () {
    test('baja el umbral si la tasa de éxito < 40%', () {
      final t = AdaptiveThreshold(50);
      for (var i = 0; i < 110; i++) {
        t.tick(0.1, false); // 0% éxito; >10 s (acumulación float)
      }
      expect(t.value, 46);
    });

    test('sube el umbral si la tasa de éxito > 75%', () {
      final t = AdaptiveThreshold(50);
      for (var i = 0; i < 200; i++) {
        t.tick(0.1, i < 190); // 95% éxito en cada ventana de 10 s
      }
      // sube +4 por ventana: 50 -> 90 (clamp en max=90)
      expect(t.value, greaterThan(50));
    });

    test('respeta min y max', () {
      final t = AdaptiveThreshold(27);
      for (var r = 0; r < 5; r++) {
        for (var i = 0; i < 100; i++) {
          t.tick(0.1, false, min: 25);
        }
      }
      expect(t.value, 25);
      final h = AdaptiveThreshold(88);
      for (var r = 0; r < 5; r++) {
        for (var i = 0; i < 100; i++) {
          h.tick(0.1, true, max: 90);
        }
      }
      expect(h.value, 90);
    });

    test('zona neutra (40-75%) no mueve el umbral', () {
      final t = AdaptiveThreshold(50);
      for (var i = 0; i < 100; i++) {
        t.tick(0.1, i % 2 == 0); // 50%
      }
      expect(t.value, 50);
    });
  });

  group('Hysteresis', () {
    test('entra con on, se mantiene entre off y on, sale bajo off', () {
      final h = Hysteresis();
      expect(h.feed(55, 60, 50), isFalse);
      expect(h.feed(65, 60, 50), isTrue); // entra
      expect(h.feed(55, 60, 50), isTrue); // zona de mantener
      expect(h.feed(45, 60, 50), isFalse); // sale
    });
  });
}
