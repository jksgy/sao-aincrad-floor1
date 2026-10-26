extends CanvasLayer
## MapUI: current area map with visited fog, POI markers, quest targets.

var open := false
var title_label: Label
var legend_label: Label
var map_draw: Control
var cell_size := 6.0
var origin := Vector2.ZERO

func _ready() -> void:
	layer = 70
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -170
	panel.offset_bottom = 170
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	title_label = UITheme.make_label("地图", 14, Color(1.0, 0.9, 0.6))
	vb.add_child(title_label)
	map_draw = Control.new()
	map_draw.custom_minimum_size = Vector2(580, 280)
	vb.add_child(map_draw)
	map_draw.draw.connect(_draw_map)
	legend_label = UITheme.make_label("◆ 玩家　▲ 出口　● 恢复点　■ 封印　✚ Boss 门　未探索区域隐藏", 11, Color(0.7, 0.75, 0.85))
	vb.add_child(legend_label)

func toggle() -> void:
	if open:
		close()
	else:
		open_ui()

func open_ui() -> void:
	if MapMan.current_map == null:
		return
	open = true
	visible = true
	InputRouter.push(InputRouter.Mode.MENU)
	var md: MapBuilder.MapData = MapMan.current_map.get_meta("data")
	title_label.text = "地图 — %s" % ({"town": "起始之镇", "field": "草原", "maze_a": "迷宫 A 区",
			"maze_b": "迷宫 B 区", "maze_c": "迷宫 C 区", "boss": "守层 Boss 之间"}).get(md.id, md.id)
	cell_size = minf(6.0, minf(560.0 / md.size.x, 260.0 / md.size.y))
	origin = Vector2((580.0 - md.size.x * cell_size) * 0.5, (280.0 - md.size.y * cell_size) * 0.5)
	map_draw.queue_redraw()

func close() -> void:
	if not open:
		return
	open = false
	visible = false
	InputRouter.pop()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
		close()
		AudioMan.play_sfx("cancel")

func _draw_map() -> void:
	if MapMan.current_map == null:
		return
	var md: MapBuilder.MapData = MapMan.current_map.get_meta("data")
	var color_by_char := {
		".": Color(0.32, 0.5, 0.24), ",": Color(0.3, 0.48, 0.23), ":": Color(0.28, 0.46, 0.22),
		"n": Color(0.36, 0.54, 0.26), "p": Color(0.68, 0.58, 0.42), "d": Color(0.62, 0.52, 0.38),
		"f": Color(0.4, 0.55, 0.26), "w": Color(0.2, 0.4, 0.62), "W": Color(0.75, 0.68, 0.5),
		"q": Color(0.75, 0.68, 0.5), "Q": Color(0.75, 0.68, 0.5), "e": Color(0.75, 0.68, 0.5),
		"o": Color(0.72, 0.72, 0.76), "O": Color(0.66, 0.66, 0.72), "c": Color(0.6, 0.56, 0.52),
		"m": Color(0.36, 0.4, 0.5), "M": Color(0.33, 0.37, 0.46), "a": Color(0.28, 0.3, 0.38),
		"A": Color(0.34, 0.36, 0.44), "t": Color(0.3, 0.46, 0.22), "T": Color(0.3, 0.46, 0.22),
		"D": Color(0.6, 0.56, 0.52), "=": Color(0.5, 0.52, 0.62), "z": Color(0.4, 0.46, 0.58),
	}
	for y in md.size.y:
		for x in md.size.x:
			var ch: String = md.grid[y][x]
			if ch == " " or ch == "":
				continue
			if not GameState.is_visited(md.id, Vector2i(x, y)):
				continue
			var col: Color = color_by_char.get(ch, Color(0.5, 0.5, 0.55))
			if MapBuilder.is_solid(ch):
				col = col.darkened(0.25)
			map_draw.draw_rect(Rect2(origin + Vector2(x, y) * cell_size, Vector2(cell_size, cell_size) * 1.01), col)
	# POIs
	var p := MapMan.player
	if p != null:
		var pc := Vector2i(int(p.global_position.x / 16), int(p.global_position.y / 16))
		_map_marker(pc, Color(1, 1, 1), "◆")
	for ex in md.exits:
		var c := Vector2i(int((ex.rect.position.x + ex.rect.size.x / 2) / 16), int((ex.rect.position.y + ex.rect.size.y / 2) / 16))
		_map_marker(c, Color(1.0, 0.85, 0.4), "▲")
	for s in md.seals:
		var col := Color(0.5, 1.0, 0.6) if GameState.has_seal(s.id) else Color(0.75, 0.5, 1.0)
		_map_marker(s.cell, col, "■")
	for g in md.gates:
		for cell in g.cells:
			_map_marker(cell, Color(1.0, 0.45, 0.35), "✚")
	# save crystals + stairs + boss from grid
	for y in md.size.y:
		for x in md.size.x:
			var ch: String = md.grid[y][x]
			if ch == "R":
				_map_marker(Vector2i(x, y), Color(0.5, 0.9, 1.0), "●")
			elif ch == "Z":
				_map_marker(Vector2i(x, y), Color(1.0, 0.95, 0.8), "▲")

func _map_marker(cell: Vector2i, col: Color, glyph: String) -> void:
	map_draw.draw_string(UITheme.theme.default_font,
			origin + Vector2(cell.x, cell.y) * cell_size + Vector2(0, cell_size * 0.9),
			glyph, HORIZONTAL_ALIGNMENT_LEFT, cell_size * 1.6, 8, col)
