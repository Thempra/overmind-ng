import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/l10n.dart';
import '../game/battle_theme.dart';
import '../ble/neurosky_ble.dart';
import '../state/battle_theme_controller.dart';
import '../state/eeg_store.dart';
import '../theme.dart';
import 'mode_selection_screen.dart';

/// Ajustes comunes a ambos modos: Bluetooth, idioma y (futuro) tema de partida.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// id (remoteId) del dispositivo que se está conectando ahora mismo.
  String? _connectingId;

  Future<void> _scan(EegStore store) async {
    if (store.isScanning) return;
    final found = await store.scanBle();
    if (!mounted) return;
    if (found.isEmpty) {
      final s = context.read<LocaleController>().s;
      // Si el fallo fue por permisos, lo decimos con claridad.
      final permErr = store.permissionError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(permErr ?? s.noDevicesFound)),
      );
    }
  }

  Future<void> _loadBonded(EegStore store) async {
    try {
      await store.loadBonded();
    } catch (e) {
      if (!mounted) return;
      final s = context.read<LocaleController>().s;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.bondedFailed}: ${e.toString().trim()}'),
        ),
      );
    }
  }

  Future<void> _connect(EegStore store, MindDevice d) async {
    setState(() => _connectingId = d.id);
    try {
      await store.connectBle(d);
    } catch (e) {
      if (!mounted) return;
      final s = context.read<LocaleController>().s;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.connectFailed}: ${e.toString().trim()}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EegStore>();
    final l10n = context.watch<LocaleController>();
    final s = l10n.s;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.settings,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Modo de juego: acceso a la pantalla de selección de modos.
          _modeEntry(context, s),
          const Divider(height: 36, color: OvermindColors.panelBorder),

          _sectionIcon(s.bluetooth, Icons.bluetooth, OvermindColors.evaCyan),
          const SizedBox(height: 12),
          // acciones bluetooth
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: store.isScanning ? null : () => _scan(store),
                  icon: store.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_searching,
                          color: OvermindColors.evaCyan),
                  label: Text(store.isScanning ? s.scanning : s.scanBle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: store.isScanning ? null : () => _loadBonded(store),
                  icon: const Icon(Icons.link,
                      color: OvermindColors.evaCyan),
                  label: Text(s.bonded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: store.addSimulated,
                  icon: const Icon(Icons.science_outlined,
                      color: OvermindColors.shield),
                  label: Text(s.addDemo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // dispositivos disponibles (se actualizan en vivo durante el escaneo)
          ..._discoveredList(store, s),
          // dispositivos conectados
          ..._deviceList(store, s),
          const Divider(height: 40, color: OvermindColors.panelBorder),

          _sectionIcon(s.language, Icons.language, OvermindColors.shield),
          const SizedBox(height: 12),
          _langToggle(l10n, s),

          const Divider(height: 40, color: OvermindColors.panelBorder),

          _sectionIcon(s.matchTheme, Icons.palette_outlined,
              OvermindColors.textDim),
          const SizedBox(height: 8),
          // Selector de tema de partida (Evangelion / Superpoderes).
          ..._themeList(l10n, s),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _themeList(LocaleController l10n, AppStrings s) {
    final selected = context.watch<BattleThemeController>().theme;
    final lang = l10n.locale.languageCode;
    return [
      for (final t in BattleTheme.all)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _themeCard(t, t.name(lang), t.id == selected.id),
        ),
    ];
  }

  Widget _themeCard(BattleTheme t, String name, bool active) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.read<BattleThemeController>().setTheme(t),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: OvermindColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? t.leftColor : OvermindColors.panelBorder,
              width: active ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              // Miniatura del combate: fondo + los dos avatares.
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 104,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/images/${t.background}',
                          fit: BoxFit.cover),
                      Positioned(
                        left: 4,
                        top: 14,
                        child: ClipOval(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Image.asset(
                                'assets/images/${t.leftImage}',
                                fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 14,
                        child: ClipOval(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Image.asset(
                                'assets/images/${t.rightImage}',
                                fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: OvermindColors.text,
                  ),
                ),
              ),
              if (active) Icon(Icons.check_circle, color: t.leftColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeEntry(BuildContext context, AppStrings s) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OvermindColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OvermindColors.panelBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OvermindColors.evaCyan.withOpacity(0.15),
                  border: Border.all(color: OvermindColors.evaCyan),
                ),
                child: const Icon(Icons.swap_horiz,
                    color: OvermindColors.evaCyan, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context
                      .watch<LocaleController>()
                      .locale
                      .languageCode ==
                          'en'
                      ? 'Game mode'
                      : 'Modo de juego',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: OvermindColors.text,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: OvermindColors.textDim),
            ],
          ),
        ),
      ),
    );
  }

  /// Lista en vivo de dispositivos BLE descubiertos durante el escaneo,
  /// cada uno con su botón de conectar.
  List<Widget> _discoveredList(EegStore store, AppStrings s) {
    final list = store.discovered;
    if (list.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          s.discovered,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: OvermindColors.textDim,
          ),
        ),
      ),
      for (final d in list)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: OvermindColors.panel,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: OvermindColors.evaCyan.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(
                d.isClassic ? Icons.cable : Icons.bluetooth,
                color: OvermindColors.evaCyan,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: const TextStyle(
                        color: OvermindColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      d.isClassic
                          ? 'SPP'
                          : (d.rssi != 0
                                ? '${d.rssi} dBm'
                                : s.bondedLabel),
                      style: const TextStyle(
                        color: OvermindColors.textDim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _connectingId == d.id
                    ? null
                    : () => _connect(store, d),
                child: _connectingId == d.id
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.connect),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _deviceList(EegStore store, AppStrings s) {
    final list = store.connected;
    if (list.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OvermindColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OvermindColors.panelBorder),
          ),
          child: Text(
            s.noDevices,
            style: const TextStyle(color: OvermindColors.textDim),
          ),
        ),
      ];
    }
    return [
      for (final e in list)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: OvermindColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OvermindColors.panelBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.headphones, color: OvermindColors.textDim),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${e.name}  ·  ATN ${e.attention}  MDT ${e.meditation}',
                  style: const TextStyle(color: OvermindColors.text),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: OvermindColors.textDim,
                onPressed: () => store.removeAt(e.slot),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _langToggle(LocaleController l10n, AppStrings s) {
    return Row(
      children: [
        _langChip(l10n, 'es', 'ES', l10n.locale.languageCode == 'es'),
        const SizedBox(width: 10),
        _langChip(l10n, 'en', 'EN', l10n.locale.languageCode == 'en'),
      ],
    );
  }

  Widget _langChip(LocaleController l10n, String code, String label, bool on) {
    final accent =
        code == 'es' ? OvermindColors.evaCyan : OvermindColors.sachielRed;
    return Expanded(
      child: GestureDetector(
        onTap: () => l10n.setLocale(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? accent.withOpacity(0.18) : OvermindColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: on ? accent : OvermindColors.panelBorder, width: 1.4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: on ? accent : OvermindColors.textDim,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionIcon(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            fontSize: 16,
            color: OvermindColors.text,
          ),
        ),
      ],
    );
  }

  Widget _comingSoon(String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OvermindColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OvermindColors.panelBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction, color: OvermindColors.textDim),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: OvermindColors.textDim),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: OvermindColors.sachielRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: OvermindColors.sachielRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
