local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local LobbyEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("LobbyEvents")
local OpenClassUI = LobbyEvents:WaitForChild("OpenClassUI")

local function setupClassNPC()
    -- Config'deki isimle eşleşen modeli bul
    local npcName = LobbyConfig.Visuals.ClassNPC_ModelName or "ClassNPC"
    local npc = workspace:WaitForChild(npcName, 10)
    
    if not npc then
        warn("Class Sistemi: '" .. npcName .. "' adında bir model bulunamadı. Lütfen Workspace'e bu isimde bir NPC ekleyin.")
        return
    end
    
    -- Etkileşim nesnesini (ProximityPrompt) nereye koyacağımızı belirle
    local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc
    if npc:IsA("Model") and npc.PrimaryPart then
        rootPart = npc.PrimaryPart
    elseif npc:IsA("Model") and not rootPart:IsA("BasePart") then
        -- Eğer hiçbir mantıklı parça bulamazsa, içindeki ilk BasePart'ı kullan
        for _, child in ipairs(npc:GetChildren()) do
            if child:IsA("BasePart") then
                rootPart = child
                break
            end
        end
    end
    
    -- ProximityPrompt'u kodla oluştur
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "ClassSelectionPrompt"
    prompt.ActionText = LobbyConfig.Visuals.ClassNPC_ActionText or "Select Class"
    prompt.KeyboardKeyCode = LobbyConfig.Visuals.ClassNPC_Key or Enum.KeyCode.E
    prompt.MaxActivationDistance = LobbyConfig.Visuals.ClassNPC_MaxDistance or 12
    prompt.HoldDuration = LobbyConfig.Visuals.ClassNPC_HoldDuration or 0
    prompt.RequiresLineOfSight = false
    
    -- EN ÖNEMLİ KISIM: Özel (Custom) stil seçimi. Bu sayede Roblox'un standart UI'si değil, bizim yazdığımız şık tasarım açılacak.
    prompt.Style = Enum.ProximityPromptStyle.Custom
    
    prompt.Parent = rootPart
    
    -- Oyuncu E tuşuna bastığında tetiklenecek olay
    prompt.Triggered:Connect(function(player)
        OpenClassUI:FireClient(player) -- Client tarafındaki UI'yi aç
    end)
end

-- NPC'nin yüklenmesi için küçük bir gecikme ile başlat
task.spawn(function()
    task.wait(2)
    setupClassNPC()
end)
