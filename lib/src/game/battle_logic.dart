import 'dart:math' as math;

// ===========================================================================
//  DUELO — lógica pura (sin Flame, sin Canvas, sin audio).
//
//  Todo lo que decide el resultado de la partida vive aquí: vida, escudo,
//  cadencia, proyectiles, impactos, muerte súbita y fin de partida. El fichero
//  `battle_game.dart` se queda SOLO con el render y el audio, y delega cada
//  frame en [BattleLogic.update].
//
//  Motivo: `battle_game.dart` no tenía ni un test (estaba excluido de
//  cobertura) y el duelo era matemáticamente injugable. Separar la simulación
//  permite testear el balance headless a 60 fps simulados.
// ===========================================================================

/// Modo de recarga del escudo.
enum ShieldRegen {
  /// Histórico (roto): `shield += (meditation - shield) * dt * 1.2`.
  ///
  /// El escudo converge a la MEDITACIÓN (escala 0-100) mientras la absorción se
  /// aplicaba en unidades absolutas, así que con med alta absorbía el 100 % del
  /// daño entrante para siempre ⇒ la vida no bajaba nunca.
  tracking,

  /// Recarga sobre el DÉFICIT: `shield += (cap - shield) * med/100 * k * dt`.
  ///
  /// Al depender del hueco disponible no se congela en el tope: con med alta el
  /// escudo se mantiene cerca del cap pero cada impacto lo vuelve a abrir.
  deficit,
}

/// Ajustes de balance de un duelo. Todo el tuning numérico está aquí para que
/// los tests puedan simular perfiles de EEG concretos sin tocar el render.
class BattleTuning {
  const BattleTuning({
    this.maxHp = 260,
    this.damageBase = 4.6,
    this.damagePerAttention = 0.022,
    this.damageMin = 3.2,
    this.damageMax = 7.4,
    this.cadenceBase = 0.45,
    this.cadencePerAttention = 0.75,
    this.shieldCap = 30,
    this.shieldRegen = ShieldRegen.deficit,
    this.shieldRegenK = 0.9,
    this.shieldTrackRate = 1.2,
    this.absorbMinFrac = 0.20,
    this.absorbMaxFrac = 0.50,
    this.absoluteAbsorb = false,
    this.suddenDeathAt = 80,
    this.suddenDeathHpCap = 60,
    this.suddenDeathDamageMult = 1.9,
    this.timeLimit = 120,
    this.fireSpeedBase = 520,
    this.fireSpeedPerPower = 3,
  });

  /// Perfil histórico: 100 HP, escudo = meditación, absorción absoluta y sin
  /// final. Se conserva para los tests que documentan el bug original.
  static const legacy = BattleTuning(
    maxHp: 100,
    damageBase: 4,
    damagePerAttention: 0.16,
    damageMin: 2,
    damageMax: 22,
    cadenceBase: 0.35,
    cadencePerAttention: 2.6,
    shieldCap: 100,
    shieldRegen: ShieldRegen.tracking,
    absoluteAbsorb: true,
    suddenDeathAt: double.infinity,
    timeLimit: double.infinity,
  );

  final double maxHp;
  final double damageBase;
  final double damagePerAttention;
  final double damageMin;
  final double damageMax;

  /// Disparos por segundo a atención 0 y ganancia por punto de atención.
  final double cadenceBase;
  final double cadencePerAttention;

  final double shieldCap;
  final ShieldRegen shieldRegen;

  /// Constante de recarga del escudo en modo [ShieldRegen.deficit].
  final double shieldRegenK;

  /// Constante de seguimiento del escudo en modo [ShieldRegen.tracking].
  final double shieldTrackRate;

  /// Absorción fraccional: % del daño que come el escudo con escudo vacío y
  /// con escudo lleno (interpolación lineal).
  final double absorbMinFrac;
  final double absorbMaxFrac;

  /// Si es true, el escudo absorbe en unidades absolutas (`min(shield, dmg)`),
  /// comportamiento del duelo original.
  final bool absoluteAbsorb;

  /// Segundo en el que entra la muerte súbita (`double.infinity` = desactivada).
  final double suddenDeathAt;

  /// Al entrar en muerte súbita la vida se recorta a este valor (el líder
  /// pierde la ventaja para que la pelea se cierre de verdad).
  final double suddenDeathHpCap;

  final double suddenDeathDamageMult;

  /// Tope duro de la partida: a partir de aquí gana quien tenga más vida.
  final double timeLimit;

  final double fireSpeedBase;
  final double fireSpeedPerPower;

  /// Daño por impacto de una bola lanzada con [attention] (0-100).
  double damageFor(double attention) =>
      (damageBase + attention * damagePerAttention)
          .clamp(damageMin, damageMax)
          .toDouble();

  /// Disparos por segundo de un jugador con [attention] (0-100).
  double cadenceFor(double attention) =>
      cadenceBase + attention / 100 * cadencePerAttention;

  /// Fracción del daño que absorbe el escudo con [shield] cargado.
  double absorbFraction(double shield) {
    final t = (shield / shieldCap).clamp(0.0, 1.0);
    return absorbMinFrac + (absorbMaxFrac - absorbMinFrac) * t;
  }
}

/// Geometría del duelo: tamaños y anclajes de los luchadores en píxeles
/// lógicos. La calcula el render (`BattleGame._layout`) y la consume la lógica.
class ArenaGeometry {
  const ArenaGeometry({
    required this.width,
    required this.height,
    required this.scale,
    required this.leftWidth,
    required this.leftHeight,
    required this.rightWidth,
    required this.rightHeight,
    this.margin = 20,
    this.groundFraction = 0.80,
    this.bobAmplitude = 10,
  });

  /// Geometría por defecto de los tests headless (1280x720, avatares 241x325).
  static const test = ArenaGeometry(
    width: 1280,
    height: 720,
    scale: 720 / 1080,
    leftWidth: 241 * 1.15,
    leftHeight: 325 * 1.15,
    rightWidth: 243 * 1.15,
    rightHeight: 325 * 1.15,
    margin: 20 * (720 / 1080),
  );

  final double width;
  final double height;
  final double scale;
  final double leftWidth;
  final double leftHeight;
  final double rightWidth;
  final double rightHeight;
  final double margin;
  final double groundFraction;
  final double bobAmplitude;

  double widthOf(int side) => side == 1 ? leftWidth : rightWidth;

  double heightOf(int side) => side == 1 ? leftHeight : rightHeight;

  /// Centro en reposo del luchador [side] (1 = izquierda, 2 = derecha).
  Offset2 homeOf(int side) {
    final w = widthOf(side);
    final x = side == 1 ? w / 2 + margin : width - w / 2 - margin;
    return Offset2(x, height * groundFraction);
  }
}

/// Par de coordenadas mínimo (evita depender de vector_math en la lógica).
class Offset2 {
  const Offset2(this.x, this.y);

  final double x;
  final double y;
}

/// Estado de un luchador (lo que el HUD y el render necesitan, sin Canvas).
class FighterState {
  FighterState({required this.side, required this.tuning});

  final int side;
  final BattleTuning tuning;

  double hp = 0;
  double shield = 0;
  double attention = 0;
  double meditation = 0;
  double charge = 0;
  double recoil = 0;
  double hitFlash = 0;
  double bob = 0;

  double get maxHp => tuning.maxHp;
  double get shieldCap => tuning.shieldCap;

  /// Fracción 0-1 de vida, para barras y tests.
  double get hpFraction => (hp / maxHp).clamp(0.0, 1.0);

  /// Fracción 0-1 de escudo, para barras y tests.
  double get shieldFraction => (shield / shieldCap).clamp(0.0, 1.0);

  void reset() {
    hp = tuning.maxHp;
    shield = 0;
    charge = 0;
    recoil = 0;
    hitFlash = 0;
  }

  /// Aplica daño teniendo en cuenta el escudo. Devuelve el daño absorbido.
  double takeDamage(double dmg) {
    hitFlash = 0.18;
    final double absorbed;
    if (tuning.absoluteAbsorb) {
      absorbed = math.min(shield, dmg);
    } else {
      absorbed = math.min(shield, dmg * tuning.absorbFraction(shield));
    }
    shield = math.max(0, shield - absorbed);
    hp = math.max(0, hp - (dmg - absorbed));
    return absorbed;
  }

  /// Recarga del escudo según el modo del perfil de balance.
  void regenShield(double dt) {
    if (tuning.shieldRegen == ShieldRegen.tracking) {
      shield = shield + (meditation - shield) * dt * tuning.shieldTrackRate;
      if (shield < 0) shield = 0;
    } else {
      shield = math.min(
        tuning.shieldCap,
        shield +
            (tuning.shieldCap - shield) *
                (meditation / 100) *
                tuning.shieldRegenK *
                dt,
      );
    }
  }
}

/// Proyectil en vuelo (solo datos; el sprite lo pinta `Fireball`).
class Projectile {
  Projectile({
    required this.id,
    required this.side,
    required this.facing,
    required this.x,
    required this.y,
    required this.targetY,
    required this.power,
  });

  final int id;
  final int side;
  final int facing;
  double x;
  double y;
  double targetY;
  final double power;
}

/// Eventos que la lógica emite y el render consume.
sealed class BattleEvent {
  const BattleEvent();
}

class ShotFired extends BattleEvent {
  const ShotFired(this.projectile);

  final Projectile projectile;
}

class ShotHit extends BattleEvent {
  const ShotHit({
    required this.projectile,
    required this.targetSide,
    required this.absorbed,
  });

  final Projectile projectile;
  final int targetSide;
  final double absorbed;
}

class DuelEnded extends BattleEvent {
  const DuelEnded(
      {required this.winnerSide, required this.draw, required this.reason});

  /// 1, 2 o null si empate.
  final int? winnerSide;
  final bool draw;
  final String reason;
}

/// Simulación completa del duelo, headless y determinista.
class BattleLogic {
  BattleLogic({this.tuning = const BattleTuning(), ArenaGeometry? arena})
      : arena = arena ?? ArenaGeometry.test {
    left = FighterState(side: 1, tuning: tuning)..reset();
    right = FighterState(side: 2, tuning: tuning)..reset();
  }

  final BattleTuning tuning;
  ArenaGeometry arena;

  late FighterState left;
  late FighterState right;

  final List<Projectile> projectiles = [];
  final List<DuelEnded> _end = [];

  int _nextId = 0;
  double time = 0;
  bool suddenDeath = false;
  bool finished = false;

  /// Motor en pausa: el duelo se congela sin perder estado ni tiempo.
  ///
  /// Se usa cuando el casco deja de emitir ([SignalMonitor]): pausar evita que
  /// la partida se decida por datos viejos congelados. Con `paused` en true,
  /// [update] no avanza el tiempo ni simula nada.
  bool paused = false;

  /// Pausa el motor (idempotente). Devuelve `true` si cambió el estado.
  bool pauseEngine() {
    if (paused || finished) return false;
    paused = true;
    return true;
  }

  /// Reanuda el motor (idempotente). Devuelve `true` si cambió el estado.
  bool resumeEngine() {
    if (!paused) return false;
    paused = false;
    return true;
  }

  /// Resultado, o null mientras se juega.
  DuelEnded? get outcome => finished ? _end.first : null;

  FighterState stateOf(int side) => side == 1 ? left : right;

  FighterState opponentOf(FighterState f) => f.side == 1 ? right : left;

  void layout(ArenaGeometry geometry) {
    arena = geometry;
  }

  /// Reinicia la partida conservando la geometría.
  void restart() {
    left.reset();
    right.reset();
    projectiles.clear();
    _end.clear();
    _nextId = 0;
    time = 0;
    suddenDeath = false;
    finished = false;
    paused = false;
  }

  /// Alimenta la lectura EEG de un luchador (0-100).
  void readEeg(int side,
      {required double attention, required double meditation}) {
    final f = stateOf(side);
    f.attention = attention;
    f.meditation = meditation;
  }

  /// Centro actual del luchador (incluye la flotación idle).
  Offset2 centerOf(int side) {
    final f = stateOf(side);
    final home = arena.homeOf(side);
    return Offset2(
        home.x, home.y + math.sin(f.bob) * arena.bobAmplitude * arena.scale);
  }

  /// Boquilla desde la que sale la bola.
  Offset2 muzzleOf(int side) {
    final c = centerOf(side);
    final facing = side == 1 ? 1 : -1;
    final w = arena.widthOf(side);
    final h = arena.heightOf(side);
    return Offset2(c.x + facing * w * 0.45, c.y - h * 0.15);
  }

  /// Avanza la simulación [dt] segundos y devuelve los eventos del frame.
  ///
  /// Con [paused] activo no avanza nada (ni tiempo ni proyectiles): el duelo
  /// queda congelado hasta [resumeEngine].
  List<BattleEvent> update(double dt) {
    final events = <BattleEvent>[];
    if (finished || paused) return events;
    time += dt;

    for (final f in [left, right]) {
      f.bob += dt * 2;
      if (suddenDeath) {
        // Escudo bloqueado: en muerte súbita no hay descuento permanente.
        f.shield = 0;
      } else {
        f.regenShield(dt);
      }

      f.charge += dt * tuning.cadenceFor(f.attention);
      if (f.charge >= 1.0) {
        events.add(ShotFired(_fire(f)));
      }

      if (f.recoil > 0) f.recoil -= dt;
      if (f.hitFlash > 0) f.hitFlash -= dt;
    }

    // Avance de proyectiles e impactos.
    final dead = <Projectile>[];
    for (final ball in projectiles) {
      ball.x += ball.facing *
          (tuning.fireSpeedBase + ball.power * tuning.fireSpeedPerPower) *
          arena.scale *
          dt;
      ball.y += (ball.targetY - ball.y) * 2 * dt;

      final shooter = stateOf(ball.side);
      final target = opponentOf(shooter);
      if (_hitTest(ball, target)) {
        // Todos los impactos del mismo frame se resuelven antes de decidir el
        // final: si no, el orden de la lista decidiría el ganador de un espejo.
        final absorbed = _applyHit(target, ball);
        events.add(ShotHit(
            projectile: ball, targetSide: target.side, absorbed: absorbed));
        dead.add(ball);
      } else if (ball.x < -80 || ball.x > arena.width + 80) {
        dead.add(ball);
      }
    }
    for (final b in dead) {
      projectiles.remove(b);
    }

    final ended = _checkEnd(events);
    if (ended != null) {
      events.add(ended);
      _end.add(ended);
      finished = true;
    }
    return events;
  }

  Projectile _fire(FighterState from) {
    final target = opponentOf(from);
    final muzzle = muzzleOf(from.side);
    final ball = Projectile(
      id: _nextId++,
      side: from.side,
      facing: from.side == 1 ? 1 : -1,
      x: muzzle.x,
      y: muzzle.y,
      targetY: centerOf(target.side).y,
      power: from.attention,
    );
    projectiles.add(ball);
    from.charge = 0;
    from.recoil = 0.15;
    return ball;
  }

  bool _hitTest(Projectile ball, FighterState target) {
    final c = centerOf(target.side);
    final dx = (ball.x - c.x).abs();
    final dy = (ball.y - c.y).abs();
    return dx < arena.widthOf(target.side) * 0.55 &&
        dy < arena.heightOf(target.side) * 0.5;
  }

  double _applyHit(FighterState target, Projectile ball) {
    final base = tuning.damageFor(ball.power);
    final dmg = suddenDeath ? base * tuning.suddenDeathDamageMult : base;
    return target.takeDamage(dmg);
  }

  DuelEnded? _checkEnd(List<BattleEvent> events) {
    final leftDown = left.hp <= 0;
    final rightDown = right.hp <= 0;
    if (leftDown && rightDown) {
      return const DuelEnded(
          winnerSide: null, draw: true, reason: 'KOsimultaneo');
    }
    if (leftDown) {
      return const DuelEnded(winnerSide: 2, draw: false, reason: 'KO');
    }
    if (rightDown) {
      return const DuelEnded(winnerSide: 1, draw: false, reason: 'KO');
    }

    if (!suddenDeath && time >= tuning.suddenDeathAt) {
      suddenDeath = true;
      for (final f in [left, right]) {
        f.hp = math.min(f.hp, tuning.suddenDeathHpCap);
        f.shield = 0;
      }
    }

    if (time >= tuning.timeLimit) {
      if (left.hp > right.hp) {
        return const DuelEnded(winnerSide: 1, draw: false, reason: 'time');
      }
      if (right.hp > left.hp) {
        return const DuelEnded(winnerSide: 2, draw: false, reason: 'time');
      }
      return const DuelEnded(winnerSide: null, draw: true, reason: 'draw');
    }
    return null;
  }
}
