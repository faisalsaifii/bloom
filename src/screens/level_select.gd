extends Screen
## Level select: 100 levels in swipeable pages, colour-coded by difficulty.

const PER_PAGE := 20
const COLS := 5
const PAGES := 5

var _page := 0
var _row: Control
var _clip: Control
var _dots: HBoxContainer
var _swiped_at := -1.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _prev: IconButton
var _next: IconButton
var _tween: Tween
var _cards: Array = []


func _backdrop_colors() -> Dictionary:
	return Levels.theme(maxi(1, mini(Save.unlocked_to, 100)))


func build() -> void:
	Sfx.play_music("menu")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	content.add_child(col)

	var header := make_header("Select Level")
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 8)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var star_icon := Control.new()
	star_icon.custom_minimum_size = Vector2(34, 34)
	star_icon.draw.connect(func(): Icons.star(star_icon, Vector2(17, 17), 15.0, UI.GOLD))
	stars.add_child(star_icon)
	stars.add_child(UI.label("%d/%d" % [Save.total_stars(), Save.LEVEL_COUNT * 3], 28, UI.TEXT, 600))
	header.add_child(stars)
	header.move_child(stars, header.get_child_count() - 2)
	var shop := GlowButton.make("Characters", UI.ACCENT2, 26, Vector2(220, 64))
	shop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop.pressed.connect(func():
		Nav.last_page = _page
		Nav.go("shop"))
	header.add_child(shop)
	header.move_child(shop, header.get_child_count() - 2)
	col.add_child(header)

	# Page area
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip.resized.connect(_layout_pages)
	col.add_child(_clip)
	_row = Control.new()
	_clip.add_child(_row)
	for p in PAGES:
		_row.add_child(_make_page(p))

	# Footer: dots + arrows
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 26)
	_prev = IconButton.make_icon("back", 60, UI.ACCENT)
	_prev.pressed.connect(func(): _go_page(_page - 1))
	_next = IconButton.make_icon("next", 60, UI.ACCENT)
	_next.pressed.connect(func(): _go_page(_page + 1))
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 12)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_prev)
	foot.add_child(_dots)
	foot.add_child(_next)
	col.add_child(foot)
	for i in PAGES:
		var d := Control.new()
		d.custom_minimum_size = Vector2(14, 14)
		d.set_meta("i", i)
		d.draw.connect(_draw_dot.bind(d))
		_dots.add_child(d)

	var start_page := clampi((Save.unlocked_to - 1) / PER_PAGE, 0, PAGES - 1)
	if Nav.last_page >= 0:
		start_page = Nav.last_page
		Nav.last_page = -1
	_page = start_page
	_layout_pages.call_deferred()
	_update_footer()


func _make_page(p: int) -> Control:
	var page := Control.new()
	page.set_meta("page", p)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(grid)
	for i in PER_PAGE:
		var n := p * PER_PAGE + i + 1
		var card := LevelCard.new(n)
		card.pressed.connect(_on_card.bind(n))
		grid.add_child(card)
		_cards.append(card)
	return page


func _layout_pages() -> void:
	var w := _clip.size.x
	var h := _clip.size.y
	if w <= 0.0:
		return
	var pad := 12.0
	for page in _row.get_children():
		var p: int = page.get_meta("page")
		page.position = Vector2(p * w, 0)
		page.size = Vector2(w, h)
		var grid: GridContainer = page.get_child(0)
		grid.position = Vector2(pad, 6)
		grid.size = Vector2(w - pad * 2, h - 12)
		var rows := PER_PAGE / COLS
		var cw := (grid.size.x - 22.0 * (COLS - 1)) / COLS
		var ch := (grid.size.y - 22.0 * (rows - 1)) / rows
		for c in grid.get_children():
			c.custom_minimum_size = Vector2(cw, ch)
	_row.position.x = -_page * w


func _go_page(p: int, silent := false) -> void:
	p = clampi(p, 0, PAGES - 1)
	if p == _page:
		return
	_page = p
	if not silent:
		Sfx.play("ui_toggle", 1.1)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_row, "position:x", -_page * _clip.size.x, 0.35)
	_update_footer()


func _update_footer() -> void:
	_prev.disabled = _page == 0
	_next.disabled = _page == PAGES - 1
	_prev.modulate.a = 0.35 if _prev.disabled else 1.0
	_next.modulate.a = 0.35 if _next.disabled else 1.0
	for d in _dots.get_children():
		d.queue_redraw()


func _draw_dot(d: Control) -> void:
	var on: bool = d.get_meta("i") == _page
	var c := UI.ACCENT if on else Color(1, 1, 1, 0.25)
	if on:
		Fx.halo(d, Vector2(7, 7), 18.0, Color(c.r, c.g, c.b, 0.6))
	d.draw_circle(Vector2(7, 7), 7.0 if on else 5.0, c)


func _on_card(n: int) -> void:
	if Time.get_ticks_msec() / 1000.0 - _swiped_at < 0.25:
		return
	if not Save.is_unlocked(n):
		Sfx.play("ui_locked")
		var t := create_tween()
		var card: Control = _cards[n - 1]
		var x0 := card.position.x
		for i in 3:
			t.tween_property(card, "position:x", x0 + 8, 0.04)
			t.tween_property(card, "position:x", x0 - 8, 0.04)
		t.tween_property(card, "position:x", x0, 0.04)
		return
	Nav.last_page = _page
	Nav.level_to_play = n
	Nav.go("game", {"level": n})


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press_pos = e.position
			_pressing = true
		elif _pressing:
			_pressing = false
			var d: Vector2 = e.position - _press_pos
			if absf(d.x) > 110.0 and absf(d.x) > absf(d.y) * 1.5:
				_swiped_at = Time.get_ticks_msec() / 1000.0
				_go_page(_page + (-1 if d.x > 0 else 1))
	elif e is InputEventKey and e.pressed:
		if e.keycode == KEY_RIGHT or e.keycode == KEY_D:
			_go_page(_page + 1)
		elif e.keycode == KEY_LEFT or e.keycode == KEY_A:
			_go_page(_page - 1)


func on_back() -> void:
	Sfx.play("ui_back")
	Nav.go("menu")


## One level tile.
class LevelCard extends GlowButton:
	var level := 1
	var unlocked := true

	func _init(n: int) -> void:
		level = n
		accent = UI.level_color(n)
		corner = 24
		unlocked = Save.is_unlocked(n)
		custom_minimum_size = Vector2(120, 70)
		muted = not unlocked

	func _ready() -> void:
		super._ready()
		if not unlocked:
			add_theme_stylebox_override("normal", _style(0.04, 0.22, 0.0, 0))
			add_theme_stylebox_override("hover", _style(0.06, 0.35, 0.0, 0))

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var col := accent if unlocked else Color(1, 1, 1, 0.35)
		var f := UI.font(700)
		var txt := str(level)
		var fs := 46
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if unlocked:
			draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
			var st := Save.stars_of(level)
			for i in 3:
				Icons.star(self, Vector2(size.x * 0.5 + (i - 1) * 34.0, size.y - 24.0), 11.0, UI.GOLD if i < st else Color(1, 1, 1, 0.35), i < st)
		else:
			draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.34 - 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.3))
			Icons.lock(self, Vector2(size.x * 0.5, size.y - 28.0), 11.0, Color(1, 1, 1, 0.4))
		if unlocked and level == Save.unlocked_to and Save.stars_of(level) == 0:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
			Fx.halo(self, Vector2(size.x - 18, 18), 18.0, Color(col.r, col.g, col.b, 0.6 * pulse))
			draw_circle(Vector2(size.x - 18, 18), 6.0, col)
			queue_redraw()
