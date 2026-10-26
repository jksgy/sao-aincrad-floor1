# -*- coding: utf-8 -*-
"""Validate generated PNGs: dimensions, opacity coverage per frame cell, palette sanity."""
import os, sys
from PIL import Image

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "project", "assets")
files = [
    "tiles/tiles.png", "chars/player.png", "chars/kirito.png", "chars/klein.png", "chars/asuna.png",
    "chars/merchant.png", "chars/blacksmith.png", "chars/liaison.png", "chars/villagers.png",
    "enem/boar.png", "enem/wolf.png", "enem/guardian.png", "enem/boss.png",
    "objs/dummy.png", "objs/chest.png", "objs/gate.png", "objs/seal.png", "objs/crystal.png", "objs/torch.png",
    "fx/slash.png", "fx/slash_big.png", "fx/spark.png", "fx/dust.png", "fx/ghost.png",
    "ui/icons.png", "ui/title_bg.png",
]
bad = 0
for f in files:
    p = os.path.join(ASSETS, f)
    im = Image.open(p).convert("RGBA")
    w, h = im.size
    a = im.getchannel("A")
    opaque = sum(1 for v in a.getdata() if v > 40)
    colors = len(set(im.getdata()))
    # per-cell coverage for sprite sheets (32px cells; boss 64)
    cs = 64 if f == "enem/boss.png" else 32
    cells = []
    for y in range(0, h, cs):
        for x in range(0, w, cs):
            box = im.crop((x, y, x + cs, y + cs)).getchannel("A")
            cells.append(sum(1 for v in box.getdata() if v > 40))
    n_cells = (w // cs) * (h // cs)
    empty = sum(1 for c in cells if c == 0)
    mx = max(cells) if cells else 0
    print(f"{f}: {w}x{h} colors={colors} opaque={opaque} cells={n_cells} empty={empty} max_cell={mx}", flush=True)
    if empty > n_cells * 0.25 or mx < 10:
        print(f"  !! SUSPICIOUS {f}", flush=True)
        bad += 1
# upscaled preview contact sheets
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
os.makedirs(outdir, exist_ok=True)
for f in files:
    p = os.path.join(ASSETS, f)
    im = Image.open(p).convert("RGBA")
    im2 = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
    name = f.replace("/", "_")
    im2.save(os.path.join(outdir, name))
print("previews written to", outdir, flush=True)
sys.exit(1 if bad else 0)
