class_name Skins
extends RefCounted
## Character catalogue + procedural drawing of every character (all glowing, all vector).

const LIST := [
	{"id": "orb", "name": "Orb", "price": 0, "shape": "circle", "c1": Color("22e6ff"), "c2": Color("d9fbff"), "trail": "spark", "tag": "The original glow"},
	{"id": "cube", "name": "Cube", "price": 100, "shape": "square", "c1": Color("ff4fd8"), "c2": Color("ffd6f6"), "trail": "spark", "tag": "Rolls with style"},
	{"id": "prism", "name": "Prism", "price": 220, "shape": "triangle", "c1": Color("ffd23f"), "c2": Color("fff6cf"), "trail": "spark", "tag": "Sharp and bright"},
	{"id": "hexa", "name": "Hexa", "price": 350, "shape": "hexagon", "c1": Color("3dffa2"), "c2": Color("d4ffe9"), "trail": "bubbles", "tag": "Six sides of glow"},
	{"id": "heart", "name": "Pulse", "price": 500, "shape": "heart", "c1": Color("ff4f81"), "c2": Color("ffd0de"), "trail": "bubbles", "tag": "Beats with the music"},
	{"id": "diamond", "name": "Crystal", "price": 700, "shape": "diamond", "c1": Color("7bb6ff"), "c2": Color("e8f2ff"), "trail": "spark", "tag": "Cut from pure light"},
	{"id": "ring", "name": "Halo", "price": 900, "shape": "ring", "c1": Color("ff9a3d"), "c2": Color("ffe3c7"), "trail": "spark", "tag": "Hollow but radiant"},
	{"id": "star", "name": "Starling", "price": 1150, "shape": "star", "c1": Color("ffe14d"), "c2": Color("fffbe0"), "trail": "spark", "tag": "Born in the night sky"},
	{"id": "ghost", "name": "Wisp", "price": 1450, "shape": "ghost", "c1": Color("b79bff"), "c2": Color("f0e9ff"), "trail": "bubbles", "tag": "Floats right through"},
	{"id": "fireball", "name": "Fireball", "price": 1800, "shape": "fire", "c1": Color("ff6a1a"), "c2": Color("ffe27a"), "trail": "fire", "tag": "Leaves a blaze behind"},
	{"id": "plasma", "name": "Plasma", "price": 2300, "shape": "plasma", "c1": Color("3df2ff"), "c2": Color("ffffff"), "trail": "electric", "tag": "Crackling with energy"},
	{"id": "nova", "name": "Nova", "price": 3000, "shape": "nova", "c1": Color("ff4fd8"), "c2": Color("ffffff"), "trail": "rainbow", "tag": "Every colour at once"},
]

static var _cube_style: StyleBoxFlat


static func get_skin(id: String) -> Dictionary:
	for s in LIST:
		if s.id == id:
			return s
	return LIST[0]


static func main_color(s: Dictionary, t: float) -> Color:
	if s.shape == "nova":
		return Color.from_hsv(fposmod(t * 0.25, 1.0), 0.7, 1.0)
	return s.c1


static func _poly(shape: String, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"triangle":
			for i in 3:
				var a := -PI / 2 + i * TAU / 3
				pts.append(Vector2(cos(a), sin(a)) * r * 1.2 + Vector2(0, r * 0.18))
		"hexagon":
			for i in 6:
				var a := i * TAU / 6
				pts.append(Vector2(cos(a), sin(a)) * r * 1.05)
		"diamond":
			pts = PackedVector2Array([Vector2(0, -r * 1.3), Vector2(r * 0.95, 0), Vector2(0, r * 1.3), Vector2(-r * 0.95, 0)])
		"star":
			for i in 10:
				var a := -PI / 2 + i * TAU / 10
				var rr := r * 1.25 if i % 2 == 0 else r * 0.55
				pts.append(Vector2(cos(a), sin(a)) * rr)
		"heart":
			for i in 28:
				var a := i * TAU / 28
				var x := 16.0 * pow(sin(a), 3)
				var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
				pts.append(Vector2(x, y + 1.5) * (r / 14.5))
		"ghost":
			for i in 13:
				var a := PI + i * PI / 12
				pts.append(Vector2(cos(a), sin(a)) * r)
			var teeth := 4
			var w := r * 2.0 / teeth
			for i in teeth * 2 + 1:
				var x := r - i * w / 2.0
				pts.append(Vector2(x, r * 0.95 if i % 2 == 0 else r * 0.55))
		_:
			for i in 32:
				var a := i * TAU / 32
				pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out


## Draws the character at `pos`. glow=true paints only the additive halo pass.
static func draw(ci: CanvasItem, s: Dictionary, pos: Vector2, r: float, rot: float, t: float,
		glow := false, look := 0.0, squash := Vector2.ONE, pulse := 1.0) -> void:
	var c1: Color = main_color(s, t)
	var c2: Color = s.c2
	var shape: String = s.shape
	if glow:
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var hr := r * 3.4 * pulse
		Fx.halo(ci, pos, hr, Color(c1.r, c1.g, c1.b, 0.55))
		Fx.halo(ci, pos, hr * 0.45, Color(c2.r, c2.g, c2.b, 0.35))
		if shape == "plasma":
			for i in 3:
				var a := t * 4.0 + i * TAU / 3
				Fx.halo(ci, pos + Vector2(cos(a), sin(a * 1.0)) * r * 1.7, r * 1.1, Color(c1.r, c1.g, c1.b, 0.7))
		return
	var spins := shape in ["square", "triangle", "hexagon", "diamond", "star"]
	ci.draw_set_transform(pos, rot if spins else 0.0, squash)
	match shape:
		"square":
			if _cube_style == null:
				_cube_style = StyleBoxFlat.new()
				_cube_style.set_corner_radius_all(6)
				_cube_style.anti_aliasing = true
			var h := r * 0.92
			_cube_style.bg_color = c1
			ci.draw_style_box(_cube_style, Rect2(-h, -h, h * 2, h * 2))
			var h2 := h * 0.58
			_cube_style.bg_color = Color(c2.r, c2.g, c2.b, 0.55)
			ci.draw_style_box(_cube_style, Rect2(-h2, -h2, h2 * 2, h2 * 2))
		"ring":
			ci.draw_arc(Vector2.ZERO, r * 0.78, 0, TAU, 40, c1, r * 0.55, true)
			ci.draw_arc(Vector2.ZERO, r * 0.78, 0, TAU, 40, Color(c2.r, c2.g, c2.b, 0.7), r * 0.18, true)
		"fire":
			var t2 := t * 9.0
			for i in 5:
				var a := -PI / 2 + (i - 2) * 0.55 + sin(t2 + i * 1.7) * 0.18
				var tip := r * (1.55 + 0.35 * sin(t2 * 1.3 + i * 2.1))
				var base := Vector2(cos(a - 0.45), sin(a - 0.45)) * r * 0.85
				var base2 := Vector2(cos(a + 0.45), sin(a + 0.45)) * r * 0.85
				ci.draw_colored_polygon(PackedVector2Array([base, Vector2(cos(a), sin(a)) * tip, base2]), Color(c1.r, c1.g * 0.8, c1.b, 0.95))
			ci.draw_circle(Vector2.ZERO, r, c1)
			ci.draw_circle(Vector2.ZERO, r * 0.62, c2)
		"plasma", "nova", "circle":
			ci.draw_circle(Vector2.ZERO, r, c1)
			ci.draw_circle(Vector2(-r * 0.18, -r * 0.2), r * 0.62, Color(c2.r, c2.g, c2.b, 0.55))
			ci.draw_arc(Vector2.ZERO, r - 1.0, 0, TAU, 32, Color(c2.r, c2.g, c2.b, 0.9), 2.0, true)
			if shape == "plasma":
				for i in 3:
					var a := t * 4.0 + i * TAU / 3
					ci.draw_circle(Vector2(cos(a), sin(a)) * r * 1.7, r * 0.2, c2)
		_:
			var pts := _poly(shape, r)
			ci.draw_colored_polygon(pts, c1)
			ci.draw_colored_polygon(_scaled(pts, 0.6), Color(c2.r, c2.g, c2.b, 0.5))
			Fx.outline(ci, pts, Color(c2.r, c2.g, c2.b, 0.95), 2.5)
	# Eyes stay upright and look where the character is heading.
	if shape != "ring":
		ci.draw_set_transform(pos, 0.0, squash)
		var eye_y := -r * 0.12 if shape != "triangle" else r * 0.18
		var ex := r * 0.34
		for sgn in [-1.0, 1.0]:
			var ec := Vector2(sgn * ex + look * r * 0.18, eye_y)
			ci.draw_circle(ec, r * 0.17, Color(0.05, 0.05, 0.12, 0.92))
			ci.draw_circle(ec + Vector2(-r * 0.04, -r * 0.05), r * 0.06, Color(1, 1, 1, 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Emits trail particles for the character while it moves.
static func emit_trail(ps: Fx.Particles, s: Dictionary, pos: Vector2, vel: Vector2, t: float, dt: float) -> void:
	var speed := vel.length()
	var c1 := main_color(s, t)
	match s.trail:
		"fire":
			for i in 2:
				ps.emit(pos + Vector2(randf_range(-6, 6), randf_range(-2, 8)), -vel * 0.12 + Vector2(randf_range(-30, 30), randf_range(-70, -20)),
					randf_range(0.35, 0.6), randf_range(5, 9), Color(1.0, randf_range(0.35, 0.8), 0.1, 0.9), 2.0, -6.0, -120.0)
		"rainbow":
			ps.emit(pos, -vel * 0.1 + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0.6, randf_range(4, 7),
				Color.from_hsv(fposmod(t * 0.9, 1.0), 0.75, 1.0, 0.9), 2.0)
		"electric":
			if randf() < 0.8:
				ps.emit(pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), Vector2(randf_range(-160, 160), randf_range(-160, 160)),
					randf_range(0.12, 0.25), randf_range(2, 3.5), Color(0.6, 1.0, 1.0, 1.0), 3.0)
		"bubbles":
			if randf() < 0.5 + speed * 0.0012:
				ps.emit(pos + Vector2(randf_range(-8, 8), randf_range(0, 10)), Vector2(randf_range(-20, 20), randf_range(-40, -10)),
					randf_range(0.5, 0.9), randf_range(3, 6), Color(c1.r, c1.g, c1.b, 0.7), 1.0, 2.0)
		_:
			if speed > 60.0 and randf() < 0.7:
				ps.emit(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), -vel * 0.06 + Vector2(randf_range(-25, 25), randf_range(-25, 25)),
					randf_range(0.3, 0.5), randf_range(2.5, 5), Color(c1.r, c1.g, c1.b, 0.8), 2.0)
