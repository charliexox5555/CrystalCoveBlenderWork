# UI text fit: audit and fix (workstream J)

The creator's request: *"There is a lot of UI where if there are long text strings, it goes over the button. All text should fit inside the buttons and contained area and not go out."*

## How it was checked

- **Scanner:** `tools/studio/ui_text_fit_scan.luau`, run in Studio Play on the Client. It is read-only. It visits every visible TextLabel, TextButton and TextBox and reports:
  - **OVERFLOW:** `TextFits == false`, or the text measured with `TextService:GetTextBoundsAsync` doesn't fit the label's box at the size the engine uses (padding counted).
  - **OUTSIDE:** where the glyphs actually draw goes past the button or art the label sits on. Cut-glass art is not a rectangle, so gems use their inner face: 10% in from the pointed ends and 13% from top and bottom (taken from the SVGs).
  - **TINY:** the rendered size is below 10 px.
  - **CUT:** the text ends in "…". This is the intended last resort; it is not counted as overflow.
- **Phone and tablet estimates:** every box is scaled by `min(Wp/W, Hp/H)` from the Studio viewport (1167×510) to 667×375, 844×390 and 1024×768, and the text is fitted again. This is an estimate, because the MCP can't switch Device Emulator presets.
- **Fixture:** `tools/studio/ui_text_fit_fixture.luau` opens every state through the Studio-only `LobbyClientDev` and `UIPreview` hooks. It makes no purchases and changes no profile data. The states are:
  - Lobby HUD.
  - Shop tabs: Featured, Glassies, Finishers, Flyers and Marbles (each crate machine with its prize carousel and buttons).
  - Kiln 10-pull reveal.
  - Inventory: Glassies, Flyers and Finishers.
  - Index.
  - Rewards: Quests, Gifts, Streak and Codes.
  - Match previews: Queue, Roll (with Pick Any, Reroll and Odds) and Results.
  - CAST button with the longest power name ("Screw-Top Slam").
- **Stress test:** every string is padded by 40% with "WWWW…" (about the length a translation adds) and the screen is scanned again.

## Baseline (original code and templates, guard off)

The original files were briefly put back for this run (16:24, Studio viewport 1167×510). Totals across 19 states: **1 overflow and 64 labels at 3–9 px.** The UI mostly "fit" by shrinking text until it couldn't be read, and many minimums were 1 px.

On phones those boxes shrink by about 25–45%. Labels whose minimum was 8–14 px (Kit labels, tabs, card names, reveal labels) are then held at that minimum and run over their buttons. That matches what the creator saw.

| Screen | What was wrong | Example |
|---|---|---|
| Shop tabs (Featured, Glassies, Finishers, Flyers) | Single-line fitter took the outline off the height twice | "Featured" at **8 px** in a 59×15 tab |
| Shop daily offers | Rarity + kind pill far too small for its words | "UNCOMMON FINISHER" at **3 px** |
| Shop bundle banner | Pill text | "LIMITED-TIME BUNDLE" at **4–6 px** |
| Shop bundle banner | Status line | "Halloween limited set" **overflow** (10 px minimum in a 9 px box) |
| Marble packs | Pills | "MARBLE BUCKET" at **4 px**, "+16% BONUS" at 6 px |
| Crate machines (Glassies, Finishers, Flyers) | Prize-card odds | "7.03%" at **8 px** (6 px on phones). Odds must be readable |
| Inventory | Long names on small plaques | "Moonlantern Carriage" at **6 px**, "Crystal Tumbler" at 9 px, "✓ EQUIPPED" at 7 px |
| Inventory | Counts | "×1" ran out of its 11 px box once its minimum was 12 |
| Kiln 10-pull reveal | Long duplicate line on small cards | "ANOTHER COPY · OWNED ×1" (needs about 140 px, has 90) |
| Roll screen | Message line built from automatically sized pieces | The idle line "Pick a glassy. This hand stays with you all match." is wider than its frame, and the old shrink never noticed |

Clean in every pass: Lobby HUD (desktop), Index, Rewards (all four tabs), Queue, Results, and the CAST button with "Screw-Top Slam".

## The fix: one fit policy for all text

`Theme.TextFit`:

| Token | Value | Meaning |
|---|---|---|
| `Min` | 12 | Preferred floor |
| `MinSmall` | 10 | Hard floor (tags, chips, small plaques) |
| `Lines` | 2 | One-line text may use two lines before it is cut |
| `BodyLines` | 3 | Descriptions |
| `GemInset` | (0.10, 0.17) | Inner face of the cut-glass gem |

`UI/Components/TextFit` applies the policy to every text object in PlayerGui. `TextFitController` sets this up, so StarterGui templates cloned at runtime, screens built in code and pop-ups are all covered. For each label it:

1. Uses `TextScaled` inside a `UITextSizeConstraint`, from its maximum down to 12 px. Fixed-size text that doesn't fit is switched to scaled, with its authored size as the maximum.
2. Wraps to two lines if one line at 12 px doesn't fit and the box is tall enough.
3. Allows 10 px, then two lines at 10 px.
4. Draws at the floor and ends with "…" (`TextTruncate.AtEnd`) only if all of that fails.
   - A floor is never larger than the box. A box shorter than 10 px is a layout problem, listed under follow-ups.
   - TextBoxes are never cut.
   - Changes that screens make themselves (wrapping, scaling, minimums) are kept: TextFit compares against what it last wrote, so it holds up under deferred signals.

### Shared helpers

| Helper | Change |
|---|---|
| `Kit.label`, `U.text` | Floors come from `Theme.TextFit`; `Small = true` for tags and chips |
| `Kit.tag`, `Kit.marbleChip` | Use the small floor |
| `Kit.marbleLine` | Measures each piece's real glyph width and shrinks the whole line until it fits (down to 10 px) |
| `StainedGlass.bindText` (FitSingleLine names, tabs, plaques) | Now uses the shared policy on one line. It was an async measure-and-set fitter that left the shop tabs at 8 px and had no truncation |

### Small screen-specific changes, where scaling alone would still be unreadable

| Where | Change |
|---|---|
| ShopCard pills (daily offers, Marble packs) | Pill 5.2:1, taller label box |
| Daily-offer pill text | Rarity only ("UNCOMMON ★"); the portrait and the tab already say the kind |
| Bundle banner pill | 5.5:1, text "LIMITED TIME" |
| PrizeCard | Odds label fills the chip's flat middle; name and odds floor 10 px instead of 1 px |
| Inventory and cosmetic tiles, badges, bundle-preview labels | Floor 10 px instead of 1 or 8 px |
| Kiln reveal on 10-pull cards | "OWNED ×N" instead of "ANOTHER COPY · OWNED ×N" (single reveals keep the long line) |

### StarterGui templates

`tools/studio/fit_ui_templates.luau`, run in Edit:
- `dry` reports what it would change.
- `apply` makes the changes. It changed 96 objects: minimums of 1–8 px raised to 10 px, never above the box. It found no fixed-size text with words in it and no gem label outside its gem.
- `restore` undoes them. Each changed object keeps its original values in the attribute `TextFitBackup`.

**The place must be saved or published to keep the template edits.** The runtime guard covers the templates either way.

## After (guard on)

Same states and viewport.

| | Overflow | Outside | Tiny (<10 px) | Cut with "…" |
|---|---|---|---|---|
| Baseline (original) | 1 | 30\* | 64 | 0 |
| **Final (16:53, controller on)** | **0** | 33\* | 38† | 11 |

\* The "outside" rows are prize cards scrolling at the ends of the crate carousels, which the carousel clips. They are not real overflow.

† 36 of the 38 are the crate prize-card odds, whose box is 8 px tall. The other 2 are the Kiln reveal bonus line, in a 9 px box. Both are layout follow-ups below; the text sits at the box height and stays inside.

Stress test (every string +40%), final code: **0 overflow in 19 states**, 130 strings ended in "…" at 10 px or larger.
- One row was caught in the frame between the text change and the refit (the Finishers detail description). Rechecked by hand: it settles to 10 px, wrapped, ending in "…".

Screenshots (Studio Play, 1167×510):

| Before | After | What changed |
|---|---|---|
| `before_shop.jpg` | `after_shop.jpg` | Tabs went from 8 px to readable; pills went from "UNCOMM…" to "UNCOMMON"; "LIMITED TIME" now fits |
| `before_gem_letterbox.jpg` | `after_gem_letterbox.jpg` | "PREVIEW EFFECT" and "FIND IN THE SHOP" ran past their gem; now they stay inside |
| `before_inventory.jpg` | `after_inventory.jpg` | "×1" counts now sit inside their 11 px box |

`after_shop.jpg` still shows "Piggy Bank" with the bottoms of the g and y cut by the buy button. That was fixed afterwards in ShopCard (name box 0.72 tall) and is not re-shot yet.

### Final verification

Last Play pass at 16:53, with the real `TextFitController` (not a manual require):
- **0 overflow** in 19 states at 1167×510, and 0 in the stress pass.
- Every gem button on Inventory and the shop tabs (2 + 6 + 6 + 6) keeps its text inside the gem face.

Two bugs were found and fixed along the way:
- **Lost changes:** a deferred-signal race could undo a screen's own switch to `TextScaled`. The PLAY button and the Kiln reveal labels showed up as fixed-size overflow. TextFit now compares each label against what it last wrote.
- **Gem letterboxing:** buttons wider than the gem's 600:172 art draw a narrower gem, but the label spanned the whole box. `StainedGlass.bindGemLabel` keeps the label's authored insets relative to the gem actually drawn, and the scanner now checks against the drawn gem.

Not re-verified in Play after the last two small edits: the ShopCard name box (0.72 tall) and the scanner's gem check. Both compile-checked with Lune.

## Known limits and follow-ups (layout, not text policy)

- **Crate prize cards are too small for their odds:** the odds text is 8 px tall at 1167×510 and about 6 px on phones. Text can't be both readable and inside that box. Either make the carousel cards bigger or put the odds in a row under the carousel. Odds must stay readable (AGENTS: show odds before every pull).
- **Inventory tiles on phones:** name plaques are about 11 px tall at 844×390, so long names are cut ("Crystal Tum…"). The full name is in the detail pane. Fewer columns on phones would fix it properly.
- **Kiln 10-pull reveal cards:** the reward and bonus labels are 9–10 px tall at 1167×510, so on phones they sit at the 10 px floor, then get cut.
- **Roll screen on phones:** the scanner can't model the shrinking message line, which is built from automatically sized pieces, so it reports 3 phone "overflows" there. `Kit.marbleLine` now shrinks the line to fit (down to 10 px), but that hasn't been seen at phone size.
- **Fight HUD:** only checked indirectly. Its text is all `Kit.label` (TextScaled, now under the guard); no live fight was run in these passes.
- **Device Emulator:** the phone numbers are estimates. Check on a real phone or in the emulator before launch.
