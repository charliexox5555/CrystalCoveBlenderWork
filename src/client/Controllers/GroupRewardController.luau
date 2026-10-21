-- The group reward stand on the client (decision 114, docs/design/GROUP_REWARD.md). The server owns the state (Player
-- attribute GroupReward: Join | Ready | Claimed) and grants; this controller drives the stand:
--   Join:    the prompt shows Roblox's group join prompt (GroupService:PromptJoinAsync runs on the client); a join or
--            "already a member" asks the server to check, and once it says Ready the claim card opens by itself
--   Ready:   the prompt opens the claim card (OnboardingController's card, kind "Group") -> OPEN -> the Kiln opening
--   Claimed: the prompt hides and the stand rests
-- Kids skip reading, so the stand talks in motion: the glass heart bobs and glows while a gift waits, faster and gold
-- when it is ready to claim, and goes still once it is spent.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local RunService = game:GetService("RunService")
local Config = require(RS.Shared.Config.GroupReward)
local Remotes = require(RS.Shared.Remotes)
local Motion = require(script.Parent.Parent.UI.Components.Motion)
local Controller = {}

-- Glow per state: light brightness, sparkle rate and colour (Ready is the gold "come and get it").
local LOOK = {
	Join = { Light = 1.2, Sparkles = 3, Color = Color3.fromHex("#9FE8FF") },
	Ready = { Light = 3, Sparkles = 14, Color = Color3.fromHex("#FFD45E") },
	Claimed = { Light = 0, Sparkles = 0, Color = Color3.fromHex("#9FE8FF") },
}
local VIEW_STUDS = 160 -- animate only when the camera is this close

function Controller:Init(controllers)
	self.Controllers, self.Player, self.Stands = controllers, Players.LocalPlayer, {}
end

function Controller:State()
	return self.Player:GetAttribute("GroupReward") or "Join"
end

-- The claim card, unless an onboarding card or opening has the stage (its own watcher shows that one first).
function Controller:Offer()
	local onboarding = self.Controllers.OnboardingController
	local step = self.Player:GetAttribute("OnboardingStep")
	if not onboarding or onboarding.ClaimKind or onboarding.Revealing or step == "Welcome" or step == "Win" then
		return
	end
	onboarding:ShowClaim("Group")
end

function Controller:Use()
	local state = self:State()
	if state == "Ready" then
		self:Offer()
		return
	end
	-- One join prompt at a time. The guard expires: a prompt that never answers (seen in Studio) can't lock the stand.
	if state ~= "Join" or (self.Prompting and os.clock() - self.Prompting < Config.PromptGuardSeconds) then
		return
	end
	local serial = os.clock()
	self.Prompting = serial
	task.spawn(function()
		local ok, result = pcall(GroupService.PromptJoinAsync, GroupService, Config.GroupId)
		if self.Prompting == serial then
			self.Prompting = nil
		end
		if not ok or typeof(result) ~= "EnumItem" then
			warn("[GroupReward] join prompt failed: " .. tostring(result))
			return
		end
		Remotes.GroupReward:FireServer("Prompt", result.Name)
		if result ~= Enum.GroupMembershipStatus.Joined and result ~= Enum.GroupMembershipStatus.AlreadyMember then
			return -- closed, not eligible, or a join request waiting for approval
		end
		-- The server checks for itself; the card opens as soon as it agrees.
		local waited = os.clock()
		while self:State() == "Join" and os.clock() - waited < Config.ConfirmWaitSeconds do
			task.wait(0.2)
		end
		if self:State() == "Ready" then
			self:Offer()
		end
	end)
end

function Controller:Look(stand)
	local state = self:State()
	local look = LOOK[state] or LOOK.Join
	stand.Prompt.Enabled = state ~= "Claimed"
	stand.Prompt.ActionText = if state == "Ready" then "Claim" else "Join"
	stand.Prompt.ObjectText = "Group gift"
	for _, light in stand.Lights do
		light.Enabled, light.Brightness, light.Color = look.Light > 0, look.Light, look.Color
	end
	for _, sparkles in stand.Sparkles do
		sparkles.Rate, sparkles.Enabled = look.Sparkles, look.Sparkles > 0
		sparkles.Color = ColorSequence.new(look.Color)
	end
end

function Controller:Bind(model)
	if self.Stands[model] or not model:IsA("Model") then
		return
	end
	local prompt = model:FindFirstChild(Config.PromptName, true)
	if not (prompt and prompt:IsA("ProximityPrompt")) then
		return
	end
	local heart = model:FindFirstChild("GlassHeart", true)
	local stand = {
		Model = model,
		Prompt = prompt,
		Heart = if heart and heart:IsA("BasePart") then heart else nil,
		Lights = {},
		Sparkles = {},
		Connections = {},
	}
	stand.Rest = stand.Heart and stand.Heart.CFrame
	for _, child in model:GetDescendants() do
		if child:IsA("PointLight") then
			table.insert(stand.Lights, child)
		elseif child:IsA("ParticleEmitter") then
			table.insert(stand.Sparkles, child)
		end
	end
	table.insert(
		stand.Connections,
		prompt.Triggered:Connect(function(player)
			if player == self.Player then
				self:Use()
			end
		end)
	)
	self.Stands[model] = stand
	self:Look(stand)
end

function Controller:Unbind(model)
	local stand = self.Stands[model]
	if stand then
		for _, connection in stand.Connections do
			connection:Disconnect()
		end
		self.Stands[model] = nil
	end
end

-- The glass heart bobs and turns while a gift waits (still under Reduced Motion, or once claimed).
function Controller:Step()
	local camera = workspace.CurrentCamera
	local state = self:State()
	local now = os.clock()
	for _, stand in self.Stands do
		local heart, rest = stand.Heart, stand.Rest
		if heart and rest and heart.Parent then
			local active = state ~= "Claimed" and not Motion.reduced()
			if active and camera and (camera.CFrame.Position - rest.Position).Magnitude < VIEW_STUDS then
				local bob = math.sin(now * 2 * math.pi / Config.BobSeconds[state]) * Config.BobStuds
				local turn = (now / Config.TurnSeconds[state]) % 1 * 2 * math.pi
				heart.CFrame = rest * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0)
				stand.Moving = true
			elseif stand.Moving then
				heart.CFrame, stand.Moving = rest, false
			end
		end
	end
end

function Controller:Start()
	CollectionService:GetInstanceAddedSignal(Config.StandTag):Connect(function(model)
		self:Bind(model)
	end)
	CollectionService:GetInstanceRemovedSignal(Config.StandTag):Connect(function(model)
		self:Unbind(model)
	end)
	for _, model in CollectionService:GetTagged(Config.StandTag) do
		self:Bind(model)
	end
	self.Player:GetAttributeChangedSignal("GroupReward"):Connect(function()
		for _, stand in self.Stands do
			self:Look(stand)
		end
	end)
	RunService.RenderStepped:Connect(function()
		self:Step()
	end)
end

return Controller
