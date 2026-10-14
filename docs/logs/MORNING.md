# Morning handoff — 2026-10-14

The requested free-game backlog is implemented. Native multiplayer, security and cleanup checks pass; imports, publishing and real-device approval remain owner actions. Final UI images/styling are the creator's work under the latest direction.

## Your actions, in order

1. **Save a local place backup and stop Play.** Import the nine glassy FBX bundles from `assets/blender/import_wave1` into **Workspace.GlassClashImports**, preserving separate meshes/names/pivots. Follow [the exact import steps](../../assets/blender/import_wave1/README.md).
2. Tell Codex the imports are ready, or run `tools/studio/install_wave1_glassies.luau` in the Command Bar. The installer skips existing assets, installs only complete sets and preserves raw imports in ServerStorage. Native import scale/pivots, portraits, cracks, shatter and real Kiln pulls still need verification after import.
3. Import the eight sky-prop bundles into the same raw-import folder. Leave them there for Codex's placement pass around your fences/decor. The glassy installer ignores those props. No old lobby builder should be rerun.
4. Edit the **14 ScreenGui templates under StarterGui** whenever ready. [UI editing guide](../ui/EDITING_UI.md). Keep names and Templates folders; replace Icon images and style the placeholders. Layout uses Scale with zero offsets. Save the place locally.
5. Publish manually through Studio, then use a published test server to check real ProfileStore reconnect/session locking and ordered leaderboard updates. Studio stays on isolated mock progress even with API access enabled.
6. On a real phone, check pick → drag to gold → lock → powers → shatter → results/replay. Check sound, readability, close buttons, touch controls and frame rate; use MicroProfiler on a low-end device. Manual gamepad checks remain open because MCP ButtonB input was blocked by CoreGui.
7. Supply the group ID and permitted reward configuration if you want the join reward. Index completion rewards also need a chosen rule.

## Finished by backlog item

| Item | Implemented and verified | Evidence |
|---|---|---|
| F1 fight | Server custom 3D pendulums, pass-bys/spin/tumble, auto powers, interpolation, aim/LOCK, layered impacts/cracks, slow-mo shards. 80 Lune + 40 Studio calibration rounds, ten live watched rounds including double KO. | [F1 report](../testing/F1_FIGHT.md) |
| F2 matches | Seven arenas, human pads/bot fill, Roll/Aim/Countdown/Fight/round end/Results, free rerolls, replay, reset/disconnect handling, nearby spectator fights. | [F2 report](../testing/F2_MATCH_FLOW.md) |
| F3 data/Kiln/collection | Reviewed pinned official ProfileStore, locked production profiles, starter grants, idempotent settlement, saved stats/collection, odds-first coin Kiln, welcome pull, duplicate stars/overflow, reveal, filters/details/Index. | [F3 report](../testing/F3_DATA_KILN.md), [vendor review](../vendor/ProfileStore_REVIEW.md) |
| UI | Fourteen editable StarterGui templates, shared scale-based components and image/list placeholders; controller binding preserves authored geometry. Native Edit audit: 14 screens, zero Position/Size/CanvasSize offsets. 39 layout states checked on A06, iPhone and iPad; final art is yours. | [Editing guide](../ui/EDITING_UI.md), F3/F4 screenshots |
| Blender | Eight sky props and nine glassies (six Commons + three Uncommons), each glassy with body/details, 16 closed shards, 144 surface crack segments and 512 icon. 17 bundles / 183 meshes, FBX round-trip bounds error below .000002 studs. | [Asset report](../testing/ASSET_WAVE1.md), [imports](../../assets/blender/import_wave1/README.md) |
| Free F4 | Three daily quests, playtime gifts, first observed win bonus, check-in streak tracking, one-use Studio test code, Daily/Codes kiosks, Trophies/Wins/Shatters boards. Save/reload retained 290 fixture coins; duplicate/malformed claims granted nothing extra. | [F4 report](../testing/F4_FREE_RETENTION.md) |
| Bug/security/performance pass | Native two-client PvP plus a third staggered join, snapshot loss, replay, disconnect and camera/control cleanup. Fixed late-join hook replication, stale far-arena events and double-KO flash leak. 20 repeated double-KO component cycles: 123 assertions pass, zero retained flashes. | [F5 report](../testing/F5_MULTIPLAYER_SECURITY.md) |

**Current unit tests: 71 passed, 0 failed in Lune and Studio.** Paid features, free Marbles and automatic publication remain disabled.

## Installed content and deferred checks

Only `pop`, `jam`, `prism` are installed. Starters are excluded from the Kiln, so the Kiln stays unavailable until complete non-starter art sets are imported. Actual odds normalize across installed eligible content. No missing art enters a normal roll. A native-Part Kiln placeholder remains at the existing lobby spot.

Native import/placement, real persistent-store session takeover/reconnect, published global boards, real-phone performance and final UI art are pending. Group grants and Index completion rewards have no invented fallback. No new paid features or third-party dependencies were added.

## Open reward rule

Native PvP confirms that leaving before a round finishes still grants normal MatchLogic coins/trophies and a match win/loss. This can be farmed. The creator has been asked whether abandoned matches should give no rewards until at least one real round completes; **the rule is unchanged pending that answer**, because the overnight instructions freeze the economy. Actual round-win/shatter stats and the first-win bonus already require observed fights.

## Calibration for Claude

80 actual-integrator rounds, seeds 101–180: 0 timeouts, .461 hits/s, 36.7% pass-bys; encounter interval 1.372 s. Median speed 20.67 studs/s (P10 7.22, P90 29.45), ShareA .499, median round 32.56 s (P10 18.69, P90 45.58). Beam 32/43 and Freeze 34/56 landed; combined 66.7%. Max string error .0000015 studs. Raw: `docs/testing/F1_calibration_draft.json`.

Candidate SimModel: HitInterval=1.37, SpeedAtAmplitude=24.5, SpeedSpread=.67, ShareSpread=.245, MissChance=.367. It fails Jam mirror duration (45.882 s >45) and Prism Blade fairness (63% >62%). The passing baseline was restored. **No Fight/Powers/rarity/economy values retuned.** Claude should review the candidate and measured aimed-power rates.

Passing baseline balance/economy: starter mirrors Pop/Jam/Prism 22.3/43.6/19.9 s, no timeouts; ~3.7 min matches, 4 day-one / 96 day-30 pulls, median first Rare 47 min / Epic 2.1 h / Legendary 9 h. Reports: `F4_balance.txt`, `F4_economy.txt`.

## Constraints preserved

Manual fences/decor, LegacyKit, imported assets and unrelated untracked files remain untouched. Rojo owns code; editable UI/world stay in the place. No publishing, paid products, new plugins, force-pushes or frozen balance retuning.
