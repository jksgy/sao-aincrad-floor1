class_name MapBuilder
extends RefCounted
## MapBuilder: parses data/maps/*.txt and builds a Map node (tile layers + objects).
## Legend must mirror tools/gen_maps.py.

# legend char -> [atlas col, row]
const TILES := {
	# walkable
	".": [0, 0], ",": [1, 0], ":": [2, 0], "n": [3, 0], "p": [4, 0], "d": [5, 0], "f": [6, 0],
	"W": [9, 0], "q": [10, 0], "Q": [11, 0], "e": [12, 0],
	"o": [0, 2], "O": [1, 2], "c": [2, 2], "D": [6, 2],
	"m": [0, 3], "M": [1, 3], "=": [7, 3], "z": [8, 3], "a": [9, 3], "A": [10, 3],
	"B": [13, 2], "L": [9, 2], "g": [10, 2],
	# solid
	"w": [7, 0], "t": [0, 1], "r": [2, 1], "R": [3, 1], "b": [4, 1], "s": [5, 1],
	"v": [3, 2], "V": [4, 2], "u": [2, 3], "|": [4, 3], "j": [6, 3], "x": [11, 2], "y": [12, 2],
}
const FOUNT := { "tl": [14, 2], "tr": [15, 2], "bl": [14, 3], "br": [15, 3] }
const OVERHEAD := { "T": [1, 1], "h": [7, 2], "H": [8, 2], "&": [7, 2] }
const NPC_CHARS := { "K": "klein", "I": "kirito", "Y": "asuna", "S": "merchant",
	"F": "blacksmith", "G": "liaison",
	"1": "villager_1", "2": "villager_2", "3": "villager_3",
	"4": "villager_4", "5": "villager_5", "6": "villager_6" }
const ENEMY_CHARS := { "@": "boar", "*": "wolf", "#": "guardian", "$": "boss_kobold_lord" }

static var _tileset: TileSet
static var _atlas: Texture2D

static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	_atlas = load("res://assets/tiles/tiles.png")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = _atlas
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	var defined := {}
	for ch in TILES.keys():
		var c: Array = TILES[ch]
		var coord := Vector2i(c[0], c[1])
		if defined.has(coord):
			continue
		defined[coord] = true
		src.create_tile(coord)
		if ch in ["w", "t", "r", "R", "b", "s", "v", "V", "u", "|", "j", "x", "y"]:
			var td := src.get_tile_data(coord, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	# fountain quadrants (solid)
	for key in FOUNT.keys():
		var c: Array = FOUNT[key]
		var coord := Vector2i(c[0], c[1])
		if not defined.has(coord):
			defined[coord] = true
			src.create_tile(coord)
		var td := src.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		# TileData collision polygons are relative to the TILE CENTER in Godot 4,
		# so a full 16x16 block is (-8,-8)..(8,8).
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	# water animation
	src.set_tile_animation_columns(Vector2i(7, 0), 2)
	src.set_tile_animation_frames_count(Vector2i(7, 0), 2)
	src.set_tile_animation_speed(Vector2i(7, 0), 3.0)
	_tileset = ts
	return ts

static func is_solid(ch: String) -> bool:
	return ch in ["w", "t", "r", "R", "b", "s", "v", "V", "u", "|", "j", "x", "y", "U"]

# ---------------- parsing ----------------
class MapData:
	var id := ""
	var size := Vector2i.ZERO
	var grid: Array = []              # Array[String] rows
	var spawns: Dictionary = {}       # id -> Vector2 (pixels center)
	var exits: Array = []             # {id, rect: Rect2, target, spawn}
	var chests: Array = []            # {id, cell: Vector2i, loot: Array}
	var seals: Array = []             # {id, cell: Vector2i}
	var gates: Array = []             # {id, cells: Array[Vector2i], deps: Array}
	var music := "town"
	var safe := false
	var is_boss := false
	var autosave := false
	var wanders: Array = []           # {char, radius, speed}

func build(map_id: String, parent: Node) -> Node2D:
	var md := parse(map_id)
	var map_node: Node2D = preload("res://scenes/map.tscn").instantiate()
	map_node.map_id = map_id
	map_node.set_meta("data", md)
	parent.add_child(map_node)
	var floor := TileMapLayer.new()
	floor.name = "Floor"
	floor.tile_set = tileset()
	floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_node.add_child(floor)
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tileset()
	walls.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_node.add_child(walls)
	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	map_node.add_child(entities)
	var areas := Node2D.new()
	areas.name = "Areas"
	map_node.add_child(areas)

	for y in md.size.y:
		for x in md.size.x:
			var ch: String = md.grid[y][x]
			if ch == " ":
				continue
			if TILES.has(ch):
				var c: Array = TILES[ch]
				var layer := walls if is_solid(ch) else floor
				layer.set_cell(Vector2i(x, y), 0, Vector2i(c[0], c[1]))
			elif ch == "U":
				var qx := 1 if (x + 1 < md.size.x and md.grid[y][x + 1] == "U") else 0
				var qy := 1 if (y + 1 < md.size.y and md.grid[y + 1][x] == "U") else 0
				var key := ("b" if qy else "t") + ("r" if qx else "l")
				var c: Array = FOUNT[key]
				walls.set_cell(Vector2i(x, y), 0, Vector2i(c[0], c[1]))
			elif OVERHEAD.has(ch):
				var c: Array = OVERHEAD[ch]
				var spr := Sprite2D.new()
				spr.texture = _atlas
				spr.region_enabled = true
				spr.region_rect = Rect2(c[0] * 16, c[1] * 16, 16, 16)
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				spr.position = Vector2(x * 16 + 8, y * 16 + 12)
				spr.y_sort_enabled = true
				entities.add_child(spr)
			elif NPC_CHARS.has(ch):
				spawn_npc(entities, NPC_CHARS[ch], Vector2i(x, y))
			elif ENEMY_CHARS.has(ch):
				spawn_enemy(entities, ENEMY_CHARS[ch], Vector2i(x, y))
			elif ch == "P":
				spawn_object(entities, "dummy", Vector2i(x, y))
			elif ch == "C":
				var id := _chest_id(map_id, x, y)
				spawn_object(entities, "chest", Vector2i(x, y), { "id": id })
			elif ch == "X":
				var gid := _gate_id(map_id, x, y)
				spawn_object(entities, "gate", Vector2i(x, y), { "id": gid })
			elif ch == "J":
				var sid := _seal_id(map_id, x, y)
				spawn_object(entities, "seal", Vector2i(x, y), { "id": sid })
			elif ch == "R":
				spawn_object(entities, "crystal", Vector2i(x, y), {})
			elif ch == "i":
				spawn_object(entities, "torch", Vector2i(x, y), {})
			elif ch == "Z":
				spawn_object(entities, "stairs", Vector2i(x, y), {})
	# exits
	for ex in md.exits:
		var area := Area2D.new()
		area.position = ex.rect.position + ex.rect.size * 0.5
		area.collision_layer = 0
		area.collision_mask = 2
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = ex.rect.size
		shape.shape = rs
		area.add_child(shape)
		area.set_meta("target", ex.target)
		area.set_meta("spawn", ex.spawn)
		areas.add_child(area)
		area.body_entered.connect(_on_exit_body.bind(area))
	# gates: fill deps from header
	for g in md.gates:
		_apply_gate_meta(entities, g)
	# map node setup
	map_node.setup(md)
	return map_node

func _on_exit_body(body: Node2D, area: Area2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		MapMan.exit_requested(str(area.get_meta("target")), str(area.get_meta("spawn")))

func _apply_gate_meta(entities: Node2D, g: Dictionary) -> void:
	var id: String = g.id
	for node in entities.get_children():
		if node.has_method("gate_meta") and node.get_meta("id", "") == id:
			node.gate_meta(g)

func _chest_id(map_id: String, x: int, y: int) -> String:
	for c in parse(map_id).chests:
		if c.cell == Vector2i(x, y):
			return c.id
	return "%s:%d,%d" % [map_id, x, y]

func _seal_id(map_id: String, x: int, y: int) -> String:
	for s in parse(map_id).seals:
		if s.cell == Vector2i(x, y):
			return s.id
	return "%s:%d,%d" % [map_id, x, y]

func _gate_id(map_id: String, x: int, y: int) -> String:
	for g in parse(map_id).gates:
		if g.cells.has(Vector2i(x, y)):
			return g.id
	return "%s:%d,%d" % [map_id, x, y]

var _cached: Dictionary = {}
func parse(map_id: String) -> MapData:
	if _cached.has(map_id):
		return _cached[map_id]
	var f := FileAccess.open("res://data/maps/%s.txt" % map_id, FileAccess.READ)
	var md := MapData.new()
	md.id = map_id
	if f == null:
		push_error("map file missing: " + map_id)
		md.size = Vector2i(10, 10)
		md.grid = []
		return md
	var rows: Array = []
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("#"):
			_parse_header(md, line)
		elif line.length() > 0:
			rows.append(line)
	f.close()
	md.grid = rows
	if rows.size() > 0:
		md.size = Vector2i(rows[0].length(), rows.size())
	_cached[map_id] = md
	return md

func _parse_header(md: MapData, line: String) -> void:
	var parts := line.substr(1).strip_edges().split(" ", false)
	if parts.size() == 0:
		return
	var key: String = String(parts[0]).trim_suffix(":")
	match key:
		"size":
			md.size = Vector2i(int(parts[1]), int(parts[2]))
		"spawn":
			md.spawns[parts[1]] = Vector2(int(parts[2]) * 16 + 8, int(parts[3]) * 16 + 14)
		"exit":
			md.exits.append({
				"id": parts[1],
				"rect": Rect2(int(parts[2]) * 16, int(parts[3]) * 16,
						(int(parts[4]) - int(parts[2]) + 1) * 16, (int(parts[5]) - int(parts[3]) + 1) * 16),
				"target": parts[6], "spawn": parts[7],
			})
		"chest":
			var loot: Array = []
			for i in range(4, parts.size()):
				loot.append(parts[i])
			md.chests.append({ "id": parts[1], "cell": Vector2i(int(parts[2]), int(parts[3])), "loot": loot })
		"seal":
			md.seals.append({ "id": parts[1], "cell": Vector2i(int(parts[2]), int(parts[3])) })
		"gate":
			# format: gate <id> <x0> <y0> [<x1> <y1>] [dep...]
			var x0 := int(parts[2])
			var y0 := int(parts[3])
			var x1 := int(parts[4]) if parts.size() > 4 else x0
			var y1 := int(parts[5]) if parts.size() > 5 else y0
			var deps: Array = []
			for i in range(6, parts.size()):
				deps.append(parts[i])
			var cells: Array = []
			for x in range(x0, x1 + 1):
				for y in range(y0, y1 + 1):
					cells.append(Vector2i(x, y))
			md.gates.append({ "id": parts[1], "cells": cells, "deps": deps })
		"music":
			md.music = parts[1]
		"safe":
			md.safe = parts[1] == "true"
		"boss":
			md.is_boss = parts[1] == "true"
		"autosave":
			md.autosave = parts[1] == "true"
		"wander":
			md.wanders.append({ "char": parts[1], "radius": int(parts[2]), "speed": int(parts[3]) })

# ---------------- object factories ----------------
func spawn_npc(entities: Node2D, npc_id: String, cell: Vector2i) -> void:
	var npc: Node2D = preload("res://scenes/npc.tscn").instantiate()
	entities.add_child(npc)
	var wander := { "radius": 0, "speed": 0 }
	var md: MapData = parse(_map_id_of(entities))
	for w in md.wanders:
		var ch := ""
		for k in NPC_CHARS.keys():
			if NPC_CHARS[k] == npc_id:
				ch = k
		if w.char == ch:
			wander = { "radius": w.radius, "speed": w.speed }
	npc.setup(npc_id, cell, wander)

func spawn_enemy(entities: Node2D, enemy_id: String, cell: Vector2i) -> void:
	if enemy_id == "boss_kobold_lord":
		var b: Node2D = preload("res://scenes/boss.tscn").instantiate()
		entities.add_child(b)
		b.position = Vector2(cell.x * 16 + 8, cell.y * 16 + 14)
		b.setup({})
		return
	var en: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	entities.add_child(en)
	en.setup(enemy_id, cell)

func spawn_object(entities: Node2D, kind: String, cell: Vector2i, meta := {}) -> void:
	var scene_path: String = {
		"dummy": "res://scenes/dummy.tscn", "chest": "res://scenes/chest.tscn",
		"gate": "res://scenes/gate.tscn", "seal": "res://scenes/seal.tscn",
		"crystal": "res://scenes/crystal.tscn", "torch": "res://scenes/torch.tscn",
		"stairs": "res://scenes/stairs.tscn",
	}[kind]
	var obj: Node2D = load(scene_path).instantiate()
	entities.add_child(obj)
	obj.position = Vector2(cell.x * 16 + 8, cell.y * 16 + 14)
	if obj.has_method("set_meta_id") and meta.has("id"):
		obj.set_meta_id(str(meta.id))
	if obj.has_method("setup"):
		obj.setup(meta)

func _map_id_of(node: Node) -> String:
	var map_node := node
	while map_node != null and not map_node.has_method("get_map_id"):
		map_node = map_node.get_parent()
	if map_node != null and map_node.has_method("get_map_id"):
		return map_node.get_map_id()
	return ""
