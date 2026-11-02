# Morning checklist — 2026-11-02

**Nothing is published.** The live game is unchanged until you publish. All code is on the branch `claude/relaunch-gauntlet`.

## 1. Save first

The changes are only in your open Glass vs Glass Studio window. **Press File > Save** before anything else. Saving doesn't change the live game. If Studio closed overnight and they're gone, tell me and I'll reinstall them from the repo.

## 2. Play for 10 minutes (about what matters most)

Press Play and play like a new player. The Studio test profile starts fresh each time.

1. Do the three free spins on the welcome card show mostly the new glass?
2. Is the first match clear? Can you tell what your glass is doing?
3. **Do fights feel long enough now?** They average about 32 seconds, up from about 21. If they drag, tell me and I'll shorten them.
4. Press PLAY AGAIN and play a full match. Do you want another one?
5. Win some coins and spin the Kiln.

To see any matchup, press Play and run this in the Server command bar:

```lua
require(game.ServerScriptService.Server.Services.FightService):BotVsBot("pop", "water_jug", 1, true)
```

The 12 new ids: `pop`, `jam`, `prism`, `glass_cup`, `water_jug`, `ketchup_bottle`, `milk_bottle`, `pickle_jar`, `lemonade_bottle`, `mason_jar`, `crystal_tumbler`, `hot_sauce`.

Watch for: which abilities feel exciting, which feel weak, and any that are confusing or too busy.

## 3. What I couldn't check

- **Fun.** I can test that things work, but only you and real players can judge this.
- **Sound.** I picked each ability's sounds from your existing library without hearing them. They may need swaps.
- **Phones.** Not tested. Check a phone or Studio's device emulator before publishing, mainly the card text and the callouts.
- **Abilities I saw on screen vs test-only:**
  - Seen in the arena: Prism rays, Jug water, Jam blob, Lemonade slices, Tumbler's FROZEN hit, Pickle drops, Mason fireflies, Hot Sauce aura, Milk (in a fight, not at the moment it pours).
  - Tests only: Pop's cap flying, Jam's full glue strand, Cup's TOP SPEED, Jug's wave, Ketchup's squeeze and SPLAT.
- **Spectators** who start watching mid-round won't see water or blobs from before they arrived.

## 4. Choices that are yours

| Decision | What I did | Change it if |
|---|---|---|
| Coins | Win 125 (was 100), loss cap 50 (was 40), so Kiln spins per hour hold with longer matches | You want spins slower or faster |
| Welcome hand | Free spins favour the new glassies | You want the full random pool back |
| Ability callouts | Short text like "CAP BLAST!" pops up, though the old brief said no power banners | You find them noisy |
| Mixed roster | 12 new, 28 old. Old ones were kept, none removed | You'd rather wait and convert more before release |

## 5. To release

1. Save, then **File > Publish to Roblox**. I didn't publish because you wanted to test first.
2. The old models stay in `ServerStorage.GlassiesBeforeV5` as a backup; the code is in git.
3. Update text is drafted at the top of [LAUNCH_COPY](../marketing/LAUNCH_COPY.md). The older description below it still says CAST, which is gone, so replace that too.
4. Your current thumbnails show the old models. Fresh ones would match the update.
5. After publishing, watch the `ClassicMatchV1` funnel and D1 for a few days before comparing, and compare against players from the same period.

## Results

Evidence and screenshots: [testing/relaunch/REPORT.md](../testing/relaunch/REPORT.md). Plan: [design/RELAUNCH_PLAN.md](../design/RELAUNCH_PLAN.md).
