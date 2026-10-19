# Combat Overhaul Research (Glass Clash)

Web research, October 2026. Source quality is flagged: **[P]** = primary or official, **[C]** = community or third-party, **[I]** = my inference or general design knowledge, not sourced. Blade Ball has no accessible official wiki or dev posts in this research (the fandom wiki returned HTTP 402), so most of its detail is community-reported. Treat exact numbers as ballpark.

## 1. Blade Ball: rarity, power, parry loop

- **Abilities affect gameplay; cosmetics do not.** Abilities are the "edge" items, bought with coins or won from a coin-paid wheel. Swords, trails and kill effects (explosions) are cosmetic, and cosmetics are the Robux crate (premium case) products. [C: [Naavik](https://naavik.co/digest/blade-ball-ugc-success/), [DungeonPath cosmetics](https://dungeonpath.com/posts/blade-ball/trails-and-cosmetics-guide/), the latter an unofficial guide]
- **Rarity is the scarcity of an ability, not its stat line.** The top abilities (Infinity, Rapture) are ranked best partly because they are rare, limited or event-gated. Infinity is called the "pay-to-win" pick because premium packs can buy it. Tier lists disagree widely on the middle abilities (Super Jump is S in one list and F in another), so there is no clean "rarer is stronger" curve. [C: [PocketGamer](https://www.pocketgamer.com/roblox/blade-ball-ability-tier-list/), [RobloxDen](https://robloxden.com/game-codes/blade-ball/guides/blade-ball-ability-tier-list), [GINX](https://www.ginx.tv/en/blade-ball-tier-list)]
- **Abilities are mostly situational sidegrades with counters.** Examples: Thunder Dash blocks parrying while active, Pulse counters ability abusers, Swap backfires if mistimed. [C: PocketGamer]
- **Balance is done by weekly per-ability patches.** A Nov 2024 patch buffed Calming Deflect and Quantum Arena and nerfed Swap, Golden Ball, Necromancer and Phantom, with limited crates and Robux spins in the same update. [C: [Sportskeeda](https://www.sportskeeda.com/roblox-news/blade-ball-festivities-update-northstar-reaper-celestial-whisper), via search snippet]
- **Economy:** the developer is quoted saying ~90% of revenue is currency purchases plus premium case rolls. Progression is slow (over 80 games for a first ability, ~7 coins per knockout, first ability ~300 coins), which creates an "arms race" that converts well. The author notes Roblox audiences accept pay-to-win more than most. [C: Naavik, quoting the developer] **Do not copy this.** Our rules forbid Robux-only power and require shown odds.
- **Parry loop (community numbers, unverified):** each parry speeds the ball by roughly 10%. The window is cited as ~200-300 ms early and under 100 ms at high speed. A same-frame double parry is a "clash" that resets the ball. Spamming gets you killed, so patience beats mashing. [C: [DungeonPath mechanics](https://dungeonpath.com/posts/blade-ball/mechanics-glossary/), flagged unreliable by the search]
- **Why it is satisfying:** short rallies (duels ~15 s), one clear input, rising speed as tension, visible danger (ball targeting you), and big feedback on a deflect. Naavik also notes that inconsistent ping makes timing hard and the initial difficulty drives churn. [C: Naavik]
- **Launch and cadence:** launched 17 June 2023, 1 billion visits in 62 days (a Roblox record at the time), peaked around 418K concurrent after a TikTok surge. Updates are weekly (limited items, abilities, maps). [C: [Pocket Tactics](https://www.pockettactics.com/blade-ball/one-billion-visits), Naavik]
- **Not found:** developer statements on pay-to-win complaints, official window sizes, official rarity tables.

## 2. Rarity without power creep

- **Ball vs Ball (closest sibling):** community tier lists show Legendary balls in C tier and Rare balls in S tier. Lists rank on damage, ability consistency, counter exposure and mechanic quality, not rarity. Wiki lists 42 balls. [C: [Games.GG](https://games.gg/roblox/guides/ball-vs-ball-tier-list/), [ProGameGuides](https://progameguides.com/roblox/complete-ball-vs-ball-tier-list/), [Bloxodes](https://bloxodes.com/wiki/ball-vs-ball/balls)]
- **Brawl Stars:** the community consensus is that rarity describes how a brawler is unlocked, not how strong it is. No official Supercell quote found. [C: [VP Esports](https://vpesports.com/brawlstars/brawlers/rarity/legendary/)]
- **Clash Royale:** Supercell caps all card levels (11 in a Mega Draft season) in some modes so cards play on equal terms, and rebalances monthly on win and usage rates. Wikipedia notes reviewers questioned pay-to-win at high levels. [P: [Supercell](https://supercell.com/en/games/clashroyale/blog/news/mega-draft-in-path-of-legends); C: [Wikipedia](https://en.wikipedia.org/wiki/Clash_Royale)]
- **Bedwars:** free kits rotate weekly, others are a permanent one-off purchase; balance is per-kit patch notes with cooldown tweaks. [C: [ProGameGuides](https://progameguides.com/roblox/roblox-bedwars-free-kits-this-week/), [Sportskeeda](https://sportskeeda.com/roblox-news/bedwars-latest-update-october-12-patch-notes-details)]
- **Murder Mystery 2:** godly knives are described only as status and cosmetic items, but sources are spam-quality. [C, weak]
- **Principles we could copy [I, supported by the above]:**
  1. Fixed power budget per glassy regardless of rarity; rarity adds *complexity, flash and variety*.
  2. Cap or normalise in modes where fairness matters (like Clash Royale's level cap).
  3. Every power has a named counter (e.g. shield-breakers, anti-freeze), so no glassy wins by default.
  4. Rarity-neutral win-rate band, patched on data like Clash Royale.
  5. Prestige goes to cosmetics (shatter style, trail, Kiln reveal).

## 3. Light-touch skill input for an auto-fight

- **No documented mobile-fair input design found for Roblox specifically.** The best primary source is Roblox's [Server Authority docs](https://create.roblox.com/docs/projects/server-authority): clients predict their own inputs, the server stays truth, mismatches roll back. It requires a specific Workspace setup, simulation-bound code and InputActions, so it conflicts with our custom pendulum streaming. Adopting it is a big commitment. [P]
- **Window sizes:** informal rhythm-game guidance says beginners need roughly 100-150 ms and experts 25-50 ms; forgiving "Good" windows can be 250+ ms. No kid-specific data found. [C: [skills.cat rhythm guide](https://skills.cat/skills/thedivergentai/gd-agentic-skills/godot-genre-rhythm), game-jam notes]
- **Recommended design [I]:**
  - Make the input *anticipatory, not reactive*. Swing turnarounds are predictable, so the player taps near a known moment. Reaction time (~250 ms for adults, slower for kids) then does not matter, and ping becomes a small offset.
  - Client sends the *simulation tick it was displaying* when tapping. The server judges against that tick, so ping drops out of the maths.
  - Graded outcome: Good window of about +/-200 ms, Perfect about +/-90 ms. Misses cost nothing but the cooldown.
  - Limited use: 1 input per swing or one charge that refills. This stops mashing, like Blade Ball's anti-spam advice.
  - Big visible indicator (ring closes, glassy pulses) and a haptic/audio cue.
- **Beyblade/Bakugan mid-battle buttons:** my searches found only toy descriptions, no app control details. [not verified]

## 4. Game feel and VFX craft

- **Hitstop:** freeze for a few dozen ms to ~100 ms; tutorials suggest 0.04-0.08 s light, 0.10-0.18 s heavy. [C: [Godot forum](https://forum.godotengine.org/t/tutorial-hit-stop-and-screen-shake-in-godot-4-autoload-trauma-camera-mit/145240), [Game Feel primer](https://uhiyama-lab.com/en/notes/ue/game-feel-hit-feedback/)] Smash's hitlag formula yields ~10-15 frames at 60 fps for a mid hit, capped at 30 frames, scaling with damage. [P-ish: [SmashWiki](https://www.ssbwiki.com/Hitlag)]
- **Camera shake:** use decaying "trauma" with noise, ring-down ~0.15-0.25 s, mostly positional, little roll; long shakes (1.5 s) cause discomfort. Add an accessibility scale. [C: [StraySpark](https://www.strayspark.studio/blog/camera-shake-game-feel-without-motion-sickness), [GG Camera Shake devforum](https://devforum.roblox.com/t/gg-camera-shake-screenshake-that-doesnt-suck/4731267)]
- **Layering:** impact is stacked at the same instant: freeze, flash, shake, sound, particles, knockback. [C: same sources]
- **Roblox techniques:** ParticleEmitter flipbooks (2x2/4x4/8x8, max 30 fps) work for one-shot bursts; Beams for links and rays; Trails for arcs. [P: [Roblox docs](https://create.roblox.com/docs/effects/particle-emitters)]
- **Mobile budgets [P]:** mobile emitters are capped at **100 particles/sec** (400 elsewhere); flipbooks auto-disable when memory is low; bigger and overlapping transparent particles cost fill-rate; avoid partial transparency; example baseline budget under 1,000 draw calls and 1M triangles. [[Roblox perf docs](https://create.roblox.com/docs/performance-optimization/design)]
- **Not found:** Strongest Battlegrounds / Jujutsu Shenanigans timing data. Treat anything claimed about them as unverified.

## 5. Roster size and cadence

- **Weekly cadence is the norm:** Blade Ball (weekly) and Pet Simulator 99 (Saturday updates, now at Update 85 by aggregator pages) both ship weekly. Bedwars rotates kits weekly. [C: [Naavik](https://naavik.co/digest/blade-ball-ugc-success/), [Hold To Reset](https://holdtoreset.com/pet-simulator-99-updates-details-list)]
- **Launch roster sizes:** not found for any of them. Ball vs Ball lists 42 balls after long live ops. [C: Bloxodes]
- **Inference [I]:** 50 at launch is not required; a smaller, distinct set plus a weekly drop likely retains better, but there is no data here to prove it.

## Recommendations for Glass Clash (ranked)

1. **Point-budget every glassy and cap Legendary+ raw stats** (Claude: `Glassies.luau`, `Balance`; re-run balance sim; effort S-M). Fixes the top playtest complaint. Rarity buys power *type* and flash, not more HP or damage.
2. **Add a timed "Spark" tap at swing turnarounds**, one charge per swing, tick-stamped by the client and judged by the server, Good +/-200 ms and Perfect +/-90 ms (effort M-L). Gives interactivity without rewriting the sim.
3. **Counter-web for powers:** tag each power with what it is weak against; Legendary+ powers get a clear counter (effort M, mostly design and `Powers.luau`).
4. **Win-rate band:** target every rarity within ~45-55% in `balance_sim`; patch on data like Clash Royale (effort S).
5. **Hitstop on big impacts**, ~50-100 ms scaled by impact speed (client freeze plus short server sim pause) (effort S, Codex).
6. **Trauma-based camera shake**, 0.15-0.25 s, positional, with a settings toggle (effort S, Codex).
7. **Layered impact stack** (flash, ring mesh, shards, sound, light pulse) per hit tier, mobile budget 100 particles/s/emitter, one-shot flipbooks (effort M, Codex).
8. **Move prestige to cosmetics:** Legendary+ get unique shatter style, trail and Kiln reveal that do not change stats (effort M).
9. **Readability cap:** one signature-power effect per glassy at a time, clear telegraph before burst (effort S).
10. **Normalised ranked/"Even Glass" mode** with stats clamped to a common tier, mirroring Clash Royale level caps (effort M, later).
11. **Roster plan:** launch with fewer, more distinct glassies and weekly drops; defer the 50 target (effort planning only).
12. **Skip Server Authority adoption** for now; it conflicts with the custom pendulum stream (effort 0, record in DECISIONS).
