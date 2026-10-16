# Glassies, Finisher and Flyer crates — 2026-10-16

Creator-approved scope: independent cosmetic crates, duplicate counts, the same item pool in both currencies, improved Marble rarity odds, matching inventories and more satisfying openings. Follow-up feedback specifically requested fixing scrolling, themed buttons and incorrectly framed/oriented display models.

## Behavior and provisional tuning

| Category | Coins: 1 / 10 | Marbles: 1 / 10 |
| --- | --- | --- |
| Glassies | 300 / 2,700 (existing) | 30 / 300 (provisional) |
| Finishers | 300 / 3,000 | 30 / 300 |
| Flyers | 1,000 / 10,000 | 100 / 1,000 |

The cosmetic prices and duplicate counts were explicitly approved. Rarity assignments/weights and the Glassies Marble price remain provisional tuning. Finisher Coin rarity weights are 60/25/10/4/1; Marble weights are 25/30/25/15/5. Flyers use Common–Epic, normalizing the same weights over present buckets (Coin total 99; Marble total 95). Glassies keep their existing Coin odds; Marble weights include Mythic at 1, total 101. The same installed IDs appear in each currency pair. Exact per-item odds are available through View All before opening; rarity totals and preview-card odds also appear on the purchase page.

Server quotes bind price, available pool and odds for 60 seconds. Only valid 1/10 quantities, sufficient wallets, current quotes and eligible policies can grant rewards. Each quote grants once; debit and grants do not yield. Marble offers/controls are absent for restricted or unresolved paid-random eligibility, and eligibility is rechecked when spending. This does not activate Robux products or sell currency.

Existing cosmetic ownership migrates to counts of at least one. The default Skyboard and Crystal Pop stay free; future nonstarter acquisition uses crates, replacing the earlier match milestones. Already-owned milestone cosmetics remain owned/equippable. Duplicates increment copies without converting cosmetic rewards into Coins. Glassy star/Rainbow/max-star bonus rules remain intact.

## Presentation

- Larger shop/inventory shells preserve the original stained-glass artwork. New purchase, View All, preview and equip controls clone the existing gem buttons and use their hover/press animations.
- Five recycled prize slots move continuously and wrap. Card anchors agree with interaction animation; background/nameplate/portrait sizing fits the strip. Prize strips are Frames and accept no drag/wheel scrolling. View All and inventory remain manually scrollable.
- Kiln and Blender-mesh capsule previews fit their actual bounds. Capsules face their front emblems; camera fitting uses both viewport axes and updates after resizing. Inventory portraits share the same fitting system.
- Finishers/Flyers use the Glassy owned/unowned grid and detail shell, rarity colors, owned-copy counts, equip/unequip-to-default and original preview effects.
- Server-pinned reels lead to one category-colored capsule firing with a rising lid/core pulse, then all awarded cards. Cards display new items or cumulative duplicate counts. Skip/Collect/close retain the existing cleanup and inventory-flight behavior. Filling the reels never changes awards.
- Low-balance controls stay visible. Marble shortfalls set the existing-style future-store attribute; no product purchase is invoked.

## Verification

- Lune: **111 passed, 0 failed**.
- Focused Client fixture `tools/studio/check_crate_ui_v1.luau`: **68 passed**, covering themed controls/minimum targets, card layout, slot reuse, wrap/reset, narrow stacked panes and hiding baked premium panels. Narrow-container checks are not a Device Emulator/phone pass.
- Actual server/remote flow in isolated Studio mock profiles: 20,000 Coins / 3,000 Marbles → 19,700 / 3,000 after one Finisher → 19,700 / 2,000 after ten Flyers. Eleven Flyer copies including the free starter; duplicate counts and wallet survived mock Save/Reload. Ten awarded cards and one firing verified.
- Spent-quote replay rejected. Policy switched from allowed to restricted after a valid quote: Marble purchase rejected without wallet change; restricted quote omitted all three Marble offers. Invalid quantity and insufficient funds rejected; refreshed odds preserved the visible error. Closing removed opening audio.
- Studio visual review: all three shops, exact-odds grid, Finisher/Flyer inventories, single Finisher reward and ten Flyer rewards. Existing Roblox CorePackages/FoundationProvider and asset 203785492 type warnings remain unrelated. No new game-script errors observed.
- Required unchanged-combat balance sim: mirror rounds 19.6–36.8 seconds, 0% mirror timeouts, side-one bias 49%, aggregate comeback rate 39%. Existing equal-stat power range 21–83% still needs separate balance review; this pass changes no combat tuning.
- Economy sim: ~5.7-minute matches, 10.5/hour, 3 day-one / 81 day-30 Glassy pulls; first Rare median 57 minutes, Epic 2.8 hours, Legendary 11.3 hours. This existing simulator does not model the new optional cosmetic spending; prices remain provisional.

## Editable assets and recovery

Current native templates: `StarterGui.KilnScreen`, `CollectionScreen`, `KilnRevealScreen`. Six editable currency panels/30 preview slots; cosmetic inventory starts hidden. Original UI is preserved in `ServerStorage.UIBackups.CrateShopBeforeV1`, with intermediate bake copies in child folders. Original CoinKiln controls remain hidden in the template as the shared button/art source.

`ReplicatedStorage.Assets.Crates` contains the preserved Kiln model plus original Burst/Sky capsules assembled from our installed Blender meshes. This pass adds no external art, plugins or animations.

Recovery: `places/CrateShop_v1.rbxm`, **487,761 bytes**, SHA256 `570f1fca7cf9e53c92d6d4fbd63790310d1e89b1fd2fcec23710139a02fd95eb`. Script-free serialization/deserialization verified; bundle contains three UI templates plus Crates. Restore UI into StarterGui and Crates into ReplicatedStorage.Assets; keep any intervening creator edits backed up first. Source scripts continue through Rojo. Builder and bake helpers are in `tools/studio/`.

Studio left in Edit, unpublished; scheduling stays paused. Creator subjective feel, real phone/controller layout and real persisted-session checks remain open.
