class_name Screen
extends Control
## Base for all full-screen menus: backdrop, safe-area margins, header, entrance animation.

var backdrop: Backdrop
var content: MarginContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	backdrop = Backdrop.new(_backdrop_colors())
	add_child(backdrop)
	content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	var m := safe_margins()
	content.add_theme_constant_override("margin_left", m.x)
	content.add_theme_constant_override("margin_right", m.z)
	content.add_theme_constant_override("margin_top", m.y)
	content.add_theme_constant_override("margin_bottom", m.w)
	add_child(content)
	build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func _backdrop_colors() -> Dictionary:
	return Levels.theme(1)


## Returns Vector4(left, top, right, bottom) margins incl. notch safe area on phones.
func safe_margins() -> Vector4:
	var base := 36
	var out := Vector4(base, 28, base, 28)
	if OS.has_feature("mobile"):
		var win := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var vp := get_viewport().get_visible_rect().size
		if win.x > 0 and safe.size.x > 0:
			var k := vp.x / float(win.x)
			out.x += maxf(0.0, safe.position.x) * k
			out.z += maxf(0.0, win.x - safe.end.x) * k
			out.y += maxf(0.0, safe.position.y) * k
			out.w += maxf(0.0, win.y - safe.end.y) * k
	return out


func build() -> void:
	pass


func on_back() -> void:
	pass


## Standard top bar. Returns the HBox so callers can append extra widgets on the right.
func make_header(title: String, accent := UI.ACCENT, show_back := true, show_wallet := true) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.custom_minimum_size = Vector2(0, 76)
	if show_back:
		var b := IconButton.make_icon("back", 72, accent)
		b.pressed.connect(on_back)
		h.add_child(b)
	var t := UI.label(title, 44, UI.TEXT, 700)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	if show_wallet:
		var w := Wallet.new()
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(w)
	return h


func pop_in(nodes: Array, delay := 0.06, from := Vector2(0, 30)) -> void:
	var i := 0
	for n in nodes:
		var c: Control = n
		c.modulate.a = 0.0
		var target := c.position
		var tw := create_tween().set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(0.08 + i * delay)
		i += 1
