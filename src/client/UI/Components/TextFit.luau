-- One text-fit policy for every label, button and box in the UI (workstream J). Text never leaves its box:
--   1. TextScaled inside a UITextSizeConstraint (Theme.TextFit.Min .. the authored/Theme maximum);
--   2. if even the minimum doesn't fit on one line and the box has room for two lines, wrap;
--   3. still too long: allow down to Theme.TextFit.MinSmall (one line, then two), then on down to
--      Theme.TextFit.MinWord (9, Roblox's readability floor for MinTextSize) rather than be cut;
--   4. if it still doesn't fit, draw at that floor and end with "…" (TextTruncate.AtEnd).
-- So text shrinks first, then goes to two lines, and is only cut when it would otherwise be unreadably small.
-- TextFit.guard(PlayerGui) applies it to everything in the UI, templates included; TextFit.apply sets a
-- label's own policy (attributes FitMin / FitLines) for code that builds labels.
-- Opt out with the attribute TextFit = false (counters with AutomaticSize grow instead and are skipped).
local Theme = require(script.Parent.Parent.Theme)
local TextFit = {}

local Fit = Theme.TextFit
local bound = setmetatable({}, { __mode = "k" })
local PROPS = { "TextScaled", "TextWrapped", "TextTruncate", "TextSize" }

local function constraint(label)
	return label:FindFirstChildOfClass("UITextSizeConstraint")
end

-- Height left for glyphs once UIPadding and a text outline are taken off.
local function room(label)
	local size = label.AbsoluteSize
	local pad = label:FindFirstChildOfClass("UIPadding")
	local h = size.Y
	if pad then
		h -= pad.PaddingTop.Offset + pad.PaddingBottom.Offset + (pad.PaddingTop.Scale + pad.PaddingBottom.Scale) * size.Y
	end
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke and stroke.Enabled and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
		h -= stroke.Thickness -- line spacing covers part of the outline
	end
	return h
end

-- TopbarPlus (TopbarStandard/Centered and their Clipped copies) sizes its own labels from TextBounds; scaling them
-- would fight its layout.
local function inTopbar(label)
	local gui = label:FindFirstAncestorOfClass("ScreenGui")
	return gui ~= nil and string.sub(gui.Name, 1, 6) == "Topbar"
end

local function eligible(label)
	return (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox"))
		and label:GetAttribute("TextFit") ~= false
		and label.AutomaticSize == Enum.AutomaticSize.None
		and not inTopbar(label)
end

local states = setmetatable({}, { __mode = "k" })

local function bind(label)
	if bound[label] or not eligible(label) then
		return
	end
	-- `base` is what the label's owner wants. `final` is what TextFit left each property at last time, so
	-- anything different at the next pass was set by someone else (a screen switching a label to wrapped,
	-- say) and becomes the new base instead of being undone. Comparing at evaluation time, not in the
	-- change signals, keeps this right under deferred signals.
	local base, final = {}, {}
	for _, prop in PROPS do
		base[prop] = label[prop]
	end
	local c = constraint(label)
	local baseMin = if c then c.MinTextSize else nil
	local finalMin = baseMin
	local busy = false
	local function set(object, prop, value)
		if object[prop] ~= value then
			object[prop] = value
		end
	end
	local function evaluate()
		if busy or not label.Parent then
			return
		end
		busy = true
		for _, prop in PROPS do
			if final[prop] ~= nil and label[prop] ~= final[prop] then
				base[prop] = label[prop]
			end
		end
		c = constraint(label)
		if c and finalMin ~= nil and c.MinTextSize ~= finalMin then
			baseMin = c.MinTextSize
		end
		for _, prop in PROPS do
			set(label, prop, base[prop])
		end
		local h = room(label)
		if label.Text ~= "" and h >= 1 and label.AbsoluteSize.X >= 1 then
			local minimum = label:GetAttribute("FitMin") or Fit.Min
			-- Never ask for more than the box can hold; a box smaller than the minimum is a layout problem.
			minimum = math.max(1, math.min(minimum, math.floor(h)))
			local lines = label:GetAttribute("FitLines") or Fit.Lines
			c = constraint(label)
			if not label.TextScaled and not label.TextFits then
				-- Fixed-size text that doesn't fit: let it scale down from its authored size.
				if not c then
					c = Instance.new("UITextSizeConstraint")
					c.Name = "TextFitLimit"
					c.MaxTextSize = math.max(minimum, label.TextSize)
					c.Parent = label
					baseMin = nil
				end
				set(label, "TextScaled", true)
			end
			-- Try the preferred floor, then the small floor; at each, one line and then two.
			-- (An authored minimum above ours is tried first: designers raise it on purpose.)
			local small = math.max(1, math.min(Fit.MinSmall, minimum))
			local floors = { math.min(math.max(baseMin or 1, minimum), math.max(1, math.floor(h))), minimum, small }
			table.insert(floors, math.max(1, math.min(Fit.MinWord, small)))
			for _, floor in floors do
				if c and label.TextScaled then
					c.MinTextSize = floor
				end
				if label.TextFits then
					break
				end
				if not label.TextWrapped and lines > 1 and h >= floor * 2.2 then
					set(label, "TextWrapped", true)
					if label.TextFits then
						break
					end
					set(label, "TextWrapped", base.TextWrapped)
				end
			end
			if not label.TextFits and label:IsA("TextBox") then
				-- Never cut what someone is typing: it stays scaled at the floor and scrolls.
				label:SetAttribute("TextFitCut", nil)
			elseif not label.TextFits then
				if not base.TextWrapped and lines > 1 and h >= small * 2.2 then
					set(label, "TextWrapped", true)
				end
				local size = if c and label.TextScaled then c.MinTextSize else math.min(label.TextSize, small)
				set(label, "TextScaled", false)
				set(label, "TextSize", size)
				set(label, "TextTruncate", Enum.TextTruncate.AtEnd)
				label:SetAttribute("TextFitCut", true)
			elseif label:GetAttribute("TextFitCut") then
				label:SetAttribute("TextFitCut", nil)
			end
		end
		for _, prop in PROPS do
			final[prop] = label[prop]
		end
		c = constraint(label)
		finalMin = if c then c.MinTextSize else nil
		busy = false
	end
	local queued = false
	local function schedule()
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				evaluate()
			end)
		end
	end
	bound[label] = true
	states[label] = { Base = base, Schedule = schedule }
	-- Luau weak keys are not ephemerons: this state's closures reference the label, so the entry would keep
	-- every destroyed label (and its closures) alive forever. Drop it when the label goes.
	label.Destroying:Connect(function()
		states[label], bound[label] = nil, nil
	end)
	for _, prop in PROPS do
		label:GetPropertyChangedSignal(prop):Connect(function()
			if not busy and label[prop] ~= final[prop] then
				schedule() -- someone else's change; evaluate() adopts it as the new base
			end
		end)
	end
	for _, prop in { "Text", "AbsoluteSize", "FontFace", "RichText", "Visible" } do
		label:GetPropertyChangedSignal(prop):Connect(schedule)
	end
	label.ChildAdded:Connect(function(child)
		if child:IsA("UITextSizeConstraint") and child.Name ~= "TextFitLimit" then
			baseMin, finalMin = child.MinTextSize, child.MinTextSize
			schedule()
		end
	end)
	evaluate()
end

-- Changes what a label's owner wants (e.g. TextScaled on, TextWrapped off) even if TextFit already
-- adjusted it this frame, then refits.
function TextFit.prefer(label, props)
	local state = states[label]
	for prop, value in props do
		label[prop] = value
		if state then
			state.Base[prop] = value
		end
	end
	if state then
		state.Schedule()
	end
end

-- Explicit policy for a label built in code. kind: "Line" (names, buttons: one line, may wrap to two),
-- "Body" (descriptions: wrap, up to Theme.TextFit.BodyLines), "Small" (tags and chips: lower minimum).
function TextFit.apply(label, kind, maxSize)
	label.TextScaled = true
	if kind == "Body" then
		label.TextWrapped = true
		label:SetAttribute("FitLines", Fit.BodyLines)
	elseif kind == "Small" then
		label:SetAttribute("FitMin", Fit.MinSmall)
	end
	local c = constraint(label) or Instance.new("UITextSizeConstraint")
	c.MinTextSize = if kind == "Small" then Fit.MinSmall else Fit.Min
	if maxSize then
		c.MaxTextSize = maxSize
	end
	c.Parent = label
	bind(label)
	return label
end

-- Every text object under `root`, now and later.
function TextFit.guard(root)
	for _, object in root:GetDescendants() do
		bind(object)
	end
	return root.DescendantAdded:Connect(function(object)
		-- Builders parent first and set Text/size after; bind once this frame's construction is done.
		task.defer(bind, object)
	end)
end

TextFit.bind = bind
return TextFit
