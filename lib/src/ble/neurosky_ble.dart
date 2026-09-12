import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../eeg/eeg_data.dart';
import '../eeg/thinkgear_parser.dart';
import 'mind_source.dart';

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

  /// Nivel de API de Android, leído de forma fiable con `device_info_plus`
  /// (NO se parsea la cadena de sistema operativo, que es frágil).
  /// 0 si no se puede determinar.
  static Future<int> _androidSdkInt() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 0;
    }
  }

  /// Solicita y comprueba los permisos de Bluetooth (Android).
  ///
  /// Android 12+ (API 31+) usa `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` como
  /// permisos en runtime y NO necesita ubicación (el manifest declara
  /// `neverForLocation`). Android ≤ 11 (API ≤ 30) sí exige ubicación para
  /// escanear BLE (allí los permisos BLE son automáticos, en la instalación).
  ///
  /// Devuelve `null` si todo está en orden, o un mensaje si falta un permiso
  /// imprescindible (entonces no se puede escanear).
  static Future<String?> ensurePermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final sdk = await _androidSdkInt();
    if (sdk >= 31) {
      // Android 12+: solo hacen falta los permisos BLE runtime.
      for (final p in [Permission.bluetoothScan, Permission.bluetoothConnect]) {
        if (!await p.isGranted) {
          final res = await p.request();
          if (!res.isGranted && !res.isPermanentlyDenied) {
            return 'Permiso Bluetooth denegado';
          }
          if (res.isPermanentlyDenied) {
            // Abrimos ajustes del sistema para que el usuario lo habilite.
            await openAppSettings();
            return 'Activa el permiso Bluetooth en los ajustes';
          }
        }
      }
    } else {
      // Android ≤ 11: escanear BLE exige acceso a ubicación.
      if (!await Permission.location.isGranted) {
        final res = await Permission.location.request();
        if (!res.isGranted && !res.isPermanentlyDenied) {
          return 'Permiso de ubicación denegado';
        }
        if (res.isPermanentlyDenied) {
          await openAppSettings();
          return 'Activa el permiso de ubicación en los ajustes';
        }
      }
    }
    return null;
  }

  /// Lista los dispositivos ya vinculados (bonded) en el sistema Android.
  ///
  /// Ordena alfabéticamente por nombre. No requiere escaneo previo. Los que
  /// solo tienen MAC (sin nombre) se descartan, igual que en el escaneo.
  static Future<List<MindDevice>> bonded() async {
    final devices = await FlutterBluePlus.bondedDevices;
    final list = <MindDevice>[];
    for (final d in devices) {
      if (d.platformName.trim().isEmpty) continue; // solo con nombre
      list.add(MindDevice.ble(d, 0, const []));
    }
    list.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  }

  /// Escanea dispositivos BLE cercanos hasta `timeout`.
  ///
  /// Solo se conservan dispositivos que publican un nombre (`platformName` no
  /// vacío); los anuncios que únicamente traen MAC (sin nombre) se descartan,
  /// tal y como se pide en la UI.
  ///
  /// Publica resultados en vivo a través de `onResult` (para que la UI pueda
  /// mostrarlos mientras escanea) y devuelve la lista final ordenada por RSSI
  /// y sin duplicados.
  ///
  /// Implementación robusta: en lugar de gestionar temporizadores y un
  /// `Completer` propios (que podían dejar el escaneo colgado si `stopScan`
  /// fallaba), se apoya en el timeout interno de `startScan(timeout:)` y se
  /// limita a esperar a que el plugin detenga el escaneo por sí mismo.
  static Future<List<MindDevice>> scan({
    Duration timeout = const Duration(seconds: 10),
    void Function(List<MindDevice>)? onResult,
    /// Si true (por defecto), descarta los dispositivos que no publican
    /// nombre (solo transmiten MAC).
    bool onlyNamed = true,
  }) async {
    // 1) Asegurar que el adaptador BLE está activo.
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {
        // Si no se puede encender seguimos; startScan notificará el error.
      }
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.adapterState
            .timeout(timeout)
            .firstWhere((s) => s == BluetoothAdapterState.on);
      } catch (_) {
        return const [];
      }
    }

    final seen = <String, MindDevice>{};

    void pushCurrent() {
      final sorted = seen.values.toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      onResult?.call(sorted);
    }

    // 2) Limpiar un posible escaneo residual del plugin antes de empezar.
    if (FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }

    // 3) Escuchar resultados en vivo. `onScanResults` no re-emite resultados
    //    de escaneos anteriores, así que empezamos con una lista limpia.
    final sub = FlutterBluePlus.onScanResults.listen((list) {
      for (final r in list) {
        // Solo dispositivos con nombre publicado (o se pide mostrar todo).
        final hasName = r.device.platformName.trim().isNotEmpty ||
            r.advertisementData.advName.trim().isNotEmpty;
        if (onlyNamed && !hasName) continue;
        seen[r.device.remoteId.str] = MindDevice.ble(
          r.device,
          r.rssi,
          r.advertisementData.serviceUuids.map((u) => u.str).toList(),
        );
      }
      pushCurrent();
    });

    try {
      // 4) startScan con su propio timeout; el plugin se auto-detiene.
      await FlutterBluePlus.startScan(timeout: timeout);

      // 5) Esperar a que el plugin termine el escaneo (timeout interno).
      while (FlutterBluePlus.isScanningNow) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } finally {
      await sub.cancel();
      if (FlutterBluePlus.isScanningNow) {
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
      }
    }

    pushCurrent();
    final sorted = seen.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return sorted;
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

    // 1) Intento directo (rápido si el dispositivo está anunciando).
    var ok = await _connectAttempt(
      autoConnect: false,
      timeout: const Duration(seconds: 12),
    );
    // 2) Fallback para dispositivos ya vinculados (bonded): autoConnect usa el
    //    vínculo guardado por Android y conecta aunque no esté anunciando.
    if (!ok) {
      ok = await _connectAttempt(
        autoConnect: true,
        timeout: const Duration(seconds: 25),
      );
    }
    if (!ok) {
      throw StateError('No se pudo conectar al dispositivo BLE');
    }

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

  /// Intenta una conexión. Con `autoConnect: true` el plugin devuelve
  /// inmediatamente, así que esperamos el estado `connected` por la vía del
  /// stream. Devuelve `true` solo si llega a conectarse.
  Future<bool> _connectAttempt({
    required bool autoConnect,
    required Duration timeout,
  }) async {
    if (!autoConnect) {
      try {
        await device.connect(timeout: timeout, mtu: 512, autoConnect: false);
        return device.isConnected;
      } catch (_) {
        return false;
      }
    }

    // autoConnect: esperar el evento de conexión.
    final completer = Completer<bool>();
    late StreamSubscription<BluetoothConnectionState> sub;
    sub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected &&
          !completer.isCompleted) {
        completer.complete(true);
      }
    });
    try {
      await device.connect(timeout: timeout, mtu: null, autoConnect: true);
      return await completer.future
          .timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    } finally {
      await sub.cancel();
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
        blinkStrength: c.blinkStrength,
        blinkDetected: c.blinkDetected,
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
