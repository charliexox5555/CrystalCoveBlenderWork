# Glass Clash — Game Design Doc (v0.2)

> Working title. Alternatives: **Bottle Battles**, **Shatter Showdown**. Search Roblox for name conflicts before picking.
> **Glassies** is a placeholder name for the collectibles (like "Pokémon" or "pets"). They start as everyday bottles and become fantasy glass creations as you progress.

## 1. Pitch

Hang your glassy on a string, swing it and shatter your opponent's. You start with a humble soda bottle and work up to glass swords, pumpkins, unicorns and dragons. Beat trainers across the world and win the tournament in the lobby. The structure is like Pokémon, and every fight ends with a satisfying shatter.

- **Audience:** all ages, mostly kids. Design for **mobile first**.
- **Inspiration:** a real-life format that's been around for years. People hang glass bottles, vases and similar objects on strings over a wooden pen, swing them into each other until one breaks, and track the winners on a bracket graphic. The game should be **recognizable as that format** to anyone who has seen the videos.

### Pillars

1. **The shatter is the reward.** Every battle ends in a slow-motion, loud, sparkly shatter. If a change makes it less satisfying, don't make it.
2. **Your glassy is yours.** You name it, level it, evolve it and dress it up, and it follows you around. A loss breaks it for a moment, never for good.
3. **From kitchen to fantasy.** Early glassies are things in your kitchen. Later ones are swords, pumpkins, unicorns and dragons. Players should *see* the fantasy ones from day one (crate previews, the Champion Pedestal, other players) so they have something to chase.
4. **Easy to play, with a small skill edge.** One button. Timing matters a little, stats matter more, and luck keeps it exciting.
5. **There's always something to watch.** Lobby tournaments draw a crowd and crown a champion.

## 2. Core loop

```
Battle (NPC trainer / wild glassy / tournament / PvP)
  → earn coins + XP (+ catch wild glassies)
  → level up, evolve, open crates, fuse, buy cosmetics
  → take on tougher trainers, bosses, zones and tournaments
  → repeat
```

**Example 10-minute session:** join, claim the daily reward, repair at the bench, fight 3 trainers on Route 1. Your soda bottle **evolves into a glass rocket**, then you catch a wild glassy. A tournament is announced, so join it, lose in the semis and pick the winner of the final. Open a crate, then leave.

## 3. Battle system

### 3.1 Setup

A **Clash Stand** is a frame that looks like a **Newton's cradle or a playground swing set**. Don't make anything look like a gallows or noose. Two glassies hang from strings (rendered with a `Beam`) and the camera looks from the side.

The center **Tournament Arena** copies the real-life setup: a **wooden octagon pen** with a crossbar above, so clips look like the videos people already know.

Every glassy hangs from its **hang point**: the neck of a bottle, the hilt of a sword, the stem of a pumpkin, the top of a unicorn's head. The swing is animated rather than simulated, so odd shapes are fine.

### 3.2 One clash (~4 s)

| Phase | Time | What happens |
|---|---|---|
| Pull back | up to 1.5 s | Both players hold the button. The glassies pull back and the power meter sweeps. |
| Release | — | The player lets go. If they don't, it auto-releases at the end as **Weak**. |
| Swing | 0.5 s | Both glassies swing toward the center. |
| Impact | — | Hitstop, clink, damage numbers, crack update, camera shake. **Both take damage**, like in real life. |
| Bounce back | 0.8 s | The glassies swing back, then the next clash starts. |

When one glassy reaches 0 HP, the last impact plays in slow motion and it **shatters** (see section 8).
**Target:** an even match lasts 4–6 clashes (about 20–30 s).

### 3.3 Power meter

| Zone | Multiplier | Default width |
|---|---|---|
| Weak | ×0.7 | the rest of the bar |
| Good | ×1.0 | 40% |
| Great | ×1.15 | 15% |
| Perfect | ×1.3 | 6%, plus up to +6% from the Swing stat |

### 3.4 Damage

```
damage    = attacker.Power × swingMult × typeMult × critMult × random(0.9, 1.1)
critChance = min(0.05 + attacker.Swing × 0.0025, 0.30)   -- crit = ×1.5
typeMult  = 1.25 (strong) | 0.8 (weak) | 1.0 (neutral)
```

- **Double KO:** if both glassies hit 0 in the same clash, the one that went less far below 0 survives on 1 HP and shows **"CLUTCH!"**.
- **Balance target:** HP ≈ 5 × an equal opponent's Power.

### 3.5 Types (rock-paper-scissors)

| Type | Beats | Everyday examples | Fantasy examples | Stat lean |
|---|---|---|---|---|
| **Heavy** | Sharp | jars, jugs | pumpkin, honey bear, dragon | high Power and HP, low Swing |
| **Sharp** | Fizzy | perfume, vases | sword, unicorn (horn), crown | high Swing and crits, low HP |
| **Fizzy** | Heavy | soda, potions | crystal ball, lollipop, galaxy orb | balanced |

Show types as large colored icons, since kids read icons, not text.

### 3.6 HP and cracks

- The model shows crack stages at **75 / 50 / 25 % HP**, alongside an HP bar.
- HP **carries over between trainer and wild battles** (like Pokémon) until you repair.
- Tournaments and PvP always start at full HP.

### 3.7 Losing

- Your glassy shatters and becomes **Broken**, so it can't battle until it's repaired.
- **Repair Benches** in the lobby and halfway along each route are free. Repair plays a **reverse shatter**: the shards fly back together, glow, and you see "Good as new!" It reuses the same shard assets.
- Glassies are **never lost for good**.

### 3.8 Server authority and anti-exploit

- The **server decides everything**: HP, damage, crits and random rolls. The client only sends its release time.
- The server sends each clash's meter start time and speed. The client returns its release timestamp, and the server works out the zone, allowing for about 150 ms of latency.
- An exploiter can always claim Perfect, so keep Perfect's bonus modest (×1.3). Log each player's Perfect rate and flag anyone above 90% over 50+ clashes.
- **Don't use Roblox physics for the swing.** Glassies are anchored and each client animates them with CFrame (sine-curve pendulum). The server knows the impact times and waits before applying results.
- Shards exist **only on the client**: unanchored parts, cleaned up after 3 s, with a cap of about 150 on screen for mobile.

## 4. Glassies

### 4.1 Glassies are data

Adding a glassy should take **one config entry plus one asset folder, with no new code**. That keeps content cheap for the AI pipeline.

```lua
pop = {
	Name = "Pop",
	Type = "Fizzy",
	Rarity = "Starter",
	Base = { Power = 20, HP = 100, Swing = 10 },
	Asset = "pop",                  -- folder under ReplicatedStorage.Assets.Glassies
	ClinkPitch = 1.1,               -- smaller glassies clink higher
	EvolvesTo = { Level = 15, Id = "rocket_pop" },
	WildZones = {},                 -- starters never spawn wild
}
```

### 4.2 Rarity: from kitchen to fantasy

Rarity also signals **how fantastical** a glassy is. Commons are things in your kitchen and Mythics are creatures.

| Rarity | Feel | Stat multiplier | Coin crate odds |
|---|---|---|---|
| Common | everyday bottles and jars | 1.00 | 60% |
| Uncommon | nicer everyday glass | 1.15 | 25% |
| Rare | fancy glass (perfume, potions, light bulbs) | 1.30 | 10% |
| Epic | **fantasy begins** (pumpkins, crystal balls, candy) | 1.50 | 4% |
| Legendary | fantasy weapons and creatures (sword, unicorn, crown) | 1.75 | 0.9% |
| Mythic | big fantasy (dragon, galaxy orb) | 2.00 | 0.1% |

**Rainbow variant** (the game's version of a shiny): any glassy has a 1-in-500 chance to roll Rainbow, with iridescent glass and +5% stats.

### 4.3 Growth

- **Level 1–50:** `stat × (1 + 0.04 × (level − 1))`, so level 50 is about ×2.96.
- **XP to the next level:** `20 + 10 × level`. Tune it so the **first evolution (level 15) happens in the first ~30 minutes** and the second (level 35) within the first few hours.
- **Evolution:** at levels 15 and 35, some glassies **transform into a more fantastical form**, with a new model and name and base stats ×1.2 per stage. They keep their level, XP, stars, Rainbow status and cosmetics. Play a big transformation moment: glow, crack, burst and reveal.
- **Stars:** fuse 3 duplicates for +1 star (max 5). Each star adds +10% stats.

### 4.4 Starters and their evolution lines

Pick one on first join, from three glassies on pedestals. Each starter evolves from kitchen to fantasy:

| Starter | Type | Level 15 | Level 35 |
|---|---|---|---|
| **Pop** (soda bottle) | Fizzy | **Rocket Pop** (glass rocket) | **Comet** (glass comet with a star trail) |
| **Jam** (jam jar) | Heavy | **Honey Bear** (honey bear bottle) | **Grizzly Guardian** (big crystal bear) |
| **Prism** (perfume bottle) | Sharp | **Prism Blade** (glass sword) | **Starblade** (glowing crystal greatsword) |

Starter evolutions are **in the MVP**. Evolutions for other glassies come later.

### 4.5 Launch roster (~21 glassies + 6 starter forms)

| Rarity | Glassies |
|---|---|
| Common | Milk bottle, Pickle jar, Ketchup bottle, Glass cup, Water jug, Lemonade bottle |
| Uncommon | Mason jar, Hot sauce bottle |
| Rare | Perfume bottle, Potion flask, Message in a Bottle, Light bulb |
| Epic | **Jack-o'-Glass** (pumpkin), **Crystal Ball**, **Glass Lollipop**, **Glass Duck** |
| Legendary | **Glass Sword**, **Glass Unicorn**, **Crystal Crown** |
| Mythic | **Glass Dragon**, **Galaxy Orb** (stars swirling inside) |

Epic and higher are **fantasy glassies available from crates at launch**, before their zones exist. Kids need to see them early.

**Later ideas:** glass shark, glass cat, phoenix, pegasus, ice crown, robot, rubber duck king, glass castle, ghost jar, glass bat, ornament, snow globe, reindeer.

**No alcohol bottles** (beer, wine, champagne, liquor). This is a kids' game, and alcohol references can change its content maturity label.

## 5. World

### 5.1 Lobby: "Glass Town"

The **Tournament Arena** (wooden octagon pen) sits in the center, with a big **bracket board** in the same style as the real-life videos. Around it are the Repair Bench, Crate Shop, Cosmetic Shop (Fills and Shatter FX), the **Champion Pedestal**, leaderboards, codes, and the exit to Route 1.

### 5.2 Zones: eight badges, from kitchen to fantasy

Each zone has 5–6 trainers in a line of rising level, wild glassies, a Repair Bench halfway, and a boss (**Shelf Champion**) at the end. The boss gives a **badge**, unlocks the next zone and adds their signature glassy to crates. The zones get more fantastical as you go.

| # | Zone | Wild glassies | Ships in |
|---|---|---|---|
| 1 | Recycling Yard | milk bottles, pickle jars, ketchup | MVP |
| 2 | Sunny Beach | message bottles, sea glass, glass shells and crabs | Update 1 |
| 3 | Candy Factory | candy jars, lollipops, gummy bears, ice cream | later |
| 4 | Pumpkin Patch | Jack-o'-Glass, lanterns, ghost jars, glass bats | later (Halloween 2027) |
| 5 | Wizard Tower | potions, crystal balls, wands, glass swords | later |
| 6 | Ice Palace | snow globes, ice crowns, glass unicorns | later |
| 7 | Volcano | lava glass, glass dragons, phoenixes | later |
| 8 | Rainbow Sky Castle | pegasus, rainbow unicorns, galaxy orbs | later |

After the 8th badge comes the endgame **Glass League**.

### 5.3 NPC trainers

- Each trainer is a config entry: name, glassy id, level, **skill** (how often they hit Great or Perfect), reward and dialogue lines.
- They're standard R15 NPCs dressed with `HumanoidDescription`, so **no Blender rigging is needed**.
- The first win each day gives the full reward. Rematches give less.

### 5.4 Wild glassies and catching

- Wild glassies float, bob and glow around each zone. Walk up to one to battle it.
- Between clashes, you can **throw a Cork** instead of swinging. The wild glassy still swings at you, so you take damage and it doesn't.
- `catch = baseRate[rarity] × (0.15 + 0.85 × (1 − hp / maxHp)) × corkBonus`
  - baseRate: Common 0.9, Uncommon 0.7, Rare 0.45, Epic 0.25, Legendary 0.1
- **The tension:** shatter it and it's gone. Keep hitting, or risk the cork?
- **Corks:** basic corks are cheap for coins. **Golden Corks** (better odds) come from rewards or Robux.

## 6. Lobby tournaments

- A tournament is announced every **8 minutes**, with a 60 s countdown. Players step on the **Join Pad**.
- It's an **8-slot bracket** shown on the bracket board. **Empty slots fill with NPC bots** of matching power, so it runs even with 2 players in the server.
- Two cups alternate:
  - **Rookie Cup:** every glassy is **scaled to level 10**, so type and timing decide it and new players can win.
  - **Open Cup:** no scaling.
- **Flow:** the quarterfinals run on 4 stands at once, then the semis, then the **final in the octagon arena**. Everyone gets a "Watch the Final!" camera prompt.
- **Pick the Winner:** spectators and knocked-out players pick a finalist for free and earn coins if they're right. **No wagering.**
- **Rewards:**
  - **Winner:** 500 coins, a Champion tag above their head until the next tournament, a server-wide announcement, and **their glassy shown big and spinning on the Champion Pedestal**.
  - **Others:** 2nd 250, semifinalists 100, every entrant 25.

## 7. PvP challenges

Walk up to another player, send a **Challenge** and they accept. The battle moves to the nearest free stand at full HP, with no wagering. Wins give a small reward, capped per opponent per day so friends and alt accounts can't farm it.

## 8. Game feel checklist (the shatter)

**Every impact**
- [ ] Hitstop of 60–100 ms
- [ ] Clink sound, pitched by size, with a crack sound layered on when a new crack stage starts
- [ ] Camera shake scaled to damage
- [ ] Damage numbers, plus **PERFECT!** / **CRIT!** text
- [ ] Crack stage swaps at 75 / 50 / 25 %
- [ ] Haptic pulse on mobile and controller (`HapticService`)

**Final blow**
- [ ] Slow motion at 0.3× for about 1 s, with the camera pushing in on the impact
- [ ] One white flash frame
- [ ] Swap the glassy for its pre-fractured shards, with outward and downward velocity and spin
- [ ] Liquid splash if it's filled, plus glitter particles
- [ ] Layered shatter sound, then the tinkle of falling shards
- [ ] The **winner's Shatter FX** cosmetic plays
- [ ] **SHATTERED!** banner; shards fade after 3 s

**Test:** record the final blow on a phone. If it doesn't look great as a 3-second clip, keep tuning before building more content.

## 9. Monetization

Focus on cosmetics, and keep tournaments from being pay-to-win (Rookie Cup scaling helps).

| Item | Kind | Price idea (R$) |
|---|---|---|
| VIP (chat tag, VIP lounge, +10% coins) | Gamepass | 299 |
| 2× Coins | Gamepass | 199 |
| +10 Glassy Slots | Gamepass | 99 |
| Auto-Repair (repair anywhere) | Gamepass | 149 |
| Lucky (better crate odds and wild spawns) | Gamepass | 249 |
| Coin packs | Dev product | 25–999 |
| Glassy Crate / 10-pack | Dev product | 49 / 449 |
| Golden Corks ×3 | Dev product | 39 |
| Private server | — | ~100 |

### Shatter FX (the main cosmetic)

These play when **your** glassy wins, on the opponent's shatter. Every opponent and spectator sees them, so they advertise themselves.

| Tier | Shatter FX |
|---|---|
| Starter (free) | Default sparkle |
| Coins | Confetti, Bubbles, Ice Burst |
| Robux / events | Rainbow, Lightning, Candy Pop, **Pumpkin Burst** (seeds and candy), **Unicorn Sparkle** (rainbow glitter and stars), **Dragon Fire** (embers), Galaxy |

### Other cosmetics

- **Fills** are liquids inside your glassy that splash when it breaks (Soda, Slime, Lava, Glitter, Honey, Galaxy).
- Labels, stickers, caps and glow auras.

### Rules

- Robux crates **must show odds before purchase**.
- Check `PolicyService:GetPolicyInfoForPlayerAsync()` → `ArePaidRandomItemsRestricted`. For players where that's true, **hide Robux crates** and offer direct-buy items instead.
- Pick the Winner is free only. Never let players bet coins or Robux.

## 10. Retention and community

- 7-day login calendar (day 7 gives a crate)
- 3 daily quests: "Win 3 battles," "Get 5 Perfects," "Catch a glassy"
- Playtime gifts at 5 / 10 / 15 / 30 minutes
- **Group join reward** (a Golden Cork), which grows your community
- Codes posted on Discord and socials with every update
- Leaderboards: Most Wins, Tournament Wins, Best Win Streak, Most Glassies Shattered
- **Weekly updates:** 2–3 new glassies plus one feature, and a bigger event each season
- On Discord, the **community votes on the next glassy** and you build it with the Blender pipeline

## 11. Marketing

- **Use the Blender MCP pipeline to render bracket videos in the real-life format**, with your actual in-game models, e.g. "16 glassies, only one survives." Mix everyday bottles with fantasy ones (sword vs. unicorn vs. pumpkin), since that's something real-life videos can't do. Every glassy in a video can be collected in the game. End each video with a "Play on Roblox" card.
- Record finals in the game (the slow-mo shatter) for Shorts and TikTok.
- At launch, cross-promote from your existing 150-CCU game with a billboard or portal and a group shout.
- For the icon and thumbnails, show a fantasy glassy (sword or unicorn) mid-shatter in bright colors. A/B test them.
- Only pay for Roblox ads once D1 retention is healthy. Don't pay for traffic into a leaky game.
- **Seasonal events:**
  - Winter: snow globes, glass ornaments, glass reindeer
  - Valentine's: heart perfume bottles, glass roses
  - Halloween 2027: Pumpkin Patch zone, ghost jars, glass bats

## 12. Technical plan

### 12.1 Where the code lives

Codex writes scripts **directly into Roblox Studio through the Roblox MCP server**. Keep this hierarchy so every session finds things in the same place:

```
ServerScriptService/
  Main (Script)                    -- requires and starts every service
  Services/ (ModuleScripts)
    DataService                    -- ProfileStore, schema, migrations
    BattleService                  -- battle state machine, damage, results
    TournamentService              -- schedule, bracket, bots
    NPCService                     -- trainers, daily cooldowns
    WildService                    -- spawns, catching
    EvolutionService               -- level thresholds, model swap
    CrateService                   -- odds, PolicyService checks
    MonetizationService            -- gamepasses, ProcessReceipt
    QuestService                   -- login, daily, playtime
ServerStorage/
  Tests/ (ModuleScripts)
    FormulaTests                   -- asserts on Formula
    BalanceSim                     -- runs 10,000 battles, prints win rates
ReplicatedStorage/
  Shared/
    Config/ (ModuleScripts)  Glassies, Rarities, Types, Trainers, Zones, Cosmetics
    Formula (ModuleScript)         -- pure damage / catch / XP math
  Remotes/                         -- created by the server at startup
  Assets/
    Glassies/<id>/  Body, Shards (Folder), Fill
    ShatterFX/<id>/
StarterPlayer/StarterPlayerScripts/
  Main (LocalScript)
  Controllers/ (ModuleScripts)
    BattleController               -- pendulum animation, meter, input
    ShatterController              -- cracks, shards, slow-mo, sounds
    UIController
```

- **`Formula` is pure functions.** After any balance change, Codex runs `ServerStorage.Tests` through the MCP's code-execution tool and checks the output, so balance stays testable without anyone playing.
- **Remotes** (client → server): `ReleaseSwing(battleId, clashIndex, t)`, `ThrowCork`, `ChallengePlayer`, `JoinTournament`, `PickWinner`. Rate-limit and validate every one on the server.
- `StreamingEnabled` is on. For the MVP all zones are areas in one place.
- **Backups:** Roblox keeps place version history on every publish, so publish at least at each milestone. This repo holds the design doc and Blender source files. Optionally, have Codex copy script sources into `src/` here at milestones so changes can be reviewed in git.

### 12.2 Save data (ProfileStore)

```lua
{
	Version = 1,
	Coins = 0,
	Glassies = {
		-- [uid] = { Id = "pop", Nick = "", Level = 1, Xp = 0, Stars = 0,
		--           Hp = 100, Broken = false, Rainbow = false, Fill = nil }
	},
	Equipped = nil,          -- glassy uid
	SlotsMax = 30,
	Corks = { Basic = 5, Golden = 0 },
	Badges = {},
	TrainerCooldowns = {},   -- [trainerId] = dayNumber
	Cosmetics = { ShatterFx = { "default" }, Fills = {}, EquippedShatterFx = "default" },
	Stats = { Wins = 0, Losses = 0, Perfects = 0, Shattered = 0, Catches = 0,
	          TournamentWins = 0, BestStreak = 0, Evolutions = 0 },
	Daily = { Streak = 0, LastClaimDay = 0, Quests = {} },
	CodesRedeemed = {},
	ProcessedReceipts = {},  -- purchase ids, for ProcessReceipt idempotency
}
```

Evolution changes `Id` and keeps everything else.

### 12.3 Blender asset spec (per glassy)

| File | Spec |
|---|---|
| `<id>_body` | ≤ 1,500 tris (≤ 3,000 for Legendary/Mythic), about 2–3 studs tall at export scale. **Origin at the hang point** (bottle neck, sword hilt, pumpkin stem, top of a creature's head). Silhouette must read clearly on a phone. |
| `<id>_shards` | 12–20 pieces from the **Cell Fracture** add-on (up to 30 for Mythic), each its own object (`shard_01`…). Same origin and scale as the body, inner faces included. |
| `<id>_fill` | Optional inner liquid or glow mesh, about 90% of the inner volume. Fantasy glassies can use a glowing core instead of liquid. |
| `<id>_icon.png` | 512×512 transparent render, with the **same camera and lighting for every glassy**. |
| Crack overlays | 3 shared stages (light / medium / heavy) that work on any glassy. Test a decal against an overlay shell on mobile and pick one. |

- **Style:** chunky, rounded, toy-like shapes with bright tinted glass. Fantasy glassies should still clearly read as **glass** (transparent, glinting), not as plastic toys.
- Roblox's `Glass` material looks different depending on device graphics quality. Test on low-end phones, and fall back to `SmoothPlastic` with Transparency 0.3 and some Reflectance.
- Export FBX, import with the Roblox MCP or the 3D Importer, and record the mesh IDs in `Config/Glassies`.

## 13. Milestones

Roblox traffic peaks over **winter break**, so launch by mid-November and ship a winter event in mid-December.

| Week | Dates (2026) | Goal |
|---|---|---|
| 1 | Oct 12–18 | **Feel prototype:** one stand, two glassies, meter, cracks, shatter. Post a clip to see how people react. **Don't build more until the shatter feels great.** |
| 2 | Oct 19–25 | Save data, starters and their evolutions, NPC trainers, Repair Bench, Zone 1 layout |
| 3 | Oct 26–Nov 1 | Wild glassies and catching, crates, leveling, launch roster from the Blender pipeline |
| 4 | Nov 2–8 | Tournaments, octagon arena and bracket board, PvP, cosmetics (Shatter FX, Fills) |
| 5 | Nov 9–15 | Monetization, daily rewards, quests, codes, UI polish, mobile testing |
| 6 | Nov 16–22 | **Soft launch** (cross-promoted from your existing game). Watch the analytics and fix issues. |
| 7–8 | Nov 23–Dec 6 | Update 1: Zone 2 (Sunny Beach), winter event prep |
| 9 | ~Dec 12 | **Winter event** (snow globes, ornaments, glass reindeer) and a marketing push for winter break |

**If you fall behind, cut in this order:** Rainbow variants → PvP challenges (tournaments already cover PvP) → stars and fusing → catching (crates and trainer rewards only).
**Never cut:** the shatter feel, starter evolutions, tournaments, saving.

## 14. Metrics

- **Roblox Analytics:** D1 and D7 retention, average session length, payer conversion, ARPDAU. Compare them with your existing game.
- **Custom events:** battles per session, % of battles with at least one Perfect, time to first evolution, tournament join rate, catch attempts, crate opens, first item purchased.
- **Funnel:** join → pick starter → first win → first catch → **first evolution** → first tournament.

## 15. Open questions

- Final game name, and the final name for the collectibles ("glassies" is a placeholder).
- **Trading** drives retention and value in kids' games but needs scam and dupe protection. Post-launch.
- **3v3 team battles** (Pokémon-style teams). Post-launch.
