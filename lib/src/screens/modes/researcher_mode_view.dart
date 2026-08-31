import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/l10n.dart';
import '../../state/eeg_store.dart';
import '../../theme.dart';
import '../../widgets/action_card.dart';
import '../data_analyzer_screen.dart';
import '../levels_mind_screen.dart';

/// Modo investigador: analizar la señal EEG (atención/meditación y ondas).
/// Selección de dispositivo automática (primero el conectado, si no demo).
class ResearcherModeView extends StatelessWidget {
  const ResearcherModeView({super.key});

  int _anySlot(EegStore store) {
    final c = store.connected;
    if (c.isNotEmpty) return c.first.slot;
    store.addSimulated();
    for (final e in store.devices) {
      if (e != null) return e.slot;
    }
    return -1;
  }

  void _open(BuildContext context, Widget Function(int) builder) {
    final store = context.read<EegStore>();
    final slot = _anySlot(store);
    if (slot < 0 || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => builder(slot)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleController>().s;
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        ActionCard(
          icon: Icons.show_chart,
          title: s.attentionMeditation,
          subtitle: s.bluetooth,
          accent: OvermindColors.evaCyan,
          big: true,
          onTap: () => _open(context, (slot) => DataAnalyzerScreen(slot: slot)),
        ),
        const SizedBox(height: 12),
        ActionCard(
          icon: Icons.graphic_eq,
          title: s.waveLevels,
          subtitle: s.bluetooth,
          accent: OvermindColors.sachielRed,
          big: true,
          onTap: () =>
              _open(context, (slot) => LevelsMindScreen(slot: slot)),
        ),
      ],
    );
  }
}
