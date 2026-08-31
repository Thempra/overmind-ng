import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/l10n.dart';
import '../state/mode_controller.dart';
import '../theme.dart';

/// Pantalla de selección de modo de juego (jugador / investigador).
/// Se puede abrir desde Settings y desde el toggle del Home.
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  void _pick(BuildContext context, OvermindMode mode) {
    context.read<ModeController>().mode = mode;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleController>().s;
    final mode = context.watch<ModeController>().mode;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          context.watch<LocaleController>().locale.languageCode == 'en'
              ? 'Game mode'
              : 'Modo de juego',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _option(
              context,
              active: mode == OvermindMode.player,
              icon: Icons.sports_esports,
              title: s.playerMode,
              subtitle: s.demoModeSub,
              accent: OvermindColors.evaCyan,
              onTap: () => _pick(context, OvermindMode.player),
            ),
            const SizedBox(height: 18),
            _option(
              context,
              active: mode == OvermindMode.researcher,
              icon: Icons.monitor_heart_outlined,
              title: s.researcherMode,
              subtitle: s.attentionMeditation,
              accent: OvermindColors.sachielRed,
              onTap: () => _pick(context, OvermindMode.researcher),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                s.done,
                style: const TextStyle(color: OvermindColors.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required bool active,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: active
                ? accent.withOpacity(0.18)
                : OvermindColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? accent : OvermindColors.panelBorder,
              width: active ? 2 : 1.2,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: accent.withOpacity(0.3), blurRadius: 20)
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.16),
                  border: Border.all(color: accent),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: OvermindColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: OvermindColors.textDim),
                    ),
                  ],
                ),
              ),
              if (active) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
