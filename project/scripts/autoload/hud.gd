extends CanvasLayer
## HUD: player bars, quest objective, potions, skill cooldown, exp, boss bar, toasts.

var name_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var sp_bar: ProgressBar
var sp_text: Label
var quest_label: Label
var potion_label: Label
var skill_box: PanelContainer
var skill_cd_label: Label
var skill_lock_label: Label
var exp_bar: ProgressBar
var boss_box: PanelContainer
var boss_name: Label
var boss_bar: ProgressBar
var prompt_label: Label
var toast_box: VBoxContainer
var _toasts: Array = []

func _ready() -> void:
	layer = 30
	_build()
	GameState.hp_changed.connect(_on_hp)
	GameState.sp_changed.connect(_on_sp)
	GameState.xp_changed.connect(_on_xp)
	GameState.level_up.connect(_on_level)
	GameState.toast.connect(_on_toast)
	Inv.potions_changed.connect(_on_potions)
	Quests.quest_updated.connect(_refresh_quest)
	visible = false

func _build() -> void:
	var icon_tex: Texture2D = load("res://assets/ui/icons.png")
	# ---- top-left: name/level + bars ----
	var tl := UITheme.make_panel()
	tl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tl.offset_left = 6
	tl.offset_top = 6
	tl.offset_right = 216
	tl.offset_bottom = 78
	add_child(tl)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	tl.add_child(vb)
	name_label = UITheme.make_label("旅人 Lv.1", 13)
	vb.add_child(name_label)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	hp_bar = _bar(Color(0.85, 0.25, 0.25))
	hp_bar.custom_minimum_size = Vector2(140, 8)
	hb.add_child(hp_bar)
	hp_text = UITheme.make_label("", 11)
	hb.add_child(hp_text)
	var hb2 := HBoxContainer.new()
	vb.add_child(hb2)
	sp_bar = _bar(Color(0.25, 0.5, 0.9))
	sp_bar.custom_minimum_size = Vector2(140, 8)
	hb2.add_child(sp_bar)
	sp_text = UITheme.make_label("", 11)
	hb2.add_child(sp_text)

	# ---- top-right: quest objective ----
	var tr := UITheme.make_panel()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -266
	tr.offset_top = 6
	tr.offset_right = -6
	tr.offset_bottom = 68
	add_child(tr)
	quest_label = UITheme.make_label("", 12, Color(1.0, 0.92, 0.7))
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.custom_minimum_size = Vector2(240, 44)
	tr.add_child(quest_label)

	# ---- bottom-left: potion + skill ----
	var bl := HBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 8
	bl.offset_top = -40
	bl.offset_right = 240
	bl.offset_bottom = -26
	bl.add_theme_constant_override("separation", 6)
	add_child(bl)
	var pot_box := UITheme.make_panel()
	pot_box.add_theme_constant_override("content_margin_left", 6)
	pot_box.add_theme_constant_override("content_margin_top", 3)
	pot_box.add_theme_constant_override("content_margin_bottom", 3)
	var pot_hb := HBoxContainer.new()
	pot_hb.add_theme_constant_override("separation", 4)
	pot_box.add_child(pot_hb)
	var pot_icon := _icon(icon_tex, 0)
	pot_hb.add_child(pot_icon)
	potion_label = UITheme.make_label("×3", 12)
	pot_hb.add_child(potion_label)
	bl.add_child(pot_box)
	skill_box = UITheme.make_panel()
	skill_box.add_theme_constant_override("content_margin_left", 6)
	skill_box.add_theme_constant_override("content_margin_top", 3)
	skill_box.add_theme_constant_override("content_margin_bottom", 3)
	var sk_hb := HBoxContainer.new()
	sk_hb.add_theme_constant_override("separation", 4)
	skill_box.add_child(sk_hb)
	sk_hb.add_child(_icon(icon_tex, 9))
	var sk_lbl := UITheme.make_label("L 剑技", 12)
	sk_hb.add_child(sk_lbl)
	skill_cd_label = UITheme.make_label("", 11, Color(1.0, 0.7, 0.5))
	sk_hb.add_child(skill_cd_label)
	skill_lock_label = UITheme.make_label("2级解锁", 11, Color(0.5, 0.5, 0.6))
	sk_hb.add_child(skill_lock_label)
	bl.add_child(skill_box)

	# ---- bottom: exp bar ----
	var eb := PanelContainer.new()
	eb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	eb.offset_left = 4
	eb.offset_right = -4
	eb.offset_top = -8
	eb.offset_bottom = -2
	eb.add_theme_stylebox_override("panel", UITheme.style_box(Color(0.03, 0.04, 0.08, 0.5), Color(0, 0, 0, 0), 0))
	add_child(eb)
	exp_bar = _bar(Color(0.65, 0.55, 0.25))
	exp_bar.custom_minimum_size = Vector2(0, 4)
	exp_bar.show_percentage = false
	eb.add_child(exp_bar)

	# ---- boss bar ----
	boss_box = UITheme.make_panel()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.offset_left = -170
	boss_box.offset_right = 170
	boss_box.offset_top = 4
	boss_box.offset_bottom = 42
	add_child(boss_box)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	boss_box.add_child(bv)
	boss_name = UITheme.make_label("狗头人领主", 13, Color(1.0, 0.55, 0.4))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(boss_name)
	boss_bar = _bar(Color(0.75, 0.2, 0.15))
	boss_bar.custom_minimum_size = Vector2(320, 8)
	bv.add_child(boss_bar)
	boss_box.visible = false

	# ---- interaction prompt ----
	prompt_label = UITheme.make_label("", 12, Color(1.0, 0.95, 0.75))
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -160
	prompt_label.offset_right = 160
	prompt_label.offset_top = -86
	prompt_label.offset_bottom = -60
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)
	prompt_label.visible = false

	# ---- toasts ----
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.offset_left = -220
	toast_box.offset_right = 220
	toast_box.offset_top = 60
	toast_box.offset_bottom = 200
	toast_box.add_theme_constant_override("separation", 4)
	add_child(toast_box)

func _bar(fill_color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.theme = UITheme.theme
	pb.min_value = 0
	pb.show_percentage = false
	var sb := UITheme.style_box(fill_color, Color(0.1, 0.1, 0.15), 1)
	pb.add_theme_stylebox_override("fill", sb)
	return pb

func _icon(tex: Texture2D, index: int) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(index * 16, 0, 16, 16)
	var tr := TextureRect.new()
	tr.texture = at
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(16, 16)
	return tr

func _on_hp(cur: int, maxv: int) -> void:
	hp_bar.max_value = maxv
	hp_bar.value = cur
	hp_text.text = "%d/%d" % [cur, maxv]

func _on_sp(cur: int, maxv: int) -> void:
	sp_bar.max_value = maxv
	sp_bar.value = cur
	sp_text.text = "%d/%d" % [cur, maxv]

func _on_xp(cur: int, next: int) -> void:
	if next <= 0:
		exp_bar.max_value = 1
		exp_bar.value = 1
	else:
		exp_bar.max_value = next
		exp_bar.value = cur

func _on_level(lv: int) -> void:
	_refresh_name()
	Fx.float_text(Vector2(200, 120), "LEVEL UP!", Color(1.0, 0.9, 0.4), 18)

func _on_potions(n: int) -> void:
	potion_label.text = "×%d" % n

func _refresh_name() -> void:
	name_label.text = "%s Lv.%d" % [GameState.player_name, GameState.level]

func _refresh_quest() -> void:
	quest_label.text = Quests.objective_text()

func set_prompt(text: String) -> void:
	if text == "":
		prompt_label.visible = false
	else:
		prompt_label.text = "按 E：%s" % text
		prompt_label.visible = true

func _on_toast(text: String, color: Color) -> void:
	var l := UITheme.make_label(text, 12, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func show_all() -> void:
	visible = true
	_refresh_name()
	_refresh_quest()
	_on_hp(GameState.hp, GameState.max_hp())
	_on_sp(GameState.sp, GameState.max_sp())
	_on_xp(GameState.xp, GameState.xp_for_next())
	_on_potions(GameState.potion_count())

func hide_all() -> void:
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	# skill cooldown
	var p := MapMan.player
	if p != null and is_instance_valid(p):
		if GameState.level < int(Config.b("skill_dash.unlock_level", 2)):
			skill_cd_label.text = ""
			skill_lock_label.visible = true
		else:
			skill_lock_label.visible = false
			if p.skill_cd > 0.0:
				skill_cd_label.text = "%.1fs" % p.skill_cd
				skill_box.modulate = Color(0.7, 0.7, 0.75)
			else:
				skill_cd_label.text = ""
				skill_box.modulate = Color.WHITE
	# boss bar
	var boss := MapMan.boss
	if boss != null and is_instance_valid(boss) and boss.fight_started and not boss.dead:
		boss_box.visible = true
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
	else:
		boss_box.visible = false
