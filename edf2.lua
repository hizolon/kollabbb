--!strict
--[[
    TSB Invisibility / Readable Luau remake
    Important: this is a NEW implementation, not decrypted code from Luraph.
    This only hides your own character on YOUR CLIENT.
    Other players can still see you; TSB server hitboxes/combat remain unaffected.
    Run as a LocalScript in StarterPlayerScripts when testing in Roblox Studio.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then
    error("This script must run on a Roblox client (LocalScript).")
end

-- Prevent duplicate state/GUI on script rerun.
local global = (_G :: any)
if type(global.__TSB_Invisibility_LocalCleanup) == "function" then
    pcall(global.__TSB_Invisibility_LocalCleanup)
end

local enabled = false
local character: Model? = nil
local addedConnection: RBXScriptConnection? = nil
local characterConnection: RBXScriptConnection? = nil
local keyConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local saved: {[Instance]: {[string]: any}} = {}
local tracked: {[BasePart]: boolean} = {}

local function changeProperty(instance: Instance, property: string, value: any)
    local oldValue: any
    local ok = pcall(function()
        oldValue = (instance :: any)[property]
    end)
    if not ok then
        return
    end

    local record = saved[instance]
    if not record then
        record = {}
        saved[instance] = record
    end
    if record[property] == nil then
        record[property] = oldValue
    end

    pcall(function()
        (instance :: any)[property] = value
    end)
end

local function hideInstance(instance: Instance)
    if instance:IsA("BasePart") then
        -- LocalTransparencyModifier is intentionally client-side only.
        changeProperty(instance, "LocalTransparencyModifier", 1)
        tracked[instance] = true
    elseif instance:IsA("Decal") or instance:IsA("Texture") then
        changeProperty(instance, "Transparency", 1)
    elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
        changeProperty(instance, "Enabled", false)
    elseif instance:IsA("Fire") or instance:IsA("Smoke") or instance:IsA("Sparkles") then
        changeProperty(instance, "Enabled", false)
    elseif instance:IsA("Highlight") or instance:IsA("BillboardGui") then
        changeProperty(instance, "Enabled", false)
    end
end

local function restoreAll()
    for instance, properties in pairs(saved) do
        if instance.Parent ~= nil then
            for property, oldValue in pairs(properties) do
                pcall(function()
                    (instance :: any)[property] = oldValue
                end)
            end
        end
    end
    table.clear(saved)
    table.clear(tracked)
end

local function bindCharacter(newCharacter: Model)
    if addedConnection then
        addedConnection:Disconnect()
        addedConnection = nil
    end
    restoreAll()
    character = newCharacter

    addedConnection = newCharacter.DescendantAdded:Connect(function(instance)
        if enabled then
            hideInstance(instance)
        end
    end)

    if enabled then
        for _, instance in ipairs(newCharacter:GetDescendants()) do
            hideInstance(instance)
        end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "TSB_Invisibility_LocalOnly"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 100

gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(216, 96)
panel.Position = UDim2.new(0.5, -108, 0, 85)
panel.BackgroundColor3 = Color3.fromRGB(29, 32, 41)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 32)
title.Position = UDim2.fromOffset(8, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(244, 244, 244)
title.Text = "TSB / Local Invisibility"
title.Parent = panel

local button = Instance.new("TextButton")
button.Name = "Toggle"
button.Size = UDim2.new(1, -18, 0, 40)
button.Position = UDim2.fromOffset(9, 45)
button.BorderSizePixel = 0
button.BackgroundColor3 = Color3.fromRGB(72, 77, 89)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.GothamBold
button.TextSize = 14
button.Parent = panel
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

local function updateButton()
    button.Text = enabled and "INVISIBLE: ON  [I]" or "INVISIBLE: OFF  [I]"
    button.BackgroundColor3 = enabled
        and Color3.fromRGB(45, 135, 110)
        or Color3.fromRGB(72, 77, 89)
end

local function setEnabled(value: boolean)
    if enabled == value then
        return
    end
    enabled = value
    if enabled then
        if character then
            for _, instance in ipairs(character:GetDescendants()) do
                hideInstance(instance)
            end
        end
    else
        restoreAll()
    end
    updateButton()
end

button.MouseButton1Click:Connect(function()
    setEnabled(not enabled)
end)

keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.KeyCode == Enum.KeyCode.I then
        setEnabled(not enabled)
    end
end)

characterConnection = player.CharacterAdded:Connect(bindCharacter)
if player.Character then
    bindCharacter(player.Character)
end

-- Some character scripts rewrite local transparency every render frame.
-- Maintain our visual override while enabled, without touching any server state.
renderConnection = RunService.RenderStepped:Connect(function()
    if not enabled then
        return
    end
    for part in pairs(tracked) do
        if part.Parent then
            if part.LocalTransparencyModifier ~= 1 then
                part.LocalTransparencyModifier = 1
            end
        else
            tracked[part] = nil
        end
    end
end)

local function cleanup()
    enabled = false
    if addedConnection then addedConnection:Disconnect() end
    if characterConnection then characterConnection:Disconnect() end
    if keyConnection then keyConnection:Disconnect() end
    if renderConnection then renderConnection:Disconnect() end
    restoreAll()
    gui:Destroy()
    if global.__TSB_Invisibility_LocalCleanup == cleanup then
        global.__TSB_Invisibility_LocalCleanup = nil
    end
end

global.__TSB_Invisibility_LocalCleanup = cleanup
updateButton()
