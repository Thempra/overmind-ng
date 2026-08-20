import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../eeg/eeg_data.dart';
import '../eeg/thinkgear_parser.dart';
import 'mind_source.dart';

/// Resultado de escaneo BLE.
class MindDevice {
  const MindDevice(this.device, this.rssi, this.serviceUuids);
  final BluetoothDevice device;
  final int rssi;
  final List<String> serviceUuids;
}

/// Gestor BLE real para MindWave Mobile 2 (y dispositivos ThinkGear BLE).
///
/// Sustituye al Bluetooth clásico RFCOMM/SPP del proyecto Android original por
/// una pila BLE moderna. El stream EEG se lee de la característica con
/// notificaciones del dispositivo y pasa por el parser ThinkGear.
class NeuroSkyBle extends MindSource {
  NeuroSkyBle(this.device, {required this.slot});

  final BluetoothDevice device;
  final int slot;

  final EegData _eeg =
      EegData(address: '', name: '', slot: 0);
  final ThinkGearParser _parser = ThinkGearParser();
  final _controller = StreamController<EegData>.broadcast();

  StreamSubscription<List<int>>? _sub;
  bool _dataFound = false;

  @override
  String get id => device.remoteId.str;

  @override
  String get name => (device.platformName.isNotEmpty)
      ? device.platformName
      : device.remoteId.str;

  @override
  EegData get eeg => _eeg;

  @override
  Stream<EegData> get stream => _controller.stream;

  /// Solicita y comprueba los permisos de Bluetooth (Android).
  static Future<bool> ensurePermissions() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      for (final p in [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ]) {
        if (!await p.isGranted) {
          final res = await p.request();
          if (!res.isGranted) return false;
        }
      }
    }
    return true;
  }

  /// Escanea dispositivos BLE cercanos hasta `timeout`.
  static Future<List<MindDevice>> scan({Duration timeout = const Duration(seconds: 15)}) async {
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }
    await FlutterBluePlus.startScan(timeout: timeout);
    final completer = Completer<List<MindDevice>>();
    final results = <MindDevice>[];
    final sub = FlutterBluePlus.scanResults.listen((list) {
      results.clear();
      for (final r in list) {
        results.add(MindDevice(
          r.device,
          r.rssi,
          r.advertisementData.serviceUuids.map((u) => u.str).toList(),
        ));
      }
    });
    // Esperamos o el timeout o un resultado que parezca MindWave.
    Timer? keepAlive;
    keepAlive = Timer(timeout, () async {
      sub.cancel();
      await FlutterBluePlus.stopScan();
      completer.complete(results);
    });
    // Detectamos dispositivos ThinkGear/NeuroSky por servicios conocidos
    // (0xFFF0) o por nombre que contenga "mind"/"wave"/"eeg".
    final t1 = Timer(const Duration(seconds: 5), () async {
      for (final r in results) {
        final n = r.device.platformName.toLowerCase();
        if (n.contains('mind') || n.contains('wave') || n.contains('eeg')) {
          keepAlive?.cancel();
          sub.cancel();
          await FlutterBluePlus.stopScan();
          completer.complete(results);
          return;
        }
      }
    });
    final finalResults = await completer.future;
    t1.cancel();
    keepAlive!.cancel();
    return finalResults;
  }

  @override
  Future<void> connect() async {
    // Cancelar un posible escaneo en curso.
    if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();

    _eeg
      ..address = device.remoteId.str
      ..name = name
      ..slot = slot
      ..reset();

    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 15),
    );
    await device.discoverServices();

    final services = device.servicesList;
    // Suscribirse a toda característica con notify y dejar que el parser filtre.
    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.properties.notify) {
          _sub = char.onValueReceived.listen(_onBytes, onError: (_) {});
          try {
            await char.setNotifyValue(true);
          } catch (_) {}
        }
      }
    }
  }

  void _onBytes(List<int> data) {
    if (_dataFound) return;
    final captures = _parser.addBytes(Uint8List.fromList(data));
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
      _dataFound = true;
      if (!_controller.isClosed) _controller.add(_eeg);
      break;
    }
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    if (device.isConnected) {
      await device.disconnect();
    }
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
