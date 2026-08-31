import 'dart:async';

import 'package:flutter/services.dart';

import '../eeg/eeg_data.dart';
import '../eeg/thinkgear_parser.dart';
import 'mind_source.dart';

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
/// los eventos por dirección (fan-out), porque el EventChannel nativo solo
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

/// Fuente EEG por Bluetooth Classic SPP (RFCOMM), p. ej. ThempraEEG.
///
/// Mismo contrato que [NeuroSkyBle]: los bytes SPP alimentan el mismo
/// `ThinkGearParser` (protocolo ThinkGear idéntico al BLE).
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
