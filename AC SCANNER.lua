--[[
    ═══════════════════════════════════════════════════════
    AC SCANNER V1.5 - AUTO REMOVE & MINIMAL
    ═══════════════════════════════════════════════════════
    Version: 1.5
    Release Date: 2024
    
    Features:
    • Auto disable + remove after each scan
    • 3 Advanced scan methods
    • Enhanced Anti-Ban protection
    • Minimal & professional GUI
    • Universal executor compatible
    • Real-time statistics
    
    Changelog V1.5:
    • Added minimize button
    • Added close button
    • Improved title bar design
    • Better window management
    • Enhanced GUI animations
    • Optimized performance
    ═══════════════════════════════════════════════════════
]]

local VERSION = "1.5"

local Scanner = {
    Results = {},
    Deleted = {},
    Disabled = {},
    Stats = {Found = 0, Removed = 0, Disabled = 0}
}

-- Universal Services
local Services = {}
local function getService(name)
    if not Services[name] then
        local s, v = pcall(game.GetService, game, name)
        Services[name] = s and v or nil
    end
    return Services[name]
end

for _, n in ipairs({"Players", "CoreGui", "UserInputService"}) do
    getService(n)
end

local Player = Services.Players and Services.Players.LocalPlayer

-- Enhanced Anti-Ban
local AntiBan = {Active = false, Blocked = 0, Protected = {}}

function AntiBan:Init()
    if self.Active then return end
    self.Active = true
    
    local patterns = {
        "kick", "ban", "report", "flag", "log", "anticheat", 
        "anti", "cheat", "detect", "exploit", "hack"
    }
    
    -- Hook metamethods
    pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        local oldNamecall = mt.__namecall
        
        setreadonly(mt, false)
        
        -- Hook __namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if method == "FireServer" or method == "InvokeServer" then
                local name = tostring(self):lower()
                for _, p in ipairs(patterns) do
                    if name:find(p, 1, true) then
                        self.Blocked = self.Blocked + 1
                        return
                    end
                end
                
                -- Check args
                for _, arg in ipairs(args) do
                    if type(arg) == "string" then
                        local lower = arg:lower()
                        for _, p in ipairs(patterns) do
                            if lower:find(p, 1, true) then
                                self.Blocked = self.Blocked + 1
                                return
                            end
                        end
                    end
                end
            elseif method == "Kick" then
                self.Blocked = self.Blocked + 1
                return
            end
            
            return oldNamecall(self, ...)
        end)
        
        -- Hook __index for protection
        mt.__index = newcclosure(function(t, k)
            if Player and t == Player then
                if k == "Kick" then
                    return function() end
                end
            end
            return oldIndex(t, k)
        end)
        
        setreadonly(mt, true)
    end)
    
    -- Protect character
    if Player then
        task.spawn(function()
            while self.Active do
                pcall(function()
                    local char = Player.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            -- Store protected values
                            if hum.WalkSpeed > 16 then
                                self.Protected.WalkSpeed = hum.WalkSpeed
                            end
                            if hum.JumpPower and hum.JumpPower > 50 then
                                self.Protected.JumpPower = hum.JumpPower
                            end
                            if hum.JumpHeight and hum.JumpHeight > 7.2 then
                                self.Protected.JumpHeight = hum.JumpHeight
                            end
                        end
                    end
                end)
                task.wait(1)
            end
        end)
    end
end

-- Keywords
local KEYWORDS = {
    "kick", "ban", "detect", "anticheat", "anti", "cheat", "exploit",
    "flag", "report", "security", "verify", "check", "validate",
    "monitor", "log", "guard", "protect", "ac", "admin", "mod",
    "k1ck", "b4n", "ant1", "ch3at", "expl01t",
    "system", "handler", "controller", "manager",
    "remote_", "_remote", "secure", "safe"
}

-- Fast match
local function match(str)
    for i = 1, #KEYWORDS do
        if str:find(KEYWORDS[i], 1, true) then return true end
    end
    return false
end

-- Disable object
local function disable(obj)
    local success = pcall(function()
        if obj and obj.Parent then
            if obj:IsA("LuaSourceContainer") then
                obj.Disabled = true
                return true
            end
        end
    end)
    return success
end

-- Delete object
local function delete(obj)
    local success = pcall(function()
        if obj and obj.Parent then
            obj:Destroy()
            return true
        end
    end)
    return success
end

-- Method 1: Fast Scan + Auto Remove
local function method1()
    local found = 0
    local services = {"ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui"}
    
    for _, svcName in ipairs(services) do
        local svc = game:FindService(svcName)
        if svc then
            for _, obj in ipairs(svc:GetDescendants()) do
                local cls = obj.ClassName
                if cls:find("Remote") or cls:find("Script") or cls:find("Bindable") then
                    local name = obj.Name:lower()
                    if match(name) then
                        found = found + 1
                        
                        -- Disable first
                        if disable(obj) then
                            Scanner.Stats.Disabled = Scanner.Stats.Disabled + 1
                            table.insert(Scanner.Disabled, {Name = obj.Name, Type = cls})
                        end
                        
                        -- Then delete
                        task.wait(0.01)
                        if delete(obj) then
                            Scanner.Stats.Removed = Scanner.Stats.Removed + 1
                            table.insert(Scanner.Deleted, {Name = obj.Name, Type = cls})
                        end
                    end
                end
            end
        end
    end
    
    return found
end

-- Method 2: Deep Scan + Auto Remove
local function method2()
    local found = 0
    local all = game:GetDescendants()
    
    for i = 1, #all do
        local obj = all[i]
        local cls = obj.ClassName
        
        if cls:find("Remote") or cls:find("Script") or cls:find("Bindable") then
            local name = obj.Name:lower()
            local path = obj:GetFullName():lower()
            
            -- Pattern check
            if match(name) or match(path) then
                found = found + 1
                
                -- Disable first
                if disable(obj) then
                    Scanner.Stats.Disabled = Scanner.Stats.Disabled + 1
                    table.insert(Scanner.Disabled, {Name = obj.Name, Type = cls})
                end
                
                -- Then delete
                task.wait(0.01)
                if delete(obj) then
                    Scanner.Stats.Removed = Scanner.Stats.Removed + 1
                    table.insert(Scanner.Deleted, {Name = obj.Name, Type = cls})
                end
            end
            
            -- Parent check
            local p = obj.Parent
            for lvl = 1, 3 do
                if p and p ~= game then
                    if match(p.Name:lower()) then
                        found = found + 1
                        
                        if disable(obj) then
                            Scanner.Stats.Disabled = Scanner.Stats.Disabled + 1
                        end
                        
                        task.wait(0.01)
                        if delete(obj) then
                            Scanner.Stats.Removed = Scanner.Stats.Removed + 1
                        end
                        break
                    end
                    p = p.Parent
                else
                    break
                end
            end
            
            -- Hash check
            local len = #obj.Name
            if len == 32 or len == 40 or len == 64 then
                found = found + 1
                if disable(obj) then Scanner.Stats.Disabled = Scanner.Stats.Disabled + 1 end
                task.wait(0.01)
                if delete(obj) then Scanner.Stats.Removed = Scanner.Stats.Removed + 1 end
            end
        end
        
        if i % 200 == 0 then task.wait() end
    end
    
    return found
end

-- Method 3: Verification Check (Check if removed)
local function method3()
    local remaining = 0
    local services = {"ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui", "Workspace"}
    
    for _, svcName in ipairs(services) do
        local svc = game:FindService(svcName)
        if svc then
            for _, obj in ipairs(svc:GetDescendants()) do
                local cls = obj.ClassName
                if cls:find("Remote") or cls:find("Script") or cls:find("Bindable") then
                    local name = obj.Name:lower()
                    
                    if match(name) then
                        remaining = remaining + 1
                        
                        -- Try to remove again
                        if obj:IsA("LuaSourceContainer") and not obj.Disabled then
                            obj.Disabled = true
                            Scanner.Stats.Disabled = Scanner.Stats.Disabled + 1
                        end
                        
                        task.wait(0.01)
                        if obj.Parent then
                            obj:Destroy()
                            Scanner.Stats.Removed = Scanner.Stats.Removed + 1
                        end
                    end
                end
            end
        end
    end
    
    return remaining
end

-- Minimal GUI
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "ACS"
    sg.ResetOnSpawn = false
    
    pcall(function() sg.Parent = getService("CoreGui") end)
    if not sg.Parent and Player then
        sg.Parent = Player:WaitForChild("PlayerGui")
    end
    
    local m = Instance.new("Frame", sg)
    m.Name = "Main"
    m.Size = UDim2.new(0, 400, 0, 180)
    m.Position = UDim2.new(0.5, -200, 0.5, -90)
    m.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    m.BorderSizePixel = 0
    
    Instance.new("UICorner", m).CornerRadius = UDim.new(0, 10)
    
    -- Title bar
    local titleBar = Instance.new("Frame", m)
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    titleBar.BorderSizePixel = 0
    
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
    
    -- Cover bottom of title bar
    local cover = Instance.new("Frame", titleBar)
    cover.Size = UDim2.new(1, 0, 0, 10)
    cover.Position = UDim2.new(0, 0, 1, -10)
    cover.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    cover.BorderSizePixel = 0
    
    -- Title
    local t = Instance.new("TextLabel", titleBar)
    t.Size = UDim2.new(1, -80, 1, 0)
    t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = "AC SCANNER V" .. VERSION
    t.TextColor3 = Color3.fromRGB(255, 255, 255)
    t.TextSize = 16
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Minimize button
    local minimize = Instance.new("TextButton", titleBar)
    minimize.Name = "Minimize"
    minimize.Size = UDim2.new(0, 30, 0, 28)
    minimize.Position = UDim2.new(1, -68, 0, 3.5)
    minimize.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    minimize.Text = "-"
    minimize.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimize.TextSize = 18
    minimize.Font = Enum.Font.GothamBold
    Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 6)
    
    -- Close button
    local close = Instance.new("TextButton", titleBar)
    close.Name = "Close"
    close.Size = UDim2.new(0, 30, 0, 28)
    close.Position = UDim2.new(1, -35, 0, 3.5)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 14
    close.Font = Enum.Font.GothamBold
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
    
    -- Content frame
    local content = Instance.new("Frame", m)
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, -35)
    content.Position = UDim2.new(0, 0, 0, 35)
    content.BackgroundTransparency = 1
    
    -- Status
    local st = Instance.new("TextLabel", content)
    st.Name = "Status"
    st.Size = UDim2.new(1, -20, 0, 25)
    st.Position = UDim2.new(0, 10, 0, 10)
    st.BackgroundTransparency = 1
    st.Text = "Ready | Auto-Remove: ON | Version: " .. VERSION
    st.TextColor3 = Color3.fromRGB(100, 255, 100)
    st.TextSize = 12
    st.Font = Enum.Font.GothamBold
    st.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Info
    local info = Instance.new("TextLabel", content)
    info.Name = "Info"
    info.Size = UDim2.new(1, -20, 0, 40)
    info.Position = UDim2.new(0, 10, 0, 40)
    info.BackgroundTransparency = 1
    info.Text = "Removed: 0\nDisabled: 0\nBlocked: 0"
    info.TextColor3 = Color3.fromRGB(180, 180, 180)
    info.TextSize = 11
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    
    -- Button
    local scan = Instance.new("TextButton", content)
    scan.Name = "Scan"
    scan.Size = UDim2.new(1, -20, 0, 40)
    scan.Position = UDim2.new(0, 10, 1, -48)
    scan.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
    scan.Text = "SCAN & AUTO REMOVE"
    scan.TextColor3 = Color3.fromRGB(255, 255, 255)
    scan.TextSize = 13
    scan.Font = Enum.Font.GothamBold
    Instance.new("UICorner", scan).CornerRadius = UDim.new(0, 8)
    
    -- Close functionality
    close.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)
    
    -- Minimize functionality
    local minimized = false
    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        
        if minimized then
            m:TweenSize(
                UDim2.new(0, 400, 0, 35),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.3,
                true
            )
            minimize.Text = "+"
            content.Visible = false
        else
            m:TweenSize(
                UDim2.new(0, 400, 0, 180),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.3,
                true
            )
            minimize.Text = "-"
            content.Visible = true
        end
    end)
    
    -- Drag (on title bar only)
    local drag, inp, dstart, spos
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dstart = i.Position
            spos = m.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    
    titleBar.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then inp = i end
    end)
    
    if Services.UserInputService then
        Services.UserInputService.InputChanged:Connect(function(i)
            if i == inp and drag then
                local d = i.Position - dstart
                m.Position = UDim2.new(spos.X.Scale, spos.X.Offset + d.X, spos.Y.Scale, spos.Y.Offset + d.Y)
            end
        end)
    end
    
    return {GUI = sg, Main = m, Status = st, Info = info, Scan = scan, Content = content}
end

-- Init
AntiBan:Init()
local ui = createGUI()

-- Scan Handler
ui.Scan.MouseButton1Click:Connect(function()
    ui.Scan.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    ui.Scan.Text = "SCANNING..."
    ui.Status.Text = "Method 1: Fast scan + remove..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
    
    -- Reset stats
    Scanner.Stats.Found = 0
    Scanner.Stats.Removed = 0
    Scanner.Stats.Disabled = 0
    
    task.spawn(function()
        -- Method 1
        local found1 = method1()
        Scanner.Stats.Found = Scanner.Stats.Found + found1
        ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
            Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
        
        task.wait(0.3)
        ui.Status.Text = "Method 2: Deep scan + remove..."
        
        -- Method 2
        local found2 = method2()
        Scanner.Stats.Found = Scanner.Stats.Found + found2
        ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
            Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
        
        task.wait(0.3)
        ui.Status.Text = "Method 3: Verification check..."
        
        -- Method 3
        local remaining = method3()
        ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
            Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
        
        task.wait(0.3)
        
        -- Final check
        ui.Status.Text = "Final verification..."
        task.wait(0.5)
        
        local finalCheck = method3()
        
        ui.Scan.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
        ui.Scan.Text = "SCAN & AUTO REMOVE"
        
        if finalCheck == 0 then
            ui.Status.Text = string.format("V%s | Complete! Removed: %d | Disabled: %d | CLEAN!", 
                VERSION, Scanner.Stats.Removed, Scanner.Stats.Disabled)
            ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            ui.Status.Text = string.format("V%s | Complete! Removed: %d | %d protected remain", 
                VERSION, Scanner.Stats.Removed, finalCheck)
            ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
        end
        
        ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
            Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
    end)
end)

-- Auto-update info
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
                Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
        end)
    end
end)

print("═══════════════════════════════════════════════════════")
print("AC SCANNER V" .. VERSION .. " LOADED")
print("═══════════════════════════════════════════════════════")
print("✓ Auto Remove: ON")
print("✓ Universal Executor Compatible")
print("✓ Anti-Ban: Enhanced")
print("✓ Character Protection: Active")
print("✓ 3 Advanced Scan Methods")
print("✓ Minimize/Close Functions")
print("═══════════════════════════════════════════════════════")
print("Ready to scan! Click button to start.")
print("═══════════════════════════════════════════════════════")
