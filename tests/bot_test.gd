extends SceneTree
## Headless sanity test: a look-ahead bot tries to beat the levels using the real simulation.
## Run: godot --headless --path . --script tests/bot_test.gd
## Env: BLOOM_LEVELS=<step> test every Nth level, BLOOM_DEBUG=1 prints deaths.

const DT := 1.0 / 60.0


func _init() -> void:
	var failed := []
	var only := OS.get_environment("BLOOM_LEVELS")
	var step := int(only) if only != "" else 1
	for n in range(1, 101, step):
		var lvl := Levels.get_level(n)
		var res := _run_bot(lvl)
		if not res.ok:
			failed.append(n)
		print("L%03d plats=%2d coins=%2d len=%5d %s deaths=%d time=%.0f" % [n, lvl.platforms.size(), lvl.coins.size(), int(lvl.length), "OK  " if res.ok else "FAIL", res.deaths, res.time])
	print("FAILED levels: ", failed)
	quit(1 if failed.size() > 0 else 0)


func _run_bot(lvl: Dictionary) -> Dictionary:
	var sim := Sim.new(lvl)
	var bot := Bot.new()
	var t := 0.0
	var respawn_wait := 0.0
	var stuck_x := 0.0
	var stuck_t := 0.0
	while t < 150.0 and not sim.finished:
		t += DT
		if not sim.alive:
			respawn_wait += DT
			if respawn_wait > 0.2:
				sim.respawn()
				respawn_wait = 0.0
				bot.reset()
			continue
		var d := bot.decide(sim)
		sim.advance(DT, d.x, d.y > 0.5)
		for ev in sim.drain_events():
			if ev.type == "death" and OS.get_environment("BLOOM_DEBUG") != "":
				print("  death L%d at x=%d y=%d" % [lvl.n, ev.pos.x, ev.pos.y])
		if absf(sim.pos.x - stuck_x) > 40.0:
			stuck_x = sim.pos.x
			stuck_t = 0.0
		else:
			stuck_t += DT
			if stuck_t > 25.0:
				break
	return {"ok": sim.finished, "deaths": sim.deaths, "time": t}
