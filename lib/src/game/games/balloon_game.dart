import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../eeg/eeg_data.dart';
import '../mind_game_session.dart';
import '../signal_processor.dart';

// ===========================================================================
//  GLOBO — calma sostenida (meditación). 6-14 años.
//  Protocolo clínico de "globos" gamificado: mantén la meditación por encima
//  del umbral adaptativo y el globo se infla; por debajo, se desinfla.
//  Cada "POP" = micro-recompensa (<1 s) + puntos. Umbral = baseline+8 con
//  histéresis; baja si encadenas fallos, sube si vas sobrado (flow).
// ===========================================================================

const _white = Color(0xFFFFFFFF);
const _white54 = Color(0x8AFFFFFF);

class BalloonLogic extends GameLogic {
  BalloonLogic({required this.eeg, required this.cal});

  final EegData? eeg;
  final Calibrator cal;

  late AdaptiveThreshold _adaptive;
  final Hysteresis _zone = Hysteresis();
  double _smooth = 0;
  double _inflate = 0; // 0..1 tamaño actual
  int _pops = 0;

  final _rng = math.Random();
  AudioPlayer? _pop;

  late Vector2 _size;
  late _Balloon _balloon;
  FlameGame? _game;

  @override
  Future<void> build(FlameGame game, Vector2 size) async {
    _size = size;
    _game = game;
    _adaptive = AdaptiveThreshold(math.max(30.0, cal.medMean + 8));
    _smooth = eeg?.meditation.toDouble() ?? cal.medMean;

    try {
      _pop = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await _pop!.setSource(AssetSource('audio/pew_pew_lei.wav'));
    } catch (_) {
      _pop = null;
    }

    final sky = _Sky()..priority = 0;
    _balloon = _Balloon(color: const Color(0xFFFF6B9D))..priority = 5;
    game.addAll([sky, _balloon]);
  }

  @override
  void update(double dt, double t) {
    final med = eeg?.meditation.toDouble() ?? 50;
    _smooth = SignalProcessor.ema(_smooth, med, 0.25);
    final th = _adaptive.value;
    final inZone = _zone.feed(_smooth, th, th - 8);
    _adaptive.tick(dt, inZone, min: 25, max: 85);

    if (inZone) {
      _inflate = math.min(1, _inflate + dt / 4.5); // ~4.5 s para llenar
    } else {
      _inflate = math.max(0, _inflate - dt / 2.0);
    }
    _balloon.settle = _inflate;

    if (_inflate >= 1) {
      _pops++;
      _inflate = 0.15;
      final fx = _BurstEffect()..priority = 30;
      // Añadirlo al árbol ANTES de spawnAt: este usa `game` (HasGameReference).
      _game?.add(fx);
      fx.spawnAt(Vector2(_size.x / 2, _size.y * 0.55), _rng);
      _pop?.seek(Duration.zero);
      _pop?.resume();
    }

    _balloon.score = _pops * 50;
  }

  @override
  double meterValue() => (eeg?.meditation ?? 0) / 100;

  @override
  int score() => _pops * 50;

  @override
  void dispose() {
    _pop?.dispose();
  }
}

class _Sky extends PositionComponent {
  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    size = canvasSize;
  }

  @override
  void render(Canvas canvas) {
    final g = Gradient.linear(
      Offset.zero,
      Offset(0, size.y),
      [const Color(0xFF0B1E3A), const Color(0xFF2A4A7B)],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..shader = g);
  }
}

class _Balloon extends PositionComponent {
  _Balloon({required this.color});
  final Color color;
  double settle = 0;
  double _bob = 0;
  int score = 0;

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    size = canvasSize;
  }

  @override
  void update(double dt) {
    _bob += dt;
  }

  @override
  void render(Canvas canvas) {
    final r = size.x * 0.10 + settle * size.x * 0.14;
    final cx = size.x / 2;
    final cy = size.y * 0.55 + math.sin(_bob * 1.4) * 8;
    // cuerda
    final path = Path()
      ..moveTo(cx, cy + r)
      ..quadraticBezierTo(
          cx + math.sin(_bob * 2) * 14, cy + r + 40, cx, cy + r + 80);
    canvas.drawPath(
        path, Paint()..color = _white54..strokeWidth = 2);
    // globo con brillo
    final grad = Gradient.radial(Offset(cx - r * 0.35, cy - r * 0.35),
        r * 1.6, [Color.lerp(color, _white, 0.55)!, color]);
    canvas.drawCircle(Offset(cx, cy), r, Paint()..shader = grad);
    // nudo
    final knot = Path()
      ..moveTo(cx - 6, cy + r)
      ..lineTo(cx + 6, cy + r)
      ..lineTo(cx, cy + r + 10)
      ..close();
    canvas.drawPath(knot, Paint()..color = color);
    // puntuación
    final pb = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center));
    pb.pushStyle(TextStyle(
      color: _white,
      fontSize: 40,
      fontWeight: FontWeight.w900,
      shadows: [Shadow(color: color.withOpacity(0.7), blurRadius: 16)],
    ));
    pb.addText('$score');
    final para = pb.build()..layout(ParagraphConstraints(width: size.x));
    canvas.drawParagraph(para, const Offset(0, 16));
  }
}

/// Explosión de partículas al inflar del todo (POP).
class _BurstEffect extends PositionComponent
    with HasGameReference<FlameGame> {
  final List<_Particle> _ps = [];
  double _life = 0;

  void spawnAt(Vector2 pos, math.Random rng) {
    position = pos;
    for (var i = 0; i < 26; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final v = 120 + rng.nextDouble() * 380;
      _ps.add(_Particle(
          Vector2(math.cos(a) * v, math.sin(a) * v),
          const Color(0xFFFF6B9D).withOpacity(0.5 + rng.nextDouble() * 0.5),
          4 + rng.nextDouble() * 6));
    }
  }

  @override
  void update(double dt) {
    _life += dt;
    for (final p in _ps) {
      p.pos += p.vel * dt;
      p.vel.y += 300 * dt;
    }
    if (_life > 0.9) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    for (final p in _ps) {
      canvas.drawCircle(p.pos.toOffset(), math.max(0, p.r * (1 - _life / 0.9)),
          Paint()..color = p.color);
    }
  }
}

class _Particle {
  _Particle(this.vel, this.color, this.r);
  final Vector2 vel;
  final Color color;
  final double r;
  Vector2 pos = Vector2.zero();
}
