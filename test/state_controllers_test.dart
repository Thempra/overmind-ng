import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/game/battle_theme.dart';
import 'package:overmind/src/i18n/l10n.dart';
import 'package:overmind/src/state/battle_theme_controller.dart';
import 'package:overmind/src/state/mode_controller.dart';
import 'package:overmind/src/state/progress_controller.dart';

String dayOffset(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

void main() {
  group('ProgressController', () {
    test('récord, puntos mentales y notify', () {
      final p = ProgressController();
      var notifications = 0;
      p.addListener(() => notifications++);

      expect(p.record('balloon', 100), isTrue); // récord sobre 0
      expect(p.record('balloon', 50), isFalse); // no supera
      expect(p.record('balloon', 150), isTrue);
      expect(p.best['balloon'], 150);
      expect(p.mentalPoints, 300);
      expect(p.streakDays, 1); // primera partida del día
      expect(notifications, 3);
    });

    test('jugar dos veces hoy no duplica la racha', () {
      final p = ProgressController()..record('x', 1);
      p.record('x', 2);
      expect(p.streakDays, 1);
      expect(p.lastPlayedDay, isNotNull);
    });

    test('hueco de 1 día con congelador disponible la perdona', () {
      final p = ProgressController()
        ..streakDays = 5
        ..lastPlayedDay = dayOffset(-2);
      p.record('x', 1);
      expect(p.streakDays, 6);
      expect(p.frozenDay, dayOffset(-1)); // consumido
    });

    test('hueco de 1 día con congelador ya usado rompe la racha', () {
      final p = ProgressController()
        ..streakDays = 5
        ..lastPlayedDay = dayOffset(-2)
        ..frozenDay = dayOffset(-1);
      p.record('x', 1);
      expect(p.streakDays, 1);
    });

    test('hueco mayor rompe la racha y vuelve a 1', () {
      final p = ProgressController()
        ..streakDays = 9
        ..lastPlayedDay = dayOffset(-5);
      p.record('x', 1);
      expect(p.streakDays, 1);
    });

    test('cada 7 días de racha se gana un congelador', () {
      final p = ProgressController()
        ..streakDays = 6
        ..lastPlayedDay = dayOffset(-1);
      p.record('x', 1); // -> 7
      expect(p.streakDays, 7);
      expect(p.frozenDay, dayOffset(0));
    });

    test('yesterdayOf formatea con ceros', () {
      expect(ProgressController.yesterdayOf('2026-03-01'), '2026-02-28');
      expect(ProgressController.yesterdayOf('2026-01-01'), '2025-12-31');
    });

    test('load con archivo inexistente no lanza', () async {
      final p = ProgressController();
      await p.load(); // path_provider no disponible en test -> catch
      expect(p.best, isEmpty);
    });
  });

  group('ModeController', () {
    test('por defecto jugador; notifica solo en cambio real', () {
      final m = ModeController();
      expect(m.mode, OvermindMode.player);
      var n = 0;
      m.addListener(() => n++);
      m.mode = OvermindMode.researcher;
      m.mode = OvermindMode.researcher; // no-op
      expect(m.mode, OvermindMode.researcher);
      expect(n, 1);
    });
  });

  group('LocaleController', () {
    test('es por defecto, cambio a en y no-op al repetir', () {
      final l = LocaleController();
      expect(l.locale.languageCode, 'es');
      expect(l.s.leave, isNotEmpty);
      var n = 0;
      l.addListener(() => n++);
      l.setLocale('en');
      l.setLocale('en');
      expect(l.locale.languageCode, 'en');
      expect(n, 1);
      expect(
        AppStrings.es.play != AppStrings.en.play,
        isTrue,
      ); // textos reales distintos
    });
  });

  group('BattleTheme / controller', () {
    test('byId conocido y fallback', () {
      expect(BattleTheme.byId('superpoderes').id, 'superpoderes');
      expect(BattleTheme.byId('no-existe').id, 'evangelion');
      expect(BattleTheme.evangelion.name('en'), 'Evangelion');
      expect(BattleTheme.superpoderes.name('es'), 'Superpoderes');
      expect(BattleTheme.all, hasLength(2));
    });

    test('setTheme cambia y notifica una vez', () {
      final c = BattleThemeController();
      expect(c.theme.id, 'evangelion');
      var n = 0;
      c.addListener(() => n++);
      c.setTheme(BattleTheme.superpoderes);
      c.setTheme(BattleTheme.superpoderes); // mismo id: no-op
      expect(c.theme.id, 'superpoderes');
      expect(n, 1);
    });

    test('load sin plugin no lanza ni cambia el tema', () async {
      final c = BattleThemeController();
      await c.load();
      expect(c.theme.id, 'evangelion');
    });
  });
}
