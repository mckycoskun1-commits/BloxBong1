local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Events = ReplicatedStorage:WaitForChild("Events")
local SprintEvent = Events:WaitForChild("SprintEvent")

local isSprintKeyHeld = false
local isSprinting = false

-- Change Shift Lock keybind to Alt (LeftAlt, RightAlt) dynamically
task.spawn(function()
    local playerScripts = Player:WaitForChild("PlayerScripts")
    local playerModule = playerScripts:WaitForChild("PlayerModule")
    local cameraModule = playerModule:WaitForChild("CameraModule")
    local mouseLockController = cameraModule:WaitForChild("MouseLockController")
    local boundKeys = mouseLockController:FindFirstChild("BoundKeys")
    if boundKeys then
        boundKeys.Value = "LeftAlt,RightAlt"
    else
        local obj = Instance.new("StringValue")
        obj.Name = "BoundKeys"
        obj.Value = "LeftAlt,RightAlt"
        obj.Parent = mouseLockController
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        isSprintKeyHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        isSprintKeyHeld = false
    end
end)

RunService.Heartbeat:Connect(function()
    local moving = false
    local character = Player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    
    if humanoid then
        moving = humanoid.MoveDirection.Magnitude > 0
    end
    
    local stateChanged = false
    
    if isSprintKeyHeld and moving then
        if not isSprinting then
            isSprinting = true
            SprintEvent:FireServer(true)
            stateChanged = true
        end
    else
        if isSprinting then
            isSprinting = false
            SprintEvent:FireServer(false)
            stateChanged = true
        end
    end
    
    if stateChanged then
        -- FOV Efekti (Koşarken hafif geri çekilme)
        TweenService:Create(Camera, TweenInfo.new(0.4), {
            FieldOfView = isSprinting and 85 or 70
        }):Play()
    end
end)
