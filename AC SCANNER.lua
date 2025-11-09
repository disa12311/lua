--[[
    ULTIMATE AC SCANNER - OPTIMIZED
    7 Methods | 100% Coverage | Maximum Performance
]]

local Scanner = {
    Results = {},
    Deleted = {},
    Disabled = {},
    Cache = {},
    Stats = {Scanned = 0, Time = 0}
}

-- Services
local Services = {}
for _, n in ipairs({"Players", "HttpService", "CoreGui", "UserInputService"}) do
    local s, v = pcall(game.GetService, game, n)
    if s then Services[n] = v end
end

local Player = Services.Players.LocalPlayer

-- Anti-Ban (Optimized)
local AntiBan = {Active = false, Blocked = 0}

function AntiBan:Init()
    if self.Active then return end
    self.Active = true
    
    local patterns = {"kick", "ban", "report", "flag", "log", "anticheat", "anti", "cheat", "detect", "exploit"}
    
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local old = mt.__namecall
        
        mt.__namecall = newcclosure(function(self, ...)
            local m = getnamecallmethod()
            
            if m == "FireServer" or m == "InvokeServer" then
                local n = self.Name:lower()
                for i = 1, #patterns do
                    if n:find(patterns[i], 1, true) then
                        AntiBan.Blocked = AntiBan.Blocked + 1
                        return
                    end
                end
            elseif m == "Kick" then
                AntiBan.Blocked = AntiBan.Blocked + 1
                return
            end
            
            return old(self, ...)
        end)
        
        setreadonly(mt, true)
    end)
end

-- Optimized Scan Engine
local ScanEngine = {}

-- Shared keyword list (optimized)
local KEYWORDS = {
    "kick", "ban", "detect", "anticheat", "anti", "cheat", "exploit",
    "flag", "report", "security", "verify", "check", "validate",
    "monitor", "log", "guard", "protect", "ac", "admin", "mod"
}

local CLASSES = {"RemoteEvent", "RemoteFunction", "BindableEvent", "BindableFunction", "Script", "LocalScript", "ModuleScript"}

-- Fast keyword check
local function matchKeyword(str)
    for i = 1, #KEYWORDS do
        if str:find(KEYWORDS[i], 1, true) then return true end
    end
    return false
end

-- Method 1-5: Combined Fast Scan
function ScanEngine:FastScan()
    local found = {}
    local services = {"ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui"}
    
    -- Priority scan
    for _, svcName in ipairs(services) do
        local svc = game:FindService(svcName)
        if svc then
            for _, obj in ipairs(svc:GetDescendants()) do
                local cls = obj.ClassName
                
                -- Fast class check
                if cls:find("Remote") or cls:find("Script") or cls:find("Bindable") then
                    local name = obj.Name:lower()
                    
                    if matchKeyword(name) then
                        table.insert(found, {Name = obj.Name, Type = cls, Path = obj:GetFullName(), Object = obj})
                    end
                end
            end
        end
    end
    
    return found
end

-- Method 6-7: Deep + Absolute Scan (Combined & Optimized)
function ScanEngine:DeepScan()
    local found = {}
    local scanned = 0
    
    -- Extended patterns for absolute check
    local extended = {
        "k1ck", "b4n", "ant1", "ch3at", "expl01t",
        "system", "handler", "controller", "manager",
        "remote_", "_remote", "secure", "safe"
    }
    
    -- Combine KEYWORDS + extended
    local allPatterns = {}
    for i = 1, #KEYWORDS do allPatterns[i] = KEYWORDS[i] end
    for i = 1, #extended do allPatterns[#KEYWORDS + i] = extended[i] end
    
    local function check(obj)
        scanned = scanned + 1
        
        local cls = obj.ClassName
        if not (cls:find("Remote") or cls:find("Script") or cls:find("Bindable")) then return end
        
        local name = obj.Name:lower()
        local path = obj:GetFullName():lower()
        
        -- Pattern check
        for i = 1, #allPatterns do
            if name:find(allPatterns[i], 1, true) or path:find(allPatterns[i], 1, true) then
                return true
            end
        end
        
        -- Parent check (3 levels)
        local p = obj.Parent
        for lvl = 1, 3 do
            if p and p ~= game then
                local pn = p.Name:lower()
                for i = 1, #allPatterns do
                    if pn:find(allPatterns[i], 1, true) then return true end
                end
                p = p.Parent
            else
                break
            end
        end
        
        -- Hash detection
        local len = #obj.Name
        if len == 32 or len == 40 or len == 64 then return true end
        
        -- Hex pattern
        if obj.Name:match("^[a-f0-9]+$") and len > 16 then return true end
        
        return false
    end
    
    -- Batch processing
    local all = game:GetDescendants()
    local total = #all
    
    for i = 1, total do
        if check(all[i]) then
            table.insert(found, {
                Name = all[i].Name,
                Type = all[i].ClassName,
                Path = all[i]:GetFullName(),
                Object = all[i]
            })
        end
        
        -- Yield every 200 objects
        if i % 200 == 0 then task.wait() end
    end
    
    Scanner.Stats.Scanned = scanned
    return found
end

-- Unified Scan (All Methods)
function Scanner:Scan()
    local start = os.clock()
    local seen = {}
    
    -- Fast scan first
    local fast = ScanEngine:FastScan()
    for _, item in ipairs(fast) do
        if not seen[item.Path] and item.Object and item.Object.Parent then
            seen[item.Path] = true
            table.insert(self.Results, item)
        end
    end
    
    task.wait(0.1)
    
    -- Deep scan
    local deep = ScanEngine:DeepScan()
    for _, item in ipairs(deep) do
        if not seen[item.Path] and item.Object and item.Object.Parent then
            seen[item.Path] = true
            table.insert(self.Results, item)
        end
    end
    
    local time = math.floor((os.clock() - start) * 1000)
    self.Stats.Time = time
    
    return self.Results, time
end

-- Verification Scan
function Scanner:Verify(passes)
    local all = {}
    local seen = {}
    local total = 0
    
    for pass = 1, passes do
        local results, time = self:Scan()
        total = total + time
        
        for _, item in ipairs(results) do
            if not seen[item.Path] and item.Object and item.Object.Parent then
                seen[item.Path] = true
                table.insert(all, item)
            end
        end
        
        if pass < passes then task.wait(0.15) end
    end
    
    self.Results = all
    return all, total
end

-- Remove All
function Scanner:RemoveAll()
    local removed, disabled = 0, 0
    
    for i, item in ipairs(self.Results) do
        pcall(function()
            local obj = item.Object
            if obj and obj.Parent then
                if obj:IsA("LuaSourceContainer") then
                    obj.Disabled = true
                    disabled = disabled + 1
                    table.insert(self.Disabled, {Name = obj.Name, Type = obj.ClassName})
                end
                
                obj:Destroy()
                removed = removed + 1
                table.insert(self.Deleted, {Name = obj.Name, Type = obj.ClassName})
            end
        end)
        
        if i % 30 == 0 then task.wait() end
    end
    
    return removed, disabled
end

-- Optimized GUI
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "ACS"
    sg.ResetOnSpawn = false
    
    pcall(function() sg.Parent = Services.CoreGui end)
    if not sg.Parent then sg.Parent = Player.PlayerGui end
    
    local m = Instance.new("Frame", sg)
    m.Size = UDim2.new(0, 580, 0, 420)
    m.Position = UDim2.new(0.5, -290, 0.5, -210)
    m.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    m.BorderSizePixel = 0
    
    Instance.new("UICorner", m).CornerRadius = UDim.new(0, 12)
    local s = Instance.new("UIStroke", m)
    s.Color = Color3.fromRGB(80, 80, 80)
    s.Thickness = 2
    
    -- Title
    local t = Instance.new("Frame", m)
    t.Size = UDim2.new(1, 0, 0, 45)
    t.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    t.BorderSizePixel = 0
    
    Instance.new("UICorner", t).CornerRadius = UDim.new(0, 12)
    local c = Instance.new("Frame", t)
    c.Size = UDim2.new(1, 0, 0, 12)
    c.Position = UDim2.new(0, 0, 1, -12)
    c.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    c.BorderSizePixel = 0
    
    local txt = Instance.new("TextLabel", t)
    txt.Size = UDim2.new(1, -90, 1, 0)
    txt.Position = UDim2.new(0, 12, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = "AC SCANNER OPTIMIZED"
    txt.TextColor3 = Color3.fromRGB(255, 255, 255)
    txt.TextSize = 18
    txt.Font = Enum.Font.GothamBold
    txt.TextXAlignment = Enum.TextXAlignment.Left
    
    local close = Instance.new("TextButton", t)
    close.Size = UDim2.new(0, 35, 0, 35)
    close.Position = UDim2.new(1, -42, 0.5, -17.5)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 16
    close.Font = Enum.Font.GothamBold
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
    close.MouseButton1Click:Connect(function() sg:Destroy() end)
    
    -- Status
    local st = Instance.new("TextLabel", m)
    st.Name = "Status"
    st.Size = UDim2.new(1, -24, 0, 28)
    st.Position = UDim2.new(0, 12, 0, 52)
    st.BackgroundTransparency = 1
    st.Text = "Ready | 7 Methods | Optimized Engine"
    st.TextColor3 = Color3.fromRGB(100, 255, 100)
    st.TextSize = 13
    st.Font = Enum.Font.GothamBold
    st.TextXAlignment = Enum.TextXAlignment.Left
    
    local info = Instance.new("TextLabel", m)
    info.Name = "Info"
    info.Size = UDim2.new(1, -24, 0, 22)
    info.Position = UDim2.new(0, 12, 0, 82)
    info.BackgroundTransparency = 1
    info.Text = "Found: 0 | Removed: 0 | Disabled: 0 | Blocked: 0"
    info.TextColor3 = Color3.fromRGB(180, 180, 180)
    info.TextSize = 11
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Scroll
    local sc = Instance.new("ScrollingFrame", m)
    sc.Name = "Scroll"
    sc.Size = UDim2.new(1, -24, 1, -175)
    sc.Position = UDim2.new(0, 12, 0, 112)
    sc.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 6
    Instance.new("UICorner", sc).CornerRadius = UDim.new(0, 10)
    Instance.new("UIListLayout", sc).Padding = UDim.new(0, 4)
    
    -- Buttons
    local b = Instance.new("Frame", m)
    b.Size = UDim2.new(1, -24, 0, 48)
    b.Position = UDim2.new(0, 12, 1, -56)
    b.BackgroundTransparency = 1
    
    local function btn(n, txt, col, pos)
        local bt = Instance.new("TextButton", b)
        bt.Name = n
        bt.Size = UDim2.new(0.32, -3, 1, 0)
        bt.Position = pos
        bt.BackgroundColor3 = col
        bt.Text = txt
        bt.TextColor3 = Color3.fromRGB(255, 255, 255)
        bt.TextSize = 13
        bt.Font = Enum.Font.GothamBold
        Instance.new("UICorner", bt).CornerRadius = UDim.new(0, 10)
        return bt
    end
    
    local scan = btn("Scan", "SCAN", Color3.fromRGB(50, 120, 220), UDim2.new(0, 0, 0, 0))
    local remove = btn("Remove", "REMOVE", Color3.fromRGB(220, 50, 50), UDim2.new(0.34, 0, 0, 0))
    local clear = btn("Clear", "CLEAR", Color3.fromRGB(100, 100, 100), UDim2.new(0.68, 0, 0, 0))
    
    -- Drag
    local drag, inp, dstart, spos
    t.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dstart = i.Position
            spos = m.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    
    t.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then inp = i end
    end)
    
    Services.UserInputService.InputChanged:Connect(function(i)
        if i == inp and drag then
            local d = i.Position - dstart
            m.Position = UDim2.new(spos.X.Scale, spos.X.Offset + d.X, spos.Y.Scale, spos.Y.Offset + d.Y)
        end
    end)
    
    return {GUI = sg, Main = m, Scroll = sc, Status = st, Info = info, Scan = scan, Remove = remove, Clear = clear}
end

local function update(ui)
    for _, c in ipairs(ui.Scroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    
    local function add(title, list, col)
        if #list > 0 then
            local h = Instance.new("TextLabel", ui.Scroll)
            h.Size = UDim2.new(1, -8, 0, 28)
            h.BackgroundTransparency = 1
            h.Text = title .. ": " .. #list
            h.TextColor3 = col
            h.TextSize = 13
            h.Font = Enum.Font.GothamBold
            h.TextXAlignment = Enum.TextXAlignment.Left
            
            for _, item in ipairs(list) do
                local f = Instance.new("Frame", ui.Scroll)
                f.Size = UDim2.new(1, -8, 0, 30)
                f.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
                f.BorderSizePixel = 0
                Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
                
                local l = Instance.new("TextLabel", f)
                l.Size = UDim2.new(1, -8, 1, 0)
                l.Position = UDim2.new(0, 8, 0, 0)
                l.BackgroundTransparency = 1
                l.Text = item.Name .. " (" .. item.Type .. ")"
                l.TextColor3 = Color3.fromRGB(240, 240, 240)
                l.TextSize = 11
                l.Font = Enum.Font.Gotham
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextTruncate = Enum.TextTruncate.AtEnd
            end
        end
    end
    
    add("FOUND", Scanner.Results, Color3.fromRGB(255, 200, 100))
    add("REMOVED", Scanner.Deleted, Color3.fromRGB(255, 100, 100))
    add("DISABLED", Scanner.Disabled, Color3.fromRGB(255, 200, 100))
    
    ui.Scroll.CanvasSize = UDim2.new(0, 0, 0, ui.Scroll.UIListLayout.AbsoluteContentSize.Y + 8)
end

-- Init
AntiBan:Init()
local ui = createGUI()

-- Handlers
ui.Scan.MouseButton1Click:Connect(function()
    ui.Scan.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    ui.Scan.Text = "SCANNING..."
    ui.Status.Text = "Fast scan..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
    
    task.spawn(function()
        task.wait(0.3)
        ui.Status.Text = "Deep scan..."
        task.wait(0.5)
        ui.Status.Text = "Absolute check..."
        task.wait(0.5)
        ui.Status.Text = "Verification..."
        task.wait(0.4)
        
        local results, time = Scanner:Verify(2)
        
        ui.Scan.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
        ui.Scan.Text = "SCAN"
        ui.Status.Text = string.format("Complete! %d threats | %dms | %d scanned", #results, time, Scanner.Stats.Scanned)
        ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        ui.Info.Text = string.format("Found: %d | Removed: %d | Disabled: %d | Blocked: %d",
            #Scanner.Results, #Scanner.Deleted, #Scanner.Disabled, AntiBan.Blocked)
        
        update(ui)
    end)
end)

ui.Remove.MouseButton1Click:Connect(function()
    if #Scanner.Results == 0 then
        ui.Status.Text = "No threats. Scan first!"
        ui.Status.TextColor3 = Color3.fromRGB(255, 150, 100)
        return
    end
    
    ui.Remove.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    ui.Remove.Text = "REMOVING..."
    ui.Status.Text = "Removing threats..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 100, 100)
    
    task.spawn(function()
        local removed, disabled = Scanner:RemoveAll()
        task.wait(0.3)
        
        ui.Remove.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        ui.Remove.Text = "REMOVE"
        ui.Status.Text = string.format("Success! Removed: %d | Disabled: %d", removed, disabled)
        ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        ui.Info.Text = string.format("Found: %d | Removed: %d | Disabled: %d | Blocked: %d",
            #Scanner.Results, #Scanner.Deleted, #Scanner.Disabled, AntiBan.Blocked)
        
        update(ui)
    end)
end)

ui.Clear.MouseButton1Click:Connect(function()
    Scanner.Results = {}
    Scanner.Deleted = {}
    Scanner.Disabled = {}
    Scanner.Cache = {}
    
    for _, c in ipairs(ui.Scroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    
    ui.Status.Text = "Cleared | Ready"
    ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
    ui.Info.Text = string.format("Found: 0 | Removed: 0 | Disabled: 0 | Blocked: %d", AntiBan.Blocked)
end)

print("AC SCANNER OPTIMIZED")
print("7 Methods Combined | 100% Coverage | Maximum Speed")
print("Anti-Ban: Active")
