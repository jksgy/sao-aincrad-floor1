extends Node
## ShotRunner: verification harness, active only with user arg --shots.
## Captures gameplay screenshots with real rendering, then quits.

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--shots"):
		return
	call_deferred("_run")

func _run() -> void:
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func():
		print("SHOTS TIMEOUT")
		get_tree().quit(2))
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	await shot("00_title")
	GameState.reset("测试者")
	Quests.reset()
	Quests.accept("q1")
	Inv.start_items()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	await wait_secs(0.8)
	HUD.show_all()
	await MapMan.change_map("town", "default")
	await wait_frames(20)
	await shot("01_town")
	var p: CharacterBody2D = MapMan.player
	if p != null and is_instance_valid(p):
		p.global_position = Vector2(40 * 16 + 8, 34 * 16 + 12)
		await wait_frames(15)
		for node in get_tree().get_nodes_in_group("interactables"):
			if node.get_meta("id", "") == "klein":
				node.interact()
		await wait_frames(20)
		await shot("02_dialogue")
		Dialogue._close()
	InvUI.open_ui()
	await wait_frames(5)
	await shot("03_inventory")
	InvUI.close()
	MapUI.open_ui()
	await wait_frames(5)
	await shot("04_map")
	MapUI.close()
	PauseMenu.open_ui()
	await wait_frames(5)
	await shot("05_pause")
	PauseMenu.close()
	await MapMan.change_map("field", "from_town")
	await wait_frames(15)
	await shot("06_field")
	if p != null and is_instance_valid(p):
		var boar: Node2D = null
		for n in get_tree().get_nodes_in_group("enemies"):
			boar = n
			break
		if boar != null:
			p.global_position = boar.global_position + Vector2(30, 0)
			p.try_attack()
			await wait_frames(8)
			await shot("07_combat")
	await MapMan.change_map("maze_a", "from_field")
	await wait_frames(15)
	await shot("08_maze_a")
	GameState.set_seal("seal_b")
	GameState.set_seal("seal_c")
	await MapMan.change_map("boss", "default")
	await wait_frames(15)
	var boss := MapMan.boss
	if boss != null and is_instance_valid(boss):
		if p != null and is_instance_valid(p):
			p.global_position = Vector2(20 * 16 + 8, 21 * 16)
		await wait_secs(1.2)
		if Dialogue.visible:
			await shot("09_boss_intro")
			for i in 4:
				if Dialogue.visible and Dialogue._choices_box.get_child_count() == 0:
					Dialogue._on_choice_pressed(0)
				await wait_frames(5)
		await wait_secs(2.0)
		await shot("10_boss_fight")
	GameOverUI.show_victory()
	await wait_frames(5)
	await shot("11_victory")
	print("SHOTS DONE")
	await wait_secs(0.3)
	get_tree().quit(0)

func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shots/%s.png" % name)
	print("shot: %s (%dx%d)" % [name, img.get_width(), img.get_height()])

func wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait_secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout
