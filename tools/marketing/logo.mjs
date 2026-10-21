// Glass Clash logo generator (Stained Glass style, decision 49 palette).
// Letters are real font outlines (opentype.js) split into jewel-glass panes with lead lines,
// a dark lead rim, a milk-glass outer rim, a 3D drop and a crack through CLASH.
// Usage: NODE_PATH=<dir with opentype.js + @resvg/resvg-js> node tools/marketing/logo.mjs <font.woff> <outDir> [sheet]
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const lookup = [process.cwd(), ...(process.env.NODE_PATH || "").split(path.delimiter).filter(Boolean)];
const need = (name) => require(require.resolve(name, { paths: lookup }));
const opentype = need("opentype.js");
const { Resvg } = need("@resvg/resvg-js");

const LEAD = "#1F1830";
const SMOKE = "#261D3B";
const JEWEL = {
	ruby: "#E23A55",
	amber: "#F5A524",
	emerald: "#22B573",
	aqua: "#1FC2D3",
	sapphire: "#2E6BE6",
	amethyst: "#8B4FE0",
	milk: "#EEE7D9",
};

// Colour schemes: one jewel per letter, GLASS then CLASH.
export const SCHEMES = {
	jewel: {
		glass: ["aqua", "sapphire", "amethyst", "aqua", "sapphire"],
		clash: ["ruby", "amber", "emerald", "ruby", "amber"],
		rim: JEWEL.milk,
	},
	cool: {
		glass: ["aqua", "aqua", "sapphire", "aqua", "aqua"],
		clash: ["amethyst", "sapphire", "amethyst", "sapphire", "amethyst"],
		rim: JEWEL.milk,
	},
	hot: {
		glass: ["aqua", "aqua", "aqua", "aqua", "aqua"],
		clash: ["ruby", "ruby", "amber", "ruby", "ruby"],
		rim: JEWEL.milk,
	},
};

function rng(seed) {
	let s = seed >>> 0;
	return () => {
		s = (s * 1664525 + 1013904223) >>> 0;
		return s / 4294967296;
	};
}

function shade(hex, f) {
	const n = parseInt(hex.slice(1), 16);
	const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) =>
		Math.round(f >= 0 ? v + (255 - v) * f : v * (1 + f))
	);
	return "#" + c.map((v) => v.toString(16).padStart(2, "0")).join("");
}

// Split a convex polygon by the line through p with direction d.
function split(poly, p, d) {
	const side = (q) => (q[0] - p[0]) * d[1] - (q[1] - p[1]) * d[0];
	const a = [];
	const b = [];
	for (let i = 0; i < poly.length; i++) {
		const q = poly[i];
		const r = poly[(i + 1) % poly.length];
		const sq = side(q);
		const sr = side(r);
		(sq >= 0 ? a : b).push(q);
		if (sq * sr < 0) {
			const t = sq / (sq - sr);
			const x = [q[0] + (r[0] - q[0]) * t, q[1] + (r[1] - q[1]) * t];
			a.push(x);
			b.push(x);
		}
	}
	return [a, b].filter((x) => x.length >= 3);
}

const pts = (poly) => poly.map((q) => q.map((v) => v.toFixed(1)).join(",")).join(" ");

// Lay out one word as glyph records (path data, box, centre).
function word(font, text, size, x0, y0, spacing) {
	const out = [];
	let x = x0;
	for (let i = 0; i < text.length; i++) {
		const g = font.charToGlyph(text[i]);
		const p = g.getPath(x, y0, size);
		const bb = p.getBoundingBox();
		out.push({ ch: text[i], d: p.toPathData(2), bb });
		x += g.advanceWidth * (size / font.unitsPerEm) + spacing;
		if (i < text.length - 1) {
			x += font.getKerningValue(g, font.charToGlyph(text[i + 1])) * (size / font.unitsPerEm);
		}
	}
	return out;
}

function boxOf(glyphs) {
	const b = { x1: Infinity, y1: Infinity, x2: -Infinity, y2: -Infinity };
	for (const g of glyphs) {
		b.x1 = Math.min(b.x1, g.bb.x1);
		b.y1 = Math.min(b.y1, g.bb.y1);
		b.x2 = Math.max(b.x2, g.bb.x2);
		b.y2 = Math.max(b.y2, g.bb.y2);
	}
	return b;
}

// The wordmark as an SVG group, centred on (cx, cy), roughly `width` wide.
export function wordmark(font, opts) {
	const { cx, cy, width, scheme, seed = 7, id = "wm" } = opts;
	const S = SCHEMES[scheme];
	const rnd = rng(seed);
	const size = 200;
	const spacing = 18;
	let top = word(font, "GLASS", size, 0, 0, spacing);
	let bottom = word(font, "CLASH", size, 0, 0, spacing);
	const tb = boxOf(top);
	const bb = boxOf(bottom);
	// Scale both lines to the same width so the stack reads as a block.
	const lineW = Math.max(tb.x2 - tb.x1, bb.x2 - bb.x1);
	const capH = tb.y2 - tb.y1;
	const gap = capH * 0.12;
	const sTop = lineW / (tb.x2 - tb.x1);
	const sBot = lineW / (bb.x2 - bb.x1);
	const scale = width / lineW;
	const lines = [
		{ glyphs: top, box: tb, s: sTop, y: 0, colors: S.glass, tilt: -1 },
		{ glyphs: bottom, box: bb, s: sBot, y: capH * sTop + gap, colors: S.clash, tilt: 1 },
	];
	const totalH = capH * sTop + gap + (bb.y2 - bb.y1) * sBot;

	const defs = [];
	const drop = [];
	const rimOuter = [];
	const rimLead = [];
	const fills = [];
	const extras = [];
	let n = 0;
	for (const [li, line] of lines.entries()) {
		const { box, s } = line;
		const lineH = (box.y2 - box.y1) * s;
		for (const [gi, g] of line.glyphs.entries()) {
			n++;
			const gid = `${id}g${n}`;
			// Letter transform: fit the line, then a small playful bounce per letter.
			const lcx = (g.bb.x1 + g.bb.x2) / 2;
			const lcy = (g.bb.y1 + g.bb.y2) / 2;
			const rot = (gi % 2 === 0 ? -1 : 1) * (2 + rnd() * 2.5) * (li === 0 ? 1 : -1);
			const bob = (gi % 2 === 0 ? -1 : 1) * capH * 0.025;
			const tx = (lcx - box.x1) * s - lineW / 2;
			const ty = line.y + (lcy - box.y1) * s - totalH / 2 + bob;
			const T = `translate(${tx.toFixed(1)} ${ty.toFixed(1)}) rotate(${rot.toFixed(2)}) scale(${s.toFixed(4)}) translate(${-lcx.toFixed(1)} ${-lcy.toFixed(1)})`;
			defs.push(`<path id="${gid}" d="${g.d}"/><clipPath id="${gid}c"><use href="#${gid}"/></clipPath>`);
			const use = (attrs) => `<use href="#${gid}" transform="${T}" ${attrs}/>`;
			drop.push(`<g transform="translate(0 ${(capH * 0.07).toFixed(1)})">${use(`fill="${SMOKE}" stroke="${SMOKE}" stroke-width="48" stroke-linejoin="round"`)}</g>`);
			rimOuter.push(use(`fill="${S.rim}" stroke="${S.rim}" stroke-width="48" stroke-linejoin="round"`));
			rimLead.push(use(`fill="${LEAD}" stroke="${LEAD}" stroke-width="22" stroke-linejoin="round"`));

			// Glass panes: split the glyph box by 2-3 random lines, clip to the glyph.
			const base = JEWEL[line.colors[gi]];
			const pad = 4;
			let panes = [
				[
					[g.bb.x1 - pad, g.bb.y1 - pad],
					[g.bb.x2 + pad, g.bb.y1 - pad],
					[g.bb.x2 + pad, g.bb.y2 + pad],
					[g.bb.x1 - pad, g.bb.y2 + pad],
				],
			];
			const cuts = 1 + Math.floor(rnd() * 2);
			for (let c = 0; c < cuts; c++) {
				const p = [g.bb.x1 + (0.25 + rnd() * 0.5) * (g.bb.x2 - g.bb.x1), g.bb.y1 + (0.2 + rnd() * 0.6) * (g.bb.y2 - g.bb.y1)];
				const a = (c / cuts) * Math.PI + rnd() * 0.9;
				const d = [Math.cos(a), Math.sin(a)];
				panes = panes.flatMap((poly) => split(poly, p, d));
			}
			const tones = [0.0, 0.18, -0.16, 0.3, -0.08, 0.1];
			const paneSvg = panes
				.map((poly, k) => `<polygon points="${pts(poly)}" fill="${shade(base, tones[k % tones.length])}" stroke="${LEAD}" stroke-width="6" stroke-linejoin="round"/>`)
				.join("");
			// Gloss: a soft light band across the top and a small glint.
			const h = g.bb.y2 - g.bb.y1;
			const w = g.bb.x2 - g.bb.x1;
			const gloss = `<polygon points="${pts([
				[g.bb.x1 - 10, g.bb.y1 - 10],
				[g.bb.x2 + 10, g.bb.y1 - 10],
				[g.bb.x2 + 10, g.bb.y1 + h * 0.22],
				[g.bb.x1 - 10, g.bb.y1 + h * 0.36],
			])}" fill="#FFFFFF" opacity="0.28"/>`;
			const glint = `<ellipse cx="${(g.bb.x1 + w * 0.3).toFixed(1)}" cy="${(g.bb.y1 + h * 0.16).toFixed(1)}" rx="${(w * 0.09).toFixed(1)}" ry="${(h * 0.035).toFixed(1)}" fill="#FFFFFF" opacity="0.85" transform="rotate(-25 ${(g.bb.x1 + w * 0.3).toFixed(1)} ${(g.bb.y1 + h * 0.16).toFixed(1)})"/>`;
			fills.push(`<g transform="${T}"><g clip-path="url(#${gid}c)">${paneSvg}${gloss}${glint}</g></g>`);

			// The crack: a jagged white-edged fracture across the A of CLASH, and shards off the H.
			if (li === 1 && g.ch === "A") {
				const ix = g.bb.x1 + w * 0.27;
				const iy = g.bb.y1 + h * 0.74;
				const rays = [];
				for (let k = 0; k < 6; k++) {
					const a = (k / 6) * Math.PI * 2 + rnd() * 0.5;
					const L = h * (0.16 + rnd() * 0.14);
					const m = [ix + Math.cos(a + 0.25) * L * 0.5, iy + Math.sin(a + 0.25) * L * 0.5];
					rays.push(`M${ix.toFixed(1)} ${iy.toFixed(1)} L${m[0].toFixed(1)} ${m[1].toFixed(1)} L${(ix + Math.cos(a) * L).toFixed(1)} ${(iy + Math.sin(a) * L).toFixed(1)}`);
				}
				const d = rays.join(" ");
				fills.push(`<g transform="${T}"><g clip-path="url(#${gid}c)"><path d="${d}" fill="none" stroke="${LEAD}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/><path d="${d}" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" stroke-linejoin="miter"/></g></g>`);
			}
			if (li === 1 && gi === line.glyphs.length - 1) {
				// Shards flying off the right of the last letter (screen space).
				const ex = tx + (g.bb.x2 - lcx) * s * scale;
				const shardCols = [line.colors[gi], "amber", "milk", line.colors[gi - 1]];
				for (let k = 0; k < 4; k++) {
					const sx = tx + w * s * (0.6 + k * 0.13);
					const sy = ty - h * s * (0.32 - k * 0.2) + (rnd() - 0.5) * 12;
					const r = (22 - k * 3.5) * (1 + rnd() * 0.3);
					const tri = [0, 1, 2].map((j) => {
						const a = rnd() * 0.6 + (j * 2 * Math.PI) / 3;
						const rr = r * (0.7 + rnd() * 0.6);
						return [sx + Math.cos(a) * rr, sy + Math.sin(a) * rr];
					});
					extras.push(`<polygon points="${pts(tri)}" fill="${JEWEL[shardCols[k]]}" stroke="${LEAD}" stroke-width="7" stroke-linejoin="round"/>`);
				}
				void ex;
			}
		}
	}
	// Sparkles near GLASS.
	const star = (x, y, r, col) =>
		`<path d="M${x} ${y - r} Q${x} ${y} ${x + r} ${y} Q${x} ${y} ${x} ${y + r} Q${x} ${y} ${x - r} ${y} Q${x} ${y} ${x} ${y - r}Z" fill="${col}" stroke="${LEAD}" stroke-width="5" stroke-linejoin="round"/>`;
	extras.push(star(-lineW / 2 - 18, -totalH / 2 + 10, 34, "#FFFFFF"));
	extras.push(star(lineW / 2 - 40, -totalH / 2 - 26, 22, JEWEL.amber));

	return {
		defs: defs.join(""),
		body: `<g transform="translate(${cx} ${cy}) scale(${scale.toFixed(4)})">${drop.join("")}${rimOuter.join("")}${rimLead.join("")}${fills.join("")}${extras.join("")}</g>`,
		aspect: lineW / totalH,
	};
}

// Square game icon: a stained-glass sunburst window behind the stacked wordmark.
export function iconSvg(font, scheme, seed = 11) {
	const W = 1024;
	const rnd = rng(seed);
	const cols = ["sapphire", "amethyst", "aqua", "sapphire", "amethyst", "aqua", "sapphire", "amethyst"];
	const rays = [];
	const N = 16;
	for (let i = 0; i < N; i++) {
		const a0 = (i / N) * Math.PI * 2 + 0.1;
		const a1 = ((i + 1) / N) * Math.PI * 2 + 0.1;
		const R = 900;
		const cxy = [W / 2, W * 0.52];
		const p = [cxy, [cxy[0] + Math.cos(a0) * R, cxy[1] + Math.sin(a0) * R], [cxy[0] + Math.cos(a1) * R, cxy[1] + Math.sin(a1) * R]];
		const col = shade(JEWEL[cols[i % cols.length]], -0.5 + rnd() * 0.12);
		rays.push(`<polygon points="${pts(p)}" fill="${col}" stroke="${LEAD}" stroke-width="10"/>`);
	}
	const halo = `<radialGradient id="halo"><stop offset="0" stop-color="${JEWEL.aqua}" stop-opacity="0.75"/><stop offset="1" stop-color="${JEWEL.aqua}" stop-opacity="0"/></radialGradient><circle cx="${W / 2}" cy="${W * 0.52}" r="470" fill="url(#halo)"/>`;
	const wm = wordmark(font, { cx: W / 2, cy: W * 0.52, width: W * 0.84, scheme, id: "ic" });
	const frame = `<rect x="18" y="18" width="${W - 36}" height="${W - 36}" fill="none" stroke="${LEAD}" stroke-width="36"/>`;
	return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${W}" viewBox="0 0 ${W} ${W}"><defs>${wm.defs}</defs><rect width="${W}" height="${W}" fill="${SMOKE}"/>${rays.join("")}${halo}${wm.body}${frame}</svg>`;
}

export function wordmarkSvg(font, scheme) {
	const W = 1600;
	const probe = wordmark(font, { cx: 0, cy: 0, width: 1300, scheme });
	const H = Math.round(1300 / probe.aspect + 300);
	const wm = wordmark(font, { cx: W / 2, cy: H / 2, width: 1240, scheme });
	return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs>${wm.defs}</defs>${wm.body}</svg>`;
}

function png(svg, file, width) {
	const r = new Resvg(svg, { fitTo: { mode: "width", value: width }, background: "rgba(0,0,0,0)" });
	fs.writeFileSync(file, r.render().asPng());
}

const [fontFile, outDir, mode] = process.argv.slice(2);
if (fontFile && outDir) {
	const font = opentype.parse(fs.readFileSync(fontFile).buffer.slice(0));
	fs.mkdirSync(outDir, { recursive: true });
	if (mode === "sheet") {
		png(wordmarkSvg(font, "jewel"), path.join(outDir, path.basename(fontFile).split("-latin")[0] + ".png"), 800);
	} else {
		fs.mkdirSync(path.join(outDir, "svg"), { recursive: true });
		for (const scheme of Object.keys(SCHEMES)) {
			const wm = wordmarkSvg(font, scheme);
			const ic = iconSvg(font, scheme);
			fs.writeFileSync(path.join(outDir, "svg", `wordmark_${scheme}.svg`), wm);
			fs.writeFileSync(path.join(outDir, "svg", `icon_${scheme}.svg`), ic);
			png(wm, path.join(outDir, `wordmark_${scheme}.png`), 1600);
			png(ic, path.join(outDir, `icon_${scheme}_512.png`), 512);
			png(ic, path.join(outDir, `icon_${scheme}_1024.png`), 1024);
		}
	}
}
