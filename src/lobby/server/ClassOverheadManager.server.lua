-- ============================================================
-- CLASS OVERHEAD UI MANAGER
-- Karakterlerin üzerinde seçili sınıfı gösterir.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local UIConfig = LobbyConfig.UI.OverheadUI

local function createOverhead(player, character)
    local head = character:WaitForChild("Head", 5)
    if not head then return end
    
    -- Varsa eskiyi sil
    local old = head:FindFirstChild("ClassOverhead")
    if old then old:Destroy() end
    
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "ClassOverhead"
    bgui.Size = UDim2.new(2.5, 0, 0.6, 0) -- Adjusted size to be much smaller and natural (2.5 studs wide, 0.6 studs high)
    bgui.StudsOffset = Vector3.new(0, UIConfig.HeightOffset, 0)
    bgui.AlwaysOnTop = UIConfig.AlwaysOnTop
    bgui.MaxDistance = UIConfig.MaxDistance
    bgui.Parent = head
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = UIConfig.Font
    label.TextScaled = true -- Enable TextScaled to make the text scale dynamically with zoom!
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = bgui
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = Color3.new(0, 0, 0)
    uiStroke.Thickness = UIConfig.StrokeThickness
    uiStroke.Parent = label

    local function updateUI()
        local className = player:GetAttribute("SelectedClass")
        local classColor = player:GetAttribute("ClassColor")
        
        if className and classColor then
            label.Text = string.upper(className)
            label.TextColor3 = classColor
        else
            label.Text = ""
        end
    end

    -- İlk güncelleme
    updateUI()
    
    -- Attribute değiştiğinde güncelle
    player:GetAttributeChangedSignal("SelectedClass"):Connect(updateUI)
    player:GetAttributeChangedSignal("ClassColor"):Connect(updateUI)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        createOverhead(player, character)
    end)
end)

-- Mevcut oyuncular için (Script restart durumunda)
for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        createOverhead(player, player.Character)
    end
end
