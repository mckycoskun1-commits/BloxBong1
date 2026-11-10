local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))

-- Remote Events Klasörü Kontrolü
local Events = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder", ReplicatedStorage)
Events.Name = "Events"

local ResetIndexProgression = Events:FindFirstChild("ResetIndexProgression") or Instance.new("RemoteEvent", Events)
ResetIndexProgression.Name = "ResetIndexProgression"

local ResetIndexResult = Events:FindFirstChild("ResetIndexResult") or Instance.new("RemoteEvent", Events)
ResetIndexResult.Name = "ResetIndexResult"

-- Index / Progression Sıfırlama İsteklerini Dinle
ResetIndexProgression.OnServerEvent:Connect(function(player)
    if not player or not player.Parent then return end

    -- ProgressionManager üzerinden sıfırla
    local success = true
    if ProgressionManager and typeof(ProgressionManager.Reset) == "function" then
        success = ProgressionManager.Reset(player)
    else
        player:SetAttribute("WipedProgression", true)
        local ProgressionDataStore = DataStoreService:GetDataStore("PlayerProgressionData_V2")
        pcall(function()
            ProgressionDataStore:RemoveAsync(tostring(player.UserId))
        end)
    end

    -- Oyuncudaki tüm Index ve Kilit Açılış Attribute'larını temizle
    for attrName, _ in pairs(player:GetAttributes()) do
        if string.find(attrName, "^Unlocked_") 
            or string.find(attrName, "^Progress_") 
            or string.find(attrName, "^NewlyUnlocked_")
            or string.find(attrName, "^Index_")
            or string.find(attrName, "^Codex_")
            or string.find(attrName, "^Discovered_")
            or string.find(attrName, "^Bestiary_") then
            player:SetAttribute(attrName, nil)
        end
    end

    print(string.format("[SettingsServer] Player %s (%d) index and progression has been reset.", player.Name, player.UserId))
    
    -- Client'a başarılı sonucunu bildir
    ResetIndexResult:FireClient(player, success ~= false)
end)
