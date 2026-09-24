import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/ble/mind_source.dart';

void main() {
  group('SimulatedMindSource', () {
    test('connect genera capturas EEG periódicas y emite por el stream', () {
      fakeAsync((async) {
        final src = SimulatedMindSource(seed: 42);
        final got = <String>[];
        src.stream.listen((e) => got.add('${e.attention}/${e.meditation}'));
        src.connect();
        async.elapse(const Duration(seconds: 5));
        expect(got.length, greaterThanOrEqualTo(5)); // ~1 cada 900 ms
        expect(src.eeg.attention, inInclusiveRange(5, 95));
        expect(src.eeg.meditation, inInclusiveRange(5, 95));
        // bandas normalizadas siempre dentro de 0..100
        for (final v in src.eeg.bands.values) {
          expect(v, inInclusiveRange(0, 100));
        }
        src.dispose();
      });
    });

    test('connect dos veces no duplica el timer', () {
      fakeAsync((async) {
        final src = SimulatedMindSource(seed: 7);
        var n = 0;
        src.stream.listen((_) => n++);
        src.connect();
        src.connect();
        async.elapse(const Duration(seconds: 2));
        expect(n, lessThanOrEqualTo(3)); // no x2
        src.dispose();
      });
    });

    test('disconnect para la emisión; dispose la cierra para siempre', () {
      fakeAsync((async) {
        final src = SimulatedMindSource(seed: 1);
        var n = 0;
        src.stream.listen((_) => n++);
        src.connect();
        async.elapse(const Duration(seconds: 2));
        final afterConnect = n;
        expect(afterConnect, greaterThan(0));
        src.disconnect();
        async.elapse(const Duration(seconds: 3));
        expect(n, afterConnect);
        src.dispose();
        async.elapse(const Duration(seconds: 3));
        expect(n, afterConnect);
      });
    });

    test('id/name/slot del contrato', () {
      final src = SimulatedMindSource(slot: 3);
      expect(src.id, 'sim:3');
      expect(src.name, 'Simulated Mind');
      expect(src.eeg, isNotNull);
    });

    test('paseo aleatorio se mantiene en rango largo plazo', () {
      fakeAsync((async) {
        final src = SimulatedMindSource(seed: 99);
        src.connect();
        async.elapse(const Duration(minutes: 10));
        expect(src.eeg.attention, inInclusiveRange(5, 95));
        expect(src.eeg.meditation, inInclusiveRange(5, 95));
        src.dispose();
      });
    });
  });
}
