-- Server entry point. Loads every ModuleScript in Services, calls :Init(services) on all of them,
-- then :Start() on each in its own thread. A service is a table with optional Init and Start.
--
--   local BattleService = {}
--   function BattleService:Init(services) self.Data = services.DataService end
--   function BattleService:Start() ... end
--   return BattleService

local servicesFolder = script.Parent:WaitForChild("Services")
local services = {}

for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module)
	end
end

for name, service in services do
	if type(service) == "table" and type(service.Init) == "function" then
		local ok, err = pcall(service.Init, service, services)
		if not ok then
			warn(string.format("[GlassClash] %s:Init failed: %s", name, tostring(err)))
		end
	end
end

local count = 0
for _, service in services do
	count += 1
	if type(service) == "table" and type(service.Start) == "function" then
		task.spawn(service.Start, service)
	end
end

print(string.format("[GlassClash] server started (%d services)", count))
