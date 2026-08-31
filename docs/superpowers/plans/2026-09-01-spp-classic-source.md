# Fuente EEG SPP Classic — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir usar el dispositivo ThempraEEG (Bluetooth Classic/SPP) desde la app, integrándolo como `MindSource` junto a BLE y simulación.

**Architecture:** Platform channel nativo Kotlin (RFCOMM/SPP → EventChannel de bytes) + `SppMindSource` en Dart que reutiliza `ThinkGearParser`. `EegStore` fusiona vinculados LE+Classic y enruta la conexión según `MindDevice.isClassic`.

**Tech Stack:** Flutter/Dart, Kotlin (MainActivity), MethodChannel/EventChannel, RFCOMM UUID SPP estándar.

**Spec:** `docs/superpowers/specs/2026-09-01-spp-classic-source-design.md`

---

### Task 1: `MindDevice` con id/name/isClassic

**Files:**
- Modify: `lib/src/ble/neurosky_ble.dart:12-18` (clase), `:113-127` (bonded), `:185-198` (scan)
- Test: `test/spp_source_test.dart` (nuevo)

- [ ] **Step 1: Escribir test fallido**

Crear `test/spp_source_test.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

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
```

- [ ] **Step 2: Verificar que falla**

Run: `flutter test test/spp_source_test.dart`
Expected: FAIL — `MindDevice.spp` no existe / `bleDevice` no definido.

- [ ] **Step 3: Implementar**

Sustituir en `lib/src/ble/neurosky_ble.dart` la clase actual (líneas 13-18) por:

```dart
/// Resultado de escaneo o vínculo: dispositivo BLE (LE) o Classic/SPP.
class MindDevice {
  MindDevice.ble(BluetoothDevice device, this.rssi, this.serviceUuids)
    : bleDevice = device,
      isClassic = false,
      _sppId = null,
      _sppName = null;

  const MindDevice.spp(String id, String name)
    : bleDevice = null,
      isClassic = true,
      rssi = 0,
      serviceUuids = const [],
      _sppId = id,
      _sppName = name;

  /// Dispositivo FBP subyacente (null si es Classic).
  final BluetoothDevice? bleDevice;
  final bool isClassic;
  final int rssi;
  final List<String> serviceUuids;
  final String? _sppId;
  final String? _sppName;

  String get id => isClassic ? _sppId! : bleDevice!.remoteId.str;
  String get name {
    if (isClassic) return _sppName!;
    final n = bleDevice!.platformName;
    return n.isNotEmpty ? n : bleDevice!.remoteId.str;
  }
}
```

Actualizar los 2 puntos de construcción:
- `bonded()`: `list.add(MindDevice.ble(d, 0, const []));` y el comparador de ordenación pasa a usar `a.name.toLowerCase().compareTo(b.name.toLowerCase())`.
- `scan()` (línea ~191): `seen[r.device.remoteId.str] = MindDevice.ble(r.device, r.rssi, r.advertisementData.serviceUuids.map((u) => u.str).toList());`

- [ ] **Step 4: Verificar test**

Run: `flutter test test/spp_source_test.dart`
Expected: PASS (nota: `flutter analyze` puede fallar por la UI aún sin actualizar — se arregla en Task 5).

- [ ] **Step 5: Commit**

```bash
git add lib/src/ble/neurosky_ble.dart test/spp_source_test.dart
git commit -m "feat(spp): MindDevice con id/name/isClassic y constructor .spp"
```

---

### Task 2: `SppDevice` + `SppClient`

**Files:**
- Create: `lib/src/ble/spp_mind_source.dart`

- [ ] **Step 1: Implementar clases (sin test directo: la lógica de canal se verifica con Fake en Task 3 y en dispositivo)**

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Dispositivo Classic/SPP vinculado devuelto por el canal nativo.
class SppDevice {
  const SppDevice({required this.address, required this.name});
  final String address;
  final String name;
}

/// Cliente del canal nativo "overmind/spp" (solo Android).
///
/// Métodos sobreescribibles para tests: [connect], [disconnect], [bytes],
/// [closed], [devices]. Mantiene UNA suscripción al EventChannel y reparte
/// los eventos por dirección (fan-out), porque EventChannel nativo solo
/// soporta un sink.
class SppClient {
  SppClient({MethodChannel? method, EventChannel? events})
    : _method = method ?? const MethodChannel('overmind/spp'),
      _events = events ?? const EventChannel('overmind/spp/bytes');

  /// Instancia por defecto compartida por toda la app.
  static final SppClient instance = SppClient();

  final MethodChannel _method;
  final EventChannel _events;
  StreamSubscription<dynamic>? _sub;
  final _bytesCtl = <String, StreamController<Uint8List>>{};
  final _closedCtl = <String, StreamController<void>>{};

  /// Dispositivos Classic/DUAL vinculados en el sistema.
  Future<List<SppDevice>> devices() async {
    final res = await _method.invokeMethod('getDevices');
    if (res == null) return const [];
    return [
      for (final e in (res as List).cast<Map>())
        SppDevice(address: e['address'] as String, name: e['name'] as String),
    ];
  }

  /// Conecta por RFCOMM/SPP. Lanza [StateError] si falla.
  Future<void> connect(String address) async {
    try {
      await _method.invokeMethod('connect', {'address': address});
    } on PlatformException catch (e) {
      throw StateError(
        'No se pudo conectar por SPP: ${e.code} ${e.message ?? ''}'.trim(),
      );
    } on MissingPluginException {
      throw StateError('SPP no disponible en esta plataforma');
    }
  }

  Future<void> disconnect(String address) async {
    try {
      await _method.invokeMethod('disconnect', {'address': address});
    } catch (_) {}
  }

  /// Flujo de bytes entrantes del dispositivo `address`.
  Stream<Uint8List> bytes(String address) {
    _ensureSubscribed();
    return (_bytesCtl[address] ??= StreamController<Uint8List>.broadcast())
        .stream;
  }

  /// Evento (void) cuando el socket de `address` se cierra o cae.
  Stream<void> closed(String address) =>
      (_closedCtl[address] ??= StreamController<void>.broadcast()).stream;

  void _ensureSubscribed() {
    if (_sub != null) return;
    _sub = _events.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
      final map = event.cast<String, dynamic>();
      final address = map['address'] as String?;
      if (address == null) return;
      if (map['closed'] == true) {
        _closedCtl[address]?.add(null);
      } else {
        final data = map['bytes'];
        if (data is Uint8List && data.isNotEmpty) {
          _bytesCtl[address]?.add(data);
        }
      }
    });
  }
}
```

- [ ] **Step 2: Compila**

Run: `dart analyze lib/src/ble/spp_mind_source.dart` (o `flutter analyze` — puede fallar solo por UI pendiente)
Expected: sin errores en este archivo.

- [ ] **Step 3: Commit**

```bash
git add lib/src/ble/spp_mind_source.dart
git commit -m "feat(spp): SppDevice y SppClient (canal nativo con fan-out por MAC)"
```

---

### Task 3: `SppMindSource`

**Files:**
- Modify: `lib/src/ble/spp_mind_source.dart`
- Test: `test/spp_source_test.dart`

- [ ] **Step 1: Escribir tests fallidos** (añadir a `test/spp_source_test.dart`; imports: `package:overmind/src/ble/spp_mind_source.dart`, `package:overmind/src/eeg/eeg_data.dart`)

```dart
/// Helper: paquete ThinkGear válido (como en thinkgear_parser_test.dart).
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
```

Tests (nuevo grupo `SppMindSource`):

```dart
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
```

- [ ] **Step 2: Verificar que fallan**

Run: `flutter test test/spp_source_test.dart`
Expected: FAIL — `SppMindSource` no existe.

- [ ] **Step 3: Implementar** (añadir a `lib/src/ble/spp_mind_source.dart`; imports: `../eeg/eeg_data.dart`, `../eeg/thinkgear_parser.dart`, `mind_source.dart`)

```dart
/// Fuente EEG por Bluetooth Classic SPP (RFCOMM), p. ej. ThempraEEG.
///
/// Mismo contrato que [NeuroSkyBle]: los bytes SPP alimentan el mismo
/// `ThinkGearParser` (protocolo idéntico al BLE).
class SppMindSource extends MindSource {
  SppMindSource({
    required this.address,
    required this.deviceName,
    required this.slot,
    SppClient? client,
  }) : _client = client ?? SppClient.instance;

  final String address;
  final String deviceName;
  final int slot;
  final SppClient _client;

  final EegData _eeg = EegData(address: '', name: '', slot: 0);
  final ThinkGearParser _parser = ThinkGearParser();
  final _controller = StreamController<EegData>.broadcast();

  StreamSubscription<Uint8List>? _bytesSub;
  StreamSubscription<void>? _closedSub;

  @override
  String get id => address;

  @override
  String get name => deviceName.isNotEmpty ? deviceName : address;

  @override
  EegData get eeg => _eeg;

  @override
  Stream<EegData> get stream => _controller.stream;

  @override
  Future<void> connect() async {
    _eeg
      ..address = address
      ..name = name
      ..slot = slot
      ..reset();
    await _client.connect(address);
    _bytesSub = _client.bytes(address).listen(_onBytes, onError: (_) {});
    _closedSub = _client.closed(address).listen((_) {});
  }

  void _onBytes(Uint8List data) {
    final captures = _parser.addBytes(data);
    for (final c in captures) {
      _eeg.applyCapture(
        signal: c.poorSignal,
        attention: c.attention,
        meditation: c.meditation,
        rawDelta: c.rawDelta.toDouble(),
        rawTheta: c.rawTheta.toDouble(),
        rawLowAlpha: c.rawLowAlpha.toDouble(),
        rawHighAlpha: c.rawHighAlpha.toDouble(),
        rawLowBeta: c.rawLowBeta.toDouble(),
        rawHighBeta: c.rawHighBeta.toDouble(),
        rawLowGamma: c.rawLowGamma.toDouble(),
        rawHighGamma: c.rawHighGamma.toDouble(),
      );
      if (!_controller.isClosed) _controller.add(_eeg);
    }
  }

  @override
  Future<void> disconnect() async {
    await _bytesSub?.cancel();
    _bytesSub = null;
    await _closedSub?.cancel();
    _closedSub = null;
    await _client.disconnect(address);
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
```

- [ ] **Step 4: Verificar tests**

Run: `flutter test test/spp_source_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/ble/spp_mind_source.dart test/spp_source_test.dart
git commit -m "feat(spp): SppMindSource sobre ThinkGearParser con cliente inyectable"
```

---

### Task 4: Enrutado y fusión en `EegStore`

**Files:**
- Modify: `lib/src/state/eeg_store.dart`
- Test: `test/spp_source_test.dart`

- [ ] **Step 1: Tests fallidos** (nuevo grupo `EegStore enrutado`; import `package:overmind/src/state/eeg_store.dart`)

```dart
test('connectBle enruta un dispositivo Classic a SppMindSource', () async {
  final fake = FakeSppClient();
  final store = EegStore(sppClient: fake);
  await store.connectBle(const MindDevice.spp('00:12:02:10:71:49', 'ThempraEEG'));
  expect(store.sources[0], isA<SppMindSource>());
  expect(store.devices[0]?.address, '00:12:02:10:71:49');
  expect(store.devices[0]?.name, 'ThempraEEG');
});

test('mergeBonded deduplica por MAC y marca los Classic', () {
  final ble = <MindDevice>[
    // No se puede construir MindDevice.ble sin FBP: se prueba solo con SPP.
  ];
  final spp = <SppDevice>[
    const SppDevice(address: 'A', name: 'Uno'),
    const SppDevice(address: 'B', name: 'Dos'),
  ];
  final merged = EegStore.mergeBonded(ble, spp);
  expect(merged, hasLength(2));
  expect(merged.every((d) => d.isClassic), isTrue);
  expect(merged.map((d) => d.name), ['Dos', 'Uno']); // ordenado por nombre
});
```

- [ ] **Step 2: Verificar que fallan**

Run: `flutter test test/spp_source_test.dart`
Expected: FAIL — `EegStore(sppClient:)` y `mergeBonded` no existen.

- [ ] **Step 3: Implementar** en `lib/src/state/eeg_store.dart`:

Imports nuevos: `dart:typed_data` no hace falta; añadir `package:flutter/services.dart` y `../ble/spp_mind_source.dart`.

Constructor y campo:

```dart
class EegStore extends ChangeNotifier {
  EegStore({SppClient? sppClient})
    : _sppClient = sppClient ?? SppClient.instance;

  final SppClient _sppClient;
```

`loadBonded()` reemplazado (deduplica: los Classic aparecen en ambas listas — FBP los devuelve también):

```dart
Future<List<MindDevice>> loadBonded() async {
  _permissionError = null;
  try {
    final ble = await NeuroSkyBle.bonded();
    var spp = <SppDevice>[];
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      try {
        spp = await _sppClient.devices();
      } on Exception {
        spp = <SppDevice>[]; // canal no disponible / sin permiso: seguimos con LE
      }
    }
    _discovered = mergeBonded(ble, spp);
    notifyListeners();
    return _discovered;
  } catch (e) {
    _discovered = const [];
    notifyListeners();
    rethrow;
  }
}

/// Fusión pura (testeable): quita de la lista BLE los que ya vienen por SPP
/// (misma MAC) y ordena todo por nombre.
static List<MindDevice> mergeBonded(
  List<MindDevice> ble,
  List<SppDevice> spp,
) {
  final sppAddresses = spp.map((d) => d.address).toSet();
  return <MindDevice>[
    ...ble.where((d) => !sppAddresses.contains(d.id)),
    ...spp.map((d) => MindDevice.spp(d.address, d.name)),
  ]..sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
}
```

`connectBle()` — sustituir `final src = NeuroSkyBle(device.device, slot: slot);`:

```dart
final MindSource src;
if (device.isClassic) {
  src = SppMindSource(
    address: device.id,
    deviceName: device.name,
    slot: slot,
    client: _sppClient,
  );
} else {
  src = NeuroSkyBle(device.bleDevice!, slot: slot);
}
```

- [ ] **Step 4: Verificar tests**

Run: `flutter test test/spp_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/state/eeg_store.dart test/spp_source_test.dart
git commit -m "feat(spp): EegStore fusiona vinculados LE+Classic y enruta la conexión"
```

---

### Task 5: UI — lista de dispositivos

**Files:**
- Modify: `lib/src/screens/settings_screen.dart:53,328,336-338,346,362,365`

- [ ] **Step 1: Cambios exactos**

- L53: `setState(() => _connectingId = d.device.remoteId.str);` → `setState(() => _connectingId = d.id);`
- L328: `const Icon(Icons.bluetooth, color: OvermindColors.evaCyan, size: 20),` → `Icon(d.isClassic ? Icons.cable : Icons.bluetooth, color: OvermindColors.evaCyan, size: 20),`
- L336-338: el `Text(...)` del nombre → `Text(d.name, ...)`
- L346: `d.rssi != 0 ? '${d.rssi} dBm' : s.bondedLabel,` → `d.isClassic ? 'SPP' : (d.rssi != 0 ? '${d.rssi} dBm' : s.bondedLabel),`
- L362 y L365: `_connectingId == d.device.remoteId.str` → `_connectingId == d.id`

- [ ] **Step 2: Verificar**

Run: `flutter analyze` → sin issues nuevos.
Run: `flutter test` → todo PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/src/screens/settings_screen.dart
git commit -m "feat(spp): la lista de dispositivos muestra y conecta fuentes SPP"
```

---

### Task 6: Canal nativo Kotlin (RFCOMM/SPP)

**Files:**
- Modify: `android/app/src/main/kotlin/com/thempra/overmind/MainActivity.kt`

- [ ] **Step 1: Implementación completa** (sin test unitario posible aquí; verificación = build + dispositivo)

```kotlin
package com.thempra.overmind

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {

    companion object {
        val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        const val METHOD_CHANNEL = "overmind/spp"
        const val EVENT_CHANNEL = "overmind/spp/bytes"
    }

    private var adapter: BluetoothAdapter? = null
    private var eventSink: EventChannel.EventSink? = null
    private val sockets = ConcurrentHashMap<String, SocketHolder>()

    private class SocketHolder(val socket: BluetoothSocket) {
        @Volatile var running: Boolean = true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        adapter =
            (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getDevices" -> handleGetDevices(result)
                        "connect" ->
                            handleConnect(call.argument<String>("address")!!, result)
                        "disconnect" ->
                            handleDisconnect(call.argument<String>("address")!!, result)
                        else -> result.notImplemented()
                    }
                } catch (e: SecurityException) {
                    result.error("security", e.message, null)
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun handleGetDevices(result: MethodChannel.Result) {
        val a = adapter
        if (a == null) {
            result.error("no_adapter", "Bluetooth adapter unavailable", null)
            return
        }
        val out = mutableListOf<Map<String, String>>()
        for (d in a.bondedDevices) {
            val type = d.type
            if (type != BluetoothDevice.DEVICE_TYPE_CLASSIC &&
                type != BluetoothDevice.DEVICE_TYPE_DUAL
            ) {
                continue
            }
            val name = d.name ?: continue
            if (name.isBlank()) continue
            out.add(mapOf("address" to d.address, "name" to name))
        }
        result.success(out)
    }

    private fun handleConnect(address: String, result: MethodChannel.Result) {
        val a = adapter
        if (a == null) {
            result.error("no_adapter", "Bluetooth adapter unavailable", null)
            return
        }
        if (sockets.containsKey(address)) {
            result.success(true)
            return
        }
        val device = a.getRemoteDevice(address)
        Thread {
            try {
                a.cancelDiscovery()
                val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
                val holder = SocketHolder(socket)
                sockets[address] = holder
                runOnUiThread { result.success(true) }
                readLoop(address, holder)
            } catch (e: IOException) {
                sockets.remove(address)
                runOnUiThread { result.error("connect_failed", e.message, null) }
            } catch (e: SecurityException) {
                runOnUiThread { result.error("security", e.message, null) }
            }
        }.start()
    }

    private fun handleDisconnect(address: String, result: MethodChannel.Result) {
        val holder = sockets.remove(address)
        if (holder == null) {
            result.success(false)
            return
        }
        holder.running = false
        try {
            holder.socket.close()
        } catch (_: IOException) {
        }
        result.success(true)
    }

    private fun readLoop(address: String, holder: SocketHolder) {
        val buffer = ByteArray(512)
        try {
            val input = holder.socket.inputStream
            while (holder.running) {
                val n = input.read(buffer)
                if (n == -1) break
                if (n > 0) {
                    val chunk = buffer.copyOf(n)
                    runOnUiThread {
                        eventSink?.success(
                            mapOf("address" to address, "bytes" to chunk)
                        )
                    }
                }
            }
        } catch (_: IOException) {
            // Socket cerrado (disconnect) o caído: se notifica abajo.
        } finally {
            sockets.remove(address)
            runOnUiThread {
                eventSink?.success(mapOf("address" to address, "closed" to true))
            }
        }
    }
}
```

Nota: los accesos a `bondedDevices`, `name`, `cancelDiscovery`, `connect`
requieren BLUETOOTH_CONNECT (concedido); el `SecurityException` global ya se
captura.

- [ ] **Step 2: Verificar build**

Run: `flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/thempra/overmind/MainActivity.kt
git commit -m "feat(spp): canal nativo RFCOMM/SPP (connect/disconnect/stream de bytes)"
```

---

### Task 7: Suite completa + análisis

- [ ] **Step 1:** Run: `flutter analyze` → sin issues.
- [ ] **Step 2:** Run: `flutter test` → todo PASS.
- [ ] **Step 3:** Fix si procede y commit de restos si hay (`git status` limpio).

---

### Task 8: Verificación en dispositivo físico

- [ ] **Step 1:** Instalar: `adb -s 399ab8593cb9 install -r build/app/outputs/flutter-apk/app-debug.apk` (aceptar diálogo MIUI).
- [ ] **Step 2:** Lanzar app → Ajustes → **Vinculados**: debe aparecer «ThempraEEG» con etiqueta SPP.
- [ ] **Step 3:** Pulsar Conectar en ThempraEEG (EEG encendido y puesto).
- [ ] **Step 4:** Evidencia en logcat:

```bash
adb -s 399ab8593cb9 logcat -d | grep -E "overmind|SPP|flutter"
```

Verificar: conexión estable (sin FATAL), y bytes fluyendo (valores attention/meditation cambian en la UI del juego; opcionalmente `dumpsys bluetooth_manager` muestra el socket GATT-less RFCOMM activo).

- [ ] **Step 5:** Commit final si quedó algo sin commitear; informe al usuario.
