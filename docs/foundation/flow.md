# Overmind NG — Flow (fases, navegación, comportamiento por botón)

Rutas = Widgets de navegación (`MaterialPageRoute`). Autoridad de comportamiento
de botones: este doc.

## 1. Mapa de navegación

```
main → HomeScreen (siempre landscape)
 ├── [toggle Jugador|Investigador]  → cambia vista inline (AnimatedSwitcher)
 │    ├── PlayerModeView   (cuadrícula de juegos)
 │    │    ├── (tap card duelo)      → GameScreen(p1,p2)      [FLAME battle]
 │    │    └── (tap card mental)      → MentalGameScreen(game) → MindGameSession
 │    └── ResearcherModeView
 │         ├── (tap "Atención/Meditación") → DataAnalyzerScreen(slot)
 │         └── (tap "Niveles de Mente")    → LevelsMindScreen(slot)
 └── [⚙ Ajustes] → SettingsScreen
      ├── [Modo de juego] → ModeSelectionScreen (elegir → pop a Home)
      ├── Bluetooth: [Escanear] [Vinculados] [Añadir demo]
      │    ├── lista descubiertos: tap = conectar
      │    └── lista conectados: [x] = desconectar slot
      └── Idioma: [ES|EN] toggle
```

## 2. Fases de la app

1. **Arranque** (`main.dart`): fijar landscape → crear `EegStore` (init con
   `isBleSupported`) → cargar tema de batalla y progreso persistentes →
   MultiProvider (EegStore, ModeController, LocaleController,
   BattleThemeController, ProgressController) → HomeScreen.
2. **Conexión** (opcional, Ajustes): escanear/vinculados/demo → slots.
3. **Juego** (batalla o mental) — ver §4.
4. **Análisis** (modo investigador).

## 3. Comportamiento botón a botón

### Home
- **Toggle Jugador/Investigador**: set `ModeController.mode`; la vista central
  se intercambia con fade 250 ms. No navega. Persistencia: ninguna (por sesión).
- **⚙ (icono circular)**: push `SettingsScreen`.

### PlayerModeView (modo jugador)
- Cabecera: `Conectados: N` (tiempo real) + título "Selecciona juego".
- **Card de duelo (Evangelion / Superpoderes)**:
  1. `BattleThemeController.setTheme(tema)` (persiste elección).
  2. Resuelve 2 slots: reales primero, rellena con `addSimulated()`.
  3. push `GameScreen(player1Slot, player2Slot)`.
  Si no hay 2 slots libres → no abre (no-op silencioso).
- **Card de juego mental (Globo/Duelo/Halcón)**: igual pero 1 slot (2 si
  `needs2`), push `MentalGameScreen`.

### GameScreen (duelo FLAME)
- initState: landscape + `immersiveSticky`; crea `BattleGame` con el tema activo.
- **VS banner** 2.2 s al inicio; luego combate.
- Reglas: atención → cadencia/daño de bolas de fuego; meditación → escudo
  regenerador; HP 0 → fin. (Daño/TTK: DISENO_JUEGOS §3.A.)
- Overlay fin: ganador grande + **[Revancha]** (`game.restart()`, misma
  partida reset) + **[Salir]** (pop a Home).
- dispose: restaura orientación y UI system.

### MindGameSession (scaffold de juego mental)
1. **Calibración** (5 s): overlay negro con consigna del juego
   (p.ej. Globo: "Relájate 5 s…"), barra de progreso %, acumula baseline.
2. **Juego** (durationSec del catálogo, 90 s): HUD superior = título (acento),
   `Xs · score`, **[Salir]** (pop inmediato). Lógica del juego corre con
   señales filtradas (TRD §5).
3. **Resultados**: overlay con `¡NUEVO RÉCORD!` o `FIN`, puntuación,
   `récord · racha`, **[Revancha]** → reinicia fase calibración con calibrador
   limpio; **[Salir]** → pop.
- `ProgressController.record(gameId, score)` suma puntos mentales y toca racha.

### ResearcherModeView
- **Card "Atención/Meditación"**: `_anySlot()` (primero conectado real, si no
  añade demo) → push `DataAnalyzerScreen(slot)`: line-chart ventana 30 s,
  muestreo 1 Hz, colores de serie según design-brief §1.
- **Card "Niveles de Mente"**: push `LevelsMindScreen(slot)`: barra poorSignal
  (0=buena, /200) + bar-chart de 11 valores (Signal, Att, Med + 8 bandas).
- Ambos: **[←]** AppBar pop.

### SettingsScreen
- **[Escanear BLE]**: `store.scanBle()`; botón pasa a spinner "Escaneando…";
  resultados en vivo en la lista. Vacío → SnackBar con `permissionError` si
  hubo fallo de permisos, si no "sin dispositivos".
- **[Vinculados]**: `store.loadBonded()` (LE + SPP dedupe); error → SnackBar.
- **[Añadir demo]**: `store.addSimulated()` en primer slot libre.
- **Item descubierto**: tap → `connectBle(d)`; spinner en el item; fallo →
  SnackBar "Conexión fallada: …". Slot ocupado hasta desconexión.
- **Item conectado [x]**: `removeAt(slot)` (desconecta y libera).
- **[Modo de juego]**: push `ModeSelectionScreen`; tap opción → set mode + pop
  (la opción activa se marca con check y borde de acento).
- **[ES|EN]**: `LocaleController.locale` — re-textualiza toda la app al instante.

## 4. Sesión de juego EEG

Pipeline de datos: backend-schema §6.2. Primitivas y knobs (EMA, calibrador,
DDA, histeresis): TRD §5. Este doc solo fija cuándo se muestran las fases al
usuario (calibración → juego → resultados, §3).

## 5. Errores de usuario y recuperaciones

| Caso | Comportamiento |
|---|---|
| Sin permisos BLE | SnackBar con texto explicativo; escaneo abortado |
| Cascos < slots necesarios | El juego no arranca; slots faltantes se rellenan con demo (nunca bloqueo) |
| Conexión BLE falla | Slot se libera, SnackBar con el error crudo |
| poorSignal ≥200 | EegData.reset() → 0s en analizador; juego sigue con última EMA |
| Audio no disponible | `_audioOk=false`, batalla sin SFX |
