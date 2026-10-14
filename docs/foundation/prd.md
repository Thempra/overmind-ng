# Overmind NG — PRD (Product Requirements Document)

Estado: **v1 — fiel al código entregado (Fase 1) + fase 2 planificada.**
Repo: `code.thempra.net/apps/overmind-ng` · App: `overmind` v1.0.0+1.

## 1. Resumen de la idea

Overmind es un juego **controlado por la mente** para Android/iOS/Linux,
port a Flutter del proyecto original `overmind-android` (Java + NeuroSky
MindWave). Cada jugador lleva un cascos EEG **NeuroSky MindWave Mobile 2**;
su atención y meditación en tiempo real mueven el juego. La experiencia
estrella es el **duelo 1v1** tipo fighting: dos luchadores se lanzan bolas de
fuego — la **atención** carga el ataque, la **meditación** sostiene el escudo.
Además es una **plataforma de juegos mentales** (calma, parpadeo, atención
sostenida) con capa de progreso (récords, puntos mentales, rachas) y un
**modo investigador** que visualiza la señal EEG cruda para analizar/validar.

## 2. Público y problema

- Jugadores locales 1v1 (amigos/familia, party game) y entrenamiento
  individual (6+ según juego).
- Investigadores/aficionados EEG que quieren ver atención/meditación/bandas
  en vivo sin escribir código.
- Problema que resuelve: el hardware MindWave suele venderse con demos
  rígidas; aquí la señal se convierte en juego competitivo con mecánicas
  diseñadas para la latencia real del dispositivo (ver `docs/DISENO_JUEGOS.md`).

## 3. Funcionalidades (enumeradas)

### 3.1 Conectividad EEG
- F1. Escaneo BLE de cascos MindWave y conexión (hasta **8 dispositivos** simultáneos en slots).
- F2. Lectura de dispositivos **ya vinculados**: BLE (LE) + Classic/SPP (solo Android), deduplicados por MAC.
- F3. Soporte de dos transportes: **BLE GATT** (MindWave Mobile 2) y **SPP/RFCOMM** (canal nativo Android).
- F4. **Modo demo/simulado**: fuente EEG sintética (random walk plausible) para jugar/analizar sin hardware y para desktop Linux.
- F5. Gestión de permisos (Bluetooth scan/connect, ubicación ≤SDK30) con error legible en UI.
- F6. Desconectar/liberar cualquier slot en caliente.

### 3.2 Modo Jugador (por defecto)
- F7. Catálogo en cuadrícula: **2 duelos temáticos** (Evangelion: EVA-01 vs SACHIEL; Superpoderes: ELSA vs RUMI) + **3 juegos mentales** (Globo, Duelo/seesaw, Halcón).
- F8. **Duelo 1v1 (battle)**: atención = velocidad/daño de bolas de fuego; meditación = escudo regenerador; HP compartido de barra; gana quien deja al rival a 0; tema visual seleccionable; revancha/salir al acabar.
- F9. **Juegos mentales** con scaffold común: calibración (5 s) → partida con duración fija → resultados con récord y racha:
  - **Globo** (meditación, umbral adaptativo, 90 s, 1P, 6+)
  - **Duelo/seesaw** (calma = med−atención, 2 cabezales, 90 s, 8+)
  - **Halcón** (parpadeo para derribar cometas, 90 s, 1P, 10+)
- F10. Asignación automática de slots: EEGs reales primero, rellena con demo si faltan.
- F11. **Capa meta persistente**: mejor puntuación por juego, puntos mentales
  totales (Σ), racha diaria con **congelador** (semántica y reglas: backend-schema §3).

### 3.3 Modo Investigador
- F12. **Analizador Atención/Meditación**: gráfica de línea en vivo (ventana 30 s).
- F13. **Niveles de Mente**: barra de calidad de señal + barras de 8 bandas EEG (delta, theta, low/high alpha, low/high beta, low/high gamma) con la normalización del proyecto original.
- F14. Selección de dispositivo automática (primero real conectado, si no demo).

### 3.4 Transversal
- F15. Selección de **modo de juego** (jugador/investigador) desde toggle del Home o desde Ajustes.
- F16. **Ajustes**: Bluetooth (escanear / vinculados / añadir demo, lista de descubiertos y conectados con desconexión), **idioma ES/EN** en toda la app, tema de partida.
- F17. Orientación **landscape forzosa** en toda la app; batalla a pantalla completa inmersiva.
- F18. SFX en la batalla (disparo/golpe) con degradado graceful si el audio falla.

## 4. Fuera de alcance (v1)

- Sin backend/nube, sin cuentas de usuario, sin ranking online (todo local; ver backend-schema §1).
- Sin exportación de datos EEG a ficheros (CSV) — el modo investigador es visual.
- Sin emparejamiento remoto entre dispositivos (el 1v1 es local, 1 tablet/PC + 2 cascos).
- Sin microtransacciones ni loot boxes (público infantil).

## 5. Fase 2 (aprobada en diseño, sin construir)

- Juegos: **Carrera Neural** (atención=acelerar, blink=carril, meditación=agarre) y **Jardín Interior** (paisaje reactivo a meditación + informe de cierre).
- Colección de avatares/desbloqueables y cofres con pity timer.
- Cifrado/estadísticas del modo investigador sobre los juegos (curvas de sesión).
- Estatua (anti-blink 2P) ya definida en diseño; pendiente de implementación si se prioriza.

## 6. Criterios de éxito

- Partida completa 2 jugadores reales sin caídas de conexión; TTK del duelo 60-90 s.
- Refuerzo visual <1 s tras cumplir el criterio de señal (regla de contingencia).
- Todo jugable de principio a fin en modo demo sin hardware (aceptación en CI/desktop).
- 0 permisos denegados sin mensaje entendible en pantalla.

## 7. Preguntas abiertas

- Q1: ¿Exportar sesión EEG a CSV en modo investigador (petición potencial de usuario)?
- Q2: ¿Racha basada en "puntos mentales" mínimos/día en vez de "≥1 partida"?
- Q3: ¿Segundo congelador comprable con puntos mentales (sin dinero real)?
