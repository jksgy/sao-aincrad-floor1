extends Node
## MapManager: map transitions with fade, player instance ownership, boss registry.

signal map_changed(map_id: String)

var current_map: Node2D = null
var player: CharacterBody2D = null
var boss: Node2D = null
var transitioning := false
var _fade_layer: CanvasLayer
var _fade: ColorRect
var builder := MapBuilder.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	_fade.modulate.a = 0.0

func change_map(map_id: String, spawn_id: String) -> void:
	if transitioning:
		return
	transitioning = true
	var tw := _fade.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "modulate:a", 1.0, 0.22)
	await tw.finished
	_teardown_map()
	_spawn_map(map_id)
	place_player(spawn_id)
	var tw2 := _fade.create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.22)
	await tw2.finished
	transitioning = false
	map_changed.emit(map_id)

func _teardown_map() -> void:
	boss = null
	GameState.in_town = false
	if player != null and is_instance_valid(player):
		var parent := player.get_parent()
		if parent != null:
			parent.remove_child(player)
	if current_map != null and is_instance_valid(current_map):
		current_map.queue_free()
	current_map = null

func _spawn_map(map_id: String) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var host := root.get_node_or_null("World") if root.has_node("World") else root
	current_map = builder.build(map_id, host)
	GameState.map_id = map_id
	Quests.notify_enter_map(map_id)
	if player == null or not is_instance_valid(player):
		player = preload("res://scenes/player.tscn").instantiate()
	var entities := current_map.get_node("Entities")
	entities.add_child(player)

func place_player(spawn_id: String) -> void:
	if current_map == null or player == null or not is_instance_valid(player):
		return
	var pos: Vector2 = current_map.player_spawn_pos(spawn_id)
	player.position = pos
	GameState.pos = pos
	GameState.spawn_id = spawn_id
	player.reset_to_spawn()
	var md: MapBuilder.MapData = current_map.get_meta("data")
	if md.autosave:
		var res := SaveMan.save_game()
		if res.ok:
			GameState.toast.emit("已自动保存", Color(0.7, 0.9, 1.0))
		else:
			GameState.toast.emit("自动保存失败：" + res.error, Color(1.0, 0.5, 0.5))
	if current_map.camera != null:
		current_map.camera.make_current()
		current_map.camera.reset_smoothing()
		current_map.camera.global_position = pos

func exit_requested(target: String, spawn_id: String) -> void:
	if transitioning:
		return
	change_map(target, spawn_id)

func load_game_into_world() -> void:
	# after SaveMan.load_game: restore map + player
	await change_map(GameState.map_id, GameState.spawn_id)
	if player != null and GameState.pos != Vector2.ZERO:
		if _cell_walkable(GameState.pos):
			player.position = GameState.pos
			if current_map != null and current_map.camera != null:
				current_map.camera.global_position = GameState.pos
				current_map.camera.reset_smoothing()

func _cell_walkable(pos: Vector2) -> bool:
	if current_map == null:
		return false
	var md: MapBuilder.MapData = current_map.get_meta("data")
	var cell := Vector2i(int(pos.x / 16), int(pos.y / 16))
	if cell.x < 0 or cell.y < 0 or cell.x >= md.size.x or cell.y >= md.size.y:
		return false
	var ch: String = md.grid[cell.y][cell.x]
	return ch != " " and not MapBuilder.is_solid(ch)

func set_camera_target() -> void:
	if current_map != null and current_map.camera != null and player != null:
		current_map.camera.global_position = player.global_position
		current_map.camera.reset_smoothing()
