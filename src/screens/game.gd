extends Screen
## Gameplay: renders the Sim, handles feedback (sound, particles, shake), HUD, pause and results.

const SPIKE_COLOR := Color(1.0, 0.27, 0.36)
const FLASH_COLOR := Color(1.0, 0.25, 0.35)
const ZOOM := 1.3

var level_n := 1
var lvl: Dictionary
var sim: Sim
var tm: Dictionary
var skin: Dictionary

var world: Node2D
var glow: Fx.GlowLayer
var hud: Control
var pause_btn: IconButton
var touch: TouchPad
var overlay: Control

var cam := Vector2(640, 420)
var shake := 0.0
var state := "play"          # play | dead | won
var paused := false
var dead_t := 0.0
var won_t := 0.0
var t := 0.0
var land_t := 0.0
var flash := 0.0
var coin_bump := 0.0
var toast_text := ""
var toast_t := 0.0
var ps := Fx.Particles.new()
var ground_y := 440.0
var platform_styles := {}
var result_shown := false
var _finish_emit := 0.0
var _hint: Label


func setup(args: Dictionary) -> void:
	level_n = clampi(int(args.get("level", 1)), 1, Save.LEVEL_COUNT)


func _backdrop_colors() -> Dictionary:
	return Levels.theme(level_n)


func build() -> void:
	Sfx.play_music("game")
	lvl = Levels.get_level(level_n)
	tm = lvl.theme
	skin = Skins.get_skin(Save.equipped)
	sim = Sim.new(lvl)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_styles()

	world = Node2D.new()
	world.draw.connect(_draw_world)
	add_child(world)
	glow = Fx.GlowLayer.new(_draw_glow)
	world.add_child(glow)

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)

	var m := safe_margins()
	pause_btn = IconButton.make_icon("pause", 68, tm.accent)
	pause_btn.position = Vector2(m.x, m.y)
	pause_btn.pressed.connect(toggle_pause)
	hud.add_child(pause_btn)

	touch = TouchPad.new()
	touch.visible = _touch_ui()
	touch.margins = m
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.accent = tm.accent
	hud.add_child(touch)

	cam = Vector2(sim.pos.x + 100.0, 420.0)
	ground_y = sim.pos.y
	_intro()
	modulate.a = 1.0


func _touch_ui() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _make_styles() -> void:
	var a: Color = tm.accent
	var a2: Color = tm.accent2
	platform_styles[Levels.Kind.STATIC] = _plat_style(a, 0.42)
	platform_styles[Levels.Kind.MOVER] = _plat_style(a2, 0.5)
	platform_styles[Levels.Kind.CRUMBLE] = _plat_style(Color(1.0, 0.66, 0.36), 0.45)


func _plat_style(c: Color, glow_a: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(c.r * 0.28, c.g * 0.28, c.b * 0.28, 0.96)
	s.border_color = c
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.shadow_color = Color(c.r, c.g, c.b, glow_a)
	s.shadow_size = 16
	s.anti_aliasing = true
	return s


func _intro() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var vs := get_viewport_rect().size
	box.position = Vector2(vs.x * 0.5 - 250, 130)
	box.custom_minimum_size = Vector2(500, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l1 := UI.label("LEVEL %d" % level_n, 72, Color.WHITE, 700)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l2 := UI.label("%s  ·  %s" % [Levels.difficulty_name(level_n), tm.name], 30, tm.accent, 500)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l1)
	box.add_child(l2)
	hud.add_child(box)
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.1)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)
	var hint := ""
	var ui_touch := _touch_ui()
	if level_n == 1:
		hint = "Use the on-screen buttons to run and jump" if ui_touch else "A / D or arrow keys to run  ·  Space to jump"
	elif level_n == 2:
		hint = "Avoid the red spikes - hold jump for higher hops"
	elif level_n == 5:
		hint = "Collect every coin for 2 stars - finish without dying for 3"
	elif level_n == 11:
		hint = "Moving platforms: time your jump"
	elif level_n == 26:
		hint = "Crumbling platforms fall after you land. Keep moving!"
	if hint != "":
		_hint = UI.label(hint, 28, UI.TEXT, 500)
		_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.size = Vector2(900, 40)
		_hint.position = Vector2(vs.x * 0.5 - 450, vs.y * 0.30)
		_hint.modulate.a = 0.0
		hud.add_child(_hint)
		var th := create_tween()
		th.tween_interval(1.4)
		th.tween_property(_hint, "modulate:a", 1.0, 0.5)
		th.tween_interval(5.0)
		th.tween_property(_hint, "modulate:a", 0.0, 0.8)


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	t += delta
	shake = maxf(0.0, shake - delta * 40.0)
	land_t = maxf(0.0, land_t - delta)
	flash = maxf(0.0, flash - delta * 2.5)
	coin_bump = maxf(0.0, coin_bump - delta * 5.0)
	toast_t = maxf(0.0, toast_t - delta)
	if not paused:
		match state:
			"play":
				var dir := Input.get_axis("left", "right")
				sim.advance(delta, dir, Input.is_action_pressed("jump"))
				if sim.alive and not sim.finished:
					Skins.emit_trail(ps, skin, sim.pos, sim.vel, t, delta)
			"dead":
				dead_t += delta
				if dead_t > 0.85:
					sim.respawn()
					state = "play"
			"won":
				won_t += delta
				if won_t > 1.0 and not result_shown:
					_show_results()
		_handle_events()
		ps.update(delta)
		_emit_ambient(delta)
	_update_camera(delta)
	var off := Vector2.ZERO
	if shake > 0.0 and Save.shake_on:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	world.scale = Vector2(ZOOM, ZOOM)
	world.position = (size * 0.5 - cam * ZOOM + off).round()
	backdrop.set_scroll(cam.x)
	world.queue_redraw()
	glow.queue_redraw()
	hud.queue_redraw()


func _update_camera(delta: float) -> void:
	var half := size * 0.5 / ZOOM
	var look := sim.facing * 90.0
	var tx := sim.pos.x + look
	tx = clampf(tx, half.x - 140.0, maxf(half.x - 140.0, float(lvl.length) - half.x + 220.0))
	if sim.on_ground:
		ground_y = lerpf(ground_y, sim.pos.y, minf(1.0, delta * 6.0))
	else:
		ground_y = lerpf(ground_y, minf(sim.pos.y, ground_y + 30.0) if sim.pos.y < ground_y else sim.pos.y - 30.0, minf(1.0, delta * 2.0))
	var ty := clampf(ground_y - 10.0, 330.0, 480.0)
	var k := minf(1.0, delta * 5.0)
	cam.x = lerpf(cam.x, tx, k)
	cam.y = lerpf(cam.y, ty, minf(1.0, delta * 3.0))


func _emit_ambient(delta: float) -> void:
	# sparkles near finish
	var fin: Vector2 = lvl.finish
	if absf(fin.x - cam.x) < size.x * 0.7:
		_finish_emit += delta
		if _finish_emit > 0.05:
			_finish_emit = 0.0
			ps.emit(fin + Vector2(randf_range(-26, 26), -randf_range(0, 40)), Vector2(randf_range(-12, 12), randf_range(-90, -40)),
				randf_range(0.8, 1.4), randf_range(2.0, 3.5), Color(0.7, 1.0, 0.85, 0.9), 0.3)


func _handle_events() -> void:
	for e in sim.drain_events():
		match e.type:
			"jump":
				Sfx.play("jump", randf_range(0.96, 1.06), -3.0)
				ps.burst(e.pos, 7, 120.0, 0.35, 3.0, Color(1, 1, 1, 0.55), PI)
				for p in ps.items.slice(-7):
					p["v"] = Vector2(p["v"].x, -absf(p["v"].y) * 0.3)
			"land":
				var sp: float = clampf(float(e.speed) / 900.0, 0.0, 1.0)
				Sfx.play("land", randf_range(0.95, 1.05), -10.0 + sp * 6.0)
				land_t = 0.12
				ps.burst(e.pos, 6 + int(sp * 8.0), 150.0, 0.4, 3.0, Color(1, 1, 1, 0.45))
				if sp > 0.6:
					shake = maxf(shake, 3.0)
			"coin":
				Sfx.coin(int(e.combo))
				ps.burst(e.pos, 14, 260.0, 0.6, 3.5, UI.GOLD)
				coin_bump = 1.0
				Sfx.vibrate(10)
			"crumble_start":
				Sfx.play("crumble", 1.2, -8.0)
			"crumble":
				Sfx.play("crumble", 0.9, -4.0)
				ps.burst(e.pos, 20, 220.0, 0.8, 4.0, Color(1.0, 0.66, 0.36))
				shake = maxf(shake, 4.0)
			"checkpoint":
				Sfx.play("star_1", 1.0, -4.0)
				ps.burst(e.pos + Vector2(0, -30), 26, 260.0, 0.8, 4.0, tm.accent)
				_toast("Checkpoint")
			"death":
				state = "dead"
				dead_t = 0.0
				Sfx.play("death")
				Sfx.vibrate(80)
				shake = 16.0
				flash = 0.6
				var c := Skins.main_color(skin, t)
				ps.burst(e.pos, 46, 520.0, 0.9, 6.0, c)
				ps.burst(e.pos, 20, 300.0, 1.1, 4.0, Color(1, 1, 1, 0.9))
			"respawn":
				ps.burst(sim.pos, 18, 220.0, 0.6, 3.5, tm.accent)
			"win":
				state = "won"
				won_t = 0.0
				Sfx.play("win")
				Sfx.vibrate(60)
				for i in 5:
					ps.burst(e.pos + Vector2(randf_range(-60, 60), -randf_range(20, 140)), 24, 420.0, 1.3, 5.0, Color.from_hsv(randf(), 0.7, 1.0))


func _toast(text: String) -> void:
	toast_text = text
	toast_t = 1.6


# ------------------------------------------------------------------ drawing
func _draw_world() -> void:
	var half := size * 0.5 / ZOOM
	var vis := Rect2(cam - half, size / ZOOM).grow(280.0)
	var spike_col := SPIKE_COLOR
	var accent: Color = tm.accent
	for i in sim.plats.size():
		var p: Dictionary = sim.plats[i]
		var r := sim.rect_of(i)
		var reach_x := float(p.amp) if (p.kind == Levels.Kind.MOVER and p.axis == 0) else 0.0
		if not vis.intersects(Rect2(r.position.x - reach_x, r.position.y - 160.0, r.size.x + reach_x * 2.0, 400.0)):
			continue
		var st: StyleBoxFlat = platform_styles[p.kind]
		var alpha := 1.0
		if p.kind == Levels.Kind.CRUMBLE and sim.pstate[i].cs == 2:
			alpha = clampf(1.0 - float(sim.pstate[i].fy) / 260.0, 0.0, 1.0)
			if alpha <= 0.0:
				continue
		if p.kind == Levels.Kind.MOVER:
			var tc := Color(tm.accent2.r, tm.accent2.g, tm.accent2.b, 0.16)
			if p.axis == 0:
				world.draw_line(Vector2(p.x - p.amp + 10, p.y + 11), Vector2(p.x + p.w + p.amp - 10, p.y + 11), tc, 3.0, true)
			else:
				world.draw_line(Vector2(p.x + p.w * 0.5, p.y - p.amp), Vector2(p.x + p.w * 0.5, p.y + p.amp + 22), tc, 3.0, true)
		world.modulate = Color(1, 1, 1, alpha)
		world.draw_style_box(st, r)
		if p.kind == Levels.Kind.CRUMBLE:
			var cc := Color(1.0, 0.75, 0.5, 0.55)
			var steps := int(r.size.x / 44.0)
			for k in steps:
				var cx := r.position.x + 22.0 + k * 44.0
				world.draw_line(Vector2(cx, r.position.y + 3), Vector2(cx + 5, r.position.y + 11), cc, 2.0, true)
				world.draw_line(Vector2(cx + 5, r.position.y + 11), Vector2(cx - 2, r.position.y + 19), cc, 2.0, true)
		elif p.kind == Levels.Kind.MOVER:
			var pc := Color(tm.accent2.r, tm.accent2.g, tm.accent2.b, 0.9)
			for sx in [r.position.x + 16.0, r.end.x - 16.0]:
				world.draw_circle(Vector2(sx, r.position.y + 11), 3.0, pc)
		world.modulate = Color.WHITE
		if not p.spikes.is_empty():
			for tri in sim.spike_triangles(i):
				world.draw_colored_polygon(tri, spike_col)
				var loop: PackedVector2Array = tri.duplicate()
				loop.append(tri[0])
				world.draw_polyline(loop, Color(1.0, 0.7, 0.72), 2.0, true)
		if p.cp:
			_draw_checkpoint(world, i, p)
	# coins
	for i in sim.coins.size():
		if sim.collected[i] == 1:
			continue
		var cp: Vector2 = sim.coins[i]
		if not vis.has_point(cp):
			continue
		var bob := sin(t * 3.0 + i * 0.7) * 3.0
		Icons.coin(world, cp + Vector2(0, bob), Sim.COIN_R, cos(t * 3.2 + i))
	_draw_finish(world)
	# player
	if state != "dead":
		var s := 1.0 + clampf(absf(sim.vel.y) / 2800.0, 0.0, 0.3)
		var sq := Vector2(1.0 / s, s)
		if land_t > 0.0:
			var k := land_t / 0.12
			sq = Vector2(1.0 + 0.25 * k, 1.0 - 0.25 * k)
		var look := clampf(sim.vel.x / Sim.SPEED, -1.0, 1.0)
		# soft shadow below
		Skins.draw(world, skin, sim.pos, Sim.R, sim.roll, t, false, look, sq)


func _draw_checkpoint(ci: CanvasItem, i: int, p: Dictionary) -> void:
	var on: bool = sim.reached_cp.has(i)
	var base := Vector2(p.x + p.w * 0.5, p.y)
	var col: Color = tm.accent if on else Color(1, 1, 1, 0.5)
	ci.draw_line(base, base + Vector2(0, -36), col, 3.0, true)
	var c := base + Vector2(0, -46.0 + sin(t * 2.5 + i) * 2.0)
	var pts := PackedVector2Array([c + Vector2(0, -12), c + Vector2(9, 0), c + Vector2(0, 12), c + Vector2(-9, 0)])
	ci.draw_colored_polygon(pts, col)


func _draw_finish(ci: CanvasItem) -> void:
	var fin: Vector2 = lvl.finish
	var pole_top := fin + Vector2(0, -120)
	ci.draw_line(fin, pole_top, Color(0.85, 1, 0.92), 5.0, true)
	var wave := sin(t * 4.0) * 5.0
	var flag := PackedVector2Array([pole_top + Vector2(0, 2), pole_top + Vector2(54, 16 + wave), pole_top + Vector2(0, 46)])
	ci.draw_colored_polygon(flag, Color("3dffa2"))
	ci.draw_circle(pole_top, 7.0, Color.WHITE)
	# ring portal at base
	ci.draw_arc(fin + Vector2(0, -3), 30.0, 0, TAU, 32, Color(0.6, 1, 0.85, 0.7), 3.0, true)


func _draw_glow(ci: Node2D) -> void:
	var half := size * 0.5 / ZOOM
	var vis := Rect2(cam - half, size / ZOOM).grow(280.0)
	var accent: Color = tm.accent
	for i in sim.plats.size():
		var p: Dictionary = sim.plats[i]
		var r := sim.rect_of(i)
		if not vis.intersects(r.grow(120.0)):
			continue
		var col: Color = accent
		if p.kind == Levels.Kind.MOVER:
			col = tm.accent2
		elif p.kind == Levels.Kind.CRUMBLE:
			col = Color(1.0, 0.66, 0.36)
		var a := 0.22
		if p.kind == Levels.Kind.CRUMBLE and sim.pstate[i].cs == 2:
			a *= clampf(1.0 - float(sim.pstate[i].fy) / 260.0, 0.0, 1.0)
		ci.draw_rect(Rect2(r.position.x + 4, r.position.y, r.size.x - 8, 3), Color(col.r, col.g, col.b, a * 2.2))
		Fx.halo(ci, Vector2(r.position.x + r.size.x * 0.5, r.position.y + 6), maxf(r.size.x * 0.62, 70.0), Color(col.r, col.g, col.b, a * 0.55))
		var tris: Array = sim.spike_triangles(i) if not p.spikes.is_empty() else []
		for tri in tris:
			var c: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
			Fx.halo(ci, c, 34.0 + 4.0 * sin(t * 5.0 + c.x), Color(SPIKE_COLOR.r, SPIKE_COLOR.g, SPIKE_COLOR.b, 0.5))
		if p.cp:
			var on: bool = sim.reached_cp.has(i)
			Fx.halo(ci, Vector2(p.x + p.w * 0.5, p.y - 46), 46.0, Color(col.r, col.g, col.b, 0.7 if on else 0.18))
	for i in sim.coins.size():
		if sim.collected[i] == 1:
			continue
		var cp: Vector2 = sim.coins[i]
		if vis.has_point(cp):
			Fx.halo(ci, cp + Vector2(0, sin(t * 3.0 + i * 0.7) * 3.0), 34.0, Color(1.0, 0.8, 0.2, 0.55))
	# finish beam
	var fin: Vector2 = lvl.finish
	if vis.has_point(fin):
		var pulse := 0.75 + 0.25 * sin(t * 3.0)
		for k in 6:
			var w := 70.0 - k * 10.0
			ci.draw_rect(Rect2(fin.x - w * 0.5, fin.y - 460.0, w, 460.0), Color(0.4, 1.0, 0.7, 0.025 * pulse))
		Fx.halo(ci, fin + Vector2(0, -4), 90.0, Color(0.4, 1.0, 0.7, 0.55 * pulse))
		Fx.halo(ci, fin + Vector2(0, -120), 40.0, Color(0.6, 1.0, 0.85, 0.6))
	ps.draw(ci)
	if state != "dead":
		var pulse2 := 1.0 + 0.06 * sin(t * 4.0)
		Skins.draw(ci, skin, sim.pos, Sim.R, 0.0, t, true, 0.0, Vector2.ONE, pulse2)


func _draw_hud() -> void:
	var m := safe_margins()
	# red flash on death
	if flash > 0.0:
		hud.draw_rect(Rect2(Vector2.ZERO, size), Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, flash * 0.35))
	# coin counter pill (top centre)
	var txt := "%d / %d" % [sim.coins_got, sim.total_coins()]
	var f := UI.font(700)
	var fs := 34
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pw := tw + 88.0
	var px := size.x * 0.5 - pw * 0.5
	var py := m.y
	var scale_k := 1.0 + 0.12 * coin_bump
	hud.draw_set_transform(Vector2(size.x * 0.5, py + 34.0), 0.0, Vector2(scale_k, scale_k))
	var sb := UI.glass(UI.GOLD, 34, 0.07, 0.45, 0.0)
	hud.draw_style_box(sb, Rect2(-pw * 0.5, -34.0, pw, 68.0))
	Fx.halo(hud, Vector2(-pw * 0.5 + 38.0, 0), 28.0, Color(1, 0.8, 0.2, 0.35))
	Icons.coin(hud, Vector2(-pw * 0.5 + 38.0, 0), 16.0)
	hud.draw_set_transform(Vector2(size.x * 0.5, py + 34.0), 0.0, Vector2(scale_k, scale_k))
	hud.draw_string(f, Vector2(-pw * 0.5 + 66.0, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# progress bar under the pill
	var bw := 380.0
	var bx := size.x * 0.5 - bw * 0.5
	var by := py + 84.0
	hud.draw_rect(Rect2(bx, by, bw, 6), Color(1, 1, 1, 0.14))
	var prog := clampf(sim.pos.x / float(lvl.length), 0.0, 1.0)
	hud.draw_rect(Rect2(bx, by, bw * prog, 6), tm.accent)
	Fx.halo(hud, Vector2(bx + bw * prog, by + 3), 16.0, Color(tm.accent.r, tm.accent.g, tm.accent.b, 0.8))
	hud.draw_circle(Vector2(bx + bw * prog, by + 3), 6.0, Color.WHITE)
	for i in sim.plats.size():
		if sim.plats[i].cp:
			var cx := bx + bw * clampf(float(sim.plats[i].x) / float(lvl.length), 0.0, 1.0)
			hud.draw_rect(Rect2(cx - 1.5, by - 4, 3, 14), Color(1, 1, 1, 0.5))
	# level tag top-right
	var tag := "LEVEL %d" % level_n
	var tf := UI.font(600)
	var ttw := tf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	hud.draw_string(tf, Vector2(size.x - m.z - ttw, m.y + 30), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.TEXT)
	var dn := Levels.difficulty_name(level_n)
	var dw := UI.font(500).get_string_size(dn, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	hud.draw_string(UI.font(500), Vector2(size.x - m.z - dw, m.y + 58), dn, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.level_color(level_n))
	if sim.deaths > 0:
		var dtxt := "x%d" % sim.deaths
		var dtw := UI.font(500).get_string_size(dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		hud.draw_string(UI.font(500), Vector2(size.x - m.z - dtw, m.y + 86), dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.DANGER)
	# toast
	if toast_t > 0.0:
		var a := clampf(toast_t / 0.4, 0.0, 1.0)
		var w2 := UI.font(600).get_string_size(toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		hud.draw_string(UI.font(600), Vector2(size.x * 0.5 - w2 * 0.5, py + 150.0 - (1.0 - a) * 10.0), toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(tm.accent.r, tm.accent.g, tm.accent.b, a))


# ------------------------------------------------------------------ pause & results
func _input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if state == "play" and not paused and is_inside_tree():
			toggle_pause()


func on_back() -> void:
	if state == "won":
		return
	toggle_pause()


func toggle_pause() -> void:
	if state == "won" or result_shown:
		return
	if paused:
		_close_overlay()
		paused = false
		Sfx.play("ui_back")
		return
	paused = true
	Sfx.play("ui_click")
	Input.action_release("left")
	Input.action_release("right")
	Input.action_release("jump")
	_open_pause()


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _make_overlay(accent: Color, width := 560) -> VBoxContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.08, 0.72)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(c)
	var p := UI.panel(accent, 34)
	p.custom_minimum_size = Vector2(width, 0)
	c.add_child(p)
	var mg := MarginContainer.new()
	for s in ["left", "right"]:
		mg.add_theme_constant_override("margin_" + s, 40)
	for s in ["top", "bottom"]:
		mg.add_theme_constant_override("margin_" + s, 32)
	p.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	mg.add_child(v)
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.18)
	p.pivot_offset = Vector2(width * 0.5, 160)
	p.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v


func _open_pause() -> void:
	var v := _make_overlay(tm.accent)
	var title := UI.label("Paused", 56, UI.TEXT, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var resume := GlowButton.make("Resume", tm.accent, 36, Vector2(0, 86))
	resume.pressed.connect(toggle_pause)
	v.add_child(resume)
	var restart := GlowButton.make("Restart", UI.ACCENT2, 30, Vector2(0, 72))
	restart.pressed.connect(func(): Nav.go("game", {"level": level_n}))
	v.add_child(restart)
	var levels := GlowButton.make("Level select", Color("8a8fb0"), 30, Vector2(0, 72))
	levels.pressed.connect(_to_levels)
	v.add_child(levels)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	row.add_child(UI.label("Music", 26, UI.TEXT_DIM, 500))
	var sm := Switch.new(Save.music_on, UI.ACCENT)
	sm.scale = Vector2(0.8, 0.8)
	sm.toggled.connect(func(on): Save.music_on = on; Save.settings_changed_notify())
	row.add_child(sm)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(30, 0)
	row.add_child(gap)
	row.add_child(UI.label("Sound", 26, UI.TEXT_DIM, 500))
	var ss := Switch.new(Save.sfx_on, UI.ACCENT)
	ss.scale = Vector2(0.8, 0.8)
	ss.toggled.connect(func(on): Save.sfx_on = on; Save.settings_changed_notify())
	row.add_child(ss)


func _to_levels() -> void:
	Nav.last_page = (level_n - 1) / 20
	Nav.go("levels")


func _show_results() -> void:
	result_shown = true
	var res := Save.complete_level(level_n, sim.coins_got, sim.total_coins(), sim.deaths, sim.run_time)
	var v := _make_overlay(UI.GOLD, 720)
	var title := UI.label("Level Complete!", 56, UI.TEXT, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	# Stars
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(0, 130)
	v.add_child(stars)
	var star_nodes: Array = []
	for i in 3:
		var sn := Control.new()
		sn.size = Vector2(120, 120)
		sn.position = Vector2(720 - 80 - 40 - 120 * 1.5 + 0, 0)
		sn.set_meta("i", i)
		var earned: bool = i < int(res.stars)
		sn.draw.connect(func():
			var c := Vector2(60, 60)
			if earned:
				Fx.halo(sn, c, 90.0, Color(1, 0.85, 0.3, 0.55))
			Icons.star(sn, c, 48.0, UI.GOLD if earned else Color(1, 1, 1, 0.3), earned))
		stars.add_child(sn)
		star_nodes.append(sn)
	stars.resized.connect(func():
		for i in star_nodes.size():
			var sn: Control = star_nodes[i]
			sn.position = Vector2(stars.size.x * 0.5 + (i - 1) * 140.0 - 60.0, 4.0 - (18.0 if i == 1 else 0.0))
			sn.pivot_offset = Vector2(60, 60))
	var seq := create_tween()
	seq.tween_interval(0.45)
	for i in 3:
		var sn: Control = star_nodes[i]
		sn.scale = Vector2.ZERO
		var earned: bool = i < int(res.stars)
		seq.tween_callback(func():
			if earned:
				Sfx.play("star_%d" % i, 1.0, 0.0)
			else:
				Sfx.play("ui_hover", 0.7))
		seq.tween_property(sn, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK)
		seq.tween_property(sn, "scale", Vector2.ONE, 0.12)
		seq.tween_interval(0.12)
	# Stats
	var stats := UI.label("Coins  %d / %d    ·    Deaths  %d    ·    %s" % [sim.coins_got, sim.total_coins(), sim.deaths, _fmt_time(sim.run_time)], 26, UI.TEXT_DIM, 500)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	var earned_row := HBoxContainer.new()
	earned_row.alignment = BoxContainer.ALIGNMENT_CENTER
	earned_row.add_theme_constant_override("separation", 12)
	var coin_icon := Control.new()
	coin_icon.custom_minimum_size = Vector2(40, 40)
	coin_icon.draw.connect(func():
		Fx.halo(coin_icon, Vector2(20, 20), 30.0, Color(1, 0.8, 0.2, 0.4))
		Icons.coin(coin_icon, Vector2(20, 20), 18.0))
	earned_row.add_child(coin_icon)
	var earned_lbl := UI.label("+0", 46, UI.GOLD, 700)
	earned_row.add_child(earned_lbl)
	if res.bonus > 0:
		earned_row.add_child(UI.label("(%d bonus)" % res.bonus, 24, UI.TEXT_DIM, 400))
	v.add_child(earned_row)
	var ct := create_tween()
	ct.tween_interval(1.0)
	ct.tween_method(func(x: float): earned_lbl.text = "+%d" % int(round(x)), 0.0, float(res.coins_earned), 0.7)
	# Buttons
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var home := IconButton.make_icon("home", 84, Color("8a8fb0"))
	home.pressed.connect(_to_levels)
	row.add_child(home)
	var again := IconButton.make_icon("restart", 84, UI.ACCENT2)
	again.pressed.connect(func(): Nav.go("game", {"level": level_n}))
	row.add_child(again)
	if level_n < Save.LEVEL_COUNT:
		var nxt := GlowButton.make("Next level", UI.ACCENT, 34, Vector2(300, 84))
		nxt.pressed.connect(func(): Nav.go("game", {"level": level_n + 1}))
		row.add_child(nxt)
	else:
		var done := GlowButton.make("You did it!", UI.GOLD, 32, Vector2(300, 84))
		done.pressed.connect(_to_levels)
		row.add_child(done)


func _fmt_time(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


## Multi-touch on-screen controls (left / right / jump). Drives the shared input actions.
class TouchPad extends Control:
	var margins := Vector4(36, 28, 36, 28)
	var accent := UI.ACCENT
	var touches := {}   # finger index -> action

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _centers() -> Dictionary:
		var by := size.y - margins.w - 100.0
		return {
			"left": Vector2(margins.x + 90.0, by),
			"right": Vector2(margins.x + 290.0, by),
			"jump": Vector2(size.x - margins.z - 130.0, by - 20.0),
		}

	func _radius(a: String) -> float:
		return 112.0 if a == "jump" else 84.0

	func _hit(p: Vector2) -> String:
		var cs := _centers()
		var best := ""
		var bd := 1e9
		for a in cs:
			var d := p.distance_to(cs[a])
			if d < _radius(a) * 1.25 and d < bd:
				best = a
				bd = d
		return best

	func _set_touch(idx: int, action: String) -> void:
		var old: String = touches.get(idx, "")
		if old == action:
			return
		if old != "":
			Input.action_release(old)
		if action == "":
			touches.erase(idx)
		else:
			touches[idx] = action
			Input.action_press(action)
		queue_redraw()

	func _input(e: InputEvent) -> void:
		if not visible:
			return
		if e is InputEventScreenTouch:
			if e.pressed:
				_set_touch(e.index, _hit(e.position))
			else:
				_set_touch(e.index, "")
		elif e is InputEventScreenDrag:
			_set_touch(e.index, _hit(e.position))

	func _draw() -> void:
		var cs := _centers()
		var active := touches.values()
		for a in cs:
			var on := active.has(a)
			var r := _radius(a)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(accent.r, accent.g, accent.b, 0.34 if on else 0.12)
			sb.border_color = Color(accent.r, accent.g, accent.b, 0.95 if on else 0.55)
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(int(r))
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.45 if on else 0.2)
			sb.shadow_size = 16 if on else 8
			sb.anti_aliasing = true
			var rr := r * (0.94 if on else 1.0)
			draw_style_box(sb, Rect2(cs[a] - Vector2(rr, rr), Vector2(rr, rr) * 2.0))
			match a:
				"left": Icons.chevron(self, cs[a] + Vector2(-6, 0), 24.0, -1.0, Color.WHITE, 8.0)
				"right": Icons.chevron(self, cs[a] + Vector2(6, 0), 24.0, 1.0, Color.WHITE, 8.0)
				"jump": _up(cs[a])

	func _up(c: Vector2) -> void:
		draw_polyline(PackedVector2Array([c + Vector2(-30, 14), c + Vector2(0, -16), c + Vector2(30, 14)]), Color.WHITE, 9.0, true)
