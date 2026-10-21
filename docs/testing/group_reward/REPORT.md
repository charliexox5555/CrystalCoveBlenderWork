# Group reward: Studio test (2026-10-21)

Studio Play on the Glass Clash place, as the Studio user (a member of group 11116787), onboarding skipped with
`OnboardingDev:Invoke("Step", player, "Done")`. Design: `docs/design/GROUP_REWARD.md`.

| Check | Result |
|---|---|
| Lune `run_tests` and Studio `RunAll` (Play server) | 232 / 232 pass |
| Member on join → stand **Ready**: prompt "Claim", gold glow (3), heart bobs | ✅ |
| E at the stand → **GROUP GIFT!** card with the Marble Kiln, no odds line | ✅ `captures/claim_card.jpg` |
| OPEN, tapped twice in 0.12 s → one opening ("THANKS FOR JOINING!"), one `[GroupReward] Claimed` | ✅ `captures/opening_reels.jpg`, `opening_reveal.jpg` (Glass Top, new) |
| After COLLECT → **Claimed**: prompt hidden, heart still, glow and sparkles off | ✅ |
| `Reset` → the real fresh check (`GetGroupsAsync`) finds the membership → Ready | ✅ |
| Dev "not a member" → **Join**: prompt "Join", soft glow (1.2) | ✅ |
| Non-member `Claim` sent from the client → refused, still Join, nothing granted | ✅ |
| Client reports `AlreadyMember` while the server says not a member → stays Join, `GroupRewardPrompted` logged | ✅ |
| Junk remote arguments (`"Prompt", 42`, `"Bogus"`) → ignored, no errors | ✅ |
| Override dropped (the join "lands") → server re-checks → Ready, prompt "Claim" | ✅ |
| No script errors from the new code | ✅ |

Notes:
- **E picks one prompt.** Standing between the stand and the Finishers machine with the camera on the Finishers, E
  opened the Finishers shop: Roblox shows one prompt per key and also weighs where the camera points. Facing the stand
  works. The prompts are 7.6 studs apart, like the Kilns' own.
- **The join modal itself can't be checked in Studio.** `PromptJoinAsync` was called (a second call said "Join prompt
  is already in progress"), but the modal didn't show in captures and the call never returned. The client's guard on it
  now expires after 30 s, so a prompt that never answers can't lock the stand. **Check once on a live server with an
  account that is not in the group:** join → the card should open within a few seconds.
- **Policy (Coin Kiln where paid random items are restricted)** is covered by the pure rule (`GroupRewardRules.kiln`,
  tested) and by reading the code. The Studio user is allowed, so Play always showed the Marble Kiln.
- The reel tiles were empty pictures while the opening spun (the icons were still loading right after joining). This
  is the same opening and icons as every Kiln pull; it isn't specific to this feature.
