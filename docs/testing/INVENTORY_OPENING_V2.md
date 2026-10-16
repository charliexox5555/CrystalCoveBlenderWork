# Inventory click and opening feedback — 2026-10-16

Reproduced the creator's inventory failure with actual Studio MCP game input: FlyersTab and FinishersTab had `Active=false` in the authored template. Earlier tests invoked `SelectTab` directly, bypassing those flags. The controls are now enabled in the editable template and runtime binding; both actual tab clicks pass. No map objects or lighting were modified.

Inventory detail portraits/backings now share a centered square footprint on both Glassy and cosmetic pages, replacing the mismatched wide rectangle. Original UI artwork and a pre-edit backup are preserved.

Crate playback now uses a compact heat/pressure sequence, a short original 4×4 pressure flipbook, converging/releasing sparks, moving capsule lids and curved item flights. The chamber's world position is projected to screen pixels, then converted into the reward frame's coordinates; the old code reused a normalized Y from a different frame and hardcoded X. Item art flies first and its card decoration appears during landing. Skip restores every card's opacity/rotation and text outlines. Camera fitting freezes during the moving-lid/scale animation so an expanding bounding box cannot zoom the camera away from the burst.

Verification:

- Actual MCP game clicks opened both Flyers and Finishers; square preview geometry checked.
- Existing opening presentation suite: **788 checks pass**, no purchases. Updated upright assertion to use the authored hang pivot instead of raw MeshPart CFrame, accommodating imported PivotOffsets. Covers 1/10 results, pinned reels, firing, skip, collect-once, interruption and audio/HUD cleanup. Initial failed fixture runs left temporary audio/HUD state; a fresh Play run passed.
- New focused `verify_opening_feedback_v2.luau`: **63 checks pass**, covering 1/10 openings in all three categories, frozen camera during lid motion, correct 128px atlas frames, launch origin within two pixels, skip decoration restoration and sound cleanup. Manually measured launch-origin error: **0 pixels**.
- Existing original pressure texture is 512×512, not 1024; frame crop is explicitly 128×128.
- Lune pure-rule suite: **111 passed, 0 failed**. Source formatting/diff checks pass. No Balance/rules changes; simulator rerun unnecessary.

Editable templates: `StarterGui.CollectionScreen` and `KilnRevealScreen`. Original copies: `ServerStorage.UIBackups.InventoryBeforeClickSquareV2` and `OpeningBeforePressureV2`. New editable pressure image prototypes are under `KilnRevealScreen.Panel.Content.KilnStage.Sparks`.

Recovery snapshot: `places/InventoryOpening_v2.rbxm`, 239,430 bytes; SHA256 `d23ef094988c08580b906e94c8866860d52e258acdb4da97dff01b1ae96d9537`. Script-free deserialize round-trip verifies 1,019 descendants, enabled tabs, square backing constraint and correct atlas crop. Restore the two ScreenGuis into StarterGui after backing up any later creator edits. Prior `places/CrateShop_v1.rbxm` remains available. Studio is left in Edit, unpublished; scheduling remains paused. Subjective animation feel and real device review remain creator work.
