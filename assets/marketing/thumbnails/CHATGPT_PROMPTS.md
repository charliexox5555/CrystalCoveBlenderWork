# Glass Clash: ChatGPT prompts for thumbnails and icons

Paint the final marketing art from the real game renders in `kit/`. **14 thumbnails + 3 icons = 17 images.**
The creator uploads the best 10 thumbnails and starts with one icon.

## How to run this (for the creator)

1. Open a **new ChatGPT chat** with access to this repo folder (or attach the files by hand).
2. Paste the **Style bible** below once at the start of the chat.
3. Then do **one image per message**: paste that image's section and attach the files it lists. Always attach the
   **Ball VS Ball references** listed in the section too (save them first, see `references/README.md`).
4. Ask for **2 options** each time ("give me 2 options").
5. Check each option against the **Reject if** list. If a glassy's shape, colour or face changed, or anything was
   invented, say what's wrong and ask again. Don't keep a wrong one.
6. Save your pick as `assets/marketing/thumbnails/from_chatgpt/<id>.png` (for example `from_chatgpt/T1a.png`).
7. When you have your picks, ask Claude Code for **step 3** (export to `final/`, contact sheet, `UPLOAD.md`).

Kit file names: every scene has `<id>_beauty.png` (full render), `<id>_subject.png` (glassies, strings, shards and
sparks on transparent), `<id>_background.png` (scene without the subject), `<id>_mask.png` (white = subject) and
`<id>_scene.blend` (the Blender scene, for Claude Code to re-render). Real Studio screenshots are the `studio_*.jpg`
files and `kit/studio/`.

---

## Style bible (paste once at the start)

> **Game:** Glass Clash, a Roblox game for kids. Players collect cute glass toys called **glassies**, hang them on
> strings from a wooden swing stand on a floating sky island, pull back, let go and smash them together until one
> **shatters** into glass shards.
>
> **Palette (Stained Glass, use for accents, glows and backgrounds):** ruby #E23A55, amber #F5A524,
> emerald #22B573, aqua #1FC2D3, sapphire #2E6BE6, amethyst #8B4FE0, light tints #FF8EA0 #FFD98A #86EDB8
> #9BF3F8 #93BCFF #CDAAFF, dark lead #1F1830 / #261D3B, milk #EEE7D9.
>
> **Art style:** the glassies are the heroes: smooth, glossy, toy-like tinted glass with bright highlights,
> a soft inner glow and a strong rim light so the glass edges sparkle. The world is matte and low-poly:
> flat-shaded green grass islands with purple rock undersides, chunky wooden stands and fences, low-poly trees,
> floating above a sea of clouds at golden hour. Bright saturated jewel colours; stained-glass accents are welcome
> in glows and light rays.
>
> **Use the attached renders as the base.** Keep every glassy's shape, colours, face and proportions
> **exactly**. Don't invent new glassies, characters, creatures, weapons, UI, buttons, numbers or text. You may
> improve lighting, add motion blur, sparkle, glass-shard trails, depth of field, light rays and a colour grade, and
> you may re-crop or enlarge the subject to fit the layout.
>
> **Energy (see the attached Ball VS Ball references, style only):** one focal point, very big; a rival in depth;
> visible motion (speed streaks, flying shards); a clean, simple background; saturated colour with glossy
> highlights; emotion. Don't copy anything from the references themselves.
>
> **Kid-friendly:** no gore, nothing scary beyond a friendly Halloween feel, no weapons pointed at people.
>
> **No text or logo at all.** No letters, numbers, watermarks or signatures anywhere. The creator adds the logo
> and any words by hand later, so leave the **clear zone** each prompt names: calm, low-detail sky or soft gradient,
> no important objects in it.
>
> **Layout:** keep important things out of the **bottom 15%** (Roblox puts the title and player count there) and
> make it read on a phone at **300 px wide**.
>
> **Output:** thumbnails 16:9 at **1920×1080**; icons square at **1024×1024**. Return the image only.

## Reject if

- A glassy has a different shape, colour, face, extra limbs, or a glassy appears that isn't in the renders.
- Any text, letters, numbers, logo, UI, coins, "FREE" badges or watermark appears.
- The clear zone is busy, or something important sits in the bottom 15% (thumbnails) or the corners (icons).
- The stand, island or avatars look like a different game (realistic, metallic, sci-fi, photographic).
- Anything resembles a known brand or character (including the Ball VS Ball balls).

## References to attach every time

`assets/marketing/thumbnails/references/bvb_thumb_1_grin_vs_web.png`,
`references/bvb_thumb_2_claw_chain.png`, `references/bvb_thumb_3_people_aim.png`,
`references/bvb_thumb_4_halloween.png` (Halloween and icons only if the chat limits attachments),
`references/bvb_icon.png` (icons only).

---

## T1: Action (two glassies colliding)

The **Glass Phoenix** (orange glass bird, fire-gold wings) and the **Comet** (pale-blue glass drop with a star and a
smiling face) meet in mid-air on their strings. The Comet's real shards burst out of the hit with sparks. The Clash
Stand's wooden frame and pen wall frame the shot.

Attach for every T1: `kit/studio/fight_clash.jpg` (real in-game look of a clash on the stand),
`kit/studio/crown_hill_island.jpg` (the island and stand from above).

### T1a: golden sky, clear zone top-left
- **Attach:** `kit/T1/T1a_beauty.png`, `kit/T1/T1a_subject.png`, `kit/T1/T1a_background.png`
- **Keep:** both glassies exactly; the strings rising to the top edge; the burst between them; the wooden stand leg at the left edge and the pen wall at the bottom.
- **Enhance:** make the pair bigger (about 55% of the frame height) and move the camera a little lower and closer so they loom; motion blur on both swings (blur trails following the arc of the strings); a brighter white-gold impact flash with a ring of light; glossy shard trails flying toward the camera; warm golden-hour rim light; a soft golden sky with a few low-poly sky islands and clouds far below; shallow depth of field on the background.
- **Camera feel:** close, slightly low, dramatic; the impact point a little right of centre.
- **Clear zone:** **top-left third**, calm blue-to-peach sky. Keep the strings out of it.

### T1b: golden sky, clear zone top-centre
- **Attach:** `kit/T1/T1b_beauty.png`, `kit/T1/T1b_subject.png`, `kit/T1/T1b_background.png`
- **Keep / enhance:** as T1a, with the clash centred and slightly lower.
- **Clear zone:** **top-centre**, a wide calm band across the upper third. Fade the strings softly where they cross it.

### T1c: deep purple/blue sky, clear zone top-left
- **Attach:** `kit/T1/T1c_beauty.png`, `kit/T1/T1c_subject.png`, `kit/T1/T1c_background.png`
- **Keep:** as T1a.
- **Enhance:** jewel night: amethyst-to-sapphire sky with a few soft stars, cool violet rim light, the orange Phoenix and blue Comet glowing against it; same flash, blur and shard trails. Keep the glassies' true colours.
- **Clear zone:** **top-left**, dark calm sky.

### T1d: deep purple/blue sky, clear zone top-centre
- **Attach:** `kit/T1/T1d_beauty.png`, `kit/T1/T1d_subject.png`, `kit/T1/T1d_background.png`
- **Keep / enhance:** as T1c, centred.
- **Clear zone:** **top-centre**.

### T1h: Halloween event version
- **Attach:** `kit/T1/T1h_beauty.png`, `kit/T1/T1h_subject.png`, `kit/T1/T1h_background.png`, `references/bvb_thumb_4_halloween.png`
- **Glassies:** **Hollowlight** (the seasonal glass pumpkin with a mint jack-o'-lantern face and a gold stem) smashing the **Galaxy Orb** (violet glass sphere with a swirling galaxy inside); Galaxy Orb shards and sparks burst from the hit.
- **Enhance:** pumpkin-orange horizon under a violet night sky, a big soft full moon top-right (not in the clear zone), gentle orange-and-violet glow from the impact, a few friendly floating lantern sparks. Friendly spooky, not scary: no skulls, no claws, no gravestones.
- **Clear zone:** **top-left**. The creator adds "[🎃 HALLOWEEN]" text there later.

---

## T2: Hero shatter

One fantasy glassy, huge in frame, cracking apart with glowing shards flying at the camera.

### T2a: Glass Dragon, golden sky, clear zone top-left
- **Attach:** `kit/T2/T2a_beauty.png`, `kit/T2/T2a_subject.png`, `kit/T2/T2a_background.png`, `kit/studio/fight_clash.jpg`
- **Glassy:** the **Glass Dragon**: mint-green glass baby dragon, big dark eyes with white shine, pink cheeks, cream horns, star-tipped wings, white belly plates. Keep it exactly.
- **Keep:** the dragon on the right, hanging from its string; its real shards bursting out of its right side.
- **Enhance:** make the dragon even bigger (about 75% of the frame height); add thin glowing crack lines spreading across the body from the impact point (cracks only, the shape stays); shards fly **at the camera** with motion blur, the nearest ones big and out of focus; bright white-mint flash at the crack; glossy highlights and a strong golden rim; soft golden sky with a sky island far below.
- **Camera feel:** close, heroic, slightly low.
- **Clear zone:** **top-left**.

### T2b: Glass Dragon, golden sky, clear zone top-centre
- **Attach:** `kit/T2/T2b_beauty.png`, `kit/T2/T2b_subject.png`, `kit/T2/T2b_background.png`
- **Keep / enhance:** as T2a, dragon centred and a bit lower (feet above the bottom 15% line).
- **Clear zone:** **top-centre**.

### T2c: Glass Unicorn, deep purple sky, clear zone top-left
- **Attach:** `kit/T2/T2c_beauty.png`, `kit/T2/T2c_subject.png`, `kit/T2/T2c_background.png`
- **Glassy:** the **Glass Unicorn**: pale pink glass unicorn rearing up, gold hooves, a clear spiral horn, a pastel rainbow mane and tail. Keep it exactly.
- **Enhance:** as T2a, on a jewel night sky (amethyst to sapphire), cool violet rim light and pink-white sparkle; shards fly toward the camera.
- **Clear zone:** **top-left**.

---

## T3: People (two players, one cheering, one shocked)

Uses **real Studio screenshots** of two Roblox avatars on the arena's queue pads (left pad cyan, right pad yellow)
with the **Honey Bear** (amber glass bear) and **Prism Blade** (ice-blue glass sword) clashing on the stand between
them. The Blender render supplies the big clash moment for the middle.

### T3a: clear zone top-left
- **Attach:** `kit/T3/studio_wide.jpg`, `kit/T3/studio_avatar_cheer.jpg`, `kit/T3/studio_avatar_shocked.jpg`, `kit/studio/fight_clash.jpg`, `kit/T3/T3a_beauty.png`, `kit/T3/T3a_subject.png`, `references/bvb_thumb_3_people_aim.png`
- **Layout (like the reference's People layout):** blue-shirt avatar **cheering** (arms up) at the **left** edge on the cyan pad, red-shirt avatar **shocked** (hands up by the face, leaning back) at the **right** edge on the yellow pad, both large (from mid-thigh up, about 60% of the frame height) and facing in. In the middle, the Honey Bear and Prism Blade clash on their strings from the wooden stand, with Prism Blade shards and sparks bursting (from `T3a_subject.png`).
- **Keep:** blocky Roblox avatar proportions and plain colours (blue/navy, red/navy); the glassies exactly; the wooden stand.
- **Enhance:** give the avatars expressive Roblox-style faces (a big open-mouth cheer on the left, a wide-eyed "oh no" on the right); motion blur on the swing, glow at the hit, golden-hour light, soft clouds behind.
- **Clear zone:** **top-left**, above the cheering avatar's head (keep the avatar lower on the left).

### T3b: clear zone top-centre
- **Attach:** as T3a, with `kit/T3/T3b_beauty.png` and `kit/T3/T3b_subject.png`.
- **Layout:** the same, with the clash a little lower so the **top-centre** stays calm sky.
- **Clear zone:** **top-centre**.

---

## T4: Collection

A stepped display of many real glassies in rarity rows (glowing trims: white Common, green Uncommon, blue Rare,
purple Epic) rising to the **Glass Unicorn** (Legendary) on a gold-ringed pedestal in a spotlight, with the Kiln
glowing behind.

### T4a: clear zone top-left
- **Attach:** `kit/T4/T4a_beauty.png`, `kit/T4/T4a_subject.png`, `kit/T4/T4a_background.png`, `kit/studio/kilns.jpg`
- **Keep:** every glassy on the steps exactly as rendered (Pop, Jam, Ketchup Bottle, Lemonade Bottle, Milk Bottle, Pickle Jar; Glass Top, Piggy Bank, Chime, Bubble Wand, Mason Jar; Potion Flask, Light Bulb, Hourglass, Frostglobe; Honey Bear, Rocket Pop, Crystal Ball, Glass Duck); the unicorn at the top.
- **Enhance:** a strong warm spotlight cone on the unicorn with sparkles and a gold halo on the pedestal ring; brighter jewel glows on the step trims; the Kiln behind on the right with a hot orange-yellow glow pouring from its door (match the real Kiln in `kilns.jpg`: cream dome, brick arch, glowing mouth); deep amethyst background with soft bokeh. Make the glassies glossier so each reads at 300 px. Don't add or remove glassies.
- **Clear zone:** **top-left**, dark calm purple.

### T4b: clear zone top-centre
- **Attach:** `kit/T4/T4b_beauty.png`, `kit/T4/T4b_subject.png`, `kit/T4/T4b_background.png`, `kit/studio/kilns.jpg`
- **Keep / enhance:** as T4a, symmetrical, unicorn at top centre. Keep the area **above** the unicorn calm.
- **Clear zone:** **top-centre**, above the unicorn's spotlight. Leave headroom.

---

## T5: World / King (Crown Hill)

The featured arena on its own sky island: the King (a Roblox avatar with the real **gold toy crown**: gold band, five
points, round jewel-coloured gem tips, hovering just above the head as in the game) on the left pad, a crowd
cheering around the pen, two glassies clashing on the stand (**Grizzly Guardian**, a gold glass bear, vs **Pop**, a
clear soda bottle with a red cap), the purple featured arch behind, other arena islands floating in the distance.

### T5a: clear zone top-left
- **Attach:** `kit/T5/studio_crown_hill_crowd.jpg`, `kit/T5/studio_king_crown.jpg`, `kit/T5/T5a_beauty.png`, `kit/T5/T5a_subject.png`, `kit/T5/T5a_background.png`, `kit/studio/arenas_row.jpg`
- **Layout:** the King large in the left-front (from the waist up, arms raised), crown glowing with gold sparkles; the stand and the clash behind and right; the crowd small around the fence; other islands with their swing stands in the distance.
- **Keep:** the crown's real design (no royal velvet, no extra jewels); blocky avatars; the wooden stand, fences and low-poly trees; the glassies exactly.
- **Enhance:** warm golden-hour light, a soft god-ray on the King, gentle sparkles, clouds below the island, slight depth of field.
- **Clear zone:** **top-left**, golden sky above the King's crown (keep the crown below it).

### T5b: clear zone top-centre
- **Attach:** as T5a with `kit/T5/T5b_beauty.png`, `T5b_subject.png`, `T5b_background.png`.
- **Layout:** the stand centred with the King in the lower-left foreground and the arch behind; calm sky above the crossbar.
- **Clear zone:** **top-centre**.

---

## Icons (1024×1024, no text, nothing important in the corners, must read at 150 px)

### I1: hero glassy mid-shatter on a jewel sunburst
- **Attach:** `kit/I1/I1_beauty.png`, `kit/I1/I1_subject.png`, `kit/I1/I1_background.png`, `references/bvb_icon.png`
- **Keep:** the Glass Dragon exactly, slightly left of centre; its shards flying out to the right.
- **Enhance:** crop tighter so the dragon fills ~75% of the icon; glowing cracks from the hit point; bright flash; stained-glass sunburst behind (ruby, amber, emerald, aqua, sapphire, amethyst rays with dark lead lines), slightly darker toward the corners so the dragon pops; strong rim light.
- **Corners:** keep them simple (rounded-corner crop); no shards or flash in the corners.

### I2: two glassies clashing, very tight crop
- **Attach:** `kit/I2/I2_beauty.png`, `kit/I2/I2_subject.png`, `references/bvb_icon.png`
- **Keep:** the Glass Phoenix (left) and the Comet (right) exactly, meeting in the centre with a burst between them.
- **Enhance:** very tight, both faces big and readable; a strong diagonal (Phoenix slightly higher); a big white-gold flash and a few large shards; simple warm-gold-to-blue background with no clouds; motion streaks behind each glassy.
- **Corners:** clear.

### I3: Collection: three rarities, Legendary in front
- **Attach:** `kit/I3/I3_beauty.png`, `kit/I3/I3_subject.png`, `kit/I3/I3_background.png`
- **Keep:** the Glass Unicorn (Legendary) in front and centre, the Potion Flask (Rare, green) back-left, the Honey Bear (Epic, amber) back-right, exactly.
- **Enhance:** a gold glow behind the unicorn, sparkle on the horn; rarity-coloured soft rim lights (blue on the flask, purple on the bear, gold on the unicorn); stained-glass sunburst in amber, amethyst and sapphire; tighten the group so the unicorn's face reads at 150 px.
- **Corners:** clear.

---

## More ideas for later (not in this kit)

- **Aim icon/thumbnail** (like the reference icon): a glassy pulled back on its string with the in-game ghost arc
  and the gold **Perfect** band, the rival glassy waiting. Needs a Studio shot of the real Aim screen first.
- **Rival in depth:** one glassy huge in the foreground, the rival small on the other side of the stand (reference 1).
