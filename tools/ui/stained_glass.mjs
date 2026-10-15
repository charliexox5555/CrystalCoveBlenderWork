// Stained Glass UI kit generator (UI v0.5). Writes every UI piece as an editable SVG and a
// transparent PNG at 2x into assets/ui/stained_glass/. Same shapes as the Figma page
// "UI v0.5 — Stained Glass". Run:  npm i @resvg/resvg-js && node tools/ui/stained_glass.mjs
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
// Finds @resvg/resvg-js from the current folder or NODE_PATH.
const require = createRequire(import.meta.url);
const { Resvg } = require(require.resolve("@resvg/resvg-js", { paths: [process.cwd(), ...(process.env.NODE_PATH ?? "").split(":").filter(Boolean)] }));

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const OUT = join(ROOT, "assets", "ui", "stained_glass");
const SCALE = 2;

export const P = {
	lead: "#1F1830", smoke: "#261D3B", smoke2: "#332854", viewport: "#3B2F5E", kiln: "#3A1E22",
	ruby: ["#E23A55", "#FF8EA0", "#9E1D38"], amber: ["#F5A524", "#FFD98A", "#B26E0B"],
	emerald: ["#22B573", "#86EDB8", "#11703F"], sapphire: ["#2E6BE6", "#93BCFF", "#1A409C"],
	amethyst: ["#8B4FE0", "#CDAAFF", "#57299F"], aqua: ["#1FC2D3", "#9BF3F8", "#0F7C88"],
	milk: ["#EEE7D9", "#FFFFFF", "#B9AE99"], slate: ["#7C7896", "#B7B3CC", "#4F4B69"],
};
let seed = 11;
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

// Stained-glass window: mosaic border band of jewel pieces + smoky inner pane.
export function windowSvg(w, h, o = {}) {
	const band = o.band ?? 26, c = o.cut ?? [34, 16, 38, 18], cols = o.colors ?? ["ruby", "amber", "emerald", "sapphire", "amethyst", "aqua"];
	const outer = chamfer(4, 4, w - 8, h - 8, c), ic = c.map((v) => Math.max(6, v - band * 0.45)), inner = chamfer(4 + band, 4 + band, w - 8 - 2 * band, h - 8 - 2 * band, ic);
	const Lo = along(outer), Li = along(inner), n = o.pieces ?? Math.max(6, Math.round((w + h) / 75));
	const ts = [0]; for (let i = 1; i < n; i++) ts.push(i / n + (rnd() - 0.5) * 0.55 / n); ts.push(1);
	let s = poly(outer, P.lead);
	for (let i = 0; i < n; i++) {
		const a = arc(outer, Lo, ts[i], ts[i + 1]), b = arc(inner, Li, ts[i], ts[i + 1]).reverse(), pc = a.concat(b), col = P[cols[Math.floor(rnd() * cols.length)]];
		s += poly(pc, col[0], LEAD(5)) + poly(shrink(pc, 0.45), col[1], 'fill-opacity="0.35"');
	}
	s += poly(inner, o.pane ?? P.smoke, LEAD(6));
	for (let k = 0; k < (o.facets ?? 3); k++) { const t = rnd(), p1 = at(inner, Li, t), p2 = at(inner, Li, (t + 0.3 + rnd() * 0.35) % 1); s += `<line x1="${p1[0].toFixed(1)}" y1="${p1[1].toFixed(1)}" x2="${p2[0].toFixed(1)}" y2="${p2[1].toFixed(1)}" stroke="${P.smoke2}" stroke-width="4"/>`; }
	return SV(w, h, s + poly(outer, "none", LEAD(8)));
}
// Cut-gem baguette: buttons, tabs, banners.
export function gemSvg(w, h, key, dim = false) {
	const c = P[key], k = Math.min(h * 0.34, w * 0.2), i = 8;
	const o = [[k, 3], [w - k, 3], [w - 3, h / 2], [w - k, h - 3], [k, h - 3], [3, h / 2]], t = [[k + i, i + 3], [w - k - i, i + 3], [w - i - 10, h / 2], [w - k - i, h - i - 3], [k + i, h - i - 3], [i + 10, h / 2]];
	let s = poly(o, c[2], LEAD(5)) + poly([o[0], o[1], t[1], t[0]], c[1]) + poly([o[1], o[2], t[2], t[1]], c[0]) + poly([o[5], o[0], t[0], t[5]], c[0]);
	s += poly(t, c[0], `stroke="${P.lead}" stroke-opacity="0.45" stroke-width="2.5" stroke-linejoin="round"`);
	s += poly([[k + 16, i + 7], [k + 40, i + 7], [k + 24, h - i - 7], [k + 6, h - i - 7]], "#FFFFFF", 'fill-opacity="0.3"') + poly(o, "none", LEAD(6));
	if (dim) s += poly(o, P.lead, 'fill-opacity="0.5"');
	return SV(w, h, s);
}
// Faceted hexagon gem for the side buttons.
export function hexSvg(w, h, key, iconSvg = "") {
	const c = P[key], cx = w / 2, o = [[cx, 3], [w - 3, h * 0.25], [w - 3, h * 0.75], [cx, h - 3], [3, h * 0.75], [3, h * 0.25]], tb = shrink(o, 0.62);
	let s = poly(o, c[0], LEAD(5));
	for (let j = 0; j < 6; j++) s += poly([o[j], o[(j + 1) % 6], tb[(j + 1) % 6], tb[j]], [c[1], c[0], c[2], c[2], c[0], c[1]][j], LEAD(2.5));
	s += poly(tb, c[0], LEAD(3)) + poly([[cx - 30, h * 0.24], [cx - 12, h * 0.2], [cx - 40, h * 0.62], [cx - 52, h * 0.56]], "#FFFFFF", 'fill-opacity="0.25"') + poly(o, "none", LEAD(7));
	return SV(w, h, s + iconSvg);
}
const pane = (w, h, fill, c = [22, 10, 24, 10]) => SV(w, h, poly(chamfer(3, 3, w - 6, h - 6, c), fill, LEAD(5)));
const plaque = (w, h, fill = P.milk[0]) => SV(w, h, poly([[h * 0.27, 3], [w - h * 0.27, 3], [w - 3, h / 2], [w - h * 0.27, h - 3], [h * 0.27, h - 3], [3, h / 2]], fill, LEAD(5)) + poly([[h * 0.3, 7], [w - h * 0.3, 7], [w - h * 0.38, h * 0.32], [h * 0.38, h * 0.32]], "#FFFFFF", 'fill-opacity="0.55"'));
const tag = (key) => SV(150, 40, poly([[14, 3], [147, 3], [136, 37], [3, 37]], P[key][0], LEAD(4)) + poly([[17, 6], [70, 6], [66, 16], [13, 16]], P[key][1], 'fill-opacity="0.5"'));
const ICON = {
	shop: '<g transform="translate(43,40)"><path d="M14 26h36l-3 30H17z" fill="#FFFFFF" stroke="#1F1830" stroke-width="4" stroke-linejoin="round"/><path d="M23 26v-6a9 9 0 0 1 18 0v6" fill="none" stroke="#1F1830" stroke-width="8"/><path d="M23 26v-6a9 9 0 0 1 18 0v6" fill="none" stroke="#FFFFFF" stroke-width="4"/></g>',
	inventory: '<g transform="translate(43,40)"><path d="M32 6l24 12v28L32 58 8 46V18z" fill="#FFFFFF" stroke="#1F1830" stroke-width="4" stroke-linejoin="round"/><path d="M8 18l24 12 24-12M32 30v28" fill="none" stroke="#1F1830" stroke-width="4" stroke-linejoin="round"/></g>',
};
const heartP = "M24 42 L7 25 C2 20 2 12 8 8.5 C13.6 5.4 20 7.2 24 12.6 C28 7.2 34.4 5.4 40 8.5 C46 12 46 20 41 25 Z";
const RARITY = { common: ["milk", "slate"], uncommon: ["emerald"], rare: ["sapphire", "aqua"], epic: ["amethyst"], legendary: ["amber"], mythic: ["ruby", "amber", "emerald", "sapphire", "amethyst", "aqua"] };
const RARITY_MAIN = { common: "milk", uncommon: "emerald", rare: "sapphire", epic: "amethyst", legendary: "amber", mythic: "ruby" };

const assets = {};
const add = (name, svg) => { assets[name] = svg; };
for (const k of ["emerald", "amber", "sapphire", "ruby", "amethyst", "aqua"]) {
	add(`button/gem_${k}`, gemSvg(300, 86, k));
	add(`banner/power_${k}`, gemSvg(600, 110, k));
}
add("button/gem_play", gemSvg(520, 130, "emerald"));
for (const k of ["aqua", "ruby", "amethyst", "amber"]) { add(`tab/tab_${k}_active`, gemSvg(240, 70, k)); add(`tab/tab_${k}_idle`, gemSvg(240, 70, k, true)); }
// Buttons are plain glass; icons and text are separate so they can be placed in Studio.
for (const k of ["amber", "sapphire", "emerald", "ruby", "amethyst", "aqua"]) add(`hud/hex_${k}`, hexSvg(150, 170, k));
add("icon/shop", SV(64, 64, ICON.shop.replace('transform="translate(43,40)"', "")));
add("icon/inventory", SV(64, 64, ICON.inventory.replace('transform="translate(43,40)"', "")));
add("hud/label_plaque", plaque(150, 44));
add("hud/currency_plaque", SV(230, 58, poly([[10, 3], [218, 3], [227, 29], [218, 55], [10, 55], [3, 29]], P.milk[0], LEAD(5)) + poly([[12, 7], [214, 7], [218, 17], [16, 17]], "#FFFFFF", 'fill-opacity="0.6"')));
add("icon/coin", SV(74, 74, '<g transform="scale(1.156)"><polygon points="20,4 44,4 60,20 60,44 44,60 20,60 4,44 4,20" fill="#F5A524" stroke="#1F1830" stroke-width="4" stroke-linejoin="round"/><polygon points="24,14 40,14 50,24 50,40 40,50 24,50 14,40 14,24" fill="#FFD98A" stroke="#B26E0B" stroke-width="2.5"/><polygon points="22,18 30,18 20,36 16,32" fill="#FFFFFF" fill-opacity="0.6"/></g>'));
add("icon/marble", SV(74, 74, '<g transform="scale(1.156)"><circle cx="32" cy="32" r="28" fill="#1FC2D3" stroke="#1F1830" stroke-width="4"/><path d="M8 36c10-14 22 6 48-6-4 16-16 26-30 24C16 52 10 46 8 36z" fill="#8B4FE0"/><circle cx="22" cy="20" r="7" fill="#FFFFFF" fill-opacity="0.75"/></g>'));
add("icon/heart_full", SV(48, 48, `<path d="${heartP}" fill="${P.ruby[0]}" ${LEAD(4)}/><polygon points="10,12 18,9.5 24,14 14,22" fill="${P.ruby[1]}" fill-opacity="0.8"/><path d="M24 12.6 L24 42 M24 26 L41 25 M24 26 L7 25" stroke="${P.ruby[2]}" stroke-width="2"/>`));
add("icon/heart_broken", SV(48, 48, `<path d="${heartP}" fill="${P.slate[2]}" ${LEAD(4)}/><path d="M24 12 L20 20 L27 27 L22 34 L24 42" fill="none" stroke="#E9E3F2" stroke-width="5" stroke-linejoin="round"/>`));
add("button/close_diamond", SV(80, 80, poly([[40, 3], [77, 40], [40, 77], [3, 40]], P.ruby[0], LEAD(5)) + poly([[40, 3], [77, 40], [40, 40]], P.ruby[1], 'fill-opacity="0.6"') + poly([[40, 40], [40, 77], [3, 40]], P.ruby[2], 'fill-opacity="0.6"')));
add("icon/close_x", SV(40, 40, '<path d="M8 8L32 32M32 8L8 32" stroke="#1F1830" stroke-width="10" stroke-linecap="round"/><path d="M8 8L32 32M32 8L8 32" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>'));
for (const k of ["aqua", "amber", "amethyst", "ruby", "emerald", "sapphire", "milk", "slate"]) add(`tag/tag_${k}`, tag(k));
for (const [r, cols] of Object.entries(RARITY)) { seed = 31; add(`tile/tile_${r}`, windowSvg(200, 240, { band: 14, cut: [22, 10, 24, 10], colors: cols, pieces: 10, facets: 2 })); }
add("tile/name_plaque", plaque(176, 44));
add("tile/selected_outline", SV(216, 256, poly(chamfer(4, 4, 208, 248, [26, 12, 28, 12]), "none", 'stroke="#FFFFFF" stroke-width="6" stroke-linejoin="round"')));
for (const [r, cols] of Object.entries(RARITY)) { seed = 40 + r.length * 7; add(`card/card_${r}`, windowSvg(460, 620, { band: 22, colors: cols, pieces: 14, cut: [40, 18, 44, 20] })); }
add("card/selected_outline", SV(480, 640, poly(chamfer(4, 4, 472, 632, [46, 22, 50, 24]), "none", 'stroke="#FFFFFF" stroke-width="6" stroke-linejoin="round"')));
seed = 9 * 13; add("panel/window_inventory", windowSvg(1560, 880, { band: 30, pieces: 40 }));
seed = 4 * 13; add("panel/window_shop", windowSvg(1700, 940, { band: 30, pieces: 44 }));
for (const k of ["sapphire", "amber", "aqua", "ruby", "amethyst", "emerald"]) add(`panel/title_${k}`, SV(380, 96, poly([[30, 4], [350, 4], [376, 48], [350, 92], [30, 92], [4, 48]], P[k][0], LEAD(6)) + poly([[30, 4], [350, 4], [340, 24], [40, 24]], P[k][1], 'fill-opacity="0.7"')));
add("panel/pane_dark", pane(400, 300, P.smoke2));
add("panel/pane_viewport", pane(400, 200, P.viewport, [18, 8, 18, 8]));
for (const r of Object.keys(RARITY)) add(`panel/odds_row_${r}`, SV(428, 62, poly([[12, 3], [425, 3], [425, 59], [3, 59], [3, 12]], P.viewport, LEAD(4)) + poly([[12, 3], [48, 3], [40, 59], [3, 59], [3, 12]], P[RARITY_MAIN[r]][0], LEAD(4))));
add("bar/stat_track", SV(300, 24, poly([[8, 2], [298, 2], [292, 22], [2, 22]], P.lead)));
for (const k of ["amber", "emerald", "aqua"]) add(`bar/stat_fill_${k}`, SV(300, 24, poly([[8, 2], [298, 2], [292, 22], [2, 22]], P[k][0], LEAD(3))));
seed = 77; add("kiln/hero_window", windowSvg(1080, 380, { band: 18, colors: ["amber", "ruby"], pieces: 16, pane: P.kiln, cut: [26, 12, 28, 12] }));
add("kiln/glow", SV(330, 300, '<defs><radialGradient id="g"><stop offset="0" stop-color="#FFE08A"/><stop offset="0.55" stop-color="#F26B1D"/><stop offset="1" stop-color="#3A1E22" stop-opacity="0"/></radialGradient></defs><polygon points="30,10 300,10 320,150 300,290 30,290 10,150" fill="url(#g)"/>'));

for (const [name, svg] of Object.entries(assets)) {
	const svgPath = join(OUT, "svg", name + ".svg"), pngPath = join(OUT, "png", name + ".png");
	mkdirSync(dirname(svgPath), { recursive: true }); mkdirSync(dirname(pngPath), { recursive: true });
	writeFileSync(svgPath, svg);
	writeFileSync(pngPath, new Resvg(svg, { fitTo: { mode: "zoom", value: SCALE }, background: "rgba(0,0,0,0)" }).render().asPng());
}
console.log(`${Object.keys(assets).length} assets written to ${OUT}`);
