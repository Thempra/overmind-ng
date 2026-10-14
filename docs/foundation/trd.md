# Overmind NG — TRD (Technical Requirements Document)

Blueprint técnico. Decisiones canónicas; el resto de docs referencian aquí.

## 1. Stack

| Capa | Decisión | Versión fijada |
|---|---|---|
| Framework | **Flutter** (Android, iOS, Linux desktop) | SDK app `^3.5.4`; build local con `~/flutter_sdk` (Flutter 3.47 / Dart 3.13) |
| Motor de juego | **flame** (sprites, partículas, GameWidget/overlays) | 1.18.0 (pin exacto) |
| BLE | **flutter_blue_plus** | 1.32.0 (pin exacto) |
| Gráficas | **fl_chart** | ^0.66.2 |
| Estado | **provider** (ChangeNotifier + MultiProvider) | ^6.1.2 |
| Audio | **audioplayers** | ^6.0.0 |
| Permisos | **permission_handler** | 11.3.0 |
| Plataformas | **device_info_plus** ^10.1.0, **path_provider** ^2.1.5 |
| Idioma | i18n manual: `AppStrings` + `LocaleController` (sin gen l10n) | — |
| Lint/test | flutter_lints ^4.0.0, flutter_test, flame_test ^1.16.2, fake_async ^1.3.3 (pin ≥1.3.3) |

**Nota de build:** `~/flutter` (Dart 3.5.4) NO compila (`CardThemeData`); usar
`~/flutter_sdk`. `fake_async` 1.3.1 roto con SDK nuevo → `^1.3.3`.

## 2. Hardware y protocolo EEG

- Dispositivo objetivo: **NeuroSky MindWave Mobile 2** (chip ThinkGear ASIC).
- Protocolo: **ThinkGear Packet** `AA AA PLENGTH PAYLOAD CHECKSUM`, parseado por
  **máquina de estados** (`lib/src/eeg/thinkgear_parser.dart`) porque BLE
  entrega notificaciones fragmentadas. Nunca offsets fijos (error del original).
- Pandos soportados: `byteAttention(0x02)`, `byteMeditation(0x03)`,
  `rawWave(0x83..)`, `byteBlink(0xD5)`, `rawBlink(0xD6)`, `rawExtended(0xD7)`
  (parpadeo), `ASIC_EEG_POWER` (8 bandas), `poorSignal(0x02)`.
- Normalización de bandas (heredada del original, **mantener**):
  `proc = (1/raw)*1e6 * 100/1800`, clamp 0-100.
- Señales y latencia reales (diseño de juego depende de esto, ver DISENO_JUEGOS):
  attention/meditation ~1 Hz con rampas 3-8 s; **blink** 0.4-1.3 s, discreto,
  refractario ~1 s → es la única señal "acción" fiable.

## 3. Transporte de datos

- **BLE (primary)**: escaneo por nombre, GATT notify; `NeuroSkyBle` expone
  `scan/bonded/ensurePermissions`. Android 12+: `BLUETOOTH_SCAN`,
  `BLUETOOTH_CONNECT`; ≤SDK30: `ACCESS_FINE_LOCATION`. iOS:
  `NSBluetoothAlwaysUsageDescription`.
- **SPP/Classic (Android)**: MethodChannel/EventChannel nativo
  `overmind/spp` (`MainActivity.kt` + `SppClient` en Dart) para cascos
  emparejados por RFCOMM. Fusionado con LE en `EegStore.mergeBonded` (dedupe
  por MAC, orden alfabético).
- **Simulado**: `SimulatedMindSource` — timer 900 ms, random walk + blink
  estadístico; siempre disponible (demo/desktop).
- Abstracción: `MindSource` (connect/disconnect/stream/eeg) implementada por
  `NeuroSkyBle`, `SppMindSource`, `SimulatedMindSource`.

## 4. Arquitectura de código

```
lib/
  main.dart                 # bootstrap: landscape, providers, tema
  src/
    theme.dart              # tokens OvermindColors + ThemeData (design-brief)
    i18n/l10n.dart          # AppStrings es/en + LocaleController
    eeg/                    # EegData (modelo vivo) + ThinkGear parser
    ble/                    # MindSource + BLE + SPP + simulado
    state/                  # EegStore, ModeController, BattleThemeController,
                            # ProgressController (persistencia JSON)
    screens/                # home, settings, mode_selection, game, analizers,
      modes/                # player_mode_view, researcher_mode_view
    game/                   # battle_game (FLAME), battle_theme,
      games/                # balloon/falcon/seesaw logic
                            # mental_games (catálogo), mind_game_session (scaffold),
                            # signal_processor (EMA/histeresis/DDA/calibrador)
    widgets/                # ActionCard, etc.
```

Reglas:
- Los juegos **nunca** leen `EegData` crudo para premiar: todo pasa por
  `SignalProcessor` (knobs en §5).
- Todo minijuego mental usa el scaffold `MindGameSession`
  (calibrar→jugar→resultados) e implementa `GameLogic`
  (`build/update/meterValue/score/dispose`).
- Estado global solo vía provider; sin singletons nuevos salvo `SppClient.instance` (ya existente).

## 5. Primitivas de señal (signal_processor.dart)

- `SignalProcessor`: EMA attention/meditation; `blinkPulse(t)` (250 ms),
  `takeBlink(t)` (un disparo).
- `Calibrator`: 5 s de muestras → media/σ (σ clamp 4-20), `attPeak/medPeak`
  clamp 30-95 → umbrales de cada juego.
- `AdaptiveThreshold` (DDA por flow): arranca en baseline+1σ; cada 10 s,
  éxito <40% → −4, >75% → +4, límites 25-90.
- `Hysteresis.feed(v, on, off)`: entra en `on`, sale en `off` (p.ej. 55/45).

## 6. Persistencia

Sin BD. Ficheros JSON en `getApplicationSupportDirectory()`
(ver backend-schema §3 para esquemas y claves).

## 7. Testing y QA

- `flutter test`: parser ThinkGear (frames fragmentados/checksum), SPP client
  (MethodChannel mock), fuentes simuladas, signal_processor, game logic
  (fake_async), store/controladores, render smoke.
- `flutter analyze` limpio; SonarQube: proyecto en `sast.thempra.net`
  (`sonar-project.properties`).
- Coverage local en `coverage/`.

## 8. Build / release / deploy

- APK: `export PATH=$HOME/flutter_sdk/bin:$PATH && flutter pub get && flutter build apk --release`
  → `build/app/outputs/flutter-apk/app-release.apk` (~50 MB).
- Entrega por Telegram: **enlace directo**, nunca adjunto MEDIA. catbox.moe
  refuse → subir a **gofile** (`api.gofile.io/servers` → upload) y reportar
  commit, tamaño, sha256.
- Push: solo Forgejo (`origin` main); remoto GitHub da 403 con las creds actuales.
- CI: Forgejo Actions para `flutter analyze` + `flutter test` (si se añade,
  usar imagen Flutter 3.47).

## 9. Pitfalls conocidos

- `CardThemeData` exige SDK nuevo → no tocar `~/flutter` viejo.
- APK viejo en `build/` persiste: comprobar timestamp antes de entregar.
- Warnings Gradle/KGP: no-fatales.
- BLE en desktop Linux: ofrecer solo si hay pila; demo siempre disponible.
- En la batalla el viewport usa píxeles lógicos reales; escalar todo con
  `k = altura/1080` para no distorsionar en tablets/desktop.
- No premiar cruces instantáneos de umbral (ruido 1 Hz): siempre EMA +
  histéresis + sostenimiento (ver §5).
