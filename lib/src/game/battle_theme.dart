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

  static const evangelion = BattleTheme(
    id: 'evangelion',
    nameEs: 'Evangelion',
    nameEn: 'Evangelion',
    background: 'game_background2.jpg',
    leftImage: 'eva01.png',
    rightImage: 'sachiel.png',
    leftBall: 'fireball_blue.png',
    rightBall: 'fireball.png',
    leftColor: Color(0xFF35B6FF),
    rightColor: Color(0xFFFF4B4B),
    leftName: 'EVA-01',
    rightName: 'SACHIEL',
  );

  static const superpoderes = BattleTheme(
    id: 'superpoderes',
    nameEs: 'Superpoderes',
    nameEn: 'Superpowers',
    background: 'background_superpoderes.png',
    leftImage: 'Elsa.png',
    rightImage: 'Rumi.png',
    leftBall: 'fireball_blue.png',
    rightBall: 'fireball_purple.png',
    leftColor: Color(0xFF4FC3F7),
    rightColor: Color(0xFF9C27B0),
    leftName: 'ELSA',
    rightName: 'RUMI',
  );

  static const all = [evangelion, superpoderes];

  static BattleTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => evangelion);
}
