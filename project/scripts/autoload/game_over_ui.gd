extends CanvasLayer
## GameOverUI: death screen (load save / title) and first-floor victory settlement.

var mode := ""
var panel: PanelContainer
var stats_label: Label

func _ready() -> void:
	layer = 90
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -120
	panel.offset_bottom = 120
	add_child(panel)

func _clear() -> void:
	for c in panel.get_children():
		c.queue_free()

func _button(text: String, cb: Callable, parent: Control) -> Button:
	var b := UITheme.make_button(text, 14)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func show_death() -> void:
	mode = "death"
	_clear()
	visible = true
	InputRouter.push(InputRouter.Mode.DEAD)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var l := UITheme.make_label("你死了……", 20, Color(1.0, 0.35, 0.3))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	var l2 := UITheme.make_label("在这个世界里，HP 归零意味着结束。\n读取存档，重新来过吧。", 12)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l2)
	var load_b := _button("读取最近存档", _load_save, vb)
	load_b.disabled = not SaveMan.has_save()
	_button("返回标题", _to_title, vb)

func show_victory() -> void:
	mode = "victory"
	_clear()
	visible = true
	InputRouter.push(InputRouter.Mode.VICTORY)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var l := UITheme.make_label("第一层 攻略完成！", 20, Color(1.0, 0.9, 0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	var t := int(GameState.play_time)
	var time_str := "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
	stats_label = UITheme.make_label("", 13)
	stats_label.text = "游戏时长　%s\n等级　%d\n击败敌人数　%d" % [time_str, GameState.level, GameState.total_kills]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(stats_label)
	var l3 := UITheme.make_label("向上的阶梯仍被迷雾笼罩——\n第一层原型的内容到此为止。", 12, Color(0.7, 0.75, 0.85))
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l3)
	_button("返回城镇继续探索", _to_town, vb)
	_button("返回标题", _to_title, vb)

func _load_save() -> void:
	var res := SaveMan.load_game()
	if not res.ok:
		GameState.toast.emit("读取失败：" + res.error, Color(1.0, 0.5, 0.5))
		return
	_restore_world()

func _restore_world() -> void:
	visible = false
	InputRouter.set_mode(InputRouter.Mode.WORLD)
	MapMan.load_game_into_world()
	HUD.show_all()
	AudioMan.play_sfx("confirm")

func _to_town() -> void:
	visible = false
	InputRouter.set_mode(InputRouter.Mode.WORLD)
	GameState.map_id = "town"
	GameState.spawn_id = "from_field"
	GameState.pos = Vector2.ZERO
	MapMan.change_map("town", "from_field")
	HUD.show_all()
	AudioMan.play_sfx("confirm")

func _to_title() -> void:
	visible = false
	get_tree().paused = false
	InputRouter.set_mode(InputRouter.Mode.TITLE)
	get_tree().change_scene_to_file("res://scenes/title.tscn")
