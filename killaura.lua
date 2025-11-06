-- Universal Kill Aura - Optimized
-- Compatible with all executors and games

-- Executor compatibility
local gethui = gethui or get_hidden_gui or function() return game:GetService("CoreGui") end
local protectgui = syn and syn.protect_gui or protectgui or function() end
local mouse1click = mouse1click or function() end

-- Services (cached)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Player
local player = Players.LocalPlayer
local playerGui = gethui()

-- Config
local CONFIG = {
    Enabled = false,
    Range = 20,
    Delay = 0.15,
    ShowVisuals = true,
    ToggleKey = Enum.KeyCode.K,
}

-- Anti-Ban
local ANTIBAN = {
    MaxCPS = 12,
    SafeDistance = 5,
    MissChance = 0.05,
    AttackLimit = 5,
    CooldownChance = 0.1,
    CooldownTime = 2,
}

-- State
local state = {
    lastAttack = 0,
    attackCount = 0,
    resetTime = tick(),
    consecutive = 0,
    currentTarget = nil,
    inCooldown = false,
    lastCooldown = tick(),
    rangeIndicator = nil,
}

-- Cache
local cache = {
    character = nil,
    hrp = nil,
    combatRemotes = {},
    lastCacheUpdate = 0,
}

-- Utility Functions
local function safeCall(func, ...)
    local success, result = pcall(func, ...)
    return success and result or nil
end

local function getRandomDelay()
    local base = CONFIG.Delay
    local variance = 0.1
    local r1, r2 = math.random(), math.random()
    local gaussian = math.sqrt(-2 * math.log(r1)) * math.cos(2 * math.pi * r2)
    return math.clamp(base + (gaussian * variance), 0.1, 0.5)
end

local function checkCPS()
    local now = tick()
    if now - state.resetTime >= 1 then
        state.attackCount = 0
        state.resetTime = now
    end
    return state.attackCount < ANTIBAN.MaxCPS
end

local function shouldMiss()
    return math.random() < ANTIBAN.MissChance
end

local function checkCooldown()
    local now = tick()
    if state.inCooldown then
        if now - state.lastCooldown >= ANTIBAN.CooldownTime then
            state.inCooldown = false
        end
        return true
    end
    if math.random() < ANTIBAN.CooldownChance then
        state.inCooldown = true
        state.lastCooldown = now
        return true
    end
    return false
end

-- Character Functions
local function updateCache()
    local now = tick()
    if now - cache.lastCacheUpdate < 1 then return end
    
    cache.character = player.Character
    if cache.character then
        cache.hrp = cache.character:FindFirstChild("HumanoidRootPart") 
                 or cache.character:FindFirstChild("Torso")
                 or cache.character:FindFirstChild("UpperTorso")
    end
    
    cache.lastCacheUpdate = now
end

local function getHRP()
    updateCache()
    return cache.hrp
end

-- Team Check
local function isTeammate(p)
    if not player.Team or not p.Team then return false end
    return player.Team == p.Team
end

-- Raycast Check
local function canSeeTarget(from, to)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {cache.character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true
    
    local result = workspace:Raycast(from, to - from, params)
    if not result then return true end
    
    local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
    return hitChar and hitChar:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Find Targets
local function findTargets()
    local targets = {}
    local myHRP = getHRP()
    if not myHRP then return targets end
    
    local myPos = myHRP.Position
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local hrp = p.Character:FindFirstChild("HumanoidRootPart") 
                     or p.Character:FindFirstChild("Torso")
                     or p.Character:FindFirstChild("UpperTorso")
            
            if hum and hrp and hum.Health > 0 and not isTeammate(p) then
                local dist = (myPos - hrp.Position).Magnitude
                
                if dist >= ANTIBAN.SafeDistance and dist <= CONFIG.Range then
                    if canSeeTarget(myPos, hrp.Position) then
                        local lookVec = hrp.CFrame.LookVector
                        local dirToMe = (myPos - hrp.Position).Unit
                        local priority = lookVec:Dot(dirToMe) < 0.5 and 1 or 0
                        
                        table.insert(targets, {
                            player = p,
                            hrp = hrp,
                            distance = dist,
                            priority = priority
                        })
                    end
                end
            end
        end
    end
    
    return targets
end

-- Combat Remotes Cache
local function updateCombatRemotes()
    if #cache.combatRemotes > 0 then return end
    
    safeCall(function()
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local name = v.Name:lower()
                if name:match("damage") or name:match("attack") or name:match("hit")
                   or name:match("combat") or name:match("punch") or name:match("shoot") then
                    table.insert(cache.combatRemotes, v)
                end
            end
        end
    end)
end

-- Attack
local function attack(target)
    if not checkCPS() or shouldMiss() then return end
    if state.consecutive >= ANTIBAN.AttackLimit then return end
    
    state.attackCount = state.attackCount + 1
    state.consecutive = state.consecutive + 1
    state.currentTarget = target.player
    
    -- Method 1: Tool activation
    safeCall(function()
        local tool = cache.character:FindFirstChildOfClass("Tool")
        if tool then
            tool:Activate()
            
            -- Fire tool remotes
            for _, v in pairs(tool:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    safeCall(v.FireServer, v, target.hrp)
                    safeCall(v.FireServer, v, {Target = target.hrp})
                elseif v:IsA("RemoteFunction") then
                    safeCall(v.InvokeServer, v, target.hrp)
                end
            end
        end
    end)
    
    -- Method 2: Cached combat remotes
    updateCombatRemotes()
    for _, remote in pairs(cache.combatRemotes) do
        safeCall(remote.FireServer, remote, target.hrp)
        safeCall(remote.FireServer, remote, target.player)
    end
    
    -- Method 3: Mouse simulation
    safeCall(function()
        local mouse = player:GetMouse()
        if mouse then
            mouse.Hit = target.hrp.CFrame
            mouse1click()
        end
    end)
end

-- GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KA_" .. HttpService:GenerateGUID(false):sub(1, 8)
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true

protectgui(screenGui)

-- Cleanup old GUIs
for _, gui in pairs(playerGui:GetChildren()) do
    if gui.Name:match("KA_") then
        safeCall(gui.Destroy, gui)
    end
end

screenGui.Parent = playerGui

-- Main Frame
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 200)
main.Position = UDim2.new(0.5, -130, 0.3, 0)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
main.BorderSizePixel = 0
main.Active = true
main.Parent = screenGui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", main).Color = Color3.fromRGB(180, 30, 30)

local grad = Instance.new("UIGradient", main)
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 20))
}
grad.Rotation = 90

-- Dragging
local dragging, dragInput, dragStart, startPos

main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Header
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 32)
header.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
header.BorderSizePixel = 0

Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
local headerFix = Instance.new("Frame", header)
headerFix.Size = UDim2.new(1, 0, 0, 8)
headerFix.Position = UDim2.new(0, 0, 1, -8)
headerFix.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
headerFix.BorderSizePixel = 0

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Kill Aura"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize Button
local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0, 26, 0, 26)
minBtn.Position = UDim2.new(1, -60, 0, 3)
minBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
minBtn.Text = "-"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.BorderSizePixel = 0

Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

-- Close Button
local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -30, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0

Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

-- Container
local container = Instance.new("Frame", main)
container.Size = UDim2.new(1, -16, 1, -40)
container.Position = UDim2.new(0, 8, 0, 36)
container.BackgroundTransparency = 1

-- Toggle Button
local toggleBtn = Instance.new("TextButton", container)
toggleBtn.Size = UDim2.new(1, 0, 0, 36)
toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
toggleBtn.Text = "DISABLED"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.BorderSizePixel = 0

Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

-- Range Label
local rangeLabel = Instance.new("TextLabel", container)
rangeLabel.Size = UDim2.new(1, 0, 0, 18)
rangeLabel.Position = UDim2.new(0, 0, 0, 42)
rangeLabel.BackgroundTransparency = 1
rangeLabel.Text = "Range: " .. CONFIG.Range
rangeLabel.Font = Enum.Font.Gotham
rangeLabel.TextSize = 11
rangeLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
rangeLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Range Slider
local rangeSliderBg = Instance.new("Frame", container)
rangeSliderBg.Size = UDim2.new(1, 0, 0, 16)
rangeSliderBg.Position = UDim2.new(0, 0, 0, 62)
rangeSliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
rangeSliderBg.BorderSizePixel = 0

Instance.new("UICorner", rangeSliderBg).CornerRadius = UDim.new(0, 8)

local rangeFill = Instance.new("Frame", rangeSliderBg)
rangeFill.Size = UDim2.new(CONFIG.Range / 50, 0, 1, 0)
rangeFill.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
rangeFill.BorderSizePixel = 0

Instance.new("UICorner", rangeFill).CornerRadius = UDim.new(0, 8)

-- Delay Label
local delayLabel = Instance.new("TextLabel", container)
delayLabel.Size = UDim2.new(1, 0, 0, 18)
delayLabel.Position = UDim2.new(0, 0, 0, 84)
delayLabel.BackgroundTransparency = 1
delayLabel.Text = "Delay: " .. CONFIG.Delay
delayLabel.Font = Enum.Font.Gotham
delayLabel.TextSize = 11
delayLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
delayLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Delay Slider
local delaySliderBg = Instance.new("Frame", container)
delaySliderBg.Size = UDim2.new(1, 0, 0, 16)
delaySliderBg.Position = UDim2.new(0, 0, 0, 104)
delaySliderBg.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
delaySliderBg.BorderSizePixel = 0

Instance.new("UICorner", delaySliderBg).CornerRadius = UDim.new(0, 8)

local delayFill = Instance.new("Frame", delaySliderBg)
delayFill.Size = UDim2.new(CONFIG.Delay / 0.5, 0, 1, 0)
delayFill.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
delayFill.BorderSizePixel = 0

Instance.new("UICorner", delayFill).CornerRadius = UDim.new(0, 8)

-- Status Label
local statusLabel = Instance.new("TextLabel", container)
statusLabel.Size = UDim2.new(1, 0, 0, 18)
statusLabel.Position = UDim2.new(0, 0, 0, 126)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statusLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Range Slider Logic
local rangeDragging = false
rangeSliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        rangeDragging = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        rangeDragging = false
    end
end)

-- Delay Slider Logic
local delayDragging = false
delaySliderBg.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        delayDragging = true
    end
end)

-- Range Indicator
local function createRangeIndicator()
    if state.rangeIndicator then
        safeCall(state.rangeIndicator.Destroy, state.rangeIndicator)
    end
    
    local part = Instance.new("Part")
    part.Name = "RI_" .. HttpService:GenerateGUID(false):sub(1, 6)
    part.Anchored = true
    part.CanCollide = false
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(0.4, CONFIG.Range * 2, CONFIG.Range * 2)
    part.Transparency = 0.75
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(255, 0, 0)
    part.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
    part.Parent = workspace
    
    local outline = Instance.new("SelectionBox", part)
    outline.LineThickness = 0.04
    outline.Color3 = Color3.fromRGB(255, 80, 80)
    outline.SurfaceTransparency = 0.9
    outline.Adornee = part
    
    state.rangeIndicator = part
end

local function updateRangeIndicator()
    if not state.rangeIndicator or not CONFIG.ShowVisuals then return end
    
    local hrp = getHRP()
    if hrp then
        state.rangeIndicator.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, 0, math.rad(90))
        state.rangeIndicator.Size = Vector3.new(0.4, CONFIG.Range * 2, CONFIG.Range * 2)
        state.rangeIndicator.Transparency = CONFIG.Enabled and 0.75 or 1
    end
end

-- Toggle
local function toggle()
    CONFIG.Enabled = not CONFIG.Enabled
    
    if CONFIG.Enabled then
        toggleBtn.Text = "ENABLED"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 30)
        if not state.rangeIndicator then
            createRangeIndicator()
        end
    else
        toggleBtn.Text = "DISABLED"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        state.consecutive = 0
        state.currentTarget = nil
    end
end

toggleBtn.MouseButton1Click:Connect(toggle)

-- Minimize
local isMinimized = false
local fullSize = main.Size

minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        main.Size = UDim2.new(0, 260, 0, 32)
        container.Visible = false
        minBtn.Text = "+"
    else
        main.Size = fullSize
        container.Visible = true
        minBtn.Text = "-"
    end
end)

-- Close
closeBtn.MouseButton1Click:Connect(function()
    CONFIG.Enabled = false
    safeCall(screenGui.Destroy, screenGui)
    if state.rangeIndicator then
        safeCall(state.rangeIndicator.Destroy, state.rangeIndicator)
    end
end)

-- Toggle GUI
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == CONFIG.ToggleKey then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- Main Loop
RunService.Heartbeat:Connect(function()
    -- Update sliders
    if rangeDragging then
        local mouse = UserInputService:GetMouseLocation()
        local pos = rangeSliderBg.AbsolutePosition
        local size = rangeSliderBg.AbsoluteSize
        local rel = math.clamp((mouse.X - pos.X) / size.X, 0, 1)
        CONFIG.Range = math.floor(rel * 45 + 5)
        rangeFill.Size = UDim2.new(rel, 0, 1, 0)
        rangeLabel.Text = "Range: " .. CONFIG.Range
    end
    
    if delayDragging then
        local mouse = UserInputService:GetMouseLocation()
        local pos = delaySliderBg.AbsolutePosition
        local size = delaySliderBg.AbsoluteSize
        local rel = math.clamp((mouse.X - pos.X) / size.X, 0, 1)
        CONFIG.Delay = math.floor(rel * 50) / 100
        delayFill.Size = UDim2.new(rel, 0, 1, 0)
        delayLabel.Text = "Delay: " .. CONFIG.Delay
    end
    
    if not CONFIG.Enabled then
        statusLabel.Text = "Disabled"
        return
    end
    
    updateRangeIndicator()
    
    if checkCooldown() then
        statusLabel.Text = "Cooldown..."
        return
    end
    
    local now = tick()
    if now - state.lastAttack < getRandomDelay() then return end
    
    local targets = findTargets()
    
    if #targets == 0 then
        state.consecutive = 0
        state.currentTarget = nil
        statusLabel.Text = "No targets"
        return
    end
    
    table.sort(targets, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.distance < b.distance
    end)
    
    attack(targets[1])
    state.lastAttack = now
    statusLabel.Text = "Active | " .. #targets .. " targets"
    
    if state.consecutive >= ANTIBAN.AttackLimit then
        task.wait(math.random(1, 2))
        state.consecutive = 0
        state.currentTarget = nil
    end
end)

-- Character respawn
player.CharacterAdded:Connect(function()
    cache.character = nil
    cache.hrp = nil
    task.wait(1)
    updateCache()
    if CONFIG.ShowVisuals then
        createRangeIndicator()
    end
end)

-- Initialize
task.spawn(function()
    task.wait(1)
    updateCache()
    if CONFIG.ShowVisuals then
        createRangeIndicator()
    end
    print("Kill Aura loaded!")
    print("Press K to toggle")
end)

-- Cleanup
if getgenv then
    getgenv().KillAuraCleanup = function()
        CONFIG.Enabled = false
        safeCall(screenGui.Destroy, screenGui)
        if state.rangeIndicator then
            safeCall(state.rangeIndicator.Destroy, state.rangeIndicator)
        end
    end
end
