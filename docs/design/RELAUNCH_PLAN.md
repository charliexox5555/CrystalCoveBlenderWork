# Glass vs Glass: making the core better

**Current direction (decision 133).** The core format stays: lobby, arena pads, pick from your hand, aim, automatic powers, hearts, Kiln spin. The job is execution, mostly abilities.

The earlier shards and Gauntlet proposal and the dark Kiln Room stage were rejected by the creator on 2026-11-02. That code is in git history at commit `6d83939`.

## Why abilities first

Ball VS Ball has the same format, so format isn't what separates the two games. The current kits were designed to be modest. The roster brief says things like "modest width" and "never becomes a real constraint", and in practice most kits are a damage bonus or a small slow. Pop's old power was +76% on every third hit, which is hard to even notice.

A concept ability follows three rules:

1. **You can see it building.** The glass or the arena shows it before it fires.
2. **It escalates.** The later in the round, the bigger it gets, so fights rise instead of plateauing.
3. **It changes the fight.** It moves glass, floods the pen or fills the screen. Damage is the smallest part.

## The first six

| Glassy | Ability | Builds up | Payoff | Escalation |
|---|---|---|---|---|
| Pop | Cap Blast | Bottle shakes harder with each clash | Cap rockets at the rival, fizz jet shoves Pop | Fuse shortens: 6, 5, 5, 4 clashes |
| Jam | Sticky Trap | Blobs of jam stick to the rival | Three blobs glue them together with a strand for 3 s | Rival gets heavier with each blob |
| Prism | Split Light | Charge glow before each shot | Rainbow rays across the arena | Rays per shot: 1, 2, 3, 5, 8 |
| Cup | Spin Cycle | Every swing winds it up, trail grows | Reaches TOP SPEED | Never loses speed during a round |
| Jug | Rising Tide | Each clash raises real water in the pen | A wave sweeps across; a glass swung high rides over it | Water slows what it touches |
| Ketchup | Big Squeeze | Splats stick to the rival | Six splats go SPLAT, with a shove | Squeezes grow: 3, 4, 5, 6 drops |

## The second six

| Glassy | Ability | Builds up | Payoff | Escalation |
|---|---|---|---|---|
| Milk | Top Up | Foam burst when it pours | Refills its own glass, so its liquid visibly rises | Pours grow, and stop at overtime so rounds still end |
| Pickle | Pickle Drop | Pickles appear at the crossbar | Fall on the rival; a glass can swing clear | Drops grow: 2, 3, 4, 5, 6 |
| Lemonade | Zest Ring | Slices appear in orbit | Slices cut the rival when they pass | One more slice every 6 s, up to 5 |
| Mason | Firefly Swarm | Each clash frees fireflies | They chase the rival and sting | 1, then 2, then 3 per clash |
| Tumbler | Ice Field | Clashes leave cubes in the air | Swinging into one hurts and chills | Up to 6 cubes hang at once |
| Hot Sauce | Hot Streak | Aura grows every 4 s | Burns the rival when it is close | Bigger and hotter, to MAX HEAT |

## Next

1. Creator plays these in real matches and says which feel right. Numbers and looks are first passes.
2. Convert the next wave of glassies once these twelve feel right. 28 remain, starting with Cookie Jar, Fishbowl, Bubble Wand, Glass Top, Chime and Piggy Bank. Each needs a concept that passes the three rules, then the v5 model treatment so the roster matches.
3. Check on phones and with unfamiliar players, then publish when the creator chooses.
4. Kiln spin polish, return hooks and monetization come after fights hold attention.

Evidence: [testing/relaunch/REPORT.md](../testing/relaunch/REPORT.md).
