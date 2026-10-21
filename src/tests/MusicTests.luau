local Music = if script then require(game.ReplicatedStorage.Shared.Config.Music) else require("../shared/Config/Music")
return function(t)
	local function checkSound(name, entry)
		t.ok(type(entry.Id) == "string" and entry.Id:match("^rbxassetid://%d+$") ~= nil, name .. " has an asset id")
		t.ok(type(entry.Volume) == "number" and entry.Volume > 0 and entry.Volume <= 1, name .. " volume in 0-1")
		t.ok(type(entry.Length) == "number" and entry.Length > 0, name .. " has a length")
		t.ok(type(entry.Name) == "string" and entry.Name ~= "", name .. " has a name")
	end
	t.test("music beds and stings are valid", function()
		for name, track in Music.Tracks do
			checkSound(name, track)
			t.ok(track.Loop == "Crossfade" or track.Loop == "Looped", name .. " has a loop mode")
			if track.Loop == "Crossfade" then
				t.ok(track.Length > Music.LoopCrossfade * 2, name .. " is long enough to crossfade into itself")
			end
		end
		for name, sting in Music.Stings do
			checkSound(name, sting)
		end
		for _, name in { "Tension", "Win", "Lose" } do
			t.ok(Music.Stings[name] ~= nil, name .. " sting exists")
		end
	end)
	t.test("every playlist slot names a real track", function()
		for _, context in { "Lobby", "Fight", "Overtime" } do
			local list = Music.Playlists[context]
			t.ok(list ~= nil and #list > 0, context .. " playlist is not empty")
			for _, name in list do
				t.ok(Music.Tracks[name] ~= nil, context .. " -> " .. name .. " is a track")
			end
		end
	end)
	t.test("fades, delays and ducks are positive", function()
		for _, key in { "FadeIn", "FadeOut", "LoopCrossfade", "SwitchDelay", "ResultGap" } do
			t.ok(type(Music[key]) == "number" and Music[key] > 0, key .. " is positive")
		end
		for _, duck in { Music.Duck, Music.StingDuck } do
			t.ok(duck.Multiplier >= 0 and duck.Multiplier < 1, "duck multiplier in 0-1")
			t.ok(duck.FadeDown > 0 and duck.FadeUp > 0, "duck fades positive")
		end
		t.ok(Music.Duck.Hold > 0, "duck hold positive")
	end)
end
