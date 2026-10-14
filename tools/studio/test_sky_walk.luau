-- Client-only Studio QA harness. Never shipped as a game script.
local player=game.Players.LocalPlayer
local character=player.Character or player.CharacterAdded:Wait()
local humanoid=character:WaitForChild("Humanoid")
local root=character:WaitForChild("HumanoidRootPart")
local report={status="running",visits={},failures={},frames={}}
_G.L1Walk=report
local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={character}
local function go(x,z)
 local hit=workspace:Raycast(Vector3.new(x,35,z),Vector3.new(0,-80,0),params)
 if not hit then table.insert(report.failures,"No ground "..x..","..z); return false end
 local target=hit.Position
 local started=os.clock(); local refresh=0; local maxSeconds=(Vector2.new(root.Position.X-x,root.Position.Z-z)).Magnitude/16+4
 while os.clock()-started<maxSeconds do
  if Vector2.new(root.Position.X-x,root.Position.Z-z).Magnitude<1.1 and root.Position.Y>=target.Y+1 then
   table.insert(report.visits,{x=x,z=z,seconds=os.clock()-started}); return true
  end
  if root.Position.Y < -5 then table.insert(report.failures,"Fell off at "..tostring(root.Position)); return false end
  if os.clock()>refresh then humanoid:MoveTo(target); refresh=os.clock()+1 end
  task.wait(.05)
 end
 table.insert(report.failures,"Blocked "..x..","..z.." at "..tostring(root.Position)); return false
end
task.spawn(function()
 humanoid.WalkSpeed=16; character:PivotTo(CFrame.new(0,4,12)); root.AssemblyLinearVelocity=Vector3.zero
 task.wait(.4)
 local start=os.clock()
 local measuring=true
 task.spawn(function()
  while measuring do
   if Vector2.new(root.Position.X+18.5,root.Position.Z+206).Magnitude<=3.3 and root.Position.Y>=10 then
    report.featuredPadEntrySeconds=os.clock()-start; return
   end
   task.wait(.01)
  end
 end)
 local ok=go(-2.7,-185) and go(-18.5,-206)
 measuring=false
 report.featuredCentreSeconds=os.clock()-start; report.featuredReached=ok
 if not ok then report.status="failed"; return end
 go(-18.5,-206); go(-18.5,-188); go(18.5,-188); go(18.5,-206); go(18.5,-188); go(0,-188)
 report.status="checking_all_pads"
 for _,e in {{155,6},{105,4},{55,2}} do
  go(0,-e[1]-18.5); go(-24,-e[1]-18.5); go(24,-e[1]-18.5); go(0,-e[1]-18.5)
  go(0,-e[1]+18.5); go(-24,-e[1]+18.5); go(24,-e[1]+18.5); go(0,-e[1]+18.5)
 end
 go(0,12)
 report.status=#report.failures==0 and "passed" or "failed"
 report.totalSeconds=os.clock()-start
end)
return "Started refreshed MoveTo route; no jumping or teleporting during traversal."
