--// Universal Advanced Voxel Builder
--// PC + Mobile | Client-Side
--// Multi-Executor Compatible

local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

--========================
-- ANTI DUPLICATE
--========================

if getgenv and getgenv().__AVB_LOADED then
    -- Dọn instance cũ nếu có
    if getgenv().__AVB_STOP then
        getgenv().__AVB_STOP()
    end
end

if getgenv then
    getgenv().__AVB_LOADED = true
end

--========================
-- SETTINGS
--========================

local GRID         = 1
local DISTANCE     = 120
local PREVIEW_RATE = 1 / 30
local MAX_BLOCKS   = 250
local MIN_SIZE     = 1
local MAX_SIZE     = 20

--========================
-- STATE
--========================

local buildMode    = false
local stopped      = false
local lastPreview  = 0
local placedBlocks = {}
local selectedBlock
local resizeAxis   = "X"
local blockCount   = 0
local blockSize    = Vector3.new(GRID, GRID, GRID)

local renderConnection
local inputConnection

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

--========================
-- GUI PARENT (multi-executor)
-- Priority: gethui() > CoreGui > PlayerGui
--========================

local function getGuiParent()
    -- gethui() tersedia di: Synapse X, KRNL, Fluxus, Delta, Solara, Wave...
    if gethui then
        return gethui()
    end

    -- Cố CoreGui (thường hoạt động ở Synapse, Electron, Coco Z)
    local ok, CoreGui = pcall(game.GetService, game, "CoreGui")
    if ok and CoreGui then
        -- Kiểm tra quyền write
        local canWrite = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = CoreGui
            t:Destroy()
        end)
        if canWrite then return CoreGui end
    end

    -- Fallback PlayerGui (luôn hoạt động)
    return player:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

--========================
-- REMOVE OLD GUI
--========================

local old = guiParent:FindFirstChild("AdvancedVoxelBuilder")
if old then old:Destroy() end

-- Dọn cả PlayerGui phòng trường hợp executor cũ để lại
local pg = player:FindFirstChild("PlayerGui")
if pg then
    local oldPG = pg:FindFirstChild("AdvancedVoxelBuilder")
    if oldPG then oldPG:Destroy() end
end

--========================
-- GUI ROOT
--========================

local gui = Instance.new("ScreenGui")
gui.Name            = "AdvancedVoxelBuilder"
gui.IgnoreGuiInset  = true
gui.ResetOnSpawn    = false
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling

-- Tắt overlay trên CoreGui nếu có quyền
pcall(function() gui.DisplayOrder = 999 end)

gui.Parent = guiParent

--========================
-- HELPERS
--========================

local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 12)
    c.Parent = parent
    return c
end

local function makeButton(parent, size, pos, color, text, font)
    local b = Instance.new("TextButton")
    b.Size                = size
    b.Position            = pos
    b.BackgroundColor3    = color
    b.TextColor3          = Color3.new(1, 1, 1)
    b.Text                = text
    b.Font                = font or Enum.Font.GothamBold
    b.TextScaled          = true
    b.BorderSizePixel     = 0
    b.AutoButtonColor     = false
    b.Parent              = parent
    makeCorner(b, 12)
    return b
end

--========================
-- MAIN FRAME
--========================

local frame = Instance.new("Frame")
frame.Size             = UDim2.new(0, 260, 0, 220)
frame.Position         = UDim2.new(0, 20, 1, -250)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel  = 0
frame.Parent           = gui
makeCorner(frame, 14)

local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
titleBar.BorderSizePixel  = 0
titleBar.Parent           = frame
makeCorner(titleBar, 14)

local title = Instance.new("TextLabel")
title.Size               = UDim2.new(1, -40, 1, 0)
title.Position           = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text               = "ADVANCED VOXEL BUILDER"
title.Font               = Enum.Font.GothamBold
title.TextScaled         = true
title.TextColor3         = Color3.new(1, 1, 1)
title.TextXAlignment     = Enum.TextXAlignment.Left
title.Parent             = titleBar

local minimizeButton = makeButton(
    titleBar,
    UDim2.new(0, 25, 0, 25),
    UDim2.new(1, -30, 0, 5),
    Color3.fromRGB(60, 60, 60), "-"
)
minimizeButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)

local buildButton = makeButton(
    frame, UDim2.new(0.85, 0, 0, 50), UDim2.new(0.075, 0, 0, 50),
    Color3.fromRGB(40, 40, 40), "BUILD OFF"
)
local clearButton = makeButton(
    frame, UDim2.new(0.4, 0, 0, 45), UDim2.new(0.075, 0, 0, 115),
    Color3.fromRGB(170, 120, 0), "CLEAR"
)
local stopButton = makeButton(
    frame, UDim2.new(0.4, 0, 0, 45), UDim2.new(0.525, 0, 0, 115),
    Color3.fromRGB(170, 0, 0), "STOP"
)

local resizeHandle = Instance.new("Frame")
resizeHandle.Size             = UDim2.new(0, 20, 0, 20)
resizeHandle.Position         = UDim2.new(1, -20, 1, -20)
resizeHandle.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
resizeHandle.BorderSizePixel  = 0
resizeHandle.Parent           = frame
makeCorner(resizeHandle, 20)

--========================
-- RESIZE PANEL
--========================

local resizePanel = Instance.new("Frame")
resizePanel.Size             = UDim2.new(0, 220, 0, 140)
resizePanel.Position         = UDim2.new(1, -240, 1, -180)
resizePanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
resizePanel.BorderSizePixel  = 0
resizePanel.Visible          = false
resizePanel.Parent           = gui
makeCorner(resizePanel, 12)

local resizeTitle = Instance.new("TextLabel")
resizeTitle.Size                 = UDim2.new(1, 0, 0, 30)
resizeTitle.BackgroundTransparency = 1
resizeTitle.Text                 = "BLOCK RESIZE"
resizeTitle.Font                 = Enum.Font.GothamBold
resizeTitle.TextScaled           = true
resizeTitle.TextColor3           = Color3.new(1, 1, 1)
resizeTitle.Parent               = resizePanel

local AXES = {
    { label = "X", pos = UDim2.new(0.05, 0, 0, 40), color = Color3.fromRGB(170, 60, 60) },
    { label = "Y", pos = UDim2.new(0.36, 0, 0, 40), color = Color3.fromRGB(60, 170, 60) },
    { label = "Z", pos = UDim2.new(0.67, 0, 0, 40), color = Color3.fromRGB(60, 60, 170) },
}
for _, ax in ipairs(AXES) do
    local btn = makeButton(resizePanel, UDim2.new(0.28, 0, 0, 35), ax.pos, ax.color, ax.label)
    btn.MouseButton1Click:Connect(function() resizeAxis = ax.label end)
end

local plusButton = makeButton(
    resizePanel, UDim2.new(0.42, 0, 0, 45), UDim2.new(0.05, 0, 0, 85),
    Color3.fromRGB(0, 170, 120), "+", Enum.Font.GothamBlack
)
local minusButton = makeButton(
    resizePanel, UDim2.new(0.42, 0, 0, 45), UDim2.new(0.53, 0, 0, 85),
    Color3.fromRGB(170, 0, 0), "-", Enum.Font.GothamBlack
)

--========================
-- MOBILE BUTTONS
--========================

local mobilePlace, mobileRemove

if isMobile then
    mobilePlace = makeButton(
        gui, UDim2.new(0, 90, 0, 90), UDim2.new(1, -110, 1, -120),
        Color3.fromRGB(0, 170, 120), "+", Enum.Font.GothamBlack
    )
    mobilePlace:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)

    mobileRemove = makeButton(
        gui, UDim2.new(0, 70, 0, 70), UDim2.new(1, -200, 1, -110),
        Color3.fromRGB(170, 0, 0), "-", Enum.Font.GothamBlack
    )
    mobileRemove:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
end

--========================
-- DRAG & RESIZE UI
--========================

local dragging, resizing = false, false
local dragStart, startPos, resizeStart, startSize

titleBar.InputBegan:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = frame.Position
    end
end)

resizeHandle.InputBegan:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        resizing    = true
        resizeStart = input.Position
        startSize   = frame.Size
    end
end)

UIS.InputEnded:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        dragging = false
        resizing = false
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    elseif resizing then
        local d = input.Position - resizeStart
        frame.Size = UDim2.new(
            startSize.X.Scale, math.clamp(startSize.X.Offset + d.X, 220, 500),
            startSize.Y.Scale, math.clamp(startSize.Y.Offset + d.Y, 160, 400)
        )
    end
end)

--========================
-- MINIMIZE
--========================

local minimized = false
local savedSize = frame.Size

minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        savedSize = frame.Size
        frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 35)
        buildButton.Visible  = false
        clearButton.Visible  = false
        stopButton.Visible   = false
        resizeHandle.Visible = false
        minimizeButton.Text  = "+"
    else
        frame.Size = savedSize
        buildButton.Visible  = true
        clearButton.Visible  = true
        stopButton.Visible   = true
        resizeHandle.Visible = true
        minimizeButton.Text  = "-"
    end
end)

--========================
-- PREVIEW BLOCK
--========================

local preview = Instance.new("Part")
preview.Size         = blockSize
preview.Anchored     = true
preview.CanCollide   = false
preview.CanTouch     = false
preview.CanQuery     = false
preview.CastShadow   = false
preview.Material     = Enum.Material.Neon
preview.Color        = Color3.fromRGB(0, 170, 255)
preview.Transparency = 0.7
preview.Parent       = workspace

--========================
-- VOXEL COLORS
--========================

local voxelColors = {
    Color3.fromRGB(110, 110, 110),
    Color3.fromRGB(80,  170, 90),
    Color3.fromRGB(150, 110, 80),
    Color3.fromRGB(220, 220, 220),
}

--========================
-- FUNCTIONS
--========================

local function snap(n)
    return math.round(n / GRID) * GRID
end

local function updateUI()
    if buildMode then
        buildButton.Text             = "BUILD ON"
        buildButton.BackgroundColor3 = Color3.fromRGB(0, 170, 120)
    else
        buildButton.Text             = "BUILD OFF"
        buildButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    end
end

local function createBlock(pos)
    if stopped or blockCount >= MAX_BLOCKS then return end
    local block = Instance.new("Part")
    block.Size             = blockSize
    block.Anchored         = true
    block.CanCollide       = true
    block.CanTouch         = false
    block.CanQuery         = false
    block.CastShadow       = false
    block.Material         = Enum.Material.SmoothPlastic
    block.TopSurface       = Enum.SurfaceType.Smooth
    block.BottomSurface    = Enum.SurfaceType.Smooth
    block.Position         = pos
    block.Color            = voxelColors[math.random(1, #voxelColors)]
    block.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
    block.Parent           = workspace
    placedBlocks[block]    = true
    blockCount            += 1
end

local function resizeBlock(add)
    if not selectedBlock then return end
    local s = selectedBlock.Size
    if resizeAxis == "X" then
        selectedBlock.Size = Vector3.new(math.clamp(s.X + add, MIN_SIZE, MAX_SIZE), s.Y, s.Z)
    elseif resizeAxis == "Y" then
        selectedBlock.Size = Vector3.new(s.X, math.clamp(s.Y + add, MIN_SIZE, MAX_SIZE), s.Z)
    else
        selectedBlock.Size = Vector3.new(s.X, s.Y, math.clamp(s.Z + add, MIN_SIZE, MAX_SIZE))
    end
end

local function removeBlock()
    local target = mouse.Target
    if not (target and placedBlocks[target]) then return end
    if selectedBlock == target then
        selectedBlock       = nil
        resizePanel.Visible = false
    end
    placedBlocks[target] = nil
    target:Destroy()
    blockCount -= 1
end

local function clearBlocks()
    selectedBlock       = nil
    resizePanel.Visible = false
    for block in pairs(placedBlocks) do
        if block and block.Parent then block:Destroy() end
    end
    table.clear(placedBlocks)
    blockCount = 0
end

--========================
-- BUTTON CONNECTIONS
--========================

plusButton.MouseButton1Click:Connect(function()  resizeBlock( GRID) end)
minusButton.MouseButton1Click:Connect(function() resizeBlock(-GRID) end)

buildButton.MouseButton1Click:Connect(function()
    if stopped then return end
    buildMode = not buildMode
    updateUI()
end)

clearButton.MouseButton1Click:Connect(clearBlocks)

if isMobile then
    mobilePlace.MouseButton1Click:Connect(function()
        if buildMode then createBlock(preview.Position) end
    end)
    mobileRemove.MouseButton1Click:Connect(removeBlock)
end

updateUI()

--========================
-- RAYCAST PARAMS (1 lần duy nhất)
--========================

local rayParams = RaycastParams.new()
rayParams.FilterType                 = Enum.RaycastFilterType.Blacklist
rayParams.FilterDescendantsInstances = { preview }

--========================
-- PREVIEW LOOP
-- Dùng RenderStepped, fallback task.spawn nếu bị block
--========================

local function previewTick()
    if stopped or not buildMode then return end
    local now = tick()
    if now - lastPreview < PREVIEW_RATE then return end
    lastPreview = now

    local camera = workspace.CurrentCamera
    if not camera then return end

    local ray    = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * DISTANCE, rayParams)

    if result then
        local pos = result.Position + result.Normal * (GRID / 2)
        preview.Position = Vector3.new(snap(pos.X), snap(pos.Y), snap(pos.Z))
    end
end

local okRS, errRS = pcall(function()
    renderConnection = RunService.RenderStepped:Connect(previewTick)
end)

-- Fallback: executor yang memblokir RenderStepped (jarang, tapi ada)
if not okRS then
    renderConnection = RunService.Heartbeat:Connect(previewTick)
end

--========================
-- INPUT
--========================

inputConnection = UIS.InputBegan:Connect(function(input, gp)
    if stopped or gp or isMobile then return end
    local t = input.UserInputType

    if t == Enum.UserInputType.MouseButton1 then
        local target = mouse.Target
        if target and placedBlocks[target] then
            selectedBlock       = target
            resizePanel.Visible = true
        elseif buildMode then
            createBlock(preview.Position)
        end
    elseif t == Enum.UserInputType.MouseButton2 then
        removeBlock()
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        selectedBlock       = nil
        resizePanel.Visible = false
    end
end)

--========================
-- STOP / CLEANUP
--========================

local function stopSystem()
    if stopped then return end
    stopped = true

    if renderConnection then renderConnection:Disconnect() end
    if inputConnection  then inputConnection:Disconnect()  end

    clearBlocks()
    pcall(function() if preview then preview:Destroy() end end)
    pcall(function() if gui     then gui:Destroy()     end end)

    -- Xoá global flag
    if getgenv then
        getgenv().__AVB_LOADED = nil
        getgenv().__AVB_STOP   = nil
    end

    print("Advanced Voxel Builder stopped")
    pcall(function() script.Disabled = true end)
end

-- Đăng ký hàm stop vào global để anti-duplicate dùng
if getgenv then
    getgenv().__AVB_STOP = stopSystem
end

stopButton.MouseButton1Click:Connect(stopSystem)

print("Advanced Voxel Builder Loaded | Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
