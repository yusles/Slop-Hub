local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ByteNetReliable = ReplicatedStorage:WaitForChild("ByteNetReliable", 5)
local LocalPlayer = game:GetService("Players").LocalPlayer
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local Window = Rayfield:CreateWindow({
    Name = "🤮 Sl🅾p Hub 🤮",
    LoadingTitle = "ByteNet Reversal Suite",
    LoadingSubtitle = "AI SLOP",
    ConfigurationSaving = { Enabled = true, FolderName = "Slop", FileName = "Config" }
})

-- --- GLOBAL STATE ---
local MiningActive = false
local MineRange = 25
local PickupRange = 25
local orbiton = false
local orbitradius = 10
local orbitspeed = 5
local itemheight = 3
local attacheditems = {}
local itemangles = {}
local AuraConfig = {
    Enabled = false,
    Range = 20,
    Targets = 1,
    Cooldown = 0.1
}
local PickupConfig = {
    Enabled = false,
    ChestPickup = false,
    Range = 20,
    SelectedItems = {} -- Table to store items selected in the multi-dropdown
}

local WalkSpeedValue = 20
local JumpPowerValue = 65
local HipHeightValue = 2
local InfiniteJumpEnabled = false
local SlopeClimbEnabled = false

task.spawn(function()
    while true do
        RunService.RenderStepped:Wait() -- Runs every frame before rendering
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hum then
            -- Enforce WalkSpeed
            if hum.WalkSpeed ~= WalkSpeedValue then
                hum.WalkSpeed = WalkSpeedValue
            end
            
            -- Enforce JumpPower
            if hum.JumpPower ~= JumpPowerValue then
                hum.UseJumpPower = true
                hum.JumpPower = JumpPowerValue
            end

            -- Enforce HipHeight
            if hum.HipHeight ~= HipHeightValue then
                hum.HipHeight = HipHeightValue
            end
        end
    end
end)

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

-- --- [1] HELPER FUNCTIONS ---

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

local function getByteNet()
    local bn = game:GetService("ReplicatedStorage"):FindFirstChild("ByteNetReliable")
    if not bn then warn("!!! BYTENETRELIABLE NOT FOUND !!!") end
    return bn
end

local function decode(str)
    local b1, b2, b3 = string.byte(str, -4, -2)
    return b1 + b2 * 256 + b3 * 65536
end

local function swingencode(ids)
    if typeof(ids) ~= "table" then ids = {ids} end
    local count = #ids
    local out = {string.char(0x00, 0x11, count, 0x00)}
    for i = 1, count do
        local num = ids[i]
        out[#out + 1] = string.char(num % 256, math.floor(num / 256) % 256, math.floor(num / 65536) % 256, 0x00)
    end
    return table.concat(out)
end

local function run(stringg, packett, itemid)
    local id = typeof(stringg) == "string" and decode(stringg) or stringg
    local packet
    if packett == "swing" then
        packet = swingencode(id)
    end
    
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("ByteNetReliable")
    if remote and packet then
        remote:FireServer(buffer.fromstring(packet))
    end
end

local function pickupencode(entityid)
    local b1 = entityid % 256
    local b2 = math.floor(entityid / 256) % 256
    local b3 = math.floor(entityid / 65536) % 256
    return string.char(0x00, 0xD5, b1, b2, b3, 0x00)
end

local function runPickup(entityid)
    local packet = pickupencode(entityid)
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("ByteNetReliable")
    if remote then
        remote:FireServer(buffer.fromstring(packet))
    end
end

-- --- [2] THE AUTOMINER LOOP ---
task.spawn(function()
    while true do
        if not AuraConfig.Enabled then
            task.wait(0.05)
            continue
        end

        local targets = {}
        local allresources = {}

        -- Collect all valid resources from both designated folders
        for _, r in pairs(workspace.Resources:GetChildren()) do
            table.insert(allresources, r)
        end
        for _, r in pairs(workspace:GetChildren()) do
            if r:IsA("Model") and r.Name == "Gold Node" then
                table.insert(allresources, r)
            end
        end

        for _, res in pairs(allresources) do
            if res:IsA("Model") and res:GetAttribute("EntityID") then
                local eid = res:GetAttribute("EntityID")
                local ppart = res.PrimaryPart or res:FindFirstChildWhichIsA("BasePart")
                if ppart then
                    local dist = (ppart.Position - root.Position).Magnitude
                    if dist <= AuraConfig.Range then
                        table.insert(targets, { eid = eid, dist = dist })
                    end
                end
            end
        end

        if #targets > 0 then
            table.sort(targets, function(a, b)
                return a.dist < b.dist
            end)

            local selectedTargets = {}
            for i = 1, math.min(AuraConfig.Targets, #targets) do
                table.insert(selectedTargets, targets[i].eid)
            end

            run(selectedTargets, "swing")
        end

        task.wait(AuraConfig.Cooldown)
    end
end)

-- --- [3] THE AUTO-PICKUP LOOP ---
task.spawn(function()
    while true do
        local LocalPlayer = game.Players.LocalPlayer
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if root then
            -- A. Ground Item Pickup
            if PickupConfig.Enabled then
                for _, item in ipairs(workspace.Items:GetChildren()) do
                    if item:IsA("BasePart") or item:IsA("MeshPart") then
                        local entityid = item:GetAttribute("EntityID")
                        -- Only pickup if the item is in our allowed list
                        if entityid and table.find(PickupConfig.SelectedItems, item.Name) then
                            if (item.Position - root.Position).Magnitude <= PickupConfig.Range then
                                runPickup(entityid)
                            end
                        end
                    end
                end
            end

            -- B. Chest Content Pickup
            if PickupConfig.ChestPickup then
                for _, chest in ipairs(workspace.Deployables:GetChildren()) do
                    if chest:IsA("Model") and chest.Name == "Chest" and chest:FindFirstChild("Contents") then
                        for _, item in ipairs(chest.Contents:GetChildren()) do
                            local entityid = item:GetAttribute("EntityID")
                            if entityid and table.find(PickupConfig.SelectedItems, item.Name) then
                                -- Check distance from the Chest itself
                                if (chest:GetPivot().Position - root.Position).Magnitude <= PickupConfig.Range then
                                    runPickup(entityid)
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.01) -- High speed polling from Herkle source
    end
end)


-- --- [3] UI ELEMENTS ---
local MainTab = Window:CreateTab("Player")
local AutoTab = Window:CreateTab("Auto-Collect")
local PathTab = Window:CreateTab("Waypoints")

-- Player UI
MainTab:CreateSlider({
    Name = "Walkspeed",
    Range = {16, 22},
    CurrentValue = WalkSpeedValue,
    Increment = 1,
    Callback = function(Value)
        WalkSpeedValue = Value -- Updates the value the loop enforces
    end,
})

MainTab:CreateSlider({
    Name = "JumpPower",
    Range = {50, 85},
    CurrentValue = JumpPowerValue,
    Increment = 1,
    Callback = function(Value)
        JumpPowerValue = Value -- Updates the value the loop enforces
    end,
})

MainTab:CreateSlider({
    Name = "Hip Height",
    Range = {0, 10},
    CurrentValue = HipHeightValue,
    Increment = 0.1,
    Callback = function(Value)
        HipHeightValue = Value -- Updates the value the loop enforces
    end,
})
MainTab:CreateToggle({Name = "Slope Climber", CurrentValue = false, Callback = function(v) _G.SlopeClimbingEnabled = v end})
MainTab:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Callback = function(v) InfiniteJumpEnabled = v end})
MainTab:CreateToggle({Name = "Remove Fog", CurrentValue = false, Callback = function(v) _G.RemoveFogEnabled = v end})
MainTab:CreateToggle({Name = "Full Bright", CurrentValue = false, Callback = function(v) _G.FullBrightEnabled = v end})

-- Auto-Collect UI
AutoTab:CreateSection("Auto-Miner")

AutoTab:CreateToggle({
   Name = "Resource Aura",
   CurrentValue = false,
   Callback = function(Value)
      AuraConfig.Enabled = Value
   end,
})

AutoTab:CreateSlider({
   Name = "Mining Range",
   Range = {1, 20},
   Increment = 1,
   Suffix = "Studs",
   CurrentValue = 20,
   Callback = function(Value)
      AuraConfig.Range = Value
   end,
})

AutoTab:CreateDropdown({
   Name = "Max Targets",
   Options = {"1", "2", "3", "4", "5", "6"},
   CurrentOption = {"1"},
   MultipleOptions = false,
   Callback = function(Option)
      AuraConfig.Targets = tonumber(Option[1])
   end,
})

AutoTab:CreateSection("Auto-Pickup")

-- --- [4] UI TOGGLE ---
AutoTab:CreateToggle({
   Name = "Auto Pickup (Ground)",
   CurrentValue = false,
   Callback = function(Value) PickupConfig.Enabled = Value end,
})

AutoTab:CreateToggle({
   Name = "Auto Pickup (Chests)",
   CurrentValue = false,
   Callback = function(Value) PickupConfig.ChestPickup = Value end,
})

AutoTab:CreateDropdown({
   Name = "Target Items",
   Options = {"Bloodfruit", "Log", "Leaves", "Wood", "Raw Iron", "Iron", "Raw Gold", "Gold", "Steel Mix", "Steel", "Raw Adurite", "Adurite", "Crystal Chunk", "Magnetite Ore", "Magnetite", "Emerald", "Pink Diamond"},
   CurrentOption = {"Gold"},
   MultipleOptions = true,
   Callback = function(Options)
      PickupConfig.SelectedItems = Options -- Updates the list of allowed items
   end,
})

AutoTab:CreateSlider({
   Name = "Pickup Range",
   Range = {1, 20},
   Increment = 1,
   Suffix = "Studs",
   CurrentValue = 20,
   Callback = function(Value) PickupConfig.Range = Value end,
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
        task.wait(1)
    end
end)

-- Climbing Utilities
UserInputService.JumpRequest:Connect(function()
    if InfiniteJumpEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

task.spawn(function()
    while true do
        local char = game.Players.LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        
        if hum then
            if _G.SlopeClimbingEnabled then
                -- Forces max slope angle to 90 degrees to prevent slipping
                hum.MaxSlopeAngle = 90
            else
                -- Returns to default Roblox physics (approx 46 degrees)
                hum.MaxSlopeAngle = 46
            end
        end
        task.wait(0.1) -- Frequent enough for physics, but saves performance
    end
end)
