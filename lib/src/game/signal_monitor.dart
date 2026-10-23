import '../eeg/eeg_data.dart';
import '../eeg/signal_quality.dart';

/// Estado del vigilante de señal durante la partida.
enum SignalWatchState {
  /// Llegan paquetes y la calidad es aceptable (fair/good).
  ok,

  /// Llegan paquetes pero la calidad es mala de forma sostenida.
  degraded,

  /// No llegan paquetes: el enlace se ha caído (o nunca llegó nada).
  lost,
}

/// Vigilante de señal por AUSENCIA DE PAQUETES, no por umbral.
///
/// Un EEG real oscila: `poorSignal` sube y baja constantemente, y un contacto
/// regular pasa por 150-200 sin que el casco esté caído. Pausar por umbral
/// produciría pausas constantes (peor que no pausar), así que:
///
///  * La PAUSA solo depende de `packetSeq`/`lastUpdate`: si el dispositivo
///    deja de emitir durante [packetTimeout] (2,5 s), el motor se pausa.
///  * La BANDA DE AVISO aparece cuando la calidad es mala
///    ([SignalQuality.isBad]) de forma continua durante [badSignalHold]
///    (3 s), sin pausar la partida.
///
/// Es determinista: se alimenta con el `dt` del motor, no con el reloj del
/// sistema, así que los tests controlan el tiempo exacto.
class SignalMonitor {
  SignalMonitor({
    this.packetTimeout = const Duration(milliseconds: 2500),
    this.badSignalHold = const Duration(seconds: 3),
  });

  /// Tiempo sin paquetes que dispara la pausa.
  final Duration packetTimeout;

  /// Tiempo de señal mala continua que dispara la banda de aviso.
  final Duration badSignalHold;

  double _sincePacket = 0;
  double _badFor = 0;
  int? _lastSeq;
  SignalWatchState _state = SignalWatchState.ok;
  SignalQuality _quality = SignalQuality.unknown;
  bool _paused = false;

  /// Estado actual del vigilante.
  SignalWatchState get state => _state;

  /// Última calidad observada (la pinta el chip del HUD).
  SignalQuality get quality => _quality;

  /// Segundos acumulados sin paquetes nuevos.
  double get secondsSincePacket => _sincePacket;

  /// Segundos acumulados con señal mala de forma continua.
  double get secondsBadSignal => _badFor;

  /// `true` si el vigilante pausó el motor por falta de paquetes.
  bool get paused => _paused;

  /// Banda de aviso visible (señal mala sostenida o enlace perdido).
  bool get showBanner => _state != SignalWatchState.ok;

  /// Pausa automática: SOLO por ausencia de paquetes.
  bool get shouldPause => _state == SignalWatchState.lost;

  /// El enlace sigue vivo (llegan paquetes), tenga la calidad que tenga.
  bool get linkAlive => _state != SignalWatchState.lost;

  double get _timeoutS => packetTimeout.inMicroseconds / 1e6;
  double get _badHoldS => badSignalHold.inMicroseconds / 1e6;

  /// Arranca el cómputo desde cero (inicio de partida o reconexión).
  ///
  /// Conserva el último `packetSeq` conocido para no contar como "paquete
  /// nuevo" uno que ya estaba recibido, y limpia acumuladores porque el
  /// jugador acaba de colocarse el casco.
  void start(EegData? eeg) {
    _lastSeq = eeg?.packetSeq;
    _sincePacket = 0;
    _badFor = 0;
    _quality = eeg?.signalQuality ?? SignalQuality.unknown;
    _state = _quality.isBad ? SignalWatchState.degraded : SignalWatchState.ok;
    _paused = false;
  }

  /// Avanza [dt] segundos con la lectura actual del dispositivo.
  ///
  /// Un paquete nuevo (aunque traiga `poorSignal = 200`) reinicia el contador
  /// de ausencia: "sin contacto" NO es "sin paquetes".
  SignalWatchState tick(EegData? eeg, double dt) {
    if (dt < 0) dt = 0;
    _sincePacket += dt;

    final seq = eeg?.packetSeq;
    final isNew = eeg != null && seq != null && seq != _lastSeq;
    if (isNew) {
      _lastSeq = seq;
      _sincePacket = 0;
    }

    _quality = eeg == null ? SignalQuality.unknown : eeg.signalQuality;

    if (_sincePacket >= _timeoutS) {
      // El enlace está mudo: pausa. El aviso de "mala calidad" deja de
      // acumular porque el diagnóstico ya no es de contacto sino de enlace.
      _state = SignalWatchState.lost;
    } else {
      if (_quality.isBad) {
        _badFor += dt;
      } else {
        _badFor = 0;
      }
      _state = _badFor >= _badHoldS
          ? SignalWatchState.degraded
          : SignalWatchState.ok;
    }

    if (_state == SignalWatchState.lost) _paused = true;
    return _state;
  }

  /// Consume la reconexión: devuelve `true` UNA vez si el motor estaba en
  /// pausa y han vuelto los paquetes.
  ///
  /// Basta con que el enlace esté vivo ([SignalWatchState.lost] superado),
  /// aunque la calidad siga siendo mala: pausamos por AUSENCIA de paquetes,
  /// no por umbral. Si el casco vuelve mal colocado, la partida se reanuda y
  /// la banda ámbar avisa de que hay que recolocarlo.
  bool takeResume() {
    if (!_paused || _state == SignalWatchState.lost) return false;
    _paused = false;
    return true;
  }
}
