extends Node
## Entry scene. Autoloads (Save, Sfx, Nav) do the real work; this hosts the global glow environment.
## Debug builds only: BLOOM_SHOTS="menu|levels|game:5:2.5:right" + BLOOM_SHOT_DIR captures screenshots and quits.

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.043, 0.039, 0.125))
	var shots := OS.get_environment("BLOOM_SHOTS")
	if shots != "" and OS.is_debug_build():
		_run_shots.call_deferred(shots.split("|"))


func _run_shots(list: PackedStringArray) -> void:
	var dir := OS.get_environment("BLOOM_SHOT_DIR")
	if dir == "":
		dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.0).timeout
	var idx := 0
	for item in list:
		var p := item.split(":")
		var args := {}
		if p.size() > 1 and p[1] != "":
			args["level"] = int(p[1])
		Nav.busy = false
		Nav.go(p[0], args, true)
		var wait := float(p[2]) if p.size() > 2 else 1.2
		var act := p[3] if p.size() > 3 else ""
		await get_tree().create_timer(0.3).timeout
		if act != "":
			for a in act.split("+"):
				Input.action_press(a)
		await get_tree().create_timer(wait).timeout
		for a in act.split("+"):
			if a != "":
				Input.action_release(a)
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%02d_%s.png" % [dir, idx, p[0] + (p[1] if p.size() > 1 else "")])
		idx += 1
	get_tree().quit()
