-- Shared square backing and portrait footprint for every Inventory detail pane.
local S = require(script.Parent.StainedGlass)
local Preview = {}
-- `small`: the phone footprint (about two thirds the height, a little higher up).
function Preview.apply(info, small)
	local backing, portrait = info.ViewportPane, info.InfoPortrait
	local y, height = if small then 0.29 else 0.35, if small then 0.15 else 0.27
	for _, object in { backing, portrait } do
		object.AnchorPoint = Vector2.new(0.5, 0.5)
		object.Position = UDim2.fromScale(0.5, y)
		object.Size = UDim2.fromScale(0.84, if object == backing then height else height * 0.907)
		local aspect = S.aspect(object, 1)
		aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	end
end
return Preview
