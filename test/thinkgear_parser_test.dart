import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:overmind/src/eeg/thinkgear_parser.dart';

/// Construye un paquete ThinkGear válido: [0xAA, 0xAA, PLENGTH, payload, checksum].
///
/// El checksum del protocolo real (TGAM) es el **complemento a uno** de la
/// suma del payload: `~suma & 0xFF` (verificado contra el hardware ThempraEEG).
Uint8List buildPacket(List<int> payload) {
  var sum = 0;
  for (final b in payload) {
    sum += b;
  }
  final checksum = (~(sum & 0xFF)) & 0xFF;
  return Uint8List.fromList([
    0xAA,
    0xAA,
    payload.length,
    ...payload,
    checksum,
  ]);
}

Uint8List concat(List<Uint8List> parts) {
  final out = BytesBuilder(copy: false);
  for (final p in parts) {
    out.add(p);
  }
  return out.toBytes();
}

void main() {
  group('ThinkGearParser', () {
    test('parsea un paquete completo con atención/meditación y ondas', () {
      final payload = <int>[
        0x02, 0x00, // poor signal = 0
        0x04, 0x50, // attention = 80
        0x05, 0x32, // meditation = 50
        // ASIC_EEG_POWER: 0x83 0x18 + 24 bytes (delta, theta, la, ha, lb, hb, lg, hg)
        0x83, 0x18,
        0x00, 0x00, 0x64, // delta = 100
        0x00, 0x00, 0x50, // theta = 80
        0x00, 0x00, 0x40, // low alpha = 64
        0x00, 0x00, 0x30, // high alpha = 48
        0x00, 0x00, 0x20, // low beta = 32
        0x00, 0x00, 0x10, // high beta = 16
        0x00, 0x00, 0x0A, // low gamma = 10
        0x00, 0x00, 0x05, // high gamma = 5
      ];
      final parser = ThinkGearParser();
      final out = parser.addBytes(buildPacket(payload));

      expect(out, hasLength(1));
      final c = out.first;
      expect(c.poorSignal, 0);
      expect(c.attention, 80);
      expect(c.meditation, 50);
      expect(c.rawDelta, 100);
      expect(c.rawTheta, 80);
      expect(c.rawLowAlpha, 64);
      expect(c.rawHighAlpha, 48);
      expect(c.rawLowBeta, 32);
      expect(c.rawHighBeta, 16);
      expect(c.rawLowGamma, 10);
      expect(c.rawHighGamma, 5);
    });

    test('frame REAL capturado del ThempraEEG por SPP (fragmentado)', () {
      // Captura literal del log OvermindSPP (sesión 22:55:25):
      // POOR=0, ATN=77, MDT=63, checksum 0xD6 (complemento a uno).
      final chunks = [
        [0xAA],
        [0xAA, 0x20, 0x02, 0x00, 0x83, 0x18, 0x01, 0x03, 0x0B, 0x01, 0x13],
        [0x77, 0x00, 0xCF, 0xC6, 0x00, 0x6B, 0x91, 0x00, 0x32, 0x30],
        [0x00, 0x39, 0x13, 0x00, 0x08, 0xF6, 0x00, 0x07, 0x19, 0x04],
        [0x4D, 0x05, 0x3F, 0xD6],
      ];
      final parser = ThinkGearParser();
      final out = <MindWaveCapture>[];
      for (final c in chunks) {
        out.addAll(parser.addBytes(Uint8List.fromList(c)));
      }

      expect(out, hasLength(1));
      final cap = out.first;
      expect(cap.poorSignal, 0);
      expect(cap.attention, 77);
      expect(cap.meditation, 63);
      expect(cap.rawDelta, 0x01030B);
      expect(cap.rawHighGamma, 0x000719);
    });

    test('descarta paquetes con checksum inválido', () {
      final payload = <int>[
        0x04, 0x50,
      ];
      final bytes = buildPacket(payload);
      bytes[bytes.length - 1] = 0; // corromper checksum
      final parser = ThinkGearParser();
      expect(parser.addBytes(bytes), isEmpty);
    });

    test('maneja fragmentación BLE (paquete partido en varios trozos)', () {
      final payload = <int>[
        0x02, 0x05, // poor signal = 5
        0x04, 0x64, // attention = 100
        0x05, 0x00, // meditation = 0
      ];
      final full = buildPacket(payload);
      final parser = ThinkGearParser();

      // Entregar byte a byte.
      final out = <Object>[];
      for (final b in full) {
        out.addAll(parser.addBytes(Uint8List.fromList([b])));
      }
      final flat = out.cast<MindWaveCapture>();
      expect(flat, hasLength(1));
      expect(flat.first.attention, 100);
      expect(flat.first.poorSignal, 5);
    });

    test('maneja dos paquetes en una sola ráfaga BLE', () {
      final p1 = buildPacket([0x02, 0x10, 0x04, 0x32]);
      final p2 = buildPacket([0x02, 0x20, 0x05, 0x64]);
      final parser = ThinkGearParser();
      final out = parser.addBytes(concat([p1, p2]));
      expect(out, hasLength(2));
      expect(out[0].attention, 50);
      expect(out[1].meditation, 100);
    });

    test('ignora RAW_WAVE (0x80) y salta códigos desconocidos con longitud', () {
      final payload = <int>[
        0x80, 0x02, 0x12, 0x34, // raw wave (se ignora)
        0x04, 0x2A, // attention = 42
        0x05, 0x1E, // meditation = 30
      ];
      final parser = ThinkGearParser();
      final out = parser.addBytes(buildPacket(payload));
      expect(out, hasLength(1));
      expect(out.first.attention, 42);
      expect(out.first.meditation, 30);
    });
  });
}
