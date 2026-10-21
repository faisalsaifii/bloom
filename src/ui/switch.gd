class_name Switch
extends Control
## Animated pill toggle.

signal toggled(on: bool)

var on := true
var accent := UI.ACCENT
var _k := 1.0
var _tween: Tween


func _init(initial := true, accent_color := UI.ACCENT) -> void:
	on = initial
	_k = 1.0 if on else 0.0
	accent = accent_color
	custom_minimum_size = Vector2(92, 50)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_on(v: bool) -> void:
	on = v
	_animate()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		on = not on
		Sfx.play("ui_toggle", 1.0 if on else 0.8)
		_animate()
		toggled.emit(on)
		accept_event()


func _animate() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float): _k = v; queue_redraw(), _k, 1.0 if on else 0.0, 0.22)


func _draw() -> void:
	var r := size.y * 0.5
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r))
	sb.bg_color = Color(accent.r, accent.g, accent.b, lerpf(0.1, 0.55, _k))
	sb.border_color = Color(accent.r, accent.g, accent.b, lerpf(0.3, 1.0, _k))
	sb.set_border_width_all(2)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.45 * _k)
	sb.shadow_size = int(14 * _k)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var kx := lerpf(r, size.x - r, _k)
	draw_circle(Vector2(kx, r), r - 6.0, Color.WHITE.lerp(Color(0.7, 0.75, 0.9), 1.0 - _k))
