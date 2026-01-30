local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ByteNetReliable = ReplicatedStorage:WaitForChild("ByteNetReliable", 5)
local LocalPlayer = game:GetService("Players").LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "🤮 Sl🅾p Hub 🤮",
    LoadingTitle = "ByteNet Reversal Suite",
    LoadingSubtitle = "AI SLOP",
    ConfigurationSaving = { Enabled = true, FolderName = "Slop", FileName = "Config" }
})

-- --- GLOBAL STATE ---
local MineRange = 22
local PickupRange = 25
local PickupWhitelist = {} -- Table to store selected items
local PickupBlacklist = {}

local WalkSpeedValue = 16
local JumpPowerValue = 50
local InfiniteJumpEnabled = false

local isRunningWaypoints = false
local waypoints = {}
local currentTween = nil
local waypointConfig = {
    speed = 18,
    loopPath = true,
    delay = 0.5,
    easingStyle = Enum.EasingStyle.Linear,
    easingDirection = Enum.EasingDirection.InOut
}

local vizFolder = workspace:FindFirstChild("WaypointVisualization") or Instance.new("Folder", workspace)
vizFolder.Name = "WaypointVisualization"

local function updateVisualization()
    vizFolder:ClearAllChildren()
    for i, pos in ipairs(waypoints) do
        local m = Instance.new("Part", vizFolder)
        m.Shape = Enum.PartType.Ball
        m.Size = Vector3.new(2, 2, 2)
        m.Position = pos
        m.Anchored = true
        m.CanCollide = false
        m.Material = Enum.Material.Neon
        m.Transparency = 0.4
        m.Color = Color3.fromRGB(255, 0, 255) -- Magenta
        m.Name = "Waypoint_" .. i
    end
end

-- --- HELPER FUNCTIONS ---

local function toLE32(id)
    if not id then return nil end 
    local a = string.char(id % 256)
    local b = string.char(math.floor(id / 256) % 256)
    local c = string.char(math.floor(id / 65536) % 256)
    local d = string.char(math.floor(id / 16777216) % 256)
    return a .. b .. c .. d
end

local function firePickup(itemID)
    local header = "\001\213" 
    local idBytes = toLE32(itemID)
    if idBytes and ByteNetReliable then
        local payload = header .. idBytes
        ByteNetReliable:FireServer(buffer.fromstring(payload))
    end
end

local function fireHit(target, context)
    if not target or not context then return end
    local header = "\001\017\002\000" 
    local tBytes = toLE32(target)
    local cBytes = toLE32(context)
    if tBytes and cBytes and ByteNetReliable then
        local payload = header .. tBytes .. cBytes
        ByteNetReliable:FireServer(buffer.fromstring(payload))
    end
end

-- --- UI TABS ---
local MainTab = Window:CreateTab("Player")
local AutoTab = Window:CreateTab("Auto-Collect")
local PathTab = Window:CreateTab("Waypoints")

-- Player UI
MainTab:CreateSlider({Name = "Walkspeed", Range = {16, 22}, CurrentValue = 20, Increment = 1, Callback = function(v) WalkSpeedValue = v end})
MainTab:CreateSlider({Name = "JumpPower", Range = {50, 85}, CurrentValue = 65, Increment = 1, Callback = function(v) JumpPowerValue = v end})
MainTab:CreateSlider({Name = "Hip Height",Range = {0, 8}, CurrentValue = 2, Increment = 0.5, Callback = function(v)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.HipHeight = v
        end
    end
})
MainTab:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Callback = function(v) InfiniteJumpEnabled = v end})
MainTab:CreateToggle({Name = "Remove Fog", CurrentValue = false, Callback = function(v) _G.RemoveFogEnabled = v end})
MainTab:CreateToggle({Name = "Full Bright", CurrentValue = false, Callback = function(v) _G.FullBrightEnabled = v end})

-- Auto-Collect UI
AutoTab:CreateSection("Gold Miner")

AutoTab:CreateToggle({
    Name = "Gold Miner",
    CurrentValue = false,
    Callback = function(Value)
        _G.UniversalMine = Value
        task.spawn(function()
            while _G.UniversalMine do
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local Res = workspace:FindFirstChild("Resources")
                if root and Res then
                    for _, item in pairs(Res:GetChildren()) do
                        if not _G.UniversalMine then break end
                        if (root.Position - item:GetPivot().Position).Magnitude < MineRange then
                            if item.Name == "Gold Node" then
                                -- Target Part logic remains same as validated
                                local mainPart = item:FindFirstChild("Gold Node") or item:FindFirstChildWhichIsA("BasePart")
                                if mainPart then fireHit(mainPart:GetAttribute("EntityID"), item:GetAttribute("EntityID")) end
                            elseif item.Name == "Ice Chunk" then
                                local ice = item:FindFirstChild("Ice")
                                if ice then fireHit(ice:GetAttribute("EntityID"), item:GetAttribute("EntityID")) end
                                local breaky = item:FindFirstChild("Breakaway")
                                local nested = breaky and breaky:FindFirstChild("Gold Node")
                                if nested then 
                                    local gPart = nested:FindFirstChild("Gold Node")
                                    if gPart then fireHit(gPart:GetAttribute("EntityID"), nested:GetAttribute("EntityID")) end
                                end
                            end
                        end
                    end
                end
                task.wait(0.1)
            end
        end)
    end
})



AutoTab:CreateSlider({
    Name = "Mining Range",
    Range = {5, 50},
    CurrentValue = 25,
    Increment = 1,
    Callback = function(v) MineRange = v end
})

AutoTab:CreateSection("Auto-Pickup")

AutoTab:CreateToggle({
    Name = "Packet Auto-Pickup",
    CurrentValue = false,
    Callback = function(Value)
        _G.PickupEnabled = Value
        task.spawn(function()
            while _G.PickupEnabled do
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local ItemsFolder = workspace:FindFirstChild("Items")
                
                if root and ItemsFolder then
                    for _, item in pairs(ItemsFolder:GetChildren()) do
                        if not _G.PickupEnabled then break end
                        
                        local itemID = item:GetAttribute("EntityID")
                        if itemID then
                            local itemName = item.Name
                            
                            -- 1. Check Blacklist
                            local isBlacklisted = false
                            for _, name in pairs(PickupBlacklist) do
                                if itemName == name then
                                    isBlacklisted = true
                                    break
                                end
                            end

                            if not isBlacklisted then
                                -- 2. Check Whitelist
                                local isWhitelisted = (#PickupWhitelist == 0)
                                if not isWhitelisted then
                                    for _, name in pairs(PickupWhitelist) do
                                        if itemName == name then
                                            isWhitelisted = true
                                            break
                                        end
                                    end
                                end

                                -- 3. Check Distance and Fire
                                if isWhitelisted then
                                    local dist = (root.Position - item:GetPivot().Position).Magnitude
                                    if dist < PickupRange then
                                        firePickup(itemID)
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(0.1) -- Keep this to prevent crashing/rate-limiting
            end
        end)
    end,
})

AutoTab:CreateDropdown({
   Name = "Pickup Whitelist",
   Options = {"Bloodfruit", "Raw Iron", "Iron", "Raw Gold", "Gold", "Steel Mix", "Steel", "Raw Adurite", "Adurite", "Crystal Chunk", "Magnetite Ore", "Magnetite", "Emerald", "Pink Diamond"},
   CurrentOption = {},
   MultipleOptions = true, -- The "Multiselect" logic
   Callback = function(Options)
       PickupWhitelist = Options
   end,
})

-- Drop this into the Auto-Collect Tab section
AutoTab:CreateDropdown({
   Name = "Pickup Blacklist",
   Options = {"Ice Cube", "Leaves", "Wood", "Stone", "Sand"},
   CurrentOption = {},
   MultipleOptions = true,
   Callback = function(Options)
       PickupBlacklist = Options
   end,
})

AutoTab:CreateSlider({
    Name = "Pickup Range",
    Range = {5, 50},
    CurrentValue = 25,
    Increment = 1,
    Callback = function(v) PickupRange = v end
})

-- Waypoints UI

PathTab:CreateSection("Movement Controls")
PathTab:CreateToggle({Name = "Enable Pathing", CurrentValue = false, Callback = function(v)
    isRunningWaypoints = v
    if v then
        task.spawn(function()
            if #waypoints == 0 then return end
            repeat
                for _, pos in ipairs(waypoints) do
                    if not isRunningWaypoints then break end
                    local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local dist = (pos - root.Position).Magnitude
                        currentTween = TweenService:Create(root, TweenInfo.new(dist/waypointConfig.speed, waypointConfig.easingStyle), {CFrame = CFrame.new(pos)})
                        currentTween:Play()
                        currentTween.Completed:Wait()
                        task.wait(waypointConfig.delay)
                    end
                end
            until not waypointConfig.loopPath or not isRunningWaypoints
        end)
    elseif currentTween then currentTween:Cancel() end
end})

-- ADD WAYPOINT
PathTab:CreateButton({
    Name = "Add Waypoint", 
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(waypoints, LocalPlayer.Character.HumanoidRootPart.Position)
            updateVisualization() -- Restores the circle
        end
    end
})

PathTab:CreateButton({
    Name = "Remove Last Waypoint",
    Callback = function()
        if #waypoints > 0 then
            table.remove(waypoints, #waypoints) -- Removes the very last entry
            updateVisualization() -- Refreshes the Neon balls in the workspace
        end
    end
})

-- CLEAR ALL WAYPOINTS
PathTab:CreateButton({
    Name = "Clear Waypoints", 
    Callback = function() 
        waypoints = {}
        isRunningWaypoints = false
        if currentTween then currentTween:Cancel() end 
        updateVisualization() -- Wipes the circles
    end
})
PathTab:CreateSection("Path Settings")
PathTab:CreateSlider({
    Name = "Tween Speed",
    Range = {1, 22},
    CurrentValue = 18,
    Increment = 1,
    Callback = function(v) waypointConfig.speed = v end
})

PathTab:CreateSlider({
    Name = "Stop Delay",
    Range = {0, 10},
    CurrentValue = 0.5,
    Increment = 0.1,
    Callback = function(v) waypointConfig.delay = v end
})

PathTab:CreateToggle({Name = "Loop Path", CurrentValue = true, Callback = function(v) waypointConfig.loopPath = v end})
-- Lighting Loop
task.spawn(function()
    local L = game:GetService("Lighting")
    while true do
        if _G.RemoveFogEnabled then L.FogEnd = 9e9; L.FogStart = 0 end
        if _G.FullBrightEnabled then
            L.Brightness, L.ClockTime, L.GlobalShadows = 2, 14, false
            L.Ambient, L.OutdoorAmbient = Color3.new(1,1,1), Color3.new(1,1,1)
        end
        task.wait(2)
    end
end)

UserInputService.JumpRequest:Connect(function()
    if InfiniteJumpEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
