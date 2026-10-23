// Modelo de calidad de señal: el bug que pintaba 4 barras verdes sin contacto.
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/eeg/eeg_data.dart';
import 'package:overmind/src/eeg/signal_quality.dart';

/// Captura con `poorSignal` dado y valores "buenos" para el resto.
void capture(EegData e, {required int poorSignal, int att = 70, int med = 60}) {
  e.applyCapture(
    signal: poorSignal,
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
  );
}

void main() {
  group('SignalQuality: umbrales del HUD (30/80/140/190)', () {
    test('los cortes exactos caen en el nivel esperado', () {
      expect(signalQualityOf(0), SignalQuality.good);
      expect(signalQualityOf(30), SignalQuality.good);
      expect(signalQualityOf(31), SignalQuality.fair);
      expect(signalQualityOf(80), SignalQuality.fair);
      expect(signalQualityOf(81), SignalQuality.poor);
      expect(signalQualityOf(140), SignalQuality.poor);
      expect(signalQualityOf(141), SignalQuality.weak);
      expect(signalQualityOf(190), SignalQuality.weak);
      expect(signalQualityOf(191), SignalQuality.weak);
      expect(signalQualityOf(199), SignalQuality.weak,
          reason: '199 es contacto pésimo, no offline');
      expect(signalQualityOf(200), SignalQuality.offline);
    });

    test('las barras son monótonas y coherentes con el estado', () {
      expect(signalQualityOf(0).bars, 4);
      expect(signalQualityOf(50).bars, 3);
      expect(signalQualityOf(100).bars, 2);
      expect(signalQualityOf(160).bars, 1);
      expect(SignalQuality.offline.bars, 0);
      expect(SignalQuality.unknown.bars, 0,
          reason: 'sin datos NO puede pintar ninguna barra');
    });

    test('hasData=false es unknown, no "señal perfecta"', () {
      // poorSignal 0 sin datos es exactamente lo que pasaba antes: el valor
      // por defecto 0 se interpretaba como señal inmejorable.
      expect(signalQualityOf(0, hasData: false), SignalQuality.unknown);
      expect(signalQualityOf(null, hasData: false), SignalQuality.unknown);
      expect(SignalQuality.unknown.bars, 0);
      expect(SignalQuality.unknown.hasContact, isFalse);
    });

    test('valores raros se tratan como sin contacto (nunca como buena señal)',
        () {
      expect(signalQualityOf(null), SignalQuality.offline);
      expect(signalQualityOf(-1), SignalQuality.offline);
      expect(signalQualityOf(250), SignalQuality.offline);
    });

    test('solo fair/good se consideran usables', () {
      expect(SignalQuality.good.isUsable, isTrue);
      expect(SignalQuality.fair.isUsable, isTrue);
      expect(SignalQuality.poor.isUsable, isFalse);
      expect(SignalQuality.weak.isUsable, isFalse);
      expect(SignalQuality.offline.isUsable, isFalse);
      expect(SignalQuality.unknown.isUsable, isFalse);
    });
  });

  group('EegData: el bug de poorSignal=200 pintado como señal perfecta', () {
    test('un EegData recién creado está unknown, NO señal buena', () {
      final e = EegData(address: 'a', name: 'n', slot: 0);
      expect(e.hasData, isFalse);
      expect(e.signalQuality, SignalQuality.unknown);
      expect(e.signalQuality.bars, 0,
          reason: 'el bug: signal=0 por defecto ⇒ 4 barras verdes');
    });

    test('poorSignal=200 NO se pinta como buena señal', () {
      final e = EegData(address: 'a', name: 'n', slot: 0);
      capture(e, poorSignal: 200, att: 90, med: 90);
      expect(e.hasData, isTrue, reason: 'el paquete llegó: hay enlace');
      expect(e.signal, 200);
      expect(e.signalQuality, SignalQuality.offline);
      expect(e.signalQuality.bars, 0, reason: 'cero barras, no cuatro');
      expect(e.signalQuality.hasContact, isFalse);
    });

    test('reset() deja unknown y conserva poorSignal=200 (no 0)', () {
      final e = EegData(address: 'a', name: 'n', slot: 0);
      capture(e, poorSignal: 0);
      expect(e.signalQuality, SignalQuality.good);
      e.reset();
      expect(e.hasData, isFalse);
      expect(e.signal, kSignalNoContact,
          reason: 'reset ponía signal=0 ⇒ señal perfecta sin contacto');
      expect(e.signalQuality, SignalQuality.unknown);
      expect(e.lastUpdate, isNull);
    });

    test('sin contacto los valores derivados se limpian pero queda constancia',
        () {
      final e = EegData(address: 'a', name: 'n', slot: 0);
      capture(e, poorSignal: 0, att: 80, med: 70);
      expect(e.attention, 80);
      capture(e, poorSignal: 200, att: 90, med: 90);
      expect(e.attention, 0, reason: 'sin contacto no hay lectura válida');
      expect(e.meditation, 0);
      expect(e.power, 0);
      expect(e.signalQuality, SignalQuality.offline);
    });

    test('el paquete de poorSignal=200 cuenta para el watchdog', () {
      final e = EegData(address: 'a', name: 'n', slot: 0);
      capture(e, poorSignal: 0);
      final seq = e.packetSeq;
      capture(e, poorSignal: 200);
      expect(e.packetSeq, seq + 1,
          reason: 'sin contacto sigue habiendo enlace: no es "sin paquetes"');
      expect(e.lastUpdate, isNotNull);
    });

    test('un EEG ruidoso con contacto nunca pasa por "desconectado"', () {
      final e = EegData(address: 'a', name: 'n', slot: 0);
      for (final v in [140, 190, 175, 145, 120, 199, 165]) {
        capture(e, poorSignal: v);
        expect(e.signalQuality, isNot(SignalQuality.offline),
            reason: 'poorSignal $v todavía tiene contacto');
        expect(e.signalQuality, isNot(SignalQuality.unknown));
      }
    });

    test('secondsSinceUpdate usa el reloj inyectado', () {
      var t = DateTime(2026, 1, 1, 12);
      final e = EegData(
        address: 'a',
        name: 'n',
        slot: 0,
        clock: () => t,
      );
      expect(e.secondsSinceUpdate, isNull);
      capture(e, poorSignal: 0);
      expect(e.secondsSinceUpdate, 0);
      t = t.add(const Duration(milliseconds: 2500));
      expect(e.secondsSinceUpdate, closeTo(2.5, 1e-9));
    });
  });
}
