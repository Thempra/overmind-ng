import 'dart:ui' show Color;

/// Definición de un "theme" de partida: define el fondo, los avatares de los
/// dos luchadores, las bolas de fuego, los colores (aura/HUD/barras) y los
/// nombres que se muestran en pantalla. El usuario elige entre ellos en
/// Ajustes → Tema de la partida.
class BattleTheme {
  const BattleTheme({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.background,
    required this.leftImage,
    required this.rightImage,
    required this.leftBall,
    required this.rightBall,
    required this.leftColor,
    required this.rightColor,
    required this.leftName,
    required this.rightName,
  });

  final String id;
  final String nameEs;
  final String nameEn;

  /// Asset de fondo de la batalla.
  final String background;

  /// Avatares de los luchadores (player1 = izquierda, player2 = derecha).
  final String leftImage;
  final String rightImage;

  /// Textura de la bola de fuego de cada lado.
  final String leftBall;
  final String rightBall;

  /// Colores de aura, HUD y barras de cada lado.
  final Color leftColor;
  final Color rightColor;

  /// Nombres mostrados en el HUD y el cartel VS.
  final String leftName;
  final String rightName;

  String name(String lang) => lang == 'en' ? nameEn : nameEs;

  static const neon = BattleTheme(
    id: 'neon',
    nameEs: 'Neón',
    nameEn: 'Neon',
    background: 'bg_neon.png',
    leftImage: 'fighter_vector.png',
    rightImage: 'fighter_orbe.png',
    leftBall: 'fireball_blue.png',
    rightBall: 'fireball.png',
    leftColor: Color(0xFF35B6FF),
    rightColor: Color(0xFFFF4B4B),
    leftName: 'VECTOR',
    rightName: 'ORBE',
  );

  static const cosmico = BattleTheme(
    id: 'cosmico',
    nameEs: 'Cósmico',
    nameEn: 'Cosmic',
    background: 'bg_cosmico.png',
    leftImage: 'fighter_prisma.png',
    rightImage: 'fighter_nebula.png',
    leftBall: 'fireball_blue.png',
    rightBall: 'fireball_purple.png',
    leftColor: Color(0xFFFFC24B),
    rightColor: Color(0xFFB07BFF),
    leftName: 'PRISMA',
    rightName: 'NEBULA',
  );

  static const elsaVsRumi = BattleTheme(
    id: 'elsa_vs_rumi',
    nameEs: 'Elsa vs Rumi',
    nameEn: 'Elsa vs Rumi',
    background: 'game_background2.jpg',
    leftImage: 'Elsa.png',
    rightImage: 'Rumi.png',
    leftBall: 'fireball_blue.png',
    rightBall: 'fireball_purple.png',
    leftColor: Color(0xFF7FD4FF),
    rightColor: Color(0xFFFF5FA2),
    leftName: 'ELSA',
    rightName: 'RUMI',
  );

  static const all = [neon, cosmico, elsaVsRumi];

  static BattleTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => neon);
}
