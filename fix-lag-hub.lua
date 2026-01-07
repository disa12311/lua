--[[
    Universal Fix Lag v2.5 - Multi-Game Compatible
    ✓ Tương thích mọi game Roblox
    ✓ Hỗ trợ tất cả executor (Synapse, Script-Ware, Fluxus, Hydrogen, v.v.)
    ✓ Anti-ban nâng cao với AI pattern randomization
    ✓ Tối ưu hóa thông minh theo từng game
    Author: AI Expert
    Date: 2026-01-07
]]

-- ============================================================================
-- KHỞI TẠO AN TOÀN - TƯƠNG THÍCH TẤT CẢ EXECUTOR
-- ============================================================================

repeat task.wait() until game:IsLoaded()

-- Kiểm tra và tạo namespace an toàn
if not getgenv then getgenv = function() return _G end end
if not gethui then gethui = function() return game:GetService("CoreGui") end end

getgenv().UniversalFixLag = getgenv().UniversalFixLag or {}
local Settings = getgenv().UniversalFixLag

-- Cấu hình mặc định
Settings.Enabled = Settings.Enabled ~= false
Settings.GuiVisible = Settings.GuiVisible ~= false
Settings.Intensity = Settings.Intensity or 70
Settings.AutoAdapt = Settings.AutoAdapt ~= false
Settings.SafeMode = Settings.SafeMode ~= false

-- ============================================================================
-- EXECUTOR DETECTION & COMPATIBILITY
-- ============================================================================

local ExecutorInfo = {
    name = "Unknown",
    features = {},
    safetyLevel = "high",
}

local function DetectExecutor()
    local checks = {
        {name = "Synapse X", check = syn and syn.request},
        {name = "Script-Ware", check = isscriptware or SCRIPT_WARE_LOADED},
        {name = "KRNL", check = KRNL_LOADED or krnl},
        {name = "Fluxus", check = fluxus or Fluxus},
        {name = "Hydrogen", check = Hydrogen},
        {name = "Electron", check = iselectron},
        {name = "Trigon", check = istrigon or TRIGON_LOADED},
        {name = "Arceus X", check = identifyexecutor and identifyexecutor():find("Arceus")},
    }
    
    for _, executor in ipairs(checks) do
        if executor.check then
            ExecutorInfo.name = executor.name
            ExecutorInfo.safetyLevel = "medium"
            break
        end
    end
    
    -- Kiểm tra các tính năng có sẵn
    ExecutorInfo.features = {
        protectGui = (syn and syn.protect_gui) or (protect_gui) or false,
        getHiddenGui = gethui or get_hidden_gui or false,
        setFpsCap = (setfpscap) or false,
        hookMetamethod = (hookmetamethod) or (hookfunction) or false,
    }
end

DetectExecutor()

-- ============================================================================
-- GAME DETECTION & AUTO-CONFIG
-- ============================================================================

local GameProfiles = {
    -- FPS Games (cần tối ưu cao)
    ["Phantom Forces"] = {intensity = 85, priority = "performance"},
    ["Arsenal"] = {intensity = 80, priority = "performance"},
    ["Bad Business"] = {intensity = 85, priority = "performance"},
    
    -- Simulator Games (cần cân bằng)
    ["Pet Simulator"] = {intensity = 70, priority = "balanced"},
    ["Clicking Simulator"] = {intensity = 65, priority = "balanced"},
    
    -- RPG Games (ưu tiên đồ họa hơn)
    ["Blox Fruits"] = {intensity = 60, priority = "visual"},
    ["Anime Fighting Simulator"] = {intensity = 65, priority = "visual"},
    
    -- Obby Games (tối ưu vừa phải)
    ["Tower of Hell"] = {intensity = 50, priority = "balanced"},
    
    -- Default cho game khác
    ["Default"] = {intensity = 70, priority = "balanced"},
}

local CurrentGame = {
    name = "Unknown",
    profile = nil,
    placeId = game.PlaceId,
}

local function DetectGame()
    local gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    CurrentGame.name = gameName
    
    -- Tìm profile phù hợp
    for profileName, profile in pairs(GameProfiles) do
        if gameName:lower():find(profileName:lower()) then
            CurrentGame.profile = profile
            if Settings.AutoAdapt then
                Settings.Intensity = profile.intensity
            end
            return
        end
    end
    
    -- Dùng profile mặc định
    CurrentGame.profile = GameProfiles["Default"]
end

task.spawn(DetectGame)

-- ============================================================================
-- ANTI-BAN SYSTEM V2 - NÂNG CAP
-- ============================================================================

local AntiBan = {
    -- Cấu hình động dựa trên executor và game
    config = {
        minOpsPerCycle = 2,
        maxOpsPerCycle = 12,
        baseDelayMs = 5,
        maxDelayMs = 50,
        randomSkipChance = 0.18,
        patternBreakInterval = 15,
    },
    
    -- Trạng thái
    state = {
        operationCount = 0,
        totalOperations = 0,
        cycleStartTime = 0,
        lastPatternBreak = 0,
        suspicionLevel = 0,
        operationTimestamps = {},
    },
    
    -- Patterns để tránh
    suspiciousPatterns = {
        tooFastOperations = 0,
        tooRegularTiming = 0,
        highVolumeSpike = 0,
    },
}

-- Tạo delay với phân phối tự nhiên hơn
function AntiBan:GenerateNaturalDelay()
    local config = self.config
    local base = config.baseDelayMs / 1000
    local maxD = config.maxDelayMs / 1000
    
    -- Kết hợp nhiều nguồn ngẫu nhiên
    local uniform = math.random()
    local exponential = -math.log(math.random()) * 0.015
    local normal = (math.random() + math.random() + math.random() + math.random()) / 4
    
    -- Trộn các phân phối
    local mixed = (uniform * 0.3 + exponential * 0.4 + normal * 0.3)
    local delay = base + (maxD - base) * mixed
    
    -- Thêm jitter ngẫu nhiên
    local jitter = (math.random() - 0.5) * delay * 0.25
    
    -- Tăng delay nếu có nghi ngờ
    if self.state.suspicionLevel > 0.3 then
        delay = delay * (1 + self.state.suspicionLevel * 0.5)
    end
    
    return math.clamp(delay + jitter, base, maxD * 1.5)
end

-- Quyết định có thực hiện operation không
function AntiBan:ShouldExecute()
    local currentTime = tick()
    local state = self.state
    
    -- Khởi tạo cycle mới
    if state.cycleStartTime == 0 then
        state.cycleStartTime = currentTime
        state.operationCount = 0
    end
    
    -- Đặt giới hạn động cho cycle
    local maxOps = math.random(self.config.minOpsPerCycle, self.config.maxOpsPerCycle)
    
    -- Pattern break - dừng hoàn toàn một lúc
    if currentTime - state.lastPatternBreak > self.config.patternBreakInterval then
        state.lastPatternBreak = currentTime
        state.cycleStartTime = 0
        return false, "pattern_break"
    end
    
    -- Random skip để phá vỡ pattern
    if math.random() < self.config.randomSkipChance then
        return false, "random_skip"
    end
    
    -- Kiểm tra limit trong cycle
    if state.operationCount >= maxOps then
        state.cycleStartTime = 0
        state.operationCount = 0
        return false, "cycle_limit"
    end
    
    -- Cho phép thực hiện
    state.operationCount = state.operationCount + 1
    state.totalOperations = state.totalOperations + 1
    
    -- Lưu timestamp
    table.insert(state.operationTimestamps, currentTime)
    if #state.operationTimestamps > 100 then
        table.remove(state.operationTimestamps, 1)
    end
    
    return true, "allowed"
end

-- Phân tích pattern để phát hiện anomaly
function AntiBan:AnalyzePatterns()
    local timestamps = self.state.operationTimestamps
    if #timestamps < 10 then return end
    
    -- Lấy 20 timestamps gần nhất
    local recent = {}
    for i = math.max(1, #timestamps - 19), #timestamps do
        table.insert(recent, timestamps[i])
    end
    
    -- Tính intervals
    local intervals = {}
    for i = 2, #recent do
        table.insert(intervals, recent[i] - recent[i-1])
    end
    
    -- Tính mean và variance
    local sum, mean = 0, 0
    for _, interval in ipairs(intervals) do
        sum = sum + interval
    end
    mean = sum / #intervals
    
    local variance = 0
    for _, interval in ipairs(intervals) do
        variance = variance + (interval - mean) ^ 2
    end
    variance = variance / #intervals
    
    -- Đánh giá suspicion
    local stdDev = math.sqrt(variance)
    local coefficientOfVariation = (mean > 0) and (stdDev / mean) or 1
    
    -- Pattern quá đều đặn (CV thấp) = nguy hiểm
    if coefficientOfVariation < 0.3 then
        self.state.suspicionLevel = math.min(self.state.suspicionLevel + 0.08, 1)
        self.suspiciousPatterns.tooRegularTiming = self.suspiciousPatterns.tooRegularTiming + 1
    else
        self.state.suspicionLevel = math.max(self.state.suspicionLevel - 0.02, 0)
    end
    
    -- Operations quá nhanh
    local recentOps = 0
    local currentTime = tick()
    for _, ts in ipairs(timestamps) do
        if currentTime - ts < 1 then
            recentOps = recentOps + 1
        end
    end
    
    if recentOps > 20 then
        self.state.suspicionLevel = math.min(self.state.suspicionLevel + 0.05, 1)
        self.suspiciousPatterns.tooFastOperations = self.suspiciousPatterns.tooFastOperations + 1
    end
end

-- Wrapper an toàn cho mọi operation
function AntiBan:SafeExecute(callback, operationType)
    local canExecute, reason = self:ShouldExecute()
    
    if not canExecute then
        if reason == "cycle_limit" or reason == "pattern_break" then
            task.wait(self:GenerateNaturalDelay())
        end
        return false, reason
    end
    
    -- Phân tích patterns định kỳ
    if self.state.totalOperations % 25 == 0 then
        self:AnalyzePatterns()
    end
    
    -- Execute với protection
    task.spawn(function()
        local delay = self:GenerateNaturalDelay()
        task.wait(delay)
        
        local success, error = pcall(callback)
        
        if not success then
            -- Tăng suspicion nếu có lỗi (có thể đang bị monitor)
            self.state.suspicionLevel = math.min(self.state.suspicionLevel + 0.03, 1)
        end
    end)
    
    return true, "executed"
end

-- ============================================================================
-- SERVICES & GLOBAL VARIABLES
-- ============================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Camera = Workspace.CurrentCamera

-- Update Character khi respawn
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
end)

-- ============================================================================
-- OPTIMIZATION CONFIG
-- ============================================================================

local OptConfig = {
    -- Visual
    removeDecals = false,
    removeTextures = false,
    removeEffects = false,
    removeFire = false,
    removeSmoke = false,
    
    -- Lighting
    disableShadows = false,
    disablePostEffects = false,
    optimizeLighting = true,
    
    -- Materials & Meshes
    lowMaterials = false,
    optimizeMeshes = false,
    reduceReflectance = true,
    
    -- Physics
    lowPhysics = false,
    disableCollision = false,
    optimizeConstraints = false,
    
    -- Sound
    optimizeSounds = true,
    maxSoundVolume = 0.4,
    
    -- UI
    disableSurfaceGuis = false,
    optimizeBillboardGuis = false,
    
    -- Camera & Rendering
    optimizeCamera = true,
    reduceFOV = false,
    targetFPS = 60,
    minFPS = 45,
}

-- Áp dụng intensity vào config
local function ApplyIntensity(intensity)
    intensity = math.clamp(intensity or 70, 0, 100)
    Settings.Intensity = intensity
    
    -- Reset tất cả
    for key in pairs(OptConfig) do
        if type(OptConfig[key]) == "boolean" then
            OptConfig[key] = false
        end
    end
    
    -- Base (luôn bật)
    OptConfig.optimizeCamera = true
    OptConfig.optimizeSounds = true
    OptConfig.optimizeLighting = true
    OptConfig.reduceReflectance = true
    
    -- Tính FPS target
    OptConfig.targetFPS = math.floor(60 * (1 - intensity / 150))
    OptConfig.minFPS = math.floor(OptConfig.targetFPS * 0.75)
    
    -- Progressive levels
    if intensity >= 20 then
        OptConfig.lowMaterials = true
        OptConfig.disableShadows = true
    end
    
    if intensity >= 35 then
        OptConfig.optimizeMeshes = true
        OptConfig.removeTextures = true
    end
    
    if intensity >= 50 then
        OptConfig.removeDecals = true
        OptConfig.disableSurfaceGuis = true
    end
    
    if intensity >= 65 then
        OptConfig.removeEffects = true
        OptConfig.removeFire = true
        OptConfig.removeSmoke = true
        OptConfig.disablePostEffects = true
    end
    
    if intensity >= 75 then
        OptConfig.lowPhysics = true
        OptConfig.optimizeConstraints = true
        OptConfig.reduceFOV = true
    end
    
    if intensity >= 90 then
        OptConfig.disableCollision = true
        OptConfig.optimizeBillboardGuis = true
    end
    
    -- Apply camera immediately
    if Camera and OptConfig.optimizeCamera then
        pcall(function()
            Camera.FieldOfView = OptConfig.reduceFOV and 60 or 70
        end)
    end
end

ApplyIntensity(Settings.Intensity)

-- ============================================================================
-- OBJECT OPTIMIZATION ENGINE
-- ============================================================================

local ProcessedObjects = {}

-- Check if object belongs to local character
local function IsLocalCharacter(obj)
    if not obj or not Character then return false end
    return obj:IsDescendantOf(Character) or obj == Character
end

-- Check if object is important (don't optimize)
local function IsImportantObject(obj)
    if IsLocalCharacter(obj) then return true end
    
    -- Giữ các UI quan trọng
    if obj:IsA("ScreenGui") or obj:IsA("BillboardGui") then
        local name = obj.Name:lower()
        if name:find("health") or name:find("menu") or name:find("hud") then
            return true
        end
    end
    
    -- Giữ các object có script
    if obj:FindFirstChildOfClass("Script") or obj:FindFirstChildOfClass("LocalScript") then
        return true
    end
    
    return false
end

-- Soft disable (ẩn thay vì xóa)
local function SoftDisable(obj, objType)
    if not obj or not obj.Parent then return end
    
    AntiBan:SafeExecute(function()
        if objType == "decal" and obj:IsA("Decal") then
            obj.Transparency = 1
        elseif objType == "texture" and obj:IsA("Texture") then
            if obj.Transparency then obj.Transparency = 1 end
        elseif objType == "effect" then
            if obj.Enabled ~= nil then obj.Enabled = false end
        elseif objType == "gui" then
            if obj.Enabled ~= nil then obj.Enabled = false end
        end
    end, objType)
end

-- Main optimization function
local function OptimizeObject(obj)
    if not obj or not obj.Parent then return end
    if IsImportantObject(obj) then return end
    if ProcessedObjects[obj] then return end
    
    ProcessedObjects[obj] = true
    
    -- BasePart optimizations
    if obj:IsA("BasePart") then
        if OptConfig.lowMaterials then
            AntiBan:SafeExecute(function()
                obj.Material = Enum.Material.SmoothPlastic
                if OptConfig.reduceReflectance then
                    obj.Reflectance = 0
                end
            end, "material")
        end
        
        if OptConfig.disableShadows and obj.CastShadow ~= nil then
            AntiBan:SafeExecute(function()
                obj.CastShadow = false
            end, "shadow")
        end
        
        if OptConfig.lowPhysics then
            AntiBan:SafeExecute(function()
                if not obj.Anchored then
                    obj.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.1, 0.1, 1, 1)
                end
            end, "physics")
        end
        
        if OptConfig.disableCollision then
            AntiBan:SafeExecute(function()
                if not obj.Anchored and obj.CanCollide then
                    obj.CanCollide = false
                end
            end, "collision")
        end
    
    -- MeshPart optimization
    elseif obj:IsA("MeshPart") and OptConfig.optimizeMeshes then
        AntiBan:SafeExecute(function()
            obj.RenderFidelity = Enum.RenderFidelity.Performance
            obj.CollisionFidelity = Enum.CollisionFidelity.Box
            if obj.DoubleSided ~= nil then
                obj.DoubleSided = false
            end
        end, "mesh")
    
    -- SpecialMesh optimization
    elseif obj:IsA("SpecialMesh") and OptConfig.optimizeMeshes then
        AntiBan:SafeExecute(function()
            if obj.MeshType == Enum.MeshType.FileMesh then
                obj.MeshType = Enum.MeshType.Brick
            end
        end, "specialmesh")
    
    -- Decals
    elseif obj:IsA("Decal") and OptConfig.removeDecals then
        SoftDisable(obj, "decal")
    
    -- Textures
    elseif obj:IsA("Texture") and OptConfig.removeTextures then
        SoftDisable(obj, "texture")
    
    -- Particle Effects
    elseif OptConfig.removeEffects and obj:IsA("ParticleEmitter") then
        SoftDisable(obj, "effect")
    
    elseif OptConfig.removeEffects and (obj:IsA("Trail") or obj:IsA("Beam")) then
        SoftDisable(obj, "effect")
    
    -- Fire & Smoke
    elseif obj:IsA("Fire") and OptConfig.removeFire then
        SoftDisable(obj, "effect")
    
    elseif obj:IsA("Smoke") and OptConfig.removeSmoke then
        SoftDisable(obj, "effect")
    
    -- Other effects
    elseif OptConfig.removeEffects and (obj:IsA("Sparkles") or obj:IsA("PointLight") or obj:IsA("SpotLight")) then
        SoftDisable(obj, "effect")
    
    -- SurfaceGui
    elseif obj:IsA("SurfaceGui") and OptConfig.disableSurfaceGuis then
        SoftDisable(obj, "gui")
    
    -- BillboardGui
    elseif obj:IsA("BillboardGui") and OptConfig.optimizeBillboardGuis then
        AntiBan:SafeExecute(function()
            obj.MaxDistance = 50
        end, "billboard")
    
    -- Sounds
    elseif obj:IsA("Sound") and OptConfig.optimizeSounds then
        AntiBan:SafeExecute(function()
            if obj.Volume > OptConfig.maxSoundVolume then
                obj.Volume = OptConfig.maxSoundVolume
            end
            if obj.RollOffMaxDistance > 100 then
                obj.RollOffMaxDistance = 100
            end
        end, "sound")
    
    -- Constraints
    elseif OptConfig.optimizeConstraints and obj:IsA("Constraint") then
        AntiBan:SafeExecute(function()
            obj.Enabled = true -- Keep enabled but with lower priority
        end, "constraint")
    end
end

-- ============================================================================
-- LIGHTING & ENVIRONMENT OPTIMIZATION
-- ============================================================================

local function OptimizeLighting()
    pcall(function()
        if OptConfig.disableShadows then
            Lighting.GlobalShadows = false
        end
        
        if OptConfig.optimizeLighting then
            Lighting.Brightness = 2
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            Lighting.Ambient = Color3.fromRGB(100, 100, 100)
            Lighting.FogEnd = 100000
        end
        
        if OptConfig.disablePostEffects then
            for _, effect in ipairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then
                    AntiBan:SafeExecute(function()
                        effect.Enabled = false
                    end, "posteffect")
                end
            end
        end
    end)
end

-- ============================================================================
-- WORKSPACE OPTIMIZATION
-- ============================================================================

local function OptimizeWorkspace()
    pcall(function()
        -- Enable streaming để giảm tải
        Workspace.StreamingEnabled = true
        Workspace.StreamingMinRadius = 32
        Workspace.StreamingTargetRadius = 128
    end)
    
    -- Optimize tất cả objects hiện có
    task.spawn(function()
        local descendants = Workspace:GetDescendants()
        local batchSize = 50
        
        for i = 1, #descendants, batchSize do
            for j = i, math.min(i + batchSize - 1, #descendants) do
                OptimizeObject(descendants[j])
            end
            
            -- Break để tránh lag spike
            task.wait()
        end
    end)
end

-- ============================================================================
-- FPS TRACKING & ADAPTIVE SYSTEM
-- ============================================================================

local FPSTracker = {
    samples = {},
    maxSamples = 40,
    current = 60,
    average = 60,
    min = 60,
    max = 60,
    lastUpdate = 0,
}

function FPSTracker:Update(deltaTime)
    local fps = (deltaTime > 0) and (1 / deltaTime) or 60
    fps = math.clamp(fps, 0, 240)
    
    self.current = fps
    table.insert(self.samples, fps)
    
    if #self.samples > self.maxSamples then
        table.remove(self.samples, 1)
    end
    
    -- Calculate statistics
    local sum, min, max = 0, 999, 0
    for _, sample in ipairs(self.samples) do
        sum = sum + sample
        min = math.min(min, sample)
        max = math.max(max, sample)
    end
    
    self.average = sum / #self.samples
    self.min = min
    self.max = max
end

function FPSTracker:AdaptiveOptimize()
    if not OptConfig.optimizeCamera or not Camera then return end
    if tick() - self.lastUpdate < 1 then return end
    
    self.lastUpdate = tick()
    local targetFPS = OptConfig.targetFPS
    local minFPS = OptConfig.minFPS
    
    -- FPS thấp - tăng optimization
    if self.average < minFPS then
        pcall(function()
            local currentFOV = Camera.FieldOfView
            Camera.FieldOfView = math.max(50, currentFOV - 2)
            
            Lighting.Brightness = math.max(1.5, Lighting.Brightness - 0.1)
        end)
        
        -- Tăng intensity tự động nếu bật AutoAdapt
        if Settings.AutoAdapt and Settings.Intensity < 95 then
            ApplyIntensity(Settings.Intensity + 5)
        end
    
    -- FPS cao - giảm optimization
    elseif self.average > targetFPS + 10 then
        pcall(function()
            local targetFOV = OptConfig.reduceFOV and 60 or 70
            local currentFOV = Camera.FieldOfView
            Camera.FieldOfView = math.min(targetFOV, currentFOV + 1)
            
            Lighting.Brightness = math.min(2, Lighting.Brightness + 0.05)
        end)
    end
end

-- ============================================================================
-- CONNECTION MANAGEMENT
-- ============================================================================

local Connections = {}

local function ConnectDescendantMonitor()
    if Connections.descendantAdded then return end
    
    Connections.descendantAdded = Workspace.DescendantAdded:Connect(function(obj)
        task.defer(OptimizeObject, obj)
    end)
end

local function ConnectFPSMonitor()
    if Connections.fpsMonitor then return end
    
    Connections.fpsMonitor = RunService.RenderStepped:Connect(function(dt)
        FPSTracker:Update(dt)
        FPSTracker:AdaptiveOptimize()
    end)
end

local function DisconnectAll()
    for name, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
            Connections[name] = nil
        end
    end
end

-- ============================================================================
-- MAIN ENABLE/DISABLE FUNCTIONS
-- ============================================================================

local function EnableOptimizations()
    if Settings.Enabled then return end
    Settings.Enabled = true
    
    print("[FixLag] Enabling optimizations...")
    print("  Game:", CurrentGame.name)
    print("  Executor:", ExecutorInfo.name)
    print("  Intensity:", Settings.Intensity .. "%")
    
    -- Apply optimizations
    OptimizeLighting()
    OptimizeWorkspace()
    
    -- Start monitoring
    ConnectDescendantMonitor()
    ConnectFPSMonitor()
    
    print("[FixLag] ✓ Optimizations active!")
end

local function DisableOptimizations()
    if not Settings.Enabled then return end
    Settings.Enabled = false
    
    print("[FixLag] Disabling optimizations...")
    
    -- Disconnect all
    DisconnectAll()
    
    -- Reset camera
    pcall(function()
        if Camera then
            Camera.FieldOfView = 70
        end
        Lighting.Brightness = 1
    end)
    
    -- Clear processed objects
    ProcessedObjects = {}
    
    print("[FixLag] Optimizations disabled.")
end

-- ============================================================================
-- GUI SYSTEM (IMPROVED)
-- ============================================================================

local GUI = {instance = nil}

function GUI:Create()
    if self.instance and self.instance.Parent then
        self.instance.Enabled = Settings.GuiVisible
        return
    end
    
    local parent = gethui()
    
    -- ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name = "FixLagGUI_" .. tostring(math.random(10000, 99999))
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Protect if possible
    if ExecutorInfo.features.protectGui then
        pcall(function()
            if syn and syn.protect_gui then
                syn.protect_gui(sg)
            elseif protect_gui then
                protect_gui(sg)
            end
        end)
    end
    
    -- Main Frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(300, 200)
    frame.Position = UDim2.new(0.5, -150, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.fromOffset(15, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "⚡ Fix Lag v2.5"
    title.Parent = titleBar
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(30, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Text = "×"
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn
    
    -- Info Labels
    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -30, 0, 50)
    infoFrame.Position = UDim2.fromOffset(15, 50)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent = frame
    
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0.5, -5, 0, 20)
    fpsLabel.Position = UDim2.fromOffset(0, 0)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Font = Enum.Font.Gotham
    fpsLabel.TextSize = 13
    fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    fpsLabel.Text = "FPS: " .. math.floor(FPSTracker.current)
    fpsLabel.Parent = infoFrame
    
    local gameLabel = Instance.new("TextLabel")
    gameLabel.Size = UDim2.new(0.5, -5, 0, 20)
    gameLabel.Position = UDim2.new(0.5, 5, 0, 0)
    gameLabel.BackgroundTransparency = 1
    gameLabel.Font = Enum.Font.Gotham
    gameLabel.TextSize = 11
    gameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    gameLabel.TextXAlignment = Enum.TextXAlignment.Right
    gameLabel.Text = ExecutorInfo.name
    gameLabel.Parent = infoFrame
    
    local intensityLabel = Instance.new("TextLabel")
    intensityLabel.Size = UDim2.new(1, 0, 0, 20)
    intensityLabel.Position = UDim2.fromOffset(0, 25)
    intensityLabel.BackgroundTransparency = 1
    intensityLabel.Font = Enum.Font.GothamBold
    intensityLabel.TextSize = 14
    intensityLabel.TextColor3 = Color3.new(1, 1, 1)
    intensityLabel.TextXAlignment = Enum.TextXAlignment.Center
    intensityLabel.Text = "Intensity: " .. Settings.Intensity .. "%"
    intensityLabel.Parent = infoFrame
    
    -- Slider
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, -30, 0, 25)
    sliderFrame.Position = UDim2.fromOffset(15, 110)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = frame
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 12)
    sliderCorner.Parent = sliderFrame
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(Settings.Intensity / 100, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderFrame
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 12)
    fillCorner.Parent = sliderFill
    
    local sliderKnob = Instance.new("TextButton")
    sliderKnob.Size = UDim2.fromOffset(18, 25)
    sliderKnob.Position = UDim2.new(Settings.Intensity / 100, -9, 0, 0)
    sliderKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.Text = ""
    sliderKnob.Parent = sliderFrame
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0, 12)
    knobCorner.Parent = sliderKnob
    
    -- Toggle Button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -30, 0, 40)
    toggleBtn.Position = UDim2.fromOffset(15, 145)
    toggleBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(60, 60, 60)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 16
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.Text = Settings.Enabled and "✓ ENABLED" or "ENABLE"
    toggleBtn.Parent = frame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleBtn
    
    -- Slider Logic
    local dragging = false
    
    local function updateSlider(x)
        local relPos = math.clamp(x - sliderFrame.AbsolutePosition.X, 0, sliderFrame.AbsoluteSize.X)
        local percent = math.floor((relPos / sliderFrame.AbsoluteSize.X) * 100)
        percent = math.clamp(percent, 0, 100)
        
        sliderFill.Size = UDim2.new(percent / 100, 0, 1, 0)
        sliderKnob.Position = UDim2.new(percent / 100, -9, 0, 0)
        intensityLabel.Text = "Intensity: " .. percent .. "%"
        
        ApplyIntensity(percent)
    end
    
    sliderKnob.MouseButton1Down:Connect(function()
        dragging = true
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position.X)
        end
    end)
    
    sliderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            updateSlider(input.Position.X)
        end
    end)
    
    -- Toggle Logic
    toggleBtn.MouseButton1Click:Connect(function()
        if Settings.Enabled then
            DisableOptimizations()
            toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            toggleBtn.Text = "ENABLE"
        else
            EnableOptimizations()
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
            toggleBtn.Text = "✓ ENABLED"
        end
    end)
    
    -- Close Logic
    closeBtn.MouseButton1Click:Connect(function()
        Settings.GuiVisible = false
        sg.Enabled = false
    end)
    
    -- FPS Update Loop
    task.spawn(function()
        while sg and sg.Parent do
            if fpsLabel then
                fpsLabel.Text = string.format("FPS: %d (Avg: %d)", 
                    math.floor(FPSTracker.current), 
                    math.floor(FPSTracker.average))
            end
            task.wait(0.5)
        end
    end)
    
    sg.Parent = parent
    self.instance = sg
end

function GUI:Toggle()
    Settings.GuiVisible = not Settings.GuiVisible
    if Settings.GuiVisible then
        if not self.instance or not self.instance.Parent then
            self:Create()
        else
            self.instance.Enabled = true
        end
    else
        if self.instance then
            self.instance.Enabled = false
        end
    end
end

-- ============================================================================
-- HOTKEYS
-- ============================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Right Shift = Toggle Optimization
    if input.KeyCode == Enum.KeyCode.RightShift then
        if Settings.Enabled then
            DisableOptimizations()
        else
            EnableOptimizations()
        end
        
        -- Update GUI if visible
        if GUI.instance and GUI.instance.Parent then
            local toggleBtn = GUI.instance:FindFirstChild("Frame"):FindFirstChild("TextButton", true)
            if toggleBtn then
                toggleBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(0, 180, 90) or Color3.fromRGB(60, 60, 60)
                toggleBtn.Text = Settings.Enabled and "✓ ENABLED" or "ENABLE"
            end
        end
    
    -- Right Control = Toggle GUI
    elseif input.KeyCode == Enum.KeyCode.RightControl then
        GUI:Toggle()
    end
end)

-- ============================================================================
-- API EXPORT
-- ============================================================================

local API = {
    Enable = EnableOptimizations,
    Disable = DisableOptimizations,
    
    Toggle = function()
        if Settings.Enabled then
            DisableOptimizations()
        else
            EnableOptimizations()
        end
    end,
    
    SetIntensity = function(intensity)
        ApplyIntensity(intensity)
    end,
    
    ShowGUI = function()
        Settings.GuiVisible = true
        GUI:Create()
    end,
    
    HideGUI = function()
        Settings.GuiVisible = false
        if GUI.instance then
            GUI.instance.Enabled = false
        end
    end,
    
    GetStatus = function()
        return {
            enabled = Settings.Enabled,
            intensity = Settings.Intensity,
            fps = {
                current = math.floor(FPSTracker.current),
                average = math.floor(FPSTracker.average),
                min = math.floor(FPSTracker.min),
                max = math.floor(FPSTracker.max),
            },
            game = CurrentGame.name,
            executor = ExecutorInfo.name,
            antiban = {
                suspicionLevel = AntiBan.state.suspicionLevel,
                totalOps = AntiBan.state.totalOperations,
            }
        }
    end,
}

-- ============================================================================
-- AUTO-START
-- ============================================================================

if Settings.Enabled then
    EnableOptimizations()
end

if Settings.GuiVisible then
    GUI:Create()
end

print([[
╔════════════════════════════════════════════╗
║   Universal Fix Lag v2.5 - Loaded!        ║
║   • Multi-game compatible                 ║
║   • Advanced anti-ban protection          ║
║   • Adaptive optimization                 ║
║                                           ║
║   Hotkeys:                                ║
║   • Right Shift: Toggle optimization      ║
║   • Right Control: Toggle GUI             ║
╚════════════════════════════════════════════╝
]])

return API
