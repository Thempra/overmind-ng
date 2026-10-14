# Overmind NG — Plan de Implementación

Fase 1 está **entregada** (commit actual de `main`); se documenta como
registro verificable. Fase 2+ es la secuencia a seguir. Cada paso con
criterio de aceptación (CA) comprobable.

## Fase 1 — Núcleo + plataforma de juegos mentales ✅ (entregada)

| # | Paso | CA |
|---|---|---|
| 1.1 | Scaffold Flutter multiplataforma, landscape, tema oscuro, permisos BLE | `flutter run -d linux` arranca; analyze limpio |
| 1.2 | Parser ThinkGear state-machine + `EegData` | Tests: frame fragmentado, checksum malo descartado, bandas proc ✔ |
| 1.3 | `MindSource` + `SimulatedMindSource` | Demo genera capturas ~1 Hz sin hardware ✔ |
| 1.4 | `NeuroSkyBle` (scan/bonded/connect/notify) + permisos | Cascos reales aparecen en scan y conectan ✔ |
| 1.5 | SPP nativo Android (`overmind/spp`) + merge bonded | Cascos clásicos vinculados se listan y conectan ✔ |
| 1.6 | `EegStore` (8 slots, demo, desconexión) + providers | Tests de store ✔ |
| 1.7 | Home con toggle Jugador/Investigador + Ajustes + ES/EN | Toggle cambia vista; idioma re-textualiza ✔ |
| 1.8 | Analizadores (DataAnalyzer, LevelsMind) port del original | Gráficas en vivo 1 Hz ✔ |
| 1.9 | Batalla FLAME 1v1 (temas EVA/Superpoderes, HP, escudo, SFX, game over) | Partida 2 jugadores/demo hasta ganador ✔ |
| 1.10 | `SignalProcessor`/`Calibrator`/`AdaptiveThreshold`/`Hysteresis` | Tests fake_async ✔ |
| 1.11 | Scaffold `MindGameSession` + catálogo + Globo/Duelo/Halcón | Flujo calibrar→jugar→resultados con récord ✔ |
| 1.12 | `ProgressController` (récords, MP, racha+congelador) | Tests de racha con gaps ✔ |
| 1.13 | Documentación DISENO_JUEGOS + docs screenshots | Presentes en `docs/` ✔ |

## Fase 1.5 — Hardening (pendiente, prioridad alta)

| # | Paso | CA |
|---|---|---|
| 1.5.1 | Persistir idioma elegido (backend-schema §1) | Reiniciar app mantiene ES/EN |
| 1.5.2 | Puntuar duelos temáticos en `progress.json` (`best['battle:<tema>']`) | Revanchas actualizan récord visible en resultados |
| 1.5.3 | i18n completa de textos hardcodeados ("Análisis —", "Niveles de Mente —", overlay de batalla) | Toggle EN cambia TODAS las cadenas visibles |
| 1.5.4 | Medidor de señal visible en juego (meterValue ya en contrato) + aviso poorSignal sostenido >3 s en HUD | El jugador ve cuándo pierde contacto |
| 1.5.5 | CI Forgejo: analyze + test en pipeline | Pipeline verde en PR; imagen Flutter 3.47 (TRD §1) |
| 1.5.6 | Versionado automático: build Number en CI + CHANGELOG | APK entregable con `version+build` creíble |

## Fase 2 — Contenido (orden por dependencias)

| # | Paso | CA |
|---|---|---|
| 2.1 | **Estatua** (anti-blink, 2P, rondas 60 s mejor de 3) — reusa scaffold | Partida 2 slots hasta 3 fallos; récord `best['statue']` |
| 2.2 | **Carrera Neural** (att=acelerar, blink=carril, med=agarre) | 90 s, DDA de curvas, récord |
| 2.3 | **Jardín Interior** (meditación → clima/sonido + informe cierre) | Informe post-sesión con media/σ del Calibrator |
| 2.4 | Cofres con pity timer + colección de avatares (sin dinero real) | Cada N pops/puntos → cofre; colección visible en Home |
| 2.5 | Capa sesión-analítica: curva att/med de la partida exportable (CSV) *(decidir: PRD Q1)* | Archivo CSV legible en storage; compartir desde Android |
| 2.6 | Pruebas de usuario niños 6-10 → ajuste de edades/consignas del catálogo | Documento de pruebas con 3 sesiones reales |

## Reglas de ejecución

- Construir estrictamente en orden; si la realidad fuerza un cambio, actualizar
  el doc afectado en el MISMO commit (skill foundation-docs).
- Tras cada paso: `flutter analyze && flutter test` en verde antes de pushear
  a `origin/main` (Forgejo).
- Release APK solo bajo petición, con recipe de TRD §8 y enlace gofile.
- Firmado/keystore: mantener `key.properties` local del repo Android, nunca en
  git (secreto).
