-- Cheap "could this be on screen?" test for presentation loops (rides, showcase displays, rider poses): a sphere
-- against the camera's view cone, widened to the screen's diagonal so nothing at a corner is ever skipped.
-- Time-driven motion that skips its off-screen frames is exactly where it should be when it comes back into view.
-- Only meaningful for things in Workspace (a preview inside a ViewportFrame has its own camera).
local ViewCull = {}
-- Studio A/B switch for profiling: workspace attribute PerfNoCull = true treats everything as on screen.
local STUDIO = game:GetService("RunService"):IsStudio()

-- True while the Studio A/B switch is on: callers also drop their lower update rates.
function ViewCull.off(): boolean
	return STUDIO and workspace:GetAttribute("PerfNoCull") == true
end

function ViewCull.visible(camera: Camera?, position: Vector3, radius: number): boolean
	if not camera or ViewCull.off() then
		return true
	end
	local cf = camera.CFrame
	local offset = position - cf.Position
	local distance = offset.Magnitude
	if distance <= radius then
		return true
	end
	local viewport = camera.ViewportSize
	local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
	local tanH = tanV * viewport.X / math.max(1, viewport.Y)
	local half = math.atan(math.sqrt(tanV * tanV + tanH * tanH))
	local angle = math.acos(math.clamp(offset:Dot(cf.LookVector) / distance, -1, 1))
	return angle <= half + math.asin(math.min(1, radius / distance))
end

return ViewCull
