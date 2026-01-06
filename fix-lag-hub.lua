if not game:IsLoaded()then game.Loaded:Wait()end
getgenv().UniversalFixLag=getgenv().UniversalFixLag or{}
local s=getgenv().UniversalFixLag
s.Enabled=s.Enabled or true
s.GuiVisible=(s.GuiVisible==nil)and true or s.GuiVisible
s.Intensity=s.Intensity or 70
local B={RemoveDecal=false,RemoveTexture=false,RemoveEffects=false,DisableShadows=false,LowMaterial=false,DisableCollision=false,LowPhysics=false,OptimizeMesh=false,DisableSurfaceGui=false,OptimizeSound=false,OptimizeCamera=true,FPSStabilizer=true,TargetFPS=60,MinFPS=40}
local c={}
local function cp(a,b)b=b or{}for k,v in pairs(a)do b[k]=v end return b end
cp(B,c)

local P=game:GetService("Players")
local W=game:GetService("Workspace")
local L=game:GetService("Lighting")
local R=game:GetService("RunService")
local U=game:GetService("UserInputService")
local lp=P.LocalPlayer
local ch=lp.Character or lp.CharacterAdded:Wait()
local cam=W.CurrentCamera

local cc,fc
local fs={},fa=c.TargetFPS
local la=0
local rt={gui=nil,drag=false,dc=nil}

local function aI(i)
 if type(i)~="number"then return end
 i=math.clamp(i,10,100)
 s.Intensity=i
 cp(B,c)
 c.OptimizeCamera=true
 c.FPSStabilizer=true
 if i>=10 then c.OptimizeSound=true end
 if i>=30 then c.LowMaterial=true c.DisableShadows=true c.OptimizeMesh=true end
 if i>=50 then c.DisableSurfaceGui=true c.RemoveTexture=true end
 if i>=70 then c.RemoveDecal=true end
 if i>=85 then c.RemoveEffects=true c.LowPhysics=true end
 if i>=95 then c.DisableCollision=true end
 c.TargetFPS=math.floor(60*(1-(i-10)/180))
 c.MinFPS=math.floor(c.TargetFPS*0.66)
 pcall(function()
  if cam and c.OptimizeCamera then cam.FieldOfView=(i>=85)and 60 or 70 end
  L.Brightness=1
 end)
end
aI(s.Intensity)

local function isL(o)return o and ch and o:IsDescendantOf(ch)end
local function opt(o)
 if not o or isL(o)then return end
 if o:IsA("BasePart")then
  if c.LowMaterial then pcall(function()o.Material=Enum.Material.Plastic o.Reflectance=0 end)end
  if c.DisableShadows and o.CastShadow~=nil then pcall(function()o.CastShadow=false end)end
  if c.DisableCollision and not o.Anchored then pcall(function()o.CanCollide=false end)end
  if c.LowPhysics then pcall(function()o.CustomPhysicalProperties=PhysicalProperties.new(0.1,0.1,0.1,1,1)end)end
 elseif c.OptimizeMesh and o:IsA("MeshPart")then
  pcall(function()o.RenderFidelity=Enum.RenderFidelity.Performance if o.DoubleSided~=nil then o.DoubleSided=false end end)
 elseif c.RemoveDecal and o:IsA("Decal")then pcall(function()o:Destroy()end)
 elseif c.RemoveTexture and o:IsA("Texture")then pcall(function()o:Destroy()end)
 elseif c.RemoveEffects and(o:IsA("ParticleEmitter")or o:IsA("Trail")or o:IsA("Beam")or o:IsA("Sparkles"))then pcall(function()o:Destroy()end)
 elseif c.DisableSurfaceGui and o:IsA("SurfaceGui")then pcall(function()o.Enabled=false end)
 elseif c.OptimizeSound and o:IsA("Sound")then pcall(function()if o.Looped then o.Volume=math.min(o.Volume,0.35)end end)
 end
end

local function once()
 pcall(function()
  L.GlobalShadows=false
  L.FogEnd=1e9
  L.Brightness=1
  for _,e in ipairs(L:GetChildren())do if e:IsA("PostEffect")then e.Enabled=false end end
 end)
 if cam and c.OptimizeCamera then cam.FieldOfView=(s.Intensity>=85)and 60 or 70 end
 pcall(function()W.StreamingEnabled=true end)
 for _,v in ipairs(W:GetDescendants())do opt(v)end
end

local function sc()
 if cc then return end
 cc=W.DescendantAdded:Connect(function(o)task.defer(opt,o)end)
end
local function xc()if cc then cc:Disconnect()cc=nil end end

local function uF(dt)
 local f=(dt>0)and(1/dt)or c.TargetFPS
 fs[#fs+1]=f if #fs>25 then table.remove(fs,1)end
 local s=0 for _,v in ipairs(fs)do s+=v end
 fa=s/#fs
end

local function sf()
 if fc then return end
 fc=R.RenderStepped:Connect(function(dt)
  uF(dt)
  if not c.FPSStabilizer or not cam or tick()-la<0.9 then return end
  la=tick()
  if fa<(c.MinFPS or 30)then
   cam.FieldOfView=math.max(55,cam.FieldOfView-2)
   L.Brightness=math.max(0.7,L.Brightness-0.12)
  elseif fa>((c.TargetFPS or 60)+5)then
   cam.FieldOfView=math.min((s.Intensity>=85)and 60 or 70,cam.FieldOfView+1)
   L.Brightness=math.min(1,L.Brightness+0.04)
  end
 end)
end
local function xf()if fc then fc:Disconnect()fc=nil end end

local function en()
 if s.Enabled then return end
 s.Enabled=true once() sc() if c.FPSStabilizer then sf()end
end
local function di()
 if not s.Enabled then return end
 s.Enabled=false xc() xf()
 if cam then cam.FieldOfView=70 end
 L.Brightness=1
end

if s.Enabled then en()end

local API={
 Enable=en,
 Disable=di,
 Toggle=function()if s.Enabled then di()else en()end end,
 ShowGUI=function()s.GuiVisible=true if rt.gui then rt.gui.Enabled=true end end,
 HideGUI=function()s.GuiVisible=false if rt.gui then rt.gui.Enabled=false end end,
 RemoveGUI=function()s.GuiVisible=false if rt.gui then rt.gui:Destroy()rt.gui=nil end end,
 SetIntensity=function(p)aI(math.clamp(tonumber(p)or s.Intensity,10,100))end,
 GetState=function()return{Enabled=s.Enabled,GuiVisible=s.GuiVisible,Intensity=s.Intensity,AvgFPS=fa}end
}
return API
