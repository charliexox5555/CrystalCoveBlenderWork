# Selection and round finish polish

October 15, 2026. Implements the creator's latest selection, ghost-glass, avatar and camera feedback. The supplied screenshots guide the clear three-card layout and selected marker; the creator's text takes priority over their example's Yes/No confirmation buttons.

Selection now allows **25 seconds**, aiming **15 seconds**, release countdown **4 seconds**, and round-end presentation **6 seconds**. Choosing and locking early still advances phases when both sides are ready. Rerolls reserve 2.6 seconds for the 2.33-second reel reveal. Watch rejoin allowance covers the longer selection phase.

The editable selection screen has larger portraits, name/type/rarity/power labels, a visible selection check, two clear action buttons, wallet and inline uniform reroll odds. View Odds lists every owned outcome with its inclusion chance. Paid rerolls remain hidden under restricted paid-random policy. Paid Pick Any and reroll send the current server quote immediately, without an extra confirmation. Client busy guards plus existing server revision/ownership/deadline/rate/price checks prevent repeat spending.

Buttons remain visible when the wallet is short. An owned `MarblesRequested` BindableEvent on RollScreen fires the action and shortfall for future store wiring; an optional constructor callback is also available. Current copy honestly says packs are unavailable. No product ID, purchase prompt, paid storefront or receipt path was activated.

Reels now have glass ticks, a slight tumble, slowing motion, landing glow and a settling bounce, pinned to the server's actual results. The panel enters with a short pop. Countdown/release text pulses; glassy HP numbers bounce on confirmed hits. Confirmed signature damage and healing get floating numbers; misses produce no damage popup. Existing complete text/stroke fading is retained.

Two ghost-glass causes were fixed. Signature detail animations could make shattered parts visible again or pull a flying winner's details back toward the old arena pose; they now stop for broken/finishing glassies. Shatter owns its broken state, stops emitters and is idempotent. Separately, cancelling an aiming preview did not send Idle because its simulation session didn't exist yet; FightService now closes both previews and started fights. The native selection audit exposed five retained previews before this fix; the repeat finishes with zero local fight roots/views and restores the Custom camera.

Avatar impact now adds a short highlight and toy fragments while leaving real avatar parts, face transparency and Humanoid health untouched. After the shatter, the camera returns from orbit to the normal arena angle, gently moves closer toward the losing avatar during winner flight, holds briefly and returns. It uses the existing FOV; user orbit remains available during Fighting.

## Evidence

- **100** Lune and Studio logic tests pass. New orchestration coverage verifies 25-second selection/15-second aiming timeouts and automatic defaults; early-ready transitions remain covered. The economy duration expectation explicitly reflects the new full-timeout flow.
- **154** native selection UI checks: sequential server-pinned reels, direct free/paid pick and reroll, busy guards, visible low-balance actions/future-store hook, all 24 outcomes/odds, policy gating, text fit and interrupted-audio cleanup.
- **179** native finish checks across all 24 models: no resurrected parts/emitters, no flying-detail snapback, camera reset/zoom/return, avatar/face/health preservation and winner hiding at impact.
- **75** native mock-server selection checks: exact spending tiers, retained hand/free use, stale/forged/replayed/unowned/restricted/insufficient/late rejection, persistence and match reset. Repeated after the preview cleanup fix; zero client errors/remaining views/roots.
- **4** focused power-number checks: confirmed damage/heal popups, HP-number pulse and no damage popup on misses.

[Native report](selection_polish_native.json), [UI image](selection_polish.jpg), [required balance diagnostic](selection_polish_balance.txt), [required economy report](selection_polish_economy.txt).

With every selection/aim timer exhausted, the economy stand-in estimates **5.7 minutes per match**, 10.5 matches/hour, 3/81 day-one/day-30 pulls, Rare 57 minutes, Epic 2.8 hours and Legendary 11.3 hours. Early-ready players are faster. Costs, odds and reward amounts are unchanged. Signature balance diagnostic remains skewed because its encounter model lacks actual geometry; no new power balance approval is claimed.

## Recoverable UI and next review

Original UI: `ServerStorage.UIBackups.RollBeforeSelectionPolish_20261015`. Reproducible builder: `tools/studio/polish_match_selection_v2.luau`; it preserves creator edits on repeated runs. Native snapshot: `places/MatchSelection_Polish_v2.rbxm`, 52,342 bytes, SHA256 `c7ade030f338bae9f52e4c30ccaa1f28d30e66fd848a2294402d9d395128caf1`; native deserialize verifies RollScreen/version/odds control. Restore its RollScreen into StarterGui after preserving any newer creator edits. Existing Blender and combat-native libraries remain unchanged.

Creator reviews the normal-speed selection feel, final camera framing on real avatars and phone/gamepad input. No device changes, desktop input, publishing or broad repeated multiplayer pass. Save the Studio place to keep the editable layout. [Current 24 powers and brainstorm](../../design/POWER_BRAINSTORM_24.md) separates installed behavior from future ideas; major power redesigns were not silently installed in this polish pass.
