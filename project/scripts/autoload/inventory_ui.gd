extends CanvasLayer
## InventoryUI: 5x4 grid + equipment + stats + description. I opens/closes.

var open := false
var sel := 0                    # 0..19 grid, 20..22 equipment rows
var panel: PanelContainer
var stats_label: Label
var eq_labels: Array = []
var desc_label: Label
var action_label: Label
var _slots: Array = []
var icons_tex: Texture2D

func _ready() -> void:
	layer = 70
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	icons_tex = load("res://assets/ui/icons.png")
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -150
	panel.offset_bottom = 150
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	panel.add_child(hb)
	# left: grid
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	hb.add_child(grid)
	for i in 20:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(52, 52)
		slot.add_theme_stylebox_override("panel", UITheme.theme.get_stylebox("panel", "InventorySlot"))
		grid.add_child(slot)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(v)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)
		var cnt := UITheme.make_label("", 10)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cnt)
		_slots.append({ "box": slot, "icon": icon, "count": cnt })
	# right: stats + equipment
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size = Vector2(250, 0)
	hb.add_child(right)
	right.add_child(UITheme.make_label("角色状态", 13, Color(1.0, 0.9, 0.6)))
	stats_label = UITheme.make_label("", 12)
	right.add_child(stats_label)
	right.add_child(UITheme.make_label("装备栏", 13, Color(1.0, 0.9, 0.6)))
	for slot_name in ["weapon", "armor", "accessory"]:
		var l := UITheme.make_label("", 12)
		l.custom_minimum_size = Vector2(0, 20)
		right.add_child(l)
		eq_labels.append({ "slot": slot_name, "label": l })
	desc_label = UITheme.make_label("", 12, Color(0.85, 0.88, 0.95))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(0, 34)
	right.add_child(desc_label)
	action_label = UITheme.make_label("Z/Enter 使用/装备　X 卸下　I/Esc 关闭", 11, Color(0.6, 0.65, 0.75))
	right.add_child(action_label)

func toggle() -> void:
	if open:
		close()
	else:
		open_ui()

func open_ui() -> void:
	open = true
	visible = true
	InputRouter.push(InputRouter.Mode.MENU)
	_refresh()

func close() -> void:
	if not open:
		return
	open = false
	visible = false
	InputRouter.pop()

func _refresh() -> void:
	for i in 20:
		var s: Dictionary = Inv.slots[i]
		var ui: Dictionary = _slots[i]
		if s.id == "":
			ui.box.visible = false
			continue
		ui.box.visible = true
		var def := Config.item(s.id)
		var icon_idx := int(def.get("icon_index", -1))
		if icon_idx < 0:
			icon_idx = _icon_index(str(def.get("icon", "")))
		var at := AtlasTexture.new()
		at.atlas = icons_tex
		at.region = Rect2(icon_idx * 16, 0, 16, 16)
		ui.icon.texture = at
		ui.count.text = "×%d" % s.count if int(def.get("stack", 1)) > 1 else ""
	var stats := GameState.total_atk()
	var stats2 := GameState.total_def()
	stats_label.text = "等级 %d   经验 %d/%s\n攻击 %d   防御 %d\n最大生命 %d   珂尔 %d" % [
		GameState.level, GameState.xp,
		"MAX" if GameState.xp_for_next() <= 0 else str(GameState.xp_for_next()),
		stats, stats2, GameState.max_hp(), GameState.col]
	_update_eq()
	_update_sel()

func _icon_index(icon: String) -> int:
	var mapping := { "potion": 0, "sword_starter": 1, "sword_bronze": 2, "sword_iron": 3,
		"armor_cloth": 4, "armor_leather": 5, "charm": 6, "col": 7, "meat": 8, "skill": 9 }
	return int(mapping.get(icon, 0))

func _update_eq() -> void:
	var names := { "weapon": "武器", "armor": "护甲", "accessory": "饰品" }
	for i in eq_labels.size():
		var e: Dictionary = eq_labels[i]
		var id: String = Inv.equipped[e.slot]
		var text: String = "%s：%s" % [names[e.slot], Config.item(id).get("name", "无")]
		if i == sel - 20:
			text = "▶ " + text
		e.label.text = text
		e.label.add_theme_color_override("font_color",
				Color(1.0, 0.9, 0.5) if i == sel - 20 else Color(0.9, 0.92, 0.97))

func _update_sel() -> void:
	for i in 20:
		var ui: Dictionary = _slots[i]
		var sb: StyleBoxFlat
		if i == sel:
			sb = UITheme.theme.get_stylebox("selected", "InventorySlot") as StyleBoxFlat
		else:
			sb = UITheme.theme.get_stylebox("panel", "InventorySlot") as StyleBoxFlat
		ui.box.add_theme_stylebox_override("panel", sb)
	_update_eq()
	_update_desc()

func _update_desc() -> void:
	if sel < 20:
		var s: Dictionary = Inv.slots[sel]
		if s.id == "":
			desc_label.text = ""
		else:
			var def := Config.item(s.id)
			var mods: Array = []
			if int(def.get("atk", 0)) > 0:
				mods.append("攻击 +%d" % int(def.atk))
			if int(def.get("def", 0)) > 0:
				mods.append("防御 +%d" % int(def.def))
			if int(def.get("maxhp", 0)) > 0:
				mods.append("最大生命 +%d" % int(def.maxhp))
			if int(def.get("heal", 0)) > 0:
				mods.append("恢复 %d 生命" % int(def.heal))
			var extra := ""
			if mods.size() > 0:
				extra = "　" + "　".join(mods)
			desc_label.text = "%s%s" % [def.get("desc", ""), extra]
	else:
		var e: Dictionary = eq_labels[sel - 20]
		var id: String = Inv.equipped[e.slot]
		if id == "":
			desc_label.text = ""
		else:
			desc_label.text = str(Config.item(id).get("desc", ""))

func _primary_action() -> void:
	if sel < 20:
		var s: Dictionary = Inv.slots[sel]
		if s.id == "":
			return
		var def := Config.item(s.id)
		var t := str(def.get("type", ""))
		if bool(def.get("usable", false)):
			var res := Inv.use_item(sel)
			if res == "hp_full":
				GameState.toast.emit("生命值已满", Color(1.0, 0.75, 0.4))
			elif res == "ok":
				AudioMan.play_sfx("potion")
			_refresh()
		elif t == "weapon" or t == "armor" or t == "accessory":
			if Inv.equip_item(sel):
				GameState.toast.emit("已装备 %s" % def.get("name", ""), Color(0.7, 1.0, 0.7))
				AudioMan.play_sfx("confirm")
				GameState.stats_changed.emit()
				_refresh()
	else:
		var e: Dictionary = eq_labels[sel - 20]
		if Inv.equipped[e.slot] == "":
			return
		if Inv.unequip_slot(str(e.slot)):
			GameState.toast.emit("已卸下装备", Color(0.8, 0.85, 1.0))
			AudioMan.play_sfx("confirm")
			GameState.stats_changed.emit()
			_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		close()
		AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_accept"):
		_primary_action()
	elif event.is_action_pressed("ui_left"):
		if sel < 20:
			sel = sel - 1 if sel % 5 != 0 else sel + 4
		_update_sel()
		AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_right"):
		if sel < 20:
			sel = sel + 1 if sel % 5 != 4 else sel - 4
		_update_sel()
		AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_up"):
		if sel < 20:
			sel = (sel - 5 + 20) % 20
		elif sel < 23:
			sel = sel - 1 if sel > 20 else 19
		_update_sel()
		AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_down"):
		if sel < 20:
			if sel >= 15:
				sel = 20 + (sel - 15)
			else:
				sel = (sel + 5) % 20
		elif sel < 23:
			sel = mini(22, sel + 1)
		_update_sel()
		AudioMan.play_sfx("cancel")
