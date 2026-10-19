# Glass Clash — Roster V2: 24 → 50

October 19, 2026 · workstream D (design only, no code) · **status: Proposed, awaiting creator approval before any Blender work.**

Builds on [COMBAT_ROSTER_V1](COMBAT_ROSTER_V1.md), [POWER_BRAINSTORM_24](POWER_BRAINSTORM_24.md), [RELEASE_OVERHAUL_PLAN](RELEASE_OVERHAUL_PLAN.md) and DECISIONS 85–87. Every new kit follows the **cast contract**: trigger → **Ready** (CAST button lights) → tap, or auto-cast at `Cast.AutoSeconds` → effect. Rarity buys more complex mechanics and flashier presentation, never more raw power; every kit targets 45–55% at equal stats in the real-swing matrix (`tools/release_matrix`, owned by workstream A).

**At a glance**

- 26 new glassies: **9 revived dormant definitions** (ids and rarities kept) and **17 brand-new**. Four dormant ids stay dormant (§1.4).
- **Launch (12):** Fishbowl, Cookie Jar, Glass Top, Bubble Wand, Piggy Bank, Light Bulb, Potion Flask, Honey Bear, Crystal Ball, Grizzly Guardian, Glass Unicorn, Glass Phoenix.
- **Drops (14):** Kitchen & Sweets → Toy Box → Sky → Deep Sea, 4/3/3/4 a week.
- **New shapes (4):** `zone`, `drain_contact`, `fuse`, `mimic`. Only `zone` and `drain_contact` are needed at launch. Everything else reuses existing shapes, plus small field extensions (§3).

---

## 1. Roster map

Status: **Live** = in the 24 today · **L** = launch (Fri 23 / Sat 24) · **W1–W4** = weekly drops. ★ = revived dormant id.

| # | id | Name | Rarity | Type | Trigger → Shape | Silhouette | Colour | Status |
|---|---|---|---|---|---|---|---|---|
| 1 | pop | Pop | Starter | Fizzy | contact×3 → contact | tall bottle | #8FE3FF | Live |
| 2 | jam | Jam | Starter | Heavy | turnaround×2 → guard | round jar | #FF6B8B | Live |
| 3 | prism | Prism | Starter | Sharp | timer → ray | faceted bottle | #C9A8FF | Live |
| 4 | milk_bottle | Milk Bottle | Common | Fizzy | threshold → heal | tall bottle | #FFFFFF | Live |
| 5 | pickle_jar | Pickle Jar | Common | Heavy | contact×3 → slow_contact | round jar | #C9F2A6 | Live |
| 6 | ketchup_bottle | Ketchup Bottle | Common | Fizzy | contact×3 → mark_contact | squeeze bottle | #FF5A4E | Live |
| 7 | glass_cup | Glass Cup | Common | Sharp | turnaround×2 → boost | cup | #DFF6FF | Live |
| 8 | water_jug | Water Jug | Common | Heavy | received×2 → cone | jug | #BFEFFF | Live |
| 9 | lemonade_bottle | Lemonade Bottle | Common | Fizzy | timer → volley | tall bottle | #FFF27A | Live |
| 10 | **fishbowl** | Fishbowl | Common | Heavy | heavy → projectile (return) | round bowl + fish | #5BC8FF | **L** |
| 11 | **cookie_jar** | Cookie Jar | Common | Heavy | received×2 → volley | round jar + cookie lid | #E8B77A | **L** |
| 12 | salt_shaker | Salt Shaker | Common | Sharp | turnaround×2 → volley (wide) | small shaker | #F4F7FA | W1 |
| 13 | cocoa_mug | Cocoa Mug | Common | Heavy | received×2 → guard | mug + handle | #A8683F | W1 |
| 14 | conch_shell | Conch Shell | Common | Sharp | stored → pulse | spiral shell | #FFB6A6 | W4 |
| 15 | mason_jar | Mason Jar | Uncommon | Heavy | heavy → armed_contact | round jar | #BFEFFF | Live |
| 16 | hot_sauce | Hot Sauce | Uncommon | Fizzy | threshold → boost | small bottle | #FF5A4E | Live |
| 17 | crystal_tumbler | Crystal Tumbler | Uncommon | Sharp | timer → mirror | cup | #D7E9FF | Live |
| 18 | chime | Chime | Uncommon | Sharp | turnaround×2 → pulse | tube bell | #8DE7E5 | Live |
| 19 | **glass_top** | Glass Top | Uncommon | Sharp | turnaround×2 → sweep (flat, 360°) | spinning top | #FF6FB1 | **L** |
| 20 | **bubble_wand** | Bubble Wand | Uncommon | Fizzy | timer → **zone** | ring wand + bubble | #B9F3FF | **L** |
| 21 | **piggy_bank** | Piggy Bank | Uncommon | Heavy | stored → volley | animal (pig) | #FF9CC2 | **L** |
| 22 | wind_up_robot | Wind-Up Robot | Uncommon | Heavy | contact×3 → boost | boxy toy + key | #9FB4C7 | W2 |
| 23 | icicle | Icicle | Uncommon | Sharp | timer → projectile | long spike | #CFF4FF | W3 |
| 24 | glass_bee | Glass Bee | Uncommon | Sharp | contact×2 → mark_contact | animal (bee) | #FFD23F | W3 |
| 25 | crescent_axe | Crescent Axe | Rare | Sharp | turnaround×2 → sweep | flask + axe | #BBA4F4 | Live |
| 26 | briar_flask | Briar Flask | Rare | Heavy | turnaround×3 → armed_contact | teardrop flask | #47D5A0 | Live |
| 27 | arc_coil | Arc Coil | Rare | Fizzy | contact×3 → ray | coil flask | #79E8FF | Live |
| 28 | hourglass | Hourglass | Rare | Heavy | turnaround×3 → heal | hourglass | #F3BC70 | Live |
| 29 | frostglobe | Frostglobe | Rare | Fizzy | timer → cone + slow | globe | #A6DFFF | Live |
| 30 | **light_bulb** ★ | Light Bulb | Rare | Sharp | contact×3 → **drain_contact** | bulb | #FFF4A8 | **L** |
| 31 | **potion_flask** ★ | Potion Flask | Rare | Fizzy | turnaround×3 → Cycle (slow / mark / heal) | round flask | #6CFF9A | **L** |
| 32 | popcorn_jar | Popcorn Jar | Rare | Heavy | turnaround×3 → **fuse** | striped tub | #FF5A4E / #FFF8E8 | W1 |
| 33 | kaleidoscope | Kaleidoscope | Rare | Sharp | timer → Cycle (ray / volley / cone) | tube + turning end | #7E6BFF | W2 |
| 34 | message_bottle ★ | Message in a Bottle | Rare | Fizzy | timer → orbit (self-centred) | corked bottle + scroll | #9FE8D8 | W4 |
| 35 | rocket_pop | Rocket Pop | Epic | Fizzy | turnaround×3 → boost + impulse | rocket bottle | #8FE3FF | Live |
| 36 | prism_blade | Prism Blade | Epic | Sharp | turnaround×2 → projectile (return) | blade | #9BE7FF | Live |
| 37 | glass_duck | Glass Duck | Epic | Heavy | threshold → guard | animal (duck) | #FFE45C | Live |
| 38 | **honey_bear** ★ | Honey Bear | Epic | Heavy | turnaround×3 → **zone** + slow | bear-shaped bottle | #FFB92E | **L** |
| 39 | **crystal_ball** ★ | Crystal Ball | Epic | Fizzy | timer → **zone** at predicted foe | orb on stand | #C9B5FF | **L** |
| 40 | glass_lollipop ★ | Glass Lollipop | Epic | Fizzy | timer → pulse + slow | disc on stick | #FF7AC8 | W1 |
| 41 | jellyfish | Glass Jellyfish | Epic | Fizzy | received×3 → boost (slow drift, armour) | dome + tentacles | #FF9EF0 | W4 |
| 42 | comet | Comet | Legendary | Fizzy | contact×3 → echo_contact | orb + tail | #B8F1FF | Live |
| 43 | **grizzly_guardian** ★ | Grizzly Guardian | Legendary | Heavy | received×3 → guard + Riposte pulse | big bear | #FFC96B | **L** |
| 44 | **glass_unicorn** ★ | Glass Unicorn | Legendary | Sharp | turnaround×2 → aimed boost, pierces guards | unicorn | #FFD6F5 | **L** |
| 45 | crystal_crown ★ | Crystal Crown | Legendary | Sharp | timer → 3 Shots fired on turnarounds | crown | #FFE07A | W2 |
| 46 | tidewhale | Tidewhale | Legendary | Heavy | turnaround×3 → sweep + Push | whale | #2FA8D8 | W4 |
| 47 | glass_dragon | Glass Dragon | Mythic | Heavy | timer → breath | dragon | #7CF0C4 | Live |
| 48 | galaxy_orb | Galaxy Orb | Mythic | Fizzy | timer → orbit | orb | #7A5CFF | Live |
| 49 | **glass_phoenix** | Glass Phoenix | Mythic | Sharp | turnaround×3 → projectile; Rebirth at 30% → pulse + heal, then volley | phoenix | #FF7A2E → #FFD34E | **L** |
| 50 | moon_moth | Moonmirror Moth | Mythic | Sharp | timer → **mimic** | moth, mirror wings | #D9E4FF | W3 |

Hollowlight (seasonal Epic, Heavy, `seed_contact`) stays outside the count, the Kiln and bot pools (DECISIONS 72).

### 1.1 Rarity pyramid and Kiln odds

| Rarity | Kiln weight | Today (24) | Launch (36) | Full (50) | Per-glassy chance today → launch → 50 |
|---|---|---|---|---|---|
| Starter | — | 3 | 3 | 3 | not in Kiln |
| Common | 56.25% | 6 | **8** (+2) | 11 (+5) | 9.4% → 7.0% → 5.1% |
| Uncommon | 22% | 4 | **7** (+3) | 10 (+6) | 5.5% → 3.1% → 2.2% |
| Rare | 14% | 5 | **7** (+2) | 10 (+5) | 2.8% → 2.0% → 1.4% |
| Epic | 6% | 3 | **5** (+2) | 7 (+4) | 2.0% → 1.2% → 0.86% |
| Legendary | 1.5% | 1 | **3** (+2) | 5 (+4) | 1.5% → 0.5% → 0.3% |
| Mythic | 0.25% | 2 | **3** (+1) | 4 (+2) | 0.125% → 0.083% → 0.0625% |

The pyramid is healthy: each tier is no larger than the one below it, and the Legendary tier stops being one lonely Comet. **Dilution is the cost** (see §5, risk 2). The Kiln weights are per rarity, so every new Legendary or Mythic makes each specific one rarer. At 50, one particular Mythic is about 1 in 1,600 Coin pulls. Marble crate weights (`Balance.Crates.MarbleWeights`, Mythic 1%) help, and Daily Featured offers sell named glassies directly. Changing odds is the creator's call (open question 5).

### 1.2 Type balance

| Type | Today | Launch | Full | Notes |
|---|---|---|---|---|
| Heavy | 8 | 13 | 17 | Launch leans Heavy because the best "everyday" launch reads (jars, bowl, piggy) are chunky |
| Fizzy | 10 | 13 | 16 | |
| Sharp | 6 | 10 | 17 | Today's biggest gap; 7 of the 14 drops are Sharp |

Rock-paper-scissors (`Heavy > Sharp > Fizzy > Heavy`) only stays fair if a random three-card hand usually holds two types. At 17/16/17 the odds are even.

### 1.3 Trigger, shape and silhouette variety

| Trigger | Today | +New | Full | New users |
|---|---|---|---|---|
| turnaround | 8 | +8 | 16 | Salt, Glass Top, Potion, Popcorn, Honey Bear, Unicorn, Tidewhale, Phoenix |
| timer | 6 | +8 | 14 | Bubble Wand, Icicle, Kaleidoscope, Message Bottle, Crystal Ball, Lollipop, Crown, Moth |
| contact | 5 | +3 | 8 | Light Bulb, Wind-Up Robot, Glass Bee |
| received | 1 | +4 | 5 | Cookie Jar, Cocoa Mug, Jellyfish, Grizzly |
| stored | 0 | +2 | 2 | Piggy Bank, Conch Shell (trigger exists in `SignatureTraits`, unused since the Hourglass rework) |
| heavy | 1 | +1 | 2 | Fishbowl |
| threshold | 3 | (Phoenix Rebirth) | 3 + 1 sub-trigger | Phoenix uses it as a second stage, not as its only trigger. Threshold-only kits were all bottom-tier in the audit |

- **Shapes:** every existing shape keeps at least one user. The new glassies add `zone` (×3), `drain_contact`, `fuse` and `mimic`. Volley grows from 1 to 4 users (Lemonade, Cookie, Salt, Piggy), each with a different trigger and spread. That is the most-shared shape, which is fine for Commons and Uncommons.
- **Silhouettes at 50 (approximate):** bottles 8, jars/tubs 5, cups/mugs/jug 4, flasks 4, orbs/globes/bowls 5, toys/tools 6 (top, wand, robot, kaleidoscope, hourglass, chime), weapons 2, crown 1, shell/spike/candy 3, creatures 12. Creatures are concentrated at Epic and above, so the shelf reads **everyday → fantasy**: Common = kitchen and house, Uncommon = toys and small critters, Rare = curios and lab glass, Epic = sweet creatures and magic objects, Legendary = guardians and royalty, Mythic = cosmic or legendary beasts.
- **Colour:** each new glassy gets a signature hue not already used by a same-rarity neighbour. The warm hues new at launch (cookie tan, honey amber, phoenix orange, piggy pink) balance today's cyan-heavy shelf (Pop, Rocket Pop, Water Jug, Mason, Tumbler, Comet, Frostglobe).

### 1.4 Dormant definitions

| Dormant id | Plan | Why |
|---|---|---|
| light_bulb, potion_flask, message_bottle, honey_bear, crystal_ball, glass_lollipop, grizzly_guardian, glass_unicorn, crystal_crown | **Revive.** Keep id, name and rarity; replace the legacy Passive/Special with a `CombatRelease.Kits` entry; reset off-lean base stats to their type lean (Light Bulb 22/100/15 → 21/105/14, Lollipop 21/105/12 → 20/110/10); new Blender model | Names and descriptions already fit, and any saved ownership keeps working |
| perfume | Stay dormant | Prism is already "a faceted perfume bottle" |
| jack_o_glass | Stay dormant | Hollowlight is the pumpkin (DECISIONS 72) |
| starblade, glass_sword | Stay dormant | A third and fourth glass sword would blur Prism Blade and Crescent Axe |

Nothing is deleted or renamed.

---

## 2. Balance method for the first-pass numbers

All numbers are **first-pass**. Workstream A's retune and `tools/release_matrix` (real swing) decide the final values. The numbers below come from one **expected-damage budget** so new kits start inside the band:

- **EV** = `Damage × LandChance ÷ cadence` in Power per second. Cadence is never shorter than `MinCastSeconds` (5 s); two-turnaround or two-clash kits are effectively one cast per 5 s.
- Today's kits on that scale: Prism 0.042 · Lemonade 0.063 · Chime 0.075 · Dragon 0.077 · Prism Blade 0.085 · Water Jug 0.098. The top four match the audit's over-performers.
- **Target for new damage kits: 0.055–0.065.** Utility converts at roughly: 1.5 s slow ≈ 0.15 Power, a 40% guard on one clash ≈ 0.25 Power, a +0.3 ContactBonus clash ≈ Glass Cup's payoff.
- Contact-bonus and guard kits are benchmarked against a named existing kit ("compare: Jam") because their value depends on clash damage, which the matrix measures better than arithmetic does.
- **Manual-cast edge:** each kit names one readable moment where tapping beats auto. The 55–62% caster-vs-auto target belongs to A; new kits must not exceed it, so no kit doubles its damage on a perfect tap.

Field names match today's `CombatRelease.Kits`. New fields are marked † and specified in §3.

---

## 3. New shapes and field extensions

### 3.1 Four new shapes

**`zone`** — a fixed hazard bubble in arena space (Bubble Wand, Honey Bear, Crystal Ball).
- Fields: `At` † = `"self"` | `"self_lead"` | `"foe_predicted"`; `Lead` † (s); `Range` = zone radius (studs); `Delay` † (s before it goes live, default 0); `Duration` = live time; `Damage`; optional `Slow`, `StatusSeconds`, `Immunity`; `Radius` (added to the target radius, as with other shapes).
- Placement at release (`Pendulum.attacks`): `self` = owner centre; `self_lead` = owner centre + owner V × `Lead`; `foe_predicted` = foe centre + foe V × `Lead`. The position is fixed and does not follow anyone.
- Step (`SignatureAttacks`): once `Age ≥ Delay`, test the foe's moving sphere against the static sphere (`Geometry.movingSphere(prevTarget, target, centre, centre, Range + radius)`). The first hit resolves once (`Rules.resolveAbility`, kind `ranged`), and `Slow` applies through the existing generic path. At `Age ≥ Delay + Duration` it resolves as a miss.
- One zone per owner; a new cast replaces the old one. `BusyUntil` already covers `Duration`. FightModel uses `LandChance`.
- Readability rule (fixed camera): every zone draws a **ground-projected ring and drop shadow** so its depth is readable from the straight-on camera.

**`drain_contact`** — steal charge on the next clash (Light Bulb).
- Flow: trigger → Ready → cast **arms** the owner for `Duration` (reuse `ArmExpiry`) → the next body contact pays off.
- Payoff: the foe's signature progress `p = Signatures.progress(foe)` becomes `p × (1 − Drain)` †:
  - count triggers: `Charge = floor(Every × p')`;
  - timer: shift `LastReady`/`NextReady` so progress equals `p'` with the same span;
  - stored: `Stored ×= (1 − Drain)`;
  - seeds: remove one seed;
  - threshold/heavy: no meter, no drain.
- The owner's clash also gets `ContactBonus`.
- **Immune:** a foe that is Ready (banked, waiting for a tap), mid-windup, or armed. This is the counterplay: tap your power and it can't be stolen.
- Event: `SignatureStatus { Kind = "Drain", Target, Amount = p − p' }`.

**`fuse`** — a hot potato (Popcorn Jar).
- Fields: `Fuse` † (s), `MaxPasses` †, `PassCooldown` †, `Damage`, `SelfScale` †.
- Release puts a kernel on the foe: `s.Fuse = { Holder = foe, Until = Time + Fuse, Passes = 0, NextPassAt = Time }`.
- `beforeContact`: if `Time ≥ NextPassAt` and `Passes < MaxPasses`, the holder flips sides, `Passes += 1` and `NextPassAt = Time + PassCooldown`.
- `tick`: at `Until`, a new `FightRules.resolveFuse(state, castId, holderSide)` deals `owner.Power × Damage × overtime`, times `typeMultiplier` if the holder is the foe, or `SelfScale` (no type multiplier) if the holder is the owner. The damage kind is `"fuse"`, so mirror and guard ignore it.
- One fuse at a time. KO or round end clears it.
- Events: `SignatureStatus` `Fuse {Holder, Seconds}`, `FusePass {Holder}`, then `CastContact` on the pop.

**`mimic`** — copy the foe's last power (Moonmirror Moth).
- FightRules records `f.LastCast = { Shape, Params }` (a clone) on each `CastRelease`.
- The Moth's cast calls `begin(state, side, emit, overrides)`. The overrides are a clone of the foe's `LastCast.Params`, with:
  - `Damage`, `Heal`, `Mitigation`, `ContactBonus` and `MarkDamage` × `CopyScale` †;
  - `Windup = max(own, copied)`;
  - cadence fields (`Trigger`, `Every`, `First`, `Interval`, `Jitter`, `MaxCasts`, `HealBelow`, `Threshold`, `Cooldown`) stripped, so the Moth keeps its own timer.
- **Copyable:** projectile, volley, cone, breath, pulse, ray, sweep, orbit, zone, heal, guard, boost, mirror, slow_contact, mark_contact, drain_contact, fuse. Contact payoffs arm the Moth's next clash for 4 s.
- **Fallback** (no foe cast yet, or the foe uses contact / armed_contact / echo_contact / seed_contact / mimic): **Moonbeam**, a `ray` with Range 8, Damage 0.5, LandChance 0.65.
- Self-shapes (heal/guard/boost/mirror) apply to the Moth.
- The `CastStart` event carries `Copied = <foe kit id>` so the presentation can tint the copy.

### 3.2 Field extensions (no new shape)

| Extension † | Used by | Change |
|---|---|---|
| heavy trigger may start any shape | Fishbowl | `Traits.damaged` "heavy" currently only arms contact; when `Shape ~= "armed_contact"`, call `begin` instead |
| stored `ReadyAt`, damage read at cast | Piggy Bank, Conch | Ready only once `Stored ≥ ReadyAt × cap`. **Damage is snapshotted when the cast starts**, not at Ready, so waiting to tap lets it fill to the cap |
| sweep `Plane = "horizontal"` | Glass Top | `sweepPoint` uses the horizontal perpendicular instead of `Up`; `Arc` up to 2π (full spin around the owner) |
| `Cycle = { {Shape, …overrides}, … }` | Potion Flask, Kaleidoscope | Cast n uses `Cycle[(n + Offset) % #Cycle + 1]` with `Offset = floor(Rng × #Cycle)` at round start; `SignatureReady`/`Charge` events carry `Next` so the model shows the coming colour |
| `Riposte = {…pulse params}` | Grizzly Guardian | When the guard blocks a body hit, call `begin` with the Riposte override immediately (skips `MinCastSeconds`, like `Reflection`) |
| `AimImpulse`, `PierceGuard` | Glass Unicorn | Boost impulse aims at the foe's centre (horizontal part, capped); the empowered clash ignores guard-shape mitigation and Jellyfish armour |
| `Push` | Tidewhale | On a sweep hit, the target's V += sweep direction × `Push` (capped, same treatment as `Impulse`) |
| boost `Mitigation`, `Drive < 1` | Jellyfish | Body hits taken during the boost are reduced by `Mitigation`; Drive 0.85 visibly slows the swing |
| orbit `Center = "self"`, `PullsSelf = false` | Message Bottle | The well sits on the owner and pulls only the foe |
| `Shots`, `ShotParams` | Crystal Crown | Release stores N shots (`StoreSeconds`); each later turnaround fires one projectile. Optional per-shot tap (open question 4) |
| `Rebirth = {threshold sub-kit}`, `Then = {overrides}`, pulse `SelfHeal` | Glass Phoenix | One latched threshold cast that preempts the normal kit; afterwards `Signature.Kit` is cloned with `Then` applied; `SelfHeal` heals at release (not in overtime) |

---

## 4. The 26 new glassies

Each block lists the model, the kit (trigger → Ready → effect), the numbers, why a tap helps, counterplay, and the VFX brief. **VFX tiers** (so workstream E can follow):

| Tier | Budget |
|---|---|
| Common | 1 burst emitter + 1 sound; anticipation is a model wiggle |
| Uncommon | + Trail or Beam |
| Rare | + one Blender VFX mesh piece + PointLight flash |
| Epic | + a distinct anticipation animation on the model and a two-stage release |
| Legendary | + bespoke VFX mesh set, a 0.04 s presentation hold on a landed hit, and its own sound layer |
| Mythic | full sequence (≥ 0.4 s anticipation, 3 beats), screen-edge tint on the local side only, and a signature shatter style |

The mobile cap is 100 particles/s per emitter for every tier.

### Launch — 12

#### 1. Fishbowl `fishbowl` · Common · Heavy · Launch
*Personality: a round, calm bowl with a tiny orange glass fish who thinks he's in charge.*
- **Model:** sphere bowl with a wide open rim; radius **0.9**; hang loop on the rim. **Moving part:** the fish (separate `Details` mesh) swims a slow loop inside, and the water surface disc wobbles. 16 shards; the fish stays whole and drops with them.
- **Kit — Fish Flip:** a body hit of ≥ 12% max HP → **Ready** → the fish leaps out toward the foe and back (two legs share one damage budget).
  `Trigger="heavy", Threshold=0.12, Shape="projectile", Path="return", Pulses=2, Range=6, Radius=0.3, Damage=0.7, Windup=0.25, Duration=1.0, LandChance=0.65` · EV ≈ 0.057 (heavy hits ≈ every 8 s)
- **Why tap:** the direction locks at release. Tap when the foe is in front of the bowl, not when it's swinging past.
- **Counter:** many light hits never trigger it (Lemonade, Salt, Bee). Big hitters (Pop, Rocket Pop, Mason) feed it.
- **VFX (Common):** anticipation: water sloshes and the fish turns to face out · release: fish arc plus a 4-drop splash · impact: water splat and a fish "boing" · colour #5BC8FF, fish #FF8A3D.

#### 2. Cookie Jar `cookie_jar` · Common · Heavy · Launch
*Personality: generous grandma energy, throws crumbs back when bumped.*
- **Model:** squat jar with a big glass-cookie lid knob (the hang point); radius **0.88**; 3–4 glass cookies inside. **Moving part:** the lid rattles on each Charge, and the cookies shuffle.
- **Kit — Crumb Toss:** take 2 body clashes → **Ready** at the next turnaround → 3 crumbs fly in a fan.
  `Trigger="received", Every=2, Shape="volley", Range=6, Radius=0.16, Arc=0.6, Pulses=3, Damage=0.5, Windup=0.3, Duration=0.6, LandChance=0.65` · EV ≈ 0.065 (compare Water Jug, deliberately lower)
- **Why tap:** volleys aim with lead. Tap while the foe swings toward you so the fan crosses its path.
- **Counter:** ranged kits that never clash (Prism, Icicle) never charge it; Light Bulb drains its count.
- **VFX (Common):** lid hop · crumb pips with a tiny dust trail · cookie-crack puff · #E8B77A with chocolate-chip specks.

#### 3. Glass Top `glass_top` · Uncommon · Sharp · Launch
*Personality: dizzy and delighted, always spinning.*
- **Model:** classic spinning top (lathe shape), candy stripes in the glass, tip down, handle knob up (the hang point); radius **0.65**. **Moving part:** the body spins slowly on its axis while idle; the spin speeds up through windup (cosmetic, like Hourglass; the hang point is preserved).
- **Kit — Spin Out:** 2 turnarounds → **Ready** → the top whirls and a flat ring of glass sweeps all the way round it.
  `Trigger="turnaround", Every=2, Shape="sweep", Plane="horizontal"†, Arc=6.28, Range=1.8, Radius=0.5, Damage=0.55, Windup=0.4, Hold=0.6, Duration=0.5, LandChance=0.55` · EV ≈ 0.061
- **Why tap:** the reach is short. Tap as the foe closes in (the CAST button pulses harder then); `Hold` covers the last moment.
- **Counter:** anything that keeps its distance (Prism, Kaleidoscope ray, Icicle); slows (Pickle, Honey) let the spin end before contact.
- **VFX (Uncommon):** stripes blur, rising whistle · horizontal Trail ring · glint ticks where it touches · #FF6FB1 / white stripes.

#### 4. Bubble Wand `bubble_wand` · Uncommon · Fizzy · Launch
*Personality: giggly, leaves surprises floating around.*
- **Model:** glass ring wand on a short twisted handle (the hang point is the handle end); radius **0.6**; a thin iridescent film disc in the ring. **Moving part:** the film disc bulges and relaxes slowly (shape-key or scale pulse).
- **Kit — Bubble Trap:** timer → **Ready** → blows one big floating bubble just ahead of itself. The bubble hangs in place, and the first time the foe touches it, it pops for damage.
  `Trigger="timer", First=5, Interval=7, Jitter=0.8, Shape="zone"†, At="self_lead", Lead=0.25, Range=1.2, Radius=0.1, Damage=0.75, Windup=0.3, Duration=4, LandChance=0.55` · EV ≈ 0.056
- **Why tap:** the bubble goes where the wand is heading. Tap on the downswing through the middle of the arena, where the foe will pass, not at an apex.
- **Counter:** erratic swings that avoid the spot; Galaxy/Message Bottle wells drag the foe off line; it only hits once.
- **VFX (Uncommon):** the film stretches · a bubble mesh with a rainbow fresnel and a ground ring · pop ring plus 6 droplets · #B9F3FF iridescent.

#### 5. Piggy Bank `piggy_bank` · Uncommon · Heavy · Launch
*Personality: thrifty; saves every bump for later.*
- **Model:** rounded glass pig, coin slot on top, curly tail; radius **0.85**; hang loop on the back. Glass coins inside show the stored amount. **Moving parts:** the tail curls and the ears twitch; the internal coin stack (3 stages) rises with `Stored`.
- **Kit — Spare Change:** stores 35% of the damage taken (cap 12% max HP) → **Ready** once half full → shoots its savings as 3 coins. Damage = what's saved.
  `Trigger="stored", StoreFraction=0.35, StoreCap=0.12, ReadyAt=0.5†, Shape="volley", Range=7, Radius=0.16, Arc=0.45, Pulses=3, Damage=0.6 (cap; actual = min(Damage, Stored/Power)), Windup=0.3, Duration=0.6, LandChance=0.65` · EV ≈ 0.05 at a full cap
- **Why tap:** a real choice. Fire at half (safe, smaller) or wait for full (bigger, but you might shatter first). The amount is read when you tap.
- **Counter:** don't hit it (ranged kits charge it too; only very short fights starve it); Light Bulb drains the piggy's savings by half.
- **VFX (Uncommon):** coins jingle up the slot · three glass coins with Trails · coin "clink" sparkle · #FF9CC2, coins #FFE07A.

#### 6. Light Bulb `light_bulb` ★ · Rare · Sharp · Launch
*Personality: bright idea, fragile ego; jealous of everyone else's power.*
- **Model:** pear bulb with a glass screw base (the hang point at the base tip); radius **0.75**; a filament in the middle. **Moving part:** the filament (emissive mesh) flickers on an idle loop and brightens per Charge.
- **Kit — Power Surge:** 3 clashes → **Ready** → the filament blazes for 4 s → the next clash drains half the foe's power meter and hits a bit harder.
  `Trigger="contact", Every=3, Shape="drain_contact"†, Drain=0.5, ContactBonus=0.35, Windup=0.15, Duration=4` · compare Ketchup/Pickle. The value is denial: half a meter is about 2–3 s of the foe's cadence.
- **Why tap:** watch the foe's charge pips. Tap when they are nearly full and a clash is coming. Wait too long and the foe goes Ready, and Ready can't be drained.
- **Counter:** **tap your own CAST promptly** (teaches the button). Threshold and heavy kits have no meter to drain. Ranged kits clash less.
- **VFX (Rare):** filament ramps, glass hum · a Beam arc from foe to bulb on payoff, carrying the foe's signature colour · a PointLight flash, then the foe's charge pips visibly drop · #FFF4A8 with an electric white core.

#### 7. Potion Flask `potion_flask` ★ · Rare · Fizzy · Launch
*Personality: a bubbling mystery; even it doesn't know what's next, but you can see it.*
- **Model:** round-bottom flask, cork stopper (the hang point), liquid fill inside; radius **0.75**. **Moving parts:** rising bubbles in the liquid; **the liquid colour tweens to the next brew** (green / pink / gold).
- **Kit — Mystery Brew:** 3 turnarounds → **Ready** → drinks the brew shown in the liquid. The order repeats; the start is random each round.
  `Trigger="turnaround", Every=3, Cycle†={ {Shape="slow_contact", Slow=0.75, StatusSeconds=1.6, Immunity=2.5, Duration=4}, {Shape="mark_contact", MarkDamage=0.45, StatusSeconds=4, Duration=4}, {Shape="heal", Heal=0.06, Windup=0.45, Duration=0.35} }, Windup=0.2` · average ≈ 0.055 equivalent. The contact brews arm the next clash for 4 s.
- **Why tap:** you know which brew is next. Tap heal when hurt and nothing is incoming; tap slow or mark as a clash is about to happen.
- **Counter:** dodge clashes during the 4 s arm; Light Bulb drains it; burst it before the heal brew comes round.
- **VFX (Rare):** cork pops up, liquid boils · brew-coloured swirl mesh around the flask, then a green tether / pink splat / gold sparkle · matching impact · #6CFF9A, plus #FF7AC8 and #FFD34E per brew.

#### 8. Honey Bear `honey_bear` ★ · Epic · Heavy · Launch
*Personality: cuddly, sticky, leaves a mess everywhere.*
- **Model:** bear-shaped squeeze bottle with a cone cap (the hang point); amber honey fill; radius **0.8**. **Moving parts:** a slow drip forms at the cap and falls on a loop; the ears wiggle.
- **Kit — Honey Puddle:** 3 turnarounds → **Ready** → squeezes a floating honey blob where it is. A foe that swings through it is slowed and takes a little damage.
  `Trigger="turnaround", Every=3, Shape="zone"†, At="self", Range=1.5, Radius=0.1, Damage=0.3, Slow=0.7, StatusSeconds=1.8, Immunity=2.5, Windup=0.35, Duration=4, LandChance=0.6` · EV ≈ 0.036 damage + slow ≈ 0.056
- **Why tap:** Ready comes at a turnaround (the edge of the arena), but the blob is placed where the bear is **when you tap**. Wait until the bear swings through the middle, where clashes happen.
- **Counter:** ranged kits don't care (Prism, Icicle, Crown); slow immunity after a slow; Unicorn's aimed dash punches through.
- **VFX (Epic):** two-stage. The bear squeezes (body squash), then a honey rope stretches out and snaps into a glossy blob mesh with a ground ring · the slowed foe gets honey strands and a "stuck" wobble · #FFB92E, deep amber core.

#### 9. Crystal Ball `crystal_ball` ★ · Epic · Fizzy · Launch
*Personality: "It saw this battle coming." Smug, mysterious.*
- **Model:** perfect sphere on a small claw-foot stand (the hang loop at the top); radius **0.8**; a swirl mesh inside. **Moving part:** the inner nebula swirl rotates and the eyes-in-the-mist pulse.
- **Kit — Foresight:** timer → **Ready** → a rune circle appears **where the foe is about to be** → 0.6 s later a star strikes that spot.
  `Trigger="timer", First=6, Interval=8, Jitter=0.8, Shape="zone"†, At="foe_predicted", Lead=0.7, Delay=0.6, Range=1.1, Radius=0.1, Damage=0.95, Windup=0.3, Duration=0.3, LandChance=0.5` · EV ≈ 0.057, landing as one big hit
- **Why tap:** prediction is linear. Tap when the foe is in a clean free swing, not about to clash or turn. Skilled players read the arc; auto still lands half the time.
- **Counter:** chaos. A clash or turnaround inside the 0.7 s breaks the prediction. Mirror catches it (ranged). Fast Sharps swing out of it.
- **VFX (Epic):** two-stage. The swirl speeds up and the eyes glow, then a ground rune circle plus a column fade-in at the predicted spot · a star falls with a Trail · a star-burst ring · #C9B5FF, gold runes #FFE07A.

#### 10. Grizzly Guardian `grizzly_guardian` ★ · Legendary · Heavy · Launch
*Personality: "The shelf's protector." Slow, patient, roars only when pushed.*
- **Model:** giant chunky crystal bear sitting upright, faceted planes; radius **1.0** (the largest; check the arena gap). Hang ring on the back of the head. **Moving parts:** the ears swivel and the chest heaves (breathing scale); the eyes glow at Ready.
- **Kit — Guardian Roar:** take 3 body clashes → **Ready** → raises a crystal guard for 3 s → if the guard blocks a clash, it **roars** an instant pulse back.
  `Trigger="received", Every=3, Shape="guard", Mitigation=0.45, Windup=0.15, Duration=3, Riposte†={Shape="pulse", Range=5, Radius=0.12, Damage=0.45, Windup=0.1, Duration=0.5, LandChance=0.85}` · compare Jam; with the roar ≈ 0.06
- **Why tap:** the guard lasts only 3 s. Tap as the foe swings in; an auto guard often wastes itself on a quiet swing.
- **Counter:** ranged attacks ignore the guard and don't trigger the roar (Prism, Crystal Ball, Crown); Glass Unicorn pierces guards; Light Bulb drains its count.
- **VFX (Legendary):** the bear rears up and crystal plates fold across its chest · plate mesh lights up · on block: a gold ring, a short 0.04 s hold, a roar shockwave mesh, and its own low-glass "ROAR" layer · #FFC96B with an ice-white rim.

#### 11. Glass Unicorn `glass_unicorn` ★ · Legendary · Sharp · Launch
*Personality: "Its horn always finds the crack." Brave, show-off.*
- **Model:** prancing unicorn, spiral horn, flowing mane in separate glass ribbons; radius **0.8**; hang point between the shoulders. **Moving parts:** the mane and tail ribbons sway (2–3 bones or separate meshes); the horn sparkle travels up the spiral.
- **Kit — Rainbow Charge:** 2 turnarounds → **Ready** → dashes toward the foe on a rainbow; the next clash hits harder and **ignores guards**.
  `Trigger="turnaround", Every=2, Shape="boost", AimImpulse=1.6†, Drive=1.12, ContactBonus=0.3, PierceGuard=true†, Rebound=1.15, Windup=0.35, Duration=1.5` · compare Glass Cup and Rocket Pop: shorter window, aimed
- **Why tap:** the dash aims at the foe at the moment of the tap. Tap at the start of a downswing with the foe ahead, so the clash comes inside 1.5 s.
- **Counter:** Heavy types (type chart); slows blunt the dash; a foe swinging away makes it whiff; mimic (Moth) copies the dash.
- **VFX (Legendary):** the horn charges up and the mane lifts · a rainbow Trail plus hoof-spark stars behind the dash · on a pierced guard, a guard-shatter mesh, a 0.04 s hold and a chime-whinny layer · #FFD6F5 with a rainbow gradient.

#### 12. Glass Phoenix `glass_phoenix` · Mythic · Sharp · Launch
*Personality: proud firebird of sunfire glass; the lower it gets, the brighter it burns.*
- **Model:** a phoenix with swept wings, a long three-feather tail and a crest; radius **0.85**; hang point at the back. **Moving parts:** slow wing beats and tail-feather sway; an inner ember glow that gets stronger in phase 2.
- **Kit — Ember Feathers → Rebirth Flare** (two phases; Mythic complexity, not extra power):
  - **Phase 1:** 3 turnarounds → **Ready** → one feather shot.
    `Trigger="turnaround", Every=3, Shape="projectile", Range=8, Radius=0.16, Damage=0.35, Windup=0.3, Duration=0.55, LandChance=0.65` (EV ≈ 0.045; the trade-off for having a Rebirth)
  - **Rebirth** † at 30% HP (once): **Ready** → bursts into flame: a pulse plus self-heal.
    `Rebirth={Threshold=0.3, Shape="pulse", Range=6, Radius=0.15, Damage=0.5, SelfHeal=0.08, Windup=0.55, Duration=0.6, LandChance=0.75}`
  - **Phase 2** (`Then`): feathers become a 3-feather volley.
    `Then={Shape="volley", Pulses=3, Arc=0.5, Damage=0.5}` (EV ≈ 0.065)
- **Why tap:** the Rebirth heal happens either way, but holding the flare (up to `AutoSeconds`) until the foe is close makes the pulse land.
- **Counter:** burst it from 35% to 0 with big hits; hit it during the 0.55 s Rebirth windup; heal and pulse are disabled in overtime; no revive, ever.
- **VFX (Mythic):** 3 beats. (1) Phase 1: a feather Trail. (2) Rebirth: the body cracks with light, wings flare wide, 0.45 s of ember swirl, then a fire-glass ring pulse and a bright heal shimmer; the local side's screen edge goes warm. (3) Phase 2: a permanent ember aura and gold feather volleys. Shatter style: the shards fall as glowing feathers. #FF7A2E → #FFD34E.

### Week 1 — Kitchen & Sweets (Oct 30–31)

#### 13. Salt Shaker `salt_shaker` · Common · Sharp · W1
*Personality: small, sharp-tongued, a pinch goes a long way.*
- **Model:** slim faceted shaker, metal-look glass cap with holes (the hang point); radius **0.55**; grains inside. **Moving part:** the grains shift with swing tilt.
- **Kit — Pinch of Salt:** 2 turnarounds → **Ready** → a wide, short spray of 4 grains.
  `Trigger="turnaround", Every=2, Shape="volley", Range=5.5, Radius=0.12, Arc=0.8, Pulses=4, Damage=0.5, Windup=0.25, Duration=0.5, LandChance=0.6` · EV ≈ 0.06
- **Why tap:** short range. Tap when the foe is near, not across the arena.
- **Counter:** distance; Mirror catches it; Heavy types shrug it off.
- **VFX (Common):** cap shake · white grain pips · tiny sparkle hits · #F4F7FA.

#### 14. Cocoa Mug `cocoa_mug` · Common · Heavy · W1
*Personality: warm, cozy, a little marshmallowy.*
- **Model:** chunky mug with a handle (the hang loop on the handle top); cocoa fill with 3 marshmallow cubes; radius **0.8**. **Moving part:** the marshmallows bob; steam wisps (client emitter) idle.
- **Kit — Marshmallow Cushion:** take 2 clashes → **Ready** → marshmallows puff up and soften the next clash.
  `Trigger="received", Every=2, Shape="guard", Mitigation=0.4, Windup=0.15, Duration=2.5` · compare Jam (turnaround ×2, 0.4, 2 s)
- **Why tap:** time the 2.5 s cushion to the next incoming swing.
- **Counter:** ranged attacks; Unicorn pierce; it only blocks one clash.
- **VFX (Common):** marshmallows swell · a soft white puff shield · a "poff" block puff · #A8683F / #FFE9D6.

#### 15. Popcorn Jar `popcorn_jar` · Rare · Heavy · W1
*Personality: excitable; things around it go POP.*
- **Model:** red-and-white striped glass tub, flared top, popcorn heaped over the rim; radius **0.85**; the hang point is a handle loop. **Moving part:** a kernel on top hops on each Charge.
- **Kit — Hot Kernel:** 3 turnarounds → **Ready** → flicks a glowing kernel onto the foe. It pops after 3 s on **whoever is holding it**; every clash passes it to the other side (max 2 passes).
  `Trigger="turnaround", Every=3, Shape="fuse"†, Fuse=3, MaxPasses=2, PassCooldown=0.3, Damage=1.0, SelfScale=0.6, Windup=0.25, Duration=3` · net EV ≈ 0.05 (it lands on the foe about 60% of the time)
- **Why tap:** tap when the foe is swinging **away**: fewer clashes before the pop means fewer chances to pass it back.
- **Counter:** clash to pass it back, ideally late; mirror and guard do nothing; Light Bulb drains it.
- **VFX (Rare):** a kernel mesh with a fuse-sparkle Trail and a shrinking countdown ring around the holder · a pass is a little hop arc · the pop is a popcorn burst mesh plus a light flash · #FF5A4E / #FFF8E8.

#### 16. Glass Lollipop `glass_lollipop` ★ · Epic · Fizzy · W1
*Personality: "Swirly, sweet and not for licking." Hypnotic.*
- **Model:** big flat spiral disc on a stick (the stick end is the hang point); radius **0.7**. **Moving part:** the spiral disc rotates slowly (visible hypno swirl).
- **Kit — Sugar Swirl:** timer → **Ready** → a spinning candy ring wave that slows the foe.
  `Trigger="timer", First=6, Interval=8, Jitter=0.8, Shape="pulse", Range=6, Radius=0.12, Damage=0.4, Slow=0.72, StatusSeconds=1.6, Immunity=2.5, Windup=0.4, Duration=0.7, LandChance=0.75` · EV ≈ 0.036 + slow ≈ 0.055
- **Why tap:** the pulse reaches 6 studs. Tap when the foe is inside that and about to swing toward you, so the slow lands before the clash.
- **Counter:** distance; slow immunity; Grizzly's guard doesn't stop ranged attacks, but Mirror does.
- **VFX (Epic):** the spiral spins up to a blur, then the disc pulses · a candy-striped ring mesh expands · the slowed foe gets an orbiting swirl · #FF7AC8 / #FFFFFF.

### Week 2 — Toy Box (Nov 6–7)

#### 17. Wind-Up Robot `wind_up_robot` · Uncommon · Heavy · W2
*Personality: clank, clank, determined; gets going once it's wound up.*
- **Model:** boxy toy robot, round eyes, wind-up key on its back; the hang point is the head antenna loop; radius **0.8**. **Moving parts:** **the key turns** (one notch per Charge, spins during the boost); the arms swing.
- **Kit — Wind-Up March:** 3 clashes → **Ready** → marches harder for 3 s; every clash in that window hits harder.
  `Trigger="contact", Every=3, Shape="boost", Drive=1.14, ContactBonus=0.2, ContinuousBonus=true, Windup=0.35, Duration=3` · compare Hot Sauce (repeatable, not a one-off)
- **Why tap:** tap right after a turnaround heading back in, so the 3 s covers the next clashes.
- **Counter:** keep away for 3 s; slows; Pickle stretches the swing.
- **VFX (Uncommon):** fast key spin with a ratchet tick · an exhaust-puff Trail · a gear-spark hit · #9FB4C7, key #FFB45C.

#### 18. Kaleidoscope `kaleidoscope` · Rare · Sharp · W2
*Personality: a show-off artist; never the same trick twice.*
- **Model:** glass tube with a faceted end cap; the hang loop is mid-tube; radius **0.6**. **Moving part:** **the end cap rotates** and its coloured chips form the next pattern (ray / fan / cone icon).
- **Kit — Pattern Shift:** timer → **Ready** → fires the pattern shown at its tip. The cycle is ray → volley → cone, starting at random.
  `Trigger="timer", First=5, Interval=7.5, Jitter=0.8, Cycle†={ {Shape="ray", Range=8, Radius=0.14, Damage=0.6, Duration=0.14, LandChance=0.65}, {Shape="volley", Range=7, Radius=0.16, Arc=0.5, Pulses=3, Damage=0.7, Duration=0.6, LandChance=0.65}, {Shape="cone", Range=5, Radius=0.15, Arc=1.0, Damage=0.7, Duration=0.3, LandChance=0.7} }, Windup=0.35` · EV ≈ 0.057 on average
- **Why tap:** each pattern has a best moment: the ray when the foe is lined up and far, the volley at mid range, the cone up close. The tip shows which is next.
- **Counter:** Mirror (Tumbler) catches the ray and volley; Crystal Ball is unaffected; any heavy hitter up close.
- **VFX (Rare):** the end cap spins and clicks into place · a coloured mesh fan matching the pattern · prism-chip impacts · #7E6BFF with rotating rainbow chips.

#### 19. Crystal Crown `crystal_crown` ★ · Legendary · Sharp · W2
*Personality: "Fit for the shelf's royalty." Regal, a bit bossy.*
- **Model:** five-point crown with a gem on each point (3 large gems are separate meshes); the hang point is the centre top ring; radius **0.85**. **Moving part:** the gems rotate slowly in their settings.
- **Kit — Crown Jewels:** timer → **Ready** → three gems lift off and orbit the crown (8 s) → each following turnaround fires one gem.
  `Trigger="timer", First=6, Interval=10, Jitter=1, Shots=3†, StoreSeconds=8, ShotParams={Shape="projectile", Range=8, Radius=0.16, Damage=0.3, Windup=0.15, Duration=0.55, LandChance=0.65}, Windup=0.3` · EV ≈ 0.056
- **Why tap:** proposed: the first tap summons the gems, and each later tap fires one gem early (0.6 s minimum gap) instead of waiting for the turnaround. See open question 4.
- **Counter:** Mirror catches gems one at a time; burst it during the 8 s; gems not fired before the 8 s run out pop harmlessly.
- **VFX (Legendary):** gems rise with a royal chord · orbit Trails, then each shot is a gem dart with a crown-glint · a gem-facet burst, a 0.04 s hold on the third hit, and its own fanfare-chime layer · #FFE07A with ruby/sapphire/emerald gems.

### Week 3 — Sky (Nov 13–14)

#### 20. Icicle `icicle` · Uncommon · Sharp · W3
*Personality: cool, quiet, drops in out of nowhere.*
- **Model:** long tapered icicle with frozen drip rings; the hang point is the thick top; radius **0.45** (slim; collision radius at the widest ring). **Moving part:** a single meltwater drip forms at the tip and falls.
- **Kit — Icicle Drop:** timer → **Ready** → snaps off a shard that flies straight at the foe.
  `Trigger="timer", First=5, Interval=7, Jitter=0.6, Shape="projectile", Range=9, Radius=0.12, Damage=0.7, Windup=0.4, Duration=0.5, LandChance=0.6` · EV ≈ 0.058 (a sidegrade to Prism: slower travel, more damage)
- **Why tap:** it leads the target. Tap when the foe is on a steady arc, not when it's about to turn.
- **Counter:** Mirror; erratic swings; Heavy types.
- **VFX (Uncommon):** frost creeps down the icicle · a shard with a frost Trail · an ice-crack puff · #CFF4FF.

#### 21. Glass Bee `glass_bee` · Uncommon · Sharp · W3
*Personality: busy, buzzy, stings and zooms off.*
- **Model:** round bee with striped amber/clear glass, tiny wings and a little stinger; the hang point is the back between the wings; radius **0.6**. **Moving parts:** **wings flutter fast** (alpha-faded flap); the antennae bob.
- **Kit — Buzz Sting:** 2 clashes → **Ready** → the next clash stings, and the clash after that pops the sting for bonus damage.
  `Trigger="contact", Every=2, Shape="mark_contact", MarkDamage=0.3, StatusSeconds=3, Windup=0, Duration=0.2` · compare Ketchup (×3, 0.5, 4 s): the same damage per clash, faster and smaller
- **Why tap:** the mark lasts 3 s. Tap when a clash is coming and another will follow soon (the CAST pulse helps).
- **Counter:** stay away for 3 s after the sting; guards soften the pop.
- **VFX (Uncommon):** wings blur with a buzz · a stinger glint plus a yellow mark dot on the foe · a honey-gold pop · #FFD23F / clear stripes.

#### 22. Moonmirror Moth `moon_moth` · Mythic · Sharp · W3
*Personality: shy, silver, borrows your best trick.*
- **Model:** a moth with large mirror-glass wings (fresnel silver) and feathery antennae; the hang point is the thorax top; radius **0.8**. **Moving parts:** slow wing flaps; **the wing faces show the copied power's colour** after a copy.
- **Kit — Mirror Wings:** timer → **Ready** (the CAST button shows the icon of the power it will copy) → casts the foe's last released power at 80%.
  `Trigger="timer", First=6, Interval=9, Jitter=1, Shape="mimic"†, CopyScale=0.8, Windup=0.4, Fallback={Shape="ray", Range=8, Radius=0.14, Damage=0.5, Duration=0.14, LandChance=0.65}` · EV ≈ 0.8 × the foe's per-cast value; tune `CopyScale` so the mirror match sits at 50%
- **Why tap:** tap right after the foe releases its big move, so you copy the freshest one at the best moment for its shape.
- **Counter:** **delay your own taps** so the Moth has nothing (or something small) to copy; contact-family kits (Pop, Briar, Comet) leave it with only Moonbeam.
- **VFX (Mythic):** 3 beats. (1) The wings fold and reflect the foe (a mirror fresnel flash). (2) Silver dust swirls, and the copied shape appears in the foe's colour with a silver outline. (3) The impact uses the copied effect plus moon-dust motes. The local screen edge gets a silver tint. Shatter style: shards scatter like moonlit wing scales. #D9E4FF.

### Week 4 — Deep Sea (Nov 20–21)

#### 23. Conch Shell `conch_shell` · Common · Sharp · W4
*Personality: hold it up and you hear the ocean… and then the ocean hits back.*
- **Model:** spiral conch with pink lip, pointy spire; the hang point is the spire tip; radius **0.7**. **Moving part:** a pearly sheen sweeps along the spiral; a sand trickle on the Charge stages.
- **Kit — Sea Roar:** stores 40% of the damage taken (cap 10% max HP) → **Ready** when half full → releases a wave ring sized by what it stored.
  `Trigger="stored", StoreFraction=0.4, StoreCap=0.1, ReadyAt=0.5†, Shape="pulse", Range=6, Radius=0.12, Damage=0.55 (cap), Windup=0.3, Duration=0.6, LandChance=0.75` · EV ≈ 0.05
- **Why tap:** fire small now or wait to fill; the pulse needs the foe within 6 studs.
- **Counter:** distance at the moment it fires; Light Bulb drains it.
- **VFX (Common):** the shell glows from inside with a whoosh · a blue ring wave · a spray puff · #FFB6A6, wave #5BC8FF.

#### 24. Message in a Bottle `message_bottle` ★ · Rare · Fizzy · W4
*Personality: "Washed up with a secret inside." Adventurous, always drifting.*
- **Model:** corked bottle (the hang point at the cork) with a rolled scroll inside; radius **0.62**. **Moving parts:** the scroll slowly turns; a little water line sloshes.
- **Kit — Whirlpool:** timer → **Ready** → a whirlpool spins up around the bottle, pulling the foe toward it, then splashes.
  `Trigger="timer", First=7, Interval=10, Jitter=1, Shape="orbit", Center="self"†, PullsSelf=false†, Range=3, Radius=0.15, Force=1.5, Damage=0.4, Windup=0.45, Duration=1.1, LandChance=0.7` · EV ≈ 0.027 + the forced clash ≈ 0.055 (the same budget as Galaxy Orb, which pulls both sides from the midpoint)
- **Why tap:** tap when the foe is just outside 3 studs and heading past, so the pull drags it into a clash.
- **Counter:** a heavy-hitting foe welcomes the clash; Galaxy's own well fights it; keeping out of 3 studs.
- **VFX (Rare):** the scroll unrolls a little and the cork spins · a spiral-water mesh plus a Beam for the pull · the end splash ring · #9FE8D8, deep #2FA8D8.

#### 25. Glass Jellyfish `jellyfish` · Epic · Fizzy · W4
*Personality: floaty, glowy, don't-touch-me.*
- **Model:** domed bell with 6 trailing ribbon tentacles; the hang point is the dome top; radius **0.8** (the bell; tentacles don't collide). **Moving parts:** **the bell pulses** (scale) and the tentacles ripple (bones or staggered meshes).
- **Kit — Drift & Sting:** take 3 clashes → **Ready** → drifts slowly for 3.5 s: clashes hurt it less and sting the foe.
  `Trigger="received", Every=3, Shape="boost", Drive=0.85†, Mitigation=0.3†, ContactBonus=0.25, ContinuousBonus=true, Windup=0.3, Duration=3.5` · compare Hot Sauce + Jam
- **Why tap:** tap as the foe winds up a heavy return, so the armour and sting cover it.
- **Counter:** ranged attacks bypass the armour (mitigation is body only); Unicorn pierces it; it is slow, so ranged kits pick at it.
- **VFX (Epic):** two-stage. The bell contracts and glow rings run down the tentacles, then a soft bioluminescent aura plus tentacle Trails · sting hits show an electric-pink zap · #FF9EF0, core #9CFFD8.

#### 26. Tidewhale `tidewhale` · Legendary · Heavy · W4
*Personality: gentle giant of the deep; one splash and everything moves.*
- **Model:** a rounded whale with a big tail fluke and a blowhole; the hang point is mid-back; radius **1.0** (check the arena gap with Grizzly). **Moving parts:** the tail fluke beats slowly; blowhole mist; the eyes blink.
- **Kit — Tidal Breach:** 3 turnarounds → **Ready** → the whale rears and a glass wave crashes down in front of it, knocking the foe into a wild swing.
  `Trigger="turnaround", Every=3, Shape="sweep", Range=4.5, Radius=0.8, Arc=1.6, Damage=0.5, Push=1.4†, Windup=0.6, Hold=0.6, Duration=0.6, LandChance=0.6` · EV ≈ 0.06 + Push (which also separates the glassies, so it is not a free combo)
- **Why tap:** tap when the foe is in front and closing, so the wave catches it mid-swing, where the push matters most.
- **Counter:** a foe behind or above the whale; the long windup can be read and swung away from; slows reduce the follow-up. Mirror can't catch it, because a sweep isn't a ranged shot.
- **VFX (Legendary):** the whale lifts its tail and the water rises behind it · a curling wave mesh with a foam Trail · a big splash, a 0.04 s hold, foam spray and its own whale-song layer · #2FA8D8, foam #E8FBFF.

---

## 5. Risks

1. **Engineering load at launch.** Launch needs 2 new shapes (`zone`, `drain_contact`) plus 6 extensions (heavy-any, stored ReadyAt, horizontal sweep, Cycle, Riposte, AimImpulse/Pierce, Rebirth/Then/SelfHeal) on top of A's cast system. **Fallbacks** if Thu 22 is tight:
   - Phoenix: Rebirth only (drop phase 1 and `Then`);
   - Unicorn: plain Rocket-Pop-style boost (drop Pierce);
   - Grizzly: plain guard (drop Riposte);
   - Potion: fixed slow brew (drop Cycle);
   - Light Bulb: swap to slow_contact (drop drain).

   Each fallback is an existing shape, so the glassy still ships.
2. **Kiln dilution.** A specific Legendary goes from 1.5% to 0.5% a pull at launch, and a specific Mythic from 1 in 800 to 1 in 1,200 (1 in 1,600 at 50). Players chasing one named Legendary or Mythic may feel stuck. This is mitigated by Marble odds and Daily Featured, but it needs a creator decision (open question 5).
3. **Numbers are arithmetic, not measured.** Every kit must pass `tools/release_matrix` (45–55% at equal stats) after A's retune. Heavy-trigger cadence (Fishbowl) and stored fill rates (Piggy, Conch) are the least certain.
4. **3D readability of zones.** Floating hazards seen from a fixed straight-on camera can look like hits when they aren't. A ground ring and shadow are required, and should be verified on phone.
5. **Self-damage (Popcorn).** Hot potato is a classic, but a kid may feel cheated when their own kernel pops on them. Playtest it; `SelfScale` can drop to 0.4.
6. **Mimic edge cases.** Copying a copy, copying Fuse, and overtime heals. The whitelist and fallback cover these; tests should include a Moth mirror match.
7. **Modelling throughput.** 12 full-quality models in about 2 days (Tue 20 – Thu 22) is tight. Three creatures (Grizzly, Unicorn, Phoenix) are the heaviest. If needed, slip Phoenix to W1 and launch with 11 + 3 Mythics already live.
8. **Overlap creep.** Three healers (Milk, Hourglass, Potion's heal brew) plus Phoenix's SelfHeal, and two bears. They are kept distinct by trigger and silhouette, but watch the inventory copy so each reads as one sentence.
9. **Launch type skew** (Sharp 10 of 36). Random hands will have fewer Sharps until W2–W3; the type chart stays fair, but Fizzy players see fewer counters.
10. **Arena clearance.** Grizzly (1.0) and Tidewhale (1.0) are the largest radii. Check the pad gap and string length against Glass Dragon (0.95) before export.

## 6. Open questions for the creator

1. **Approve the 12 launch picks** (or swap any for a drop glassy)?
2. Keep **perfume, jack_o_glass, starblade, glass_sword** dormant (not released) as proposed?
3. Is **self-damage** on Popcorn's hot potato OK for our audience?
4. **Crown multi-tap:** may a Legendary use several CAST taps (one per gem), or should it be strictly one tap per Ready?
5. **Kiln odds:** accept the dilution, or consider a later change (for example a small Legendary/Mythic weight bump, or a "new glassy" featured rate-up that is always shown in the odds)? This touches paid random items, so it is your call.
6. **Drop day:** Saturday drops (matching the launch Saturday), or Friday?
7. Names: any to change? (Tidewhale, Moonmirror Moth, Glass Top, Wind-Up Robot are the most invented.)

## 7. Recommended build order for the 12 launch glassies (easiest first)

| # | Glassy | Model effort | Kit effort | Why this slot |
|---|---|---|---|---|
| 1 | Cookie Jar | S (jar family) | none: existing received + volley | Zero new code; proves the Blender → Studio → kit pipeline |
| 2 | Fishbowl | S (sphere + fish) | S: heavy trigger may start any shape | One-line rule change |
| 3 | Glass Top | S (lathe) | S: sweep `Plane` | Small Pendulum change; spin reuses Hourglass's cosmetic spin |
| 4 | Piggy Bank | M | S: stored `ReadyAt`, damage at cast | The stored path already exists in Traits |
| 5 | Bubble Wand | S | **M: new `zone`** | Builds `zone` with the simplest placement (`self_lead`) |
| 6 | Crystal Ball | S (sphere + stand) | S: `zone` `foe_predicted` + `Delay` | Reuses zone |
| 7 | Honey Bear | M | S: `zone` + Slow (generic path) | Reuses zone |
| 8 | Potion Flask | S | M: `Cycle` + liquid tint | Cycle will be reused by Kaleidoscope (W2) |
| 9 | Light Bulb | S | **M: new `drain_contact`** | Needs A's Ready state (Ready-immunity) |
| 10 | Grizzly Guardian | L (creature) | S: `Riposte` | Big model, small kit |
| 11 | Glass Unicorn | L (creature, ribbons) | M: `AimImpulse`, `PierceGuard` | |
| 12 | Glass Phoenix | L (wings, feathers) | L: `Rebirth`/`Then`/`SelfHeal` | Most complex; has the cleanest fallback (Rebirth only) |

Modelling (workstream C/F) can run in parallel with kit code (A): models 1–4 Tue, 5–9 Wed, 10–12 Wed–Thu; kits follow the same order, with `zone` landing before model 5 imports.

**Drops** build in their week, each finishing with a matrix run: W1 needs `fuse`, W2 reuses `Cycle` and needs `Shots`, W3 needs `mimic`, W4 needs `Push`, boost `Mitigation` and orbit `Center`.
