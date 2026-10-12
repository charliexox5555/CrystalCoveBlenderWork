# M1 phone feel check

The gameplay and HUD are in Studio and pushed to Git. **Publication is still pending:** Studio MCP's Edit context rejects AssetService.SavePlaceAsync. In the open Studio place, leave Rojo connected and choose **File > Publish to Roblox**. Then open [Glass Clash](https://www.roblox.com/games/129420351303019) on your phone using your Roblox account.

1. Start in **landscape**, with audible device volume. Walk toward the wooden A-frame stand and tap **CLASH** on its practice prompt. Pop fights the NPC Jam at level 10.
2. **Touch and hold anywhere on the play area**, then lift your finger when the white needle reaches the gold center. Look for **PERFECT**, a stronger impact burst and bigger damage on average. Try releasing early for a weaker hit. The bottles should keep swinging after you lift your finger.
3. Start holding again **during the rebound**, before the next meter window. Keep holding into the next window and release on gold. This should work without needing to lift and press again at the window boundary.
4. Watch the glass at **75%, 50% and 25% HP**. Cracks should follow the curved surface and move with the glassy. Listen for the clink and short crack layer at impact. Check whether the motion feels weighty and springy.
5. Finish the battle. Check the side-on camera, slow motion, white flash, break plus shard-tinkle audio, scattering/bouncing fragments and **SHATTERED!** result. Decide whether that finish actually feels satisfying.
6. Wait for the result to close. Movement and normal camera should return; fragments disappear in about three seconds. Start a second battle. Also reset your character during a battle, respawn, and start again.
7. Rotate to **portrait** during another battle. Check both HP cards, portraits, type labels, centered timing bar and instructions. No clipped text or missed touches. Return to landscape for the main feel judgment.

Record a short clip with sound, ideally covering a Perfect impact and the finishing shatter. Tell me about missed touches, any floating cracks, audio balance, frame drops, and whether contact/rebound and the final shatter feel good. Real-phone satisfaction is the remaining M1 approval gate; the emulator cannot settle that.

## Verified in Studio

- Lune and Roblox RunAll: **28 passed, 0 failed**; 14 server release-validation checks pass.
- Galaxy A06 landscape: screen-wide emulated Touch completed a five-clash victory, including four Perfect releases. Peak fragments: 17, below the 150 cap; floor rebounds observed.
- iPhone 17 Pro landscape and portrait: visible text fits; screen-wide Touch release accepted. CoreUISafeInsets used for the HUD.
- Holding during rebound then releasing in the next window registered Perfect through real Space input.
- Fixed-RNG damage comparison: Weak **24**, Perfect **44**. Actual damage varies with server RNG and crits.
- All four approved Sound instances load. Active-battle reset returns Interrupted, clears all three battle ScreenGuis, restores the normal camera and WalkSpeed 16, and restores the idle glassies after respawn. Fresh Output clean.
- Studio left in Edit mode with the device simulator stopped.
