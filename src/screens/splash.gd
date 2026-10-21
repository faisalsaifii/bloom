extends Screen
## Brand splash: logo blooms in, then hands over to the main menu.

var _logo: TextureRect
var _tap: Label
var _t := 0.0
var _done := false
var _ring: Control


func _backdrop_colors() -> Dictionary:
	return Levels.theme(1)


func build() -> void:
	modulate.a = 1.0
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)

	_logo = TextureRect.new()
	_logo.texture = load("res://assets/branding/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.set_anchors_preset(Control.PRESET_CENTER)
	_logo.custom_minimum_size = Vector2(760, 380)
	_logo.size = Vector2(760, 380)
	_logo.position = (get_viewport_rect().size - _logo.size) * 0.5 + Vector2(0, -20)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.modulate.a = 0.0
	_logo.scale = Vector2(0.8, 0.8)
	add_child(_logo)

	_tap = UI.label("tap to start" if OS.has_feature("web") else "everything glows", 28, UI.TEXT_DIM, 400)
	_tap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tap.position = Vector2(get_viewport_rect().size.x * 0.5 - 100, get_viewport_rect().size.y - 110)
	_tap.modulate.a = 0.0
	add_child(_tap)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_logo, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_tap, "modulate:a", 1.0, 0.8).set_delay(0.8)
	get_tree().create_timer(0.35).timeout.connect(func(): Sfx.play("win", 1.0, -8.0))
	if not OS.has_feature("web"):
		get_tree().create_timer(2.6).timeout.connect(_finish)


func _process(delta: float) -> void:
	_t += delta
	_ring.queue_redraw()


func _draw_ring() -> void:
	var c := _ring.size * 0.5 + Vector2(0, -50)
	var k := clampf(_t / 1.2, 0.0, 1.0)
	for i in 6:
		var a := _t * 0.6 + i * TAU / 6
		var col := Color.from_hsv(i / 6.0 + 0.9, 0.55, 1.0, (1.0 - k) * 0.9)
		var p := c + Vector2(cos(a), sin(a)) * (60.0 + 360.0 * k)
		Fx.halo(_ring, p, 40.0, Color(col.r, col.g, col.b, col.a * 0.7))
		_ring.draw_circle(p, 5.0, col)


func _input(e: InputEvent) -> void:
	if _t > 0.6 and ((e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Sfx.play_music("menu")
	Nav.go("menu")
