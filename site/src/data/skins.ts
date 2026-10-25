// Mirrors src/core/skins.gd in the game: names, prices, colours, taglines.
export type Skin = { name: string; price: number; c1: string; c2: string; shape: string; tag: string };

export const SKINS: Skin[] = [
	{ name: 'Orb', price: 0, c1: '#22e6ff', c2: '#d9fbff', shape: 'circle', tag: 'The original glow' },
	{ name: 'Cube', price: 100, c1: '#ff4fd8', c2: '#ffd6f6', shape: 'square', tag: 'Rolls with style' },
	{ name: 'Prism', price: 220, c1: '#ffd23f', c2: '#fff6cf', shape: 'tri', tag: 'Sharp and bright' },
	{ name: 'Hexa', price: 350, c1: '#3dffa2', c2: '#d4ffe9', shape: 'hex', tag: 'Six sides of glow' },
	{ name: 'Pulse', price: 500, c1: '#ff4f81', c2: '#ffd0de', shape: 'heart', tag: 'Beats with the music' },
	{ name: 'Crystal', price: 700, c1: '#7bb6ff', c2: '#e8f2ff', shape: 'dia', tag: 'Cut from pure light' },
	{ name: 'Halo', price: 900, c1: '#ff9a3d', c2: '#ffe3c7', shape: 'ring', tag: 'Hollow but radiant' },
	{ name: 'Starling', price: 1150, c1: '#ffe14d', c2: '#fffbe0', shape: 'star', tag: 'Born in the night sky' },
	{ name: 'Wisp', price: 1450, c1: '#b79bff', c2: '#f0e9ff', shape: 'ghost', tag: 'Floats right through' },
	{ name: 'Fireball', price: 1800, c1: '#ff6a1a', c2: '#ffe27a', shape: 'circle', tag: 'Leaves a blaze behind' },
	{ name: 'Plasma', price: 2300, c1: '#3df2ff', c2: '#ffffff', shape: 'circle', tag: 'Crackling with energy' },
	{ name: 'Nova', price: 3000, c1: '#ff4fd8', c2: '#ffffff', shape: 'circle', tag: 'Every colour at once' },
];

const poly = (n: number, r: number, rot = 0) =>
	Array.from({ length: n }, (_, i) => {
		const a = rot + (i * 2 * Math.PI) / n;
		return `${(32 + r * Math.cos(a)).toFixed(1)},${(32 + r * Math.sin(a)).toFixed(1)}`;
	}).join(' ');

/** Inner SVG markup (64x64 viewBox) for a character. */
export function skinSvg(s: Skin): string {
	const st = `fill="${s.c2}" stroke="${s.c1}" stroke-width="5" stroke-linejoin="round"`;
	let g: string;
	switch (s.shape) {
		case 'square': g = `<rect x="12" y="12" width="40" height="40" rx="9" ${st}/>`; break;
		case 'tri': g = `<polygon points="${poly(3, 27, -Math.PI / 2)}" ${st}/>`; break;
		case 'hex': g = `<polygon points="${poly(6, 26)}" ${st}/>`; break;
		case 'dia': g = `<polygon points="32,5 54,32 32,59 10,32" ${st}/>`; break;
		case 'star': {
			const p = Array.from({ length: 10 }, (_, i) => {
				const a = -Math.PI / 2 + (i * Math.PI) / 5;
				const r = i % 2 ? 12 : 28;
				return `${(32 + r * Math.cos(a)).toFixed(1)},${(33 + r * Math.sin(a)).toFixed(1)}`;
			});
			g = `<polygon points="${p.join(' ')}" ${st}/>`;
			break;
		}
		case 'heart': g = `<path d="M32 55 C6 36 8 12 24 12 C29 12 32 16 32 19 C32 16 35 12 40 12 C56 12 58 36 32 55Z" ${st}/>`; break;
		case 'ring': g = `<circle cx="32" cy="32" r="22" fill="none" stroke="${s.c1}" stroke-width="8"/>`; break;
		case 'ghost': g = `<path d="M12 56 V30 C12 10 52 10 52 30 V56 L42 48 L32 56 L22 48Z" ${st}/>`; break;
		default: g = `<circle cx="32" cy="32" r="22" ${st}/>`;
	}
	if (s.name === 'Nova')
		g = g.replace('/>', `><animate attributeName="stroke" values="#ff4fd8;#ffd23f;#3dffa2;#38e8ff;#b57bff;#ff4fd8" dur="4s" repeatCount="indefinite"/></circle>`);
	if (s.name === 'Fireball') g += `<circle cx="32" cy="32" r="11" fill="#ffe27a" opacity=".9"/>`;
	if (s.name === 'Plasma') g += `<path d="M20 34 L30 26 L34 38 L44 30" fill="none" stroke="#3df2ff" stroke-width="2.5" stroke-linecap="round"/>`;
	return g;
}
