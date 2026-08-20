import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../eeg/eeg_data.dart';
import '../state/eeg_store.dart';

/// Port de [DataAnalyzer] (proyecto Android original): gráfica de línea en
/// tiempo real de Atención y Meditación de un dispositivo.
class DataAnalyzerScreen extends StatefulWidget {
  const DataAnalyzerScreen({super.key, required this.slot});

  final int slot;

  @override
  State<DataAnalyzerScreen> createState() => _DataAnalyzerScreenState();
}

class _DataAnalyzerScreenState extends State<DataAnalyzerScreen> {
  static const int maxPoints = 30;
  final List<double> _attention = [];
  final List<double> _meditation = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final eeg = context.read<EegStore>().devices[widget.slot];
      if (eeg == null || !mounted) return;
      setState(() {
        _attention
          ..add(eeg.attention.toDouble())
          ..removeAt(0);
        _meditation
          ..add(eeg.meditation.toDouble())
          ..removeAt(0);
      });
    });
    // Llenar con ceros iniciales.
    for (var i = 0; i < maxPoints; i++) {
      _attention.add(0);
      _meditation.add(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eeg = context.select<EegStore, EegData?>(
        (s) => s.devices[widget.slot]);
    final name = eeg?.name ?? 'Dispositivo';

    return Scaffold(
      appBar: AppBar(title: Text('Análisis — $name')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < _attention.length; i++)
                          FlSpot(i.toDouble(), _attention[i]),
                      ],
                      color: const Color(0xFF00C800),
                      isCurved: false,
                      barWidth: 2,
                    ),
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < _meditation.length; i++)
                          FlSpot(i.toDouble(), _meditation[i]),
                      ],
                      color: const Color(0xFF0000C8),
                      isCurved: false,
                      barWidth: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(Color(0xFF00C800)),
                SizedBox(width: 6),
                Text('Atención'),
                SizedBox(width: 24),
                _LegendDot(Color(0xFF0000C8)),
                SizedBox(width: 6),
                Text('Meditación'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
