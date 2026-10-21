class_name UI
extends RefCounted
## Design system helpers: fonts, glass panels, labels, theme.

const FONT_PATH := "res://assets/fonts/Outfit.ttf"
const TEXT := Color("f4f6ff")
const TEXT_DIM := Color("9aa3d0")
const GOLD := Color("ffd24a")
const DANGER := Color("ff4d6d")
const ACCENT := Color("38e8ff")
const ACCENT2 := Color("b57bff")

static var _fonts := {}


static func font(weight := 500) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(FONT_PATH)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


static func label(text: String, size := 28, color := TEXT, weight := 500) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func glass(accent := ACCENT, radius := 24, fill := 0.07, border := 0.35, glow := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, fill)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(2)
	s.border_color = Color(accent.r, accent.g, accent.b, border)
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.2
	if glow > 0.0:
		s.shadow_color = Color(accent.r, accent.g, accent.b, glow)
		s.shadow_size = 18
	return s


static func panel(accent := ACCENT, radius := 28) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass(accent, radius, 0.06, 0.3, 0.0))
	return p


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = 26
	# Sliders
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(6)
	fill.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	fill.shadow_size = 8
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", Fx.circle_tex(34, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", Fx.circle_tex(40, Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", Fx.circle_tex(34, Color(1, 1, 1, 0.4)))
	t.set_constant("center_grabber", "HSlider", 1)
	# Scroll bars: hidden for touch-friendly look.
	var empty := StyleBoxEmpty.new()
	for sb in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(sb, "VScrollBar", empty)
		t.set_stylebox(sb, "HScrollBar", empty)
	return t


static func level_color(n: int) -> Color:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray([Color("38e8ff"), Color("4dff9a"), Color("ffd24a"), Color("ff8a3d"), Color("ff4d6d"), Color("b57bff")])
	return g.sample(Levels.difficulty(n))
