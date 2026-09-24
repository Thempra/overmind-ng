#!/usr/bin/env python3
"""Genera icono de app 'Overmind' en clave del juego (duelo EEG):
onda cerebral + barra de poder EVA(cian) vs SACHIEL(rojo) sobre fondo oscuro.
Base 512x512 RGBA opaco, esquinas redondeadas suaves."""
import math, os, struct, zlib

S = 512

def bg_grad(nx, ny):
    # fondo navy oscuro con leve degradado vertical
    t = ny
    r = 8 + 6*t
    g = 11 + 7*t
    b = 18 + 12*t
    return (r, g, b)

def radial_glow(nx, ny, cx, cy, rmax, col, falloff=1.0):
    d2 = (nx-cx)**2 + (ny-cy)**2
    if d2 > rmax*rmax: return None
    d = math.sqrt(d2)/rmax
    a = (1-d)**falloff
    return (col[0], col[1], col[2], a)

def within_roundrect(nx, ny, x0, y0, x1, y1, radius):
    # nx,ny en 0..1
    px = nx*S; py = ny*S
    bx0, by0 = x0*S, y0*S
    bx1, by1 = x1*S, y1*S
    r = radius*S
    qx = min(max(px, bx0+r), bx1-r)
    qy = min(max(py, by0+r), by1-r)
    return (px-qx)**2 + (py-qy)**2 <= r*r

def hbar(nx, ny):
    # barra horizontal de poder: y0..y1, x0..x1 ; centros cian/rojo separados
    y0, y1 = 0.43, 0.54
    x0, x1 = 0.14, 0.86
    if not (x0 <= nx <= x1 and y0 <= ny <= y1): return None
    # esquinas redondeadas pequeñas
    rr = min(0.012, (y1-y0)/2)
    # dentro
    e0x,e1x = x0+rr, x1-rr
    if not within_roundrect(nx,ny,x0,y0,x1,y1,rr): return None
    # color: mezcla según x: izquierda cian derecha roja, centro blanco
    mid = (x0+x1)/2
    w = (x1-x0)/2
    tt = (nx-mid)/w  # -1..1
    cian = (58,182,255)
    rojo = (255,75,75)
    blanco = (235,244,255)
    if abs(tt)<0.06:
        c = blanco
        a = 1.0
    elif tt<0:
        k = (tt+0.06)/(1.06)  # 0..1
        c = tuple(int(cian[i]*(1-k)+blanco[i]*k) for i in range(3))
        a = 0.95-0.15*abs(tt)
    else:
        k = (0.06-tt)/(1.06)
        c = tuple(int(rojo[i]*(1-k)+blanco[i]*k) for i in range(3))
        a = 0.95-0.15*abs(tt)
    return (c[0],c[1],c[2], a)

def eeg_wave(nx, ny):
    # ondas cerebrales: unas curvas encima de la barra
    cy = 0.30
    amp = 0.05
    # dos picos sinusoidales
    d = ny-cy
    if abs(d) > amp*1.2: return None
    # trazos horizontales con fase
    val = math.sin(nx*math.pi*2.2)*amp*0.7 + math.sin(nx*math.pi*5.1)*amp*0.3
    # grosor del trazo
    if abs(d - val) < 0.008:
        return (160,225,255, 0.9)
    if abs(d - val - 0.022) < 0.010 and 0.25<nx<0.75:
        return (255,120,120, 0.55)
    return None

def core_orb(nx, ny):
    # nucleo central brillante (energia mental)
    cx, cy = 0.5, 0.485
    glow = radial_glow(nx, ny, cx, cy, 0.09, (120,220,255), 2.2)
    return glow

SS = 3
out = [[(0,0,0,0) for _ in range(S)] for _ in range(S)]
for y in range(S):
    for x in range(S):
        acc = [0.0,0.0,0.0,0.0]  # premultiplied over
        # base opaca
        base = bg_grad(y/S, x/S)  # nota: usar coords
        cov = 0
        for sy in range(SS):
            for sx in range(SS):
                nx=(x*SS+sx+0.5)/(S*SS); ny=(y*SS+sy+0.5)/(S*SS)
                # capas: orb (glow aditivo) sobre base; barra; onda
                pix = None
                # orb
                orb = core_orb(nx,ny)
                hb = hbar(nx,ny)
                wv = eeg_wave(nx,ny)
                # combinar: empieza desde fondo base
                r,g,b = bg_grad(nx,ny)
                # aplicar orb aditivo
                if orb:
                    r = min(255,int(r*(1-orb[3]) + 150*orb[3]))
                    g = min(255,int(g*(1-orb[3]*0.7) + 220*orb[3]*0.7))
                    b = min(255,int(b*(1-orb[3]) + 255*orb[3]))
                # aplicar barra encima
                if hb:
                    fr=hb[3]
                    r=int(r*(1-fr)+hb[0]*fr); g=int(g*(1-fr)+hb[1]*fr); b=int(b*(1-fr)+hb[2]*fr)
                if wv:
                    fr=wv[3]
                    r=int(r*(1-fr)+wv[0]*fr); g=int(g*(1-fr)+wv[1]*fr); b=int(b*(1-fr)+wv[2]*fr)
                # borde exterior oscuro
                if not (0.02<nx<0.98 and 0.02<ny<0.98):
                    r=int(r*0.3); g=int(g*0.3); b=int(b*0.3)
                acc[0]+=r; acc[1]+=g; acc[2]+=b; cov+=1
        n=SS*SS
        out[y][x]=(max(0,min(255,int(acc[0]/n))),max(0,min(255,int(acc[1]/n))),max(0,min(255,int(acc[2]/n))),255)

rows=b''
for y in range(S):
    rows+=b'\x00'
    for x in range(S):
        r,g,b,a=out[y][x]
        rows+=bytes((r,g,b,a))
def chunk(typ,data):
    c=struct.pack('>I',len(data))+typ+data
    c+=struct.pack('>I',zlib.crc32(typ+data)&0xffffffff)
    return c
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',S,S,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows,9))+chunk(b'IEND',b'')
_out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon_512.png")
with open(_out_path, "wb") as _f:
    _f.write(png)
print("OK", _out_path, "512x512", len(png), "bytes")
