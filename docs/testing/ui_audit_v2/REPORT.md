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
| 3 | Medium | Daily Glassy tile | ODDS button is 102x30 px at 1366x768 (≈20 px tall on a Galaxy A06), under the 44 px tap target; the ⏣ 9 gem text is ≈8 px. | Sent to the monetization session |
| 4 | Medium | Roll cards | Long power texts wrap to three tiny lines and touch the card's bottom edge (Potion Flask, [21](before/laptop_21_roll_match.jpg)); Midnight (124 characters), Sunny (101) and Whiskers (93) are longer still. | Fixed: the text box uses the card's full glass width and sits clear of the bottom edge |
| 5 | Medium | Fight billboards | Under the name and hearts, the glassy chip and HP line are ≈5-6 px on a laptop ([22](before/laptop_22_aim.jpg), [24](before/laptop_24_fight_cast.jpg)): unreadable. | (pending) |
| 6 | Low | Daily / Playtime / Codes | The coin and Marble counters stay on screen (on purpose: claimed currency flies into them) but the window's corner covers half of them ([05](before/laptop_05_daily_auto.jpg), [17](before/laptop_17_playtime.jpg)). | Fixed: while a reward window is open the counters draw above it |
| 7 | Low | Wallets and prices | Numbers read two ways: "10000" in the wallets, "2700 COINS" on the Kiln, but "13,000" on the Marble page. | Fixed: one `Util.commas` for the lobby, Shop and match wallets, Kiln OPEN prices and daily-offer coin prices |
| 8 | Low | Marbles page | Pack name tag and bonus tag run into each other (MARBLE BUCKET / +23% BONUS, BARREL, VAULT); the Daily Marbles stack pokes above its card into the TODAY / +21% tags ([09](before/laptop_09_shop_marbles.jpg), [10](before/laptop_10_shop_daily_marbles.jpg)). | Asked the monetization session |
| 9 | Low | Lobby HUD | Nav labels are fitted one by one, so "Shop" is 26 px and "Inventory" 22 px. | Not changed (cosmetic) |
| 10 | Low | Kiln prize cards | The odds chip is small and straddles the card's bottom edge (by design); "5.11%" is ≈10 px on a laptop. | Not changed (design) |
| 11 | Low | Shop footers | "Same items in both crates…" and "Marbles pay for…" captions are ≈11 px and sit on the window frame. | Not changed |

## Devices

| Device | Viewport | Result |
|---|---|---|
| Average Laptop | 1365x768 | captures 01-25 in [before/](before/) |

## Not checked / follow-ups

(pending)
