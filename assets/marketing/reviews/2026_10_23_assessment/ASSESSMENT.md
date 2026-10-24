# Glass vs Glass — thumbnail and acquisition assessment
Checked 23 October 2026. This is an evidence review, not a claim that a creative will reach 4–5% CTR.

## What the latest results say

| Creative | Impressions | Clicks | Calculated CTR | Spend, ad credits |
|---|---:|---:|---:|---:|
| Perfect Release | 1,392 | 27 | 1.94% | 0.20 |
| You Win | 408 | 5 | 1.23% | 0.04 |
| Cast Now | 556 | 12 | 2.16% | 0.05 |
| Pick One, original | 1,135 | 20 | 1.76% | 0.11 |
| Bottle Smash | 3,058 | 53 | 1.73% | 0.43 |
| Jar Vs Sword | 769 | 11 | 1.43% | 0.10 |
| **Screenshot total** | **7,318** | **128** | **1.75%** | **0.93** |

Transcribed from the creator's supplied screenshot. All rows show Learning; Plays contains a dash, not an observed zero. This crop does not include every campaign or reserve creative.

Cast Now and Perfect Release lead by point estimate. They have only 12 and 27 clicks, respectively. Illustrative 95% Wilson intervals overlap: Cast 1.24–3.73%, Perfect 1.34–2.81%, Bottle Smash 1.33–2.26%. Allocation is not necessarily randomized, so these intervals are only a small-sample illustration, not a controlled causal test. Bottle Smash has the most clicks in this crop.

Early rankings changed: original Pick One went from 13/583 (2.23%) to 20/1,135 (1.76%); Bottle Smash from 8/657 (1.22%) to 53/3,058 (1.73%). Avoid declaring a winner after the first few hundred impressions. Compared with the earlier four-creatives Plays crop (226/21,639 = 1.04%), the new crop is encouraging descriptively, but dates/audiences differ and it does not establish a causal lift.

## The matched-date click/player figures

The creator confirmed **761 ad clicks and 212 ad-attributed unique players cover the same dates**.

- 3.59 clicks per distinct attributed player.
- Equivalently, 27.9 distinct attributed players per 100 recorded clicks.
- This is **not a measured 27.9% click-to-join conversion**: repeat clicks and deduplicated players have different denominators. It does not establish 72.1% abandonment.
- Total matching spend is not provided. Unique-player acquisition cost would be matching spend / 212. Do not divide this screenshot's 0.93 credits by 212; its 128 clicks are only a subset.
- Unique-player acquisition cost also differs from Ads Manager cost per play if plays include repeat sessions.

Official reporting notes say post-click metrics can take up to 48 hours. Let those populate before treating blanks as failures. [Roblox Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager)

## Important account constraint: currently 16+ only

Read-only Creator Dashboard inspection of universe 10770493435 showed:

- **“Glass vs Glass ⚔️ is available to players ages 16+!”**
- Under-16 access pending the 250 highly engaged player step.
- **8 as of Oct 23, 2026, 5:00 PM** in the dashboard.
- Other visible identity/security/content-rating steps complete.

The dashboard's tooltip defines highly engaged players using their broader history of Roblox play and purchases. **8 / 212 is not this game's retention or engagement rate.** The two figures use different criteria and may have different reporting freshness.

Current results have not tested under-16 response. This matters because the intended audience is mostly kids. It does not establish which eligible age groups received particular ads or explain every low CTR. No audience setting, payment, campaign or publishing action was performed.

Roblox's current threshold announcement confirms the 250-player entry threshold. [Official announcement](https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164/1)

Plays acquisition and access qualification are different goals. Official documentation says Engagement targets age-checked, highly engaged players who count toward Kids & Select, typically at higher cost per play. If qualification is the priority, measure qualifying progress separately rather than expecting every Plays-acquired user to count. No objective or budget changed. [Ads goals](https://create.roblox.com/docs/production/promotion/ads-manager)

## Is the game idea the problem?

**The available evidence neither rejects nor validates the product.** The closest mechanical reference, Ball VS Ball, had about 29,000 active players during this check. Its actual developer description offers fighter selection, automatic battles and collecting. That demonstrates demand for a related category, not demand for our exact execution or proof of any thumbnail's CTR. [Ball VS Ball](https://www.roblox.com/games/96510596525082/Ball-VS-Ball)

The dashboard's visible engagement summary used a small, older-looking 28-day dataset that could not be matched to the 212-player ad cohort. Do not report that summary as those players' retention. The Funnels page had no populated report in its selected window. The source already contains onboarding funnel events; an empty dashboard does not by itself establish broken instrumentation.

The useful next product evidence is new ad players reaching their first fight, finishing it, starting a second fight, and returning. Check those with matching dates once reporting is current. If many join but never reach the promised battle, the first-session path deserves attention; more thumbnail effects will not repair that.

## What the verified visual references show

[Open the reference board](REFERENCE_BOARD.html). Four images came from Roblox's public gallery thumbnail API, not YouTube search results. [Public metadata snapshot](PUBLIC_REFERENCE_DATA.json)

Observed composition:
1. Large red, frightened subject in a clamp; a smaller chained threat behind it.
2. Huge yellow grin on a purple backdrop; cyan portal is the secondary threat.
3. One framed choice/aiming diagram, with avatars pushed to the sides.
4. Large webbed yellow subject with a smaller red opponent behind.

These use size hierarchy, distinct silhouettes and an immediately legible threat or choice. Their live ad/Home use and private CTR are unknown. Popularity does not isolate image effectiveness, and competitor artwork must not be copied.

At 180px, our cyan/pink glass is pale against bright sky and warm wood. Cast Now communicates an action, but several arena frames compete with the subjects. Perfect Release makes a control understandable while shrinking the actual fight. Bottle Smash reads as a collision, but the material can resemble soft toys or plastic. These are visual hypotheses, not measured causes.

## Next creative briefs, in priority order

### 1. Cast Now — stronger contrast, same promise

Keep the current bottle/jar identities and genuine casting action so this tests presentation rather than a completely new fantasy. Crop closer, use a simpler darker blue background behind the glass, strengthen tinted rims/refraction, and retain one short CAST timing cue. One rope per fighter; one visible direction of attack. Remove distant arenas and decorative noise. Keep vivid cyan/pink separation without washing both subjects toward white.

Use the unchanged Cast Now as its comparator. Do not alter the name/objective at the same time and then credit the image for the difference.

### 2. Fragile glass — a clear moment of danger

One large intact original glassy faces one visibly cracked opponent immediately before impact. Show real glass thickness, a readable face and a few large shards; no white explosion covering the event. Matte simple arena, no logo or new progression claim. The hook is “which one survives?” expressed through the picture. Avoid depicting an automatic guaranteed one-hit win or invented player-controlled weapon.

This tests whether glass fragility provides a clearer distinctive reason to play than generic shiny creatures. The existing 1v1 Me reserve is another social challenger if not already tested; it is absent from this screenshot, so its performance is unknown.

## Comparison and limits

Keep one current baseline and track clicks, attributed plays, matching spend and new-user progression. Several reserve concepts can run; the creator explicitly wants multiple tests. Preserve the distinction between ad CTR and Home qPTR. No universal Roblox 4–5% CTR benchmark was found in the primary material reviewed, and that target is not a guarantee.

Keep Glass vs Glass ⚔️ stable during this comparison. No new image batch was produced in this assessment session: the deliverables are verified references, updated evidence and focused briefs. No game code, Studio content, account settings or ads were changed.
