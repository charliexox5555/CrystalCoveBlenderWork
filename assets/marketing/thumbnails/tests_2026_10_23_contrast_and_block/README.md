# Glass vs Glass — contrast and ability tests
23 October 2026. Three finished ad thumbnails, created using the built-in imagegen tool from saved original game assets. [First results](EARLY_RESULTS.md): Cracked Close Call 18/644 (2.80%), Lid Block 9/648 (1.39%), Cast Contrast 5/603 (0.83%). Close Call is the provisional leader; attributed plays are outside the crop.

## Ready files

| File | Hook | Purpose |
|---|---|---|
| [01_cast_contrast.png](01_cast_contrast.png) | Time the cast | Presentation comparison with the original Cast Now: clean blue background, stronger transparent-glass definition, same bottle/jar and timing cue. |
| [02_cracked_close_call.png](02_cracked_close_call.png) | Will it survive the next hit? | Large anxious jar, visible fracture/chip and an incoming suspended Prism Blade. No text; simple threat/fragility story. |
| [03_lid_block.png](03_lid_block.png) | Block the hit | Jam's real raised-lid shield catches the incoming sword. One short word and one clear contact point. |

All three are native **1672 × 941 opaque RGB PNGs**, 1.61–1.67 MB. Exact sizes/hashes: [FILE_QA.json](FILE_QA.json). [320/180px preview](PREVIEW.html). [Exact prompts and generated sources](PROMPTS.md).

## What changed and why

The creator reports another ad credit spent and CTR declining, without updated exact per-creative counts. Do not present the previous Cast 12/556 snapshot as its current rate, invent new percentages or diagnose fatigue from this alone.

The previous audit identified pale subjects against bright sky/wood and competing scenery as visual hypotheses. This pack gives the glass stronger tinted edges, a clean blue backdrop and larger, clearer interaction. Cast retains the existing promise. The two jar/sword stories test fragility and a readable defensive action. Faces in 02/03 are exaggerated marketing expressions; the underlying game assets are normally faceless. These are not untouched captures or direct Blender renders.

The shield is grounded in the current source: Jam uses shield / Lid Shield; HeroPowers raises the original lid toward the opponent and warms it toward gold. PowerFX/Kits adds rim/sheens. No invented handheld weapon, shield-holding avatar or new game feature is implied.

## Suggested comparison

The first checkpoint favors **Cracked Close Call**. Keep its current file unchanged as the next comparison point; if that lead holds, prioritize danger-story variants with one major feature changed at a time. Lid Block and Cast Contrast trail at similar early exposure. The original Cast still needs a matched-date comparison before attributing any effect to its presentation changes.

Compare matching-date clicks, attributed plays and cost, plus first/second fight progression. A higher CTR alone is not a completed acquisition result. The current 16+ access constraint and qualification-vs-retention distinction remain documented in the [assessment](../../reviews/2026_10_23_assessment/ASSESSMENT.md). No promised 4–5% CTR.

## Quality checks

- Full-size review: recognizable Pop/Jam/Prism Blade shapes; two suspension ropes per battle; no human hands or avatars; sword is a suspended fighter.
- 03 revised to move/shrink BLOCK away from the rope and simplify the distant background. Open jar mouth and one raised lid remain distinct.
- Browser 320px and 180px: text, subject hierarchy, crack/chip, impact/shield and overall color separation reviewed; original Cast loads for comparison.
- PNG decode, RGB opacity, dimensions, file sizes and SHA-256 checks pass. Files copied unchanged from generated originals; no code-based image editing/resizing.
- Repository-required Lune suite: **270 passed, 0 failed**.
