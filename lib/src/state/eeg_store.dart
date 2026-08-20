import 'package:flutter/foundation.dart';

import '../ble/mind_source.dart';
import '../ble/neurosky_ble.dart';
import '../eeg/eeg_data.dart';

/// Almacén global de dispositivos EEG conectados (hasta 8 slots, igual que el
/// MAX_NUM_BLUETOOTH del original) y orquestador de conexiones BLE/simuladas.
class EegStore extends ChangeNotifier {
  static const maxDevices = 8;

  final List<EegData?> _devices = List.filled(maxDevices, null);
  final List<MindSource?> _sources = List.filled(maxDevices, null);

  bool _scanning = false;
  List<MindDevice> _discovered = [];
  bool _bleAvailable = false;

  List<EegData?> get devices => _devices;
  List<MindSource?> get sources => _sources;
  bool get isScanning => _scanning;
  List<MindDevice> get discovered => List.unmodifiable(_discovered);
  bool get bleAvailable => _bleAvailable;

  int? get nextFreeSlot {
    for (var i = 0; i < maxDevices; i++) {
      if (_devices[i] == null) return i;
    }
    return null;
  }

  bool get isBleSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  List<EegData> get connected =>
      _devices.whereType<EegData>().toList(growable: false);

  /// Marca si la pila BLE real está disponible o hay que usar simulación.
  void init(bool bleAvailable) {
    _bleAvailable = bleAvailable;
    notifyListeners();
  }

  /// Escanea dispositivos BLE cercanos.
  Future<List<MindDevice>> scanBle() async {
    _scanning = true;
    notifyListeners();
    try {
      if (!await NeuroSkyBle.ensurePermissions()) {
        _discovered = const [];
        return _discovered;
      }
      final found = await NeuroSkyBle.scan();
      _discovered = found;
      return found;
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Conecta un dispositivo BLE descubierto en el primer slot libre.
  Future<bool> connectBle(MindDevice device) async {
    final slot = nextFreeSlot;
    if (slot == null) return false;
    final src = NeuroSkyBle(device.device, slot: slot);
    _sources[slot] = src;
    _devices[slot] = src.eeg;
    notifyListeners();
    try {
      await src.connect();
      return true;
    } catch (e) {
      _sources[slot] = null;
      _devices[slot] = null;
      notifyListeners();
      // ignore: avoid_print
      debugPrint('BLE connect failed: $e');
      return false;
    }
  }

  /// Añade una fuente simulada (demo / desktop Linux).
  void addSimulated() {
    final slot = nextFreeSlot;
    if (slot == null) return;
    final src = SimulatedMindSource(slot: slot);
    src.eeg
      ..slot = slot
      ..name = 'Simulated Mind';
    _sources[slot] = src;
    _devices[slot] = src.eeg;
    notifyListeners();
    src.connect();
  }

  /// Desconecta y libera un slot.
  Future<void> removeAt(int slot) async {
    final src = _sources[slot];
    if (src != null) {
      await src.disconnect();
      if (src is SimulatedMindSource) src.dispose();
    }
    _sources[slot] = null;
    _devices[slot] = null;
    notifyListeners();
  }

  Future<void> disposeAll() async {
    for (var i = 0; i < maxDevices; i++) {
      final src = _sources[i];
      if (src != null) {
        await src.disconnect();
        if (src is SimulatedMindSource) src.dispose();
      }
      _sources[i] = null;
      _devices[i] = null;
    }
  }
}
