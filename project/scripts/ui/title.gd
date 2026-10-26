extends Control
## Title screen: continue / new game (name input) / settings / quit + intro cutscene.

var bg: TextureRect
var menu: VBoxContainer
var name_dialog: PanelContainer
var name_edit: LineEdit
var intro_layer: CanvasLayer
var intro_label: Label
var intro_idx := 0
var intro_t := 0.0
var intro_running := false
var skip_pressed := false

const INTRO_PAGES := [
	"2026 年 11 月 6 日。\n《Sword Art Online》正式运营。",
	"然而——\n这是一场无法登出的死亡游戏。",
	"唯一的出路，\n是通关第 100 层。",
	"第一层　起始之镇。\n你的故事，从这里开始。",
]

func _ready() -> void:
	InputRouter.set_mode(InputRouter.Mode.TITLE)
	HUD.hide_all()
	AudioMan.play_music("title", 1.0)
	bg = TextureRect.new()
	bg.texture = load("res://assets/ui/title_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0.02, 0.25)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -140
	vb.offset_right = 140
	vb.offset_top = -90
	vb.offset_bottom = 150
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := UITheme.make_label("刀剑神域　艾恩葛朗特　第一层", 22, Color(0.95, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := UITheme.make_label("— 同人像素 RPG 原型 —", 12, Color(0.7, 0.78, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vb.add_child(spacer)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	vb.add_child(menu)
	_show_menu()

func _show_menu() -> void:
	for c in menu.get_children():
		c.queue_free()
	var continue_b := UITheme.make_button("继续游戏", 15)
	continue_b.disabled = not SaveMan.has_save()
	continue_b.focus_mode = Control.FOCUS_NONE
	continue_b.pressed.connect(_continue_game)
	menu.add_child(continue_b)
	var new_b := UITheme.make_button("新游戏", 15)
	new_b.focus_mode = Control.FOCUS_NONE
	new_b.pressed.connect(_show_name_dialog)
	menu.add_child(new_b)
	var settings_b := UITheme.make_button("设置", 15)
	settings_b.focus_mode = Control.FOCUS_NONE
	settings_b.pressed.connect(_show_settings)
	menu.add_child(settings_b)
	var quit_b := UITheme.make_button("退出游戏", 15)
	quit_b.focus_mode = Control.FOCUS_NONE
	quit_b.pressed.connect(func(): get_tree().quit())
	menu.add_child(quit_b)
	var note := UITheme.make_label("同人学习用途原型　角色与世界观版权归原作者所有", 10, Color(0.5, 0.55, 0.65))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(note)

func _continue_game() -> void:
	var res := SaveMan.load_game()
	if not res.ok:
		GameState.toast.emit("读取失败：" + res.error, Color(1.0, 0.5, 0.5))
		return
	_start_game(false)

func _show_name_dialog() -> void:
	if name_dialog != null:
		return
	name_dialog = UITheme.make_panel()
	name_dialog.set_anchors_preset(Control.PRESET_CENTER)
	name_dialog.offset_left = -150
	name_dialog.offset_right = 150
	name_dialog.offset_top = -80
	name_dialog.offset_bottom = 80
	add_child(name_dialog)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	name_dialog.add_child(vb)
	vb.add_child(UITheme.make_label("输入你的名字（留空为「旅人」）", 13))
	name_edit = LineEdit.new()
	name_edit.max_length = 10
	name_edit.placeholder_text = "旅人"
	name_edit.theme = UITheme.theme
	vb.add_child(name_edit)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	var ok_b := UITheme.make_button("开始", 13)
	ok_b.focus_mode = Control.FOCUS_NONE
	ok_b.pressed.connect(_new_game)
	hb.add_child(ok_b)
	var cancel_b := UITheme.make_button("取消", 13)
	cancel_b.focus_mode = Control.FOCUS_NONE
	cancel_b.pressed.connect(func(): name_dialog.queue_free(); name_dialog = null)
	hb.add_child(cancel_b)
	name_edit.grab_focus()

func _new_game() -> void:
	var name := name_edit.text.strip_edges() if name_edit != null else ""
	if name_dialog != null:
		name_dialog.queue_free()
		name_dialog = null
	GameState.reset(name)
	Quests.reset()
	Quests.accept("q1")
	Inv.start_items()
	SaveMan.save_game()
	_play_intro()

func _play_intro() -> void:
	intro_layer = CanvasLayer.new()
	intro_layer.layer = 95
	add_child(intro_layer)
	var black := ColorRect.new()
	black.color = Color(0.01, 0.01, 0.03, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_layer.add_child(black)
	intro_label = UITheme.make_label("", 16, Color(0.95, 0.95, 1.0))
	intro_label.set_anchors_preset(Control.PRESET_CENTER)
	intro_label.offset_left = -280
	intro_label.offset_right = 280
	intro_label.offset_top = -60
	intro_label.offset_bottom = 60
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_layer.add_child(intro_label)
	var hint := UITheme.make_label("Esc 跳过开场", 11, Color(0.6, 0.6, 0.7))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -30
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_layer.add_child(hint)
	intro_idx = 0
	intro_t = 0.0
	skip_pressed = false
	intro_running = true
	_show_intro_page()

func _show_intro_page() -> void:
	if intro_idx >= INTRO_PAGES.size():
		_finish_intro()
		return
	intro_label.text = INTRO_PAGES[intro_idx]
	intro_label.modulate.a = 0.0
	var tw := intro_label.create_tween()
	tw.tween_property(intro_label, "modulate:a", 1.0, 0.5)

func _finish_intro() -> void:
	intro_running = false
	if intro_layer != null:
		intro_layer.queue_free()
		intro_layer = null
	_start_game(true)

func _process(delta: float) -> void:
	if intro_running:
		intro_t += delta
		if intro_t > 4.2:
			intro_t = 0.0
			intro_idx += 1
			_show_intro_page()

func _unhandled_input(event: InputEvent) -> void:
	if intro_running:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			skip_pressed = true
			_finish_intro()
			return
		if event.is_action_pressed("ui_accept") and intro_t > 0.6:
			intro_t = 0.0
			intro_idx += 1
			_show_intro_page()
			return

func _start_game(fresh: bool) -> void:
	# fresh == true means state already initialized (new game)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _show_settings() -> void:
	PauseMenu.open_ui()
