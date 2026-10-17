# Hollowlight inventory and match equipment

October 16, 2026. Seasonal art stays in `ReplicatedStorage.Assets.Seasonal.Hollowlight`; no additional imports or map changes.

## Behavior

- Runtime Inventory adds a themed **Skins** tab alongside Glassies, Finishers and Flyers. StarterGui originals remain unchanged. All three seasonal items have native mesh portraits, owned counts, selection and normal equip/unequip controls; long cosmetic names fit their plaques.
- Hollowlight Pop is a separate cosmetic look for **Pop**, with the same stars, stats, pressure rules and authoritative hit proxy. Skin ownership lives in `Cosmetics.Skins` / `Cosmetics.Counts.Skins`; `EquippedSkins` defaults to an empty string. Existing profiles migrate additively, preserving legacy ownership and unrelated cosmetics. No seasonal item is granted on login.
- `Config.RoundCosmetics.Seasonal` contributes to the inspectable/equippable catalog and ID map; ordinary `Rideables`/`Finishers` arrays remain the unchanged crate/bot pools. No seasonal Coin/Marble odds, prices, products or sale dates are activated. Locked entries say **SEASONAL · NOT AVAILABLE YET**, remain previewable, and cannot equip.
- Existing rate-limited equip remote validates category, ID, installed art and ownership. A skin requires its base glassy. The server captures validated equipment once per match; midmatch changes apply next match. Match/roll/aim/countdown/fight/round-end descriptions carry the frozen look, and late-sync fight data preserves it. Only Pop receives the pumpkin mesh. Ordinary Pop/Jam/Prism/etc. retain their normal visuals.
- Skiff resolves from the seasonal library and uses its existing original glider pose/hinges. Lantern Eclipse resolves its original sound and animated mesh/particle sequence. Inventory, final hand cards, reel cells and the owned picker show the equipped Pop look without changing IDs or odds.

## Verification

- **114 Lune tests pass.** New cases cover seasonal grant/equip/reload, base ownership, no automatic grants, malformed saved counts, profile independence, frozen loadouts, unchanged currency and exclusion from both ordinary crate currencies. Existing combat/economy tests still pass; no Balance/Glassies/Powers changes or simulator rerun.
- **30 native server checks** with an explicitly isolated Studio mock profile: unowned/malformed/spam rejection, idempotent test grant, all three categories equip, actual ProfileStore mock save/reload, copy counts, zero wallet change, normal staged skiff and frozen/matching-base appearance. Run `tools/studio/verify_hollowlight_equipment_server.luau` in a temporary native QA Script context so service requires share the game server's cache; direct MCP requires use a separate cache. It leaves an aiming review match; clean up through `MatchDev:Invoke("SelectionTest", "Forfeit", player)`.
- **27 native client checks** in `verify_hollowlight_inventory.luau`: four active tabs fit inside their header, unchanged 24-glassy roster, equipped Pop portrait, all seasonal ownership/portraits, long labels, preview replay/tab-switch cancellation and unavailable states. Fixture creates/destroys its own UI.
- Actual Studio MCP mouse clicks separately verified Skins, Flyers, Lantern Skiff selection, Lantern Eclipse selection/animated preview/replay, and skin equip/unequip. Server snapshots confirm the clicks changed equipment while preserving Coins/Marbles. Let deferred button events settle before targeting controls created by a tab switch.
- `verify_hollowlight_round.luau` advances one mock normal match through release: **4 assertions**, server phase Fighting, base Id `pop`, normal **112 max HP**, pumpkin skin and Lantern Eclipse frozen in the session. `FightService:Sync` was called and the client rendered the permanent pumpkin mesh after sync; real avatar stayed at **100 health**. The match was forfeited and temporary QA/UI roots removed. No completion reward was claimed.
- Installed art recovery remains `places/Hollowlight_v2.rbxm`; this pass changes source runtime only. Studio returned to Edit/unpublished, map/lighting/device settings untouched, schedules remain paused. Existing Roblox FoundationProvider and asset-type 203785492 warnings remain; initial observer attempts used the isolated MCP service cache and batched clicks before tab creation, then were corrected. No observed gameplay-script errors in the successful checks.

## Creator test

Start **Play**, then run in the **Server** command bar:

```lua
game.ServerStorage.CosmeticDev:Invoke("PreviewHollowlight", game.Players:GetPlayers()[1])
```

This idempotently unlocks one copy of all three items **only when Studio uses mock profiles**. It has no client remote, does not spend currency, and cannot grant production ownership. Open Inventory → Skins / Flyers / Finishers and equip each item. Pick Pop in a round to see Hollowlight; other glassies keep their own appearance. The test unlock is session-local; actual production grants and sales remain unconfigured.

Remaining: creator normal-round/phone feel, optional distinct seasonal riding-pose refinement, production ownership grants/receipt integration and real product IDs/dates before any storefront activation. Daily personalized shop remains queued separately.
