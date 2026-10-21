# Prompt: music and match sound pass

Paste everything below the line into a new Claude Code chat opened on the repo folder, with Studio (Rojo connected) open.

---

Continue Glass Clash in this repo (branch `claude/roblox-game-concepts-0x0lnj`). This session is **music and match sound design only**.

## Start

1. `git pull`. Read `AGENTS.md`, the newest 3 entries in `docs/logs/DEVLOG.md`, and `docs/audio/SOUND_LIST.md` (sections "Background music" and anything about match/results sounds).
2. Read only the code you need:
   - `src/shared/Config/Music.luau` (pure data, track list and fade numbers)
   - `src/client/Controllers/MusicController.luau` (picks a track from PlayerGui attributes, crossfades, ducks under the shatter)
   - `src/client/AudioGroups.luau` (Master → MusicMaster / GlassClashSFX SoundGroups, Settings sliders)
   - Then grep for where the match phases, the countdown, `Overtime`, hearts and the Results screen are already published (PlayerGui attributes, `FightEvents`, `MatchState`). Reuse those signals; don't add remotes if existing state is enough.
3. Check without changing anything: `lune run tools/run_tests` passes, Studio MCP is on the place, Rojo is connected.

Keep token use modest: read files you need, not whole folders. Use a helper agent for Creator Store searching or broad greps if it saves context.

## What I want

**Remove the current rotation** (Rainbow Garden lobby loop, the 30 s match loop, the Calm track for panels/results) and use these instead. Every sound must sit **quietly in the background**: it adds to the experience, never competes with hits, powers, finishers or UI.

| Slot | When it plays | Asset ID | Notes |
|---|---|---|---|
| Lobby A | In the lobby, also with lobby panels open (Shop, Inventory, Kiln…) | `78720640408712` "Gravity Well" | |
| Lobby B | Same | `109260416655887` "Fractal Tide" | Lobby alternates A → B → A… with crossfades (random start track per join) |
| Tension sting | ~3 s suspense **just before the fight starts** (the 3-2-1 countdown before release); if the countdown is a different length, line its end up with "LET GO"/release | `103121809098519` | One shot, not looped. Music ducks under it |
| Loser sound | Results/round-loss moment for the player who lost the match | `1844442622` | One shot, then fade back to lobby music |
| Winner jingle | Results moment for the player who won the match | `127039883737564` | One shot, then fade back to lobby music |
| Fight | Aim, countdown, fight, spectating | **You find it** (below) | Must be long |
| Overtime / last heart | Overtime, and the final round when either player is down to their last heart | **You find it** (below) | More intense than Fight |

Results screen no longer gets its own music: the jingle or loser sound plays, the music bed under it stays ducked or silent, then lobby music fades back in when Results closes.

### Finding the Fight and Overtime tracks

- I like the **current match track** ("I know that you like it", `9042710302`), but at 32 s it loops too often. Find a **longer** track in the same feel: energetic, danceable, kid-friendly, no vocals, **at least 2 minutes** (longer is better). I'll swap it later if I find better.
- Overtime/last heart: same energy family but faster and more intense. It can be short (60 s+) if it loops cleanly.
- Use only audio that's safe to ship: Roblox's licensed library (**APMOfficial** / "Courtesy of APM Music", or other Roblox-licensed music) or audio I own. No Toolbox models. Search through the Studio MCP if it can reach the Creator Store; otherwise give me 3–5 candidates per slot (name, ID, length, publisher, one-line feel) and I'll pick.
- If you can't find good candidates either way, wire the slots with the current match track as a placeholder and list search terms for me ("upbeat action", "game show", "energetic electronic", "battle arena"; overtime: "intense", "final round", "boss light").

## How it should sound and behave

- **Verify every ID first** in a Studio client: it loads (`IsLoaded`, no permission/moderation error), real `TimeLength`, and how it ends (hard cut, fade or ring-out). Report any that fail; don't silently drop them. Record name, length and publisher in `docs/audio/SOUND_LIST.md`.
- **Volumes:** low. Start music beds around 0.2–0.3 track gain (the current ones are 0.28–0.32; my new lobby tracks may be mastered louder, so match **perceived** loudness by ear, not numbers). Stings and jingles a little above the bed but still gentle. All music, stings and jingles go through `MusicMaster` so the Music slider and mute control them.
- **Seamless loops:** don't rely on `Looped = true` for tracks that don't loop cleanly. For long tracks, crossfade into the next play (or the next playlist track) a couple of seconds before the end using two Sound instances, so there's never a gap or a click. For tracks that do loop cleanly, `Looped` is fine. Decide per track, put the choice in `Config/Music`.
- **Fades:** smooth fade-in on every start and fade-out on every stop (around 1.5 s in, 1–1.5 s out to start, tune by ear). Switching contexts crossfades; nothing ever cuts abruptly. Keep the existing settle delay so quick panel flicks don't thrash music.
- **Overtime / last heart:** crossfade from Fight to Overtime when the `Overtime` event fires or the final round with a last heart starts; back to Fight only at a new round if neither condition holds.
- **Ducking:** keep the existing duck under the shatter/finisher; also duck under the tension sting, the jingles and the Kiln reveal if it has sound.
- **Spectating** uses Fight music too, at the same volume.
- Preload all music on join (as now), no hitches when a track starts.
- All numbers and IDs live in `src/shared/Config/Music.luau` (pure data, Lune-loadable); logic stays in `MusicController`. Add a small Lune test that the config is valid (every slot has an ID and a volume in 0–1, fades positive).

## Rules

- Don't touch the map, arenas, lighting, UI layout or unrelated sounds (hit, power, finisher, UI clicks).
- No new remotes unless existing state can't tell you the phase; if you add one, validate and rate-limit it.
- Clean up connections and stop/destroy Sounds you create; nothing leaks across matches.
- Don't publish; remind me to Save to Roblox.

## Done when

- [ ] Lobby alternates Gravity Well and Fractal Tide with clean crossfades; panels keep lobby music.
- [ ] Tension sting before release, winner/loser sounds on results, then lobby music returns.
- [ ] A long Fight track and an Overtime/last-heart track are in (or candidates listed for me), switching by crossfade.
- [ ] No gaps, clicks or abrupt cuts anywhere; everything quiet and background; Music slider and mute affect all of it.
- [ ] Play-tested in Studio: a full bot match from the lobby through Overtime to Results and back, plus spectating. Studio Output clean.
- [ ] `lune run tools/run_tests` and Studio RunAll (in a Play server) pass. `SOUND_LIST.md` updated, DEVLOG entry, a Proposed decision for the new music plan, committed and pushed.

Then tell me what you picked, the volumes you set, and exactly what to listen for when I test.
