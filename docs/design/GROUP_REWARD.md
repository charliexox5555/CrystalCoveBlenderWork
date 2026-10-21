# Group reward (decision 114, Proposed)

A stand in the lobby gives everyone in the Glass Clash group (**11116787**) **one free Marble Kiln open, once ever**.
Not in the group yet? The stand opens Roblox's join prompt right there, and the gift unlocks as soon as the join lands.

## How it plays

| Stand state (`Player.GroupReward`) | What the player sees | E / tap does |
|---|---|---|
| **Join** (not a member, or the check failed) | Heart bobs slowly, soft aqua glow, a few sparkles. Prompt: **Join · Group gift** | Roblox's group join prompt (`GroupService:PromptJoinAsync`). Joined or "already a member" → the server checks for itself → the claim card opens by itself |
| **Ready** (member, not claimed) | Heart bobs faster, bright gold glow, lots of sparkles. Prompt: **Claim · Group gift** | The claim card (same card as the welcome / first win): **GROUP GIFT!**, the Marble Kiln, **OPEN** |
| **Claimed** | Heart still, no glow, no prompt | (prompt hidden) |

OPEN → one open of the **Marble Kiln**, with the Marble Kiln's own odds, played as the usual Kiln opening ("THANKS FOR
JOINING!"). Like the other free claim cards, the card shows no odds line (decision 102). Where `PolicyService`
says paid random items are restricted, or the policy is unknown, the gift is a **Coin Kiln** open instead, and the card
shows the Coin Kiln. Kids skip reading, so the stand speaks through motion and light: slow means "come and see", fast and
gold means "it's ready", still means done.

## Research (proven methods)

- **Prompting a join.** `GroupService:PromptJoinAsync(groupId)` shows Roblox's own join prompt to the local player and
  returns `Enum.GroupMembershipStatus`: `Joined`, `AlreadyMember`, `JoinRequestPending` (groups that need approval) or
  `None` (closed, cancelled or not eligible). The docs' sample runs it on the client and wraps it in `pcall`.
  [GroupService](https://create.roblox.com/docs/reference/engine/classes/GroupService),
  [GroupMembershipStatus](https://create.roblox.com/docs/reference/engine/enums/GroupMembershipStatus)
- **Membership checks are cached per peer.** `Player:IsInGroupAsync` (which replaces the deprecated `IsInGroup`) caches
  its result, and the server and the client keep separate caches. A join through `PromptJoinAsync` clears the cache only
  "on the client where the prompt was shown", so the **server keeps its old `false`** for the rest of the visit.
  `GetRolesInGroupAsync` is cached the same way.
  [Player.IsInGroupAsync](https://create.roblox.com/docs/reference/engine/classes/Player)
- **So the server re-checks with `GroupService:GetGroupsAsync`** after a prompt. Its docs mention no cache, and
  developers use it for exactly this, to get fresh membership
  ([DevForum: group function caching](https://devforum.roblox.com/t/group-related-function-caching/118214)). We retry 3
  times, 2 s apart, in case the join takes a moment to show up. The first check at join time uses `IsInGroupAsync`, as
  the docs recommend.
- **Never trust the client's result.** The client reports the prompt's result only so the server knows when to look.
  The grant needs the server's own confirmed membership (the standard server-authoritative rule; AGENTS.md).
- **Set the flag when the grant happens, not at join time.** A common group-reward bug is setting "claimed" on
  `PlayerAdded`, which locks out players who join the group later
  ([DevForum: group rewards script](https://devforum.roblox.com/t/group-rewards-script/3537863)). Here the flag is set
  only inside the claim, after membership is confirmed and before the roll, so the grant happens once.
- **Rules on rewarding membership.** Roblox's [Community Standards](https://about.roblox.com/community-standards) do not
  forbid in-game rewards for joining a group. They forbid misleading content used to drive engagement and paying
  **Robux** for joins. DevForum consensus is that group perks are fine, while rewards for **likes** are frowned on,
  because likes are meant as an honest rating
  ([DevForum](https://devforum.roblox.com/t/is-rewarding-players-for-liking-favoriting-a-game-allowed/2926286)). So:
  a free, non-Robux, honest reward ("join the group, get a gift"), no reward for likes or favourites, and no Discord
  links in game.
- **What top games do.** Group-reward chests sit in the spawn hub and unlock as soon as a player joins (e.g. Pet
  Simulator 99's group chest; Bee Swarm Simulator's group-only codes). Older games needed a rejoin because they couldn't
  prompt in game. With `PromptJoinAsync` and a fresh server check, ours unlocks without a rejoin.
- **Policy.** The Marble Kiln is a paid random item, so it is gated on `PolicyService.ArePaidRandomItemsRestricted`
  like every other Marble pull (AGENTS.md). Restricted or unknown → Coin Kiln.

## Code

- `src/shared/Config/GroupReward.luau`: group id, tag / prompt names, retries, rate limits, stand motion.
- `src/server/Data/GroupRewardRules.luau` (pure, Lune-tested in `src/tests/GroupRewardTests.luau`): `state`,
  `afterPrompt`, `kiln` (policy), `inGroups`, `claim` (once ever, members only), `roll` (that Kiln's odds).
- `src/server/Services/GroupRewardService.luau`: membership checks, `Player` attributes `GroupReward` and
  `GroupRewardKiln`, the `GroupReward` remote (`"Prompt", status` / `"Claim"`, both rate-limited), the grant (profile
  flag `Flags.GroupRewardClaimed`, reconciled in `ProfileSchema`), the opening (`OnboardingReveal`, `Kind = "Group"`,
  `Currency`), and custom analytics events `GroupRewardPrompted` / `GroupRewardJoined` / `GroupRewardClaimed`.
- `src/client/Controllers/GroupRewardController.luau`: the stand's prompt, the join prompt, glow and bob.
- `OnboardingController`: the claim card has a third kind, `Group` (title, Kiln currency, OPEN fires `GroupReward`).
  `KilnScreen.reveal` takes `Currency`.

## The stand (lives in the place: save it)

`Workspace.Lobby.GroupRewardStand`, between the Finishers machine and the Kilns at (-33.5, 0, -3), facing the spawn.
Tag `GroupRewardStand`, `ModelStreamingMode` Atomic. Inside:

- `Root`: an invisible pivot at the floor centre, holding `PromptAttachment.GroupReward` (ProximityPrompt: E / X,
  10 studs, no hold).
- MeshParts from asset **91987420283885** (FBX `assets/blender/map/group_reward_stand/`, built by
  `tools/blender/build_group_reward_stand.py`, 1,536 tris), scaled from the importer's 100x:
  `Stand_Lead` #2A2140 (collides, Hull), `Stand_Gold` #F4B73A, `Stand_Milk` #7A7480 (the kiln dome, Marble Kiln grey),
  `Stand_Brick` #3D1585 (arch), `Stand_Copper` #654D46 (chimney), `Stand_Glow` Neon #93BCFF (the kiln mouth),
  `Stand_Aqua` #2FC4D6 (emblem window), `Stand_Amethyst` #8C4FE0 (side panes), three Glass marbles, and
  `GlassHeart` (Glass #FF5C8A, with `GiftGlow` PointLight and `Sparkles` ParticleEmitter; the client animates it).
- The raw insert is archived at `ServerStorage.GroupRewardStandRaw`.

## Testing

- Lune: `GroupRewardTests` (8 tests: state, prompt results, policy Kiln, `GetGroupsAsync` parsing, once-ever claim,
  profile reconcile, Marble vs Coin odds).
- Studio, where `IsInGroupAsync` answers for the real Studio user: `ServerStorage.GroupRewardDev:Invoke("Member", player,
  true | false | nil)` pretends the player is in or out of the group (`nil` asks Roblox again);
  `:Invoke("Reset", player)` clears the claim. Evidence in `docs/testing/group_reward/`.
- Not testable in Studio: Roblox's join modal itself (in Studio the call never returned and the modal doesn't show in
  captures). Check it once on a live server with an account that is not in the group.
