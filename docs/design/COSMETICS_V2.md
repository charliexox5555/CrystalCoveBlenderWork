# Glass Clash — Cosmetics V2: 24 flyers and 24 finishers

October 19, 2026 · workstream D (design only, no code) · decision 94 scope · **status: Proposed, for A's approval.**

Builds on [FLYERS_V3](../art/FLYERS_V3.md) (H), [FINISHERS_V2](../vfx/FINISHERS_V2.md) (G), [HOLLOWLIGHT_PREMIUM](../vfx/HOLLOWLIGHT_PREMIUM.md) (I), [ROSTER_V2](ROSTER_V2.md), `Config/RoundCosmetics`, `CrateRules` and `Balance.Crates`. The house bar is unchanged: glass first (tinted shells over darker cores, refraction, rainbow facets, sparkle), kid-friendly, original, no brands, readable on a phone, within mobile budgets. Cosmetics never touch combat.

**At a glance**

- **Flyers:** 5 existing + **19 new** = 24. Launch adds **7**: Paper Jet, Bubble Pod, Honey Hover, Dragonfly, Carousel, Sunwing, Starwhale. The other 12 come in the four Saturday drops, 3 a week.
- **Finishers:** 6 existing + **18 new** = 24. Launch adds **7**: Frost Pop, Gumball, Honeyburst, Hocus Pop, Petalstorm, Starmane, Emberwing. The other 11 come in the drops (3/3/3/2).
- **Drop themes** match the glassy drops: W1 Kitchen & Sweets (Sat Oct 31), W2 Toy Box (Nov 7), W3 Sky (Nov 14), W4 Deep Sea (Nov 21).
- **Riding:** every flyer uses one of H's four families, Stand-Surf, Sit-Cushion, Kneel/Crouch or Handle (stand or seated), with no custom clips. All Handle flyers use the standard GripL/GripR layout.
- **Finishers** are built from one reusable **module kit** (§4.1), with one or two hero meshes per item.
- **For A:** add a Mythic weight to the Coin crates, take the free starters out of the crate pools, and add Daily Store tiers for the new top rarities (§5.3).
- **Quality rule** (same as decision 88): an item that isn't at full quality, with model, motion, effects and sound, moves to a later drop. There are no placeholder versions.

---

## 1. Roster map

Status: **Live** = in game today · **L** = launch (Fri 23 / Sat 24) · **W1–W4** = Saturday drops · **S** = seasonal (outside the crate pools). Families: **SS** Stand-Surf · **SC** Sit-Cushion · **KC** Kneel/Crouch · **HS** Handle, standing · **HC** Handle, seated.

### 1.1 Flyers (24)

| # | id | Name | Rarity | Theme | Family | Signature trail | Status |
|---|---|---|---|---|---|---|---|
| 1 | skyboard | Skyboard | Common | sky | SS | aqua rail trails, pod sparkles | Live (free starter) |
| 2 | paper_jet | Paper Jet | Common | toys/paper | KC | white crease streamers | **L** |
| 3 | teacup_twirl | Teacup Twirl | Common | Kitchen | SC | steam curls + sugar sparkles | W1 |
| 4 | top_spinner | Top Spinner | Common | Toy Box | SS | candy-stripe spiral | W2 |
| 5 | sky_kite | Sky Kite | Common | Sky | HS | ribbon tail streamers | W3 |
| 6 | pearl_clam | Pearl Clam | Common | Deep Sea | SC | bubble stream + pearl glints | W4 |
| 7 | cloud_cushion | Cloud Cushion | Uncommon | sky | SC | three ribbon trails | Live |
| 8 | bubble_pod | Bubble Pod | Uncommon | bubbles | SC | iridescent bubble wake | **L** |
| 9 | honey_hover | Honey Hover | Uncommon | garden | SS | amber drips + 2 orbiting glass bees | **L** |
| 10 | swirl_board | Swirl Board | Uncommon | Kitchen | SS | pink-white candy ribbon | W1 |
| 11 | toy_racer | Toy Racer | Uncommon | Toy Box | HC | checker puffs + wheel sparks | W2 |
| 12 | sea_turtle | Sea Turtle | Uncommon | Deep Sea | KC | flipper ripples + bubbles | W4 |
| 13 | rocket_skiff | Rocket Skiff | Rare | sky | HS | layered exhaust | Live |
| 14 | dragonfly | Dragonfly | Rare | garden | HC | four wing shimmer trails | **L** |
| 15 | cupcopter | Cupcopter | Rare | Kitchen | SC | sprinkle rain under the rotor | W1 |
| 16 | sky_balloon | Sky Balloon | Rare | Sky | HS | burner glow + drifting confetti | W3 |
| 17 | jelly_glider | Jelly Glider | Rare | Deep Sea | HS | glowing tentacle ribbons | W4 |
| 18 | prism_ray | Prism Ray | Epic | sky | SS | prismatic wing trails | Live |
| 19 | carousel | Carousel | Epic | toys/fair | HC | twinkling bulb lights + music notes | **L** |
| 20 | biplane | Biplane | Epic | Toy Box | HC | smoke-ring loops + scarf trail | W2 |
| 21 | sunwing | Sunwing | Legendary | phoenix | KC | ember feathers + sunfire trail | **L** |
| 22 | sky_castle | Sky Castle | Legendary | Sky | SS | waterfall mist off the island edges | W3 |
| 23 | starwhale | Starwhale | Mythic | cosmic | SC | galaxy wake + constellation sparks | **L** |
| 24 | lantern_skiff | Moonlantern Carriage | Legendary | Hollowlight | HC | moon dust + wisps | S |

Family mix: SS 6 · SC 6 · KC 3 · HS 4 · HC 5 (24 in all). Every family has a Common and an Uncommon user, so cheap flyers show off every pose too.

### 1.2 Finishers (24)

| # | id | Name | Rarity | Theme | Hero element | Length | Status |
|---|---|---|---|---|---|---|---|
| 1 | glass_burst | Prism Pop | Common | prism | facet shell | 1.7 s | Live (free starter) |
| 2 | frost_pop | Frost Pop | Common | winter | ice cube that cracks into snowflakes | 1.7 s | **L** |
| 3 | popcorn | Popcorn | Common | Kitchen | glass kernels | 1.7 s | W1 |
| 4 | boing_box | Boing Box | Common | Toy Box | spring-star toy box | 1.7 s | W2 |
| 5 | cloudburst | Cloudburst | Common | Sky | rain cloud + mini rainbow | 1.7 s | W3 |
| 6 | splash | Splash | Common | Deep Sea | curling wave | 1.7 s | W4 |
| 7 | party_burst | Piñata Pop | Uncommon | party | piñata star | 1.9 s | Live |
| 8 | gumball | Gumball | Uncommon | toys/sweets | gumball globe + crank | 1.9 s | **L** |
| 9 | honeyburst | Honeyburst | Uncommon | garden | honeycomb hexes + bees | 1.9 s | **L** |
| 10 | sundae | Sundae | Uncommon | Kitchen | stacking scoops + cherry | 1.9 s | W1 |
| 11 | origami | Origami | Uncommon | Toy Box | paper planes → cranes | 1.9 s | W2 |
| 12 | balloons | Balloons | Uncommon | Sky | glass balloon bunch | 1.9 s | W3 |
| 13 | bubble_bloom | Fizz Bloom | Rare | fizz | giant bubble | 2.1 s | Live |
| 14 | hocus_pop | Hocus Pop | Rare | magic | tipping potion + glass frog | 2.1 s | **L** |
| 15 | petalstorm | Petalstorm | Rare | garden | glass flowers + petal vortex | 2.1 s | **L** |
| 16 | jellyquake | Jellyquake | Rare | Kitchen | wobbly jelly mould | 2.1 s | W1 |
| 17 | aurora | Aurora | Rare | Sky | aurora ribbon curtain | 2.1 s | W3 |
| 18 | brick_boom | Ka-Block | Epic | toys | blocks spelling BOOM | 2.3 s | Live |
| 19 | starmane | Starmane | Epic | unicorn | galloping unicorn + rainbow column | 2.3 s | **L** |
| 20 | blastoff | Blastoff | Epic | Toy Box | 3-2-1 toy rocket + parachute | 2.3 s | W2 |
| 21 | starfall | Supernova | Legendary | cosmic | star core supernova | 2.4 s | Live |
| 22 | whalesong | Whalesong | Legendary | Deep Sea | breaching glass whale | 2.6 s | W4 |
| 23 | emberwing | Emberwing | Mythic | phoenix | phoenix dive + sunfire column | 2.9 s | **L** |
| 24 | lantern_eclipse | Lantern Eclipse | Legendary | Hollowlight | ghost choir + eclipse | 3.2 s | S |

All finisher names are 10 characters or fewer (G's phone-tile rule). Flyer names are 12 or fewer; the ui-text-fit session should confirm both on the 844×390 tiles.

### 1.3 Rarity pyramid and crate odds

The crate pool is everything except the seasonal item, so **23 per category**. Target pool per category: **Common 6 · Uncommon 6 · Rare 5 · Epic 3 · Legendary 2 · Mythic 1.**

| | Flyers today → launch → 24 | Finishers today → launch → 24 |
|---|---|---|
| Common | 1 → 2 → 6 | 1 → 2 → 6 |
| Uncommon | 1 → 3 → 6 | 1 → 3 → 6 |
| Rare | 1 → 2 → 5 | 1 → 3 → 5 |
| Epic | 1 → 2 → 3 | 1 → 2 → 3 |
| Legendary | 0 → 1 → 2 (+ Moonlantern, seasonal) | 1 → 1 → 2 (+ Eclipse, seasonal) |
| Mythic | 0 → 1 → 1 | 0 → 1 → 1 |
| **Crate pool** | 4 → **11** → 23 | 5 → **12** → 23 |

**Per-item chance per pull.** `CrateRules.odds` splits each rarity's weight evenly across its items. The Coin column assumes A's proposed weights (§5.3: Common 59.75, Mythic 0.25).

| Rarity | Coin crate, launch | Coin crate, 24 | Marble crate, launch | Marble crate, 24 |
|---|---|---|---|---|
| Common | 29.9% | 10.0% | 12.4% | 4.1% |
| Uncommon | 8.3% | 4.2% | 9.9% | 5.0% |
| Rare | 5.0% (flyers) / 3.3% (finishers) | 2.0% | 12.4% / 8.3% | 5.0% |
| Epic | 2.0% | 1.3% | 7.4% | 5.0% |
| Legendary | 1.0% | 0.5% | 5.0% | 2.5% |
| Mythic | 0.25% (proposed; 0% today) | 0.25% | 1.0% | 1.0% |

The pyramid is healthy: Commons dominate Coin pulls, and the Marble crate still makes Rare to Legendary realistic. A Common at 29.9% at launch is high, and one of the two launch Commons is the free starter, so many Coin pulls would be duplicates (fix in §5.3).

### 1.4 Variety

- **Silhouettes:** boards (Skyboard, Swirl Board, Top Spinner, Honey Hover), seats/pods (Cloud, Bubble Pod, Teacup, Pearl Clam, Cupcopter), vehicles (Rocket Skiff, Toy Racer, Biplane, Sky Balloon), creatures (Prism Ray, Dragonfly, Sea Turtle, Jelly Glider, Sunwing, Starwhale, Carousel pony) and two fantasy set pieces (Sky Castle, Moonlantern). No two flyers in one rarity share a silhouette class.
- **Everyday → fantasy:** Common flyers and finishers are household and toy things (paper, teacups, popcorn, a wave); Legendary and Mythic are wonders (phoenix, castle in the sky, galaxy whale, supernova, ghost choir).
- **Colour:** each item's colour pair is unique within its category (§3/§4). The warm launch hues (honey, ember, candy) balance the cyan- and lilac-heavy starters.
- **Sets** (cross-sell, Daily Store bundles; the creator decides any bundle): **Phoenix** (Glass Phoenix + Sunwing + Emberwing), **Honey** (Honey Bear + Honey Hover + Honeyburst), **Unicorn** (Glass Unicorn + Carousel + Starmane), **Bubble** (Bubble Wand + Bubble Pod + Fizz Bloom). Each drop week also ships one glassy + flyer + finisher in the same theme.

### 1.5 Drop schedule

| Week (Sat) | Theme | Flyers | Finishers | Chase item |
|---|---|---|---|---|
| W1 Oct 31 | Kitchen & Sweets | Teacup Twirl (C), Swirl Board (U), Cupcopter (R) | Popcorn (C), Sundae (U), Jellyquake (R) | Rares + Glass Lollipop (Epic glassy) |
| W2 Nov 7 | Toy Box | Top Spinner (C), Toy Racer (U), Biplane (E) | Boing Box (C), Origami (U), Blastoff (E) | two Epics |
| W3 Nov 14 | Sky | Sky Kite (C), Sky Balloon (R), Sky Castle (L) | Cloudburst (C), Balloons (U), Aurora (R) | Sky Castle + Moonmirror Moth (Mythic glassy) |
| W4 Nov 21 | Deep Sea | Pearl Clam (C), Sea Turtle (U), Jelly Glider (R) | Splash (C), Whalesong (L) | Whalesong + Tidewhale (Legendary glassy) |

---

## 2. Shared flyer rules (from H, restated for builders)

- **1 Blender unit = 1 stud; R15 rider scale.** A default R15 rider is about 5 studs tall: hips about 2.5 above the feet, about 2 studs across the shoulders. Size decks and seats to that.
- **Origin** = the rider contact point: `RiderFeet` (deck top) for SS/HS/KC, `RiderSeat` (seat top) for SC/HC. The nose is Blender +Y.
- **Layered materials:** glass hero shell (transparency 0.25–0.35) over a darker core, pearl or gold trim, a little Neon.
- **Budgets:** Common/Uncommon ≤ 5,500 tris, Rare/Epic ≤ 7,500, Legendary ≤ 8,000, **Mythic ≤ 9,000** (new tier, proposed). Each moving part is its own mesh with its pivot in `manifest.json`.
- **Effects:** tagged `RideEmitter`; a launch burst tagged `RideLaunch`; one `RideLoop` sound (3D, volume ≤ 0.12, rolloff 6–40).
- **Motion:** everything goes through `RideMotion` part kinds (`Wing`, `Swing`, `Spin`, `Pulse`, `Flame`, `Puff`, `Tail`, `Fin`). Items marked † need a new part kind: `Bob` (vertical slide on a rail) and `Orbit` (a satellite circling a pivot).
- **Handle family layout (proposed to H; H's numbers win):** `GripL`/`GripR` 1.9 studs apart, centred on the nose axis. HS: 3.1 above `RiderFeet`, 1.1 forward. HC: 1.3 above `RiderSeat`, 1.4 forward. A handle flyer models its bar, wheel, yoke or rim to pass through those two points, so one clip fits all.

## 3. The 19 new flyers

Format: concept · silhouette and size · materials and colours · moving parts · trail and particles · sound loop · family.

### Launch (7)

#### Paper Jet `paper_jet` · Common · KC · Launch
*A giant folded paper plane, but made of frosted glass.*
- **Silhouette:** classic dart plane, 7.0 long × 5.2 wingspan. Crisp fold lines are bevelled glass ridges; a slightly raised keel the rider kneels on.
- **Colours:** frosted white glass `#F4F8FF` over a pale blue core `#BFD8FF`, a pencil-yellow trim line `#FFD84D` along the fold, a Neon tip `#9FE3FF`.
- **Moving parts:** the wing tips flex (`Fin`) and the tail flaps trim with the bank.
- **Trail:** two white crease-streamer `Trail`s from the wing tips; paper-glint motes.
- **Sound:** a soft paper flutter with a breezy hiss.
- **Family:** KC, kneeling on the keel, hands on the fold.

#### Bubble Pod `bubble_pod` · Uncommon · SC · Launch
*Ride inside a giant soap bubble.*
- **Silhouette:** a 4.6-stud sphere with a cut-open front quarter, a cushioned bench inside, and a heart-shaped wand ring as a "spoiler" behind (it matches the Bubble Wand glassy).
- **Colours:** iridescent film glass (low transparency 0.5 with a rainbow fresnel), a mint bench `#80E8DA`, a pearl ring trim.
- **Moving parts:** the shell wobbles (`Pulse`, slight non-uniform scale); three small bubbles orbit it† (`Orbit`).
- **Trail:** a wake of small bubbles that pop after 1 s; a rainbow sheen ribbon.
- **Sound:** a soft wobbly "bloop" hum.
- **Family:** SC.

#### Honey Hover `honey_hover` · Uncommon · SS · Launch
*A floating honeycomb with two glass bees on patrol.*
- **Silhouette:** a hexagonal glass honeycomb deck, 6.8 × 5.8, about 0.7 thick, with open amber cells at the rim and a honey-drip edge.
- **Colours:** amber glass `#FFB92E` over a deep honey core `#C77A00`, a cream wax trim `#FFF1C9`, Neon cell glints.
- **Moving parts:** two glass bees orbit the deck† (`Orbit`, wings `Wing`); honey drips form and fall (`Pulse` on drip meshes).
- **Trail:** slow amber drip particles; a faint hex-sparkle trail.
- **Sound:** a gentle buzz layered under a warm hum.
- **Family:** SS.

#### Dragonfly `dragonfly` · Rare · HC · Launch
*A glass dragonfly bike with four shimmering wings.*
- **Silhouette:** a long segmented body (8.6 long) with a saddle mid-body, a handlebar (antenna-shaped, ending in GripL/GripR) and four long wings (7.8 span).
- **Colours:** teal glass `#2FD0B5` over a deep green core `#0E6B5C`, wings clear with a rainbow vein pattern, gold joints `#F5D99A`, Neon eyes `#B9FFF0`.
- **Moving parts:** four wings flutter fast, front and back pairs out of phase (`Wing`); the tail segments sway (`Tail`).
- **Trail:** four thin wing-shimmer `Trail`s; tiny dew-drop sparkles.
- **Sound:** a quick soft wing whirr.
- **Family:** HC.

#### Carousel `carousel` · Epic · HC · Launch
*A merry-go-round pony that flew off the ride, canopy and all.*
- **Silhouette:** a glass carousel pony (mane, little unicorn horn, saddle) on a twisted gold pole, topped by a small striped canopy (3.6 across) with bulb lights. Total about 7 tall × 6 long. A gold crossbar on the pole carries GripL/GripR.
- **Colours:** pink pearl glass `#FFD6F5` over a rose core `#E58FC7`, gold pole and trim `#F5D99A`, a canopy striped white/mint `#7CE7D5`, Neon bulbs `#FFF4A8`.
- **Moving parts:** the pony bobs up and down on the pole† (`Bob`, sliding while the rider's grips follow); the canopy spins slowly (`Spin`); the mane and tail ribbons sway (`Tail`); the bulbs chase-blink (`Pulse`).
- **Trail:** a twinkle-light trail and drifting glass music notes; a sparkle burst on launch.
- **Sound:** a soft music-box loop (original, 4 bars) under a gentle hum.
- **Family:** HC. Note for H: `Bob` moves the seat; check whether HC can parent the rider to the pony part instead of the root. If not, make the canopy and pole bob and keep the pony fixed.

#### Sunwing `sunwing` · Legendary · KC · Launch
*Ride a sunfire glass phoenix (set: Glass Phoenix, Emberwing).*
- **Silhouette:** a phoenix with a long neck and crest, wings 11.0 across, swept up, and a three-feather tail 5 long. The rider kneels in a feathered saddle between the wings. Body about 8 long.
- **Colours:** a gradient of orange `#FF7A2E` to gold `#FFD34E` glass over a deep red core `#B8321A`, gold trim, Neon ember veins along the feathers.
- **Moving parts:** big wing beats with a slow, heavy down-stroke and the feather tips lagging (`Wing` plus `Fin` on the tips); the tail feathers sway (`Tail`); the crest flickers (`Flame`).
- **Trail:** a sunfire ribbon `Trail` from each wing tip, ember-feather particles drifting down, a heat shimmer on launch, and a phoenix-cry launch burst (ring of embers).
- **Sound:** a warm crackle with a slow whoosh on each wing beat.
- **Family:** KC.

#### Starwhale `starwhale` · Mythic · SC · Launch
*A gentle whale made of night-sky glass, swimming through the air.*
- **Silhouette:** a rounded whale 11.5 long with a big tail fluke and pectoral fins. A saddle with a little glass backrest sits on top. Inside the body is a galaxy: a swirl mesh plus 20 star points, visible through the shell.
- **Colours:** deep indigo glass `#2B2A7A` (transparency 0.3) over a violet core `#7A5CFF`, star points Neon white/gold `#FFE9A8`, pearl belly trim.
- **Moving parts:** the tail fluke beats (`Swing`); the fins paddle (`Fin`); the inner galaxy rotates (`Spin`); constellation lines draw and fade across the shell (`Pulse` on a line mesh); a blowhole spout of stars every 6 s (`RideEmitter` burst).
- **Trail:** a wide, soft galaxy wake (Beam ribbon with a starfield texture) plus constellation sparks.
- **Sound:** a low, soothing whale-song phrase every 8 s over a starry shimmer bed. It must come from the licensed library; record it in SOUND_LIST.
- **Family:** SC.
- **Mythic extras:** on launch, a ring of stars forms and the whale dives through it; when the rider settles, the spout fires once.

### Week 1 — Kitchen & Sweets

#### Teacup Twirl `teacup_twirl` · Common · SC · W1
- **Concept:** a fairground teacup on its saucer, slowly turning. **Silhouette:** cup 4.2 across with a handle, on a saucer 5.4 across, with a bench inside.
- **Colours:** white glass with blue rose painting `#7FA8E8` and a gold rim.
- **Moving parts:** the cup turns slowly on the saucer (`Spin`) while the rider faces forward; a spoon handle bobs.
- **Trail:** curls of steam plus sugar-cube sparkles. **Sound:** a soft clink and a gentle turning hum. **Family:** SC.

#### Swirl Board `swirl_board` · Uncommon · SS · W1
- **Concept:** a giant swirl-lollipop disc ridden like a board, with its stick as the tail fin. **Silhouette:** disc 6.0 across, 0.6 thick; stick 2.5.
- **Colours:** pink `#FF7AC8` and white swirl glass, a candy-stripe stick.
- **Moving parts:** the swirl texture or mesh rotates under the feet (`Spin` on the inner swirl only); the stick fin trims (`Fin`).
- **Trail:** a pink-white twisted candy ribbon. **Sound:** a sweet glassy whirl. **Family:** SS.

#### Cupcopter `cupcopter` · Rare · SC · W1
- **Concept:** a glass cupcake with a cherry-stem rotor on top. **Silhouette:** a cupcake case 4.4 across, a frosting swirl seat, and a two-blade rotor on the cherry stem, 6 across.
- **Colours:** case mint `#7CE7D5` over a deeper core, frosting strawberry `#FFAFC9`, cherry `#FF4D5E` Neon, sprinkles in rainbow chips.
- **Moving parts:** the rotor spins (`Spin`); the cherry wobbles (`Swing`); the frosting puffs breathe (`Puff`).
- **Trail:** sprinkle rain falling under the rotor, plus a soft downdraft ring. **Sound:** a cute soft rotor flutter. **Family:** SC.

### Week 2 — Toy Box

#### Top Spinner `top_spinner` · Common · SS · W2
- **Concept:** stand on a flat plate atop a giant spinning top (matches the Glass Top glassy). **Silhouette:** top body 4.0 across, tip down, with a static deck plate on top.
- **Colours:** candy stripes `#FF6FB1` / white, a gold tip.
- **Moving parts:** the top body spins fast beneath the static deck (`Spin`).
- **Trail:** a stripe-coloured spiral trail from the rim. **Sound:** a humming top whir. **Family:** SS.

#### Toy Racer `toy_racer` · Uncommon · HC · W2
- **Concept:** a wind-up toy race car that learned to fly. **Silhouette:** a stubby car 6.4 long, four glass wheels tilted down as hover wheels, a steering wheel through GripL/GripR, a big wind-up key on the back.
- **Colours:** racing red glass `#FF5A4E` over a dark core, a white racing number "1" decal (original), steel-blue key `#9FB4C7`.
- **Moving parts:** the key turns (`Spin`); the wheels spin (`Spin`); the steering wheel rocks with the bank (`Swing`).
- **Trail:** checkered puff particles plus wheel sparks. **Sound:** a ratchety wind-up purr. **Family:** HC.

#### Biplane `biplane` · Epic · HC · W2
- **Concept:** a glass toy biplane with a spinning propeller. **Silhouette:** two stacked wings 9.0 across, fuselage 7.5, cockpit seat, yoke through GripL/GripR.
- **Colours:** sky-blue glass `#6EC8FF` over a navy core, cream wing trim, gold propeller `#F5D99A`, Neon wingtip lights (red and green).
- **Moving parts:** the propeller spins (`Spin`); the rudder and ailerons trim (`Fin`); a scarf ribbon on the rider's seatback streams (`Tail`).
- **Trail:** a white smoke trail that sometimes curls into a heart loop (one every 8 s); wingtip light streaks. **Sound:** a cheerful little propeller buzz. **Family:** HC.

### Week 3 — Sky

#### Sky Kite `sky_kite` · Common · HS · W3
- **Concept:** hold the crossbar of a diamond kite and stand on its footbar. **Silhouette:** a diamond 5.5 tall, with a crossbar through GripL/GripR, a footbar below and a ribbon tail of bows.
- **Colours:** sunny yellow `#FFD84D` and sky-blue panels, white ribbon bows.
- **Moving parts:** the tail bows ripple (`Tail`); the diamond flexes (`Pulse`).
- **Trail:** ribbon streamers. **Sound:** kite-flap flutter. **Family:** HS.

#### Sky Balloon `sky_balloon` · Rare · HS · W3
- **Concept:** a striped glass hot-air balloon with a tiny basket. **Silhouette:** balloon 6.0 across, basket 2.6 across; the rider stands in the basket gripping the rim (GripL/GripR on the rim).
- **Colours:** stripes coral `#EF8268`, butter `#FFE39A` and aqua `#61D4DF`, a wicker-gold basket.
- **Moving parts:** the burner flame flickers (`Flame`); the balloon sways (`Swing`); sandbag charms swing (`Swing`).
- **Trail:** a burner glow plus drifting paper-confetti glints. **Sound:** a soft burner whoomph every 4 s over a wind bed. **Family:** HS.

#### Sky Castle `sky_castle` · Legendary · SS · W3
- **Concept:** stand on a floating glass island with its own tiny castle. **Silhouette:** an island disc 8.5 across with a rocky glass underside cone; a tiny castle (3 towers, 4.5 tall) at the back; the rider stands at the front.
- **Colours:** island grass-glass `#7CD992` over a crystal underside `#BBA4F4`, castle pearl with gold roofs `#FFE07A`, Neon windows.
- **Moving parts:** flags on the towers wave (`Tail`); two waterfalls pour off the edge (Beam plus particles); floating rocks orbit underneath† (`Orbit`); the windows twinkle (`Pulse`).
- **Trail:** waterfall mist and sparkling droplets falling below; on launch, a rainbow arc over the island.
- **Sound:** a faint waterfall rush plus a soft chime every few seconds. **Family:** SS.

### Week 4 — Deep Sea

#### Pearl Clam `pearl_clam` · Common · SC · W4
- **Concept:** sit in an open glass clam with a big pearl behind you. **Silhouette:** two scalloped shells 4.8 across, the top shell as a backrest, a pearl 1.2 across.
- **Colours:** shell blush `#FFB6A6` with pearl inside `#F6F1FF`.
- **Moving parts:** the top shell opens and closes slightly (`Swing`); the pearl glows (`Pulse`).
- **Trail:** a bubble stream plus pearl glints. **Sound:** gentle underwater bubbling. **Family:** SC.

#### Sea Turtle `sea_turtle` · Uncommon · KC · W4
- **Concept:** a friendly glass sea turtle. **Silhouette:** shell 5.6 long with hex plates, four flippers, a round head; the rider kneels on the shell.
- **Colours:** sea-green glass `#3FC9A0` over a deep core, gold plate edges.
- **Moving parts:** the front flippers paddle (`Wing`); the back flippers trail (`Fin`); the head bobs (`Swing`).
- **Trail:** water-ripple rings plus bubbles. **Sound:** a slow swimmy whoosh. **Family:** KC.

#### Jelly Glider `jelly_glider` · Rare · HS · W4
- **Concept:** hold two tentacle handles and stand on a glowing ring under a big jellyfish dome. **Silhouette:** dome 6.0 across, eight ribbon tentacles; a footring 2.4 across; two tentacle handles through GripL/GripR.
- **Colours:** pink glass `#FF9EF0` with mint bioluminescent rings `#9CFFD8`.
- **Moving parts:** the dome pulses (`Pulse`); the tentacles ripple with lag (`Tail`); the glow rings travel down the dome (`Pulse` on rings).
- **Trail:** glowing tentacle ribbons plus soft light motes. **Sound:** a soft pulsing glassy hum. **Family:** HS.

---

## 4. Finishers

### 4.1 The finisher module kit (for G)

Every finisher is **hero mesh(es) + a recipe of shared modules** on G's single timeline (`Config/FinisherShows`, one Heartbeat clock, pooling, `StillAt`, low detail). Modules take parameters, never per-finisher code:

| Module | Parameters | Notes |
|---|---|---|
| `MeshReveal` | mesh/set, mode (`drop`, `assemble`, `grow`, `swoop`, `orbit`, `rise`), path, squash/stretch, overshoot, t0/t1 | how every hero arrives |
| `Shockwave` | kind (`ring`, `crown`, `dome`), radius, seconds, colour, count (doubles), axis | reuses ShockCrown |
| `ShardBurst` | mesh set or generic glass shards, count, speed, spin, gravity, tint list, lit | the payoff for any hero that breaks |
| `BeamColumn` | height, width, gradient, rise/hold/fade | Neon cylinder + Beams; Epic and up |
| `ParticleField` | texture, mode (`burst`, `rain`, `swirl`, `rise`, `orbit`), count or rate, area | budget-scaled by detail level |
| `LightGrade` | PointLight curve; ColorCorrection curve (Legendary+ only) | single grade owner with a ref count (the I pattern) |
| `CameraBeat` | shake, FOV punch, hold, push, orbit, kick | the existing `FinisherCamera` fields |
| `Cue` | FinisherAudio Rise/Fly/Burst list | the existing player |

**New particle textures** (render with `build_finishers_v3.py`): Snow, Petal, Ember, Feather, Hex, Sprinkle, MusicNote, Heart, Raindrop. Existing: StarGlint, Glitter, Confetti, Fizz, Stardust, Droplets, Sparks.

**Rarity ladder** (extends G's table):

| Tier | Length | Adds |
|---|---|---|
| Common | 1.7 s | hero + ring + 2 particle layers |
| Uncommon | 1.9 s | + squash-and-stretch, trails |
| Rare | 2.1 s | + PointLight, a chain-reaction linger |
| Epic | 2.3 s | + FOV punch, a payoff pose |
| Legendary | 2.4–2.6 s | + grade, BeamColumn or double shock, a hush |
| Mythic | 2.9 s | + **two peaks** (impact, then a hero release), a world change (grade or arena effect, at most 1.0 s), a signature shatter on the foe-side glassy shards (tint and glow), and its own sound motif |

Budgets stay as G set them (≤ 60 parts, ~250 particles at the peak, 1 light, 1 Highlight). Mythic only: the grade may run up to 1.0 s at ≤ −0.12 brightness, as with Eclipse.

**Timing rule:** **P** = the peak on the winner's impact (`PeakAt` < 0.65 s, the flight time). Mythic adds **P2**, the hero release, later in the show. Times below are from show start. Sound names are from the existing finisher bank; **new** marks a sound to source (licensed library only, recorded in SOUND_LIST).

### 4.2 Launch (7)

#### Frost Pop `frost_pop` · Common · 1.7 s · Launch
*An ice cube freezes around your foe, cracks, and bursts into snowflakes.*
- **Colours:** ice `#BFEFFF`, white, frost blue `#7FB8FF`.
- **Beats:** 0.00–0.40 gather: frost creeps up from below (`ParticleField` rise, Snow) and 6 ice slabs assemble into a cube around the foe (`MeshReveal` assemble). **P 0.40:** crack lines flash across the cube, ring. 0.40–0.90 release: the cube shatters (`ShardBurst`, ice slabs) and 8 big glass snowflakes spin out. 0.90–1.70 linger: snow drifts down and the flakes twinkle and fade.
- **Hero meshes:** `IceSlab` (×6), `GlassSnowflake`.
- **Camera:** small shake.
- **Sound:** Rise MagicRiser · Fly RisingWhoosh · Burst ChargeGlass 0.05, **SafetyGlass P**, ShatterScatter 0.5, ChimeCluster 0.8, **new** soft "frost crackle" 0.15.

#### Gumball `gumball` · Uncommon · 1.9 s · Launch
*A gumball machine globe drops over your foe, the crank turns, and gumballs bounce everywhere.*
- **Colours:** red machine `#FF5A4E`, clear globe, rainbow gumballs.
- **Beats:** 0.00–0.25 the globe drops with stretch and squashes over the foe. 0.25–0.50 the crank turns twice (with clicks) while the gumballs churn faster. **P 0.50:** the coin-slot lid pops, the globe flashes, ring. 0.50–1.10 release: 14 glass gumballs burst out and bounce twice on the floor plane, with Trails. 1.10–1.90 linger: the gumballs pop into sparkles in sequence and the globe shrinks away.
- **Hero meshes:** `GumballGlobe` (base, globe, crank), `Gumball`.
- **Modules:** MeshReveal drop · Shockwave ring · ParticleField burst (StarGlint) · ShardBurst (the gumballs, bounce on).
- **Camera:** small shake.
- **Sound:** Rise PartyHorn (soft) · Fly RisingWhoosh · Burst Boing 0.22, **new** crank clicks 0.30/0.40, **MagicPoof P**, BubblePop ×5 from 1.15, CapRattle 0.7.

#### Honeyburst `honeyburst` · Uncommon · 1.9 s · Launch
*Golden honeycomb builds around your foe, a squad of glass bees buzzes in, and it all pops into honey sparkles (set: Honey).*
- **Colours:** amber `#FFB92E`, honey core `#C77A00`, cream `#FFF1C9`.
- **Beats:** 0.00–0.50 gather: 10 hex cells assemble into a dome shell (`MeshReveal` assemble), and 4 bees orbit in with wing blur. **P 0.50:** the hexes flash gold, ring, a honey splash crown. 0.50–1.10 release: the hexes pop outward and the bees zoom off on looping Trails. 1.10–1.90 linger: honey drips fall (`ParticleField` rain) and hex sparkles fade.
- **Hero meshes:** `HoneyHex`, `GlassBee` (reuse the Honey Hover bees).
- **Camera:** small shake.
- **Sound:** Rise **new** buzz swell · Fly RisingWhoosh · Burst ChargeGlass 0.1, **SplashBloom P**, ChimeCluster 0.9, buzz fade 1.2.

#### Hocus Pop `hocus_pop` · Rare · 2.1 s · Launch
*A potion flask tips over your foe, three colours of magic smoke swirl, and a crowned glass frog hops out.*
- **Colours:** green `#6CFF9A`, pink `#FF7AC8`, gold `#FFD34E` (Potion Flask's three brews).
- **Beats:** 0.00–0.55 gather: a big flask swoops in above, tips, and pours a spiral of three-colour smoke around the foe (`ParticleField` swirl, three emitters). The smoke spins faster. **P 0.55:** a poof flash, a PointLight in green, the smoke bursts, ring. 0.55–1.20 release: a glass frog with a little crown pops up from the smoke, does one hop with squash, and gives a "ribbit" sparkle. 1.20–2.10 linger: chain reaction. Three smoke puffs pop in sequence (green, pink, gold), each with a mini ring; the frog sparkles away.
- **Hero meshes:** `PotionFlaskBig`, `CrownFrog`.
- **Camera:** small shake.
- **Sound:** Rise MagicRiser · Fly RisingWhoosh · Burst Bubbles 0.1, **MagicPoof P**, **new** cute ribbit 0.85, BubblePop 1.3/1.45/1.6, ChimeCluster 1.7.

#### Petalstorm `petalstorm` · Rare · 2.1 s · Launch
*Glass flowers sprout around your foe, bloom all at once, and spin into a petal storm.*
- **Colours:** rose `#FF8FB8`, sunflower `#FFD84D`, leaf `#7CD992`.
- **Beats:** 0.00–0.55 gather: 6 glass stems grow up in a ring (`MeshReveal` grow) and the buds swell. **P 0.55:** all 6 bloom at once, a flash, a warm PointLight, ring. 0.55–1.20 release: the petals tear off into a vortex around the foe (`ParticleField` swirl, Petal) and rise. 1.20–2.10 linger: the vortex unwinds and the petals flutter down; the flowers chime and shrink one by one (chain).
- **Hero meshes:** `GlassFlower` (stem, bud, bloom states).
- **Camera:** small shake plus a slight push.
- **Sound:** Rise MagicRiser · Fly RisingWhoosh · Burst ChargeGlass 0.2, **MagicPoof P**, **new** wind swirl 0.6, ChimeCluster ×3 at 1.3/1.5/1.7.

#### Starmane `starmane` · Epic · 2.3 s · Launch
*A glass unicorn gallops in on a rainbow, rears up, and its horn fires a rainbow column that rains stars and hearts (set: Unicorn).*
- **Colours:** pearl pink `#FFD6F5`, rainbow gradient, gold `#FFE07A`.
- **Beats:** 0.00–0.55 gather: a unicorn swoops in on an arcing rainbow bridge (`MeshReveal` swoop, rainbow Beam behind) and lands beside the foe. **P 0.55:** it rears, the horn flashes, a `BeamColumn` rainbow shoots straight up, a ring, an FOV punch and shake. 0.55–1.40 release: stars and hearts rain from the top of the column (`ParticleField` rain) and the column twists. 1.40–2.30 linger, **payoff pose:** the unicorn bows to the camera, its mane sparkles, then it gallops off up the fading rainbow.
- **Hero meshes:** `UnicornHero` (3 poses: run, rear, bow; rigid pose meshes swapped in, no rig needed), `RainbowBridge`.
- **Camera:** FOV punch at P; `CameraHoldSeconds` 1.6.
- **Sound:** Rise MagicRiser · Fly RisingWhoosh · Burst **new** hoof clops 0.3–0.5, **MagicPoof P**, SoftBoom P+0.01, FallingShimmer 0.8, ChimeCluster 1.5, **new** sparkle whinny 1.6.

#### Emberwing `emberwing` · Mythic · 2.9 s · Launch
*A sunfire phoenix circles your foe, dives, and a column of sunfire glass erupts. The world glows like sunset, and feathers of light fall (set: Phoenix).*
- **Colours:** ember orange `#FF7A2E`, gold `#FFD34E`, deep red core `#B8321A`, sunset grade.
- **Beats:**
  - 0.00–0.55 gather: an ember swirl rises around the foe; a glass phoenix circles overhead twice (`MeshReveal` orbit) with sunfire Trails.
  - **P 0.55** (impact): the phoenix screeches (soft), a ring and an ember burst. The phoenix climbs high.
  - 0.55–1.25 the world change: the viewed screen grades to warm sunset (Mythic grade, ≤ −0.12 brightness, warm tint). A ground ring of fire-glass runes spreads, and the phoenix folds its wings at the apex. Hush at 1.15–1.25.
  - **P2 1.25:** the phoenix dives straight into the foe. A sunfire `BeamColumn` erupts, a double Shockwave (horizontal ring plus vertical crown), a flash, kick, FOV punch.
  - 1.25–2.00 release: 12 glowing glass feathers spiral out of the column (`ShardBurst`, Feather mesh), and the column flares and narrows.
  - 2.00–2.90 linger: the grade eases out by 2.2; feather particles drift down like embers; the phoenix rises from the column top and flies off. **Signature shatter:** the loser's glassy shards glow ember at their edges as they fall.
- **Hero meshes:** `PhoenixHero` (wings open, folded dive), `SunFeather`, `RuneRing`.
- **Camera:** `CameraHoldSeconds` 2.3, `KickAt` 1.25, push 0.68, orbit 0.2.
- **Sound motif:** a rising three-note "sun horn" (pitch ×1.0, ×1.25, ×1.5 on a warm brass-glass hit) for the Phoenix set, the same idea as the Lantern Chime. Rise CosmicRiser · Fly RisingWhoosh · Burst: **new** sun-horn note 1 at P, note 2 at 0.9, note 3 at P2; SoftBoom P2; **SafetyGlass P2+0.01**; FallingShimmer 1.4; **new** crackle tail 2.0; Twinkle 2.7.

### 4.3 Week 1 — Kitchen & Sweets

- **Popcorn `popcorn` · Common · 1.7 s.** Kernels gather and spin around the foe, then pop into fluffy glass popcorn. *Colours* butter `#FFF1C9`, red/white stripe accents. *Beats:* 0.00–0.40 12 glowing kernels orbit in and heat up; **P 0.40** pop-pop-pop flash, ring; 0.40–0.90 popcorn puffs burst out with tumble (`ShardBurst`); 0.90–1.70 a few late kernels pop, and the rest fade. *Meshes:* `Kernel`, `PopcornPuff`. *Sound:* **new** kernel pops (×6 spread over P to 1.2), MagicPoof P.
- **Sundae `sundae` · Uncommon · 1.9 s.** A glass bowl drops in, 3 scoops stack on the foe's head, a cherry lands on top, and it all pops into sprinkles. *Colours* strawberry `#FFAFC9`, mint `#B6F5DA`, vanilla `#FFF4D6`, cherry `#FF4D5E`. *Beats:* 0.00–0.50 the scoops drop and squash one by one; **P 0.50** the cherry lands with a boing, flash; 0.50–1.10 the scoops pop outward and sprinkles burst (`ParticleField`, Sprinkle); 1.10–1.90 sprinkles rain and the cherry bounces off with a trail. *Meshes:* `SundaeBowl`, `Scoop`, `Cherry`. *Sound:* Boing ×3, MagicPoof P, ChimeCluster tail.
- **Jellyquake `jellyquake` · Rare · 2.1 s.** A giant wobbly jelly mould plops over the foe, wobbles harder and harder, then splats into bouncing jelly cubes. *Colours* lime `#B8FF6B`, raspberry `#FF5A8A`, PointLight lime. *Beats:* 0.00–0.55 it plops, then wobbles (squash-and-stretch on a sine, ramping); **P 0.55** splat, ring, light; 0.55–1.20 16 jelly cubes bounce out with squash; 1.20–2.10 chain: the cubes pop one after another in a ripple, 70 ms apart. *Meshes:* `JellyMould`, `JellyCube`. *Sound:* **new** jelly wobble, SplashBloom P, BubblePop chain.

### 4.4 Week 2 — Toy Box

- **Boing Box `boing_box` · Common · 1.7 s.** A toy box lands, its lid rattles, and a glass spring-star boings out and bursts into stars. Deliberately no clown, to keep it friendly. *Colours* sky-blue box `#6EC8FF`, star gold `#FFE07A`. *Beats:* 0.00–0.40 the box drops and the lid rattles; **P 0.40** the spring-star shoots up with stretch, flash; 0.40–0.90 the star wobbles on its spring, then pops into stars; 0.90–1.70 the stars twinkle down and the box closes. *Meshes:* `ToyBox`, `SpringStar`. *Sound:* CapRattle, Boing P, ChimeCluster.
- **Origami `origami` · Uncommon · 1.9 s.** Glass paper planes swoop in and circle the foe, crash together in a flash, and unfold into a flock of paper cranes. *Colours* white `#F4F8FF`, pastel folds (mint, peach, lilac). *Beats:* 0.00–0.50 6 planes swoop in on curved Trails; **P 0.50** they converge, flash, ring; 0.50–1.10 6 cranes unfold mid-air (pose swap) and flap away; 1.10–1.90 folded-confetti flutter. *Meshes:* `GlassPlane`, `GlassCrane`. *Sound:* **new** paper fold flicks, MagicPoof P, RisingWhoosh tail.
- **Blastoff `blastoff` · Epic · 2.3 s.** Glass countdown numbers 3-2-1 pop in, a toy rocket launches beside the foe, bursts into a smiley-face firework, and a toy parachute floats down. *Colours* rocket red/white `#FF5A4E`, firework rainbow, parachute stripes. *Beats:* 0.00–0.55 the numbers pop in and out (3, 2, 1, each 0.15 s) while the rocket rumbles; **P 0.55** liftoff, smoke ring, FOV punch, shake; 0.55–1.40 the rocket arcs up and bursts into a smiley-face firework of glass sparks plus streamers; 1.40–2.30 **payoff pose:** a toy parachute with a little glass star floats down in front of the camera and pops. *Meshes:* `CountNumber` (3, 2, 1), `ToyRocket`, `ToyParachute`. *Sound:* ToyBlockA ticks per number, SoftBoom P, **new** firework crackle 1.0, PartyHorn 1.1, ChimeCluster 2.1.

### 4.5 Week 3 — Sky

- **Cloudburst `cloudburst` · Common · 1.7 s.** A puffy cloud drifts over the foe, swells, and bursts into glass rain and a mini rainbow. *Colours* cloud white, rain `#9FD8FF`, rainbow. *Beats:* 0.00–0.40 the cloud slides in and grows grey; **P 0.40** burst, flash, ring; 0.40–0.90 a raindrop shower (`ParticleField` rain, Raindrop) and a small rainbow arc grows; 0.90–1.70 the rainbow fades and droplets glint. *Meshes:* `PuffCloud`, `MiniRainbow`. *Sound:* **new** soft thunder-tap, SplashBloom P, ChimeCluster.
- **Balloons `balloons` · Uncommon · 1.9 s.** A bunch of glass balloons gathers round the foe, lifts off, and pops one after another into confetti. *Colours* rainbow balloons with a gold ribbon. *Beats:* 0.00–0.50 8 balloons float in on wobbly strings; **P 0.50** they jerk upward together, flash; 0.50–1.10 they rise and sway; 1.10–1.90 they pop in sequence (90 ms apart), each with confetti. *Meshes:* `GlassBalloon`. *Sound:* **new** balloon squeak, BubblePop chain, PartyHorn tail.
- **Aurora `aurora` · Rare · 2.1 s.** Aurora ribbons wrap around the foe like a curtain of light, ripple, and snap into a starry glass shimmer. *Colours* aurora green `#63EFBC`, violet `#A995FF`, PointLight teal. *Beats:* 0.00–0.55 3 aurora ribbon Beams spiral up around the foe; **P 0.55** the ribbons flare bright, ring, light; 0.55–1.20 the ribbons widen into a curtain behind the foe and ripple; 1.20–2.10 chain: the curtain breaks into falling glass stars from left to right. *Meshes:* `AuroraRibbon` (Beam texture plus a thin mesh fallback). *Sound:* CosmicRiser, MagicPoof P, FallingShimmer, Twinkle chain.

### 4.6 Week 4 — Deep Sea

- **Splash `splash` · Common · 1.7 s.** A glass wave curls up behind the foe and crashes over it in a spray of droplets and seashells. *Colours* ocean `#2FA8D8`, foam `#E8FBFF`, shell pink. *Beats:* 0.00–0.40 the wave rises behind the foe; **P 0.40** it crashes, splash crown, ring; 0.40–0.90 droplets and 4 glass seashells fly out; 0.90–1.70 foam bubbles fizz away. *Meshes:* `CurlWave`, `Seashell`. *Sound:* SplashBloom P, Bubbles tail.
- **Whalesong `whalesong` · Legendary · 2.6 s.** The arena floor turns to sea, a glass whale breaches up under the foe, sings, and splashes down in a shower of pearls. *Colours* deep blue `#1E6FB8`, aqua `#5BC8FF`, pearl `#F6F1FF`; Legendary grade, cool blue.
  - 0.00–0.55 gather: a translucent sea disc spreads across the floor under the foe (`MeshReveal` grow); the grade dips cool and blue; bubbles rise.
  - **P 0.55:** the whale breaches straight up under the foe (`MeshReveal` rise), a double Shockwave (ring plus crown), a splash crown, FOV punch.
  - 0.55–0.85 hush: the whale hangs at its apex, the music drops, a soft whale-song note.
  - 0.85–1.60 release: it falls back down with a huge splash, and 14 glass pearls burst out (`ShardBurst`) in an arc.
  - 1.60–2.60 linger: the sea disc shrinks, the pearls bounce and twinkle, the grade restores by 1.9.
  - *Meshes:* `WhaleHero` (breach pose), `SeaDisc`, `Pearl`. *Camera:* hold 1.9, kick 0.85. *Sound:* **new** whale call (shared with Starwhale), SplashBloom P and 0.85, SoftBoom 0.85, FallingShimmer 1.2, Twinkle 2.3.

---

## 5. Build plan

### 5.1 Launch flyers, modelling order for F (headless Blender, v4 tools)

Easiest first. Each one reuses an existing family clip where it can, so it can be fitted the day it imports.

| # | Flyer | Model effort | Family readiness | Why this slot |
|---|---|---|---|---|
| 1 | Honey Hover | S (hex deck, drips) + bees | SS = Skyboard clip | Proves `Orbit`† on the simplest base |
| 2 | Bubble Pod | S (sphere, bench) | SC = Cloud Cushion clip | Iridescent glass material, reused by later items |
| 3 | Paper Jet | S (folded planes) | **KC (new from H)** | First KC user; waits for H's clip |
| 4 | Dragonfly | M (segments, 4 wings) | **HC (H's grip layout)** | First standard-grip build; validates GripL/GripR |
| 5 | Carousel | M–L (pony, pole, canopy) | HC + `Bob`† | Grip on a moving part: check with H first (§3 note) |
| 6 | Sunwing | L (wings, feathers) | KC | Large wings; reuses the Glass Phoenix palette and material |
| 7 | Starwhale | L (whale, inner galaxy, constellations) | SC | Mythic: most layers; inner-galaxy transparency needs a phone check |

Each flyer ships with `manifest.json` (moving parts, pivots, family, grips), a 512 icon with the flyer camera, and the FBX round-trip. Uploads currently hit the Open Cloud 403 (G's note), so plan an upload window as soon as the key is fixed.

### 5.2 Finisher build order for G

1. **Extract the module kit** (§4.1) from the five V2 shows into shared modules. Re-express Prism Pop with it as the regression check (it should look identical).
2. **Frost Pop** (Common): assemble + shard burst + snow, the minimal recipe.
3. **Gumball** (Uncommon): drop + bounce shards.
4. **Honeyburst** (Uncommon): assemble + orbiters; shares bees with Honey Hover (coordinate with F).
5. **Hocus Pop** (Rare): swirl field + chain linger + pose swap.
6. **Petalstorm** (Rare): grow + vortex.
7. **Starmane** (Epic): pose-swap hero + BeamColumn + payoff pose.
8. **Emberwing** (Mythic): two peaks, world grade, signature shatter; the most work, so last.

Drops follow the same pattern weekly. New modules land the week they are first needed: water surfaces in W4, the countdown for Blastoff in W2.

### 5.3 Crate pools and odds, for A

1. **Coin crate Mythic weight.** `Balance.Crates.CoinWeights` has no Mythic, so Starwhale and Emberwing could only come from Marble crates, which are hidden where `PolicyService` restricts paid random items. Proposed: `CoinWeights = { Common = 59.75, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 1, Mythic = 0.25 }` (mirrors the glassy Kiln's 0.25%). Odds are shown as always. Marble weights unchanged.
2. **Free starters out of the crate pools.** `skyboard` and `glass_burst` are free to every player (`Matches = 0`) but still sit in the pools, so at launch about 30% of Coin pulls hand back something everyone already owns. Proposed: `CrateRules.odds` skips `Matches == 0` items, so Common is split between the paid Commons. Decision 68 says every item stays in both pools; this only removes items nobody can lack. It is a creator-visible odds change, so confirm.
3. **New items** get no `Matches` field (crate and store only, per decision 68); `Rarity` goes on each entry, or into the `rarities` map in `RoundCosmetics`. Seasonal items stay in `C.Seasonal`.
4. **Pool entry gate.** An item joins the pools only once its art is installed (the `available` argument already supports this), so a late drop never rolls as a missing model.
5. **Daily Store.** Flyers have no Robux tiers above Epic Featured, and Finishers none above Legendary (decision 80). Sunwing, Sky Castle (Legendary flyers), Starwhale and Emberwing (Mythic) need tiers and prices. These are paid products, so they are the creator's decision; there is nothing to configure until then.
6. **Duplicates.** Cosmetic duplicates are counted (decision 68) but give nothing. With 2 paid Commons at launch, duplicates will be frequent. Consider a small Coin refund per duplicate cosmetic (like `DuplicateCoinsAtMaxStars`). This is an economy change, so the creator decides.

## 6. Risks

1. **Throughput.** 14 launch items at full quality by Thursday, alongside 12 glassies, with Blender GPU time shared and Open Cloud uploads blocked (403). Per decision 88, anything not ready moves to a drop. The cut order if needed is Starwhale and Emberwing last in, so they slip to W1 together.
2. **Animation families aren't final.** KC and Handle clips and the grip layout come from H. Paper Jet, Dragonfly and Carousel depend on them; Carousel's moving seat may need a fallback (fixed pony, bobbing canopy).
3. **Mythic access.** Without the Coin Mythic weight, the two Mythics are Marble-only and invisible in restricted regions (§5.3.1).
4. **Motif overlap.** Two whales (Starwhale flyer, Whalesong finisher, Tidewhale glassy) and two phoenix pieces are deliberate sets, but each must look different: the night-sky galaxy whale versus the blue sea whale.
5. **Kid safety.** No gambling imagery (no coin jackpots or slot reels; Gumball uses a coin slot only as a lid), no clowns, fire is "sunfire glass" with no burning, and fireworks are celebratory with smiley shapes.
6. **Performance.** Mythic two-peak shows and Starwhale's inner galaxy need a phone frame check; low detail must drop the grade, the second shockwave and the inner galaxy.
7. **Sound sourcing.** About 15 new sounds are marked **new**. They come from the licensed library only (Creator Store free / ProSoundEffects); budget a sourcing pass early in W1 prep.

## 7. Open questions (for A, and the creator where marked)

1. **Approve the 14 launch picks** (7 flyers, 7 finishers)?
2. **Creator:** add the Coin-crate Mythic weight (0.25%) for cosmetics?
3. **Creator:** remove the free starters from the crate pools?
4. **Creator:** Daily Store tiers for Legendary/Mythic cosmetics, and themed set bundles (Phoenix, Honey, Unicorn, Bubble)?
5. **Creator:** a Coin refund for duplicate cosmetics?
6. **H:** confirm the grip layout and whether HC can ride a bobbing part (Carousel).
