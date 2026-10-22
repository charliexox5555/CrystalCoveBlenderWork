# Glass Clash square icons — 2026-10-22

Mode: built-in imagegen, reference-guided generation. Opaque square icons without logo/text. Originals are reference inputs and remain unchanged.

## Duel — initial exact prompt

```text
Use case: ads-marketing
Asset type: Roblox experience icon; one finished opaque square image, 1024 x 1024, full bleed, no text or logo.
Primary request: Create a polished Glass Clash icon using the exact existing glass collectibles, showing the readable instant two suspended glassies collide. Make this a fresh square composition designed to read at 150 pixels, not a square crop of the thumbnail.
Input images: Image 1 I2_beauty.png is the authoritative reference for the two actual game glassies and their suspended collision. Image 2 T1a.jpg is supporting reference for the finished glass material, faces, warm/cool contrast and attractive lighting only. Ignore and exclude its logo and lettering.
Subjects: Orange-red Glass Phoenix on the left: rounded glass bird body, small cute beak, big dark oval eyes with highlights, pink cheeks, upward red crest, two broad angular jagged amber wings, small feet and tail. Icy cyan Comet on the right: large rounded teardrop glass body, pointed comet tip, cute dark eyes, pink cheeks and smile, a few prismatic trailing facets. Preserve these identities and toy proportions faithfully. These are glass ornaments, not fur animals or fleshy creatures.
Composition: Tight dynamic three-quarter clash, Phoenix slightly higher on the left, Comet lower on the right. Together their large faces and bodies occupy about 80 percent of the square. Show two thin suspension strings from the upper edge connecting naturally to their respective original hang points. Their inner body edges meet slightly below center. A small concentrated white-gold contact spark and a clearly broken outer edge of the Comet with four or five large icy glass fragments show impact. Keep both entire faces unobscured; maintain separated silhouettes. Critical eyes, faces and beak stay well inside the square with room for rounded display corners. A few wing tips or peripheral shards can approach the edge.
Scene and style: Premium colorful 3D game key art, glossy translucent tinted glass with crisp thick rims, selective facets and broad controlled reflections. Simple soft cobalt-blue backdrop grading into warm peach near the bottom, with a very faint out-of-focus wooden arena rail only along the bottom edge. Bright glass subjects stand out against the quieter background. Warm amber light on Phoenix, cool cyan on Comet. Small rim highlights and limited motion arcs, no overwhelming white explosion.
Constraints: No logos, words, letters, VS, numbers, badges, border, collage, watermark, avatars, hands, crowns, extra pets, rainbow sunburst, confetti or dense spark streaks. Keep the original shapes, charming readable faces and glass material. Favor bold clean shapes and one unmistakable clash over extra detail.
```

References, in order:
1. `../../thumbnails/kit/I2/I2_beauty.png`
2. `../../thumbnails/final/T1a.jpg`

## Dragon — initial exact prompt

```text
Use case: ads-marketing
Asset type: Roblox experience icon; one finished opaque square image, 1024 x 1024, full bleed, no text or logo.
Primary request: Create a striking simple Glass Clash icon of the existing mint-green Glass Dragon at the instant its outer wing begins to shatter. A single very large recognizable hero, designed to read at 150 pixels.
Input images: Image 1 I1_beauty.png is the authoritative reference for the actual Glass Dragon design and geometry. Image 2 T2a.jpg is supporting reference for polished lighting and material, the same dragon's face and mint-green color only. Exclude its logo and lettering; do not reproduce the wide composition.
Subject: Preserve the same cute glass dragon: round head, small ivory horns, big navy-black oval eyes with bright highlights, pink cheek spots, small broad green snout with two tiny nostrils, rotund body, pale segmented belly plates, tiny round feet, two angular faceted batlike mint-green wings. Faithful toy proportions, no generic furry pet, no aggressive teeth.
Composition: Three-quarter hero fills about 85 percent of the square, head large and slightly left of center, body descending toward the lower center, left wing spread. On its outer right wing only, a clean fracture and four separated substantial green glass shards imply shattering in a battle, while most of the dragon remains intact and recognizable. The face, both eyes and snout are completely unobstructed and far from corners. One thin suspension string attached to the dragon's existing hang point exits the top. A tiny warm white contact glint at the wing fracture is subordinate to the face. No second character.
Scene and style: Premium polished 3D game artwork. Glossy translucent mint glass, crisp darker emerald rims, broad controlled reflections and readable silhouette. A simple rich indigo-to-blue background with a soft warm halo behind the dragon provides clear green-versus-purple contrast; corners are quiet. Very faint low-poly floating island silhouettes near the bottom can suggest the existing game's world without becoming a second focal point. Bright, playful and clean; a restrained cyan rim and warm golden edge highlight, not washed-out glass.
Constraints: No logo, words, letters, numbers, badges, frame, watermark, humans, hands, weapons, crown, rainbow stained-glass spokes, multiple pets, dense spark showers or big white explosion. This must remain recognizably the supplied original Glass Dragon, not a newly invented dragon.
```

References, in order:
1. `../../thumbnails/kit/I1/I1_beauty.png`
2. `../../thumbnails/final/T2a.jpg`

## Duel — small-size refinement exact prompt

Edit target: initial generated duel, `iterations/glass_clash_icon_duel_v1.png`.

```text
Use case: precise-object-edit
Asset type: final square Roblox game icon, opaque full bleed.
Edit target: the supplied Phoenix–Comet icon. Preserve the exact Phoenix and Comet identities, glass material, faces, warm/cool lighting and two attached suspension strings.
Change only framing and surrounding visual clutter: move the camera substantially closer to the two faces and their collision. Make both faces about 30 percent larger in the square. Phoenix's face sits left of center and Comet's face right of center, near the same middle horizontal band with a slight diagonal; both look toward the viewer. Allow outermost Phoenix wing tips and the bottom of the Comet body to crop naturally outside the square, but never cut either face, eye or beak. Keep each face safely inset from the corners. The faces and immediately adjoining glass bodies dominate, with short lengths of both strings visible at the top. The original bright gold impact stays between their inner body edges and remains small enough not to wash out their faces.
Simplify the background into a smooth cobalt-blue upper field and warm peach lower field. Remove the wooden rail and detailed clouds. Retain only three or four large icy shards close to the Comet's fracture; remove the other floating chips, tiny spark showers and long rays. Keep a restrained short motion arc and compact contact glint.
Maintain premium polished translucent 3D glass rendering with crisp rims and original cute face details. This is an icon close-up of the same glassies actually colliding, not a different bird, not an egg and not a dragon. No text, logos, letters, badges, frames, watermark, new objects or people. Output square, not a side-by-side comparison.
```
