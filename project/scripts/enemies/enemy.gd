extends CharacterBody2D
## Enemy: shared FSM for boar / wolf / guardian. Behavior tuned by data/enemies.json.

var data: Dictionary = {}
var enemy_id := ""
var def_value := 0
var hp := 0
var max_hp := 0
var home := Vector2.ZERO

var state := "idle"
var state_t := 0.0
var anim_t := 0.0
var patrol_target := Vector2.ZERO
var strike_dir := Vector2.DOWN
var dir_row := 0
var has_hit := false
var dead := false
var awarded := false
var attack_cd := 0.0
var flash_t := 0.0
var knock_t := 0.0
var knock_vel := Vector2.ZERO
var player_ref: Node2D = null
var sprite: Sprite2D
var telegraph: Node2D
var rng := RandomNumberGenerator.new()

func setup(eid: String, cell: Vector2i) -> void:
	enemy_id = eid
	data = Config.enemy(eid)
	def_value = int(data.get("def", 1))
	max_hp = int(data.get("hp", 10))
	hp = max_hp
	position = Vector2(cell.x * 16 + 8, cell.y * 16 + 14)
	home = position
	add_to_group("enemy")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	sprite = $Sprite
	sprite.texture = load("res://assets/enem/%s.png" % data.get("sprite", "boar"))
	sprite.hframes = 18
	sprite.vframes = 4
	sprite.offset = Vector2(0, -16)
	telegraph = $Telegraph
	rng.randomize()
	patrol_target = home

func _find_player() -> void:
	if MapMan.player == null:
		player_ref = null
		return
	player_ref = MapMan.player

func _los_clear() -> bool:
	if player_ref == null:
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, player_ref.global_position, 1)
	var hit := space.intersect_ray(q)
	return hit.is_empty()

func _physics_process(delta: float) -> void:
	if get_tree().paused or dead:
		return
	anim_t += delta
	state_t += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	flash_t = maxf(0.0, flash_t - delta)
	knock_t = maxf(0.0, knock_t - delta)
	modulate = Color(1.6, 1.6, 1.6) if flash_t > 0.0 else Color.WHITE
	if not InputRouter.world_ok():
		_update_anim()
		return
	_find_player()
	if knock_t > 0.0:
		velocity = knock_vel * (knock_t / 0.12)
		move_and_slide()
	else:
		match state:
			"idle": _s_idle(delta)
			"patrol": _s_patrol(delta)
			"alert": _s_alert(delta)
			"chase": _s_chase(delta)
			"windup": _s_windup(delta)
			"strike": _s_strike(delta)
			"recover": _s_recover(delta)
			"return": _s_return(delta)
	_separate()
	_update_anim()

func _can_see_player() -> bool:
	if player_ref == null:
		return false
	var vision := float(data.get("vision", 120.0))
	if global_position.distance_to(player_ref.global_position) > vision:
		return false
	return _los_clear()

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	if s != "windup":
		telegraph.hide()

func _face_player() -> void:
	if player_ref == null:
		return
	var d := player_ref.global_position - global_position
	if d.length() < 0.01:
		return
	if absf(d.x) > absf(d.y):
		strike_dir = Vector2.RIGHT if d.x > 0 else Vector2.LEFT
	else:
		strike_dir = Vector2.DOWN if d.y > 0 else Vector2.UP
	dir_row = { Vector2(0, 1): 0, Vector2(-1, 0): 1, Vector2(1, 0): 2, Vector2(0, -1): 3 }[strike_dir]

func _s_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	if _can_see_player():
		_set_state("alert")
		return
	if state_t > 1.2 + rng.randf() * 1.6:
		var off := Vector2(rng.randf_range(-28, 28), rng.randf_range(-28, 28))
		patrol_target = home + off
		_set_state("patrol")

func _s_patrol(delta: float) -> void:
	if _can_see_player():
		_set_state("alert")
		return
	var d := patrol_target - global_position
	if d.length() < 4.0 or state_t > 5.0:
		_set_state("idle")
		return
	velocity = d.normalized() * float(data.get("speed", 30.0))
	_face_dir(d.normalized())
	move_and_slide()

func _s_alert(delta: float) -> void:
	velocity = Vector2.ZERO
	if state_t > 0.35:
		_set_state("chase")

func _s_chase(delta: float) -> void:
	if player_ref == null:
		_set_state("return")
		return
	var leash := float(data.get("leash", 200.0))
	var d := player_ref.global_position - global_position
	if global_position.distance_to(home) > leash:
		_set_state("return")
		return
	_face_dir(d.normalized())
	var range_px := float(data.get("attack_range", 26.0))
	if d.length() <= range_px and attack_cd <= 0.0:
		_set_state("windup")
		return
	velocity = d.normalized() * float(data.get("chase_speed", 50.0))
	move_and_slide()

func _s_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	var windup := float(data.get("windup", 0.5))
	if state_t <= delta:
		_face_player()
		var atype := str(data.get("attack_type", "swing"))
		if atype == "swing":
			telegraph.show_arc(strike_dir, float(data.get("swing_arc", 90.0)),
					float(data.get("attack_range", 38.0)))
		elif atype == "charge":
			telegraph.show_line(strike_dir, float(data.get("charge_dist", 44.0)) + 12.0, 22.0)
		else:
			telegraph.show_line(strike_dir, float(data.get("pounce_dist", 56.0)) + 10.0, 24.0)
	if state_t >= windup:
		has_hit = false
		_set_state("strike")

func _s_strike(delta: float) -> void:
	var strike_time := float(data.get("strike_time", 0.2))
	var atype := str(data.get("attack_type", "swing"))
	match atype:
		"charge":
			velocity = strike_dir * (float(data.get("charge_dist", 44.0)) / strike_time)
			move_and_slide()
			_try_hit(float(data.get("attack_range", 22.0)) + 10.0, 1.0, 360.0)
		"pounce":
			velocity = (player_ref.global_position - global_position).normalized() * \
					(float(data.get("pounce_dist", 56.0)) / strike_time)
			move_and_slide()
			_try_hit(float(data.get("attack_range", 26.0)) + 14.0, 1.0, 360.0)
		"swing":
			velocity = Vector2.ZERO
			_try_hit(float(data.get("attack_range", 38.0)), 1.0, float(data.get("swing_arc", 90.0)))
	if state_t >= strike_time:
		_set_state("recover")
		attack_cd = 0.7 + rng.randf() * 0.6

func _try_hit(dist: float, mult: float, arc_deg: float) -> void:
	if has_hit or player_ref == null:
		return
	var to_p := player_ref.global_position - global_position
	if to_p.length() > dist:
		return
	if arc_deg < 360.0 and strike_dir.angle_to(to_p) > deg_to_rad(arc_deg * 0.5):
		return
	has_hit = true
	var dmg := maxi(1, int(round(float(data.get("atk", 10)) * mult - GameState.total_def())))
	player_ref.take_damage(dmg, global_position)

func _s_recover(delta: float) -> void:
	velocity = Vector2.ZERO
	if state_t >= float(data.get("recover", 0.9)):
		_set_state("chase")

func _s_return(delta: float) -> void:
	var d := home - global_position
	if d.length() < 4.0:
		hp = max_hp
		_set_state("idle")
		return
	velocity = d.normalized() * float(data.get("speed", 30.0))
	_face_dir(d.normalized())
	hp = mini(max_hp, hp + int(round(float(Config.b("enemy_general.return_heal", 20.0)) * delta)))
	move_and_slide()

func _face_dir(d: Vector2) -> void:
	if absf(d.x) > absf(d.y):
		strike_dir = Vector2.RIGHT if d.x > 0 else Vector2.LEFT
	else:
		strike_dir = Vector2.DOWN if d.y > 0 else Vector2.UP
	dir_row = { Vector2(0, 1): 0, Vector2(-1, 0): 1, Vector2(1, 0): 2, Vector2(0, -1): 3 }[strike_dir]

func _separate() -> void:
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is Node2D):
			continue
		var d: Vector2 = global_position - other.global_position
		var min_d := float(Config.b("enemy_general.separation", 10.0))
		if d.length() > 0.01 and d.length() < min_d:
			global_position += d.normalized() * (min_d - d.length()) * 0.5

func take_damage(dmg: int, from_pos: Vector2) -> void:
	if dead:
		return
	hp -= dmg
	flash_t = 0.12
	var kb := (global_position - from_pos)
	if kb.length() > 0.01:
		knock_vel = kb.normalized() * 70.0
		knock_t = 0.12
	Fx.float_text(global_position + Vector2(0, -26), "-%d" % dmg, Color(1.0, 0.8, 0.4), 13)
	if state == "windup":
		_set_state("recover")
		attack_cd = 0.5
	if hp <= 0:
		_die()

func _die() -> void:
	if awarded:
		return
	awarded = true
	dead = true
	_set_state("dead")
	velocity = Vector2.ZERO
	collision_layer = 0
	GameState.add_xp(int(data.get("xp", 0)))
	GameState.add_col(int(data.get("col", 0)))
	GameState.notify_kill(enemy_id)
	AudioMan.play_sfx("die")
	Fx.spark(global_position + Vector2(0, -16))
	Fx.float_text(global_position + Vector2(0, -30), "+%d 经验" % int(data.get("xp", 0)), Color(0.7, 1.0, 0.7), 12)
	_roll_drop()
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(queue_free)

func _roll_drop() -> void:
	var chance := float(data.get("drop_chance", 0.0))
	if chance <= 0.0 or rng.randf() > chance:
		return
	if Inv.can_add("meat", 1):
		Inv.add_item("meat", 1)
		GameState.toast.emit("获得 兽肉", Color(0.9, 0.85, 0.6))
	else:
		var pickup: Node2D = preload("res://scenes/pickup.tscn").instantiate()
		get_parent().add_child(pickup)
		pickup.position = global_position + Vector2(0, -8)
		pickup.setup({ "id": "meat" })
		GameState.toast.emit("背包已满，掉落物留在了原地", Color(1.0, 0.75, 0.4))

func _update_anim() -> void:
	var col := 0
	match state:
		"idle":
			col = int(anim_t * 2.0) % 2
		"patrol", "return":
			col = 2 + int(anim_t * 7.0) % 4
		"alert":
			col = 11 + int(anim_t * 8.0) % 3
		"chase":
			col = 2 + int(anim_t * 8.0) % 4
		"windup":
			col = 6
		"strike":
			col = 7 + int(state_t / 0.07) % 2
		"recover":
			col = 9
		"dead":
			col = 14 + mini(3, int(state_t / 0.3))
	sprite.frame = dir_row * 18 + col
