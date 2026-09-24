import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_audio.dart';
import 'package:overmind/src/eeg/eeg_data.dart';
import 'package:overmind/src/game/games/balloon_game.dart';
import 'package:overmind/src/game/mind_game_session.dart';
import 'package:overmind/src/game/signal_processor.dart';
import 'package:overmind/src/i18n/l10n.dart';
import 'package:overmind/src/state/eeg_store.dart';
import 'package:overmind/src/state/progress_controller.dart';
import 'package:provider/provider.dart';

class _DummyLogic extends GameLogic {
  int updates = 0;
  @override
  Future<void> build(FlameGame game, Vector2 size) async {}
  @override
  void update(double dt, double t) => updates++;
  @override
  double meterValue() => 0.5;
  @override
  int score() => 42;
}

Widget _wrap(Widget child, EegStore store, ProgressController prog) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => LocaleController()),
      ChangeNotifierProvider.value(value: prog),
    ],
    child: MaterialApp(home: child),
  );
}

EegData liveEeg() {
  final e = EegData(address: 'a', name: 'n', slot: 0);
  e.applyCapture(
    signal: 0,
    attention: 70,
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
  return e;
}

void main() {
  group('MindGameSession scaffold', () {
    testWidgets('calibración -> juego -> resultados con récord', (tester) async {
      final store = EegStore();
      store.addSimulated(); // slot 0 ocupado
      store.devices[0]!.address = 'sim:0';
      final prog = ProgressController();
      late _DummyLogic created;

      await tester.pumpWidget(
        _wrap(
          MindGameSession(
            gameId: 'dummy',
            title: 'DUMMY',
            accent: Colors.pink,
            calibrateInstruction: 'Relájate',
            durationSec: 2,
            slots: const [0],
            logicBuilder: (eegs, cal) => created = _DummyLogic(),
          ),
          store,
          prog,
        ),
      );

      // Fase de calibración: instrucción visible
      expect(find.text('Relájate'), findsOneWidget);
      expect(find.text('DUMMY'), findsOneWidget);

      // Avanzar la calibración (5 s) + juego (2 s) a base de pumps.
      // El GameWidget corre con el reloj del tester.
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump();

      // Deberíamos estar en resultados: puntuación del DummyLogic (42)
      expect(find.textContaining('42'), findsWidgets);
      expect(prog.best['dummy'], 42); // récord registrado
      expect(created.updates, greaterThan(0));

      // Detener la fuente simulada (Timer.periodic) antes del teardown.
      await store.removeAt(0);
      await tester.pump();

      // Botones de resultados: revancha reinicia a calibración
      await tester.tap(find.text('Revancha'));
      await tester.pump();
      expect(find.text('Relájate'), findsOneWidget);
    });

    testWidgets('salir hace pop', (tester) async {
      final store = EegStore();
      store.addSimulated();
      final prog = ProgressController();
      final nav = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => LocaleController()),
            ChangeNotifierProvider.value(value: prog),
          ],
          child: MaterialApp(
            navigatorKey: nav,
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => MindGameSession(
                      gameId: 'x',
                      title: 'X',
                      accent: Colors.blue,
                      calibrateInstruction: 'CAL',
                      durationSec: 1,
                      slots: const [0],
                      logicBuilder: (e, c) => _DummyLogic(),
                    ),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Salir'), findsOneWidget);
      await tester.tap(find.text('Salir'));
      await tester.pump();
      await store.removeAt(0); // cancela el Timer periódico de la simulación
      await tester.pump();
      expect(find.text('go'), findsOneWidget);
    });
  });
}
