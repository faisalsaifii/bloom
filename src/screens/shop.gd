extends Screen
## Character shop: spend coins on new glowing characters.

var _selected := ""
var _preview: SkinView
var _name: Label
var _tag: Label
var _action: GlowButton
var _cards := {}
var _wallet: Wallet
var _burst := Fx.Particles.new()
var _fx: Fx.GlowLayer


func _backdrop_colors() -> Dictionary:
	return Levels.theme(8)


func build() -> void:
	_selected = Save.equipped
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	content.add_child(col)
	var header := make_header("Characters", UI.ACCENT2, true, true)
	_wallet = header.get_child(header.get_child_count() - 1)
	col.add_child(header)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)

	# Left: big preview
	var left := UI.panel(UI.ACCENT2, 32)
	left.custom_minimum_size = Vector2(360, 0)
	row.add_child(left)
	var lm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		lm.add_theme_constant_override("margin_" + s, 22)
	left.add_child(lm)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lm.add_child(lv)
	_preview = SkinView.new(_selected, 56.0, true)
	_preview.custom_minimum_size = Vector2(300, 250)
	lv.add_child(_preview)
	_name = UI.label("", 44, UI.TEXT, 700)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(_name)
	_tag = UI.label("", 24, UI.TEXT_DIM, 400)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_tag)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp)
	_action = GlowButton.make("", UI.ACCENT, 30, Vector2(300, 80))
	_action.pressed.connect(_on_action)
	lv.add_child(_action)

	# Right: grid of characters
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for s in Skins.LIST:
		var card := SkinCard.new(s.id)
		card.pressed.connect(_select.bind(s.id))
		grid.add_child(card)
		_cards[s.id] = card

	_fx = Fx.GlowLayer.new(func(ci): _burst.draw(ci))
	add_child(_fx)
	_select(_selected, true)


func _process(delta: float) -> void:
	_burst.update(delta)
	if _fx:
		_fx.queue_redraw()


func _select(id: String, silent := false) -> void:
	_selected = id
	var s := Skins.get_skin(id)
	_preview.set_skin(id)
	_preview.locked = false
	_name.text = s.name
	_tag.text = s.tag
	for k in _cards:
		_cards[k].selected = k == id
		_cards[k].queue_redraw()
	_refresh_action()


func _refresh_action() -> void:
	var s := Skins.get_skin(_selected)
	var owned := Save.owns(_selected)
	if owned and Save.equipped == _selected:
		_action.text = "Equipped"
		_action.disabled = true
		_action.set_accent(UI.ACCENT)
	elif owned:
		_action.text = "Equip"
		_action.disabled = false
		_action.set_accent(UI.ACCENT)
	else:
		_action.text = "Buy  ·  %d" % s.price
		_action.disabled = false
		_action.set_accent(UI.GOLD if Save.coins >= s.price else Color("8a8fb0"))
	for k in _cards:
		_cards[k].queue_redraw()


func _on_action() -> void:
	var s := Skins.get_skin(_selected)
	if Save.owns(_selected):
		Save.equip(_selected)
		Sfx.play("ui_toggle", 1.2)
	elif Save.coins >= s.price:
		Save.buy(_selected, s.price)
		Save.equip(_selected)
		Sfx.play("buy")
		Sfx.vibrate(40)
		var c := _preview.global_position + _preview.size * 0.5
		_burst.burst(c, 60, 420.0, 0.9, 6.0, Skins.main_color(s, 0.0))
		_burst.burst(c, 30, 300.0, 1.1, 4.0, Color(1, 0.9, 0.5))
	else:
		Sfx.play("ui_locked")
		_wallet.flash_insufficient()
	_refresh_action()


func on_back() -> void:
	Sfx.play("ui_back")
	Nav.go("levels")


## Grid tile for one character.
class SkinCard extends GlowButton:
	var skin_id := ""
	var selected := false
	var view: SkinView

	func _init(id: String) -> void:
		skin_id = id
		var s := Skins.get_skin(id)
		accent = s.c1 if s.shape != "nova" else Color("ff4fd8")
		corner = 24
		custom_minimum_size = Vector2(182, 218)
		view = SkinView.new(id, 30.0, false)
		view.position = Vector2(41, 18)
		view.size = Vector2(100, 100)
		add_child(view)

	func _ready() -> void:
		super._ready()
		add_theme_stylebox_override("normal", _style(0.08, 0.65, 0.16, 10))
		view.locked = not Save.owns(skin_id)

	func _draw() -> void:
		view.locked = not Save.owns(skin_id)
		var s := Skins.get_skin(skin_id)
		var f := UI.font(700)
		var w := f.get_string_size(s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(f, Vector2(size.x * 0.5 - w * 0.5, 156), s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE if Save.owns(skin_id) else UI.TEXT_DIM)
		var cy := 191.0
		if Save.equipped == skin_id:
			Icons.check(self, Vector2(size.x * 0.5 - 38, cy), 8.0, UI.ACCENT, 4.0)
			draw_string(UI.font(600), Vector2(size.x * 0.5 - 22, cy + 8), "Equipped", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.ACCENT)
		elif Save.owns(skin_id):
			var t := "Owned"
			var tw := UI.font(500).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(UI.font(500), Vector2(size.x * 0.5 - tw * 0.5, cy + 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.TEXT_DIM)
		else:
			var price := str(s.price)
			var pw := UI.font(700).get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			var x0 := size.x * 0.5 - (pw + 30.0) * 0.5
			Icons.coin(self, Vector2(x0 + 11, cy), 11.0)
			draw_string(UI.font(700), Vector2(x0 + 30, cy + 8), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.GOLD)
		if selected:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_corner_radius_all(corner)
			sb.set_border_width_all(3)
			sb.border_color = Color.WHITE
			sb.anti_aliasing = true
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
