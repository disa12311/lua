-- Universal Kill Aura Script with Anti-Ban
-- Compatible with all major executors
-- Optimized for safety and performance

-- Check executor environment
local is_sirhurt_closure = is_sirhurt_closure or issentinelclosure
local is_syn_closure = is_syn_closure or issynapsefunction
local getgc = getgc or get_gc_objects
local getconnections = getconnections or get_signal_cons
local gethiddenproperty = gethiddenproperty or get_hidden_property
local gethui = gethui or get_hidden_gui or function() return game:GetService("CoreGui") end

local function loadScript()
    -- Services
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    -- Player
    local player = Players.LocalPlayer
    local playerGui = gethui and gethui() or player:WaitForChild("PlayerGui")
    
    -- Anti-Ban Configuration (Nâng cao)
    local ANTI_BAN = {
        RandomizeDelay = true,      -- Randomize attack delays
        MaxCPS = 15,                -- Max clicks per second (giảm xuống 15)
        HumanBehavior = true,       -- Simulate human behavior
        StealthMode = false,        -- Hide visual indicators
        SafeDistance = 5,           -- Minimum safe distance (tăng lên 5)
        SmartTarget = true,         -- Chỉ tấn công khi enemy nhìn khác hướng
        RandomMiss = true,          -- Bỏ lỡ ngẫu nhiên đôi khi
        MissChance = 0.05,          -- 5% cơ hội bỏ lỡ
        AttackPattern = true,       -- Thay đổi pattern tấn công
        CooldownPeriod = true,      -- Nghỉ giữa các đợt tấn công
        CooldownChance = 0.1,       -- 10% cơ hội nghỉ
        CooldownTime = 2,           -- Nghỉ 2 giây
    }
    
    -- Main Config
    local CONFIG = {
        Enabled = false,
        Range = 20,
        MinDelay = 0.15,            -- Tăng min delay
        MaxDelay = 0.4,             -- Tăng max delay
        TargetTeammates = false,
        ShowVisuals = true,
        ToggleKey = Enum.KeyCode.K,
        WallCheck = true,           -- Bật wall check mặc định
        TargetLock = false,         -- Lock vào 1 target
        AttackLimit = 5,            -- Giới hạn 5 đòn liên tiếp
    }
    
    local lastAttackTime = 0
    local rangeIndicator
    local attackCount = 0
    local lastResetTime = tick()
    local currentTarget = nil
    local consecutiveAttacks = 0
    local lastCooldown = tick()
    local inCooldown = false
    local attackHistory = {}
    
    -- Utility Functions
    local function safeWait(duration)
        local start = tick()
        while tick() - start < duration do
            RunService.Heartbeat:Wait()
        end
    end
    
    local function getRandomDelay()
        if ANTI_BAN.RandomizeDelay then
            -- Sử dụng phân phối chuẩn để delay tự nhiên hơn
            local base = (CONFIG.MinDelay + CONFIG.MaxDelay) / 2
            local variance = (CONFIG.MaxDelay - CONFIG.MinDelay) / 4
            local random1 = math.random()
            local random2 = math.random()
            local gaussian = math.sqrt(-2 * math.log(random1)) * math.cos(2 * math.pi * random2)
            local delay = base + (gaussian * variance)
            return math.clamp(delay, CONFIG.MinDelay, CONFIG.MaxDelay)
        end
        return CONFIG.MinDelay
    end
    
    local function checkCPS()
        local currentTime = tick()
        if currentTime - lastResetTime >= 1 then
            attackCount = 0
            lastResetTime = currentTime
        end
        return attackCount < ANTI_BAN.MaxCPS
    end
    
    local function shouldMissAttack()
        if ANTI_BAN.RandomMiss then
            return math.random() < ANTI_BAN.MissChance
        end
        return false
    end
    
    local function checkCooldown()
        if not ANTI_BAN.CooldownPeriod then return false end
        
        local currentTime = tick()
        if inCooldown then
            if currentTime - lastCooldown >= ANTI_BAN.CooldownTime then
                inCooldown = false
                lastCooldown = currentTime
            end
            return true
        end
        
        if math.random() < ANTI_BAN.CooldownChance then
            inCooldown = true
            lastCooldown = currentTime
            return true
        end
        
        return false
    end
    
    local function isTargetLookingAway(targetHRP, myHRP)
        if not ANTI_BAN.SmartTarget then return true end
        
        -- Kiểm tra hướng nhìn của target
        local targetLook = targetHRP.CFrame.LookVector
        local directionToMe = (myHRP.Position - targetHRP.Position).Unit
        local dotProduct = targetLook:Dot(directionToMe)
        
        -- Nếu dot product < 0.5 nghĩa là target đang nhìn khác hướng (>60 độ)
        return dotProduct < 0.5
    end
    
    local function canAttackTarget(target)
        -- Kiểm tra attack limit
        if consecutiveAttacks >= CONFIG.AttackLimit then
            return false
        end
        
        -- Kiểm tra target lock
        if CONFIG.TargetLock and currentTarget and currentTarget ~= target then
            return false
        end
        
        return true
    end
    
    local function raycastCheck(from, to)
        if not CONFIG.WallCheck then return true end
        
        local direction = (to - from)
        local ray = Ray.new(from, direction)
        local hit = workspace:FindPartOnRay(ray, player.Character, false, true)
        
        return not hit or hit:IsDescendantOf(workspace)
    end
    
    -- Create GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KA_" .. game:GetService("HttpService"):GenerateGUID(false):sub(1, 8)
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    
    -- Protection
    pcall(function()
        if gethiddenproperty then
            gethiddenproperty(screenGui, "OnTopOfCoreBlur")
        end
        if syn and syn.protect_gui then
            syn.protect_gui(screenGui)
        end
        if protectgui then
            protectgui(screenGui)
        end
    end)
    
    -- Destroy existing GUI
    pcall(function()
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui.Name:match("KA_") or gui.Name:match("KillAura") then
                gui:Destroy()
            end
        end
    end)
    
    screenGui.Parent = playerGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 280, 0, 220)
    mainFrame.Position = UDim2.new(0.5, -140, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame
    
    -- Stroke for border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(200, 40, 40)
    stroke.Thickness = 1
    stroke.Parent = mainFrame
    
    -- Gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 33)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 23))
    }
    gradient.Rotation = 90
    gradient.Parent = mainFrame
    
    -- Dragging
    local dragging, dragInput, dragStart, startPos
    
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = header
    
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 8)
    headerFix.Position = UDim2.new(0, 0, 1, -8)
    headerFix.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Kill Aura"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    -- Minimize Button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    minimizeBtn.Position = UDim2.new(1, -68, 0, 3.5)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    minimizeBtn.Text = "-"
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Parent = header
    
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 6)
    minimizeCorner.Parent = minimizeBtn
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -35, 0, 3.5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 16
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn
    
    -- Container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(1, -20, 1, -45)
    container.Position = UDim2.new(0, 10, 0, 40)
    container.BackgroundTransparency = 1
    container.Parent = mainFrame
    
    -- Helper function to create elements
    local yOffset = 0
    
    local function createButton(text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.Position = UDim2.new(0, 0, 0, yOffset)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.BorderSizePixel = 0
        btn.Parent = container
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
        yOffset = yOffset + 45
        return btn
    end
    
    local function createLabel(text)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.Position = UDim2.new(0, 0, 0, yOffset)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = container
        yOffset = yOffset + 22
        return lbl
    end
    
    local function createSlider(labelText, min, max, default, callback)
        local label = createLabel(labelText .. ": " .. default)
        
        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(1, 0, 0, 18)
        sliderBg.Position = UDim2.new(0, 0, 0, yOffset)
        sliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = container
        
        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(0, 9)
        sliderCorner.Parent = sliderBg
        
        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBg
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 9)
        fillCorner.Parent = sliderFill
        
        local dragging = false
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        RunService.Heartbeat:Connect(function()
            if dragging then
                local mouse = UserInputService:GetMouseLocation()
                local pos = sliderBg.AbsolutePosition
                local size = sliderBg.AbsoluteSize
                local rel = math.clamp((mouse.X - pos.X) / size.X, 0, 1)
                local value = math.floor(min + rel * (max - min))
                
                sliderFill.Size = UDim2.new(rel, 0, 1, 0)
                label.Text = labelText .. ": " .. value
                callback(value)
            end
        end)
        
        yOffset = yOffset + 25
        return {label = label, slider = sliderBg, fill = sliderFill}
    end
    
    -- Create UI Elements
    local toggleBtn = createButton("DISABLED", Color3.fromRGB(200, 50, 50), function() end)
    
    local rangeSlider = createSlider("Range", 5, 50, CONFIG.Range, function(val)
        CONFIG.Range = val
    end)
    
    local delaySlider = createSlider("Delay", 1, 10, CONFIG.MinDelay * 10, function(val)
        CONFIG.MinDelay = val / 10
        CONFIG.MaxDelay = (val / 10) + 0.2
    end)
    
    local statusLabel = createLabel("Status: Ready")
    
    -- Functions
    local function getCharacter()
        return player.Character
    end
    
    local function getHRP()
        local char = getCharacter()
        return char and char:FindFirstChild("HumanoidRootPart")
    end
    
    function createRangeIndicator()
        if rangeIndicator then rangeIndicator:Destroy() end
        
        -- Tạo vòng tròn nằm ngang bao quanh người chơi
        rangeIndicator = Instance.new("Part")
        rangeIndicator.Name = "RI_" .. game:GetService("HttpService"):GenerateGUID(false):sub(1, 6)
        rangeIndicator.Anchored = true
        rangeIndicator.CanCollide = false
        rangeIndicator.Shape = Enum.PartType.Cylinder
        rangeIndicator.Size = Vector3.new(0.5, CONFIG.Range * 2, CONFIG.Range * 2)
        rangeIndicator.Transparency = ANTI_BAN.StealthMode and 1 or 0.75
        rangeIndicator.Material = Enum.Material.Neon
        rangeIndicator.Color = Color3.fromRGB(255, 0, 0)
        rangeIndicator.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
        
        -- Protection
        pcall(function()
            if setscriptable then
                setscriptable(rangeIndicator, "Parent", true)
            end
        end)
        
        rangeIndicator.Parent = workspace
        
        -- Thêm outline để dễ nhìn hơn
        local outline = Instance.new("SelectionBox")
        outline.LineThickness = 0.05
        outline.Color3 = Color3.fromRGB(255, 100, 100)
        outline.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
        outline.SurfaceTransparency = 0.9
        outline.Adornee = rangeIndicator
        outline.Parent = rangeIndicator
    end
    
    local function updateRangeIndicator()
        local hrp = getHRP()
        if rangeIndicator and hrp and CONFIG.ShowVisuals then
            -- Đặt vòng tròn nằm ngang tại vị trí người chơi
            rangeIndicator.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, 0, math.rad(90))
            rangeIndicator.Size = Vector3.new(0.5, CONFIG.Range * 2, CONFIG.Range * 2)
            
            -- Điều chỉnh độ trong suốt
            if CONFIG.Enabled and not ANTI_BAN.StealthMode then
                rangeIndicator.Transparency = 0.75
            else
                rangeIndicator.Transparency = 1
            end
        end
    end
    
    local function isTeammate(targetPlayer)
        if CONFIG.TargetTeammates then return false end
        return player.Team and targetPlayer.Team and player.Team == targetPlayer.Team
    end
    
    local function findTargets()
        local targets = {}
        local hrp = getHRP()
        if not hrp then return targets end
        
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local char = p.Character
                local hum = char:FindFirstChild("Humanoid")
                local thrp = char:FindFirstChild("HumanoidRootPart")
                
                if hum and thrp and hum.Health > 0 then
                    local dist = (hrp.Position - thrp.Position).Magnitude
                    
                    if dist >= ANTI_BAN.SafeDistance and dist <= CONFIG.Range and not isTeammate(p) then
                        if raycastCheck(hrp.Position, thrp.Position) then
                            -- Kiểm tra nếu target đang nhìn khác hướng (an toàn hơn)
                            local isLookingAway = isTargetLookingAway(thrp, hrp)
                            
                            table.insert(targets, {
                                player = p,
                                humanoid = hum,
                                hrp = thrp,
                                distance = dist,
                                priority = isLookingAway and 1 or 0 -- Ưu tiên target nhìn khác hướng
                            })
                        end
                    end
                end
            end
        end
        
        return targets
    end
    
    local function attack(target)
        if not checkCPS() then return end
        if not canAttackTarget(target.player) then return end
        if shouldMissAttack() then 
            -- Bỏ lỡ đòn để giống người thật
            return 
        end
        
        pcall(function()
            -- Sử dụng damage của game, không thay đổi gì
            attackCount = attackCount + 1
            consecutiveAttacks = consecutiveAttacks + 1
            
            -- Set current target
            currentTarget = target.player
            
            -- Lưu lịch sử tấn công
            table.insert(attackHistory, {
                target = target.player.Name,
                time = tick(),
            })
            
            -- Giới hạn history
            if #attackHistory > 50 then
                table.remove(attackHistory, 1)
            end
        end)
        
        -- Kích hoạt tool để game xử lý damage
        local char = getCharacter()
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function() 
                    tool:Activate() 
                end)
                
                -- Thử fire remote nếu có
                for _, v in pairs(tool:GetDescendants()) do
                    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                        pcall(function()
                            if v:IsA("RemoteEvent") then
                                v:FireServer(target.hrp)
                            else
                                v:InvokeServer(target.hrp)
                            end
                        end)
                    end
                end
            end
        end
    end
    
    -- Toggle Function
    local function toggle()
        CONFIG.Enabled = not CONFIG.Enabled
        
        if CONFIG.Enabled then
            toggleBtn.Text = "ENABLED"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
            if CONFIG.ShowVisuals and not rangeIndicator then
                createRangeIndicator()
            end
        else
            toggleBtn.Text = "DISABLED"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end
    
    toggleBtn.MouseButton1Click:Connect(toggle)
    
    -- Minimize button logic
    local isMinimized = false
    local fullSize = mainFrame.Size
    local minSize = UDim2.new(0, 280, 0, 35)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            mainFrame.Size = minSize
            container.Visible = false
            minimizeBtn.Text = "+"
        else
            mainFrame.Size = fullSize
            container.Visible = true
            minimizeBtn.Text = "-"
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        if rangeIndicator then rangeIndicator:Destroy() end
    end)
    
    -- Keybind
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == CONFIG.ToggleKey then
            screenGui.Enabled = not screenGui.Enabled
        end
    end)
    
    -- Main Loop
    RunService.Heartbeat:Connect(function()
        if CONFIG.Enabled then
            updateRangeIndicator()
            
            -- Kiểm tra cooldown period
            if checkCooldown() then
                statusLabel.Text = "Cooling down..."
                return
            end
            
            local currentTime = tick()
            local delay = getRandomDelay()
            
            if currentTime - lastAttackTime >= delay then
                local targets = findTargets()
                
                -- Reset consecutive attacks nếu không có target
                if #targets == 0 then
                    consecutiveAttacks = 0
                    currentTarget = nil
                end
                
                statusLabel.Text = "Active | Targets: " .. #targets
                
                if #targets > 0 then
                    -- Sort theo priority và distance
                    table.sort(targets, function(a, b)
                        if a.priority ~= b.priority then
                            return a.priority > b.priority
                        end
                        return a.distance < b.distance
                    end)
                    
                    attack(targets[1])
                    lastAttackTime = currentTime
                    
                    -- Reset consecutive attacks sau một khoảng thời gian
                    if consecutiveAttacks >= CONFIG.AttackLimit then
                        wait(math.random(1, 2)) -- Nghỉ 1-2 giây
                        consecutiveAttacks = 0
                        currentTarget = nil
                    end
                end
            end
        else
            consecutiveAttacks = 0
            currentTarget = nil
            statusLabel.Text = "Disabled"
        end
    end)
    
    -- Character respawn
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if CONFIG.ShowVisuals then
            createRangeIndicator()
        end
    end)
    
    -- Initialize
    if CONFIG.ShowVisuals then
        createRangeIndicator()
    end
    
    -- Cleanup on script unload
    if getgenv then
        getgenv().KillAuraCleanup = function()
            pcall(function() screenGui:Destroy() end)
            pcall(function() if rangeIndicator then rangeIndicator:Destroy() end end)
            print("Kill Aura cleaned up")
        end
    end
    
    print("Kill Aura loaded successfully!")
    print("Press K to toggle GUI")
end

-- Protected call with multiple fallbacks
local success, err = pcall(loadScript)
if not success then
    local success2, err2 = xpcall(loadScript, function(e)
        return debug.traceback(e)
    end)
    if not success2 then
        warn("Error loading Kill Aura:", err2 or err)
    end
end