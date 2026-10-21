extends SceneTree
## Headless sanity test: a look-ahead bot tries to beat the levels using the real simulation.
## Run: godot --headless --path . --script tests/bot_test.gd
## Env: BLOOM_LEVELS=<step> test every Nth level, BLOOM_DEBUG=1 prints deaths.

const DT := 1.0 / 60.0


func _init() -> void:
	var failed := []
	var coin_total := 0
	var only := OS.get_environment("BLOOM_LEVELS")
	var step := int(only) if only != "" else 1
	for n in range(1, 101, step):
		var lvl := Levels.get_level(n)
		coin_total += lvl.coins.size()
		var res := _run_bot(lvl)
		if not res.ok:
			failed.append(n)
		print("L%03d plats=%2d coins=%2d len=%5d %s deaths=%d time=%.0f" % [n, lvl.platforms.size(), lvl.coins.size(), int(lvl.length), "OK  " if res.ok else "FAIL", res.deaths, res.time])
	print("FAILED levels: ", failed)
	quit(1 if failed.size() > 0 else 0)


## Simulate `hold` seconds of jump then release, running right, until landing / death. Returns score.
func _rollout_jump(sim: Sim, hold: float) -> float:
	var s := sim.clone()
	var t := 0.0
	var airborne := false
	while t < 1.8:
		s.advance(DT, 1.0, t < hold)
		t += DT
		if not s.alive:
			return -1.0
		if s.finished:
			return 5000.0
		if not s.on_ground:
			airborne = true
		elif airborne:
			# Landed. Penalise landing right into a spike (checked a bit further).
			var ok := _survives_run(s, 0.2)
			return s.pos.x + (0.0 if ok else -800.0)
		if s.pos.y > 900.0:
			return -1.0
	return -1.0


func _survives_run(sim: Sim, secs: float) -> bool:
	var s := sim.clone()
	var t := 0.0
	while t < secs:
		s.advance(DT, 1.0, false)
		t += DT
		if not s.alive:
			return false
	return true


func _run_bot(lvl: Dictionary) -> Dictionary:
	var sim := Sim.new(lvl)
	var t := 0.0
	var hold_total := 0.0
	var hold_t := 99.0
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
				hold_t = 99.0
			continue
		var dir := 1.0
		if sim.on_ground:
			# Would running straight on get us killed or off the platform in the next moments?
			var probe := sim.clone()
			var danger := false
			var pt := 0.0
			while pt < 0.28:
				probe.advance(DT, 1.0, false)
				pt += DT
				if not probe.alive:
					danger = true
					break
				if not probe.on_ground and pt < 0.06 + 0.001:
					danger = true
					break
			if danger:
				var best := -1e9
				var best_hold := 0.0
				for h in [0.04, 0.08, 0.13, 0.2, 0.35, 0.9]:
					var sc := _rollout_jump(sim, h)
					if sc > best:
						best = sc
						best_hold = h
				if best > -0.5:
					hold_total = best_hold
					hold_t = 0.0
				else:
					dir = 0.0  # no safe jump now: wait (moving platform / timing)
		# identical timing to _rollout_jump so the plan matches reality
		sim.advance(DT, dir, hold_t < hold_total)
		hold_t += DT
		for ev in sim.drain_events():
			if ev.type == "death" and OS.get_environment("BLOOM_DEBUG") != "":
				print("  death L%d at x=%d y=%d" % [lvl.n, ev.pos.x, ev.pos.y])
				if sim.deaths == 1:
					for k in sim.plats.size():
						var pl: Dictionary = sim.plats[k]
						if absf(pl.x - ev.pos.x) < 500.0:
							print("    plat %d x=%d y=%d w=%d kind=%d amp=%d axis=%d spd=%.2f spikes=%s" % [k, pl.x, pl.y, pl.w, pl.kind, pl.amp, pl.axis, pl.speed, str(pl.spikes)])
		if absf(sim.pos.x - stuck_x) > 40.0:
			stuck_x = sim.pos.x
			stuck_t = 0.0
		else:
			stuck_t += DT
			if stuck_t > 25.0:
				break
	return {"ok": sim.finished, "deaths": sim.deaths, "time": t}
