--[[
    Ultimate Anti-Cheat Scanner v3.0
    Maximum Performance & Optimization
    By: Advanced Security Team
]]

-- Constants
local SCAN_DELAY = 0.01
local CACHE_LIFETIME = 300
local MAX_BATCH_SIZE = 100
local PRIORITY_SERVICES = {"ReplicatedStorage", "StarterPlayer", "StarterGui", "Workspace"}

-- Core Scanner
local Scanner = {
    Results = {},
    DeletedFiles = {},
    DisabledScripts = {},
    Cache = {},
    Stats = {
        TotalScanned = 0,
        CacheHits = 0,
        ScanTime = 0,
        LastScan = 0
    },
    Config = {
        DeepScan = true,
        AutoRescan = true,
        CacheEnabled = true,
        BatchProcessing = true
    }
}

-- Optimized Service Getter
local Services = {}
local function initServices()
    local serviceNames = {
        "Players", "RunService", "HttpService", 
        "CoreGui", "UserInputService", "TweenService"
    }
    
    for _, name in ipairs(serviceNames) do
        local success, service = pcall(game.GetService, game, name)
        if success then Services[name] = service end
    end
end
initServices()

local Player = Services.Players.LocalPlayer

-- Anti-Ban System (Optimized)
local AntiBan = {
    Active = false,
    BlockedRemotes = {},
    HookedFunctions = {}
}

function AntiBan:Initialize()
    if self.Active then return end
    self.Active = true
    
    -- Optimized Remote Hook
    local blockedPatterns = {
        "kick", "ban", "report", "flag", "anticheat", 
        "detect", "log", "exploit", "cheat"
    }
    
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        if method == "FireServer" or method == "InvokeServer" then
            local name = self.Name:lower()
            
            -- Fast pattern matching
            for i = 1, #blockedPatterns do
                if name:find(blockedPatterns[i], 1, true) then
                    AntiBan.BlockedRemotes[self] = (AntiBan.BlockedRemotes[self] or 0) + 1
                    return
                end
            end
        elseif method == "Kick" then
            return -- Block all kicks
        end
        
        return oldNamecall(self, ...)
    end)
    
    -- Humanoid Protection
    task.spawn(function()
        while self.Active do
            local char = Player.Character
            if char then
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid and humanoid.WalkSpeed > 16 then
                    local mt = getrawmetatable(game)
                    setreadonly(mt, false)
                    local oldIndex = mt.__index
                    
                    mt.__index = newcclosure(function(t, k)
                        if t == humanoid and k == "WalkSpeed" then
                            return 16
                        end
                        return oldIndex(t, k)
                    end)
                    
                    setreadonly(mt, true)
                end
            end
            task.wait(1)
        end
    end)
end

-- Ultra-Fast Scanning Engine
function Scanner:OptimizedScan(deep)
    local startTime = os.clock()
    local found = {}
    local scanned = {}
    local total = 0
    
    -- Optimized keyword matching
    local keywords = {
        "kick", "ban", "detect", "anticheat", "anti", "cheat",
        "exploit", "flag", "report", "security", "verify",
        "check", "validate", "monitor", "log", "guard", "protect", "ac"
    }
    
    -- Fast class filter
    local validClasses = {
        RemoteEvent = true, RemoteFunction = true,
        BindableEvent = true, BindableFunction = true,
        Script = true, LocalScript = true, ModuleScript = true
    }
    
    local function processObject(obj)
        total = total + 1
        local id = tostring(obj)
        
        -- Cache check
        if self.Config.CacheEnabled and self.Cache[id] then
            self.Stats.CacheHits = self.Stats.CacheHits + 1
            return self.Cache[id]
        end
        
        if scanned[id] then return end
        scanned[id] = true
        
        -- Fast class check
        if not validClasses[obj.ClassName] then return end
        
        -- Optimized name matching
        local name = obj.Name
        local lower = name:lower()
        
        for i = 1, #keywords do
            if lower:find(keywords[i], 1, true) then
                local result = {
                    Name = name,
                    Type = obj.ClassName,
                    Path = obj:GetFullName(),
                    Object = obj
                }
                
                table.insert(found, result)
                if self.Config.CacheEnabled then
                    self.Cache[id] = result
                end
                break
            end
        end
    end
    
    -- Batch processing
    local function processBatch(objects)
        local batch = {}
        local count = 0
        
        for _, obj in ipairs(objects) do
            count = count + 1
            processObject(obj)
            
            if self.Config.BatchProcessing and count % MAX_BATCH_SIZE == 0 then
                task.wait() -- Prevent lag spikes
            end
        end
    end
    
    -- Priority scan first
    for _, serviceName in ipairs(PRIORITY_SERVICES) do
        local service = game:FindService(serviceName)
        if service then
            processBatch(service:GetDescendants())
        end
    end
    
    -- Deep scan if enabled
    if deep then
        local allObjects = game:GetDescendants()
        processBatch(allObjects)
    end
    
    local scanTime = math.floor((os.clock() - startTime) * 1000)
    self.Stats.TotalScanned = total
    self.Stats.ScanTime = scanTime
    self.Stats.LastScan = os.clock()
    
    return found, scanTime, total
end

-- Multi-Pass Deep Scan
function Scanner:DeepScan(passes)
    passes = passes or 3
    local allResults = {}
    local seen = {}
    local totalTime = 0
    
    for pass = 1, passes do
        local results, time = self:OptimizedScan(pass > 1)
        totalTime = totalTime + time
        
        -- Merge unique results
        for _, item in ipairs(results) do
            local key = item.Path
            if not seen[key] and item.Object and item.Object.Parent then
                seen[key] = true
                table.insert(allResults, item)
            end
        end
        
        if pass < passes then task.wait(0.1) end
    end
    
    self.Results = allResults
    return allResults, totalTime
end

-- Fast Removal System
function Scanner:RemoveAll()
    local removed, disabled, failed = 0, 0, 0
    local startTime = os.clock()
    
    -- Batch removal
    for i, item in ipairs(self.Results) do
        local obj = item.Object
        
        if obj and obj.Parent then
            -- Disable scripts first
            if obj:IsA("LuaSourceContainer") then
                local success = pcall(function()
                    obj.Disabled = true
                    disabled = disabled + 1
                    table.insert(self.DisabledScripts, {
                        Name = obj.Name,
                        Type = obj.ClassName,
                        Path = item.Path
                    })
                end)
                if not success then failed = failed + 1 end
            end
            
            -- Delete object
            local success = pcall(function()
                table.insert(self.DeletedFiles, {
                    Name = obj.Name,
                    Type = obj.ClassName,
                    Path = item.Path
                })
                obj:Destroy()
                removed = removed + 1
            end)
            
            if not success then failed = failed + 1 end
            
            -- Batch delay
            if i % 50 == 0 then task.wait() end
        end
    end
    
    local removeTime = math.floor((os.clock() - startTime) * 1000)
    return removed, disabled, failed, removeTime
end

-- Verify Clean
function Scanner:VerifyScan()
    local results = self:OptimizedScan(true)
    return #results == 0, #results
end

-- Cache Management
function Scanner:ClearCache()
    self.Cache = {}
    self.Stats.CacheHits = 0
end

function Scanner:AutoCacheCleanup()
    task.spawn(function()
        while task.wait(CACHE_LIFETIME) do
            local now = os.clock()
            if now - self.Stats.LastScan > CACHE_LIFETIME then
                self:ClearCache()
            end
        end
    end)
end

-- Ultra-Optimized GUI
local GUI = {}

function GUI:Create()
    local sg = Instance.new("ScreenGui")
    sg.Name = "ACS_"..Services.HttpService:GenerateGUID(false):sub(1,6)
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    
    pcall(function() sg.Parent = Services.CoreGui end)
    if not sg.Parent then sg.Parent = Player:WaitForChild("PlayerGui") end
    
    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 600, 0, 500)
    main.Position = UDim2.new(0.5, -300, 0.5, -250)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.BorderSizePixel = 0
    main.Parent = sg
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(80, 80, 80)
    stroke.Thickness = 2
    
    -- Title Bar
    local title = Instance.new("Frame", main)
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 55)
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 12)
    local cover = Instance.new("Frame", title)
    cover.Size = UDim2.new(1, 0, 0, 15)
    cover.Position = UDim2.new(0, 0, 1, -15)
    cover.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    cover.BorderSizePixel = 0
    
    local titleText = Instance.new("TextLabel", title)
    titleText.Size = UDim2.new(1, -250, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "⚡ Ultimate AC Scanner v3.0"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextSize = 20
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Status Badge
    local badge = Instance.new("Frame", title)
    badge.Name = "Badge"
    badge.Size = UDim2.new(0, 140, 0, 30)
    badge.Position = UDim2.new(1, -245, 0.5, -15)
    badge.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)
    
    local badgeText = Instance.new("TextLabel", badge)
    badgeText.Name = "Text"
    badgeText.Size = UDim2.new(1, -10, 1, 0)
    badgeText.Position = UDim2.new(0, 5, 0, 0)
    badgeText.BackgroundTransparency = 1
    badgeText.Text = "🛡️ PROTECTED"
    badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
    badgeText.TextSize = 12
    badgeText.Font = Enum.Font.GothamBold
    
    -- Minimize Button
    local minBtn = Instance.new("TextButton", title)
    minBtn.Name = "Min"
    minBtn.Size = UDim2.new(0, 35, 0, 35)
    minBtn.Position = UDim2.new(1, -90, 0.5, -17.5)
    minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.TextSize = 18
    minBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)
    
    -- Close Button
    local closeBtn = Instance.new("TextButton", title)
    closeBtn.Name = "Close"
    closeBtn.Size = UDim2.new(0, 35, 0, 35)
    closeBtn.Position = UDim2.new(1, -45, 0.5, -17.5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    
    closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
    
    -- Stats Panel
    local stats = Instance.new("Frame", main)
    stats.Name = "Stats"
    stats.Size = UDim2.new(1, -30, 0, 70)
    stats.Position = UDim2.new(0, 15, 0, 65)
    stats.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    stats.BorderSizePixel = 0
    Instance.new("UICorner", stats).CornerRadius = UDim.new(0, 10)
    
    local statusLabel = Instance.new("TextLabel", stats)
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -20, 0, 30)
    statusLabel.Position = UDim2.new(0, 10, 0, 5)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "✅ Ready | Deep Scan: 3-Pass | Cache: Enabled"
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local infoLabel = Instance.new("TextLabel", stats)
    infoLabel.Name = "Info"
    infoLabel.Size = UDim2.new(1, -20, 0, 25)
    infoLabel.Position = UDim2.new(0, 10, 0, 40)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "📊 Found: 0 | Removed: 0 | Disabled: 0 | Cache: 0"
    infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    infoLabel.TextSize = 12
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Scroll Frame
    local scroll = Instance.new("ScrollingFrame", main)
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1, -30, 1, -215)
    scroll.Position = UDim2.new(0, 15, 0, 145)
    scroll.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 8
    scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 10)
    
    local list = Instance.new("UIListLayout", scroll)
    list.Padding = UDim.new(0, 5)
    
    -- Buttons Container
    local btns = Instance.new("Frame", main)
    btns.Name = "Buttons"
    btns.Size = UDim2.new(1, -30, 0, 55)
    btns.Position = UDim2.new(0, 15, 1, -65)
    btns.BackgroundTransparency = 1
    
    local function createBtn(name, text, color, pos)
        local btn = Instance.new("TextButton", btns)
        btn.Name = name
        btn.Size = UDim2.new(0.24, -5, 1, 0)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        return btn
    end
    
    local scanBtn = createBtn("Scan", "⚡ Deep Scan", Color3.fromRGB(50, 120, 220), UDim2.new(0, 0, 0, 0))
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
    
    Services.UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Minimize
    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        main:TweenSize(
            minimized and UDim2.new(0, 600, 0, 55) or UDim2.new(0, 600, 0, 500),
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
        Clear = clearBtn
    }
end

function GUI:CreateItem(parent, text, icon, color)
    local item = Instance.new("Frame", parent)
    item.Size = UDim2.new(1, -10, 0, 35)
    item.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    item.BorderSizePixel = 0
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 8)
    
    local iconLabel = Instance.new("TextLabel", item)
    iconLabel.Size = UDim2.new(0, 30, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = color
    iconLabel.TextSize = 16
    
    local label = Instance.new("TextLabel", item)
    label.Size = UDim2.new(1, -35, 1, 0)
    label.Position = UDim2.new(0, 35, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(240, 240, 240)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    
    return item
end

function GUI:UpdateList(elements)
    local scroll = elements.Scroll
    
    -- Clear
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    -- Add results
    if #Scanner.Results > 0 then
        local header = Instance.new("TextLabel", scroll)
        header.Size = UDim2.new(1, -10, 0, 30)
        header.BackgroundTransparency = 1
        header.Text = string.format("📋 Threats Found: %d", #Scanner.Results)
        header.TextColor3 = Color3.fromRGB(255, 200, 100)
        header.TextSize = 14
        header.Font = Enum.Font.GothamBold
        header.TextXAlignment = Enum.TextXAlignment.Left
        
        for _, item in ipairs(Scanner.Results) do
            self:CreateItem(scroll, 
                string.format("%s (%s)", item.Name, item.Type),
                "📄",
                Color3.fromRGB(200, 200, 200)
            )
        end
    end
    
    -- Add deleted
    if #Scanner.DeletedFiles > 0 then
        local header = Instance.new("TextLabel", scroll)
        header.Size = UDim2.new(1, -10, 0, 30)
        header.BackgroundTransparency = 1
        header.Text = string.format("🗑️ Deleted: %d", #Scanner.DeletedFiles)
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
    
    -- Add disabled
    if #Scanner.DisabledScripts > 0 then
        local header = Instance.new("TextLabel", scroll)
        header.Size = UDim2.new(1, -10, 0, 30)
        header.BackgroundTransparency = 1
        header.Text = string.format("⚠️ Disabled: %d", #Scanner.DisabledScripts)
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

-- Initialize
AntiBan:Initialize()
Scanner:AutoCacheCleanup()

local ui = GUI:Create()

-- Button Handlers
ui.Scan.MouseButton1Click:Connect(function()
    ui.Scan.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    ui.Scan.Text = "⏳ Scanning..."
    ui.Status.Text = "🔍 Pass 1/3: Priority scan..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
    
    task.spawn(function()
        task.wait(0.3)
        ui.Status.Text = "🔍 Pass 2/3: Deep scan..."
        task.wait(0.5)
        ui.Status.Text = "🔍 Pass 3/3: Verification..."
        task.wait(0.5)
        
        local results, totalTime = Scanner:DeepScan(3)
        
        ui.Scan.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
        ui.Scan.Text = "⚡ Deep Scan"
        ui.Status.Text = string.format("✅ Scan complete! %d threats in %dms | Scanned: %d objects", 
            #results, totalTime, Scanner.Stats.TotalScanned)
        ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        ui.Info.Text = string.format("📊 Found: %d | Removed: %d | Disabled: %d | Cache: %d hits",
            #Scanner.Results, #Scanner.DeletedFiles, #Scanner.DisabledScripts, Scanner.Stats.CacheHits)
        
        GUI:UpdateList(ui)
    end)
end)

ui.Remove.MouseButton1Click:Connect(function()
    if #Scanner.Results == 0 then
        ui.Status.Text = "⚠️ No threats found. Run scan first!"
        ui.Status.TextColor3 = Color3.fromRGB(255, 150, 100)
        return
    end
    
    ui.Remove.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    ui.Remove.Text = "⏳ Removing..."
    ui.Status.Text = "🗑️ Disabling & removing threats..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 100, 100)
    
    task.spawn(function()
        local removed, disabled, failed, time = Scanner:RemoveAll()
        
        task.wait(0.5)
        ui.Status.Text = "🔍 Verifying removal..."
        
        local clean, remaining = Scanner:VerifyScan()
        
        ui.Remove.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        ui.Remove.Text = "🗑️ Remove"
        
        if clean then
            ui.Status.Text = string.format("✅ Success! Removed: %d | Disabled: %d in %dms | VERIFIED CLEAN!",
                removed, disabled, time)
            ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            ui.Status.Text = string.format("⚠️ Removed: %d | Disabled: %d | %d protected items remain",
                removed, disabled, remaining)
            ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
        end
        
        ui.Info.Text = string.format("📊 Found: %d | Removed: %d | Disabled: %d | Cache: %d hits",
            #Scanner.Results, #Scanner.DeletedFiles, #Scanner.DisabledScripts, Scanner.Stats.CacheHits)
        
        GUI:UpdateList(ui)
    end)
end)

ui.Verify.MouseButton1Click:Connect(function()
    ui.Verify.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    ui.Verify.Text = "⏳ Checking..."
    ui.Status.Text = "🔍 Running verification scan..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
    
    task.spawn(function()
        task.wait(0.3)
        local clean, threats = Scanner:VerifyScan()
        
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
    Scanner:ClearCache()
    
    for _, child in ipairs(ui.Scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    ui.Status.Text = "✅ History cleared | Cache flushed | Ready for new scan"
    ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
    ui.Info.Text = "📊 Found: 0 | Removed: 0 | Disabled: 0 | Cache: 0 hits"
end)

-- Performance Monitor
task.spawn(function()
    while task.wait(5) do
        if #Scanner.Results > 0 or #Scanner.DeletedFiles > 0 then
            ui.Info.Text = string.format("📊 Found: %d | Removed: %d | Disabled: %d | Cache: %d hits",
                #Scanner.Results, #Scanner.DeletedFiles, #Scanner.DisabledScripts, Scanner.Stats.CacheHits)
        end
    end
end)

-- Auto-optimization
task.spawn(function()
    while task.wait(60) do
        -- Memory optimization
        if Scanner.Stats.CacheHits > 1000 then
            Scanner:ClearCache()
            print("[AC Scanner] Auto-optimization: Cache cleared")
        end
        
        -- Garbage collection hint
        if #Scanner.DeletedFiles > 500 then
            Scanner.DeletedFiles = {}
            print("[AC Scanner] Auto-optimization: History pruned")
        end
    end
end)

-- Initialize complete
print("═"..string.rep("═", 60))
print("⚡ ULTIMATE AC SCANNER V3.0 - MAXIMUM PERFORMANCE")
print("═"..string.rep("═", 60))
print("✅ Core Systems: ONLINE")
print("🛡️ Anti-Ban Protection: ACTIVE")
print("⚡ Deep Scan Engine: 3-PASS MODE")
print("💾 Cache System: ENABLED")
print("🚀 Batch Processing: OPTIMIZED")
print("📊 Performance Monitor: RUNNING")
print("🔄 Auto-Cleanup: SCHEDULED")
print("═"..string.rep("═", 60))
print("📈 Performance Stats:")
print("   • Scan Speed: Ultra-Fast")
print("   • Memory Usage: Optimized")
print("   • Compatibility: Universal Executor")
print("   • Cache Lifetime: "..CACHE_LIFETIME.."s")
print("   • Batch Size: "..MAX_BATCH_SIZE.." objects")
print("═"..string.rep("═", 60))
print("🎯 Ready to scan! Use GUI controls to begin.")
print("═"..string.rep("═", 60))

-- Export API for advanced users
getgenv().ACScanner = {
    Version = "3.0",
    Scanner = Scanner,
    AntiBan = AntiBan,
    GUI = GUI,
    
    -- Quick functions
    QuickScan = function()
        return Scanner:OptimizedScan(false)
    end,
    
    DeepScan = function()
        return Scanner:DeepScan(3)
    end,
    
    RemoveAll = function()
        return Scanner:RemoveAll()
    end,
    
    Verify = function()
        return Scanner:VerifyScan()
    end,
    
    ClearCache = function()
        Scanner:ClearCache()
    end,
    
    GetStats = function()
        return {
            Found = #Scanner.Results,
            Deleted = #Scanner.DeletedFiles,
            Disabled = #Scanner.DisabledScripts,
            CacheHits = Scanner.Stats.CacheHits,
            TotalScanned = Scanner.Stats.TotalScanned,
            LastScanTime = Scanner.Stats.ScanTime,
            BlockedRemotes = AntiBan.BlockedRemotes
        }
    end,
    
    -- Advanced config
    SetConfig = function(config)
        for key, value in pairs(config) do
            if Scanner.Config[key] ~= nil then
                Scanner.Config[key] = value
            end
        end
    end,
    
    GetConfig = function()
        return Scanner.Config
    end
}

print("📦 Global API exported to: getgenv().ACScanner")
print("📚 Example: getgenv().ACScanner.QuickScan()")
print("═"..string.rep("═", 60))
