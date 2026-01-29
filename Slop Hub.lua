local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ByteNetRemote = ReplicatedStorage:WaitForChild("ByteNetReliable")
local LocalPlayer = game:GetService("Players").LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "🤮 Sl🅾p Hub 🤮",
    LoadingTitle = "ByteNet Reversal Suite",
	LoadingSubtitle = "AI SLOP",
    ConfigurationSaving = { Enabled = true, FolderName = "GeminiMaster", FileName = "Config" }
})

-- --- GLOBAL STATE ---
local AutoPickupEnabled = false
local PickupRange = 25
local CurrentKey = 0
local SweepWidth = 3

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

-- --- STAT FORCER (The bypass for resetting WalkSpeed) ---
task.spawn(function()
    while true do
        RunService.RenderStepped:Wait() -- Runs every frame
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            -- Constantly reapplies values to win the 'tug-of-war' with game scripts
            if hum.WalkSpeed ~= WalkSpeedValue then
                hum.WalkSpeed = WalkSpeedValue
            end
            if hum.JumpPower ~= JumpPowerValue then
                hum.UseJumpPower = true
                hum.JumpPower = JumpPowerValue
            end
        end
    end
end)

-- --- BYTENET SNIFFER ---
local oldFire
oldFire = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
    local args = {...}
    if self == ByteNetRemote and typeof(args[1]) == "buffer" then
        local b = args[1]
        if buffer.readu8(b, 1) == 213 then
            CurrentKey = buffer.readu8(b, 3)
        end
    end
    return oldFire(self, ...)
end)

-- --- HELPER FUNCTIONS ---
local function firePickup(id, key)
    local b = buffer.create(6)
    buffer.writeu8(b, 0, 0); buffer.writeu8(b, 1, 213)
    buffer.writeu8(b, 2, id % 256); buffer.writeu8(b, 3, key % 256)
    buffer.writeu8(b, 4, 0); buffer.writeu8(b, 5, 0)
    ByteNetRemote:FireServer(b)
end

local vizFolder = workspace:FindFirstChild("WaypointVisualization") or Instance.new("Folder", workspace)
vizFolder.Name = "WaypointVisualization"

local function updateVisualization()
    vizFolder:ClearAllChildren()
    for i, pos in ipairs(waypoints) do
        local m = Instance.new("Part", vizFolder)
        m.Shape, m.Size, m.Position, m.Anchored, m.CanCollide = Enum.PartType.Ball, Vector3.new(2,2,2), pos, true, false
        m.Material, m.Transparency, m.Color = Enum.Material.Neon, 0.4, Color3.fromRGB(255, 0, 255)
    end
end

-- --- INPUT HANDLERS ---
UserInputService.JumpRequest:Connect(function()
    if InfiniteJumpEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- --- AUTOMATION LOOPS ---

-- Pickup Loop
task.spawn(function()
    while true do
        task.wait(0.2)
        if AutoPickupEnabled and CurrentKey ~= 0 then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                for _, item in pairs(workspace.Items:GetChildren()) do
                    local id = item:GetAttribute("EntityID")
                    if id and (item:GetPivot().Position - root.Position).Magnitude <= PickupRange then
                        for i = 0, SweepWidth do firePickup(id, CurrentKey + i) end
                    end
                end
            end
        end
    end
end)

-- Tweening Logic
local function startWaypointTweening()
    if #waypoints == 0 then return end
    isRunningWaypoints = true
    repeat
        for i, pos in ipairs(waypoints) do
            if not isRunningWaypoints then break end
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (pos - root.Position).Magnitude
                local tInfo = TweenInfo.new(dist/waypointConfig.speed, waypointConfig.easingStyle, waypointConfig.easingDirection)
                currentTween = TweenService:Create(root, tInfo, {CFrame = CFrame.new(pos)})
                currentTween:Play()
                currentTween.Completed:Wait()
                task.wait(waypointConfig.delay)
            end
        end
    until not waypointConfig.loopPath or not isRunningWaypoints
end

-- --- UI TABS ---
local MainTab = Window:CreateTab("Player", 4483362458)
local AutoTab = Window:CreateTab("Auto-Collect", 4483362458)
local PathTab = Window:CreateTab("Waypoints", 4483362458)

-- Player UI
MainTab:CreateSection("Movement")
MainTab:CreateSlider({
    Name = "Walkspeed", 
    Range = {16, 22}, 
    CurrentValue = 16, 
    Increment = 1,
    Callback = function(v) WalkSpeedValue = v end
})

MainTab:CreateSlider({
    Name = "JumpPower", 
    Range = {50, 85}, 
    CurrentValue = 50, 
    Increment = 1,
    Callback = function(v) JumpPowerValue = v end
})

MainTab:CreateToggle({
    Name = "Infinite Jump", 
    CurrentValue = false, 
    Callback = function(v) InfiniteJumpEnabled = v end
})

-- Auto-Collect UI
AutoTab:CreateSection("Live Diagnostics")
local DiagPara = AutoTab:CreateParagraph({Title = "System: Standby", Content = "Key: 0 | Range: 25"})

task.spawn(function()
    while task.wait(0.5) do
        DiagPara:Set({Title = "Status: "..(AutoPickupEnabled and "ON" or "OFF"), Content = "Current Key: "..CurrentKey.."\nSweep Window: "..SweepWidth})
    end
end)

AutoTab:CreateToggle({Name = "Enable Auto-Pickup", CurrentValue = false, Callback = function(v) AutoPickupEnabled = v end})
AutoTab:CreateSlider({Name = "Pickup Range", Range = {5, 75}, CurrentValue = 25, Increment = 1, Callback = function(v) PickupRange = v end})
AutoTab:CreateSlider({Name = "Sweep Width", Range = {1, 10}, CurrentValue = 3, Increment = 1, Callback = function(v) SweepWidth = v end})
AutoTab:CreateButton({Name = "Brute Force Sync", Callback = function() 
    local items = workspace.Items:GetChildren()
    if #items > 0 then for i=0,255 do firePickup(items[1]:GetAttribute("EntityID"), i) end end 
end})

-- Waypoints UI
PathTab:CreateSection("Movement Controls")
PathTab:CreateToggle({Name = "Enable Pathing", CurrentValue = false, Callback = function(v)
    if v then task.spawn(startWaypointTweening) else isRunningWaypoints = false if currentTween then currentTween:Cancel() end end
end})

PathTab:CreateButton({Name = "Add Waypoint Here", Callback = function()
    if LocalPlayer.Character then
        table.insert(waypoints, LocalPlayer.Character.HumanoidRootPart.Position)
        updateVisualization()
    end
end})

PathTab:CreateButton({Name = "Clear All Waypoints", Callback = function() 
    waypoints = {} 
    updateVisualization() 
    isRunningWaypoints = false
    if currentTween then currentTween:Cancel() end 
end})

PathTab:CreateSection("Path Settings")
PathTab:CreateSlider({Name = "Speed", Range = {1, 22}, CurrentValue = 18, Increment = 1, Callback = function(v) waypointConfig.speed = v end})
PathTab:CreateSlider({Name = "Stop Delay", Range = {0, 5}, CurrentValue = 0.5, Increment = 0.1, Callback = function(v) waypointConfig.delay = v end})
PathTab:CreateToggle({Name = "Loop Path", CurrentValue = true, Callback = function(v) waypointConfig.loopPath = v end})