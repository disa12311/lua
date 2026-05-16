--// Universal Advanced Voxel Builder
--// PC + Mobile | Client-Side
--// Multi-Executor + 3-Axis Gizmo + Highlight + Fixed Drag

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

local GRID           = 1
local DISTANCE       = 120
local PREVIEW_RATE   = 1 / 30
local MAX_BLOCKS     = 250
local MIN_SIZE       = 1
local MAX_SIZE       = 20
local GIZMO_RADIUS   = 0.09
local GIZMO_GAP      = 0.7
local GIZMO_SEGMENTS = 28

--========================
-- STATE
--========================

local buildMode    = false
local stopped      = false
local lastPreview  = 0
local placedBlocks = {}
local selectedBlock
local blockCount   = 0
local blockSize    = Vector3.new(GRID, GRID, GRID)

local renderConnection
local inputConnection

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- Gizmo
local gizmoModel       = nil
local draggingGizmo    = false
local gizmoDragAxis    = nil
local gizmoDragPlaneOrigin = nil  -- điểm gốc plane
local gizmoDragPlaneNormal = nil  -- normal của plane chiếu
local gizmoDragOrigSize    = nil
local gizmoDragOrigPos     = nil
local gizmoDragOffset      = 0    -- offset để drag mượt (không giật về 0)

-- Highlight
local selectionBox     = nil
local dragHighlight    = nil  -- highlight màu trục đang kéo

local AXIS_COLORS = {
    X = Color3.fromRGB(220, 60,  60),
    Y = Color3.fromRGB(60,  200, 80),
    Z = Color3.fromRGB(60,  100, 220),
}

--========================
-- GUI PARENT
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

local old = guiParent:FindFirstChild("AdvancedVoxelBuilder")
if old then old:Destroy() end
local pg = player:FindFirstChild("PlayerGui")
if pg then
    local o = pg:FindFirstChild("AdvancedVoxelBuilder")
    if o then o:Destroy() end
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

local titleLabel = Instance.new("TextLabel")
titleLabel.Size               = UDim2.new(1, -40, 1, 0)
titleLabel.Position           = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text               = "ADVANCED VOXEL BUILDER"
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.TextScaled         = true
titleLabel.TextColor3         = Color3.new(1, 1, 1)
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent             = titleBar

local minimizeButton = makeButton(
    titleBar, UDim2.new(0,25,0,25), UDim2.new(1,-30,0,5),
    Color3.fromRGB(60,60,60), "-"
)
minimizeButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1,0)

local buildButton = makeButton(frame, UDim2.new(0.85,0,0,50), UDim2.new(0.075,0,0,50),  Color3.fromRGB(40,40,40),    "BUILD OFF")
local clearButton = makeButton(frame, UDim2.new(0.4,0,0,45),  UDim2.new(0.075,0,0,115), Color3.fromRGB(170,120,0),   "CLEAR")
local stopButton  = makeButton(frame, UDim2.new(0.4,0,0,45),  UDim2.new(0.525,0,0,115), Color3.fromRGB(170,0,0),     "STOP")

local resizeHandle = Instance.new("Frame")
resizeHandle.Size             = UDim2.new(0,20,0,20)
resizeHandle.Position         = UDim2.new(1,-20,1,-20)
resizeHandle.BackgroundColor3 = Color3.fromRGB(90,90,90)
resizeHandle.BorderSizePixel  = 0
resizeHandle.Parent           = frame
makeCorner(resizeHandle, 20)

-- Hint
local hintLabel = Instance.new("TextLabel")
hintLabel.Size                   = UDim2.new(0,260,0,28)
hintLabel.Position               = UDim2.new(0,20,1,-38)
hintLabel.BackgroundColor3       = Color3.fromRGB(20,20,20)
hintLabel.BackgroundTransparency = 0.3
hintLabel.BorderSizePixel        = 0
hintLabel.Text                   = "Chọn block → kéo vòng tròn để resize"
hintLabel.Font                   = Enum.Font.Gotham
hintLabel.TextScaled             = true
hintLabel.TextColor3             = Color3.fromRGB(180,180,180)
hintLabel.Visible                = false
hintLabel.Parent                 = gui
makeCorner(hintLabel, 8)

-- Mobile
local mobilePlace, mobileRemove
if isMobile then
    mobilePlace = makeButton(gui, UDim2.new(0,90,0,90), UDim2.new(1,-110,1,-120), Color3.fromRGB(0,170,120), "+", Enum.Font.GothamBlack)
    mobilePlace:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1,0)
    mobileRemove = makeButton(gui, UDim2.new(0,70,0,70), UDim2.new(1,-200,1,-110), Color3.fromRGB(170,0,0), "-", Enum.Font.GothamBlack)
    mobileRemove:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1,0)
end

--========================
-- DRAG FRAME UI
--========================

local dragging, resizingFrame = false, false
local dragStart, startPos, resizeStart, startSize

titleBar.InputBegan:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = frame.Position
    end
end)
resizeHandle.InputBegan:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        resizingFrame = true; resizeStart = input.Position; startSize = frame.Size
    end
end)
UIS.InputEnded:Connect(function(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        dragging = false; resizingFrame = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    elseif resizingFrame then
        local d = input.Position - resizeStart
        frame.Size = UDim2.new(startSize.X.Scale, math.clamp(startSize.X.Offset+d.X,220,500), startSize.Y.Scale, math.clamp(startSize.Y.Offset+d.Y,130,400))
    end
end)

-- Minimize
local minimized = false
local savedSize = frame.Size
minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        savedSize = frame.Size
        frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 35)
        buildButton.Visible = false; clearButton.Visible = false
        stopButton.Visible  = false; resizeHandle.Visible = false
        minimizeButton.Text = "+"
    else
        frame.Size = savedSize
        buildButton.Visible = true; clearButton.Visible = true
        stopButton.Visible  = true; resizeHandle.Visible = true
        minimizeButton.Text = "-"
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
preview.Color        = Color3.fromRGB(0,170,255)
preview.Transparency = 0.7
preview.Parent       = workspace

local voxelColors = {
    Color3.fromRGB(110,110,110),
    Color3.fromRGB(80,170,90),
    Color3.fromRGB(150,110,80),
    Color3.fromRGB(220,220,220),
}

--========================
-- HIGHLIGHT SYSTEM
--========================

-- SelectionBox bám theo block đang chọn
local function createSelectionBox(adornee, color, lineThick)
    local sb = Instance.new("SelectionBox")
    sb.Color3          = color or Color3.fromRGB(255,255,255)
    sb.LineThickness   = lineThick or 0.05
    sb.SurfaceColor3   = color or Color3.fromRGB(255,255,255)
    sb.SurfaceTransparency = 0.85
    sb.Adornee         = adornee
    sb.Parent          = workspace
    return sb
end

local function showSelectionHighlight(block)
    if selectionBox then selectionBox:Destroy() end
    if dragHighlight then dragHighlight:Destroy(); dragHighlight = nil end
    if not block then selectionBox = nil; return end
    selectionBox = createSelectionBox(block, Color3.fromRGB(255,255,255), 0.05)
end

local function showDragHighlight(block, axis)
    if dragHighlight then dragHighlight:Destroy() end
    if not block then dragHighlight = nil; return end
    dragHighlight = createSelectionBox(block, AXIS_COLORS[axis], 0.07)
    dragHighlight.SurfaceTransparency = 0.7
    -- Tắt selectionBox trắng khi đang kéo để không chồng
    if selectionBox then selectionBox.Transparency = 1 end
end

local function hideDragHighlight()
    if dragHighlight then dragHighlight:Destroy(); dragHighlight = nil end
    -- Bật lại selectionBox
    if selectionBox then selectionBox.Transparency = 0 end
end

--========================
-- GIZMO SYSTEM
--========================

local function makeSegment(color, axis)
    local p = Instance.new("Part")
    p.Shape        = Enum.PartType.Cylinder
    p.Anchored     = true
    p.CanCollide   = false
    p.CanTouch     = false
    p.CanQuery     = true
    p.CastShadow   = false
    p.Material     = Enum.Material.Neon
    p.Color        = color
    p.Transparency = 0
    p.Name         = axis
    return p
end

local function destroyGizmo()
    if gizmoModel then gizmoModel:Destroy(); gizmoModel = nil end
    hintLabel.Visible = false
end

local function buildGizmo(block)
    destroyGizmo()
    if not block then return end

    local model = Instance.new("Model")
    model.Name   = "_AVB_Gizmo"
    model.Parent = workspace
    gizmoModel   = model

    local s      = block.Size
    local center = block.Position

    local rings = {
        { axis="X", radius = math.max(s.Y,s.Z)/2 + GIZMO_GAP },
        { axis="Y", radius = math.max(s.X,s.Z)/2 + GIZMO_GAP },
        { axis="Z", radius = math.max(s.X,s.Y)/2 + GIZMO_GAP },
    }

    for _, ring in ipairs(rings) do
        local color  = AXIS_COLORS[ring.axis]
        local r      = ring.radius
        local folder = Instance.new("Folder")
        folder.Name  = "Ring_" .. ring.axis
        folder.Parent = model

        local arcLen = 2 * r * math.sin(math.pi / GIZMO_SEGMENTS)

        for i = 0, GIZMO_SEGMENTS - 1 do
            local angleM = ((i + 0.5) / GIZMO_SEGMENTS) * math.pi * 2
            local angle  = (i / GIZMO_SEGMENTS) * math.pi * 2

            local seg  = makeSegment(color, ring.axis)
            seg.Size   = Vector3.new(arcLen, GIZMO_RADIUS, GIZMO_RADIUS)
            seg.Parent = folder

            local lp, look
            if ring.axis == "X" then
                lp   = Vector3.new(0, r*math.sin(angleM), r*math.cos(angleM))
                look = Vector3.new(0, math.cos(angle + math.pi/2), -math.sin(angle + math.pi/2))
            elseif ring.axis == "Y" then
                lp   = Vector3.new(r*math.cos(angleM), 0, r*math.sin(angleM))
                look = Vector3.new(-math.sin(angle + math.pi/2), 0, math.cos(angle + math.pi/2))
            else
                lp   = Vector3.new(r*math.cos(angleM), r*math.sin(angleM), 0)
                look = Vector3.new(-math.sin(angle + math.pi/2), math.cos(angle + math.pi/2), 0)
            end

            seg.CFrame = CFrame.lookAt(center + lp, center + lp + look)
                       * CFrame.Angles(0, math.pi/2, 0)
        end
    end

    hintLabel.Visible = true
end

--========================
-- PLANE-BASED DRAG (fixed)
-- Chiếu ray lên mặt phẳng vuông góc với trục,
-- đi qua tâm block → delta chính xác dù camera ở đâu
--========================

-- Giao điểm ray với plane (plane defined by point + normal)
local function rayPlaneIntersect(rayOrigin, rayDir, planeOrigin, planeNormal)
    local denom = rayDir:Dot(planeNormal)
    if math.abs(denom) < 1e-6 then return nil end
    local t = (planeOrigin - rayOrigin):Dot(planeNormal) / denom
    if t < 0 then return nil end
    return rayOrigin + rayDir * t
end

local function getMouseRay()
    camera = workspace.CurrentCamera
    if not camera then return nil, nil end
    local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
    return ray.Origin, ray.Direction
end

-- Lấy điểm trên plane tương ứng vị trí chuột
local function getMouseOnPlane()
    local origin, dir = getMouseRay()
    if not origin then return nil end
    return rayPlaneIntersect(origin, dir, gizmoDragPlaneOrigin, gizmoDragPlaneNormal)
end

-- Chọn normal tốt nhất cho plane của trục:
-- Trục X → plane YZ hay XY tùy camera nhìn từ đâu
-- Nguyên tắc: dùng plane mà normal có dot với camera direction lớn nhất
local function choosePlaneNormal(axis, blockPos)
    camera = workspace.CurrentCamera
    local camDir = (blockPos - camera.CFrame.Position).Unit

    local candidates = {
        X = { Vector3.new(0,1,0), Vector3.new(0,0,1) },
        Y = { Vector3.new(1,0,0), Vector3.new(0,0,1) },
        Z = { Vector3.new(1,0,0), Vector3.new(0,1,0) },
    }

    local best, bestDot = candidates[axis][1], 0
    for _, n in ipairs(candidates[axis]) do
        local d = math.abs(camDir:Dot(n))
        if d > bestDot then bestDot = d; best = n end
    end
    return best
end

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
        buildButton.BackgroundColor3 = Color3.fromRGB(0,170,120)
    else
        buildButton.Text             = "BUILD OFF"
        buildButton.BackgroundColor3 = Color3.fromRGB(40,40,40)
    end
end

local function createBlock(pos)
    if stopped or blockCount >= MAX_BLOCKS then return end
    local block = Instance.new("Part")
    block.Size         = blockSize
    block.Anchored     = true
    block.CanCollide   = true
    block.CanTouch     = false
    block.CanQuery     = false
    block.CastShadow   = false
    block.Material     = Enum.Material.SmoothPlastic
    block.TopSurface   = Enum.SurfaceType.Smooth
    block.BottomSurface= Enum.SurfaceType.Smooth
    block.Position     = pos
    block.Color        = voxelColors[math.random(1,#voxelColors)]
    block.CustomPhysicalProperties = PhysicalProperties.new(0.7,0.3,0.5)
    block.Parent       = workspace
    placedBlocks[block]= true
    blockCount        += 1
end

local function deselectBlock()
    showSelectionHighlight(nil)
    destroyGizmo()
    selectedBlock = nil
end

local function selectBlock(block)
    selectedBlock = block
    showSelectionHighlight(block)
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

local function getGizmoAxis(target)
    if not (target and gizmoModel) then return nil end
    if (target.Name=="X" or target.Name=="Y" or target.Name=="Z")
    and target:IsDescendantOf(gizmoModel) then
        return target.Name
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

    if t == Enum.UserInputType.MouseButton1 then
        local target = mouse.Target

        -- Click vòng gizmo → bắt đầu kéo
        local axis = getGizmoAxis(target)
        if axis and selectedBlock then
            -- Tính plane tốt nhất cho trục này
            local planeNormal = choosePlaneNormal(axis, selectedBlock.Position)
            local startPoint  = getMouseOnPlane()  -- cần set trước
            -- Set plane
            gizmoDragPlaneOrigin = selectedBlock.Position
            gizmoDragPlaneNormal = planeNormal
            startPoint           = getMouseOnPlane()

            if startPoint then
                draggingGizmo     = true
                gizmoDragAxis     = axis
                gizmoDragOrigSize = selectedBlock.Size
                gizmoDragOrigPos  = selectedBlock.Position
                -- Offset = giá trị trục tại điểm click - giá trị trục của tâm block
                -- Để kéo không giật về 0
                gizmoDragOffset   = projectOnAxis(startPoint, axis)
                                  - projectOnAxis(selectedBlock.Position, axis)
                showDragHighlight(selectedBlock, axis)
            end
            return
        end

        -- Click block đã đặt
        if target and placedBlocks[target] then
            selectBlock(target)
            return
        end

        -- Click vùng trống
        deselectBlock()
        if buildMode then createBlock(preview.Position) end

    elseif t == Enum.UserInputType.MouseButton2 then
        removeBlock()
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if draggingGizmo and selectedBlock then
        -- Snap size cuối
        local s = selectedBlock.Size
        selectedBlock.Size = Vector3.new(
            math.clamp(snap(s.X), MIN_SIZE, MAX_SIZE),
            math.clamp(snap(s.Y), MIN_SIZE, MAX_SIZE),
            math.clamp(snap(s.Z), MIN_SIZE, MAX_SIZE)
        )
        buildGizmo(selectedBlock)
        showSelectionHighlight(selectedBlock)
    end
    draggingGizmo = false
    gizmoDragAxis = nil
    hideDragHighlight()
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape then deselectBlock() end
end)

--========================
-- RENDER LOOP
--========================

local function onRenderStep()
    if stopped then return end
    camera = workspace.CurrentCamera

    -- Gizmo drag
    if draggingGizmo and selectedBlock and gizmoDragAxis then
        local pt = getMouseOnPlane()
        if pt then
            -- Delta = vị trí chuột trên trục - vị trí gốc block - offset click
            local mouseVal = projectOnAxis(pt, gizmoDragAxis)
            local blockOriginVal = projectOnAxis(gizmoDragOrigPos, gizmoDragAxis)
            local delta = mouseVal - blockOriginVal - gizmoDragOffset

            -- Tính size mới từ gốc (không cộng dồn)
            local origVal = projectOnAxis(gizmoDragOrigSize, gizmoDragAxis)
            local newSize = math.clamp(origVal + delta * 2, MIN_SIZE, MAX_SIZE)

            local s = gizmoDragOrigSize
            if gizmoDragAxis == "X" then
                selectedBlock.Size = Vector3.new(newSize, s.Y, s.Z)
            elseif gizmoDragAxis == "Y" then
                selectedBlock.Size = Vector3.new(s.X, newSize, s.Z)
                -- Giữ đáy cố định
                selectedBlock.Position = gizmoDragOrigPos
                    + Vector3.new(0, (newSize - s.Y)/2, 0)
            else
                selectedBlock.Size = Vector3.new(s.X, s.Y, newSize)
            end

            buildGizmo(selectedBlock)
            -- Cập nhật highlight drag theo size mới
            if dragHighlight then
                dragHighlight.Adornee = selectedBlock
            end
        end
        return
    end

    -- Preview
    if not buildMode then return end
    local now = tick()
    if now - lastPreview < PREVIEW_RATE then return end
    lastPreview = now
    if not camera then return end

    local ray    = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * DISTANCE, rayParams)
    if result then
        local pos = result.Position + result.Normal * (GRID/2)
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
-- STOP
--========================

local function stopSystem()
    if stopped then return end
    stopped = true
    if renderConnection then renderConnection:Disconnect() end
    if inputConnection  then inputConnection:Disconnect()  end
    hideDragHighlight()
    deselectBlock()
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
