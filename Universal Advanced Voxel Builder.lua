--// Universal Advanced Voxel Builder
--// PC + Mobile | Client-Side
--// Multi-Executor + 3-Axis Gizmo Ring

local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()
local camera

--========================
-- ANTI DUPLICATE
--========================

if getgenv and getgenv().__AVB_LOADED then
    if getgenv().__AVB_STOP then getgenv().__AVB_STOP() end
end
if getgenv then getgenv().__AVB_LOADED = true end

--========================
-- SETTINGS
--========================

local GRID         = 1
local DISTANCE     = 120
local PREVIEW_RATE = 1 / 30
local MAX_BLOCKS   = 250
local MIN_SIZE     = 1
local MAX_SIZE     = 20

local GIZMO_RADIUS    = 0.08   -- độ dày vòng tròn
local GIZMO_GAP       = 0.6    -- khoảng cách vòng ra khỏi mặt block
local GIZMO_SEGMENTS  = 24     -- số đoạn tạo vòng tròn

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

-- Gizmo state
local gizmoModel       = nil   -- Model chứa các vòng tròn
local draggingGizmo    = false
local gizmoDragAxis    = nil   -- "X" / "Y" / "Z"
local gizmoDragStart   = nil   -- Vector3 mouse world pos khi bắt đầu kéo
local gizmoDragOrigSize= nil   -- Size block trước khi kéo
local gizmoDragOrigPos = nil   -- Position block trước khi kéo

local AXIS_COLORS = {
    X = Color3.fromRGB(220, 60,  60),
    Y = Color3.fromRGB(60,  200, 80),
    Z = Color3.fromRGB(60,  100, 220),
}

--========================
-- GUI PARENT (multi-executor)
--========================

local function getGuiParent()
    if gethui then return gethui() end
    local ok, CoreGui = pcall(game.GetService, game, "CoreGui")
    if ok and CoreGui then
        local canWrite = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = CoreGui
            t:Destroy()
        end)
        if canWrite then return CoreGui end
    end
    return player:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

--========================
-- REMOVE OLD GUI
--========================

local old = guiParent:FindFirstChild("AdvancedVoxelBuilder")
if old then old:Destroy() end
local pg = player:FindFirstChild("PlayerGui")
if pg then
    local oldPG = pg:FindFirstChild("AdvancedVoxelBuilder")
    if oldPG then oldPG:Destroy() end
end

--========================
-- GUI ROOT
--========================

local gui = Instance.new("ScreenGui")
gui.Name           = "AdvancedVoxelBuilder"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
    b.Size             = size
    b.Position         = pos
    b.BackgroundColor3 = color
    b.TextColor3       = Color3.new(1, 1, 1)
    b.Text             = text
    b.Font             = font or Enum.Font.GothamBold
    b.TextScaled       = true
    b.BorderSizePixel  = 0
    b.AutoButtonColor  = false
    b.Parent           = parent
    makeCorner(b, 12)
    return b
end

--========================
-- MAIN FRAME
--========================

local frame = Instance.new("Frame")
frame.Size             = UDim2.new(0, 260, 0, 175)
frame.Position         = UDim2.new(0, 20, 1, -205)
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
    UDim2.new(0, 25, 0, 25), UDim2.new(1, -30, 0, 5),
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
-- HINT LABEL (hướng dẫn gizmo)
--========================

local hintLabel = Instance.new("TextLabel")
hintLabel.Size               = UDim2.new(0, 260, 0, 28)
hintLabel.Position           = UDim2.new(0, 20, 1, -38)
hintLabel.BackgroundColor3   = Color3.fromRGB(20, 20, 20)
hintLabel.BackgroundTransparency = 0.3
hintLabel.BorderSizePixel    = 0
hintLabel.Text               = "Chọn block → kéo vòng tròn để resize"
hintLabel.Font               = Enum.Font.Gotham
hintLabel.TextScaled         = true
hintLabel.TextColor3         = Color3.fromRGB(180, 180, 180)
hintLabel.Visible            = false
hintLabel.Parent             = gui
makeCorner(hintLabel, 8)

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
-- DRAG & RESIZE FRAME UI
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
            startSize.Y.Scale, math.clamp(startSize.Y.Offset + d.Y, 130, 400)
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

local voxelColors = {
    Color3.fromRGB(110, 110, 110),
    Color3.fromRGB(80,  170, 90),
    Color3.fromRGB(150, 110, 80),
    Color3.fromRGB(220, 220, 220),
}

--========================
-- GIZMO SYSTEM
-- Mỗi vòng tròn = nhiều Part hình trụ nhỏ tạo thành vòng
--========================

-- Tạo 1 segment (hình trụ nhỏ) của vòng tròn
local function makeSegment(color)
    local p = Instance.new("Part")
    p.Shape        = Enum.PartType.Cylinder
    p.Size         = Vector3.new(GIZMO_RADIUS, GIZMO_RADIUS * 2, GIZMO_RADIUS)
    p.Anchored     = true
    p.CanCollide   = false
    p.CanTouch     = false
    p.CanQuery     = true   -- cần raycast để detect click
    p.CastShadow   = false
    p.Material     = Enum.Material.Neon
    p.Color        = color
    p.Transparency = 0
    return p
end

-- Xoá gizmo cũ
local function destroyGizmo()
    if gizmoModel then
        gizmoModel:Destroy()
        gizmoModel = nil
    end
    hintLabel.Visible = false
end

-- Tạo gizmo 3 vòng tròn quanh block đã chọn
local function buildGizmo(block)
    destroyGizmo()
    if not block then return end

    local model = Instance.new("Model")
    model.Name = "_AVB_Gizmo"
    model.Parent = workspace
    gizmoModel = model

    local s = block.Size
    local center = block.Position

    -- Bán kính mỗi vòng = nửa kích thước cạnh + gap
    local radii = {
        X = math.max(s.Y, s.Z) / 2 + GIZMO_GAP,
        Y = math.max(s.X, s.Z) / 2 + GIZMO_GAP,
        Z = math.max(s.X, s.Y) / 2 + GIZMO_GAP,
    }

    -- Vòng X: nằm trên mặt phẳng YZ → xoay quanh Z
    -- Vòng Y: nằm trên mặt phẳng XZ → xoay quanh X
    -- Vòng Z: nằm trên mặt phẳng XY → xoay quanh Y
    local rings = {
        { axis = "X", radius = radii.X, normal = Vector3.new(1,0,0) },
        { axis = "Y", radius = radii.Y, normal = Vector3.new(0,1,0) },
        { axis = "Z", radius = radii.Z, normal = Vector3.new(0,0,1) },
    }

    for _, ring in ipairs(rings) do
        local color  = AXIS_COLORS[ring.axis]
        local r      = ring.radius
        local n      = ring.normal
        local folder = Instance.new("Folder")
        folder.Name  = "Ring_" .. ring.axis
        folder.Parent = model

        for i = 0, GIZMO_SEGMENTS - 1 do
            local angle  = (i / GIZMO_SEGMENTS) * math.pi * 2
            local angleM = ((i + 0.5) / GIZMO_SEGMENTS) * math.pi * 2

            local seg = makeSegment(color)
            seg.Name   = ring.axis  -- đánh dấu để nhận axis khi raycast
            seg.Parent = folder

            -- Vị trí điểm giữa segment trên vòng tròn
            local lp   -- local position offset
            local look -- hướng của segment (tiếp tuyến vòng tròn)

            if ring.axis == "X" then
                lp   = Vector3.new(0, r * math.sin(angleM), r * math.cos(angleM))
                look = Vector3.new(0, math.cos(angle + math.pi/2), -math.sin(angle + math.pi/2))
            elseif ring.axis == "Y" then
                lp   = Vector3.new(r * math.cos(angleM), 0, r * math.sin(angleM))
                look = Vector3.new(-math.sin(angle + math.pi/2), 0, math.cos(angle + math.pi/2))
            else -- Z
                lp   = Vector3.new(r * math.cos(angleM), r * math.sin(angleM), 0)
                look = Vector3.new(-math.sin(angle + math.pi/2), math.cos(angle + math.pi/2), 0)
            end

            -- Chiều dài segment = cung tròn giữa 2 điểm liên tiếp
            local arcLen = 2 * r * math.sin(math.pi / GIZMO_SEGMENTS)
            seg.Size = Vector3.new(arcLen, GIZMO_RADIUS, GIZMO_RADIUS)

            seg.CFrame = CFrame.lookAt(center + lp, center + lp + look)
                * CFrame.Angles(0, math.pi / 2, 0) -- cylinder dọc theo lookAt
        end
    end

    hintLabel.Visible = true
end

-- Cập nhật vị trí gizmo khi block thay đổi size/pos
local function updateGizmo()
    if not (gizmoModel and selectedBlock) then return end
    -- Tái tạo nhanh (nhẹ vì chỉ update khi kéo xong)
    buildGizmo(selectedBlock)
end

--========================
-- GIZMO DRAG (world-space)
-- Khi user kéo vòng tròn, tính delta mouse trên trục tương ứng
--========================

local function getMouseWorldPos(dist)
    camera = workspace.CurrentCamera
    if not camera then return nil end
    local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
    return ray.Origin + ray.Direction * (dist or 20)
end

-- Project vector onto axis
local function projectOnAxis(v, axis)
    if axis == "X" then return v.X
    elseif axis == "Y" then return v.Y
    else return v.Z end
end

--========================
-- BLOCK FUNCTIONS
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

local function deselectBlock()
    selectedBlock = nil
    destroyGizmo()
end

local function selectBlock(block)
    selectedBlock = block
    buildGizmo(block)
end

local function removeBlock()
    local target = mouse.Target
    if not (target and placedBlocks[target]) then return end
    if selectedBlock == target then deselectBlock() end
    placedBlocks[target] = nil
    target:Destroy()
    blockCount -= 1
end

local function clearBlocks()
    deselectBlock()
    for block in pairs(placedBlocks) do
        if block and block.Parent then block:Destroy() end
    end
    table.clear(placedBlocks)
    blockCount = 0
end

--========================
-- GIZMO SEGMENT DETECTION
-- Kiểm tra xem target có phải là segment vòng gizmo không
--========================

local function getGizmoAxis(target)
    if not (target and gizmoModel) then return nil end
    -- Segment được đặt tên = axis ("X"/"Y"/"Z") và parent là Folder trong gizmoModel
    if target.Name == "X" or target.Name == "Y" or target.Name == "Z" then
        if target:IsDescendantOf(gizmoModel) then
            return target.Name
        end
    end
    return nil
end

--========================
-- BUTTON CONNECTIONS
--========================

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
-- RAYCAST PARAMS
--========================

local rayParams = RaycastParams.new()
rayParams.FilterType                 = Enum.RaycastFilterType.Blacklist
rayParams.FilterDescendantsInstances = { preview }

--========================
-- INPUT
--========================

inputConnection = UIS.InputBegan:Connect(function(input, gp)
    if stopped or gp or isMobile then return end
    local t = input.UserInputType

    -- LEFT CLICK
    if t == Enum.UserInputType.MouseButton1 then
        local target = mouse.Target

        -- Kiểm tra click vào vòng gizmo trước
        local axis = getGizmoAxis(target)
        if axis and selectedBlock then
            draggingGizmo     = true
            gizmoDragAxis     = axis
            gizmoDragStart    = getMouseWorldPos(30)
            gizmoDragOrigSize = selectedBlock.Size
            gizmoDragOrigPos  = selectedBlock.Position
            return
        end

        -- Click vào block đã đặt → chọn
        if target and placedBlocks[target] then
            selectBlock(target)
            return
        end

        -- Click vào vùng trống → deselect + đặt block nếu build mode
        deselectBlock()
        if buildMode then
            createBlock(preview.Position)
        end

    -- RIGHT CLICK
    elseif t == Enum.UserInputType.MouseButton2 then
        removeBlock()
    end
end)

-- Khi thả chuột → kết thúc kéo gizmo, snap lại size
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if draggingGizmo and selectedBlock then
            -- Snap size về lưới GRID
            local s = selectedBlock.Size
            selectedBlock.Size = Vector3.new(
                math.clamp(snap(s.X), MIN_SIZE, MAX_SIZE),
                math.clamp(snap(s.Y), MIN_SIZE, MAX_SIZE),
                math.clamp(snap(s.Z), MIN_SIZE, MAX_SIZE)
            )
            updateGizmo()
        end
        draggingGizmo  = false
        gizmoDragAxis  = nil
        gizmoDragStart = nil
    end
end)

-- Deselect bằng Escape
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        deselectBlock()
    end
end)

--========================
-- PREVIEW + GIZMO DRAG LOOP
--========================

local function onRenderStep()
    if stopped then return end
    camera = workspace.CurrentCamera

    -- Kéo gizmo real-time
    if draggingGizmo and selectedBlock and gizmoDragStart then
        local curPos = getMouseWorldPos(30)
        if curPos then
            local delta = projectOnAxis(curPos - gizmoDragStart, gizmoDragAxis)
            -- Mỗi 2 studs chuột = 1 stud thay đổi size (tỉ lệ cảm giác tốt)
            local rawSize = projectOnAxis(gizmoDragOrigSize, gizmoDragAxis) + delta * 1.5
            local newSize = math.clamp(rawSize, MIN_SIZE, MAX_SIZE)

            if gizmoDragAxis == "X" then
                selectedBlock.Size = Vector3.new(newSize, gizmoDragOrigSize.Y, gizmoDragOrigSize.Z)
            elseif gizmoDragAxis == "Y" then
                selectedBlock.Size = Vector3.new(gizmoDragOrigSize.X, newSize, gizmoDragOrigSize.Z)
                -- Giữ đáy block cố định khi kéo Y
                selectedBlock.Position = gizmoDragOrigPos
                    + Vector3.new(0, (newSize - gizmoDragOrigSize.Y) / 2, 0)
            else
                selectedBlock.Size = Vector3.new(gizmoDragOrigSize.X, gizmoDragOrigSize.Y, newSize)
            end

            -- Cập nhật vòng gizmo liên tục khi kéo
            buildGizmo(selectedBlock)
        end
        return
    end

    -- Preview block
    if not buildMode then return end
    local now = tick()
    if now - lastPreview < PREVIEW_RATE then return end
    lastPreview = now

    if not camera then return end
    local ray    = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * DISTANCE, rayParams)
    if result then
        local pos = result.Position + result.Normal * (GRID / 2)
        preview.Position = Vector3.new(snap(pos.X), snap(pos.Y), snap(pos.Z))
    end
end

local okRS = pcall(function()
    renderConnection = RunService.RenderStepped:Connect(onRenderStep)
end)
if not okRS then
    renderConnection = RunService.Heartbeat:Connect(onRenderStep)
end

--========================
-- STOP / CLEANUP
--========================

local function stopSystem()
    if stopped then return end
    stopped = true

    if renderConnection then renderConnection:Disconnect() end
    if inputConnection  then inputConnection:Disconnect()  end

    destroyGizmo()
    clearBlocks()
    pcall(function() if preview then preview:Destroy() end end)
    pcall(function() if gui     then gui:Destroy()     end end)

    if getgenv then
        getgenv().__AVB_LOADED = nil
        getgenv().__AVB_STOP   = nil
    end

    print("Advanced Voxel Builder stopped")
    pcall(function() script.Disabled = true end)
end

if getgenv then getgenv().__AVB_STOP = stopSystem end
stopButton.MouseButton1Click:Connect(stopSystem)

print("Advanced Voxel Builder Loaded | " .. (identifyexecutor and identifyexecutor() or "Unknown Executor"))
