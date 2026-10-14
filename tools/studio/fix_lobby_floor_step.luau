-- Polish pass (2026-10-14): level the one lobby collision slab that sat 1.4 studs high.
-- Workspace.Lobby.Collision.Isle_Lobby_Floor2 had its centre at Y +0.70 (top 1.40) and a ~1.3 degree yaw,
-- while all 64 sibling slabs are axis-aligned with their top at the island's grass level. Players walking
-- from spawn to Bridge 1 crossed an invisible 1.4-stud ledge and floated above the grass there.
-- The original CFrame is kept in the OriginalCFrame_2026_10_14 attribute; re-running is harmless.

local slab = workspace.Lobby.Collision:FindFirstChild("Isle_Lobby_Floor2")
assert(slab and slab:IsA("BasePart"), "Isle_Lobby_Floor2 not found")
if slab:GetAttribute("OriginalCFrame_2026_10_14") == nil then
	slab:SetAttribute("OriginalCFrame_2026_10_14", slab.CFrame)
end
slab.CFrame = CFrame.new(0, -slab.Size.Y / 2, slab.Position.Z)
return "top now " .. (slab.Position.Y + slab.Size.Y / 2)
