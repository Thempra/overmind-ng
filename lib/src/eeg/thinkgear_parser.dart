import 'package:flutter/foundation.dart';

/// Resultado de un paquete ThinkGear completo parseado.
@immutable
class MindWaveCapture {
  const MindWaveCapture({
    this.poorSignal = 200,
    this.attention = 0,
    this.meditation = 0,
    this.rawDelta = 0,
    this.rawTheta = 0,
    this.rawLowAlpha = 0,
    this.rawHighAlpha = 0,
    this.rawLowBeta = 0,
    this.rawHighBeta = 0,
    this.rawLowGamma = 0,
    this.rawHighGamma = 0,
  });

  final int poorSignal;
  final int attention;
  final int meditation;
  final int rawDelta;
  final int rawTheta;
  final int rawLowAlpha;
  final int rawHighAlpha;
  final int rawLowBeta;
  final int rawHighBeta;
  final int rawLowGamma;
  final int rawHighGamma;
}

/// Parser de máquina de estados del protocolo **ThinkGear** (NeuroSky).
///
/// El proyecto Android original leía un frame rígido de 36 bytes con offsets
/// hardcodeados (frágil y solo válido para un firmware concreto). Para el port
/// BLE implementamos el protocolo real: los datos llegan en notificaciones BLE
/// que pueden fragmentar o juntar varios paquetes, así que este parser acumula
/// bytes y extrae paquetes completos [Sync, Sync, PLENGTH, Payload, Checksum].
///
/// Códigos de payload soportados (formato TGAM real, verificado con hardware):
///  0x02 POOR_SIGNAL (1B, sin byte de longitud)
///  0x04 ATTENTION   (1B, sin byte de longitud)
///  0x05 MEDITATION  (1B, sin byte de longitud)
///  0x80 RAW_WAVE    [0x80][0x02][2B le]  — se ignora
///  0x83 ASIC_EEG_POWER [0x83][0x18][24B, 8 bandas big-endian]
/// El checksum es el complemento a UNO de la suma del payload.
class ThinkGearParser {
  final Uint8List _buf;
  int _len = 0;
  final List<MindWaveCapture> _out = [];

  ThinkGearParser({int bufferCapacity = 1024})
      : _buf = Uint8List(bufferCapacity);

  static const int _sync = 0xAA;

  /// Alimenta el parser con bytes entrantes y devuelve las capturas completas.
  List<MindWaveCapture> addBytes(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if (_len == 0 && b == _sync) {
        _buf[_len++] = b;
        continue;
      }
      if (_len == 1 && b == _sync) {
        _buf[_len++] = b;
        continue;
      }
      if (_len == 0) continue; // aún no hemos visto el primer sync
      _buf[_len++] = b;
      if (_len == 2) continue; // esperando PLENGTH

      final pLength = _buf[2];
      if (_len == 4 + pLength) {
        // Frame completo: 2 sync + 1 PLENGTH + pLength payload + 1 checksum.
        // El checksum del protocolo TGAM real es el COMPLEMENTO A UNO de la
        // suma del payload (verificado contra hardware ThempraEEG):
        // (suma_baja + checksum) & 0xFF == 0xFF.
        var sum = 0;
        for (var j = 3; j < 3 + pLength; j++) {
          sum += _buf[j] & 0xFF;
        }
        final checksum = _buf[3 + pLength] & 0xFF;
        final valid = ((sum & 0xFF) + checksum) & 0xFF == 0xFF;
        if (valid) {
          _out.add(_decodePayload(pLength));
        }
        _len = 0;
      }
    }
    final result = List<MindWaveCapture>.from(_out);
    _out.clear();
    return result;
  }

  MindWaveCapture _decodePayload(int pLength) {
    var poorSignal = 200;
    var attention = 0;
    var meditation = 0;
    var rawDelta = 0, rawTheta = 0;
    var rawLowAlpha = 0, rawHighAlpha = 0;
    var rawLowBeta = 0, rawHighBeta = 0;
    var rawLowGamma = 0, rawHighGamma = 0;

    // Formato REAL TGAM: los códigos de 1 byte (0x02 POOR_SIGNAL, 0x04
    // ATTENTION, 0x05 MEDITATION) van como [código][valor] SIN byte de
    // longitud. El resto (0x80 RAW, 0x83 ASIC_EEG_POWER…) lleva
    // [código][longitud][datos].
    var i = 3;
    while (i < 3 + pLength) {
      final code = _buf[i] & 0xFF;
      if (code == 0x02 || code == 0x04 || code == 0x05) {
        if (i + 1 >= 3 + pLength) break;
        final value = _buf[i + 1] & 0xFF;
        switch (code) {
          case 0x02:
            poorSignal = value;
          case 0x04:
            attention = value;
          case 0x05:
            meditation = value;
        }
        i += 2;
        continue;
      }
      if (i + 1 >= 3 + pLength) break;
      final len = _buf[i + 1] & 0xFF;
      final valueStart = i + 2;
      if (valueStart + len > 3 + pLength) break;

      if (code == 0x83 && len >= 24) {
        // ASIC_EEG_POWER: 8 bandas x 3 bytes big-endian.
        rawDelta = _b3(valueStart);
        rawTheta = _b3(valueStart + 3);
        rawLowAlpha = _b3(valueStart + 6);
        rawHighAlpha = _b3(valueStart + 9);
        rawLowBeta = _b3(valueStart + 12);
        rawHighBeta = _b3(valueStart + 15);
        rawLowGamma = _b3(valueStart + 18);
        rawHighGamma = _b3(valueStart + 21);
      }
      // 0x80 RAW_WAVE y otros códigos se ignoran.

      i = valueStart + len;
    }

    return MindWaveCapture(
      poorSignal: poorSignal,
      attention: attention,
      meditation: meditation,
      rawDelta: rawDelta,
      rawTheta: rawTheta,
      rawLowAlpha: rawLowAlpha,
      rawHighAlpha: rawHighAlpha,
      rawLowBeta: rawLowBeta,
      rawHighBeta: rawHighBeta,
      rawLowGamma: rawLowGamma,
      rawHighGamma: rawHighGamma,
    );
  }

  int _b3(int offset) {
    return (_buf[offset] & 0xFF) << 16 |
        (_buf[offset + 1] & 0xFF) << 8 |
        (_buf[offset + 2] & 0xFF);
  }
}
