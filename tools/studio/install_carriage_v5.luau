-- Moonlantern Carriage v5 mesh install (workstream I, docs/vfx/HOLLOWLIGHT_PREMIUM.md section 7b). Studio **Edit**.
-- Needs ServerStorage.HollowlightV5Import = InsertService:LoadAsset(85604557082927) (hollowlight_v5/roblox_assets.json).
-- Backs up the installed carriage to ServerStorage.HollowlightCarriageV4BeforeV5 (once), then builds the v5 model:
--   * every v5 mesh whose name exists on the installed model replaces that part and inherits its material, colour,
--     transparency, attributes and children (emitters, lights, attachments keep their world placement);
--   * new v5 parts get the palette below; HullGlow glows, HullStars twinkle, LanternChain swings with the lantern;
--   * Wing/WingRibs/WingEdge beat about the v4 wing root; WingTip* flex after the beat (CarriageFX WingTip) about the
--     wrist line from anchors.json; the v4 wing ribbon trail moves onto the tips.
-- Import frame: the FBX arrives at 100x with the nose on +Z, so parts map by Ry(180) and 0.0135 (0.01 x the 1.35
-- install scale); the seat lands exactly where v4's did. Item id, ownership and the lantern pumpkin are unchanged.
local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
local folder = RS.Assets.Seasonal.Hollowlight
local current = folder.moonlantern_carriage
if current:GetAttribute("Version") == 5 then
	return "already v5"
end
if not SS:FindFirstChild("HollowlightCarriageV4BeforeV5") then
	local b = current:Clone()
	b.Name = "HollowlightCarriageV4BeforeV5"
	b.Parent = SS
end
local import = SS.HollowlightV5Import:FindFirstChildWhichIsA("Model")
local K = 0.0135
local ROT = CFrame.Angles(0, math.pi, 0)
local new = current:Clone()
local pivot0 = new:GetPivot()
local function toModel(p)
	return pivot0 * (CFrame.new(ROT:PointToWorldSpace(p.Position * K)) * ROT * p.CFrame.Rotation)
end
local roots = {}
for _, side in { "R", "L" } do
	local w = new:FindFirstChild("Wing_" .. side, true)
	roots[side] = w.CFrame:PointToWorldSpace(w:GetAttribute("WingPivot") or Vector3.zero)
end
local body = new:FindFirstChild("LanternBody", true)
local hinge = body.CFrame:PointToWorldSpace(body:GetAttribute("SwingPivot") or Vector3.zero)
local style = {
	HullGlow = { Material = Enum.Material.Neon, Color = "#61EFBD", Transparency = 0.05, CarriageMotion = "Glow" },
	HullStars = { Material = Enum.Material.SmoothPlastic, Color = "#FFD27A", Transparency = 0, CarriageMotion = "Twinkle" },
	WingTip = { Material = Enum.Material.Glass, Color = "#7A55C8", Transparency = 0.15 },
	WingTipRibs = { Material = Enum.Material.SmoothPlastic, Color = "#DDA84D", Transparency = 0 },
	WingEdge = { Material = Enum.Material.Neon, Color = "#C79BFF", Transparency = 0.1 },
	WingTipEdge = { Material = Enum.Material.Neon, Color = "#C79BFF", Transparency = 0.1 },
	EngineRing = { Material = Enum.Material.SmoothPlastic, Color = "#DDA84D", Transparency = 0 },
	LanternChain = { Material = Enum.Material.SmoothPlastic, Color = "#DDA84D", Transparency = 0 },
}
for _, src in import:GetDescendants() do
	if not src:IsA("BasePart") then
		continue
	end
	local q = src:Clone()
	for _, c in q:GetChildren() do
		c:Destroy()
	end
	q.CFrame, q.Size = toModel(src), src.Size * K
	q.Anchored, q.CanCollide, q.CanTouch, q.CanQuery, q.CastShadow = true, false, false, false, false
	local old = new:FindFirstChild(src.Name, true)
	if old and old:IsA("BasePart") then
		q.Material, q.Color, q.Transparency, q.Reflectance = old.Material, old.Color, old.Transparency, old.Reflectance
		for k, v in old:GetAttributes() do
			q:SetAttribute(k, v)
		end
		for _, child in old:GetChildren() do
			local worlds = {}
			for _, a in child:GetDescendants() do
				if a:IsA("Attachment") then
					worlds[a] = a.WorldCFrame
				end
			end
			local own = child:IsA("Attachment") and child.WorldCFrame
			child.Parent = q
			if own then
				child.WorldCFrame = own
			end
			for a, w in worlds do
				a.WorldCFrame = w
			end
		end
		q.Parent = old.Parent
		old:Destroy()
	else
		local s = style[src.Name:gsub("_[LR]$", "")]
		if s then
			q.Material, q.Color, q.Transparency = s.Material, Color3.fromHex(s.Color), s.Transparency
			if s.CarriageMotion then
				q:SetAttribute("CarriageMotion", s.CarriageMotion)
			end
		end
		q:SetAttribute("V5Part", true)
		q.Parent = new
	end
end
local anchors = { -- assets/blender/seasonal/hollowlight_v5/anchors.json (Roblox axes, Blender scale)
	WingWrist_R = Vector3.new(2.5941, 0.6943, -0.5934),
	WingSplit_R = Vector3.new(2.987, 0.9736, 0.779),
	WingWrist_L = Vector3.new(-2.5941, 0.6943, -0.5934),
	WingSplit_L = Vector3.new(-2.987, 0.9736, 0.779),
}
for _, side in { "R", "L" } do
	local sign = if side == "R" then 1 else -1
	local wing = new:FindFirstChild("Wing_" .. side, true)
	for _, n in { "Wing_", "WingRibs_", "WingEdge_" } do
		local p = new:FindFirstChild(n .. side, true)
		p:SetAttribute("RideMotion", "Wing")
		p:SetAttribute("WingSide", sign)
		p:SetAttribute("WingPivot", p.CFrame:PointToObjectSpace(roots[side]))
	end
	local wrist = pivot0:PointToWorldSpace(anchors["WingWrist_" .. side] * 1.35)
	local split = pivot0:PointToWorldSpace(anchors["WingSplit_" .. side] * 1.35)
	for _, n in { "WingTip_", "WingTipRibs_", "WingTipEdge_" } do
		local p = new:FindFirstChild(n .. side, true)
		p:SetAttribute("CarriageMotion", "WingTip")
		p:SetAttribute("FollowPart", "Wing_" .. side)
		p:SetAttribute("WingSide", sign)
		p:SetAttribute("TipAxis0", wing.CFrame:PointToObjectSpace(wrist))
		p:SetAttribute("TipAxis1", wing.CFrame:PointToObjectSpace(split))
	end
	local tip = new:FindFirstChild("WingTip_" .. side, true)
	for _, c in wing:GetChildren() do
		if c:IsA("Trail") or (c:IsA("Attachment") and c.Name:match("^Tip")) then
			local w = c:IsA("Attachment") and c.WorldCFrame
			c.Parent = tip
			if w then
				c.WorldCFrame = w
			end
		end
	end
end
local chain = new:FindFirstChild("LanternChain", true)
chain:SetAttribute("RideMotion", "Swing")
chain:SetAttribute("SwingPivot", chain.CFrame:PointToObjectSpace(hinge))
-- Hand grips for the HandleSit ride animation (workstream H IK): top tube corners of the handlebar.
local bar = new:FindFirstChild("Handlebar", true)
for name, x in { GripL = -0.62, GripR = 0.62 } do
	local g = Instance.new("Attachment")
	g.Name, g.Parent = name, bar
	g.WorldCFrame = pivot0.Rotation + pivot0:PointToWorldSpace(Vector3.new(x, 1.46, -1.74))
end
-- Footrest moved back to where a default R15 HandleSit leg reaches (soles at about z -1.7, y 0.5; workstream H).
local foot = new:FindFirstChild("Footrest", true)
foot.CFrame = pivot0 * CFrame.new(0, 0.35, -1.75) * (pivot0:Inverse() * foot.CFrame).Rotation
foot:SetAttribute("MovedForHandleSit", true)
new:SetAttribute("Version", 5)
new:SetAttribute("SourceAssetId", "85604557082927")
new.Name = "moonlantern_carriage"
current.Parent = nil
new.Parent = folder
current:Destroy()
return "moonlantern_carriage v5 installed"
