-- A frozen frame of a finisher for icons and portraits (ViewportFrames can't show particles or tweens). It is
-- built by the real show (Presentation/FinisherFX.still) at its StillAt beat, so cards always match the effect.
local FinisherFX = require(script.Parent.Parent.Parent.Presentation.FinisherFX)
local Still = {}

-- Builds the still into `world` (a WorldModel or Model). Returns false for ids without a standard show.
function Still.build(world, id)
	return FinisherFX.still(world, id)
end

return Still
