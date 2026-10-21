class_name Wallet
extends PanelContainer
## Coin balance pill that counts up/down when the balance changes.

var _label: Label
var _shown := 0.0
var _icon: Control
var _tween: Tween


func _init() -> void:
	add_theme_stylebox_override("panel", _style())
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(34, 34)
	_icon.draw.connect(func():
		Fx.halo(_icon, Vector2(17, 17), 26.0, Color(1, 0.8, 0.2, 0.35))
		Icons.coin(_icon, Vector2(17, 17), 15.0))
	box.add_child(_icon)
	_label = UI.label("0", 30, UI.TEXT, 700)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_label)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_shown = Save.coins
	_label.text = str(Save.coins)
	Save.coins_changed.connect(_on_changed)
	pivot_offset = size * 0.5


func _style() -> StyleBoxFlat:
	var s := UI.glass(UI.GOLD, 30, 0.07, 0.4)
	s.content_margin_left = 18
	s.content_margin_right = 24
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _on_changed() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float):
		_shown = v
		_label.text = str(int(round(v))), _shown, float(Save.coins), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pivot_offset = size * 0.5
	var t2 := create_tween()
	t2.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	t2.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func flash_insufficient() -> void:
	var t := create_tween()
	for i in 3:
		t.tween_property(self, "modulate", Color(1, 0.35, 0.4), 0.07)
		t.tween_property(self, "modulate", Color.WHITE, 0.07)
