import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../eeg/eeg_data.dart';
import '../mind_game_session.dart';

// ===========================================================================
//  HALCÓN — parpadeo como reflejo (10-99 años).
//  El parpadeo es la señal más rápida y fiable del MindWave (~0,5 s).
//  Objetivos (cometas) aparecen en el cielo con una mecha que se apaga:
//  parpadea mientras la mecha está encendida para derribarlos. Acertar en
//  la ventana estrecha (núcleo) da bonus. Racha de aciertos = multiplicador.
//  Es el "whack-a-mole" del EEG: micro-loop acierto->premio <1 s.
// ===========================================================================
class FalconLogic extends GameLogic {
  FalconLogic({required this.eeg});

  final EegData? eeg;

  final _rng = math.Random();
  final List<_Comet> _comets = [];
  int _hits = 0, _cores = 0, _misses = 0, _combo = 0, _bestCombo = 0;
  int _score = 0;
  double _spawnT = 0;
  int _lastBlinkSeq = 0;
  AudioPlayer? _sfx;
  _FalconView? _view;

  @override
  Future<void> build(FlameGame game, Vector2 size) async {
    _view = _FalconView(comets: _comets)..priority = 5;
    game.add(_view!);
    try {
      _sfx = AudioPlayer();
      await _sfx!.setSource(AssetSource('audio/pew_pew_lei.wav'));
    } catch (_) {
      _sfx = null;
    }
    _lastBlinkSeq = eeg?.blinkSeq ?? 0;
  }

  void _fire() {
    // Derriba el objetivo más cercano a explotar (mecha más corta viva).
    _Comet? target;
    for (final c in _comets) {
      if (!c.dead && c.life > 0 && (target == null || c.life < target.life)) {
        target = c;
      }
    }
    if (target == null) {
      _combo = 0; // parpadeo al vacío
      return;
    }
    target.dead = true;
    final core = target.life > target.dur * 0.35 &&
        target.life < target.dur * 0.75; // ventana central
    _hits++;
    _combo++;
    if (_combo > _bestCombo) _bestCombo = _combo;
    if (core) _cores++;
    final mult = math.min(5, 1 + _combo ~/ 4);
    _score += (core ? 150 : 60) * mult;
    _sfx?.seek(Duration.zero);
    _sfx?.resume();
  }

  @override
  void update(double dt, double t) {
    // Parpadeo -> disparo (solo secuencias nuevas de blink).
    if (eeg != null && eeg!.blinkSeq != _lastBlinkSeq) {
      _lastBlinkSeq = eeg!.blinkSeq;
      _fire();
    }
    // Spawn con rampa: más frecuentes y con menos mecha hacia el final.
    _spawnT -= dt;
    final progress = (t / 90).clamp(0.0, 1.0);
    final interval = 1.6 - progress * 0.7;
    if (_spawnT <= 0) {
      _spawnT = interval * (0.7 + _rng.nextDouble() * 0.6);
      final dur = 2.6 - progress * 0.9;
      final w = _view?.size.x ?? 1280, h = _view?.size.y ?? 720;
      _comets.add(_Comet(
        Vector2(w * (0.1 + _rng.nextDouble() * 0.8),
            h * (0.15 + _rng.nextDouble() * 0.5)),
        dur,
      ));
    }
    for (final c in _comets) {
      if (!c.dead) {
        c.life -= dt;
        if (c.life <= 0) {
          c.dead = true;
          c.life = 0;
          _misses++;
          _combo = 0;
        }
      } else {
        c.fade += dt;
      }
    }
    _comets.removeWhere((c) => c.dead && c.fade > 0.4);
    _view?.combo = _combo;
  }

  @override
  double meterValue() => (_combo % 5) / 4;

  @override
  int score() => _score;

  @override
  void dispose() {
    _sfx?.dispose();
  }
}

class _Comet {
  _Comet(this.pos, this.dur)
      : hue = 180 + (pos.y * 0.7) % 140,
        life = dur;
  final Vector2 pos;
  final double dur;
  final double hue;
  double life;
  double fade = 0;
  bool dead = false;
}

class _FalconView extends PositionComponent {
  _FalconView({required this.comets});
  final List<_Comet> comets;
  int combo = 0;
  double _t = 0;

  @override
  void onGameResize(Vector2 c) {
    super.onGameResize(c);
    size = c;
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final g = Gradient.linear(Offset.zero, Offset(0, size.y),
        [const Color(0xFF050A18), const Color(0xFF101A33)]);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..shader = g);
    // estrellas fakes
    for (var i = 0; i < 40; i++) {
      final x = (i * 97.3) % size.x, y = (i * 61.7) % (size.y * 0.7);
      canvas.drawCircle(Offset(x, y), 1, Paint()..color = const Color(0x3FFFFFFF));
    }
    for (final c in comets) {
      final frac = (c.life / c.dur).clamp(0.0, 1.0);
      final r = size.x * 0.035;
      final pulse = c.dead ? 1.6 : 1.0 + math.sin(_t * 8 + c.pos.x) * 0.06;
      final col = (_hsla(c.dead ? 0.25 : 1.0, c.hue, 0.8, 0.6));
      // halo de la ventana central (núcleo)
      if (!c.dead) {
        canvas.drawCircle(
            c.pos.toOffset(),
            r * 2.4,
            Paint()
              ..color = const Color(0x1AFFFFFF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * (0.9 * _coreWindow(frac)));
      }
      canvas.drawCircle(
          c.pos.toOffset(),
          r * pulse,
          Paint()
            ..color = c.dead
                ? col.withOpacity(0.3)
                : col);
      // mecha que se consume
      if (!c.dead) {
        final arc = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
            Rect.fromCircle(center: c.pos.toOffset(), radius: r * 1.7),
            -math.pi / 2,
            math.pi * 2 * frac,
            false,
            arc);
      }
    }
    if (combo >= 4) {
      final pb = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center));
      pb.pushStyle(TextStyle(
        color: const Color(0xFFFFD54F),
        fontSize: 30,
        fontWeight: FontWeight.w900,
        shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 4)],
      ));
      pb.addText('x${math.min(5, 1 + combo ~/ 4)}');
      final para = pb.build()..layout(ParagraphConstraints(width: size.x));
      canvas.drawParagraph(para, Offset(0, size.y * 0.86));
    }
  }

  /// Grosor de la diana central cuando toca la ventana de bonus.
  double _coreWindow(double frac) => (frac > 0.35 && frac < 0.75) ? 1.0 : 0.15;

  /// Color desde HSL (evita depender de Flutter dentro del motor).
  Color _hsla(double a, double h, double s, double l) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final hp = (h % 360) / 60;
    final x = c * (1 - (hp % 2 - 1).abs());
    final m = l - c / 2;
    double r = 0, g = 0, b = 0;
    if (hp < 1) { r = c; g = x; } else if (hp < 2) { r = x; g = c; }
    else if (hp < 3) { g = c; b = x; } else if (hp < 4) { g = x; b = c; }
    else if (hp < 5) { r = x; b = c; } else { r = c; b = x; }
    int ch(double v) => ((v + m) * 255).clamp(0, 255).round();
    return Color.fromARGB((a * 255).round(), ch(r), ch(g), ch(b));
  }
}
