-- Client-only developer art preview. All results are staged inputs, never gameplay claims.
-- Run the returned factory in the Client DataModel after cloning CombatReleaseArtPreview into RS.
return function()
	local RunService = game:GetService("RunService")
	assert(RunService:IsClient(), "Client preview only")
	local RS = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local assets = RS:WaitForChild("CombatReleaseArtPreview")
	local root = Instance.new("Folder")
	root.Name = "CombatRelease_StagedVFXPreview"
	root:SetAttribute("PreviewOnly", true)
	root:SetAttribute("StagedResults", true)
	root.Parent = workspace
	local preview =
		{ Root = root, Fighters = {}, Result = "hit", Audio = false, Cycle = -1, Emitted = {}, SoundsPlayed = 0 }
	preview.Hidden = {}
	for _, gui in game.Players.LocalPlayer.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") then
			preview.Hidden[gui], gui.Enabled = gui.Enabled, false
		end
	end
	local captionGui = Instance.new("ScreenGui")
	captionGui.Name, captionGui.ResetOnSpawn = "CombatArtPreviewCaption", false
	captionGui.Parent = game.Players.LocalPlayer.PlayerGui
	local caption = Instance.new("TextLabel")
	caption.AnchorPoint, caption.Position = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.06)
	caption.Size, caption.BackgroundTransparency = UDim2.fromOffset(700, 35), 0.25
	caption.BackgroundColor3, caption.TextColor3 = Color3.fromRGB(20, 28, 48), Color3.new(1, 1, 1)
	caption.Font, caption.TextSize, caption.Parent = Enum.Font.GothamBold, 16, captionGui
	local camera = workspace.CurrentCamera
	local old = { Type = camera.CameraType, CFrame = camera.CFrame, FOV = camera.FieldOfView }
	local scale = 1.75
	local ids = { "pop", "jam", "prism", "crescent_axe", "briar_flask", "arc_coil" }
	local function primitive(name, parent)
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = name, true, false, false, false
		p.CastShadow, p.Material = false, Enum.Material.Neon
		p.Parent = parent
		return p
	end
	local function label(parent, text, position, width)
		local anchor = primitive("PreviewCaption", parent)
		anchor.Size, anchor.Transparency, anchor.Position = Vector3.one * 0.1, 1, position
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.AlwaysOnTop = UDim2.fromOffset(width or 150, 42), true
		gui.Parent = anchor
		local l = Instance.new("TextLabel")
		l.Size, l.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		l.Font, l.TextSize, l.Text = Enum.Font.GothamBold, 16, text
		l.TextColor3, l.TextStrokeTransparency = Color3.new(1, 1, 1), 0.2
		l.Parent = gui
		return l
	end
	preview.Caption = caption
	for index, id in ids do
		local source = assets.Glassies[id]
		local model = Instance.new("Model")
		model.Name, model.WorldPivot = id, CFrame.identity
		source.Body:Clone().Parent = model
		local details = {}
		for _, p in source.Details:GetChildren() do
			if not p:GetAttribute("EffectOnly") then
				local copy = p:Clone()
				copy.Parent = model
				details[p.Name] = copy
			end
		end
		model:ScaleTo(scale)
		model.Parent = root
		local origin = Vector3.new((index - 3.5) * 6, 25, 2000)
		local f = {
			Id = id,
			Model = model,
			Source = source,
			Details = details,
			Origin = origin,
			Body = model.Body,
			Pieces = {},
		}
		f.Color = f.Body.Color
		f.Effects = Instance.new("Folder")
		f.Effects.Name, f.Effects.Parent = "Effects_" .. id, root
		for _, name in { "Ring", "GuardPlate", "CurvedSlash", "Thorn", "BubbleDome" } do
			local p = assets.Combat.Meshes[name]:Clone()
			p.Name, p.Color, p.Parent = name, f.Color, f.Effects
			p:SetAttribute("BaseSize", p.Size)
			f[name] = p
		end
		f.Ray = primitive("LockedDirectionRay", f.Effects)
		f.Ray.Color = f.Color
		local hook = primitive("Hook", root)
		hook.Position, hook.Transparency, hook.Size = origin + Vector3.yAxis * 7, 1, Vector3.one * 0.1
		local at0, at1 = Instance.new("Attachment"), Instance.new("Attachment")
		at0.Parent, at1.Parent = hook, f.Body
		at1.CFrame = f.Body.PivotOffset
		local rope = Instance.new("Beam")
		rope.Name, rope.Attachment0, rope.Attachment1 = "PreviewString", at0, at1
		rope.Width0, rope.Width1, rope.FaceCamera = 0.04, 0.04, true
		rope.Color, rope.Parent = ColorSequence.new(Color3.fromRGB(242, 234, 216)), model
		f.Rope = rope
		local mount = Instance.new("Attachment")
		mount.Name, mount.Parent = "ContactOrigin", f.Body
		mount.Position = Vector3.new(0, 0, 1.4)
		for _, template in assets.Combat.Particles:GetChildren() do
			local e = template:Clone()
			e.Color, e.Parent = ColorSequence.new(f.Color), mount
		end
		f.Emitters = mount
		local weapon = assets.Combat.Kits.crescent_axe.CrescentWeapon:Clone()
		weapon:ScaleTo(scale)
		weapon.Parent = f.Effects
		f.Weapon = weapon
		for _, p in weapon:GetChildren() do
			p.Transparency = 1
		end
		for _, template in source.Shards:GetChildren() do
			local p = template:Clone()
			p.Size *= scale
			p.PivotOffset = CFrame.new(p.PivotOffset.Position * scale) * p.PivotOffset.Rotation
			p.Transparency, p.Parent = 1, f.Effects
			table.insert(f.Pieces, p)
		end
		f.Caption = label(root, id:gsub("_", " "), origin + Vector3.new(0, -5, 0))
		preview.Fighters[index] = f
	end
	function preview:Sound(name, f)
		if not self.Audio then
			return
		end
		local template = assets.Combat.Audio:FindFirstChild(name)
		if not template then
			return
		end
		local s = template:Clone()
		self.SoundsPlayed += 1
		s.Volume *= 0.7
		s.Parent = f.Body
		s.TimePosition = template:GetAttribute("StartSeconds") or 0
		s:Play()
		local duration = template:GetAttribute("PreviewSeconds") or 0.5
		local fade = template:GetAttribute("FadeSeconds") or 0.035
		task.delay(math.max(0, duration - fade), function()
			if s.Parent then
				TweenService:Create(s, TweenInfo.new(fade), { Volume = 0 }):Play()
			end
		end)
		game:GetService("Debris"):AddItem(s, duration)
	end
	function preview:Emit(f, name)
		local e = f.Emitters:FindFirstChild(name)
		if e then
			e:Emit(e:GetAttribute("BurstCount"))
			self.Emitted[name] = (self.Emitted[name] or 0) + e:GetAttribute("BurstCount")
		end
	end
	function preview:At(t, result)
		result = result or self.Result
		local cycle, phase = math.floor(t / 5), t % 5
		if cycle ~= self.Cycle then
			self.Cycle, self.Released, self.Contacted, self.Shattered = cycle, false, false, false
			for _, f in self.Fighters do
				for _, e in f.Emitters:GetChildren() do
					e:Clear()
				end
			end
		end
		self.Caption.Text = "ART PREVIEW • staged " .. result .. " • no gameplay damage"
		for index, f in self.Fighters do
			local motion =
				Vector3.new(math.sin(t * 2 + index) * 0.4, math.cos(t * 4 + index) * 0.12, math.sin(t + index) * 0.15)
			local pivot = CFrame.new(f.Origin + motion) * CFrame.Angles(0, math.sin(t * 2 + index) * 0.08, 0)
			f.Model:PivotTo(pivot)
			local shattered = phase >= 3.2
			for _, p in f.Model:GetChildren() do
				if p:IsA("BasePart") then
					p.Transparency = if shattered then 1 else (if p.Name == "Body" then 0.28 else 0)
				end
			end
			f.Rope.Enabled = not shattered
			for _, p in { f.Ring, f.GuardPlate, f.CurvedSlash, f.Thorn, f.BubbleDome, f.Ray } do
				p.Transparency = 1
			end
			for _, p in f.Weapon:GetChildren() do
				p.Transparency = 1
			end
			local charge = math.clamp(phase / 1.2, 0, 1)
			for name, p in f.Details do
				if name:find("ChargeBubble") or name:find("CoilSegment") or name:find("Thorn_") then
					local number = tonumber(name:match("_(%d+)")) or 1
					local on = charge * 3 >= number and phase < 1.65
					p.Transparency = if shattered then 1 elseif on then 0.08 else 0.8
					p.Material = if on then Enum.Material.Neon else Enum.Material.Glass
				end
			end
			local center = f.Body.Position
			if phase < 1.5 and not shattered then
				f.Ring.Size = f.Ring:GetAttribute("BaseSize") * (1.5 + charge * 0.5)
				f.Ring.CFrame, f.Ring.Transparency = CFrame.new(center + Vector3.new(0, 0, 1.1)), 0.7 - charge * 0.3
			end
			if f.Id == "jam" and phase >= 1.2 and phase < 2.8 then
				f.GuardPlate.Size = f.GuardPlate:GetAttribute("BaseSize") * scale
				f.GuardPlate.CFrame, f.GuardPlate.Transparency = CFrame.new(center + Vector3.new(1.6, 0, 1.8)), 0.3
				f.GuardPlate.Color, f.GuardPlate.Material = Color3.fromRGB(214, 171, 83), Enum.Material.Glass
			elseif f.Id == "crescent_axe" and phase >= 1.1 and phase < 2.0 then
				local sweep = math.clamp((phase - 1.5) / 0.14, 0, 1)
				f.Weapon:PivotTo(
					CFrame.new(center + Vector3.new(0.5, 0, 1.3)) * CFrame.Angles(0, 0, math.rad(-85 + sweep * 155))
				)
				for _, p in f.Weapon:GetChildren() do
					p.Transparency = math.clamp((phase - 1.75) / 0.25, 0, 1)
				end
				f.CurvedSlash.Size = f.CurvedSlash:GetAttribute("BaseSize") * scale
				f.CurvedSlash.CFrame, f.CurvedSlash.Transparency =
					CFrame.new(center + Vector3.new(1.2, 0, 1.4)), if phase < 1.5 then 1 else 0.4
			elseif (f.Id == "prism" or f.Id == "arc_coil") and phase >= 1.5 and phase < 1.8 then
				-- Fixed release direction; a miss never bends toward an invented impact.
				local dir = if result == "miss" then Vector3.new(1, 0.4, -0.5).Unit else Vector3.xAxis
				local length = 2.8
				f.Ray.Size = Vector3.new(if f.Id == "arc_coil" then 0.16 else 0.1, 0.1, length)
				f.Ray.CFrame, f.Ray.Transparency =
					CFrame.lookAt(center + dir * length / 2, center + dir * length), (phase - 1.5) / 0.3
			elseif (f.Id == "pop" or f.Id == "briar_flask") and phase >= 1.5 and phase < 1.9 then
				local u = (phase - 1.5) / 0.4
				f.Ring.Size = f.Ring:GetAttribute("BaseSize") * (2 + u * 1.2)
				f.Ring.CFrame, f.Ring.Transparency = CFrame.new(center + Vector3.new(0, 0, 1.1)), 0.15 + u * 0.85
			end
			for i, p in f.Pieces do
				local u = math.clamp((phase - 3.2) / 0.7, 0, 1)
				local angle = i * 2.399963
				local delta =
					Vector3.new(math.cos(angle) * u * 1.5, -u * u * 2 + math.sin(i) * u, math.sin(angle) * u * 1.1)
				p:PivotTo(pivot * CFrame.new(delta) * CFrame.Angles(u * math.sin(i), u * math.cos(i), 0))
				p.Transparency = if not shattered then 1 else 0.28 + math.clamp((phase - 3.7) / 0.6, 0, 1) * 0.72
			end
		end
		if phase >= 1.5 and not self.Released then
			self.Released = true
			for _, f in self.Fighters do
				self:Sound(assets.Combat.Kits[f.Id]:GetAttribute("ReleaseSound"), f)
			end
			self:Emit(self.Fighters[1], "PressurePop")
		end
		if phase >= 1.65 and not self.Contacted then
			self.Contacted = true
			if result ~= "miss" then
				for _, f in self.Fighters do
					self:Emit(f, "ContactGlint")
					self:Sound(if result == "block" then "LidBlock" else "ClinkLightA", f)
				end
			end
		end
		if phase >= 3.2 and not self.Shattered then
			self.Shattered = true
			for _, f in self.Fighters do
				self:Emit(f, "GlassDust")
				self:Emit(f, "GlassChips")
			end
			self:Sound("ShatterHeavy", self.Fighters[1])
		end
		camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 52
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 26, 2033), Vector3.new(0, 26, 2000))
	end
	function preview:Play(seconds)
		if self.Connection then
			self.Connection:Disconnect()
		end
		local start = os.clock()
		self.Connection = RunService.RenderStepped:Connect(function()
			if not root.Parent or os.clock() - start > seconds then
				self:Destroy()
				return
			end
			self:At(os.clock() - start, self.Result)
		end)
	end
	function preview:Destroy()
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
		end
		root:Destroy()
		captionGui:Destroy()
		for gui, enabled in self.Hidden do
			if gui.Parent then
				gui.Enabled = enabled
			end
		end
		camera.CameraType, camera.CFrame, camera.FieldOfView = old.Type, old.CFrame, old.FOV
	end
	preview:At(0, "hit")
	return preview
end
