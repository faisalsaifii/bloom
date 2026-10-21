class_name SkinView
extends Control
## Animated preview of a character (bobbing, glowing). Used in the shop, menu and results.

var skin: Dictionary
var radius := 30.0
var hop := true
var locked := false
var _t := randf() * 10.0
var _glow: Fx.GlowLayer
var _ps := Fx.Particles.new()
var _emit := 0.0


func _init(skin_id := "orb", r := 30.0, hopping := true) -> void:
	skin = Skins.get_skin(skin_id)
	radius = r
	hop = hopping
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = Fx.GlowLayer.new(_paint_glow)
	add_child(_glow)


func set_skin(id: String) -> void:
	skin = Skins.get_skin(id)
	_ps.clear()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_ps.update(delta)
	var c := _centre()
	_emit += delta
	if _emit > 0.03 and not locked:
		_emit = 0.0
		Skins.emit_trail(_ps, skin, c + Vector2(0, radius * 0.4), Vector2(randf_range(-40, 40), -30), _t, delta)
	queue_redraw()
	_glow.queue_redraw()


func _centre() -> Vector2:
	var bob := 0.0
	if hop:
		bob = -absf(sin(_t * 2.6)) * radius * 0.9
	return size * 0.5 + Vector2(0, bob)


func _squash() -> Vector2:
	if not hop:
		return Vector2.ONE
	var k := absf(sin(_t * 2.6))
	var s := 1.0 + (0.5 - k) * 0.12
	return Vector2(1.0 / s, s)


func _draw() -> void:
	if locked:
		var dark := skin.duplicate()
		dark.c1 = Color(0.2, 0.22, 0.32)
		dark.c2 = Color(0.45, 0.48, 0.6)
		dark.trail = "none"
		Skins.draw(self, dark, size * 0.5, radius, _t * 0.5, _t, false, 0.0, Vector2.ONE)
		return
	if hop:
		var k := absf(sin(_t * 2.6))
		var sh := 1.0 - k * 0.5
		draw_set_transform(size * 0.5 + Vector2(0, radius * 1.15), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, radius * 1.1 * sh, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Skins.draw(self, skin, _centre(), radius, _t * 1.2, _t, false, sin(_t * 0.8) * 0.6, _squash())


func _paint_glow(ci: CanvasItem) -> void:
	_ps.draw(ci)
	if locked:
		return
	Skins.draw(ci, skin, _centre(), radius, _t * 1.2, _t, true, 0.0, Vector2.ONE, 1.0 + 0.08 * sin(_t * 3.0))
