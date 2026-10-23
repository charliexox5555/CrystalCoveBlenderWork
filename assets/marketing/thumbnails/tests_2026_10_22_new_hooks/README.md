# Glass Clash — three new thumbnail hooks

Created 22 October 2026, after the creator reported weak early ads with 1.5 credits spent. A subsequent screenshot supplies early asset-level impressions/CTR: see [EARLY_AD_RESULTS.md](EARLY_AD_RESULTS.md). The Unicorn shatter leads at 2.3% from 663 impressions; the ranking remains provisional. This batch is a set of creative hypotheses, not a measured explanation of the previous results.

## Finished artwork

| File | Hook | Why test it |
| --- | --- | --- |
| [01 Incoming Blade](01_incoming_blade.png) | An amber Honey Bear and an approaching Prism Blade, just before contact | Recommended first test: a large face, two contrasting silhouettes and an immediate threat |
| [02 Pull to Smash](02_pull_to_smash.png) | Saved bacon avatars, actual wooden arena, one swing arrow | Makes the pull/release mechanic legible; tests a clean playable-looking composition |
| [03 Lucky Kiln Pull](03_lucky_kiln_pull.png) | Original Glass Dragon revealed over the real Kiln tray, bacon avatar reaction | Tests collecting/discovery interest against the two combat hooks |

All are native **1672 × 941 opaque RGB PNGs**, approximately 16:9, under 3 MB. The requested ideal was 1920 × 1080; the built-in tool returned these native dimensions. No code-based resizing, cropping, compositing or enhancement was used. All three requested deliverables are saved here; older art remains unchanged.

Built-in imagegen with reference-guided generation. Exact prompts, input order and reference roles: [PROMPTS.md](PROMPTS.md). These are generated interpretations of the supplied original assets, not direct Blender renders or untouched in-game screenshots. No Studio instances were connected at the time, so existing Studio captures and native asset renders supplied the references.

## Reasoning and research

Working hypothesis: earlier thumbnails may have given the wordmark, landscape and shatter effects more attention than the game action. That is a visual assessment, not a causal conclusion from the available ad data. The supplied Blade Ball examples show different readable stories: imminent threat, a strong character focal point, and an understandable move. Borrowed those composition principles, while keeping Glass Clash subjects and mechanics. No Blade Ball props, logos, chains, pumpkin or characters appear in the final images; competitor reference files are not redistributed in this batch.

Primary sources checked on 22 October 2026:

- [Roblox thumbnail guidance](https://create.roblox.com/docs/production/publishing/thumbnails): relevant imagery, clear theme/color, landscape 16:9 ideally 1920 × 1080; important content should avoid the bottom edge because metadata can cover it. This informed the large subjects, quieter backgrounds and placement. Removing the logo is a creative hypothesis, not a proven platform rule.
- [Roblox advertising examples](https://create.roblox.com/docs/production/promotion/advertise): the Hypershot case discusses testing different visual concepts to find effective creatives. It does not establish a universal winning style or a CTR benchmark for Glass Clash.
- [Ads Manager reporting](https://create.roblox.com/docs/production/promotion/ads-manager): first 24 hours are marked Learning; impressions/clicks report in real time, whereas attributed plays/earnings can take up to 48 hours to appear. Campaign details include asset-level breakdowns.
- [Discovery FAQ](https://create.roblox.com/docs/discovery-faq): sponsored delivery and Recommended for You ranking are separate. Keep ad CTR, ad plays and organic Home qPTR separate when assessing these tests.

## Testing next

Revised after the screenshot: keep the existing Unicorn shatter as the control, and prioritize Incoming Blade and Lucky Kiln Pull. Pull to Smash is now a lower-priority mechanics/avatars test. Keep the same objective and comparable audience, dates and placements. Inspect actual per-asset exposure rather than assuming the observed samples are equal.

Record each asset's impressions, clicks, CTR, plays, plays/impression, cost/play and subsequent playtime over the same reporting window. CTR = clicks / impressions × 100; it is not Home qualified play-through rate. Spend alone does not tell us the statistical sample size. Avoid a fixed credit/time cutoff or a promised CTR target; inspect the actual counts and uncertainty. A click increase with poorer joining/engagement should not be treated as an overall win.

No campaign, spend, upload or Home-thumbnail settings were changed.

## QA

- Full-size review: original amber Honey Bear cap/bow/face, cyan Prism Blade crossguard/gems, green Dragon silhouette, actual Kiln dome/arch/tray.
- Incoming Blade has two connected suspension strings, a clear pre-contact gap and restrained surface cracking. No invented chains or hand-held weapon.
- Pull to Smash has two suspended glassies, one illustrated aiming path and a flat pointer. The arrow/cursor is an explanatory graphic, not an asserted screenshot of the live UI.
- Bacon avatars use two properly connected cuboid arms and plain block ends, with no separate fingers or malformed C-grips. Kiln scene is a collecting reveal, not combat.
- Reviewed browser previews at 320 × 180 and approximately 180 × 101. Main subjects and arrows remain recognizable at small size. Peripheral floor, feet and podium edges can sit in the bottom metadata area; the key faces/actions are higher.
- PNG decode/dimensions/file sizes pass. Project checks: Lune **270 passed, 0 failed**.
- [PREVIEW.html](PREVIEW.html) repeats the display check using browser scaling without changing the PNG files.

## Provenance

Built-in outputs copied intact from the current generated-images session:

| Final | Generated source | Bytes | SHA-256 |
| --- | --- | --- | --- |
| 01 | exec-76bd736e-7f2c-4abf-a194-c27e21b58af3.png | 1,784,225 | 5A5593350037DAA037723E786AE8A36307DCD235B00E847BB90439FDB5E98B61 |
| 02 | exec-8f9797fd-d410-4b39-ab70-5b96be1d41bf.png | 1,818,175 | D20D4D59ECE964F4E4C8B73B6A17FCD11F41342766B9D0C5DE0D3FA01B6F0EB0 |
| 03 | exec-00a74db6-a271-4a07-afe8-549d23eddf99.png | 1,768,089 | 87F19E661A7514AD5D423A7D92BD486B26078B2D1A85B902D4BD5058D6F3E50A |
