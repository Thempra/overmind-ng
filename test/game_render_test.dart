// Render de componentes de los juegos con un Canvas real (PictureRecorder),
// para cubrir los métodos render() que la lógica pura no ejercita.
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/game/games/balloon_game.dart';
import 'package:overmind/src/game/games/falcon_game.dart';
import 'package:overmind/src/game/games/seesaw_game.dart';
import 'package:vector_math/vector_math_64.dart';

import 'fake_audio.dart';
import 'game_logic_test_helpers.dart';

/// Renderiza todo el árbol montado con un Canvas de registro.
void renderTree(FlameGame game) {
  final pic = PictureRecorder();
  final canvas = Canvas(pic);
  void visit(Component c) {
    if (c.isMounted) c.render(canvas);
    if (c is ComponentSet) c.children.forEach(visit);
  }

  visit(game);
  pic.endRecording();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installFakeAudio();

  group('Render de componentes con Canvas real', () {
    testWithFlameGame('Balloon: render de todas las capas', (game) async {
      final e = eegWith(att: 80, med: 80);
      final logic = BalloonLogic(eeg: e, cal: calBaseline());
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      for (var i = 0; i < 130; i++) {
        logic.update(0.05, i * 0.05); // hincha y estalla varias veces
      }
      game.update(0); // monta los efectos de partículas
      renderTree(game);
      expect(logic.score(), greaterThan(0));
      logic.dispose();
    });

    testWithFlameGame('Falcon: render de vista y cometas', (game) async {
      final e = eegWith(att: 50, med: 50);
      final logic = FalconLogic(eeg: e);
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      logic.update(0.05, 0.05);
      game.update(0);
      renderTree(game);
      expect(logic.meterValue(), inInclusiveRange(0, 1));
      logic.dispose();
    });

    testWithFlameGame('Seesaw: render de vista', (game) async {
      final a = eegWith(att: 50, med: 50);
      final b = eegWith(att: 50, med: 50);
      final logic = SeesawLogic(eegs: [a, b], cal: calBaseline());
      await logic.build(game, Vector2(800, 600));
      await game.ready();
      logic.update(0.05, 0.05);
      game.update(0);
      renderTree(game);
      expect(logic.meterValue(), inInclusiveRange(0, 1));
      logic.dispose();
    });
  });
}
