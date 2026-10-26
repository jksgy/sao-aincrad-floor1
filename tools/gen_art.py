# -*- coding: utf-8 -*-
"""Aincrad Proto pixel art generator. All art is procedural, palette-consistent, 16x16 grid.
Outputs PNGs into project/assets. Run with bundled Python (Pillow).
"""
import os, random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "project", "assets")

# ---------- tiny helpers ----------
def img(w, h, bg=None):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0) if bg is None else bg)
    return im

def px(im, x, y, c, a=255):
    if 0 <= x < im.width and 0 <= y < im.height:
        r, g, b = c
        im.putpixel((x, y), (r, g, b, a))

def rect(im, x0, y0, x1, y1, c, a=255):
    for y in range(y0, y1):
        for x in range(x0, x1):
            px(im, x, y, c, a)

def hline(im, x0, x1, y, c):
    for x in range(x0, x1):
        px(im, x, y, c)

def outline_rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            if x == x0 or x == x1 - 1 or y == y0 or y == y1 - 1:
                px(im, x, y, c)

def noise_fill(im, x0, y0, x1, y1, base, variants, rng, prob=0.35):
    for y in range(y0, y1):
        for x in range(x0, x1):
            if rng.random() < prob:
                px(im, x, y, rng.choice(variants))
            else:
                px(im, x, y, base)

def shade(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))))

# ---------- tileset ----------
def make_tileset(path):
    S = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    T = {}  # name -> (col,row)
    def put(col, row, im):
        S.paste(im, (col * 16, row * 16))
    def cell(name, col, row):
        T[name] = (col, row)

    rng = random.Random(7)

    # ---- field ground (row 0) ----
    def grass_tile(seed, tuft=False, flower=False):
        im = img(16, 16)
        noise_fill(im, 0, 0, 16, 16, (86, 130, 60), [(96, 142, 66), (78, 120, 56), (104, 148, 72)], rng)
        if tuft:
            for _ in range(6):
                x = rng.randrange(2, 14); y = rng.randrange(4, 13)
                hline(im, x, x + 1, y, (126, 168, 84)); px(im, x, y - 1, (126, 168, 84))
        if flower:
            for _ in range(3):
                x = rng.randrange(2, 14); y = rng.randrange(3, 13)
                px(im, x, y, rng.choice([(240, 240, 120), (235, 120, 130), (180, 130, 230)]))
                px(im, x, y + 1, (90, 110, 60))
        return im

    for i, name in enumerate(["grass1", "grass2", "grass3"]):
        cell(name, i, 0); put(i, 0, grass_tile(i, tuft=(name != "grass1"), flower=(name == "grass3")))
    cell("tallgrass", 3, 0)
    tg = img(16, 16); noise_fill(tg, 0, 0, 16, 16, (86, 130, 60), [(96, 142, 66), (78, 120, 56)], rng)
    for _ in range(10):
        x = rng.randrange(1, 15); y = rng.randrange(3, 15)
        hline(tg, x, x + 1, y, (130, 176, 86)); px(tg, x, y - 1, (140, 188, 92))
    put(3, 0, tg)

    cell("path", 4, 0)
    p = img(16, 16); noise_fill(p, 0, 0, 16, 16, (178, 150, 110), [(188, 160, 118), (168, 140, 102), (158, 132, 96)], rng)
    put(4, 0, p)
    cell("dirt", 5, 0)
    d = img(16, 16); noise_fill(d, 0, 0, 16, 16, (150, 120, 88), [(160, 128, 94), (140, 112, 82)], rng)
    put(5, 0, d)
    cell("flowers", 6, 0)
    put(6, 0, grass_tile(6, flower=True))

    # water animated (7,0)-(8,0)
    for f in range(2):
        cell("water%d" % f, 7 + f, 0)
        w = img(16, 16, (58, 110, 168))
        for y in range(16):
            for x in range(16):
                if ((x * 3 + y * 5 + f * 7) % 11) < 3:
                    px(w, x, y, (76, 132, 188))
                elif ((x * 5 + y * 3 + f * 13) % 13) == 0:
                    px(w, x, y, (44, 92, 150))
        put(7 + f, 0, w)
    # water edges (9..12,0): shallow walkable sand rim
    for i, name in enumerate(["wedge_top", "wedge_bottom", "wedge_left", "wedge_right"]):
        cell(name, 9 + i, 0)
        e = img(16, 16, (58, 110, 168))
        sand = (196, 178, 130)
        for x in range(16):
            for y in range(16):
                if ((x * 7 + y * 11) % 13) < 2:
                    px(e, x, y, (70, 124, 180))
        if name == "wedge_top":
            rect(e, 0, 12, 16, 16, sand)
            for x in range(16):
                if (x % 5) == 0: rect(e, x, 9, x + 2, 12, sand)
        elif name == "wedge_bottom":
            rect(e, 0, 0, 16, 4, sand)
            for x in range(16):
                if (x % 5) == 0: rect(e, x, 4, x + 2, 7, sand)
        elif name == "wedge_left":
            rect(e, 12, 0, 16, 16, sand)
        else:
            rect(e, 0, 0, 4, 16, sand)
        put(9 + i, 0, e)

    # ---- trees / rocks (row 1) ----
    cell("trunk", 0, 1)
    t = img(16, 16, (86, 130, 60))
    rect(t, 6, 2, 10, 15, (110, 74, 40)); rect(t, 6, 2, 7, 15, (132, 92, 52)); rect(t, 5, 2, 6, 15, (88, 58, 30))
    px(t, 8, 6, (140, 100, 58)); px(t, 8, 10, (140, 100, 58))
    put(0, 1, t)

    cell("canopy", 1, 1)
    c = img(16, 16)
    def leaf(x, y, col): px(c, x, y, col)
    for y in range(2, 15):
        for x in range(16):
            dist = abs(x - 7.5) / 7.5 + abs(y - 8.5) / 7.0
            if dist < 1.0:
                col = (58, 110, 46) if (x + y) % 3 == 0 else (70, 128, 52)
                if (x * 13 + y * 7) % 11 == 0: col = (88, 148, 64)
                if dist > 0.86: col = (44, 88, 38)
                leaf(x, y, col)
    # highlight top
    for x in range(5, 11):
        if (x % 2) == 0: leaf(x, 3, (96, 156, 70)); leaf(x, 4, (80, 136, 58))
    put(1, 1, c)

    cell("rock_s", 2, 1)
    r = img(16, 16, (86, 130, 60))
    rect(r, 3, 8, 13, 15, (120, 124, 128)); rect(r, 3, 8, 8, 15, (140, 144, 148)); rect(r, 3, 8, 13, 10, (100, 104, 110))
    put(2, 1, r)
    cell("rock_b", 3, 1)
    r2 = img(16, 16, (86, 130, 60))
    rect(r2, 2, 5, 15, 16, (110, 114, 120)); rect(r2, 2, 5, 8, 16, (130, 134, 140)); rect(r2, 2, 5, 15, 8, (90, 94, 102))
    px(r2, 5, 7, (150, 154, 158)); px(r2, 6, 6, (150, 154, 158))
    put(3, 1, r2)
    cell("bush", 4, 1)
    b = img(16, 16, (86, 130, 60))
    for y in range(6, 16):
        for x in range(1, 15):
            if (x * 11 + y * 7) % 9 < 4: px(b, x, y, (52, 96, 44) if (x + y) % 2 else (66, 118, 50))
    px(b, 8, 7, (96, 148, 66))
    put(4, 1, b)
    cell("stump", 5, 1)
    st = img(16, 16, (86, 130, 60))
    rect(st, 4, 8, 12, 15, (112, 76, 42)); rect(st, 4, 8, 12, 9, (150, 112, 66)); px(st, 7, 8, (170, 132, 82))
    put(5, 1, st)

    # ---- town (row 2) ----
    cell("floor", 0, 2)
    fl = img(16, 16)
    noise_fill(fl, 0, 0, 16, 16, (188, 186, 190), [(178, 176, 182), (198, 196, 200)], rng)
    for i in range(16):
        if i % 8 == 0: hline(fl, 0, 16, i, (150, 148, 156))
    for i in range(16):
        if i % 8 == 0:
            for y in range(16): px(fl, i, y, (150, 148, 156))
    put(0, 2, fl)
    cell("floor2", 1, 2)
    fl2 = img(16, 16)
    noise_fill(fl2, 0, 0, 16, 16, (176, 174, 180), [(166, 164, 172), (188, 186, 192)], rng)
    for i in range(16):
        if i % 8 == 4: hline(fl2, 0, 16, i, (144, 142, 150))
    put(1, 2, fl2)
    cell("cobble", 2, 2)
    cb = img(16, 16, (140, 134, 128))
    stones = [(0, 0, 8, 8), (8, 0, 16, 7), (0, 8, 7, 16), (7, 7, 16, 16), (8, 8, 11, 11)]
    for s in stones:
        rect(cb, s[0], s[1], s[2], s[3], (162, 156, 150))
        rect(cb, s[0], s[1], s[0] + 1, s[3], (180, 174, 168))
        rect(cb, s[0], s[3] - 1, s[2], s[3], (128, 122, 118))
    put(2, 2, cb)
    cell("wall", 3, 2)
    wl = img(16, 16)
    noise_fill(wl, 0, 0, 16, 16, (196, 186, 164), [(188, 178, 156), (204, 194, 172)], rng)
    for y in range(16):
        if y % 8 == 0: hline(wl, 0, 16, y, (168, 158, 138))
        elif y % 8 == 4: hline(wl, 0, 16, y, (176, 166, 146))
    px(wl, 0, 0, (150, 140, 122))
    put(3, 2, wl)
    cell("wall_top", 4, 2)
    wt = img(16, 16)
    noise_fill(wt, 0, 0, 16, 16, (196, 186, 164), [(188, 178, 156)], rng)
    rect(wt, 0, 0, 16, 3, (206, 198, 176)); hline(wt, 0, 16, 4, (160, 150, 132))
    put(4, 2, wt)
    cell("wall_win", 5, 2)
    ww = img(16, 16)
    noise_fill(ww, 0, 0, 16, 16, (196, 186, 164), [(188, 178, 156)], rng)
    outline_rect(ww, 4, 5, 12, 12, (96, 70, 40)); rect(ww, 5, 6, 11, 11, (60, 78, 96))
    hline(ww, 5, 11, 8, (110, 132, 150)); px(ww, 8, 6, (110, 132, 150)); px(ww, 8, 9, (110, 132, 150)); px(ww, 8, 10, (110, 132, 150))
    put(5, 2, ww)
    cell("door", 6, 2)
    dr = img(16, 16, (150, 142, 130))
    rect(dr, 4, 2, 12, 16, (110, 74, 42)); rect(dr, 4, 2, 6, 16, (130, 90, 52)); outline_rect(dr, 4, 2, 12, 16, (78, 52, 30))
    px(dr, 9, 9, (220, 190, 120))
    put(6, 2, dr)
    cell("roof", 7, 2)
    rf = img(16, 16)
    for y in range(16):
        base = (168, 74, 52) if y % 8 < 4 else (158, 66, 46)
        for x in range(16):
            px(rf, x, y, shade(base, 1.0 + 0.05 * ((x + y) % 3 - 1)))
        hline(rf, 0, 16, y, (120, 52, 38)) if y % 8 == 4 else None
    hline(rf, 0, 16, 0, (200, 100, 72))
    put(7, 2, rf)
    cell("roof_edge", 8, 2)
    re_ = img(16, 16)
    for y in range(16):
        base = (150, 58, 42) if y % 8 < 4 else (140, 52, 38)
        for x in range(16):
            px(re_, x, y, shade(base, 1.0 + 0.05 * ((x + y) % 3 - 1)))
    hline(re_, 0, 16, 15, (110, 42, 32))
    put(8, 2, re_)
    cell("lantern", 9, 2)
    ln = img(16, 16, (150, 142, 130))
    rect(ln, 6, 3, 10, 4, (70, 66, 72)); rect(ln, 5, 6, 11, 13, (70, 66, 72))
    rect(ln, 6, 6, 10, 12, (255, 214, 120)); rect(ln, 7, 7, 9, 10, (255, 240, 180))
    put(9, 2, ln)
    cell("sign", 10, 2)
    sg = img(16, 16, (150, 142, 130))
    rect(sg, 7, 2, 9, 14, (110, 74, 42)); rect(sg, 3, 4, 13, 9, (128, 88, 50)); outline_rect(sg, 3, 4, 13, 9, (88, 60, 34))
    px(sg, 5, 6, (200, 170, 110)); px(sg, 9, 6, (200, 170, 110))
    put(10, 2, sg)
    cell("crate", 11, 2)
    cr = img(16, 16, (150, 142, 130))
    rect(cr, 3, 6, 13, 16, (150, 110, 60)); rect(cr, 3, 6, 8, 16, (170, 128, 72))
    for y in (6, 16):
        hline(cr, 3, 13, y, (110, 80, 42))
    px(cr, 8, 6, (110, 80, 42)); px(cr, 8, 15, (110, 80, 42))
    put(11, 2, cr)
    cell("barrel", 12, 2)
    br = img(16, 16, (150, 142, 130))
    rect(br, 3, 5, 13, 16, (132, 96, 52)); rect(br, 3, 5, 7, 16, (152, 112, 62))
    for y in (5, 16):
        hline(br, 3, 13, y, (100, 72, 38))
    put(12, 2, br)
    cell("bench", 13, 2)
    bn = img(16, 16, (150, 142, 130))
    rect(bn, 2, 9, 14, 12, (150, 108, 62)); rect(bn, 3, 12, 5, 16, (120, 86, 48)); rect(bn, 11, 12, 13, 16, (120, 86, 48))
    put(13, 2, bn)
    # fountain quadrants 14,2 TL / 15,2 TR / 14,3 BL / 15,3 BR
    fq = [
        ("fount_tl", 14, 2, 0, 0), ("fount_tr", 15, 2, 8, 0),
        ("fount_bl", 14, 3, 0, 8), ("fount_br", 15, 3, 8, 8),
    ]
    for name, cx, cy, ox, oy in fq:
        cell(name, cx, cy)
        f = img(16, 16, (150, 142, 130))
        # basin rim ring (inner corner piece)
        rect(f, ox, oy, ox + 8, oy + 8, (208, 202, 190))
        if ox == 0:
            rect(f, 0, oy + 1, 2, oy + 8, (168, 162, 152))
        else:
            rect(f, 14, oy + 1, 16, oy + 8, (168, 162, 152))
        if oy == 0:
            rect(f, ox + 1, 0, ox + 8, 2, (168, 162, 152))
        else:
            rect(f, ox + 1, 14, ox + 8, 16, (168, 162, 152))
        # water inside
        rect(f, ox + 2, oy + 2, ox + 8, oy + 8, (86, 148, 196))
        rect(f, ox + 2, oy + 2, ox + 6, oy + 6, (110, 168, 210))
        put(cx, cy, f)

    # ---- dungeon (row 3) ----
    cell("dfloor", 0, 3)
    df = img(16, 16)
    noise_fill(df, 0, 0, 16, 16, (92, 100, 120), [(84, 92, 112), (102, 110, 130)], rng)
    hline(df, 0, 16, 0, (70, 78, 98)); px(df, 0, 0, (70, 78, 98))
    for i in range(16):
        if i % 8 == 0:
            for y in range(16): px(df, i, y, (72, 80, 100))
    put(0, 3, df)
    cell("dfloor2", 1, 3)
    df2 = img(16, 16)
    noise_fill(df2, 0, 0, 16, 16, (84, 92, 112), [(76, 84, 104), (94, 102, 122)], rng)
    # cracks
    for i in range(2):
        x0 = rng.randrange(1, 10); y0 = rng.randrange(1, 12)
        for k in range(4):
            px(df2, x0 + k, y0 + (k % 2), (58, 66, 86))
    put(1, 3, df2)
    cell("dwall", 2, 3)
    dw = img(16, 16)
    noise_fill(dw, 0, 0, 16, 16, (110, 122, 148), [(100, 112, 138), (120, 132, 158)], rng)
    for y in range(16):
        if y % 8 == 0: hline(dw, 0, 16, y, (86, 96, 122))
    hline(dw, 0, 16, 0, (138, 150, 174))
    put(2, 3, dw)
    cell("dwall_top", 3, 3)
    dtt = img(16, 16)
    noise_fill(dtt, 0, 0, 16, 16, (110, 122, 148), [(100, 112, 138)], rng)
    rect(dtt, 0, 0, 16, 3, (144, 156, 180)); hline(dtt, 0, 16, 4, (84, 94, 120))
    put(3, 3, dtt)
    cell("pillar", 4, 3)
    pl = img(16, 16, (92, 100, 120))
    rect(pl, 3, 2, 13, 15, (128, 138, 160)); rect(pl, 3, 2, 6, 15, (148, 158, 178))
    rect(pl, 2, 1, 14, 3, (96, 106, 128)); rect(pl, 2, 14, 14, 16, (96, 106, 128))
    px(pl, 4, 8, (170, 178, 194))
    put(4, 3, pl)
    cell("crack", 5, 3)
    ck = img(16, 16, (92, 100, 120))
    for i in range(8):
        x = 2 + i; px(ck, x, 8 - (i % 3), (62, 70, 90)); px(ck, x, 9, (62, 70, 90))
    px(ck, 10, 7, (62, 70, 90)); px(ck, 5, 11, (62, 70, 90)); px(ck, 6, 10, (62, 70, 90))
    put(5, 3, ck)
    cell("rubble", 6, 3)
    rb = img(16, 16, (92, 100, 120))
    for i in range(10):
        x = rng.randrange(2, 13); y = rng.randrange(7, 15)
        rect(rb, x, y, min(x + rng.randrange(2, 4), 15), min(y + rng.randrange(1, 3), 15), rng.choice([(120, 130, 152), (104, 114, 138), (134, 144, 164)]))
    put(6, 3, rb)
    cell("stairs", 7, 3)
    st_ = img(16, 16, (92, 100, 120))
    for i in range(4):
        rect(st_, 1, 2 + i * 3, 15, 4 + i * 3, (130, 140, 162))
        rect(st_, 1, 2 + i * 3, 3, 4 + i * 3, (150, 160, 180))
    put(7, 3, st_)
    cell("rune", 8, 3)
    rn = img(16, 16, (92, 100, 120))
    outline_rect(rn, 4, 4, 12, 12, (150, 190, 230))
    px(rn, 8, 6, (150, 190, 230)); px(rn, 6, 8, (150, 190, 230)); px(rn, 10, 8, (150, 190, 230)); px(rn, 8, 10, (150, 190, 230))
    put(8, 3, rn)
    cell("arena", 9, 3)
    ar = img(16, 16)
    noise_fill(ar, 0, 0, 16, 16, (70, 74, 92), [(62, 66, 84), (78, 82, 100)], rng)
    hline(ar, 0, 16, 0, (54, 58, 76))
    put(9, 3, ar)
    cell("arena_edge", 10, 3)
    ae = img(16, 16)
    noise_fill(ae, 0, 0, 16, 16, (84, 88, 106), [(76, 80, 98), (92, 96, 114)], rng)
    hline(ae, 0, 16, 0, (110, 114, 132))
    put(10, 3, ae)

    S.save(path)
    return T

# ---------- character dolls ----------
PALETTES = {
    "player": dict(skin=(238, 200, 168), hair=(88, 92, 104), shirt=(110, 128, 158), shirt_d=(90, 106, 134),
                   pants=(52, 54, 66), boots=(64, 52, 44), belt=(96, 72, 40), metal=(200, 204, 216), blade=(214, 228, 244), grip=(120, 80, 40)),
    "kirito": dict(skin=(238, 200, 168), hair=(40, 40, 48), shirt=(34, 36, 44), shirt_d=(26, 28, 34),
                   pants=(40, 42, 52), boots=(30, 32, 40), belt=(70, 70, 80), metal=(160, 164, 176), blade=(214, 228, 244), grip=(80, 60, 40)),
    "klein": dict(skin=(240, 196, 160), hair=(150, 84, 56), shirt=(196, 96, 80), shirt_d=(170, 80, 66),
                  pants=(70, 62, 60), boots=(90, 70, 50), belt=(110, 84, 50), metal=(180, 184, 196), blade=(214, 228, 244), grip=(90, 66, 40)),
    "asuna": dict(skin=(244, 208, 178), hair=(176, 122, 82), shirt=(236, 236, 240), shirt_d=(204, 180, 188),
                  pants=(204, 180, 188), boots=(120, 96, 88), belt=(160, 60, 60), metal=(200, 204, 216), blade=(214, 228, 244), grip=(140, 90, 60)),
    "merchant": dict(skin=(236, 198, 162), hair=(120, 96, 74), shirt=(90, 138, 100), shirt_d=(74, 118, 84),
                     pants=(88, 80, 70), boots=(80, 62, 46), belt=(104, 82, 48), metal=(180, 184, 196), blade=(214, 228, 244), grip=(110, 82, 48)),
    "blacksmith": dict(skin=(232, 190, 154), hair=(70, 66, 66), shirt=(130, 108, 82), shirt_d=(110, 90, 68),
                       pants=(66, 62, 64), boots=(56, 48, 44), belt=(80, 66, 48), metal=(150, 154, 166), blade=(214, 228, 244), grip=(96, 72, 44)),
    "liaison": dict(skin=(238, 202, 170), hair=(190, 168, 110), shirt=(74, 104, 160), shirt_d=(60, 88, 140),
                    pants=(56, 62, 80), boots=(60, 54, 48), belt=(90, 74, 48), metal=(190, 194, 206), blade=(214, 228, 244), grip=(100, 78, 46)),
    "villager": [
        dict(skin=(240, 202, 168), hair=(96, 66, 50), shirt=(176, 84, 88), shirt_d=(150, 68, 72), pants=(86, 78, 70), boots=(86, 66, 48), belt=(100, 80, 48), metal=(180, 184, 196), blade=(214, 228, 244), grip=(110, 82, 48)),
        dict(skin=(232, 196, 160), hair=(60, 62, 70), shirt=(96, 128, 170), shirt_d=(78, 108, 148), pants=(70, 66, 74), boots=(70, 58, 48), belt=(90, 74, 48), metal=(180, 184, 196), blade=(214, 228, 244), grip=(110, 82, 48)),
        dict(skin=(244, 206, 170), hair=(176, 146, 104), shirt=(150, 128, 88), shirt_d=(128, 108, 72), pants=(84, 74, 64), boots=(80, 62, 46), belt=(96, 76, 46), metal=(180, 184, 196), blade=(214, 228, 244), grip=(110, 82, 48)),
        dict(skin=(236, 200, 164), hair=(66, 70, 80), shirt=(96, 150, 120), shirt_d=(78, 128, 100), pants=(74, 68, 76), boots=(74, 60, 48), belt=(100, 80, 48), metal=(180, 184, 196), blade=(214, 228, 244), grip=(110, 82, 48)),
        dict(skin=(238, 202, 166), hair=(70, 58, 50), shirt=(190, 140, 90), shirt_d=(166, 118, 72), pants=(76, 70, 78), boots=(78, 62, 46), belt=(90, 74, 48), metal=(180, 184, 196), blade=(214, 228, 244), grip=(110, 82, 48)),
        dict(skin=(242, 204, 172), hair=(140, 140, 150), shirt=(140, 108, 150), shirt_d=(118, 88, 128), pants=(78, 72, 80), boots=(82, 64, 48), belt=(96, 76, 46), metal=(180, 184, 196), blade=(214, 228, 244), grip=(110, 82, 48)),
    ],
}

COLS = {"idle": 2, "walk": 4, "attack": 4, "hurt": 1, "dodge": 3, "death": 4}
COLMAP = [("idle", 0), ("walk", 2), ("attack", 6), ("hurt", 10), ("dodge", 11), ("death", 14)]
DIRS = ["down", "left", "right", "up"]

def shadow(im, cx, cy, rx=7, ry=2):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            dx = (x - cx) / (rx + 0.01); dy = (y - cy) / (ry + 0.01)
            if dx * dx + dy * dy <= 1.0:
                px(im, x, y, (20, 24, 30), 70)

def doll_frame(pal, dirn, anim, idx, S=32):
    """Draw one frame of a humanoid. S=32 normal, 64 boss."""
    im = img(S, S)
    s = S // 32  # scale
    def X(v): return v * s
    P = pal
    skin, hair = P["skin"], P["hair"]
    shirt, shirt_d = P["shirt"], P["shirt_d"]
    pants, boots, belt = P["pants"], P["boots"], P["belt"]
    out = shade(shirt, 0.55)

    # ---------- shadow ----------
    shadow(im, S // 2, X(29), X(7), X(2))

    def leg(x0, lift, is_front=True):
        x1 = x0 + X(3)
        rect(im, x0, X(22) - lift, x1, X(26) - lift, pants)
        rect(im, x0, X(22) - lift, x0 + X(1), X(26) - lift, shade(pants, 1.15))
        rect(im, x0 - X(1), X(26) - lift, x1 + X(1), X(28) - lift, boots)
        rect(im, x0 - X(1), X(28) - lift, x1 + X(1), X(29) - lift, shade(boots, 0.7))

    def torso(y0=X(14), y1=X(22)):
        rect(im, X(10), y0, X(22), y1, shirt)
        rect(im, X(10), y0, X(12), y1, shirt_d)
        rect(im, X(20), y0, X(22), y1, shade(shirt, 0.8))
        outline_rect(im, X(10), y0, X(22), y1, out)
        # belt
        rect(im, X(10), y1 - X(2), X(22), y1, belt)
        px(im, S // 2, y1 - X(1), (222, 190, 110))

    def arm(x0, x1, y0, y1, hand=None):
        rect(im, x0, y0, x1, y1, shirt)
        rect(im, x0, y0, x0 + X(1), y1, shirt_d)
        if hand is not None:
            rect(im, x0 - X(1), hand, x1 + X(1), hand + X(2), skin)

    def head(dirn, y0=X(7), y1=X(15)):
        cx0, cx1 = X(11), X(21)
        # face
        rect(im, cx0, y0, cx1, y1, skin)
        rect(im, cx0, y1 - X(2), cx1, y1, shade(skin, 0.9))
        # hair
        if dirn == "up":
            rect(im, cx0 - X(1), y0 - X(1), cx1 + X(1), y1 - X(3), hair)
            rect(im, cx0 - X(1), y0 - X(1), cx0 + X(2), y1 - X(1), shade(hair, 1.2))
            rect(im, cx0 - X(1), y1 - X(5), cx1 + X(1), y1 - X(3), hair)
        elif dirn == "down":
            rect(im, cx0 - X(1), y0 - X(1), cx1 + X(1), y0 + X(4), hair)
            rect(im, cx0 - X(1), y0 - X(1), cx1 + X(1), y0 + X(1), shade(hair, 1.3))
            # fringe
            rect(im, cx0 - X(1), y0 + X(3), cx1 + X(1), y0 + X(5), hair)
            px(im, cx0 + X(1), y0 + X(4), hair); px(im, cx1 - X(1), y0 + X(4), hair)
            # eyes
            px(im, cx0 + X(3), y0 + X(4), (40, 40, 50)); px(im, cx0 + X(7), y0 + X(4), (40, 40, 50))
        else:  # left/right profile
            rect(im, cx0 - X(1), y0 - X(1), cx1 + X(1), y0 + X(4), hair)
            if dirn == "left":
                rect(im, cx0 - X(1), y0, cx1 - X(2), y1 - X(2), hair)  # back of head
                px(im, cx1 - X(3), y0 + X(4), (40, 40, 50))
                px(im, cx1 - X(2), y0 + X(2), hair)
            else:
                rect(im, cx0 + X(2), y0, cx1 + X(1), y1 - X(2), hair)
                px(im, cx0 + X(3), y0 + X(4), (40, 40, 50))
                px(im, cx0 + X(2), y0 + X(2), hair)

    def scabbard(dirn):
        # sword at left hip (viewer's left)
        grip, metal = P["grip"], P["metal"]
        if dirn == "down":
            rect(im, X(9), X(16), X(11), X(24), grip)
            rect(im, X(9), X(16), X(10), X(24), shade(grip, 1.3))
            rect(im, X(8), X(15), X(12), X(17), metal)
        elif dirn == "up":
            rect(im, X(21), X(16), X(23), X(24), grip)
            rect(im, X(22), X(16), X(23), X(24), shade(grip, 1.3))
            rect(im, X(20), X(15), X(24), X(17), metal)
        elif dirn == "left":
            rect(im, X(11), X(16), X(13), X(24), grip)
            rect(im, X(12), X(16), X(13), X(24), shade(grip, 1.3))
        else:
            rect(im, X(11), X(16), X(13), X(24), grip)

    def sword(dirn, phase):
        """Sword in hand; phase 0..3 across swing."""
        b, g, m = P["blade"], P["grip"], P["metal"]
        if dirn == "down":
            # swing from overhead to lower-right
            pts = [(X(16), X(2), X(18), X(8)), (X(17), X(4), X(23), X(11)), (X(18), X(9), X(26), X(16)), (X(17), X(14), X(24), X(21))]
            x0, y0, x1, y1 = pts[phase]
            rect(im, x0, y0, x1, y1, b)
            rect(im, x1 - X(1), y0, x1, y1, shade(b, 0.8))
            rect(im, x0 - X(1), y1 - X(2), x0 + X(2), y1 + X(2), g)
            rect(im, x0 - X(1), y1 + X(1), x0 + X(2), y1 + X(2), m)
        elif dirn == "up":
            pts = [(X(16), X(2), X(18), X(8)), (X(15), X(4), X(9), X(11)), (X(14), X(9), X(6), X(16)), (X(15), X(14), X(8), X(21))]
            x0, y0, x1, y1 = pts[phase]
            rect(im, x0, y0, x1, y1, b)
            rect(im, x0, y0, x0 + X(1), y1, shade(b, 0.8))
            rect(im, x0 - X(1), y1 - X(2), x0 + X(2), y1 + X(2), g)
        else:
            fwd = 1 if dirn == "right" else -1
            # horizontal sweep at torso height
            pts = [(-X(6), X(10)), (-X(2), X(12)), (X(3), X(13)), (X(8), X(12))]
            dx, dy = pts[phase]
            cx = S // 2 + dx * fwd
            cy = S // 2 - X(2) + dy
            rect(im, cx, cy, cx + X(10) * fwd, cy + X(2), b)
            rect(im, cx, cy, cx + X(10) * fwd, cy + X(1), shade(b, 0.75))
            rect(im, cx - X(1) * fwd, cy - X(1), cx + X(1) * fwd, cy + X(2), g)

    # ================= pose assembly =================
    if anim == "idle":
        bob = (idx % 2) * X(1)
        leg(X(13), bob, True); leg(X(17), bob, False)
        torso(y0=X(14) - bob)
        arm(X(8), X(10), X(15) - bob, X(20) - bob, hand=X(20) - bob - X(1))
        arm(X(22), X(24), X(15) - bob, X(20) - bob, hand=X(20) - bob - X(1))
        head(dirn, y0=X(7) - bob, y1=X(15) - bob)
        scabbard(dirn)
    elif anim == "walk":
        seq = [0, 1, 2, 1]
        ph = seq[idx]
        if dirn in ("down", "up"):
            l1 = [X(1), 0, -X(1), 0][ph]; l2 = [-X(1), 0, X(1), 0][ph]
            leg(X(13), l1, True); leg(X(17), l2, False)
            torso()
            arm(X(8), X(10), X(15), X(20), hand=X(20) - X(1) + (l2 if dirn == "down" else -l2))
            arm(X(22), X(24), X(15), X(20), hand=X(20) - X(1) + (l1 if dirn == "down" else -l1))
            head(dirn)
            scabbard(dirn)
        else:
            fwd = 1 if dirn == "right" else -1
            l1 = [X(1), 0, -X(1), 0][ph]; l2 = [-X(1), 0, X(1), 0][ph]
            leg(X(13) + l1 * fwd, X(1) - abs(l1), True)
            leg(X(17) + l2 * fwd, X(1) - abs(l2), False)
            torso()
            arm(X(8), X(10), X(15), X(20), hand=X(19))
            arm(X(22), X(24), X(15), X(20), hand=X(19))
            head(dirn)
            scabbard(dirn)
    elif anim == "attack":
        ph = idx
        if ph == 0:
            leg(X(13), 0, True); leg(X(17), 0, False)
            torso()
            arm(X(8), X(10), X(12), X(18), hand=X(17))
            arm(X(22), X(24), X(12), X(18), hand=X(17))
            head(dirn)
            sword(dirn, 0)
        elif ph == 1:
            leg(X(13), X(1), True); leg(X(17), X(1), False)
            torso()
            arm(X(8), X(10), X(14), X(19), hand=X(18))
            arm(X(22), X(24), X(14), X(19), hand=X(18))
            head(dirn)
            sword(dirn, 1)
        elif ph == 2:
            leg(X(12), 0, True); leg(X(18), 0, False)
            torso()
            arm(X(6), X(9), X(15), X(20), hand=X(19))
            arm(X(22), X(25), X(14), X(19), hand=X(18))
            head(dirn)
            sword(dirn, 2)
        else:
            leg(X(13), 0, True); leg(X(17), 0, False)
            torso()
            arm(X(8), X(10), X(15), X(20), hand=X(19))
            arm(X(23), X(25), X(15), X(20), hand=X(19))
            head(dirn)
            sword(dirn, 3)
    elif anim == "hurt":
        leg(X(13) - X(1), 0, True); leg(X(17) + X(1), 0, False)
        torso(y0=X(15), y1=X(23))
        arm(X(7), X(9), X(13), X(18), hand=X(17))
        arm(X(23), X(25), X(13), X(18), hand=X(17))
        head(dirn, y0=X(8), y1=X(16))
        scabbard(dirn)
        # impact flash
        for (fx, fy) in [(X(10), X(15)), (X(21), X(15)), (X(8), X(18)), (X(23), X(18))]:
            px(im, fx, fy, (255, 255, 255), 200)
    elif anim == "dodge":
        ph = idx
        if dirn in ("down", "up"):
            lean = X(2) if dirn == "down" else -X(2)
            ghost = -X(3) if dirn == "down" else X(3)
            for g in range(3 - ph):
                o = ghost * (g + 1)
                rect(im, X(11) + o, X(8) + o, X(21) + o, X(20) + o, (180, 210, 240), 50)
            leg(X(13) + lean, X(1), True); leg(X(17) + lean, 0, False)
            torso(y0=X(15), y1=X(23))
            arm(X(9) + lean, X(11) + lean, X(14), X(19), hand=X(18))
            arm(X(21) + lean, X(23) + lean, X(14), X(19), hand=X(18))
            head(dirn, y0=X(8), y1=X(16))
        else:
            fwd = 1 if dirn == "right" else -1
            for g in range(3 - ph):
                o = -X(3) * fwd * (g + 1)
                rect(im, X(11) + o, X(8), X(21) + o, X(20), (180, 210, 240), 50)
            leg(X(13) + X(2) * fwd, X(1), True); leg(X(17) - X(2) * fwd, X(1), False)
            torso(y0=X(15), y1=X(23))
            arm(X(9), X(11), X(14), X(19), hand=X(18))
            arm(X(21), X(23), X(14), X(19), hand=X(18))
            head(dirn, y0=X(8), y1=X(16))
    elif anim == "death":
        ph = idx
        if ph == 0:
            leg(X(13), X(2), True); leg(X(17), X(2), False)
            torso(y0=X(17), y1=X(25))
            arm(X(8), X(10), X(16), X(21), hand=X(20))
            arm(X(22), X(24), X(16), X(21), hand=X(20))
            head(dirn, y0=X(10), y1=X(18))
        elif ph == 1:
            # 45 degree fall: body diagonal
            for k in range(6):
                rect(im, X(10) + k * X(2), X(16) + k * X(2), X(22) + k * X(2), X(20) + k * X(2), shirt)
            rect(im, X(8), X(14), X(14), X(18), skin)
            rect(im, X(8), X(14), X(14), X(15), hair)
        else:
            # lying
            rect(im, X(5), X(26), X(27), X(30), pants)
            rect(im, X(9), X(22), X(27), X(27), shirt)
            rect(im, X(9), X(22), X(27), X(23), shirt_d)
            rect(im, X(23), X(22), X(30), X(25), skin)
            rect(im, X(24), X(21), X(30), X(23), hair)
            if ph == 3:
                px(im, X(25), X(23), (60, 60, 66)); px(im, X(28), X(23), (60, 60, 66))
            rect(im, X(5), X(29), X(27), X(30), boots)
    return im

def make_character(path, pal, S=32):
    W = 18 * S; H = 4 * S
    sheet = Image.new("RGBA", (W, H))
    for di, dirn in enumerate(DIRS):
        for anim, col in COLMAP:
            n = COLS[anim]
            for i in range(n):
                f = doll_frame(pal, dirn, anim, i, S)
                sheet.paste(f, ((col + i) * S, di * S))
    sheet.save(path)

# ---------- enemies ----------
def make_boar(path):
    S = 32
    sheet = Image.new("RGBA", (18 * S, 4 * S))
    body = (128, 92, 62); body_d = (104, 72, 48); dark = (66, 46, 34)
    for di, dirn in enumerate(DIRS):
        for anim, col in COLMAP:
            for i in range(COLS[anim]):
                im = img(S, S)
                shadow(im, 16, 28, 8, 2)
                ph = i
                if anim == "idle":
                    bob = (i % 2)
                    rect(im, 7, 14 - bob, 25, 24 - bob, body)
                    rect(im, 7, 14 - bob, 13, 24 - bob, body_d)
                    rect(im, 7, 14 - bob, 25, 17 - bob, (150, 112, 76))
                    rect(im, 20, 10 - bob, 27, 15 - bob, body)  # head
                    rect(im, 20, 10 - bob, 27, 12 - bob, (150, 112, 76))
                    px(im, 25, 12 - bob, (40, 40, 50))
                    rect(im, 22, 8 - bob, 24, 10 - bob, (238, 232, 220))  # tusk
                    for lx in (9, 16):
                        rect(im, lx, 22 - bob, lx + 3, 28, dark)
                    rect(im, 22, 22 - bob, 25, 28, dark)
                elif anim == "walk":
                    seq = [0, 1, 2, 1]
                    ph = seq[i]
                    rect(im, 7, 14, 25, 24, body)
                    rect(im, 7, 14, 13, 24, body_d)
                    rect(im, 20, 10, 27, 15, body)
                    px(im, 25, 12, (40, 40, 50))
                    rect(im, 22, 8, 24, 10, (238, 232, 220))
                    l1 = [1, 0, -1, 0][ph]; l2 = [-1, 0, 1, 0][ph]
                    for lx, l in ((9, l1), (16, l2)):
                        rect(im, lx + l, 22, lx + l + 3, 28, dark)
                    rect(im, 22 - l1, 22, 25 - l1, 28, dark)
                elif anim == "attack":
                    # windup head-down then short charge
                    rect(im, 7, 14 + ph, 25, 24 + ph, body)
                    rect(im, 7, 14 + ph, 13, 24 + ph, body_d)
                    rect(im, 18 + ph * 2, 12 + ph, 25 + ph * 2, 17 + ph, body)
                    rect(im, 18 + ph * 2, 12 + ph, 25 + ph * 2, 14 + ph, (150, 112, 76))
                    rect(im, 20 + ph * 2, 6 + ph, 22 + ph * 2, 9 + ph, (238, 232, 220))
                    if ph == 1:
                        px(im, 25, 15, (255, 70, 70), 180)
                    for lx in (9, 16):
                        rect(im, lx, 22 + ph, lx + 3, 28, dark)
                elif anim == "hurt":
                    rect(im, 6, 14, 24, 24, body)
                    rect(im, 6, 14, 12, 24, body_d)
                    rect(im, 19, 10, 26, 15, body)
                    px(im, 24, 12, (40, 40, 50))
                    for (fx, fy) in [(8, 16), (22, 16)]:
                        px(im, fx, fy, (255, 255, 255), 200)
                elif anim == "dodge":  # alert pose
                    rect(im, 7, 13, 25, 23, body)
                    rect(im, 7, 13, 13, 23, body_d)
                    rect(im, 19, 8, 26, 13, body)
                    rect(im, 19, 8, 26, 10, (150, 112, 76))
                    px(im, 23, 10, (200, 60, 60))
                    rect(im, 12, 3 + (i % 2), 14, 6 + (i % 2), (255, 120, 120))  # ! mark
                elif anim == "death":
                    rect(im, 5, 18 + ph, 27, 22 + ph, body)
                    rect(im, 5, 18 + ph, 13, 22 + ph, body_d)
                    rect(im, 20, 14 + ph, 27, 18 + ph, body)
                    rect(im, 22, 10 + ph, 24, 13 + ph, (238, 232, 220))
                    rect(im, 5, 22 + ph, 27, 24 + ph, dark)
                    if ph == 3:
                        px(im, 24, 16, (40, 40, 50))
                sheet.paste(im, ((col + i) * S, di * S))
    sheet.save(path)

def make_wolf(path):
    S = 32
    sheet = Image.new("RGBA", (18 * S, 4 * S))
    fur = (122, 124, 134); fur_d = (98, 100, 112); fur_l = (150, 152, 162)
    dark = (52, 54, 64)
    for di, dirn in enumerate(DIRS):
        for anim, col in COLMAP:
            for i in range(COLS[anim]):
                im = img(S, S)
                shadow(im, 16, 28, 8, 2)
                ph = i
                if anim == "idle":
                    bob = (i % 2)
                    rect(im, 7, 13 - bob, 25, 22 - bob, fur)
                    rect(im, 7, 13 - bob, 12, 22 - bob, fur_d)
                    rect(im, 20, 8 - bob, 27, 14 - bob, fur)  # head
                    rect(im, 20, 8 - bob, 27, 10 - bob, fur_l)
                    px(im, 25, 10 - bob, (240, 200, 80))
                    rect(im, 9, 4 - bob, 13, 8 - bob, fur_d)  # ear
                    rect(im, 4, 14 - bob, 7, 20 - bob, fur_d)  # tail
                    for lx in (9, 16):
                        rect(im, lx, 21 - bob, lx + 3, 27, dark)
                    rect(im, 22, 21 - bob, 25, 27, dark)
                elif anim == "walk":
                    seq = [0, 1, 2, 1]
                    ph = seq[i]
                    rect(im, 7, 13, 25, 22, fur)
                    rect(im, 7, 13, 12, 22, fur_d)
                    rect(im, 20, 8, 27, 14, fur)
                    px(im, 25, 10, (240, 200, 80))
                    rect(im, 9, 4, 13, 8, fur_d)
                    rect(im, 4, 14 - (ph % 2), 7, 20 - (ph % 2), fur_d)
                    l1 = [1, 0, -1, 0][ph]; l2 = [-1, 0, 1, 0][ph]
                    for lx, l in ((9, l1), (16, l2)):
                        rect(im, lx + l, 21, lx + l + 3, 27, dark)
                    rect(im, 22 - l1, 21, 25 - l1, 27, dark)
                elif anim == "attack":  # pounce
                    rect(im, 7 + ph, 11 - ph * 2, 25 + ph, 20 - ph * 2, fur)
                    rect(im, 7 + ph, 11 - ph * 2, 12 + ph, 20 - ph * 2, fur_d)
                    rect(im, 20 + ph * 2, 4 - ph * 2, 27 + ph * 2, 10 - ph * 2, fur)
                    rect(im, 20 + ph * 2, 4 - ph * 2, 27 + ph * 2, 6 - ph * 2, fur_l)
                    px(im, 26 + ph * 2, 7 - ph * 2, (240, 200, 80))
                    rect(im, 21 + ph * 2, 2 - ph * 2, 25 + ph * 2, 5 - ph * 2, (238, 232, 220))  # teeth
                    rect(im, 9 + ph, 20 - ph * 2, 12 + ph, 26, dark)
                    rect(im, 17 + ph, 20 - ph * 2, 20 + ph, 26, dark)
                elif anim == "hurt":
                    rect(im, 6, 13, 24, 22, fur)
                    rect(im, 6, 13, 11, 22, fur_d)
                    rect(im, 19, 8, 26, 14, fur)
                    px(im, 24, 10, (240, 200, 80))
                    px(im, 10, 16, (255, 255, 255), 200); px(im, 20, 16, (255, 255, 255), 200)
                elif anim == "dodge":  # alert
                    rect(im, 7, 12, 25, 21, fur)
                    rect(im, 7, 12, 12, 21, fur_d)
                    rect(im, 19, 7, 26, 13, fur)
                    px(im, 24, 9, (240, 200, 80))
                    rect(im, 9, 3, 13, 7, fur_d)
                    rect(im, 12, 1 + (i % 2), 14, 4 + (i % 2), (255, 120, 120))
                elif anim == "death":
                    rect(im, 5, 17 + ph, 27, 21 + ph, fur)
                    rect(im, 5, 17 + ph, 12, 21 + ph, fur_d)
                    rect(im, 20, 13 + ph, 27, 17 + ph, fur)
                    rect(im, 9, 11 + ph, 13, 15 + ph, fur_d)
                    if ph == 3:
                        px(im, 25, 15, (40, 40, 50))
                sheet.paste(im, ((col + i) * S, di * S))
    sheet.save(path)

def make_guardian(path):
    pal = dict(skin=(214, 216, 226), hair=(60, 60, 70), shirt=(96, 104, 128), shirt_d=(78, 86, 110),
               pants=(66, 70, 88), boots=(54, 56, 70), belt=(70, 74, 92), metal=(170, 178, 196), blade=(208, 214, 232), grip=(80, 76, 90))
    make_character(path, pal, 32)

def make_boss(path):
    pal = dict(skin=(176, 148, 120), hair=(110, 66, 48), shirt=(96, 66, 50), shirt_d=(78, 52, 40),
               pants=(60, 48, 42), boots=(44, 36, 32), belt=(120, 92, 40), metal=(200, 170, 90), blade=(168, 168, 190), grip=(96, 70, 40))
    make_character(path, pal, 64)

def make_dummy(path):
    S = 32
    sheet = Image.new("RGBA", (4 * S, S))
    for i in range(4):
        im = img(S, S)
        shadow(im, 16, 29, 6, 2)
        rect(im, 8, 5, 12, 9, (170, 120, 60))
        rect(im, 7, 9, 25, 11, (150, 100, 48))  # arms
        rect(im, 9, 9, 23, 27, (150, 100, 48))
        rect(im, 9, 9, 14, 27, (176, 124, 62))
        rect(im, 11, 11, 21, 21, (214, 190, 140))
        outline_rect(im, 11, 11, 21, 21, (170, 100, 60))
        rect(im, 15, 14, 17, 18, (170, 100, 60))
        rect(im, 10, 27, 14, 30, (110, 72, 34))
        rect(im, 18, 27, 22, 30, (110, 72, 34))
        if i % 2 == 1:
            px(im, 16, 12, (240, 220, 120))
        sheet.paste(im, (i * S, 0))
    sheet.save(path)

# ---------- objects & fx ----------
def make_chest(path):
    S = 32
    sheet = Image.new("RGBA", (2 * S, S))
    for f in range(2):
        im = img(S, S)
        shadow(im, 16, 29, 7, 2)
        rect(im, 7, 18, 25, 29, (128, 84, 46))
        rect(im, 7, 18, 13, 29, (150, 102, 58))
        rect(im, 7, 18, 25, 29 - (0 if f == 0 else 4), (128, 84, 46) if f == 0 else (120, 78, 44))
        if f == 1:
            rect(im, 7, 14, 25, 18, (146, 98, 56))
        rect(im, 13, 18, 19, 29, (214, 174, 96))
        px(im, 15, 23, (90, 58, 32)); px(im, 17, 23, (90, 58, 32))
        if f == 1:
            px(im, 14, 17, (255, 226, 120)); px(im, 18, 16, (255, 226, 120))
        sheet.paste(im, (f * S, 0))
    sheet.save(path)

def make_gate(path):
    S = 32
    sheet = Image.new("RGBA", (3 * S, S))
    for f in range(3):
        im = img(S, S)
        shadow(im, 16, 30, 8, 2)
        rect(im, 3, 4, 29, 7, (90, 100, 124))
        rect(im, 3, 4, 29, 30, (70, 80, 104))
        rect(im, 3, 4, 9, 30, (86, 96, 120))
        for y in range(6, 29, 4):
            hline(im, 4, 28, y, (56, 64, 88))
        px(im, 7, 24, (200, 190, 120))
        if f == 1:
            for x in (8, 12):
                for y in range(5, 29):
                    px(im, x, y, (150, 220, 255), 160)
        elif f == 2:
            rect(im, 3, 4, 29, 30, (30, 34, 52))
            rect(im, 3, 4, 9, 30, (44, 50, 70))
            for y in range(6, 29, 4):
                hline(im, 4, 28, y, (22, 26, 42))
        sheet.paste(im, (f * S, 0))
    sheet.save(path)

def make_seal(path):
    S = 32
    sheet = Image.new("RGBA", (2 * S, S))
    for f in range(2):
        im = img(S, S)
        shadow(im, 16, 29, 6, 2)
        rect(im, 8, 20, 24, 29, (96, 104, 128))
        rect(im, 8, 20, 12, 29, (112, 120, 144))
        for x0 in (8, 18):
            rect(im, x0, 26, x0 + 6, 29, (76, 84, 108))
        if f == 0:
            c = (140, 150, 180)
        else:
            c = (130, 230, 255)
        for y in range(7, 20):
            for x in range(9, 23):
                dx = (x - 16) / 7.0; dy = (y - 13.5) / 6.5
                if dx * dx + dy * dy < 1.0:
                    px(im, x, y, c if (x + y) % 3 else shade(c, 1.25))
        outline_rect(im, 11, 9, 21, 18, shade(c, 0.6))
        sheet.paste(im, (f * S, 0))
    sheet.save(path)

def make_crystal(path):
    S = 32
    sheet = Image.new("RGBA", (2 * S, S))
    for f in range(2):
        im = img(S, S)
        shadow(im, 16, 29, 5, 2)
        for y in range(6, 22):
            half = 4 + int(4 * (y - 6) / 16)
            for x in range(16 - half, 16 + half):
                if x == 16 - half or x == 16 + half - 1:
                    px(im, x, y, (200, 240, 255), 255)
                elif (x + y + f) % 4 == 0:
                    px(im, x, y, (160, 226, 255), 255)
                else:
                    px(im, x, y, (90, 170, 230), 235)
        px(im, 16, 8 + f, (255, 255, 255), 255)
        rect(im, 11, 20, 21, 23, (110, 118, 142))
        rect(im, 12, 23, 20, 29, (96, 104, 128))
        sheet.paste(im, (f * S, 0))
    sheet.save(path)

def make_torch(path):
    S = 32
    sheet = Image.new("RGBA", (2 * S, S))
    for f in range(2):
        im = img(S, S)
        shadow(im, 16, 29, 4, 2)
        rect(im, 13, 14, 19, 29, (110, 74, 40))
        rect(im, 13, 14, 15, 29, (132, 92, 52))
        rect(im, 11, 11, 21, 15, (90, 90, 100))
        flame = [(16, 9), (15, 10), (17, 10), (14, 11), (18, 11), (16, 11)]
        for x, y in flame:
            px(im, x, y, (255, 170, 60))
        px(im, 16, 9 + f % 2, (255, 230, 140))
        px(im, 16, 8, (255, 210, 110), 180)
        px(im, 15, 8, (255, 150, 50), 120)
        sheet.paste(im, (f * S, 0))
    sheet.save(path)

def make_slash(path, big=False):
    S = 64 if big else 32
    sheet = Image.new("RGBA", (4 * S, S))
    for f in range(4):
        im = img(S, S)
        c = S // 2
        r0 = (S // 2) - 4
        seg = 50
        for t in range(seg):
            a0 = -60 + t * 110 / seg
            a1 = a0 + 110.0 / seg
            import math
            for a in (a0, a1, (a0 + a1) / 2):
                rad = math.radians(a + f * 4 - 8)
                x = int(c + (r0 + f * 1.2) * math.cos(rad))
                y = int(c + (r0 + f * 1.2) * math.sin(rad))
                for dx in range(-1, 2):
                    for dy in range(-1, 2):
                        px(im, x + dx, y + dy, (190, 235, 255), 255 if abs(dx) + abs(dy) == 0 else 160)
        for t in range(seg):
            import math
            a = -60 + t * 110 / seg
            rad = math.radians(a + f * 4 - 8)
            x = int(c + (r0 - 2 + f * 1.2) * math.cos(rad))
            y = int(c + (r0 - 2 + f * 1.2) * math.sin(rad))
            px(im, x, y, (255, 255, 255), 230)
        sheet.paste(im, (f * S, 0))
    sheet.save(path)

def make_spark(path):
    S = 16
    sheet = Image.new("RGBA", (4 * S, S))
    for f in range(4):
        im = img(S, S)
        c = 8
        n = 6
        for i in range(n):
            a = 3.14159 * 2 * i / n + f * 0.4
            import math
            x = int(c + (2 + f) * math.cos(a)); y = int(c + (2 + f) * math.sin(a))
            px(im, x, y, (255, 255, 255), 255)
            px(im, x + (1 if x > c else -1), y, (255, 220, 120), 200)
        sheet.paste(im, (f * S, 0))
    sheet.save(path)

def make_dust(path):
    S = 16
    sheet = Image.new("RGBA", (3 * S, S))
    for f in range(3):
        im = img(S, S)
        r = 2 + f * 2
        for y in range(8 - r, 8 + r):
            for x in range(8 - r, 8 + r):
                if (x - 8) ** 2 + (y - 8) ** 2 <= r * r:
                    px(im, x, y, (200, 190, 170), 120 if f == 2 else 200)
        sheet.paste(im, (f * S, 0))
    sheet.save(path)

def make_ghost(path):
    S = 32
    im = img(S, S)
    # translucent silhouette (used with modulate for dodge afterimage)
    rect(im, 11, 8, 21, 20, (200, 225, 250), 120)
    rect(im, 11, 8, 21, 10, (200, 225, 250), 150)
    im.save(path)

def make_icons(path):
    S = 16
    icons = {}
    sheet = Image.new("RGBA", (16 * S, S))
    def ic(name, i, fn):
        icons[name] = i
        im = img(S, S)
        fn(im)
        sheet.paste(im, (i * S, 0))
    def potion(im):
        rect(im, 6, 2, 10, 4, (160, 130, 90))
        rect(im, 5, 4, 11, 14, (200, 220, 240))
        rect(im, 5, 4, 8, 14, (180, 206, 232))
        rect(im, 6, 7, 10, 12, (240, 90, 110))
        px(im, 7, 9, (255, 255, 255))
    def sword(im, c1, c2):
        rect(im, 5, 2, 8, 9, c1)
        rect(im, 6, 2, 8, 9, c2)
        rect(im, 4, 9, 9, 10, (214, 170, 90))
        rect(im, 3, 10, 10, 12, (120, 80, 40))
    ic("potion", 0, potion)
    ic("sword_starter", 1, lambda im: sword(im, (168, 176, 190), (140, 148, 162)))
    ic("sword_bronze", 2, lambda im: sword(im, (196, 150, 96), (168, 124, 74)))
    ic("sword_iron", 3, lambda im: sword(im, (210, 214, 226), (176, 180, 196)))
    def armor(im, c1, c2):
        rect(im, 4, 2, 12, 8, c1)
        rect(im, 4, 2, 8, 8, c2)
        rect(im, 3, 4, 4, 10, c2)
        rect(im, 12, 4, 13, 10, c2)
        rect(im, 4, 8, 12, 14, c1)
        px(im, 7, 5, (240, 230, 150))
    ic("armor_cloth", 4, lambda im: armor(im, (206, 198, 186), (182, 172, 158)))
    ic("armor_leather", 5, lambda im: armor(im, (158, 108, 62), (132, 88, 50)))
    def charm(im):
        outline_rect(im, 5, 3, 11, 12, (214, 170, 90))
        rect(im, 6, 4, 10, 11, (90, 140, 190))
        px(im, 8, 6, (255, 255, 255))
        px(im, 8, 12, (214, 170, 90)); px(im, 8, 13, (214, 170, 90))
    ic("charm", 6, charm)
    def col(im):
        for y in range(5, 11):
            for x in range(4, 12):
                if (x - 8) ** 2 + (y - 8) ** 2 <= 12:
                    px(im, x, y, (230, 196, 90))
        px(im, 8, 8, (255, 235, 160))
    ic("col", 7, col)
    def meat(im):
        rect(im, 4, 6, 12, 11, (214, 130, 96))
        rect(im, 4, 6, 8, 8, (240, 224, 214))
        px(im, 6, 8, (160, 90, 70)); px(im, 10, 10, (160, 90, 70))
    ic("meat", 8, meat)
    def skill(im):
        rect(im, 7, 2, 9, 14, (150, 220, 255))
        px(im, 8, 1, (150, 220, 255)); px(im, 8, 15, (150, 220, 255))
        px(im, 6, 7, (255, 255, 255)); px(im, 10, 9, (255, 255, 255))
    ic("skill", 9, skill)
    sheet.save(path)
    return icons

def make_title_bg(path):
    W, H = 640, 360
    im = Image.new("RGBA", (W, H))
    rng = random.Random(11)
    for y in range(H):
        t = y / H
        c = (int(20 + 60 * t), int(30 + 80 * t), int(60 + 110 * t))
        for x in range(W):
            px(im, x, y, c)
    # stars
    for _ in range(120):
        x = rng.randrange(0, W); y = rng.randrange(0, 180)
        a = rng.randrange(120, 255)
        px(im, x, y, (255, 255, 255), a)
    # clouds
    for cx, cy, s in [(120, 60, 3), (420, 90, 4), (300, 30, 2), (560, 40, 3)]:
        for dy in range(-4 * s, 4 * s):
            for dx in range(-12 * s, 12 * s):
                if abs(dx) + abs(dy) * 2 < 20 * s:
                    px(im, cx + dx, cy + dy, (240, 240, 255), 26)
    # floating island silhouette
    base_y = H - 60
    for y in range(base_y, H):
        for x in range(W):
            n = rng.random()
            if y == base_y:
                px(im, x, y, (30, 26, 34))
            elif y > base_y and n < 0.7:
                px(im, x, y, (36, 32, 40))
    # castle silhouette on island
    def tower(x0, w, h, top):
        rect(im, x0, H - 60 - h, x0 + w, H - 60, (22, 20, 30))
        rect(im, x0 - 4, H - 60 - h - 8, x0 + w + 4, H - 60 - h, (22, 20, 30))
        if top:
            for i in range(6):
                rect(im, x0 - 6 + i * 4, H - 60 - h - 14 - (0 if i % 2 == 0 else 4), x0 - 2 + i * 4, H - 60 - h - 8, (22, 20, 30))
    tower(200, 40, 90, True)
    tower(300, 70, 140, True)
    tower(430, 34, 70, False)
    tower(150, 24, 55, False)
    tower(470, 26, 55, False)
    rect(im, 180, H - 20, 480, H - 60, (22, 20, 30))
    # light beams
    for x in range(120, 520, 40):
        for k in range(60):
            px(im, x + k // 4, H - 60 - k, (200, 220, 255), 14 if k % 3 else 8)
    im.save(path)

def make_icon(path):
    im = img(128, 128, (24, 26, 40))
    # sword
    rect(im, 56, 16, 64, 96, (200, 214, 236))
    rect(im, 64, 16, 72, 96, (168, 182, 208))
    rect(im, 52, 12, 60, 20, (150, 220, 255))
    rect(im, 48, 92, 80, 100, (214, 170, 90))
    rect(im, 42, 100, 86, 108, (120, 80, 40))
    px(im, 64, 6, (255, 255, 255), 220)
    im.save(path)

def main():
    os.makedirs(ROOT, exist_ok=True)
    for sub in ["tiles", "chars", "enem", "fx", "objs", "ui"]:
        os.makedirs(os.path.join(ROOT, sub), exist_ok=True)
    T = make_tileset(os.path.join(ROOT, "tiles", "tiles.png"))
    print("tiles:", len(T))
    make_character(os.path.join(ROOT, "chars", "player.png"), PALETTES["player"])
    make_character(os.path.join(ROOT, "chars", "kirito.png"), PALETTES["kirito"])
    make_character(os.path.join(ROOT, "chars", "klein.png"), PALETTES["klein"])
    make_character(os.path.join(ROOT, "chars", "asuna.png"), PALETTES["asuna"])
    make_character(os.path.join(ROOT, "chars", "merchant.png"), PALETTES["merchant"])
    make_character(os.path.join(ROOT, "chars", "blacksmith.png"), PALETTES["blacksmith"])
    make_character(os.path.join(ROOT, "chars", "liaison.png"), PALETTES["liaison"])
    # villagers: 6 sprites in one sheet
    vw = 18 * 32
    vsheet = Image.new("RGBA", (vw * 6, 4 * 32))
    for vi in range(6):
        pal = PALETTES["villager"][vi]
        tmp = Image.new("RGBA", (vw, 4 * 32))
        for di, dirn in enumerate(DIRS):
            for anim, col in COLMAP:
                for i in range(COLS[anim]):
                    tmp.paste(doll_frame(pal, dirn, anim, i), ((col + i) * 32, di * 32))
        vsheet.paste(tmp, (vi * vw, 0))
    vsheet.save(os.path.join(ROOT, "chars", "villagers.png"))
    make_boar(os.path.join(ROOT, "enem", "boar.png"))
    make_wolf(os.path.join(ROOT, "enem", "wolf.png"))
    make_guardian(os.path.join(ROOT, "enem", "guardian.png"))
    make_boss(os.path.join(ROOT, "enem", "boss.png"))
    make_dummy(os.path.join(ROOT, "objs", "dummy.png"))
    make_chest(os.path.join(ROOT, "objs", "chest.png"))
    make_gate(os.path.join(ROOT, "objs", "gate.png"))
    make_seal(os.path.join(ROOT, "objs", "seal.png"))
    make_crystal(os.path.join(ROOT, "objs", "crystal.png"))
    make_torch(os.path.join(ROOT, "objs", "torch.png"))
    make_slash(os.path.join(ROOT, "fx", "slash.png"), False)
    make_slash(os.path.join(ROOT, "fx", "slash_big.png"), True)
    make_spark(os.path.join(ROOT, "fx", "spark.png"))
    make_dust(os.path.join(ROOT, "fx", "dust.png"))
    make_ghost(os.path.join(ROOT, "fx", "ghost.png"))
    icons = make_icons(os.path.join(ROOT, "ui", "icons.png"))
    print("icons:", icons)
    make_title_bg(os.path.join(ROOT, "ui", "title_bg.png"))
    make_icon(os.path.join(os.path.dirname(ROOT), "icon.png"))
    print("art done")

if __name__ == "__main__":
    main()
