# -*- coding: utf-8 -*-
"""Map connectivity checker: flood-fill from spawns, verify POIs and exits are reachable."""
import os, sys, collections

MAPS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "project", "data", "maps")

WALKABLE_TILES = set(".,:npdfWqQeoOcDmMB=azg") | {"U_never"} - {"U_never"}
SOLID_TILES = set("wtrRbsvVu|jxy") | {"U"}
DECOR = set("i")           # torch object on floor
OBJECTS = set("K I Y S F G 1 2 3 4 5 6 @ * # $ P C J R Z X".split())
# 'X' gate: passable for reachability (it can be opened)
PASSABLE_OBJECTS = OBJECTS

def load(name):
    grid = []
    spawns, exits, chests, seals, gates = {}, [], [], [], []
    with open(os.path.join(MAPS, name + ".txt"), encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("#"):
                p = line[1:].strip().split()
                if not p:
                    continue
                key = p[0].rstrip(":")
                if key == "spawn":
                    spawns[p[1]] = (int(p[2]), int(p[3]))
                elif key == "exit":
                    exits.append({"id": p[1], "rect": (int(p[2]), int(p[3]), int(p[4]), int(p[5])),
                                  "target": p[6], "spawn": p[7]})
                elif key == "chest":
                    chests.append({"id": p[1], "cell": (int(p[2]), int(p[3]))})
                elif key == "seal":
                    seals.append({"id": p[1], "cell": (int(p[2]), int(p[3]))})
                elif key == "gate":
                    gates.append({"id": p[1], "cell": (int(p[2]), int(p[3])), "deps": p[6:]})
                continue
            if line:
                grid.append(line)
    return grid, spawns, exits, chests, seals, gates

def cell_char(grid, x, y):
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        return grid[y][x]
    return " "

def walkable(ch):
    if ch in (" ", ""):
        return False
    if ch in SOLID_TILES:
        return False
    if ch in DECOR:
        return True
    if ch in PASSABLE_OBJECTS:
        return True
    return True   # any remaining floor-ish decor

def flood(grid, start):
    W, H = len(grid[0]), len(grid)
    seen = set()
    q = collections.deque()
    if walkable(cell_char(grid, *start)):
        seen.add(start); q.append(start)
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen and walkable(cell_char(grid, nx, ny)):
                seen.add((nx, ny)); q.append((nx, ny))
    return seen

def check(name):
    grid, spawns, exits, chests, seals, gates = load(name)
    W, H = len(grid[0]), len(grid)
    problems = []
    # all walkable cells and their reachability from the primary spawn
    start = spawns.get("default") or next(iter(spawns.values()))
    if not walkable(cell_char(grid, *start)):
        problems.append(f"spawn default on solid tile {start}")
    reach = flood(grid, start)
    walk_cells = {(x, y) for y in range(H) for x in range(W) if walkable(cell_char(grid, x, y))}
    unreachable = walk_cells - reach
    if unreachable:
        problems.append(f"{len(unreachable)} walkable cells unreachable (e.g. {sorted(unreachable)[:6]})")
    for sid, cell in spawns.items():
        if cell not in reach:
            problems.append(f"spawn {sid} unreachable/hidden at {cell}")
    for c in chests:
        if c["cell"] not in reach:
            problems.append(f"chest {c['id']} unreachable at {c['cell']}")
    for s in seals:
        if s["cell"] not in reach:
            problems.append(f"seal {s['id']} unreachable at {s['cell']}")
    for e in exits:
        x0, y0, x1, y1 = e["rect"]
        areas = {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}
        if not (areas & reach):
            problems.append(f"exit {e['id']} unreachable (rect {e['rect']})")
    # NPC / enemy / boss / stairs positions
    for y in range(H):
        for x in range(W):
            ch = grid[y][x]
            if ch in "KIYSFG123456$Z":
                if (x, y) not in reach:
                    problems.append(f"entity '{ch}' unreachable at {(x, y)}")
    if problems:
        print(f"[FAIL] {name}: " + "; ".join(problems))
        return 1
    print(f"[ok] {name}: {len(reach)} reachable cells, {len(spawns)} spawns, {len(exits)} exits, "
          f"{len(chests)} chests, {len(seals)} seals")
    return 0

def main():
    bad = 0
    for name in ["town", "field", "maze_a", "maze_b", "maze_c", "boss"]:
        bad += check(name)
    print("MAPS_BAD=", bad)
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
