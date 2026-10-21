# Glass Clash logo

Stained Glass style (DECISIONS 49 palette): chunky letters split into jewel-glass panes with lead lines, a milk-glass rim, a 3D drop, a crack in the A and shards flying off the H. Nothing to edit by hand: re-run the generator.

| File | Use |
|---|---|
| `wordmark_<scheme>.png` (1600 px wide, transparent) | Thumbnails, loading screen, group banner, YouTube/TikTok |
| `icon_<scheme>_512.png` | Roblox game icon (upload size 512×512) |
| `icon_<scheme>_1024.png` | Large icon, social avatar |
| `svg/` | Vector sources |

Schemes: **jewel** (cyan/blue/violet GLASS + ruby/amber/emerald CLASH, the main one), **cool** (all blues and violets), **hot** (cyan GLASS + red CLASH).

Font: **Lilita One** (Juan Montoreano, SIL Open Font License, free for logos and commercial use). Taken from the npm package `@fontsource/lilita-one` (`files/lilita-one-latin-400-normal.woff`).

Regenerate:

```
npm i @resvg/resvg-js@2.6.2 opentype.js@1.3.4   (anywhere; point NODE_PATH at its node_modules)
NODE_PATH=<that>/node_modules node tools/marketing/logo.mjs <lilita-one .woff> assets/marketing/logo
```

The Roblox icon is cropped with rounded corners on some pages; everything important sits inside the frame, so it survives. Roblox loading-screen use: upload `wordmark_jewel.png` as a Decal/Image and show it in an ImageLabel with ScaleType Fit.
