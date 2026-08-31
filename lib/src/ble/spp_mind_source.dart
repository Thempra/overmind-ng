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
