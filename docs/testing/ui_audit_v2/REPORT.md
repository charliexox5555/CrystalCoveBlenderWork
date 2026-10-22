# UI audit v2: pre-test pass (2026-10-21)

Every screen a player can reach, checked in Studio Play with the device simulator before the group test and Saturday's
release. "Before" captures are in [before/](before/), "after" captures (once fixed) in [after/](after/).

How: Studio Play on a fresh mock profile, onboarding played through once (Welcome → first opening → Daily), then
skipped with `OnboardingDev`. Screens opened with `PlayerScripts.UIAuditDev` (`Open` / `Close`) and
`LobbyClientDev` (`ShopTab`, `PreviewKiln`, `KilnPull`, `PreviewMatch`), a real bot match from PLAY. Every state was
scanned with `UIAuditDev:Invoke("Scan")`, which now also reports text drawn over other text (`TEXT-OVERLAP`), text
under 9.5 px (`TINY`) and two windows open at once (`TWO-OPEN`), and it skips TopbarPlus' own hidden copies.

Severity: **High** breaks a screen or looks broken to every player; **Medium** clearly visible on a common device or
in a common flow; **Low** polish.

## Findings

| # | Sev | Where | Problem | Status |
|---|---|---|---|---|
| 1 | High | Shop header (laptop) | The Shop sometimes opened with the phone header (full-width tabs, pills in the title strip) on a 1366x768 laptop, then switched to the desktop header (tabs and pills sharing a row) when the window was rebuilt (after a pull) — the header visibly jumps ([08](before/laptop_08_shop_featured.jpg) → [12](before/laptop_12_shop_header_jumps.jpg)). The phone layout was applied once, when the window was created, and never taken back. | Fixed: `ResponsiveController` applies or undoes the phone layout on every fit (keeps the screen's own values, so the Marbles tab still resizes the row); an unsized camera never counts as a phone |
| 2 | Medium | Lobby HUD tiles | The Daily Glassy and Starter Pack tiles stay on screen while the rest of the HUD hides: over the onboarding Welcome card ([02](before/laptop_02_welcome.jpg)) and beside the Kiln reveals ([13](before/laptop_13_kiln10_reveal_tiles.jpg)); the Starter tile touches the reveal's right column. | Sent to the monetization session (owns the tiles) |
| 3 | Medium | Daily Glassy tile | ODDS button is 102x30 px at 1366x768 (≈20 px tall on a Galaxy A06), under the 44 px tap target; the ⏣ 9 gem text is ≈8 px. | Monetization session is fixing it (the ODDS button became its own HUD button, `LobbyHUD.DailyOddsButton`; the odds strip and big gem were removed on the creator's request in a30cc7b) |
| 4 | Medium | Roll cards | Long power texts wrap to three tiny lines and touch the card's bottom edge (Potion Flask, [21](before/laptop_21_roll_match.jpg)); Midnight (124 characters), Sunny (101) and Whiskers (93) are longer still. | Fixed: the text box uses the card's full glass width and sits clear of the bottom edge |
| 5 | Medium | Fight billboards | Under the name and hearts, the glassy chip and HP line are ≈5-6 px on a laptop ([22](before/laptop_22_aim.jpg), [24](before/laptop_24_fight_cast.jpg)): unreadable. | Fixed: billboards are 1.5x on every screen (`Config/Responsive.BillboardMinScale`), up to 1.8x on short phones, and grow upwards so the HP line stays off the avatar's head ([a06 10](before/a06_10_aim_billboard_overlap.jpg) was the first try) |
| 6 | Low | Daily / Playtime / Codes | The coin and Marble counters stay on screen (on purpose: claimed currency flies into them) but the window's corner covers half of them ([05](before/laptop_05_daily_auto.jpg), [17](before/laptop_17_playtime.jpg)). | Fixed: while a reward window is open the counters draw above it |
| 7 | Low | Wallets and prices | Numbers read two ways: "10000" in the wallets, "2700 COINS" on the Kiln, but "13,000" on the Marble page. | Fixed: one `Util.commas` for the lobby, Shop and match wallets, Kiln OPEN prices and daily-offer coin prices |
| 8 | Low | Marbles page | Pack name tag and bonus tag run into each other (MARBLE BUCKET / +23% BONUS, BARREL, VAULT); the Daily Marbles stack pokes above its card into the TODAY / +21% tags ([09](before/laptop_09_shop_marbles.jpg), [10](before/laptop_10_shop_daily_marbles.jpg)). | Monetization session is fixing it |
| 9 | Low | Lobby HUD | Nav labels are fitted one by one, so "Shop" is 26 px and "Inventory" 22 px. | Not changed (cosmetic) |
| 10 | Low | Kiln prize cards | The odds chip is small and straddles the card's bottom edge (by design); "5.11%" is ≈10 px on a laptop. | Not changed (design) |
| 11 | Low | Shop footers | "Same items in both crates…" and "Marbles pay for…" captions are ≈11 px and sit on the window frame. | Not changed |
| 12 | **High** | Kiln odds on phones | On a Galaxy A06 the Shop window is height-bound (465x257 px of a 705x338 screen: Roblox's top bar takes 58 px and the window keeps its 1.8 aspect), so the rarity odds rows are 7 px and the prize cards' names 6 px and odds 5 px ([a06 05](before/a06_05_shop_glassies.jpg)). The odds are there before every pull, but a child can't read them. | **Needs the creator**: proposal below |
| 13 | Medium | Inventory info pane on phones | Same cause: the passive / power descriptions are cut mid-sentence ("Charges through body clashes. Tap"), stats 6-7 px ([a06 07](before/a06_07_inventory.jpg)). | Needs the creator (same proposal) |
| 14 | Medium | Lobby nav on phones | "Inventory" is cut to "Invent..." (its label is 33x11 px) and the Shop / Inventory buttons are ≈40 pt ([a06 01](before/a06_01_lobby_first.jpg)). | (pending) |
| 15 | Medium | Starter Pack popup on phones | Close is 27x27 px and the popup's top-right corner runs into the touch wallet ([a06 03](before/a06_03_starter_popup.jpg)). | Sent to the monetization session |
| 16 | Medium | Marble "+" on phones | 26x30 px in the HUD and the Shop header. | Sent to the monetization session |
| 17 | Medium | Queue on phones | INVITE FRIEND is 107x30 px ([a06 08](before/a06_08_queue.jpg)). | Fixed: at least 40 px tall |
| 18 | Low | Profile vs Inventory | Profile said "Glassies 0/36" while the Inventory listed 39 (the Daily and Starter Pack glassies were left out of the profile total) ([a06 13](before/a06_13_profile.jpg), [a06 07](before/a06_07_inventory.jpg)). | Fixed: both count `Glassies.visible` |
| 19 | Low | Roll cards on phones | Power text fits on one line with "…" ([a06 09](before/a06_09_roll.jpg)); the whole text is in Pick Any and the Inventory. | Not changed |
| 20 | Low | Daily Rewards on phones | The CLAIM pill is 48x13 px, but the whole Day card claims (decision 106). | Not changed |
| 21 | Low | PLAY hint on phones | "joins the nearest free arena" sits on the PLAY button's top edge. | (pending) |

## Devices

| Device | Viewport | Result |
|---|---|---|
| Average Laptop | 1365x768 | captures 01-25 in [before/](before/) |

## For the creator: windows on small phones (findings 12, 13)

Every menu keeps the shape it was drawn at (the Shop is 1.8 : 1). A landscape phone minus Roblox's 58 px top bar is
about 2.5 : 1, so the window fills the height but only two thirds of the width, and the text in its busiest panels
ends up 5-8 px. Making windows taller isn't possible (the top bar icons sit where the title banners would go), so the
fix is to show less in those panels on phones:

- **Kiln (Glassies / Finishers / Flyers tabs):** on phones only, drop the four prize cards under "PRIZE PREVIEW" and
  let the odds list use that space (rows about twice as tall, ≈14 px). VIEW ALL stays where it is and opens every
  prize with its chance, as now.
- **Inventory info pane:** on phones only, a smaller 3D preview, and the passive / power descriptions get its room
  (two lines each instead of one).

Both change how those two screens look on phones (laptop, tablet and console stay as they are), so they wait for
your OK.

## Not checked / follow-ups

(pending)
