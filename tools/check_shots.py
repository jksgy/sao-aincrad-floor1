# -*- coding: utf-8 -*-
"""Verify screenshots have expected content characteristics."""
import os
from PIL import Image

SHOTS = os.path.join(r"D:\2DSAO\tools\appdata\Godot\app_userdata",
                     "刀剑神域：艾恩葛朗特第一层（同人原型）", "shots")

def stats(p):
    im = Image.open(p).convert("RGB")
    w, h = im.size
    colors = im.getcolors(1000000)
    colors = sorted(colors, reverse=True)
    return im, colors

def frac(im, pred):
    n = 0
    total = im.width * im.height
    for v in im.getdata():
        if pred(v[0], v[1], v[2]):
            n += 1
    return n / total

expect = {
    "00_title.png": [("sky blue-ish", lambda r, g, b: b > 60 and b > r), ],
    "01_town.png": [("roof red-brown", lambda r, g, b: r > 110 and g < 110 and b < 90 and r > g + 30)],
    "02_dialogue.png": [("dark dim overlay", lambda r, g, b: r < 30 and g < 30 and b < 45)],
    "03_inventory.png": [("panel dark", lambda r, g, b: r < 40 and g < 42 and b < 55)],
    "06_field.png": [("grass green", lambda r, g, b: g > 90 and g > r and g > b)],
    "08_maze_a.png": [("dungeon blue-gray", lambda r, g, b: 60 < b < 160 and abs(r - g) < 25)],
    "10_boss_fight.png": [("telegraph red-orange", lambda r, g, b: r > 100 and r > g + 40 and r > b + 40)],
    "11_victory.png": [("gold title-ish", lambda r, g, b: r > 170 and g > 120 and r > b + 60)],
}
bad = 0
for name, checks in expect.items():
    p = os.path.join(SHOTS, name)
    if not os.path.exists(p):
        print(f"{name}: MISSING"); bad += 1; continue
    im, colors = stats(p)
    line = f"{name}: colors={len(colors)}"
    for label, pred in checks:
        f = frac(im, pred)
        ok = f > 0.001
        line += f" | {label}={f:.3f}{'' if ok else ' <-- LOW'}"
        if not ok:
            bad += 1
    print(line)
print("BAD=", bad)
