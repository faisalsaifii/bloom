class_name Sim
extends RefCounted
## Pure platformer simulation (no nodes). The Game screen renders it; tests/bots can drive it headlessly.
## Platforms are one-way slabs: you land on their top, you can jump up through them.

const R := 16.0
const GRAV := 2300.0
const FALL_MULT := 1.12
const MAX_FALL := 1150.0
const SPEED := 330.0
const ACC_G := 3400.0
const ACC_A := 2300.0
const FRIC_G := 3800.0
const FRIC_A := 450.0
const JUMP_V := 830.0
const COYOTE := 0.1
const BUFFER := 0.13
const KILL_Y := 1100.0
const CRUMBLE_DELAY := 0.5
const COIN_R := 13.0
const SPIKE_H := 22.0
const STEP := 1.0 / 120.0

var level: Dictionary
var plats: Array
var coins: Array
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var on_ground := false
var ground_idx := -1
var time := 0.0
var run_time := 0.0
var coyote := 0.0
var buffer := 0.0
var jump_was_held := false
var alive := true
var finished := false
var deaths := 0
var coins_got := 0
var combo := 0
var combo_t := 0.0
var collected: PackedByteArray
var cp_pos := Vector2.ZERO
var cp_collected: PackedByteArray
var cp_coins := 0
var cp_idx := -1
var reached_cp: Dictionary = {}
var events: Array = []     # [{"type": String, ...}] drained by the view
var pstate: Array = []     # per-platform runtime state
var acc := 0.0
var facing := 1.0
var roll := 0.0


func _init(lvl: Dictionary) -> void:
	level = lvl
	plats = lvl.platforms
	coins = lvl.coins
	collected = PackedByteArray()
	collected.resize(coins.size())
	cp_collected = collected.duplicate()
	cp_pos = Vector2(lvl.start.x, lvl.start.y - R)
	_reset_platforms()
	respawn()


## Deep copy of the full simulation state (used by look-ahead bots/tests).
func clone() -> Sim:
	var c := Sim.new(level)
	c.pos = pos
	c.vel = vel
	c.on_ground = on_ground
	c.ground_idx = ground_idx
	c.time = time
	c.run_time = run_time
	c.coyote = coyote
	c.buffer = buffer
	c.jump_was_held = jump_was_held
	c.alive = alive
	c.finished = finished
	c.deaths = deaths
	c.coins_got = coins_got
	c.collected = collected.duplicate()
	c.cp_pos = cp_pos
	c.cp_collected = cp_collected.duplicate()
	c.cp_coins = cp_coins
	c.reached_cp = reached_cp.duplicate()
	c.pstate = pstate.duplicate(true)
	c.acc = acc
	c.facing = facing
	c.roll = roll
	c.events.clear()
	return c


func _reset_platforms() -> void:
	pstate.clear()
	for p in plats:
		pstate.append({"ox": 0.0, "oy": 0.0, "dx": 0.0, "dy": 0.0, "cs": 0, "ct": 0.0, "fy": 0.0, "fv": 0.0})
	_update_platforms(0.0, true)


func respawn() -> void:
	pos = cp_pos
	vel = Vector2.ZERO
	on_ground = false
	ground_idx = -1
	coyote = 0.0
	buffer = 0.0
	alive = true
	combo = 0
	collected = cp_collected.duplicate()
	coins_got = cp_coins
	_reset_platforms()
	events.append({"type": "respawn"})


func total_coins() -> int:
	return coins.size()


func rect_of(i: int) -> Rect2:
	var p: Dictionary = plats[i]
	var s: Dictionary = pstate[i]
	return Rect2(p.x + s.ox, p.y + s.oy + s.fy, p.w, Levels.PLAT_H)


func _update_platforms(dt: float, snap := false) -> void:
	for i in plats.size():
		var p: Dictionary = plats[i]
		if not snap and absf(p.x - pos.x) > 1800.0:
			continue  # far off-screen: state is recomputed when it comes back into range
		var s: Dictionary = pstate[i]
		if p.kind == Levels.Kind.MOVER:
			var off: float = sin(time * p.speed + p.phase) * p.amp
			var nx: float = s.ox
			var ny: float = s.oy
			if p.axis == 0:
				nx = off
			else:
				ny = off
			s.dx = 0.0 if snap else nx - s.ox
			s.dy = 0.0 if snap else ny - s.oy
			s.ox = nx
			s.oy = ny
		elif p.kind == Levels.Kind.CRUMBLE:
			if s.cs == 1:
				s.ct += dt
				s.ox = randf_range(-1.8, 1.8)
				if s.ct >= CRUMBLE_DELAY:
					s.cs = 2
					s.ox = 0.0
					events.append({"type": "crumble", "pos": Vector2(p.x + p.w * 0.5, p.y)})
			elif s.cs == 2:
				s.fv += GRAV * dt
				s.dy = s.fv * dt
				s.fy += s.dy


func _solid(i: int) -> bool:
	return pstate[i].cs != 2


func spike_triangles(i: int) -> Array:
	## Returns an array of PackedVector2Array triangles (world space) for platform i.
	var out: Array = []
	var p: Dictionary = plats[i]
	var r := rect_of(i)
	for sp in p.spikes:
		var teeth := int(round(float(sp.w) / Levels.SPIKE_W))
		for k in teeth:
			var x0: float = r.position.x + float(sp.off) + k * Levels.SPIKE_W
			out.append(PackedVector2Array([
				Vector2(x0, r.position.y), Vector2(x0 + Levels.SPIKE_W, r.position.y),
				Vector2(x0 + Levels.SPIKE_W * 0.5, r.position.y - SPIKE_H)]))
	return out


static func _closest_on_seg(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return a + ab * t


static func circle_hits_tri(c: Vector2, rad: float, tri: PackedVector2Array) -> bool:
	for i in 3:
		if _closest_on_seg(c, tri[i], tri[(i + 1) % 3]).distance_to(c) <= rad:
			return true
	# centre inside triangle
	var d1 := (c - tri[1]).cross(tri[0] - tri[1])
	var d2 := (c - tri[2]).cross(tri[1] - tri[2])
	var d3 := (c - tri[0]).cross(tri[2] - tri[0])
	var neg := d1 < 0 or d2 < 0 or d3 < 0
	var posv := d1 > 0 or d2 > 0 or d3 > 0
	return not (neg and posv)


## Advance the simulation by dt seconds (sub-stepped for stability).
func advance(dt: float, move_dir: float, jump_held: bool) -> void:
	acc += minf(dt, 0.1)
	while acc >= STEP:
		acc -= STEP
		_step(STEP, move_dir, jump_held)


func _step(dt: float, move_dir: float, jump_held: bool) -> void:
	if finished or not alive:
		return
	time += dt
	run_time += dt
	_update_platforms(dt)

	# Carry with the platform we stand on.
	if on_ground and ground_idx >= 0:
		var s: Dictionary = pstate[ground_idx]
		pos.x += s.dx
		pos.y += s.dy
		if plats[ground_idx].kind == Levels.Kind.CRUMBLE and s.cs == 2:
			on_ground = false

	# Jump buffering / coyote.
	if jump_held and not jump_was_held:
		buffer = BUFFER
	buffer = maxf(0.0, buffer - dt)
	coyote = COYOTE if on_ground else maxf(0.0, coyote - dt)
	if buffer > 0.0 and coyote > 0.0:
		vel.y = -JUMP_V
		on_ground = false
		ground_idx = -1
		coyote = 0.0
		buffer = 0.0
		events.append({"type": "jump", "pos": pos + Vector2(0, R)})
	# Variable jump height: release early to cut the jump short.
	if not jump_held and vel.y < -280.0:
		vel.y = -280.0
	jump_was_held = jump_held

	# Horizontal movement.
	var target := move_dir * SPEED
	var acc_rate: float = ACC_G if on_ground else ACC_A
	if is_zero_approx(move_dir):
		vel.x = move_toward(vel.x, 0.0, (FRIC_G if on_ground else FRIC_A) * dt)
	else:
		vel.x = move_toward(vel.x, target, acc_rate * dt)
		facing = signf(move_dir)

	# Gravity.
	var g := GRAV * (FALL_MULT if vel.y > 0.0 else 1.0)
	vel.y = minf(vel.y + g * dt, MAX_FALL)

	var prev := pos
	pos += vel * dt
	roll += vel.x * dt / R

	# One-way landing.
	var was_ground := on_ground
	on_ground = false
	if vel.y >= 0.0:
		var best := -1
		var best_top := 1e9
		for i in plats.size():
			if absf(plats[i].x - pos.x) > 700.0 or not _solid(i):
				continue
			var r := rect_of(i)
			if pos.x < r.position.x - R * 0.35 or pos.x > r.end.x + R * 0.35:
				continue
			var top := r.position.y
			var prev_bottom := prev.y + R
			if prev_bottom <= top + 10.0 and pos.y + R >= top and top < best_top:
				best = i
				best_top = top
		if best >= 0:
			pos.y = best_top - R
			if not was_ground and vel.y > 250.0:
				events.append({"type": "land", "pos": pos + Vector2(0, R), "speed": vel.y})
			vel.y = 0.0
			on_ground = true
			ground_idx = best
			var s2: Dictionary = pstate[best]
			if plats[best].kind == Levels.Kind.CRUMBLE and s2.cs == 0:
				s2.cs = 1
				events.append({"type": "crumble_start", "pos": Vector2(pos.x, best_top)})
	if not on_ground:
		ground_idx = -1

	_check_hazards_and_pickups(dt)


func _check_hazards_and_pickups(dt: float) -> void:
	combo_t = maxf(0.0, combo_t - dt)
	if combo_t <= 0.0:
		combo = 0
	# Fell out of the world.
	if pos.y > KILL_Y:
		_die()
		return
	# Spikes.
	var hit_r := R * 0.78
	for i in plats.size():
		if plats[i].spikes.is_empty():
			continue
		var r := rect_of(i)
		if pos.x < r.position.x - 60.0 or pos.x > r.end.x + 60.0:
			continue
		for tri in spike_triangles(i):
			if circle_hits_tri(pos, hit_r, tri):
				_die()
				return
	# Coins.
	for i in coins.size():
		if collected[i] == 0 and pos.distance_squared_to(coins[i]) < (R + COIN_R + 3.0) * (R + COIN_R + 3.0):
			collected[i] = 1
			coins_got += 1
			events.append({"type": "coin", "pos": coins[i], "combo": combo})
			combo += 1
			combo_t = 1.1
	# Checkpoints.
	for i in plats.size():
		if plats[i].cp and not reached_cp.has(i):
			var cpp := Vector2(plats[i].x + plats[i].w * 0.5, plats[i].y)
			if absf(pos.x - cpp.x) < 40.0 and absf(pos.y + R - cpp.y) < 40.0:
				reached_cp[i] = true
				cp_pos = Vector2(cpp.x, cpp.y - R)
				cp_collected = collected.duplicate()
				cp_coins = coins_got
				cp_idx = i
				events.append({"type": "checkpoint", "pos": cpp})
	# Finish.
	var fin: Vector2 = level.finish
	if absf(pos.x - fin.x) < 34.0 and pos.y + R > fin.y - 190.0 and pos.y + R < fin.y + 30.0:
		finished = true
		vel = Vector2.ZERO
		events.append({"type": "win", "pos": fin})


func _die() -> void:
	alive = false
	deaths += 1
	events.append({"type": "death", "pos": pos})


func drain_events() -> Array:
	var e := events
	events = []
	return e
