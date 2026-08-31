import 'package:flutter/foundation.dart';

/// Modos de la app: jugar o investigar (analizar señales).
enum OvermindMode { player, researcher }

/// Estado global del modo activo, compartido entre HomeScreen,
/// ModeSelectionScreen y SettingsScreen.
class ModeController extends ChangeNotifier {
  OvermindMode _mode = OvermindMode.player; // por defecto: modo jugador

  OvermindMode get mode => _mode;

  set mode(OvermindMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
  }
}
