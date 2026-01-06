--[[
  Universal Fix Lag - GUI with Intensity Slider + Hide/Remove GUI
  - Universal, executor-safe, client-side only
  - Slider: intensity 10%..100% (maps to a set of safe optimizations)
  - "Hide GUI": hides interface but keeps fix running
  - "Remove GUI": destroys GUI (fix still runs). Use API.ShowGUI() to recreate
  - Hotkeys:
      RightShift -> Toggle Fix ON/OFF
      RightControl -> Toggle GUI show/hide (recreates GUI if removed)
--]]

if not game:IsLoaded() then game.Loaded:Wait() end

-- ================= GLOBAL STATE & CONFIG =================
getgenv().UniversalFixLag = getgenv().UniversalFixLag or {}
local STATE = getgenv().UniversalFixLag

STATE.Enabled = STATE.Enabled or true
STATE.GuiVisible = (STATE.GuiVisible == nil) and true or STATE.GuiVisible
STATE.Intensity = STATE.Intensity or 70            -- default 70%
STATE.Mode = STATE.Mode or "Normal"

-- base config (will be overridden by intensity)
local BASE = {
    RemoveDecal = false,
    RemoveTexture = false,
    RemoveEffects = false,
    DisableShadows = false,
    LowMaterial = false,
    DisableCollision = false,
    LowPhysics = false,
    OptimizeMesh = false,
    DisableSurfaceGui = false,
    OptimizeSound = false,
    OptimizeCamera = true,
    FPSStabilizer = true,
    TargetFPS = 60,
    MinFPS = 40,
}

-- active config in use
local CONFIG = {}
local function copyTable(src, dst)
    dst = dst or {}
    for k,v in pairs(src) do dst[k]=v end
    return dst
end
copyTable(BASE, CONFIG)

-- ================= SERVICES & LOCALS =================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local CHAR = LP.Character or LP.CharacterAdded:Wait()
local CAMERA = Workspace.CurrentCamera

-- ================= RUNTIME =================
local CleanerConn, FPSConn
local fpsSamples = {}
local fpsAvg = CONFIG.TargetFPS
local lastAdjust = 0
local runtime = { gui = nil, dragging = false, dragConn = nil }

-- ================= INTENSITY MAPPING =================
-- Map Intensity (10..100) to CONFIG flags/strength.
local function applyIntensity(intensity)
    if type(intensity) ~= "number" then return end
    intensity = math.clamp(intensity, 10, 100)
    STATE.Intensity = intensity

    -- Reset to base first
    copyTable(BASE, CONFIG)

    -- Always keep camera & stabilizer on
    CONFIG.OptimizeCamera = true
    CONFIG.FPSStabilizer = true

    -- progressive enabling by thresholds
    if intensity >= 10 then
        -- minimal improvements
        CONFIG.OptimizeSound = true
    end
    if intensity >= 30 then
        CONFIG.LowMaterial = true
        CONFIG.DisableShadows = true
        CONFIG.OptimizeMesh = true
    end
    if intensity >= 50 then
        CONFIG.DisableSurfaceGui = true
        CONFIG.RemoveTexture = true
    end
    if intensity >= 70 then
        CONFIG.RemoveDecal = true
        CONFIG.RemoveEffects = false -- keep a bit safer until 90
    end
    if intensity >= 85 then
        CONFIG.RemoveEffects = true
        CONFIG.LowPhysics = true
    end
    if intensity >= 95 then
        CONFIG.DisableCollision = true
    end

    -- scale FPS targets by intensity (more aggressive intensity -> lower target to stabilize)
    CONFIG.TargetFPS = math.floor(60 * (1 - (intensity - 10) / 180)) -- maps 10->~57, 100->~26 (aggressive)
    CONFIG.MinFPS = math.floor(CONFIG.TargetFPS * 0.66) -- 2/3 of target

    -- apply immediate visual adjustments if running
    pcall(function()
        if CAMERA and CONFIG.OptimizeCamera then
            CAMERA.FieldOfView = (intensity >= 85) and 60 or 70
        end
        Lighting.Brightness = 1
    end)
end

-- Initialize intensity
applyIntensity(STATE.Intensity)

-- ================= CORE OPTIMIZATION =================
local function isLocalDescendant(obj)
    return obj and CHAR and obj:IsDescendantOf(CHAR)
end

local function optimizeInstance(obj)
    if not obj then return end
    if isLocalDescendant(obj) then return end

    -- BasePart
    if obj:IsA("BasePart") then
        if CONFIG.LowMaterial then
            pcall(function()
                obj.Material = Enum.Material.Plastic
                obj.Reflectance = 0
            end)
        end
        if CONFIG.DisableShadows and obj.CastShadow ~= nil then
            pcall(function() obj.CastShadow = false end)
        end
        if CONFIG.DisableCollision and not obj.Anchored then
            pcall(function() obj.CanCollide = false end)
        end
        if CONFIG.LowPhysics then
            pcall(function()
                obj.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.1, 0.1, 1, 1)
            end)
        end

    -- MeshPart
    elseif CONFIG.OptimizeMesh and obj:IsA("MeshPart") then
        pcall(function()
            obj.RenderFidelity = Enum.RenderFidelity.Performance
            if obj.DoubleSided ~= nil then obj.DoubleSided = false end
        end)

    -- Decal / Texture
    elseif CONFIG.RemoveDecal and obj:IsA("Decal") then
        pcall(function() obj:Destroy() end)

    elseif CONFIG.RemoveTexture and obj:IsA("Texture") then
        pcall(function() obj:Destroy() end)

    -- Effects (conditional on fps)
    elseif CONFIG.RemoveEffects and (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Sparkles")) then
        pcall(function() obj:Destroy() end)

    -- SurfaceGui
    elseif CONFIG.DisableSurfaceGui and obj:IsA("SurfaceGui") then
        pcall(function() obj.Enabled = false end)

    -- Sound
    elseif CONFIG.OptimizeSound and obj:IsA("Sound") then
        pcall(function()
            if obj.Looped then obj.Volume = math.min(obj.Volume, 0.35) end
        end)
    end
end

-- ================= APPLY ONCE =================
local function applyOnce()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e9
        Lighting.Brightness = 1
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then
                pcall(function() e.Enabled = false end)
            end
        end
    end)

    if CAMERA and CONFIG.OptimizeCamera then
        pcall(function() CAMERA.FieldOfView = (STATE.Intensity >= 85) and 60 or 70 end)
    end

    pcall(function() Workspace.StreamingEnabled = true end)

    for _, v in ipairs(Workspace:GetDescendants()) do
        optimizeInstance(v)
    end
end

-- ================= CLEANER (lightweight) =================
local function startCleaner()
    if CleanerConn then return end
    CleanerConn = Workspace.DescendantAdded:Connect(function(obj)
        task.defer(optimizeInstance, obj)
    end)
end
local function stopCleaner()
    if CleanerConn then
        pcall(function() CleanerConn:Disconnect() end)
        CleanerConn = nil
    end
end

-- ================= FPS STABILIZER =================
local function updateFPS(dt)
    local fps = (dt > 0) and (1/dt) or CONFIG.TargetFPS
    table.insert(fpsSamples, fps)
    if #fpsSamples > 25 then table.remove(fpsSamples,1) end
    local s=0 for _,v in ipairs(fpsSamples) do s=s+v end
    fpsAvg = s / (#fpsSamples>0 and #fpsSamples or 1)
end

local function startFPS()
    if FPSConn then return end
    FPSConn = RunService.RenderStepped:Connect(function(dt)
        updateFPS(dt)
        if not CONFIG.FPSStabilizer or not CAMERA then return end
        if tick() - lastAdjust < 0.9 then return end
        lastAdjust = tick()

        if fpsAvg < (CONFIG.MinFPS or 30) then
            pcall(function()
                CAMERA.FieldOfView = math.max(55, CAMERA.FieldOfView - 2)
                Lighting.Brightness = math.max(0.7, Lighting.Brightness - 0.12)
            end)
        elseif fpsAvg > ((CONFIG.TargetFPS or 60) + 5) then
            pcall(function()
                CAMERA.FieldOfView = math.min((STATE.Intensity>=85) and 60 or 70, CAMERA.FieldOfView + 1)
                Lighting.Brightness = math.min(1, Lighting.Brightness + 0.04)
            end)
        end
    end)
end
local function stopFPS()
    if FPSConn then
        pcall(function() FPSConn:Disconnect() end)
        FPSConn = nil
    end
end

-- ================= ENABLE / DISABLE =================
local function enableFix()
    if STATE.Enabled then return end
    STATE.Enabled = true
    applyOnce()
    startCleaner()
    if CONFIG.FPSStabilizer then startFPS() end
end
local function disableFix()
    if not STATE.Enabled then return end
    STATE.Enabled = false
    stopCleaner()
    stopFPS()
    -- restore minimal safe defaults
    pcall(function()
        if CAMERA and CONFIG.OptimizeCamera then CAMERA.FieldOfView = 70 end
        Lighting.Brightness = 1
    end)
end

-- If state persisted as enabled on re-inject, ensure running
if STATE.Enabled then
    applyIntensity(STATE.Intensity)
    enableFix()
else
    -- still apply intensity to ensure config is ready for when enabled
    applyIntensity(STATE.Intensity)
end

-- ================= GUI BUILD (slider + hide + remove) =================
local function createGUI()
    if runtime.gui and runtime.gui.Parent then
        runtime.gui.Enabled = STATE.GuiVisible
        return runtime.gui
    end

    local parent = (gethui and gethui()) or (get_hidden_gui and get_hidden_gui()) or game:GetService("CoreGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UniversalFixLag_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = parent
    if syn and syn.protect_gui then pcall(syn.protect_gui, screenGui) end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(260, 150)
    frame.Position = UDim2.fromOffset(18, 120)
    frame.BackgroundTransparency = 0.12
    frame.BackgroundColor3 = Color3.fromRGB(22,22,22)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    frame.Active = true
    frame.Draggable = true

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -12, 0, 24)
    title.Position = UDim2.fromOffset(6, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.new(1,1,1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Universal FixLag • Intensity"

    local percentLabel = Instance.new("TextLabel", frame)
    percentLabel.Size = UDim2.fromOffset(80, 20)
    percentLabel.Position = UDim2.fromOffset(174, 8)
    percentLabel.BackgroundTransparency = 1
    percentLabel.Font = Enum.Font.Gotham
    percentLabel.TextSize = 12
    percentLabel.TextColor3 = Color3.fromRGB(200,200,200)
    percentLabel.Text = tostring(STATE.Intensity) .. "%"

    -- Slider background
    local sliderBg = Instance.new("Frame", frame)
    sliderBg.Size = UDim2.fromOffset(220, 18)
    sliderBg.Position = UDim2.fromOffset(16, 36)
    sliderBg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    sliderBg.BorderSizePixel = 0
    sliderBg.Name = "SliderBg"

    -- Slider fill
    local sliderFill = Instance.new("Frame", sliderBg)
    sliderFill.Size = UDim2.new(STATE.Intensity/100, 0, 1, 0)
    sliderFill.Position = UDim2.new(0,0,0,0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0,150,90)
    sliderFill.BorderSizePixel = 0

    -- Slider knob
    local knob = Instance.new("TextButton", sliderBg)
    knob.Size = UDim2.fromOffset(14, 18)
    knob.Position = UDim2.new(STATE.Intensity/100, -7, 0, 0)
    knob.AutoButtonColor = false
    knob.Text = ""
    knob.BackgroundColor3 = Color3.fromRGB(220,220,220)
    knob.BorderSizePixel = 0

    -- Buttons
    local toggleBtn = Instance.new("TextButton", frame)
    toggleBtn.Size = UDim2.fromOffset(120, 34)
    toggleBtn.Position = UDim2.fromOffset(16, 62)
    toggleBtn.Font = Enum.Font.Gotham
    toggleBtn.TextSize = 14
    toggleBtn.TextColor3 = Color3.new(1,1,1)
    toggleBtn.Text = STATE.Enabled and "Disable Fix" or "Enable Fix"
    toggleBtn.BackgroundColor3 = STATE.Enabled and Color3.fromRGB(0,150,90) or Color3.fromRGB(60,60,60)
    toggleBtn.BorderSizePixel = 0

    local hideBtn = Instance.new("TextButton", frame)
    hideBtn.Size = UDim2.fromOffset(120, 24)
    hideBtn.Position = UDim2.fromOffset(16, 104)
    hideBtn.Font = Enum.Font.Gotham
    hideBtn.TextSize = 12
    hideBtn.TextColor3 = Color3.new(1,1,1)
    hideBtn.Text = "Hide GUI"
    hideBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
    hideBtn.BorderSizePixel = 0

    local removeBtn = Instance.new("TextButton", frame)
    removeBtn.Size = UDim2.fromOffset(120, 24)
    removeBtn.Position = UDim2.fromOffset(140, 104)
    removeBtn.Font = Enum.Font.Gotham
    removeBtn.TextSize = 12
    removeBtn.TextColor3 = Color3.new(1,1,1)
    removeBtn.Text = "Remove GUI"
    removeBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
    removeBtn.BorderSizePixel = 0

    -- Slider behavior helpers
    local dragging = false
    local function setSliderFromX(x)
        local absPos = math.clamp(x - sliderBg.AbsolutePosition.X, 0, sliderBg.AbsoluteSize.X)
        local pct = math.floor((absPos / sliderBg.AbsoluteSize.X) * 100)
        pct = math.clamp(pct, 10, 100)
        -- update UI
        sliderFill.Size = UDim2.new(pct/100, 0, 1, 0)
        knob.Position = UDim2.new(pct/100, -7, 0, 0)
        percentLabel.Text = tostring(pct) .. "%"
        -- apply intensity change (live)
        applyIntensity(pct)
    end

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            runtime.dragging = true
            runtime.dragConn = UserInputService.InputChanged:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseMovement then
                    setSliderFromX(inp.Position.X)
                end
            end)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            runtime.dragging = false
            if runtime.dragConn then runtime.dragConn:Disconnect() runtime.dragConn = nil end
            -- persist chosen intensity
            STATE.Intensity = tonumber(percentLabel.Text:match("(%d+)%s*%%")) or STATE.Intensity
            applyIntensity(STATE.Intensity)
        end
    end)

    -- also allow clicking on slider background to set
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            setSliderFromX(input.Position.X)
            STATE.Intensity = tonumber(percentLabel.Text:match("(%d+)%s*%%")) or STATE.Intensity
            applyIntensity(STATE.Intensity)
        end
    end)

    -- Toggle fix
    toggleBtn.MouseButton1Click:Connect(function()
        if STATE.Enabled then
            disableFix()
        else
            enableFix()
        end
        toggleBtn.Text = STATE.Enabled and "Disable Fix" or "Enable Fix"
        toggleBtn.BackgroundColor3 = STATE.Enabled and Color3.fromRGB(0,150,90) or Color3.fromRGB(60,60,60)
    end)

    -- Hide GUI: just disable the ScreenGui (can be re-enabled)
    hideBtn.MouseButton1Click:Connect(function()
        STATE.GuiVisible = false
        screenGui.Enabled = false
    end)

    -- Remove GUI: destroy and keep state so user can recreate with API.ShowGUI()
    removeBtn.MouseButton1Click:Connect(function()
        STATE.GuiVisible = false
        runtime.gui = nil
        pcall(function() screenGui:Destroy() end)
    end)

    runtime.gui = screenGui
    runtime.gui.Update = function()
        if runtime.gui then runtime.gui.Enabled = STATE.GuiVisible end
    end

    runtime.gui.Update()
    return runtime.gui
end

-- create GUI if desired
if STATE.GuiVisible then createGUI() end

-- ================= HOTKEYS =================
UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        if STATE.Enabled then disableFix() else enableFix() end
        if runtime.gui and runtime.gui.Parent then
            -- update toggle button if GUI exists
            for _, v in ipairs(runtime.gui:GetDescendants()) do
                if v:IsA("TextButton") and (v.Text == "Enable Fix" or v.Text == "Disable Fix" or v.Text:match("Disable Fix") or v.Text:match("Enable Fix")) then
                    pcall(function() v.Text = STATE.Enabled and "Disable Fix" or "Enable Fix" end)
                    pcall(function() v.BackgroundColor3 = STATE.Enabled and Color3.fromRGB(0,150,90) or Color3.fromRGB(60,60,60) end)
                end
            end
        end
    elseif inp.KeyCode == Enum.KeyCode.RightControl then
        -- toggle GUI visible; if GUI removed, recreate
        STATE.GuiVisible = not STATE.GuiVisible
        if runtime.gui and runtime.gui.Parent then
            runtime.gui.Enabled = STATE.GuiVisible
        else
            if STATE.GuiVisible then createGUI() end
        end
    end
end)

-- ================= PUBLIC API =================
local API = {
    Enable = enableFix,
    Disable = disableFix,
    Toggle = function() if STATE.Enabled then disableFix() else enableFix() end end,
    ShowGUI = function() STATE.GuiVisible = true if runtime.gui then runtime.gui.Enabled = true else createGUI() end end,
    HideGUI = function() STATE.GuiVisible = false if runtime.gui then runtime.gui.Enabled = false end end,
    RemoveGUI = function() STATE.GuiVisible = false if runtime.gui then pcall(function() runtime.gui:Destroy() end) runtime.gui = nil end end,
    SetIntensity = function(p) applyIntensity(math.clamp(tonumber(p) or STATE.Intensity, 10, 100)) end,
    GetState = function() return {
        Enabled = STATE.Enabled,
        GuiVisible = STATE.GuiVisible,
        Intensity = STATE.Intensity,
        Config = CONFIG,
        AvgFPS = fpsAvg
    } end,
}

-- Return API if executor supports returns
return API
