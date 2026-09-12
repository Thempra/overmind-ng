# OVERMIND — Plataforma de juegos mentales: informe de diseño

_Fuente: 3 informes de investigación (mecánicas de juegos EEG reales, teoría de
engagement, características de señal MindWave) + deducción propia. Septiembre 2026._

## 1. Por qué el juego actual engancha poco

1. **TTK (tiempo hasta matar) de ~15-25 s**: la partida muere antes de que el
   bucle de anticipación se active. La dopamina se genera en la *anticipación*
   de la recompensa, no en la recompensa (compulsion loop).
2. **Recompensa determinista y lineal** (más atención → más bola): sin
   imprevisibilidad ni progresión, no hay loop medio (partida→premio) ni largo
   (temporada→colección).
3. **Sin capa meta**: nada que hacer volver a buscar mañana (rachas, récords,
   desbloqueables).
4. **Mala contingencia**: premiar el cruce instantáneo de umbral con una señal
   de 1 Hz con rampas de 3-8 s genera refuerzo ruidoso; el condicionamiento
   operante exige criterio sostenido (≥2 s) + histéresis.

## 2. Primitivas de control disponibles (señales reales)

| Señal | Latencia | Naturaleza | Uso de diseño |
|---|---|---|---|
| Atención (0-100) | 1-2 s, rampas 3-8 s | continua, lenta, deriva ±10-20 | potencia/altura/velocidad sostenida |
| Meditación (0-100) | igual, anti-correlada con atención | continua | calma/escudo/gating |
| **Blink** (0xD5/0xD7) | 0,4-1,3 s | **discreto, fiable, refractario ~1 s** | acción/disparo/pulso — la señal más fiable del dispositivo |
| poorSignal | ~1 s | gate | "mantén el contacto" / pausa |
| Bandas θ/α/β/γ | 1 s | compuestas | modos especiales (fase 2) |

Reglas de oro (evidencia): refuerzo visual/sonoro <1 s del criterio; criterio
sostenido ≥2 s con histéresis (55/45); EMA α≈0,3; jamás exigir atención y
meditación altas a la vez (son casi razones inversas); pausa automática si
poorSignal>190 durante 3 s; penalizar "esforzarse mal" (apretar mandíbula =
falsa atención) diseñando para **atención relajada** (potencia ∝ att × calma).

## 3. Catálogo de juegos (por edad y bucle)

Todos comparten: sesión = calibración (5 s) → 1-3 min de juego → pantalla de
resultados con récord/rachas. Sesión total 10-15 min (<10 años), 2×15 (mayores).

### A. DUELO (existente, retocado) — 8+
- 2 jugadores EEG (o demo). Atención=ataque, meditación=escudo, **parpadeo=escudo de emergencia** (única acción instantánea; refractario 2 s).
- Cambios: HP 100→260, daño comprimido, TTK objetivo 60-90 s. Temas Evangelion/Superpoderes.
- Antecedentes: Mindball, meditation-deathmatch, duelo seesaw validado científicamente (PMID 35882224).

### B. GLOBOS ZEN — 6+ (meditación)
- El globo crece mientras mantienes la calma **sobre un umbral adaptativo**
  (baseline+σ; baja si fracisas, sube si aciertas >75% — flow).
- Globo lleno = POP + partículas + sonido (micro-recompensa <1 s). Cada 5 pops,
  cofre con bonus. **Parpadeo = aguja** (pop instantáneo de bonus).
- Es el protocolo clínico de globos convertido en arcade. Antecedente: MindBalloon (Emotiv), MindLight (RCT con +adherencia que TCC online).

### C. LEVITA — 8+ (atención + blink)
- Orbe levitando tipo Mindflex: **atención = altura**. Anillos aparecen a la
  derecha; atravesarlos = punto. Los anillos se colocan según tu baseline
  (DDA). **Parpadeo = impulso ascendente (dash)**.
- 90 s, récords por tema. Antecedentes: Force Trainer/Mindflex (juguetes EEG de mayor éxito comercial), neuro_drive (atención=acelerar, blink=cambiar de carril).

### D. ESTATUA — todas las edades (parpadeo, anti-blink)
- **No parpadees**. Cada parpadeo = -1 vida (3 vidas). Ojos cerrados = trampa
  bloqueada: si tu atención cae bajo un suelo, también pierdes vida.
- Duelo local 2 cabezales (o vs demo que parpadea a su ritmo). Rondas de 60 s,
  mejor de 3. El party game más barato de producir y el más tenso.
- Antecedentes: staring contests EEG (giuliatondin/unity-mindwave-runner et al.).

### E. CARRERA NEURAL — 10+ (fase 2)
- Atención = acelerar; parpadeo = cambiar de carril; meditación = agarre en
  curvas. Duelo 2P. (Mapeo exacto de aki202/neuro_drive.)

### F. JARDÍN INTERIOR — todas (fase 2, modo calma/Muse)
- Paisaje sonoro/visual reactivo a la meditación (clima = estado mental).
  Cierre de sesión relajante + informe. Coleccionable: plantas desbloqueadas.

## 4. Capa meta (engagement largo)

- **Rachas diarias con congelador** (la señal varía por sueño/cafeína: no perder racha por un mal día).
- **Récord por juego + total de "puntos mentales"** (Σ de todas las sesiones).
- 3 bucles anidados: acción (2-5 s) → sesión (3 min) → meta (días/semanas).
- Octalysis: Feedback (la barra cerebral es el juguete), Social (duelo local), Loss avoidance (racha), Ownership (colección fase 2), Unpredictability (cofres con pity timer, sin loot boxes agresivas — público infantil).

## 5. Implementación (Fase 1 = esta entrega)

- `game/signal_processor.dart` — EMA, histéresis, criterio sostenido, umbral adaptativo (DDA), debounce de blink, calibrador de baseline.
- `state/progress_controller.dart` — récords + racha persistente.
- `games/` — scaffold de sesión (calibración → juego → resultados) + Globos Zen + Levita + Estatua (2P) + catálogo de juegos.
- `battle_game.dart` — retune TTK (HP 260, daño comprimido, blink = escudo de emergencia).
- Home: el selector muestra el catálogo completo (2 duelos temáticos + 3 juegos nuevos).

Fase 2: Carrera neural, Jardín interior, colección de avatares, cofres, modo investigador sobre estos juegos.
