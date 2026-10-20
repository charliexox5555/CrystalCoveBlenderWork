// Art for the CodesScreen (top bar "Codes" window): a small mosaic window and a dark inset code field.
// Same look as tools/ui/stained_glass.mjs (jewel mosaic border, lead lines, chamfered corners); the shape helpers
// are copied from it because importing that file would regenerate the whole kit.
//   npm i @resvg/resvg-js && node tools/ui/codes_art.mjs
// writes svg/ and png/ (2x) to assets/ui/screens/codes/. build() also runs in a browser (no file access) so the
// SVGs can be rasterised with a canvas when Node is not installed.

const P = {
	lead: "#1F1830", smoke: "#261D3B", smoke2: "#332854",
	ruby: ["#E23A55", "#FF8EA0", "#9E1D38"], amber: ["#F5A524", "#FFD98A", "#B26E0B"],
	emerald: ["#22B573", "#86EDB8", "#11703F"], sapphire: ["#2E6BE6", "#93BCFF", "#1A409C"],
	amethyst: ["#8B4FE0", "#CDAAFF", "#57299F"], aqua: ["#1FC2D3", "#9BF3F8", "#0F7C88"],
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

function windowSvg(w, h, o = {}) {
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

// Dark inset glass field: sunk below the window pane (darker fill, shadow along the top edge, a lit lip along the
// bottom edge) and held by lead. 520x100 -> drawn Fit at aspect 5.2. `focus` swaps the inner ring for aqua.
function fieldSvg(focus) {
	const w = 520, h = 100, c = [14, 6, 14, 6], fill = "#15102A";
	let s = poly(chamfer(2, 2, w - 4, h - 4, c), P.lead);
	s += poly(chamfer(7, 7, w - 14, h - 14, c.map((v) => v - 3)), fill, focus ? `stroke="${P.aqua[0]}" stroke-width="4" stroke-linejoin="round"` : 'stroke="#2E2450" stroke-width="2" stroke-linejoin="round"');
	s += `<line x1="22" y1="13" x2="${w - 14}" y2="13" stroke="#0B0817" stroke-width="6" stroke-linecap="round" opacity="0.85"/>`;
	s += `<line x1="18" y1="${h - 13}" x2="${w - 22}" y2="${h - 13}" stroke="${focus ? P.aqua[2] : "#4B3C7A"}" stroke-width="3" stroke-linecap="round" opacity="0.9"/>`;
	s += poly(chamfer(2, 2, w - 4, h - 4, c), "none", LEAD(4));
	return SV(w, h, s);
}

export function build() {
	seed = 23;
	return {
		"window_codes": windowSvg(900, 560, { band: 34, cut: [30, 14, 32, 16], pieces: 30, facets: 2 }),
		"field_inset": fieldSvg(false),
		"field_focus": fieldSvg(true),
	};
}

async function main() {
	const { writeFileSync, mkdirSync } = await import("node:fs");
	const { dirname, join } = await import("node:path");
	const { fileURLToPath } = await import("node:url");
	const { createRequire } = await import("node:module");
	const require = createRequire(import.meta.url);
	const { Resvg } = require(require.resolve("@resvg/resvg-js", { paths: [process.cwd(), ...(process.env.NODE_PATH ?? "").split(":").filter(Boolean)] }));
	const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "assets", "ui", "screens", "codes");
	for (const [name, svg] of Object.entries(build())) {
		mkdirSync(join(OUT, "svg"), { recursive: true }); mkdirSync(join(OUT, "png"), { recursive: true });
		writeFileSync(join(OUT, "svg", name + ".svg"), svg);
		writeFileSync(join(OUT, "png", name + ".png"), new Resvg(svg, { fitTo: { mode: "zoom", value: 2 }, background: "rgba(0,0,0,0)" }).render().asPng());
	}
	console.log("written to " + OUT);
}
if (typeof process !== "undefined" && process.versions?.node && process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop())) await main();
