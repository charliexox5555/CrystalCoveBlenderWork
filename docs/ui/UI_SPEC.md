# UI Spec (v0.3: arena matches)

- **Style:** "crisp glass" (GAME_DESIGN 13): dark frosted panels, thin 2 px cyan → violet edges, Montserrat ExtraBold/Bold, Black Italic only for pop-ups, soft glows, no thick outlines. Color meanings: green buy/claim/confirm, red close/cancel, yellow special/limited, blue neutral, purple fuse.
- **Tokens:** `src/client/UI/Theme.luau`. **Components:** `src/client/UI/Components` (Panel, Button, Pill, ProgressBar, GlassyPortrait, Util). Build every screen from these.
- **Old mockups:** [Figma](https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ) (inventory `2:268` and the style kit `2:2` still apply; the meter battle screen `2:657` is obsolete).

## Rules

- Interactive UI in `ScreenInsets = CoreUISafeInsets`; keep the bottom-left (thumbstick) and bottom-right (jump) corners clear in the lobby.
- Scale layout + `UIAspectRatioConstraint` + `UISizeConstraint` minimums (tap targets ≥ 44 px on phones). Test in the Device Emulator on phone presets before calling a screen done.
- Gamepad: every button selectable; B / Escape closes the open panel.
- During a match the lobby HUD hides; only match UI shows. **The 3D fight stays the star**: match UI hugs the edges.

## 1. Lobby HUD

```
┌──────────────────────────────────────────────────────────────┐
│ (Roblox menu)                     Coins 1,250 +   Marbles 40 + │
│ [Kiln] [Glassies] [Shop]                ▶ Win 3 rounds   1/3   │
│ [Quests] [Index]                        ▶ 2 Perfect Releases   │
│                                                                │
│ Gifts 2:00                                     [Daily streak]  │
│ (thumbstick zone)                                (jump zone)   │
└──────────────────────────────────────────────────────────────┘
```

## 2. Queue panel (standing on a pad)

Small panel above the bottom center: "Waiting for a challenger… 0:12" with a progress ring that fills to `QueueBotAfterSeconds`, then "A bot joined!". Buttons: **Leave** (red), **Invite friend** (blue).

## 3. Roll (8 s)

```
┌──────────────────────────────────────────────────────────────┐
│ ♥♥♥  YOU                 ROUND 2                 RIVAL  ♥♥♡  │
│                                                                │
│   ┌─────────┐       ┌─────────┐       ┌─────────┐              │
│   │ (3D)    │       │ (3D)    │       │ (3D)    │              │
│   │ Pop     │       │ Comet   │       │ Jam     │              │
│   │ Fizzy ★2│       │Legendary│       │ Heavy   │              │
│   │ Fizz Burst      │ Fizz Burst      │ Sturdy  │              │
│   │ Pressure Pop    │ Beam    │       │ Lid Shield             │
│   └─────────┘       └─────────┘       └─────────┘              │
│        [ REROLL  free ]              ⏱ 6                       │
└──────────────────────────────────────────────────────────────┘
```

- Cards slot in with a quick spin, like a slot machine settling (the "gacha" feel); rarity glow on the card edge.
- Card: spinning `ViewportFrame` model, name, type icon + color, rarity, stars, passive name, special name; tap to see a one-line description of each.
- Opponent's last pick shown small under their name ("Last: Jam (Heavy)") to make counter-picking a choice.
- **Reroll** button: "free" or the Marble cost (`MatchLogic.rerollCost`). Hidden when the collection has ≤ 3 glassies. Paid rerolls ask for confirmation the first time.
- Timer out → first card is picked.

## 4. Aim (6 s)

- Camera behind your glassy, side of the stand. **Drag** anywhere to pull your glassy back along its arc (touch, mouse; gamepad left stick). A ghost arc shows the swing; the **Perfect band** glows gold on the arc.
- **LOCK** button (green) bottom-right; locking early is fine. "PERFECT!" sparkle if inside the band.
- Opponent's glassy visible but their aim hidden until release.

## 5. Countdown + Fight HUD

```
┌──────────────────────────────────────────────────────────────┐
│ ♥♥♥ [Pop ★2  Fizzy ███████░░] VS [░░██████ Jam  Heavy] ♥♥♡    │
│                                                                │
│          (3D Clash Stand, 3/4 camera, both glassies)           │
│                                                                │
│   Fizz Burst!                                    SMASH! 24     │
│                                                   ( SPECIAL )  │
└──────────────────────────────────────────────────────────────┘
```

- 3-2-1 big centered numbers, then **LET GO!**
- HP bars top, with a delayed damage trail and crack icons at 75 / 50 / 25 %. Hearts beside each bar.
- **SPECIAL** button bottom-right (where the thumb rests): a ring fills with charge; when full it glows yellow and pulses with the special's name ("LID SHIELD"). Tap once; it greys out "USED". PC: Space / click; gamepad: A / R2.
- Popups: damage numbers (size by damage), CRIT!, SMASH! (big hits), passive names in the glassy's tint, special name banners.
- Shield/freeze/pump/slam state as a small icon under the HP bar with a draining timer.
- Overtime banner at 45 s ("OVERTIME: hits get stronger!").

## 6. Round end (4 s)

Final blow slow-mo + SHATTERED! banner (ShatterController). The loser's **glass heart** above their side cracks and pops with a small shatter. "ROUND 2 → YOU" pill.

## 7. Results

Big WIN / DEFEAT, rounds 3–2, the glassies each player used per round (small icons), rewards counting up (coins, trophies), quest progress ticks, buttons **Play again** (green, re-queues on the same pad) and **Lobby** (blue).

## 8. The Kiln

- **Odds first:** the panel opens on the odds list (every glassy, its rarity and exact %, from `Formula.kilnOdds`), with **Pull ×1 (300)** and **Pull ×10 (2,700)** below it. Never hide the odds behind a button.
- Reveal: molten glass glows in the furnace, gets blown into a bubble, the bubble cools into the glassy with a rarity-colored flash. Duplicates show "+1 ★".
- 10-pull reveals one by one with Skip.

## 9. Glassies (collection) and Index

- Grid of glass tiles (rarity tint + edge, icon, stars, Rainbow shimmer), filters by type and rarity, sort. Detail panel: spinning model, stats, passive and special with descriptions, stars, "Used in N matches".
- Index: every glassy; unowned ones as silhouettes; completion rewards per rarity.

## 10. Shop

Marble packs (green R$ buttons), gamepasses (VIP, 2× Coins), Shatter FX (preview plays on a test bottle), heart and stand skins. Nothing random is sold for Robux at launch.

## Status

| Screen | Milestone | Status |
|---|---|---|
| Fight HUD (HP, hearts, SPECIAL, popups) | F1 | To build |
| Aim | F1 | To build |
| Queue panel, Roll, Countdown, Round end, Results | F2 | To build |
| Kiln, Collection, Index | F3 | To build (inventory mockup reusable) |
| Lobby HUD, Quests, Shop, Shatter FX | F4 | To build |
| Loading screen | F5 | Concept in RESOURCES 6 |
