import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'src/i18n/l10n.dart';
import 'src/screens/home_screen.dart';
import 'src/state/battle_theme_controller.dart';
import 'src/state/eeg_store.dart';
import 'src/state/mode_controller.dart';
import 'src/state/progress_controller.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Overmind se usa siempre en horizontal: forzamos landscape en toda la app.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final store = EegStore();
  // En móvil intentamos habilitar BLE; en desktop (Linux) dejamos el flag para
  // que la UI ofrezca BLE si hay pila disponible y siempre el modo demo.
  store.init(store.isBleSupported);

  final themeController = BattleThemeController();
  themeController.load();

  final progress = ProgressController();
  progress.load();

  // El idioma se resuelve ANTES del primer frame: settings.json -> sistema -> ES.
  final locale = LocaleController();
  await locale.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => ModeController()),
        ChangeNotifierProvider.value(value: locale),
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider.value(value: progress),
      ],
      child: const OvermindApp(),
    ),
  );
}

class OvermindApp extends StatelessWidget {
  const OvermindApp({super.key});

  @override
  Widget build(BuildContext context) {
    // No se pinta nada hasta tener el locale resuelto: evita el parpadeo
    // ES -> EN del primer frame cuando el idioma guardado es inglés.
    final l10n = context.watch<LocaleController>();
    return MaterialApp(
      title: 'Overmind',
      debugShowCheckedModeBanner: false,
      theme: overmindTheme(),
      home: l10n.loaded ? const HomeScreen() : const SizedBox.shrink(),
    );
  }
}
