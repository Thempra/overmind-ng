# Overmind NG — Backend Schema

**No hay backend remoto ni base de datos.** La app es 100 % local (PRD §4).
Este doc define: modelo de datos en runtime, persistencia en disco (KV JSON),
contrato de claves, "autenticación" (emparejamiento de dispositivos) y flujos
de datos end-to-end.

## 1. Almacenamiento

| Mecanismo | Dónde | Qué guarda |
|---|---|---|
| Memoria (provider) | `EegStore` + `EegData` por slot | Estado EEG vivo |
| Fichero JSON | `getApplicationSupportDirectory()/progress.json` | Progreso del jugador |
| Fichero JSON | `getApplicationSupportDirectory()/battle_theme.json` | Tema de batalla elegido |
| Preferencia de idioma | `LocaleController` (en memoria; pendiente persistir → pregunta PRD) | es/en |

No se usan SharedPreferences ni BD; `path_provider` + `dart:io`.

## 2. Modelo en runtime (no persistido)

### EegStore (singleton por provider)
| Campo | Tipo | Notas |
|---|---|---|
| devices | `List<EegData?>[8]` | index = slot; null = libre (máx. 8, herencia del MAX_NUM_BLUETOOTH original) |
| sources | `List<MindSource?>[8]` | NeuroSkyBle / SppMindSource / SimulatedMindSource |
| discovered | `List<MindDevice>` | resultado de scan/bonded |
| scanning, bleAvailable, permissionError | bool/bool/String? | estado de UI |

### EegData (ChangeNotifier mutante, uno por slot)
address (String, p.ej. `sim:0` o MAC), name, slot, signal (poorSignal 0-200),
attention 0-100, meditation 0-100, blinkStrength, blinkDetected, blinkSeq
(monoctrónico, protege contra doble consumo), raw{Delta,Theta,LowAlpha,
HighAlpha,LowBeta,HighBeta,LowGamma,HighGamma} (uint ASIC), getters proc
`delta..hgamma` (normalización TRD §2), `power = (att+med)/2`, `bands` (map
11 claves para el analizador).

### MindDevice
id (=remoteId/MAC), name, `isClassic`, bleDevice? (FlutterBluePlus).

## 3. Persistencia en disco

### `progress.json` (ProgressController)
```json
{
  "best":   { "<gameId>": int },      // récords por juego
  "mp":     int,                       // puntos mentales totales (Σ scores)
  "streak": int,                       // racha diaria actual
  "last":   "yyyy-MM-dd" | null,       // último día jugado
  "frozen": "yyyy-MM-dd" | null        // día congelado (1 perdón)
}
```
Claves de `best` = `MentalGame.id`: `balloon | seesaw | falcon` (+ futuros;
los duelos temáticos aún no puntúan → abierto).
Reglas de racha: gap 1 d → +1; gap 2 d y congelador sin usar → consume
congelador, +1; resto → reset a 1; cada 7 días de racha se gana 1 congelador.
Lecturas/escrituras best-effort (fallos silenciosos de I/O tolerados a propósito).

### `battle_theme.json` (BattleThemeController)
```json
{ "theme": "evangelion" | "superpoderes" }
```

## 4. Contrato de canal nativo (Android SPP)

| Canal | Tipo | Métodos/eventos |
|---|---|---|
| `overmind/spp` | MethodChannel | `devices` → `[{address,name}]`; `connect(mac)`; `disconnect` |
| `overmind/spp/events` | EventChannel | stream de bytes RFCOMM → parser ThinkGear en Dart |

Solo Android; en resto de plataformas `SppClient` lanza excepción y
`loadBonded` degrada a solo LE.

## 5. "Autenticación" = ciclo de vida de dispositivo

No hay usuarios, tokens ni sesiones de usuario. La única identidad es el
bindeo del casco:

```
[Scan BLE] --nombre/MAC--> discovered
[tap item] --> EegStore.connectBle --> slot libre --> source.connect()
             ├── BLE: GATT client + subscribe notify --> parser ThinkGear --> EegData.applyCapture
             ├── SPP: canal nativo --> mismos pasos
             └── fallo --> slot liberado + excepción a la UI
[desconectar] --> source.disconnect --> slot = null
```

Sin datos personales: MAC se queda en memoria; nada viaja por red.
RGPD: no hay datos almacenados identificables (el progreso no vincula personas).

## 6. Flujos de datos end-to-end

1. **Adquisición**: notificación BLE fragmentada → state machine parser →
   captura completa + checksum OK → `EegData.applyCapture` (si poorSignal≥200
   → reset) → `notifyListeners`.
2. **Juego**: `MindGameSession._tick(dt)` → `SignalProcessor.sample` →
   `GameLogic.update` → score → fin → `ProgressController.record` →
   persist JSON.
3. **Analizador**: Timer 1 Hz lee slot → ventana de 30 puntos (line) o
   `bands` (bar).

## 7. Migraciones / versionado

JSON sin campo `version`: los parsers toleran ausencias (`?? 0`). Si se añade
campo, seguir la misma regla (default-safe), nunca rename sin shim.
