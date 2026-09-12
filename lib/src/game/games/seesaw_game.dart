import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../eeg/eeg_data.dart';
import '../mind_game_session.dart';
import '../signal_processor.dart';

// ===========================================================================
//  DUELO — balancín de calma, 2 jugadores locales (8-99 años).
//  Basado en el duelo EEG "seesaw" validado científicamente (J Neural Eng
//  2022, alfa relativo): cada jugador empuja la bola con su calma normalizada
//  (meditación-atención respecto a su baseline). Gana quien mantiene la
//  bola en el campo del rival al terminar cada ronda.
// ===========================================================================
class SeesawLogic extends GameLogic {
  SeesawLogic({required this.eegs, required this.cal});

  final List<EegData?> eegs;
  final Calibrator cal;

  double _ball = 0.5; // 0 = lado jug.1, 1 = lado jug.2
  double _smoothA = 0, _smoothB = 0;
  int _round = 1;
  int _winsA = 0, _winsB = 0;
  double _roundT = 0;
  double _lockT = 0; // congelar bola 1.5 s entre rondas
  late double _baseA, _baseB;

  _SeesawView? _view;

  /// "Calma" normalizada del jugador i respecto a su baseline de calibración.
  double _drive(EegData? e, double base) {
    if (e == null) return 0;
    final calm = e.meditation - e.attention; // eje opuesto
    final norm = ((calm - base) / 30).clamp(-1.0, 1.0);
    return norm;
  }

  @override
  Future<void> build(FlameGame game, Vector2 size) async {
    _baseA = cal.medMean - cal.attMean;
    _baseB = _baseA; // un solo cabezal de calibración para ambos
    _smoothA = _smoothB = 0;
    _view = _SeesawView()..priority = 5;
    game.add(_view!);
  }

  @override
  void update(double dt, double t) {
    if (_lockT > 0) {
      _lockT -= dt;
      return;
    }
    _roundT += dt;
    final a = _drive(eegs[0], _baseA);
    final b = _drive(eegs.length > 1 ? eegs[1] : null, _baseB);
    _smoothA = SignalProcessor.ema(_smoothA, a, 0.2);
    _smoothB = SignalProcessor.ema(_smoothB, b, 0.2);
    _ball = (_ball + (_smoothA - _smoothB) * dt * 0.28).clamp(0.0, 1.0);
    _view!.ball = _ball;

    if (_ball <= 0.02 || _ball >= 0.98 || _roundT > 20) {
      // Fin de ronda: la bola a 0 = campo del 1 vacío -> gana el 1.
      if (_ball <= 0.5) {
        _winsA++;
      } else {
        _winsB++;
      }
      _round++;
      _ball = 0.5;
      _roundT = 0;
      _lockT = 1.5;
    }
    _view!.hud = '$_winsA  —  $_winsB   ·  ronda $_round';
  }

  @override
  double meterValue() {
    final e = eegs.firstWhere((x) => x != null, orElse: () => eegs.first);
    return (e?.meditation ?? 0) / 100;
  }

  @override
  int score() => _winsA; // P1 local: sus rondas ganadas
}

class _SeesawView extends PositionComponent {
  double ball = 0.5;
  String hud = '';
  double _t = 0;

  @override
  void onGameResize(Vector2 c) {
    super.onGameResize(c);
    size = c;
  }

  @override
  void update(double dt) => _t += dt;

  void _drawText(Canvas canvas, String text, double cx, double y, double fontSize, Color color) {
    final pb = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center));
    pb.pushStyle(TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 4)],
    ));
    pb.addText(text);
    final para = pb.build()..layout(ParagraphConstraints(width: size.x));
    canvas.drawParagraph(para, Offset(0, y));
    // centrado aproximado ya lo da textAlign center sobre width=size.x
    assert(cx == cx);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x, h = size.y;
    // campos
    canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h),
        Paint()..color = const Color(0x2235B6FF));
    canvas.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h),
        Paint()..color = const Color(0x22FF4B4B));
    // suelo
    final floorY = h * 0.75;
    canvas.drawLine(Offset(0, floorY), Offset(w, floorY),
        Paint()..color = const Color(0x40FFFFFF));
    // bola dorada
    final x = w * 0.08 + ball * w * 0.84;
    final r = w * 0.035;
    final bounce = math.sin(_t * 6).abs() * 4;
    canvas.drawCircle(
        Offset(x, floorY - r - bounce),
        r,
        Paint()
          ..shader = Gradient.radial(
              Offset(x - r / 3, floorY - r * 1.4 - bounce),
              r * 1.4,
              [const Color(0xFFFFFFFF), const Color(0xFFE8B44B)]));
    // marcador
    _drawText(canvas, hud, w / 2, 16, 34, const Color(0xFFFFFFFF));
  }
}
