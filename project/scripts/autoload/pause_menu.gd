extends CanvasLayer
## PauseMenu: continue / help / settings / title / quit. Tree pauses while open.

var open := false
var page := "main"
var sel := 0
var panel: PanelContainer
var content: VBoxContainer
var _buttons: Array = []

func _ready() -> void:
	layer = 80
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -170
	panel.offset_right = 170
	panel.offset_top = -140
	panel.offset_bottom = 140
	add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

func toggle() -> void:
	if open:
		close()
	else:
		open_ui()

func open_ui() -> void:
	if InputRouter.mode() != InputRouter.Mode.WORLD:
		return
	open = true
	visible = true
	get_tree().paused = true
	InputRouter.push(InputRouter.Mode.MENU)
	_show_main()

func close() -> void:
	if not open:
		return
	open = false
	visible = false
	get_tree().paused = false
	InputRouter.pop()

func _clear() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()

func _add_button(text: String, cb: Callable) -> void:
	var b := UITheme.make_button(text, 14)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	content.add_child(b)
	_buttons.append(b)

func _show_main() -> void:
	page = "main"
	_clear()
	content.add_child(UITheme.make_label("— 暂停 —", 16, Color(1.0, 0.9, 0.6)))
	_add_button("继续游戏", func(): close())
	_add_button("操作说明", _show_help)
	_add_button("设置", _show_settings)
	_add_button("返回标题", _to_title)
	_add_button("退出游戏", func(): get_tree().quit())
	sel = 0
	_update_sel()

func _show_help() -> void:
	page = "help"
	_clear()
	content.add_child(UITheme.make_label("操作说明", 15, Color(1.0, 0.9, 0.6)))
	var help_text := "WASD / 方向键：移动（八方向）\nJ：普通攻击（三段连击）\nK：闪避（中途无敌）\nL：剑技「突进斩」（2 级解锁）\nQ：使用药水\nE：交互 / 对话\nI：背包与装备\nM：地图\nEsc：暂停 / 关闭菜单\n\n城镇是安全区，可自动恢复并手动存档。\n死亡后可读取最近的存档重新挑战。"
	content.add_child(UITheme.make_label(help_text, 12))
	_add_button("返回", _show_main)
	sel = 0
	_update_sel()

func _show_settings() -> void:
	page = "settings"
	_clear()
	content.add_child(UITheme.make_label("设置", 15, Color(1.0, 0.9, 0.6)))
	_buttons.append(_slider("主音量", "master"))
	_buttons.append(_slider("音乐音量", "music"))
	_buttons.append(_slider("音效音量", "sfx"))
	var fs_b := UITheme.make_button("全屏：关")
	fs_b.focus_mode = Control.FOCUS_NONE
	fs_b.pressed.connect(_toggle_fullscreen.bind(fs_b))
	content.add_child(fs_b)
	_buttons.append(fs_b)
	var sh_b := UITheme.make_button("屏幕震动：开")
	sh_b.focus_mode = Control.FOCUS_NONE
	sh_b.pressed.connect(_toggle_shake.bind(sh_b))
	content.add_child(sh_b)
	_buttons.append(sh_b)
	fs_b.text = "全屏：%s" % ("开" if bool(GameState.settings.get("fullscreen", false)) else "关")
	sh_b.text = "屏幕震动：%s" % ("开" if bool(GameState.settings.get("shake", true)) else "关")
	_add_button("返回", _show_main)
	sel = 0
	_update_sel()

func _slider(label_text: String, key: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	content.add_child(hb)
	hb.add_child(UITheme.make_label(label_text, 12))
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.custom_minimum_size = Vector2(140, 20)
	sl.value = float(GameState.settings.get(key, 0.8)) * 100.0
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float) -> void:
		GameState.settings[key] = v / 100.0
		AudioMan.apply_volumes()
		SaveMan.save_settings())
	hb.add_child(sl)
	return hb

func _toggle_fullscreen(btn: Button) -> void:
	var fs := not bool(GameState.settings.get("fullscreen", false))
	GameState.settings["fullscreen"] = fs
	SaveMan.save_settings()
	btn.text = "全屏：%s" % ("开" if fs else "关")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioMan.play_sfx("confirm")

func _toggle_shake(btn: Button) -> void:
	var s := not bool(GameState.settings.get("shake", true))
	GameState.settings["shake"] = s
	SaveMan.save_settings()
	btn.text = "屏幕震动：%s" % ("开" if s else "关")
	AudioMan.play_sfx("confirm")

func _to_title() -> void:
	get_tree().paused = false
	open = false
	visible = false
	InputRouter.set_mode(InputRouter.Mode.TITLE)
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _update_sel() -> void:
	for i in _buttons.size():
		var b: Control = _buttons[i]
		if i == sel and b is Button:
			b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		elif b is Button:
			b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.97))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if page == "main":
			close()
		else:
			_show_main()
		AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_up"):
		sel = maxi(0, sel - 1)
		_update_sel()
		AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_down"):
		sel = mini(_buttons.size() - 1, sel + 1)
		_update_sel()
		AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_accept"):
		var b: Control = _buttons[sel] if sel < _buttons.size() else null
		if b is Button:
			b.pressed.emit()
		elif b is HBoxContainer:
			var sl := b.get_child(1) as HSlider
			if sl != null:
				sl.grab_focus()
