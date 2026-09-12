import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Progreso persistente de la plataforma: mejor puntuación por juego,
/// puntos mentales totales y racha diaria de entrenamiento (con congelador:
/// un día malo de EEG no rompe la racha si ya hubo otro esa misma semana).
class ProgressController extends ChangeNotifier {
  final Map<String, int> best = {};
  int mentalPoints = 0;
  int streakDays = 0;
  String? lastPlayedDay; // yyyy-MM-dd
  String? frozenDay; // día guardado por el congelador

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/progress.json');
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      best.addAll((j['best'] as Map?)?.cast<String, int>() ?? {});
      mentalPoints = j['mp'] as int? ?? 0;
      streakDays = j['streak'] as int? ?? 0;
      lastPlayedDay = j['last'] as String?;
      frozenDay = j['frozen'] as String?;
      notifyListeners();
    } catch (_) {}
  }

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Registra el resultado de una partida. Devuelve true si hay récord.
  bool record(String gameId, int score) {
    final prev = best[gameId] ?? 0;
    final isRecord = score > prev;
    if (isRecord) best[gameId] = score;
    mentalPoints += score;
    _touchStreak();
    notifyListeners();
    _persist();
    return isRecord;
  }

  void _touchStreak() {
    final today = _today;
    if (lastPlayedDay == today) return;
    if (lastPlayedDay != null) {
      final last = DateTime.parse(lastPlayedDay!);
      final gap = DateTime.now().difference(last).inDays;
      if (gap == 1) {
        streakDays++;
      } else if (gap == 2 && frozenDay != yesterdayOf(today)) {
        // salto de un día: se perdona una vez (congelador), que se consume.
        frozenDay = yesterdayOf(today);
        streakDays++;
      } else {
        streakDays = 1;
      }
    } else {
      streakDays = 1;
    }
    lastPlayedDay = today;
    // Ganar un congelador por cada 7 días de racha.
    if (streakDays > 0 && streakDays % 7 == 0) frozenDay ??= today;
  }

  static String yesterdayOf(String day) {
    final d = DateTime.parse(day).subtract(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/progress.json');
      await f.writeAsString(jsonEncode({
        'best': best,
        'mp': mentalPoints,
        'streak': streakDays,
        'last': lastPlayedDay,
        'frozen': frozenDay,
      }));
    } catch (_) {}
  }
}
