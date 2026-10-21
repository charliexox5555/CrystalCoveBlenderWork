# Featured Stage: options (brainstorm, not built)

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
