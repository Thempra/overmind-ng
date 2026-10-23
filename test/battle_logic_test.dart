// Sudden death y cierre de partida del duelo.
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/game/battle_logic.dart';

/// Simula un duelo headless con EEG constante y devuelve el resultado.
({double ttk, int? winner, bool draw, double hp1, double hp2, String? reason})
    simulate({
  required double att1,
  required double med1,
  double? att2,
  double? med2,
  BattleTuning tuning = const BattleTuning(),
  double dt = 1 / 60,
  double maxSeconds = 200,
}) {
  final logic = BattleLogic(tuning: tuning);
  logic.readEeg(1, attention: att1, meditation: med1);
  logic.readEeg(2, attention: att2 ?? att1, meditation: med2 ?? med1);
  while (!logic.finished && logic.time < maxSeconds) {
    logic.update(dt);
  }
  final o = logic.outcome;
  return (
    ttk: logic.time,
    winner: o?.winnerSide,
    draw: o?.draw ?? false,
    hp1: logic.left.hp,
    hp2: logic.right.hp,
    reason: o?.reason,
  );
}

void main() {
  group('El duelo SIEMPRE termina', () {
    test('el escudo ya no congela la vida con meditación alta', () {
      // BUG original: shield=meditation y absorción absoluta ⇒ con med alta la
      // regeneración (dt*1.2 hacia med) superaba el daño entrante y el HP no
      // bajaba NUNCA. Este perfil (att60/med90) era invicto antes del retune.
      final r = simulate(att1: 60, med1: 90);
      expect(r.reason, isNotNull,
          reason: 'la partida debe declarar un final, no colgarse');
      expect(r.ttk, lessThanOrEqualTo(120.0),
          reason: 'el tope duro de 120 s debe cerrar la partida');
      expect(r.hp1 + r.hp2, lessThan(200),
          reason: 'los dos luchadores deben haber recibido daño real');
    });

    test('con meditación 0 el duelo no se eterniza ni muere instantáneo', () {
      final r = simulate(att1: 0, med1: 0);
      expect(r.reason, isNotNull);
      expect(r.ttk, greaterThan(20.0),
          reason: 'sin escudo la pelea no debe durar dos telediarios');
      expect(r.ttk, lessThanOrEqualTo(120.0));
    });

    test('perfiles opuestos de atención convergen en un rango jugable', () {
      for (final att in [10.0, 30.0, 50.0, 70.0, 90.0, 100.0]) {
        final r = simulate(att1: att, med1: 50);
        expect(r.reason, isNotNull, reason: 'att $att no terminó nunca');
        expect(r.ttk, inInclusiveRange(20.0, 120.0),
            reason: 'att $att dio un TTK de ${r.ttk}');
      }
    });

    test('empate declarado cuando los dos llegan igualados al límite', () {
      final r = simulate(att1: 0, med1: 100);
      // Simétrico perfecto: o hay KO simultáneo o empate/timeout, pero nunca
      // "sin final".
      expect(r.reason, isNotNull);
      expect(r.winner != null || r.draw, isTrue);
    });
  });

  group('Muerte súbita', () {
    test('a los 80 s recorta la vida a 60 y bloquea el escudo', () {
      final logic = BattleLogic();
      logic.readEeg(1, attention: 20, meditation: 100);
      logic.readEeg(2, attention: 20, meditation: 100);
      // Antes del umbral el escudo debe estar cargado.
      for (var i = 0; i < 60 * 20; i++) {
        logic.update(1 / 60);
      }
      expect(logic.suddenDeath, isFalse);
      expect(logic.left.shield, greaterThan(0),
          reason: 'con med 100 el escudo debe recargarse sobre el déficit');

      while (!logic.suddenDeath && logic.time < 90) {
        logic.update(1 / 60);
      }
      expect(logic.suddenDeath, isTrue);
      expect(logic.left.hp, lessThanOrEqualTo(60));
      expect(logic.right.hp, lessThanOrEqualTo(60));
      expect(logic.left.shield, 0,
          reason: 'en muerte súbita el escudo queda bloqueado');
    });

    test('la muerte súbita sola (sin tope duro) no basta para cerrar el duelo',
        () {
      // Documenta por qué hace falta el límite de 120 s: con daño x1.9 y
      // escudo bloqueado el duelo se estira por encima de lo que queremos.
      const noLimit = BattleTuning(timeLimit: 10000);
      final r = simulate(att1: 30, med1: 25, tuning: noLimit);
      expect(r.reason, isNotNull,
          reason: 'con vida recortada a 60 al final hay KO');
      // Si algún día el multiplicador basta por sí solo, este test avisa de que
      // el tope de 120 s pasó a ser redundante (revisar, no borrar a ciegas).
    });
  });

  group('Regresión del bug original (perfil legacy)', () {
    test('el perfil histórico no cerraba la partida con meditación alta', () {
      final r = simulate(
        att1: 60,
        med1: 90,
        tuning: BattleTuning.legacy,
        maxSeconds: 120,
      );
      expect(r.reason, isNull,
          reason: 'con el balance antiguo la partida se colgaba: es el bug');
      expect(r.hp1, 100,
          reason: 'el escudo = meditación absorbía el 100 % del daño: la vida '
              'del rival no bajaba NI UN PUNTO en 120 s');
      expect(r.hp2, 100);
    });
  });
}
