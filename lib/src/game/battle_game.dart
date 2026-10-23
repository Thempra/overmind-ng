import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';

import '../ble/mind_source.dart';
import '../eeg/signal_quality.dart';
import '../i18n/l10n.dart';
import '../state/eeg_store.dart';
import 'battle_logic.dart';
import 'battle_theme.dart';
import 'signal_chip.dart';
import 'signal_monitor.dart';

// ===========================================================================
//  Overmind — Fighting 1v1 (FLAME)
//  Cada jugador lanza bolas de fuego al rival. La mecánica está ligada
//  al EEG de cada jugador:
//    • ATENCIÓN   → cadencia y daño de las bolas de fuego (ataque)
//    • MEDITACIÓN → escudo fraccional que absorbe parte del daño recibido
//  Gana el primero que deje el HP del rival a 0, o quien tenga más HP al
//  agotarse el tiempo (muerte súbita a los 80 s, empate posible).
//
//  La SIMULACIÓN vive en `battle_logic.dart` (pura, testeable headless);
//  este fichero solo pinta el estado y dispara el audio.
//  El aspecto (fondo, avatares, colores, nombres) lo define un [BattleTheme].
// ===========================================================================

class BattleGame extends FlameGame with TapCallbacks {
  BattleGame({
    required this.store,
    required this.player1Slot,
    required this.player2Slot,
    this.theme = BattleTheme.neon,
    this.tuning = const BattleTuning(),
    this.strings = AppStrings.es,
  });

  final EegStore store;
  final int player1Slot;
  final int player2Slot;
  final BattleTheme theme;

  /// Ajustes de balance del duelo (ver [BattleTuning]).
  final BattleTuning tuning;

  /// Textos ES/EN de la banda de aviso y del overlay de reconexión.
  final AppStrings strings;

  /// Vigilantes de señal: uno por jugador. Pausan el motor SOLO por ausencia
  /// de paquetes (2,5 s), nunca por umbral de `poorSignal`.
  final SignalMonitor monitor1 = SignalMonitor();
  final SignalMonitor monitor2 = SignalMonitor();

  /// `true` mientras la partida está detenida esperando al casco.
  ///
  /// OJO: no se llama `paused` porque [FlameGame] ya expone ese nombre (y
  /// desactivaría el propio `update` del juego, incluido el watchdog).
  bool get signalPaused => logic.paused;

  /// Simulación pura del duelo: sin Flame, sin Canvas, sin audio.
  late final BattleLogic logic = BattleLogic(tuning: tuning);

  Fighter? player1;
  Fighter? player2;
  final List<Fireball> _fireballs = [];
  Hud? _hud;
  VsBanner? _vsBanner;
  SignalOverlay? _signalOverlay;
  AudioPlayer? _pew;
  AudioPlayer? _hit;
  bool _audioOk = false;

  double _shake = 0;
  double _vsTimer = 2.2;
  String? winner;

  bool get gameOver => winner != null;

  // El juego usa el tamaño REAL del widget (coordenadas = píxeles lógicos del
  // dispositivo, viewport MaxViewport 1:1). Todos los elementos se escalan con
  // `k = altura/1080` para que el combate rellene y se vea proporcional en
  // cualquier pantalla (móvil, tablet, desktop), sin barras ni distorsión.
  static const double _refH = 1080;
  double _k = 1;
  Vector2 _res = Vector2(1280, 720);
  SpriteComponent? _bg;

  double get k => _k;

  @override
  Future<void> onLoad() async {
    final images = Flame.images;
    final bg = await images.load(theme.background);
    final left = await images.load(theme.leftImage);
    final right = await images.load(theme.rightImage);
    final fbLeft = await images.load(theme.leftBall);
    final fbRight = await images.load(theme.rightBall);

    _bg = SpriteComponent(sprite: Sprite(bg))
      ..position = Vector2.zero()
      ..priority = 0;
    add(_bg!);

    player1 = Fighter(
      image: left,
      state: logic.left,
      flameColor: theme.leftColor,
      ballImage: fbLeft,
    )..priority = 5;
    player2 = Fighter(
      image: right,
      state: logic.right,
      flameColor: theme.rightColor,
      ballImage: fbRight,
    )..priority = 5;

    add(player1!);
    add(player2!);

    _hud = Hud(theme)..priority = 40;
    add(_hud!);

    _vsBanner = VsBanner(theme)..priority = 50;
    add(_vsBanner!);

    _signalOverlay = SignalOverlay(() => strings)..priority = 45;
    add(_signalOverlay!);

    monitor1.start(store.devices[player1Slot]);
    monitor2.start(store.devices[player2Slot]);

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

  /// Recalcula escala y posiciones usando la resolución real del widget.
  /// El viewport por defecto (MaxViewport) es 1:1, así que las coordenadas del
  /// juego coinciden con los píxeles lógicos del dispositivo → rellena por
  /// completo ancho y alto en cualquier pantalla.
  void _layout() {
    if (size.x <= 0 || size.y <= 0) return;
    _res = size.clone();
    _k = (size.y / _refH).clamp(0.5, 2.5);

    // Fondo rellena exactamente el área visible.
    _bg?.size = _res;

    // Luchadores anclados a los bordes (izquierda/derecha), a una altura
    // relativa a la pantalla, con tamaño proporcional a la altura.
    player1?.layoutAt(_res, _k);
    player2?.layoutAt(_res, _k);

    // La simulación usa exactamente la misma geometría que el render, para
    // que los impactos medidos en test coincidan con lo que se ve.
    if (player1 != null && player2 != null) {
      logic.layout(ArenaGeometry(
        width: _res.x,
        height: _res.y,
        scale: _k,
        leftWidth: player1!.size.x,
        leftHeight: player1!.size.y,
        rightWidth: player2!.size.x,
        rightHeight: player2!.size.y,
        margin: 20.0 * _k,
      ));
    }

    _hud?.size = _res;
    _hud?.setScale(_k);
    _signalOverlay?.size = _res;
    _signalOverlay?.setScale(_k);
    _vsBanner?.size = _res;
    _vsBanner?.setScale(_k);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_vsTimer > 0 || gameOver) return;
    _spawn(logic.left);
    _spawn(logic.right);
  }

  /// Atajo de accesibilidad: el toque adelanta la carga pendiente.
  void _spawn(FighterState f) {
    if (f.charge < 0.5) f.charge = 0.8;
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
          final speed = (120 + (power * 4) + (i % 5) * 60) * k;
          return AcceleratedParticle(
            lifespan: 0.6,
            speed: Vector2(math.cos(ang), math.sin(ang)) * speed,
            acceleration: Vector2(0, 300 * k),
            child: CircleParticle(
              paint: Paint()
                ..color = color.withOpacity(0.9 - (i % 4) * 0.2)
                ..blendMode = BlendMode.plus,
              radius: (6 + (i % 4) * 4) * k,
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

    // Refrescar los datos EEG de cada luchador.
    final e1 = store.devices[player1Slot];
    final e2 = store.devices[player2Slot];

    // ---- Watchdog de señal (por AUSENCIA de paquetes, no por umbral) ----
    // Un EEG real oscila: poorSignal sube y baja sin que el casco se caiga.
    // Por eso la pausa solo depende de que dejen de llegar paquetes 2,5 s.
    final s1 = monitor1.tick(e1, dt);
    final s2 = monitor2.tick(e2, dt);
    _hud?.updateSignal(
      quality1: e1?.signalQuality ?? SignalQuality.unknown,
      quality2: e2?.signalQuality ?? SignalQuality.unknown,
      demo1: _isDemo(player1Slot),
      demo2: _isDemo(player2Slot),
      offlineLabel: strings.signalOffline,
      demoLabel: strings.demoChip,
    );
    _signalOverlay?.updateSignal(
      state1: s1,
      state2: s2,
      demo1: _isDemo(player1Slot),
      demo2: _isDemo(player2Slot),
      strings: strings,
    );

    final lost = s1 == SignalWatchState.lost || s2 == SignalWatchState.lost;
    if (lost) {
      // Pausa automática: el duelo se congela y se muestra el overlay de
      // reconexión. Al volver los paquetes se reanuda solo (más abajo).
      if (logic.pauseEngine()) _clearFireballs();
      _signalOverlay?.markPaused();
      return;
    }
    // Reconexión: basta con que vuelvan los paquetes de los dos lados.
    // (Si solo uno perdió el enlace, el otro nunca estuvo en pausa: exigir
    // `takeResume()` en ambos dejaría la partida congelada para siempre.)
    final resumed = monitor1.takeResume() | monitor2.takeResume();
    if (logic.paused && resumed && monitor1.linkAlive && monitor2.linkAlive) {
      logic.resumeEngine();
      _signalOverlay?.markResumed();
    }

    logic.readEeg(1,
        attention: e1?.attention.toDouble() ?? 0,
        meditation: e1?.meditation.toDouble() ?? 0);
    logic.readEeg(2,
        attention: e2?.attention.toDouble() ?? 0,
        meditation: e2?.meditation.toDouble() ?? 0);

    // Un paso de simulación; el render consume los eventos del frame.
    for (final ev in logic.update(dt)) {
      switch (ev) {
        case ShotFired(:final projectile):
          _spawnFireball(projectile);
        case ShotHit(:final projectile, :final absorbed):
          _onHit(projectile, absorbed);
        case DuelEnded e:
          _endGame(e);
      }
    }

    // Sincronizar los sprites con los proyectiles vivos de la simulación.
    final live = logic.projectiles.map((p) => p.id).toSet();
    for (final ball in _fireballs) {
      if (!live.contains(ball.projectile.id)) ball.removeFromParent();
    }
    _fireballs.removeWhere((b) => b.parent == null);

    // Shake decay.
    if (_shake > 0) _shake = math.max(0, _shake - dt * 3);

    // El centro lo manda la simulación (incluye la flotación idle).
    player1!.applyLogicCenter(logic.centerOf(1));
    player2!.applyLogicCenter(logic.centerOf(2));
  }

  /// `true` si el slot es un dispositivo simulado (chip DEMO en el HUD).
  bool _isDemo(int slot) {
    final src = store.sources[slot];
    return src is SimulatedMindSource;
  }

  /// Retira del árbol los proyectiles en vuelo (al pausar por pérdida de
  /// señal no queremos que queden bolas congeladas en pantalla).
  void _clearFireballs() {
    for (final b in _fireballs) {
      b.removeFromParent();
    }
    _fireballs.clear();
  }

  void _spawnFireball(Projectile p) {
    final from = p.side == 1 ? player1! : player2!;
    final ball = Fireball(
      projectile: p,
      targetY: p.targetY,
      power: p.power,
      image: from.ballImage,
      color: from.flameColor,
      scale: k,
    )..priority = 10;
    add(ball);
    _fireballs.add(ball);
    _playFire();
  }

  void _onHit(Projectile p, double absorbed) {
    final from = p.side == 1 ? player1! : player2!;
    _explode(Vector2(p.x, p.y), from.flameColor, p.power / 10 + 1);
    _shake = 8;
    _hud!.flash(p.side, absorbed > 0);
    if (!_audioOk || _hit == null) return;
    try {
      _hit!.seek(Duration.zero);
      _hit!.resume();
    } catch (_) {}
  }

  void _endGame(DuelEnded ev) {
    if (ev.draw) {
      winner = 'Empate';
    } else {
      final name = ev.winnerSide == 1 ? theme.leftName : theme.rightName;
      winner = '$name gana';
    }
    overlays.add('gameOver');
  }

  void restart() {
    winner = null;
    _vsTimer = 2.2;
    logic.restart();
    _clearFireballs();
    monitor1.start(store.devices[player1Slot]);
    monitor2.start(store.devices[player2Slot]);
    _signalOverlay?.markResumed();
    player1!.applyLogicCenter(logic.centerOf(1));
    player2!.applyLogicCenter(logic.centerOf(2));
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
    required this.state,
    required this.flameColor,
    required this.ballImage,
  })  : image = image,
        super(
          size: Vector2(
            image.width.toDouble() * 1.15,
            image.height.toDouble() * 1.15,
          ),
        );

  final Image image;

  /// Estado de simulación que este componente pinta (vive en [BattleLogic]).
  final FighterState state;

  final Color flameColor;
  final Image ballImage;

  /// Factor de escala (altura de pantalla / 1080) para los dibujos fijos.
  double k = 1;

  double _pulse = 0;

  int get side => state.side;
  int get facing => side == 1 ? 1 : -1;

  double get attention => state.attention;
  double get meditation => state.meditation;
  double get shield => state.shield;
  double get hp => state.hp;
  double get recoil => state.recoil;
  double get hitFlash => state.hitFlash;

  Vector2 get center => position.clone() + size / 2;
  Vector2 get muzzle => Vector2(
        center.x + facing * size.x * 0.45,
        center.y - size.y * 0.15,
      );

  /// Coloca el sprite en el centro que calcula la simulación.
  void applyLogicCenter(Offset2 c) {
    position.setValues(c.x - size.x / 2, c.y - size.y / 2);
  }

  void reset() {
    state.reset();
    applyHome();
  }

  /// Sitúa al luchador en su posición base (usado al re-posicionar el layout).
  void applyHome() {
    position.setFrom(centerHome - size / 2);
  }

  /// Posición de reposo del luchador, recalculada en [layoutAt].
  final Vector2 centerHome = Vector2.zero();

  /// Recalcula tamaño y posición anclando al borde de la pantalla.
  /// `screen` = resolución real del widget; el lado lo fija [state].
  void layoutAt(Vector2 screen, double s) {
    k = s;
    // Altura del luchador = 34.6% de la altura de pantalla, derivada del
    // aspecto del sprite. Se expresa como fracción (no en píxeles del PNG)
    // para que el arte pueda generarse a 2x sin cambiar el encuadre.
    final h = screen.y * 0.346;
    final w = h * image.width / image.height;
    size.setValues(w, h);
    final margin = 20.0 * s;
    centerHome.setValues(
      side == 1 ? size.x / 2 + margin : screen.x - size.x / 2 - margin,
      screen.y * 0.80,
    );
    position.setFrom(centerHome - size / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 3;
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

    // ---- Anillo de escudo (fracción 0-1 del cap, no escala 0-100) ----
    final shieldFrac = state.shieldFraction;
    if (state.shield > 0.5) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (6 + shieldFrac * 12) * k
        ..color = const Color(0xFFB0F7FF).withOpacity(0.35 + shieldFrac * 0.5)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(cx, cy), size.x * 0.62, ring);
    }

    // ---- Sprite del luchador ----
    final flash = hitFlash > 0;
    final spritePaint = Paint();
    if (flash) {
      spritePaint.colorFilter = const ColorFilter.matrix(<double>[
        2,
        0,
        0,
        0,
        -128,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        2,
        0,
        -128,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.x, size.y);
    if (facing < 0) {
      // Volteo horizontal fiable: transform de canvas (un dest rect de ancho
      // negativo no se rasteriza en todas las versiones de Skia).
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1.0, 1.0);
      canvas.drawImageRect(image, src, dst, spritePaint);
      canvas.restore();
    } else {
      canvas.drawImageRect(image, src, dst, spritePaint);
    }

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
    drawMeter(canvas, cx, -30 * k, attention / 100, flameColor, 'ATN');
    drawMeter(canvas, cx, -54 * k, shieldFrac, const Color(0xFFB0F7FF), 'MDT');
  }

  void drawMeter(Canvas canvas, double cx, double y, double frac, Color color,
      String label) {
    final w = size.x * 0.62;
    final h = 12.0 * k;
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
    required this.projectile,
    required this.targetY,
    required this.power,
    required this.image,
    required this.color,
    double scale = 1,
  }) : super(
          position: Vector2(projectile.x, projectile.y),
          anchor: Anchor.center,
          size: Vector2.all(70 * (1 + power / 100) * scale),
        ) {
    scaleFactor = scale;
  }

  /// Proyectil de la simulación que este sprite representa.
  final Projectile projectile;
  final double targetY;
  final double power;
  final Image image;
  final Color color;
  double scaleFactor = 1;

  double _t = 0;

  int get side => projectile.side;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    // La trayectoria la manda la simulación; el sprite solo la refleja.
    position.setValues(projectile.x, projectile.y);
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
  Hud(this.theme);

  final BattleTheme theme;
  Fighter? p1;
  Fighter? p2;
  double flashP1 = 0, flashP2 = 0;
  double shieldP1 = 0, shieldP2 = 0;
  double _k = 1;

  /// Calidad de señal por lado (chip de 4 barras entre las barras de HP).
  SignalQuality quality1 = SignalQuality.unknown;
  SignalQuality quality2 = SignalQuality.unknown;

  /// `true` si el slot es un dispositivo simulado (chip DEMO gris).
  bool demo1 = false;
  bool demo2 = false;

  /// Etiquetas i18n del chip, inyectadas por el juego.
  String offlineLabel = 'SIN SEÑAL';
  String demoLabel = 'DEMO';

  void setScale(double s) => _k = s;

  /// Actualiza la calidad de señal mostrada y las marcas DEMO.
  void updateSignal({
    required SignalQuality quality1,
    required SignalQuality quality2,
    bool demo1 = false,
    bool demo2 = false,
    String? offlineLabel,
    String? demoLabel,
  }) {
    this.quality1 = quality1;
    this.quality2 = quality2;
    this.demo1 = demo1;
    this.demo2 = demo2;
    if (offlineLabel != null) this.offlineLabel = offlineLabel;
    if (demoLabel != null) this.demoLabel = demoLabel;
  }

  void updateData(Fighter? a, Fighter? b) {
    p1 = a;
    p2 = b;
    if (flashP1 > 0) flashP1 -= 0.06;
    if (flashP2 > 0) flashP2 -= 0.06;
    if (shieldP1 > 0) shieldP1 -= 0.06;
    if (shieldP2 > 0) shieldP2 -= 0.06;
  }

  void flash(int side, bool absorbed) {
    if (side == 1)
      flashP1 = 1;
    else
      flashP2 = 1;
    if (absorbed) {
      if (side == 1)
        shieldP1 = 1;
      else
        shieldP2 = 1;
    }
  }

  @override
  void render(Canvas canvas) {
    final k = _k;
    final w = size.x;
    final top = 34.0 * k;
    final barW = w * 0.38;
    final barH = 34.0 * k;
    final md = w * 0.035; // margen ~ proporcional al ancho

    _bar(canvas, md, top, barW, p1?.state, theme.leftColor, flashP1, true, k);
    _bar(canvas, w - md - barW, top, barW, p2?.state, theme.rightColor, flashP2,
        false, k);

    // Shield mini-bar debajo de cada barra.
    _miniBar(canvas, md, top + barH + 8 * k, barW, p1?.state,
        const Color(0xFFB0F7FF), shieldP1, k);
    _miniBar(canvas, w - md - barW, top + barH + 8 * k, barW, p2?.state,
        const Color(0xFFB0F7FF), shieldP2, k);

    // Nombres.
    drawText(canvas, theme.leftName, md, top - 30 * k, 26 * k, theme.leftColor,
        400 * k);
    drawText(canvas, theme.rightName, w - md - 300 * k, top - 30 * k, 26 * k,
        theme.rightColor, 300 * k,
        alignRight: true);

    // Valores EEG en vivo.
    if (p1 != null) {
      drawText(
          canvas,
          'ATN ${p1!.attention.round()}  MDT ${p1!.meditation.round()}',
          md,
          top + barH + 34 * k,
          20 * k,
          const Color(0xFFE6E6E6),
          420 * k);
    }
    if (p2 != null) {
      drawText(
          canvas,
          'ATN ${p2!.attention.round()}  MDT ${p2!.meditation.round()}',
          w - md - 420 * k,
          top + barH + 34 * k,
          20 * k,
          const Color(0xFFE6E6E6),
          420 * k,
          alignRight: true);
    }

    // Línea decorativa del HUD.
    final line = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 2 * k;
    canvas.drawLine(
        Offset(0, top + barH + 60 * k), Offset(w, top + barH + 60 * k), line);

    // Chips de calidad de señal, centrados entre las dos barras de HP.
    // "Desconectado" (unknown/offline) pinta CERO barras: es imposible que el
    // estado sin contacto se vea como señal llena.
    final cx = w / 2;
    final chipY = top + 2 * k;
    final leftChip = layoutSignalChip(
      quality: quality1,
      origin: Offset(cx - 4 * k, chipY),
      scale: k,
      isDemo: demo1,
      alignRight: true,
      disconnectedLabel: offlineLabel,
      demoLabel: demoLabel,
    );
    final rightChip = layoutSignalChip(
      quality: quality2,
      origin: Offset(cx + 4 * k, chipY),
      scale: k,
      isDemo: demo2,
      disconnectedLabel: offlineLabel,
      demoLabel: demoLabel,
    );
    _signalChip(canvas, leftChip, k);
    _signalChip(canvas, rightChip, k);
  }

  /// Pinta un chip de señal ya calculado (geometría pura en [signal_chip]).
  void _signalChip(Canvas canvas, SignalChipLayout chip, double k) {
    final r = RRect.fromRectAndRadius(chip.chipRect, Radius.circular(6 * k));
    canvas.drawRRect(r, Paint()..color = SignalChipColors.background);
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * k
          ..color = SignalChipColors.outline);

    for (var i = 0; i < chip.bars.length; i++) {
      final fill = chip.fills[i];
      final bar =
          RRect.fromRectAndRadius(chip.bars[i], Radius.circular(1.5 * k));
      canvas.drawRRect(bar, Paint()..color = SignalChipColors.empty);
      if (fill != null) canvas.drawRRect(bar, Paint()..color = fill);
    }

    // La etiqueta "SIN SEÑAL" se pinta en rojo para no confundirse con una
    // lectura válida; DEMO en gris; el porcentaje en el color de la señal.
    final Color labelColor;
    if (chip.isDemo) {
      labelColor = SignalChipColors.demo;
    } else if (!chip.quality.hasContact) {
      labelColor = SignalChipColors.weak;
    } else {
      labelColor = switch (chip.quality) {
        SignalQuality.good => SignalChipColors.good,
        SignalQuality.fair => SignalChipColors.fair,
        _ => SignalChipColors.poor,
      };
    }
    drawText(canvas, chip.label, chip.labelPosition.dx, chip.labelPosition.dy,
        13 * k, labelColor, 64 * k);
  }

  void _bar(Canvas canvas, double x, double y, double w, FighterState? st,
      Color color, double flash, bool left, double k) {
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, 34 * k), Radius.circular(8 * k));
    canvas.drawRRect(r, Paint()..color = const Color(0xB0000000));
    // Fracción real de vida (HP 260: un /100 fijo dejaría la barra al 38 %).
    final frac = st?.hpFraction ?? 0;
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
            Rect.fromLTWH(x, y, fillW, 34 * k), Radius.circular(8 * k)),
        gp);
    if (flash > 0) {
      canvas.drawRRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * k
            ..color = const Color(0xFFFFFFFF).withOpacity(flash));
    }
    final hp = st?.hp ?? 0;
    drawText(canvas, '${hp.toStringAsFixed(0)}', x, y + 4 * k, 24 * k,
        const Color(0xFFFFFFFF), 60 * k,
        alignRight: !left);
  }

  void _miniBar(Canvas canvas, double x, double y, double w, FighterState? st,
      Color color, double flash, double k) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, 8 * k), Radius.circular(4 * k)),
        Paint()..color = const Color(0x66000000));
    // Fracción del cap de escudo (30), no de una escala 0-100.
    final fill = ((st?.shieldFraction ?? 0) * w).clamp(0.0, w);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, fill, 8 * k), Radius.circular(4 * k)),
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
        Shadow(color: Color(0xAA000000), blurRadius: 4, offset: Offset(1, 1)),
      ],
    ));
    pb.addText(text);
    final para = pb.build()..layout(ParagraphConstraints(width: width));
    canvas.drawParagraph(para, Offset(x, y));
  }
}

// ===========================================================================
//  VsBanner — cartel de presentación del combate (luchador izq. vs der.)
// ===========================================================================
class VsBanner extends PositionComponent {
  VsBanner(this.theme);

  final BattleTheme theme;

  /// Tiempo restante del cartel; el juego lo actualiza cada frame.
  double remaining = 2.2;
  double _k = 1;

  void setScale(double s) => _k = s;

  @override
  void render(Canvas canvas) {
    if (remaining <= 0) return;
    final k = _k;
    final cx = size.x / 2;
    final cy = size.y * 0.40;
    final alpha = remaining < 0.6 ? (remaining / 0.6).clamp(0.0, 1.0) : 1.0;

    // Scrim oscuro para hacer resaltar el cartel.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Color(0x66000000).withOpacity(alpha));

    // Líneas decorativas horizontales.
    final line = Paint()
      ..color = Color(0x88FFFFFF).withOpacity(alpha)
      ..strokeWidth = 3 * k;
    canvas.drawLine(Offset(0, cy + 40 * k), Offset(cx - 40 * k, cy + 40 * k),
        line..strokeWidth = 3 * k);
    canvas.drawLine(Offset(cx + 40 * k, cy + 40 * k),
        Offset(size.x, cy + 40 * k), line..strokeWidth = 3 * k);

    _text(canvas, theme.leftName, cx - 340 * k, cy - 30 * k, 54 * k,
        theme.leftColor.withOpacity(alpha), 320 * k, TextAlign.right);
    _text(canvas, 'VS', cx - 60 * k, cy - 16 * k, 72 * k,
        Color(0xFFFFFFFF).withOpacity(alpha), 120 * k, TextAlign.center);
    _text(canvas, theme.rightName, cx + 20 * k, cy - 30 * k, 54 * k,
        theme.rightColor.withOpacity(alpha), 320 * k, TextAlign.left);

    if (remaining < 1.1) {
      final pulse = 0.7 + 0.3 * math.sin(remaining * 22);
      _text(
          canvas,
          '¡PELEA!',
          cx - 150 * k,
          cy + 70 * k,
          46 * k,
          Color(0xFFFFFF00).withOpacity(alpha * pulse),
          300 * k,
          TextAlign.center);
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

// ===========================================================================
//  SignalOverlay — banda de aviso de señal y overlay de reconexión
// ===========================================================================
/// Capa de diagnóstico de señal sobre la partida.
///
/// Dos estados visuales, ambos alimentados por [SignalMonitor]:
///  * **Banda de aviso** (ámbar): la señal es mala (sin contacto o muy
///    débil) durante más de 3 s, pero siguen llegando paquetes y la partida
///    NO se detiene.
///  * **Overlay de reconexión** (scrim oscuro + texto): no llegan paquetes
///    desde hace 2,5 s; el motor está pausado y se reanuda solo.
class SignalOverlay extends PositionComponent {
  SignalOverlay(this._strings);

  final AppStrings Function() _strings;

  SignalWatchState state1 = SignalWatchState.ok;
  SignalWatchState state2 = SignalWatchState.ok;
  bool demo1 = false;
  bool demo2 = false;
  bool pausedNow = false;
  double _k = 1;
  double _t = 0;

  void setScale(double s) => _k = s;

  /// `true` si al menos un lado tiene enlace perdido.
  bool get isLost =>
      state1 == SignalWatchState.lost || state2 == SignalWatchState.lost;

  /// `true` si hay banda de aviso que pintar (mala señal sostenida o pausa).
  bool get showsWarning =>
      isLost ||
      state1 == SignalWatchState.degraded ||
      state2 == SignalWatchState.degraded;

  void updateSignal({
    required SignalWatchState state1,
    required SignalWatchState state2,
    bool demo1 = false,
    bool demo2 = false,
    AppStrings? strings,
  }) {
    this.state1 = state1;
    this.state2 = state2;
    this.demo1 = demo1;
    this.demo2 = demo2;
  }

  void markPaused() => pausedNow = true;

  void markResumed() => pausedNow = false;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!showsWarning) return;
    final k = _k;
    final s = _strings();

    if (isLost) {
      _renderReconnecting(canvas, k, s);
    } else {
      _renderWarningBanner(canvas, k, s);
    }
  }

  void _renderWarningBanner(Canvas canvas, double k, AppStrings s) {
    final pulse = 0.75 + 0.25 * math.sin(_t * 4);
    final h = 34.0 * k;
    final y = size.y - h - 24 * k;
    final rect = Rect.fromLTWH(24 * k, y, size.x - 48 * k, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8 * k)),
      Paint()..color = const Color(0xE6B26A00).withValues(alpha: 0.9 * pulse),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8 * k)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * k
        ..color = const Color(0xFFFFD54F),
    );
    _text(canvas, '!  ${s.signalBadHint}', rect.left + 14 * k, y + 7 * k,
        18 * k, const Color(0xFFFFF3E0), rect.width - 28 * k);
  }

  void _renderReconnecting(Canvas canvas, double k, AppStrings s) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xB3000000),
    );
    final w = 520 * k;
    final x = (size.x - w) / 2;
    final y = size.y * 0.34;
    final pulse = 0.6 + 0.4 * math.sin(_t * 3);
    _text(canvas, s.reconnecting, x, y, 46 * k,
        const Color(0xFFFF7043).withValues(alpha: pulse), w);
    _text(canvas, s.reconnectingHint, x, y + 62 * k, 20 * k,
        const Color(0xFFE0E0E0), w);
  }

  void _text(Canvas canvas, String text, double x, double y, double size,
      Color color, double width) {
    final pb = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center));
    pb.pushStyle(TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w900,
      shadows: const [
        Shadow(color: Color(0xDD000000), blurRadius: 6, offset: Offset(1, 1)),
      ],
    ));
    pb.addText(text);
    final para = pb.build()..layout(ParagraphConstraints(width: width));
    canvas.drawParagraph(para, Offset(x, y));
  }
}
