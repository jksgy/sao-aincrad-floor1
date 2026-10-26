extends Node2D
## Training dummy: tutorial target, no XP, no repeat farming.

var sprite: Sprite2D
var anim_t := 0.0

func setup(meta: Dictionary) -> void:
	set_meta("id", "dummy")
	set_meta("interact_name", "训练木桩")
	add_to_group("interactables")
	add_to_group("dummy")
	var body := StaticBody2D.new()
	body.collision_layer = 1 | 8
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(10, 14)
	shape.shape = rs
	shape.position = Vector2(0, -7)
	body.add_child(shape)
	add_child(body)
	sprite = $Sprite
	sprite.texture = load("res://assets/objs/dummy.png")
	sprite.hframes = 4
	sprite.offset = Vector2(0, -16)

func interact() -> void:
	GameState.toast.emit("训练木桩：按 J 攻击它试试", Color(0.8, 0.9, 1.0))

func on_hit(from_pos: Vector2) -> void:
	Fx.spark(global_position + Vector2(0, -14))
	AudioMan.play_sfx("hit")
	sprite.frame = (sprite.frame + 1) % 4
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + signf(position.x - from_pos.x) * 2.0, 0.06)
	tw.tween_property(self, "position:x", position.x, 0.08)
	Quests.notify_hit_dummy()
	# guidance when the player hasn't reached the dummy stage yet
	if Quests.state_of("q1") == Quests.State.ACTIVE and Quests.stage_of("q1") < 2:
		GameState.toast.emit("挥剑的手感不错。先找桐人聊聊战斗技巧吧。", Color(0.8, 0.9, 1.0))

func _physics_process(delta: float) -> void:
	anim_t += delta
	if int(anim_t * 2.0) % 2 == 0:
		sprite.frame = sprite.frame  # keep hit feedback frame
