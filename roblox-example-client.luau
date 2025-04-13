local ScreenGui = Instance.new("ScreenGui",game:GetService("CoreGui"))
local Frame = Instance.new("Frame", ScreenGui)

local scriptJson = game:HttpGet("https://scriptblox.com/api/script/search?q=admin") -- 20 most recent scripts that relate to "admin"

local scripts = game:GetService("HttpService"):JSONDecode(scriptJson)

for i, script in next, scripts.result.scripts do
    -- Example: create a TextLabel for each script
    local newTextLabel = Instance.new("TextLabel")
    newTextLabel.Text = "Title: " .. script.title .. "\nSlug: " .. script.slug
    newTextLabel.Size = UDim2.new(1, 0, 0, 50)
    newTextLabel.Parent = Frame  
end

