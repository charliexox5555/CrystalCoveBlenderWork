-- Shared ownership prevents a closing panel/fight from restoring controls over another UI.
local GuiService = game:GetService("GuiService")
local Gate = { Owners = {}, Baseline = true }
function Gate.acquire(owner)
	if Gate.Owners[owner] then
		return
	end
	if next(Gate.Owners) == nil then
		Gate.Baseline = GuiService.TouchControlsEnabled
	end
	Gate.Owners[owner] = true
	GuiService.TouchControlsEnabled = false
end
function Gate.release(owner)
	if not Gate.Owners[owner] then
		return
	end
	Gate.Owners[owner] = nil
	GuiService.TouchControlsEnabled = if next(Gate.Owners) then false else Gate.Baseline
end
return Gate
