# Personalized daily store and Hollowlight bundle

Creator direction, 2026-10-16. This is the implementation queue/design brief; product IDs, prices, dates and sales are not activated.

## Accepted requirements

- Four visible offers per player: three Robux items, one Coin item. Robux offers generally feature good mid/high-tier items, with occasional higher-tier choices. Coin offers can occasionally be good but should stay modest.
- Different daily selections for different players; stable across reconnects and servers during the same day. Separate selection and rotation formulas.
- Reset at **6 PM fixed CST (UTC−6), year-round**: **00:00 UTC**. This is 7 PM in daylight-saving Central locations during summer; it deliberately does not follow America/Chicago daylight saving.
- Multiple price levels within each Robux rarity/tier; corresponding product IDs will be supplied later. Coin offers do not use these nested Robux price levels.
- First limited bundle: original Halloween pumpkin glassy appearance, special flyer and special finisher. Creator explicitly chooses a seasonal variant, preserving the 24-glassy roster.
- Map work belongs to the creator. No map placement, arena, terrain or lighting edits in this pass.

## Proposed daily formula

Offers are direct purchases of the **specific visible item**, selected by the daily rotation before the player buys. The Coin item is a randomly selected daily offer, rather than an undisclosed random reward after payment. This interpretation follows the reference's named item cards.

```
DayKey = floor(ServerUnixSeconds / 86400)
NextReset = (DayKey + 1) * 86400
Seed = Hash(OfferVersion, UserId, DayKey, SlotIndex)
```

Use a server-owned deterministic RNG and a canonical sorted eligible catalog. Persist the four selected offers when generated, including item/category/rarity/price-band and version. Joining another server, buying an item or reopening the store must not reroll today's offers. Refresh the client countdown/offer set at the server boundary; the client clock never authorizes purchases.

Proposed slots: one Glassy, one Finisher and one Flyer for Robux. Coin category rotates through Glassies → Finishers → Flyers using `(UserId + DayKey) % 3`. Within each category, choose rarity and then choose uniformly among eligible items of that rarity. Require installed art, current release eligibility and an allowed sale flag. Exclude limited-bundle appearances from the ordinary rotation unless explicitly configured.

Starting rarity weights for review, **not live economy configuration**:

| Currency | Common | Uncommon | Rare | Epic | Legendary | Mythic |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Robux | 0 | 20 | 45 | 30 | 4.5 | 0.5 |
| Coins | 55 | 35 | 9 | 1 | 0 | 0 |

Prefer an unowned item when first generating a day's offer, otherwise allow a clearly labelled extra copy. Use a deterministic shuffled bag per category/rarity to reduce consecutive-day repeats; prevent duplicate item IDs within one day's four slots. If a bucket is empty, renormalize over eligible rarities. Ownership changes later in the day must not mutate locked offers.

For Robux only, define an item `ValueBand` within its rarity, initially Standard/Featured. Product mapping key: `(Category, Rarity, ValueBand)`; each mapping has its own future developer-product ID. The creator chooses actual Robux prices/IDs. Display the product's actual configured purchase metadata when available. Coin pricing uses a single category/rarity matrix, without nested bands. Missing configuration must stay unavailable, not guess an ID or price.

## Implementation queue and acceptance

1. Pure daily-selection module/config and deterministic date/rotation tests; simulate duplicates, tier distribution, Coin spending and acquisition pacing before enabling purchases.
2. Save daily offers and per-slot purchase state in ProfileStore. One Coin purchase per slot/day; server validates quote, day, wallet, ownership/count grant and rate limit atomically. Show owned-copy results honestly.
3. Four large Featured cards with clear category, rarity, named item, price and one shared reset countdown. The existing stained-glass skin stays; reference screenshots inform hierarchy, not copied assets. Narrow layout becomes two columns with readable controls.
4. Add future product-ID matrix and idempotent receipts. Persist a specific offer intent before prompting; delayed/retried receipts honor the original item's snapshot across reset/rejoin. Never overwrite an unresolved intent with a newer day's item. Test replay, simultaneous prompts, disconnect, cancellation, delayed receipt and reset boundaries. Real sales remain disabled until creator IDs/prices are supplied and receipt handling is verified.
5. Boundary tests: one second before/at midnight UTC, leap day, reconnect on another server, catalog update, empty rarity, low wallet and delayed receipt. Published persistence and real device review follow creator approval of configuration.

## Hollowlight: original seasonal art/presentation direction

**Hollowlight Pop**: a ribbed amber-glass pumpkin lantern, antique-gold curled stem, midnight leaves and a friendly mint-lit face. It is a Pop appearance, with Pop's authoritative stats, pressure/contact power, hit proxy and timing. Fit its visuals to the existing Pop swing envelope at installation. No 25th glassy, stronger paid stats or extra damaging projectiles.

**Lantern Skiff**: a polished violet moon-skiff with scalloped wings, gold edges, mint veins and two amber lantern engines. Separate wings/veins support a gentle glide/bank; mint exhaust curls and little sparks communicate lift. Use the existing original surf/glide poses as a starting point, then refine feet/deck contact after import.

**Lantern Eclipse**: a central pumpkin lantern, three friendly ghost wisps and an eclipsing ring. Proposed sequence: 0–0.25s lantern blink/anticipation; 0.25–0.65s wisps spiral inward with thin ribbons; 0.65–0.85s a single mint/orange pop and expanding ring; 0.85–1.7s wisps/ribbons peel away into falling glass glints. Keep the recipient visible and preserve heart/camera/damage rules. A paid appearance's spectacle is cosmetic.

For the Pumpkin pressure burst: mint light creeps along the ribs as pressure builds; the stem kicks at release and a brief friendly wisp flare appears at the real contact point. Spooky presentation must stay synchronized with the existing Pop hit, not imply a new invisible ranged attack. Purchase descriptions identify it as a seasonal look with the same underlying power.

## VFX research and production plan

Roblox's [explosion tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions) demonstrates short, one-shot emissions with drag and gradual transparency fades. Apply that pattern to a compact bright flash, slower smoke and a few faster shards; avoid a long opaque blast that hides the characters.

The [volcano VFX breakdown](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/create-volcanoes) separates surface motion, embers, splashes and smoke into layers. The same separation informs our brief: one anticipation layer, one sharp burst, then a quieter moving residue. This is a design adaptation, not copied volcano assets or lighting settings.

[Beams](https://create.roblox.com/docs/effects/beams) support endpoint width, curvature and transparency, making them suitable for the wisps' thin trailing ribbons. Preserve the readable Blender silhouettes underneath. Review [particle emitter/flipbook guidance](https://create.roblox.com/docs/effects/particle-emitters) and [performance guidance](https://create.roblox.com/docs/performance-optimization/improve) when implementing the world effects; bound the number and screen coverage of transparent layers.

Production target: three wisp actors, two thin ribbons, one ring and brief emitted bursts; start under 60 simultaneously visible particles and 20 mesh pieces, then reduce further for phones based on measured results. Keep meshes/emissions client-only, with cancellation and cleanup on round end/stream-out. No global map/Lighting changes. UI openings use the existing original 4×4 atlas (512px, 128px frames) because ordinary world particles do not render inside ViewportFrames.

## Concrete progress and remaining work

**Current:** creator imported the [refined v2 set](../../assets/blender/seasonal/hollowlight_v2/README.md). All 68 meshes are installed at normalized scale/facing, raw import preserved, permanent IDs/recovery snapshot saved. Original ghost/ring/particle finisher and Pop skin/pressure presentation pass 257 focused art checks. Seasonal ownership/equip UI, Skins tab and frozen server match/sync presentation are now implemented: 114 pure tests, 30 server/27 UI checks, real clicks and one live release/sync pass. Owners can equip; locked entries preview truthfully. Ordinary crates are unchanged, and a Studio mock-only test unlock is documented in [the equipment report](../testing/HOLLOWLIGHT_EQUIPMENT.md). Storefront/real grants/receipts and final normal-round/phone review remain pending; no sales/countdown activation. The following paragraph describes the earlier preserved prototype.

Blender prototype sources, body/details/shards exports, cosmetic FBX bundle and three 512px renders are in [the art folder](../../assets/blender/seasonal/hollowlight_v1/README.md). Pumpkin body is 1,056 triangles with 16 closed shards. Cosmetic FBX round-trip verifies 39 meshes / 11,574 triangles. An editable native VFX prototype supplies four disabled burst layers (36 particles total), two disabled curved ribbons and phase attributes, using our original textures. It lives in ReplicatedStorage.Assets.VFX.HollowlightPrototype and the saved native kit; no map placement. Earlier source is retained. No live catalog or sales change was made.

Next: creator normal-round/phone feel and any final VFX/pose polish → configured dates/product IDs, production grants and verified receipts. Import, ownership/equip data and preview/match support are implemented. Do not show an active limited-time countdown until real start/end dates are supplied.
