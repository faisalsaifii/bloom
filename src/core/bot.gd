class_name Bot
extends RefCounted
## Look-ahead autoplayer. Used by tests/bot_test.gd to prove levels are beatable and by debug autoplay.
## It simulates candidate jumps on a clone of the real Sim and picks one that lands safely.

const DT := 1.0 / 60.0

var hold_total := 0.0
var hold_t := 99.0


func reset() -> void:
	hold_t = 99.0


## Returns Vector2(move_dir, jump_held 0/1) for this frame. Call once per DT-sized frame.
func decide(sim: Sim) -> Vector2:
	var dir := 1.0
	if sim.on_ground:
		var probe := sim.clone()
		var danger := false
		var pt := 0.0
		while pt < 0.28:
			probe.advance(DT, 1.0, false)
			pt += DT
			if not probe.alive:
				danger = true
				break
			if not probe.on_ground and pt < 0.061:
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
				dir = 0.0  # no safe jump right now: wait (moving platform / timing)
	var held := hold_t < hold_total
	hold_t += DT
	return Vector2(dir, 1.0 if held else 0.0)


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
