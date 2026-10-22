# Power check: "the Unicorn's power did nothing"

Creator, playtesting (2026-10-22): "The unicorn glass, power did not seem to do anything. It fired and you saw the
VFX but no damage was done to the other glass or anything (not sure what the power does though so I could be
wrong)."

**Verdict: the power works as designed but reads as "nothing happened" (case 3).** No rules or numbers changed.
The fix makes the result visible: a coloured, bigger number on a powered hit, a "GUARD BROKEN!" call, and a
fizzle-and-shrug beat when the dash misses.

## What the Glass Unicorn's power does (Rainbow Charge)

- **Charges:** every 2 swing turnarounds, then it is **Ready** (tap CAST, or it fires by itself after 1.6 s).
- **Cast:** a 0.35 s windup, then a **2 s boost**. The unicorn dashes toward the foe (`AimImpulse` 2.0, aimed at
  the foe's centre) and swings 12% higher (`Drive` 1.12).
- **Payoff:** the **next clash inside those 2 s** deals **+62% damage** (`ContactBonus` 0.62), knocks the foe back
  15% harder, and **breaks through a guard** (Jam, Grizzly, Glass Duck: full damage instead of reduced).
- **No clash in 2 s:** the boost runs out and nothing else happens. It does no damage by itself.

In plain words: *the Unicorn doesn't shoot anything. It charges at the other glass, and if they bump within 2
seconds, that bump hits much harder and smashes through shields.*

Code: `Balance.CombatRelease.Kits.glass_unicorn`, `SignatureTraits.selfRelease` (boost) and
`Traits.beforeContact` (payoff), `SignatureRules.mitigate` (pierce), `Pendulum.integrate` (aimed impulse).

## What happens on the real swing

`lune run tools/power_check 30 glass_unicorn` plus a one-off Unicorn trace (25 rounds per cast style). Both run the server's own
`Pendulum` + `FightRules`, which is the code Studio's FightService runs: 25–30 rounds per cast style, equal stats,
against a rotating field of foes using bot casting.

| Cast style | Dashes | No clash in 2 s ("dud") | Clash lands after | Powered clash | Ordinary clash | Powered clash still below an ordinary one |
|---|---|---|---|---|---|---|
| auto (never taps CAST) | 89–109 | **34–36%** | 1.0–1.3 s | 12.3 dmg @ 21.2 studs/s | 7.6 @ 21.6 | 25% |
| smart (taps as the foe swings in) | 102–122 | **14–16%** | 0.7–1.0 s | 11.5 @ 22.3 | 8.0 @ 21.3 | 30% |
| mash (taps the moment it's Ready) | 109–133 | **36–37%** | 1.1–1.5 s | 11.9 @ 21.3 | 7.7 @ 21.4 | 27% |

What a player sees:

1. **About 1 in 3 auto dashes meets no clash.** The rainbow trail and glow play, then the glow fades and nothing
   happens. Before this fix there was no miss beat for boosts, unlike ranged powers.
2. **When it lands, the extra damage is real (+62%), but it looks like any other bump.** The clash number was the
   same plain white "−12" as every clash. Speed-based damage also varies a lot (0.6–1.4× roll, speed^1.4), so
   about a quarter of powered clashes still deal less than an average ordinary clash. Nothing marked the hit as
   the power's.
3. **Pierce is rare** (1–6 per 25 rounds), because it only shows against guard kits with a guard up, and there was
   no text for it.

So "no damage was done" is what the screen said, even when the rules applied +62%.

## Fix (presentation, plus one rules event that changes no numbers)

- **Miss beat.** The rules now emit `SignatureStatus Kind="BoostFade"` when a boost runs out with no clash
  (`SignatureTraits.tick`; a `ContinuousBonus` boost that landed at least once does not fade). The client stops
  the dash trail and aura, plays the existing fizzle (a shrinking ring and falling chips, `States.disarm`), and
  plays the power-miss shrug and soft whoosh (`CombatFeel:PowerMiss`). This is picture-only, with no text. It also
  applies to Glass Cup, Rocket Pop and Hot Sauce. `ArmedFade` (armed hits that time out) now gets the same shrug.
- **Hit beat.** When a power pays off on a clash (boosts and armed hits such as Pop, Pickle Jar, Light Bulb and
  Mason Jar), that clash's damage number on the struck glassy is **in the power's colour and 1.35× bigger**
  (`AbilityNumbers.clash`, `FightHud:Popup` scale). The "RAINBOW CHARGE!" call over the caster was already there.
- **Pierce call.** A pierced guard now shows **"GUARD BROKEN!"** over the guard owner, next to the existing
  guard-shatter burst.
- Test: `LaunchKitTests` "Glass Unicorn's dash pays +ContactBonus on the next clash, or fades with a BoostFade".

Is it too weak? See the matrix below. The numbers stay as they are unless the equal-stat rate is outside
45–55% (decision 86).

Release matrix, Glass Unicorn vs all 39 other kits, equal stats, 624 rounds (±4%):

| Mode | Unicorn wins | Worst / best matchup |
|---|---|---|
| `equal:bot0.5` (the standard check, BALANCE_RELEASE.md) | **46.8%**, inside 45–55% | Mason Jar 19% / Comet 81% |
| `equal:auto` (nobody taps CAST) | 43.9%, a little low | Mason Jar 12% / Comet 88% |

So the Unicorn is **not** genuinely too weak: it is in the band, at the low end. The numbers stay. If the creator wants
it a bit stronger later, the gentlest lever is `Duration` 2.0 → 2.5 (the same window as Glass Cup and Rocket Pop),
which cuts the auto whiffs. Another option is a floor on a powered clash, so a soft bump is never a "−2". Both are
balance changes, so they are left for the creator.

## Studio Play check (2026-10-22)

- Server, synced code, 4 rounds per cast style vs Jam / Grizzly: auto 12 boosts → 10 payoffs + 2 `BoostFade`, 2
  pierces. Smart 12 → 11 + 1, 2 pierces. Every dash ends in exactly one of the two. Some auto payoffs were 1.9 and
  2.3 damage: a slow bump times 1.62 is still tiny, and that is what the creator saw.
- Client, spectated `FightDev` BotVsBot Unicorn vs Grizzly. Powered clashes showed "RAINBOW CHARGE!" plus the
  struck glassy's number in #FF7AD9 at text size 37 (ordinary clashes white, 28). Unicorn vs Jam:
  `FeelPowerMiss` = 1 from a faded dash, `FeelPowerLand` = 2. No errors or warnings from the fight code in Output.

## Sweep: every power, how often it does nothing

Same tool, all 40 kits, 30 rounds per cast style. "Dud" = casts with **no measurable effect** before the cast's
window closed: no damage landed, no payoff clash, no block, no heal, no pierce, slow, mark or drain. Flag: **>40%**
in auto or smart.

### Offenders (>40%)

| Power | Shape | auto dud | smart dud | mash dud | per landed cast | Has a miss beat already? |
|---|---|---|---|---|---|---|
| Crescent Axe | sweep | **75.5%** | **68.6%** | 67.8% | 17.7 dmg | yes (ranged miss) |
| Glass Top | sweep | **74.4%** | **75.6%** | 84.9% | 15.5 | yes |
| Fishbowl | projectile (return) | **79.8%** | **45.3%** | 96.9% | 10.0 | yes |
| Piggy Bank | volley | **78.3%** | **61.8%** | 60.8% | 10.8 | yes |
| Cookie Jar | volley | **76.2%** | **54.9%** | 65.1% | 10.2 | yes |
| Whiskers (daily) | projectile (return) | **76.0%** | **75.0%** | 80.2% | 18.8 | yes |
| Sunny Rooster (starter pack) | volley | **65.0%** | **76.4%** | 77.8% | 21.4 | yes |
| Chime | pulse | **66.7%** | **62.5%** | 65.2% | 9.6 | yes |
| Prism Blade | projectile (return) | **66.4%** | **48.0%** | 50.3% | 5.8 | yes |
| Comet | echo shot | **64.3%** | **48.5%** | 63.1% | 9.5 | yes |
| Galaxy Orb | orbit | **42.3%** | **66.7%** | 54.2% | 13.8 | yes |
| Lemonade Bottle | volley | **56.4%** | **61.3%** | 62.9% | 9.9 | yes |
| Prism | ray | **61.3%** | 21.7% | 67.4% | 8.8 | yes |
| Midnight Moon (daily) | pulse | **60.4%** | 38.1% | 42.4% | 15.4 | yes |
| Water Jug | cone | **56.3%** | 10.5% | 49.1% | 8.7 | yes |
| Crystal Tumbler | mirror | **55.4%** | **54.8%** | 53.1% | 11.6 (counter clash) | partly (mirror just ends) |
| Honey Bear | zone | **51.5%** | 7.5% | 42.1% | 5.5 | yes (zone ends) |
| Frostglobe | cone | **51.4%** | 30.3% | 58.0% | 9.7 | yes |
| Glass Dragon | breath | **50.0%** | 26.4% | 51.1% | 7.4 | yes |
| Glass Phoenix | projectile | **48.6%** | **47.7%** | 47.4% | 6.2 | yes |
| Bubble Wand | zone | **47.4%** | 27.8% | 53.6% | 8.8 | yes (zone ends) |
| Hot Sauce | boost | 10.7% | **40.7%** | 40.7% | 13.6 (powered clash) | now yes (BoostFade) |

Close to the line: Rocket Pop 39.1% auto / 26.5% smart (boost, now with BoostFade), Grizzly Guardian 37% (a
guard that blocks nothing), Glass Unicorn 36% / 16%.

Fine (<30% in auto and smart): Pop, Jam, Pickle Jar, Ketchup, Glass Cup, Mason Jar, Briar Flask, Light Bulb,
Potion Flask, Milk Bottle, Hourglass, Glass Duck, Crystal Ball, Arc Coil, Hollowlight.

### Reading the sweep

- **The ranged kits miss more than designed.** ROSTER_V2 tunes ranged kits on `LandChance` 0.55–0.65 (35–45%
  misses). On the real swing, Crescent Axe, Glass Top, Fishbowl, Piggy Bank, Cookie Jar, Whiskers, Sunny and
  Chime land a third of the time or less. They keep their equal-stat win rates because each landed cast hits hard
  (15–21 for the sweeps and Whiskers/Sunny). So win rates hide how often the power visibly whiffs.
- **These are not silent duds like the Unicorn was.** Every ranged miss already has a beat: the shot visibly
  flies past (`Kits.*.Miss`, `CombatFeel:PowerMiss`). The issue is frequency, a kid seeing their power miss 2 or 3
  times out of 4, not invisibility.
- **Tapping helps most kits a lot** (Prism 61→22%, Water Jug 56→11%, Honey Bear 52→8%), as decision 85 intends.
  It doesn't help the sweeps (Crescent Axe, Glass Top), Chime, Lemonade or Sunny/Whiskers: their reach is short or
  their timing is fixed, so no tap makes them land.
- Caveats: Crystal Tumbler's counter is counted as its own cast, so it is double-counted. Galaxy Orb's orbit
  counts only damage. Hot Sauce's smart number is from 59 casts.

### Recommendation (not done here: it is a balance change right before release)

Raise the landing rate of the worst eight (Crescent Axe, Glass Top, Fishbowl, Piggy Bank, Cookie Jar, Whiskers,
Sunny Rooster, Chime) toward the designed 55–65%: larger `Radius`/`Range` or `Arc`, or aim assist on the
volley/projectile path, with damage per landed cast lowered to keep equal-stat 45–55% (decision 86). Re-run
`tools/power_check` and the release matrix after.

## How to re-run

```
~/.rokit/bin/lune run tools/power_check 30                 # all kits (~45 min on one core)
~/.rokit/bin/lune run tools/power_check 30 glass_unicorn   # one kit
```

For the full sweep, split the id list across cores, as `tools/release_matrix.sh` does.
