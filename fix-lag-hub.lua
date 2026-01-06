--[[ 
    Fix Lag Hub
    Optimized for ALL executors & games
    Minimal overhead | Client-side only
]]

if not game:IsLoaded() then game.Loaded:Wait() end

-- ================= CONFIG =================
local ENABLED = false

local CONFIG = {
    RemoveDecal = true,
    RemoveTexture = true,
    RemoveEffect = true,
    DisableShadow = true,
    LowMaterial = true,
}

-- ================= SERVICES =================
local WS = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local CHAR = LP.Character or LP.CharacterAdded:Wait()

-- ================= CORE OPT =================
local function optimize(obj)
    if obj:IsDescendantOf(CHAR) then return end

    if obj:IsA("BasePart") then
        if CONFIG.LowMaterial then
            obj.Material = Enum.Material.Plastic
            obj.Reflectance = 0
        end
        if CONFIG.DisableShadow and obj.CastShadow ~= nil then
            obj.CastShadow = false
        end

    elseif CONFIG.RemoveDecal and obj:IsA("Decal") then
        obj:Destroy()

    elseif CONFIG.RemoveTexture and obj:IsA("Texture") then
        obj:Destroy()

    elseif CONFIG.RemoveEffect and (
        obj:IsA("ParticleEmitter") or
        obj:IsA("Trail") or
        obj:IsA("Beam")
    ) then
        obj:Destroy()
    end
end

-- ================= APPLY ONCE =================
local function applyAll()
    -- Lighting (1 lần)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e9

    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("PostEffect") then
            e.Enabled = false
        end
    end

    -- Workspace (1 lần)
    for _, v in ipairs(WS:GetDescendants()) do
        optimize(v)
    end
end

-- ================= REALTIME CLEAN =================
local CLEAN_CONN
local function enableCleaner()
    if CLEAN_CONN then return end
    CLEAN_CONN = WS.DescendantAdded:Connect(function(obj)
        task.defer(optimize, obj)
    end)
end

local function disableCleaner()
    if CLEAN_CONN then
        CLEAN_CONN:Disconnect()
        CLEAN_CONN = nil
    end
end

-- ================= TOGGLE =================
local function toggle()
    ENABLED = not ENABLED
    if ENABLED then
        applyAll()
        enableCleaner()
    else
        disableCleaner()
    end
end

-- ================= GUI (1 BUTTON) =================
local parent =
    (gethui and gethui()) or
    (get_hidden_gui and get_hidden_gui()) or
    game.CoreGui

local gui = Instance.new("ScreenGui", parent)
gui.Name = "FixLagHub"

if syn and syn.protect_gui then
    syn.protect_gui(gui)
end

local btn = Instance.new("TextButton", gui)
btn.Size = UDim2.fromOffset(110, 36)
btn.Position = UDim2.fromOffset(20, 120)
btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btn.TextColor3 = Color3.new(1,1,1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 14
btn.Text = "FIX LAG : OFF"
btn.BorderSizePixel = 0
btn.Draggable = true
btn.Active = true

btn.MouseButton1Click:Connect(function()
    toggle()
    btn.Text = ENABLED and "FIX LAG : ON" or "FIX LAG : OFF"
    btn.BackgroundColor3 = ENABLED
        and Color3.fromRGB(0,140,80)
        or Color3.fromRGB(40,40,40)
end)

-- ================= HOTKEY =================
UIS.InputBegan:Connect(function(i, g)
    if not g and i.KeyCode == Enum.KeyCode.RightShift then
        btn:Activate()
    end
end)

print("✅Fix Lag Hub Loaded")
