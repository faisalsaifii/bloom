class_name Icons
extends RefCounted
## Vector icons drawn with primitives (no font glyph or image dependencies).


static func star_points(c: Vector2, r: float, rot := -PI / 2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot + i * TAU / 10
		var rr := r if i % 2 == 0 else r * 0.46
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func star(ci: CanvasItem, c: Vector2, r: float, color: Color, filled := true) -> void:
	var pts := star_points(c, r)
	if filled:
		ci.draw_colored_polygon(pts, color)
	Fx.outline(ci, pts, color if filled else Color(color.r, color.g, color.b, 0.45), maxf(1.5, r * 0.12))


static func coin(ci: CanvasItem, c: Vector2, r: float, spin := 1.0) -> void:
	var gold := UI.GOLD
	ci.draw_set_transform(c, 0.0, Vector2(maxf(0.15, absf(spin)), 1.0))
	ci.draw_circle(Vector2.ZERO, r, gold)
	ci.draw_arc(Vector2.ZERO, r * 0.66, 0, TAU, 24, Color(1, 0.97, 0.75, 0.9), maxf(1.5, r * 0.14), true)
	ci.draw_arc(Vector2.ZERO, r, 0, TAU, 28, Color(1, 0.93, 0.6), maxf(1.5, r * 0.1), true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func chevron(ci: CanvasItem, c: Vector2, s: float, dir: float, color: Color, w := 5.0) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-dir * s * 0.45, -s), c + Vector2(dir * s * 0.45, 0), c + Vector2(-dir * s * 0.45, s)]), color, w, true)


static func pause(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.9, -s), Vector2(s * 0.62, s * 2)), color)
	ci.draw_rect(Rect2(c + Vector2(s * 0.28, -s), Vector2(s * 0.62, s * 2)), color)


static func play(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, -s), c + Vector2(s * 1.0, 0), c + Vector2(-s * 0.7, s)]), color)


static func restart(ci: CanvasItem, c: Vector2, s: float, color: Color, w := 5.0) -> void:
	ci.draw_arc(c, s, -PI * 0.35, PI * 1.45, 28, color, w, true)
	var tip := c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * s
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.1, -s * 0.55), tip + Vector2(s * 0.5, s * 0.1), tip + Vector2(-s * 0.55, s * 0.1)]), color)


static func home(ci: CanvasItem, c: Vector2, s: float, color: Color, w := 4.0) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(0, -s * 0.95), c + Vector2(s, 0)]), color, w, true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.2), c + Vector2(-s * 0.7, s * 0.85), c + Vector2(s * 0.7, s * 0.85), c + Vector2(s * 0.7, -s * 0.2)]), color, w, true)


static func lock(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.55, PI, TAU, 16, color, maxf(2.0, s * 0.22), true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(s * 0.25))
	ci.draw_style_box(sb, Rect2(c + Vector2(-s * 0.8, -s * 0.2), Vector2(s * 1.6, s * 1.2)))
	ci.draw_circle(c + Vector2(0, s * 0.4), s * 0.16, Color(0.05, 0.05, 0.15, 0.85))


static func check(ci: CanvasItem, c: Vector2, s: float, color: Color, w := 5.0) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s * 0.3, s * 0.7), c + Vector2(s, -s * 0.7)]), color, w, true)


static func cross(ci: CanvasItem, c: Vector2, s: float, color: Color, w := 5.0) -> void:
	ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), color, w, true)
	ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), color, w, true)


static func bloom(ci: CanvasItem, c: Vector2, r: float, rot := 0.0, alpha := 1.0) -> void:
	for i in 6:
		var a := rot + i * TAU / 6
		var col := Color.from_hsv(i / 6.0 + 0.9, 0.55, 1.0, alpha)
		ci.draw_arc(c + Vector2(cos(a), sin(a)) * r * 0.52, r * 0.4, 0, TAU, 24, col, maxf(2.0, r * 0.07), true)
	ci.draw_circle(c, r * 0.2, Color(1, 1, 1, alpha))
