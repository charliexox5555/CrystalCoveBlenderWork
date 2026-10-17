--!strict
-- Every remote in the game (GAME_DESIGN 13.3). The server creates them; clients wait for them.
-- Client -> server remotes are validated and rate-limited by their owning service.
-- Intervals live in Balance.Match, Balance.Data and Balance.Retention.
--
--   Server -> client
--     MatchState     (RemoteEvent)            phase changes: Queue, Rolling, Aiming, Countdown, Fighting, RoundEnd, MatchEnd
--     RollOffers     (RemoteEvent)            persistent match hand, revisions, prices, wallet and policy eligibility
--     FightEvents    (RemoteEvent)            FightRules events (Hit, Passive, Power, PerfectRelease, Overtime, Shatter, End)
--     FightSnapshot  (UnreliableRemoteEvent)  glassy positions/rotations + HP + power glow at Balance.Feel.SnapshotRate
--     MatchResult    (RemoteEvent)            winner, coins, trophies
--   Client -> server
--     PickGlassy     (RemoteEvent)  id: string
--     Reroll         (RemoteEvent)  matchId, round, selectionRevision, expectedCost
--     PickAny        (RemoteEvent)  id, matchId, round, selectionRevision, expectedCost
--     SetAim         (RemoteEvent)  aim: number, yaw: number (radians; clamped by FightRules.clampAim / clampYaw)
--     LeaveQueue     (RemoteEvent)  (no args)
--     RequestFightState (RemoteEvent) late-join/respawn bootstrap (no args)
--     RequestStore   (RemoteEvent)  (no args) -> StoreOffers: today's daily offers + featured bundle
--     BuyStoreOffer  (RemoteEvent)  slot: number, id: string, day: number (Coins buy now; Robux prompts)
--     BuyStoreBundle (RemoteEvent)  bundleId: string (Robux prompt once a product ID is configured)
--     RequestMusicPrefs (RemoteEvent) (no args) -> MusicPrefs { Muted, Volume }
--     SetMusicPrefs  (RemoteEvent)  muted: boolean, volume: number (0-1); saved by MusicPrefsService
--   Server -> client: StoreOffers (view, NextReset, ServerNow, Message), StoreResult (purchase outcome)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local reliable = {
	"MatchState",
	"RollOffers",
	"FightEvents",
	"MatchResult",
	"PickGlassy",
	"Reroll",
	"PickAny",
	"SetAim",
	"LeaveQueue",
	"JoinNearestArena",
	"RequestRematch",
	"ProfileSnapshot",
	"RequestProfile",
	"KilnOdds",
	"KilnResult",
	"RequestKiln",
	"PullKiln",
	"ClaimRetention",
	"RedeemCode",
	"RetentionResult",
	"RequestFightState",
	"EquipRoundCosmetic",
	"CosmeticResult",
	"RequestStore",
	"StoreOffers",
	"BuyStoreOffer",
	"BuyStoreBundle",
	"StoreResult",
	"RequestMusicPrefs",
	"MusicPrefs",
	"SetMusicPrefs",
}
local unreliable = { "FightSnapshot" }

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder and RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end
folder = folder or ReplicatedStorage:WaitForChild("Remotes")

local remotes: { [string]: any } = {}
local function get(name: string, className: string)
	local remote = folder:FindFirstChild(name)
	if not remote and RunService:IsServer() then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	remote = remote or folder:WaitForChild(name)
	assert(remote:IsA(className), "Unexpected remote class: " .. name)
	remotes[name] = remote
end
for _, name in reliable do
	get(name, "RemoteEvent")
end
for _, name in unreliable do
	get(name, "UnreliableRemoteEvent")
end
return remotes
