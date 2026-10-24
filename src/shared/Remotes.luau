--!strict
-- Every remote in the game (GAME_DESIGN 13.3). The server creates them; clients wait for them.
-- Client -> server remotes are validated and rate-limited by their owning service.
-- Intervals live in Balance.Match, Balance.Data and Balance.Retention.
--
--   Server -> client
--     MatchState     (RemoteEvent)            phase changes: Queue, QueueLeft (contract in ArenaService), Rolling, Aiming, Countdown, Fighting, RoundEnd, MatchEnd
--     RollOffers     (RemoteEvent)            persistent match hand, revisions, prices, wallet and policy eligibility
--     FightEvents    (RemoteEvent)            FightRules events (Hit, Passive, Power, PerfectRelease, Overtime, Shatter, End)
--     FightSnapshot  (UnreliableRemoteEvent)  glassy positions/rotations + HP + power glow at Balance.Feel.SnapshotRate
--     MatchResult    (RemoteEvent)            winner, coins, trophies
--   Client -> server
--     PickGlassy     (RemoteEvent)  id: string
--     Reroll         (RemoteEvent)  matchId, round, selectionRevision, expectedCost
--     PickAny        (RemoteEvent)  id, matchId, round, selectionRevision, expectedCost
--     SetAim         (RemoteEvent)  aim: number, yaw: number (radians; clamped by FightRules.clampAim / clampYaw)
--     CastPower      (RemoteEvent)  (no args) cast your Ready power now (FightService; decision 85)
--     Push           (RemoteEvent)  (no args) shove your glassy; charges in ArenaRules (FightService; decision 122)
--     LeaveQueue     (RemoteEvent)  (no args) leave the queue, or forfeit the live match (ArenaService)
--     RequestFightState (RemoteEvent) late-join/respawn bootstrap (no args)
--     RequestStore   (RemoteEvent)  (no args) -> StoreOffers: today's daily offers + featured bundle
--     BuyStoreOffer  (RemoteEvent)  slot: number, id: string, day: number (Coins buy now; Robux prompts)
--     BuyStoreBundle (RemoteEvent)  bundleId: string (Robux prompt once a product ID is configured)
--     BuyMarblePack  (RemoteEvent)  packId: string (Config/MarbleShop; Robux prompt)
--     OnboardingAction (RemoteEvent) action: "OpenWelcome" (decision 100; OnboardingService validates the step)
--     Server -> client: OnboardingReveal { Results, Odds, Kind = "Welcome" | "Win" } plays a Kiln opening
--     RequestSettings (RemoteEvent) (no args) -> Settings { Master, Music, SFX, BotPlay, AutoCast, ... } (Config/Settings)
--     SetSetting     (RemoteEvent)  key: string, value: number (0-1) | boolean; saved by SettingsService (decision 99)
--   Server -> client: StoreOffers (view, NextReset, ServerNow, Message), StoreResult (purchase outcome)
--     RequestPlayerProfile (RemoteEvent) userId: number -> PlayerProfile { UserId, Name, View } | { UserId, Missing }
--                    another player's read-only profile (ProfileSchema.publicView; DataService, decision 104)
--     Deals          (RemoteEvent)  "Request" | "Buy", kind ("Starter" | "DailyGlassy" | "DailyMarbles") | "AutoOpened"
--                    -> DealState (OfferRules.view + Held, ServerNow, Message); StoreService, decision 116
--     GroupReward    (RemoteEvent)  "Prompt", status: GroupMembershipStatus name | "Claim" (GroupRewardService, decision 114)
--                    state comes back as Player attributes; the opening as OnboardingReveal { Kind = "Group", Currency }

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
	"CastPower",
	"Push",
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
	"BuyMarblePack",
	"OnboardingAction",
	"OnboardingReveal",
	"RequestSettings",
	"Settings",
	"SetSetting",
	"RequestPlayerProfile",
	"PlayerProfile",
	"GroupReward",
	"Deals",
	"DealState",
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
