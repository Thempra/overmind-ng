import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/l10n.dart';

import '../eeg/eeg_data.dart';
import 'mind_game_session.dart';
import 'signal_processor.dart';
import 'games/balloon_game.dart';
import 'games/falcon_game.dart';
import 'games/seesaw_game.dart';

/// Abre la sesión de un [MentalGame] con sus metadatos ya aplicados.
class MentalGameScreen extends StatelessWidget {
  const MentalGameScreen({super.key, required this.game, required this.slots});

  final MentalGame game;
  final List<int> slots;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleController>().locale.languageCode;
    return MindGameSession(
      gameId: game.id,
      title: game.name(lang),
      accent: game.accent,
      calibrateInstruction: game.calibrate,
      durationSec: game.durationSec,
      slots: slots,
      logicBuilder: game.launch,
    );
  }
}

/// Metadatos + launcher de cada juego mental de la plataforma.
class MentalGame {
  const MentalGame({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.subtitleEs,
    required this.subtitleEn,
    required this.icon,
    required this.accent,
    required this.signal,
    required this.age,
    required this.needs2,
    required this.durationSec,
    required this.calibrate,
    required this.launch,
  });

  final String id;
  final String nameEs, nameEn, subtitleEs, subtitleEn;
  final IconData icon;
  final Color accent;
  final String signal; // señal conductora, para la ficha del juego
  final String age;
  final bool needs2;
  final int durationSec;
  final String calibrate;
  final GameLogic Function(List<EegData?>, Calibrator) launch;

  String name(String lang) => lang == 'en' ? nameEn : nameEs;
  String subtitle(String lang) => lang == 'en' ? subtitleEn : subtitleEs;

  static final balloon = MentalGame(
    id: 'balloon',
    nameEs: 'Globo',
    nameEn: 'Balloon',
    subtitleEs: 'Mantén la calma e ínflalo hasta hacer estallar',
    subtitleEn: 'Hold your calm and inflate it until it pops',
    icon: Icons.bubble_chart,
    accent: Color(0xFFFF6B9D),
    signal: 'MEDITACIÓN',
    age: '6+',
    needs2: false,
    durationSec: 90,
    calibrate: 'Relájate 5 s… respira hondo y quédate quieto',
    launch: (e, c) => BalloonLogic(eeg: e.first, cal: c),
  );

  static final seesaw = MentalGame(
    id: 'seesaw',
    nameEs: 'Duelo',
    nameEn: 'Duel',
    subtitleEs: '2 cabezales · empuja la bola con tu calma',
    subtitleEn: '2 headsets · push the ball with your calm',
    icon: Icons.balance,
    accent: Color(0xFFB388FF),
    signal: 'CALMA (med−atención)',
    age: '8+',
    needs2: true,
    durationSec: 90,
    calibrate: 'Ambos: calmados 5 s… los dos quietos',
    launch: (e, c) => SeesawLogic(eegs: e, cal: c),
  );

  static final falcon = MentalGame(
    id: 'falcon',
    nameEs: 'Halcón',
    nameEn: 'Falcon',
    subtitleEs: 'Parpadea para derribar cometas antes de que se apaguen',
    subtitleEn: 'Blink to shoot comets down before they fade',
    icon: Icons.radar,
    accent: Color(0xFF4FC3F7),
    signal: 'PARPADEO',
    age: '10+',
    needs2: false,
    durationSec: 90,
    calibrate: 'Mira la pantalla tranquila 5 s… luego parpadea a propósito',
    launch: (e, c) => FalconLogic(eeg: e.first),
  );

  static final all = [balloon, seesaw, falcon];
}
