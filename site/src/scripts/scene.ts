// Hero scene: a self-playing level in the style of the game. A bot runs a scrolling course,
// jumping gaps and spikes, and collects the coins laid out along each jump arc.
const cv = document.getElementById('scene-cv') as HTMLCanvasElement | null;
if (cv) run(cv);

function run(cv: HTMLCanvasElement) {
	const ctx = cv.getContext('2d')!;
	const W = 560, H = 480, GROUND = 350, R = 16, X = 170;
	const SPEED = 200, GRAV = 1900, JUMP = 620;
	const AIR = (2 * JUMP) / GRAV, REACH = SPEED * AIR, APEX = (JUMP * JUMP) / (2 * GRAV);
	const CYAN = '#38e8ff', VIOLET = '#b57bff', PINK = '#ff4fd8', GOLD = '#ffe14d', SPIKE = '#ff4f81';
	const calm = matchMedia('(prefers-reduced-motion: reduce)').matches;
	const hudCoins = document.getElementById('scene-coins');

	type Seg = { x: number; w: number };
	type Coin = { x: number; y: number };
	type P = { x: number; y: number; vx: number; vy: number; l: number; c: string; r: number; ring?: boolean };
	let segs: Seg[] = [], spikes: number[] = [], coins: Coin[] = [], parts: P[] = [], trail: { x: number; y: number }[] = [];
	let camX = 0, genX = -120, y = GROUND - R, vy = 0, grounded = true, last = 0, visible = true, collected = 0, squash = 0;

	const rnd = (a: number, b: number) => a + Math.random() * (b - a);
	const far = Array.from({ length: 7 }, (_, i) => ({ x: i * 150 + rnd(0, 60), y: rnd(70, 250), s: rnd(26, 58), rot: rnd(0, 6), n: [3, 4, 6][i % 3] }));
	const mid = Array.from({ length: 5 }, (_, i) => ({ x: i * 230 + rnd(0, 80), y: rnd(120, 270), w: rnd(70, 130), c: [VIOLET, PINK, CYAN][i % 3] }));
	const stars = Array.from({ length: 60 }, () => ({ x: rnd(0, W), y: rnd(0, GROUND - 40), s: rnd(0.04, 0.2), r: rnd(0.5, 1.5), t: rnd(0, 6) }));

	const arc = (start: number) => {
		for (const t of [0.18, 0.34, 0.5, 0.66, 0.82]) coins.push({ x: start + t * REACH, y: GROUND - R - APEX * 4 * t * (1 - t) });
	};

	function gen() {
		while (genX < camX + W + 300) {
			const first = segs.length === 0;
			const w = first ? 700 : rnd(300, 470);
			segs.push({ x: genX, w });
			if (!first) {
				const s1 = genX + rnd(120, w - 160 > 120 ? w - 160 : 121);
				spikes.push(s1); arc(s1 - 55);
				if (s1 + 190 <= genX + w - 160 && Math.random() < 0.55) { spikes.push(s1 + 190); arc(s1 + 190 - 55); }
			}
			arc(genX + w - 25);
			genX += w + rnd(70, 90);
		}
		segs = segs.filter((s) => s.x + s.w > camX - 200);
		spikes = spikes.filter((x) => x > camX - 200);
		coins = coins.filter((c) => c.x > camX - 200);
	}

	const burst = (x: number, yy: number, c: string, n: number, up = 1) => {
		for (let i = 0; i < n; i++) { const a = rnd(0, Math.PI * 2), v = rnd(30, 110); parts.push({ x, y: yy, vx: Math.cos(a) * v, vy: Math.sin(a) * v * up - 20, l: 1, c, r: rnd(1.2, 2.6) }); }
	};

	function respawn() {
		const px = camX + X;
		const next = segs.find((s) => s.x > px + 30) ?? segs[segs.length - 1];
		camX = next.x + 60 - X; y = GROUND - R; vy = 0; grounded = true; trail = [];
	}

	function step(dt: number) {
		camX += SPEED * dt; gen();
		const px = camX + X;
		const was = grounded;
		vy += GRAV * dt; y += vy * dt;
		const seg = segs.find((s) => px >= s.x - 4 && px <= s.x + s.w + 4);
		if (seg && y >= GROUND - R && vy >= 0) {
			if (!was) { burst(px, GROUND, CYAN, 8, -0.6); squash = 1; }
			y = GROUND - R; vy = 0; grounded = true;
		} else grounded = false;
		if (y > H + 40) respawn();
		for (const sx of spikes) if (Math.abs(sx - px) < R + 4 && y > GROUND - R - 18) respawn();
		for (let i = coins.length - 1; i >= 0; i--) {
			const c = coins[i];
			if (Math.hypot(c.x - px, c.y - y) < R + 10) {
				coins.splice(i, 1); collected++; burst(c.x, c.y, GOLD, 7);
				parts.push({ x: c.x, y: c.y, vx: 0, vy: 0, l: 1, c: GOLD, r: 8, ring: true });
				if (hudCoins) hudCoins.textContent = String(collected);
			}
		}
		if (grounded) {
			const edge = seg ? seg.x + seg.w - px : 999;
			const sp = spikes.find((sx) => sx - px > 0 && sx - px <= 55);
			if (edge < 25 || sp !== undefined) { vy = -JUMP; grounded = false; }
		}
		trail.push({ x: px, y }); if (trail.length > 16) trail.shift();
		for (const p of parts) { p.l -= dt * (p.ring ? 2.4 : 1.7); p.x += p.vx * dt; p.y += p.vy * dt; if (!p.ring) p.vy += 140 * dt; }
		parts = parts.filter((p) => p.l > 0);
		squash = Math.max(0, squash - dt * 5);
		if (Math.random() < dt * 5) parts.push({ x: camX + rnd(0, W), y: GROUND + rnd(-10, 20), vx: rnd(-6, 6), vy: rnd(-40, -18), l: 1.2, c: [CYAN, VIOLET, PINK][Math.floor(rnd(0, 3))], r: rnd(1, 2.2) });
	}

	const poly = (cx: number, cy: number, r: number, n: number, rot: number) => {
		ctx.beginPath();
		for (let i = 0; i < n; i++) { const a = rot + (i * Math.PI * 2) / n; i ? ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r) : ctx.moveTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r); }
		ctx.closePath();
	};
	const wrap = (v: number, m: number) => ((v % m) + m) % m;

	function draw(now: number) {
		const k = cv!.width / W;
		ctx.setTransform(k, 0, 0, k, 0, 0);
		ctx.clearRect(0, 0, W, H);
		ctx.shadowBlur = 0; ctx.globalAlpha = 1;

		// horizon glow
		const hg = ctx.createLinearGradient(0, GROUND - 180, 0, GROUND + 10);
		hg.addColorStop(0, 'rgba(56,232,255,0)'); hg.addColorStop(1, 'rgba(56,232,255,.10)');
		ctx.fillStyle = hg; ctx.fillRect(0, GROUND - 180, W, 190);

		for (const s of stars) {
			ctx.globalAlpha = 0.25 + 0.35 * (0.5 + 0.5 * Math.sin(now / 900 + s.t));
			ctx.fillStyle = '#fff'; ctx.fillRect(wrap(s.x - camX * s.s, W), s.y, s.r, s.r);
		}
		ctx.globalAlpha = 1;

		// far layer: slow drifting crystals
		for (const c of far) {
			const x = wrap(c.x - camX * 0.1, W + 160) - 80;
			ctx.strokeStyle = 'rgba(181,123,255,.22)'; ctx.fillStyle = 'rgba(181,123,255,.05)'; ctx.lineWidth = 1.5;
			poly(x, c.y, c.s, c.n, c.rot + now / 9000); ctx.fill(); ctx.stroke();
		}
		// mid layer: distant platforms
		ctx.lineCap = 'round';
		for (const m of mid) {
			const x = wrap(m.x - camX * 0.4, W + 300) - 100;
			ctx.globalAlpha = 0.4; ctx.strokeStyle = m.c; ctx.shadowColor = m.c; ctx.shadowBlur = 10; ctx.lineWidth = 3;
			ctx.beginPath(); ctx.moveTo(x, m.y); ctx.lineTo(x + m.w, m.y); ctx.stroke();
		}
		ctx.globalAlpha = 1; ctx.shadowBlur = 0;

		// ground segments
		for (const s of segs) {
			const x = s.x - camX;
			const g = ctx.createLinearGradient(0, GROUND, 0, H);
			g.addColorStop(0, 'rgba(56,232,255,.22)'); g.addColorStop(1, 'rgba(56,232,255,0)');
			ctx.fillStyle = g; ctx.fillRect(x, GROUND, s.w, H - GROUND);
			ctx.strokeStyle = 'rgba(56,232,255,.10)'; ctx.lineWidth = 1;
			for (let gx = Math.ceil((s.x) / 40) * 40; gx < s.x + s.w; gx += 40) { ctx.beginPath(); ctx.moveTo(gx - camX, GROUND + 2); ctx.lineTo(gx - camX, H); ctx.stroke(); }
			ctx.shadowColor = CYAN; ctx.shadowBlur = 16; ctx.strokeStyle = CYAN; ctx.lineWidth = 4;
			ctx.beginPath(); ctx.moveTo(x, GROUND); ctx.lineTo(x + s.w, GROUND); ctx.stroke();
			ctx.shadowBlur = 0; ctx.strokeStyle = '#d9fbff'; ctx.lineWidth = 1; ctx.globalAlpha = 0.7;
			ctx.beginPath(); ctx.moveTo(x + 1, GROUND - 1); ctx.lineTo(x + s.w - 1, GROUND - 1); ctx.stroke(); ctx.globalAlpha = 1;
		}

		// spikes
		ctx.shadowColor = SPIKE; ctx.shadowBlur = 14; ctx.fillStyle = SPIKE;
		for (const sx of spikes) { const x = sx - camX; ctx.beginPath(); ctx.moveTo(x - 13, GROUND); ctx.lineTo(x, GROUND - 28); ctx.lineTo(x + 13, GROUND); ctx.closePath(); ctx.fill(); }

		// coins (spinning)
		ctx.shadowColor = GOLD; ctx.shadowBlur = 12; ctx.fillStyle = GOLD;
		for (const c of coins) {
			const sw = Math.abs(Math.cos(now / 380 + c.x * 0.05));
			ctx.beginPath(); ctx.ellipse(c.x - camX, c.y, 3 + 4 * sw, 7, 0, 0, 7); ctx.fill();
		}
		ctx.shadowBlur = 0;

		// trail
		for (let i = 0; i < trail.length; i++) {
			const t = trail[i], f = i / trail.length;
			ctx.globalAlpha = f * 0.35; ctx.fillStyle = CYAN;
			ctx.beginPath(); ctx.arc(t.x - camX, t.y, R * (0.35 + f * 0.5), 0, 7); ctx.fill();
		}
		ctx.globalAlpha = 1;

		// orb
		ctx.save(); ctx.translate(X, y);
		const air = Math.min(1, Math.abs(vy) / 700);
		ctx.scale(1 - air * 0.1 + squash * 0.18, 1 + air * 0.14 - squash * 0.2);
		ctx.shadowColor = CYAN; ctx.shadowBlur = 26;
		ctx.fillStyle = '#eafcff'; ctx.strokeStyle = CYAN; ctx.lineWidth = 4.5;
		ctx.beginPath(); ctx.arc(0, 0, R, 0, 7); ctx.fill(); ctx.stroke();
		ctx.restore();

		// particles
		for (const p of parts) {
			ctx.globalAlpha = Math.max(0, p.l) * (p.ring ? 0.8 : 0.9);
			if (p.ring) { ctx.strokeStyle = p.c; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(p.x - camX, p.y, p.r + (1 - p.l) * 22, 0, 7); ctx.stroke(); }
			else { ctx.fillStyle = p.c; ctx.shadowColor = p.c; ctx.shadowBlur = 8; ctx.beginPath(); ctx.arc(p.x - camX, p.y, p.r, 0, 7); ctx.fill(); }
		}
		ctx.globalAlpha = 1; ctx.shadowBlur = 0;
	}

	function frame(t: number) {
		if (visible) { step(Math.min(0.05, (t - last) / 1000 || 0)); draw(t); }
		last = t;
		requestAnimationFrame(frame);
	}
	function resize() {
		const r = cv.getBoundingClientRect(), d = Math.min(2, devicePixelRatio || 1);
		cv.width = Math.round(r.width * d); cv.height = Math.round(r.width * (H / W) * d);
	}
	addEventListener('resize', resize); resize();
	new IntersectionObserver((e) => { visible = e[0].isIntersecting; }, { threshold: 0.05 }).observe(cv);
	gen();
	if (calm) { for (let i = 0; i < 60; i++) step(0.016); draw(0); } else requestAnimationFrame(frame);
}
