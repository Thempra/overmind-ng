import 'package:flutter/foundation.dart';

import '../ble/mind_source.dart';
import '../ble/neurosky_ble.dart';
import '../ble/spp_mind_source.dart';
import '../eeg/eeg_data.dart';

/// Almacén global de dispositivos EEG conectados (hasta 8 slots, igual que el
/// MAX_NUM_BLUETOOTH del original) y orquestador de conexiones BLE/simuladas.
class EegStore extends ChangeNotifier {
  EegStore({SppClient? sppClient})
    : _sppClient = sppClient ?? SppClient.instance;

  final SppClient _sppClient;

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

  /// Carga los dispositivos vinculados: LE (FPB) + Classic/SPP (canal nativo,
  /// solo Android). FBP también devuelve los Classic, así que se deduplican.
  Future<List<MindDevice>> loadBonded() async {
    _permissionError = null;
    try {
      final ble = await NeuroSkyBle.bonded();
      var spp = <SppDevice>[];
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          spp = await _sppClient.devices();
        } on Exception {
          spp = <SppDevice>[]; // canal no disponible: seguimos solo con LE
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

  /// Fusión pura: quita de la lista BLE los que ya vienen por SPP (misma MAC)
  /// y ordena todo alfabéticamente por nombre.
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

  /// Conecta un dispositivo BLE descubierto en el primer slot libre.
  /// Devuelve null si no hay slot libre; si la conexión falla, propaga la
  /// excepción (el UI la mostrará) y limpia el slot.
  Future<void> connectBle(MindDevice device) async {
    final slot = nextFreeSlot;
    if (slot == null) {
      throw StateError('No hay slots libres (máximo $maxDevices)');
    }
    final src =
        device.isClassic
            ? SppMindSource(
              address: device.id,
              deviceName: device.name,
              slot: slot,
              client: _sppClient,
            )
            : NeuroSkyBle(device.bleDevice!, slot: slot);
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
