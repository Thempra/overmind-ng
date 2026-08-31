# Diseño: Fuente EEG SPP Classic (Bluetooth RFCOMM)

Fecha: 2026-09-01
Estado: aprobado

## Problema

El hardware real (ThempraEEG, MAC `00:12:02:10:71:49`) es un dispositivo
**Bluetooth Classic (BR/EDR, SPP sobre RFCOMM)** con chip ISSC. El port usa
`flutter_blue_plus`, que solo escanea BLE; un scan LE jamás lista un
dispositivo Classic-only (evidencia: `DevType=1`, vínculo `[BR/EDR]`, 0
anuncios LE en logcat, mientras el scan BLE de la app funcionaba con 395
resultados). El proyecto Android original (`AndroMindLib`) usaba SPP clásico.

`flutter_bluetooth_serial` (pub.dev) queda descartado: exige Dart `<3.0.0`
(2021), incompatible con Dart 3.13 del proyecto.

## Solución

Platform channel nativo propio + fuente `MindSource` nueva, reutilizando el
`ThinkGearParser` (los bytes SPP siguen el mismo protocolo ThinkGear).

### Arquitectura

```
BluetoothSocket RFCOMM (UUID SPP 00001101-0000-1000-8000-00805F9B34FB)
  → hilo lector Kotlin (MainActivity.kt)
    → EventChannel "overmind/spp/bytes"  {address, bytes}
      → SppMindSource (lib/src/ble/spp_mind_source.dart)
        → ThinkGearParser.addBytes → EegData → stream → juego
```

### Componentes

1. **Nativo (Kotlin, MainActivity.kt)**
   - MethodChannel `overmind/spp`:
     - `getDevices()` → vinculados con tipo CLASSIC o DUAL: `[{address, name}]`
     - `connect(address)` → secure RFCOMM + hilo lector; error `connect_failed`
       si el socket falla (timeout implícito del SO ~12 s)
     - `disconnect(address)` → cierra socket y hilo
   - EventChannel `overmind/spp/bytes`: emite `{address: String, bytes: Uint8}`
     por cada chunk leído; `onError`/`onDone` al caer el socket.
   - Requiere `BLUETOOTH_CONNECT` (ya concedido); sin cambios de manifest.

2. **`SppMindSource extends MindSource`** (`lib/src/ble/spp_mind_source.dart`)
   - Contrato idéntico a `NeuroSkyBle` (id=MAC, name, eeg, stream, connect,
     disconnect). Escucha el EventChannel filtrando por su MAC.
   - `connect()` completa cuando el socket conecta; los datos fluyen por
     `stream`. Sin writes (el stream ThinkGear arranca solo).

3. **`MindDevice`** (neurosky_ble.dart): gana `id`, `name`, `isClassic`;
   constructores `MindDevice.ble(...)` y `MindDevice.spp(...)`. La UI pasa a
   usar `d.name`/`d.id` (3 puntos de uso).

4. **`EegStore`**:
   - `loadBonded()` fusiona vinculados LE (FPB, excluyendo los Classic) +
     Classic (canal nativo)
   - `connectBle()` enruta: `isClassic` → `SppMindSource`, si no → `NeuroSkyBle`

5. **UI (settings_screen.dart)**: sin botones nuevos; la lista de "Vinculados"
   muestra los SPP con etiqueta «SPP» en lugar del RSSI.

### Descubrimiento

Solo dispositivos vinculados (decisión del usuario). Sin escaneo Classic.

### Errores

- Fallo de conexión SPP → `StateError` (mismo contrato que BLE)
- Caída del socket → cierre limpio del stream (los slots quedan como estén;
  el usuario desconecta manualmente)

### Alcance / límites

- Solo Android (`Platform.isAndroid`); iOS/Linux intactos
- Máximo 8 slots compartido con BLE/simulado (sin cambios)
- Sin reconexión automática (YAGNI)

## Verificación

1. Tests unitarios: enrutado `connectBle` (SPP vs BLE) con canal falseado;
   parseo de un frame ThinkGear entrante por SppMindSource.
2. `flutter analyze` + `flutter test`.
3. Verificación real: build → instalar en el Xiaomi → conectar ThempraEEG
   desde "Vinculados" → logcat demuestra socket + bytes entrantes.
