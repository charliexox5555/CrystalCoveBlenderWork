# Current powers and next brainstorm

Updated October 16, 2026. Exactly 24 release glassies. The middle columns describe implemented behavior; the last column is a proposal, not installed gameplay. Current numbers are in `src/shared/Config/Balance.luau` and remain provisional for balance. The latest readability pass is documented in `docs/testing/combat_release/POWER_READABILITY_V3.md`.

Most current signatures are a single shot, a short buff, or a one-use shield. More particles alone won't give them distinct stories. The next pass should make a few powers visibly change the next swing or create a brief event players can anticipate, then react to. Keep each action readable, bounded and server-authoritative.

| Glassy | Current signature / trigger | What it currently does | Idea to discuss |
|---|---|---|---|
| Pop | Pressure Pop / every 3 clashes | Extra contact damage, stronger rebound, launched cap and large pressure wave | Let the pressure visibly build in its bubbles before the payoff |
| Jam | Lid Guard / every 2 turnarounds | Real lid raises as a shield; softens the next body clash by 40% with a gold block burst | Lid spins like a frisbee after a successful block, then counter-slaps the opponent |
| Prism | Refraction Ray / timed charge | Aimed glowing lens fires a white-core ray with colored rings and brief afterglow; can miss | Split into three rainbow rays with a single shared damage budget |
| Crescent Axe | Crescent Sweep / every 2 turnarounds | Shows a raised blue axe, then sweeps its actual head along the bounded damage arc with a trail | Add a more pronounced slam recoil on a confirmed hit |
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
| Hourglass | Second Turn / 3 turnarounds at or below 65% HP | Whole-glassy spin heals 7% maximum HP; twice per round, 8-second cooldown, disabled in overtime | Sand visibly flows upward during the repair; keep current heal limits |
| Frostglobe | Snowdrift / timed | One short frost cone with a brief nonstacking slow | A visible snowball impact builds a temporary ice shell that cracks apart when the slow ends |
| Prism Blade | Edgewake / every 2 turnarounds | A crescent travels out and back; each leg can hit once, sharing one damage budget | A curved return route makes the second pass easier to follow without automatic homing |
| Rocket Pop | Afterburn Swing / every 3 turnarounds | Brief boost, capped tangent impulse and next-clash payoff | A two-stage boost: sputter, then a clear rocket dive along the string arc |
| Glass Duck | Bubble Buoy / low HP, once | A bubble softens one dangerous body clash by 50% | Duck rides a buoy bubble briefly; the popped bubble releases a playful splash counter |
| Comet | Star Echo / every 3 clashes, then turnaround | Leaves a star at the contact point; fires it later | One orbiting mini-star loops around the glassy before launching, with an obvious trail and return point |
| Glass Dragon | Dragon Breath / timed | Three locked cone pulses sharing one damage budget | Three chunky glass fireballs that burst into a short breath fan, with a visible jaw/wings anticipation |
| Galaxy Orb | Little Orbit / timed | A brief bounded gravity well bends swings and closes with a pulse | Three mini-moons orbit the well, sling outward, then collapse; cap total damage and pull strength |

## Best first experiments

Hourglass's spinning repair and the Pop/Jam/Prism/Axe readability pass are now installed. Review those at normal speed first. Dragon fireballs, Galaxy mini-moons and Jam's counter remain ideas for a later mechanics pass. Test against Pop, Axe and Blade before changing all 24. Avoid giving every kit a stun, homing attack or extra independent damage source.

Questions for our next brainstorm: which should be the funniest, which should feel most powerful, and should movement disruption or projectile patterns be the main source of surprise? No answer is required to use the completed selection/finisher polish.
