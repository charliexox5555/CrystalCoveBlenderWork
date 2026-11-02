# Concept abilities in the real arena: test report (2026-11-02)

Studio only, not published. Place 129420351303019, branch `claude/relaunch-gauntlet`. Plan: [design/RELAUNCH_PLAN.md](../../design/RELAUNCH_PLAN.md).

The earlier Gauntlet slice was rejected and removed. Its screenshots here (`after_*.jpg`) are history, kept only for comparison.

## Screens

| Rising Tide fills the pen | Split Light |
|---|---|
| ![tide](concept_tide.jpg) | ![rays](concept_rays.jpg) |

| Reaction faces and a jam blob | Real match from the lobby, mixed with an older model |
|---|---|
| ![faces](concept_faces.jpg) | ![match](concept_real_match.jpg) |

| Zest Ring and Ice Field | Pickle Drop and Firefly Swarm |
|---|---|
| ![zest](concept_zest_ice.jpg) | ![pickles](concept_pickles_flies.jpg) |

## Verified

- Lune and Studio Play server: **309 passed, 0 failed**. Each of the 12 abilities has a real-swing test, and round length has a range check.
- Round length on the real swing (`equal:bot0.5`, 4,680 rounds): **mean 32.2 s**. Before this work, `tools/pacing_report` measured 21.6 s.
- Balance on the real swing, 234 rounds per glassy: **43.6% to 56.8%, 34 of 40 inside 45-55%**. At this sample size a few points either way is noise.
- Real first session in Studio: welcome spins, reveal, assisted first match against Rookie Bot. No new console errors, only the old `203785492` warning.
- Native two-client regression through `MultiplayerLauncher`: **passed, zero errors, 151 s**. Real pads, invalid inputs rejected, full PvP settlement (125 coins for the win, 49 for the loss), PLAY AGAIN, opponent disconnect with no reward, late-join spectator. Seven simultaneous fights: server 60 FPS, 0.30 ms of simulation per frame. Clients ran at about 15 FPS, which earlier reports put down to Studio throttling background simulated clients; no real phone measured.
- Drawn in the real arena, confirmed by screenshot or by the objects existing during a watched fight: all abilities except Cup's speed-up effects, which tests cover. Milk's refill moment was not caught.
- Economy: match about 3.9 min. With rewards up about 25%, 141 Kiln pulls by day 30 (was 145) and 5 on day 1.
- No new remotes: abilities are server-driven and clients only draw them.

## Not verified

Full list for the creator: [MORNING](../../logs/MORNING.md).

- Nobody but the creator has judged feel, and sound choices were not heard.
- No phone or emulator check.
- Cup's TOP SPEED and Milk's refill were not seen on screen; tests cover both.
- Balance is equal-stat bots; real players and rarity may shift it.

## Run it

Press Play in Studio and play normally. To watch a chosen matchup, run this in the Server command bar:

```lua
require(game.ServerScriptService.Server.Services.FightService):BotVsBot("pop", "water_jug", 1, true)
```

Ids: `pop`, `jam`, `prism`, `glass_cup`, `water_jug`, `ketchup_bottle`, `milk_bottle`, `pickle_jar`, `lemonade_bottle`, `mason_jar`, `crystal_tumbler`, `hot_sauce`.
