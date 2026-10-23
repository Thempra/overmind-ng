// Watchdog por AUSENCIA de paquetes (2,5 s) + pausa/reanudación del motor.
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/eeg/eeg_data.dart';
import 'package:overmind/src/game/battle_logic.dart';
import 'package:overmind/src/game/signal_monitor.dart';

/// Reloj simulado: el watchdog usa el `dt` del motor, no el reloj del sistema.
class FrameClock {
  double t = 0;

  /// Simula [seconds] a 60 fps sin paquetes nuevos.
  void idle(SignalMonitor m, EegData? e, double seconds) {
    const dt = 1 / 60;
    for (var i = 0; i < (seconds * 60).floor(); i++) {
      t += dt;
      m.tick(e, dt);
    }
  }

  /// Simula [seconds] a 60 fps emitiendo un paquete cada [everyMs] ms.
  void alive(
    SignalMonitor m,
    EegData e,
    double seconds, {
    int everyMs = 1000,
    int poorSignal = 0,
  }) {
    final framesPerPacket = (everyMs / 1000 * 60).round();
    var f = 0;
    const dt = 1 / 60;
    for (var i = 0; i < (seconds * 60).floor(); i++) {
      t += dt;
      if (f == 0) {
        e.applyCapture(
          signal: poorSignal,
          attention: 60,
          meditation: 55,
          rawDelta: 100,
          rawTheta: 80,
          rawLowAlpha: 64,
          rawHighAlpha: 48,
          rawLowBeta: 32,
          rawHighBeta: 16,
          rawLowGamma: 10,
          rawHighGamma: 5,
        );
      }
      f = (f + 1) % framesPerPacket;
      m.tick(e, dt);
    }
  }
}

EegData freshEeg() => EegData(address: 'a', name: 'n', slot: 0);

void main() {
  group('Watchdog: pausa a los 2,5 s sin paquetes y NO antes', () {
    test('no pausa a 2,4 s (justo por debajo del umbral)', () {
      final e = freshEeg()
        ..applyCapture(
          signal: 0,
          attention: 60,
          meditation: 60,
          rawDelta: 100,
          rawTheta: 80,
          rawLowAlpha: 64,
          rawHighAlpha: 48,
          rawLowBeta: 32,
          rawHighBeta: 16,
          rawLowGamma: 10,
          rawHighGamma: 5,
        );
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.idle(m, e, 2.4);
      expect(m.state, isNot(SignalWatchState.lost));
      expect(m.shouldPause, isFalse,
          reason: 'un solo paquete perdido no puede pausar la partida');
      expect(m.secondsSincePacket, closeTo(2.4, 0.05));
    });

    test('pausa a los 2,5 s sin paquetes', () {
      final e = freshEeg()
        ..applyCapture(
          signal: 0,
          attention: 60,
          meditation: 60,
          rawDelta: 100,
          rawTheta: 80,
          rawLowAlpha: 64,
          rawHighAlpha: 48,
          rawLowBeta: 32,
          rawHighBeta: 16,
          rawLowGamma: 10,
          rawHighGamma: 5,
        );
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.idle(m, e, 2.55);
      expect(m.state, SignalWatchState.lost);
      expect(m.shouldPause, isTrue);
      expect(m.paused, isTrue);
    });

    test('un paquete intermedio reinicia el contador (no acumula)', () {
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.alive(m, e, 2.0); // 2 s con paquetes
      c.idle(m, e, 1.5); // 1,5 s de silencio
      expect(m.state, isNot(SignalWatchState.lost));
      c.alive(m, e, 3.0); // vuelven: nunca debe haber pausado
      expect(m.state, SignalWatchState.ok);
      expect(m.paused, isFalse);
    });

    test('dispositivo null (slot vacío) también dispara el watchdog', () {
      final m = SignalMonitor()..start(null);
      final c = FrameClock();
      c.idle(m, null, 2.55);
      expect(m.state, SignalWatchState.lost);
    });
  });

  group('Reconexión: se reanuda sola', () {
    test('takeResume devuelve true una sola vez al volver los paquetes', () {
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.idle(m, e, 3.0);
      expect(m.paused, isTrue);

      c.alive(m, e, 0.5);
      expect(m.state, SignalWatchState.ok);
      expect(m.takeResume(), isTrue);
      expect(m.paused, isFalse);
      expect(m.takeResume(), isFalse, reason: 'solo una reanudación');
    });

    test('reconecta aunque el casco vuelva con mal contacto', () {
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.alive(m, e, 1.0, everyMs: 500);
      c.idle(m, e, 3.0);
      expect(m.paused, isTrue);
      // Vuelven paquetes pero con poorSignal=200: el enlace está vivo.
      c.alive(m, e, 3.5, everyMs: 500, poorSignal: 200);
      expect(m.state, isNot(SignalWatchState.lost));
      expect(m.takeResume(), isTrue,
          reason: 'pausamos por falta de paquetes, no por mala calidad');
      expect(m.state, SignalWatchState.degraded);
      expect(m.showBanner, isTrue, reason: 'sigue avisando de la mala señal');
    });

    test('sin reconexión takeResume no dispara', () {
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.idle(m, e, 4.0);
      expect(m.takeResume(), isFalse);
      expect(m.paused, isTrue);
    });
  });

  group('Falsos positivos: señal mala CON paquetes no pausa', () {
    test('poorSignal=200 sostenido 10 s no pausa (el enlace sigue vivo)', () {
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.alive(m, e, 10.0, everyMs: 500, poorSignal: 200);
      expect(m.state, isNot(SignalWatchState.lost));
      expect(m.shouldPause, isFalse,
          reason: 'sin contacto NO es sin paquetes: pausar aquí sería el bug');
      expect(m.paused, isFalse);
      // Pero sí avisa: la banda de aviso debe estar visible.
      expect(m.state, SignalWatchState.degraded);
      expect(m.showBanner, isTrue);
    });

    test('EEG ruidoso (oscila 100-199) nunca pausa', () {
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      const noise = [120, 190, 145, 199, 160, 110, 175];
      var i = 0;
      for (var s = 0; s < 30; s++) {
        c.alive(m, e, 1.0, everyMs: 250, poorSignal: noise[i % noise.length]);
        i++;
        expect(m.state, isNot(SignalWatchState.lost),
            reason: 'segundo $s con contacto: no debe pausar');
      }
      expect(m.paused, isFalse);
    });

    test('la banda de aviso necesita 3 s de señal mala sostenida', () {
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.alive(m, e, 2.0, everyMs: 500, poorSignal: 200);
      expect(m.state, SignalWatchState.ok,
          reason: 'aún no han pasado 3 s de señal mala');
      c.alive(m, e, 1.5, everyMs: 500, poorSignal: 200);
      expect(m.state, SignalWatchState.degraded);
      expect(m.secondsBadSignal, greaterThanOrEqualTo(3.0));
    });

    test('recuperar la señal limpia el contador de "mala"', () {
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      c.alive(m, e, 4.0, everyMs: 500, poorSignal: 200);
      expect(m.state, SignalWatchState.degraded);
      c.alive(m, e, 1.0, everyMs: 250, poorSignal: 0);
      expect(m.state, SignalWatchState.ok);
      expect(m.secondsBadSignal, 0);
    });
  });

  group('BattleLogic: pauseEngine / resumeEngine de verdad', () {
    test('pausado no avanza tiempo ni simula', () {
      final logic = BattleLogic();
      logic.readEeg(1, attention: 80, meditation: 50);
      logic.readEeg(2, attention: 20, meditation: 50);
      for (var i = 0; i < 120; i++) {
        logic.update(1 / 60);
      }
      final t = logic.time;
      final hp1 = logic.left.hp;
      final hp2 = logic.right.hp;

      expect(logic.pauseEngine(), isTrue);
      expect(logic.paused, isTrue);
      // Los proyectiles ya en vuelo se congelan (no se mueven ni impactan).
      final flying = logic.projectiles.length;
      final posBefore = logic.projectiles.map((p) => p.x).toList();
      for (var i = 0; i < 600; i++) {
        expect(logic.update(1 / 60), isEmpty);
      }
      expect(logic.time, t, reason: 'el reloj no avanza en pausa');
      expect(logic.left.hp, hp1);
      expect(logic.right.hp, hp2);
      expect(logic.projectiles.length, flying);
      expect(logic.projectiles.map((p) => p.x).toList(), posBefore,
          reason: 'nada se mueve con el motor en pausa');
    });

    test('resumeEngine reanuda y la partida termina igual', () {
      final logic = BattleLogic();
      logic.readEeg(1, attention: 90, meditation: 90);
      logic.readEeg(2, attention: 90, meditation: 90);
      for (var i = 0; i < 300; i++) {
        logic.update(1 / 60);
      }
      logic.pauseEngine();
      for (var i = 0; i < 300; i++) {
        logic.update(1 / 60);
      }
      expect(logic.resumeEngine(), isTrue);
      expect(logic.paused, isFalse);
      var guard = 0;
      while (!logic.finished && guard++ < 20000) {
        logic.update(1 / 60);
      }
      expect(logic.finished, isTrue, reason: 'la pausa no cuelga la partida');
      expect(logic.outcome, isNotNull);
    });

    test('pauseEngine/resumeEngine son idempotentes', () {
      final logic = BattleLogic();
      expect(logic.resumeEngine(), isFalse, reason: 'ya estaba corriendo');
      expect(logic.pauseEngine(), isTrue);
      expect(logic.pauseEngine(), isFalse, reason: 'ya estaba pausado');
      expect(logic.resumeEngine(), isTrue);
      expect(logic.resumeEngine(), isFalse);
    });

    test('restart limpia la pausa', () {
      final logic = BattleLogic();
      logic.pauseEngine();
      logic.restart();
      expect(logic.paused, isFalse);
      expect(logic.time, 0);
    });
  });

  group('Integración motor + watchdog: el duelo se congela y vuelve', () {
    test('sin paquetes 3 s el motor queda pausado; al volver, sigue', () {
      final logic = BattleLogic();
      final e = freshEeg();
      final m = SignalMonitor()..start(e);
      final c = FrameClock();
      logic.readEeg(1, attention: 70, meditation: 40);
      logic.readEeg(2, attention: 70, meditation: 40);

      // 1 s de juego normal con paquetes.
      for (var i = 0; i < 60; i++) {
        c.alive(m, e, 1 / 60, everyMs: 250);
        if (m.shouldPause) logic.pauseEngine();
        logic.update(1 / 60);
      }
      expect(logic.paused, isFalse);
      final tOk = logic.time;
      expect(tOk, greaterThan(0));

      // 3 s de silencio: se pausa y el tiempo se congela.
      for (var i = 0; i < 180; i++) {
        c.idle(m, e, 1 / 60);
        if (m.shouldPause) logic.pauseEngine();
        logic.update(1 / 60);
      }
      expect(logic.paused, isTrue);
      final tPaused = logic.time;
      expect(tPaused, lessThan(tOk + 2.6));

      // Vuelven los paquetes: se reanuda solo.
      for (var i = 0; i < 120; i++) {
        c.alive(m, e, 1 / 60, everyMs: 250);
        if (m.takeResume()) logic.resumeEngine();
        logic.update(1 / 60);
      }
      expect(logic.paused, isFalse);
      expect(logic.time, greaterThan(tPaused));
    });
  });

  group('Dos jugadores: perder un solo enlace no congela la partida', () {
    test('si solo uno se cae, al volver se reanuda', () {
      final e1 = freshEeg();
      final e2 = freshEeg();
      final m1 = SignalMonitor()..start(e1);
      final m2 = SignalMonitor()..start(e2);
      final c = FrameClock();
      c.alive(m1, e1, 1.0, everyMs: 250);
      c.alive(m2, e2, 1.0, everyMs: 250);

      // Solo el jugador 1 pierde el enlace.
      c.idle(m1, e1, 3.0);
      c.alive(m2, e2, 3.0, everyMs: 250);
      expect(m1.shouldPause, isTrue);
      expect(m2.shouldPause, isFalse);

      // Vuelve: la reanudación del lado vivo no debe quedar bloqueada.
      c.alive(m1, e1, 1.0, everyMs: 250);
      final resumed = m1.takeResume() | m2.takeResume();
      expect(resumed, isTrue);
      expect(m1.linkAlive && m2.linkAlive, isTrue,
          reason:
              'con un solo lado caído, exigir ambos takeResume colgaría el duelo');
    });
  });

  group('Umbral declarado', () {
    test('timeout 2,5 s y aviso 3 s por defecto', () {
      final m = SignalMonitor();
      expect(m.packetTimeout, const Duration(milliseconds: 2500));
      expect(m.badSignalHold, const Duration(seconds: 3));
    });
  });
}
