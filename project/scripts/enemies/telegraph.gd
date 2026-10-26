extends Node2D
## Telegraph: draws enemy attack warnings (arc / line / circle), translucent red-orange.

var kind := ""
var arc_deg := 90.0
var angle := 0.0
var radius := 40.0
var line_dir := Vector2.RIGHT
var line_len := 80.0
var line_w := 24.0

func show_arc(dir: Vector2, arc_deg_px: float, radius_px: float) -> void:
	kind = "arc"
	angle = dir.angle()
	arc_deg = arc_deg_px
	radius = radius_px
	visible = true
	queue_redraw()

func show_line(dir: Vector2, length: float, width: float) -> void:
	kind = "line"
	line_dir = dir.normalized()
	line_len = length
	line_w = width
	visible = true
	queue_redraw()

func show_circle(radius_px: float) -> void:
	kind = "circle"
	radius = radius_px
	visible = true
	queue_redraw()

func hide() -> void:
	visible = false

func _draw() -> void:
	var fill := Color(1.0, 0.25, 0.1, 0.22)
	var edge := Color(1.0, 0.42, 0.2, 0.55)
	match kind:
		"arc":
			var pts := PackedVector2Array()
			pts.append(Vector2.ZERO)
			var steps := 24
			for i in steps + 1:
				var a := angle - deg_to_rad(arc_deg * 0.5) + deg_to_rad(arc_deg) * i / steps
				pts.append(Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(pts, fill)
			for i in steps + 1:
				var a := angle - deg_to_rad(arc_deg * 0.5) + deg_to_rad(arc_deg) * i / steps
				draw_circle(Vector2(cos(a), sin(a)) * radius, 1.5, edge)
		"line":
			var perp := line_dir.orthogonal()
			var pts := PackedVector2Array([
				perp * (line_w * 0.5),
				perp * (line_w * 0.5) + line_dir * line_len,
				perp * (-line_w * 0.5) + line_dir * line_len,
				perp * (-line_w * 0.5),
			])
			draw_colored_polygon(pts, fill)
			for i in 4:
				draw_line(pts[i], pts[(i + 1) % 4], edge, 1.5)
		"circle":
			draw_circle(Vector2.ZERO, radius, fill)
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, edge, 1.5)
