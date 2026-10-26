extends CharacterBody2D
## NPC: idle/wander animation, dialogue routing from npcs.json.

var npc_id := ""
var npc_data: Dictionary = {}
var name_text := ""
var wander_radius := 0
var wander_speed := 0
var home := Vector2.ZERO
var state := "idle"
var state_t := 0.0
var anim_t := 0.0
var dir_row := 0
var target := Vector2.ZERO
var sprite: Sprite2D
var rng := RandomNumberGenerator.new()

func setup(id: String, cell: Vector2i, wander: Dictionary) -> void:
	npc_id = id
	npc_data = Config.npc(id)
	name_text = str(npc_data.get("name", "居民"))
	wander_radius = int(wander.get("radius", 0))
	wander_speed = int(wander.get("speed", 0))
	position = Vector2(cell.x * 16 + 8, cell.y * 16 + 14)
	home = position
	add_to_group("interactables")
	set_meta("id", id)
	set_meta("interact_name", name_text)
	collision_layer = 1
	collision_mask = 1
	sprite = $Sprite
	var spr_name := str(npc_data.get("sprite", "villagers"))
	sprite.texture = load("res://assets/chars/%s.png" % spr_name)
	sprite.hframes = 18
	sprite.vframes = 4
	sprite.offset = Vector2(0, -16)
	if npc_data.has("sprite_index"):
		sprite.region_enabled = true
		sprite.region_rect = Rect2(int(npc_data.sprite_index) * 18 * 32, 0, 18 * 32, 4 * 32)
		sprite.offset = Vector2(0, -16)
	rng.randomize()

func interact() -> void:
	if MapMan.player != null:
		_face(MapMan.player.global_position - global_position)
	var start_id := _resolve_route()
	if start_id != "":
		Dialogue.start(start_id, self)

func _resolve_route() -> String:
	for route in npc_data.get("routes", []):
		var cond: Dictionary = route.get("cond", {})
		if _cond_ok(cond):
			return str(route.get("start", ""))
	return ""

func _cond_ok(cond: Dictionary) -> bool:
	for key in cond.keys():
		match key:
			"quest":
				# only check the state when the condition actually specifies one
				if cond.has("state") and Quests.state_name(str(cond[key])) != str(cond["state"]):
					return false
			"stage":
				if Quests.stage_of(str(cond.get("quest", ""))) != int(cond[key]):
					return false
			"flag":
				if GameState.has_flag(str(cond[key])) != bool(cond.get("value", true)):
					return false
			"flag_not":
				if GameState.has_flag(str(cond[key])):
					return false
			"need_done":
				if Quests.state_of(str(cond[key])) != Quests.State.REWARDED:
					return false
	return true

func _face(d: Vector2) -> void:
	if d.length() < 0.01:
		return
	if absf(d.x) > absf(d.y):
		dir_row = 2 if d.x > 0 else 1
	else:
		dir_row = 0 if d.y > 0 else 3

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	anim_t += delta
	state_t += delta
	if InputRouter.world_ok():
		if wander_radius > 0:
			match state:
				"idle":
					velocity = Vector2.ZERO
					if state_t > 1.5 + rng.randf() * 2.0:
						var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() \
								* rng.randf() * wander_radius * 16.0
						target = home + off
						state = "walk"
						state_t = 0.0
				"walk":
					var d := target - global_position
					if d.length() < 3.0 or state_t > 3.0:
						state = "idle"
						state_t = 0.0
					else:
						velocity = d.normalized() * wander_speed * 16.0
						_face(d.normalized())
		else:
			velocity = Vector2.ZERO
		move_and_slide()
	_update_anim()

func _update_anim() -> void:
	var col := int(anim_t * 2.0) % 2
	if state == "walk":
		col = 2 + int(anim_t * 7.0) % 4
	sprite.frame = dir_row * 18 + col
