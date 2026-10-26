extends Node2D
## Seal device: activates a named seal (quest + gate deps), visual state change.

var seal_id := ""
var active := false
var sprite: Sprite2D
var glow: Sprite2D

func set_meta_id(id: String) -> void:
	seal_id = id

func setup(meta: Dictionary) -> void:
	seal_id = str(meta.get("id", seal_id))
	set_meta("id", seal_id)
	set_meta("interact_name", "封印机关")
	add_to_group("interactables")
	sprite = $Sprite
	sprite.texture = load("res://assets/objs/seal.png")
	sprite.hframes = 2
	sprite.offset = Vector2(0, -14)
	active = GameState.has_seal(seal_id)
	sprite.frame = 1 if active else 0
	if active:
		_twinkle()

func interact() -> void:
	if active:
		GameState.toast.emit("封印机关已经激活", Color(0.7, 0.9, 1.0))
		return
	active = true
	GameState.set_seal(seal_id)
	sprite.frame = 1
	AudioMan.play_sfx("lever")
	Fx.spark(global_position + Vector2(0, -16))
	_twinkle()
	Quests.notify_seal(seal_id)
	var total := 0
	var done := 0
	for id in ["seal_b", "seal_c"]:
		total += 1
		if GameState.has_seal(id):
			done += 1
	GameState.toast.emit("封印机关已激活（%d/%d）" % [done, total], Color(0.6, 1.0, 0.9))
	# refresh gates
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.has_method("refresh_gate"):
			node.refresh_gate()

func _twinkle() -> void:
	var tw := sprite.create_tween()
	tw.set_loops()
	tw.tween_property(sprite, "modulate", Color(1.4, 1.5, 1.6), 0.8)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.8)
