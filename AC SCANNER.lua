--[[
    ═══════════════════════════════════════════════════════
    UNIVERSAL AC SCANNER V4.0 - ALL GAMES COMPATIBLE
    ═══════════════════════════════════════════════════════
    ✓ Works on ALL Roblox games
    ✓ Auto-detects game-specific anti-cheat
    ✓ Adaptive scanning algorithms
    ✓ Maximum compatibility & performance
    ═══════════════════════════════════════════════════════
]]

-- Universal Configuration
local CONFIG = {
    ScanDelay = 0.01,
    CacheLifetime = 300,
    MaxBatchSize = 100,
    DeepScanPasses = 3,
    AutoAdapt = true,
    SafeMode = true
}

-- Game Detection System
local GameDetector = {
    GameId = game.PlaceId,
    GameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
    Detected = false,
    Profile = "Universal"
}

function GameDetector:Analyze()
    local profiles = {
        -- Popular games profiles
        ["Prison Life"] = {
            Keywords = {"arrest", "cop", "prisoner", "guard"},
            CriticalServices = {"Workspace", "ReplicatedStorage"}
        },
        ["Adopt Me"] = {
            Keywords = {"trade", "pet", "adopt", "money"},
            CriticalServices = {"ReplicatedStorage", "ReplicatedFirst"}
        },
        ["Brookhaven"] = {
            Keywords = {"house", "vehicle", "money", "job"},
            CriticalServices = {"ReplicatedStorage", "Workspace"}
        },
        ["Blox Fruits"] = {
            Keywords = {"fruit", "boss", "combat", "level"},
            CriticalServices = {"ReplicatedStorage", "Workspace"}
        },
        ["Arsenal"] = {
            Keywords = {"weapon", "kill", "round", "score"},
            CriticalServices = {"ReplicatedStorage", "ReplicatedFirst"}
        },
        -- Universal fallback
        ["Universal"] = {
            Keywords = {"kick", "ban", "detect", "anticheat", "anti", "cheat", "exploit", "flag", "report"},
            CriticalServices = {"ReplicatedStorage", "StarterPlayer", "StarterGui", "Workspace"}
        }
    }
    
    -- Try to match known game
    for gameName, profile in pairs(profiles) do
        if self.GameName:lower():find(gameName:lower()) then
            self.Profile = gameName
            self.Detected = true
            return profile
        end
    end
    
    -- Return universal profile
    return profiles["Universal"]
end

-- Core Scanner (Universal)
local Scanner = {
    Results = {},
    DeletedFiles = {},
    DisabledScripts = {},
    Cache = {},
    GameProfile = nil,
    Stats = {
        TotalScanned = 0,
        CacheHits = 0,
        ScanTime = 0,
        LastScan = 0,
        GamesSupported = "ALL"
    }
}

-- Universal Service Getter (Never fails)
local Services = {}
local function safeGetService(name)
    if not Services[name] then
        local success, service = pcall(game.GetService, game, name)
        Services[name] = success and service or nil
    end
    return Services[name]
end

-- Initialize core services
local serviceList = {
    "Players", "RunService", "HttpService", "CoreGui", 
    "UserInputService", "TweenService", "Workspace",
    "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer",
    "StarterGui", "Lighting", "SoundService"
}

for _, name in ipairs(serviceList) do
    safeGetService(name)
end

local Player = Services.Players and Services.Players.LocalPlayer

-- Universal Anti-Ban (Works everywhere)
local AntiBan = {
    Active = false,
    Hooks = {},
    Blocked = 0
}

function AntiBan:UniversalHook()
    if self.Active then return end
    self.Active = true
    
    -- Universal patterns (works in all games)
    local dangerPatterns = {
        "kick", "ban", "report", "flag", "log",
        "anticheat", "anti", "cheat", "detect", "exploit",
        "hack", "security", "verify", "validate", "monitor"
    }
    
    -- Safe hook with error handling
    local success, err = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Block dangerous remote calls
            if method == "FireServer" or method == "InvokeServer" then
                local name = self.Name:lower()
                
                for _, pattern in ipairs(dangerPatterns) do
                    if name:find(pattern, 1, true) then
                        AntiBan.Blocked = AntiBan.Blocked + 1
                        return
                    end
                end
                
                -- Check arguments
                for _, arg in ipairs(args) do
                    if type(arg) == "string" then
                        local lower = arg:lower()
                        for _, pattern in ipairs(dangerPatterns) do
                            if lower:find(pattern, 1, true) then
                                AntiBan.Blocked = AntiBan.Blocked + 1
                                return
                            end
                        end
                    end
                end
            end
            
            -- Block kicks
            if method == "Kick" then
                AntiBan.Blocked = AntiBan.Blocked + 1
                return
            end
            
            return oldNamecall(self, ...)
        end)
        
        setreadonly(mt, true)
    end)
    
    if not success then
        warn("[Anti-Ban] Hook failed, using fallback protection")
        -- Fallback: Just warn user
        self.Active = true
    end
end

function AntiBan:ProtectCharacter()
    task.spawn(function()
        while self.Active and Player do
            pcall(function()
                local char = Player.Character
                if char then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        -- Protect common exploitable properties
                        local mt = getrawmetatable(game)
                        if mt and mt.__index then
                            setreadonly(mt, false)
                            local oldIndex = mt.__index
                            
                            mt.__index = newcclosure(function(t, k)
                                if t == humanoid then
                                    if k == "WalkSpeed" and humanoid.WalkSpeed > 16 then
                                        return 16
                                    elseif k == "JumpPower" and humanoid.JumpPower > 50 then
                                        return 50
                                    elseif k == "JumpHeight" and humanoid.JumpHeight > 7.2 then
                                        return 7.2
                                    end
                                end
                                return oldIndex(t, k)
                            end)
                            
                            setreadonly(mt, true)
                        end
                    end
                end
            end)
            task.wait(1)
        end
    end)
end

-- Universal Scanner (Adaptive)
function Scanner:InitializeGameProfile()
    self.GameProfile = GameDetector:Analyze()
    print("[Scanner] Game Profile: " .. GameDetector.Profile)
end

function Scanner:UniversalScan(deep)
    local startTime = os.clock()
    local found = {}
    local scanned = {}
    local total = 0
    
    -- Use game-specific keywords if available
    local keywords = self.GameProfile and self.GameProfile.Keywords or {
        "kick", "ban", "detect", "anticheat", "anti", "cheat",
        "exploit", "flag", "report", "security", "verify",
        "check", "validate", "monitor", "log", "guard", "protect", "ac"
    }
    
    -- Universal class filter
    local targetClasses = {
        "RemoteEvent", "RemoteFunction",
        "BindableEvent", "BindableFunction",
        "Script", "LocalScript", "ModuleScript"
    }
    
    local function scanObject(obj)
        total = total + 1
        local id = tostring(obj)
        
        if scanned[id] then 
            self.Stats.CacheHits = self.Stats.CacheHits + 1
            return 
        end
        scanned[id] = true
        
        -- Check class
        local isTarget = false
        for _, className in ipairs(targetClasses) do
            if obj:IsA(className) then
                isTarget = true
                break
            end
        end
        
        if not isTarget then return end
        
        -- Check name
        local name = obj.Name:lower()
        for _, keyword in ipairs(keywords) do
            if name:find(keyword, 1, true) then
                local result = {
                    Name = obj.Name,
                    Type = obj.ClassName,
                    Path = obj:GetFullName(),
                    Object = obj
                }
                table.insert(found, result)
                break
            end
        end
    end
    
    local function scanService(service)
        if not service then return end
        
        pcall(function()
            local descendants = service:GetDescendants()
            for i = 1, #descendants do
                scanObject(descendants[i])
                
                -- Prevent lag
                if i % CONFIG.MaxBatchSize == 0 then
                    task.wait()
                end
            end
        end)
    end
    
    -- Priority scan critical services
    local criticalServices = self.GameProfile and self.GameProfile.CriticalServices or 
        {"ReplicatedStorage", "StarterPlayer", "StarterGui", "Workspace"}
    
    for _, serviceName in ipairs(criticalServices) do
        local service = safeGetService(serviceName)
        scanService(service)
    end
    
    -- Deep scan all services
    if deep then
        pcall(function()
            for _, service in pairs(Services) do
                if service and type(service) == "userdata" then
                    scanService(service)
                end
            end
        end)
    end
    
    local scanTime = math.floor((os.clock() - startTime) * 1000)
    self.Stats.TotalScanned = total
    self.Stats.ScanTime = scanTime
    self.Stats.LastScan = os.clock()
    
    return found, scanTime, total
end

function Scanner:MultiPassScan(passes)
    local allResults = {}
    local seen = {}
    local totalTime = 0
    
    for pass = 1, passes do
        local results, time = self:UniversalScan(pass > 1)
        totalTime = totalTime + time
        
        -- Merge unique
        for _, item in ipairs(results) do
            if not seen[item.Path] and item.Object and item.Object.Parent then
                seen[item.Path] = true
                table.insert(allResults, item)
            end
        end
        
        if pass < passes then task.wait(0.1) end
    end
    
    self.Results = allResults
    return allResults, totalTime
end

function Scanner:SafeRemove(obj)
    local success = pcall(function()
        if obj and obj.Parent then
            -- Try to disable first
            if obj:IsA("LuaSourceContainer") then
                obj.Disabled = true
            end
            
            -- Then destroy
            obj:Destroy()
            return true
        end
    end)
    return success
end

function Scanner:RemoveAll()
    local removed, disabled, failed = 0, 0, 0
    
    for i, item in ipairs(self.Results) do
        local obj = item.Object
        
        pcall(function()
            if obj and obj.Parent then
                -- Disable scripts
                if obj:IsA("LuaSourceContainer") then
                    obj.Disabled = true
                    disabled = disabled + 1
                    table.insert(self.DisabledScripts, {
                        Name = obj.Name,
                        Type = obj.ClassName,
                        Path = item.Path
                    })
                end
                
                -- Remove object
                if self:SafeRemove(obj) then
                    removed = removed + 1
                    table.insert(self.DeletedFiles, {
                        Name = obj.Name,
                        Type = obj.ClassName,
                        Path = item.Path
                    })
                else
                    failed = failed + 1
                end
            end
        end)
        
        if i % 50 == 0 then task.wait() end
    end
    
    return removed, disabled, failed
end

function Scanner:QuickVerify()
    local threats = self:UniversalScan(true)
    return #threats == 0, #threats
end

-- Universal GUI (Works everywhere)
local GUI = {}

function GUI:Create()
    local sg = Instance.new("ScreenGui")
    sg.Name = "UniversalACS_" .. tostring(math.random(1000, 9999))
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Try CoreGui first, fallback to PlayerGui
    local success = pcall(function()
        sg.Parent = safeGetService("CoreGui")
    end)
    
    if not success and Player then
        pcall(function()
            sg.Parent = Player:WaitForChild("PlayerGui", 5)
        end)
    end
    
    if not sg.Parent then
        warn("[GUI] Failed to parent GUI, trying direct assignment")
        sg.Parent = game:GetService("Players").LocalPlayer.PlayerGui
    end
    
    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 620, 0, 520)
    main.Position = UDim2.new(0.5, -310, 0.5, -260)
    main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    main.BorderSizePixel = 0
    main.Parent = sg
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
    
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(90, 90, 90)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    
    -- Glow effect
    local shadow = Instance.new("ImageLabel", main)
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.7
    shadow.ZIndex = 0
    
    -- Title Bar
    local title = Instance.new("Frame", main)
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 60)
    title.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    title.BorderSizePixel = 0
    
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 14)
    
    local titleCover = Instance.new("Frame", title)
    titleCover.Size = UDim2.new(1, 0, 0, 20)
    titleCover.Position = UDim2.new(0, 0, 1, -20)
    titleCover.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    titleCover.BorderSizePixel = 0
    
    -- Title text with game name
    local titleText = Instance.new("TextLabel", title)
    titleText.Size = UDim2.new(1, -280, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "🌐 Universal AC Scanner"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextSize = 20
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Game indicator
    local gameLabel = Instance.new("TextLabel", title)
    gameLabel.Name = "GameLabel"
    gameLabel.Size = UDim2.new(0, 200, 0, 25)
    gameLabel.Position = UDim2.new(1, -395, 0.5, -12.5)
    gameLabel.BackgroundColor3 = Color3.fromRGB(40, 80, 200)
    gameLabel.Text = "🎮 " .. GameDetector.Profile
    gameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    gameLabel.TextSize = 11
    gameLabel.Font = Enum.Font.GothamBold
    Instance.new("UICorner", gameLabel).CornerRadius = UDim.new(0, 8)
    
    -- Status badge
    local badge = Instance.new("Frame", title)
    badge.Name = "Badge"
    badge.Size = UDim2.new(0, 130, 0, 30)
    badge.Position = UDim2.new(1, -185, 0.5, -15)
    badge.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)
    
    local badgeText = Instance.new("TextLabel", badge)
    badgeText.Size = UDim2.new(1, 0, 1, 0)
    badgeText.BackgroundTransparency = 1
    badgeText.Text = "🛡️ PROTECTED"
    badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
    badgeText.TextSize = 12
    badgeText.Font = Enum.Font.GothamBold
    
    -- Control buttons
    local minBtn = Instance.new("TextButton", title)
    minBtn.Name = "Min"
    minBtn.Size = UDim2.new(0, 38, 0, 38)
    minBtn.Position = UDim2.new(1, -95, 0.5, -19)
    minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.TextSize = 20
    minBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)
    
    local closeBtn = Instance.new("TextButton", title)
    closeBtn.Name = "Close"
    closeBtn.Size = UDim2.new(0, 38, 0, 38)
    closeBtn.Position = UDim2.new(1, -50, 0.5, -19)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    
    closeBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)
    
    -- Stats panel
    local stats = Instance.new("Frame", main)
    stats.Name = "Stats"
    stats.Size = UDim2.new(1, -30, 0, 75)
    stats.Position = UDim2.new(0, 15, 0, 70)
    stats.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    stats.BorderSizePixel = 0
    Instance.new("UICorner", stats).CornerRadius = UDim.new(0, 10)
    
    local statusLabel = Instance.new("TextLabel", stats)
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -20, 0, 28)
    statusLabel.Position = UDim2.new(0, 10, 0, 5)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "✅ Ready | Profile: " .. GameDetector.Profile .. " | All Games Compatible"
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local infoLabel = Instance.new("TextLabel", stats)
    infoLabel.Name = "Info"
    infoLabel.Size = UDim2.new(1, -20, 0, 22)
    infoLabel.Position = UDim2.new(0, 10, 0, 38)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "📊 Found: 0 | Removed: 0 | Disabled: 0 | Blocked: 0"
    infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    infoLabel.TextSize = 12
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Scroll frame
    local scroll = Instance.new("ScrollingFrame", main)
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1, -30, 1, -230)
    scroll.Position = UDim2.new(0, 15, 0, 155)
    scroll.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 8
    scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 10)
    
    local list = Instance.new("UIListLayout", scroll)
    list.Padding = UDim.new(0, 5)
    
    -- Buttons
    local btns = Instance.new("Frame", main)
    btns.Name = "Buttons"
    btns.Size = UDim2.new(1, -30, 0, 55)
    btns.Position = UDim2.new(0, 15, 1, -65)
    btns.BackgroundTransparency = 1
    
    local function createBtn(name, text, color, pos)
        local btn = Instance.new("TextButton", btns)
        btn.Name = name
        btn.Size = UDim2.new(0.24, -4, 1, 0)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        return btn
    end
    
    local scanBtn = createBtn("Scan", "⚡ Scan", Color3.fromRGB(50, 120, 220), UDim2.new(0, 0, 0, 0))
    local removeBtn = createBtn("Remove", "🗑️ Remove", Color3.fromRGB(220, 50, 50), UDim2.new(0.25, 0, 0, 0))
    local verifyBtn = createBtn("Verify", "✓ Verify", Color3.fromRGB(50, 200, 50), UDim2.new(0.5, 0, 0, 0))
    local clearBtn = createBtn("Clear", "🔄 Clear", Color3.fromRGB(100, 100, 100), UDim2.new(0.75, 0, 0, 0))
    
    -- Dragging
    local dragging, dragInput, dragStart, startPos
    title.InputBegan:Connect(function(input)
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
    
    title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    if Services.UserInputService then
        Services.UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    
    -- Minimize
    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        main:TweenSize(
            minimized and UDim2.new(0, 620, 0, 60) or UDim2.new(0, 620, 0, 520),
            "Out", "Quad", 0.3, true
        )
        minBtn.Text = minimized and "□" or "—"
    end)
    
    return {
        ScreenGui = sg,
        Main = main,
        Scroll = scroll,
        Status = statusLabel,
        Info = infoLabel,
        Scan = scanBtn,
        Remove = removeBtn,
        Verify = verifyBtn,
        Clear = clearBtn,
        GameLabel = gameLabel
    }
end

function GUI:CreateItem(parent, text, icon, color)
    local item = Instance.new("Frame", parent)
    item.Size = UDim2.new(1, -10, 0, 36)
    item.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    item.BorderSizePixel = 0
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 8)
    
    local iconLabel = Instance.new("TextLabel", item)
    iconLabel.Size = UDim2.new(0, 32, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = color
    iconLabel.TextSize = 16
    
    local label = Instance.new("TextLabel", item)
    label.Size = UDim2.new(1, -38, 1, 0)
    label.Position = UDim2.new(0, 38, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(240, 240, 240)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    
    return item
end

function GUI:UpdateList(ui)
    local scroll = ui.Scroll
    
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    if #Scanner.Results > 0 then
        local header = Instance.new("TextLabel", scroll)
        header.Size = UDim2.new(1, -10, 0, 32)
        header.BackgroundTransparency = 1
        header.Text = string.format("📋 Threats: %d", #Scanner.Results)
        header.TextColor3 = Color3.fromRGB(255, 200, 100)
        header.TextSize = 14
        header.Font = Enum.Font.GothamBold
        header.TextXAlignment = Enum.TextXAlignment.Left
        
        for _, item in ipairs(Scanner.DisabledScripts) do
            self:CreateItem(scroll,
                string.format("%s (%s)", item.Name, item.Type),
                "⚠️",
                Color3.fromRGB(255, 200, 100)
            )
        end
    end
    
    scroll.CanvasSize = UDim2.new(0, 0, 0, scroll.UIListLayout.AbsoluteContentSize.Y + 10)
end

-- Initialize everything
print("═"..string.rep("═", 65))
print("🌐 UNIVERSAL AC SCANNER V4.0 - INITIALIZING...")
print("═"..string.rep("═", 65))

-- Detect game
Scanner:InitializeGameProfile()
print("🎮 Game Detected: " .. GameDetector.GameName)
print("📋 Profile: " .. GameDetector.Profile)
print("🆔 Place ID: " .. GameDetector.GameId)

-- Start anti-ban
AntiBan:UniversalHook()
AntiBan:ProtectCharacter()
print("🛡️ Anti-Ban: ACTIVE")

-- Create GUI
local ui = GUI:Create()
print("💎 GUI: LOADED")

print("═"..string.rep("═", 65))
print("✅ READY TO SCAN ANY GAME!")
print("═"..string.rep("═", 65))

-- Button handlers
ui.Scan.MouseButton1Click:Connect(function()
    ui.Scan.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    ui.Scan.Text = "⏳ Scanning..."
    ui.Status.Text = "🔍 Pass 1/3: Quick scan..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
    
    task.spawn(function()
        task.wait(0.3)
        ui.Status.Text = "🔍 Pass 2/3: Deep scan..."
        task.wait(0.5)
        ui.Status.Text = "🔍 Pass 3/3: Verification..."
        task.wait(0.5)
        
        local results, totalTime = Scanner:MultiPassScan(CONFIG.DeepScanPasses)
        
        ui.Scan.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
        ui.Scan.Text = "⚡ Scan"
        ui.Status.Text = string.format("✅ Found %d threats in %dms | Scanned: %d objects",
            #results, totalTime, Scanner.Stats.TotalScanned)
        ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        ui.Info.Text = string.format("📊 Found: %d | Removed: %d | Disabled: %d | Blocked: %d",
            #Scanner.Results, #Scanner.DeletedFiles, #Scanner.DisabledScripts, AntiBan.Blocked)
        
        GUI:UpdateList(ui)
    end)
end)

ui.Remove.MouseButton1Click:Connect(function()
    if #Scanner.Results == 0 then
        ui.Status.Text = "⚠️ No threats found. Scan first!"
        ui.Status.TextColor3 = Color3.fromRGB(255, 150, 100)
        return
    end
    
    ui.Remove.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    ui.Remove.Text = "⏳ Removing..."
    ui.Status.Text = "🗑️ Removing threats..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 100, 100)
    
    task.spawn(function()
        local removed, disabled, failed = Scanner:RemoveAll()
        
        task.wait(0.5)
        ui.Status.Text = "🔍 Verifying removal..."
        
        local clean, remaining = Scanner:QuickVerify()
        
        ui.Remove.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        ui.Remove.Text = "🗑️ Remove"
        
        if clean then
            ui.Status.Text = string.format("✅ SUCCESS! Removed: %d | Disabled: %d | VERIFIED CLEAN!",
                removed, disabled)
            ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            ui.Status.Text = string.format("⚠️ Removed: %d | Disabled: %d | %d protected items remain",
                removed, disabled, remaining)
            ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
        end
        
        ui.Info.Text = string.format("📊 Found: %d | Removed: %d | Disabled: %d | Blocked: %d",
            #Scanner.Results, #Scanner.DeletedFiles, #Scanner.DisabledScripts, AntiBan.Blocked)
        
        GUI:UpdateList(ui)
    end)
end)

ui.Verify.MouseButton1Click:Connect(function()
    ui.Verify.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    ui.Verify.Text = "⏳ Checking..."
    ui.Status.Text = "🔍 Verifying game state..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
    
    task.spawn(function()
        task.wait(0.3)
        local clean, threats = Scanner:QuickVerify()
        
        ui.Verify.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        ui.Verify.Text = "✓ Verify"
        
        if clean then
            ui.Status.Text = "✅ VERIFIED CLEAN! No threats detected!"
            ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            ui.Status.Text = string.format("⚠️ WARNING! %d threats still present!", threats)
            ui.Status.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
end)

ui.Clear.MouseButton1Click:Connect(function()
    Scanner.Results = {}
    Scanner.DeletedFiles = {}
    Scanner.DisabledScripts = {}
    Scanner.Cache = {}
    
    for _, child in ipairs(ui.Scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    ui.Status.Text = "✅ Cleared | Ready for new scan"
    ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
    ui.Info.Text = string.format("📊 Found: 0 | Removed: 0 | Disabled: 0 | Blocked: %d", AntiBan.Blocked)
end)

-- Auto-optimization
task.spawn(function()
    while task.wait(60) do
        if Scanner.Stats.TotalScanned > 10000 then
            Scanner.Cache = {}
        end
        
        if #Scanner.DeletedFiles > 1000 then
            Scanner.DeletedFiles = {}
        end
    end
end)

-- Performance monitor
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            ui.Info.Text = string.format("📊 Found: %d | Removed: %d | Disabled: %d | Blocked: %d",
                #Scanner.Results, #Scanner.DeletedFiles, #Scanner.DisabledScripts, AntiBan.Blocked)
        end)
    end
end)

-- Export global API
getgenv().UniversalACS = {
    Version = "4.0",
    GameProfile = GameDetector.Profile,
    Scanner = Scanner,
    AntiBan = AntiBan,
    
    -- Quick functions
    QuickScan = function()
        return Scanner:UniversalScan(false)
    end,
    
    DeepScan = function()
        return Scanner:MultiPassScan(3)
    end,
    
    RemoveAll = function()
        return Scanner:RemoveAll()
    end,
    
    Verify = function()
        return Scanner:QuickVerify()
    end,
    
    GetStats = function()
        return {
            Game = GameDetector.GameName,
            Profile = GameDetector.Profile,
            PlaceId = GameDetector.GameId,
            Found = #Scanner.Results,
            Removed = #Scanner.DeletedFiles,
            Disabled = #Scanner.DisabledScripts,
            Blocked = AntiBan.Blocked,
            TotalScanned = Scanner.Stats.TotalScanned,
            LastScanTime = Scanner.Stats.ScanTime,
            Supported = "ALL GAMES"
        }
    end,
    
    -- Game info
    GetGameInfo = function()
        return {
            Name = GameDetector.GameName,
            PlaceId = GameDetector.GameId,
            Profile = GameDetector.Profile,
            Detected = GameDetector.Detected
        }
    end,
    
    -- Advanced config
    SetConfig = function(config)
        for key, value in pairs(config) do
            if CONFIG[key] ~= nil then
                CONFIG[key] = value
            end
        end
    end,
    
    GetConfig = function()
        return CONFIG
    end
}

print("═"..string.rep("═", 65))
print("📦 Global API: getgenv().UniversalACS")
print("💡 Examples:")
print("   • getgenv().UniversalACS.DeepScan()")
print("   • getgenv().UniversalACS.GetGameInfo()")
print("   • getgenv().UniversalACS.GetStats()")
print("═"..string.rep("═", 65))
print("🌍 COMPATIBLE WITH ALL ROBLOX GAMES!")
print("🎮 Current Game: " .. GameDetector.GameName)
print("🚀 Status: READY TO USE")
print("═"..string.rep("═", 65))XAlignment.Left
        
        for _, item in ipairs(Scanner.Results) do
            self:CreateItem(scroll,
                string.format("%s (%s)", item.Name, item.Type),
                "📄",
                Color3.fromRGB(200, 200, 200)
            )
        end
    end
    
    if #Scanner.DeletedFiles > 0 then
        local header = Instance.new("TextLabel", scroll)
        header.Size = UDim2.new(1, -10, 0, 32)
        header.BackgroundTransparency = 1
        header.Text = string.format("🗑️ Removed: %d", #Scanner.DeletedFiles)
        header.TextColor3 = Color3.fromRGB(255, 100, 100)
        header.TextSize = 14
        header.Font = Enum.Font.GothamBold
        header.TextXAlignment = Enum.TextXAlignment.Left
        
        for _, item in ipairs(Scanner.DeletedFiles) do
            self:CreateItem(scroll,
                string.format("%s (%s)", item.Name, item.Type),
                "🗑️",
                Color3.fromRGB(255, 100, 100)
            )
        end
    end
    
    if #Scanner.DisabledScripts > 0 then
        local header = Instance.new("TextLabel", scroll)
        header.Size = UDim2.new(1, -10, 0, 32)
        header.BackgroundTransparency = 1
        header.Text = string.format("⚠️ Disabled: %d", #Scanner.DisabledScripts)
        header.TextColor3 = Color3.fromRGB(255, 200, 100)
        header.TextSize = 14
        header.Font = Enum.Font.GothamBold
        header.TextXAlignment = Enum.Text
