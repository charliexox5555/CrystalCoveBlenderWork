--!strict
-- Surface cracks for the v5 glassies, generated from their shell outlines (tools/blender/build_buddies_v5.py):
-- rows are { ax, ay, az, bx, by, bz, stage } in model space, front = +Z, Y = -depth below the hang point.
-- Cracks start beside the face and run outward, so expressions stay readable.
local Shells: { [string]: { any } } = {
	pop = {
		{ 0.34, 0.22 },
		{ 0.42, 0.62 },
		{ 0.80, 1.00 },
		{ 0.98, 1.42 },
		{ 1.02, 1.95 },
		{ 0.98, 2.42 },
		{ 0.78, 2.72 },
	},
	jam = { { 1.14, 0.42 }, { 1.30, 0.70 }, { 1.38, 1.15 }, { 1.38, 1.70 }, { 1.26, 2.12 }, { 0.96, 2.32 } },
	prism = { { 0.30, 0.62 }, { 0.98, 1.05 }, { 1.20, 1.50 }, { 0.98, 2.10 }, { 0.42, 2.58 } },
	glass_cup = { { 0.94, 0.40 }, { 0.86, 1.10 }, { 0.76, 1.70 }, { 0.64, 1.92 } },
	water_jug = { { 0.62, 0.84 }, { 1.12, 1.30 }, { 1.40, 1.90 }, { 1.42, 2.46 }, { 1.20, 2.86 } },
	ketchup_bottle = { { 0.50, 0.86 }, { 0.80, 1.34 }, { 0.94, 2.00 }, { 0.96, 2.52 }, { 0.76, 2.80 } },
}
local STAGES = { { 1, 2, 5 }, { 2, 3, 6 }, { 3, 4, 7 } } -- stage, crack count, segments per crack

local function radiusAt(shell: { any }, depth: number): number
	for i = 1, #shell - 1 do
		local a, b = shell[i], shell[i + 1]
		if depth >= a[2] and depth <= b[2] then
			return a[1] + (b[1] - a[1]) * (depth - a[2]) / (b[2] - a[2])
		end
	end
	return shell[#shell][1]
end

local function point(shell: { any }, depth: number, angle: number): (number, number, number)
	local r = radiusAt(shell, depth) + 0.02
	return r * math.sin(angle), -depth, r * math.cos(angle)
end

local function round(n: number): number
	return math.round(n * 1000) / 1000
end

local function build(id: string, shell: { any }): { { number } }
	local seed = 0
	for i = 1, #id do
		seed = (seed * 31 + string.byte(id, i)) % 2147483647
	end
	local function random(low: number, high: number): number
		seed = (seed * 48271) % 2147483647
		return low + (high - low) * (seed / 2147483647)
	end
	local top, bottom = shell[1][2] + 0.05, shell[#shell][2] - 0.1
	local rows = {}
	for _, stage in STAGES do
		for _ = 1, stage[2] do
			local side = if random(0, 1) < 0.5 then -1 else 1
			local angle, depth = side * random(0.75, 1.5), random(top, bottom)
			for _ = 1, stage[3] do
				local nextDepth = math.clamp(depth + random(-0.3, 0.3), top, bottom)
				local nextAngle = angle + side * random(0.04, 0.24)
				local ax, ay, az = point(shell, depth, angle)
				local bx, by, bz = point(shell, nextDepth, nextAngle)
				table.insert(rows, { round(ax), round(ay), round(az), round(bx), round(by), round(bz), stage[1] })
				depth, angle = nextDepth, nextAngle
			end
		end
	end
	return rows
end

local Cracks: { [string]: { { number } } } = {}
for id, shell in Shells do
	Cracks[id] = build(id, shell)
end
return Cracks
