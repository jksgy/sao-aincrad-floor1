extends Node
## Config: loads all data/*.json at startup and exposes typed accessors.
## All tunable parameters live in data/*.json (集中配置).

var balance: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var skills: Array = []
var quests: Dictionary = {}
var npcs: Dictionary = {}
var dialogues: Dictionary = {}

func _ready() -> void:
	_ensure_user_dir()
	balance = _load_json("res://data/balance.json")
	for it in _load_json("res://data/items.json"):
		items[it.id] = it
	for en in _load_json("res://data/enemies.json"):
		enemies[en.id] = en
	skills = _load_json("res://data/skills.json")
	for q in _load_json("res://data/quests.json"):
		quests[q.id] = q
	for n in _load_json("res://data/npcs.json"):
		npcs[n.id] = n
	dialogues = _load_json("res://data/dialogues.json")

func _load_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("config: cannot open " + path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("config: bad json " + path)
		return {}
	return data

func _ensure_user_dir() -> void:
	# Keep user:// usable even on machines with unusual profile permissions.
	var dir := OS.get_user_data_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			push_error("cannot create user dir: %s (error %d)" % [dir, err])
			OS.alert("无法创建游戏数据目录：\n%s\n错误码：%d" % [dir, err], "AincradProto")
			get_tree().quit(1)

func item(id: String) -> Dictionary:
	return items.get(id, {})

func enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func quest(id: String) -> Dictionary:
	return quests.get(id, {})

func npc(id: String) -> Dictionary:
	return npcs.get(id, {})

func dialogue(id: String) -> Array:
	var d = dialogues.get(id, [])
	return d if d is Array else []

func skill(id: String) -> Dictionary:
	for s in skills:
		if s.id == id:
			return s
	return {}

func b(path: String, default = null):
	# dotted path access into balance, e.g. b("attack.range")
	var node: Variant = balance
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return default
	return node
