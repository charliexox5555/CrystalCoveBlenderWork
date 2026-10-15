# UI Spec (v0.3: arena matches)

> **v0.5 theme (Oct 15, approved): Stained Glass** — Figma page "UI v0.5 — Stained Glass", references in [v05/](v05/), assets + palette + fonts + SliceCenter table in [assets/ui/stained_glass](../../assets/ui/stained_glass/README.md). Build prompt: [prompts/04_ui_stained_glass.md](../prompts/04_ui_stained_glass.md). No rounded corners anywhere.
>
> **v0.4 layout (Oct 15, creator-directed): build from the Figma page "UI v0.4 — arena game"** ([file](https://www.figma.com/design/r3guIIk5deo7vNxLzJN0RZ)). Five screens plus a component kit: 01 Lobby HUD, 02 Inventory, 03 Shop, 04 Choose your glassy, 05 Fight HUD. Ball VS Ball layouts as inspiration, our own glass style. Where this conflicts with older sections below, the Figma page wins.
> - **One structure for every menu:** header (title, currencies on Shop, red close) → coloured category tabs (Glassies cyan, Flyers pink, Finishers violet, Kiln orange, Marbles blue; future tabs dashed) → content left + info panel right. Shop is the same shell, larger.
> - **Lobby HUD:** two square buttons on the left (Shop, Inventory); Coins and Marbles pills directly under them (display-only, `Active = false`, so touches reach the thumbstick); big green PLAY bottom-centre (joins the nearest free arena). **Top-right stays empty** (Roblox player list covers it).
> - **Inventory (creator revision, decision 54):** Owned glassies first, then an Unowned divider and every missing catalog entry in the same scroll area. Missing portraits are dimmed; entries awaiting artwork use a clear placeholder. Both sections are inspectable. No levels, sort/search, Stars display or Equip; only owned glassies enter your roll pool. Tile edge = rarity colour. Right panel: name, ownership/type/rarity, upright model or artwork-pending placeholder, passive, power and Power/HP/Swing bars (base stats for unowned).
> - **Glassy portraits are ViewportFrames** of the real models everywhere (tiles, cards, info panel).
> - **Fight HUD:** only a billboard above each player (name, 3 hearts, glassy + type chip) plus short popups (power banner in the glassy's tint, damage numbers). No HP bars, buttons or panels; damage reads from cracks on the glass.
> - **Choose your glassy (decision 55):** 3 big cards roll vertically one at a time at match start, then remain unchanged between rounds. Main Pick Any opens owned inventory for this round only; small paid Reroll on the right replaces the match hand. Show wallet, prices, timer and both players' hearts.

**October 14 creator direction:** Codex lays out functional placeholders using Scale, with editable ScreenGui templates in StarterGui. The creator supplies final image-based styling. Ball v Ball screenshots are layout inspiration, not a one-to-one copy. See [editing guide](EDITING_UI.md). This takes priority over spending more time on final UI artwork.

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
│        [ PICK ANY  free ]   [ REROLL  3 ]              ⏱ 6                       │
└──────────────────────────────────────────────────────────────┘
```

- Cards roll vertically, fast and sequentially, with server-pinned final glassies. Animate once at match start or after an explicit paid reroll; never automatically between rounds. Each owned glassy is equally likely, with no duplicates within a hand.
- Card: upright, centered static `ViewportFrame` model, name, type + rarity and concise power text. No Stars display.
- Opponent's last pick shown small under their name ("Last: Jam (Heavy)") to make counter-picking a choice.
- **Pick Any:** one free use per match, then 6 → 9 → 12 Marbles, capped at 12. Opens owned-only choices and selects this round's glassy; never replaces a hand card. Paid choices require confirmation.
- **Reroll:** smaller right-side button; prices 3, 3, 6, 6, then 9 Marbles forever within the match. Every spend asks for confirmation showing all eligible outcomes and equal inclusion probabilities. Hidden for collections ≤ 3 and when paid-random policy is restricted/unavailable. Both counters reset next match.
- Timer out → first card is picked.

## 4. Aim (6 s)

- Camera behind your glassy, side of the stand. **Drag** anywhere to pull your glassy back: drag distance = how far, drag direction = which way (up to `AimYawMax` either side). A ghost arc shows the first swing; the **Perfect band** glows gold on the pull distance.
- **LOCK** button (green) bottom-right; locking early is fine. "PERFECT!" sparkle if inside the band.
- Opponent's glassy visible but their aim hidden until release.

## 5. Countdown + Fight HUD

```
┌──────────────────────────────────────────────────────────────┐
│ ♥♥♥ [Pop ★2  Fizzy ███████░░] VS [░░██████ Jam  Heavy] ♥♥♡    │
│                                                                │
│          (3D Clash Stand, 3/4 camera, both glassies)           │
│                                                                │
│   Fizz Burst!            ⚡ HOT STREAK! ⚡          SMASH! 24   │
│                                                                │
└──────────────────────────────────────────────────────────────┘
```

- 3-2-1 big centered numbers, then **LET GO!**
- HP bars top, with a delayed damage trail and crack icons at 75 / 50 / 25 %. Hearts beside each bar.
- **No buttons during the fight** (DECISIONS 33). Powers fire by themselves: a big **banner with the power's name** in the glassy's tint ("HOT STREAK!", "LID SHIELD!") plus its effect on the glassy. A miss shows "MISSED!" in grey: part of the fun.
- A thin glow ring around each portrait fills as the next power gets close (`FightRules.powerProgress`), so players feel the tension ("it's about to go off!").
- Popups: damage numbers (size by damage), CRIT!, SMASH! (big hits), WHOOSH (near-miss pass-by), passive names in the glassy's tint.
- Shield/freeze/pump/slam/rage state as a small icon under the HP bar with a draining timer.
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
| Fight HUD (HP, hearts, power banners, popups) | F1 | To build |
| Aim | F1 | To build |
| Queue panel, Roll, Countdown, Round end, Results | F2 | To build |
| Kiln, Collection, Index | F3 | To build (inventory mockup reusable) |
| Lobby HUD, Quests, Shop, Shatter FX | F4 | To build |
| Loading screen | F5 | Concept in RESOURCES 6 |
