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
  String? _permissionError;
  List<MindDevice> _discovered = [];
  bool _bleAvailable = false;

  List<EegData?> get devices => _devices;
  List<MindSource?> get sources => _sources;
  bool get isScanning => _scanning;
  List<MindDevice> get discovered => List.unmodifiable(_discovered);
  bool get bleAvailable => _bleAvailable;

  /// Mensaje legible si el último escaneo no pudo arrancar por permisos;
  /// null si se pudo escanear.
  String? get permissionError => _permissionError;

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

  /// Escanea dispositivos BLE cercanos. Publica los resultados en vivo en
  /// `discovered` (notificando a la UI) y devuelve la lista final.
  Future<List<MindDevice>> scanBle() async {
    _scanning = true;
    _permissionError = null;
    _discovered = const [];
    notifyListeners();
    try {
      final permErr = await NeuroSkyBle.ensurePermissions();
      if (permErr != null) {
        _permissionError = permErr;
        _discovered = const [];
        return _discovered;
      }
      final found = await NeuroSkyBle.scan(onResult: (devices) {
        _discovered = devices;
        notifyListeners();
      });
      _discovered = found;
      return found;
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Carga los dispositivos ya vinculados (bonded) por Android y los deja en
  /// `discovered` para que el usuario pueda conectarse a ellos sin escanear.
  Future<List<MindDevice>> loadBonded() async {
    _permissionError = null;
    try {
      final found = await NeuroSkyBle.bonded();
      _discovered = found;
      notifyListeners();
      return found;
    } catch (e) {
      _discovered = const [];
      notifyListeners();
      rethrow;
    }
  }

  /// Conecta un dispositivo BLE descubierto en el primer slot libre.
  /// Devuelve null si no hay slot libre; si la conexión falla, propaga la
  /// excepción (el UI la mostrará) y limpia el slot.
  Future<void> connectBle(MindDevice device) async {
    final slot = nextFreeSlot;
    if (slot == null) {
      throw StateError('No hay slots libres (máximo $maxDevices)');
    }
    final src = NeuroSkyBle(device.device, slot: slot);
    _sources[slot] = src;
    _devices[slot] = src.eeg;
    notifyListeners();
    try {
      await src.connect();
    } catch (e) {
      _sources[slot] = null;
      _devices[slot] = null;
      notifyListeners();
      rethrow;
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
