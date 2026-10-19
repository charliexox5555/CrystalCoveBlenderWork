# Power VFX v2 verification (workstream E), Oct 19

Direction and per-kit table: [docs/vfx/POWER_VFX_V2.md](../../vfx/POWER_VFX_V2.md). This report covers what was checked in Studio Play and what is still open.

## How it was checked

- **Preview harness** (`src/client/Dev/PowerVFXPreview.luau`, driver `tools/studio/preview_power_vfx.luau`, Play / Client):
  - Stages a kit's real event sequence through the real `FightScene` → `CombatEffects` → `HeroPowers` / `PowerFX` pipeline: `SignatureReady` → `CastStart` or `SignatureArmed` → `CastRelease` → `CastContact`, `SignatureContact`, `SignatureBlock` or `SignatureStatus`.
  - Event fields and numbers come from `Balance.CombatRelease.Kits`.
  - The clock can be frozen at any beat (`Stop`) for captures. `Zoom = 1` is the default fight camera (33 studs, FOV 52); `0.5` is a closer look.
- **Real matches:** `MatchDev:Invoke("AllBots")` ran 7 bot-vs-bot matches with cast policies (the bots press CAST), so live Ready, Armed, Manual/auto CastStart, Block and Status events arrived from the server. This was done three times.

## Results

| Check | Result |
|---|---|
| Before captures | All 24 kits, `before/` (one key beat each) |
| After captures | 27 images in `after/`: starters, Legendary/Mythic, Epic, Rare and most Commons/Uncommons. Mason Jar, Glass Cup and Frostglobe were stepped in Play after the fixes but not re-captured. |
| Live events | Over 25 s of 7 matches: SignatureReady 24, SignatureArmed 10, CastStart 14, CastRelease 12, SignatureBlock 11, SignatureContact 6, SignatureStatus 2. No PowerFX errors after the fixes below. |
| Leftovers after rounds | In 5 rounds, sampled 2.5 s after each Shatter: **0 visible PowerFX parts, 0 enabled outlines** in every fight. `PowerHeroBloom` is never left in Lighting. Pools stay at 26–52 hidden parts per fight and are destroyed with the fight. |
| Client cost (`FightClientDev` Profile, 7 live arenas, 90 frames ×3) | Mean render 1.42–1.72 ms per frame, max 3.6–7.3 ms, about 60 fps (whole fight controller, every arena). |
| PowerFX share (`StepMs` / `StepMaxMs` attributes on each fight's `PowerFX` folder) | 0.001–0.17 ms mean per fight per frame; worst frame 0.80 ms (a spawn frame); at most 7 live effects in one fight. |
| Low-detail branch (`Low = true`, or `workspace:SetAttribute("PowerFXLowDetail", true)` in Studio) | About half the pieces; no lights, outlines or bloom; the breath and impact still read (`after/glass_dragon_low_detail.jpg`). |
| Phone readability | `after/phone_proxy_prism_844w.jpg` is a default-camera capture downscaled to phone width (844 px, landscape). The ray and impact still read. |

## Fixed during verification

- `FX:Trail` read its attachments from the wrong parent. This broke every travelling shot (Comet, Lemonade, Prism Blade).
- The Prism rainbow beam passed a ColorSequence as a part colour, which skipped the muzzle flash.
- Breath and cone sheets, and rings aimed along the travel direction, were edge-on from the side camera. They now lie in the camera plane (`FX.along`, `FX.tilted`).
- Impacts spawned at body centres were hidden inside the glass. Every primitive now sits about 1 stud toward the camera.
- Neon washed pale colours to white. Pale signature colours were saturated, coloured beams use low light emission, and Ready, cast and armed states use `FX:Vivid`, which picks the accent for white, cream and silver kits.
- Rocket flames pointed into the bottle. The Hourglass clock was oversized and opaque. The Duck bubble hid the duck (it is now ForceField). Sparkle particles were too small to see at fight distance.

## Open items

- **Device Emulator:** the Studio MCP can't switch Device Emulator presets (workstream B hit the same limit). The phone check above is a downscaled proxy. Please do a real phone-preset pass.
- **Creator feel review** at real speed. The captures are frozen frames.
- **Sounds:** the `-- SFX:` cues in `PowerFX/Kits.luau` and `LaunchKit.luau` are listed for workstream B (POWER_VFX_V2 §7). No new sounds were added.
- **Launch-power kit:** builders are in place, but nothing is wired until A ships the event fields (POWER_VFX_V2 §5) and the models land.

## Pass 2: per-power sounds and launch kits, Oct 19 (10:44–10:54, Studio lock slot)

| Check | Result |
|---|---|
| New sounds load | All 10 `PowerAudio` ProSoundEffects ids report `IsLoaded = true`. Lengths: AirRush 2.23 s, Crackle 0.95 s, FireBurst 1.38 s, FireLick 0.83 s, FizzPop 0.81 s, LidBonk 2.28 s, MagicSwirl 3.31 s, Roar 1.68 s, SlideUp 1.38 s, StarExit 3.39 s. |
| Cues fire | 22 kits and 6 launch kits ran with sound on through the preview (Mason Jar and Glass Cup weren't in the batches). Every wired cue played: FizzPop, LidBonk, MagicSwirl, StarExit, AirRush, Crackle, FireBurst, FireLick, Roar and SlideUp, plus the reused bank layers (ChimeCluster, FallingShimmer, CosmicRiser, LanternBell, Bubbles). **No PowerFX errors** after the `ipairs` fix found in this pass. |
| Voice cap | During 7 live AllBots matches, sampled every frame for about 25 s: at most **1** power voice at once (cap 6). |
| Leftovers | 8 rounds, sampled 2.5 s after each Shatter: **0 visible PowerFX parts, 0 outlines** in every fight. |
| PowerFX cost | `StepMs` / `StepMaxMs` per fight: 0.03–0.48 ms. |
| Whole-client profile | **Not trustworthy this run.** The Mac's load average was about 100 (other sessions' renders and simulations), and Studio rendered at 0.6–1.4 fps, so FightClientDev Profile read 59 ms mean. The earlier pass (above, normal load) measured 1.4–1.7 ms mean with 7 arenas. |
| Phone preset | Still not possible: the Studio MCP can't switch Device Emulator presets. This needs a manual pass. |

Mix rules agreed with workstream B:
- Contact cues stay at or below 0.35 volume.
- A contact cue drops its tail layers when a Smash/Crit hit (B's `Feel:Classify`) lands within 80 ms, in either order.
- Cues never repeat a sample that CombatEffects already plays (each kit's Release/Contact sound, and LidBlock).
- Fights you aren't watching play only the first layer, at 0.6x volume.
