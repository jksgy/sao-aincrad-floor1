extends Node
## UITheme: builds the global pixel UI theme (Chinese font, panels, buttons).

var theme: Theme

func _ready() -> void:
	theme = build_theme()

func build_theme() -> Theme:
	var t := Theme.new()
	var font: FontFile = load("res://assets/fonts/NotoSansSC.ttf")
	if font == null:
		push_error("font load failed")
	else:
		t.default_font = font
	t.default_font_size = 16
	t.set_color("font_color", "Label", Color(0.92, 0.93, 0.96))
	t.set_color("font_outline_color", "Label", Color(0.05, 0.06, 0.1))
	t.set_constant("outline_size", "Label", 2)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.08, 0.13, 0.92)
	panel.border_color = Color(0.45, 0.5, 0.62)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(4)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.13, 0.15, 0.23)
	btn.border_color = Color(0.4, 0.45, 0.58)
	btn.set_border_width_all(2)
	btn.set_corner_radius_all(3)
	btn.content_margin_left = 12
	btn.content_margin_right = 12
	btn.content_margin_top = 5
	btn.content_margin_bottom = 5
	t.set_stylebox("normal", "Button", btn)
	var btn_h := btn.duplicate() as StyleBoxFlat
	btn_h.bg_color = Color(0.22, 0.25, 0.38)
	btn_h.border_color = Color(1.0, 0.85, 0.5)
	t.set_stylebox("hover", "Button", btn_h)
	t.set_stylebox("focus", "Button", btn_h)
	var btn_p := btn.duplicate() as StyleBoxFlat
	btn_p.bg_color = Color(0.3, 0.33, 0.5)
	t.set_stylebox("pressed", "Button", btn_p)
	var btn_d := btn.duplicate() as StyleBoxFlat
	btn_d.bg_color = Color(0.1, 0.1, 0.14)
	btn_d.border_color = Color(0.2, 0.22, 0.3)
	t.set_stylebox("disabled", "Button", btn_d)
	t.set_color("font_color", "Button", Color(0.9, 0.92, 0.97))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.6))
	t.set_color("font_pressed_color", "Button", Color(1.0, 1.0, 1.0))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.42, 0.5))

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.06, 0.1, 0.85)
	bar_bg.border_color = Color(0.35, 0.4, 0.5)
	bar_bg.set_border_width_all(1)
	t.set_stylebox("panel", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.35, 0.75, 0.4)
	bar_fill.set_corner_radius_all(1)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	var slot := StyleBoxFlat.new()
	slot.bg_color = Color(0.1, 0.11, 0.17, 0.9)
	slot.border_color = Color(0.35, 0.4, 0.52)
	slot.set_border_width_all(1)
	t.set_stylebox("panel", "InventorySlot", slot)
	var slot_sel := slot.duplicate() as StyleBoxFlat
	slot_sel.border_color = Color(1.0, 0.85, 0.5)
	slot_sel.set_border_width_all(2)
	t.set_stylebox("selected", "InventorySlot", slot_sel)

	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0.02, 0.02, 0.05, 0.6)
	t.set_stylebox("panel", "DimScreen", dim)

	var hbar := StyleBoxFlat.new()
	hbar.bg_color = Color(0.06, 0.07, 0.11, 0.8)
	t.set_stylebox("panel", "HUDBox", hbar)
	return t

func make_label(text: String, size := 14, color := Color(0.92, 0.93, 0.96)) -> Label:
	var l := Label.new()
	l.text = text
	l.theme = theme
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func make_button(text: String, size := 14) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = theme
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	return b

func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = theme
	return p

func style_box(color: Color, border := Color(0.35, 0.4, 0.52), radius := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	return sb
