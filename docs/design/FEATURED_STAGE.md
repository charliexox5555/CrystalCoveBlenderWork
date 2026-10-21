# Featured Stage: options (brainstorm, not built)

**Creator pick (Oct 20): Crown Hill**, with coins that trickle in while you hold the crown. It must stay a fun
add-on that never out-earns normal play or spoils other players' matches. See
[Crown Hill: full design](#crown-hill-full-design-creator-pick) at the end.

**Built (Oct 21, decision 105).** Code map:
- **Rules and numbers:** pure `src/shared/HillRules.luau` and `src/shared/Config/Hill.luau`, Lune-tested in
  `src/tests/HillTests.luau`.
- **Server:** `src/server/Services/HillService.luau` (line, King, crown, coins, board), with small hooks in
  ArenaService (the featured arena's queue, prompts, pads and board), MatchService (`StartMatch` options and the hill
  branch in `Finish`), MatchLogic (per-side `Hearts`) and ArenaBoard (crown, prize chip).
- **Client:** `src/client/Controllers/HillController.luau` (line chip, "+1" crown coins, crown burst).
- **Economy check:** `src/tests/HillEconomySim.luau`, printed by `lune run tools/economy_sim`.

Written Oct 20, 2026. The featured island at the end of the lobby (Arena 7, board text "FEATURED ARENA") runs the same
matches as every other arena. GAME_DESIGN 5 once planned to show the highest-trophy fights on a big board there. This
doc lists ways to make it special. **Nothing is built until the creator picks.**

## Facts that shape the choice

- **A normal match is long:** about 5.7 minutes (about 4 rounds of about 80 s; 3 hearts each). Any "winner stays on"
  idea with full matches leaves a queue of 3 kids waiting 15+ minutes. Featured fights need a **shorter format**.
- **Servers will often be quiet at launch.** A mode that needs 3+ real players at once will usually sit empty. Bots
  already fill a pad after 15 s (`QueueBotAfterSeconds`), so every idea below keeps a bot ready.
- **What we can reuse:**
  - `MatchService:StartMatch(arena, players, ...)` already takes any mix of players and bots.
  - The `Runner` already accepts per-match options (the tutorial uses one for a longer pick timer). Adding `Hearts = 1`
    the same way is small.
  - Bot skill and bot collections are already configurable per side.
  - Spectating (`Spectate` flag, the Watch prompt) already exists, and the viewing fixes in this patch make it last a
    whole match.
- **Rules that apply to every option:**
  - Coins and Robux are never wagered.
  - No chat or voting that names or targets a player.
  - Odds are shown before any random reward.

---

## 1. Crown Hill (King of the Hill)

**What a kid sees and does:**
- The featured stand has a golden crown pad (the King) and a challenger pad.
- Step on the challenger pad. When it's your turn, you fight the King in **one sudden-death round** (1 heart each,
  about 80 s).
- Win and you are the new King: a floating crown sits over your head, and your name and streak light up the big board.
- Lose and you walk off. The next challenger steps up.
- If nobody is on the hill, a **Crown Bot** holds it, so it's never empty. A lone kid can always challenge the bot.

**Why they'd come back:**
- Being King is visible to the whole server: the crown is shown in the lobby while you reign.
- "Beat my streak" gives kids a reason to bring friends.
- Short rounds mean a quick turn even with a line.

**Rewards (no wagering):**
- Small coins per defence (for example 15), plus a one-time **"Crowned!"** bonus the first time each day.
- **Reign cap: 5 defences.** Then the King "retires undefeated" with a bigger bonus and a free crate ticket (odds
  shown in the Shop as usual), and the hill resets to the Crown Bot. This stops one strong player camping on the hill
  and moves the crown around.
- Coins from beating the Crown Bot are capped per day, so kids can't farm it.
- Hill fights don't change Trophies, so there's no trophy farming against the bot.
- A "Best Reign" stat that can go on the new profile page.

**Build cost: medium, about 3–4 days.**
- ArenaService: an Arena 7 queue mode where the winner stays on their pad and the next queued player is pulled in.
- `Runner` option `Hearts = 1`, and skip the results screen between hill fights.
- Crown Bot = the existing bot with a fixed name and a slightly higher skill.
- Big board: a SurfaceGui with the King, the streak and the line.
- A crown accessory over the King's head.
- Pure `HillRules` (turn order, reign cap, payouts) with Lune tests.

**Risks:**
- **Waits:** mitigated by 1-round fights and the reign cap.
- **Camping:** the reign cap.
- **Win-trading between friends:** the per-day coin cap.
- **Hurt feelings when knocked off:** losing costs nothing; you just walk back into the line.
- **Griefing the shot:** the hide-others fix from this patch covers people walking in.
- **Rarity edge (about 55%):** fine for one round, and luck keeps it open.

## 2. Champion's Stage

**What a kid sees and does:**
- The highest-trophy player in the server is the **Champion**, shown on a statue or board on the featured island.
- Anyone can step on the challenge pad to call the Champion for a full match.

**Why they'd come back:** status, and climbing trophies to become the Champion.

**Rewards:** normal match rewards plus a small "beat the Champion" bonus.

**Build cost: small to medium, 2–3 days.** A server-wide trophy lookup, a board, a challenge request and an
accept/decline prompt for the Champion.

**Risks (big):**
- The Champion may be AFK, busy or in another match, so challengers wait for nothing.
- The Champion gets pestered all day.
- In a server of beginners, the "Champion" has 40 trophies and it means little.
- Needs an accept/decline flow, which is a new kind of social pressure for young kids.

**Not recommended for launch.**

## 3. Big Screen Stage (the best fight in the server)

**What a kid sees and does:**
- Arena 7 runs normal matches. A giant screen on the featured island (and a small one by spawn) always shows **the
  most exciting fight in the server right now**: match point, a Legendary or Mythic glassy, a long streak.
- Tap **Watch** on the screen to jump the camera to that fight.
- Free emoji **cheers** pop over the fight while you watch.

**Why they'd come back:** seeing rare glassies in action makes kids want them (good for the Kiln). It's also something to
do while waiting.

**Rewards:** none, or a tiny once-a-day "Watched a match point" coin bonus. Watching never pays per minute (no AFK
farming).

**Build cost: high, about 4–6 days.**
- Picking the "best fight" server-side is easy (match state is all in MatchService).
- Drawing a live 3D fight on a screen is the hard part. ViewportFrames would have to copy the fight scene every frame,
  which is expensive on phones. The cheap version is a scoreboard-style screen (names, glassy icons, hearts) plus the
  Watch button that uses the camera view we already have.

**Risks:**
- Empty servers have nothing to show (fall back to a bot vs bot exhibition).
- Cheers could be spammed (rate limit them, emoji only, no text).

**Best as an add-on** to option 1 or 4, not on its own.

## 4. Boss of the Day (rotating event)

**What a kid sees and does:**
- The featured arena holds a **giant Boss glassy** (a big, glowing version of a roster glassy) that changes every day.
- Step on the pad to fight it. It's still a normal 1v1 swing, but the Boss is bigger, has more HP and has a boss power
  colour. You get 3 hearts, and it has more.
- Beat it once a day for a prize.
- Weekends could swap in an event, for example **Bracket Hour** (a 4-player bracket every 30 minutes, bots fill the
  empty seats) or **Double Coins**.

**Why they'd come back:**
- A new Boss every day, and a clear daily goal.
- It works with one player in the server.
- Friends can watch each other try.

**Rewards:**
- The first Boss win each day gives a Boss Chest: coins, sometimes a free crate ticket (odds shown in the Shop).
- A "Bosses beaten" stat and, later, a level reward on the profile.
- Losing costs nothing, and you can retry as often as you like.

**Build cost: medium, about 3–5 days.**
- Bot side with a scaled setup: a bigger model and more HP through FightRules setup, with balance numbers in
  `Balance.Boss`.
- A daily rotation (like the daily store's seeded rotation).
- Boss presentation: scale, glow, a health bar on the board.
- Needs balance-sim runs, so the Boss is beatable by a kid with Commons about 30–40% of the time.

**Risks:**
- Balance (too hard means frustration; too easy means it's boring). Tune with the sim.
- A big model may clip the stand (check scale).
- Bracket Hour needs players present at a set time, which is weak on quiet servers. Keep it a later add-on.

## 5. Featured Matchup of the Day

**What a kid sees and does:**
- Today, the featured arena gives **both players the same special glassies**, for example "Unicorn Day: everyone
  fights with the Glass Unicorn", or a fixed 3-glassy hand of Legendaries.
- You try glassies you don't own yet, on an even field.

**Why they'd come back:**
- A new matchup every day, and the chance to try Legendaries for free.
- It's fair: same glassies on both sides, so new kids can beat veterans.

**Rewards:** normal match coins, plus a once-a-day "Featured win" bonus. The glassies are **loaned for the match only**
(like `Glassies.Fallback`), never granted.

**Build cost: small, about 1–2 days.**
- Override the collection for both sides in `StartMatch` with a daily seeded hand.
- A board showing today's glassies.
- Everything else (match, bots, rewards) is unchanged.

**Risks:**
- Low; it's still a normal match.
- Could make kids feel they "lose" the Legendary afterwards. Mitigate with a soft "Find it in the Kiln" icon (no
  pressure text, and no paid prompt on that screen).

---

## Recommendation

**Build Crown Hill (option 1), and use the Featured Matchup (option 5) as its daily twist.**

- **It answers the creator's instinct.** King of the Hill is the most obvious "special" thing a kid can see from across
  the lobby: a crown, a streak, a line of challengers.
- **It works in a quiet server** because the Crown Bot holds the hill when no one else is there.
- **The two big problems with a classic KotH are fixed by the rules:**
  - Waits: one-heart sudden-death rounds.
  - Camping: the 5-defence reign cap with a "retired undefeated" bonus.
- **It reuses what exists:** the match flow, bots, viewing and the hide-others fix.
- **New code is small and testable:** a queue mode, a `Hearts` runner option, the board, the crown, and a pure
  `HillRules`.
- **Adding option 5 later is cheap** (about a day): hill fights could use "today's featured glassies" on both sides,
  so the hill stays fair for new players and shows off Legendaries.
- **Later, if the game grows:** Boss of the Day (option 4) for weekends or events, and a Big Screen (option 3) for busy
  servers.

**Questions for the creator before building:**
1. Crown Hill, or a different option?
2. Should hill fights be **one sudden-death round**, or best of 3 hearts (longer waits)?
3. Reign cap of **5 defences**: OK, or a different number?
4. Should the crown show over the King's head everywhere in the lobby, or only on the featured island?

---

## Crown Hill: full design (creator pick)

The creator chose Crown Hill and asked for coins while you hold the crown, balanced so it stays an add-on: fun, worth
a visit, and never better than playing normal matches.

### The loop

1. **The hill is never empty.** When nobody holds it, the **Crown Bot** is King.
2. **Join the line** by stepping on the challenger pad. You get a spot in the line, shown as a number on the board,
   and can walk around the island while you wait.
3. **Your turn:** one **sudden-death round** against the King (1 heart each). It uses the normal roll / pick / aim /
   swing, so all powers, finishers and flyers work as usual.
4. **Win and you're King:**
   - A gold crown floats over your head.
   - Your name, avatar and streak go up on the big board.
   - A crown burst plays and the whole island hears a fanfare.
5. **As King, you keep defending.** The next person in line steps up. If the line is empty for 10 s, the Crown Bot
   challenges you, so the King is **always playing, never idle**.
6. **Reign cap: 5 defences.** After the 5th, you **retire undefeated**: a big crown shower, a bonus, and the hill goes
   back to the Crown Bot.
7. **Lose and you go back to the lobby, or join the end of the line.** Losing costs nothing.

### Crown coins: balanced against normal play

Normal play earns about **800 coins an hour** (about **13 a minute**: 100 per match win, 8–40 per loss, 5.7-minute
matches). The rule for Crown Hill is that **a King earns about the same per minute as a player winning normal matches
(about 15–18 a minute), never much more**, and a **daily cap** stops it from replacing normal play.

| What | Coins | Notes |
|---|---|---|
| **Crown trickle** | **+1 every 5 s** while you are King **and a hill fight is running** | About 12 a minute. A "+1" coin pops over your crown. No ticks while idle, walking away or between fights, so there's no AFK farming. |
| Take the crown | 25 | Beating the King, or the Crown Bot. |
| Each defence won | 15 | |
| Retire undefeated (5 defences) | 100 | Plus one free Coin crate ticket, **once per day** (odds shown in the Shop as usual). |
| Losing a hill fight | 5 | Just a thank-you for playing. |
| **Daily cap on all Crown Hill coins** | **500** | About 40 minutes of normal play. After the cap you can still play, wear the crown and grow your streak; the coin pops just stop (the crown keeps its sparkle). The board shows a small coin meter, not text. |

**What this works out to (one round is about 100 s including picks):**

| | Coins | Time | Per minute |
|---|---|---|---|
| A full 5-defence reign | about 25 + 5×15 + about 100 trickle + 100 = **300** | about 9 minutes | about **33** |
| The same 9 minutes of normal play | about **120** | | about 13 |
| A typical King (holds 1–2 defences) | about 75–100 | about 3–4 minutes | about **25** |
| A challenger who loses | 5 | about 2 minutes | about **2.5** |

- A great reign is a **treat** (about 2× normal for a few minutes).
- Most visits are about even with normal play, and losing pays less than a normal loss.
- So kids who only want coins still do best playing normal matches.
- With the 500 daily cap the hill adds at most about **35%** to a 40-minute day of normal play (about 530 coins).
- Run `tools/economy_sim` with a "visits the hill once a day" case before shipping, and keep "first Legendary" within
  10% of today's 10.4 h.

### Keeping it fair and kind

- **Doesn't touch the main game:**
  - Hill fights don't change **Trophies**, the **Wins** leaderboard, Win Rate or Best Streak. Those stay normal-match
    stats.
  - The hill has its own stats: **Crowns taken** and **Best Reign**, ready for the profile page.
  - Quests and level XP count a hill fight as half a match at most (set when the profile/levels work lands).
- **Everyone gets a turn:**
  - First come, first served.
  - One line spot per player.
  - The reign cap stops camping.
  - A King who loses goes to the back like everyone else.
- **No farming:**
  - Coins only tick during real fights.
  - Daily cap.
  - Crate ticket once per day.
  - Win-trading between friends hits the same cap.
- **AFK King:** if the King doesn't aim in two fights in a row (the swing auto-releases), they step down and the crown
  passes on.
- **Walking away:** the King must stay on the featured island. Leaving the island or the server hands the crown to the
  next in line, or to the Crown Bot. Coins already earned are kept.
- **Nobody spoils the shot:** this patch's hide-others fix keeps passers-by out of the King's and the challenger's view.
- **Kind losing:** no "dethroned" text or sad sounds aimed at the loser. The camera celebrates the new King, and the
  old King gets a small "Best Reign" medal if they set a personal best.
- **Bots:** the Crown Bot is clearly a bot (BOT tag, name ends in "Bot") with medium skill (about 0.5), so a kid with
  Commons beats it about half the time. It never earns or keeps coins.
- **Rarity:** still the normal ≈ 55% edge. One-round fights keep luck in play, so Legendaries don't own the hill.

### Build plan (when approved)

- **Pure `HillRules`** + Lune tests: line order, turn hand-off, reign cap, AFK step-down, coin trickle, daily cap,
  stats.
- **`Balance.Hill`:** all the numbers above.
- **ArenaService:** a Crown Hill mode for the featured stand (King pad + challenger line), with the Crown Bot when empty.
- **MatchService / Runner:** a `Hearts = 1` option and hill rewards through `HillRules`. The results screen is skipped
  between hill fights (just the crown moment).
- **Profile fields** (reconcile migration): `Hill = { Crowns, BestReign, Day, CoinsToday, TicketDay }`.
- **Client:** crown accessory over the King, "+1" coin pops, the big board (King, streak, line, coin meter), and the
  crown burst and fanfare.
- **Checks:** a 3-player Studio test with the multiplayer harness, and the economy sim with a hill case.
- **Estimate:** about 3–4 days.
- **Start after the levels/profile work lands,** since both touch MatchService rewards and the profile.

### Defaults chosen (change any of them)

- Sudden-death **one-round** fights.
- **5-defence** reign cap.
- The crown shows only while you're on the featured island, because the King has to stay there.
