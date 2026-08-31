import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../game/battle_theme.dart';

/// Controla el tema de partida seleccionado y lo persiste en disco
/// (archivo JSON simple en el directorio de soporte de la app), de modo que
/// se recuerde entre sesiones sin depender de servicios externos.
class BattleThemeController extends ChangeNotifier {
  BattleTheme _theme = BattleTheme.evangelion;
  BattleTheme get theme => _theme;

  void setTheme(BattleTheme t) {
    if (t.id == _theme.id) return;
    _theme = t;
    notifyListeners();
    _persist(t.id);
  }

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/battle_theme.json');
      if (await f.exists()) {
        final id = (await f.readAsString()).trim();
        _theme = BattleTheme.byId(id);
        notifyListeners();
      }
    } catch (_) {
      // Si no se puede leer, nos quedamos con el tema por defecto.
    }
  }

  Future<void> _persist(String id) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/battle_theme.json');
      await f.writeAsString(id);
    } catch (_) {}
  }
}
