extends Node
## GameState: persistent player + world state (survives map changes, saved to user://).

signal hp_changed(cur: int, maxv: int)
signal sp_changed(cur: int, maxv: int)
signal xp_changed(cur: int, next: int)
signal level_up(new_level: int)
signal col_changed(col: int)
signal potions_changed(n: int)
signal stats_changed
signal died
signal toast(text: String, color: Color)

const SAVE_VERSION := 1

var player_name := "旅人"
var level := 1
var xp := 0
var hp := 100
var sp := 100
var base_atk := 6
var base_def := 2
var col := 30

var map_id := "town"
var spawn_id := "default"
var pos := Vector2.ZERO

var flags: Dictionary = {}          # persistent story flags
var seals: Dictionary = {}          # seal_id -> true
var chests: Dictionary = {}         # chest_id -> true
var boss_defeated := false
var first_floor_done := false
var map_visited: Dictionary = {}    # "map:x,y" -> true

var play_time := 0.0
var total_kills := 0
var kills_by_enemy: Dictionary = {}

var settings: Dictionary = {
	"master": 0.8, "music": 0.65, "sfx": 0.8,
	"fullscreen": false, "shake": true,
}

var in_town := false
var stamina_idle := 0.0
var _sp_accum := 0.0
var _hp_accum := 0.0
var _xp_next: Array = []

func _ready() -> void:
	_xp_next = Config.b("player.xp_thresholds", [0, 40, 110, 220, 380])

func reset(new_name: String = "") -> void:
	var start: Dictionary = Config.b("player.start", {})
	player_name = new_name if new_name != "" else Config.b("player.default_name", "旅人")
	level = int(start.get("level", 1))
	xp = 0
	hp = int(start.get("hp", 100))
	sp = int(start.get("sp", 100))
	base_atk = int(start.get("atk", 6))
	base_def = int(start.get("def", 2))
	col = int(start.get("col", 30))
	map_id = "town"
	spawn_id = "default"
	pos = Vector2.ZERO
	flags = {}
	seals = {}
	chests = {}
	boss_defeated = false
	first_floor_done = false
	map_visited = {}
	play_time = 0.0
	total_kills = 0
	kills_by_enemy = {}
	in_town = false
	stamina_idle = 0.0
	hp_changed.emit(hp, max_hp())
	sp_changed.emit(sp, max_sp())
	xp_changed.emit(xp, xp_for_next())
	col_changed.emit(col)
	stats_changed.emit()

# ---------- derived stats ----------
func max_hp() -> int:
	var bonus := 0
	var acc := Inv.equipped.get("accessory", "")
	if acc != "":
		bonus += int(Config.item(acc).get("maxhp", 0))
	return 100 + 15 * (level - 1) + bonus

func max_sp() -> int:
	return 100 + 4 * (level - 1)

func equip_atk() -> int:
	return Inv.equip_stats().atk

func equip_def() -> int:
	return Inv.equip_stats().def

func total_atk() -> int:
	return base_atk + equip_atk()

func total_def() -> int:
	return base_def + equip_def()

func xp_for_next() -> int:
	if level >= Config.b("player.level_cap", 5):
		return -1
	if _xp_next.size() > level:
		return int(_xp_next[level])
	return 0

# ---------- xp / level ----------
func add_xp(n: int) -> void:
	if level >= Config.b("player.level_cap", 5):
		return
	xp += n
	var gained := 0
	while level < Config.b("player.level_cap", 5):
		var next := xp_for_next()
		if next < 0 or xp < next:
			break
		xp -= next
		level += 1
		gained += 1
		var up: Dictionary = Config.b("player.levelup", {})
		hp += int(up.get("max_hp", 15))
		sp = max_sp()
		base_atk += int(up.get("atk", 2))
		base_def += int(up.get("def", 1))
		level_up.emit(level)
		toast.emit("等级提升！现在等级 %d" % level, Color(1.0, 0.9, 0.4))
		AudioMan.play_sfx("levelup")
		stats_changed.emit()
	if gained > 0:
		hp_changed.emit(hp, max_hp())
		sp_changed.emit(sp, max_sp())
	xp_changed.emit(xp, xp_for_next())

# ---------- hp / sp ----------
func heal(n: int) -> void:
	hp = clampi(hp + n, 0, max_hp())
	hp_changed.emit(hp, max_hp())

func heal_full() -> void:
	hp = max_hp()
	sp = max_sp()
	hp_changed.emit(hp, max_hp())
	sp_changed.emit(sp, max_sp())

func take_damage(n: int) -> void:
	hp = clampi(hp - n, 0, max_hp())
	hp_changed.emit(hp, max_hp())
	if hp <= 0:
		died.emit()

func can_spend_sp(n: int) -> bool:
	return sp >= n

func spend_sp(n: int) -> void:
	sp = clampi(sp - n, 0, max_sp())
	stamina_idle = 0.0
	sp_changed.emit(sp, max_sp())

func add_col(n: int) -> void:
	col = maxi(0, col + n)
	col_changed.emit(col)

func spend_col(n: int) -> bool:
	if col < n:
		return false
	col -= n
	col_changed.emit(col)
	return true

# ---------- potions ----------
func potion_count() -> int:
	return Inv.count("potion")

# ---------- flags ----------
func set_flag(name: String, value = true) -> void:
	flags[name] = value

func has_flag(name: String) -> bool:
	return bool(flags.get(name, false))

func set_seal(id: String) -> void:
	seals[id] = true

func has_seal(id: String) -> bool:
	return bool(seals.get(id, false))

func open_chest(id: String) -> void:
	chests[id] = true

func is_chest_open(id: String) -> bool:
	return bool(chests.get(id, false))

func mark_visited(map: String, cell: Vector2i) -> void:
	map_visited["%s:%d,%d" % [map, cell.x, cell.y]] = true

func is_visited(map: String, cell: Vector2i) -> bool:
	return bool(map_visited.get("%s:%d,%d" % [map, cell.x, cell.y], false))

# ---------- kill tracking ----------
func notify_kill(enemy_id: String) -> void:
	total_kills += 1
	kills_by_enemy[enemy_id] = int(kills_by_enemy.get(enemy_id, 0)) + 1
	Quests.notify_kill(enemy_id)

# ---------- regen (called from _physics_process) ----------
func _physics_process(delta: float) -> void:
	if InputRouter.mode() == InputRouter.Mode.WORLD:
		regen(delta)

func regen(delta: float) -> void:
	stamina_idle += delta
	var delay := float(Config.b("combat.stamina_regen_delay", 0.75))
	var sp_rate := float(Config.b("combat.town_sp_regen_per_sec", 30.0)) if in_town \
			else float(Config.b("combat.stamina_regen_per_sec", 24.0))
	if stamina_idle >= delay and sp < max_sp():
		_sp_accum += sp_rate * delta
		var gain := int(_sp_accum)
		if gain > 0:
			_sp_accum -= gain
			sp = mini(max_sp(), sp + gain)
			sp_changed.emit(sp, max_sp())
	else:
		_sp_accum = 0.0
	if sp >= max_sp():
		_sp_accum = 0.0
	if in_town and hp < max_hp():
		_hp_accum += float(Config.b("combat.town_hp_regen_per_sec", 2.0)) * delta
		var gh := int(_hp_accum)
		if gh > 0:
			_hp_accum -= gh
			hp = mini(max_hp(), hp + gh)
			hp_changed.emit(hp, max_hp())
	if hp >= max_hp():
		_hp_accum = 0.0
	play_time += delta

# ---------- serialization ----------
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"name": player_name,
		"level": level, "xp": xp, "hp": hp, "sp": sp,
		"base_atk": base_atk, "base_def": base_def, "col": col,
		"map": map_id, "spawn": spawn_id, "pos": [pos.x, pos.y],
		"flags": flags, "seals": seals, "chests": chests,
		"boss_defeated": boss_defeated, "first_floor_done": first_floor_done,
		"map_visited": map_visited,
		"play_time": play_time, "total_kills": total_kills, "kills_by_enemy": kills_by_enemy,
		"settings": settings,
	}

func from_dict(d: Dictionary) -> void:
	player_name = str(d.get("name", "旅人"))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	hp = int(d.get("hp", 100))
	sp = int(d.get("sp", 100))
	base_atk = int(d.get("base_atk", 6))
	base_def = int(d.get("base_def", 2))
	col = int(d.get("col", 30))
	map_id = str(d.get("map", "town"))
	spawn_id = str(d.get("spawn", "default"))
	var p: Array = d.get("pos", [0.0, 0.0])
	pos = Vector2(float(p[0]), float(p[1]))
	flags = d.get("flags", {})
	seals = d.get("seals", {})
	chests = d.get("chests", {})
	boss_defeated = bool(d.get("boss_defeated", false))
	first_floor_done = bool(d.get("first_floor_done", false))
	map_visited = d.get("map_visited", {})
	play_time = float(d.get("play_time", 0.0))
	total_kills = int(d.get("total_kills", 0))
	kills_by_enemy = d.get("kills_by_enemy", {})
	var s: Dictionary = d.get("settings", {})
	for k in settings.keys():
		if s.has(k):
			settings[k] = s[k]
	hp_changed.emit(hp, max_hp())
	sp_changed.emit(sp, max_sp())
	xp_changed.emit(xp, xp_for_next())
	col_changed.emit(col)
	stats_changed.emit()
