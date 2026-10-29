# Classic loop integration — October 29

Target: Glass vs Glass, place 129420351303019. Files synced directly through Roblox MCP; no Rojo. Initial Studio version 696 already contained the unfinished classic-combat patch. Existing local work was retained and completed. Changed script copies are preserved in ServerStorage.ClassicBefore20261029.

Published through Studio File > Publish. Native Output confirms successful publication and version **700**. The loaded Edit DataModel's PlaceVersion getter remained 696, so the publication confirmation is the version evidence. Studio is in Edit with default viewport.

## Verified

- Final source/Studio equality check: 28 changed/new Luau scripts. Final Lune and Studio RunAll: **287 passed, 0 failed**. Changed sources formatted; unrelated existing formatting differences were not rewritten.
- Galaxy A06 landscape (705×338) and iPhone 17 Pro landscape runtime (749×381): welcome, collection, first duel and reward/replay flow exercised. The runtime intentionally forces landscape (decision 106); portrait emulator selection did not constitute a portrait gameplay test. Studio reset to default viewport afterwards.
- Welcome COLLECT advances to Arena; **100 existing Day 1 coins**, no Daily Rewards modal. Trusted calendar completion bypasses the remote limiter, retains the same once-per-day rule and requests saving before advancement.
- Two no-input introductory bot matches: **38.6 / 39.1 seconds** from match start through natural completion, including 8-second pick, 6-second aim, 2-second countdown and 4.5-second finish; actual fights approximately18 seconds. This excludes loading, welcome and walking, and is not a player median.
- Intro had one heart per side and ended after one shatter. Subsequent replay had three hearts and the first prize **Frostglobe as first/default card**, with two other owned choices and PickAnyUsed=0. Potion Flask replay portrait/goal also visually checked.
- Deliberate drag/release during a held aiming window registered **PERFECT**, disabled LOCK and advanced to Countdown before the test hold expired. No CAST/PUSH UI in the actual fights. Reliable event probe recorded no Push/Heat/GlintSpawn/Bump/Twist events.
- Reset during replay round2: `ClassicMatchDurationV1 Reset`, no natural-completion step and no legacy Second Match Finished; zero additional XP, pending first-prize hand preserved.
- Reset after the final authoritative introductory shatter: match win still recorded, normal completion retained and first reward available. Test attribute ClassicFinalResetPassed=true.
- New match funnel logs exactly Started→First fight→First shatter→Completed for a natural finish; early reset stops before Completed. Production dashboard ingestion remains unverified from Studio.
- Source fixes from review: controller B dismisses replay; loader gates reconnect prompt; concise return-goal copy; first PvP loss no longer claims victory; long HP-panel names no longer inherit the world tag's shrinking aspect constraint; paid Daily Glassy label distinct from free Daily Rewards.

## Simulations

Final full outputs: [tests](classic_balance_2026_10_29/final_tests.txt), [balance](classic_balance_2026_10_29/final_balance_sim.txt), [economy](classic_balance_2026_10_29/final_economy_sim.txt).

Stand-in balance: mirror rounds16.8–26.0s, side1 bias51%, Perfect/worst60%, five-star Pop52%. The stand-in lacks live power geometry/policy fidelity; do not tune kits from its field table. Real swing: 6,240 equal:auto baseline rounds, mean20.9s,2.3%timeouts,31/40 in45–55%; focused two-kit retune measured49.4%/53.0%. Its subset has concentrated slow/timeout matchups; no final full-roster matrix claim. See [balance report](CLASSIC_BALANCE_2026_10_29.md).

Economy model (assumes40min/day, not the creator's reported4min sessions): ~2.9min normal matches,20.8matches/hour;5day1 pulls,145byday30; Lv5after10matches,Lv10after49; first Legendary median4.0h, Mythic32%within30days. Welcome guarantees and daily exclusives are distinct from random-pull acquisition medians.

## Limits and follow-up

The old asset-type warning for203785492 remains; no literal source or ParticleEmitter texture reference was found. Final test session had no gameplay stack traces. An earlier temporary QA listener mistakenly treated the binary snapshot as a table; it was discarded with that play session and replaced with the reliable FightEvents probe. A direct controller-module inspection from the MCP VM also produced a probe-only uninitialized-controller error; final session excluded it.

No measured D1/replay lift, revenue lift or popularity claim. Need real unfamiliar mobile observations, native two-client PvP, production event verification after publish and comparable acquisition/build cohorts. Receipt audit found a separate pending-purchase limitation without saved intents; no live purchase or new monetization feature was introduced.
