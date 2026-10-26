extends Node
## Fx: transient visual effects (slashes, sparks, dust, ghosts, floating text).

func _host() -> Node:
	if MapMan.current_map != null:
		var e := MapMan.current_map.get_node_or_null("Entities")
		if e != null:
			return e
	return get_tree().current_scene

func spawn_slash(pos: Vector2, angle: float, big := false) -> void:
	var tex: Texture2D = load("res://assets/fx/slash_big.png" if big else "res://assets/fx/slash.png")
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _make_frames(tex, 4, 0.045)
	spr.position = pos
	spr.rotation = angle
	spr.z_index = 20
	_host().add_child(spr)
	spr.play("fx")
	spr.animation_finished.connect(spr.queue_free)

func spawn_skill_slash(pos: Vector2, angle: float) -> void:
	var tex: Texture2D = load("res://assets/fx/slash_big.png")
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _make_frames(tex, 4, 0.04)
	spr.position = pos
	spr.rotation = angle
	spr.modulate = Color(0.75, 1.0, 1.0)
	spr.z_index = 20
	_host().add_child(spr)
	spr.play("fx")
	spr.animation_finished.connect(spr.queue_free)

func spark(pos: Vector2) -> void:
	var tex: Texture2D = load("res://assets/fx/spark.png")
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _make_frames(tex, 4, 0.03)
	spr.position = pos
	spr.z_index = 20
	_host().add_child(spr)
	spr.play("fx")
	spr.animation_finished.connect(spr.queue_free)

func dust(pos: Vector2, dir: Vector2 = Vector2.ZERO) -> void:
	var tex: Texture2D = load("res://assets/fx/dust.png")
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _make_frames(tex, 3, 0.07)
	spr.position = pos + dir * 6.0
	spr.z_index = 5
	_host().add_child(spr)
	spr.play("fx")
	spr.animation_finished.connect(spr.queue_free)

func ghost(pos: Vector2, texture: Texture2D, cell: int) -> void:
	var spr := Sprite2D.new()
	spr.texture = texture
	spr.hframes = 18
	spr.vframes = 4
	spr.frame = cell
	spr.position = pos
	spr.modulate = Color(0.75, 0.92, 1.0, 0.45)
	spr.z_index = 3
	_host().add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, 0.3)
	tw.tween_callback(spr.queue_free)

func float_text(pos: Vector2, text: String, color := Color(1, 1, 1), size := 13) -> void:
	var l := Label.new()
	l.text = text
	l.theme = UITheme.theme
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.position = pos + Vector2(-30, -26)
	l.z_index = 30
	_host().add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(l.queue_free)

func _make_frames(tex: Texture2D, count: int, speed: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var w := tex.get_width() / count
	sf.add_animation("fx")
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * w, 0, w, tex.get_height())
		sf.add_frame("fx", at)
	sf.set_animation_speed("fx", 1.0 / speed)
	sf.set_animation_loop("fx", false)
	return sf
