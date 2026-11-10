local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))

-- Remote olayları ve fonksiyonları oluştur / bekle
local Events = ReplicatedStorage:WaitForChild("Events")
local LobbyEvents = Events:FindFirstChild("LobbyEvents") or Instance.new("Folder", Events)
LobbyEvents.Name = "LobbyEvents"

local OpenShopUI = LobbyEvents:FindFirstChild("OpenShopUI") or Instance.new("RemoteEvent", LobbyEvents)
OpenShopUI.Name = "OpenShopUI"

local BuyShopUpgrade = LobbyEvents:FindFirstChild("BuyShopUpgrade") or Instance.new("RemoteFunction", LobbyEvents)
BuyShopUpgrade.Name = "BuyShopUpgrade"

local RefundShopUpgrades = LobbyEvents:FindFirstChild("RefundShopUpgrades") or Instance.new("RemoteFunction", LobbyEvents)
RefundShopUpgrades.Name = "RefundShopUpgrades"

-- Satın alma isteğini işle
BuyShopUpgrade.OnServerInvoke = function(player, upgradeKey)
    if not player or not upgradeKey then
        return false, "Geçersiz istek"
    end
    return ProgressionManager.BuyUpgrade(player, upgradeKey)
end

-- İade (Refund) isteğini işle
RefundShopUpgrades.OnServerInvoke = function(player)
    if not player then
        return false, "Geçersiz istek", 0
    end
    return ProgressionManager.RefundAllUpgrades(player)
end

-- Dükkan NPC'sini bul ve etkileşim prompt'unu kur
local function findShopNPC()
    local primaryName = LobbyConfig.Visuals.ShopNPC_ModelName or "Shop"
    local candidates = { primaryName, "Shop", "ShopNPC", "MerchantNPC", "Merchant", "Blacksmith", "Demirci" }
    
    for _, name in ipairs(candidates) do
        local found = workspace:FindFirstChild(name)
        if found then
            return found
        end
    end
    return nil
end

local function setupShopNPC()
    local npc = findShopNPC()
    
    if not npc then
        -- Eğer hemen bulunamazsa biraz bekleyip tekrar dene (Studio veya geç yüklenen haritalar için)
        task.spawn(function()
            for attempt = 1, 15 do
                task.wait(1)
                npc = findShopNPC()
                if npc then
                    break
                end
            end
            
            if not npc then
                warn("[ShopNPCManager] Workspace içinde 'Shop' adında bir model bulunamadı.")
                return
            end
            
            attachPrompt(npc)
        end)
        return
    end
    
    attachPrompt(npc)
end

function attachPrompt(npc)
    -- Etkileşim nesnesini (ProximityPrompt) nereye koyacağımızı belirle
    local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head") or npc.PrimaryPart
    if not rootPart or not rootPart:IsA("BasePart") then
        for _, child in ipairs(npc:GetChildren()) do
            if child:IsA("BasePart") then
                rootPart = child
                break
            end
        end
    end
    
    if not rootPart then
        warn("[ShopNPCManager] NPC içinde uygun bir BasePart bulunamadı: " .. npc.Name)
        return
    end
    
    -- Mevcut eski prompt varsa temizle
    local existing = rootPart:FindFirstChild("ShopPrompt")
    if existing then existing:Destroy() end
    
    -- Yeni özel ProximityPrompt oluştur
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "ShopPrompt"
    prompt.ActionText = LobbyConfig.Visuals.ShopNPC_ActionText or "Silver Shop"
    prompt.ObjectText = LobbyConfig.Visuals.ShopNPC_ObjectText or "Shop"
    prompt.KeyboardKeyCode = LobbyConfig.Visuals.ShopNPC_Key or Enum.KeyCode.E
    prompt.MaxActivationDistance = LobbyConfig.Visuals.ShopNPC_MaxDistance or 18
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Custom -- Custom retro prompt görünümü
    prompt.Parent = rootPart
    
    prompt.Triggered:Connect(function(player)
        OpenShopUI:FireClient(player)
    end)
end

-- NPC'nin yüklenmesi için küçük bir gecikme ile başlat
task.spawn(function()
    task.wait(1.5)
    setupShopNPC()
end)
