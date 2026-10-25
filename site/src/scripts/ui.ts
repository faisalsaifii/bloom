import './scene';
const fine = matchMedia('(pointer: fine)').matches;
const calm = matchMedia('(prefers-reduced-motion: reduce)').matches;

// header: tightens on scroll, shows read progress, tracks the section in view
const nav = document.querySelector<HTMLElement>('.nav')!;
const links = document.getElementById('links')!;
const ind = links.querySelector<HTMLElement>('.ind')!;
const items = [...links.querySelectorAll<HTMLAnchorElement>('a')];
let active: HTMLAnchorElement | null = null;

const moveTo = (a: HTMLAnchorElement | null) => {
	if (!a) { ind.style.opacity = '0'; return; }
	ind.style.opacity = '1';
	ind.style.width = `${a.offsetWidth}px`;
	ind.style.transform = `translateX(${a.offsetLeft}px)`;
};
const setActive = (a: HTMLAnchorElement | null) => {
	active = a;
	items.forEach((i) => i.classList.toggle('on', i === a));
	moveTo(a);
};
items.forEach((a) => {
	a.addEventListener('pointerenter', () => moveTo(a));
	a.addEventListener('focus', () => moveTo(a));
});
links.addEventListener('pointerleave', () => moveTo(active));

const onScroll = () => {
	nav.classList.toggle('scrolled', scrollY > 12);
	// the active section is the last one whose top has passed the middle of the viewport
	let cur: HTMLAnchorElement | null = null;
	for (const a of items) {
		const sec = document.getElementById(a.dataset.s!);
		if (sec && sec.getBoundingClientRect().top < innerHeight * 0.45) cur = a;
	}
	if (cur !== active) setActive(cur);
};
addEventListener('scroll', onScroll, { passive: true });
addEventListener('resize', () => moveTo(active));
onScroll();

// mobile menu
const menu = document.getElementById('menu')!;
const setMenu = (open: boolean) => { nav.classList.toggle('open', open); menu.setAttribute('aria-expanded', String(open)); };
menu.addEventListener('click', () => setMenu(!nav.classList.contains('open')));
document.querySelectorAll('#drawer a').forEach((a) => a.addEventListener('click', () => setMenu(false)));
addEventListener('keydown', (e) => { if (e.key === 'Escape') setMenu(false); });

// reveal on scroll
const io = new IntersectionObserver(
	(entries) => entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }),
	{ threshold: 0.2 },
);
document.querySelectorAll('.rv').forEach((el) => io.observe(el));

// buttons: magnetic pull, gradient flood from the pointer, spark burst on click
document.querySelectorAll<HTMLElement>('.btn').forEach((btn) => {
	btn.addEventListener('pointermove', (e) => {
		const r = btn.getBoundingClientRect();
		btn.style.setProperty('--mx', `${e.clientX - r.left}px`);
		btn.style.setProperty('--my', `${e.clientY - r.top}px`);
		if (fine && !calm) btn.style.translate = `${(e.clientX - r.left - r.width / 2) * 0.12}px ${(e.clientY - r.top - r.height / 2) * 0.22}px`;
	});
	btn.addEventListener('pointerleave', () => { btn.style.translate = ''; });
	btn.addEventListener('click', (e) => {
		if (calm) return;
		for (let i = 0; i < 12; i++) {
			const s = document.createElement('i');
			s.className = 'spark';
			const a = (i / 12) * Math.PI * 2 + Math.random() * 0.4, d = 50 + Math.random() * 40;
			s.style.cssText = `left:${e.clientX}px;top:${e.clientY}px;--dx:${Math.cos(a) * d}px;--dy:${Math.sin(a) * d}px;--h:${Math.random() * 360}`;
			document.body.appendChild(s);
			setTimeout(() => s.remove(), 800);
		}
	});
});

// custom cursor: dot follows exactly, ring trails behind and swells over interactive things
if (fine && !calm) {
	const dot = document.querySelector<HTMLElement>('.c-dot')!;
	const ring = document.querySelector<HTMLElement>('.c-ring')!;
	document.documentElement.classList.add('has-cursor');
	let x = innerWidth / 2, y = innerHeight / 2, rx = x, ry = y;
	addEventListener('pointermove', (e) => {
		x = e.clientX; y = e.clientY;
		document.documentElement.classList.add('cursor-on');
		const t = (e.target as Element).closest('a, button, .card, .chars li');
		ring.classList.toggle('big', !!t);
	});
	document.addEventListener('pointerleave', () => document.documentElement.classList.remove('cursor-on'));
	addEventListener('pointerdown', () => ring.classList.add('down'));
	addEventListener('pointerup', () => ring.classList.remove('down'));
	(function loop() {
		rx += (x - rx) * 0.16; ry += (y - ry) * 0.16;
		dot.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%)`;
		ring.style.transform = `translate(${rx}px, ${ry}px) translate(-50%, -50%)`;
		requestAnimationFrame(loop);
	})();
}
