import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/screens/home_screen.dart';
import 'src/state/eeg_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = EegStore();
  // En móvil intentamos habilitar BLE; en desktop (Linux) dejamos el flag para
  // que la UI ofrezca BLE si hay pila disponible y siempre el modo demo.
  store.init(store.isBleSupported);

  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const OvermindApp(),
    ),
  );
}

class OvermindApp extends StatelessWidget {
  const OvermindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Overmind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C800)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
