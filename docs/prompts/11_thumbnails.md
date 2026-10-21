# Prompt: thumbnails + icon kit (Claude → ChatGPT → Claude)

The pipeline has three steps:
1. **Claude Code** (on your computer, with Blender and Studio) builds a kit of real game renders and writes the ChatGPT prompts.
2. **ChatGPT** (with access to the repo folder) paints the final art from those renders.
3. **Claude** adds the exact logo and text, exports, and checks that everything reads at phone size.

Paste everything below the line into a new Claude Code chat opened on the repo folder. Have Blender open with its MCP server started, and Studio open on the place.

---

Continue Glass Clash in this repo (branch `claude/roblox-game-concepts-0x0lnj`). This session makes **marketing art: 5 thumbnails + 1 icon, in several versions each, for Roblox thumbnail personalization testing**.

You don't paint the final art. You build a **kit of real game renders** and write a **prompt file for ChatGPT**, which paints the final images from the kit. Then, when I bring the ChatGPT images back, you add the logo and text and export the upload files.

## Start (keep token use low)

1. `git pull`. Read `AGENTS.md` and `docs/marketing/MARKETING_PLAN.md`, plus DECISIONS **49** (Stained Glass palette), **105** (Crown Hill) and **110** (name, logo, store text). Use `grep` to find these; don't read the whole file.
2. Read `assets/marketing/logo/README.md`. The logo is **final**: `assets/marketing/logo/wordmark_jewel.png` (transparent PNG) and `svg/`. Never redraw or retype it; always paste the file.
3. Get the Blender helper function list with `grep -n "^def " tools/blender/glassclash_blender.py`. In Blender, load it with `exec(open(...).read()); set_repo(<this folder>)`.
4. Use helper agents to save context:
   - a **fast/cheap model** to list which glassy, map and stand files exist (`assets/blender/glassies/*`, `assets/blender/map/*`) and which glassies are Rare+ in `src/shared/Config/Glassies.luau`;
   - your **main model** for the Blender scenes and the art direction.

## Roblox rules for this art (checked Oct 2026)

- **Thumbnails:**
  - 16:9 at **1920×1080**. Anything else gets stretched.
  - For Home Page personalization, each upload must be **under 3 MB**. Export JPG at quality ~90, and PNG only if it stays under 3 MB.
  - Up to 10 thumbnails per experience.
- **Personalization:**
  - Needs **2 or more active** Home Page thumbnails.
  - Roblox first shows each one to random players, then favours the best one for each player group, measured by qualified play-through rate.
  - So make **real variety in type**, not five near-copies.
- **Icon:**
  - Square, **512×512** (deliver 1024 as well).
  - Shown as small as ~150 px with rounded corners, so the subject must read at 150 px and nothing important sits in the corners.
  - The game name shows under the icon on Roblox, so text on the icon is optional.
  - I didn't find an icon A/B test on Roblox, so we'll swap icons by hand and compare a week at a time. Still make 3 icon versions.
- **Honesty:**
  - Show only what's really in the game: our glassies, the stand, sky islands and real powers/finishers.
  - No fake UI, no "FREE ROBUX", no copyrighted characters.
  - Kid-friendly, no gore.
- **Layout:**
  - Roblox tiles cover the **bottom edge** of a thumbnail with the title and player count on some layouts, so keep key things out of the bottom ~15%.
  - Design for a phone: the thumbnail is often ~300 px wide. Use one clear focal point, big shapes, bright saturated jewel colours on a darker background, and at most **3–4 words** of text.

## The 5 thumbnail types (one each, then variants)

| # | Type | Scene | Text idea |
|---|---|---|---|
| T1 | **Action** | Two glassies colliding in mid-air on their strings, a big burst of shards and sparks between them, the Clash Stand behind, sky-island backdrop | none, or "SMASH!" |
| T2 | **Hero shatter** | One fantasy glassy (glass dragon or unicorn) huge in frame, cracking apart with glowing shards flying at the camera | "SHATTER THEM!" |
| T3 | **People** | Two Roblox avatars on the queue pads reacting (one cheering, one shocked) while their glassies clash between them | "WHO BREAKS FIRST?" |
| T4 | **Collection** | A glowing pile or shelf of many glassies by rarity, a Legendary in a spotlight, Kiln glow | "COLLECT THEM ALL" |
| T5 | **World / King** | Crown Hill: the King's glassy with the gold crown on the featured island, crowd around, other arenas behind | "BECOME KING" |

**Variants to test (aim for 12–15 images total, then I'll upload the best 10):**
- every type **with and without** text;
- T1 and T2 with two backgrounds (golden sky vs deep purple/blue);
- one **seasonal** version of T1 for the Halloween event (pumpkin glassy).

**Icon (3 versions):**
- **I1:** a hero glassy mid-shatter, close up, on a jewel sunburst;
- **I2:** two glassies clashing, very tight crop;
- **I3:** the existing logo icon (`assets/marketing/logo/icon_jewel_512.png`) as the control.

## Your job, step by step

### 1. Build the kit in Blender (real assets only)

For each type, set up a scene from the **real exported models**: glassy `.blend`/`.fbx` from `assets/blender/glassies/<id>/`, the Clash Stand from `assets/blender/map/clash_stand.*`, and island and kit pieces from `assets/blender/map/sky*`. Then:

- **Camera and composition:** 16:9 for thumbnails, square for icons. Leave clear space where the logo and text will go (usually top-left or top-centre).
- **Glassies:** shown at `GlassyScale` (1.75×). Use their real shard sets for the shatter moments, exploded outward from the hit point.
- **Materials:** glossy tinted glass (ART_BIBLE). Bright, warm key light with a strong rim light so the glass reads. The world stays matte and low-poly.
- **Render passes, per scene, into `assets/marketing/thumbnails/kit/<T#>/`:**
  - `beauty.png`: full render, no text;
  - `subject.png`: the glassies and shards only, on a transparent background;
  - `background.png`: the background only;
  - a `depth.png` or mask if it's quick.
- Use Eevee for fast drafts and Cycles (~64–128 samples, denoised) for finals. Save each scene as `assets/marketing/thumbnails/kit/<T#>/scene.blend`.
- **T3 (avatars):** Blender has no Roblox avatars, so use Studio instead.
  1. Pose two R15 avatars on the pads with expressive poses or emotes.
  2. Take screenshots: ask me to take them in Studio (camera set by you through the MCP) and save them to `kit/T3/studio_*.png`.
  3. Add Blender renders of the clash for the middle.
- **Studio screenshots for every type:** also gather 1–2 real screenshots of the matching moment (fight, Kiln, Crown Hill), so ChatGPT sees the true look. If the MCP can't capture the viewport, tell me exactly where to put the camera and I'll take them.
- **Glance at each render** (look/screenshot at small size) and fix framing before moving on. Keep it efficient: a few good renders, not dozens.

### 2. Write the ChatGPT prompt file

Create `assets/marketing/thumbnails/CHATGPT_PROMPTS.md`. ChatGPT can open the repo folder. It has:

- **A shared header (the style bible):**
  - the Glass Clash pitch in 2 lines;
  - the palette hexes (DECISIONS 49);
  - the art style: glossy toy-like glass heroes, matte low-poly world, golden-hour sky islands, jewel colours, stained-glass accents;
  - **"use the attached renders as the base: keep every glassy's shape, colours and proportions exactly; don't invent new glassies, characters, UI or text"**;
  - kid-friendly;
  - output size (1920×1080, or 1024×1024 for icons);
  - **no text or logo at all**, plus where to leave empty space for them (we add them afterwards, exactly).
- **One section per image (T1a, T1b… I1–I3), each with:**
  - the exact file paths to attach (beauty, subject, background, Studio screenshots);
  - what to keep;
  - what to enhance (lighting, motion blur on the swing, sparkle, shard trails, depth of field, colour grade);
  - the camera feel;
  - the clear zone for logo/text.
- **A short "how to run this" note for me:**
  - one image per chat message;
  - attach the listed files;
  - ask for 2 options;
  - save picks to `assets/marketing/thumbnails/from_chatgpt/<id>.png`.

Commit the kit (renders as PNG; large `.blend` files go through Git LFS automatically) and the prompt file, push, and **stop**. Tell me the kit is ready and how many images to make.

### 3. When I'm back with the ChatGPT images: composite and export

Write a small script, `tools/marketing/compose.mjs` (or Python with PIL), that for each picked image:

1. Places `wordmark_jewel.png` and the short text in the clear zone. Use **Lilita One**, the logo's font: white with a dark `#1F1830` outline and a soft shadow.
2. Exports `assets/marketing/thumbnails/final/<id>.jpg` at 1920×1080, under 3 MB, plus a no-text version.
3. Exports icons at 512 and 1024.

Then build `final/contact_sheet.png` showing every thumbnail at **300 px wide** and every icon at **150 px**, on a light and a dark background. Look at it critically. Fix anything that doesn't read, has wrong models or warped shapes from the AI, or hides key things in the bottom 15%.

Finish with `assets/marketing/thumbnails/UPLOAD.md`:
- which 10 to upload first, and which icon to start with;
- the steps: Creator Dashboard → the experience → Configure → Places/Thumbnails → **Home Page** tab → *Edit active thumbnails* → upload → tick **Active** → Save → start the personalization test;
- what to check after a week: the qualified play-through rate per thumbnail, then replace the losers with new variants.

Add a DEVLOG line, commit and push.

## Rules

- Don't change game code, the map, UI or the logo files.
- Don't upload anything to Roblox (I do that) and don't publish.
- Every image must show the real game. If ChatGPT changes a glassy's shape or adds things that aren't in the game, reject it and ask again rather than shipping it.
