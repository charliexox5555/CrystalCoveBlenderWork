-- Rider animation families (Config/RideFamilies + RideKeyframes): every family is complete, loops are seamless,
-- one-shots start and end on the base pose, mirrors are symmetric and every flyer names a real family.
local Shared = if script then game.ReplicatedStorage.Shared else nil
local K = if Shared then require(Shared.RideKeyframes) else require("../shared/RideKeyframes")
local F = if Shared then require(Shared.Config.RideFamilies) else require("../shared/Config/RideFamilies")

local function close(t, a, b, eps, msg)
	for _, channel in K.Channels do
		local x, y = a[channel] or { 0, 0, 0 }, b[channel] or { 0, 0, 0 }
		for i = 1, 3 do
			t.near(x[i], y[i], eps, ("%s %s[%d]"):format(msg, channel, i))
		end
	end
end

return function(t)
	t.test("every family has all five clips and a contact mode", function()
		for name, family in F.Families do
			t.ok(family.Contact == "Feet" or family.Contact == "Seat" or family.Contact == "Low", name .. " contact")
			for _, clipName in F.ClipNames do
				t.ok(K.clip(name, clipName) ~= nil, name .. "." .. clipName)
			end
		end
	end)
	t.test("loops are seamless and one-shots start and end on the base pose", function()
		for name in F.Families do
			for _, clipName in F.ClipNames do
				local clip = K.clip(name, clipName)
				if F.Loops[clipName] then
					close(
						t,
						K.sample(name, clipName, 0),
						K.sample(name, clipName, clip.Seconds),
						1e-6,
						name .. clipName
					)
				else
					local plain = F.Families[name].Base
					close(t, K.sample(name, clipName, 0), plain, 1e-6, name .. clipName .. " start")
					close(t, K.sample(name, clipName, clip.Seconds), plain, 1e-6, name .. clipName .. " end")
				end
			end
		end
	end)
	t.test("LeanRight mirrors LeanLeft and leans the other way", function()
		for name in F.Families do
			local l, r = K.sample(name, "LeanLeft", 0.3, false), K.sample(name, "LeanRight", 0.3, false)
			local lr, rr = l.Root or { 0, 0, 0 }, r.Root or { 0, 0, 0 }
			t.near(lr[3], -rr[3], 1e-6, name .. " root roll mirrored")
			t.ok(lr[3] > 0, name .. " LeanLeft rolls left")
		end
	end)
	t.test("angles stay in a sane range and R6 maps every limb", function()
		for name in F.Families do
			for _, clipName in F.ClipNames do
				local clip = K.clip(name, clipName)
				for i = 0, 10 do
					local pose = K.sample(name, clipName, clip.Seconds * i / 10)
					for channel, a in pose do
						for axis = 1, 3 do
							t.between(a[axis], -150, 150, name .. clipName .. channel)
						end
					end
					local r6 = K.toR6(name, pose)
					for _, c in { "Root", "Head", "LeftArm", "RightArm", "LeftHip", "RightHip" } do
						t.ok(r6[c] ~= nil, name .. " R6 " .. c)
					end
				end
			end
		end
	end)
	t.test("every flyer rides a real family; handle families have a standard grip layout", function()
		for id, def in F.Flyers do
			local family = F.Families[def.Family]
			t.ok(family ~= nil, id .. " family")
			if family.Handles then
				t.ok(F.StandardGrips[def.Family] ~= nil, id .. " grip layout")
			end
		end
	end)
end
