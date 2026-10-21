extends Node
## All audio: sound effects pool, music with cross-fade, bus volumes tied to settings.

const DIR := "res://assets/audio/"
const SFX_NAMES := [
	"jump", "land", "death", "win", "buy", "whoosh", "crumble", "bounce",
	"ui_click", "ui_hover", "ui_back", "ui_locked", "ui_toggle",
	"coin_0", "coin_1", "coin_2", "coin_3", "coin_4", "coin_5",
	"star_0", "star_1", "star_2",
]
const POOL := 12

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _fade: Tween
var _last_hover := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for n in SFX_NAMES:
		_streams[n] = load(DIR + n + ".wav")
	for m in ["menu", "game"]:
		var s: AudioStreamWAV = load(DIR + "music_%s.wav" % m)
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 4  # 16-bit stereo => 4 bytes per frame
		_music[m] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	Save.settings_changed.connect(apply_settings)
	apply_settings()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


func apply_settings() -> void:
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(mi, not Save.music_on)
	AudioServer.set_bus_mute(si, not Save.sfx_on)
	AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(Save.music_vol, 0.0001)) - 6.0)
	AudioServer.set_bus_volume_db(si, linear_to_db(maxf(Save.sfx_vol, 0.0001)))


func play(sfx_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	var s: AudioStream = _streams.get(sfx_name)
	if s == null or not Save.sfx_on:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func coin(combo: int) -> void:
	play("coin_%d" % clampi(combo, 0, 5), 1.0, -2.0)


func hover() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hover > 0.04:
		_last_hover = now
		play("ui_hover", randf_range(0.97, 1.03), -4.0)


func click() -> void:
	play("ui_click")


func play_music(track: String, fade := 1.2) -> void:
	if track == _current_music:
		return
	_current_music = track
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -40.0 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	incoming.stream = _music[track]
	incoming.volume_db = -60.0
	incoming.play()
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming, "volume_db", -3.0, fade)
	_fade.tween_property(outgoing, "volume_db", -60.0, fade)
	_fade.chain().tween_callback(outgoing.stop)


func duck(amount_db: float, time := 0.3) -> void:
	var p := _music_a if _music_a.volume_db > _music_b.volume_db else _music_b
	create_tween().tween_property(p, "volume_db", -3.0 + amount_db, time)


func vibrate(ms: int) -> void:
	if Save.vibrate_on and (OS.has_feature("android") or OS.has_feature("ios")):
		Input.vibrate_handheld(ms)
