import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../eeg/eeg_data.dart';
import '../i18n/l10n.dart';
import '../state/eeg_store.dart';
import '../state/progress_controller.dart';
import 'signal_processor.dart';

/// Contrato de la lógica de un minijuego mental.
abstract class GameLogic {
  final List<Component> layers = [];

  /// Construye componentes (debe añadirlos a [game] y a [layers]).
  Future<void> build(FlameGame game, Vector2 size);

  /// Llamado por el scaffold en cada frame de la fase de juego.
  void update(double dt, double t);

  /// 0..1 para el medidor de señal superior.
  double meterValue();

  /// Puntuable en la fase de resultados.
  int score();

  /// Cierra recursos.
  void dispose() {}
}

/// Scaffold común: calibración (5 s) → juego (duración) → resultados con
/// récord. Todos los juegos mentales de la plataforma lo usan.
class MindGameSession extends StatefulWidget {
  const MindGameSession({
    super.key,
    required this.gameId,
    required this.title,
    required this.accent,
    required this.calibrateInstruction,
    required this.durationSec,
    required this.slots,
    required this.logicBuilder,
  });

  final String gameId;
  final String title;
  final Color accent;
  final String calibrateInstruction;
  final int durationSec;
  final List<int> slots;

  /// Recibe los EEG (1 o 2, pueden ser null) y el calibrador con el baseline.
  final GameLogic Function(List<EegData?> eegs, Calibrator cal) logicBuilder;

  @override
  State<MindGameSession> createState() => _MindGameSessionState();
}

enum _Phase { calibrate, play, results }

class _MindGameSessionState extends State<MindGameSession> {
  late final _SessionGame _game;
  late GameLogic _logic;
  late final List<EegData?> _eegs;
  _Phase _phase = _Phase.calibrate;
  double _t = 0;
  int _finalScore = 0;
  bool _isRecord = false;

  final Calibrator _cal = Calibrator();
  double _calT = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final store = context.read<EegStore>();
    _eegs = widget.slots.map((s) => store.devices[s]).toList();
    _logic = _PlaceholderLogic();
    _game = _SessionGame(onTick: _tick, ensureLogic: () => _logic);
  }

  void _tick(double dt) {
    switch (_phase) {
      case _Phase.calibrate:
        _calT += dt;
        final e = _eegs.firstWhere(
            (e) => e != null, orElse: () => _eegs.first);
        if (e != null) _cal.add(e.attention.toDouble(), e.meditation.toDouble());
        if (_calT >= 5) {
          // Calibración hecha: crear la lógica real del juego.
          _logic = widget.logicBuilder(_eegs, _cal);
          _game.swapLogic(_logic);
          setState(() {
            _phase = _Phase.play;
            _t = 0;
          });
        }
        break;
      case _Phase.play:
        _t += dt;
        _logic.update(dt, _t);
        if (_t >= widget.durationSec) _finish();
        break;
      case _Phase.results:
        break;
    }
  }

  void _finish() {
    final s = _logic.score();
    final rec = context.read<ProgressController>().record(widget.gameId, s);
    setState(() {
      _finalScore = s;
      _isRecord = rec;
      _phase = _Phase.results;
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _logic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleController>().s;
    final progress = context.watch<ProgressController>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      if (_phase == _Phase.play)
                        Text(
                          '${(widget.durationSec - _t).ceil()}s · ${_logic.score()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(s.leave,
                            style: const TextStyle(color: Colors.white54)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          if (_phase == _Phase.calibrate) _calibrationOverlay(),
          if (_phase == _Phase.results)
            _resultsOverlay(context, progress, s),
        ],
      ),
    );
  }

  Widget _calibrationOverlay() {
    final pct = (_calT / 5 * 100).round();
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_heart_outlined, size: 48, color: widget.accent),
            const SizedBox(height: 16),
            Text(
              widget.calibrateInstruction,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 260,
              child: LinearProgressIndicator(
                value: _calT / 5,
                minHeight: 10,
                color: widget.accent,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 8),
            Text('$pct%', style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _resultsOverlay(
      BuildContext context, ProgressController progress, AppStrings s) {
    final best = progress.best[widget.gameId] ?? 0;
    return Container(
      color: Colors.black.withOpacity(0.82),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF10141C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.accent.withOpacity(0.7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isRecord ? '¡NUEVO RÉCORD!' : 'FIN',
                style: TextStyle(
                  color: _isRecord ? widget.accent : Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text('$_finalScore',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w900)),
              Text('récord: $best · racha: ${progress.streakDays} días',
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 20),
              Row(mainAxisSize: MainAxisSize.min, children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: widget.accent),
                  onPressed: _restart,
                  child: Text(s.rematch),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.leave,
                      style: const TextStyle(color: Colors.white70)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _restart() {
    setState(() {
      _phase = _Phase.calibrate;
      _calT = 0;
      _cal.attention.clear();
      _cal.meditation.clear();
    });
    final old = _logic;
    _logic = _PlaceholderLogic();
    _game.swapLogic(_logic, disposeOld: old);
    old.dispose();
  }
}

/// Lógica vacía que solo hay durante la calibración.
class _PlaceholderLogic implements GameLogic {
  @override
  final layers = <Component>[];
  @override
  Future<void> build(FlameGame game, Vector2 size) async {}
  @override
  void update(double dt, double t) {}
  @override
  int score() => 0;
  @override
  double meterValue() => 0;
  @override
  void dispose() {}
}

/// FlameGame genérico del scaffold: tick + intercambio de lógica.
class _SessionGame extends FlameGame {
  _SessionGame({required this.onTick, required this.ensureLogic});

  final void Function(double dt) onTick;
  final GameLogic Function() ensureLogic;

  @override
  Color backgroundColor() => const Color(0xFF0A0E16);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _current?.build(this, size);
  }

  GameLogic? _current;

  void setCurrent(GameLogic logic) => _current = logic;

  void swapLogic(GameLogic logic, {GameLogic? disposeOld}) {
    if (disposeOld != null) {
      for (final c in disposeOld.layers) {
        if (c.parent != null) c.removeFromParent();
      }
      disposeOld.layers.clear();
    }
    logic.build(this, size);
    setCurrent(logic);
  }

  @override
  void update(double dt) {
    super.update(dt);
    onTick(dt);
  }
}
