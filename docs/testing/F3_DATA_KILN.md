# F3 data, Kiln and collection — 2026-10-14

ProfileStore is pinned and reviewed in `docs/vendor`. Published servers use session-locked profiles; Studio defaults to an isolated mock store. With Studio API access off, mock save/reload retained 321 test coins and Pop ★1. Lune and Studio: **65 passed, 0 failed**. A legacy-stars migration bug was caught and fixed by tests. Production datastore/rejoin checks need a published test server.

A complete live match awarded and mock-saved 54 coins, 5 trophies, one match win, 3 observed shatters/round wins, 3 Perfect releases, one use of each starter, and one welcome pull. A collection → match → active fight → reset regression returned TouchControlsEnabled from false to true and left no active match. Shared touch-control ownership fixes the previous restore-order race between lobby, match and fight UI.

Kiln coin pulls use Formula, server-selected content, single-use expiring odds quotes, duplicate stars/overflow and welcome eligibility after the first match. The installed pool currently contains only the three starters, which cannot be pulled. A valid-quote request with an empty pool retained 321 coins and zero pulls. No eligible art means no debit. Real paid coin-pull integration remains gated on manual non-starter imports; there are no Robux or Marble purchases.

Lobby HUD, collection filters/sort, scrolling power details and the Index are implemented. Unknown art uses question tiles; installed unowned art can use a dark silhouette. Kiln opens with all eligible odds visible, coin prices and independent Rainbow odds; reveals inflate/cool a bubble, show duplicate stars, advance individually or Skip back to fresh odds. A Studio-only preview exercises the reveal using starter portraits without granting anything. Index completion rewards await a configured reward rule; none were invented.

## Visual evidence

- Samsung Galaxy A06 landscape: [collection](f3/f3_collection_a06.jpg), [detail](f3/f3_detail_a06.jpg), [scrolled powers](f3/f3_powers_a06.jpg), [empty Kiln](f3/f3_kiln_closed_a06.jpg).
- iPhone 17 Pro landscape: [Index](f3/f3_index_iphone.jpg), [duplicate reveal preview](f3/f3_reveal_iphone.jpg). Fixed reveal-button overlap found on the shorter A06 layout. Wider UI/device verification continues in the next pass.

The MCP mouse helper did not consistently activate top-right buttons under device emulation; direct visual-fixture navigation and scrolling worked. Do not treat a helper's “Success” as proof of an Activated callback. Gamepad ButtonB was rejected by VirtualInput as a CoreGui binding. Manual close/gamepad verification remains part of the user phone pass unless a later integration check resolves the tooling issue.

## Simulator baseline

No fight/power/rarity/economy numbers changed. `F3_backend_balance.txt`: starter mirror averages Pop 22.3 s, Jam 43.6 s, Prism 19.9 s, no timeouts; Pop mirror side-one win rate 49%. `F3_backend_economy.txt`: ~3.7 min matches, 4 day-one pulls, 96 by day 30, median first Rare 47 min, Epic 2.1 h, Legendary 9 h. These use the passing FightModel baseline; actual-swing calibration remains in the F1 report for Claude.
