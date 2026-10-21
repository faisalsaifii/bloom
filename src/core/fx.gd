class_name Fx
extends RefCounted
## Shared visual helpers: soft glow textures, additive material, tiny particle system.

static var _glow: Texture2D
static var _additive: CanvasItemMaterial
static var _circle_cache := {}


static func glow() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.8, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.16),
			Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow = t
	return _glow


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


## Anti-aliased filled circle texture (used for slider grabbers etc).
static func circle_tex(diameter: int, color: Color) -> Texture2D:
	var key := "%d_%s" % [diameter, color.to_html()]
	if _circle_cache.has(key):
		return _circle_cache[key]
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c := diameter / 2.0
	for y in diameter:
		for x in diameter:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(c, c))
			var a := clampf(c - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	var tex := ImageTexture.create_from_image(img)
	_circle_cache[key] = tex
	return tex


static func halo(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(glow(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


static func neon(hue: float, s := 0.65, v := 1.0, a := 1.0) -> Color:
	return Color.from_hsv(fposmod(hue, 1.0), s, v, a)


## Draws a polygon outline as a closed line loop.
static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, color, width, true)


## Lightweight particle system, drawn additively by whoever owns it.
class Particles:
	var items: Array = []
	var max_count := 400

	func emit(pos: Vector2, vel: Vector2, life: float, size: float, color: Color, drag := 0.0, grow := 0.0, gravity := 0.0) -> void:
		if items.size() >= max_count:
			items.pop_front()
		items.append({"p": pos, "v": vel, "l": life, "m": life, "s": size, "c": color, "d": drag, "g": grow, "gr": gravity})

	func burst(pos: Vector2, count: int, speed: float, life: float, size: float, color: Color, spread := 6.2831853) -> void:
		for i in count:
			var a := randf() * spread
			var sp := speed * randf_range(0.35, 1.0)
			emit(pos, Vector2(cos(a), sin(a)) * sp, life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.2), color, 1.5)

	func update(dt: float) -> void:
		var i := items.size() - 1
		while i >= 0:
			var it: Dictionary = items[i]
			var life: float = it["l"] - dt
			if life <= 0.0:
				items.remove_at(i)
			else:
				var v: Vector2 = it["v"]
				v *= maxf(0.0, 1.0 - float(it["d"]) * dt)
				v.y += float(it["gr"]) * dt
				it["l"] = life
				it["v"] = v
				it["p"] = Vector2(it["p"]) + v * dt
				it["s"] = float(it["s"]) + float(it["g"]) * dt
			i -= 1

	func draw(ci: CanvasItem) -> void:
		for it in items:
			var k: float = float(it["l"]) / float(it["m"])
			var col: Color = it["c"]
			col.a *= k
			var r: float = maxf(0.5, float(it["s"]) * (0.35 + 0.65 * k))
			var p: Vector2 = it["p"]
			Fx.halo(ci, p, r * 3.2, Color(col.r, col.g, col.b, col.a * 0.55))
			ci.draw_circle(p, r, col)

	func clear() -> void:
		items.clear()


## Node2D that paints through a callable with additive blending (fake bloom layer).
class GlowLayer extends Node2D:
	var painter: Callable

	func _init(p: Callable = Callable()) -> void:
		painter = p
		material = Fx.additive()

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)
