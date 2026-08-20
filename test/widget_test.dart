import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/eeg/eeg_data.dart';
import 'package:overmind/src/state/eeg_store.dart';

void main() {
  group('EegData', () {
    test('applyCapture actualiza poder y ondas normalizadas', () {
      final eeg = EegData(address: 'a', name: 'n', slot: 0);
      eeg.applyCapture(
        signal: 0,
        attention: 80,
        meditation: 50,
        rawDelta: 100,
        rawTheta: 80,
        rawLowAlpha: 64,
        rawHighAlpha: 48,
        rawLowBeta: 32,
        rawHighBeta: 16,
        rawLowGamma: 10,
        rawHighGamma: 5,
      );
      expect(eeg.attention, 80);
      expect(eeg.meditation, 50);
      expect(eeg.power, 65); // (80+50)/2
      expect(eeg.delta, greaterThan(0));
      expect(eeg.delta, lessThanOrEqualTo(100));
    });

    test('sin señal (poor signal 200) resetea los valores', () {
      final eeg = EegData(address: 'a', name: 'n', slot: 0);
      eeg.applyCapture(
        signal: 200,
        attention: 90,
        meditation: 90,
        rawDelta: 100,
        rawTheta: 80,
        rawLowAlpha: 64,
        rawHighAlpha: 48,
        rawLowBeta: 32,
        rawHighBeta: 16,
        rawLowGamma: 10,
        rawHighGamma: 5,
      );
      expect(eeg.attention, 0);
      expect(eeg.meditation, 0);
    });
  });

  group('EegStore', () {
    test('gestiona slots y dispositivos simulados', () async {
      final store = EegStore();
      expect(store.nextFreeSlot, 0);
      store.addSimulated();
      expect(store.connected, hasLength(1));
      expect(store.nextFreeSlot, 1);
      store.addSimulated();
      expect(store.connected, hasLength(2));
      expect(store.nextFreeSlot, 2);
      await store.removeAt(0);
      expect(store.connected, hasLength(1));
      expect(store.nextFreeSlot, 0);
    });
  });
}
