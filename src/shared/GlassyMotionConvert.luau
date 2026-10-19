--!strict
-- Pure converter from the Blender motion manifests (docs/art/glassy_revamp/motion_manifest.json,
-- docs/art/launch_glassies/motion_manifest.json) to Config/GlassyMotion. Used by tools/gen_glassy_motion.luau and the
-- tests; no Roblox APIs, so it runs in Lune.
local Convert = {}

-- Parameter names: manifest snake_case -> config PascalCase.
local KEYS = {
	amp_deg = "AmpDeg",
	period_s = "Period",
	phase = "Phase",
	amp_studs = "AmpStuds",
	deg_per_s = "DegPerS",
	amp = "Amp",
	rate_hz = "RateHz",
	interval_s = "Interval",
	dur_s = "Duration",
	max_deg = "MaxDeg",
	gain = "Gain",
	freq_hz = "FreqHz",
	damping = "Damping",
	grow_s = "Grow",
	fall_studs = "FallStuds",
	deg = "Deg",
	studs = "Studs",
	factor = "Factor",
}

-- Required parameters per motion type (the runtime reads exactly these).
Convert.Idle = {
	sway = { "AmpDeg", "Period" },
	spin = { "DegPerS" },
	bob = { "AmpStuds", "Period" },
	pulse = { "Amp", "Period" },
	slosh = { "MaxDeg", "Gain", "FreqHz", "Damping" },
	flicker = { "Amp", "RateHz" },
	blink = { "Interval", "Duration" },
	drip = { "Period", "Grow", "FallStuds" },
}
Convert.Hit = {
	kick = { "Deg", "FreqHz", "Damping" },
	flare = { "Deg", "FreqHz", "Damping" },
	hop = { "Studs", "FreqHz", "Damping" },
	squash = { "Factor", "FreqHz", "Damping" },
	flash = { "Duration" },
	spin_boost = { "DegPerS", "Duration" },
}

local function motion(raw: any): any
	if type(raw) ~= "table" or raw.type == nil or raw.type == "static" or raw.type == "none" then
		return nil
	end
	local out: { [string]: any } = { Type = raw.type }
	for key, value in raw do
		if key ~= "type" then
			out[KEYS[key] or key] = value
		end
	end
	return out
end

local function unit(v: any): { number }
	local x, y, z = v[1] or 0, v[2] or 0, v[3] or 0
	local m = math.sqrt(x * x + y * y + z * z)
	if m < 1e-6 then
		return { 0, 1, 0 }
	end
	local function round(n: number): number
		return math.floor(n / m * 1e6 + 0.5) / 1e6
	end
	return { round(x), round(y), round(z) }
end

local function round3(v: any): { number }
	local out = {}
	for i = 1, 3 do
		out[i] = math.floor((v[i] or 0) * 1e5 + 0.5) / 1e5
	end
	return out
end

-- One glassy: keep parts that move (a pivot plus an idle or hit), order parents before followers.
function Convert.glassy(raw: any): any
	local parts = {}
	local byName = {}
	for _, p in raw.parts or {} do
		local idle = {}
		local first = motion(p.idle)
		if first then
			table.insert(idle, first)
		end
		for _, layer in p.idle_layers or {} do
			local m = motion(layer)
			if m then
				table.insert(idle, m)
			end
		end
		local hit = motion(p.hit)
		-- Static parts that ride a moving part (chips on a cookie) are kept so they move with it.
		if p.pivot_roblox and (#idle > 0 or hit or p.follows) then
			local entry = {
				Name = p.name,
				Body = p.role == "Body" or nil,
				Pivot = round3(p.pivot_roblox),
				Axis = unit(p.axis_roblox or { 0, 1, 0 }),
				Idle = idle,
				Hit = hit,
				Lod = p.lod_keep == true,
				Follows = p.follows,
				Neon = p.material == "Neon" or nil,
			}
			table.insert(parts, entry)
			byName[entry.Name] = entry
		end
	end
	-- Parents first: a stable topological order. A follower whose parent is missing (or was itself dropped) keeps
	-- its own motion; if it has none it is dropped too.
	local ordered, visited, kept = {}, {}, {}
	local function place(entry, depth)
		if visited[entry] or depth > 8 then
			return
		end
		visited[entry] = true
		local parent = entry.Follows and byName[entry.Follows]
		if parent then
			place(parent, depth + 1)
		end
		if entry.Follows and not (parent and kept[parent]) then
			entry.Follows = nil
		end
		if not entry.Follows and #entry.Idle == 0 and not entry.Hit then
			return
		end
		kept[entry] = true
		table.insert(ordered, entry)
	end
	for _, entry in parts do
		place(entry, 0)
	end
	return { Version = raw.version, Parts = ordered }
end

-- manifests: list of decoded manifest tables. Later manifests win on duplicate ids.
function Convert.config(manifests: { any }): any
	local glassies = {}
	for _, manifest in manifests do
		for id, raw in manifest.glassies or {} do
			local g = Convert.glassy(raw)
			if #g.Parts > 0 then
				glassies[id] = g
			end
		end
	end
	return { Glassies = glassies }
end

-- Returns a list of problems (empty when the config is usable by Presentation/GlassyMotion).
function Convert.validate(config: any): { string }
	local problems = {}
	for id, g in config.Glassies or {} do
		local seen = {}
		for _, p in g.Parts do
			local where = id .. "." .. tostring(p.Name)
			if p.Follows and not seen[p.Follows] then
				table.insert(problems, where .. " follows " .. p.Follows .. ", which is not earlier in the list")
			end
			seen[p.Name] = true
			local a = p.Axis
			if math.abs(math.sqrt(a[1] ^ 2 + a[2] ^ 2 + a[3] ^ 2) - 1) > 1e-3 then
				table.insert(problems, where .. " axis is not unit length")
			end
			for _, m in p.Idle do
				local need = Convert.Idle[m.Type]
				if not need then
					table.insert(problems, where .. " unknown idle " .. tostring(m.Type))
				else
					for _, key in need do
						if type(m[key]) ~= "number" then
							table.insert(problems, where .. " idle " .. m.Type .. " missing " .. key)
						end
					end
				end
			end
			if p.Hit then
				local need = Convert.Hit[p.Hit.Type]
				if not need then
					table.insert(problems, where .. " unknown hit " .. tostring(p.Hit.Type))
				else
					for _, key in need do
						if type(p.Hit[key]) ~= "number" then
							table.insert(problems, where .. " hit " .. p.Hit.Type .. " missing " .. key)
						end
					end
				end
			end
		end
	end
	return problems
end

-- Deterministic Luau source for the generated config (sorted keys, no trailing noise).
function Convert.serialize(value: any, indent: string?): string
	indent = indent or ""
	local t = type(value)
	if t == "string" then
		return string.format("%q", value)
	elseif t == "number" then
		if value == math.floor(value) and math.abs(value) < 1e9 then
			return tostring(math.floor(value))
		end
		return string.format("%.6g", value)
	elseif t == "boolean" then
		return tostring(value)
	elseif t ~= "table" then
		return "nil"
	end
	local inner = (indent :: string) .. "\t"
	if #value > 0 then
		local scalar = true
		for _, v in value do
			if type(v) == "table" then
				scalar = false
			end
		end
		local items = {}
		for _, v in value do
			table.insert(items, Convert.serialize(v, inner))
		end
		if scalar then
			return "{ " .. table.concat(items, ", ") .. " }"
		end
		return "{\n" .. inner .. table.concat(items, ",\n" .. inner) .. ",\n" .. indent .. "}"
	end
	local keys = {}
	for k in value do
		table.insert(keys, k)
	end
	table.sort(keys)
	if #keys == 0 then
		return "{}"
	end
	local items = {}
	for _, k in keys do
		local key = if string.match(k, "^[%a_][%w_]*$") then k else "[" .. string.format("%q", k) .. "]"
		table.insert(items, key .. " = " .. Convert.serialize(value[k], inner))
	end
	return "{\n" .. inner .. table.concat(items, ",\n" .. inner) .. ",\n" .. indent .. "}"
end

return Convert
