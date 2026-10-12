# Bottle Battles — Game Design Doc (v0.1)

> Working title. Alternatives: **Glass Clash**, **Shatter Showdown**. Search Roblox for name conflicts before picking.

## 1. Pitch

Hang your bottle on a string, swing it and shatter your opponent's. Collect bottles, level them up, beat trainers across the world, and win the tournament in the lobby. The structure is like Pokémon, and every fight ends with a satisfying shatter.

- **Audience:** all ages, mostly kids. Design for **mobile first**.
- **Inspiration:** viral reels where two glass objects hang on strings and swing into each other until one breaks, run as a bracket.

### Pillars

1. **The shatter is the reward.** Every battle ends in a slow-motion, loud, sparkly shatter. If a change makes it less satisfying, don't make it.
2. **Your bottle is yours.** You name it, level it and dress it up, and it follows you around. A loss breaks it for a moment, never for good.
3. **Easy to play, with a small skill edge.** One button. Timing matters a little, stats matter more, and luck keeps it exciting.
4. **There's always something to watch.** Lobby tournaments draw a crowd and crown a champion.

## 2. Core loop

```
Battle (NPC trainer / wild bottle / tournament / PvP)
  → earn coins + XP (+ catch wild bottles)
  → level up, open crates, fuse, buy cosmetics
  → take on tougher trainers, bosses and tournaments
  → repeat
```

**Example 10-minute session:** join, claim the daily reward, repair at the bench, fight 3 trainers on Route 1, catch a wild bottle. A tournament is announced, so join it, lose in the semis and pick the winner of the final. Open a crate, then leave.

## 3. Battle system

### 3.1 Setup

A **Clash Stand** is a frame that looks like a **Newton's cradle or a playground swing set**. Don't make anything look like a gallows or noose. Two bottles hang from strings (rendered with a `Beam`) and the camera looks from the side, like the reels.

### 3.2 One clash (~4 s)

| Phase | Time | What happens |
|---|---|---|
| Pull back | up to 1.5 s | Both players hold the button. The bottles pull back and the power meter sweeps. |
| Release | — | The player lets go. If they don't, it auto-releases at the end as **Weak**. |
| Swing | 0.5 s | Both bottles swing toward the center. |
| Impact | — | Hitstop, clink, damage numbers, crack update, camera shake. **Both bottles take damage**, like in real life. |
| Bounce back | 0.8 s | The bottles swing back, then the next clash starts. |

When one bottle reaches 0 HP, the last impact plays in slow motion and it **shatters** (see section 8).
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

- **Double KO:** if both bottles hit 0 in the same clash, the one that went less far below 0 survives on 1 HP and shows **"CLUTCH!"**.
- **Balance target:** HP ≈ 5 × an equal opponent's Power.

### 3.5 Types (rock-paper-scissors)

| Type | Beats | Examples | Stat lean |
|---|---|---|---|
| **Heavy** | Sharp | jars, jugs | high Power and HP, low Swing |
| **Sharp** | Fizzy | crystal, perfume, vases | high Swing and crits, low HP |
| **Fizzy** | Heavy | soda, potions | balanced |

Show types as large colored icons, since kids read icons, not text.

### 3.6 HP and cracks

- The bottle model shows crack stages at **75 / 50 / 25 % HP**, alongside an HP bar.
- HP **carries over between trainer and wild battles** (like Pokémon) until you repair.
- Tournaments and PvP always start at full HP.

### 3.7 Losing

- Your bottle shatters and becomes **Broken**, so it can't battle until it's repaired.
- **Repair Benches** in the lobby and halfway along each route are free. Repair plays a **reverse shatter**: the shards fly back together, glow, and you see "Good as new!" It reuses the same shard assets.
- Bottles are **never lost for good**.

### 3.8 Server authority and anti-exploit

- The **server decides everything**: HP, damage, crits and random rolls. The client only sends its release time.
- The server sends each clash's meter start time and speed. The client returns its release timestamp, and the server works out the zone, allowing for about 150 ms of latency.
- An exploiter can always claim Perfect, so keep Perfect's bonus modest (×1.3). Log each player's Perfect rate and flag anyone above 90% over 50+ clashes.
- **Don't use Roblox physics for the swing.** Bottles are anchored and each client animates them with CFrame (sine-curve pendulum). The server knows the impact times and waits before applying results.
- Shards exist **only on the client**: unanchored parts, cleaned up after 3 s, with a cap of about 150 on screen for mobile.

## 4. Bottles

### 4.1 Bottles are data

Adding a bottle should take **one config entry plus one asset folder, with no new code**. That keeps content cheap for the AI pipeline.

```lua
soda_classic = {
	Name = "Fizzy Pop",
	Type = "Fizzy",
	Rarity = "Common",
	Base = { Power = 20, HP = 100, Swing = 10 },
	Asset = "soda_classic",        -- folder under assets/
	ClinkPitch = 1.1,              -- smaller bottles clink higher
	WildZones = { "recycling_yard" },
}
```

### 4.2 Rarity

| Rarity | Stat multiplier | Coin crate odds |
|---|---|---|
| Common | 1.00 | 60% |
| Uncommon | 1.15 | 25% |
| Rare | 1.30 | 10% |
| Epic | 1.50 | 4% |
| Legendary | 1.75 | 0.9% |
| Mythic | 2.00 | 0.1% |

**Rainbow variant** (the game's version of a shiny): any bottle has a 1-in-500 chance to roll Rainbow, with iridescent glass and +5% stats.

### 4.3 Growth

- **Level 1–50:** `stat × (1 + 0.04 × (level − 1))`, so level 50 is about ×2.96. Wins give XP.
- **Stars:** fuse 3 duplicates for +1 star (max 5). Each star adds +10% stats, which gives duplicates a use.
- **Evolution** (post-launch): at levels 15 and 35 the bottle changes model in the **Kiln**.

### 4.4 Starters

Pick one on first join, from three bottles on pedestals:

- **Pop**: Fizzy soda bottle
- **Jam**: Heavy jam jar
- **Prism**: Sharp crystal perfume bottle

### 4.5 Launch roster (~18 bottles)

| Rarity | Bottles |
|---|---|
| Common / Uncommon | Soda bottle, Milk bottle, Jam jar, Pickle jar, Ketchup bottle, Glass cup, Water jug, Mason jar |
| Rare | Perfume bottle, Potion flask, Message in a Bottle, Hot sauce bottle |
| Epic | Crystal vase, Hourglass, Lava lamp, Ship-in-a-bottle |
| Legendary | Diamond flask, Genie bottle |
| Mythic | Galaxy bottle (stars swirling inside) |

**No alcohol bottles** (beer, wine, champagne, liquor). This is a kids' game, and alcohol references can change its content maturity label.

## 5. World

### 5.1 Lobby: "Glass Town"

The Tournament Arena sits in the center. Around it are the Repair Bench, Crate Shop, Cosmetic Shop (Fills and Shatter FX), the **Champion Pedestal**, leaderboards, codes, and the exit to Route 1.

### 5.2 Zones (like Pokémon routes)

Each zone has 5–6 trainers in a line of rising level, wild bottles, a Repair Bench halfway, and a boss (**Shelf Champion**) at the end. The boss gives a **badge**, unlocks the next zone and adds their signature bottle to crates.

| # | Zone | Wild pool | Ships in |
|---|---|---|---|
| 1 | Recycling Yard | sodas, milk, jars | MVP |
| 2 | Sunny Beach | message bottles, sea glass | Update 1 |
| 3 | Candy Factory | candy jars | later |
| 4 | Science Lab | potions, flasks | later |
| 5 | Ice Palace | ice bottles, snow globes | later |
| 6 | Volcano | lava glass | later |

The long-term goal is 8 badges, then an endgame "Glass League."

### 5.3 NPC trainers

- Each trainer is a config entry: name, bottle id, level, **skill** (how often they hit Great or Perfect), reward and dialogue lines.
- They're standard R15 NPCs dressed with `HumanoidDescription`, so **no Blender rigging is needed**.
- The first win each day gives the full reward. Rematches give less.

### 5.4 Wild bottles and catching

- Wild bottles float, bob and glow around each zone. Walk up to one to battle it.
- Between clashes, you can **throw a Cork** instead of swinging. The wild bottle still swings at you, so you take damage and it doesn't.
- `catch = baseRate[rarity] × (0.15 + 0.85 × (1 − hp / maxHp)) × corkBonus`
  - baseRate: Common 0.9, Uncommon 0.7, Rare 0.45, Epic 0.25, Legendary 0.1
- **The tension:** shatter it and it's gone. Keep hitting, or risk the cork?
- **Corks:** basic corks are cheap for coins. **Golden Corks** (better odds) come from rewards or Robux.

## 6. Lobby tournaments

- A tournament is announced every **8 minutes**, with a 60 s countdown. Players step on the **Join Pad**.
- It's an **8-slot bracket**. **Empty slots fill with NPC bots** of matching power, so it runs even with 2 players in the server.
- Two cups alternate:
  - **Rookie Cup:** every bottle is **scaled to level 10**, so type and timing decide it and new players can win.
  - **Open Cup:** no scaling.
- **Flow:** the quarterfinals run on 4 stands at once, then the semis, then the **final in the center arena**. Everyone gets a "Watch the Final!" camera prompt.
- **Pick the Winner:** spectators and knocked-out players pick a finalist for free and earn coins if they're right. **No wagering.**
- **Rewards:**
  - **Winner:** 500 coins, a Champion tag above their head until the next tournament, a server-wide announcement, and **their bottle shown big and spinning on the Champion Pedestal**.
  - **Others:** 2nd 250, semifinalists 100, every entrant 25.

## 7. PvP challenges

Walk up to another player, send a **Challenge** and they accept. The battle moves to the nearest free stand at full HP, with no wagering. Wins give a small reward, capped per opponent per day so friends and alt accounts can't farm it.

## 8. Game feel checklist (the shatter)

**Every impact**
- [ ] Hitstop of 60–100 ms
- [ ] Clink sound, pitched by bottle size, with a crack sound layered on when a new crack stage starts
- [ ] Camera shake scaled to damage
- [ ] Damage numbers, plus **PERFECT!** / **CRIT!** text
- [ ] Crack stage swaps at 75 / 50 / 25 %
- [ ] Haptic pulse on mobile and controller (`HapticService`)

**Final blow**
- [ ] Slow motion at 0.3× for about 1 s, with the camera pushing in on the impact
- [ ] One white flash frame
- [ ] Swap the bottle for its pre-fractured shards, with outward and downward velocity and spin
- [ ] Liquid splash if the bottle is filled, plus glitter particles
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
| +10 Bottle Slots | Gamepass | 99 |
| Auto-Repair (repair anywhere) | Gamepass | 149 |
| Lucky (better crate odds and wild spawns) | Gamepass | 249 |
| Coin packs | Dev product | 25–999 |
| Bottle Crate / 10-pack | Dev product | 49 / 449 |
| Golden Corks ×3 | Dev product | 39 |
| Private server | — | ~100 |

**Cosmetics**
- **Shatter FX** play when *your* bottle wins (Confetti, Ice Burst, Rainbow, Lightning, Candy, Galaxy). Opponents see them, so they advertise themselves.
- **Fills** are liquids inside your bottle that splash when it breaks (Soda, Slime, Lava, Glitter, Honey, Galaxy).
- Labels, stickers, caps and glow auras.

**Rules**
- Robux crates **must show odds before purchase**.
- Check `PolicyService:GetPolicyInfoForPlayerAsync()` → `ArePaidRandomItemsRestricted`. For players where that's true, **hide Robux crates** and offer direct-buy items instead.
- Pick the Winner is free only. Never let players bet coins or Robux.

## 10. Retention and community

- 7-day login calendar (day 7 gives a crate)
- 3 daily quests: "Win 3 battles," "Get 5 Perfects," "Catch a bottle"
- Playtime gifts at 5 / 10 / 15 / 30 minutes
- **Group join reward** (a Golden Cork), which grows your community
- Codes posted on Discord and socials with every update
- Leaderboards: Most Wins, Tournament Wins, Best Win Streak, Most Bottles Shattered
- **Weekly updates:** 2–3 new bottles plus one feature, and a bigger event each season
- On Discord, the **community votes on the next bottle** and you build it with the Blender pipeline

## 11. Marketing

- **Use the Blender MCP pipeline to render the same kind of reels** that inspired the game, with your actual in-game bottle models, e.g. "16 bottles, only one survives." Every bottle in a video can be collected in the game. End each video with a "Play on Roblox" card.
- Record finals in the game (the slow-mo shatter) for Shorts and TikTok.
- At launch, cross-promote from your existing 150-CCU game with a billboard or portal and a group shout.
- For the icon and thumbnails, show a bottle mid-shatter in bright colors. A/B test them.
- Only pay for Roblox ads once D1 retention is healthy. Don't pay for traffic into a leaky game.
- **Seasonal events:**
  - Winter: snow globes and glass ornaments, since glass fits Christmas perfectly
  - Valentine's: heart perfume bottles
  - Halloween 2027: haunted potion bottles and glowing pumpkin jars (your horror idea, reused as an event)

## 12. Technical plan

### 12.1 Project layout (Rojo, so the code lives in git; Roblox MCP for scene and assets)

```
src/
  server/Services/
    DataService.lua          -- ProfileStore, schema, migrations
    BattleService.lua        -- battle state machine, damage, results
    TournamentService.lua    -- schedule, bracket, bots
    NPCService.lua           -- trainers, daily cooldowns
    WildService.lua          -- spawns, catching
    CrateService.lua         -- odds, PolicyService checks
    MonetizationService.lua  -- gamepasses, ProcessReceipt
    QuestService.lua         -- login, daily, playtime
  client/Controllers/
    BattleController.lua     -- pendulum animation, meter, input
    ShatterController.lua    -- cracks, shards, slow-mo, sounds
    UIController.lua
  shared/
    Config/  Bottles.lua Rarities.lua Types.lua Trainers.lua Zones.lua Cosmetics.lua
    Formula.lua              -- pure damage / catch / XP math
    Remotes.lua
assets/
  blender/<bottle_id>/       -- .blend source + exports
  icons/
docs/
```

- **`Formula.lua` is pure functions** with unit tests (Jest-Lua or TestEZ), so the AI can check balance changes without opening Studio.
- **Balance simulator:** a script that runs 10,000 battles between config bottles and prints win rates, so Codex can tune numbers.
- **Remotes** (client → server): `ReleaseSwing(battleId, clashIndex, t)`, `ThrowCork`, `ChallengePlayer`, `JoinTournament`, `PickWinner`. Rate-limit and validate every one on the server.
- `StreamingEnabled` is on. For the MVP all zones are areas in one place.

### 12.2 Save data (ProfileStore)

```lua
{
	Version = 1,
	Coins = 0,
	Bottles = {
		-- [uid] = { Id = "soda_classic", Nick = "", Level = 1, Xp = 0, Stars = 0,
		--           Hp = 100, Broken = false, Rainbow = false, Fill = nil }
	},
	Equipped = nil,          -- bottle uid
	SlotsMax = 30,
	Corks = { Basic = 5, Golden = 0 },
	Badges = {},
	TrainerCooldowns = {},   -- [trainerId] = dayNumber
	Cosmetics = { ShatterFx = { "default" }, Fills = {}, EquippedShatterFx = "default" },
	Stats = { Wins = 0, Losses = 0, Perfects = 0, Shattered = 0, Catches = 0,
	          TournamentWins = 0, BestStreak = 0 },
	Daily = { Streak = 0, LastClaimDay = 0, Quests = {} },
	CodesRedeemed = {},
	ProcessedReceipts = {},  -- purchase ids, for ProcessReceipt idempotency
}
```

### 12.3 Blender asset spec (per bottle)

| File | Spec |
|---|---|
| `<id>_body` | ≤ 1,500 tris, about 2–3 studs tall at export scale. **Origin at the hang point** (top center of the neck). Silhouette must read clearly on a phone. |
| `<id>_shards` | 12–20 pieces from the **Cell Fracture** add-on, each its own object (`shard_01`…). Same origin and scale as the body, inner faces included. |
| `<id>_fill` | Optional inner liquid mesh, about 90% of the inner volume. |
| `<id>_icon.png` | 512×512 transparent render, with the **same camera and lighting for every bottle**. |
| Crack overlays | 3 shared stages (light / medium / heavy) that work on any bottle. Test a decal against an overlay shell on mobile and pick one. |

- Roblox's `Glass` material looks different depending on device graphics quality. Test on low-end phones, and fall back to `SmoothPlastic` with Transparency 0.3 and some Reflectance.
- Export FBX, import with the Roblox MCP or the 3D Importer, and record the mesh IDs in `Bottles.lua`.

## 13. Milestones

Roblox traffic peaks over **winter break**, so launch by mid-November and ship a winter event in mid-December.

| Week | Dates (2026) | Goal |
|---|---|---|
| 1 | Oct 12–18 | **Feel prototype:** one stand, two bottles, meter, cracks, shatter. Post a clip to see how people react. **Don't build more until the shatter feels great.** |
| 2 | Oct 19–25 | Save data, starters, NPC trainers, Repair Bench, Zone 1 layout |
| 3 | Oct 26–Nov 1 | Wild bottles and catching, crates, leveling, ~18 bottles from the Blender pipeline |
| 4 | Nov 2–8 | Tournaments, PvP, cosmetics (Shatter FX, Fills) |
| 5 | Nov 9–15 | Monetization, daily rewards, quests, codes, UI polish, mobile testing |
| 6 | Nov 16–22 | **Soft launch** (cross-promoted from your existing game). Watch the analytics and fix issues. |
| 7–8 | Nov 23–Dec 6 | Update 1: Zone 2 (Sunny Beach), winter event prep |
| 9 | ~Dec 12 | **Winter event** (snow globes, glass ornaments) and a marketing push for winter break |

**If you fall behind, cut in this order:** Rainbow variants → PvP challenges (tournaments already cover PvP) → stars and fusing → catching (crates and trainer rewards only).
**Never cut:** the shatter feel, tournaments, saving.

## 14. Metrics

- **Roblox Analytics:** D1 and D7 retention, average session length, payer conversion, ARPDAU. Compare them with your existing game.
- **Custom events:** battles per session, % of battles with at least one Perfect, tournament join rate, catch attempts, crate opens, first item purchased.
- **Funnel:** join → pick starter → first win → first catch → first tournament.

## 15. Open questions

- Final name (check Roblox search for conflicts).
- Reference reels: confirm the exact setup (string length, frame, how the bracket is shown, and whether they're Blender renders or real footage).
- **Trading** drives retention and value in kids' games but needs scam and dupe protection. Post-launch.
- **3v3 team battles** (Pokémon-style teams). Post-launch.
