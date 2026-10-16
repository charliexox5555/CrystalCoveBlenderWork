# Current powers and next brainstorm

October 15, 2026. Exactly 24 release glassies. The middle columns describe implemented behavior; the last column is a proposal, not installed gameplay. Current numbers are in `src/shared/Config/Balance.luau` and remain provisional for balance.

Most current signatures are a single shot, a short buff, or a one-use shield. More particles alone won't give them distinct stories. The next pass should make a few powers visibly change the next swing or create a brief event players can anticipate, then react to. Keep each action readable, bounded and server-authoritative.

| Glassy | Current signature / trigger | What it currently does | Idea to discuss |
|---|---|---|---|
| Pop | Pressure Pop / every 3 clashes | Extra contact damage and stronger rebound | The cap visibly launches; a pressure ring pushes the next swing into a dramatic comeback |
| Jam | Lid Guard / every 2 turnarounds | Lid softens the next body clash by 40% | Lid catches the hit, spins like a frisbee, then counter-slaps the opponent |
| Prism | Refraction Ray / timed charge | Fires one locked, narrow ray that can miss | Split into three rainbow rays with a single shared damage budget |
| Crescent Axe | Crescent Sweep / every 2 turnarounds | Winds up and swings a separate axe through a bounded arc | A clear raised-axe pose, close-range slam and visible knockback rather than a tiny distant miss |
| Briar Flask | Thorn Bloom / every 3 turnarounds | Grows thorns; next body clash deals extra damage | Thorn petals burst, orbit briefly, then converge on the next contact |
| Arc Coil | Coil Discharge / every 3 clashes | Fires a crackling locked electrical shot | A short-lived electric tether crackles along the string and ends in a snapping discharge |
| Milk Bottle | Fresh Seal / below half HP, once | Repairs 12% maximum HP after a windup | Foamy bubbles patch actual cracks, then one leftover bubble pops as a small contact counter |
| Pickle Jar | Brine Line / every 3 clashes | Brief nonstacking slow with a visible tether | Sticky brine visibly stretches and snaps, releasing the slowed swing into a slingshot |
| Ketchup Bottle | Splat Pop / every 3 clashes | Marks the target; a later clash pops it for extra damage | A bouncing tomato blob sticks visibly and swells before the next hit detonates it |
| Glass Cup | Rim Rush / every 2 turnarounds | Briefly increases swing drive and empowers contact | A rim ricochet streak that rewards the next incoming swing with a pronounced rebound |
| Water Jug | Sloshback / stores 2 received clashes | At a later turnaround, releases one short splash cone | Store a visibly rising water level, then throw a rolling wave that tips the opponent sideways |
| Lemonade Bottle | Zest Volley / timed | Three traveling pips in a fan, sharing one damage budget | Pips bounce once and pop in sequence; limited ricochets create a little chase |
| Mason Jar | Screw-Top Counter / heavy received hit | Arms one expiring next-contact damage bonus | Lid ratchets upward, then springs down in an obvious hammer-like counter |
| Hot Sauce | Hot Streak / below half HP, once | One brief stronger-drive window with empowered clashes | A short hot streak accelerates each swing visibly; clear cooldown smoke when it ends |
| Crystal Tumbler | Mirror Catch / timed | Partially catches one ranged hit and sends a return ray; unused catch becomes a contact bonus | A large faceted mirror catches and visibly banks the projectile around its rim before returning it |
| Chime | Resonant Ring / every 2 turnarounds | One expanding 3D pulse shell | Two staggered ringing waves; the second nudges swing phase, making timing visibly different |
| Hourglass | Borrowed Moment / stores part of damage | Sends a capped sand shot at a later turnaround | Rewind its own last swing briefly, then replay it as a double-back; requires bounded motion history |
| Frostglobe | Snowdrift / timed | One short frost cone with a brief nonstacking slow | A visible snowball impact builds a temporary ice shell that cracks apart when the slow ends |
| Prism Blade | Edgewake / every 2 turnarounds | A crescent travels out and back; each leg can hit once, sharing one damage budget | A curved return route makes the second pass easier to follow without automatic homing |
| Rocket Pop | Afterburn Swing / every 3 turnarounds | Brief boost, capped tangent impulse and next-clash payoff | A two-stage boost: sputter, then a clear rocket dive along the string arc |
| Glass Duck | Bubble Buoy / low HP, once | A bubble softens one dangerous body clash by 50% | Duck rides a buoy bubble briefly; the popped bubble releases a playful splash counter |
| Comet | Star Echo / every 3 clashes, then turnaround | Leaves a star at the contact point; fires it later | One orbiting mini-star loops around the glassy before launching, with an obvious trail and return point |
| Glass Dragon | Dragon Breath / timed | Three locked cone pulses sharing one damage budget | Three chunky glass fireballs that burst into a short breath fan, with a visible jaw/wings anticipation |
| Galaxy Orb | Little Orbit / timed | A brief bounded gravity well bends swings and closes with a pulse | Three mini-moons orbit the well, sling outward, then collapse; cap total damage and pull strength |

## Best first experiments

Start with Dragon, Galaxy, Hourglass and Jam: projectile spectacle, a short arena event, a movement surprise and a satisfying defensive counter. They would feel different even with the particles turned down. Test these against Pop, Axe and Blade before changing all 24. Avoid giving every kit a stun, homing attack or extra independent damage source.

Questions for our next brainstorm: which should be the funniest, which should feel most powerful, and should movement disruption or projectile patterns be the main source of surprise? No answer is required to use the completed selection/finisher polish.
