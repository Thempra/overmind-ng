import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/l10n.dart';
import '../../state/eeg_store.dart';
import '../../theme.dart';
import '../../widgets/action_card.dart';
import '../game_screen.dart';

/// Modo jugador (pantalla por defecto): lanzar combates con 1 o 2 jugadores
/// reales (el resto, demo) o ver jugar a dos demos. Selección de dispositivos
/// automática para evitar clics innecesarios.
class PlayerModeView extends StatelessWidget {
  const PlayerModeView({super.key});

  /// Toma el siguiente slot disponible para el jugador: prefiere dispositivos
  /// EEG reales (no simulados), luego cualquier conectado, y rellena con demo.
  int _takeSlot(EegStore store, Set<int> used) {
    for (final e in store.connected) {
      if (!e.name.contains('Simulated') && !used.contains(e.slot)) return e.slot;
    }
    for (final e in store.connected) {
      if (!used.contains(e.slot)) return e.slot;
    }
    // crear demo
    store.addSimulated();
    for (final e in store.devices) {
      if (e != null && !used.contains(e.slot)) return e.slot;
    }
    return -1;
  }

  Future<void> _launch(BuildContext context, EegStore store, int realPlayers,
      {bool allDemo = false}) async {
    final used = <int>{};
    final slots = <int>[];
    final real = allDemo ? 0 : realPlayers;
    for (var i = 0; i < real; i++) {
      final slot = _takeSlot(store, used);
      if (slot < 0) break;
      used.add(slot);
      slots.add(slot);
    }
    while (slots.length < 2) {
      final slot = _takeSlot(store, used);
      if (slot < 0) break;
      used.add(slot);
      slots.add(slot);
    }
    if (slots.length < 2 || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          player1Slot: slots[0],
          player2Slot: slots[1],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EegStore>();
    final s = context.watch<LocaleController>().s;
    final realCount = store.connected.length;

    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        Text(
          '${s.connected}: $realCount',
          style: const TextStyle(
            color: OvermindColors.textDim,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        ActionCard(
          icon: Icons.person,
          title: s.onePlayer,
          subtitle: s.onePlayerSub,
          accent: OvermindColors.evaCyan,
          big: true,
          onTap: () => _launch(context, store, 1),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.group,
          title: s.twoPlayers,
          subtitle: '2 × EEG',
          accent: OvermindColors.shield,
          big: true,
          onTap: () => _launch(context, store, 2),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.science_outlined,
          title: s.demoMode,
          subtitle: s.demoModeSub,
          accent: OvermindColors.sachielRed,
          big: true,
          onTap: () => _launch(context, store, 2, allDemo: true),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
