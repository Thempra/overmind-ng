import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/battle_game.dart';
import '../state/battle_theme_controller.dart';
import '../state/eeg_store.dart';

/// Pantalla que aloja el [BattleGame] (FLAME) con el overlay de fin de partida.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.player1Slot,
    required this.player2Slot,
  });

  final int player1Slot;
  final int player2Slot;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late BattleGame _game;

  @override
  void initState() {
    super.initState();
    // La batalla siempre en horizontal y a pantalla completa (inmersivo).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _game = BattleGame(
      store: context.read<EegStore>(),
      player1Slot: widget.player1Slot,
      player2Slot: widget.player2Slot,
      theme: context.read<BattleThemeController>().theme,
    );
  }

  @override
  void dispose() {
    // Restaurar orientación vertical y UI del sistema al salir.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _game.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'gameOver': (context, game) => _GameOverOverlay(
                game: game as BattleGame,
                onExit: () => Navigator.of(context).pop(),
              ),
        },
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.game, required this.onExit});

  final BattleGame game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color.fromRGBO(0, 0, 0, 0.75),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              game.winner ?? 'Game Over',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: game.restart,
                  child: const Text('Revancha'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onExit,
                  child: const Text('Salir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
