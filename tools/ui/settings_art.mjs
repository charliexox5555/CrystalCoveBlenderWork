// Settings screen artwork (Stained Glass, aqua accent). Writes editable SVGs and transparent PNGs at 2x into
// assets/ui/screens/settings/. Same palette and lead-line style as tools/ui/stained_glass.mjs, kept separate so the
// kit script stays untouched (importing it would regenerate the whole kit).
// Run:  node tools/ui/settings_art.mjs   (renders with @resvg/resvg-js if found, else sharp; both via NODE_PATH)
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const paths = [process.cwd(), ...(process.env.NODE_PATH ?? "").split(":").filter(Boolean)];
const find = (name) => { try { return require(require.resolve(name, { paths })); } catch { return null; } };
const resvg = find("@resvg/resvg-js"), sharp = resvg ? null : find("sharp");
if (!resvg && !sharp) throw new Error("Needs @resvg/resvg-js or sharp (npm i @resvg/resvg-js)");

const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "assets", "ui", "screens", "settings");
const SCALE = 2;
const P = {
	lead: "#1F1830", smoke: "#261D3B", smoke2: "#332854", viewport: "#3B2F5E",
	ruby: ["#E23A55", "#FF8EA0", "#9E1D38"], amber: ["#F5A524", "#FFD98A", "#B26E0B"],
	emerald: ["#22B573", "#86EDB8", "#11703F"], sapphire: ["#2E6BE6", "#93BCFF", "#1A409C"],
	amethyst: ["#8B4FE0", "#CDAAFF", "#57299F"], aqua: ["#1FC2D3", "#9BF3F8", "#0F7C88"],
	milk: ["#EEE7D9", "#FFFFFF", "#B9AE99"], slate: ["#7C7896", "#B7B3CC", "#4F4B69"],
};
let seed = 23;
const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
const pts = (a) => a.map((p) => p[0].toFixed(1) + "," + p[1].toFixed(1)).join(" ");
const poly = (a, fill, extra = "") => `<polygon points="${pts(a)}" fill="${fill}" ${extra}/>`;
const SV = (w, h, s) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">${s}</svg>`;
const LEAD = (w) => `stroke="${P.lead}" stroke-width="${w}" stroke-linejoin="round"`;
const chamfer = (x, y, w, h, c) => [[x + c[0], y], [x + w - c[1], y], [x + w, y + c[1]], [x + w, y + h - c[2]], [x + w - c[2], y + h], [x + c[3], y + h], [x, y + h - c[3]], [x, y + c[0]]];
const along = (pl) => { const L = [0]; for (let i = 0; i < pl.length; i++) { const a = pl[i], b = pl[(i + 1) % pl.length]; L.push(L[i] + Math.hypot(b[0] - a[0], b[1] - a[1])); } return L; };
const at = (pl, L, t) => { const d = t * L[L.length - 1]; for (let i = 0; i < pl.length; i++) { if (d <= L[i + 1] + 1e-6) { const a = pl[i], b = pl[(i + 1) % pl.length], u = (d - L[i]) / ((L[i + 1] - L[i]) || 1); return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]; } } return pl[0]; };
const arc = (pl, L, t0, t1) => { const T = L[L.length - 1], o = [at(pl, L, t0)]; for (let i = 1; i <= pl.length; i++) { const ti = L[i] / T; if (ti > t0 && ti < t1) o.push(pl[i % pl.length]); } o.push(at(pl, L, t1)); return o; };
const shrink = (a, f) => { const cx = a.reduce((s, p) => s + p[0], 0) / a.length, cy = a.reduce((s, p) => s + p[1], 0) / a.length; return a.map((p) => [cx + (p[0] - cx) * f, cy + (p[1] - cy) * f]); };
// Long hexagon (pointed ends): toggle tracks, slider bars.
const hexBar = (x, y, w, h, k) => [[x + k, y], [x + w - k, y], [x + w, y + h / 2], [x + w - k, y + h], [x + k, y + h], [x, y + h / 2]];

// Window: same mosaic-border recipe as the kit's windowSvg, in cool jewels (aqua-led) so Settings reads apart from
// the amber reward screens.
function windowSvg(w, h, o) {
	const band = o.band, c = o.cut, cols = o.colors;
	const outer = chamfer(4, 4, w - 8, h - 8, c), ic = c.map((v) => Math.max(6, v - band * 0.45)), inner = chamfer(4 + band, 4 + band, w - 8 - 2 * band, h - 8 - 2 * band, ic);
	const Lo = along(outer), Li = along(inner), n = o.pieces;
	const ts = [0]; for (let i = 1; i < n; i++) ts.push(i / n + (rnd() - 0.5) * 0.55 / n); ts.push(1);
	let s = poly(outer, P.lead);
	for (let i = 0; i < n; i++) {
		const a = arc(outer, Lo, ts[i], ts[i + 1]), b = arc(inner, Li, ts[i], ts[i + 1]).reverse(), pc = a.concat(b), col = P[cols[Math.floor(rnd() * cols.length)]];
		s += poly(pc, col[0], LEAD(5)) + poly(shrink(pc, 0.45), col[1], 'fill-opacity="0.35"');
	}
	s += poly(inner, P.smoke, LEAD(6));
	for (let k = 0; k < 3; k++) { const t = rnd(), p1 = at(inner, Li, t), p2 = at(inner, Li, (t + 0.3 + rnd() * 0.35) % 1); s += `<line x1="${p1[0].toFixed(1)}" y1="${p1[1].toFixed(1)}" x2="${p2[0].toFixed(1)}" y2="${p2[1].toFixed(1)}" stroke="${P.smoke2}" stroke-width="4"/>`; }
	return SV(w, h, s + poly(outer, "none", LEAD(8)));
}

// Toggle track: pointed glass bar. ON = lit emerald, OFF = dark slate. Knob and ON/OFF text are separate.
function toggleTrack(on) {
	const w = 128, h = 56, c = on ? P.emerald : P.slate, o = hexBar(3, 3, w - 6, h - 6, 16), inner = hexBar(11, 10, w - 22, h - 20, 11);
	let s = poly(o, on ? c[2] : P.smoke, LEAD(5));
	s += poly(inner, on ? c[0] : c[2], `stroke="${P.lead}" stroke-opacity="0.5" stroke-width="2.5" stroke-linejoin="round"`);
	s += poly([[22, 12], [w - 22, 12], [w - 28, 22], [28, 22]], on ? c[1] : c[0], `fill-opacity="${on ? 0.7 : 0.35}"`);
	return SV(w, h, s + poly(o, "none", LEAD(6)));
}
// Toggle knob: faceted milk-glass octagon.
function toggleKnob() {
	const o = chamfer(3, 3, 50, 50, [14, 14, 14, 14]), t = shrink(o, 0.58);
	let s = poly(o, P.milk[0], LEAD(5));
	for (let j = 0; j < 8; j++) s += poly([o[j], o[(j + 1) % 8], t[(j + 1) % 8], t[j]], [P.milk[1], P.milk[1], P.milk[0], P.milk[2], P.milk[2], P.milk[2], P.milk[0], P.milk[1]][j], `stroke="${P.lead}" stroke-opacity="0.35" stroke-width="2"`);
	s += poly(t, P.milk[0], LEAD(2.5)) + poly([[19, 17], [27, 15], [22, 30], [16, 28]], "#FFFFFF", 'fill-opacity="0.8"');
	return SV(56, 56, s + poly(o, "none", LEAD(5)));
}
// Slider groove and fill share one outline so the fill sits exactly inside the groove.
function sliderTrack() {
	const o = hexBar(3, 3, 294, 22, 10);
	return SV(300, 28, poly(o, P.smoke, LEAD(5)) + poly([[14, 19], [286, 19], [290, 23], [10, 23]], P.viewport));
}
function sliderFill(key) {
	const o = hexBar(3, 3, 294, 22, 10), c = P[key];
	return SV(300, 28, poly(o, c[0], LEAD(4)) + poly([[13, 6], [287, 6], [291, 12], [9, 12]], c[1], 'fill-opacity="0.75"'));
}
// Slider knob: upright hexagon gem, milk glass with an aqua heart so it reads on both groove and fill.
function sliderKnob() {
	const w = 44, h = 52, cx = w / 2, o = [[cx, 3], [w - 3, h * 0.27], [w - 3, h * 0.73], [cx, h - 3], [3, h * 0.73], [3, h * 0.27]], t = shrink(o, 0.5);
	let s = poly(o, P.milk[0], LEAD(5));
	for (let j = 0; j < 6; j++) s += poly([o[j], o[(j + 1) % 6], t[(j + 1) % 6], t[j]], [P.milk[1], P.milk[0], P.milk[2], P.milk[2], P.milk[0], P.milk[1]][j], `stroke="${P.lead}" stroke-opacity="0.35" stroke-width="2"`);
	return SV(w, h, s + poly(t, P.aqua[0], LEAD(2.5)) + poly(o, "none", LEAD(5)));
}
// Row plate: dark cut-glass pane behind each setting (Slice).
const rowPlate = () => SV(300, 60, poly(chamfer(3, 3, 294, 54, [12, 6, 12, 6]), P.smoke2, LEAD(4)) + poly([[16, 7], [286, 7], [283, 11], [13, 11]], P.viewport, 'fill-opacity="0.9"'));
// Section header rule: thin aqua came that runs from the header text to the column edge (Slice).
const sectionRule = () => SV(200, 16, poly(hexBar(2, 2, 196, 12, 6), P.aqua[0], LEAD(3)) + poly([[9, 5], [191, 5], [189, 8], [11, 8]], P.aqua[1], 'fill-opacity="0.7"'));

// Row icons: white glass shapes with lead outline, like icon/shop. No rounded panels; curves only where the
// symbol needs them (sound waves, eye).
const W = `fill="#FFFFFF" ${LEAD(4)}`, WL = (w = 5) => `fill="none" stroke="${P.lead}" stroke-width="${w + 4}" stroke-linejoin="round"`, WW = (w = 5) => `fill="none" stroke="#FFFFFF" stroke-width="${w}" stroke-linejoin="round"`;
const dual = (d, w = 5) => `<path d="${d}" ${WL(w)} stroke-linecap="round"/><path d="${d}" ${WW(w)} stroke-linecap="round"/>`;
const ICON = {
	master: `<polygon points="8,24 20,24 34,12 34,52 20,40 8,40" ${W}/>` + dual("M42 24 Q47 32 42 40") + dual("M49 17 Q58 32 49 47"),
	music: `<polygon points="22,14 54,6 54,14 22,22" ${W}/>` + dual("M24 18 L24 46", 6) + dual("M52 10 L52 40", 6) + `<polygon points="10,44 18,38 26,42 26,50 18,56 10,52" ${W}/><polygon points="38,38 46,32 54,36 54,44 46,50 38,46" ${W}/>`,
	sfx: `<polygon points="32,4 37,22 54,12 44,28 60,34 42,38 48,56 32,44 18,58 20,40 4,36 20,28 10,12 27,22" ${W}/><polygon points="32,20 36,30 44,32 36,36 32,44 28,36 20,32 28,30" fill="${P.amber[1]}" ${LEAD(2.5)}/>`,
	bot: dual("M32 6 L32 14", 4) + `<polygon points="28,4 36,4 36,10 28,10" fill="${P.ruby[0]}" ${LEAD(3)}/><polygon points="14,14 50,14 56,20 56,46 50,52 14,52 8,46 8,20" ${W}/><polygon points="17,24 27,24 27,34 17,34" fill="${P.aqua[0]}" ${LEAD(3)}/><polygon points="37,24 47,24 47,34 37,34" fill="${P.aqua[0]}" ${LEAD(3)}/><polygon points="20,41 44,41 44,45 20,45" fill="${P.lead}"/><polygon points="2,26 8,26 8,40 2,40" ${W}/><polygon points="56,26 62,26 62,40 56,40" ${W}/>`,
	autocast: `<polygon points="38,3 12,36 28,36 22,61 52,24 35,24" fill="${P.amber[1]}" ${LEAD(4)}/><polygon points="34,10 18,32 25,32" fill="#FFFFFF" fill-opacity="0.85"/>`,
	effects: `<polygon points="26,6 31,22 47,27 31,32 26,48 21,32 5,27 21,22" ${W}/><polygon points="48,34 51,43 60,46 51,49 48,58 45,49 36,46 45,43" ${W}/><polygon points="50,4 52,10 58,12 52,14 50,20 48,14 42,12 48,10" ${W}/>`,
	motion: `<polygon points="12,18 22,18 26,12 38,12 42,18 52,18 56,22 56,48 52,52 12,52 8,48 8,22" ${W}/><polygon points="32,24 40,28 42,36 38,44 32,46 24,44 20,36 24,28" fill="${P.aqua[0]}" ${LEAD(3)}/><polygon points="28,30 33,28 30,36 27,35" fill="#FFFFFF" fill-opacity="0.85"/>`,
	cosmetics: `<path d="M4 32 Q32 6 60 32 Q32 58 4 32 Z" ${W}/><polygon points="32,22 40,26 42,32 40,38 32,42 24,38 22,32 24,26" fill="${P.amethyst[0]}" ${LEAD(3)}/>` + dual("M10 54 L54 10", 6),
};

const assets = {};
const add = (name, svg) => { assets[name] = svg; };
seed = 23; add("window_settings", windowSvg(1260, 860, { band: 30, cut: [34, 16, 38, 18], colors: ["aqua", "aqua", "sapphire", "amethyst", "emerald"], pieces: 34 }));
add("toggle_on", toggleTrack(true));
add("toggle_off", toggleTrack(false));
add("toggle_knob", toggleKnob());
add("slider_track", sliderTrack());
add("slider_fill_aqua", sliderFill("aqua"));
add("slider_knob", sliderKnob());
add("row_plate", rowPlate());
add("section_rule", sectionRule());
for (const [k, body] of Object.entries(ICON)) add(`icon_${k}`, SV(64, 64, body));

for (const [name, svg] of Object.entries(assets)) {
	const svgPath = join(OUT, "svg", name + ".svg"), pngPath = join(OUT, "png", name + ".png");
	mkdirSync(dirname(svgPath), { recursive: true }); mkdirSync(dirname(pngPath), { recursive: true });
	writeFileSync(svgPath, svg);
	const png = resvg
		? new resvg.Resvg(svg, { fitTo: { mode: "zoom", value: SCALE }, background: "rgba(0,0,0,0)" }).render().asPng()
		: await sharp(Buffer.from(svg), { density: 72 * SCALE }).png().toBuffer();
	writeFileSync(pngPath, png);
}
console.log(`${Object.keys(assets).length} settings assets written to ${OUT}`);
