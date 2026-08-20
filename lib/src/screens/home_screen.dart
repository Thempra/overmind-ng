import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../eeg/eeg_data.dart';
import '../state/eeg_store.dart';
import 'data_analyzer_screen.dart';
import 'game_screen.dart';
import 'levels_mind_screen.dart';

/// Pantalla principal (port de [MainActivity] del proyecto Android original).
/// Permite conectar hasta 8 dispositivos EEG, ver sus valores en vivo y abrir
/// los analizadores y el juego.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _scanning = false;

  Future<void> _startScan(EegStore store) async {
    setState(() => _scanning = true);
    final found = await store.scanBle();
    if (!mounted) return;
    setState(() => _scanning = false);

    if (found.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron dispositivos BLE')),
      );
      return;
    }

    if (!context.mounted) return;
    // Diálogo para elegir un dispositivo descubierto.
    final pick = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Dispositivos encontrados'),
        children: [
          for (var i = 0; i < found.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(i),
              child: Text(
                '${found[i].device.platformName}  (${found[i].rssi} dBm)',
              ),
            ),
        ],
      ),
    );
    if (pick != null && context.mounted) {
      final ok = await store.connectBle(found[pick]);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo conectar')),
        );
      }
    }
  }

  Future<int?> _pickDevice(EegStore store, String title) async {
    final connected = store.connected;
    if (connected.isEmpty) return null;
    if (connected.length == 1) return connected.first.slot;

    final pick = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final e in connected)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(e.slot),
              child: Text(e.name),
            ),
        ],
      ),
    );
    return pick;
  }

  Future<void> _pickPlayersAndPlay(EegStore store) async {
    final connected = store.connected;
    if (connected.length < 2) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas al menos 2 dispositivos para jugar'),
        ),
      );
      return;
    }
    final picks = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Elige 2 jugadores'),
        children: [
          for (int i = 0; i < connected.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(
                ctx,
              ).pop([connected[i].slot, connected[(i + 1) % connected.length].slot]),
              child: Text('Jugador 1: ${connected[i].name}'),
            ),
        ],
      ),
    );
    if (picks == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          player1Slot: picks[0],
          player2Slot: picks[1],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EegStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Overmind')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Estado Bluetooth
            Text(
              store.bleAvailable
                  ? 'Bluetooth BLE activo'
                  : 'Desconectado — usa el modo demo',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),

            // Botones de conexión
            Row(
              children: [
                if (store.isBleSupported)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _scanning
                          ? null
                          : () => _startScan(store),
                      icon: _scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bluetooth_searching),
                      label: Text(_scanning ? 'Escaneando…' : 'Escanear BLE'),
                    ),
                  ),
                if (store.isBleSupported) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: store.addSimulated,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Modo demo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Slots de dispositivos
            Text(
              'Dispositivos (${store.connected.length}/${EegStore.maxDevices})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: store.connected.isEmpty
                  ? const Center(
                      child: Text(
                        'Conecta un dispositivo BLE o pulsa "Modo demo".',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final e in store.devices)
                          if (e != null) _DeviceSlotCard(eeg: e, store: store),
                      ],
                    ),
            ),
            const SizedBox(height: 12),

            // Acciones principales
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final slot = await _pickDevice(store, 'Elige dispositivo');
                      if (slot != null && context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DataAnalyzerScreen(slot: slot),
                          ),
                        );
                      }
                    },
                    child: const Text('Atención / Meditación'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final slot = await _pickDevice(store, 'Elige dispositivo');
                      if (slot != null && context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LevelsMindScreen(slot: slot),
                          ),
                        );
                      }
                    },
                    child: const Text('Niveles de onda'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _pickPlayersAndPlay(store),
                    child: const Text('Jugar ▶'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceSlotCard extends StatelessWidget {
  const _DeviceSlotCard({required this.eeg, required this.store});

  final EegData eeg;
  final EegStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: eeg,
      builder: (context, _) {
        final poor = eeg.signal >= 200 || eeg.signal > 100;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                eeg.name.contains('Simulated') ? Icons.science : Icons.headphones,
              ),
            ),
            title: Text('${eeg.name}  [slot ${eeg.slot}]'),
            subtitle: Text(
              'Atención ${eeg.attention}  •  Meditación ${eeg.meditation}\n'
              'Señal ${eeg.signal}/200  ${poor ? '(mala)' : '(buena)'}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => store.removeAt(eeg.slot),
            ),
          ),
        );
      },
    );
  }
}
