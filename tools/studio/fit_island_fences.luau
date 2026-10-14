-- Edit-only, fitted to the exact exported grass rims. Never rerun over edited fences.
-- Original manually placed perimeter models/bridge rails are moved to ServerStorage.Unsorted.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
-- BEGIN_GENERATED_RIMS
local Paths = game:GetService("HttpService"):JSONDecode(
	[==[{"Isle_Lobby":{"Size":[96,56],"Points":[[47.0677948,-0.5938856],[46.4498193,-7.2326855],[44.9874072,-13.7459464],[43.2783015,-20.1530564],[38.3782759,-24.5989237],[32.4244787,-27.4645135],[25.8138618,-28.0],[19.1734134,-27.6760241],[12.5314956,-27.3797148],[5.8834403,-27.2924789],[-0.7653275,-27.2858715],[-7.4140951,-27.2918376],[-14.0621574,-27.3800192],[-20.7068972,-27.6110729],[-27.3536705,-27.6583479],[-33.9181058,-26.6892338],[-40.158274,-24.4052456],[-44.5882566,-19.7805078],[-45.2158528,-13.142136],[-46.7653762,-6.6502619],[-47.3096629,-0.0045782],[-47.8969102,6.6422783],[-48.0,13.2825247],[-44.5966088,18.9236525],[-39.3310721,22.8992586],[-32.8700686,24.4166727],[-26.3745305,25.8292588],[-19.87937,27.2402537],[-13.2615932,27.8508629],[-6.6147003,27.9902987],[0.034059,28.0],[6.6828166,27.9903891],[13.3295332,27.8434452],[19.9507504,27.2614664],[26.4957822,26.0938431],[33.0013537,24.7174426],[39.0628426,22.0855735],[44.3780552,18.0749407],[48.0,12.6978443],[47.5995388,6.0566949]],"NorthGate":true,"SouthGate":false},"Isle_Arena1":{"Size":[92,46],"Points":[[45.4534229,0.442849],[46.0,-5.623747],[45.7804928,-11.649513],[42.1998759,-16.5231602],[36.8430058,-19.249476],[30.8225257,-20.162063],[24.8457145,-21.3267363],[18.8556397,-22.4177641],[12.7836981,-22.8785583],[6.6937339,-22.9901823],[0.6024961,-23.0],[-5.488754,-22.9968554],[-11.5793771,-22.9207123],[-17.6608399,-22.5912538],[-23.7079161,-21.8664419],[-29.7217956,-20.8991658],[-35.5508951,-19.2002783],[-40.6966929,-15.9464674],[-45.4705901,-12.2642381],[-46.0,-6.3262675],[-45.3384941,-0.2710375],[-44.795502,5.7908206],[-43.3436179,11.7110829],[-40.803209,17.1253788],[-35.8754774,20.6997038],[-30.1991549,22.7662443],[-24.1196046,23.0],[-18.0348084,22.7222442],[-11.9477228,22.5023124],[-5.8569184,22.4357769],[0.2343281,22.4292098],[6.3255803,22.430451],[12.4166479,22.4723258],[18.5065415,22.5996875],[24.5970663,22.645254],[30.6605809,22.1206383],[36.5937147,20.7540859],[42.0509627,18.201064],[43.2752955,12.3889125],[44.7261314,6.479929]],"NorthGate":true,"SouthGate":true},"Isle_Arena2":{"Size":[92,46],"Points":[[45.6127657,-0.2876861],[45.1609725,-6.3921407],[43.8909657,-12.3798414],[40.1085763,-17.0417319],[35.3281489,-20.8690121],[29.6076588,-22.853894],[23.4835018,-23.0],[17.3568716,-22.778803],[11.2279621,-22.6380395],[5.0974548,-22.5998524],[-1.0331958,-22.595025],[-7.1638489,-22.5926209],[-13.2944963,-22.5999657],[-19.425065,-22.5840775],[-25.5482995,-22.3120822],[-31.6234147,-21.5023785],[-37.6653886,-20.4654056],[-43.082147,-17.9184333],[-43.8624543,-11.9241935],[-45.1798609,-5.9446646],[-45.6424013,0.1563538],[-46.0,6.2712907],[-45.3288522,12.3172402],[-42.3841459,17.6260264],[-36.7192988,19.7172875],[-30.6262024,20.390295],[-24.6113784,21.5652125],[-18.5617841,22.5375126],[-12.4437268,22.9079269],[-6.3138119,22.9922501],[-0.1831671,23.0],[5.9474849,22.9983367],[12.0777355,22.9369164],[18.20338,22.6981889],[24.3161996,22.2350453],[30.3944092,21.4541089],[36.0095976,19.1483834],[41.047945,15.6938421],[45.6787267,11.8676811],[46.0,5.8236673]],"NorthGate":true,"SouthGate":true},"Isle_Arena3":{"Size":[92,46],"Points":[[45.7109718,-0.2162289],[45.3698708,-6.3469461],[44.2052135,-12.3658353],[40.1586272,-16.8278362],[35.412311,-20.7139049],[29.7197645,-22.8035647],[23.5787641,-23.0],[17.4321889,-22.8345048],[11.2843158,-22.7303358],[5.1355641,-22.7016077],[-1.0132652,-22.6969182],[-7.1620953,-22.6926494],[-13.3109151,-22.6812877],[-19.4590606,-22.6011162],[-25.5937802,-22.2095855],[-31.6800751,-21.3407505],[-37.7611544,-20.4324591],[-43.2648242,-18.0253718],[-44.1710133,-12.0385564],[-45.3812958,-6.0182781],[-45.7673835,0.1070468],[-46.0,6.245478],[-45.2748629,12.3176801],[-42.7130718,17.8248832],[-37.0185225,19.8693989],[-30.9037756,20.5111442],[-24.8630078,21.6486037],[-18.7866037,22.568089],[-12.6486748,22.9129098],[-6.5004852,22.9919506],[-0.3516624,23.0],[5.7971688,22.9998844],[11.9457713,22.9539713],[18.0917925,22.7744784],[24.2308679,22.4317841],[30.3385207,21.7503322],[35.9255993,19.3659118],[40.9097861,15.81734],[45.551806,11.9784796],[46.0,5.9186632]],"NorthGate":true,"SouthGate":true},"Isle_Featured":{"Size":[72,48],"Points":[[35.8144288,0.2520556],[36.0,-4.8662015],[35.3818087,-9.9196141],[32.2933159,-13.918375],[28.3250485,-17.1417161],[24.6330657,-20.6721278],[19.9523408,-22.6479882],[14.9001235,-23.4062334],[9.8027671,-23.7910164],[4.6942974,-23.9764005],[-0.4177252,-24.0],[-5.5293768,-23.9432493],[-10.626805,-23.5804992],[-15.6421303,-22.6084513],[-20.576253,-21.2695893],[-25.5875176,-20.260521],[-30.4424332,-18.7220171],[-33.7592913,-14.9619337],[-35.2563206,-10.0696941],[-36.0,-5.0116771],[-35.924391,0.1084708],[-35.5101295,5.2087101],[-34.5591798,10.2407336],[-33.7820112,15.299691],[-30.7580932,19.2464046],[-25.9483078,20.9295518],[-20.970953,22.0977845],[-15.9755819,23.1806641],[-10.8962996,23.7371528],[-5.7868907,23.8897261],[-0.6748183,23.914809],[4.437317,23.9277021],[9.5492878,23.9690677],[14.6612052,24.0],[19.7511033,23.5921583],[24.4588068,21.7078458],[28.1073201,18.1333769],[31.879334,14.6784679],[34.5780675,10.3910142],[35.4999131,5.362558]],"NorthGate":false,"SouthGate":true}}]==]
)
-- END_GENERATED_RIMS
local lobby = workspace.Lobby
assert(not lobby:FindFirstChild("Fences"), "Fences already exist; preserve manual edits before rebuilding")
local root = Instance.new("Folder")
root.Name = "Fences"
root:SetAttribute("GeneratedBy", "GlassClashFenceFit1")
local SS = game:GetService("ServerStorage")
local unsorted = SS:FindFirstChild("Unsorted") or Instance.new("Folder")
unsorted.Name, unsorted.Parent = "Unsorted", SS
local backup = Instance.new("Folder")
backup.Name, backup.Parent = "OriginalPerimeterFences", unsorted
local postColor, railColor = Color3.fromRGB(86, 66, 54), Color3.fromRGB(105, 64, 40)
local spacing, inset, halfGate = 5, 0.9, 5.5
local gates, report = {}, {}
local function cross(a, b)
	return a.X * b.Y - a.Y * b.X
end
local function part(parent, name, size, cf, color, collision)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanTouch, p.CanQuery = true, false, collision == true
	p.CanCollide, p.Transparency = collision == true, if collision then 1 else 0
	p.CastShadow, p.Material = not collision, Enum.Material.Plastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function fence(parent, points, skipEndpoints)
	for i, p in points do
		local nextPoint = points[math.min(i + 1, #points)]
		local direction = nextPoint - p
		local yaw = if direction.Magnitude > 0.01 then math.atan2(-direction.X, -direction.Z) else 0
		if not skipEndpoints or (i > 1 and i < #points) then
			part(
				parent,
				"Post",
				Vector3.new(1, 3, 1),
				CFrame.new(p + Vector3.yAxis * 1.5) * CFrame.Angles(0, yaw, 0),
				postColor
			)
		end
		if i < #points then
			local length = direction.Magnitude
			for _, h in { 0.9, 2.1 } do
				part(
					parent,
					"Rail",
					Vector3.new(0.6, 0.6, length),
					CFrame.lookAt((p + nextPoint) / 2 + Vector3.yAxis * h, nextPoint + Vector3.yAxis * h),
					railColor
				)
			end
			part(
				parent,
				"SafetyCollider",
				Vector3.new(0.8, 3, length),
				CFrame.lookAt((p + nextPoint) / 2 + Vector3.yAxis * 1.5, nextPoint + Vector3.yAxis * 1.5),
				postColor,
				true
			)
		end
	end
end
local function island(name, data)
	local grass = lobby.Islands[name]:FindFirstChild(name .. "_Grass")
	assert(grass, "Missing grass mesh: " .. name)
	local original = {}
	for _, p in data.Points do
		table.insert(original, Vector2.new(p[1] * grass.Size.X / data.Size[1], p[2] * grass.Size.Z / data.Size[2]))
	end
	local area = 0
	for i, p in original do
		area += cross(p, original[i % #original + 1])
	end
	local sign = if area > 0 then 1 else -1
	local rim = {}
	for i, p in original do
		local before, after = original[(i - 2) % #original + 1], original[i % #original + 1]
		local u, v = (p - before).Unit, (after - p).Unit
		local a = p + Vector2.new(-u.Y, u.X) * sign * inset
		local b = p + Vector2.new(-v.Y, v.X) * sign * inset
		local denominator = cross(u, v)
		table.insert(
			rim,
			if math.abs(denominator) < 0.0001 then (a + b) / 2 else a + u * (cross(b - a, v) / denominator)
		)
	end
	local cumulative, length = { 0 }, 0
	for i, p in rim do
		length += (rim[i % #rim + 1] - p).Magnitude
		table.insert(cumulative, length)
	end
	local function pointAt(distance)
		distance %= length
		for i = 1, #rim do
			if distance <= cumulative[i + 1] then
				return rim[i]:Lerp(rim[i % #rim + 1], (distance - cumulative[i]) / (cumulative[i + 1] - cumulative[i]))
			end
		end
		return rim[1]
	end
	local function isGate(p)
		return math.abs(p.X) < halfGate - 0.0001
			and ((data.NorthGate and p.Y < -data.Size[2] * 0.3) or (data.SouthGate and p.Y > data.Size[2] * 0.3))
	end
	local cuts = { 0, length }
	for i, p in rim do
		local q = rim[i % #rim + 1]
		for _, x in { -halfGate, halfGate } do
			if math.abs(q.X - p.X) > 0.00001 then
				local alpha = (x - p.X) / (q.X - p.X)
				if alpha > 0 and alpha < 1 then
					local hit = p:Lerp(q, alpha)
					if
						(data.NorthGate and hit.Y < -data.Size[2] * 0.3)
						or (data.SouthGate and hit.Y > data.Size[2] * 0.3)
					then
						table.insert(cuts, cumulative[i] + (q - p).Magnitude * alpha)
					end
				end
			end
		end
	end
	table.sort(cuts)
	local arcs = {}
	for i = 1, #cuts - 1 do
		if not isGate(pointAt((cuts[i] + cuts[i + 1]) / 2)) then
			table.insert(arcs, { cuts[i], cuts[i + 1] })
		end
	end
	if #arcs > 1 and arcs[1][1] == 0 and arcs[#arcs][2] == length then
		local first, last = table.remove(arcs, 1), table.remove(arcs)
		table.insert(arcs, { last[1], first[2] + length })
	end
	local model = Instance.new("Model")
	model.Name, model.ModelStreamingMode = name, Enum.ModelStreamingMode.Atomic
	local top = grass.Size.Y / 2
	local function world(p)
		return grass.CFrame:PointToWorldSpace(Vector3.new(p.X, top, p.Y))
	end
	gates[name] = {}
	local minSpan, maxSpan, postCount = math.huge, 0, 0
	for _, arc in arcs do
		local count = math.max(1, math.floor((arc[2] - arc[1]) / spacing + 0.5))
		local points = {}
		for j = 0, count do
			local p = pointAt(arc[1] + (arc[2] - arc[1]) * j / count)
			table.insert(points, world(p))
			if j == 0 or j == count then
				if math.abs(math.abs(p.X) - halfGate) < 0.01 then
					local key = if p.Y < 0 then "North" else "South"
					gates[name][key] = gates[name][key] or {}
					gates[name][key][if p.X < 0 then 1 else 2] = world(p)
				end
			end
			if j > 0 then
				local span = (points[j + 1] - points[j]).Magnitude
				minSpan = math.min(minSpan, span)
				maxSpan = math.max(maxSpan, span)
			end
		end
		postCount += #points
		fence(model, points)
	end
	model:SetAttribute("Island", name)
	model.Parent = root
	report[name] = { Posts = postCount, MinSpan = minSpan, MaxSpan = maxSpan, GateWidth = halfGate * 2 }
	task.wait()
end
for _, name in { "Isle_Lobby", "Isle_Arena1", "Isle_Arena2", "Isle_Arena3", "Isle_Featured" } do
	island(name, Paths[name])
end
local names = { "Isle_Lobby", "Isle_Arena1", "Isle_Arena2", "Isle_Arena3", "Isle_Featured" }
for i = 1, 4 do
	local a, b = gates[names[i]].North, gates[names[i + 1]].South
	assert(a and b and a[1] and a[2] and b[1] and b[2], "Missing bridge openings")
	local model = Instance.new("Model")
	model.Name = "Bridge" .. i
	for side = 1, 2 do
		local middle = (a[side] + b[side]) / 2
		middle = Vector3.new(if side == 1 then -4.2 else 4.2, middle.Y, middle.Z)
		fence(model, { a[side], middle, b[side] }, true)
	end
	model.Parent = root
	for _, rail in lobby.Bridges["Bridge" .. i]:GetChildren() do
		if rail.Name == "LowRail" then
			rail:SetAttribute("OriginalBridge", i)
			rail.Parent = backup
		end
	end
end
-- These two manually built Part-only perimeter models were explicitly supplied as references.
for _, m in workspace:GetChildren() do
	if m:IsA("Model") and m.Name == "Model" then
		local parts, valid = 0, true
		for _, p in m:GetDescendants() do
			if p:IsA("LuaSourceContainer") then
				valid = false
			end
			if p:IsA("BasePart") then
				parts += 1
				valid = valid and p:IsA("Part") and (math.abs(p.Size.Y - 3) < 0.01 or math.abs(p.Size.Y - 0.6) < 0.01)
			end
		end
		if valid and parts > 100 then
			m:SetAttribute("OriginalName", m.Name)
			m.Parent = backup
		end
	end
end
root.Parent = lobby
return { Islands = report, Descendants = #root:GetDescendants(), OriginalBackup = backup:GetFullName() }
