-- ================================================================
--   SCRIPT FLING + ANTI-FLING (UNIVERSAL - TƯƠNG THÍCH NHIỀU EXECUTOR)
-- ================================================================

-- ===== KIỂM TRA MÔI TRƯỜNG =====
-- Một số executor dùng game, một số dùng shared, một số dùng getrenv()
local function callIfAvailable(fn)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, result = pcall(fn)
    if ok then
        return result
    end

    return nil
end

local env = callIfAvailable(getrenv) or callIfAvailable(getfenv) or _G
local gameService = env.game or rawget(_G, "game") or game
assert(gameService, "Không tìm thấy biến game trong môi trường hiện tại")

local function cloneReference(instance)
    if type(cloneref) == "function" then
        local ok, cloned = pcall(cloneref, instance)
        if ok and cloned then
            return cloned
        end
    end

    return instance
end

local function safeGetService(serviceName)
    local ok, service = pcall(function()
        return cloneReference(gameService:GetService(serviceName))
    end)

    if ok then
        return service
    end

    return nil
end

local Players = assert(safeGetService("Players"), "Không tìm thấy Players service")
local RunService = assert(safeGetService("RunService"), "Không tìm thấy RunService service")
local UserInputService = assert(safeGetService("UserInputService"), "Không tìm thấy UserInputService service")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ===== BIẾN TRẠNG THÁI =====
local flingEnabled = false
local antiFlingEnabled = false
local connections = {}

local function trackConnection(connection)
    if not connection then
        return nil
    end

    table.insert(connections, connection)
    return connection
end

local function setPartVelocity(part, velocity)
    local ok = pcall(function()
        part.AssemblyLinearVelocity = velocity
    end)

    if ok then
        return true
    end

    ok = pcall(function()
        part.Velocity = velocity
    end)

    return ok
end

local function getPartVelocity(part)
    local ok, velocity = pcall(function()
        return part.AssemblyLinearVelocity
    end)

    if ok and velocity then
        return velocity
    end

    ok, velocity = pcall(function()
        return part.Velocity
    end)

    if ok and velocity then
        return velocity
    end

    return Vector3.new(0, 0, 0)
end

local function setPartAngularVelocity(part, velocity)
    local ok = pcall(function()
        part.AssemblyAngularVelocity = velocity
    end)

    if ok then
        return true
    end

    return pcall(function()
        part.RotVelocity = velocity
    end)
end

local function getRootPart(char)
    if not char then
        return nil
    end

    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char.PrimaryPart
        or char:FindFirstChildWhichIsA("BasePart")
end

local function getHumanoid(char)
    if not char then
        return nil
    end

    return char:FindFirstChildOfClass("Humanoid") or char:FindFirstChild("Humanoid")
end

-- ===== CẬP NHẬT NHÂN VẬT (hỗ trợ respawn) =====
local character = player.Character
local rootPart = getRootPart(character)
local humanoid = getHumanoid(character)

local function updateCharacter()
    character = player.Character
    if character then
        rootPart = getRootPart(character)
        humanoid = getHumanoid(character)
    else
        rootPart = nil
        humanoid = nil
    end
end

trackConnection(player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    rootPart = nil
    humanoid = nil

    rootPart = newCharacter:WaitForChild("HumanoidRootPart", 5) or getRootPart(newCharacter)
    humanoid = newCharacter:WaitForChild("Humanoid", 5) or getHumanoid(newCharacter)
end))
updateCharacter()

-- ================================================================
--                TẠO GIAO DIỆN GUI (Dragable)
-- ================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlingControlGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Một số executor yêu cầu Parent khác nhau
local function getGuiParent()
    local hiddenGui = callIfAvailable(gethui)
    if hiddenGui then
        return hiddenGui
    end

    local playerGui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 5)
    if playerGui then
        return playerGui
    end

    return safeGetService("CoreGui") or safeGetService("StarterGui")
end

local guiParent = getGuiParent()
local oldGui = guiParent and guiParent:FindFirstChild(screenGui.Name)
if oldGui then
    oldGui:Destroy()
end

if type(syn) == "table" and type(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, screenGui)
elseif type(protectgui) == "function" then
    pcall(protectgui, screenGui)
end

screenGui.Parent = guiParent

-- === Khung chính ===
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 180)
frame.Position = UDim2.new(0.5, -130, 0.5, -90)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = false
frame.Parent = screenGui

local dragging = false
local dragStart = nil
local startPosition = nil

local function updateDrag(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end

trackConnection(frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = frame.Position

        trackConnection(input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end))
    end
end))

trackConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateDrag(input)
    end
end))

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

-- === Tiêu đề ===
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.Position = UDim2.new(0, 0, 0, 0)
title.Text = "⚡ Fling Control ⚡"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = frame

-- === Dòng phụ ===
local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, 0, 0, 20)
sub.Position = UDim2.new(0, 0, 0, 32)
sub.Text = "Nhấn nút để kích hoạt chức năng"
sub.TextColor3 = Color3.fromRGB(180, 180, 200)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.Parent = frame

-- === Nút FLING (bật/tắt chế độ fling) ===
local flingBtn = Instance.new("TextButton")
flingBtn.Size = UDim2.new(0.85, 0, 0, 38)
flingBtn.Position = UDim2.new(0.075, 0, 0.38, 0)
flingBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
flingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
flingBtn.Text = "🔴 FLING: OFF"
flingBtn.Font = Enum.Font.GothamBold
flingBtn.TextSize = 14
flingBtn.Parent = frame

local btnCorner1 = Instance.new("UICorner")
btnCorner1.CornerRadius = UDim.new(0, 6)
btnCorner1.Parent = flingBtn

-- === Nút FLING NOW (thực thi fling ngay) ===
local flingNowBtn = Instance.new("TextButton")
flingNowBtn.Size = UDim2.new(0.85, 0, 0, 30)
flingNowBtn.Position = UDim2.new(0.075, 0, 0.58, 0)
flingNowBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
flingNowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
flingNowBtn.Text = "🚀 FLING NGAY!"
flingNowBtn.Font = Enum.Font.GothamBold
flingNowBtn.TextSize = 13
flingNowBtn.Parent = frame

local btnCorner1b = Instance.new("UICorner")
btnCorner1b.CornerRadius = UDim.new(0, 6)
btnCorner1b.Parent = flingNowBtn

-- === Nút ANTI-FLING ===
local antiBtn = Instance.new("TextButton")
antiBtn.Size = UDim2.new(0.85, 0, 0, 38)
antiBtn.Position = UDim2.new(0.075, 0, 0.72, 0)
antiBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 255)
antiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
antiBtn.Text = "🔵 ANTI-FLING: OFF"
antiBtn.Font = Enum.Font.GothamBold
antiBtn.TextSize = 14
antiBtn.Parent = frame

local btnCorner2 = Instance.new("UICorner")
btnCorner2.CornerRadius = UDim.new(0, 6)
btnCorner2.Parent = antiBtn

-- ================================================================
--         HÀM FLING - ĐẨY TẤT CẢ NGƯỜI CHƠI KHÁC
-- ================================================================
local function doFling()
    if not character or not rootPart then
        updateCharacter()
        if not rootPart then
            print("⚠️ Không tìm thấy RootPart!")
            return
        end
    end

    -- Lấy hướng nhìn, cộng thêm lực bật lên
    local look = rootPart.CFrame.LookVector
    -- Kiểm tra nếu LookVector bị lỗi (trong một số game)
    if look.Magnitude == 0 then
        look = Vector3.new(0, 0, 1)
    end
    
    local direction = look * 150 + Vector3.new(0, 80, 0)

    local count = 0
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherChar = otherPlayer.Character
            if otherChar then
                local otherRoot = getRootPart(otherChar)
                if otherRoot then
                    -- Dùng helper an toàn để tránh lỗi crash executor
                    if setPartVelocity(otherRoot, direction) then
                        count = count + 1
                    end
                end
            end
        end
    end
    
    print("✅ Đã fling " .. count .. " người chơi!")
end

-- ================================================================
--               SỰ KIỆN NÚT BẤM
-- ================================================================

-- Bật/tắt chế độ fling (khi bật, nhấn F để fling)
trackConnection(flingBtn.MouseButton1Click:Connect(function()
    flingEnabled = not flingEnabled
    if flingEnabled then
        flingBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        flingBtn.Text = "🟢 FLING: ON (Nhấn F)"
    else
        flingBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
        flingBtn.Text = "🔴 FLING: OFF"
    end
end))

-- Nút Fling ngay (không cần bật chế độ)
trackConnection(flingNowBtn.MouseButton1Click:Connect(function()
    doFling()
end))

-- Bật/tắt Anti-Fling
trackConnection(antiBtn.MouseButton1Click:Connect(function()
    antiFlingEnabled = not antiFlingEnabled
    if antiFlingEnabled then
        antiBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        antiBtn.Text = "🟢 ANTI-FLING: ON"
    else
        antiBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 255)
        antiBtn.Text = "🔵 ANTI-FLING: OFF"
    end
end))

-- ================================================================
--               PHÍM TẮT F (chỉ khi bật chế độ Fling)
-- ================================================================
trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F and flingEnabled then
        doFling()
    end
end))

-- ================================================================
--               ANTI-FLING - CHỐNG BỊ FLING
-- ================================================================
trackConnection(RunService.Heartbeat:Connect(function()
    if not antiFlingEnabled then return end
    if not character or not rootPart or not humanoid then
        updateCharacter()
        return
    end

    local rootOk, rootParent = pcall(function()
        return rootPart.Parent
    end)
    if not rootOk or not rootParent then
        updateCharacter()
        return
    end

    local healthOk, health = pcall(function()
        return humanoid.Health
    end)
    if not healthOk or health <= 0 then
        updateCharacter()
        return
    end

    local vel = getPartVelocity(rootPart)
    local magnitudeOk, magnitude = pcall(function()
        return vel.Magnitude
    end)
    if not magnitudeOk then return end

    -- Ngưỡng 80: cho phép di chuyển bình thường
    if magnitude > 80 then
        setPartVelocity(rootPart, Vector3.new(0, 0, 0))
        setPartAngularVelocity(rootPart, Vector3.new(0, 0, 0))
    end
end))

-- ================================================================
--          XỬ LÝ KHI EXECUTOR BỊ NGẮT KẾT NỐI
-- ================================================================
-- Một số executor có sự kiện ngắt, một số không
local cleanedUp = false
local function cleanup(destroyGui)
    if cleanedUp then return end
    cleanedUp = true

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    for index in ipairs(connections) do
        connections[index] = nil
    end

    if destroyGui and screenGui then
        screenGui:Destroy()
    end
end

local destroySignalConnected = pcall(function()
    screenGui.Destroying:Connect(function()
        cleanup(false)
    end)
end)

if not destroySignalConnected then
    trackConnection(screenGui.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            cleanup(false)
        end
    end))
end

-- ================================================================
--               THÔNG BÁO KHỞI TẠO
-- ================================================================
print("=" .. string.rep("=", 50))
print("✅ FLING + ANTI-FLING UNIVERSAL SCRIPT ĐÃ TẢI!")
print("📌 Hướng dẫn sử dụng:")
print("   🟢 Bật FLING -> nhấn phím F để đẩy người khác")
print("   🚀 Nhấn 'FLING NGAY!' để fling tức thì")
print("   🔵 Bật ANTI-FLING để tự bảo vệ khỏi bị fling")
print("=" .. string.rep("=", 50))
