extends Screen
## Main menu: Play / Settings / Exit.

const VERSION := "1.0.0"
var _logo: TextureRect


func _backdrop_colors() -> Dictionary:
	return Levels.theme(1)


func build() -> void:
	Sfx.play_music("menu")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	content.add_child(row)

	# ---- Left: brand + hero character
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)

	_logo = TextureRect.new()
	_logo.texture = load("res://assets/branding/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(560, 300)
	left.add_child(_logo)

	var tag := UI.label("hop. glow. collect.", 30, UI.TEXT_DIM, 400)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(tag)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(560, 190)
	left.add_child(pad)
	var plat := StyleBoxFlat.new()
	plat.bg_color = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.16)
	plat.border_color = UI.ACCENT
	plat.set_border_width_all(3)
	plat.set_corner_radius_all(11)
	plat.shadow_color = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.5)
	plat.shadow_size = 18
	plat.anti_aliasing = true
	pad.draw.connect(func(): pad.draw_style_box(plat, Rect2(pad.size.x * 0.5 - 130, 150, 260, 22)))
	var hero := SkinView.new(Save.equipped, 34.0, true)
	hero.size = Vector2(120, 140)
	pad.add_child(hero)
	pad.resized.connect(func(): hero.position = Vector2(pad.size.x * 0.5 - 60, 12))

	# ---- Right: buttons
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(440, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 22)
	row.add_child(right)

	var play := GlowButton.make("PLAY", UI.ACCENT, 42, Vector2(420, 104))
	play.pressed.connect(func(): Nav.go("levels"))
	var settings := GlowButton.make("SETTINGS", UI.ACCENT2, 32, Vector2(420, 84))
	settings.pressed.connect(func(): Nav.go("settings"))
	var buttons: Array = [play, settings]
	if not OS.has_feature("web") and not OS.has_feature("ios"):
		var quit := GlowButton.make("EXIT", UI.DANGER, 32, Vector2(420, 84))
		quit.pressed.connect(func():
			Save.save_data()
			get_tree().quit())
		buttons.append(quit)
	for b in buttons:
		right.add_child(b)

	# ---- Corners
	var w := Wallet.new()
	var ver := UI.label("v" + VERSION, 20, UI.TEXT_DIM, 400)
	ver.modulate.a = 0.6
	var stars := UI.label("%d / %d stars" % [Save.total_stars(), Save.LEVEL_COUNT * 3], 22, UI.TEXT_DIM, 500)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 36
	bottom.offset_right = -36
	bottom.offset_top = -80
	bottom.offset_bottom = -24
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 24)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bsp := Control.new()
	bsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(w)
	bottom.add_child(bsp)
	bottom.add_child(stars)
	bottom.add_child(ver)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ver.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Entrance animation
	var i := 0
	for b in buttons:
		b.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.15 + i * 0.1)
		tw.tween_property(b, "modulate:a", 1.0, 0.3)
		i += 1
	var pulse := create_tween().set_loops()
	_logo.pivot_offset = Vector2(280, 150)
	pulse.tween_property(_logo, "scale", Vector2(1.02, 1.02), 2.4).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_logo, "scale", Vector2(1.0, 1.0), 2.4).set_trans(Tween.TRANS_SINE)


func on_back() -> void:
	pass
