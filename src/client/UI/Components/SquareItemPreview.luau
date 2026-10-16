-- Shared square backing and portrait footprint for every Inventory detail pane.
local S = require(script.Parent.StainedGlass)
local Preview = {}
function Preview.apply(info)
	local backing, portrait = info.ViewportPane, info.InfoPortrait
	for _, object in { backing, portrait } do
		object.AnchorPoint = Vector2.new(0.5, 0.5)
		object.Position = UDim2.fromScale(0.5, 0.35)
		object.Size = UDim2.fromScale(0.84, if object == backing then 0.27 else 0.245)
		local aspect = S.aspect(object, 1)
		aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	end
end
return Preview
