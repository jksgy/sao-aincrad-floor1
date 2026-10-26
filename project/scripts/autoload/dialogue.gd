extends CanvasLayer
## Dialogue: bottom panel, typewriter, choices, effects, conditional pages.

var pages: Array = []
var idx := 0
var on_end := Callable()
var npc_node: Node2D = null
var typing := false
var chars_shown := 0.0
var sel := 0
var pending_shop := ""
var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _arrow: Label
var _choices_box: VBoxContainer
var _choice_buttons: Array = []

func _ready() -> void:
	layer = 60
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = UITheme.make_panel()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 20
	_panel.offset_right = -20
	_panel.offset_top = -118
	_panel.offset_bottom = -12
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	_name_label = UITheme.make_label("", 14, Color(1.0, 0.85, 0.5))
	vb.add_child(_name_label)
	_text_label = UITheme.make_label("", 14)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 44)
	vb.add_child(_text_label)
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 4)
	vb.add_child(_choices_box)
	_arrow = UITheme.make_label("▼", 12, Color(0.9, 0.9, 0.9))
	_arrow.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_arrow.offset_left = -26
	_arrow.offset_top = -22
	add_child(_arrow)

func is_open() -> bool:
	return visible

func start(id: String, npc: Node2D = null, end_cb := Callable()) -> void:
	var p := Config.dialogue(id)
	if p.is_empty():
		if end_cb.is_valid():
			end_cb.call()
		return
	InputRouter.push(InputRouter.Mode.DIALOGUE)
	pages = p
	idx = 0
	on_end = end_cb
	npc_node = npc
	pending_shop = ""
	visible = true
	_advance_to_valid()
	_show_page()

func start_auto(id: String, npc: Node2D, end_cb := Callable()) -> void:
	start(id, npc, end_cb)

func _advance_to_valid() -> void:
	while idx < pages.size() and not _cond_ok(pages[idx].get("cond", {})):
		idx += 1

func _show_page() -> void:
	_choices_box.visible = false
	for b in _choice_buttons:
		b.queue_free()
	_choice_buttons.clear()
	if idx >= pages.size():
		_close()
		return
	var page: Dictionary = pages[idx]
	_run_effects(page.get("effects", []))
	_name_label.text = str(page.get("speaker", "？？？"))
	_text_label.text = str(page.get("text", ""))
	chars_shown = 0.0
	typing = true
	_arrow.visible = true
	var choices: Array = page.get("choices", [])
	if not choices.is_empty():
		_choices_box.visible = true
		typing = false
		chars_shown = float(_text_label.text.length())
		_arrow.visible = false
		sel = 0
		for i in choices.size():
			var c: Dictionary = choices[i]
			var b := UITheme.make_button(str(c.get("text", "")), 13)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_on_choice_pressed.bind(i))
			_choices_box.add_child(b)
			_choice_buttons.append(b)
		_update_choice_style()

func _update_choice_style() -> void:
	for i in _choice_buttons.size():
		var b: Button = _choice_buttons[i]
		b.add_theme_color_override("font_color",
				Color(1.0, 0.9, 0.6) if i == sel else Color(0.9, 0.92, 0.97))

func _on_choice_pressed(i: int) -> void:
	var page: Dictionary = pages[idx]
	var choices: Array = page.get("choices", [])
	if choices.is_empty():
		# no choices on this page: treat as advance
		idx += 1
		_advance_to_valid()
		_show_page()
		return
	if i < 0 or i >= choices.size():
		return
	AudioMan.play_sfx("confirm")
	var jump: String = str(choices[i].get("jump", ""))
	if jump != "":
		var target := Config.dialogue(jump)
		if not target.is_empty():
			pages = target
			idx = 0
			_advance_to_valid()
			_show_page()
			return
	idx += 1
	_advance_to_valid()
	_show_page()

func _close() -> void:
	visible = false
	InputRouter.pop()
	var cb := on_end
	on_end = Callable()
	var shop := pending_shop
	pending_shop = ""
	if cb.is_valid():
		cb.call()
	if shop != "":
		ShopUI.open_shop(shop)

func _process(delta: float) -> void:
	if not visible:
		return
	if typing:
		chars_shown += delta * 40.0
		if chars_shown >= _text_label.text.length():
			chars_shown = float(_text_label.text.length())
			typing = false
		_text_label.visible_characters = int(chars_shown)
	_arrow.visible = (not typing) and _choices_box.get_child_count() == 0 and \
			(not _choices_box.visible)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not InputRouter.dialogue_ok():
		return
	var has_choices: bool = _choices_box.visible
	if event.is_action_pressed("ui_accept"):
		if has_choices:
			_on_choice_pressed(sel)
		elif typing:
			chars_shown = float(_text_label.text.length())
			typing = false
			_text_label.visible_characters = -1
			AudioMan.play_sfx("confirm")
		else:
			AudioMan.play_sfx("confirm")
			idx += 1
			_advance_to_valid()
			_show_page()
	elif event.is_action_pressed("ui_cancel") and not has_choices:
		_close()
	elif has_choices and event.is_action_pressed("ui_up"):
		sel = maxi(0, sel - 1)
		AudioMan.play_sfx("cancel")
		_update_choice_style()
	elif has_choices and event.is_action_pressed("ui_down"):
		sel = mini(_choice_buttons.size() - 1, sel + 1)
		AudioMan.play_sfx("cancel")
		_update_choice_style()

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

func _run_effects(effects: Array) -> void:
	for e in effects:
		var d: Dictionary = e
		match str(d.get("type", "")):
			"quest_stage":
				Quests.force_stage_done(str(d.get("quest", "")), int(d.get("stage", 0)))
			"quest_accept":
				Quests.accept(str(d.get("quest", "")))
			"quest_reward":
				Quests.reward(str(d.get("quest", "")))
			"quest_force_ready":
				Quests.force_ready(str(d.get("quest", "")))
			"flag":
				GameState.set_flag(str(d.get("name", "")), d.get("value", true))
			"save":
				SaveMan.save_game()
			"heal":
				GameState.heal_full()
			"open_shop":
				pending_shop = str(d.get("shop", ""))
