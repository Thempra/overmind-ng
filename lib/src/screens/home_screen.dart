import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/l10n.dart';
import '../state/eeg_store.dart';
import '../state/mode_controller.dart';
import '../theme.dart';
import 'settings_screen.dart';
import 'modes/player_mode_view.dart';
import 'modes/researcher_mode_view.dart';

/// Pantalla principal: por defecto muestra el MODO JUGADOR.
/// Incluye un toggle de 1 toque para cambiar de modo y acceso a Ajustes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EegStore>();
    final l10n = context.watch<LocaleController>();
    final mode = context.watch<ModeController>().mode;
    final s = l10n.s;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _GameBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, l10n, s),
                  const SizedBox(height: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(mode),
                        child: mode == OvermindMode.player
                            ? const PlayerModeView()
                            : const ResearcherModeView(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
      BuildContext context, LocaleController l10n, AppStrings s) {
    final mode = context.watch<ModeController>().mode;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'OVER'),
                    TextSpan(
                      text: 'MIND',
                      style: TextStyle(color: OvermindColors.evaCyan),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: OvermindColors.text,
                  shadows: [
                    Shadow(color: OvermindColors.evaCyan, blurRadius: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        _modeToggle(context, mode, s),
        const SizedBox(width: 10),
        _iconButton(
          Icons.settings,
          OvermindColors.shield,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _modeToggle(BuildContext ctx, OvermindMode mode, AppStrings s) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: OvermindColors.panel,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: OvermindColors.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleItem(ctx, mode == OvermindMode.player, s.playerMode,
              OvermindColors.evaCyan, OvermindMode.player),
          _toggleItem(ctx, mode == OvermindMode.researcher, s.researcherMode,
              OvermindColors.sachielRed, OvermindMode.researcher),
        ],
      ),
    );
  }

  Widget _toggleItem(BuildContext ctx, bool active, String label, Color accent,
      OvermindMode m) {
    return GestureDetector(
      onTap: () => ctx.read<ModeController>().mode = m,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: active ? accent : OvermindColors.textDim,
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, Color color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: OvermindColors.panel,
          shape: BoxShape.circle,
          border: Border.all(color: OvermindColors.panelBorder),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _GameBackdrop extends StatelessWidget {
  const _GameBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/game_background.jpg',
          fit: BoxFit.cover,
          opacity: const AlwaysStoppedAnimation(0.28),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xE60A0E16), Color(0xB30A0E16), OvermindColors.bg],
            ),
          ),
        ),
      ],
    );
  }
}
