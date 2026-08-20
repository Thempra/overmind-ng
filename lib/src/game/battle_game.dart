import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';

import '../eeg/eeg_data.dart';
import '../state/eeg_store.dart';

// ===========================================================================
//  Overmind — Fighting de EVAs 1v1 (FLAME)
//  Cada jugador (Eva) lanza bolas de fuego al rival. La mecánica está ligada
//  al EEG de cada jugador:
//    • ATENCIÓN   → velocidad y daño de las bolas de fuego (ataque)
//    • MEDITACIÓN → escudo regenerador que absorbe el daño recibido
//  Gana el primer Eva que deje el HP del rival a 0.
// ===========================================================================

class BattleGame extends FlameGame with TapCallbacks {
  BattleGame({
    required this.store,
    required this.player1Slot,
    required this.player2Slot,
  });

  final EegStore store;
  final int player1Slot;
  final int player2Slot;

  Fighter? player1;
  Fighter? player2;
  final List<Fireball> _fireballs = [];
  Hud? _hud;
  VsBanner? _vsBanner;
  AudioPlayer? _pew;
  AudioPlayer? _hit;
  bool _audioOk = false;

  double _shake = 0;
  double _vsTimer = 2.2;
  String? winner;

  bool get gameOver => winner != null;

  // Layout adaptativo: la resolución lógica se ajusta al aspecto real de la
  // pantalla (altura fija de referencia) para que la imagen rellene sin barras.
  static const double _refH = 1080;
  static const double _p1X = 0.14, _p2X = 0.86, _fy = 0.80;
  Vector2 _res = Vector2(1280, 720);
  SpriteComponent? _bg;

  @override
  Future<void> onLoad() async {
    final images = Flame.images;
    final bg = await images.load('game_background2.jpg');
    final eva = await images.load('eva01.png');
    final angel = await images.load('sachiel.png');
    final fbRed = await images.load('fireball.png');
    final fbBlue = await images.load('fireball_blue.png');

    _bg = SpriteComponent(sprite: Sprite(bg))
      ..position = Vector2.zero()
      ..priority = 0;
    add(_bg!);

    player1 = Fighter(
      image: eva,
      side: 1,
      facing: 1,
      centerHome: Vector2.zero(),
      flameColor: const Color(0xFF35B6FF),
      ballImage: fbBlue,
    )..priority = 5;
    player2 = Fighter(
      image: angel,
      side: 2,
      facing: -1,
      centerHome: Vector2.zero(),
      flameColor: const Color(0xFFFF4B4B),
      ballImage: fbRed,
    )..priority = 5;

    add(player1!);
    add(player2!);

    _hud = Hud()..priority = 40;
    add(_hud!);

    _vsBanner = VsBanner()..priority = 50;
    add(_vsBanner!);

    try {
      _pew = AudioPlayer();
      await _pew!.setSource(AssetSource('audio/pew_pew_lei.wav'));
      _hit = AudioPlayer();
      await _hit!.setSource(AssetSource('audio/pew_pew_lei.wav'));
      _audioOk = true;
    } catch (_) {
      _audioOk = false;
      _pew = null;
      _hit = null;
    }

    _layout();
    return super.onLoad();
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    _layout();
  }

  /// Recalcula la resolución lógica según el aspecto real y reposiciona todo.
  void _layout() {
    if (size.x <= 0 || size.y <= 0) return;
    _res = Vector2(size.x * _refH / size.y, _refH);
    camera.viewport = FixedResolutionViewport(resolution: _res);
    _bg?.size = _res;
    player1?.centerHome.setValues(_res.x * _p1X, _res.y * _fy);
    player2?.centerHome.setValues(_res.x * _p2X, _res.y * _fy);
    player1?.applyHome();
    player2?.applyHome();
    _hud?.size = _res;
    _vsBanner?.size = _res;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_vsTimer > 0 || gameOver) return;
    _spawn(player1!);
    _spawn(player2!);
  }

  void _spawn(Fighter f) {
    if (f.charge < 0.5) f.charge = 0.8; // el toque dispara enseguida
  }

  Fighter _opponentOf(Fighter f) =>
      (f.side == 1) ? player2! : player1!;

  void _fire(Fighter from) {
    final target = _opponentOf(from);
    final ball = Fireball(
      side: from.side,
      facing: from.facing,
      start: from.muzzle,
      targetY: target.center.y,
      power: from.attention,
      image: from.ballImage,
      color: from.flameColor,
    )..priority = 10;
    add(ball);
    _fireballs.add(ball);
    from.charge = 0;
    from.recoil = 0.15;
    _playFire();
  }

  void _playFire() {
    if (!_audioOk || _pew == null) return;
    try {
      _pew!.seek(Duration.zero);
      _pew!.resume();
    } catch (_) {}
  }

  void _explode(Vector2 at, Color color, double power) {
    add(ParticleSystemComponent(
      particle: Particle.generate(
        count: 24,
        lifespan: 0.6,
        generator: (i) {
          final ang = (i / 24) * 2 * math.pi;
          final speed = 120 + (power * 4) + (i % 5) * 60;
          return AcceleratedParticle(
            lifespan: 0.6,
            speed: Vector2(math.cos(ang), math.sin(ang)) * speed,
            acceleration: Vector2(0, 300),
            child: CircleParticle(
              paint: Paint()
                ..color = color.withOpacity(0.9 - (i % 4) * 0.2)
                ..blendMode = BlendMode.plus,
              radius: 6 + (i % 4) * 4,
            ),
          );
        },
      ),
      position: at,
    )..priority = 25);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _hud?.updateData(player1, player2);

    if (_vsTimer > 0) {
      _vsTimer -= dt;
      _vsBanner?.remaining = _vsTimer;
      return;
    }
    _vsBanner?.remaining = 0;
    if (gameOver) return;

    // Refrescar los datos EEG de cada luchador y lanzar bolas según atención.
    player1!.readEeg(store.devices[player1Slot]);
    player2!.readEeg(store.devices[player2Slot]);
    player1!.updateFighter(dt, _fire);
    player2!.updateFighter(dt, _fire);

    // Avanzar proyectiles y detectar impactos.
    final w = _res.x;
    for (final ball in _fireballs) {
      ball.move(dt);
      final target = _opponentOf(_fighterOf(ball)!);
      if (_hitTest(ball, target)) {
        _applyHit(target, ball);
        ball.removeFromParent();
      } else if (ball.position.x < -80 || ball.position.x > w + 80) {
        ball.removeFromParent();
      }
    }
    _fireballs.removeWhere((b) => b.parent == null);

    // Shake decay.
    if (_shake > 0) _shake = math.max(0, _shake - dt * 3);

    // ¿Alguien por debajo de 0?
    if (player1!.hp <= 0) _endGame(2);
    else if (player2!.hp <= 0) _endGame(1);
  }

  Fighter? _fighterOf(Fireball b) => b.side == 1 ? player1 : player2;

  bool _hitTest(Fireball ball, Fighter target) {
    final dx = (ball.position.x - target.center.x).abs();
    final dy = (ball.position.y - target.center.y).abs();
    final hitX = dx < target.size.x * 0.55;
    final hitY = dy < target.size.y * 0.5;
    return hitX && hitY;
  }

  void _applyHit(Fighter target, Fireball ball) {
    final dmg = (4 + ball.power * 0.16).clamp(2.0, 22.0).toDouble();
    final absorbed = target.takeDamage(dmg);
    _explode(ball.position.clone(), ball.color, ball.power / 10 + 1);
    _shake = 8;
    _hud!.flash(ball.side, absorbed > 0);
    if (!_audioOk || _hit == null) return;
    try {
      _hit!.seek(Duration.zero);
      _hit!.resume();
    } catch (_) {}
  }

  void _endGame(int winnerSide) {
    winner = winnerSide == 1 ? 'Eva-01 gana' : 'Sachiel gana';
    overlays.add('gameOver');
  }

  void restart() {
    winner = null;
    _vsTimer = 2.2;
    player1!.reset();
    player2!.reset();
    for (final b in _fireballs) {
      b.removeFromParent();
    }
    _fireballs.clear();
    overlays.remove('gameOver');
  }

  @override
  void render(Canvas canvas) {
    if (_shake > 0) {
      final dx = (math.Random().nextDouble() - 0.5) * _shake;
      final dy = (math.Random().nextDouble() - 0.5) * _shake;
      canvas.translate(dx, dy);
      super.render(canvas);
      canvas.translate(-dx, -dy);
    } else {
      super.render(canvas);
    }
  }

  void shutdown() {
    _pew?.dispose();
    _hit?.dispose();
    _fireballs.clear();
  }
}

// ===========================================================================
//  Fighter — cada Eva con aura, escudo y medidores EEG
// ===========================================================================
class Fighter extends PositionComponent {
  Fighter({
    required Image image,
    required this.side,
    required this.facing,
    required this.centerHome,
    required this.flameColor,
    required this.ballImage,
  })  : image = image,
        super(
          size: Vector2(
            image.width.toDouble() * 1.15,
            image.height.toDouble() * 1.15,
          ),
        ) {
    position = centerHome - size / 2;
  }

  final Image image;
  final int side;
  final int facing; // 1 = mira a la derecha, -1 = a la izquierda
  final Vector2 centerHome;
  final Color flameColor;
  final Image ballImage;

  double hp = 100;
  double shield = 0;
  double attention = 0;
  double meditation = 0;
  double charge = 0;
  double recoil = 0;
  double hitFlash = 0;
  double _bob = 0;
  double _pulse = 0;

  Vector2 get center => position.clone() + size / 2;
  Vector2 get muzzle => Vector2(
        center.x + facing * size.x * 0.45,
        center.y - size.y * 0.15,
      );

  void readEeg(EegData? eeg) {
    attention = eeg?.attention.toDouble() ?? 0;
    meditation = eeg?.meditation.toDouble() ?? 0;
  }

  /// Actualiza velocidad de carga (atención) y escudo (meditación).
  void updateFighter(double dt, void Function(Fighter) fire) {
    _bob += dt * 2;
    _pulse += dt * 3;

    // Escudo tiende a la meditación (0..100).
    shield = shield + (meditation - shield) * dt * 1.2;
    if (shield < 0) shield = 0;

    // Carga de bola según atención: más atención ⇒ dispara más rápido.
    charge += dt * (0.35 + attention / 100 * 2.6);
    if (charge >= 1.0) {
      fire(this);
    }

    if (recoil > 0) recoil -= dt;
    if (hitFlash > 0) hitFlash -= dt;

    // Pequeña flotación "idle".
    position.y = (centerHome.y - size.y / 2) + math.sin(_bob) * 10;
  }

  void reset() {
    hp = 100;
    shield = 0;
    charge = 0;
    position.setFrom(centerHome - size / 2);
  }

  /// Sitúa al luchador en su posición base (usado al re-posicionar el layout).
  void applyHome() {
    position.setFrom(centerHome - size / 2);
  }

  /// Aplica daño teniendo en cuenta el escudo. Devuelve el daño absorbido.
  double takeDamage(double dmg) {
    hitFlash = 0.18;
    final absorbed = math.min(shield, dmg);
    shield -= absorbed;
    final real = dmg - absorbed;
    hp = math.max(0, hp - real);
    return absorbed;
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final t = _pulse;

    // ---- Aura exterior (glow) que crece con la atención ----
    final auraR =
        size.x * (0.75 + (attention / 100) * 0.55 + math.sin(t) * 0.04);
    final auraPaint = Paint()
      ..shader = Gradient.radial(
        Offset(cx, cy),
        auraR,
        [
          flameColor.withOpacity(0.30 + (attention / 100) * 0.3),
          flameColor.withOpacity(0.02),
        ],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(cx, cy), auraR, auraPaint);

    // ---- Anillo de escudo (meditación) ----
    if (shield > 1) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 + shield * 0.05
        ..color = const Color(0xFFB0F7FF).withOpacity(0.35 + shield / 100 * 0.5)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(cx, cy), size.x * 0.62, ring);
    }

    // ---- Sprite del Eva ----
    final flash = hitFlash > 0;
    final spritePaint = Paint();
    if (flash) {
      spritePaint.colorFilter = const ColorFilter.matrix(<double>[
        2, 0, 0, 0, -128,
        0, 1, 0, 0, 0,
        0, 0, 2, 0, -128,
        0, 0, 0, 1, 0,
      ]);
    }
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = facing < 0
        ? Rect.fromLTWH(size.x, 0, -size.x, size.y)
        : Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawImageRect(image, src, dst, spritePaint);

    // Destello en la boca al disparar (recoil).
    if (recoil > 0) {
      final fp = Paint()
        ..color = flameColor.withOpacity(recoil * 4)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(
        Offset(muzzle.x - position.x, muzzle.y - position.y),
        size.x * 0.18,
        fp,
      );
    }

    // ---- Medidores sobre la cabeza ----
    drawMeter(canvas, cx, -30, attention / 100, flameColor, 'ATN');
    drawMeter(canvas, cx, -54, shield / 100, const Color(0xFFB0F7FF), 'MDT');
  }

  void drawMeter(Canvas canvas, double cx, double y, double frac, Color color,
      String label) {
    final w = size.x * 0.62;
    const h = 12.0;
    final x = cx - w / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(6)),
      Paint()..color = const Color(0x66000000),
    );
    final fill = (frac * w).clamp(0.0, w);
    final gp = Paint()
      ..shader = Gradient.linear(
        Offset(x, 0),
        Offset(x + w, 0),
        [color.withOpacity(0.6), color],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, fill, h), const Radius.circular(6)),
      gp,
    );
  }
}

// ===========================================================================
//  Fireball — bola de fuego con glow y tamaño según el poder (atención)
// ===========================================================================
class Fireball extends PositionComponent {
  Fireball({
    required this.side,
    required this.facing,
    required Vector2 start,
    required this.targetY,
    required this.power,
    required this.image,
    required this.color,
  }) : super(
          position: start,
          anchor: Anchor.center,
          size: Vector2.all(70 * (1 + power / 100)),
        );

  final int side;
  final int facing;
  final double targetY;
  final double power;
  final Image image;
  final Color color;

  double _t = 0;

  void move(double dt) {
    _t += dt;
    position += Vector2(
          facing * (520 + power * 3),
          (targetY - position.y) * 2,
        ) *
        dt;
  }

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final c = Offset(size.x / 2, size.y / 2);

    // Glow externo (aditivo, pulsante).
    final glow = Paint()
      ..shader = Gradient.radial(
        c,
        r * 1.6,
        [
          color.withOpacity(0.55 + math.sin(_t * 12) * 0.15),
          color.withOpacity(0.0),
        ],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c, r * 1.6, glow);

    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawImageRect(image, src, dst, Paint());

    // Núcleo brillante central.
    final core = Paint()
      ..shader = Gradient.radial(
        c,
        r * 0.7,
        [
          const Color(0xFFFFFFFF),
          color.withOpacity(0.9),
          color.withOpacity(0.0),
        ],
        [0.0, 0.5, 1.0],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c, r * 0.7, core);
  }
}

// ===========================================================================
//  Hud — barras de vida, nombres y valores EEG en tiempo real
// ===========================================================================
class Hud extends PositionComponent {
  Fighter? p1;
  Fighter? p2;
  double flashP1 = 0, flashP2 = 0;
  double shieldP1 = 0, shieldP2 = 0;

  void updateData(Fighter? a, Fighter? b) {
    p1 = a;
    p2 = b;
    if (flashP1 > 0) flashP1 -= 0.06;
    if (flashP2 > 0) flashP2 -= 0.06;
    if (shieldP1 > 0) shieldP1 -= 0.06;
    if (shieldP2 > 0) shieldP2 -= 0.06;
  }

  void flash(int side, bool absorbed) {
    if (side == 1) flashP1 = 1; else flashP2 = 1;
    if (absorbed) {
      if (side == 1) shieldP1 = 1; else shieldP2 = 1;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final top = 34.0;
    final barW = w * 0.38;
    const barH = 34.0;

    _bar(canvas, 40, top, barW, p1?.hp ?? 0, const Color(0xFF35B6FF),
        flashP1, true);
    _bar(canvas, w - 40 - barW, top, barW, p2?.hp ?? 0,
        const Color(0xFFFF4B4B), flashP2, false);

    // Shield mini-bar debajo de cada barra.
    _miniBar(canvas, 40, top + barH + 8, barW, p1?.shield ?? 0,
        const Color(0xFFB0F7FF), shieldP1);
    _miniBar(canvas, w - 40 - barW, top + barH + 8, barW, p2?.shield ?? 0,
        const Color(0xFFB0F7FF), shieldP2);

    // Nombres.
    drawText(canvas, 'EVA-01', 40, top - 30, 26, const Color(0xFF35B6FF), 400);
    drawText(canvas, 'SACHIEL', w - 40 - 300, top - 30, 26,
        const Color(0xFFFF4B4B), 300,
        alignRight: true);

    // Valores EEG en vivo.
    if (p1 != null) {
      drawText(
          canvas,
          'ATN ${p1!.attention.round()}  MDT ${p1!.meditation.round()}',
          40, top + barH + 34, 20, const Color(0xFFE6E6E6), 420);
    }
    if (p2 != null) {
      drawText(
          canvas,
          'ATN ${p2!.attention.round()}  MDT ${p2!.meditation.round()}',
          w - 40 - 420, top + barH + 34, 20, const Color(0xFFE6E6E6), 420,
          alignRight: true);
    }

    // Línea decorativa del HUD.
    final line = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, top + barH + 60), Offset(w, top + barH + 60),
        line);
  }

  void _bar(Canvas canvas, double x, double y, double w, double hp,
      Color color, double flash, bool left) {
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, 34), const Radius.circular(8));
    canvas.drawRRect(r, Paint()..color = const Color(0xB0000000));
    final frac = (hp / 100).clamp(0.0, 1.0);
    final fillW = w * frac;
    final gp = Paint()
      ..shader = Gradient.linear(
        Offset(x, 0),
        Offset(x + w, 0),
        [color.withOpacity(0.6), color.withOpacity(0.3), color],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, fillW, 34), const Radius.circular(8)),
        gp);
    if (flash > 0) {
      canvas.drawRRect(r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFFFFF).withOpacity(flash));
    }
    drawText(canvas, '${hp.toStringAsFixed(0)}', x, y + 4, 24,
        const Color(0xFFFFFFFF), 60,
        alignRight: !left);
  }

  void _miniBar(Canvas canvas, double x, double y, double w, double val,
      Color color, double flash) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, 8),
            const Radius.circular(4)),
        Paint()..color = const Color(0x66000000));
    final fill = ((val / 100) * w).clamp(0.0, w);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, fill, 8),
            const Radius.circular(4)),
        Paint()..color = color);
  }

  void drawText(Canvas canvas, String text, double x, double y, double size,
      Color color, double width,
      {bool alignRight = false}) {
    final pb = ParagraphBuilder(ParagraphStyle(
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
    ));
    pb.pushStyle(TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w800,
      shadows: const [
        Shadow(
            color: Color(0xAA000000), blurRadius: 4, offset: Offset(1, 1)),
      ],
    ));
    pb.addText(text);
    final para = pb.build()
      ..layout(ParagraphConstraints(width: width));
    canvas.drawParagraph(para, Offset(x, y));
  }
}

// ===========================================================================
//  VsBanner — cartel de presentación del combate (EVA-01 vs SACHIEL)
// ===========================================================================
class VsBanner extends PositionComponent {
  /// Tiempo restante del cartel; el juego lo actualiza cada frame.
  double remaining = 2.2;

  @override
  void render(Canvas canvas) {
    if (remaining <= 0) return;
    final cx = size.x / 2;
    final cy = size.y * 0.40;
    final alpha = remaining < 0.6 ? (remaining / 0.6).clamp(0.0, 1.0) : 1.0;

    // Scrim oscuro para hacer resaltar el cartel.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Color(0x66000000).withOpacity(alpha));

    // Líneas decorativas horizontales.
    final line = Paint()
      ..color = Color(0x88FFFFFF).withOpacity(alpha)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, cy + 40), Offset(cx - 40, cy + 40), line..strokeWidth = 3);
    canvas.drawLine(Offset(cx + 40, cy + 40), Offset(size.x, cy + 40), line..strokeWidth = 3);

    _text(canvas, 'EVA-01', cx - 340, cy - 30, 54, Color(0xFF35B6FF).withOpacity(alpha), 320, TextAlign.right);
    _text(canvas, 'VS', cx - 60, cy - 16, 72, Color(0xFFFFFFFF).withOpacity(alpha), 120, TextAlign.center);
    _text(canvas, 'SACHIEL', cx + 20, cy - 30, 54, Color(0xFFFF4B4B).withOpacity(alpha), 320, TextAlign.left);

    if (remaining < 1.1) {
      final pulse = 0.7 + 0.3 * math.sin(remaining * 22);
      _text(canvas, '¡PELEA!', cx - 150, cy + 70, 46,
          Color(0xFFFFFF00).withOpacity(alpha * pulse), 300, TextAlign.center);
    }
  }

  void _text(Canvas canvas, String text, double x, double y, double size,
      Color color, double width, TextAlign align) {
    final pb = ParagraphBuilder(ParagraphStyle(textAlign: align));
    pb.pushStyle(TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w900,
      shadows: const [
        Shadow(color: Color(0xDD000000), blurRadius: 6, offset: Offset(2, 2)),
      ],
    ));
    pb.addText(text);
    final para = pb.build()..layout(ParagraphConstraints(width: width));
    canvas.drawParagraph(para, Offset(x, y));
  }
}
