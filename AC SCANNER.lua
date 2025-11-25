--[[
    ═══════════════════════════════════════════════════════
    AC SCANNER V1.5 - UNIVERSAL EXECUTOR EDITION
    ═══════════════════════════════════════════════════════
    Version: 1.5 Universal
    Release Date: 2024
    
    Compatible Executors:
    ✓ Synapse X/Z
    ✓ Script-Ware
    ✓ KRNL
    ✓ Fluxus
    ✓ Electron
    ✓ Delta
    ✓ Evon
    ✓ Solara
    ✓ Wave
    ✓ And more...
    
    Features:
    • Auto disable + remove after each scan
    • 3 Advanced scan methods
    • Enhanced Anti-Ban protection
    • Minimal & professional GUI
    • Universal executor compatible
    • Real-time statistics
    • Fallback systems for all executors
    
    Changelog V1.5 Universal:
    • Universal executor compatibility
    • Safe metamethod hooks
    • Multiple fallback systems
    • Enhanced error handling
    • Optimized for all executors
    • Better performance
    ═══════════════════════════════════════════════════════
]]

local VERSION = "1.5 Universal"

-- Executor Detection
local Executor = {
    Name = "Unknown",
    HasMetaHook = false,
    HasNewCClosure = false,
    HasSetReadonly = false
}

-- Detect executor capabilities
pcall(function()
    if syn then Executor.Name = "Synapse"
    elseif KRNL_LOADED then Executor.Name = "KRNL"
    elseif isfluxus then Executor.Name = "Fluxus"
    elseif getexecutorname then Executor.Name = getexecutorname()
    elseif identifyexecutor then Executor.Name = identifyexecutor()
    end
    
    Executor.HasMetaHook = getrawmetatable ~= nil
    Executor.HasNewCClosure = newcclosure ~= nil or protect_function ~= nil
    Executor.HasSetReadonly = setreadonly ~= nil or make_writeable ~= nil
end)

local Scanner = {
    Results = {},
    Deleted = {},
    Disabled = {},
    Stats = {Found = 0, Removed = 0, Disabled = 0}
}

-- Universal Services (Safe for all executors)
local Services = {}
local function getService(name)
    if not Services[name] then
        local s, v = pcall(function()
            return game:GetService(name)
        end)
        Services[name] = s and v or nil
    end
    return Services[name]
end

-- Pre-load services
local serviceList = {"Players", "CoreGui", "UserInputService", "RunService"}
for _, n in ipairs(serviceList) do
    getService(n)
end

local Player = Services.Players and Services.Players.LocalPlayer

-- Universal Anti-Ban (Works with all executors)
local AntiBan = {Active = false, Blocked = 0, Protected = {}}

function AntiBan:Init()
    if self.Active then return end
    self.Active = true
    
    local patterns = {
        "kick", "ban", "report", "flag", "log", "anticheat", 
        "anti", "cheat", "detect", "exploit", "hack"
    }
    
    -- Universal metamethod hook with fallbacks
    local hooked = false
    
    -- Method 1: Standard metamethod hook
    if Executor.HasMetaHook then
        pcall(function()
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            
            -- Safe setreadonly
            local function safeSetReadonly(t, state)
                if setreadonly then
                    setreadonly(t, state)
                elseif make_writeable and not state then
                    make_writeable(t)
                elseif make_readonly and state then
                    make_readonly(t)
                end
            end
            
            safeSetReadonly(mt, false)
            
            -- Safe newcclosure
            local function safeWrap(func)
                if newcclosure then
                    return newcclosure(func)
                elseif protect_function then
                    return protect_function(func)
                end
                return func
            end
            
            mt.__namecall = safeWrap(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                if method == "FireServer" or method == "InvokeServer" then
                    local name = tostring(self):lower()
                    for _, p in ipairs(patterns) do
                        if name:find(p, 1, true) then
                            AntiBan.Blocked = AntiBan.Blocked + 1
                            return
                        end
                    end
                    
                    -- Check args
                    for _, arg in ipairs(args) do
                        if type(arg) == "string" then
                            local lower = arg:lower()
                            for _, p in ipairs(patterns) do
                                if lower:find(p, 1, true) then
                                    AntiBan.Blocked = AntiBan.Blocked + 1
                                    return
                                end
                            end
                        end
                    end
                elseif method == "Kick" then
                    AntiBan.Blocked = AntiBan.Blocked + 1
                    return
                end
                
                return oldNamecall(self, ...)
            end)
            
            safeSetReadonly(mt, true)
            hooked = true
        end)
    end
    
    -- Method 2: Fallback - Hook player directly
    if not hooked and Player then
        pcall(function()
            local oldKick = Player.Kick
            Player.Kick = function()
                AntiBan.Blocked = AntiBan.Blocked + 1
            end
            hooked = true
        end)
    end
    
    -- Character protection (universal)
    if Player then
        task.spawn(function()
            while self.Active do
                pcall(function()
                    local char = Player.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            -- Store values
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

-- Universal disable (works on all executors)
local function disable(obj)
    local success = false
    pcall(function()
        if obj and obj.Parent then
            if obj:IsA("LuaSourceContainer") then
                obj.Disabled = true
                success = true
            end
        end
    end)
    return success
end

-- Universal delete (works on all executors)
local function delete(obj)
    local success = false
    pcall(function()
        if obj and obj.Parent then
            obj:Destroy()
            success = true
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
            local descendants = {}
            pcall(function()
                descendants = svc:GetDescendants()
            end)
            
            for _, obj in ipairs(descendants) do
                pcall(function()
                    local cls = obj.ClassName
                    if cls:find("Remote") or cls:find("Script") or cls:find("Bindable") then
                        local name = obj.Name:lower()
                        if match(name) then
                            found = found + 1
                            
                            if disable(obj) then
                                Scanner.Stats.Disabled = Scanner.Stats.Disabled + 1
                                table.insert(Scanner.Disabled, {Name = obj.Name, Type = cls})
                            end
                            
                            task.wait(0.01)
                            if delete(obj) then
                                Scanner.Stats.Removed = Scanner.Stats.Removed + 1
                                table.insert(Scanner.Deleted, {Name = obj.Name, Type = cls})
                            end
                        end
                    end
                end)
            end
        end
    end
    
    return found
end

-- Method 2: Deep Scan + Auto Remove
local function method2()
    local found = 0
    local all = {}
    
    pcall(function()
        all = game:GetDescendants()
    end)
    
    for i = 1, #all do
        pcall(function()
            local obj = all[i]
            local cls = obj.ClassName
            
            if cls:find("Remote") or cls:find("Script") or cls:find("Bindable") then
                local name = obj.Name:lower()
                local path = ""
                pcall(function() path = obj:GetFullName():lower() end)
                
                if match(name) or match(path) then
                    found = found + 1
                    
                    if disable(obj) then
                        Scanner.Stats.Disabled = Scanner.Stats.Disabled + 1
                        table.insert(Scanner.Disabled, {Name = obj.Name, Type = cls})
                    end
                    
                    task.wait(0.01)
                    if delete(obj) then
                        Scanner.Stats.Removed = Scanner.Stats.Removed + 1
                        table.insert(Scanner.Deleted, {Name = obj.Name, Type = cls})
                    end
                end
                
                -- Parent check
                pcall(function()
                    local p = obj.Parent
                    for lvl = 1, 3 do
                        if p and p ~= game then
                            if match(p.Name:lower()) then
                                found = found + 1
                                disable(obj)
                                task.wait(0.01)
                                delete(obj)
                                break
                            end
                            p = p.Parent
                        else
                            break
                        end
                    end
                end)
                
                -- Hash check
                local len = #obj.Name
                if len == 32 or len == 40 or len == 64 then
                    found = found + 1
                    disable(obj)
                    task.wait(0.01)
                    delete(obj)
                end
            end
        end)
        
        if i % 150 == 0 then task.wait() end
    end
    
    return found
end

-- Method 3: Verification Check
local function method3()
    local remaining = 0
    local services = {"ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui", "Workspace"}
    
    for _, svcName in ipairs(services) do
        local svc = game:FindService(svcName)
        if svc then
            local descendants = {}
            pcall(function()
                descendants = svc:GetDescendants()
            end)
            
            for _, obj in ipairs(descendants) do
                pcall(function()
                    local cls = obj.ClassName
                    if cls:find("Remote") or cls:find("Script") or cls:find("Bindable") then
                        local name = obj.Name:lower()
                        
                        if match(name) then
                            remaining = remaining + 1
                            
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
                end)
            end
        end
    end
    
    return remaining
end

-- Universal GUI (Compatible with all executors)
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "ACS_" .. tostring(math.random(1000, 9999))
    sg.ResetOnSpawn = false
    
    -- Try CoreGui first, then PlayerGui
    local guiParented = false
    pcall(function()
        sg.Parent = getService("CoreGui")
        guiParented = true
    end)
    
    if not guiParented and Player then
        pcall(function()
            local pg = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 3)
            if pg then
                sg.Parent = pg
                guiParented = true
            end
        end)
    end
    
    if not guiParented then
        warn("[AC Scanner] Failed to parent GUI")
        return nil
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
    
    local cover = Instance.new("Frame", titleBar)
    cover.Size = UDim2.new(1, 0, 0, 10)
    cover.Position = UDim2.new(0, 0, 1, -10)
    cover.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    cover.BorderSizePixel = 0
    
    local t = Instance.new("TextLabel", titleBar)
    t.Size = UDim2.new(1, -80, 1, 0)
    t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = "AC SCANNER V" .. VERSION
    t.TextColor3 = Color3.fromRGB(255, 255, 255)
    t.TextSize = 14
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    
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
    
    local content = Instance.new("Frame", m)
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, -35)
    content.Position = UDim2.new(0, 0, 0, 35)
    content.BackgroundTransparency = 1
    
    local st = Instance.new("TextLabel", content)
    st.Name = "Status"
    st.Size = UDim2.new(1, -20, 0, 25)
    st.Position = UDim2.new(0, 10, 0, 10)
    st.BackgroundTransparency = 1
    st.Text = "Ready | Executor: " .. Executor.Name
    st.TextColor3 = Color3.fromRGB(100, 255, 100)
    st.TextSize = 11
    st.Font = Enum.Font.GothamBold
    st.TextXAlignment = Enum.TextXAlignment.Left
    
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
    
    close.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)
    
    local minimized = false
    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        
        pcall(function()
            if minimized then
                m:TweenSize(UDim2.new(0, 400, 0, 35), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
                minimize.Text = "+"
                content.Visible = false
            else
                m:TweenSize(UDim2.new(0, 400, 0, 180), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
                minimize.Text = "-"
                content.Visible = true
            end
        end)
    end)
    
    -- Universal drag (works on all executors)
    local drag, dragInput, dragStart, startPos
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dragStart = input.Position
            startPos = m.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    drag = false
                end
            end)
        end
    end)
    
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    local uis = getService("UserInputService")
    if uis then
        uis.InputChanged:Connect(function(input)
            if input == dragInput and drag then
                local delta = input.Position - dragStart
                m.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    
    return {GUI = sg, Main = m, Status = st, Info = info, Scan = scan, Content = content}
end

-- Init
AntiBan:Init()
local ui = createGUI()

if not ui then
    warn("[AC Scanner] GUI creation failed")
    return
end

-- Scan Handler
ui.Scan.MouseButton1Click:Connect(function()
    ui.Scan.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    ui.Scan.Text = "SCANNING..."
    ui.Status.Text = "Method 1: Fast scan..."
    ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
    
    Scanner.Stats.Found = 0
    Scanner.Stats.Removed = 0
    Scanner.Stats.Disabled = 0
    
    task.spawn(function()
        local found1 = method1()
        Scanner.Stats.Found = Scanner.Stats.Found + found1
        ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
            Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
        
        task.wait(0.3)
        ui.Status.Text = "Method 2: Deep scan..."
        
        local found2 = method2()
        Scanner.Stats.Found = Scanner.Stats.Found + found2
        ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
            Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
        
        task.wait(0.3)
        ui.Status.Text = "Method 3: Verification..."
        
        local remaining = method3()
        ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
            Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
        
        task.wait(0.3)
        ui.Status.Text = "Final check..."
        task.wait(0.5)
        
        local finalCheck = method3()
        
        ui.Scan.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
        ui.Scan.Text = "SCAN & AUTO REMOVE"
        
        if finalCheck == 0 then
            ui.Status.Text = string.format("Complete! Removed: %d | CLEAN!", Scanner.Stats.Removed)
            ui.Status.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            ui.Status.Text = string.format("Complete! Removed: %d | %d remain", Scanner.Stats.Removed, finalCheck)
            ui.Status.TextColor3 = Color3.fromRGB(255, 200, 100)
        end
        
        ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
            Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
    end)
end)

-- Auto-update
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if ui and ui.Info then
                ui.Info.Text = string.format("Removed: %d\nDisabled: %d\nBlocked: %d", 
                    Scanner.Stats.Removed, Scanner.Stats.Disabled, AntiBan.Blocked)
            end
        end)
    end
end)

print("═══════════════════════════════════════════════════════")
print("AC SCANNER V" .. VERSION .. " LOADED")
print("═══════════════════════════════════════════════════════")
print("✓ Executor: " .. Executor.Name)
print("✓ Meta Hook: " .. (Executor.HasMetaHook and "YES" or "NO"))
print("✓ NewCClosure: " .. (Executor.HasNewCClosure and "YES" or "NO"))
print("✓ Auto Remove: ON")
print("✓ Anti-Ban: Enhanced")
print("✓ 3 Advanced Methods")
print("═══════════════════════════════════════════════════════")
print("Ready to scan!")
print("═══════════════════════════════════════════════════════")
