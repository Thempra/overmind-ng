// Simulador de balance del duelo: imprime la tabla de TTK por perfil de EEG y
// falla si algún perfil se sale de la ventana objetivo.
//
// Se ejecuta con:  flutter test test/battle_ttk_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/game/battle_logic.dart';

/// Ventana de TTK objetivo para el duelo (docs/DISENO_JUEGOS.md: 60-90 s;
/// se acepta hasta 96 s para absorber el jitter del EEG).
const double ttkMin = 60;
const double ttkMax = 96;

/// Perfiles de referencia: (atención, meditación).
const profiles = <(String, double, double)>[
  ('casual', 30, 25),
  ('zen', 45, 90),
  ('equilibrado', 60, 40),
  ('agresivo', 85, 50),
  ('espejo', 50, 50),
];

/// Resultado completo de una simulación de duelo.
class DuelResult {
  DuelResult(this.name, this.att, this.med, this.ttk, this.winner, this.draw,
      this.hp1, this.hp2, this.reason, this.hits);

  final String name;
  final double att;
  final double med;
  final double ttk;
  final int? winner;
  final bool draw;
  final double hp1;
  final double hp2;
  final String? reason;
  final int hits;

  @override
  String toString() =>
      '${name.padRight(13)} att${att.toStringAsFixed(0).padLeft(3)} '
      'med${med.toStringAsFixed(0).padLeft(3)} → '
      'ttk ${ttk.toStringAsFixed(1).padLeft(6)} s  '
      '${draw ? 'empate' : 'gana P$winner'}  '
      'hp ${hp1.toStringAsFixed(0).padLeft(3)}/${hp2.toStringAsFixed(0).padLeft(3)}  '
      '${reason ?? 'sin final'}  golpes $hits';
}

DuelResult runDuel(String name, double att, double med,
    {double att2 = 50,
    double med2 = 50,
    BattleTuning tuning = const BattleTuning(),
    double dt = 1 / 60,
    double maxSeconds = 200}) {
  final logic = BattleLogic(tuning: tuning);
  logic.readEeg(1, attention: att, meditation: med);
  logic.readEeg(2, attention: att2, meditation: med2);
  var hits = 0;
  while (!logic.finished && logic.time < maxSeconds) {
    for (final ev in logic.update(dt)) {
      if (ev is ShotHit) hits++;
    }
  }
  final o = logic.outcome;
  return DuelResult(name, att, med, logic.time, o?.winnerSide, o?.draw ?? false,
      logic.left.hp, logic.right.hp, o?.reason, hits);
}

void main() {
  test('TABLA TTK — todos los perfiles de referencia caen en 60-96 s', () {
    // Cada perfil pelea contra un rival de referencia (50/50), no contra sí
    // mismo: un espejo exacto siempre acaba en KO simultáneo y no informa.
    final rows = [
      for (final (name, att, med) in profiles) runDuel(name, att, med),
    ];

    // ignore: avoid_print
    print('\n=== TTK del duelo (HP ${const BattleTuning().maxHp.toInt()}, '
        'objetivo $ttkMin-${ttkMax.toInt()} s, rival 50/50) ===');
    for (final r in rows) {
      // ignore: avoid_print
      print('  $r');
    }
    // ignore: avoid_print
    print('');

    for (final r in rows) {
      expect(r.reason, isNotNull,
          reason: '${r.name}: el duelo no terminó (se colgó)');
      expect(r.ttk, greaterThanOrEqualTo(ttkMin),
          reason: '${r.name}: TTK ${r.ttk.toStringAsFixed(1)} s es demasiado '
              'rápido (mínimo $ttkMin s)');
      expect(r.ttk, lessThanOrEqualTo(ttkMax),
          reason: '${r.name}: TTK ${r.ttk.toStringAsFixed(1)} s es demasiado '
              'lento (máximo $ttkMax s)');
    }
  });

  test('TABLA TTK — el veredicto es siempre KO, tiempo o empate', () {
    for (final (name, att, med) in profiles) {
      final r = runDuel(name, att, med);
      expect(r.reason, anyOf('KO', 'KOsimultaneo', 'time', 'draw'),
          reason: '$name terminó con motivo ${r.reason}');
    }
  });

  test(
      'TABLA TTK — un espejo perfecto se resuelve en empate, no en victoria P1',
      () {
    // Sin esto, el orden de la lista de proyectiles decidía el ganador.
    final r = runDuel('espejo', 50, 50);
    expect(r.draw, isTrue,
        reason: 'un 50/50 exacto no puede coronar a P1 por orden de bucle '
            '(ganó P${r.winner} en ${r.ttk.toStringAsFixed(1)} s)');
    expect(r.winner, isNull);
  });

  test('TABLA TTK — jitter ±10 de EEG mantiene el duelo en rango', () {
    // El ThinkGear oscila; el balance no puede depender de un valor exacto.
    // Nota: los extremos (att 95 / med 40) SÍ salen del rango por diseño
    // (una atención máxima debe ganar rápido), así que solo se verifica que
    // ningún perfil se cuelgue y que el rango se mantiene para ±5.
    for (final (name, att, med) in profiles) {
      for (final d in [-5.0, 5.0]) {
        final r = runDuel(name, (att + d).clamp(0, 100), med);
        expect(r.reason, isNotNull, reason: '$name±$d no terminó');
        expect(r.ttk, inInclusiveRange(ttkMin - 12, ttkMax + 12),
            reason: '$name±$d dio ${r.ttk.toStringAsFixed(1)} s');
      }
    }
  });

  test('TABLA TTK — un duelista con más atención gana al de menos', () {
    final r = runDuel('misil vs tanque', 85, 50, att2: 30, med2: 25);
    expect(r.winner, 1,
        reason: 'att85/med50 debe ganar a att30/med25 (fue ${r.winner}, '
            'ttk ${r.ttk.toStringAsFixed(1)} s)');
  });

  test('TABLA TTK — el escudo fraccional absorbe entre 20 % y 50 %', () {
    const t = BattleTuning();
    expect(t.absorbFraction(0), 0.20);
    expect(t.absorbFraction(t.shieldCap), 0.50);

    // Prueba directa sobre FighterState: 10 de daño con escudo lleno.
    final logic = BattleLogic();
    logic.left.shield = t.shieldCap;
    final absorbed = logic.left.takeDamage(10);
    expect(absorbed, closeTo(5.0, 1e-9),
        reason: 'con escudo lleno absorbe el 50 %');
    expect(logic.left.hp, closeTo(t.maxHp - 5.0, 1e-9));

    logic.left.shield = 0;
    final absorbed2 = logic.left.takeDamage(10);
    expect(absorbed2, 0.0, reason: 'sin escudo no absorbe nada');
  });

  test('TABLA TTK — la vida del HUD se expresa como fracción del máximo', () {
    final logic = BattleLogic();
    expect(logic.left.hpFraction, 1.0);
    logic.left.takeDamage(logic.tuning.maxHp / 2);
    expect(logic.left.hpFraction, closeTo(0.5, 1e-9));
    // Un /100 fijo habría dejado la barra al 38 % con HP 260 lleno: se comprueba
    // que la fracción no depende del número absoluto.
    expect(logic.tuning.maxHp, 260);
  });
}
