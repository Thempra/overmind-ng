import 'dart:math';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';

import '../state/eeg_store.dart';

/// Bola de fuego disparada por un jugador hacia la barra de poder.
class FireProjectile extends PositionComponent {
  FireProjectile({
    required super.position,
    required this.velocity,
    required super.size,
  });

  final Vector2 velocity;

  void updateProjectile(double dt) {
    position.add(velocity * dt);
  }
}

/// Port a FLAME de [GameLayer] (proyecto Android original).
///
/// Juego de tira y afloja (tug-of-war): dos jugadores (izquierda/derecha)
/// disparan bolas de fuego hacia una barra de poder central que se desplaza
/// según la diferencia de (atención + meditación) de cada usuario EEG.
/// Gana quien empuja la barra fuera de su lado.
class BattleGame extends FlameGame with TapCallbacks {
  BattleGame({
    required this.store,
    required this.player1Slot,
    required this.player2Slot,
  });

  final EegStore store;
  final int player1Slot;
  final int player2Slot;

  static const double projectileSpeed = 480; // px/s (igual que el original)
  static const double physicsStep = 0.9;

  late SpriteComponent _player1;
  late SpriteComponent _player2;
  late SpriteComponent _powerBar;

  final List<FireProjectile> _projectiles = [];
  AudioPlayer? _pew;

  double powerBarX = 0;
  double _gameTimer = 0;
  double _projTimer = 0;

  int powerP1 = 0, powerP2 = 0;
  String? winner;

  bool get gameOver => winner != null;

  int _powerOf(int slot) {
    if (slot < 0 || slot >= EegStore.maxDevices) return 0;
    final eeg = store.devices[slot];
    if (eeg == null) return 0;
    return eeg.power;
  }

  @override
  Future<void> onLoad() async {
    camera.viewport.size = Vector2(1920, 1080);

    final images = Flame.images;
    final bgImage = await images.load('images/game_background2.jpg');
    final p1Image = await images.load('images/eva01.png');
    final p2Image = await images.load('images/sachiel.png');
    final pbImage = await images.load('images/powerbar.png');
    _redFireball = await images.load('images/fireball.png');
    _blueFireball = await images.load('images/fireball_blue.png');

    add(SpriteComponent(sprite: Sprite(bgImage))
      ..size = camera.viewport.size
      ..position = Vector2.zero());

    final winH = camera.viewport.size.y;
    final winW = camera.viewport.size.x;

    _player1 = SpriteComponent(sprite: Sprite(p1Image))
      ..anchor = Anchor.center
      ..position = Vector2(p1Image.width / 2, winH / 2);
    _player2 = SpriteComponent(sprite: Sprite(p2Image))
      ..anchor = Anchor.center
      ..position = Vector2(winW - p2Image.width / 2, winH / 2);
    add(_player1);
    add(_player2);

    powerBarX = winW / 2;
    _powerBar = SpriteComponent(sprite: Sprite(pbImage))
      ..anchor = Anchor.center
      ..position = Vector2(powerBarX, winH - pbImage.height / 2);
    add(_powerBar);

    // Sonido del disparo (opcional y tolerante a fallos en desktop).
    try {
      final p = AudioPlayer();
      await p.setSource(AssetSource('audio/pew_pew_lei.wav'));
      _pew = p;
    } catch (_) {
      _pew = null;
    }

    return super.onLoad();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameOver) return;
    _firePlayer1();
    _firePlayer2();
  }

  void _firePlayer1() {
    final size = camera.viewport.size;
    final proj = _makeProjectile(
      position: Vector2(100, size.y / 2),
      velocity: Vector2(projectileSpeed, 0),
      image: _blueFireball!,
    );
    add(proj);
    _projectiles.add(proj);
    _playPew();
  }

  void _firePlayer2() {
    final size = camera.viewport.size;
    final proj = _makeProjectile(
      position: Vector2(size.x - 100, size.y / 2),
      velocity: Vector2(-projectileSpeed, 0),
      image: _redFireball!,
    );
    add(proj);
    _projectiles.add(proj);
    _playPew();
  }

  ui.Image? _redFireball;
  ui.Image? _blueFireball;
  double _targetY = 0;

  FireProjectile _makeProjectile({
    required Vector2 position,
    required Vector2 velocity,
    required ui.Image image,
  }) {
    final size = Vector2(image.width.toDouble(), image.height.toDouble());
    final proj = FireProjectile(
      position: position,
      velocity: velocity,
      size: size,
    )..anchor = Anchor.center;
    proj.add(SpriteComponent(sprite: Sprite(image))..size = size);
    _targetY = _projectiles.isEmpty
        ? _player2.position.y
        : (_player1.position.y +
            (Random().nextInt(81) - 40)); // pequeña dispersión en Y
    return proj;
  }

  void _playPew() {
    _pew?.stop();
    _pew?.resume();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver) return;

    // Lógica del juego (cada ~1s): desplazar la barra según los poderes.
    _gameTimer += dt;
    if (_gameTimer >= 1.0) {
      _gameTimer = 0;
      powerP1 = _powerOf(player1Slot);
      powerP2 = _powerOf(player2Slot);
      powerBarX += (powerP1 - powerP2) * physicsStep;
      _powerBar.position.x = powerBarX;
    }

    // Disparos automáticos (cada ~0.2s) proporcionales al poder.
    _projTimer += dt;
    if (_projTimer >= 0.2) {
      _projTimer = 0;
      for (var i = 0; i < powerP1 ~/ 20; i++) {
        _firePlayer1();
      }
      for (var i = 0; i < powerP2 ~/ 20; i++) {
        _firePlayer2();
      }
    }

    // Mover proyectiles y acercarlos al objetivo en Y.
    final size = camera.viewport.size;
    for (final p in _projectiles) {
      p.updateProjectile(dt);
      p.position.y += ((_targetY - p.position.y) * dt * 2).clamp(-10, 10);
      if (p.position.x < 20 || p.position.x > size.x - 20) {
        p.removeFromParent();
      }
    }
    _projectiles.removeWhere((p) => !p.isLoaded || p.parent == null);

    // Comprobar ganador.
    if (powerBarX < 0) {
      _endGame('Player 2 wins');
    } else if (powerBarX > size.x) {
      _endGame('Player 1 wins');
    }
  }

  void _endGame(String msg) {
    winner = msg;
    overlays.add('gameOver');
  }

  void restart() {
    winner = null;
    powerBarX = camera.viewport.size.x / 2;
    _powerBar.position.x = powerBarX;
    _projectiles.clear();
    overlays.remove('gameOver');
  }

  void shutdown() {
    _pew?.dispose();
    _projectiles.clear();
  }
}
