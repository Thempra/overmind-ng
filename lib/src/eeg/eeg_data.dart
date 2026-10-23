import 'package:flutter/foundation.dart';

import 'signal_quality.dart';

/// Datos EEG de un dispositivo MindWave (NeuroSky ThinkGear).
///
/// Port directo del modelo [Eeg] del proyecto Android original
/// (overmind/src/net/thempra/overmind/Eeg.java), ampliado con valores
/// crudos de banda y la normalización porcentual que usaba el original.
///
/// ## Modelo de señal (corregido)
///
/// `signal` guarda el `poorSignal` CRUDO de ThinkGear (0 = contacto
/// perfecto, 200 = sin contacto). Antes `reset()` ponía `signal = 0`, con lo
/// que "desconectado" se pintaba como "señal perfecta". Ahora:
///
///  * [hasData] distingue "nunca llegó un paquete" ([SignalQuality.unknown])
///    de "llegó un paquete sin contacto" ([SignalQuality.offline]).
///  * [signalQuality] es la única fuente de verdad para el HUD.
///  * [lastUpdate]/[packetSeq] alimentan el watchdog de ausencia de paquetes.
class EegData extends ChangeNotifier {
  EegData({
    required this.address,
    required this.name,
    required this.slot,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  String address;
  String name;
  int slot;

  final DateTime Function() _clock;

  /// `poorSignal` crudo de ThinkGear: 0 = buena, 200 = sin contacto.
  ///
  /// Un valor de [kSignalNoContact] con [hasData] en false significa
  /// "desconocido"; nunca "señal perfecta".
  int signal = kSignalNoContact;

  int attention = 0;
  int meditation = 0;

  /// Parpadeo: fuerza 0-100 del ultimo blink y flag del ASIC. El juego lo
  /// consume via `takeBlink()` para no procesar el mismo parpadeo dos veces.
  int blinkStrength = 0;
  bool blinkDetected = false;
  int _blinkSeq = 0;

  // Valores crudos (ASIC_EEG_POWER) por banda.
  double rawDelta = 0;
  double rawTheta = 0;
  double rawLowAlpha = 0;
  double rawHighAlpha = 0;
  double rawLowBeta = 0;
  double rawHighBeta = 0;
  double rawLowGamma = 0;
  double rawHighGamma = 0;

  bool _hasData = false;

  /// `true` si ha llegado al menos un paquete desde el último [reset].
  bool get hasData => _hasData;

  /// Timestamp del último paquete recibido (null si nunca hubo).
  DateTime? lastUpdate;

  /// Contador monótono de paquetes recibidos (incluye los de poorSignal=200:
  /// un paquete sin contacto sigue demostrando que el enlace está vivo).
  int packetSeq = 0;

  /// Calidad de señal explícita para el HUD (nunca "perfecta" sin datos).
  SignalQuality get signalQuality => signalQualityOf(signal, hasData: _hasData);

  /// Segundos desde el último paquete, o null si nunca llegó ninguno.
  double? get secondsSinceUpdate {
    final last = lastUpdate;
    if (last == null) return null;
    return _clock().difference(last).inMicroseconds / 1e6;
  }

  /// Normalización original del proyecto Android:
  /// prodelta = (1/rawdelta) * 1_000_000   y luego  * 100 / 1800.
  double _proc(double raw) {
    if (raw <= 0) return 0;
    final p = (1 / raw) * 1000000;
    final v = (p * 100) / 1800;
    return v.clamp(0.0, 100.0);
  }

  double get delta => _proc(rawDelta);
  double get theta => _proc(rawTheta);
  double get lalpha => _proc(rawLowAlpha);
  double get halpha => _proc(rawHighAlpha);
  double get lbeta => _proc(rawLowBeta);
  double get hbeta => _proc(rawHighBeta);
  double get lgamma => _proc(rawLowGamma);
  double get hgamma => _proc(rawHighGamma);

  /// Aplica una nueva captura (versión corregida del parser ThinkGear).
  void applyCapture({
    required int signal,
    required int attention,
    required int meditation,
    required double rawDelta,
    required double rawTheta,
    required double rawLowAlpha,
    required double rawHighAlpha,
    required double rawLowBeta,
    required double rawHighBeta,
    required double rawLowGamma,
    required double rawHighGamma,
    int blinkStrength = 0,
    bool blinkDetected = false,
  }) {
    // Todo paquete prueba que el enlace está vivo, aunque no haya contacto:
    // por eso `packetSeq`/`lastUpdate` se actualizan ANTES del corte por
    // poorSignal y el watchdog nunca confunde "sin contacto" con
    // "sin paquetes".
    _hasData = true;
    this.signal = signal.clamp(0, kSignalNoContact);
    lastUpdate = _clock();
    packetSeq++;

    if (signal >= kSignalNoContact) {
      // Sin contacto en la piel no hay lectura válida: los valores derivados
      // se ponen a cero (comportamiento del original), pero `signal` conserva
      // el 200 para que el HUD muestre "sin señal" y no barras llenas.
      _clearReading();
      notifyListeners();
      return;
    }
    this.attention = attention;
    this.meditation = meditation;
    this.blinkStrength = blinkStrength;
    this.rawDelta = rawDelta;
    this.rawTheta = rawTheta;
    this.rawLowAlpha = rawLowAlpha;
    this.rawHighAlpha = rawHighAlpha;
    this.rawLowBeta = rawLowBeta;
    this.rawHighBeta = rawHighBeta;
    this.rawLowGamma = rawLowGamma;
    this.rawHighGamma = rawHighGamma;
    if (blinkDetected || blinkStrength > 30) {
      this.blinkDetected = true;
      _blinkSeq++;
      _blinkPending = true;
    } else {
      this.blinkDetected = false;
    }
    notifyListeners();
  }

  /// Secuencia que incrementa solo cuando hay un parpadeo NUEVO.
  int get blinkSeq => _blinkSeq;

  /// Consume el parpadeo pendiente: true una sola vez por parpadeo.
  bool takeBlink() {
    if (!_blinkPending) return false;
    _blinkPending = false;
    return true;
  }

  bool _blinkPending = false;

  /// Limpia los valores derivados conservando la calidad de señal conocida.
  void _clearReading() {
    attention = 0;
    meditation = 0;
    blinkStrength = 0;
    blinkDetected = false;
    rawDelta = rawTheta = rawLowAlpha = rawHighAlpha = 0;
    rawLowBeta = rawHighBeta = rawLowGamma = rawHighGamma = 0;
  }

  /// Vuelve al estado "sin datos": calidad [SignalQuality.unknown], NUNCA
  /// "señal perfecta". Se llama al (re)conectar un dispositivo.
  void reset() {
    _hasData = false;
    signal = kSignalNoContact;
    lastUpdate = null;
    _clearReading();
    notifyListeners();
  }

  /// Poder del jugador usado por el juego: (atención + meditación) / 2.
  int get power => (attention + meditation) ~/ 2;

  Map<String, double> get bands => {
        'Signal': signal.toDouble(),
        'Attention': attention.toDouble(),
        'Meditation': meditation.toDouble(),
        'Blink': blinkStrength.toDouble(),
        'Delta': delta,
        'Theta': theta,
        'Low Alpha': lalpha,
        'High Alpha': halpha,
        'Low Beta': lbeta,
        'High Beta': hbeta,
        'Low Gamma': lgamma,
        'High Gamma': hgamma,
      };
}
