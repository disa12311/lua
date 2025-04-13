
local ScreenGui = Instance.new("ScreenGui",game:GetService("CoreGui"))
local Frame = Instance.new("Frame", ScreenGui)
local HttpService = game:GetService("HttpService")

local success, result = pcall(function()
    return HttpService:GetAsync("https://scriptblox.com/api/script/search?q=admin") -- 20 most recent scripts that relate to "admin"
end)

if success then
    local scripts = HttpService:JSONDecode(result)

    for i, script in next, scripts.result.scripts do
        -- Example: create a TextLabel for each script
        local newTextLabel = Instance.new("TextLabel")
        newTextLabel.Text = "Title: " .. script.title .. "\nSlug: " .. script.slug
        newTextLabel.Size = UDim2.new(1, 0, 0, 50)
        newTextLabel.Parent = Frame
    end
else
    warn("Failed to fetch scripts: " .. result)
end
