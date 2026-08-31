import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/ble/neurosky_ble.dart';

void main() {
  group('MindDevice', () {
    test('.spp expone id, name e isClassic', () {
      final d = const MindDevice.spp('00:11:22:33:44:55', 'ThempraEEG');
      expect(d.isClassic, isTrue);
      expect(d.id, '00:11:22:33:44:55');
      expect(d.name, 'ThempraEEG');
      expect(d.rssi, 0);
      expect(d.serviceUuids, isEmpty);
      expect(d.bleDevice, isNull);
    });
  });
}
