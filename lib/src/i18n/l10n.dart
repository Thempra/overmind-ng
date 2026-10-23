import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Textos de la interfaz en español e inglés.
class AppStrings {
  const AppStrings._({
    required this.playerMode,
    required this.researcherMode,
    required this.settings,
    required this.bluetooth,
    required this.language,
    required this.comingSoon,
    required this.attentionMeditation,
    required this.waveLevels,
    required this.selectGame,
    required this.onePlayer,
    required this.twoPlayers,
    required this.demoMode,
    required this.onePlayerSub,
    required this.demoModeSub,
    required this.scanBle,
    required this.scanning,
    required this.bonded,
    required this.bondedLabel,
    required this.bondedFailed,
    required this.addDemo,
    required this.connected,
    required this.devices,
    required this.discovered,
    required this.connect,
    required this.connectFailed,
    required this.noDevices,
    required this.noDevicesHint,
    required this.noDevicesFound,
    required this.play,
    required this.pickPlayer,
    required this.pickTwo,
    required this.needTwoReal,
    required this.battle,
    required this.player,
    required this.leave,
    required this.rematch,
    required this.demo,
    required this.done,
    required this.gameMode,
    required this.device,
    required this.analysis,
    required this.mindLevels,
    required this.signal,
    required this.signalGood,
    required this.attention,
    required this.meditation,
    required this.lowAlpha,
    required this.highAlpha,
    required this.lowBeta,
    required this.highBeta,
    required this.lowGamma,
    required this.highGamma,
    required this.attShort,
    required this.medShort,
    required this.lowAlphaShort,
    required this.highAlphaShort,
    required this.lowBetaShort,
    required this.highBetaShort,
    required this.lowGammaShort,
    required this.highGammaShort,
  });

  final String playerMode;
  final String researcherMode;
  final String settings;
  final String bluetooth;
  final String language;
  final String comingSoon;
  final String attentionMeditation;
  final String waveLevels;
  final String selectGame;
  final String onePlayer;
  final String twoPlayers;
  final String demoMode;
  final String onePlayerSub;
  final String demoModeSub;
  final String scanBle;
  final String scanning;
  final String bonded;
  final String bondedLabel;
  final String bondedFailed;
  final String addDemo;
  final String connected;
  final String devices;
  final String discovered;
  final String connect;
  final String connectFailed;
  final String noDevices;
  final String noDevicesHint;
  final String noDevicesFound;
  final String play;
  final String pickPlayer;
  final String pickTwo;
  final String needTwoReal;
  final String battle;
  final String player;
  final String leave;
  final String rematch;
  final String demo;
  final String done;

  /// Modo de juego (título de la pantalla de selección y entrada en Ajustes).
  final String gameMode;

  /// Nombre por defecto de un dispositivo EEG sin nombre asignado.
  final String device;

  /// Título del analizador de atención/meditación.
  final String analysis;

  /// Título de la pantalla de niveles de onda.
  final String mindLevels;

  /// Etiqueta de calidad de señal (0 = buena).
  final String signal;
  final String signalGood;

  /// Etiquetas del analizador (atención, meditación y bandas EEG).
  final String attention;
  final String meditation;
  final String lowAlpha;
  final String highAlpha;
  final String lowBeta;
  final String highBeta;
  final String lowGamma;
  final String highGamma;

  /// Versiones cortas para el eje X de la gráfica de barras.
  final String attShort;
  final String medShort;
  final String lowAlphaShort;
  final String highAlphaShort;
  final String lowBetaShort;
  final String highBetaShort;
  final String lowGammaShort;
  final String highGammaShort;

  static const es = AppStrings._(
    playerMode: 'Jugador',
    researcherMode: 'Investigador',
    settings: 'Ajustes',
    bluetooth: 'Bluetooth',
    language: 'Idioma',
    comingSoon: 'Próximamente',
    attentionMeditation: 'Atención / Meditación',
    waveLevels: 'Niveles de onda',
    selectGame: 'Elige un juego',
    onePlayer: '1 Jugador',
    twoPlayers: '2 Jugadores',
    demoMode: 'Modo demo',
    onePlayerSub: 'Vs. IA en modo demo',
    demoModeSub: 'Ver jugar a dos demo',
    scanBle: 'Escanear BLE',
    scanning: 'Escaneando…',
    bonded: 'Vinculados',
    bondedLabel: 'Vinculado',
    bondedFailed: 'No se pudieron cargar los vinculados',
    addDemo: 'Añadir demo',
    connected: 'Conectados',
    devices: 'Dispositivos',
    discovered: 'Dispositivos disponibles',
    connect: 'Conectar',
    connectFailed: 'No se pudo conectar',
    noDevices: 'No hay dispositivos conectados',
    noDevicesHint:
        'Conecta un EEG por Bluetooth en Ajustes o usa el modo demo.',
    noDevicesFound:
        'No se encontraron dispositivos BLE. Enciende el EEG y vuelve a escanear.',
    play: 'JUGAR',
    pickPlayer: 'Elige tu dispositivo EEG',
    pickTwo: 'Elige 2 jugadores',
    needTwoReal: 'Necesitas al menos 2 jugadores reales o usa el modo demo.',
    battle: 'Combate',
    player: 'Jugador',
    leave: 'Salir',
    rematch: 'Revancha',
    demo: 'demo',
    done: 'Listo',
    gameMode: 'Modo de juego',
    device: 'Dispositivo',
    analysis: 'Análisis',
    mindLevels: 'Niveles de Mente',
    signal: 'Señal',
    signalGood: '0 = buena',
    attention: 'Atención',
    meditation: 'Meditación',
    lowAlpha: 'Alfa baja',
    highAlpha: 'Alfa alta',
    lowBeta: 'Beta baja',
    highBeta: 'Beta alta',
    lowGamma: 'Gamma baja',
    highGamma: 'Gamma alta',
    attShort: 'Aten',
    medShort: 'Medi',
    lowAlphaShort: 'αBaja',
    highAlphaShort: 'αAlta',
    lowBetaShort: 'βBaja',
    highBetaShort: 'βAlta',
    lowGammaShort: 'γBaja',
    highGammaShort: 'γAlta',
  );

  static const en = AppStrings._(
    playerMode: 'Player',
    researcherMode: 'Researcher',
    settings: 'Settings',
    bluetooth: 'Bluetooth',
    language: 'Language',
    comingSoon: 'Coming soon',
    attentionMeditation: 'Attention / Meditation',
    waveLevels: 'Wave levels',
    selectGame: 'Select a game',
    onePlayer: '1 Player',
    twoPlayers: '2 Players',
    demoMode: 'Demo mode',
    onePlayerSub: 'Vs. AI in demo mode',
    demoModeSub: 'Watch two demos play',
    scanBle: 'Scan BLE',
    scanning: 'Scanning…',
    bonded: 'Bonded',
    bondedLabel: 'Bonded',
    bondedFailed: 'Could not load bonded devices',
    addDemo: 'Add demo',
    connected: 'Connected',
    devices: 'Devices',
    discovered: 'Available devices',
    connect: 'Connect',
    connectFailed: 'Connection failed',
    noDevices: 'No devices connected',
    noDevicesHint: 'Connect an EEG via Bluetooth in Settings or use demo mode.',
    noDevicesFound: 'No BLE devices found. Turn on your EEG and scan again.',
    play: 'PLAY',
    pickPlayer: 'Pick your EEG device',
    pickTwo: 'Pick 2 players',
    needTwoReal: 'You need at least 2 real players or use demo mode.',
    battle: 'Battle',
    player: 'Player',
    leave: 'Leave',
    rematch: 'Rematch',
    demo: 'demo',
    done: 'Done',
    gameMode: 'Game mode',
    device: 'Device',
    analysis: 'Analysis',
    mindLevels: 'Mind Levels',
    signal: 'Signal',
    signalGood: '0 = good',
    attention: 'Attention',
    meditation: 'Meditation',
    lowAlpha: 'Low Alpha',
    highAlpha: 'High Alpha',
    lowBeta: 'Low Beta',
    highBeta: 'High Beta',
    lowGamma: 'Low Gamma',
    highGamma: 'High Gamma',
    attShort: 'Att',
    medShort: 'Med',
    lowAlphaShort: 'LAlpha',
    highAlphaShort: 'HAlpha',
    lowBetaShort: 'LBeta',
    highBetaShort: 'HBeta',
    lowGammaShort: 'LGamma',
    highGammaShort: 'HGamma',
  );
}

/// Persistencia del idioma en `settings.json` dentro del directorio de soporte
/// de la aplicación (mismo patrón local-first que el tema y el progreso: sin
/// plugins ni servicios externos).
class LocaleSettingsStore {
  LocaleSettingsStore({Future<Directory> Function()? dirProvider})
      : _dirProvider = dirProvider ?? getApplicationSupportDirectory;

  static const fileName = 'settings.json';
  static const localeKey = 'locale';

  final Future<Directory> Function() _dirProvider;

  Future<File> _file() async {
    final dir = await _dirProvider();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$fileName');
  }

  /// Devuelve el código guardado, o `null` si no hay fichero/clave legible.
  Future<String?> readLocale() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) return null;
      final code = decoded[localeKey];
      return code is String && code.isNotEmpty ? code : null;
    } catch (_) {
      // Fichero corrupto o sin permisos: se ignora y se usa el fallback.
      return null;
    }
  }

  /// Guarda el código conservando el resto de claves de `settings.json`.
  Future<void> writeLocale(String code) async {
    try {
      final f = await _file();
      var data = <String, dynamic>{};
      if (await f.exists()) {
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is Map) data = decoded.cast<String, dynamic>();
      }
      data[localeKey] = code;
      await f.writeAsString(jsonEncode(data));
    } catch (_) {
      // Persistir es best-effort: la app sigue funcionando sin disco.
    }
  }
}

/// Controla el idioma activo y expone los textos correspondientes.
class LocaleController extends ChangeNotifier {
  LocaleController({
    LocaleSettingsStore? store,
    String? systemLanguageCode,
  })  : _store = store ?? LocaleSettingsStore(),
        _systemLanguageCode = systemLanguageCode;

  /// Idiomas soportados por la app.
  static const supported = <String>['es', 'en'];

  /// Fallback cuando no hay nada guardado ni idioma de sistema reconocido.
  static const fallback = 'es';

  final LocaleSettingsStore _store;
  final String? _systemLanguageCode;

  Locale _locale = const Locale(fallback);
  bool _loaded = false;

  Locale get locale => _locale;

  /// `true` cuando el idioma ya se resolvió leyendo `settings.json`.
  ///
  /// La UI espera a este flag antes de pintar para no mostrar un frame en ES y
  /// cambiarlo a EN (parpadeo) en cada arranque.
  bool get loaded => _loaded;

  AppStrings get s =>
      _locale.languageCode == 'en' ? AppStrings.en : AppStrings.es;

  /// Normaliza `es-ES`, `EN_us`, … a un código soportado (fallback ES).
  static String normalize(String? code) {
    final base = (code ?? '').toLowerCase().split(RegExp('[-_]')).first;
    return supported.contains(base) ? base : fallback;
  }

  String get _systemLocaleCode {
    if (_systemLanguageCode != null) return _systemLanguageCode;
    try {
      return PlatformDispatcher.instance.locale.languageCode;
    } catch (_) {
      return fallback;
    }
  }

  /// Carga el idioma guardado; si no hay, el del sistema con fallback a ES.
  /// Marca [loaded] y notifica una sola vez.
  Future<void> load() async {
    final saved = await _store.readLocale();
    _locale = Locale(normalize(saved ?? _systemLocaleCode));
    _loaded = true;
    notifyListeners();
  }

  void setLocale(String code) {
    final next = normalize(code);
    if (_locale.languageCode == next) return;
    _locale = Locale(next);
    notifyListeners();
    unawaited(_store.writeLocale(next));
  }
}
