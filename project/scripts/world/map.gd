extends Node2D
## Map node: camera, safe-zone handling, music, boss trigger, exits are built by MapBuilder.

var map_id := ""
var size := Vector2i.ZERO
var safe := false
var music_id := "town"
var is_boss := false
var boss_started := false
var camera: Camera2D
var shake_t := 0.0
var shake_amp := 0.0
var rng := RandomNumberGenerator.new()

func get_map_id() -> String:
	return map_id

func setup(md) -> void:
	map_id = md.id
	size = md.size
	safe = md.safe
	music_id = md.music
	is_boss = md.is_boss
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = Config.b("camera.smoothing", 5.0)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = size.x * 16
	camera.limit_bottom = size.y * 16
	camera.position = Vector2(size.x * 8, size.y * 8)
	camera.zoom = Vector2.ONE * Config.b("camera.normal_zoom", 1.0)
	add_child(camera)
	if is_boss:
		_build_boss_trigger()
	if map_id == "maze_c":
		_build_boss_door_trigger()
	if safe:
		GameState.in_town = true
	AudioMan.play_music(music_id)

func _build_boss_door_trigger() -> void:
	# pre-boss room: reaching it completes q3's "reach boss door" step and
	# Asuna greets the player once.
	var area := Area2D.new()
	area.position = Vector2(27 * 16, 4 * 16)
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(11 * 16, 5 * 16)
	shape.shape = rs
	area.add_child(shape)
	$Areas.add_child(area)
	area.body_entered.connect(_on_boss_door_trigger)

func _on_boss_door_trigger(body: Node2D) -> void:
	if not (body is CharacterBody2D) or not body.is_in_group("player"):
		return
	Quests.notify_reach_boss_door()
	if not GameState.has_flag("asuna_talked") and not Dialogue.visible:
		Dialogue.start("asuna_prep")

func _build_boss_trigger() -> void:
	var area := Area2D.new()
	area.position = Vector2(size.x * 8, 21 * 16)
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(size.x * 16, 2 * 16)
	shape.shape = rs
	area.add_child(shape)
	$Areas.add_child(area)
	area.body_entered.connect(_on_boss_trigger)

func _on_boss_trigger(body: Node2D) -> void:
	if boss_started or not (body is CharacterBody2D) or not body.is_in_group("player"):
		return
	if GameState.boss_defeated:
		return
	boss_started = true
	var boss := MapMan.boss
	if boss != null and not boss.fight_started:
		boss.start_intro()

func apply_shake(amp: float) -> void:
	if not bool(GameState.settings.get("shake", true)):
		return
	shake_amp = maxf(shake_amp, amp)
	shake_t = maxf(shake_t, 0.25)

func _process(delta: float) -> void:
	if camera == null:
		return
	if MapMan.player != null:
		camera.global_position = MapMan.player.global_position
	if shake_t > 0.0:
		shake_t -= delta
		var k := clampf(shake_t / 0.25, 0.0, 1.0)
		camera.offset = Vector2(
			rng.randf_range(-1, 1) * shake_amp * k,
			rng.randf_range(-1, 1) * shake_amp * k)
	else:
		camera.offset = Vector2.ZERO

func boss_zoom(value: float) -> void:
	if camera == null:
		return
	var tw := camera.create_tween()
	tw.tween_property(camera, "zoom", Vector2.ONE * value, 0.6)

func player_spawn_pos(spawn_id: String) -> Vector2:
	var md: MapBuilder.MapData = get_meta("data")
	if md.spawns.has(spawn_id):
		return md.spawns[spawn_id]
	if md.spawns.has("default"):
		return md.spawns["default"]
	return Vector2(size.x * 8, size.y * 8)
