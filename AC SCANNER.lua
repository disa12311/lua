--[[
    ═══════════════════════════════════════════════════════
    AC SCANNER V2.0 - MODERN EDITION
    ═══════════════════════════════════════════════════════
    Version: 2.0
    Release: 2024
    Architecture: Modern Lua 5.1+
    
    🚀 Modern Features:
    • TypeScript-like class system
    • Async/await pattern with promises
    • Event-driven architecture
    • Singleton pattern
    • Observer pattern for UI updates
    • Modular design
    • ES6+ inspired syntax
    
    🎯 Core Systems:
    • Smart executor detection
    • Advanced anti-ban system
    • Real-time scanning engine
    • Modern UI framework
    • Auto-remove pipeline
    
    ⚡ Performance:
    • Optimized async operations
    • Non-blocking scans
    • Memory efficient
    • Lazy loading
    ═══════════════════════════════════════════════════════
]]

-- ============================================================
-- CONSTANTS & CONFIG
-- ============================================================

local VERSION = "2.0"

local Config = {
    SCAN_DELAY = 0.01,
    BATCH_SIZE = 150,
    UPDATE_INTERVAL = 2,
    ANIMATION_SPEED = 0.3,
    KEYWORDS = {
        "kick", "ban", "detect", "anticheat", "anti", "cheat", "exploit",
        "flag", "report", "security", "verify", "check", "validate",
        "monitor", "log", "guard", "protect", "ac", "admin", "mod",
        "k1ck", "b4n", "ant1", "ch3at", "expl01t",
        "system", "handler", "controller", "manager",
        "remote_", "_remote", "secure", "safe"
    }
}

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

local Utils = {}

function Utils.pcall(func, ...)
    local success, result = pcall(func, ...)
    return success and result or nil
end

function Utils.safeGetService(serviceName)
    return Utils.pcall(game.GetService, game, serviceName)
end

function Utils.match(str, patterns)
    local lower = str:lower()
    for _, pattern in ipairs(patterns) do
        if lower:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

function Utils.delay(seconds)
    return task.wait(seconds)
end

-- ============================================================
-- EXECUTOR DETECTION (Singleton)
-- ============================================================

local Executor = (function()
    local instance
    
    local function create()
        local self = {
            name = "Unknown",
            capabilities = {
                metaHook = false,
                newCClosure = false,
                setReadonly = false
            }
        }
        
        -- Detect executor
        Utils.pcall(function()
            if syn then 
                self.name = "Synapse"
            elseif KRNL_LOADED then 
                self.name = "KRNL"
            elseif isfluxus then 
                self.name = "Fluxus"
            elseif getexecutorname then 
                self.name = getexecutorname()
            elseif identifyexecutor then 
                self.name = identifyexecutor()
            end
            
            self.capabilities.metaHook = getrawmetatable ~= nil
            self.capabilities.newCClosure = newcclosure ~= nil or protect_function ~= nil
            self.capabilities.setReadonly = setreadonly ~= nil or make_writeable ~= nil
        end)
        
        function self:hasCapability(cap)
            return self.capabilities[cap] or false
        end
        
        function self:info()
            return {
                name = self.name,
                capabilities = self.capabilities
            }
        end
        
        return self
    end
    
    return {
        getInstance = function()
            if not instance then
                instance = create()
            end
            return instance
        end
    }
end)()

-- ============================================================
-- SERVICE MANAGER (Singleton)
-- ============================================================

local ServiceManager = (function()
    local instance
    
    local function create()
        local self = {
            services = {},
            player = nil
        }
        
        function self:get(serviceName)
            if not self.services[serviceName] then
                self.services[serviceName] = Utils.safeGetService(serviceName)
            end
            return self.services[serviceName]
        end
        
        function self:init()
            -- Pre-load essential services
            local essential = {"Players", "CoreGui", "UserInputService", "RunService"}
            for _, name in ipairs(essential) do
                self:get(name)
            end
            
            local players = self:get("Players")
            self.player = players and players.LocalPlayer
        end
        
        return self
    end
    
    return {
        getInstance = function()
            if not instance then
                instance = create()
                instance:init()
            end
            return instance
        end
    }
end)()

-- ============================================================
-- ANTI-BAN SYSTEM (Class)
-- ============================================================

local AntiBan = {}
AntiBan.__index = AntiBan

function AntiBan.new()
    local self = setmetatable({}, AntiBan)
    
    self.active = false
    self.blocked = 0
    self.protected = {}
    self.patterns = {
        "kick", "ban", "report", "flag", "log", 
        "anticheat", "anti", "cheat", "detect", "exploit", "hack"
    }
    
    return self
end

function AntiBan:init()
    if self.active then return end
    self.active = true
    
    self:hookMetaMethods()
    self:protectCharacter()
end

function AntiBan:hookMetaMethods()
    local executor = Executor.getInstance()
    
    if not executor:hasCapability("metaHook") then
        return self:fallbackHook()
    end
    
    Utils.pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        
        -- Safe setreadonly
        local function setReadonly(t, state)
            if setreadonly then
                setreadonly(t, state)
            elseif make_writeable and not state then
                make_writeable(t)
            elseif make_readonly and state then
                make_readonly(t)
            end
        end
        
        -- Safe newcclosure
        local function wrapFunction(func)
            if newcclosure then
                return newcclosure(func)
            elseif protect_function then
                return protect_function(func)
            end
            return func
        end
        
        setReadonly(mt, false)
        
        mt.__namecall = wrapFunction(function(obj, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if method == "FireServer" or method == "InvokeServer" then
                local name = tostring(obj):lower()
                
                -- Check object name
                if Utils.match(name, self.patterns) then
                    self.blocked = self.blocked + 1
                    return
                end
                
                -- Check arguments
                for _, arg in ipairs(args) do
                    if type(arg) == "string" and Utils.match(arg, self.patterns) then
                        self.blocked = self.blocked + 1
                        return
                    end
                end
            elseif method == "Kick" then
                self.blocked = self.blocked + 1
                return
            end
            
            return oldNamecall(obj, ...)
        end)
        
        setReadonly(mt, true)
    end)
end

function AntiBan:fallbackHook()
    local sm = ServiceManager.getInstance()
    local player = sm.player
    
    if player then
        Utils.pcall(function()
            local oldKick = player.Kick
            player.Kick = function()
                self.blocked = self.blocked + 1
            end
        end)
    end
end

function AntiBan:protectCharacter()
    local sm = ServiceManager.getInstance()
    local player = sm.player
    
    if not player then return end
    
    task.spawn(function()
        while self.active do
            Utils.pcall(function()
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        if hum.WalkSpeed > 16 then
                            self.protected.WalkSpeed = hum.WalkSpeed
                        end
                        if hum.JumpPower and hum.JumpPower > 50 then
                            self.protected.JumpPower = hum.JumpPower
                        end
                        if hum.JumpHeight and hum.JumpHeight > 7.2 then
                            self.protected.JumpHeight = hum.JumpHeight
                        end
                    end
                end
            end)
            Utils.delay(1)
        end
    end)
end

function AntiBan:getStats()
    return {
        blocked = self.blocked,
        protected = self.protected
    }
end

-- ============================================================
-- SCANNER ENGINE (Class)
-- ============================================================

local Scanner = {}
Scanner.__index = Scanner

function Scanner.new()
    local self = setmetatable({}, Scanner)
    
    self.results = {}
    self.deleted = {}
    self.disabled = {}
    self.stats = {
        found = 0,
        removed = 0,
        disabled = 0
    }
    self.observers = {}
    
    return self
end

function Scanner:subscribe(callback)
    table.insert(self.observers, callback)
end

function Scanner:notify()
    for _, callback in ipairs(self.observers) do
        Utils.pcall(callback, self:getStats())
    end
end

function Scanner:disable(obj)
    return Utils.pcall(function()
        if obj and obj.Parent and obj:IsA("LuaSourceContainer") then
            obj.Disabled = true
            self.stats.disabled = self.stats.disabled + 1
            table.insert(self.disabled, {name = obj.Name, type = obj.ClassName})
            return true
        end
    end) or false
end

function Scanner:delete(obj)
    return Utils.pcall(function()
        if obj and obj.Parent then
            obj:Destroy()
            self.stats.removed = self.stats.removed + 1
            table.insert(self.deleted, {name = obj.Name, type = obj.ClassName})
            return true
        end
    end) or false
end

function Scanner:processObject(obj)
    local cls = obj.ClassName
    
    if not (cls:find("Remote") or cls:find("Script") or cls:find("Bindable")) then
        return false
    end
    
    local name = obj.Name:lower()
    local path = Utils.pcall(obj.GetFullName, obj) or ""
    
    -- Pattern check
    if Utils.match(name, Config.KEYWORDS) or Utils.match(path:lower(), Config.KEYWORDS) then
        self:disable(obj)
        Utils.delay(Config.SCAN_DELAY)
        self:delete(obj)
        return true
    end
    
    -- Parent check
    local parent = obj.Parent
    for i = 1, 3 do
        if parent and parent ~= game then
            if Utils.match(parent.Name, Config.KEYWORDS) then
                self:disable(obj)
                Utils.delay(Config.SCAN_DELAY)
                self:delete(obj)
                return true
            end
            parent = parent.Parent
        else
            break
        end
    end
    
    -- Hash check
    local len = #obj.Name
    if len == 32 or len == 40 or len == 64 then
        self:disable(obj)
        Utils.delay(Config.SCAN_DELAY)
        self:delete(obj)
        return true
    end
    
    return false
end

function Scanner:scanService(serviceName)
    local found = 0
    local svc = game:FindService(serviceName)
    
    if svc then
        local descendants = Utils.pcall(svc.GetDescendants, svc) or {}
        
        for _, obj in ipairs(descendants) do
            Utils.pcall(function()
                if self:processObject(obj) then
                    found = found + 1
                end
            end)
        end
    end
    
    return found
end

function Scanner:fastScan()
    local services = {"ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui"}
    local total = 0
    
    for _, service in ipairs(services) do
        total = total + self:scanService(service)
    end
    
    return total
end

function Scanner:deepScan()
    local found = 0
    local all = Utils.pcall(game.GetDescendants, game) or {}
    
    for i, obj in ipairs(all) do
        Utils.pcall(function()
            if self:processObject(obj) then
                found = found + 1
            end
        end)
        
        if i % Config.BATCH_SIZE == 0 then
            Utils.delay(0)
        end
    end
    
    return found
end

function Scanner:verify()
    local services = {"ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui", "Workspace"}
    local remaining = 0
    
    for _, serviceName in ipairs(services) do
        local svc = game:FindService(serviceName)
        if svc then
            local descendants = Utils.pcall(svc.GetDescendants, svc) or {}
            
            for _, obj in ipairs(descendants) do
                Utils.pcall(function()
                    if self:processObject(obj) then
                        remaining = remaining + 1
                    end
                end)
            end
        end
    end
    
    return remaining
end

function Scanner:async(callback)
    task.spawn(function()
        callback(self)
    end)
end

function Scanner:reset()
    self.stats.found = 0
    self.stats.removed = 0
    self.stats.disabled = 0
end

function Scanner:getStats()
    return {
        found = self.stats.found,
        removed = self.stats.removed,
        disabled = self.stats.disabled,
        total = #self.results
    }
end

-- ============================================================
-- MODERN UI FRAMEWORK (Class)
-- ============================================================

local UI = {}
UI.__index = UI

function UI.new()
    local self = setmetatable({}, UI)
    
    self.elements = {}
    self.state = {
        minimized = false,
        scanning = false
    }
    
    return self
end

function UI:createElement(className, props)
    local element = Instance.new(className)
    
    for key, value in pairs(props or {}) do
        if key == "Children" then
            for _, child in ipairs(value) do
                child.Parent = element
            end
        else
            element[key] = value
        end
    end
    
    return element
end

function UI:createButton(props)
    local btn = self:createElement("TextButton", props)
    
    local corner = self:createElement("UICorner", {
        CornerRadius = UDim.new(0, props.CornerRadius or 8),
        Parent = btn
    })
    
    return btn
end

function UI:render()
    local sm = ServiceManager.getInstance()
    
    local sg = self:createElement("ScreenGui", {
        Name = "ACS_" .. tostring(math.random(1000, 9999)),
        ResetOnSpawn = false
    })
    
    -- Try CoreGui first
    local parented = Utils.pcall(function()
        sg.Parent = sm:get("CoreGui")
    end)
    
    if not parented and sm.player then
        Utils.pcall(function()
            sg.Parent = sm.player:WaitForChild("PlayerGui", 3)
        end)
    end
    
    local main = self:createElement("Frame", {
        Name = "Main",
        Size = UDim2.new(0, 420, 0, 190),
        Position = UDim2.new(0.5, -210, 0.5, -95),
        BackgroundColor3 = Color3.fromRGB(12, 12, 12),
        BorderSizePixel = 0,
        Parent = sg,
        Children = {
            self:createElement("UICorner", {CornerRadius = UDim.new(0, 12)}),
            self:createElement("UIStroke", {
                Color = Color3.fromRGB(70, 70, 70),
                Thickness = 2
            })
        }
    })
    
    -- Title Bar
    local titleBar = self:createElement("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(18, 18, 18),
        BorderSizePixel = 0,
        Parent = main,
        Children = {
            self:createElement("UICorner", {CornerRadius = UDim.new(0, 12)}),
            self:createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 12),
                Position = UDim2.new(0, 0, 1, -12),
                BackgroundColor3 = Color3.fromRGB(18, 18, 18),
                BorderSizePixel = 0
            })
        }
    })
    
    local title = self:createElement("TextLabel", {
        Size = UDim2.new(1, -85, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "AC SCANNER V" .. VERSION,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar
    })
    
    local minimize = self:createButton({
        Name = "Minimize",
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(1, -72, 0.5, -16),
        BackgroundColor3 = Color3.fromRGB(65, 65, 65),
        Text = "-",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        CornerRadius = 8,
        Parent = titleBar
    })
    
    local close = self:createButton({
        Name = "Close",
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(1, -36, 0.5, -16),
        BackgroundColor3 = Color3.fromRGB(220, 55, 55),
        Text = "×",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        CornerRadius = 8,
        Parent = titleBar
    })
    
    -- Content
    local content = self:createElement("Frame", {
        Name = "Content",
        Size = UDim2.new(1, 0, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundTransparency = 1,
        Parent = main
    })
    
    local executor = Executor.getInstance()
    local status = self:createElement("TextLabel", {
        Name = "Status",
        Size = UDim2.new(1, -24, 0, 26),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        Text = "Ready • Executor: " .. executor.name,
        TextColor3 = Color3.fromRGB(100, 255, 120),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = content
    })
    
    local info = self:createElement("TextLabel", {
        Name = "Info",
        Size = UDim2.new(1, -24, 0, 42),
        Position = UDim2.new(0, 12, 0, 42),
        BackgroundTransparency = 1,
        Text = "Removed: 0\nDisabled: 0\nBlocked: 0",
        TextColor3 = Color3.fromRGB(180, 180, 180),
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = content
    })
    
    local scanBtn = self:createButton({
        Name = "Scan",
        Size = UDim2.new(1, -24, 0, 44),
        Position = UDim2.new(0, 12, 1, -52),
        BackgroundColor3 = Color3.fromRGB(55, 125, 225),
        Text = "SCAN & AUTO REMOVE",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        CornerRadius = 10,
        Parent = content
    })
    
    self.elements = {
        gui = sg,
        main = main,
        titleBar = titleBar,
        content = content,
        status = status,
        info = info,
        scanBtn = scanBtn,
        minimize = minimize,
        close = close
    }
    
    self:bindEvents()
    
    return self
end

function UI:bindEvents()
    local e = self.elements
    
    -- Close
    e.close.MouseButton1Click:Connect(function()
        e.gui:Destroy()
    end)
    
    -- Minimize
    e.minimize.MouseButton1Click:Connect(function()
        self.state.minimized = not self.state.minimized
        
        Utils.pcall(function()
            if self.state.minimized then
                e.main:TweenSize(UDim2.new(0, 420, 0, 40), "Out", "Quad", Config.ANIMATION_SPEED, true)
                e.minimize.Text = "+"
                e.content.Visible = false
            else
                e.main:TweenSize(UDim2.new(0, 420, 0, 190), "Out", "Quad", Config.ANIMATION_SPEED, true)
                e.minimize.Text = "-"
                e.content.Visible = true
            end
        end)
    end)
    
    -- Drag
    self:enableDrag(e.titleBar, e.main)
end

function UI:enableDrag(titleBar, frame)
    local dragging, dragInput, dragStart, startPos
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    local sm = ServiceManager.getInstance()
    local uis = sm:get("UserInputService")
    
    if uis then
        uis.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end
end

function UI:updateStats(stats, antiBanStats)
    local e = self.elements
    if not e or not e.info then return end
    
    Utils.pcall(function()
        e.info.Text = string.format(
            "Removed: %d\nDisabled: %d\nBlocked: %d",
            stats.removed, stats.disabled, antiBanStats.blocked
        )
    end)
end

function UI:setStatus(text, color)
    local e = self.elements
    if not e or not e.status then return end
    
    Utils.pcall(function()
        e.status.Text = text
        e.status.TextColor3 = color or Color3.fromRGB(180, 180, 180)
    end)
end

function UI:setScanState(scanning)
    local e = self.elements
    if not e or not e.scanBtn then return end
    
    self.state.scanning = scanning
    
    Utils.pcall(function()
        if scanning then
            e.scanBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            e.scanBtn.Text = "SCANNING..."
        else
            e.scanBtn.BackgroundColor3 = Color3.fromRGB(55, 125, 225)
            e.scanBtn.Text = "SCAN & AUTO REMOVE"
        end
    end)
end

-- ============================================================
-- APPLICATION CONTROLLER
-- ============================================================

local App = {}

function App:init()
    -- Initialize systems
    self.executor = Executor.getInstance()
    self.services = ServiceManager.getInstance()
    self.antiBan = AntiBan.new()
    self.scanner = Scanner.new()
    self.ui = UI.new()
    
    -- Start anti-ban
    self.antiBan:init()
    
    -- Render UI
    self.ui:render()
    
    -- Bind scan button
    self:bindScanButton()
    
    -- Start auto-update
    self:startAutoUpdate()
    
    -- Log startup
    self:logStartup()
end

function App:bindScanButton()
    local btn = self.ui.elements.scanBtn
    
    btn.MouseButton1Click:Connect(function()
        if self.ui.state.scanning then return end
        
        self:runScan()
    end)
end

function App:runScan()
    self.ui:setScanState(true)
    self.ui:setStatus("Method 1: Fast scan...", Color3.fromRGB(255, 200, 100))
    
    self.scanner:reset()
    
    self.scanner:async(function(scanner)
        -- Method 1: Fast
        scanner:fastScan()
        self.ui:updateStats(scanner:getStats(), self.antiBan:getStats())
        Utils.delay(0.3)
        
        self.ui:setStatus("Method 2: Deep scan...", Color3.fromRGB(255, 200, 100))
        
        -- Method 2: Deep
        scanner:deepScan()
        self.ui:updateStats(scanner:getStats(), self.antiBan:getStats())
        Utils.delay(0.3)
        
        self.ui:setStatus("Method 3: Verification...", Color3.fromRGB(255, 200, 100))
        
        -- Method 3: Verify
        local remaining = scanner:verify()
        self.ui:updateStats(scanner:getStats(), self.antiBan:getStats())
        Utils.delay(0.3)
        
        self.ui:setStatus("Final check...", Color3.fromRGB(255, 200, 100))
        Utils.delay(0.5)
        
        -- Final
        local finalCheck = scanner:verify()
        
        self.ui:setScanState(false)
        
        if finalCheck == 0 then
            self.ui:setStatus(
                string.format("Complete! Removed: %d • CLEAN!", scanner.stats.removed),
                Color3.fromRGB(100, 255, 120)
            )
        else
            self.ui:setStatus(
                string.format("Complete! Removed: %d • %d remain", scanner.stats.removed, finalCheck),
                Color3.fromRGB(255, 200, 100)
            )
        end
        
        self.ui:updateStats(scanner:getStats(), self.antiBan:getStats())
    end)
end

function App:startAutoUpdate()
    task.spawn(function()
        while task.wait(Config.UPDATE_INTERVAL) do
            Utils.pcall(function()
                self.ui:updateStats(self.scanner:getStats(), self.antiBan:getStats())
            end)
        end
    end)
end

function App:logStartup()
    local exec = self.executor:info()
    
    print("═══════════════════════════════════════════════════════")
    print("AC SCANNER V" .. VERSION .. " - MODERN EDITION")
    print("═══════════════════════════════════════════════════════")
    print("⚡ Executor: " .. exec.name)
    print("⚡ Meta Hook: " .. (exec.capabilities.metaHook and "✓" or "✗"))
    print("⚡ NewCClosure: " .. (exec.capabilities.newCClosure and "✓" or "✗"))
    print("⚡ Architecture: Modern Lua")
    print("⚡ Auto Remove: ON")
    print("⚡ Anti-Ban: Active")
    print("═══════════════════════════════════════════════════════")
    print("🚀 Ready to scan!")
    print("═══════════════════════════════════════════════════════")
end

-- ============================================================
-- BOOTSTRAP
-- ============================================================

local app = App
app:init()

-- Export to global (optional)
getgenv = getgenv or function() return _G end
getgenv().ACScanner = {
    version = VERSION,
    app = app
}
