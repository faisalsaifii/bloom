extends Node
## Screen navigation with a glowing transition, shared input map and theme.

const SCREENS := {
	"splash": preload("res://src/screens/splash.gd"),
	"menu": preload("res://src/screens/main_menu.gd"),
	"levels": preload("res://src/screens/level_select.gd"),
	"game": preload("res://src/screens/game.gd"),
	"shop": preload("res://src/screens/shop.gd"),
	"settings": preload("res://src/screens/settings.gd"),
}

var current: Control
var current_name := ""
var busy := false
var level_to_play := 1
var last_page := -1

var _holder: Control
var _veil: Control
var _veil_alpha := 0.0
var _root_theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_root_theme = UI.make_theme()
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.theme = _root_theme
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_holder)
	var vl := CanvasLayer.new()
	vl.layer = 100
	add_child(vl)
	_veil = Control.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.draw.connect(_draw_veil)
	_veil.visible = false
	vl.add_child(_veil)
	get_window().title = "Bloom"
	apply_display()
	Save.settings_changed.connect(apply_display)
	go("splash", {}, true)


func apply_display() -> void:
	if OS.has_feature("pc") and not OS.has_feature("web"):
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if Save.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)


func _setup_input() -> void:
	_action("left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_action("right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_action("jump", [KEY_SPACE, KEY_W, KEY_UP, KEY_Z], [JOY_BUTTON_A, JOY_BUTTON_B])
	_action("pause", [KEY_P], [JOY_BUTTON_START])
	for ax in [[JOY_AXIS_LEFT_X, -1.0, "left"], [JOY_AXIS_LEFT_X, 1.0, "right"]]:
		var e := InputEventJoypadMotion.new()
		e.axis = ax[0]
		e.axis_value = ax[1]
		InputMap.action_add_event(ax[2], e)


func _action(act: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(act):
		InputMap.add_action(act, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(act, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(act, e)


func go(screen: String, args := {}, instant := false) -> void:
	if busy:
		return
	busy = true
	if not instant:
		Sfx.play("whoosh", 1.0, -6.0)
		_veil.visible = true
		var t := create_tween()
		t.tween_method(_set_veil, 0.0, 1.0, 0.22)
		await t.finished
	if current:
		current.queue_free()
		current = null
	var s: Control = SCREENS[screen].new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	if s.has_method("setup"):
		s.setup(args)
	_holder.add_child(s)
	current = s
	current_name = screen
	if not instant:
		var t2 := create_tween()
		t2.tween_method(_set_veil, 1.0, 0.0, 0.3)
		await t2.finished
		_veil.visible = false
	busy = false


func _set_veil(v: float) -> void:
	_veil_alpha = v
	_veil.queue_redraw()


func _draw_veil() -> void:
	var sz := _veil.size
	_veil.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.03, 0.1, _veil_alpha))
	var c := sz * 0.5
	var t := Time.get_ticks_msec() / 1000.0
	for i in 6:
		var a := t * 2.5 + i * TAU / 6
		var p := c + Vector2(cos(a), sin(a)) * 26.0 * _veil_alpha
		var col := Color.from_hsv(i / 6.0, 0.6, 1.0, _veil_alpha)
		Fx.halo(_veil, p, 34.0, Color(col.r, col.g, col.b, col.a * 0.8))
		_veil.draw_circle(p, 5.0, col)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current and current.has_method("on_back") and not busy:
		current.on_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and current and current.has_method("on_back") and not busy:
		current.on_back()
