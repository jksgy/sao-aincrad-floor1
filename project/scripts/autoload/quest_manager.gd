extends Node
## QuestManager: quest states, stage progression, notifications from the world.

signal quest_updated
signal quest_completed(id: String)
signal objective_changed(text: String)

enum State { NOT_ACCEPTED, ACTIVE, READY, DONE, REWARDED }
const STATE_NAMES := ["not_accepted", "active", "ready", "done", "rewarded"]

var states: Dictionary = {}   # qid -> {state: int, stage: int, counts: {}}

func _ready() -> void:
	reset()

func reset() -> void:
	states = {}
	for qid in Config.quests.keys():
		states[qid] = { "state": State.NOT_ACCEPTED, "stage": 0, "counts": {} }
	quest_updated.emit()

func state_of(qid: String) -> int:
	return int(states.get(qid, {}).get("state", State.NOT_ACCEPTED))

func stage_of(qid: String) -> int:
	return int(states.get(qid, {}).get("stage", 0))

func state_name(qid: String) -> String:
	return STATE_NAMES[state_of(qid)]

func accept(qid: String) -> void:
	if not Config.quests.has(qid):
		return
	if state_of(qid) != State.NOT_ACCEPTED:
		return
	states[qid] = { "state": State.ACTIVE, "stage": 0, "counts": {} }
	GameState.toast.emit("新任务：「%s」" % Config.quest(qid).title, Color(1.0, 0.85, 0.5))
	AudioMan.play_sfx("pickup")
	quest_updated.emit()

func stage_count(qid: String) -> int:
	return (Config.quest(qid).stages as Array).size()

func _advance(qid: String) -> void:
	var st: Dictionary = states[qid]
	st.stage += 1
	if st.stage >= stage_count(qid):
		st.state = State.READY
		GameState.toast.emit("任务可交付：「%s」" % Config.quest(qid).title, Color(0.6, 1.0, 0.7))
		quest_completed.emit(qid)
	quest_updated.emit()

func _count(qid: String, key: String) -> int:
	return int(states[qid].counts.get(key, 0))

func _increment(qid: String, key: String, amount: int = 1) -> void:
	states[qid].counts[key] = _count(qid, key) + amount
	quest_updated.emit()

# notification from world
func notify_kill(enemy_id: String) -> void:
	for qid in Config.quests.keys():
		if state_of(qid) != State.ACTIVE:
			continue
		var q := Config.quest(qid)
		var stage: Dictionary = q.stages[stage_of(qid)]
		if stage.get("type", "") == "kill" and stage.get("target", "") == enemy_id:
			_increment(qid, "kill", 1)
			var total := int(stage.get("count", 1))
			var done := mini(_count(qid, "kill"), total)
			if done >= total:
				_advance(qid)
			else:
				var enemy_name := str(Config.enemy(enemy_id).get("name", enemy_id))
				GameState.toast.emit("任务进度：%s %d/%d" % [enemy_name, done, total],
						Color(0.8, 0.95, 1.0))

func notify_seal(seal_id: String) -> void:
	for qid in Config.quests.keys():
		if state_of(qid) != State.ACTIVE:
			continue
		var q := Config.quest(qid)
		var stage: Dictionary = q.stages[stage_of(qid)]
		if stage.get("type", "") == "seal" and stage.get("target", "") == seal_id:
			_advance(qid)

func notify_enter_map(map_id: String) -> void:
	for qid in Config.quests.keys():
		if state_of(qid) != State.ACTIVE:
			continue
		var q := Config.quest(qid)
		var stage: Dictionary = q.stages[stage_of(qid)]
		if stage.get("type", "") == "enter_map" and stage.get("target", "") == map_id:
			_advance(qid)

func notify_hit_dummy() -> void:
	for qid in Config.quests.keys():
		if state_of(qid) != State.ACTIVE:
			continue
		var q := Config.quest(qid)
		var stage: Dictionary = q.stages[stage_of(qid)]
		if stage.get("type", "") == "hit_dummy":
			_increment(qid, "hit_dummy", 1)
			if _count(qid, "hit_dummy") >= int(stage.get("count", 1)):
				_advance(qid)

func notify_dodge() -> void:
	for qid in Config.quests.keys():
		if state_of(qid) != State.ACTIVE:
			continue
		var q := Config.quest(qid)
		var stage: Dictionary = q.stages[stage_of(qid)]
		if stage.get("type", "") == "dodge":
			_increment(qid, "dodge", 1)
			if _count(qid, "dodge") >= int(stage.get("count", 1)):
				_advance(qid)

func notify_reach_boss_door() -> void:
	for qid in Config.quests.keys():
		if state_of(qid) != State.ACTIVE:
			continue
		var q := Config.quest(qid)
		var stage: Dictionary = q.stages[stage_of(qid)]
		if stage.get("type", "") == "reach" and stage.get("target", "") == "boss_door":
			_advance(qid)

func notify_stairs() -> void:
	for qid in Config.quests.keys():
		if state_of(qid) != State.ACTIVE:
			continue
		var q := Config.quest(qid)
		var stage: Dictionary = q.stages[stage_of(qid)]
		if stage.get("type", "") == "stairs":
			_advance(qid)

func force_stage_done(qid: String, stage: int) -> void:
	if not Config.quests.has(qid):
		return
	var st: Dictionary = states[qid]
	if st.stage == stage:
		_advance(qid)

func force_ready(qid: String) -> void:
	if not Config.quests.has(qid):
		return
	var st: Dictionary = states[qid]
	if st.state == State.NOT_ACCEPTED:
		st.state = State.ACTIVE
	while st.stage < stage_count(qid):
		_advance(qid)
	quest_updated.emit()

func reward(qid: String) -> bool:
	if state_of(qid) != State.READY:
		return false
	var q := Config.quest(qid)
	var r: Dictionary = q.get("rewards", {})
	GameState.add_xp(int(r.get("xp", 0)))
	if int(r.get("col", 0)) > 0:
		GameState.add_col(int(r.get("col", 0)))
	for item_id in r.get("items", []):
		Inv.add_item(str(item_id), 1)
	states[qid].state = State.REWARDED
	GameState.toast.emit("任务完成：「%s」" % q.title, Color(0.6, 1.0, 0.7))
	AudioMan.play_sfx("unlock")
	quest_updated.emit()
	return true

func current_quest_id() -> String:
	for qid in Config.quests.keys():
		if state_of(qid) == State.ACTIVE:
			return qid
	# 可交付的任务也算“当前任务”，保证 HUD 一直有指引
	for qid in Config.quests.keys():
		if state_of(qid) == State.READY:
			return qid
	return ""

func objective_text() -> String:
	var qid := current_quest_id()
	if qid == "":
		return _next_step_hint()
	var q := Config.quest(qid)
	if state_of(qid) == State.READY:
		var giver_name := str(Config.npc(str(q.get("giver", ""))).get("name", "委托人"))
		return "任务可交付：「%s」\n返回%s处交谈" % [q.title, giver_name]
	var stage: Dictionary = q.stages[stage_of(qid)]
	var desc: String = stage.get("desc", "")
	if stage.get("type", "") == "kill":
		var c := _count(qid, "kill")
		var total := int(stage.get("count", 1))
		desc = "击败%s（%d/%d）" % [_kill_target_name(str(stage.get("target", ""))), mini(c, total), total]
	return "任务「%s」：%s" % [q.title, desc]

func _kill_target_name(target: String) -> String:
	var en := Config.enemy(target)
	if not en.is_empty():
		return str(en.get("name", "敌人"))
	if target != "" and target == str(Config.b("boss.id", "")):
		return str(Config.b("boss.name", "守层 Boss"))
	return "敌人"

func _next_step_hint() -> String:
	if GameState.boss_defeated and GameState.first_floor_done:
		return "第一层已攻略。城镇中的生活仍在继续。"
	if state_of("q1") == State.REWARDED and state_of("q2") == State.NOT_ACCEPTED:
		return "主线指引：去东侧杂货摊，找杂货商人接受委托"
	if state_of("q2") == State.REWARDED and state_of("q3") == State.NOT_ACCEPTED:
		return "主线指引：去镇子东北角，找攻略联络员"
	if state_of("q3") == State.REWARDED and state_of("q4") == State.NOT_ACCEPTED:
		return "主线指引：前往草原东侧遗迹，到 Boss 门前找亚丝娜"
	if GameState.boss_defeated and not GameState.first_floor_done:
		return "主线指引：调查 Boss 房北侧的阶梯"
	return ""

func to_dict() -> Dictionary:
	return { "states": states }

func from_dict(d: Dictionary) -> void:
	reset()
	var s: Dictionary = d.get("states", {})
	for qid in s.keys():
		if states.has(qid):
			var e: Dictionary = s[qid]
			states[qid] = {
				"state": clampi(int(e.get("state", 0)), 0, 4),
				"stage": maxi(0, int(e.get("stage", 0))),
				"counts": e.get("counts", {}),
			}
	quest_updated.emit()
