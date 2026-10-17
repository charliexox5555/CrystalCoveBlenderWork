// Square prize-card frames for the shop's odds carousel (tile/prize_<rarity>, 240x240, PNG at 2x).
// Same window generator as the rest of the kit; kept separate so the kit script stays untouched.
// Run:  npm i @resvg/resvg-js && node tools/ui/prize_card.mjs
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import { windowSvg } from "./stained_glass.mjs";
const require = createRequire(import.meta.url);
const { Resvg } = require(require.resolve("@resvg/resvg-js", { paths: [process.cwd(), ...(process.env.NODE_PATH ?? "").split(":").filter(Boolean)] }));
const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "assets", "ui", "stained_glass");
const RARITY = { common: ["milk", "slate"], uncommon: ["emerald"], rare: ["sapphire", "aqua"], epic: ["amethyst"], legendary: ["amber"], mythic: ["ruby", "amber", "emerald", "sapphire", "amethyst", "aqua"] };
for (const [r, cols] of Object.entries(RARITY)) {
	const svg = windowSvg(240, 240, { band: 14, cut: [24, 10, 24, 10], colors: cols, pieces: 12, facets: 0 });
	const name = `tile/prize_${r}`;
	const svgPath = join(OUT, "svg", name + ".svg"), pngPath = join(OUT, "png", name + ".png");
	mkdirSync(dirname(svgPath), { recursive: true }); mkdirSync(dirname(pngPath), { recursive: true });
	writeFileSync(svgPath, svg);
	writeFileSync(pngPath, new Resvg(svg, { fitTo: { mode: "zoom", value: 2 }, background: "rgba(0,0,0,0)" }).render().asPng());
}
console.log("6 prize card frames written");
