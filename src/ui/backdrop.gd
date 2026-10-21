class_name Backdrop
extends ColorRect
## Animated gradient + bloom orbs + stars. Used behind every screen.

static var _shader: Shader


func _init(theme_colors := {}) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = load("res://src/ui/backdrop.gdshader")
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = _shader
	apply_colors(theme_colors)
	resized.connect(_on_resized)


func apply_colors(c: Dictionary) -> void:
	var m := material as ShaderMaterial
	if c.is_empty():
		return
	m.set_shader_parameter("top_color", c.bg_top)
	m.set_shader_parameter("bottom_color", c.bg_bot)
	m.set_shader_parameter("glow_a", c.accent)
	m.set_shader_parameter("glow_b", c.accent2)


func set_scroll(v: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("scroll", v)


func _on_resized() -> void:
	if size.y > 0.0:
		(material as ShaderMaterial).set_shader_parameter("aspect", Vector2(size.x / size.y, 1.0))
