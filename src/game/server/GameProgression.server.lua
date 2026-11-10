local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))

-- Initialize Events and RemoteEvent
local Events = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder", ReplicatedStorage)
Events.Name = "Events"

local QuestUnlocked = Events:FindFirstChild("QuestUnlocked") or Instance.new("RemoteEvent")
QuestUnlocked.Name = "QuestUnlocked"
QuestUnlocked.Parent = Events

-- Load progression on PlayerAdded
Players.PlayerAdded:Connect(function(player)
    ProgressionManager.Load(player)
end)

-- In case players are already in (Studio test play)
for _, player in ipairs(Players:GetPlayers()) do
    ProgressionManager.Load(player)
end
