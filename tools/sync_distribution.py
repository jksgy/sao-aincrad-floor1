# -*- coding: utf-8 -*-
"""Sync docs + screenshots into the Desktop distribution folder (UTF-8 paths handled here)."""
import os, shutil

DESKTOP = os.path.join(os.path.expanduser("~"), "Desktop", "刀剑神域第一层原型")
WS = r"D:\2DSAO"

os.makedirs(DESKTOP, exist_ok=True)
for name in ["说明.txt", "验证记录.md"]:
    shutil.copy2(os.path.join(WS, name), os.path.join(DESKTOP, name))

shots_src = os.path.join(WS, "验证截图")
shots_dst = os.path.join(DESKTOP, "验证截图")
os.makedirs(shots_dst, exist_ok=True)
for f in os.listdir(shots_src):
    if f.endswith(".png"):
        shutil.copy2(os.path.join(shots_src, f), os.path.join(shots_dst, f))

shutil.copy2(os.path.join(WS, "project", "icon.png"), os.path.join(DESKTOP, "icon.png"))
print("synced:", sorted(os.listdir(DESKTOP)))
