--!strict
-- Every remote in the game (GAME_DESIGN 13.3). The server creates them; clients wait for them.
-- Client -> server remotes are validated and rate-limited in MatchService (Balance.Match.*RateSeconds).
--
--   Server -> client
--     MatchState     (RemoteEvent)            phase changes: Queue, Rolling, Aiming, Countdown, Fighting, RoundEnd, MatchEnd
--     RollOffers     (RemoteEvent)            your 3 offers + reroll cost
--     FightEvents    (RemoteEvent)            FightRules events (Hit, Passive, Power, PerfectRelease, Overtime, Shatter, End)
--     FightSnapshot  (UnreliableRemoteEvent)  glassy positions/rotations + HP + power glow at Balance.Feel.SnapshotRate
--     MatchResult    (RemoteEvent)            winner, coins, trophies
--   Client -> server
--     PickGlassy     (RemoteEvent)  id: string
--     Reroll         (RemoteEvent)  (no args)
--     SetAim         (RemoteEvent)  aim: number, yaw: number (radians; clamped by FightRules.clampAim / clampYaw)
--     LeaveQueue     (RemoteEvent)  (no args)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local reliable = {
	"MatchState",
	"RollOffers",
	"FightEvents",
	"MatchResult",
	"PickGlassy",
	"Reroll",
	"SetAim",
	"LeaveQueue",
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
