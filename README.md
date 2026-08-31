# Overmind NG

Next-generation version of the Android project **overmind-android** (NeuroSky/MindWave EEG),
rewritten in **Flutter**.
Runs on **Android**, **iOS** and **Linux desktop**, with a **BLE** stack for the EEG and
**FLAME** as the game's graphics engine.

## What it is

Overmind is a mind-controlled "tug-of-war" game.
Two users, each wearing an EEG headset (NeuroSky MindWave Mobile 2),
dispute a central power bar that moves according to the difference in
**(attention + meditation)**. Whoever pushes the bar off their side wins.

It also includes two real-time analyzers:
- **Attention / Meditation** (line chart)
- **Wave levels** (signal, attention, meditation and 8 EEG band bars:
  delta, theta, high/low alpha, high/low beta, high/low gamma)

## Mapping of the original project

| Original (Android, Java) | Port (Flutter) |
|---|---|
| `MainActivity` | `lib/src/screens/home_screen.dart` + `EegStore` |
| `AndroMindLib` (classic SPP Bluetooth) | `lib/src/ble/neurosky_ble.dart` (BLE) |
| Rigid 36-byte parsing | `lib/src/eeg/thinkgear_parser.dart` (real ThinkGear protocol) |
| `Eeg` | `lib/src/eeg/eeg_data.dart` |
| `DataAnalyzer` (AndroidPlot) | `lib/src/screens/data_analyzer_screen.dart` (fl_chart) |
| `LevelsMind` + `WavesIndexFormat` | `lib/src/screens/levels_mind_screen.dart` (fl_chart) |
| `SimpleGame` / `GameLayer` / `GameOverLayer` (Cocos2D) | `lib/src/game/battle_game.dart` + `game_screen.dart` (FLAME) |
| `res/raw/*.wav` and `assets/*.png` | `assets/audio/` and `assets/images/` |

## Stack

- **Flutter** (Android, iOS, Linux desktop)
- **FLAME 1.x** — game engine (sprites, simple physics, game-over overlay)
- **flutter_blue_plus** — BLE stack (scanning, connection and EEG stream reading)
- **audioplayers** — sound effects (shooting)
- **fl_chart** — analyzer charts
- **provider** — state management

## Engineering notes

- The original used **classic Bluetooth RFCOMM/SPP** with fragile parsing of
  fixed offsets over a 36-byte frame. The port uses **BLE** (MindWave
  Mobile 2) and a **state-machine parser** for the real *ThinkGear* protocol
  (`AA AA PLENGTH payload checksum`), which is essential because BLE delivers
  data in fragmented notifications. Covered by unit tests.
- On **desktop Linux** (or without hardware) there is a **demo mode** (`SimulatedMindSource`)
  that generates plausible EEG values through a random walk, so you can test
  everything (analysis and the 2-player game) without a headset.

## Permissions

- **Android**: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` and
  `ACCESS_FINE_LOCATION` (≤ SDK 30) permissions in `AndroidManifest.xml`.
- **iOS**: `NSBluetoothAlwaysUsageDescription` in `Info.plist`.

## How to run

```bash
flutter pub get
# Linux desktop (demo mode / with BLE adapter if present)
flutter run -d linux
# Android / iOS
flutter run
```

## Tests

```bash
flutter test        # ThinkGear parser + model + store
flutter analyze
```

## Structure

```
lib/
  main.dart
  src/
    eeg/      eeg_data.dart, thinkgear_parser.dart
    ble/      mind_source.dart (abstraction + simulation), neurosky_ble.dart
    state/    eeg_store.dart
    screens/  home_screen, data_analyzer_screen, levels_mind_screen, game_screen
    game/     battle_game.dart (FLAME)
assets/
  images/     original sprites and backgrounds
  audio/      pew_pew_lei.wav
```
