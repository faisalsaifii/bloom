class_name GlowButton
extends Button
## Glassy neon button with hover glow, press squash and sound.

var accent := UI.ACCENT
var corner := 22
var _tween: Tween
var muted := false


static func make(text: String, accent_color := UI.ACCENT, font_size := 32, min_size := Vector2(300, 78)) -> GlowButton:
	var b := GlowButton.new()
	b.text = text
	b.accent = accent_color
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", UI.font(600))
	b.add_theme_font_size_override("font_size", font_size)
	return b


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_color_override("font_color", UI.TEXT)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	_apply_styles()
	resized.connect(func(): pivot_offset = size * 0.5)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(func(): _scale_to(1.0))
	button_down.connect(func(): _scale_to(0.95, 0.07))
	button_up.connect(func(): _scale_to(1.04 if is_hovered() else 1.0, 0.12))
	pressed.connect(func():
		if not muted:
			Sfx.click())


func set_accent(c: Color) -> void:
	accent = c
	_apply_styles()


func _style(fill: float, border: float, glow: float, shadow_size: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent.r, accent.g, accent.b, fill)
	s.set_corner_radius_all(corner)
	s.set_border_width_all(2)
	s.border_color = Color(accent.r, accent.g, accent.b, border)
	s.shadow_color = Color(accent.r, accent.g, accent.b, glow)
	s.shadow_size = shadow_size
	s.anti_aliasing = true
	s.content_margin_left = 22
	s.content_margin_right = 22
	return s


func _apply_styles() -> void:
	add_theme_stylebox_override("normal", _style(0.13, 0.8, 0.28, 12))
	add_theme_stylebox_override("hover", _style(0.26, 1.0, 0.5, 22))
	add_theme_stylebox_override("pressed", _style(0.4, 1.0, 0.4, 8))
	add_theme_stylebox_override("disabled", _style(0.04, 0.2, 0.0, 0))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_hover() -> void:
	if not disabled and not muted:
		Sfx.hover()
	_scale_to(1.04)


func _scale_to(s: float, d := 0.15) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(s, s), d)
