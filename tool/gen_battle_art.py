#!/usr/bin/env python3
"""Arte generativo determinista del duelo de Overmind NG.

Genera, sin ninguna dependencia externa (solo math/struct/zlib de la stdlib) y
sin modelos generativos de ningun tipo, los 6 assets de batalla del juego:

    assets/images/fighter_vector.png   512x704  RGBA  luchador AZUL  (tema neon, izq.)
    assets/images/fighter_orbe.png     512x704  RGBA  luchador ROJO  (tema neon, der.)
    assets/images/fighter_prisma.png   512x704  RGBA  luchador AMBAR (tema cosmico, izq.)
    assets/images/fighter_nebula.png   512x704  RGBA  luchador VIOLETA (tema cosmico, der.)
    assets/images/bg_neon.png         1080x1920 RGBA  fondo tema neon
    assets/images/bg_cosmico.png      1080x1920 RGBA  fondo tema cosmico
    docs/battle_art_preview.png       1080x1920 RGB   composicion de portada (web)

Uso (desde la raiz del repo):

    python3 tool/gen_battle_art.py all            # regenera todo
    python3 tool/gen_battle_art.py vector         # un asset suelto
    python3 tool/gen_battle_art.py orbe prisma nebula
    python3 tool/gen_battle_art.py bg-neon bg-cosmico preview

Es determinista: no usa random ni reloj. Dos ejecuciones producen bytes
identicos (mismo md5). La "aleatoriedad" (estrellas, ruido de nebulosa) sale
de un LCG con semilla fija y de un hash entero, nunca de `random`.

Metodo: geometria descrita en coordenadas normalizadas (0..1) y rasterizada
por muestreo con supersampling (SS, ver abajo) sobre campos de distancia con
signo (SDF) en espacio de pixeles. De un SDF se obtiene a la vez cobertura
antialias y luz de borde (rim light) midiendo -d, que es lo que da el acabado
"silueta recortada" del design brief.
"""
import math
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG_DIR = os.path.join(ROOT, "assets", "images")
DOCS_DIR = os.path.join(ROOT, "docs")

# Muestras por eje y pixel. 2 => 4 muestras/px: suficiente porque la silueta es
# un SDF (borde suave por distancia) y a 2x el grano ya no se ve a tamano movil.
SS = 2

# ---------------------------------------------------------------------------
#  Paleta declarada (tuplas). Nada de nombres de terceros: son colores propios.
# ---------------------------------------------------------------------------
NAVY_DEEP = (0x05, 0x07, 0x0E)
NAVY = (0x0A, 0x0E, 0x16)
NAVY_LIFT = (0x12, 0x1A, 0x2B)
STEEL = (0x24, 0x30, 0x4D)

CYAN = (0x35, 0xB6, 0xFF)
CYAN_HOT = (0xD8, 0xF7, 0xFF)
CYAN_DARK = (0x08, 0x2A, 0x47)

RED = (0xFF, 0x4B, 0x4B)
RED_HOT = (0xFF, 0xE0, 0xD8)
RED_DARK = (0x38, 0x08, 0x10)

# Antes AMBER (dorado): el luchador dorado de cuerpo entero leia como C-3PO.
# Ahora TEAL: mismo rol de "cristal facetado" pero sin referente reconocible.
AMBER = (0x3D, 0xD6, 0xC4)
AMBER_HOT = (0xDF, 0xFF, 0xFB)
AMBER_DARK = (0x04, 0x2E, 0x2B)

# Antes VIOLET (purpura): con antenas en la cabeza leia como EVA-01. Un purpura
# con hombreras y picos es la silueta de la franquicia; se pasa a INDIGO acero.
VIOLET = (0x6E, 0x8C, 0xD8)
VIOLET_HOT = (0xE6, 0xEF, 0xFF)
VIOLET_DARK = (0x0A, 0x14, 0x2E)
MAGENTA = (0x7F, 0xC8, 0xFF)   # acento del luchador violeta: tira a rosa para
                              # no confundirse con la nebulosa del fondo


# ---------------------------------------------------------------------------
#  Utilidades de color / mezcla
# ---------------------------------------------------------------------------
def mix(a, b, t):
    """Interpolacion lineal de dos colores (tuplas RGB) con t en 0..1."""
    if t < 0.0:
        t = 0.0
    elif t > 1.0:
        t = 1.0
    return (a[0] + (b[0] - a[0]) * t,
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t)


def clamp01(x):
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)


def smoothstep(e0, e1, x):
    if e1 == e0:
        return 0.0 if x < e0 else 1.0
    t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def lcg(seed):
    """Generador congruencial lineal: aleatoriedad reproducible sin `random`."""
    s = seed & 0xFFFFFFFF

    def nxt():
        nonlocal s
        s = (1664525 * s + 1013904223) & 0xFFFFFFFF
        return s / 4294967296.0

    return nxt


def ihash(x, y, salt=0):
    """Hash entero barato y estable -> 0..1 (para ruido de valor)."""
    h = (x * 374761393 + y * 668265263 + salt * 2147483647) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFFFF) / 16777216.0


# ---------------------------------------------------------------------------
#  Campos de distancia con signo (SDF), en pixeles
# ---------------------------------------------------------------------------
def sd_circle(px, py, cx, cy, r):
    return math.hypot(px - cx, py - cy) - r


def sd_poly(px, py, vs):
    """Distancia con signo a un poligono (negativa dentro). Coste O(n)."""
    n = len(vs)
    d2 = 1e18
    inside = False
    jx, jy = vs[-1]
    for i in range(n):
        ix, iy = vs[i]
        ex = jx - ix
        ey = jy - iy
        wx = px - ix
        wy = py - iy
        ee = ex * ex + ey * ey
        t = 0.0 if ee == 0.0 else (wx * ex + wy * ey) / ee
        if t < 0.0:
            t = 0.0
        elif t > 1.0:
            t = 1.0
        bx = wx - t * ex
        by = wy - t * ey
        dd = bx * bx + by * by
        if dd < d2:
            d2 = dd
        if ((iy > py) != (jy > py)) and (px < (jx - ix) * (py - iy) / (jy - iy) + ix):
            inside = not inside
        jx, jy = ix, iy
    d = math.sqrt(d2)
    return -d if inside else d


def sd_ellipse_ring(px, py, cx, cy, a, b, ang, thick):
    """Anillo eliptico (a, b = semiejes, ang en rad, thick = grosor)."""
    ca = math.cos(-ang)
    sa = math.sin(-ang)
    x = (px - cx) * ca - (py - cy) * sa
    y = (px - cx) * sa + (py - cy) * ca
    r = math.hypot(x / a, y / b)
    return abs(r - 1.0) * min(a, b) - thick * 0.5


def sd_segment(px, py, x0, y0, x1, y1, w):
    """Segmento de grosor w (ideal para trazos/ribetes)."""
    ex = x1 - x0
    ey = y1 - y0
    ee = ex * ex + ey * ey
    t = 0.0 if ee == 0.0 else clamp01(((px - x0) * ex + (py - y0) * ey) / ee)
    return math.hypot(px - (x0 + t * ex), py - (y0 + t * ey)) - w * 0.5


def taper(p0, p1, w0, w1):
    """Quad tapering de p0(w0) a p1(w1): el bloque constructivo de brazos/piernas."""
    x0, y0 = p0
    x1, y1 = p1
    dx = x1 - x0
    dy = y1 - y0
    ln = math.hypot(dx, dy) or 1.0
    nx = -dy / ln
    ny = dx / ln
    return [
        (x0 + nx * w0 * 0.5, y0 + ny * w0 * 0.5),
        (x1 + nx * w1 * 0.5, y1 + ny * w1 * 0.5),
        (x1 - nx * w1 * 0.5, y1 - ny * w1 * 0.5),
        (x0 - nx * w0 * 0.5, y0 - ny * w0 * 0.5),
    ]


def kite(cx, cy, hw, hh, top=0.0):
    """Rombo/cristal: hw media anchura, hh media altura, top desplaza el vertice."""
    return [(cx, cy - hh + top), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]


def norm(pts, W, H):
    """Convierte vertices normalizados (0..1) a pixeles del lienzo."""
    return [(x * W, y * H) for (x, y) in pts]


def rot_pts(pts, cx, cy, ang):
    ca = math.cos(ang)
    sa = math.sin(ang)
    return [(cx + (x - cx) * ca - (y - cy) * sa,
             cy + (x - cx) * sa + (y - cy) * ca) for (x, y) in pts]


# ---------------------------------------------------------------------------
#  Motor de rasterizado de un luchador
# ---------------------------------------------------------------------------
class Layer:
    """Una capa de la silueta: SDF + color (constante o gradiente vertical)."""

    def __init__(self, sd, bbox, col_a, col_b=None, rim=None, rim_w=3.0,
                 rim_k=0.9, alpha=1.0, y0=0.0, y1=1.0):
        self.sd = sd
        self.bbox = bbox          # (x0, y0, x1, y1) en pixeles
        self.col_a = col_a
        self.col_b = col_b        # si existe, gradiente vertical de a->b
        self.rim = rim
        self.rim_w = rim_w
        self.rim_k = rim_k
        self.alpha = alpha
        self.y0 = y0
        self.y1 = y1


def render_layers(W, H, layers, ss=SS):
    """Rasteriza la pila de capas a RGBA con supersampling y rim light."""
    out = bytearray(W * H * 4)
    inv = 1.0 / (ss * ss)
    # bbox global
    gx0 = min(l.bbox[0] for l in layers)
    gy0 = min(l.bbox[1] for l in layers)
    gx1 = max(l.bbox[2] for l in layers)
    gy1 = max(l.bbox[3] for l in layers)
    ix0 = max(0, int(gx0) - 2)
    iy0 = max(0, int(gy0) - 2)
    ix1 = min(W, int(gx1) + 3)
    iy1 = min(H, int(gy1) + 3)

    for y in range(iy0, iy1):
        row = y * W * 4
        for x in range(ix0, ix1):
            ar = ag = ab = aa = 0.0
            for sy in range(ss):
                py = y + (sy + 0.5) / ss
                for sx in range(ss):
                    px = x + (sx + 0.5) / ss
                    pr = pg = pb = pa = 0.0   # premultiplicado
                    hit = False
                    for L in layers:
                        bx0, by0, bx1, by1 = L.bbox
                        if px < bx0 or px > bx1 or py < by0 or py > by1:
                            continue
                        d = L.sd(px, py)
                        if d > 1.2:
                            continue
                        cov = clamp01(0.5 - d)
                        if cov <= 0.0:
                            continue
                        hit = True
                        # color de la capa: constante o gradiente vertical
                        if L.col_b is None:
                            cr, cg, cb = L.col_a
                        else:
                            t = clamp01((py - L.y0) / (L.y1 - L.y0))
                            c = mix(L.col_a, L.col_b, t)
                            cr, cg, cb = c
                        # rim light: borde interior iluminado
                        if L.rim is not None and d < 0.0:
                            k = (1.0 - clamp01(-d / L.rim_w)) * L.rim_k
                            if k > 0.0:
                                cr = cr + (L.rim[0] - cr) * k
                                cg = cg + (L.rim[1] - cg) * k
                                cb = cb + (L.rim[2] - cb) * k
                        a = cov * L.alpha
                        # over premultiplicado
                        pr = cr * a + pr * (1.0 - a)
                        pg = cg * a + pg * (1.0 - a)
                        pb = cb * a + pb * (1.0 - a)
                        pa = a + pa * (1.0 - a)
                    if hit:
                        ar += pr
                        ag += pg
                        ab += pb
                        aa += pa
            if aa <= 0.0:
                continue
            # des-premultiplizar y escribir (clamp a 255)
            r = ar * inv / (aa * inv)
            g = ag * inv / (aa * inv)
            b = ab * inv / (aa * inv)
            a = aa * inv
            o = row + x * 4
            out[o] = 0 if r < 0 else (255 if r > 255 else int(r + 0.5))
            out[o + 1] = 0 if g < 0 else (255 if g > 255 else int(g + 0.5))
            out[o + 2] = 0 if b < 0 else (255 if b > 255 else int(b + 0.5))
            out[o + 3] = 0 if a < 0 else (255 if a > 1 else int(a * 255 + 0.5))
    return out


def additive_glow(px, py, cx, cy, rad, col, strength=1.0, falloff=2.0):
    """Halo radial aditivo -> (dr, dg, db, peso) o None."""
    d = math.hypot(px - cx, py - cy)
    if d >= rad:
        return None
    k = (1.0 - d / rad) ** falloff * strength
    return (col[0] * k, col[1] * k, col[2] * k, k)


def add_glow_png(buf, W, H, cx, cy, rad, col, strength=1.0, falloff=2.0):
    """Suma un halo aditivo sobre un buffer RGBA/RGB ya renderizado."""
    x0 = max(0, int(cx - rad))
    x1 = min(W, int(cx + rad) + 1)
    y0 = max(0, int(cy - rad))
    y1 = min(H, int(cy + rad) + 1)
    for y in range(y0, y1):
        for x in range(x0, x1):
            g = additive_glow(x + 0.5, y + 0.5, cx, cy, rad, col, strength, falloff)
            if g is None:
                continue
            o = (y * W + x) * 4
            r = buf[o] + g[0]
            gg = buf[o + 1] + g[1]
            b = buf[o + 2] + g[2]
            buf[o] = 255 if r > 255 else int(r)
            buf[o + 1] = 255 if gg > 255 else int(gg)
            buf[o + 2] = 255 if b > 255 else int(b)
            if buf[o + 3] < 255:
                a = min(255.0, buf[o + 3] + g[3] * 255.0)
                buf[o + 3] = int(a)


# ---------------------------------------------------------------------------
#  Luchadores
# ---------------------------------------------------------------------------
FW, FH = 512, 704


def add_silhouette_halo(buf, W, H, col, width=7, strength=0.55):
    """Halo exterior alrededor de la silueta (alpha difuminado, por detras).

    El rim light interior separa las piezas entre si, pero a tamano movil el
    contorno exterior se fundia con fondos del mismo tono. Esto difumina el
    canal alpha y lo usa como mascara: el halo cae SOLO fuera de la figura.
    """
    alpha = [buf[(y * W + x) * 4 + 3] / 255.0 for y in range(H) for x in range(W)]
    # blur de caja separable, dos pasadas: kernel gaussiano aproximado
    def box(src, r):
        tmp = [0.0] * (W * H)
        for y in range(H):
            row = y * W
            acc = 0.0
            for x in range(W):
                acc += src[row + x]
                if x - r - 1 >= 0:
                    acc -= src[row + x - r - 1]
                lo = 0 if x - r < 0 else x - r
                tmp[row + x] = acc / (x - lo + 1)
        out = [0.0] * (W * H)
        for x in range(W):
            acc = 0.0
            for y in range(H):
                acc += tmp[y * W + x]
                if y - r - 1 >= 0:
                    acc -= tmp[(y - r - 1) * W + x]
                lo = 0 if y - r < 0 else y - r
                out[y * W + x] = acc / (y - lo + 1)
        return out

    blur = box(box(alpha, width), width)
    for i in range(W * H):
        a = alpha[i]
        if a > 0.92:
            continue
        g = blur[i] * (1.0 - a)
        if g <= 0.004:
            continue
        k = g * strength
        o = i * 4
        buf[o] = min(255, int(buf[o] + col[0] * k))
        buf[o + 1] = min(255, int(buf[o + 1] + col[1] * k))
        buf[o + 2] = min(255, int(buf[o + 2] + col[2] * k))
        buf[o + 3] = max(buf[o + 3], min(255, int(255 * a + 210 * g)))


RIM_SCALE = 1.7  # el rim se calcula a 512-704 px; en movil el sprite baja a
                 # ~1/3 y un borde de 3 px se pierde. Escalado, el contorno
                 # sobrevive al reescalado y separa la figura del fondo.


def _poly_layer(L, pts, ca, cb=None, rim=None, rw=3.0, rk=0.7, alpha=1.0, pad=3.0):
    """Anade a L una capa poligonal a partir de vertices YA en pixeles."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    y0 = min(ys)
    y1 = max(ys)
    if y1 - y0 < 1.0:
        y1 = y0 + 1.0
    L.append(Layer(lambda px, py, _p=pts: sd_poly(px, py, _p),
                   (min(xs) - pad, y0 - pad, max(xs) + pad, y1 + pad),
                   ca, cb, rim=rim, rim_w=rw * RIM_SCALE, rim_k=rk,
                   alpha=alpha, y0=y0, y1=y1))


def _limb(L, p0, p1, w0, w1, ca, cb, rim, rw, rk, alpha=1.0):
    _poly_layer(L, taper(p0, p1, w0, w1), ca, cb, rim=rim, rw=rw, rk=rk,
                alpha=alpha, pad=2.0)


def _ellipse_pts(cx, cy, a, b, n=30, ang=0.0):
    pts = [(cx + math.cos(k * 2 * math.pi / n) * a,
            cy + math.sin(k * 2 * math.pi / n) * b) for k in range(n)]
    return rot_pts(pts, cx, cy, ang) if ang else pts


# Proporciones comunes (fracciones del lienzo). Todas las siluetas comparten
# esqueleto para que el VS se lea como "dos luchadores", no como dos objetos.
_HEAD_Y = 0.130
_SHOULDER_Y = 0.250
_HIP_Y = 0.545
_KNEE_Y = 0.760
_FOOT_Y = 0.975
_SHOULDER_X = 0.170
_HIP_X = 0.080


def _skeleton(W, H, pal, style):
    """Piernas, torso, brazos y cabeza segun `style`.

    Devuelve la lista de capas. `style` en {"plates", "facet", "organic",
    "orb"} cambia SOLO la construccion geometrica de cada pieza: el esqueleto
    (donde esta cada cosa) es el mismo, y de ahi que los cuatro se lean como
    luchadores enfrentados.
    """
    L = []
    main, dark, deep, hot = pal["main"], pal["mid"], pal["dark"], pal["hot"]

    # ---------- piernas ----------
    for sgn in (-1, 1):
        hip = ((0.5 + _HIP_X * sgn) * W, _HIP_Y * H)
        knee = ((0.5 + 0.098 * sgn) * W, _KNEE_Y * H)
        foot = ((0.5 + 0.115 * sgn) * W, _FOOT_Y * H)
        if style == "organic":
            # muslo y gemelo como capsulas redondeadas, sin rodilla marcada
            _limb(L, hip, knee, 0.115 * W, 0.092 * W, main, dark, hot, 3.0, 0.65, 0.95)
            _limb(L, knee, foot, 0.092 * W, 0.070 * W, main, deep, hot, 2.6, 0.55, 0.95)
        else:
            _limb(L, hip, knee, 0.098 * W, 0.066 * W, main, dark, hot, 3.0, 0.7)
            _limb(L, knee, foot, 0.066 * W, 0.048 * W, main, deep, hot, 2.6, 0.55)
        # pie: cuna hacia delante, misma en todos los estilos
        fx = (0.5 + 0.115 * sgn) * W
        _poly_layer(L, [(fx - 0.052 * W, _FOOT_Y * H),
                        (fx + 0.070 * W, _FOOT_Y * H - 0.004 * H),
                        (fx + 0.062 * W, 0.998 * H),
                        (fx - 0.062 * W, 0.998 * H)],
                    dark, deep, hot, 2.2, 0.5)

    # ---------- torso ----------
    cx = 0.5 * W
    if style == "plates":
        torso = [(cx, 0.190 * H), (cx + 0.175 * W, 0.320 * H),
                 (cx + 0.128 * W, 0.500 * H), (cx + 0.070 * W, 0.560 * H),
                 (cx - 0.070 * W, 0.560 * H), (cx - 0.128 * W, 0.500 * H),
                 (cx - 0.175 * W, 0.320 * H)]
        _poly_layer(L, torso, main, dark, hot, 5.0, 0.85)
        # placa pectoral interna, mas oscura: da volumen sin dibujar anatomia
        _poly_layer(L, [(cx, 0.240 * H), (cx + 0.100 * W, 0.330 * H),
                        (cx + 0.072 * W, 0.478 * H), (cx, 0.512 * H),
                        (cx - 0.072 * W, 0.478 * H), (cx - 0.100 * W, 0.330 * H)],
                    deep, (0x02, 0x06, 0x0A), hot, 2.2, 0.45)
    elif style == "facet":
        # trapecio facetado con hombros anchos y cintura estrecha
        torso = [(cx - 0.165 * W, 0.255 * H), (cx + 0.165 * W, 0.255 * H),
                 (cx + 0.112 * W, 0.470 * H), (cx + 0.062 * W, 0.556 * H),
                 (cx - 0.062 * W, 0.556 * H), (cx - 0.112 * W, 0.470 * H)]
        _poly_layer(L, torso, main, dark, hot, 5.0, 0.85)
        # faceta derecha en sombra (tallado, no pintado)
        _poly_layer(L, [(cx, 0.262 * H), (cx + 0.158 * W, 0.262 * H),
                        (cx + 0.107 * W, 0.470 * H), (cx + 0.058 * W, 0.550 * H),
                        (cx, 0.550 * H)],
                    deep, (0x02, 0x04, 0x08), None, alpha=0.55)
    elif style == "organic":
        torso = _ellipse_pts(cx, 0.395 * H, 0.165 * W, 0.185 * H, 34, 0.0)
        _poly_layer(L, torso, main, dark, hot, 5.0, 0.8)
        # cinturon bajo el torso: cierra la silueta y separa torso de piernas
        _poly_layer(L, [(cx - 0.148 * W, 0.505 * H), (cx + 0.148 * W, 0.505 * H),
                        (cx + 0.112 * W, 0.565 * H), (cx - 0.112 * W, 0.565 * H)],
                    (0x0E, 0x06, 0x1C), (0x05, 0x02, 0x0A), hot, 2.4, 0.55)
    else:  # orb
        torso = _ellipse_pts(cx, 0.390 * H, 0.180 * W, 0.200 * H, 32, 0.0)
        _poly_layer(L, torso, main, dark, hot, 6.0, 0.8)

    # ---------- hombreras / hombros ----------
    # Centradas en el punto de hombro del brazo (0.200) para que la pieza y el
    # brazo se toquen: antes quedaban desalineadas y se leia "despegado".
    for sgn in (-1, 1):
        sx = (0.5 + 0.200 * sgn) * W
        if style == "organic":
            _poly_layer(L, _ellipse_pts(sx, 0.292 * H, 0.078 * W, 0.072 * H, 24, 0.0),
                        main, dark, hot, 3.4, 0.8, alpha=0.97)
        else:
            # cuna simetrica: borde exterior vertical, interior inclinado
            _poly_layer(L, [(sx - 0.078 * W * sgn, 0.238 * H),
                            (sx + 0.052 * W * sgn, 0.250 * H),
                            (sx + 0.058 * W * sgn, 0.340 * H),
                            (sx - 0.070 * W * sgn, 0.352 * H)],
                        main, dark, hot, 3.4, 0.8)

    # ---------- brazos ----------
    for sgn in (-1, 1):
        sh = ((0.5 + 0.200 * sgn) * W, 0.300 * H)
        el = ((0.5 + 0.252 * sgn) * W, 0.455 * H)
        hd = ((0.5 + 0.238 * sgn) * W, 0.590 * H)
        up = 0.062 if style != "organic" else 0.078
        fo = 0.048 if style != "organic" else 0.060
        _limb(L, sh, el, up * W, fo * W, main, dark, hot, 2.8, 0.7)
        _limb(L, el, hd, fo * W, (fo - 0.010) * W, main, deep, hot, 2.4, 0.55)
        if style == "organic":
            _poly_layer(L, _ellipse_pts(hd[0], (0.615 * H), 0.042 * W, 0.042 * H, 18),
                        main, dark, hot, 2.4, 0.6, alpha=0.95)
        else:
            _poly_layer(L, [(hd[0] - 0.030 * W, 0.596 * H),
                            (hd[0] + 0.030 * W, 0.596 * H),
                            (hd[0] + 0.026 * W, 0.648 * H),
                            (hd[0] - 0.026 * W, 0.648 * H)],
                        pal["mid"], deep, hot, 2.2, 0.65)

    # ---------- cuello ----------
    ny = 0.205 * H
    _poly_layer(L, [(cx - 0.040 * W, ny), (cx + 0.040 * W, ny),
                    (cx + 0.048 * W, 0.238 * H), (cx - 0.048 * W, 0.238 * H)],
                dark, deep, hot, 2.0, 0.55)

    # ---------- cabeza ----------
    hy = _HEAD_Y * H
    if style == "plates":
        head = [(cx, (0.030) * H), (cx + 0.082 * W, 0.072 * H),
                (cx + 0.092 * W, 0.140 * H), (cx + 0.030 * W, 0.180 * H),
                (cx - 0.030 * W, 0.180 * H), (cx - 0.092 * W, 0.140 * H),
                (cx - 0.082 * W, 0.072 * H)]
        _poly_layer(L, head, main, dark, hot, 4.2, 0.9)
        # visor horizontal: la unica "cara"
        _poly_layer(L, [(cx - 0.070 * W, 0.104 * H), (cx + 0.070 * W, 0.098 * H),
                        (cx + 0.068 * W, 0.132 * H), (cx - 0.068 * W, 0.138 * H)],
                    hot, hot, None, alpha=0.96)
        _poly_layer(L, [(cx - 0.006 * W, 0.032 * H), (cx + 0.006 * W, 0.032 * H),
                        (cx + 0.008 * W, 0.104 * H), (cx - 0.008 * W, 0.104 * H)],
                    hot, main, None, alpha=0.8)
    elif style == "facet":
        _poly_layer(L, [(cx, 0.020 * H), (cx + 0.076 * W, 0.098 * H),
                        (cx + 0.040 * W, 0.190 * H), (cx - 0.040 * W, 0.190 * H),
                        (cx - 0.076 * W, 0.098 * H)],
                    main, dark, hot, 4.0, 0.9)
        # arista vertical encendida en el centro del cristal-cabeza
        _poly_layer(L, [(cx - 0.008 * W, 0.032 * H), (cx + 0.008 * W, 0.032 * H),
                        (cx + 0.012 * W, 0.182 * H), (cx - 0.012 * W, 0.182 * H)],
                    hot, main, None, alpha=0.85)
    elif style == "organic":
        # cabeza gota, inclinada, con dos cintas cortas
        head = _ellipse_pts(cx, hy, 0.078 * W, 0.086 * H, 26, 0.20)
        _poly_layer(L, head, main, dark, hot, 4.0, 0.85)
        _poly_layer(L, _ellipse_pts(cx, hy + 0.012 * H, 0.030 * W, 0.030 * H, 16),
                    hot, hot, None, alpha=0.95)
    else:  # orb: cabeza = anillo luminoso abierto
        _poly_layer(L, _ellipse_pts(cx, hy, 0.082 * W, 0.088 * H, 26, 0.0),
                    main, dark, hot, 4.5, 0.85)
        L.append(Layer(lambda px, py: sd_ellipse_ring(px, py, cx, hy, 0.050 * W,
                                                      0.050 * W, 0.0, 0.014 * W),
                       (cx - 0.062 * W, hy - 0.062 * W,
                        cx + 0.062 * W, hy + 0.062 * W),
                       hot, None, alpha=0.95))
    return L


def fighter_vector():
    """Tema NEON / izquierda: placas angulares azules, visor y nucleo."""
    W, H = FW, FH
    # Los medios suben respecto al CYAN_DARK puro: sobre la rejilla azul del
    # fondo, un cuerpo azul oscuro se perdia. El contorno lo cierra el rim.
    pal = {"main": CYAN, "mid": (0x16, 0x44, 0x6E), "dark": (0x08, 0x1A, 0x2C),
           "hot": CYAN_HOT}
    L = _skeleton(W, H, pal, "plates")
    # nucleo de pecho (rombo encendido)
    cx = 0.5 * W
    _poly_layer(L, kite(cx, 0.372 * H, 0.052 * W, 0.062 * H), CYAN_HOT, CYAN,
                None, alpha=0.98)
    # dos ribetes verticales en el torso
    for sgn in (-1, 1):
        _poly_layer(L, [((0.5 + 0.055 * sgn) * W, 0.300 * H),
                        ((0.5 + 0.070 * sgn) * W, 0.300 * H),
                        ((0.5 + 0.052 * sgn) * W, 0.520 * H),
                        ((0.5 + 0.038 * sgn) * W, 0.520 * H)],
                    CYAN_HOT, None, None, alpha=0.55)
    buf = render_layers(W, H, L)
    add_glow_png(buf, W, H, cx, 0.372 * H, 0.125 * W, CYAN_HOT, 0.80, 2.4)
    add_glow_png(buf, W, H, cx, 0.116 * H, 0.095 * W, CYAN_HOT, 0.50, 2.2)
    add_glow_png(buf, W, H, cx, 0.985 * H, 0.260 * W, CYAN, 0.34, 2.4)
    add_silhouette_halo(buf, W, H, CYAN, width=7, strength=0.60)
    return buf, W, H


def fighter_orbe():
    """Tema NEON / derecha: entidad esferica roja, anillo orbital y base de energia."""
    W, H = FW, FH
    pal = {"main": RED, "mid": (0x4A, 0x10, 0x16), "dark": RED_DARK,
           "hot": RED_HOT}
    L = _skeleton(W, H, pal, "orb")
    cx = 0.5 * W
    cy = 0.390 * H
    # anillo orbital: elipse muy achatada y girada, cruzando el torso
    L.append(Layer(lambda px, py: sd_ellipse_ring(px, py, cx, cy + 0.020 * H,
                                                  0.290 * W, 0.078 * H, -0.30,
                                                  0.020 * W),
                   (cx - 0.320 * W, cy - 0.130 * H, cx + 0.320 * W,
                    cy + 0.170 * H),
                   mix(RED, RED_HOT, 0.45), None, alpha=0.9))
    # tres esquirlas en orbita (posiciones fijas, no aleatorias)
    for (ang, dist, s) in ((-0.55, 1.55, 0.028), (1.05, 1.62, 0.022),
                           (2.55, 1.45, 0.019)):
        ox = cx + math.cos(ang) * 0.290 * W * dist
        oy = cy + 0.020 * H + math.sin(ang) * 0.078 * H * dist * 1.9
        _poly_layer(L, rot_pts(kite(ox, oy, s * W, s * W * 1.8), ox, oy, ang),
                    RED_HOT, RED, None, alpha=0.9)
    buf = render_layers(W, H, L)
    add_glow_png(buf, W, H, cx, cy, 0.330 * W, RED, 0.42, 2.6)
    add_glow_png(buf, W, H, cx - 0.055 * W, cy - 0.070 * H, 0.135 * W,
                 RED_HOT, 0.65, 2.1)
    add_glow_png(buf, W, H, cx, 0.780 * H, 0.190 * W, RED, 0.20, 2.6)
    add_glow_png(buf, W, H, cx, 0.985 * H, 0.250 * W, RED, 0.30, 2.4)
    add_silhouette_halo(buf, W, H, RED, width=7, strength=0.55)
    return buf, W, H


def fighter_prisma():
    """Tema COSMICO / izquierda: luchador de cristal ambar facetado."""
    W, H = FW, FH
    pal = {"main": AMBER, "mid": (0x0B, 0x4F, 0x49), "dark": AMBER_DARK,
           "hot": AMBER_HOT}
    L = _skeleton(W, H, pal, "facet")
    cx = 0.5 * W
    # nucleo de cristal en el pecho (kite invertido)
    _poly_layer(L, kite(cx, 0.375 * H, 0.062 * W, 0.082 * H, 0.010 * H),
                AMBER_HOT, AMBER, None, alpha=0.95)
    # esquirlas satelite (posiciones fijas)
    for (fx, fy, s) in ((0.235, 0.470, 0.024), (0.765, 0.600, 0.020),
                        (0.800, 0.395, 0.016), (0.205, 0.680, 0.015)):
        _poly_layer(L, kite(fx * W, fy * H, s * W, s * W * 1.9, -s * W * 0.4),
                    AMBER_HOT, AMBER, None, alpha=0.8)
    buf = render_layers(W, H, L)
    add_glow_png(buf, W, H, cx, 0.375 * H, 0.150 * W, AMBER_HOT, 0.55, 2.4)
    add_glow_png(buf, W, H, cx, 0.105 * H, 0.100 * W, AMBER_HOT, 0.45, 2.2)
    add_glow_png(buf, W, H, cx, 0.985 * H, 0.260 * W, AMBER, 0.34, 2.4)
    add_silhouette_halo(buf, W, H, AMBER, width=7, strength=0.50)
    return buf, W, H


def fighter_nebula():
    """Tema COSMICO / derecha: entidad organica violeta, cintas y bulbo."""
    W, H = FW, FH
    # Rampa de mas contraste que la de cristal: a 370 px el violeta sobre
    # violeta se emborronaba, asi que el cuerpo bajo va casi negro.
    # main estaba hardcodeado en (0xC4,0x60,0xFF) = purpura saturado, que es el
    # color exacto de EVA-01 y anulaba el cambio de VIOLET. Ahora azul acero.
    pal = {"main": (0x8F, 0xB6, 0xF2), "mid": (0x2A, 0x40, 0x6B),
           "dark": (0x07, 0x0F, 0x20), "hot": VIOLET_HOT}
    L = _skeleton(W, H, pal, "organic")
    cx = 0.5 * W
    # ojo/cristal central (anillo + punto): lee como punto focal, no como cara
    L.append(Layer(lambda px, py: sd_ellipse_ring(px, py, cx, 0.400 * H,
                                                  0.062 * W, 0.062 * W, 0.0,
                                                  0.012 * W),
                   (cx - 0.075 * W, 0.400 * H - 0.075 * W,
                    cx + 0.075 * W, 0.400 * H + 0.075 * W),
                   VIOLET_HOT, None, alpha=0.92))
    # cintas que caen desde la cadera (dos por lado, dan movimiento)
    for sgn in (-1, 1):
        for j, (w0, w1) in enumerate(((0.035, 0.014), (0.026, 0.010))):
            p0 = ((0.5 + (0.085 + j * 0.045) * sgn) * W, 0.545 * H)
            p1 = ((0.5 + (0.150 + j * 0.060) * sgn) * W, 0.790 * H)
            _limb(L, p0, p1, w0 * W, w1 * W, pal["mid"], VIOLET_DARK,
                  VIOLET_HOT, 1.8, 0.5, alpha=0.75)
    # Sin antenas: dos apendices que salian de la cabeza hacia arriba se leian
    # como los cuernos de EVA-01. Se sustituyen por una cresta baja y centrada,
    # que da altura sin dibujar el icono de ninguna franquicia.
    # Cresta ancha y baja (no domo): un domo con visera vertical lee como el
    # casco de EVA-01; esto es una visera horizontal de ancho completo.
    crest = [(cx - 0.140 * W, 0.098 * H), (cx - 0.070 * W, 0.058 * H),
             (cx + 0.070 * W, 0.058 * H), (cx + 0.140 * W, 0.098 * H)]
    L.append(Layer(lambda px, py: sd_poly(px, py, crest),
                   (cx - 0.120 * W, 0.040 * H, cx + 0.120 * W, 0.090 * H),
                   pal["main"], None, None, alpha=0.9))
    buf = render_layers(W, H, L)
    add_glow_png(buf, W, H, cx, 0.400 * H, 0.300 * W, VIOLET, 0.45, 2.5)
    add_glow_png(buf, W, H, cx, 0.400 * H, 0.090 * W, VIOLET_HOT, 0.60, 2.0)
    add_glow_png(buf, W, H, cx, 0.985 * H, 0.250 * W, VIOLET, 0.30, 2.4)
    add_silhouette_halo(buf, W, H, MAGENTA, width=7, strength=0.62)
    return buf, W, H


# ---------------------------------------------------------------------------
#  Fondos
# ---------------------------------------------------------------------------
BW, BH = 1080, 1920


def bg_neon():
    """Fondo tema NEON: horizonte con rejilla en perspectiva y haces verticales.

    Pensado para moverse en parallax: la mitad inferior es geometria regular
    (rejilla) y la superior solo degradado + haces, asi que un desplazamiento
    lento no revela bordes.
    """
    W, H = BW, BH
    buf = bytearray(W * H * 4)
    horizon = 0.615
    hz_y = horizon * H
    for y in range(H):
        v = y / H
        # degradado de cielo: casi negro arriba, azul acero en el horizonte
        t = smoothstep(0.0, horizon, v)
        sky = mix(NAVY_DEEP, mix(NAVY_LIFT, CYAN_DARK, 0.55), t ** 1.35)
        # suelo: del horizonte hacia abajo se va a negro azulado
        if v > horizon:
            g = smoothstep(horizon, 1.0, v)
            floor_base = mix(mix(NAVY, NAVY_DEEP, 0.5), (0.030, 0.045, 0.068), g)
        else:
            floor_base = sky
        for x in range(W):
            u = x / W
            r, gg, b = floor_base
            # --- haz vertical de luz (tres columnas suaves) ---
            if v < horizon:
                beam = (math.sin(u * math.pi * 3.0 + 0.6) * 0.5 + 0.5) ** 6
                beam *= (1.0 - smoothstep(0.0, horizon * 0.95, v)) * 0.55
                r += CYAN[0] * beam * 0.055
                gg += CYAN[1] * beam * 0.075
                b += CYAN[2] * beam * 0.085
            # --- rejilla en perspectiva (solo suelo) ---
            if v > horizon:
                dz = v - horizon
                z = 1.0 / (dz * 9.0 + 0.085)          # profundidad
                # lineas transversales
                fz = z * 1.0
                lz = abs(fz - round(fz))
                line_z = 1.0 - smoothstep(0.0, 0.055 + dz * 0.10, lz)
                # lineas longitudinales (convergen al centro)
                sx = (u - 0.5) * z * 5.2
                lx = abs(sx - round(sx))
                line_x = 1.0 - smoothstep(0.0, 0.05 + dz * 0.05, lx)
                near = smoothstep(horizon, horizon + 0.035, v)
                fade = (1.0 - smoothstep(0.30, 0.95, dz)) * near
                k = (line_z * 0.85 + line_x * 0.65) * fade
                if k > 0.0:
                    c = mix(floor_base, CYAN, min(1.0, k * 0.75))
                    r, gg, b = c
                    # brillo extra en el cruce
                    if line_z > 0.5 and line_x > 0.5:
                        r += 26
                        gg += 44
                        b += 52
            # --- glow de horizonte ---
            hg = math.exp(-abs(v - horizon) * 34.0)
            r += CYAN[0] * hg * 0.26
            gg += CYAN[1] * hg * 0.30
            b += CYAN[2] * hg * 0.34
            # --- vineta + scanline muy suave ---
            vx = (u - 0.5) * 2.0
            vig = 1.0 - 0.35 * (vx * vx) - 0.22 * smoothstep(0.65, 1.0, v)
            r *= vig
            gg *= vig
            b *= vig
            if y % 3 == 0:
                r *= 0.975
                gg *= 0.975
                b *= 0.975
            o = (y * W + x) * 4
            buf[o] = 255 if r > 255 else (0 if r < 0 else int(r))
            buf[o + 1] = 255 if gg > 255 else (0 if gg < 0 else int(gg))
            buf[o + 2] = 255 if b > 255 else (0 if b < 0 else int(b))
            buf[o + 3] = 255
    # dos "balizas" de acento, encendidas, lejos del centro
    add_glow_png(buf, W, H, 0.18 * W, 0.62 * H, 0.16 * W, CYAN, 0.30, 2.6)
    add_glow_png(buf, W, H, 0.82 * W, 0.62 * H, 0.16 * W, CYAN, 0.30, 2.6)
    return buf, W, H


def value_noise(gw, gh, salt, cells=4, octaves=4):
    """Ruido de valor multioctava (determinista) muestreado en gw x gh.

    `cells` es el numero de celdas del primer octavo a lo ancho: 4 da manchas
    grandes y suaves en vez de un damero. Cada octavo duplica la frecuencia y
    divide la amplitud por 2 (ruido "fractal" clasico).
    """
    out = [0.0] * (gw * gh)
    amp = 1.0
    tot = 0.0
    for oc in range(octaves):
        cw = max(2, cells * (2 ** oc) + 1)
        ch = max(2, int(cw * gh / gw) + 1)
        grid = [ihash(i, j, salt + oc * 7919) for j in range(ch) for i in range(cw)]
        for j in range(gh):
            fy = j / gh * (ch - 1)
            iy = int(fy)
            ty = fy - iy
            ty = ty * ty * (3 - 2 * ty)
            r0 = iy * cw
            r1 = min(ch - 1, iy + 1) * cw
            for i in range(gw):
                fx = i / gw * (cw - 1)
                ix = int(fx)
                tx = fx - ix
                tx = tx * tx * (3 - 2 * tx)
                i1 = min(cw - 1, ix + 1)
                a = grid[r0 + ix] + (grid[r0 + i1] - grid[r0 + ix]) * tx
                b = grid[r1 + ix] + (grid[r1 + i1] - grid[r1 + ix]) * tx
                out[j * gw + i] += (a + (b - a) * ty) * amp
        tot += amp
        amp *= 0.5
    return [v / tot for v in out]


def bg_cosmico():
    """Fondo tema COSMICO: nebulosa violeta/ambar, estrellas fijas y agujas."""
    W, H = BW, BH
    buf = bytearray(W * H * 4)
    # ---- nebulosa a 1/8 de resolucion y luego bilineal: manchas grandes ----
    gw, gh = W // 8 + 2, H // 8 + 2
    n1 = value_noise(gw, gh, 17, cells=3, octaves=4)
    n2 = value_noise(gw, gh, 4711, cells=5, octaves=3)
    cell = 8.0
    # ---- fondo: degradado vertical + nebulosa ----
    for y in range(H):
        v = y / H
        base = mix((0x07, 0x05, 0x11), (0x17, 0x0D, 0x28), smoothstep(0.0, 0.80, v))
        base = mix(base, (0x09, 0x06, 0x14), smoothstep(0.70, 1.0, v))
        fy = y / cell
        iy = int(fy)
        ty = fy - iy
        ty = ty * ty * (3 - 2 * ty)
        r0 = iy * gw
        r1 = min(gh - 1, iy + 1) * gw
        for x in range(W):
            u = x / W
            fx = x / cell
            ix = int(fx)
            tx = fx - ix
            tx = tx * tx * (3 - 2 * tx)
            ix1 = ix + 1
            if ix1 >= gw:
                ix1 = gw - 1
            a1 = n1[r0 + ix] + (n1[r0 + ix1] - n1[r0 + ix]) * tx
            b1 = n1[r1 + ix] + (n1[r1 + ix1] - n1[r1 + ix]) * tx
            m1 = a1 + (b1 - a1) * ty
            a2 = n2[r0 + ix] + (n2[r0 + ix1] - n2[r0 + ix]) * tx
            b2 = n2[r1 + ix] + (n2[r1 + ix1] - n2[r1 + ix]) * tx
            m2 = a2 + (b2 - a2) * ty
            # banda de nebulosa: concentrada en el tercio medio, caida suave
            band = smoothstep(0.02, 0.40, v) * (1.0 - smoothstep(0.52, 0.92, v))
            # umbral alto + smoothstep = gas suave, sin damero
            dens1 = smoothstep(0.46, 0.78, m1) * band
            dens2 = smoothstep(0.52, 0.80, m2) * band
            r, gg, b = base
            r += VIOLET[0] * dens1 * 0.14 + AMBER[0] * dens2 * 0.055
            gg += VIOLET[1] * dens1 * 0.075 + AMBER[1] * dens2 * 0.042
            b += VIOLET[2] * dens1 * 0.175 + AMBER[2] * dens2 * 0.020
            # halo de horizonte bajo (linea de amanecer)
            hg = math.exp(-((v - 0.760) ** 2) * 240.0)
            r += AMBER[0] * hg * 0.13
            gg += AMBER[1] * hg * 0.10
            b += AMBER[2] * hg * 0.075
            # vineta
            vx = (u - 0.5) * 2.0
            vig = 1.0 - 0.30 * vx * vx - 0.18 * smoothstep(0.70, 1.0, v)
            o = (y * W + x) * 4
            rr = r * vig
            g2 = gg * vig
            bb = b * vig
            # dither ordenado 2x2: rompe el banding del degradado sin ruido visible
            dth = (0.35 if ((x & 1) ^ (y & 1)) else -0.35)
            buf[o] = _c8(rr + dth)
            buf[o + 1] = _c8(g2 + dth)
            buf[o + 2] = _c8(bb + dth)
            buf[o + 3] = 255

    # ---- campo de estrellas: LCG con semilla fija ----
    rnd = lcg(20261023)
    for i in range(320):
        sx = int(rnd() * W)
        sy = int(rnd() * H)
        mag = rnd() ** 2.4            # muchas tenues, pocas brillantes
        tint = rnd()
        col = mix((0xDF, 0xE8, 0xFF), AMBER, 0.55) if tint > 0.72 else (0xCF, 0xD8, 0xFF)
        rad = 0.8 + mag * 4.4
        add_glow_png(buf, W, H, sx, sy, rad + 1.5, col, 0.10 + mag * 0.80, 1.6)

    # ---- agujas de cristal en el tercio inferior (silueta + ribete, con AA) ----
    rnd2 = lcg(777)
    spikes = []
    for i in range(8):
        cx = (i + 0.5) / 8.0 * W + (rnd2() - 0.5) * 70
        h = (0.09 + rnd2() * 0.19) * H
        hw = 30 + rnd2() * 62
        lean = (rnd2() - 0.5) * 0.35 * hw
        spikes.append((cx, h, hw, lean))
    # de mas alta a mas baja: las bajas quedan delante, dando profundidad
    spikes.sort(key=lambda s: -s[1])
    for (cx, h, hw, lean) in spikes:
        top = H - h
        pts = [(cx + lean, top), (cx + hw, H + 2), (cx - hw, H + 2)]
        x0 = max(0, int(min(p[0] for p in pts)) - 2)
        x1 = min(W, int(max(p[0] for p in pts)) + 3)
        y0 = max(0, int(top) - 2)
        for y in range(y0, H):
            for x in range(x0, x1):
                # cobertura AA por 2x2 muestras del triangulo
                cov = 0.0
                for sy in (0.25, 0.75):
                    for sx in (0.25, 0.75):
                        d = sd_poly(x + sx, y + sy, pts)
                        cov += clamp01(0.5 - d)
                cov *= 0.25
                if cov <= 0.0:
                    continue
                # cuerpo casi negro con violeta profundo; ribete en el borde
                body = (0x07, 0x05, 0x0E)
                edge = _rim_edge(x + 0.5, y + 0.5, pts, 3.2)
                col = mix(body, mix(VIOLET_DARK, VIOLET, 0.55), edge * 0.85)
                o = (y * W + x) * 4
                for ch, cv in enumerate(col):
                    buf[o + ch] = _c8(buf[o + ch] * (1.0 - cov) + cv * cov)
    # brillo de la cresta de cada aguja
    for (cx, h, hw, lean) in spikes:
        add_glow_png(buf, W, H, cx + lean, H - h + 4, 26, AMBER, 0.22, 2.0)
    return buf, W, H


def _c8(v):
    return 255 if v > 255 else (0 if v < 0 else int(v))


def _rim_edge(px, py, pts, w):
    """1 en el borde interior del poligono, 0 hacia dentro (para el ribete)."""
    d = sd_poly(px, py, pts)
    if d > 0.0:
        return 0.0
    return 1.0 - clamp01(-d / w)


# ---------------------------------------------------------------------------
#  Composicion de portada (docs/)
# ---------------------------------------------------------------------------
def preview():
    """Compone fondo + los dos luchadores del tema neon a 1080x1920.

    No es una captura del APK: es arte generado por este mismo script, para que
    la landing tenga una imagen propia hasta que se recapture la app real.
    """
    W, H = BW, BH
    buf = bytearray(bg_neon()[0])
    sprites = (("fighter_vector.png", 0.045, CYAN), ("fighter_orbe.png", 0.545, RED))
    for (name, xfrac, col) in sprites:
        sw, sh, data = read_png(os.path.join(IMG_DIR, name))
        # escala: alto 46% del lienzo, anclado abajo
        scale = (H * 0.46) / sh
        dw = int(sw * scale)
        dh = int(sh * scale)
        ox = int(W * xfrac)
        oy = int(H * 0.52)
        for y in range(dh):
            sy = int(y / scale)
            if sy >= sh:
                continue
            for x in range(dw):
                sx = int(x / scale)
                if sx >= sw:
                    continue
                so = (sy * sw + sx) * 4
                a = data[so + 3]
                if a == 0:
                    continue
                px = ox + x
                py = oy + y
                if px < 0 or px >= W or py < 0 or py >= H:
                    continue
                o = (py * W + px) * 4
                k = a / 255.0
                buf[o] = int(data[so] * k + buf[o] * (1 - k))
                buf[o + 1] = int(data[so + 1] * k + buf[o + 1] * (1 - k))
                buf[o + 2] = int(data[so + 2] * k + buf[o + 2] * (1 - k))
    # barras de vida esquematicas (sin texto: el script no lleva tipografia)
    for (x0, x1, col) in ((0.06, 0.44, CYAN), (0.56, 0.94, RED)):
        for y in range(int(H * 0.035), int(H * 0.055)):
            for x in range(int(W * x0), int(W * x1)):
                o = (y * W + x) * 4
                k = 0.55 if (y % 3) else 0.85
                buf[o] = int(col[0] * k + buf[o] * (1 - k))
                buf[o + 1] = int(col[1] * k + buf[o + 1] * (1 - k))
                buf[o + 2] = int(col[2] * k + buf[o + 2] * (1 - k))
    return buf, W, H


# ---------------------------------------------------------------------------
#  PNG: escritura y lectura minima (stdlib)
# ---------------------------------------------------------------------------
def write_png(path, buf, W, H, alpha=True):
    rows = bytearray()
    stride = W * 4
    for y in range(H):
        rows.append(0)  # filtro None
        rows += buf[y * stride:(y + 1) * stride]
    ctype = 6 if alpha else 2
    png = (b"\x89PNG\r\n\x1a\n"
           + _chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, ctype, 0, 0, 0))
           + _chunk(b"IDAT", zlib.compress(bytes(rows), 9))
           + _chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return len(png)


def _chunk(typ, data):
    c = struct.pack(">I", len(data)) + typ + data
    return c + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)


def read_png(path):
    """Lector PNG minimo para RGBA/RGB de 8 bits sin filtros ni paleta."""
    with open(path, "rb") as f:
        d = f.read()
    W, H, bd, ct = struct.unpack(">IIBB", d[16:26])
    assert bd == 8 and ct in (2, 6), "solo PNG 8-bit RGB/RGBA"
    pos = 8
    idat = bytearray()
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos + 4])[0]
        typ = d[pos + 4:pos + 8]
        if typ == b"IDAT":
            idat += d[pos + 8:pos + 8 + ln]
        pos += 12 + ln
    raw = zlib.decompress(bytes(idat))
    bpp = 4 if ct == 6 else 3
    stride = W * bpp
    out = bytearray(W * H * 4)
    prev = bytearray(stride)
    p = 0
    for y in range(H):
        ft = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if ft == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ft == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                c = prev[i - bpp] if i >= bpp else 0
                b = prev[i]
                pa = abs(b - c)
                pb = abs(a - c)
                pc = abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        for x in range(W):
            o = (y * W + x) * 4
            s = x * bpp
            out[o] = line[s]
            out[o + 1] = line[s + 1]
            out[o + 2] = line[s + 2]
            out[o + 3] = line[s + 3] if bpp == 4 else 255
        prev = line
    return W, H, out


# ---------------------------------------------------------------------------
#  Registro de tareas
# ---------------------------------------------------------------------------
TASKS = {
    "vector": ("fighter_vector.png", fighter_vector, True),
    "orbe": ("fighter_orbe.png", fighter_orbe, True),
    "prisma": ("fighter_prisma.png", fighter_prisma, True),
    "nebula": ("fighter_nebula.png", fighter_nebula, True),
    "bg-neon": ("bg_neon.png", bg_neon, True),
    "bg-cosmico": ("bg_cosmico.png", bg_cosmico, True),
    # alpha=True obligatorio: preview() devuelve buffer RGBA (4 B/px). Con
    # alpha=False se escribe cabecera RGB de 3 B/px sobre filas de 4 B/px y el
    # PNG sale corrupto ("unrecognized data stream contents").
    "preview": ("../docs/battle_art_preview.png", preview, True),
}


def run(name):
    fname, fn, alpha = TASKS[name]
    buf, W, H = fn()
    base = DOCS_DIR if fname.startswith("../") else IMG_DIR
    path = os.path.normpath(os.path.join(base, fname))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    n = write_png(path, buf, W, H, alpha)
    print("OK %-28s %dx%d %7d bytes  %s"
          % (os.path.basename(path), W, H, n,
             os.path.relpath(path, ROOT)))


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        print("tareas:", ", ".join(TASKS), ", all")
        return 0
    names = argv[1:]
    if names == ["all"]:
        names = list(TASKS)
    for n in names:
        if n not in TASKS:
            print("tarea desconocida:", n)
            return 2
        run(n)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
