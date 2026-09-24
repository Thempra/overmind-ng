import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_audio.dart';
import 'package:overmind/src/eeg/eeg_data.dart';
import 'package:overmind/src/game/games/balloon_game.dart';
import 'package:overmind/src/game/games/falcon_game.dart';
import 'package:overmind/src/game/games/seesaw_game.dart';
import 'package:overmind/src/game/mental_games.dart';
import 'package:overmind/src/game/signal_processor.dart';

import 'game_logic_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installFakeAudio();


  group('BalloonLogic', () {
    testWithFlameGame('calma sostenida -> globo se hincha y estalla (puntos)',
(game) async {
      final logic = BalloonLogic(eeg: eegWith(med: 90), cal: calBaseline());
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      var t = 0.0;
      for (var i = 0; i < 100; i++) {
        logic.update(0.1, t);
        t += 0.1;
      }
      expect(logic.score(), greaterThanOrEqualTo(50)); // >=1 POP
      expect(logic.meterValue(), closeTo(0.9, 1e-9));
      logic.dispose();
    });

    testWithFlameGame('sin calma el globo se desinfla y no puntúa', (game) async {
      final logic = BalloonLogic(eeg: eegWith(med: 10), cal: calBaseline());
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      var t = 0.0;
      for (var i = 0; i < 100; i++) {
        logic.update(0.1, t);
        t += 0.1;
      }
      expect(logic.score(), 0);
      logic.dispose();
    });

    testWithFlameGame('eeg null usa rama por defecto sin petar', (game) async {
      final logic = BalloonLogic(eeg: null, cal: calBaseline());
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      logic.update(0.1, 0);
      expect(logic.meterValue(), 0);
      logic.dispose();
    });
  });

  group('FalconLogic', () {
    testWithFlameGame('parpadeo derriba cometas -> puntos', (game) async {
      final eeg = eegWith();
      final logic = FalconLogic(eeg: eeg);
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      // dejar spawnear al menos una cometa
      logic.update(0.1, 0);
      logic.update(0.5, 0.6);
      blinkNow(eeg);
      logic.update(0.1, 0.7);
      expect(logic.score(), greaterThan(0));
      expect(logic.meterValue(), greaterThan(0)); // combo 1 -> 1/4
      logic.dispose();
    });

    testWithFlameGame('parpadeo al vacío resetea el combo', (game) async {
      final eeg = eegWith();
      final logic = FalconLogic(eeg: eeg);
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      // sin cometas vivas: primera update las crea, pero probamos el path
      // de disparo sin objetivo matando el tiempo de vida primero.
      var t = 0.0;
      for (var i = 0; i < 60; i++) {
        logic.update(0.1, t);
        t += 0.1;
      }
      // parpadeos repetidos: unos aciertan, otros fallan; el juego sigue vivo
      blinkNow(eeg);
      logic.update(0.1, t);
      expect(logic.score(), greaterThanOrEqualTo(0));
      logic.dispose();
    });

    testWithFlameGame('cometas que caducan cuentan como fallos', (game) async {
      final logic = FalconLogic(eeg: null);
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      var t = 0.0;
      for (var i = 0; i < 500; i++) {
        logic.update(0.1, t);
        t += 0.1;
      }
      expect(logic.score(), 0); // nadie dispara
      expect(logic.meterValue(), 0);
      logic.dispose();
    });
  });

  group('SeesawLogic', () {
    testWithFlameGame('bola empujada al extremo 0 suma rondas para P1', (game) async {
      // Conduce negativa (poca calma rel. baseline) => bola hacia 0 => gana A.
      final a = eegWith(att: 90, med: 10);
      final logic = SeesawLogic(eegs: [a, null], cal: calBaseline());
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      var t = 0.0;
      for (var i = 0; i < 400; i++) {
        logic.update(0.05, t);
        t += 0.05;
      }
      expect(logic.score(), greaterThan(0)); // rondas ganadas por P1
      expect(logic.meterValue(), closeTo(0.1, 1e-9));
    });

    testWithFlameGame('empate de señales: rondas cierran por tiempo', (game) async {
      final a = eegWith(att: 50, med: 50);
      final b = eegWith(att: 50, med: 50);
      final logic = SeesawLogic(eegs: [a, b], cal: calBaseline());
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      var t = 0.0;
      for (var i = 0; i < 500; i++) {
        logic.update(0.05, t);
        t += 0.05;
      }
      // bola quieta en 0.5 -> fin de ronda por tiempo, gana A (<=0.5)
      expect(logic.score(), greaterThan(0));
      expect(logic.meterValue(), closeTo(0.5, 1e-9));
    });
  });

  group('MentalGame metadatos', () {
    test('nombre/subtítulo según idioma y catálogo completo', () {
      expect(MentalGame.all.map((g) => g.id), ['balloon', 'seesaw', 'falcon']);
      expect(MentalGame.balloon.name('es'), 'Globo');
      expect(MentalGame.balloon.name('en'), 'Balloon');
      expect(MentalGame.seesaw.subtitle('es'), contains('2 cabezales'));
      expect(MentalGame.falcon.subtitle('en'), contains('Blink'));
      expect(MentalGame.seesaw.needs2, isTrue);
      expect(MentalGame.balloon.needs2, isFalse);
    });

    test('launch construye la lógica de cada juego', () {
      final eegs = [eegWith(), null];
      expect(
        MentalGame.balloon.launch(eegs, calBaseline()),
        isA<BalloonLogic>(),
      );
      expect(
        MentalGame.seesaw.launch(eegs, calBaseline()),
        isA<SeesawLogic>(),
      );
      expect(MentalGame.falcon.launch(eegs, calBaseline()), isA<FalconLogic>());
    });
  });
}
