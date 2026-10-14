# Overmind — Documentos fundacionales

Índice de autoridad (single source of truth). Cada hecho vive en UN solo doc;
los demás solo lo referencian como "TRD §3", "flow §4", etc.

| Doc | Autoridad (qué define) |
|---|---|
| [prd.md](prd.md) | Qué y por qué: idea, funcionalidades, modos, catálogo de juegos, alcance in/out, preguntas abiertas |
| [trd.md](trd.md) | Stack, librerías y versiones, canales BLE/SPP, parser ThinkGear, hardware/pitfalls, recetas de build/test/deploy |
| [flow.md](flow.md) | Navegación completa + comportamiento exacto de cada botón/trigger |
| [design-brief.md](design-brief.md) | Tokens (paleta/tipo/spacing), inventario de componentes, aspecto de cada pantalla |
| [backend-schema.md](backend-schema.md) | Modelo de datos en runtime, persistencia local (KV), contrato de claves, flujo de dispositivos/señal end-to-end |
| [implementation-plan.md](implementation-plan.md) | Secuencia de fases + criterios de aceptación (Fase 1 = entregada; fase 2 = pendiente) |

Docs históricos del repo: `docs/DISENO_JUEGOS.md` (informe de diseño de la
plataforma de juegos mentales, sept-2026) sigue siendo la **autoridad del game
design** (TTK, tuning de daño, mecánicas de cada juego, primitivas de señal y
su justificación). Lo demás (stack, ingeniería, pantallas) es autoridad de
esta carpeta.

Regla de mantenimiento: cambiar un knob/endpoint/token ⇒ actualizar SOLO su doc
propietario y el código, en el mismo commit. Si un hecho aparece en dos docs,
el no-propietario pasa a ser una referencia tipo "TRD §5".

Mapa de tópicos → doc propietario: knobs de señal/tuning técnico → TRD §5 ·
game design/TTK → DISENO_JUEGOS · esquemas JSON y reglas de racha →
backend-schema §3 · criterios de éxito/aceptación → PRD §6 y plan (CA) ·
comportamiento de botones → flow §3 · colores/tokens → design-brief §1.
