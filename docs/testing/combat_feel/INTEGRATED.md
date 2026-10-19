# Integrated combat check (Oct 19)

**Combined layers:**
- Combat feel (B, `CombatFeel`/`ImpactBeat`)
- Power VFX v2 (E, `a0e240d`, `bd27ff2`)
- The CAST button and retuned balance (A, `c147c3b` onward)

**How it was run:**
- Studio Play, real `MatchDev` "Start" matches with the local player against a bot. A client script picked, aimed and pressed CAST about 0.5 s after each own-side `SignatureReady`, the same as a player tapping the button.
- For load, `MatchDev` "AllBots" filled the other 6 arenas.
- Five matches across three Play runs, inside the shared Studio lock (`tools/studio_lock.sh`, name `combat-feel`).

## Beats per round (live counters on the fight folder)

| Round | Hits (Glance / Solid / Smash / Crit) | Blocks | Hitstops | Manual casts (mine / all) | Other |
|---|---|---|---|---|---|
| match 1 r1 | 2 / 4 / 5 / 4 | 4 | 18 (2 skipped in final slow-mo) | 2 / 6 | Perfect 1, power land 1 / miss 1, KO, victory |
| match 1 r2 | 0 / 1 / 2 / 3 | 0 | 9 (1 skipped) | 2 / 4 | Perfect 2, power land 3 / miss 1, KO, victory |
| retune check r1 | 0 / 6 / 5 / 2 | 4 | 20 (1 skipped) | 3 / 8 | Perfect 2, power land 1, KO, victory |
| earlier run | 1 / 3 / 1 / 2 | 4 | n/a | 2 / 5 | comeback 1, power miss 4, KO, victory |

Every own CAST press produced the screen beat. The live cast shot is `10_integrated_cast.jpg`: E's kit flourish on the glassy, the pulse on the stand floor and the damage popups, all readable from the normal camera.

## Frame cost (desktop)

Measured with the `FightClientDev` "Profile" hook for 8 s while fighting: 7 views (my participant fight plus 6 nearby bot fights).

| Metric | Value |
|---|---|
| FPS | 56.4 |
| Worst frame | 153 ms (one spike) |
| Fight render work, mean | 1.20 ms/frame |
| Fight render work, worst frame | 5.12 ms |
| Mean by view: participant | 0.44 ms |
| Mean by view: 6 nearby fights total | 0.66 ms |
| Mean by view: far | 0.07 ms |

Nothing of mine stands out as a hot spot. The impact pool peaked at 23 parts, Highlights at 2, and visible fight parts at 323 (most of them E's pooled power parts plus shards).

**Phone Device Emulator: not measured.** The Studio MCP can't switch emulator devices, so this needs a person: pick an iPhone preset in Studio and run `FightClientDev:Invoke("Profile", 8)` during a fight.

## Does it read clearly? What doubled up

1. **Camera:** E's PowerFX never moves the camera (checked in code), so there's one shake system with one cap (0.3 studs, −6° FOV). Nothing doubles here.
2. **Power contact bursts did double up.**
   - Before: a landed power drew E's kit Hit, CombatEffects' generic Smash-sized starburst (`Impact.emit`), and my hit tier when a body hit landed at the same moment. That made two starbursts at once.
   - **Fixed:** `Impact.emit` now uses a small `Contact` tier (one ring, flash, a few chips, no spokes), so E's kit visual leads.
3. **Cast moment:** the split agreed with E holds.
   - A's button only scales out on press; it has no popup or sound.
   - E draws the on-glassy flourish.
   - I do the hold, FOV, flash, "NICE CAST!", edge tint and riser. No duplicate popup or sound.
4. **Shatter moment was the loudest pile-up.**
   - Up to 11 voices: Break 0.65, two Tinkles 0.35–0.40, the finisher's MagicBurst 0.44, SoftBoom, FallingShimmer, risers, my KO thunk and my victory chime.
   - **Fixed on my side:** the victory beat is silent now (visual rings and glints stay, the finisher's cues own that moment), and the KO thunk went from 0.5 to 0.4.
   - The finisher cues belong to the finishers session.
5. **In-fight sound peak:** 9 voices at once (hit layers, a block and E's lid bonk), with a summed volume of 3.5.
   - The biggest single layer is `ChargeGlass` at cue volume **1.30** (`Config/AudioCues`, played by CombatEffects on CastStart). That's twice any other combat sound.
   - I didn't change it blind: the sample may simply be quiet. It needs a listen. If it's loud, drop that cue to about 0.6. `AudioCues` currently has other sessions' uncommitted edits, so it's left for a quiet moment.
6. **E's power sounds** (its own `Config/PowerAudio`, 6-voice cap) cap contact cues at 0.35 and play only their first layer when one of my Smash/Crit hits lands within 80 ms. E reads the tier through `scene.Feel:Classify(e)`, so keep that method stable.

## Changes in this pass

- `Config/CombatFeel`:
  - new `Tiers.Contact`.
  - `Victory` sounds emptied.
  - KO thunk at 0.4.
- `ImpactBeat.emit`: uses `Contact` for signature contacts and guard blocks.
- `CombatFeel:Hold`: Studio-only counters for skipped holds (`FeelHoldSkipView`, `FeelHoldSkipFinal`). They showed that the only skips are hits inside the final slow-mo, which is intended.

## Tests

- Lune: 155 passed, 0 failed. One earlier run showed 1 failure while other sessions were mid-edit; it didn't reproduce.
- Studio output during the retune check: no game-script errors. The only errors were Roblox CorePackages chat-module load errors.

## Left

- Phone emulator profile (needs a person).
- A listen to `ChargeGlass` at 1.30.
- The creator's real-speed feel review.
