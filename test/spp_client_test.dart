import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/ble/mind_source.dart';
import 'package:overmind/src/ble/neurosky_ble.dart';
import 'package:overmind/src/ble/spp_mind_source.dart';
import 'package:overmind/src/state/eeg_store.dart';

class _ThrowingClient extends SppClient {
  @override
  Future<void> connect(String address) async {
    throw MissingPluginException('no android');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SppClient sobre canales mockeados', () {
    const method = MethodChannel('overmind/spp');
    const events = EventChannel('overmind/spp/bytes');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(method, null);
      messenger.setMockStreamHandler(events, null);
    });

    test('devices() parsea la lista nativa y maneja null', () async {
      messenger.setMockMethodCallHandler(method, (call) async {
        if (call.method == 'getDevices') {
          return [
            {'address': 'AA:BB', 'name': 'ThempraEEG'},
            {'address': 'CC:DD', 'name': 'MindWave'},
          ];
        }
        return null;
      });
      final client = SppClient(method: method, events: events);
      final devs = await client.devices();
      expect(devs, hasLength(2));
      expect(devs.first.address, 'AA:BB');
      expect(devs.first.name, 'ThempraEEG');

      messenger.setMockMethodCallHandler(method, (call) async => null);
      expect(await client.devices(), isEmpty);
    });

    test('connect propaga PlatformException como StateError', () async {
      messenger.setMockMethodCallHandler(method, (call) async {
        if (call.method == 'connect') {
          throw PlatformException(code: 'NO_CONNECT', message: 'refused');
        }
        return null;
      });
      final client = SppClient(method: method, events: events);
      await expectLater(
        client.connect('AA:BB'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('NO_CONNECT'),
          ),
        ),
      );
    });

    test('disconnect nunca lanza aunque el nativo falle', () async {
      messenger.setMockMethodCallHandler(method, (call) async {
        throw PlatformException(code: 'X');
      });
      final client = SppClient(method: method, events: events);
      await expectLater(client.disconnect('AA:BB'), completes);
    });

    test('fan-out: reparte bytes y cierre por dirección', () async {
      const eventsMap = <Object?>[
        {'address': 'AA:BB', 'bytes': [1, 2, 3]},
        {'address': 'OTHER', 'bytes': [9]},
        {'address': 'AA:BB', 'closed': true},
        'basura-no-map',
        {'bytes': [1]}, // sin address
      ];
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (args, sink) {
            // El codec del EventChannel entrega Map<Object?,Object?> y las
            // listas como Int32List -> los eventos reales llevan Uint8List.
            for (final e in eventsMap) {
              if (e is Map) {
                final b = e['bytes'];
                sink.success({
                  ...e,
                  if (b != null) 'bytes': Uint8List.fromList((b as List).cast<int>()),
                });
              } else {
                sink.success(e);
              }
            }
          },
        ),
      );
      final client = SppClient(method: method, events: events);

      final rx = <Uint8List>[];
      final closed = <void>[];
      client.bytes('AA:BB').listen(rx.add);
      client.closed('AA:BB').listen(closed.add);
      await Future<void>.delayed(Duration.zero);

      expect(rx, hasLength(1));
      expect(rx.first, Uint8List.fromList([1, 2, 3]));
      expect(closed, hasLength(1));
    });
  });

  group('SppMindSource con cliente que falla', () {
    test('connect propaga el error del cliente', () async {
      final src = SppMindSource(
        address: 'AA:BB',
        deviceName: '',
        slot: 0,
        client: _ThrowingClient(),
      );
      expect(src.name, 'AA:BB'); // sin nombre -> cae a la MAC
      await expectLater(src.connect(), throwsA(isA<MissingPluginException>()));
    });
  });

  group('EegStore.mergeBonded', () {
    test('dedupe por MAC y orden alfabético insensible a mayúsculas', () {
      final ble = [
        MindDevice.spp('AA:BB', 'zeta'),
        MindDevice.spp('CC:DD', 'Beta'),
      ];
      final spp = [SppDevice(address: 'AA:BB', name: 'zeta-spp')];
      final merged = EegStore.mergeBonded(ble, spp);
      // orden alfabético por nombre: 'Beta' < 'zeta-spp'
      expect(merged.map((d) => d.id), ['CC:DD', 'AA:BB']);
      expect(merged[1].name, 'zeta-spp'); // gana la versión SPP
      expect(merged.first.name, 'Beta');
    });

    test('listas vacías', () {
      expect(EegStore.mergeBonded(const [], const []), isEmpty);
    });
  });

  group('EegStore ciclo de vida', () {
    test('init/isBleSupported/permissionError/disposeAll', () async {
      final store = EegStore();
      expect(store.permissionError, isNull);
      store.init(true);
      expect(store.bleAvailable, isTrue);
      store.addSimulated();
      store.addSimulated();
      expect(store.sources.whereType<MindSource>(), hasLength(2));
      await store.disposeAll();
      expect(store.connected, isEmpty);
      expect(store.sources.whereType<MindSource>(), isEmpty);
      expect(store.nextFreeSlot, 0);
    });

    test('rellena los 8 slots y addSimulated ignora el desbordamiento', () {
      final store = EegStore();
      for (var i = 0; i < 10; i++) {
        store.addSimulated();
      }
      expect(store.connected, hasLength(EegStore.maxDevices));
      expect(store.nextFreeSlot, isNull);
    });

    test('connectBle con dispositivo classic usa SPP y limpia slot al fallar', () async {
      final store = EegStore(sppClient: _ThrowingClient());
      const dev = MindDevice.spp('AA:BB', 'ThempraEEG');
      await expectLater(store.connectBle(dev), throwsA(isA<Exception>()));
      expect(store.connected, isEmpty); // slot limpiado tras el fallo
    });
  });
}
