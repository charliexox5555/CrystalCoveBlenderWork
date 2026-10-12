-- Client entry point. Same pattern as the server: every ModuleScript in Controllers gets
-- :Init(controllers), then :Start() in its own thread.

local controllersFolder = script.Parent:WaitForChild("Controllers")
local controllers = {}

for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = require(module)
	end
end

for name, controller in controllers do
	if type(controller) == "table" and type(controller.Init) == "function" then
		local ok, err = pcall(controller.Init, controller, controllers)
		if not ok then
			warn(string.format("[GlassClash] %s:Init failed: %s", name, tostring(err)))
		end
	end
end

for _, controller in controllers do
	if type(controller) == "table" and type(controller.Start) == "function" then
		task.spawn(controller.Start, controller)
	end
end
