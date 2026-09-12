import 'package:flutter/foundation.dart';
import 'dart:ui' show Locale;

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
    noDevicesHint:
        'Connect an EEG via Bluetooth in Settings or use demo mode.',
    noDevicesFound:
        'No BLE devices found. Turn on your EEG and scan again.',
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
  );
}

/// Controla el idioma activo y expone los textos correspondientes.
class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('es');
  Locale get locale => _locale;
  AppStrings get s =>
      _locale.languageCode == 'en' ? AppStrings.en : AppStrings.es;

  void setLocale(String code) {
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    notifyListeners();
  }
}
