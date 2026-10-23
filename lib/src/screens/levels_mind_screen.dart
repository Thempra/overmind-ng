import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../eeg/eeg_data.dart';
import '../i18n/l10n.dart';
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

  /// Nombres de banda neutros al idioma: son claves de [EegData.bands] y
  /// términos técnicos que no se traducen.
  static const signalKey = 'Signal';
  static const delta = 'Delta';
  static const theta = 'Theta';

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

  /// Orden igual al WavesIndexFormat original: clave de banda + etiqueta.
  List<(String, String)> _rows(AppStrings s) => [
        (signalKey, s.signal),
        ('Attention', s.attention),
        ('Meditation', s.meditation),
        (delta, delta),
        (theta, theta),
        ('Low Alpha', s.lowAlpha),
        ('High Alpha', s.highAlpha),
        ('Low Beta', s.lowBeta),
        ('High Beta', s.highBeta),
        ('Low Gamma', s.lowGamma),
        ('High Gamma', s.highGamma),
      ];

  /// Etiquetas cortas del eje X, en el mismo orden que [_rows].
  List<String> _shortLabels(AppStrings s) => [
        signalKey,
        s.attShort,
        s.medShort,
        delta,
        theta,
        s.lowAlphaShort,
        s.highAlphaShort,
        s.lowBetaShort,
        s.highBetaShort,
        s.lowGammaShort,
        s.highGammaShort,
      ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleController>().s;
    final eeg =
        context.select<EegStore, EegData?>((st) => st.devices[widget.slot]);
    final name = eeg?.name ?? s.device;
    final bands = eeg?.bands ?? {};
    final rows = _rows(s);
    final shortLabels = _shortLabels(s);

    return Scaffold(
      appBar: AppBar(title: Text('${s.mindLevels} — $name')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.signal, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            Text('${eeg?.signal ?? 0}/200 (${s.signalGood})'),
            const SizedBox(height: 24),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) =>
                            _bottomTitle(value, meta, shortLabels),
                      ),
                    ),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (var i = 0; i < rows.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: (bands[rows[i].$1] ?? 0)
                                .clamp(0, 100)
                                .toDouble(),
                            width: 18,
                            color: _colorFor(i),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
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

  Widget _bottomTitle(double value, TitleMeta meta, List<String> labels) {
    final i = value.toInt();
    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        labels[i],
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
