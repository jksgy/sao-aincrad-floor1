extends CanvasLayer
## ShopUI: buy/sell tabs. Merchant sells potions, blacksmith sells weapons/armor.

var is_open := false
var shop_id := ""
var tab := 0                    # 0 buy, 1 sell
var sel := 0
var panel: PanelContainer
var title_label: Label
var col_label: Label
var list_box: VBoxContainer
var desc_label: Label
var hint_label: Label
var _rows: Array = []
var _buy_items: Array = []
var _sell_slots: Array = []

func _ready() -> void:
	layer = 70
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -130
	panel.offset_bottom = 130
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	title_label = UITheme.make_label("商店", 15, Color(1.0, 0.9, 0.6))
	vb.add_child(title_label)
	col_label = UITheme.make_label("珂尔：0", 13, Color(1.0, 0.85, 0.4))
	vb.add_child(col_label)
	var tabs := HBoxContainer.new()
	vb.add_child(tabs)
	var buy_b := UITheme.make_button("购买", 13)
	buy_b.focus_mode = Control.FOCUS_NONE
	buy_b.pressed.connect(func(): _set_tab(0))
	tabs.add_child(buy_b)
	var sell_b := UITheme.make_button("出售", 13)
	sell_b.focus_mode = Control.FOCUS_NONE
	sell_b.pressed.connect(func(): _set_tab(1))
	tabs.add_child(sell_b)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 2)
	list_box.custom_minimum_size = Vector2(0, 170)
	vb.add_child(list_box)
	desc_label = UITheme.make_label("", 12, Color(0.85, 0.88, 0.95))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc_label)
	hint_label = UITheme.make_label("↑↓ 选择　Z/Enter 确认　Esc 关闭", 11, Color(0.6, 0.65, 0.75))
	vb.add_child(hint_label)

func open_shop(shop: String) -> void:
	shop_id = shop
	is_open = true
	visible = true
	InputRouter.push(InputRouter.Mode.MENU)
	var npc := Config.npc(shop)
	title_label.text = "%s" % npc.get("name", "商店")
	_buy_items = []
	for item_id in npc.get("sells", []):
		if Config.item(str(item_id)).is_empty():
			continue
		_buy_items.append(str(item_id))
	_set_tab(0)

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	InputRouter.pop()

func _set_tab(t: int) -> void:
	tab = t
	sel = 0
	_rebuild()
	AudioMan.play_sfx("cancel")

func _rebuild() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_sell_slots.clear()
	col_label.text = "珂尔：%d" % GameState.col
	if tab == 0:
		for item_id in _buy_items:
			var def := Config.item(item_id)
			_rows.append(_row("● %s   %d 珂尔（攻击+%d/防御+%d/恢复%d）" % [
				def.get("name", "?"), int(def.get("price", 0)),
				int(def.get("atk", 0)), int(def.get("def", 0)), int(def.get("heal", 0))], item_id, def))
	else:
		for i in Inv.slots.size():
			var s: Dictionary = Inv.slots[i]
			if s.id == "":
				continue
			var def := Config.item(s.id)
			if not bool(def.get("sellable", false)):
				continue
			var is_equipped := false
			for eq in Inv.equipped.values():
				if eq == s.id:
					is_equipped = true
			if is_equipped:
				continue
			var price := maxi(1, int(def.get("price", 0)) / 2)
			_sell_slots.append({ "slot": i, "id": s.id, "count": s.count, "price": price })
			_rows.append(_row("● %s ×%d   可卖 %d 珂尔" % [def.get("name", "?"), s.count, price],
					s.id, def))
	if _rows.is_empty():
		desc_label.text = "（这里空空如也）"
		sel = -1
	else:
		_update_sel()

func _row(text: String, item_id: String, def: Dictionary) -> Label:
	var l := UITheme.make_label(text, 12)
	l.custom_minimum_size = Vector2(0, 18)
	list_box.add_child(l)
	return l

func _update_sel() -> void:
	for i in _rows.size():
		var l: Label = _rows[i]
		if i == sel:
			l.text = "▶" + l.text.substr(1) if l.text.begins_with("●") else "▶ " + l.text
			l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		else:
			if l.text.begins_with("▶"):
				l.text = "●" + l.text.substr(1)
			l.add_theme_color_override("font_color", Color(0.9, 0.92, 0.97))
	_update_desc()

func _update_desc() -> void:
	if sel < 0:
		desc_label.text = ""
		return
	if tab == 0 and sel < _buy_items.size():
		var def := Config.item(_buy_items[sel])
		var owned := Inv.count(_buy_items[sel])
		desc_label.text = "%s\n持有 %d" % [def.get("desc", ""), owned]
	elif tab == 1 and sel < _sell_slots.size():
		var e: Dictionary = _sell_slots[sel]
		desc_label.text = str(Config.item(e.id).get("desc", ""))

func _is_equipped(item_id: String) -> bool:
	for eq in Inv.equipped.values():
		if eq == item_id:
			return true
	return false

func _do_confirm() -> void:
	if sel < 0:
		return
	if tab == 0:
		var item_id: String = _buy_items[sel]
		var def := Config.item(item_id)
		var price := int(def.get("price", 0))
		if GameState.col < price:
			GameState.toast.emit("珂尔不足", Color(1.0, 0.6, 0.5))
			AudioMan.play_sfx("no_stamina")
			return
		if not Inv.can_add(item_id, 1):
			GameState.toast.emit("背包已满", Color(1.0, 0.6, 0.5))
			AudioMan.play_sfx("no_stamina")
			return
		if GameState.spend_col(price) and Inv.add_item(item_id, 1):
			GameState.toast.emit("购买了 %s" % def.get("name", ""), Color(0.7, 1.0, 0.7))
			AudioMan.play_sfx("pickup")
			_rebuild()
	else:
		var e: Dictionary = _sell_slots[sel]
		if Inv.remove_item(str(e.id), 1):
			GameState.add_col(int(e.price))
			GameState.toast.emit("出售了 %s（+%d 珂尔）" % [Config.item(e.id).get("name", ""), e.price],
					Color(0.7, 1.0, 0.7))
			AudioMan.play_sfx("pickup")
			_rebuild()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_up"):
		if _rows.size() > 0:
			sel = (sel - 1) % _rows.size() if sel >= 0 else _rows.size() - 1
			_update_sel()
			AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_down"):
		if _rows.size() > 0:
			sel = (sel + 1) % _rows.size() if sel >= 0 else 0
			_update_sel()
			AudioMan.play_sfx("cancel")
	elif event.is_action_pressed("ui_accept"):
		_do_confirm()
