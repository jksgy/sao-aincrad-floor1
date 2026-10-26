extends CharacterBody2D
## Player: state machine (idle/move/attack 3-combo/skill dash/dodge/hurt/dead) + interact.

signal player_died

enum State { IDLE, MOVE, ATTACK, SKILL, DODGE, HURT, DEAD }

const DIR_ROWS := { "down": 0, "left": 1, "right": 2, "up": 3 }
const FACE_VECS := { "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP }
const DIR_FROM_VEC := { Vector2(0, 1): "down", Vector2(-1, 0): "left", Vector2(1, 0): "right", Vector2(0, -1): "up" }

var state := State.IDLE
var dir_name := "down"
var facing := Vector2.DOWN

var state_t := 0.0
var anim_t := 0.0
var attack_phase := 0            # 0 windup, 1 active, 2 recover
var combo := 0
var combo_timer := 0.0
var sep_timer := 0.0
var buffered_attack := false
var swing_instance := 0
var hit_set: Dictionary = {}     # instance -> {id: true}
var invuln_t := 0.0
var hurt_t := 0.0
var knock_dir := Vector2.ZERO
var dodge_cd := 0.0
var dodge_dir := Vector2.DOWN
var dodge_invuln := false
var skill_cd := 0.0
var skill_dir := Vector2.DOWN
var potion_cd := 0.0
var dead_t := 0.0
var dead_handled := false
var move_speed := 90.0

var sprite: Sprite2D

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	sprite = $Sprite
	sprite.texture = load("res://assets/chars/player.png")
	sprite.hframes = 18
	sprite.vframes = 4
	sprite.offset = Vector2(0, -16)
	move_speed = float(Config.b("player.base_speed", 90.0))

func reset_to_spawn() -> void:
	state = State.IDLE
	state_t = 0.0
	attack_phase = 0
	combo = 0
	combo_timer = 0.0
	buffered_attack = false
	invuln_t = 0.0
	hurt_t = 0.0
	dodge_cd = 0.0
	skill_cd = 0.0
	potion_cd = 0.0
	dead_t = 0.0
	dead_handled = false
	dodge_invuln = false
	velocity = Vector2.ZERO
	GameState.hp = maxi(GameState.hp, 1)
	GameState.sp = maxi(GameState.sp, 1)
	GameState.hp_changed.emit(GameState.hp, GameState.max_hp())
	GameState.sp_changed.emit(GameState.sp, GameState.max_sp())
	modulate.a = 1.0

# ---------------- input ----------------
func _unhandled_input(event: InputEvent) -> void:
	if not InputRouter.world_ok() or state == State.DEAD:
		return
	if event.is_action_pressed("attack"):
		try_attack()
	elif event.is_action_pressed("dodge"):
		try_dodge()
	elif event.is_action_pressed("skill"):
		try_skill()
	elif event.is_action_pressed("potion"):
		try_potion()
	elif event.is_action_pressed("interact"):
		try_interact()

func try_attack() -> void:
	var sp_cost := int(Config.b("combat.attack_stamina", 6))
	if state == State.ATTACK:
		if attack_phase < 2:
			buffered_attack = true
			return
	if not GameState.can_spend_sp(sp_cost):
		_feedback("体力不足")
		return
	if state == State.DODGE or state == State.HURT or state == State.SKILL:
		return
	GameState.spend_sp(sp_cost)
	if state == State.ATTACK:
		combo = (combo + 1) % 3
	else:
		combo = (combo + 1) % 3 if combo_timer > 0.0 else 0
	state = State.ATTACK
	state_t = 0.0
	attack_phase = 0
	swing_instance += 1
	hit_set[swing_instance] = {}
	AudioMan.play_sfx("swing")

func try_dodge() -> void:
	if dodge_cd > 0.0:
		return
	if state == State.ATTACK and attack_phase < 2:
		return
	if state == State.SKILL or state == State.HURT or state == State.DEAD:
		return
	var sp_cost := int(Config.b("combat.dodge_stamina", 20))
	if not GameState.can_spend_sp(sp_cost):
		_feedback("体力不足")
		return
	GameState.spend_sp(sp_cost)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dodge_dir = input.normalized() if input != Vector2.ZERO else facing
	if dodge_dir == Vector2.ZERO:
		dodge_dir = facing
	_update_facing_from_dir(dodge_dir)
	state = State.DODGE
	state_t = 0.0
	dodge_cd = float(Config.b("dodge.cooldown", 0.25)) + float(Config.b("dodge.duration", 0.28))
	dodge_invuln = false
	AudioMan.play_sfx("dodge")
	Fx.dust(global_position, -dodge_dir)
	Quests.notify_dodge()

func try_skill() -> void:
	if GameState.level < int(Config.b("skill_dash.unlock_level", 2)):
		_feedback("2 级解锁剑技「突进斩」")
		return
	if skill_cd > 0.0:
		_feedback("剑技冷却中（%.1f 秒）" % skill_cd)
		return
	if state != State.IDLE and state != State.MOVE:
		return
	var sp_cost := int(Config.b("skill_dash.stamina", 30))
	if not GameState.can_spend_sp(sp_cost):
		_feedback("体力不足")
		return
	GameState.spend_sp(sp_cost)
	skill_dir = facing
	state = State.SKILL
	state_t = 0.0
	swing_instance += 1
	hit_set[swing_instance] = {}
	skill_cd = float(Config.b("skill_dash.cooldown", 6.0))
	AudioMan.play_sfx("skill")

func try_potion() -> void:
	if potion_cd > 0.0:
		_feedback("药水冷却中")
		return
	if GameState.potion_count() <= 0:
		_feedback("没有药水了")
		return
	if GameState.hp >= GameState.max_hp():
		_feedback("生命值已满")
		return
	for i in Inv.slots.size():
		if Inv.slots[i].id == "potion":
			Inv.use_item(i)
			potion_cd = float(Config.b("potion.cooldown", 2.0))
			return

func try_interact() -> void:
	if state != State.IDLE and state != State.MOVE:
		return
	var best: Node2D = null
	var best_d := 30.0
	for node in get_tree().get_nodes_in_group("interactables"):
		if not (node is Node2D):
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	if best != null and best.has_method("interact"):
		best.interact()

func _feedback(text: String) -> void:
	GameState.toast.emit(text, Color(1.0, 0.75, 0.4))
	AudioMan.play_sfx("no_stamina")

# ---------------- damage ----------------
func take_damage(dmg: int, from_pos: Vector2) -> bool:
	if state == State.DEAD:
		return false
	if dodge_invuln or invuln_t > 0.0:
		return false
	invuln_t = float(Config.b("combat.invuln_after_hit", 0.6))
	GameState.take_damage(dmg)
	knock_dir = (global_position - from_pos)
	if knock_dir.length() < 0.001:
		knock_dir = -facing
	knock_dir = knock_dir.normalized()
	hurt_t = 0.25
	AudioMan.play_sfx("hurt")
	Fx.float_text(global_position + Vector2(0, -26), "-%d" % dmg, Color(1.0, 0.45, 0.4), 15)
	Fx.spark(global_position + Vector2(0, -14))
	if MapMan.current_map != null:
		MapMan.current_map.apply_shake(float(Config.b("camera.shake_amp", 2.0)))
	if GameState.hp <= 0:
		_die()
	else:
		state = State.HURT
		state_t = 0.0
	return true

func _die() -> void:
	state = State.DEAD
	state_t = 0.0
	dead_handled = false
	velocity = Vector2.ZERO
	AudioMan.play_sfx("die")
	GameState.toast.emit("你死了……", Color(1.0, 0.3, 0.3))

# ---------------- melee queries ----------------
func _melee_hits() -> Array:
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = float(Config.b("attack.range", 30.0))
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + facing * 16.0)
	q.collision_mask = 4 | 8
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return space.intersect_shape(q, 32)

func _apply_attack(mult: float, instance_id: int) -> void:
	var arc := float(Config.b("attack.arc_deg", 75.0))
	for r in _melee_hits():
		var node: Object = r.get("collider")
		if node == null or not (node is Node2D):
			continue
		var hits: Dictionary = hit_set.get(instance_id, {})
		if hits.has(node.get_instance_id()):
			continue
		var delta: Vector2 = (node as Node2D).global_position - global_position
		if facing.angle_to(delta) > deg_to_rad(arc * 0.5):
			continue
		hits[node.get_instance_id()] = true
		if node.is_in_group("enemy"):
			var dmg := maxi(1, int(round(GameState.total_atk() * mult - int(node.get("def_value")))))
			if node.has_method("take_damage"):
				node.take_damage(dmg, global_position)
		else:
			var dummy_node := _resolve_dummy(node)
			if dummy_node != null and dummy_node.has_method("on_hit"):
				dummy_node.on_hit(global_position)

func _resolve_dummy(node: Node2D) -> Node2D:
	if node.is_in_group("dummy"):
		return node
	if node.get_parent() != null and node.get_parent().is_in_group("dummy"):
		return node.get_parent() as Node2D
	return null

func _depenetrate_from_enemies() -> void:
	# Nudge the player out if a pass-through dodge (or a charge) left them
	# inside an enemy body. Picks the nearest free spot; never crosses walls.
	var space := get_world_2d().direct_space_state
	var sh := RectangleShape2D.new()
	sh.size = Vector2(10, 6)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = sh
	q.collision_mask = 4
	q.collide_with_areas = false
	q.transform = Transform2D(0, global_position + Vector2(0, -3))
	var res := space.intersect_shape(q, 4)
	if res.is_empty():
		return
	var other: Node2D = null
	for r in res:
		var c = r.get("collider")
		if c is Node2D:
			other = c
			break
	if other == null:
		return
	var push: Vector2 = global_position - other.global_position
	if push.length() < 0.01:
		push = Vector2.DOWN
	push = push.normalized()
	for step in [12.0, 18.0, 24.0, 32.0, 40.0, 52.0]:
		var dest: Vector2 = global_position + push * step
		var q2 := PhysicsShapeQueryParameters2D.new()
		q2.shape = sh
		q2.collision_mask = 1 | 4
		q2.collide_with_areas = false
		q2.transform = Transform2D(0, dest + Vector2(0, -3))
		if space.intersect_shape(q2, 4).is_empty():
			global_position = dest
			return

func _player_damage(mult: float) -> int:
	# damage dealt BY player to a target with its own def applied by the target
	return maxi(1, int(round(GameState.total_atk() * mult)))

func apply_damage_to(enemy: Node2D, mult: float) -> int:
	var dmg := maxi(1, int(round(GameState.total_atk() * mult - int(enemy.get("def_value")))))
	return dmg

# ---------------- main loop ----------------
func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	# timers
	invuln_t = maxf(0.0, invuln_t - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	state_t += delta
	anim_t += delta

	# invuln blink
	if invuln_t > 0.0 and state != State.DEAD:
		modulate.a = 0.35 if int(anim_t * 16.0) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0

	if not InputRouter.world_ok():
		_update_anim()
		return

	match state:
		State.IDLE, State.MOVE:
			_process_move(delta)
		State.ATTACK:
			_process_attack(delta)
		State.SKILL:
			_process_skill(delta)
		State.DODGE:
			_process_dodge(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			_process_dead(delta)
	move_and_slide()
	sep_timer -= delta
	if sep_timer <= 0.0 and state != State.DODGE and state != State.DEAD:
		sep_timer = 0.2
		_depenetrate_from_enemies()

	if state != State.DEAD:
		GameState.pos = global_position
		var cell := Vector2i(int(global_position.x / 16), int(global_position.y / 16))
		GameState.mark_visited(GameState.map_id, cell)

# ---------- per-state ----------
func _process_move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		_update_facing_from_input(input)
		velocity = input * move_speed
		state = State.MOVE
	else:
		velocity = Vector2.ZERO
		state = State.IDLE

func _process_attack(delta: float) -> void:
	var windup := float(Config.b("attack.windup", 0.1))
	var active := float(Config.b("attack.active", 0.1))
	var recover := float(Config.b("attack.recover", 0.22))
	velocity = Vector2.ZERO
	if attack_phase == 0 and state_t >= windup:
		attack_phase = 1
		state_t = 0.0
	elif attack_phase == 1:
		var mult: Array = Config.b("attack.combo_mult", [1.0, 1.15, 1.4])
		_apply_attack(float(mult[combo]), swing_instance)
		if state_t >= active:
			attack_phase = 2
			state_t = 0.0
	elif attack_phase == 2:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input * move_speed * 0.35
		if state_t >= recover:
			state = State.IDLE
			combo_timer = float(Config.b("attack.combo_reset", 0.65))
			state_t = 0.0
			if buffered_attack:
				buffered_attack = false
				try_attack()

func _process_skill(delta: float) -> void:
	var windup := float(Config.b("skill_dash.windup", 0.25))
	var dash_time := 0.18
	var recover := float(Config.b("skill_dash.recover", 0.35))
	velocity = Vector2.ZERO
	if state_t < windup:
		pass
	elif state_t < windup + dash_time:
		velocity = skill_dir * (float(Config.b("skill_dash.distance", 64.0)) / dash_time)
		_apply_skill_hit()
		if int(state_t / 0.06) != int((state_t - delta) / 0.06):
			Fx.spawn_skill_slash(global_position + skill_dir * 8.0, skill_dir.angle())
			Fx.ghost(global_position + Vector2(0, -16), sprite.texture, sprite.frame)
	elif state_t >= windup + dash_time + recover:
		state = State.IDLE
		state_t = 0.0

func _apply_skill_hit() -> void:
	var mult := float(Config.b("skill_dash.mult", 1.8))
	for r in _melee_hits():
		var node: Object = r.get("collider")
		if node == null or not (node is Node2D):
			continue
		var hits: Dictionary = hit_set.get(swing_instance, {})
		if hits.has(node.get_instance_id()):
			continue
		hits[node.get_instance_id()] = true
		if node.is_in_group("enemy") and node.has_method("take_damage"):
			var dmg := maxi(1, int(round(GameState.total_atk() * mult - int(node.get("def_value")))))
			node.take_damage(dmg, global_position)
			Fx.spark(node.global_position + Vector2(0, -14))
		else:
			var dummy_node := _resolve_dummy(node)
			if dummy_node != null and dummy_node.has_method("on_hit"):
				dummy_node.on_hit(global_position)

func _process_dodge(delta: float) -> void:
	var duration := float(Config.b("dodge.duration", 0.28))
	var inv_start := float(Config.b("dodge.invuln_start", 0.06))
	var inv_end := float(Config.b("dodge.invuln_end", 0.22))
	dodge_invuln = state_t >= inv_start and state_t <= inv_end
	velocity = dodge_dir * (float(Config.b("dodge.distance", 48.0)) / duration)
	# pass through enemies
	collision_mask = 1
	if int(state_t / 0.07) != int((state_t - delta) / 0.07):
		Fx.ghost(global_position + Vector2(0, -16), sprite.texture, sprite.frame)
	if state_t >= duration:
		state = State.IDLE
		state_t = 0.0
		collision_mask = 1 | 4
		dodge_invuln = false
		# never end a pass-through dodge inside an enemy body
		_depenetrate_from_enemies()

func _process_hurt(delta: float) -> void:
	velocity = knock_dir * float(Config.b("combat.knockback", 90.0)) * (hurt_t / 0.25)
	if hurt_t <= 0.0:
		state = State.IDLE
		state_t = 0.0

func _process_dead(delta: float) -> void:
	velocity = Vector2.ZERO
	if state_t >= 1.4 and not dead_handled:
		dead_handled = true
		player_died.emit()

# ---------- facing & anim ----------
func _update_facing_from_input(input: Vector2) -> void:
	if absf(input.x) > absf(input.y):
		_set_facing(Vector2.RIGHT if input.x > 0 else Vector2.LEFT)
	else:
		_set_facing(Vector2.DOWN if input.y > 0 else Vector2.UP)

func _update_facing_from_dir(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_set_facing(Vector2.RIGHT if dir.x > 0 else Vector2.LEFT)
	else:
		_set_facing(Vector2.DOWN if dir.y > 0 else Vector2.UP)

func _set_facing(v: Vector2) -> void:
	facing = v
	dir_name = DIR_FROM_VEC.get(v, "down")

func _update_anim() -> void:
	var col := 0
	match state:
		State.IDLE:
			col = int(anim_t * 2.0) % 2
		State.MOVE:
			col = 2 + (int(anim_t * 7.0) % 4)
		State.ATTACK:
			match attack_phase:
				0: col = 6
				1: col = 7
				2: col = 8 if int(anim_t * 6.0) % 2 == 0 else 9
		State.SKILL:
			var windup := float(Config.b("skill_dash.windup", 0.25))
			if state_t < windup:
				col = 6
			elif state_t < windup + 0.18:
				col = 7
			else:
				col = 8
		State.DODGE:
			col = 11 + mini(2, int(state_t / 0.093))
		State.HURT:
			col = 10
		State.DEAD:
			col = 14 + mini(3, int(state_t / 0.35))
	sprite.frame = DIR_ROWS[dir_name] * 18 + col
