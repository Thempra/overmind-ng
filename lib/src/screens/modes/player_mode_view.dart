import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../game/battle_theme.dart';
import '../../game/mental_games.dart';
import '../../i18n/l10n.dart';
import '../../state/battle_theme_controller.dart';
import '../../state/eeg_store.dart';
import '../../state/progress_controller.dart';
import '../../theme.dart';
import '../game_screen.dart';

/// Modo jugador (pantalla por defecto): selector de juegos en cuadrícula.
/// Los juegos de batalla muestran su arte (fondo + luchadores); los juegos
/// mentales usan una portada dibujada con el acento y la iconografía de cada
/// uno. Todos en 2-3 columnas según el ancho disponible.
class PlayerModeView extends StatelessWidget {
  const PlayerModeView({super.key});

  /// Toma el siguiente slot disponible: EEGs reales primero, luego demo.
  int _takeSlot(EegStore store, Set<int> used) {
    for (final e in store.connected) {
      if (!e.name.contains('Simulated') && !used.contains(e.slot)) return e.slot;
    }
    for (final e in store.connected) {
      if (!used.contains(e.slot)) return e.slot;
    }
    store.addSimulated();
    for (final e in store.devices) {
      if (e != null && !used.contains(e.slot)) return e.slot;
    }
    return -1;
  }

  List<int> _slots(EegStore store, int want) {
    final used = <int>{};
    final slots = <int>[];
    final real = store.connected.length > want ? want : store.connected.length;
    for (var i = 0; i < real; i++) {
      final slot = _takeSlot(store, used);
      if (slot < 0) break;
      used.add(slot);
      slots.add(slot);
    }
    while (slots.length < want) {
      final slot = _takeSlot(store, used);
      if (slot < 0) break;
      used.add(slot);
      slots.add(slot);
    }
    return slots;
  }

  void _launch(BuildContext context, EegStore store) {
    final slots = _slots(store, 2);
    if (slots.length < 2 || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          GameScreen(player1Slot: slots[0], player2Slot: slots[1]),
    ));
  }

  void _selectGame(BuildContext context, EegStore store, BattleTheme theme) {
    context.read<BattleThemeController>().setTheme(theme);
    _launch(context, store);
  }

  void _launchMental(BuildContext context, EegStore store, MentalGame g) {
    final want = g.needs2 ? 2 : 1;
    final slots = _slots(store, want);
    if (slots.length < want || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MentalGameScreen(game: g, slots: slots),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleController>().s;
    final lang = context.watch<LocaleController>().locale.languageCode;
    final realCount = context.watch<EegStore>().connected.length;
    final store = context.read<EegStore>();

    final games = <Widget>[
      ...BattleTheme.all.map((t) => _gameCard(context, store, t, lang, s)),
      ...MentalGame.all.map((g) => _mentalCard(context, store, g, lang, s)),
    ];

    return LayoutBuilder(builder: (context, box) {
      // 3 columnas en horizontal/screens anchas; 2 en vertical.
      final cols = box.maxWidth >= 680 ? 3 : 2;
      // En 3 columnas las tarjetas son más horizontales (menos altas).
      final ratio = cols == 3 ? 1.05 : 0.78;
      return ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        children: [
          Text(
            '${s.connected}: $realCount',
            style: const TextStyle(
              color: OvermindColors.textDim,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.selectGame,
            style: const TextStyle(
              color: OvermindColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: ratio,
            children: games,
          ),
        ],
      );
    });
  }

  /// Tarjeta de batalla: fondo + luchadores + nombre.
  Widget _gameCard(BuildContext context, EegStore store, BattleTheme theme,
      String lang, AppStrings s) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _selectGame(context, store, theme),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.leftColor.withOpacity(0.7),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                  color: theme.leftColor.withOpacity(0.25), blurRadius: 18),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/${theme.background}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: OvermindColors.panel),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xD907090F), Color(0x3307090F)],
                  ),
                ),
              ),
              // Luchadores enfrentados (superior).
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6, top: 26),
                        child: Image.asset(
                          'assets/images/${theme.leftImage}',
                          height: 82,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6, top: 26),
                        child: Image.asset(
                          'assets/images/${theme.rightImage}',
                          height: 82,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Nombre en la base.
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.38),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.leftColor.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              theme.name(lang).toUpperCase(),
                              style: TextStyle(
                                color: theme.leftColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  s.play,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const Icon(Icons.play_arrow,
                                    size: 14, color: Colors.white70),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de juego mental: portada dibujada + nombre + señal.
  Widget _mentalCard(
      BuildContext context, EegStore store, MentalGame g, String lang, AppStrings s) {
    final record = context.watch<ProgressController>().best[g.id] ?? 0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _launchMental(context, store, g),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: g.accent.withOpacity(0.7), width: 1.6),
            boxShadow: [
              BoxShadow(color: g.accent.withOpacity(0.25), blurRadius: 18),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MentalCover(game: g),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC07090F), Color(0x0007090F)],
                  ),
                ),
              ),
              // Etiqueta de señal / edad / récord.
              if (g.needs2)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _chip('2 × EEG', g.accent),
                ),
              if (record > 0)
                Positioned(
                  bottom: 42,
                  right: 8,
                  child: _chip('★ $record', const Color(0xFFFFD54F)),
                ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name(lang).toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.5,
                          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            s.play,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                          Icon(g.icon,
                              size: 12, color: Colors.white.withOpacity(0.8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Portada ilustrada para un juego mental, sin necesidad de asset propio.
class _MentalCover extends StatelessWidget {
  const _MentalCover({required this.game});
  final MentalGame game;

  @override
  Widget build(BuildContext context) {
    switch (game.id) {
      case 'balloon':
        return _CoverScene(
          colors: [const Color(0xFF1A3A6B), const Color(0xFF6B4A8F)],
          child: Stack(clipBehavior: Clip.none, children: [
            // sol
            Positioned(
              top: 22,
              right: 24,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFE082).withOpacity(0.85),
                ),
              ),
            ),
            // globo
            Center(
              child: Transform.translate(
                offset: Offset(0, -6),
                child: Container(
                  width: 52,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Color.lerp(game.accent, Colors.white, 0.5)!,
                      game.accent,
                    ]),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.bubble_chart,
                      color: Colors.white.withOpacity(0.9),
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
            // nubes
            Positioned(
              bottom: 30,
              left: 14,
              child: _cloud(const Color(0x55FFFFFF)),
            ),
            Positioned(
              bottom: 22,
              right: 16,
              child: _cloud(const Color(0x44FFFFFF)),
            ),
          ]),
        );
      case 'seesaw':
        return _CoverScene(
          colors: [const Color(0xFF5B2A6B), const Color(0xFF14506B)],
          child: Stack(children: [
            // esfera central sobre horizonte
            Center(
              child: Transform.translate(
                offset: const Offset(0, 4),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFE8B44B),
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFE8B44B).withOpacity(0.5),
                          blurRadius: 18),
                    ],
                  ),
                ),
              ),
            ),
            // dos cabezales (lados)
            Positioned(
              left: 14,
              top: 30,
              child: Icon(Icons.person,
                  color: Colors.white.withOpacity(0.6), size: 26),
            ),
            Positioned(
              right: 14,
              top: 30,
              child: Icon(Icons.person,
                  color: Colors.white.withOpacity(0.6), size: 26),
            ),
            // suelo
            Positioned(
              bottom: 34,
              left: 0,
              right: 0,
              child: Container(height: 3, color: Colors.white.withOpacity(0.4)),
            ),
          ]),
        );
      case 'falcon':
        return _CoverScene(
          colors: [const Color(0xFF04070F), const Color(0xFF1B2A45)],
          child: Stack(children: [
            for (var i = 0; i < 26; i++)
              Positioned(
                left: (i * 37.3) % 200 - 20,
                top: (i * 53.7) % 130,
                child: Container(
                  width: i % 4 == 0 ? 2.4 : 1.4,
                  height: i % 4 == 0 ? 2.4 : 1.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.4 + (i % 5) * 0.1),
                  ),
                ),
              ),
            // cometa
            Positioned(
              right: 22,
              top: 38,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white,
                    const Color(0xFF4FC3F7),
                    const Color(0xFF1A5F8F),
                  ]),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF4FC3F7).withOpacity(0.7),
                        blurRadius: 14),
                  ],
                ),
              ),
            ),
            // mecha que se consume (arco)
            Positioned(
              right: 54,
              top: 70,
              child: Transform.scale(
                scale: 0.8,
                child: Container(width: 20, height: 20, color: Colors.transparent),
              ),
            ),
          ]),
        );
      default:
        return _CoverScene(
          colors: [OvermindColors.panel, game.accent],
          child: Icon(game.icon, color: Colors.white70, size: 44),
        );
    }
  }

  Widget _cloud(Color color) => Container(
        width: 34,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
      );
}

/// Fondo en degradado + viñeta inferior para una portada.
class _CoverScene extends StatelessWidget {
  const _CoverScene({required this.colors, required this.child});
  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}
