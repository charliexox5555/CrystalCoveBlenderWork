# Monetization: Studio test report (decision 116)

Studio Play, 2026-10-21, mock profiles (fresh each run), `OnboardingDev:Invoke("Step", player, "Done")` to skip
onboarding. Offers without a developer product ran on Studio placeholder ids with a simulated receipt (nothing
charged). Design and prices: [MONETIZATION.md](../../design/MONETIZATION.md).

## What was checked

| # | Check | Result | Capture |
|---|---|---|---|
| 1 | Starter Pack opens by itself once the lobby is free after onboarding | opens; timer "ENDS IN 2d 23h", worth 696 → 49, -92% | [01](captures/01_starter_pack_popup.jpg) |
| 2 | Buy the Starter Pack | receipt granted once: +150 Marbles, Sunny / Daybreak / Dawn Kite owned, `Deals.StarterBought`; HUD tile gone; a second intent is refused ("You already have the Starter Pack") | [02](captures/02_starter_bought_tile_gone.jpg) |
| 3 | Daily Glassy tile → popup | odds by rarity with each glassy's chance (Rare 60% = 7 × 8.57% … Mythic 1.5% = 3 × 0.5%) before the BUY button | [03](captures/03_daily_glassy_odds.jpg) |
| 4 | DETAILS | every glassy with its exact chance | [04](captures/04_daily_glassy_details.jpg) |
| 5 | Buy the Daily Glassy | an Epic (Prism Blade) out of a Kiln opening; the button turns into the countdown to 00:00 UTC; a second buy the same day is refused | [05](captures/05_daily_glassy_reveal.jpg) |
| 6 | Marble "+" → Marbles page | scrolls; Daily Marbles card (x60, +21%, 49) and the Day 1-7 ladder on top, packs below with computed bonuses | [06](captures/06_marbles_page_daily.jpg) |
| 7 | Shop open → Starter tile at the side | the window shrinks a little and the tile sits beside it with its timer and price | [07](captures/07_shop_starter_side.jpg) |
| 8 | Marble crate with 0 Marbles | Need Marbles: "30 more", today's Daily Marbles (x60) with BUY, MORE for the page | [08](captures/08_need_marbles_shop.jpg) |
| 9 | BUY on Need Marbles | +60 in the wallet, "Thank you! 60 Marbles added", still in the Shop | [09](captures/09_need_marbles_bought.jpg) |
| 10 | REROLL with 0 Marbles in a bot match | Need Marbles over the selection: "3 more", the Handful (Daily Marbles was bought), no MORE in a match; closing it gives REROLL / PICK ANY back | [10](captures/10_need_marbles_match.jpg) |
| 11 | iPhone 17 Pro (touch) | Daily tile moves next to Shop (out of the thumbstick area), Starter tile on the right | [11](captures/11_phone_hud_tiles.jpg) |
| 12 | iPhone 17 Pro popup | fits, text readable | [12](captures/12_phone_starter_popup.jpg) |
| 13 | Xbox (TV safe area) | popup and tiles inside the safe area | [13](captures/13_xbox_starter_popup.jpg) |
| 14 | Price guard | at start the server read all 24 existing products' real prices and held back the 15 repriced ones (their dashboard prices are still the old ones; 13 after the creator kept the 3,999 / 8,999 prices): they show COMING SOON and refuse to prompt | console |

Lune: `lune run tools/run_tests` 259/259 (new `OfferTests`, 15 tests; a payer bound in `EconomyTests`).

## Creator changes (2026-10-22)

| # | Change | Result | Capture |
|---|---|---|---|
| 15 | Daily Glassy tile, before / after | before: under Inventory with a small ODDS tag and price tag ([14](captures/14_daily_tile_before.jpg)); after: top of the left column with a full-width emerald ⏣ 9 gem, a DAILY tag, a larger ODDS button and the rarity odds strip beside it | [15](captures/15_daily_tile_after.jpg) |
| 16 | Tap the tile | the Robux prompt opens straight away (Studio test dialog); the receipt grants once (a replayed PurchaseId is a no-op); the glassy comes out of the Kiln reveal | – |
| 17 | After buying | tile, strip and ODDS hide; Shop / Inventory move back up; with the server clock one day ahead the tile comes back | [16](captures/16_daily_bought_tile_gone.jpg) |
| 18 | ODDS button | opens the odds table (DETAILS lists every glassy) | [03](captures/03_daily_glassy_odds.jpg) |
| 19 | Marbles page | packs first (7 of them, 4 across), Daily Marbles below | [17](captures/17_marbles_packs_first.jpg), [18](captures/18_marbles_daily_below.jpg) |
| 20 | iPhone 17 Pro | Daily tile + odds on top, Shop and Inventory side by side under it, nothing near the thumbstick | [19](captures/19_phone_daily_top.jpg) |

Also fixed: an offer update arriving while a popup was open could leave the tile hidden after the popup closed (the
controller re-applies the state on every popup close).

## Not checked / follow-ups

- **Real Robux prompts for the new offers**: they need the developer products (MONETIZATION.md §9). The Handful
  (unchanged price) opened Studio's test purchase dialog as before.
- **Phone taps**: Studio's device simulator didn't pass MCP mouse clicks to the game, so phone checks are visual.
- **Controller**: the popups register with GamepadNav (BUY first, B closes), but no real controller was used.
- While a popup is open the HUD under it should hide (only the wallet stays); on a fresh join the HUD can reappear
  under the popup when loading finishes. Cosmetic (the popup is modal).
- Daybreak's meshes were still in moderation ("not approved") in this Studio, so its card used the item picture.
