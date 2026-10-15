# Glass Clash — combat roster and VFX plan

October 15, 2026. **Creator approved the direction and fixed this roster at 24 for release.** Counts, damage and timings remain prototype values. The later [release handoff](../HANDOFF_COMBAT_RELEASE.md) is the current production authority: improve existing bodies in Blender, build the new ones and complete all 24 in four batches. Research: [sources and existing-system audit](../research/COMBAT_VFX_RESEARCH.md).

The goal is a fight where you can see trouble building, anticipate a dramatic collision, understand what saved or shattered a glassy, and want to watch the next matchup. “1000× better” is the creative ambition, not a performance or fun measurement.

Only research/documents change in this pass. No models, scripts, balance values, ownership, rarity, Kiln pools or paid features change. All attack counts, durations and limits below are prototype proposals. Existing rules stay live until a later implementation pass is authorized.

## 1. Direction

**Every glassy should do something distinctive you can recognize without a popup.** Use one signature ability and, where useful, one quiet supporting trait. Its inventory description should state that signature in one short sentence. We can retain some existing passive logic underneath, but replacing or combining the current passive/burst system is a proposed design revision, not an already accepted rule change.

Keep the creator-approved foundations:

- Two glassies remain attached to strings in the current 3D swing arena. The creator explicitly chose swing turnarounds instead of adding bounce walls.
- Players pick and aim, then watch automatic powers. No new mid-fight buttons.
- Fixed straight-on fight camera and grounded avatars on their queue pads. Do not reintroduce camera cuts, orbiting, round-end zooms, power banners or result screens.
- Keep the current retained three-card match hand and round-only Pick Any.
- Glassies remain glossy toy glass; the environment stays matte. Original names/shapes, no alcohol references or copied characters.
- Existing IDs and recognizable identities stay intact. The creator now requests Blender improvements to existing bodies as well as separate effect pieces; preserve old sources and regenerate matching shards/crack paths. New concept IDs are fixed in the release manifest.

What changes in the proposed fighting design:

1. **Build anticipation:** bubbles fill, a lid lifts, an axe cocks back, thorns grow. The viewer can predict something exciting.
2. **Change what happens:** some powers reward contact, others turnarounds, distance, taking damage or surviving at low HP. Avoid making every glassy a different-colored laser.
3. **Give collisions weight:** a localized contact flash, clear rebound, pitched glass clink, short debris and stronger feedback for a genuinely heavy hit.
4. **Leave breathing room:** small routine contacts; bolder signature actions; the largest payoff reserved for shattering.
5. **Allow surprises with explanations:** swing position and timing provide uncertainty. Visible charges and capped triggers provide a story the viewer can follow.

## 2. Shared fight feel

| Moment | Proposed presentation | What makes it satisfying |
|---|---|---|
| Normal contact | Small glass glint exactly at contact, 3–6 dust flecks, brief body wobble, varied clink | Sharp, quick feedback that keeps motion visible |
| Heavy contact | Directional crescent/splinter flash, stronger rebound, low thump under glass crack | The picture and sound agree about the hit's weight |
| Ability becoming ready | A physical charge detail on the glassy; short rising audio cue | The viewer anticipates the next payoff |
| Ability release | Distinct silhouette/motion, visible travel or sweep, effect-specific sound | You know whose ability fired and where it went |
| Block | Lid/plate catches the contact, brief dent/ripple, bright blocked-contact ping | A readable save instead of an unexplained zero damage |
| Miss | Attack passes beside the target and visibly dissipates | A miss is understandable without a banner |
| Low HP | Existing cracks plus sparse escaping dust and a restrained stress creak | Tension without covering HP/hearts |
| Shatter | Very brief client presentation hold, directional prebroken shards, bright initial crack then delicate tinkles | A crisp break followed by a readable falling-debris tail |
| Round finish | Winner rise → flight to loser → cosmetic avatar-glass impact → one heart loss | One continuous payoff using the existing finisher |

Suggested initial timings: ordinary impacts 0.08–0.15 seconds, heavy-impact presentation hold 0.035–0.055 seconds, signature windups 0.25–0.45 seconds, shatter presentation hold 0.07–0.10 seconds. These are art-tuning starting points. Never pause the authoritative server fight to sell a hit. During a local hold, buffer events and resume the presentation timeline without losing damage/shatter events. Avoid holds on ordinary repeated contacts.

Respect the fixed camera: sell impact with body reaction, trails, sound and contact effects. Camera shake/FOV pulses are optional future experiments that need the creator's agreement; they are not required by this plan.

## 3. Proposed trigger vocabulary

| Trigger | Meaning | Typical users |
|---|---|---|
| Contact | One validated body collision encounter, not every simulation substep | Pop, Ketchup, Arc Coil |
| Swing turnaround | A meaningful rise reaches an apex and starts falling again | Jam, Crescent Axe, Briar Flask |
| Ready timer | A visible charge completes, then an attack winds up | Prism, Frostglobe, Dragon |
| Damage stored | Accepted damage fills a bounded visible meter/piece | Water Jug, Hourglass |
| Low-HP threshold | One latched crossing per round, not repeated threshold flicker | Hot Sauce, Glass Duck |

Turnaround detection belongs in the server simulation. For the spherical pendulum, detect a positive-to-negative vertical-velocity crossing after a sufficient rise, with a minimum angular excursion and debounce. Do not use X-velocity alone: 3D sideways swings make that unreliable. Suppress tiny jitters, the initial stationary release, frozen motion and collision-induced reversals. A turnaround detector must be tested against loops and off-plane swings before any kit depends on it. Prototype detector values: at least 20° excursion, 0.65-second debounce, and no contact in the preceding 0.15 seconds; tune from recorded motion rather than treating those values as final.

Small readiness visuals can update on every qualifying event, but major attacks obey cooldowns/caps. An “every hit” trait does not mean a full-screen explosion every hit.

## 4. The 24-glassy release roster

Names of existing glassies remain unchanged. “Description” is proposed player-facing ability copy. Looks describe existing silhouette preservation or a new modeling brief. Counters are tendencies to test, not guaranteed wins. Existing rarity labels remain; new rarities and acquisition sources are deliberately unassigned until mechanics are balanced.

### A. The 12 playable glassies: make existing art more interesting

#### 1. Pop — pressure attacker · first prototype

- **Description:** “Every third clash pops a pressure burst.”
- **Look:** Keep the cyan soda bottle, red cap and bubbles. Three large internal bubbles light in sequence; the cap rattles when ready.
- **Ability — Pressure Pop:** On the third qualifying contact, spend the three charges on bonus contact damage and a stronger legal rebound. Supporting trait: none initially; the charge is the identity.
- **VFX:** Blender supplies a reusable bubble dome and burst-ring mesh; Studio counts/glows the bubbles, lifts the cap slightly, emits a short fizz sheet and expands the ring from the contact point. Rubber-pop layer over a glass clink.
- **Tradeoff:** Needs repeated contact; charge does not create guaranteed long-range damage. The ring is cosmetic unless the rules explicitly award a separate area attack later.

#### 2. Jam — defensive timing · first prototype

- **Description:** “Raises its lid to soften the next clash.”
- **Look:** Keep the pink jam jar and gold lid. A separate translucent guard plate resembles the lid, leaving the body visible.
- **Ability — Lid Guard:** Every second turnaround raises a one-contact guard for up to two seconds. It reduces the next body's contact damage, then breaks. Prototype mitigation 40%; no complete immunity or projectile protection initially.
- **VFX:** Blender lid/guard mesh; Studio makes it face the incoming opponent, catches the contact with a localized ripple, then flips it away into glints. Distinct lid clang.
- **Tradeoff:** A light hit can use up the guard; ranged effects still threaten it. No permanent bubble obscuring the jar.

#### 3. Prism — aimed precision · first prototype

- **Description:** “Charges a narrow prism ray that can miss.”
- **Look:** Keep the violet faceted bottle and gem stopper. Three facets brighten inward toward the firing face.
- **Ability — Refraction Ray:** A visible timed charge produces a short, narrow ray after a windup. Direction locks at release; movement may carry the foe out of the shot. One bounded damage event.
- **VFX:** Blender small lens and shared flare texture; Studio Beam with thin bright core, colored edge and a contact glint only on a confirmed hit. Rising glass tone followed by a crisp ping.
- **Tradeoff:** Strong visual aim cue, modest width and cooldown; do not animate a successful ray toward a target the server says it missed.

#### 4. Milk Bottle — one useful repair

- **Description:** “Foams over to seal a little damage once.”
- **Look:** Preserve the milk bottle; add a soft white foam rim and three chunky bubbles around the neck.
- **Ability — Fresh Seal:** First drop below half HP triggers one small capped heal after a short foam buildup. It cannot trigger again from healing across the threshold. No continuous regeneration initially.
- **VFX:** Blender foam cap/bubble shapes; Studio rolls a white band down the body, emits bubbles and briefly softens the appropriate crack stage after server HP updates. Gentle pour/pop sound.
- **Tradeoff:** Can shatter before the repair resolves; repair budget must not prolong rounds indefinitely.

#### 5. Pickle Jar — sticky contact

- **Description:** “Clashes leave a brief sticky brine tether.”
- **Look:** Keep pale-green chunky jar; show two big pickle-shaped silhouettes inside if the current model allows it, not dozens of details.
- **Ability — Brine Line:** Every third contact briefly reduces the foe's swing drive. A stretching tether sells the effect but never becomes a real constraint. One refreshable effect, no slow stacking.
- **VFX:** Shared Studio curved Beam with droplet texture; Blender supplies a droplet mesh. Tether snaps into two droplets when its short duration ends.
- **Tradeoff:** Does not stop the swing or keep the foe attached. Lower raw burst output balances reliable utility.

#### 6. Ketchup Bottle — delayed burst

- **Description:** “Sticks a splat that pops on the next clash.”
- **Look:** Existing red bottle; nozzle visibly compresses before firing. Splat uses rounded tomato shapes, clearly food-themed.
- **Ability — Splat Pop:** Every third contact places one visible blob on the opponent. Their next body collision consumes it for a small extra burst; it expires if unused. One blob maximum.
- **VFX:** Blender rounded splat mesh; Studio attaches it to a surface marker, makes it wobble and bursts tiny tomato droplets on resolution. Squeeze, then wet pop; no bloodlike sprays.
- **Tradeoff:** Needs a follow-up encounter; no stacking or damage-trigger recursion.

#### 7. Glass Cup — risky big swing

- **Description:** “Builds a bigger swing after two turnarounds.”
- **Look:** Preserve simple clear cup; the rim gets a short cyan light arc when charged.
- **Ability — Rim Rush:** Every second turnaround boosts swing drive briefly. Next solid collision uses the charge for a stronger shove, then returns to normal. It still follows the server pendulum/string constraints.
- **VFX:** Shared rim-ring and short directional Trail; Studio gives the cup a glass resonance cue and crisp rim flash on its empowered contact.
- **Tradeoff:** A glancing path can waste the temporary power window; no direct guaranteed damage.

#### 8. Water Jug — stored retaliation

- **Description:** “Stores two hits, then splashes back.”
- **Look:** Keep broad blue jug. A stylized inner water wedge rises in two steps; no fluid simulation.
- **Ability — Sloshback:** Two received body contacts ready a short forward splash at the next turnaround. The server tests a brief cone; outside the cone means a miss. Storage is bounded and resets on release.
- **VFX:** Blender two curved splash sheets and droplets; Studio scales/fades them through the cone. One low slosh followed by a water slap.
- **Tradeoff:** Must take contact to charge and can release at an awkward angle; receiving hits never heals it.

#### 9. Lemonade Bottle — spreading shot

- **Description:** “Fires a fan of three zesty glass pips.”
- **Look:** Keep yellow bottle, add a large simple lemon-slice charge cue near the cap.
- **Ability — Zest Volley:** A visible timed charge fires three small citrus pips in a shallow fan. Each has a visible short flight, with one shared capped damage budget for the entire volley. No slow or hard freeze.
- **VFX:** Blender citrus wedge and chunky pip mesh; Studio launches three short yellow-green trails with tiny fizz pops at confirmed contacts. Fizzy hiss followed by three quick plinks.
- **Tradeoff:** Wider coverage than Prism but lower concentrated output; a foe may pass between the pips or take only one. No invisible cone-wide damage.

#### 10. Mason Jar — counterpunch

- **Description:** “Taking a heavy hit charges its next clash.”
- **Look:** Preserve screw-top jar; lid turns a quarter-step and two broad stress bands glow when armed.
- **Ability — Screw-Top Counter:** One sufficiently heavy received body collision arms a single stronger next body contact, expiring after a short window. It does not multiply incoming damage back automatically.
- **VFX:** Blender threaded collar detail if needed; Studio twists the lid, winds a short spiral around the neck, then releases a broad contact flash. Screw click → heavy glass knock.
- **Tradeoff:** Small repeated hits do not charge it; can be defeated before its reply.

#### 11. Hot Sauce — comeback rush

- **Description:** “Heats up below half health for one fiery rush.”
- **Look:** Preserve small red bottle; three visible ember dots heat from amber to orange. Glass remains visible through a narrow flame collar.
- **Ability — Hot Streak:** One low-HP crossing triggers a short bonus-drive/damage window. One use per round; no repeated triggering after repairs, no permanent speed ramp.
- **VFX:** Shared ember/heat ribbon texture, small Blender flame tongue mesh; Studio trails only during the active window. Sizzle and fast clink accents.
- **Tradeoff:** Brief and risky while already damaged; it can waste the window on a pass-by.

#### 12. Crystal Tumbler — one stored reflection

- **Description:** “Catches part of a ray and returns a glint.”
- **Look:** Keep cut-crystal tumbler; one broad facet becomes a bright mirror when ready.
- **Ability — Mirror Catch:** Periodically primes one partial ranged-hit mitigation. A successfully caught directional attack readies a small narrow return shot after a windup; it can miss. Does not reflect reflections or body contacts. If the brief mirror window expires unused, its charge becomes a smaller next-contact glint bonus so the kit still does something against contact fighters.
- **VFX:** Blender facet plate; Studio splits the incoming contact glint, lights the plate, then sends a short return Beam. Two distinct high pings.
- **Tradeoff:** Body-contact specialists still hurt it; this is a soft ranged counter, never total immunity.

### B. Six new original glassies

#### 13. Crescent Axe — visible weapon sweep · first prototype

- **Description:** “Winds up a glass axe at every second turnaround.”
- **Look:** A squat lavender glass flask with a crescent stopper and silver-blue shoulders. A separate broad, blunt toy-glass axe materializes beside it; the flask remains the primary fighter silhouette.
- **Ability — Crescent Sweep:** Every second turnaround winds the axe back, then sweeps one short arc in the opponent's direction. The sweep is a separate bounded attack and can miss. The body remains on its string.
- **VFX:** Blender flask, axe/handle and one curved slash mesh. Studio animates the axe pivot and a short Trail, then chips it into glints. Server evaluates one swept attack volume, not axe MeshPart physics. Air cut → glass chop.
- **Tradeoff:** Short reach, clear windup and one hit per cast; not a constantly spinning damage fan.

#### 14. Briar Flask — growing thorns · first prototype

- **Description:** “Grows glass thorns that burst on its next clash.”
- **Look:** Emerald teardrop flask with a leaflike stopper and rose-colored seed inside. Three large clear thorn fins sprout around its middle.
- **Ability — Thorn Bloom:** Three turnarounds grow three thorn stages. When fully grown, the next body contact consumes them for a bonus strike. Thorns are bounded offensive charge, not unlimited retaliation.
- **VFX:** Blender three tapered, rounded thorn meshes and a vine collar; Studio grows them outward in stages, flashes the contact and dissolves them. Small crystalline growth clicks → sharp leafy crack.
- **Tradeoff:** Slow setup; no invisible arena hazards or thorns covering the entire pen. Spikes remain attached to the glassy.

#### 15. Arc Coil — electrical storage · first prototype

- **Description:** “Charges on clashes, then fires a crackling arc.”
- **Look:** Cyan squat bulb with a chunky copper-colored collar and three bright glass coil segments. No real electrical brand marks.
- **Ability — Coil Discharge:** Three qualifying body contacts fill the coil. After a brief windup it fires a short aimed bolt; a narrow server sweep decides hit/miss. It does not chain back into its own charge counter.
- **VFX:** Blender collar/coil segments; Studio creates a seeded jagged Beam path with small side sparks and a clear impact flash. Ratcheting charge ticks → sharp electrical snap.
- **Tradeoff:** Needs contacts and enough range/alignment at release. Small branch sparks are decorative, not extra invisible hits.

#### 16. Chime — traveling sound pulse

- **Description:** “Rings out a glass pulse after two turnarounds.”
- **Look:** Bell-shaped aqua glass bottle with a large suspended pearl clapper and flared rim.
- **Ability — Resonant Ring:** Every second turnaround produces a visible expanding pulse shell. It damages once if the shell crosses the foe before fading; maximum range and damage are capped. No stun.
- **VFX:** Blender bell/clapper plus shared annular ring mesh; Studio expands two thin rings and adds a few vibrating glints. One musical glass note with a short echo.
- **Tradeoff:** Wide but weaker than focused attacks; travel time allows a swing path to outrun the limited pulse.

#### 17. Hourglass — stored-damage return

- **Description:** “Stores a little damage and returns it as a sand shot.”
- **Look:** Amber glass hourglass with violet caps and a broad glowing sand stream. Outer frame is chunky, not filigree.
- **Ability — Borrowed Moment:** A limited fraction of accepted damage fills a visible lower chamber without preventing that damage. At a later turnaround, flip and launch one compact sand shot proportional to stored damage, capped. No healing, rewind or extra life.
- **VFX:** Blender body/frame, sand inserts and projectile bead; Studio flips separate presentation details while the collision body stays correct, then animates one sand ribbon. Glass tick → sandy swish.
- **Tradeoff:** Must survive to cash out; the shot can miss. Stored value cannot exceed the defined cap.

#### 18. Frostglobe — brief area control

- **Description:** “Sends a frosty puff that slows the next swing.”
- **Look:** Blue glass snow globe with a tiny original crystal sprout inside and a broad white collar. Keep the inner object simple and readable.
- **Ability — Snowdrift:** A visible timed swirl releases a short cone of frost, applying a brief nonstacking drive reduction if it connects. Shared slow floor and reapplication protection prevent repeated lockouts.
- **VFX:** Blender ice chips and a curling sheet; Studio emits sparse snow, sweeps the sheet forward and briefly shows three frost facets on the target. Breath-like puff → ice tinkle.
- **Tradeoff:** Reduced damage budget for control; no hard freeze and no white cloud hiding both fighters.

### C. Six existing catalog glassies for a later spectacle batch

These IDs already exist in the catalog but do not have installed playable art. This is a proposed first full kit, not permission to replace or grant items.

#### 19. Prism Blade — precision slash

- **Description:** “Charges a cutting arc at the top of its swing.”
- **Look:** Keep the Prism family violet/cyan cue; short broad glass sword, chunky hilt at the hang point, beveled readable blade.
- **Ability — Edgewake:** Two turnarounds charge a narrow forward slash that travels briefly through space. It can miss and hits once; unlike Crescent Axe it leaves the weapon and becomes a short projectile arc.
- **VFX:** Blender sword, curved crescent and edge glints; Studio sweeps a thin edge Trail and launches the crescent. Clean glass zing with a sharp contact ping.
- **Tradeoff:** Narrow coverage and no persistent cutting field; body silhouette and damage volume must agree.

#### 20. Rocket Pop — movement payoff

- **Description:** “Ignites boosters for its next incoming swing.”
- **Look:** Pop-family cyan glass bottle with red fins and three chunky nozzle details; the family link remains obvious.
- **Ability — Afterburn Swing:** Every third turnaround lights the boosters, briefly adding a capped tangent impulse toward the normal swing arc. Next body clash consumes its bonus, or the window expires. It never detaches from the string or teleports.
- **VFX:** Blender fins/nozzles and small flame mesh; Studio short exhaust Trail with expanding heat ring. Toy rocket whistle → punchy contact pop.
- **Tradeoff:** Higher speed can produce a miss and bigger reciprocal collision risk; movement changes require simulation calibration.

#### 21. Glass Duck — one comic rescue

- **Description:** “Bubbles up to soften one dangerous clash.”
- **Look:** Round yellow duck-shaped glass collectible, broad beak and tiny wings; a small bubble crown signals readiness.
- **Ability — Bubble Buoy:** Once below a low-HP threshold, gains a short-lived one-contact mitigation bubble. It is not invulnerable and cannot save a glassy already shattered by the triggering hit.
- **VFX:** Blender duck, wing details and shared bubble dome; Studio pops three bubbles, adds a tiny wing flap and one visible shield ripple. Short original squeak/quack-like sound → bubble pop.
- **Tradeoff:** One use, brief duration, reduced protection against non-contact attacks. No actual HP resurrection.

#### 22. Comet — delayed return attack

- **Description:** “Leaves one star that returns on its next turnaround.”
- **Look:** Rounded pale-cyan comet with a swept crystal tail and a distinct warm star core.
- **Ability — Star Echo:** A charged body contact leaves one hovering star at its actual contact position. At the next turnaround the star flies toward a locked aim point, then expires. Only one star can exist; one hit maximum.
- **VFX:** Blender comet, star bead and tail wedges; Studio holds the bead briefly, then draws a thin star Trail on its short flight. Sparkling plink → descending whistle.
- **Tradeoff:** Delay permits a miss; the hovering star is a projectile marker, never a third fighter or collision body.

#### 23. Glass Dragon — short grand breath

- **Description:** “Builds a sparkling breath, then sweeps a short cone.”
- **Look:** Cute emerald glass dragon with a large snout, two broad wings and chunky curled tail. Hang point on top of the head; no thin individual scales.
- **Ability — Dragon Breath:** A longer visible charge lights throat and wing veins, followed by a short three-pulse breath cone. Server locks/updates direction by a defined turn-rate limit; each pulse uses the same bounded cast damage budget. No indefinite flamethrower.
- **VFX:** Blender dragon, jaw/wing details and two breath-sheet shapes; Studio animates jaw, emits sparkling mint shards and keeps the cone's leading edge readable. Friendly rumble → crystalline airy roar.
- **Tradeoff:** Long setup and no body-collision bonus during breath; can be out of position. Sparkle breath fits the current catalog's identity.

#### 24. Galaxy Orb — brief motion disruption

- **Description:** “Opens a tiny gravity well that bends one swing.”
- **Look:** Violet glass orb with a bright offset star core and two broad glass orbit bands. Swirl interior with simple layers, not a unique expensive shader.
- **Ability — Little Orbit:** A long visible charge places one small temporary well between fighters. Server applies a capped tangent force while they are in range, preserving string length and minimum drive; one closing pulse can deal bounded damage. No dragging avatars or trapping a fighter indefinitely.
- **VFX:** Blender orbit bands and shallow vortex funnel; Studio rotates bands, uses sparse inward star particles and closes with a small ring. Low soft hum → glass-star pop.
- **Tradeoff:** Advanced simulation work; build last. A well's location can help either swing, and the damage budget remains modest. No black full-screen disk.

### Roster coverage and the remaining catalog

| Watching for… | Candidates |
|---|---|
| Charged contact / big shove | Pop, Glass Cup, Mason Jar, Rocket Pop |
| A save at the right moment | Jam, Milk Bottle, Glass Duck |
| A shot landing or missing | Prism, Lemonade Bottle, Crystal Tumbler, Arc Coil, Prism Blade |
| A delayed payoff | Ketchup Bottle, Water Jug, Hourglass, Comet |
| A physical-looking weapon | Crescent Axe, Briar Flask |
| Motion disruption | Pickle Jar, Frostglobe, Galaxy Orb |
| A visible comeback window | Hot Sauce |
| A broad signature | Chime, Glass Dragon |

The remaining 13 existing catalog entries stay intact as dormant backlog: Perfume, Potion Flask, Message in a Bottle, Light Bulb, Honey Bear, Jack-o'-Glass, Crystal Ball, Glass Lollipop, Grizzly Guardian, Starblade, Glass Sword, Glass Unicorn and Crystal Crown. They are not additions to the fixed release roster. None are deleted or renamed; handle release filtering and any saved ownership as specified in the handoff. Roster expansion requires a later creator instruction.

## 5. Blender and Studio responsibilities

**Blender makes the shapes and reusable image assets. Studio makes them move, react, sound and resolve during gameplay.** Complex Blender simulations are useful for producing flat texture frames, not something we assume imports as a live effect.

| Asset / behavior | Blender deliverable | Studio deliverable |
|---|---|---|
| New glassy | Body, separate recolorable details, 12–20 closed shards, upright shared-view icon | Glass/material/tint, hang attachment, portraits, cracks, local anchored render |
| Axe/slash/thorns | Low-poly axe, crescent arc, three thorn sizes | Pivot animation, trails, timed appearance and cleanup; server swept volumes |
| Shields | Lid plate, curved shield rim, bubble dome | Facing, one-hit ripple/break, gameplay-state lifetime |
| Water/food/frost | Curved splash/puff sheets, splat and drop meshes | Scale/fade, emit bursts, attach markers, no fluid physics |
| Electricity/rays | Small coil/lens shapes, original streak texture | Seeded Beam paths, source/impact attachments and timed audio |
| Charge/readiness | Broad coil segments, bubbles, sand inserts, facet plate | State-driven light/color/detail transforms, capped audio cues |
| Shatter | Closed fracture pieces and shared glass-dust/glint textures | Directional local debris, short contact flare, cleanup and layered sound |
| Breath/gravity | Cone sheet, orbit bands, vortex funnel | Short scripted motion, server-aligned cone/well visualization |

Original shared VFX kit, built once:

- Meshes: expanding ring, curved slash, lens flare plane, droplet, bubble dome, guard plate, thorn, splash sheet, puff sheet and small crystal chip.
- Static textures: glass glint, directional streak, soft puff, tiny shard fleck, electricity strip and droplet mask. Target 256–512 px; use alpha padding.
- Two initial 4×4 flipbooks: glass dust and pressure/fizz pop, 512 or 1024 px depending on the first import proof. Add frost/breath variants later only if a recolor/static texture cannot do the job.
- Sound families: light/medium/heavy clinks, rising glass charge, lid block, axe swish, electrical snap, bubble pop, splat, ice tinkle, water slap and full shatter. Prototype with the four approved existing sounds; final distinct sounds need original synthesis/recordings or confirmed license/Roblox permission.

Effects should mostly be smooth stylized geometry with a few sharp glass facets. Large solid visual forms do the work; particles add the final sparkle. Rare/Mythic complexity may increase visual richness, but ability readability and combat budget do not disappear for common glassies.

## 6. First Blender batch: concrete work order

Build the shared effect kit and **three new bodies**: Crescent Axe, Briar Flask and Arc Coil. Improve Pop/Jam/Prism proportions, edges and finish while retaining their identities; preserve old sources and add removable charge/guard/lens details. The handoff defines the following three batches to complete all 24.

| Order | Deliverable | Review view |
|---|---|---|
| 1 | Contact/shatter kit: ring, glint, slash, chip, dust/fizz sheets | Large still of impact and short preview on existing Pop/Jam |
| 2 | Crescent Axe flask + separate axe/handle + sweep arc | Body/icon plus charge → sweep → contact storyboard |
| 3 | Briar Flask + three thorns + vine collar | Body/icon plus bare → growing → ready → burst states |
| 4 | Arc Coil + three charge segments + collar | Body/icon plus empty → charged → discharge states |
| 5 | Pop bubbles/cap cue, Jam guard plate, Prism lens cue | Side-by-side existing artwork with effect additions |
| 6 | Export/import proof and six-glassy effect assembly | Real fixed-camera Studio comparison before expanding |

Body specification follows the existing art contract: 1 unit = 1 stud, hang-point origin, applied transforms, smooth shading, separate recolorable meshes, closed shards with matching origin/scale. Ordinary intact body/details target ≤1,500 triangles; eventual hero bodies ≤3,000. First-batch standalone effect meshes target 50–300 triangles each. Do not make weapon tips or glass edges needle-thin.

New files after approval:

```text
assets/blender/glassies/<id>/<id>.blend
assets/blender/glassies/<id>/<id>_body.fbx
assets/blender/glassies/<id>/<id>_details.fbx
assets/blender/glassies/<id>/<id>_shards.fbx
assets/blender/glassies/<id>/manifest.json
assets/icons/<id>.png
assets/blender/vfx/combat_v1/combat_v1.blend
assets/blender/vfx/combat_v1/exports/<piece>.fbx
assets/vfx/combat_v1/textures/<name>.png
```

Each asset manifest records triangle count, bounds, hang point, piece names, attachment-marker coordinates and export settings. Reuse the working helper/export axes. Icons must remain upright and centered per the creator's later UI direction. Blender empties are reference markers; the Studio import script creates actual Attachments from their recorded coordinates. Export meshes separately so plain colors stay editable in Studio.

Do an early FBX round-trip, then one real Roblox import: confirm scale, pivot, transparency sorting, two-sided sheet visibility, mirrored orientation and texture padding before producing the full batch. No assumption that Blender lights, nodes or simulation caches reproduce in Roblox.

## 7. Later implementation architecture

This is a plan, not code added in this pass:

1. Keep `FightRules` as the owner of charges, cooldowns, status effects, damage and round resolution. Proposed ability definitions specify trigger and effect rather than copying formulas into services.
2. Extend deterministic `Pendulum` with validated turnaround/encounter facts and bounded attack geometry. Server-authored sweeps/projectiles resolve against the fighter positions; visual particles never deal damage. Prototype geometry helpers must work in Lune.
3. Represent a cast as charge/start/release/contact/expire events with fight ID, unique cast ID, time, source side, seed, origin, direction and actual hit result. Source/target motion and effect timing share the current presentation buffer.
4. Cosmetic client modules dispatch by effect family, using reusable templates under `ReplicatedStorage.Assets.VFX.Combat`. Keep `FightScene` as the integration point and extend existing shatter/finisher code.
5. Late join/bootstrap carries current charges and persistent effects. Missing or reordered events cannot create extra attacks, and expired casts do not restart on respawn.
6. Every effect belongs to its fight/cast. Clear it on shatter, forfeit, round replacement, watch-stop and scene destruction. Pools must reset color, attachments, sound and emission state.

Rules for interactions:

- Ability damage cannot count as a new body collision or refill charge unless a kit explicitly says so. Reflection never reflects reflection; splats/thorns never trigger one another recursively.
- One cast has explicit hit and damage caps. A three-pulse breath divides its budget; it does not get three full bursts accidentally.
- Body-collision damage stays reciprocal. Pickle/frost slows have a common minimum swing-drive floor and strongest-effect handling rather than multiplicative stacking.
- Simultaneous results use the existing deterministic round-resolution order. Once a fighter has shattered, pending offensive casts cancel; dead projectiles do not reverse the result.
- Aim still matters. Narrow attacks use actual direction/travel tests; do not arbitrarily label a guaranteed auto-hit as a miss for decoration.
- Weapon mesh scale is cosmetic until a corresponding server attack shape exists. Any visible damaging reach must match the configured shape closely.

## 8. Example fight to aim for

Pop meets Crescent Axe. First collision is a quick clear clink and rebound. Pop's first bubble lights. On a later apex, Crescent Axe begins lifting its weapon; a rising glass tone makes you look at it. Pop is moving inward with two bubbles lit: its next clash will burst. The axe sweeps: it might strike first, pass behind Pop, or collide during Pop's pressure burst. The server resolves the actual order and contact; the effects show it. A final body hit produces one clean shatter, then the established winner flight and heart loss. No menu, long camera cut or power-name banner interrupts the sequence.

Jam against Arc Coil should feel different: Jam's lid might consume a body hit while the coil still charges, but the later electrical shot is not automatically blocked by a contact-only lid. That creates a readable matchup without guaranteeing the coil wins.

## 9. Budget and acceptance gates

Provisional focused-fight caps, to be profiled rather than treated as engine limits:

| Resource | Starting budget |
|---|---|
| Active signature meshes | ≤12 total, mostly shared simple pieces |
| Live effect particles | ≤100 normally; ≤180 briefly during shatter |
| Visible glass shards | 12–20 per broken glassy; global cap below existing ~150 guidance |
| Concurrent prominent attack effects | One signature per side; overlapping resolved casts still show minimum cues |
| Dynamic effect lights | 0–1, non-shadowing; mesh glow is the fallback |
| Transparent sheets across a fighter | Aim for ≤2 beyond the glass body |
| Focused-fight extra presentation cost | Target ≤2 ms on the selected low-tier test device; measure before claiming it |

Full detail is for participants and a selected watched match. Nearby background arenas retain essential attack cues at lower density; distant fights use the existing simplified view. Dropping visual detail must never remove the silhouette/charge/hit information needed to understand the selected fight. Important cues work without bloom, sound or flipbooks.

Before scaling the roster:

- Watch a six-glassy comparison from the actual fixed fight camera. Can a new viewer name the attack source, tell a block from a miss, and see both bodies/HP throughout?
- Each ability needs a visible trigger/readiness state, release, accurate hit/miss and cleanup. Compare 15-second clips at normal speed and with audio muted.
- Run pure rules tests, balance/economy simulators after content/config changes, and seeded native swing checks. Compare normalized equal-stat kits against the existing fairness/round-length targets; separately test real rarity/star matchups without silently changing their multipliers.
- Explicitly test axe sweep misses, 3D turnaround jitter, double contact, reflection recursion, slow overlap, healing thresholds, lethal hits during windup, repeated rematches, dropped events and late joins.
- Record hit frequency, signature casts/hits, lead changes, comeback rate, round time and timeouts. Preserve the 15–45 second round goal and <5% timeout target unless the creator agrees otherwise.
- Profile one focused fight plus seven active arenas. Do real low-end-device checks in a later creator-authorized device pass; this research pass changes no device settings.

## 10. Review and stopping point

The creator approved the roster/direction and requests exactly 24 release glassies, with improved existing art and new Blender models. Six prototype kits plus the shared contact/shatter kit are the first production checkpoint; the remaining 18 follow in three batches. Final damage numbers, new rarity assignments, economy changes and asset purchases are not implied by roster approval.

The creator settled the arena question: keep hanging glassies and use turnarounds. Begin the next chat from the complete release handoff/prompt, make actual Blender assets, validate the first import and effects, then complete the fixed roster. Refine tunable rules from live checks without adding extra roster entries or silently changing settled gameplay/UI constraints.
