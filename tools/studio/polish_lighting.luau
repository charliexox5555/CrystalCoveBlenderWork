-- Polish pass (2026-10-14): calmer, clearer lighting for Crystal Isles. Run in Edit mode via the Studio MCP.
-- * Backs up the original Lighting properties and post effects once, to
--   ServerStorage.WorldBackups.Lighting_2026_10_14 (attributes + cloned effects). Restore by copying back.
-- * Tones the ColorCorrection saturation down (+0.40 made the matte grass read as neon and fought the glass),
--   adds a touch of contrast, and adds the low Bloom ART_BIBLE section 4 asks for so glass glints pop.
-- * Disables the 1-px Blur so glassies and text stay crisp on phones (kept in place, Enabled = false).
-- Re-running reapplies the same target values; the backup is never overwritten.

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local backups = ServerStorage:FindFirstChild("WorldBackups") or Instance.new("Folder")
backups.Name, backups.Parent = "WorldBackups", ServerStorage
local backup = backups:FindFirstChild("Lighting_2026_10_14")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "Lighting_2026_10_14"
	for _, property in
		{
			"Ambient",
			"OutdoorAmbient",
			"Brightness",
			"ClockTime",
			"EnvironmentDiffuseScale",
			"EnvironmentSpecularScale",
			"ExposureCompensation",
			"ShadowSoftness",
		}
	do
		backup:SetAttribute(property, (Lighting :: any)[property])
	end
	for _, effect in Lighting:GetChildren() do
		effect:Clone().Parent = backup
	end
	backup.Parent = backups
end

local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if cc then
	cc.Saturation = 0.12
	cc.Contrast = 0.06
end

local bloom = Lighting:FindFirstChild("GlassBloom") or Instance.new("BloomEffect")
bloom.Name = "GlassBloom"
bloom.Intensity, bloom.Size, bloom.Threshold = 0.35, 24, 1.6
bloom.Parent = Lighting

local blur = Lighting:FindFirstChildOfClass("BlurEffect")
if blur then
	blur.Enabled = false
end

return "lighting polished; backup at " .. backup:GetFullName()
