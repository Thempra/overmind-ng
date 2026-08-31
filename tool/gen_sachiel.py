#!/usr/bin/env python3
"""Genera sachiel.png - avatar estilo Evangelion (Ángel Sachiel), sprite de pie,
fondo transparente, silueta clara y muy visible. Salida 243x325 RGBA."""
import math, struct, zlib

W, H = 243, 325
SS = 4                # supersampling
SW, SH = W*SS, H*SS

# --- geometria en coords normalizadas (x:0..1, y:0..1, origen arriba-izq)
def setup():
    # paleta
    white   = (235,235,235)
    light   = (205,210,218)
    grey    = (150,155,168)
    dark    = (45,50,62)
    core    = (70,200,255)   # nucleo azul (Energia)
    core_hi = (180,240,255)
    stripe  = (30,32,40)
    outline = (18,20,28)

    shapes = []
    def add(fn, color):
        shapes.append((fn, color))

    # Cabeza: casco alargado (angulo). Use capsule vertical width narrow
    # Elipse de la cabeza: centro (0.5,0.10), rx 0.085, ry 0.115
    add(lambda x,y: _ell(x,y,0.5,0.108,0.095,0.13), white)
    # cresta / "nariz" central alargada hacia abajo y arriba
    add(lambda x,y: _capsule(x,y,0.5,0.005,0.5,0.10,0.028), white)
    # dos rayas verticales negras en la cara
    add(lambda x,y: _capsule(x,y,0.455,0.02,0.455,0.16,0.0075), stripe)
    add(lambda x,y: _capsule(x,y,0.545,0.02,0.545,0.16,0.0075), stripe)
    # mandibula que baja
    add(lambda x,y: _tri(x,y,0.5,0.215,0.415,0.15,0.585,0.15), white)
    # cuello
    add(lambda x,y: _capsule(x,y,0.5,0.205,0.5,0.245,0.032), light)

    # Torso (pectoral ancho, cintura fina)
    add(lambda x,y: _tri(x,y,0.5,0.24,0.36,0.40,0.64,0.40), white)
    # zona media oscura (cuerpo tipo Sachiel con rayas)
    add(lambda x,y: _capsule(x,y,0.5,0.40,0.5,0.56,0.10), light)
    # rayas pectorales verticales
    add(lambda x,y: _capsule(x,y,0.44,0.25,0.44,0.40,0.006), stripe)
    add(lambda x,y: _capsule(x,y,0.56,0.25,0.56,0.40,0.006), stripe)
    # abdomen oscuro con rayas horizontales
    add(lambda x,y: _capsule(x,y,0.5,0.455,0.5,0.455,0.095), dark)
    for i,(yy,hh) in enumerate([(0.43,0.012),(0.475,0.012),(0.52,0.012),(0.56,0.018)]):
        add(lambda x,y,yy=yy,hh=hh: _capsule(x,y,0.5,yy,0.5,yy,0.05), grey)
    # Nucleo central (corazon/energia) brillante
    add(lambda x,y: _ell(x,y,0.5,0.455,0.055,0.055), core)
    add(lambda x,y: _ell(x,y,0.5,0.455,0.026,0.026), core_hi)

    # Hombros/mangas
    add(lambda x,y: _ell(x,y,0.345,0.30,0.075,0.085), light)
    add(lambda x,y: _ell(x,y,0.655,0.30,0.075,0.085), light)
    # Brazos finos levantados en T (pose de angel)
    add(lambda x,y: _capsule(x,y,0.26,0.30,0.09,0.42,0.028), white)
    add(lambda x,y: _capsule(x,y,0.74,0.30,0.91,0.42,0.028), white)
    # manos
    add(lambda x,y: _ell(x,y,0.085,0.435,0.028,0.040), light)
    add(lambda x,y: _ell(x,y,0.915,0.435,0.028,0.040), light)

    # Cadera
    add(lambda x,y: _capsule(x,y,0.5,0.575,0.5,0.63,0.075), white)
    # Piernas
    add(lambda x,y: _capsule(x,y,0.44,0.63,0.44,0.90,0.045), light)
    add(lambda x,y: _capsule(x,y,0.56,0.63,0.56,0.90,0.045), light)
    # pies
    add(lambda x,y: _ell(x,y,0.44,0.925,0.055,0.022), grey)
    add(lambda x,y: _ell(x,y,0.56,0.925,0.055,0.022), grey)
    return shapes

def _ell(x,y,cx,cy,rx,ry):
    return ((x-cx)/rx)**2 + ((y-cy)/ry)**2 <= 1.0
def _capsule(x,y,x1,y1,x2,y2,r):
    # segmento + capsulas
    dx,dy=x2-x1,y2-y1
    L2=dx*dx+dy*dy
    if L2==0: return (x-x1)**2+(y-y1)**2 <= r*r
    t=((x-x1)*dx+(y-y1)*dy)/L2
    t=max(0,min(1,t))
    px,py=x1+t*dx,y1+t*dy
    return (x-px)**2+(y-py)**2 <= r*r
def _tri(x,y,ax,ay,bx,by,cx,cy):
    def sgn(px,py,qx,qy,rx,ry):
        return (px-rx)*(qy-ry)-(qx-rx)*(py-ry)
    d1=sgn(x,y,ax,ay,bx,by); d2=sgn(x,y,bx,by,cx,cy); d3=sgn(x,y,cx,cy,ax,ay)
    neg=(d1<0) or (d2<0) or (d3<0); pos=(d1>0) or (d2>0) or (d3>0)
    return not (neg and pos)

shapes=setup()

# rasterizar con supersampling usando coverage por subpixel
out=[[ (0,0,0,0) for _ in range(W)] for _ in range(H)]
for y in range(H):
    for x in range(W):
        # recuento de submuestras por capa (ultima gana)
        hit=[]
        for sy in range(SS):
            for sx in range(SS):
                nx=(x*SS+sx+0.5)/SW
                ny=(y*SS+sy+0.5)/SH
                col=None
                for fn,c in shapes:
                    if fn(nx,ny):
                        col=c
                if col is None:
                    hit.append(None)
                else:
                    hit.append(col)
        # determinar color dominante y cobertura
        from collections import Counter
        cnt=Counter()
        nnone=0
        for h in hit:
            if h is None: nnone+=1
            else: cnt[h]+=1
        total=SS*SS
        opaque=total-nnone
        if opaque==0:
            out[y][x]=(0,0,0,0)
        else:
            (col,_)=cnt.most_common(1)[0]
            a=int(255*opaque/total)
            out[y][x]=(col[0],col[1],col[2],a)

# borde de contorno oscuro: añadir trazado a píxeles opacos adyacentes a transparente
def is_op(x,y): return out[y][x][3]>40
for y in range(H):
    for x in range(W):
        if not is_op(x,y): continue
        for dy,dx in [(-1,0),(1,0),(0,-1),(0,1)]:
            x2,y2=x+dx,y+dy
            if 0<=x2<W and 0<=y2<H and not is_op(x2,y2):
                r,g,b,a=out[y][x]
                out[y][x]=(int(r*0.15+18*0.85),int(g*0.15+20*0.85),int(b*0.15+28*0.85),a)
                break

# escribir PNG RGBA
rows=b''
for y in range(H):
    rows+=b'\x00'
    for x in range(W):
        r,g,b,a=out[y][x]
        rows+=bytes((r,g,b,a))
def chunk(typ,data):
    c=struct.pack('>I',len(data))+typ+data
    c+=struct.pack('>I',zlib.crc32(typ+data)&0xffffffff)
    return c
png=b'\x89PNG\r\n\x1a\n'
png+=chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,6,0,0,0))
png+=chunk(b'IDAT',zlib.compress(rows,9))
png+=chunk(b'IEND',b'')
open('assets/images/sachiel.png','wb').write(png)
print('OK sachiel.png', W,'x',H, len(png),'bytes')
