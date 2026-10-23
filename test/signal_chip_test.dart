// HUD: el chip de señal NUNCA pinta barras llenas cuando no hay contacto.
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/eeg/eeg_data.dart';
import 'package:overmind/src/eeg/signal_quality.dart';
import 'package:overmind/src/game/battle_game.dart';
import 'package:overmind/src/game/battle_theme.dart';
import 'package:overmind/src/i18n/l10n.dart';
import 'package:overmind/src/game/signal_chip.dart';
import 'package:overmind/src/game/signal_monitor.dart';

const origin = Offset(100, 40);

SignalChipLayout chipFor(
  SignalQuality q, {
  bool demo = false,
  String? offlineLabel,
}) =>
    layoutSignalChip(
      quality: q,
      origin: origin,
      isDemo: demo,
      disconnectedLabel: offlineLabel,
    );

void main() {
  group('layoutSignalChip: "desconectado" no puede verse como señal llena', () {
    test('unknown ⇒ 0 barras encendidas', () {
      final chip = chipFor(SignalQuality.unknown);
      expect(chip.filledBars, 0);
      expect(chip.fills.every((c) => c == null), isTrue,
          reason: 'el bug pintaba 4 barras verdes con signal=0');
      expect(chip.showsDisconnected, isTrue);
    });

    test('offline (poorSignal=200) ⇒ 0 barras encendidas', () {
      final chip = chipFor(SignalQuality.offline, offlineLabel: 'SIN SEÑAL');
      expect(chip.filledBars, 0);
      expect(chip.label, 'SIN SEÑAL');
      expect(chip.showsDisconnected, isTrue);
    });

    test('offline y good no comparten ni una barra encendida', () {
      final off = chipFor(SignalQuality.offline);
      final good = chipFor(SignalQuality.good);
      expect(good.filledBars, 4);
      expect(off.filledBars, 0);
      expect(off.fills.any((c) => c != null), isFalse);
      expect(good.fills.every((c) => c == SignalChipColors.good), isTrue);
    });

    test('las 4 calidades con contacto pintan 1..4 barras', () {
      expect(chipFor(SignalQuality.weak).filledBars, 1);
      expect(chipFor(SignalQuality.poor).filledBars, 2);
      expect(chipFor(SignalQuality.fair).filledBars, 3);
      expect(chipFor(SignalQuality.good).filledBars, 4);
    });

    test('las barras encendidas son siempre las primeras (izq→der)', () {
      for (final q in [SignalQuality.weak, SignalQuality.fair]) {
        final chip = chipFor(q);
        final n = q.bars;
        for (var i = 0; i < 4; i++) {
          expect(chip.fills[i] != null, i < n, reason: '$q barra $i');
        }
      }
    });

    test('DEMO pinta 0 barras y etiqueta gris', () {
      final chip = chipFor(SignalQuality.good, demo: true);
      expect(chip.isDemo, isTrue);
      expect(chip.filledBars, 0, reason: 'un demo no debe parecer un EEG real');
      expect(chip.label, 'DEMO');
    });

    test('geometría: 4 barras crecientes y dentro del chip', () {
      final chip = chipFor(SignalQuality.good, offlineLabel: 'X');
      expect(chip.bars, hasLength(4));
      for (var i = 1; i < 4; i++) {
        expect(chip.bars[i].height, greaterThan(chip.bars[i - 1].height));
      }
      for (final b in chip.bars) {
        expect(chip.chipRect.contains(b.topLeft), isTrue);
        expect(b.bottom, lessThanOrEqualTo(chip.chipRect.bottom + 0.01));
      }
      expect(chip.chipRect.width, kSignalChipWidth);
      expect(chip.chipRect.height, kSignalChipHeight);
    });

    test('alignRight ancla el chip por su borde derecho', () {
      final chip = layoutSignalChip(
        quality: SignalQuality.good,
        origin: const Offset(400, 10),
        alignRight: true,
      );
      expect(chip.chipRect.right, 400);
      expect(chip.chipRect.left, 400 - kSignalChipWidth);
    });
  });

  group('Hud: la fuente de verdad es la calidad, no el int', () {
    test('updateSignal propaga calidad y DEMO por lado', () {
      final hud = Hud(BattleTheme.neon)
        ..updateSignal(
          quality1: SignalQuality.offline,
          quality2: SignalQuality.good,
          demo1: false,
          demo2: true,
        );
      expect(hud.quality1, SignalQuality.offline);
      expect(hud.quality2, SignalQuality.good);
      expect(hud.demo2, isTrue);
    });

    test('un chip del HUD con poorSignal=200 no tiene barras', () {
      // Reproduce el camino completo: EegData real → calidad → layout.
      final e = EegData(address: 'a', name: 'n', slot: 0);
      e.applyCapture(
        signal: 200,
        attention: 95,
        meditation: 95,
        rawDelta: 100,
        rawTheta: 80,
        rawLowAlpha: 64,
        rawHighAlpha: 48,
        rawLowBeta: 32,
        rawHighBeta: 16,
        rawLowGamma: 10,
        rawHighGamma: 5,
      );
      final chip = chipFor(e.signalQuality, offlineLabel: 'SIN SEÑAL');
      expect(chip.filledBars, 0);
      expect(chip.showsDisconnected, isTrue);
    });

    test('el HUD renderiza sin excepción con señal offline y con DEMO', () {
      // Canvas real de registro: ejercita los métodos render del chip.
      final hud = Hud(BattleTheme.neon)
        ..size = Vector2(1280, 720)
        ..setScale(1)
        ..updateSignal(
          quality1: SignalQuality.offline,
          quality2: SignalQuality.unknown,
          demo1: false,
          demo2: true,
        );
      final pic = PictureRecorder();
      final canvas = Canvas(pic);
      hud.render(canvas);
      expect(pic.endRecording(), isNotNull);
    });
  });

  group('SignalOverlay: banda de aviso y overlay de reconexión', () {
    test('sin degradación ni pérdida no se pinta nada', () {
      final o = SignalOverlay(() => AppStrings.es);
      expect(o.showsWarning, isFalse);
      expect(o.isLost, isFalse);
    });

    test('señal mala sostenida ⇒ banda de aviso sin pausa', () {
      final o = SignalOverlay(() => AppStrings.es)
        ..updateSignal(
          state1: SignalWatchState.degraded,
          state2: SignalWatchState.ok,
        );
      expect(o.showsWarning, isTrue);
      expect(o.isLost, isFalse, reason: 'la partida NO se detiene por umbral');
    });

    test('enlace perdido ⇒ overlay de reconexión (pausa)', () {
      final o = SignalOverlay(() => AppStrings.es)
        ..updateSignal(
          state1: SignalWatchState.lost,
          state2: SignalWatchState.lost,
        )
        ..markPaused();
      expect(o.isLost, isTrue);
      expect(o.pausedNow, isTrue);
      o.markResumed();
      expect(o.pausedNow, isFalse);
    });

    test('el overlay se renderiza en ambos estados sin excepción', () {
      for (final st in [SignalWatchState.degraded, SignalWatchState.lost]) {
        final o = SignalOverlay(() => AppStrings.en)
          ..size = Vector2(1280, 720)
          ..setScale(1)
          ..updateSignal(state1: st, state2: st);
        final pic = PictureRecorder();
        o.render(Canvas(pic));
        expect(pic.endRecording(), isNotNull, reason: '$st');
      }
    });
  });
}
