# Overmind NG — Design Brief

Estética: **sci-fi oscuro estilo Evangelion HUD**, moderno y formal, sin
neón agresivo. Los acentos de color identifican bando/modo; los paneles se
delimitan por fondo propio + borde sutil, no por bordes gordos.

## 1. Paleta (tokens en `lib/src/theme.dart` → `OvermindColors`)

| Token | HEX | Uso |
|---|---|---|
| bg | `#0A0E16` | Fondo general |
| bgLighter | `#121A2B` | Botones filled |
| panel | `#171F33` | Tarjetas, paneles, toggle |
| panelBorder | `#24304D` | Bordes 1-1.2 px |
| evaCyan | `#35B6FF` | Acento jugador 1 / modo Jugador / primaria |
| sachielRed | `#FF4B4B` | Acento jugador 2 / modo Investigador / secundaria |
| shield | `#B0F7FF` | Iconos utilitarios (ajustes, demo, idioma) |
| yellow | `#FFE34D` | Destellos/avisos puntuales |
| text | `#E8EEF6` | Texto principal |
| textDim | `#9AA7BF` | Texto secundario |

Acentos de juego mental (por ficha): Globo `#FF6B9D`, Duelo `#B388FF`,
Halcón `#4FC3F7`. Analizadores conservan los colores heredados del original:
atención `#00C800`, meditación `#0000C8`, ondas `#9900CC`.

## 2. Tipografía y forma

- Fuente system (Roboto/SF); jerarquía por peso: títulos **w900** con
  `letterSpacing` 1.5-4, cuerpo w400-700.
- Wordmark **OVERMIND**: 30 px w900 ls 4, "MIND" en evaCyan, shadow cyan blur 16.
- Radios: 12 (botones), 14 (cards theme), 16-18 (cards grandes/toggle),
  círculo (icon-buttons 44 px).
- Glow: `BoxShadow(accent.withOpacity(0.25-0.3), blurRadius 18-20)` solo en
  elementos activos/seleccionados — nunca en reposo.

## 3. Componentes

- **ActionCard** (`widgets/action_card.dart`): icono en círculo tintado +
  título + subtítulo + acento; variantes `big`.
- **Mode toggle** (Home): píldora panel+borde, item activo = fondo
  accent@0.22 + texto accent w800.
- **Game card duelo**: foto de fondo cover + gradiente inferior opaco,
  luchadores enfrentados (82 px), borde `leftColor@0.7` + glow, nombre abajo.
- **Game card mental**: portada dibujada con el acento del juego + icono +
  nombre + subtítulo + ficha (señal, edad, 1P/2P).
- **Opción de modo** (ModeSelection): fila panel, activa = borde 2 px accent +
  glow + check_circle; icono 56 px en círculo accent@0.16.
- **Botones**: FilledButton bg `bgLighter` borde panelBorder texto w700 15 px
  (el tema); en overlay de resultados, filled del acento del juego.
- **Overlays de sesión**: calibración = negro@87 centrado (icono 48 accent,
  consigna 22 w800, barra 260 px accent, %); resultados = tarjeta `#10141C`
  radio 20 borde accent@0.7, marcador 56 w900.
- **Backdrop Home**: `game_background.jpg` al 28% + gradiente vertical
  `#E60A0E16 → bg`.

## 4. Pantallas (aspecto exacto)

1. **Home**: backdrop; header = wordmark izq., toggle centro-der, ⚙ der.;
   cuerpo = vista de modo con fade. Padding 28/14.
2. **PlayerModeView**: línea "Conectados: N" (textDim w700 ls1), "Selecciona
   juego" 22 w900, grid 3 col (≥680 px) / 2 col, ratio 1.05/0.78, gap 12.
3. **Battle**: fullscreen inmersivo; fondo del tema; 2 luchadores con aura
   (izq. cyan/EVA, der. rojo/SACHIEL o según tema); barras HP superiores con
   nombres del tema; VS banner 2.2 s; overlay fin = caja negra@75, ganador
   40 px, [Revancha] filled, [Salir] outlined.
4. **MindGameSession**: fondo `#0A0E16`; HUD superior (título accent ls2,
   contador `90s · pts`, Salir white54); overlays de fase según §3.
5. **ResearcherModeView**: 2 ActionCards big (cyan / rojo).
6. **DataAnalyzer**: LineChart 0-100, rejilla, sin títulos eje X, leyenda dots.
7. **LevelsMind**: barra señal (verde <100 / naranja), texto `n/200`,
   BarChart 11 barras 18 px radio sup 3, etiquetas 9 px.
8. **Settings**: AppBar transparente; entrada "Modo de juego" (fila panel
   16 radio, icono swap cyan); divider panelBorder; sección Bluetooth
   (icono+3 botones filled en fila + listas descubiertos/conectados con [x]);
   sección Idioma (toggle ES/EN).
9. **ModeSelection**: 2 filas-opción centradas, activa con glow + check.

## 5. Motion / audio

- Transiciones: fades cortos (180-250 ms); nada de parallax.
- SFX solo batalla: `pew_pew_lei.wav` disparo + golpe; volumen moderado.
- Feedback de recompensa tras criterio de señal: <1 s, no negociable
  (criterio de éxito: PRD §6; justificación: DISENO_JUEGOS §2).

## 6. Referencias visuales del repo

`docs/home_screen.png`, `home_researcher.png`, `game_screen.png`,
`settings_themes.png`, `superpoderes_battle.png`, `icon_preview.png`.
