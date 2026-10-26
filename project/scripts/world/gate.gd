extends Node2D
## Gate: closed until all dep seals active. Boss entry gate is controlled by the boss fight.

var gate_id := ""
var deps: Array = []
var boss_controlled := false
var open := false
var body: StaticBody2D
var sprite: Sprite2D

func set_meta_id(id: String) -> void:
	gate_id = id

func gate_meta(g: Dictionary) -> void:
	deps = g.get("deps", [])
	refresh_gate()

func setup(meta: Dictionary) -> void:
	gate_id = str(meta.get("id", gate_id))
	set_meta("id", gate_id)
	set_meta("interact_name", "大门")
	add_to_group("interactables")
	body = $Body
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape2D = body.get_node("Shape")
	shape.position = Vector2(0, -8)
	sprite = $Sprite
	sprite.texture = load("res://assets/objs/gate.png")
	sprite.hframes = 3
	sprite.offset = Vector2(0, -16)
	refresh_gate()

func refresh_gate() -> void:
	if boss_controlled:
		return
	var should_open := true
	for d in deps:
		if not GameState.has_seal(str(d)):
			should_open = false
	open = should_open
	_update()

func set_boss_closed(closed: bool) -> void:
	boss_controlled = true
	open = not closed
	_update()

func _update() -> void:
	if body == null:
		return
	var shape: CollisionShape2D = body.get_node("Shape")
	shape.disabled = open
	sprite.frame = 2 if open else 0

func interact() -> void:
	if boss_controlled and not open:
		GameState.toast.emit("战斗结束前无法离开！", Color(1.0, 0.6, 0.4))
		return
	if open:
		GameState.toast.emit("门已经打开", Color(0.7, 0.9, 1.0))
		return
	if deps.is_empty():
		GameState.toast.emit("这扇门被某种力量封锁着……", Color(1.0, 0.75, 0.4))
		return
	var need: Array = []
	for d in deps:
		if not GameState.has_seal(str(d)):
			need.append(str(d))
	GameState.toast.emit("封印尚未解除（还需 %d 处）" % need.size(), Color(1.0, 0.75, 0.4))
	AudioMan.play_sfx("no_stamina")
