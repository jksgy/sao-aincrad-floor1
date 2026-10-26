extends CharacterBody2D
## Boss: kobold lord, two phases. Windup -> strike -> recover with telegraphed attacks.

signal boss_hp_changed(cur: int, maxv: int)
signal boss_fight_started
signal boss_died

var data: Dictionary = {}
var hp := 900
var max_hp := 900
var def_value := 5
var fight_started := false
var fight_active := false
var phase2 := false
var dead := false
var awarded := false

var state := "idle"          # idle intro choose windup strike recover roar dead
var attack_name := ""
var state_t := 0.0
var anim_t := 0.0
var strike_dir := Vector2.DOWN
var dir_row := 0
var has_hit := false
var flash_t := 0.0
var player_ref: Node2D = null
var sprite: Sprite2D
var telegraph: Node2D
var home := Vector2.ZERO
var attack_cds := { "sweep": 0.0, "charge": 0.0, "slam": 0.0 }
var last_attack := ""
var dash_start := Vector2.ZERO
var speed_mult := 1.0

func setup(meta: Dictionary) -> void:
	data = Config.b("boss", {})
	hp = int(data.get("hp", 900))
	max_hp = hp
	def_value = int(data.get("def", 5))
	home = position
	add_to_group("enemy")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2
	sprite = $Sprite
	sprite.texture = load("res://assets/enem/boss.png")
	sprite.hframes = 18
	sprite.vframes = 4
	sprite.offset = Vector2(0, -32)
	telegraph = $Telegraph
	MapMan.boss = self

func _find_player() -> void:
	player_ref = MapMan.player

func start_intro() -> void:
	fight_started = true
	_face_player()
	Dialogue.start_auto("boss_intro", self, _on_intro_done)

func _on_intro_done() -> void:
	start_fight()

func start_fight() -> void:
	fight_active = true
	boss_fight_started.emit()
	_set_gate(true)
	if MapMan.current_map != null:
		MapMan.current_map.boss_zoom(float(Config.b("camera.boss_zoom", 0.85)))
	_set_state("choose")
	state_t = 1.2

func _set_gate(closed: bool) -> void:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get_meta("id", "") == "boss_entry_gate":
			node.set_boss_closed(closed)

func _physics_process(delta: float) -> void:
	if dead:
		return
	anim_t += delta
	state_t += delta
	flash_t = maxf(0.0, flash_t - delta)
	modulate = Color(1.6, 1.6, 1.6) if flash_t > 0.0 else (Color(1.25, 0.85, 0.8) if phase2 else Color.WHITE)
	for k in attack_cds.keys():
		attack_cds[k] = maxf(0.0, attack_cds[k] - delta)
	if not fight_active:
		_update_anim()
		return
	if not InputRouter.world_ok():
		return
	_find_player()
	match state:
		"choose": _s_choose(delta)
		"windup": _s_windup(delta)
		"strike": _s_strike(delta)
		"recover": _s_recover(delta)
		"roar": _s_roar(delta)
		"back": _s_back(delta)
	move_and_slide()
	_update_anim()

func _s_choose(delta: float) -> void:
	velocity = Vector2.ZERO
	if state_t < 0.8:
		return
	if player_ref == null:
		_set_state("back")
		return
	if player_ref.state == player_ref.State.DEAD:
		_set_state("back")
		return
	var dist := global_position.distance_to(player_ref.global_position)
	var options: Array = []
	if dist > 85.0 and attack_cds.charge <= 0.0:
		options.append("charge")
	if dist > 40.0 and attack_cds.sweep <= 0.0:
		options.append("sweep")
	if dist <= 60.0 and attack_cds.slam <= 0.0:
		options.append("slam")
	if options.is_empty():
		# close distance
		if player_ref != null:
			_face_player()
			velocity = strike_dir * 60.0 * speed_mult
		return
	# phase2 combo: charge is followed by slam
	if phase2 and last_attack == "charge" and attack_cds.slam <= 0.0 and dist <= 130.0:
		options = ["slam"]
	attack_name = options.pick_random()
	last_attack = attack_name
	_set_state("windup")

func _s_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	if player_ref == null:
		_set_state("back")
		return
	if state_t <= delta:
		_face_player()
		var spec: Dictionary = data.get(attack_name, {})
		match attack_name:
			"sweep":
				telegraph.show_arc(strike_dir, float(spec.get("arc_deg", 110.0)), float(spec.get("range", 60.0)))
			"charge":
				telegraph.show_line(strike_dir, float(spec.get("distance", 160.0)), 30.0)
			"slam":
				telegraph.show_circle(float(spec.get("radius", 50.0)))
	var spec: Dictionary = data.get(attack_name, {})
	if state_t >= float(spec.get("windup", 0.75)):
		has_hit = false
		dash_start = global_position
		_set_state("strike")

func _s_strike(delta: float) -> void:
	var spec: Dictionary = data.get(attack_name, {})
	match attack_name:
		"sweep":
			velocity = Vector2.ZERO
			_try_hit(float(spec.get("range", 60.0)), float(spec.get("mult", 1.0)), float(spec.get("arc_deg", 110.0)))
			if state_t >= 0.16:
				attack_cds[attack_name] = 3.0
				_set_state("recover")
		"charge":
			velocity = strike_dir * (float(spec.get("distance", 160.0)) / 0.4) * speed_mult
			if global_position.distance_to(dash_start) < float(spec.get("distance", 160.0)):
				_try_hit(40.0, float(spec.get("mult", 1.4)), 360.0)
			if state_t >= 0.4 or global_position.distance_to(dash_start) >= float(spec.get("distance", 160.0)) - 4.0:
				attack_cds[attack_name] = 4.0
				_set_state("recover")
		"slam":
			velocity = Vector2.ZERO
			if state_t >= 0.25 and state_t <= 0.35:
				_try_hit(float(spec.get("radius", 50.0)), float(spec.get("mult", 1.3)), 360.0)
			if state_t >= 0.4:
				attack_cds[attack_name] = 3.5
				_set_state("recover")

func _s_recover(delta: float) -> void:
	velocity = Vector2.ZERO
	var spec: Dictionary = data.get(attack_name, {})
	var t := float(spec.get("recover", 0.8))
	if state_t >= t / speed_mult:
		_set_state("choose")

func _s_roar(delta: float) -> void:
	velocity = Vector2.ZERO
	if state_t >= 1.1:
		_set_state("choose")
		state_t = 0.6

func _s_back(delta: float) -> void:
	var d := home - global_position
	if d.length() < 6.0:
		velocity = Vector2.ZERO
		_set_state("choose")
		state_t = 0.6
		return
	velocity = d.normalized() * 60.0
	_face_dir(d.normalized())

func _try_hit(dist: float, mult: float, arc_deg: float) -> void:
	if has_hit or player_ref == null:
		return
	if player_ref.state == player_ref.State.DEAD:
		return
	var to_p := player_ref.global_position - global_position
	if to_p.length() > dist:
		return
	if arc_deg < 360.0 and strike_dir.angle_to(to_p) > deg_to_rad(arc_deg * 0.5):
		return
	has_hit = true
	var dmg := maxi(1, int(round(float(data.get("atk", 24)) * mult - GameState.total_def())))
	player_ref.take_damage(dmg, global_position)
	Fx.dust(global_position + Vector2(0, -10))

func take_damage(dmg: int, from_pos: Vector2) -> void:
	if dead or not fight_active:
		return
	hp -= dmg
	flash_t = 0.1
	Fx.float_text(global_position + Vector2(0, -40), "-%d" % dmg, Color(1.0, 0.85, 0.5), 14)
	boss_hp_changed.emit(hp, max_hp)
	if not phase2 and hp <= int(max_hp * float(data.get("phase2_hp_ratio", 0.4))):
		_start_phase2()
	if hp <= 0:
		_die()

func _start_phase2() -> void:
	phase2 = true
	speed_mult = float(data.get("phase2_speed_mult", 1.35))
	AudioMan.play_sfx("roar")
	GameState.toast.emit("狗头人领主进入了狂暴状态！", Color(1.0, 0.4, 0.3))
	if MapMan.current_map != null:
		MapMan.current_map.apply_shake(3.0)
	_set_state("roar")

func _die() -> void:
	if awarded:
		return
	awarded = true
	dead = true
	fight_active = false
	velocity = Vector2.ZERO
	telegraph.hide()
	collision_layer = 0
	_set_state("dead")
	GameState.boss_defeated = true
	GameState.add_xp(int(data.get("xp", 200)))
	GameState.add_col(int(data.get("col", 120)))
	GameState.notify_kill("boss_kobold_lord")
	AudioMan.play_sfx("victory")
	GameState.toast.emit("守层 Boss「狗头人领主」被击败！", Color(1.0, 0.9, 0.4))
	_set_gate(false)
	boss_died.emit()
	if MapMan.current_map != null:
		MapMan.current_map.boss_zoom(float(Config.b("camera.normal_zoom", 1.0)))

func _face_player() -> void:
	if player_ref == null:
		return
	var d := player_ref.global_position - global_position
	if d.length() < 0.01:
		return
	_face_dir(d.normalized())

func _face_dir(d: Vector2) -> void:
	if absf(d.x) > absf(d.y):
		strike_dir = Vector2.RIGHT if d.x > 0 else Vector2.LEFT
	else:
		strike_dir = Vector2.DOWN if d.y > 0 else Vector2.UP
	dir_row = { Vector2(0, 1): 0, Vector2(-1, 0): 1, Vector2(1, 0): 2, Vector2(0, -1): 3 }[strike_dir]

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	if s != "windup":
		telegraph.hide()

func _update_anim() -> void:
	var col := 0
	match state:
		"idle", "choose", "back":
			col = 0 if state == "idle" else (2 + int(anim_t * 6.0) % 4)
			if state == "idle":
				col = int(anim_t * 2.0) % 2
		"windup":
			col = 6
		"strike":
			col = 7 + int(state_t / 0.08) % 2
		"recover":
			col = 9
		"roar":
			col = 11 + int(anim_t * 6.0) % 3
		"dead":
			col = 14 + mini(3, int(state_t / 0.35))
	sprite.frame = dir_row * 18 + col
