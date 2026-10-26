extends Node2D
## Stairs in the boss room: victory settlement trigger.

var sprite: Sprite2D

func setup(meta: Dictionary) -> void:
	set_meta("id", "stairs")
	set_meta("interact_name", "通往上层的阶梯")
	add_to_group("interactables")
	sprite = $Sprite
	sprite.texture = load("res://assets/tiles/tiles.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(7 * 16, 3 * 16, 16, 16)
	sprite.offset = Vector2(0, -8)
	sprite.position = Vector2(0, -4)

func interact() -> void:
	if not GameState.boss_defeated:
		GameState.toast.emit("阶梯被强大的力量封印着……", Color(1.0, 0.75, 0.4))
		AudioMan.play_sfx("no_stamina")
		return
	if GameState.first_floor_done:
		GameState.toast.emit("第一层原型内容已完成。", Color(0.7, 1.0, 0.8))
		return
	# robustness: if the boss was already defeated while q4 was still on its kill stage,
	# complete that stage now so the settlement can never soft-lock.
	if Quests.state_of("q4") == Quests.State.ACTIVE and Quests.stage_of("q4") == 0 and GameState.boss_defeated:
		Quests.force_stage_done("q4", 0)
	Quests.notify_stairs()
	Quests.reward("q4")
	GameState.first_floor_done = true
	SaveMan.save_game()
	GameOverUI.show_victory()
