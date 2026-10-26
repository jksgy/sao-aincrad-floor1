# -*- coding: utf-8 -*-
"""Map authoring: hand-designed ASCII structures -> data/maps/*.txt (fixed width, validated).
Legend must mirror map_builder.gd LEGEND."""
import os, random

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "project", "data", "maps")
os.makedirs(OUT, exist_ok=True)

def build(w, h, setup):
    """setup(grid): grid is list of h rows (lists of w chars)."""
    g = [[" " for _ in range(w)] for _ in range(h)]
    setup(g)
    rows = []
    for y in range(h):
        rows.append("".join(g[y]))
    return "\n".join(rows) + "\n"

def rect(g, x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < len(g[0]) and 0 <= y < len(g):
                g[y][x] = ch

def hline(g, x0, x1, y, ch):
    rect(g, x0, y, x1, y, ch)

def vline(g, x, y0, y1, ch):
    rect(g, x, y0, x, y1, ch)

def box(g, x0, y0, x1, y1, wall="v", floor="o", door=None, door_x=None):
    rect(g, x0, y0, x1, y1, floor)
    hline(g, x0, x1, y0, wall); hline(g, x0, x1, y1, wall)
    vline(g, x0, y0, y1, wall); vline(g, x1, y0, y1, wall)
    if door:
        g[y1][door_x] = door

def border(g, w, h, ch="v"):
    hline(g, 0, w - 1, 0, ch); hline(g, 0, w - 1, h - 1, ch)
    vline(g, 0, 0, h - 1, ch); vline(g, w - 1, 0, h - 1, ch)

def tree(g, x, y):
    if 0 <= x < len(g[0]) and 0 <= y < len(g):
        g[y][x] = "t"
        if y - 1 >= 0:
            g[y - 1][x] = "T"

def pond(g, x0, y0, x1, y1):
    rect(g, x0 + 1, y0 + 1, x1 - 1, y1 - 1, "w")
    hline(g, x0 + 1, x1 - 1, y0, "W")
    hline(g, x0 + 1, x1 - 1, y1, "q")
    vline(g, x0, y0 + 1, y1 - 1, "Q")
    vline(g, x1, y0 + 1, y1 - 1, "e")

# ================= TOWN 80x60 =================
def town():
    W, H = 80, 60
    def roofed(g, x0, y0, x1, y1, door_x, floor="o"):
        box(g, x0, y0, x1, y1, floor=floor)
        g[y1][door_x] = "D"
        rect(g, x0, y0 - 2, x1, y0 - 1, "h")
        hline(g, x0, x1, y0, "H")

    def setup(g):
        border(g, W, H, "v")
        rect(g, 1, 1, 78, 58, "o")
        # plaza cobble
        rect(g, 28, 18, 52, 42, "c")
        # fountain 2x2
        rect(g, 39, 29, 40, 30, "U")
        # south gate (gap in border)
        rect(g, 36, 59, 44, 59, "c")
        g[58][36] = "L"; g[58][44] = "L"
        hline(g, 36, 44, 57, "c")
        # buildings
        roofed(g, 6, 20, 20, 30, 13)            # blacksmith
        roofed(g, 24, 20, 34, 30, 29, "O")      # equipment shop
        roofed(g, 52, 16, 64, 26, 58, "O")      # general store
        roofed(g, 34, 4, 46, 10, 40, "O")       # chapel + save point
        roofed(g, 62, 4, 72, 10, 67, "O")       # liaison office
        roofed(g, 16, 4, 26, 10, 21, "O")       # house N1
        roofed(g, 50, 4, 60, 10, 55, "O")       # house N2
        roofed(g, 56, 34, 66, 46, 61, "O")      # house SE1
        roofed(g, 68, 34, 76, 46, 72, "O")      # house SE2
        roofed(g, 6, 34, 16, 46, 11, "O")       # house SW1
        roofed(g, 18, 38, 26, 46, 22, "O")      # house SW2
        # shop signs beside doors (on floor, not wall)
        g[31][12] = "g"; g[31][30] = "g"; g[27][57] = "g"
        # save crystal + bench in chapel
        g[8][38] = "R"; g[8][42] = "B"
        # liaison outside office + bulletin sign
        g[12][66] = "G"; g[12][68] = "g"
        # merchant stall in front of store
        rect(g, 48, 20, 52, 20, "x")
        rect(g, 47, 19, 53, 19, "&")
        g[21][49] = "S"
        # blacksmith + forge props
        g[32][13] = "F"
        g[28][8] = "y"; g[28][10] = "x"
        # training yard: dummies + kirito
        g[28][38] = "P"; g[28][40] = "P"; g[28][42] = "P"
        g[31][38] = "I"
        # klein at plaza
        g[35][40] = "K"
        # villagers
        g[13][40] = "1"; g[36][47] = "2"; g[30][70] = "3"; g[13][24] = "4"
        g[30][58] = "5"; g[12][47] = "6"
        # decor (only in open areas)
        for (x, y) in [(38, 16), (48, 16), (30, 30), (26, 40), (54, 44), (72, 30)]:
            g[y][x] = "L"
        for (x, y) in [(14, 14), (44, 14), (66, 14), (30, 12), (74, 20), (8, 32), (40, 46), (54, 48)]:
            g[y][x] = "f"
        for (x, y) in [(10, 12), (46, 12), (68, 12)]:
            g[y][x] = "b"
        tree(g, 6, 13); tree(g, 74, 13); tree(g, 72, 30)
        tree(g, 6, 31); tree(g, 76, 31)
        for (x, y) in [(22, 29), (36, 27), (36, 29), (38, 44), (46, 44)]:
            g[y][x] = "x"
        for (x, y) in [(22, 27), (38, 46), (48, 44)]:
            g[y][x] = "y"
    return "town", build(W, H, setup) + "\n".join([
        "# name: 起始之镇", f"# size: {W} {H}",
        "# music: town", "# safe: true",
        "# spawn: default 40 33", "# spawn: from_field 40 55",
        "# exit: to_field 36 57 44 59 field from_town",
        "# wander: 1 2 2", "# wander: 3 1 2",
    ]) + "\n"

# ================= FIELD 120x90 =================
def field():
    W, H = 120, 90
    def setup(g):
        # grass fill placeholder
        for y in range(H):
            for x in range(W):
                g[y][x] = "."
        # town gate at north
        rect(g, 56, 0, 63, 3, "p")
        g[4][58] = "L"; g[4][61] = "L"
        # main road: vertical then east, vertical, east to maze
        vline(g, 59, 5, 24, "p")
        hline(g, 59, 104, 24, "p")
        vline(g, 104, 24, 46, "p")
        hline(g, 104, 117, 46, "p")
        rect(g, 116, 43, 117, 48, "d")
        # pond north-west
        pond(g, 18, 12, 34, 24)
        # forest central-west (trees)
        for (x, y) in [(24, 30), (28, 32), (32, 30), (36, 34), (22, 36), (27, 38), (33, 40),
                       (38, 42), (20, 44), (26, 46), (31, 48), (37, 50), (24, 54), (30, 56),
                       (44, 44), (48, 48), (52, 52), (46, 56), (58, 58), (14, 58), (10, 64),
                       (14, 70), (20, 74), (26, 78), (6, 80), (10, 86), (18, 84), (30, 86),
                       (38, 82), (44, 86), (52, 88), (60, 86), (66, 80), (70, 86), (78, 82),
                       (84, 76), (88, 70), (92, 64), (96, 58), (76, 58), (82, 62), (66, 62),
                       (60, 66), (54, 70), (48, 74), (42, 70), (36, 66), (30, 62), (40, 76),
                       (70, 70), (76, 74), (82, 78), (88, 82), (94, 86), (100, 82), (106, 76),
                       (112, 70), (114, 60), (110, 52)]:
            tree(g, x, y)
        # rocks / bushes / stumps scattered
        for (x, y) in [(40, 30), (46, 32), (50, 36), (42, 52), (56, 60), (64, 66), (72, 72), (80, 68), (62, 54), (34, 44)]:
            g[y][x] = "r"
        for (x, y) in [(44, 30), (36, 36), (40, 46), (66, 58), (74, 64), (52, 66), (68, 80)]:
            g[y][x] = "R"
        for (x, y) in [(48, 40), (54, 44), (60, 48), (64, 56), (70, 62), (76, 66), (34, 50), (28, 44)]:
            g[y][x] = "b"
        for (x, y) in [(42, 40), (46, 44), (50, 50), (58, 54)]:
            g[y][x] = "s"
        # rest spot (bench + flowers) west
        g[38][26] = "B"
        for (x, y) in [(24, 36), (26, 38), (30, 36), (32, 38)]:
            g[y][x] = "f"
        rect(g, 22, 34, 34, 40, "d")
        g[38][26] = "B"
        # hidden chest SW clearing
        g[76][16] = "C"
        # supply chest in forest branch
        g[60][48] = "C"
        # east ruins
        for x in (96, 100, 104, 108):
            g[34][x] = "|"; g[36][x] = "|"
        rect(g, 94, 32, 110, 32, "j"); rect(g, 94, 38, 110, 38, "j")
        rect(g, 96, 33, 110, 37, "d")
        g[34][92] = "g"
        g[35][98] = "#"; g[37][106] = "#"
        # boars near north road
        for (x, y) in [(48, 8), (54, 12), (66, 10), (50, 16), (68, 16), (44, 20), (74, 12), (62, 20), (46, 10)]:
            g[y][x] = "@"
        # wolves in forest
        for (x, y) in [(30, 28), (38, 32), (28, 42), (34, 46), (42, 48), (36, 58), (50, 46), (56, 50), (60, 54), (48, 62)]:
            g[y][x] = "*"
        # flowers near spawn
        for (x, y) in [(55, 8), (63, 8), (57, 14), (62, 14)]:
            g[y][x] = "f"
    return "field", build(W, H, setup) + "\n".join([
        "# name: 草原", f"# size: {W} {H}",
        "# music: field", "# safe: false",
        "# spawn: default 59 8", "# spawn: from_town 59 8", "# spawn: from_maze 114 45",
        "# exit: to_town 56 0 63 2 town from_field",
        "# exit: to_maze_a 115 43 119 47 maze_a from_field",
        "# chest: chest_field_hidden 16 76 old_charm",
        "# chest: chest_field_supply 48 60 potion potion col30",
    ]) + "\n"

# ================= MAZE A 56x40 =================
def maze_a():
    W, H = 56, 40
    def setup(g):
        # carve-from-solid: fill everything, then dig corridors/rooms
        border(g, W, H, "u")
        rect(g, 1, 1, 54, 38, "u")
        # west entry + hall
        rect(g, 0, 19, 11, 20, "m")
        rect(g, 11, 15, 34, 25, "m")
        # chest room + corridor down to hall
        rect(g, 5, 4, 13, 10, "m")
        rect(g, 8, 10, 10, 16, "m")
        # switch room + corridor down to hall
        rect(g, 18, 4, 24, 10, "m")
        rect(g, 20, 10, 22, 16, "m")
        # north corridor (demo door) + exit room
        rect(g, 27, 3, 29, 15, "m")
        rect(g, 25, 1, 31, 3, "m")
        g[10][27] = "X"; g[10][28] = "X"; g[10][29] = "X"
        # contents
        g[7][21] = "J"          # seal_demo
        g[6][7] = "C"           # chest
        g[18][16] = "#"; g[22][27] = "#"
        g[20][24] = "|"
        g[1][26] = "="; g[1][30] = "="
        # torches / deco (walkable cells only)
        for (x, y) in [(3, 19), (12, 20), (33, 20), (9, 8), (22, 6), (28, 5), (30, 23)]:
            g[y][x] = "i"
        for (x, y) in [(14, 20), (30, 20), (22, 16), (12, 23), (33, 24), (10, 17), (17, 6), (29, 10)]:
            g[y][x] = "j"
        for (x, y) in [(16, 18), (28, 24), (23, 8), (6, 5)]:
            g[y][x] = "z"
    return "maze_a", build(W, H, setup) + "\n".join([
        "# name: 迷宫一层 A 区", f"# size: {W} {H}",
        "# music: dungeon", "# safe: false",
        "# spawn: default 5 20", "# spawn: from_field 5 20", "# spawn: from_b 28 2",
        "# exit: to_field 0 19 1 20 field from_maze",
        "# exit: to_maze_b 26 0 29 1 maze_b from_a",
        "# seal: seal_demo 21 7",
        "# gate: door_demo 27 10 29 10 seal_demo",
        "# chest: chest_a1 7 6 potion potion col20",
    ]) + "\n"

# ================= MAZE B 56x40 =================
def maze_b():
    W, H = 56, 40
    def setup(g):
        border(g, W, H, "u")
        rect(g, 1, 1, 54, 38, "u")
        # south entry hall + main corridor north
        rect(g, 26, 39, 28, 39, "m")
        rect(g, 22, 30, 32, 38, "m")
        rect(g, 26, 20, 29, 30, "m")
        # central artery east-west
        rect(g, 10, 17, 50, 20, "m")
        # west supply room (touches artery row 17)
        rect(g, 5, 12, 15, 17, "m")
        # west dead-end look-out branch
        rect(g, 12, 20, 14, 27, "m")
        # seal room + corridor
        rect(g, 18, 6, 28, 12, "m")
        rect(g, 22, 12, 24, 17, "m")
        # east dead-end branch (rune)
        rect(g, 40, 6, 43, 13, "m")
        rect(g, 41, 13, 42, 17, "m")
        # east treasure room (iron sword) + corridor
        rect(g, 43, 11, 51, 16, "m")
        rect(g, 46, 16, 47, 17, "m")
        # east exit corridor
        rect(g, 50, 17, 55, 20, "m")
        # contents
        g[8][23] = "J"          # seal_b
        g[14][9] = "C"          # supply chest
        g[13][47] = "C"         # iron sword chest
        g[15][23] = "#"; g[9][26] = "#"
        g[31][27] = "#"
        g[8][41] = "z"; g[19][48] = "j"; g[25][13] = "j"
        for (x, y) in [(27, 33), (30, 31), (20, 19), (34, 19), (25, 7), (44, 15), (52, 19), (12, 25)]:
            g[y][x] = "i"
    return "maze_b", build(W, H, setup) + "\n".join([
        "# name: 迷宫一层 B 区", f"# size: {W} {H}",
        "# music: dungeon", "# safe: false",
        "# spawn: default 27 35", "# spawn: from_a 27 35", "# spawn: from_c 52 19",
        "# exit: to_maze_a 26 38 28 39 maze_a from_b",
        "# exit: to_maze_c 54 19 55 20 maze_c from_b",
        "# seal: seal_b 23 8",
        "# chest: chest_b_supply 9 14 potion potion",
        "# chest: chest_b_sword 47 13 iron_sword",
    ]) + "\n"

# ================= MAZE C 56x40 =================
def maze_c():
    W, H = 56, 40
    def setup(g):
        border(g, W, H, "u")
        rect(g, 1, 1, 54, 38, "u")
        # west entry hall + main artery
        rect(g, 0, 19, 14, 20, "m")
        rect(g, 4, 17, 14, 22, "m")
        rect(g, 14, 18, 46, 21, "m")
        # seal room (east) + corridor
        rect(g, 34, 6, 44, 12, "m")
        rect(g, 37, 12, 39, 18, "m")
        # pre-boss corridor + room (west of seal room)
        rect(g, 24, 6, 27, 18, "m")
        rect(g, 22, 2, 32, 6, "m")
        # boss gate on the north wall
        g[1][26] = "X"; g[1][27] = "X"; g[1][28] = "X"; g[1][29] = "X"
        # south supply room + corridor
        rect(g, 38, 24, 46, 30, "m")
        rect(g, 40, 21, 42, 24, "m")
        # contents
        g[8][38] = "J"          # seal_c
        g[27][42] = "C"         # supply chest
        g[4][22] = "R"          # save crystal
        g[4][30] = "Y"          # asuna
        g[9][27] = "#"
        g[19][8] = "#"; g[22][12] = "#"
        g[3][24] = "z"
        for (x, y) in [(6, 18), (6, 21), (20, 19), (44, 19), (25, 4), (31, 7), (39, 26), (2, 19)]:
            g[y][x] = "i"
        for (x, y) in [(16, 19), (33, 18), (36, 8), (43, 25), (26, 12)]:
            g[y][x] = "j"
        for (x, y) in [(10, 20), (18, 21), (35, 10), (40, 29)]:
            g[y][x] = "z"
    return "maze_c", build(W, H, setup) + "\n".join([
        "# name: 迷宫一层 C 区", f"# size: {W} {H}",
        "# music: dungeon", "# safe: false",
        "# spawn: default 4 19", "# spawn: from_b 4 19", "# spawn: from_boss 27 3",
        "# exit: to_maze_b 0 19 1 20 maze_b from_c",
        "# exit: to_boss 26 0 29 1 boss from_c",
        "# seal: seal_c 38 8",
        "# gate: boss_gate 26 1 29 1 seal_b seal_c",
        "# chest: chest_c_supply 42 27 potion potion potion",
    ]) + "\n"

# ================= BOSS 40x28 =================
def boss_room():
    W, H = 40, 28
    def setup(g):
        border(g, W, H, "u")
        rect(g, 1, 1, 38, 26, "a")
        # arena ring
        hline(g, 4, 35, 4, "A"); hline(g, 4, 35, 19, "A")
        vline(g, 4, 4, 19, "A"); vline(g, 35, 4, 19, "A")
        # south entry corridor
        rect(g, 17, 22, 22, 26, "a")
        vline(g, 17, 22, 26, "u"); vline(g, 22, 22, 26, "u")
        # entry gate
        hline(g, 15, 24, 23, "u")
        g[23][20] = "X"
        g[23][19] = "u"; g[23][21] = "u"
        hline(g, 15, 24, 22, "u")
        rect(g, 19, 22, 20, 22, "a")
        g[26][19] = "i"; g[26][20] = "i"
        # pillars + torches
        g[7][6] = "|"; g[7][33] = "|"; g[17][6] = "|"; g[17][33] = "|"
        g[11][5] = "i"; g[11][34] = "i"
        # boss + stairs
        g[12][20] = "$"
        g[4][19] = "Z"; g[4][21] = "Z"
        g[3][20] = "z"
        # north wall runes
        for x in (10, 14, 26, 30):
            g[1][x] = "z"
        for (x, y) in [(8, 12), (32, 12), (12, 8), (28, 8), (20, 17)]:
            g[y][x] = "j"
    return "boss", build(W, H, setup) + "\n".join([
        "# name: 守层 Boss 之间", f"# size: {W} {H}",
        "# music: boss", "# safe: false", "# boss: true",
        "# spawn: default 20 25", "# spawn: from_c 20 25",
        "# exit: to_maze_c 17 26 22 27 maze_c from_boss",
        "# gate: boss_entry_gate 20 23",
        "# autosave: true",
    ]) + "\n"

def main():
    maps = [town(), field(), maze_a(), maze_b(), maze_c(), boss_room()]
    for name, content in maps:
        p = os.path.join(OUT, name + ".txt")
        with open(p, "w", encoding="utf-8") as f:
            f.write(content)
        # validate widths
        lines = [l for l in content.split("\n") if l and not l.startswith("#")]
        widths = set(len(l) for l in lines)
        if len(widths) != 1:
            raise SystemExit(f"{name}: inconsistent row widths {widths}")
        print(f"{name}: {len(lines)} rows x {widths.pop()} cols -> {p}", flush=True)

if __name__ == "__main__":
    main()
