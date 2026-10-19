-- Play / Client (Studio MCP execute_luau): silently measures finisher sounds with AudioPlayer -> AudioAnalyzer
-- (no output device, so nothing is heard). Prints onset, peak time, peak RMS and length per id so trims in
-- Config/AudioCues can be matched to the approved bank. Cleans up after itself.
local SoundService = game:GetService("SoundService")
local ids = _G.FinisherSoundIds
	or {
		FN_MagicBurst = "rbxassetid://9116385087",
		FN_GlowSwell = "rbxassetid://9116393976",
		FN_PunchyPoof = "rbxassetid://9125640290",
		FN_GlassPing = "rbxassetid://9126073644",
		-- Reference bank sounds (already approved) for level matching.
		SafetyGlass = "rbxassetid://9118763987",
		MagicPoof = "rbxassetid://9116406610",
		SoftBoom = "rbxassetid://9125404320",
	}
local folder = Instance.new("Folder")
folder.Name = "FinisherSoundMeasure"
folder.Parent = SoundService
local results = {}
local jobs = 0
for name, asset in ids do
	jobs += 1
	task.spawn(function()
		local player = Instance.new("AudioPlayer")
		player.Asset = asset
		player.Parent = folder
		local analyzer = Instance.new("AudioAnalyzer")
		analyzer.Parent = folder
		local wire = Instance.new("Wire")
		wire.SourceInstance, wire.TargetInstance = player, analyzer
		wire.Parent = folder
		local t0 = os.clock()
		while not player.IsReady and os.clock() - t0 < 8 do
			task.wait(0.05)
		end
		if not player.IsReady then
			results[name] = "not ready"
			jobs -= 1
			return
		end
		local length = player.TimeLength
		player:Play()
		local start = os.clock()
		local samples = {}
		while os.clock() - start < math.min(length, 4) + 0.1 do
			table.insert(samples, { os.clock() - start, analyzer.RmsLevel, analyzer.PeakLevel })
			task.wait(0.03)
		end
		local peak, peakAt = 0, 0
		for _, s in samples do
			if s[2] > peak then
				peak, peakAt = s[2], s[1]
			end
		end
		local onset, tail = nil, 0
		for _, s in samples do
			if not onset and s[2] > peak * 0.15 then
				onset = s[1]
			end
			if s[2] > peak * 0.1 then
				tail = s[1]
			end
		end
		results[name] = string.format(
			"len %.2f s, onset %.2f, peak %.3f at %.2f, audible until %.2f",
			length,
			onset or -1,
			peak,
			peakAt,
			tail
		)
		jobs -= 1
	end)
end
local t0 = os.clock()
while jobs > 0 and os.clock() - t0 < 20 do
	task.wait(0.1)
end
folder:Destroy()
local lines = {}
for name, line in results do
	table.insert(lines, name .. ": " .. line)
end
table.sort(lines)
return table.concat(lines, "\n")
