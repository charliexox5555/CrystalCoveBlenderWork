# GlassyMotion verification (workstream E), Oct 19

Code: commit fdc0bba. Design and gate: [docs/vfx/GLASSY_MOTION.md](../../vfx/GLASSY_MOTION.md).

| Check | Result |
|---|---|
| Config generator | `lune run tools/gen_glassy_motion` produces 36 glassies and 207 moving parts. Validation is clean: every follower comes after its parent, axes are unit length, and all idle and hit parameters are present. |
| Lune tests | `GlassyMotionTests` (4 tests) cover the converter's keep/drop and ordering rules, the validator, deterministic serialisation, and the generated config naming only real glassies. Full suite: 159 passed, 0 failed. |
| Gate in Studio Edit | No installed `Assets.Glassies` model is flagged (`MotionVersion`/`ReleaseVersion >= 3`), so today's game behaves exactly as before. |
| Fixture run in Play | **Not run.** At 12:08 Studio went into a half-started Play under the shared lock: the server came up, but the Client datamodel was never reachable, the MCP's Stop returned "Start play hasn't finished yet" for 30+ minutes, and screen capture could not connect. The Mac's load average was 70–80. Studio needs a **manual Stop or restart by the creator**. |

Fixture to run once Studio is back (Play / Client, script at `tools/studio/glassy_motion_fixture.luau`):
1. Build a client-side `fishbowl` model flagged `MotionVersion = 4`, with placeholder parts at the manifest pivots (WaterSurface, Fish, FishEyes, FishEyeShine, FishFins, FishTail, bubbles). It is discarded when Play stops.
2. Run `PowerVFXPreview("fishbowl")` so it goes through FightScene → Hero.init → status. Check that the fish swims, the tail wags, the eyes blink and the water sloshes, and that Ready speeds them up.
3. Check cleanup: destroying the fixture drops the handle, and the 30 Hz preview loop disconnects when nothing is left.
4. Measure `Motion:Step` cost for 14 handles over 120 frames.
