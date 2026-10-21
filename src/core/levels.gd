class_name Levels
extends RefCounted
## Deterministic procedural generator for the 100 levels. Difficulty ramps with level number.
## Every gap is checked against the real jump physics (see Sim) so levels are always passable.

const PLAT_H := 22.0
const SPIKE_W := 24.0
const THEME_HUES := [0.52, 0.47, 0.42, 0.36, 0.58, 0.63, 0.69, 0.75, 0.80, 0.86]
const THEME_NAMES := ["Lagoon", "Mint", "Meadow", "Grove", "Dusk", "Midnight", "Orchid", "Violet", "Rose", "Ember"]

enum Kind { STATIC, MOVER, CRUMBLE }

static var _cache := {}


static func difficulty(n: int) -> float:
	return clampf((n - 1) / 99.0, 0.0, 1.0)


static func difficulty_name(n: int) -> String:
	if n <= 10: return "Easy"
	if n <= 30: return "Medium"
	if n <= 55: return "Hard"
	if n <= 80: return "Expert"
	return "Insane"


static func theme(n: int) -> Dictionary:
	var idx := clampi((n - 1) / 10, 0, 9)
	var h: float = THEME_HUES[idx]
	return {
		"name": THEME_NAMES[idx],
		"accent": Color.from_hsv(h, 0.62, 1.0),
		"accent2": Color.from_hsv(fposmod(h + 0.12, 1.0), 0.55, 1.0),
		"bg_top": Color.from_hsv(h, 0.62, 0.24),
		"bg_bot": Color.from_hsv(fposmod(h - 0.03, 1.0), 0.75, 0.07),
		"hue": h,
	}


## Horizontal distance a full jump covers when landing `dy_up` pixels above take-off (negative = below).
static func reach(dy_up: float) -> float:
	var apex := Sim.JUMP_V * Sim.JUMP_V / (2.0 * Sim.GRAV)
	var t1 := Sim.JUMP_V / Sim.GRAV
	var drop := apex - dy_up
	if drop < 0.0:
		return 0.0
	var t2 := sqrt(2.0 * drop / (Sim.GRAV * Sim.FALL_MULT))
	return Sim.SPEED * (t1 + t2)


static func get_level(n: int) -> Dictionary:
	if not _cache.has(n):
		_cache[n] = build(n)
	return _cache[n]


static func build(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + n * 977
	var d := difficulty(n)
	var count := int(round(lerpf(8.0, 44.0, pow(d, 0.9))))
	var plats: Array = []
	var coins: Array = []

	# Start platform.
	var cur := {"x": 0.0, "y": 440.0, "w": 400.0, "kind": Kind.STATIC, "spikes": [], "cp": false}
	plats.append(cur)
	var spike_chance := 0.0 if n < 2 else lerpf(0.22, 0.7, d)
	if n == 2:
		spike_chance = 0.6
	var mover_chance := 0.0 if n < 11 else lerpf(0.1, 0.3, d)
	var crumble_chance := 0.0 if n < 26 else lerpf(0.08, 0.26, d)
	var prev_kind: int = Kind.STATIC
	var crumble_run := 0
	var prev_foot := Vector2(0.0, 400.0)  # footprint [x0, x1] of the previous platform

	for i in count:
		var kind: int = Kind.STATIC
		var roll := rng.randf()
		if roll < mover_chance and prev_kind != Kind.MOVER:
			kind = Kind.MOVER
		elif roll < mover_chance + crumble_chance and crumble_run < 2 and prev_kind != Kind.MOVER:
			kind = Kind.CRUMBLE
		var base_w := lerpf(300.0, 104.0, pow(d, 0.8)) * rng.randf_range(0.85, 1.25)
		var w := roundf(base_w / 12.0) * 12.0
		var spikes: Array = []
		if kind == Kind.STATIC or (kind == Kind.MOVER and n >= 45 and rng.randf() < 0.35):
			if rng.randf() < spike_chance and i > 0 and i < count - 1:
				var teeth := rng.randi_range(1, 1 + int(d * 4.2))
				var sw := teeth * SPIKE_W
				w = maxf(w, sw + 200.0)
				w = roundf(w / 12.0) * 12.0
				var room_l := 105.0
				var room_r := 90.0
				var off := rng.randf_range(room_l, maxf(room_l, w - room_r - sw))
				spikes.append({"off": roundf(off / 4.0) * 4.0, "w": sw})
		# Vertical placement.
		var amp := 0.0
		var axis := 0
		var speed := 0.0
		if kind == Kind.MOVER:
			axis = 0 if (n < 26 or rng.randf() < 0.6) else 1
			amp = roundf(lerpf(50.0, 110.0, d) * rng.randf_range(0.7, 1.0)) if axis == 0 else roundf(lerpf(30.0, 50.0, d))
			speed = lerpf(0.9, 1.7, d) * rng.randf_range(0.85, 1.15)
		var vlimit := lerpf(40.0, 95.0, d)
		var dy := roundf(rng.randf_range(-1.0, 1.0) * vlimit)
		if axis == 1 or prev_kind == Kind.MOVER:
			dy = clampf(dy, -30.0, 30.0)
		var ny: float = clampf(cur.y - dy, 300.0, 540.0)
		dy = cur.y - ny
		var vert_extra := amp if axis == 1 else 0.0
		var prev_vert_extra := float(cur.get("amp", 0.0)) if int(cur.get("axis", 0)) == 1 else 0.0
		# Gap sized against jump physics (worst case when either side is moving).
		var worst_dy := dy + vert_extra + prev_vert_extra
		var gmax := reach(minf(worst_dy, 105.0))
		var f := lerpf(0.34, 0.88, pow(d, 0.9)) * rng.randf_range(0.8, 1.0)
		var gap := gmax * f
		var h_extra := 0.0
		if kind == Kind.MOVER and axis == 0:
			h_extra += 2.0 * amp
		if cur.kind == Kind.MOVER and int(cur.get("axis", 0)) == 0:
			h_extra += 2.0 * float(cur.amp)
		gap = clampf(gap - h_extra, 28.0, 250.0)
		var foot_x0: float = prev_foot.y + gap
		var plat := {"w": w, "y": ny, "kind": kind, "spikes": spikes, "cp": false, "amp": amp, "axis": axis, "speed": speed,
			"phase": rng.randf() * TAU}
		if kind == Kind.MOVER and axis == 0:
			plat.x = foot_x0 + amp  # centre of travel
			prev_foot = Vector2(foot_x0, foot_x0 + w + 2.0 * amp)
		else:
			plat.x = foot_x0
			prev_foot = Vector2(foot_x0, foot_x0 + w)
		plats.append(plat)
		crumble_run = crumble_run + 1 if kind == Kind.CRUMBLE else 0
		prev_kind = kind
		cur = plat

	# Finish platform.
	var gap_f := reach(0.0) * lerpf(0.34, 0.5, d)
	var fin := {"x": prev_foot.y + gap_f, "y": clampf(cur.y, 340.0, 520.0), "w": 420.0, "kind": Kind.STATIC, "spikes": [], "cp": false}
	plats.append(fin)

	# Checkpoints on wide, static, spike-free platforms every ~12 platforms.
	if count >= 16:
		var i := 11
		while i < plats.size() - 3:
			var j := i
			while j < i + 4 and j < plats.size() - 3:
				var p: Dictionary = plats[j]
				if p.kind == Kind.STATIC and p.spikes.is_empty() and p.w >= 150.0:
					p.cp = true
					break
				j += 1
			i += 12

	# Coins: arcs over gaps, trails on platforms, arcs over spikes.
	for i in plats.size():
		var p: Dictionary = plats[i]
		var px0: float = p.x - (p.amp if p.kind == Kind.MOVER and int(p.get("axis", 0)) == 0 else 0.0)
		var px1: float = p.x + p.w + (p.amp if p.kind == Kind.MOVER and int(p.get("axis", 0)) == 0 else 0.0)
		if i < plats.size() - 1:
			var q: Dictionary = plats[i + 1]
			var qx0: float = q.x - (q.amp if q.kind == Kind.MOVER and int(q.get("axis", 0)) == 0 else 0.0)
			if rng.randf() < 0.75 and qx0 - px1 > 60.0:
				var c := 3
				for k in c:
					var t := (k + 1.0) / (c + 1.0)
					var cx := lerpf(px1, qx0, t)
					var cy := lerpf(p.y, q.y, t) - 52.0 - 62.0 * sin(PI * t)
					coins.append(Vector2(cx, cy))
		for s in p.spikes:
			var sx: float = p.x + float(s.off) + float(s.w) * 0.5
			coins.append(Vector2(sx, p.y - 98.0))
		if p.spikes.is_empty() and i > 0 and i < plats.size() - 1 and rng.randf() < 0.35:
			var cc := rng.randi_range(2, 3)
			for k in cc:
				var cx2: float = p.x + p.w * (k + 1.0) / (cc + 1.0)
				coins.append(Vector2(cx2, p.y - 44.0))
	# Cap coin count so counts stay satisfying but not overwhelming.
	var quota := int(round(lerpf(8.0, 36.0, d)))
	while coins.size() > quota and coins.size() > 6:
		coins.remove_at(rng.randi_range(0, coins.size() - 1))

	var length: float = fin.x + fin.w
	return {
		"n": n,
		"platforms": plats,
		"coins": coins,
		"start": Vector2(80.0, 440.0),
		"finish": Vector2(fin.x + fin.w * 0.5, fin.y),
		"length": length,
		"theme": theme(n),
	}
