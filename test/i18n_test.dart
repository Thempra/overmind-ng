import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/i18n/l10n.dart';

/// Accesor de cada campo de [AppStrings], para poder recorrerlos todos sin
/// reflexión (no disponible en AOT) y comprobar paridad ES/EN.
typedef _Field = (String, String Function(AppStrings));

const List<_Field> _fields = [
  ('playerMode', _playerMode),
  ('researcherMode', _researcherMode),
  ('settings', _settings),
  ('bluetooth', _bluetooth),
  ('language', _language),
  ('comingSoon', _comingSoon),
  ('attentionMeditation', _attentionMeditation),
  ('waveLevels', _waveLevels),
  ('selectGame', _selectGame),
  ('onePlayer', _onePlayer),
  ('twoPlayers', _twoPlayers),
  ('demoMode', _demoMode),
  ('onePlayerSub', _onePlayerSub),
  ('demoModeSub', _demoModeSub),
  ('scanBle', _scanBle),
  ('scanning', _scanning),
  ('bonded', _bonded),
  ('bondedLabel', _bondedLabel),
  ('bondedFailed', _bondedFailed),
  ('addDemo', _addDemo),
  ('connected', _connected),
  ('devices', _devices),
  ('discovered', _discovered),
  ('connect', _connect),
  ('connectFailed', _connectFailed),
  ('noDevices', _noDevices),
  ('noDevicesHint', _noDevicesHint),
  ('noDevicesFound', _noDevicesFound),
  ('play', _play),
  ('pickPlayer', _pickPlayer),
  ('pickTwo', _pickTwo),
  ('needTwoReal', _needTwoReal),
  ('battle', _battle),
  ('player', _player),
  ('leave', _leave),
  ('rematch', _rematch),
  ('demo', _demo),
  ('done', _done),
  ('gameMode', _gameMode),
  ('device', _device),
  ('analysis', _analysis),
  ('mindLevels', _mindLevels),
  ('signal', _signal),
  ('signalGood', _signalGood),
  ('attention', _attention),
  ('meditation', _meditation),
  ('lowAlpha', _lowAlpha),
  ('highAlpha', _highAlpha),
  ('lowBeta', _lowBeta),
  ('highBeta', _highBeta),
  ('lowGamma', _lowGamma),
  ('highGamma', _highGamma),
  ('attShort', _attShort),
  ('medShort', _medShort),
  ('lowAlphaShort', _lowAlphaShort),
  ('highAlphaShort', _highAlphaShort),
  ('lowBetaShort', _lowBetaShort),
  ('highBetaShort', _highBetaShort),
  ('lowGammaShort', _lowGammaShort),
  ('highGammaShort', _highGammaShort),
  ('signalOffline', _signalOffline),
  ('signalBadHint', _signalBadHint),
  ('reconnecting', _reconnecting),
  ('reconnectingHint', _reconnectingHint),
  ('demoChip', _demoChip),
];

String _playerMode(AppStrings s) => s.playerMode;
String _researcherMode(AppStrings s) => s.researcherMode;
String _settings(AppStrings s) => s.settings;
String _bluetooth(AppStrings s) => s.bluetooth;
String _language(AppStrings s) => s.language;
String _comingSoon(AppStrings s) => s.comingSoon;
String _attentionMeditation(AppStrings s) => s.attentionMeditation;
String _waveLevels(AppStrings s) => s.waveLevels;
String _selectGame(AppStrings s) => s.selectGame;
String _onePlayer(AppStrings s) => s.onePlayer;
String _twoPlayers(AppStrings s) => s.twoPlayers;
String _demoMode(AppStrings s) => s.demoMode;
String _onePlayerSub(AppStrings s) => s.onePlayerSub;
String _demoModeSub(AppStrings s) => s.demoModeSub;
String _scanBle(AppStrings s) => s.scanBle;
String _scanning(AppStrings s) => s.scanning;
String _bonded(AppStrings s) => s.bonded;
String _bondedLabel(AppStrings s) => s.bondedLabel;
String _bondedFailed(AppStrings s) => s.bondedFailed;
String _addDemo(AppStrings s) => s.addDemo;
String _connected(AppStrings s) => s.connected;
String _devices(AppStrings s) => s.devices;
String _discovered(AppStrings s) => s.discovered;
String _connect(AppStrings s) => s.connect;
String _connectFailed(AppStrings s) => s.connectFailed;
String _noDevices(AppStrings s) => s.noDevices;
String _noDevicesHint(AppStrings s) => s.noDevicesHint;
String _noDevicesFound(AppStrings s) => s.noDevicesFound;
String _play(AppStrings s) => s.play;
String _pickPlayer(AppStrings s) => s.pickPlayer;
String _pickTwo(AppStrings s) => s.pickTwo;
String _needTwoReal(AppStrings s) => s.needTwoReal;
String _battle(AppStrings s) => s.battle;
String _player(AppStrings s) => s.player;
String _leave(AppStrings s) => s.leave;
String _rematch(AppStrings s) => s.rematch;
String _demo(AppStrings s) => s.demo;
String _done(AppStrings s) => s.done;
String _gameMode(AppStrings s) => s.gameMode;
String _device(AppStrings s) => s.device;
String _analysis(AppStrings s) => s.analysis;
String _mindLevels(AppStrings s) => s.mindLevels;
String _signal(AppStrings s) => s.signal;
String _signalGood(AppStrings s) => s.signalGood;
String _attention(AppStrings s) => s.attention;
String _meditation(AppStrings s) => s.meditation;
String _lowAlpha(AppStrings s) => s.lowAlpha;
String _highAlpha(AppStrings s) => s.highAlpha;
String _lowBeta(AppStrings s) => s.lowBeta;
String _highBeta(AppStrings s) => s.highBeta;
String _lowGamma(AppStrings s) => s.lowGamma;
String _highGamma(AppStrings s) => s.highGamma;
String _attShort(AppStrings s) => s.attShort;
String _medShort(AppStrings s) => s.medShort;
String _lowAlphaShort(AppStrings s) => s.lowAlphaShort;
String _highAlphaShort(AppStrings s) => s.highAlphaShort;
String _lowBetaShort(AppStrings s) => s.lowBetaShort;
String _highBetaShort(AppStrings s) => s.highBetaShort;
String _lowGammaShort(AppStrings s) => s.lowGammaShort;
String _highGammaShort(AppStrings s) => s.highGammaShort;
String _signalOffline(AppStrings s) => s.signalOffline;
String _signalBadHint(AppStrings s) => s.signalBadHint;
String _reconnecting(AppStrings s) => s.reconnecting;
String _reconnectingHint(AppStrings s) => s.reconnectingHint;
String _demoChip(AppStrings s) => s.demoChip;

/// Claves nuevas de esta iteración (las que faltaban para cerrar el i18n).
const List<String> _newKeys = [
  'gameMode',
  'device',
  'analysis',
  'mindLevels',
  'signal',
  'signalGood',
  'attention',
  'meditation',
  'lowAlpha',
  'highAlpha',
  'lowBeta',
  'highBeta',
  'lowGamma',
  'highGamma',
  'attShort',
  'medShort',
  'lowAlphaShort',
  'highAlphaShort',
  'lowBetaShort',
  'highBetaShort',
  'lowGammaShort',
  'highGammaShort',
  'signalOffline',
  'signalBadHint',
  'reconnecting',
  'reconnectingHint',
  'demoChip',
];

/// Claves cuyo texto es legítimamente idéntico en ambos idiomas (marca
/// registrada / término técnico que no se traduce).
const Set<String> _sameInBoth = {'bluetooth', 'demo', 'demoChip'};

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('overmind_settings_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  LocaleSettingsStore storeIn(Directory dir) =>
      LocaleSettingsStore(dirProvider: () async => dir);

  group('AppStrings paridad ES/EN', () {
    test('todas las claves tienen ES y EN no vacíos y distintos', () {
      for (final (name, get) in _fields) {
        final es = get(AppStrings.es);
        final en = get(AppStrings.en);
        expect(es.trim(), isNotEmpty, reason: '$name vacío en ES');
        expect(en.trim(), isNotEmpty, reason: '$name vacío en EN');
        if (_sameInBoth.contains(name)) continue;
        expect(es, isNot(equals(en)), reason: '$name idéntico en ES y EN');
      }
    });

    test('las claves nuevas están todas en la lista y traducidas', () {
      final names = _fields.map((f) => f.$1).toSet();
      for (final key in _newKeys) {
        expect(names, contains(key), reason: '$key no se comprueba');
      }
      // Sin duplicados en la tabla de comprobación.
      expect(names.length, _fields.length);
    });

    test('etiquetas del analizador traducidas (no quedan literales ES)', () {
      expect(AppStrings.en.analysis, 'Analysis');
      expect(AppStrings.en.mindLevels, 'Mind Levels');
      expect(AppStrings.en.signal, 'Signal');
      expect(AppStrings.en.signalGood, '0 = good');
      expect(AppStrings.en.attention, 'Attention');
      expect(AppStrings.en.meditation, 'Meditation');
      expect(AppStrings.en.device, 'Device');
      expect(AppStrings.en.gameMode, 'Game mode');
      expect(AppStrings.en.rematch, 'Rematch');
      expect(AppStrings.en.leave, 'Leave');
      // Textos de diagnóstico de señal (Track D).
      expect(AppStrings.es.signalOffline, 'SIN SEÑAL');
      expect(AppStrings.en.signalOffline, 'NO SIGNAL');
      expect(AppStrings.es.reconnecting, 'RECONECTANDO');
      expect(AppStrings.en.reconnecting, 'RECONNECTING');
      expect(AppStrings.es.demoChip, AppStrings.en.demoChip, reason: 'DEMO');
      expect(
        [AppStrings.es.analysis, AppStrings.es.signal].join(),
        'AnálisisSeñal',
      );
    });
  });

  group('LocaleController toggle', () {
    test('arranca en no cargado y ES; load marca loaded', () async {
      final c = LocaleController(
        store: storeIn(tmp),
        systemLanguageCode: 'es',
      );
      expect(c.loaded, isFalse);
      expect(c.locale.languageCode, 'es');

      await c.load();
      expect(c.loaded, isTrue);
      expect(c.locale.languageCode, 'es');
      expect(c.s.leave, AppStrings.es.leave);
    });

    test('el toggle cambia los textos y notifica', () async {
      final c = LocaleController(store: storeIn(tmp), systemLanguageCode: 'es');
      await c.load();
      var n = 0;
      c.addListener(() => n++);

      c.setLocale('en');
      expect(c.locale.languageCode, 'en');
      expect(c.s.settings, 'Settings');
      expect(c.s.rematch, 'Rematch');
      expect(c.s.analysis, 'Analysis');
      expect(n, 1);

      c.setLocale('en'); // no-op
      expect(n, 1);

      c.setLocale('es');
      expect(c.s.settings, 'Ajustes');
      expect(n, 2);
    });

    test('sin fichero usa el idioma del sistema con fallback ES', () async {
      final en = LocaleController(
        store: storeIn(tmp),
        systemLanguageCode: 'en',
      );
      await en.load();
      expect(en.locale.languageCode, 'en');

      final fr = LocaleController(
        store: storeIn(tmp),
        systemLanguageCode: 'fr',
      );
      await fr.load();
      expect(fr.locale.languageCode, 'es'); // no soportado -> ES

      final none = LocaleController(store: storeIn(tmp));
      await none.load();
      expect(none.loaded, isTrue);
      expect(LocaleController.supported, contains(none.locale.languageCode));
    });

    test('normalize acepta variantes regionales y rechaza el resto', () {
      expect(LocaleController.normalize('es-ES'), 'es');
      expect(LocaleController.normalize('en_US'), 'en');
      expect(LocaleController.normalize('EN'), 'en');
      expect(LocaleController.normalize('de-DE'), 'es');
      expect(LocaleController.normalize(null), 'es');
      expect(LocaleController.normalize(''), 'es');
    });
  });

  group('Persistencia en settings.json', () {
    test('round-trip: guardar y leer el locale', () async {
      final st = storeIn(tmp);
      expect(await st.readLocale(), isNull);

      await st.writeLocale('en');
      expect(await st.readLocale(), 'en');

      final f = File('${tmp.path}/${LocaleSettingsStore.fileName}');
      expect(await f.exists(), isTrue);
      expect(
        jsonDecode(await f.readAsString()),
        {LocaleSettingsStore.localeKey: 'en'},
      );

      await st.writeLocale('es');
      expect(await st.readLocale(), 'es');
    });

    test('sobrevive a una instancia nueva del controlador', () async {
      final first = LocaleController(
        store: storeIn(tmp),
        systemLanguageCode: 'es',
      );
      await first.load();
      first.setLocale('en');
      // deja terminar el guardado asíncrono
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final second = LocaleController(
        store: storeIn(tmp),
        systemLanguageCode: 'es',
      );
      await second.load();
      expect(second.locale.languageCode, 'en');
      expect(second.s.settings, 'Settings');
    });

    test('conserva otras claves y tolera fichero corrupto', () async {
      final f = File('${tmp.path}/${LocaleSettingsStore.fileName}');
      await f.writeAsString(jsonEncode({'theme': 'neon'}));
      final st = storeIn(tmp);

      await st.writeLocale('en');
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      expect(data['theme'], 'neon');
      expect(data[LocaleSettingsStore.localeKey], 'en');

      await f.writeAsString('{no es json');
      expect(await st.readLocale(), isNull); // no lanza

      final c = LocaleController(
        store: storeIn(tmp),
        systemLanguageCode: 'en',
      );
      await c.load(); // cae al sistema
      expect(c.locale.languageCode, 'en');
    });
  });

  group('flag loaded (sin parpadeo)', () {
    testWidgets('la home no se pinta hasta tener el locale resuelto',
        (tester) async {
      final c = LocaleController(store: storeIn(tmp), systemLanguageCode: 'en');

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: c,
            builder: (_, __) => c.loaded
                ? Text(c.s.settings)
                : const Text('BOOT', textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('BOOT'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);

      // I/O real (settings.json) fuera del reloj falso de flutter_test.
      await tester.runAsync(c.load);
      await tester.pump();
      expect(find.text('BOOT'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
