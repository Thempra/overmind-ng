# Overmind (Flutter)

Port a **Flutter** del proyecto Android **overmind-android** (NeuroSky/MindWave EEG).
Corre en **Android**, **iOS** y **Linux desktop**, con pila **BLE** para el EEG y
**FLAME** como motor de gráficos del juego.

## Qué es

Overmind es un juego de "tira y afloja" (tug-of-war) controlado por la mente.
Dos usuarios, cada uno con un auricular EEG (NeuroSky MindWave Mobile 2),
disputan una barra de poder central que se desplaza según la diferencia de
**(atención + meditación)**. Gana quien empuja la barra fuera de su lado.

Incluye también dos analizadores en tiempo real:
- **Atención / Meditación** (gráfica de línea)
- **Niveles de onda** (barras de señal, atención, meditación y 8 bandas EEG:
  delta, theta, alta/baja alpha, alta/baja beta, alta/baja gamma)

## Mapeo del proyecto original

| Original (Android, Java) | Port (Flutter) |
|---|---|
| `MainActivity` | `lib/src/screens/home_screen.dart` + `EegStore` |
| `AndroMindLib` (BT clásico SPP) | `lib/src/ble/neurosky_ble.dart` (BLE) |
| Parseo rígido de 36 bytes | `lib/src/eeg/thinkgear_parser.dart` (protocolo ThinkGear real) |
| `Eeg` | `lib/src/eeg/eeg_data.dart` |
| `DataAnalyzer` (AndroidPlot) | `lib/src/screens/data_analyzer_screen.dart` (fl_chart) |
| `LevelsMind` + `WavesIndexFormat` | `lib/src/screens/levels_mind_screen.dart` (fl_chart) |
| `SimpleGame` / `GameLayer` / `GameOverLayer` (Cocos2D) | `lib/src/game/battle_game.dart` + `game_screen.dart` (FLAME) |
| `res/raw/*.wav` y `assets/*.png` | `assets/audio/` y `assets/images/` |

## Stack

- **Flutter** (Android, iOS, Linux desktop)
- **FLAME 1.x** — motor del juego (sprites, física sencilla, overlay de fin)
- **flutter_blue_plus** — pila BLE (escaneo, conexión y lectura del stream EEG)
- **audioplayers** — efectos de sonido (disparo)
- **fl_chart** — gráficas de los analizadores
- **provider** — gestión de estado

## Notas de ingeniería

- El original usaba **Bluetooth clásico RFCOMM/SPP** con un parseo frágil de
  offsets fijos sobre un frame de 36 bytes. El port usa **BLE** (MindWave
  Mobile 2) y un **parser de máquina de estados** del protocolo *ThinkGear*
  real (`AA AA PLENGTH payload checksum`), imprescindible porque BLE entrega
  los datos en notificaciones fragmentadas. Cubierto por tests unitarios.
- En **desktop Linux** (o sin hardware) hay un **modo demo** (`SimulatedMindSource`)
  que genera valores EEG plausibles mediante un paseo aleatorio, para poder
  probar todo (análisis y juego con 2 jugadores) sin auricular.
- `flutter_blue_plus` `connect()` exige el parámetro `License` (se usa
  `License.nonprofit`, válido para uso personal/no comercial/educativo).

## Permisos

- **Android**: permisos `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` y
  `ACCESS_FINE_LOCATION` (≤ SDK 30) en `AndroidManifest.xml`.
- **iOS**: `NSBluetoothAlwaysUsageDescription` en `Info.plist`.

## Cómo ejecutar

```bash
flutter pub get
# Linux desktop (modo demo / con adaptador BLE si existe)
flutter run -d linux
# Android / iOS
flutter run
```

## Tests

```bash
flutter test        # parser ThinkGear + modelo + store
flutter analyze
```

## Estructura

```
lib/
  main.dart
  src/
    eeg/      eeg_data.dart, thinkgear_parser.dart
    ble/      mind_source.dart (abstracción + simulación), neurosky_ble.dart
    state/    eeg_store.dart
    screens/  home_screen, data_analyzer_screen, levels_mind_screen, game_screen
    game/     battle_game.dart (FLAME)
assets/
  images/     sprites y fondos del original
  audio/      pew_pew_lei.wav
```
