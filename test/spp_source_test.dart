import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/ble/neurosky_ble.dart';
import 'package:overmind/src/ble/spp_mind_source.dart';
import 'package:overmind/src/eeg/eeg_data.dart';

/// Helper: paquete ThinkGear válido [0xAA, 0xAA, PLENGTH, payload, checksum].
Uint8List buildPacket(List<int> payload) {
  var sum = 0;
  for (final b in payload) {
    sum += b;
  }
  return Uint8List.fromList(
    [0xAA, 0xAA, payload.length, ...payload, (0x100 - (sum & 0xFF)) & 0xFF],
  );
}

class FakeSppClient extends SppClient {
  FakeSppClient() : super();
  final bytesCtl = StreamController<Uint8List>.broadcast();
  final closedCtl = StreamController<void>.broadcast();
  bool connectCalled = false;
  bool disconnectCalled = false;

  @override
  Future<void> connect(String address) async => connectCalled = true;

  @override
  Future<void> disconnect(String address) async => disconnectCalled = true;

  @override
  Stream<Uint8List> bytes(String address) => bytesCtl.stream;

  @override
  Stream<void> closed(String address) => closedCtl.stream;
}

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

  group('SppMindSource', () {
    test('connect alimenta el parser y emite capturas por el stream', () async {
      final fake = FakeSppClient();
      final src = SppMindSource(
        address: '00:11:22:33:44:55',
        deviceName: 'ThempraEEG',
        slot: 2,
        client: fake,
      );
      final emitted = <EegData>[];
      final sub = src.stream.listen(emitted.add);
      await src.connect();

      expect(fake.connectCalled, isTrue);
      expect(src.id, '00:11:22:33:44:55');
      expect(src.name, 'ThempraEEG');
      expect(src.eeg.slot, 2);
      expect(src.eeg.address, '00:11:22:33:44:55');

      fake.bytesCtl.add(buildPacket([
        0x02, 0x01, 0x00,
        0x04, 0x01, 0x50,
        0x05, 0x01, 0x32,
      ]));
      await Future<void>.delayed(Duration.zero);

      expect(src.eeg.attention, 80);
      expect(src.eeg.meditation, 50);
      expect(emitted, isNotEmpty);

      await sub.cancel();
      await src.disconnect();
    });

    test('disconnect cancela suscripciones y avisa al cliente', () async {
      final fake = FakeSppClient();
      final src = SppMindSource(
        address: 'AA',
        deviceName: 'X',
        slot: 0,
        client: fake,
      );
      await src.connect();
      await src.disconnect();
      expect(fake.disconnectCalled, isTrue);
    });

    test('name cae a la MAC si el nombre llega vacío', () {
      final fake = FakeSppClient();
      final src = SppMindSource(
        address: '00:12:02:10:71:49',
        deviceName: '',
        slot: 0,
        client: fake,
      );
      expect(src.name, '00:12:02:10:71:49');
    });
  });
}
