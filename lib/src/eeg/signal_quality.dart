/// Modelo explícito de calidad de señal del ThinkGear (NeuroSky).
///
/// `poorSignal` de ThinkGear es una escala INVERSA: 0 = contacto perfecto,
/// 200 = electrodo sin contacto. El error histórico del proyecto era usar
/// `signal = 0` como centinela de "sin datos", lo que convertía el estado
/// "desconectado / nunca hubo datos" en "señal perfecta" (4 barras verdes).
///
/// Aquí separamos los tres casos que antes se confundían:
///   (a) nunca llegó un paquete            → [SignalQuality.unknown]
///   (b) hubo paquete y poorSignal = 200   → [SignalQuality.offline]
///   (c) hubo paquete con contacto         → weak / poor / fair / good
///
/// Los cortes 30/80/140/190 son los umbrales del HUD (1..4 barras).
library;

/// Calidad de señal derivada de `poorSignal`, con el estado "sin datos"
/// representado explícitamente.
enum SignalQuality {
  /// Todavía no ha llegado ningún paquete (recién conectado, o slot vacío).
  unknown,

  /// Último paquete con `poorSignal >= 200`: electrodo sin contacto.
  offline,

  /// Contacto muy malo (191-199): 1 barra.
  weak,

  /// Contacto malo (141-190): 2 barras.
  poor,

  /// Contacto aceptable (81-140): 3 barras.
  fair,

  /// Contacto bueno (0-30): 4 barras.
  good;

  /// Barras de señal a pintar (0 = ninguna). `unknown` y `offline` NUNCA
  /// pueden pintar barras: es la garantía que faltaba.
  int get bars => switch (this) {
        SignalQuality.good => 4,
        SignalQuality.fair => 3,
        SignalQuality.poor => 2,
        SignalQuality.weak => 1,
        SignalQuality.offline => 0,
        SignalQuality.unknown => 0,
      };

  /// Hay electrodo en la cabeza (aunque la señal sea mala).
  bool get hasContact =>
      this == SignalQuality.weak ||
      this == SignalQuality.poor ||
      this == SignalQuality.fair ||
      this == SignalQuality.good;

  /// Señal lo bastante mala como para avisar al jugador.
  bool get isBad =>
      this == SignalQuality.offline ||
      this == SignalQuality.weak ||
      this == SignalQuality.poor;

  /// Señal utilizable para jugar (fair o good).
  bool get isUsable => this == SignalQuality.fair || this == SignalQuality.good;
}

/// Umbrales de `poorSignal` (inclusive) para cada nivel.
const int kSignalGoodMax = 30;
const int kSignalFairMax = 80;
const int kSignalPoorMax = 140;
const int kSignalWeakMax = 190;

/// Valor de ThinkGear que significa "sin contacto".
const int kSignalNoContact = 200;

/// Traduce `poorSignal` (0..200) a un estado explícito.
///
/// [hasData] distingue "no ha llegado nada todavía" ([SignalQuality.unknown])
/// de "ha llegado un paquete sin contacto" ([SignalQuality.offline]).
SignalQuality signalQualityOf(int? poorSignal, {bool hasData = true}) {
  if (!hasData) return SignalQuality.unknown;
  final v = poorSignal;
  // Valores fuera de rango (null / negativos) se tratan como sin contacto:
  // ante la duda, no mentir al jugador con barras verdes.
  if (v == null || v < 0 || v >= kSignalNoContact) return SignalQuality.offline;
  if (v <= kSignalGoodMax) return SignalQuality.good;
  if (v <= kSignalFairMax) return SignalQuality.fair;
  if (v <= kSignalPoorMax) return SignalQuality.poor;
  // 191-199 es un contacto pésimo pero CONTACTO: solo 200 (o más) significa
  // electrodo fuera. Tratarlo como "offline" mentiría al jugador.
  return SignalQuality.weak;
}
