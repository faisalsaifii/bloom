extends Screen
## Settings: audio on/off + volume, screen shake, vibration, fullscreen, reset.


func _backdrop_colors() -> Dictionary:
	return Levels.theme(7)


func build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	content.add_child(col)
	col.add_child(make_header("Settings", UI.ACCENT2, true, false))

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)

	var panel := UI.panel(UI.ACCENT2)
	panel.custom_minimum_size = Vector2(900, 0)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 20)
	margin.add_child(rows)
	center.add_child(panel)

	_slider_row(rows, "Music", UI.ACCENT, Save.music_on, Save.music_vol,
		func(on): Save.music_on = on; Save.settings_changed_notify(),
		func(v): Save.music_vol = v; Save.settings_changed_notify())
	_slider_row(rows, "Sound effects", UI.ACCENT2, Save.sfx_on, Save.sfx_vol,
		func(on): Save.sfx_on = on; Save.settings_changed_notify(),
		func(v):
			Save.sfx_vol = v
			Save.settings_changed_notify()
			Sfx.play("coin_%d" % int(v * 5.0)))
	_toggle_row(rows, "Screen shake", Save.shake_on, func(on): Save.shake_on = on; Save.settings_changed_notify())
	if OS.has_feature("mobile"):
		_toggle_row(rows, "Vibration", Save.vibrate_on, func(on):
			Save.vibrate_on = on
			Save.settings_changed_notify()
			if on:
				Sfx.vibrate(40))
	if OS.has_feature("pc") and not OS.has_feature("web"):
		_toggle_row(rows, "Fullscreen", Save.fullscreen, func(on): Save.fullscreen = on; Save.settings_changed_notify())

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	rows.add_child(foot)
	var info := UI.label("Bloom v%s" % "1.0.0", 22, UI.TEXT_DIM, 400)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(info)
	var reset := GlowButton.make("Reset progress", UI.DANGER, 24, Vector2(260, 60))
	reset.pressed.connect(_confirm_reset)
	foot.add_child(reset)


func _row_label(text: String) -> Label:
	var l := UI.label(text, 32, UI.TEXT, 600)
	l.custom_minimum_size = Vector2(250, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _toggle_row(parent: Control, text: String, value: bool, cb: Callable) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 24)
	r.add_child(_row_label(text))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(sp)
	var sw := Switch.new(value, UI.ACCENT)
	sw.toggled.connect(cb)
	r.add_child(sw)
	parent.add_child(r)


func _slider_row(parent: Control, text: String, accent: Color, on: bool, vol: float, on_cb: Callable, vol_cb: Callable) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 24)
	r.add_child(_row_label(text))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = vol
	s.custom_minimum_size = Vector2(320, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.drag_ended.connect(func(changed: bool):
		if changed:
			vol_cb.call(s.value))
	s.value_changed.connect(func(v: float):
		if text == "Music":
			Save.music_vol = v
			Save.settings_changed.emit())
	r.add_child(s)
	var sw := Switch.new(on, accent)
	sw.toggled.connect(on_cb)
	r.add_child(sw)
	parent.add_child(r)


func _confirm_reset() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0.05, 0.7)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.add_child(c)
	var p := UI.panel(UI.DANGER)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 36)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	m.add_child(v)
	var t := UI.label("Erase all progress?", 40, UI.TEXT, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("Coins, characters and stars will be lost.", 26, UI.TEXT_DIM, 400)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	v.add_child(hb)
	var no := GlowButton.make("Keep", UI.ACCENT, 28, Vector2(220, 70))
	no.pressed.connect(veil.queue_free)
	var yes := GlowButton.make("Erase", UI.DANGER, 28, Vector2(220, 70))
	yes.pressed.connect(func():
		Save.reset_progress()
		Sfx.play("death", 1.0, -6.0)
		veil.queue_free())
	hb.add_child(no)
	hb.add_child(yes)
	c.add_child(p)


func on_back() -> void:
	Sfx.play("ui_back")
	Nav.go("menu")
