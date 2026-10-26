extends Node2D
## Save crystal: full heal + manual save.

var sprite: Sprite2D

func setup(meta: Dictionary) -> void:
	set_meta("id", "crystal")
	set_meta("interact_name", "恢复点")
	add_to_group("interactables")
	sprite = $Sprite
	sprite.texture = load("res://assets/objs/crystal.png")
	sprite.hframes = 2
	sprite.offset = Vector2(0, -14)
	var tw := sprite.create_tween()
	tw.set_loops()
	tw.tween_property(sprite, "modulate", Color(1.3, 1.4, 1.6), 0.7)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.7)
	var t2 := sprite.create_tween()
	t2.set_loops()
	t2.tween_interval(0.5)
	t2.tween_callback(func(): sprite.frame = (sprite.frame + 1) % 2)

func interact() -> void:
	GameState.heal_full()
	var res := SaveMan.save_game()
	if res.ok:
		GameState.toast.emit("已恢复并保存", Color(0.7, 1.0, 0.8))
		AudioMan.play_sfx("levelup")
		Fx.spark(global_position + Vector2(0, -18))
	else:
		GameState.toast.emit("保存失败：" + res.error, Color(1.0, 0.5, 0.5))
