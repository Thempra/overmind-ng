// Entrypoint TEMPORAL de verificación: arranca directamente la pantalla de
// juego con 2 fuentes EEG simuladas. NO es el main de producción.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/screens/game_screen.dart';
import 'src/state/eeg_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = EegStore();
  store.init(false);
  store.addSimulated(); // slot 0
  store.addSimulated(); // slot 1

  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        title: 'Overmind Demo',
        debugShowCheckedModeBanner: false,
        home: const GameScreen(player1Slot: 0, player2Slot: 1),
      ),
    ),
  );
}
