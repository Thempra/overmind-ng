import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../eeg/eeg_data.dart';
import '../state/eeg_store.dart';

/// Port de [LevelsMind] + [WavesIndexFormat] (proyecto Android original):
/// gráfica de barras del nivel de señal, atención, meditación y 8 ondas EEG.
class LevelsMindScreen extends StatefulWidget {
  const LevelsMindScreen({super.key, required this.slot});

  final int slot;

  @override
  State<LevelsMindScreen> createState() => _LevelsMindScreenState();
}

class _LevelsMindScreenState extends State<LevelsMindScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eeg = context.select<EegStore, EegData?>((s) => s.devices[widget.slot]);
    final name = eeg?.name ?? 'Dispositivo';
    final bands = eeg?.bands ?? {};

    // Orden igual al WavesIndexFormat original.
    const order = [
      'Signal', 'Attention', 'Meditation',
      'Delta', 'Theta', 'Low Alpha', 'High Alpha',
      'Low Beta', 'High Beta', 'Low Gamma', 'High Gamma',
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Niveles de Mente — $name')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Señal', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (eeg?.signal ?? 0) >= 200
                  ? 0
                  : 1 - ((eeg?.signal ?? 0) / 200).clamp(0.0, 1.0),
              minHeight: 10,
              color: (eeg?.signal ?? 0) > 100 ? Colors.orange : Colors.green,
              backgroundColor: Colors.grey,
            ),
            const SizedBox(height: 8),
            Text('${eeg?.signal ?? 0}/200 (0 = buena)'),
            const SizedBox(height: 24),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: _bottomTitle,
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (var i = 0; i < order.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (bands[order[i]] ?? 0).clamp(0, 100).toDouble(),
                            width: 18,
                            color: _colorFor(i),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    const order = [
      'Signal', 'Att', 'Med',
      'Delta', 'Theta', 'LAlpha', 'HAlpha',
      'LBeta', 'HBeta', 'LGamma', 'HGamma',
    ];
    final i = value.toInt();
    if (i < 0 || i >= order.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        order[i],
        style: const TextStyle(fontSize: 9, color: Colors.black54),
      ),
    );
  }

  Color _colorFor(int i) {
    if (i == 0) return const Color(0xFF00C800); // señal
    if (i == 1) return const Color(0xFF0000C8); // atención
    if (i == 2) return const Color(0xFFC80000); // meditación
    return const Color(0xFF9900CC); // ondas
  }
}
