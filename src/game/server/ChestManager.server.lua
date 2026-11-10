local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))
local PositionUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PositionUtil"))

local Events = ReplicatedStorage:WaitForChild("Events")
local PlayChestAnimationEvent = Events:WaitForChild("PlayChestAnimation")
local ChestAwardedEvent = Events:WaitForChild("ChestAwarded")
local ChestClaimedEvent = Events:WaitForChild("ChestClaimed")
local BossDefeatedBindable = Events:WaitForChild("BossDefeated")
local GetPlayerData = Events:WaitForChild("GetPlayerData")

local function getChestCost(chestsOpened)
    if chestsOpened == 0 then return 30 end
    
    local staticCosts = {
        [0] = 30, [1] = 72, [2] = 115, [3] = 159, [4] = 206, [5] = 256,
        [6] = 309, [7] = 366, [8] = 427, [9] = 495, [10] = 569, [11] = 952,
        [12] = 1346, [13] = 1753, [14] = 2175, [15] = 2617, [16] = 3083,
        [17] = 3577, [18] = 4105, [19] = 4677, [20] = 5301, [21] = 6538,
        [22] = 7853, [23] = 9262, [24] = 10786, [25] = 12451
    }
    
    if staticCosts[chestsOpened] then
        return staticCosts[chestsOpened]
    else
        local baseCost = 12451
        local diff = chestsOpened - 25
        return math.floor(baseCost * (1.15 ^ diff))
    end
end

local PlayersOpeningChests = {}

local function isSomeoneOpeningChest()
    for _, isOpening in pairs(PlayersOpeningChests) do
        if isOpening then return true end
    end
    return false
end

local function isSomeoneChoosingUpgrade()
    for _, p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("IsChoosingUpgrade") == true then
            return true
        end
    end
    return false
end

ChestClaimedEvent.OnServerEvent:Connect(function(player)
    if PlayersOpeningChests[player] then
        PlayersOpeningChests[player] = nil
        player:SetAttribute("IsOpeningChest", false)
        
        if not isSomeoneOpeningChest() then
            ReplicatedStorage:SetAttribute("IsOpeningChest", false)
            
            -- Sadece hiçbir oyuncu upgrade/kart seçme ekranında değilse ve manuel duraklatılmamışsa oyunu devam ettir
            if not isSomeoneChoosingUpgrade() and not ReplicatedStorage:GetAttribute("IsManualPaused") then
                ReplicatedStorage:SetAttribute("IsPaused", false)
                local PauseEvent = Events:FindFirstChild("PauseEvent")
                if PauseEvent then
                    PauseEvent:FireAllClients(false)
                end
                
                -- Bütün oyuncuların hareket kabiliyetini geri ver
                local allPlayers = Players:GetPlayers()
                for _, p in ipairs(allPlayers) do
                    p:SetAttribute("IsOpeningChest", false)
                    if p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.Anchored = false end
                        
                        if p.Character:FindFirstChild("Humanoid") then
                            local pData = GetPlayerData:Invoke(p)
                            local speedBonus = pData and pData.SpeedBonus or 0
                            p.Character.Humanoid.WalkSpeed = 17 + speedBonus
                        end
                    end
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if PlayersOpeningChests[player] then
        PlayersOpeningChests[player] = nil
        player:SetAttribute("IsOpeningChest", false)
        
        if not isSomeoneOpeningChest() then
            ReplicatedStorage:SetAttribute("IsOpeningChest", false)
            
            if not isSomeoneChoosingUpgrade() and not ReplicatedStorage:GetAttribute("IsManualPaused") and ReplicatedStorage:GetAttribute("IsPaused") then
                ReplicatedStorage:SetAttribute("IsPaused", false)
                local PauseEvent = Events:FindFirstChild("PauseEvent")
                if PauseEvent then
                    PauseEvent:FireAllClients(false)
                end
                
                -- Bütün oyuncuların hareket kabiliyetini geri ver
                local allPlayers = Players:GetPlayers()
                for _, p in ipairs(allPlayers) do
                    p:SetAttribute("IsOpeningChest", false)
                    if p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.Anchored = false end
                        
                        if p.Character:FindFirstChild("Humanoid") then
                            local pData = GetPlayerData:Invoke(p)
                            local speedBonus = pData and pData.SpeedBonus or 0
                            p.Character.Humanoid.WalkSpeed = 17 + speedBonus
                        end
                    end
                end
            end
        end
    end
end)

-- Raycast down to find ground position using PositionUtil
local function getValidSpawnPosition(rawPos)
    local pos, normal = PositionUtil.getValidSpawnPosition(rawPos, Config, workspace:FindFirstChild("Enemies"))
    return pos, normal
end

-- Item rolling based on player luck
local function rollItem(player)
    local data = GetPlayerData:Invoke(player)
    local luck = 0
    if data and data.Items and data.Items.clover then
        luck = data.Items.clover * 0.05
    end
    if data and data.LuckBonus then
        luck = luck + data.LuckBonus
    end
    
    -- Roll rarity
    local levelMap = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4 }
    local totalWeight = 0
    local rarityWeights = {}
    for name, info in pairs(ItemConfig.Rarities) do
        local weight = info.Weight
        local level = levelMap[name] or 1
        local multiplier = (1 + luck) ^ (level - 1)
        weight = weight * multiplier
        
        rarityWeights[name] = weight
        totalWeight = totalWeight + weight
    end
    
    local roll = math.random() * totalWeight
    local chosenRarity = "Common"
    local cumulative = 0
    for name, weight in pairs(rarityWeights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            chosenRarity = name
            break
        end
    end
    
    -- Filter items in rarity (Kilitli olanları kontrol et)
    local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))
    local itemsInRarity = {}
    for key, item in pairs(ItemConfig.Items) do
        if item.Rarity == chosenRarity then
            if not item.LockedByDefault or ProgressionManager.IsUnlocked(player, key) then
                table.insert(itemsInRarity, key)
            end
        end
    end
    
    -- Fallback
    if #itemsInRarity == 0 then
        for key, item in pairs(ItemConfig.Items) do
            if item.Rarity == "Common" then
                if not item.LockedByDefault or ProgressionManager.IsUnlocked(player, key) then
                    table.insert(itemsInRarity, key)
                end
            end
        end
    end
    
    local chosenItemKey = itemsInRarity[math.random(1, #itemsInRarity)]
    return chosenItemKey, ItemConfig.Items[chosenItemKey]
end

-- Spawns a chest at the given location
local function spawnChest(position, isBoss, normal)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local chestFolder = assets and (assets:FindFirstChild("Chests") or assets:FindFirstChild("Chest"))
    
    local chestAsset = nil
    if chestFolder then
        if isBoss then
            chestAsset = chestFolder:FindFirstChild("BossChest") or chestFolder:FindFirstChild("Boss Chest")
        else
            chestAsset = chestFolder:FindFirstChild("Chest") or chestFolder:FindFirstChild("MapChest")
        end
    end
    
    if not chestAsset then
        warn("[ChestManager] ERROR: Custom Chest model not found in ReplicatedStorage.Assets.Chests!")
        return
    end
    
    local model = chestAsset:Clone()
    model.Name = isBoss and "BossChest" or "MapChest"
    
    -- Ensure everything is anchored to prevent physics from deforming the chest
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
        end
    end
    
    local groundPosition = position - Vector3.new(0, 3, 0)
    
    -- Chests should spawn completely upright to avoid deformation/clipping on stairs and slopes
    local useNormal = Vector3.new(0, 1, 0)
    local baseCFrame = CFrame.new(groundPosition)
    
    model:PivotTo(baseCFrame)
    
    -- Sandığın gerçek büyüklüğünü hesapla ve alt kısmını tam zemine oturt
    local bboxCFrame, bboxSize = model:GetBoundingBox()
    local localBottom = bboxCFrame.Position - useNormal * (bboxSize.Y / 2)
    local offset = groundPosition - localBottom
    
    model:PivotTo(model:GetPivot() + offset)
    
    -- Apply subtle highlight glow around the model (subtle yellow/red glow, hidden behind walls)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ChestHighlight"
    highlight.OutlineColor = isBoss and Color3.fromRGB(220, 80, 80) or Color3.fromRGB(255, 215, 0)
    highlight.OutlineTransparency = 0.5 -- Subtle, not very obvious
    highlight.FillTransparency = 1 -- Fully transparent interior
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- Hides behind walls/obstacles
    highlight.Adornee = model
    highlight.Parent = model
    
    -- Arayüzün tam ortada durması için modelin geometrik merkezini hesapla ve görünmez bir merkez parçası oluştur
    local finalBBoxCFrame, finalBBoxSize = model:GetBoundingBox()
    local centerPart = Instance.new("Part")
    centerPart.Name = "PromptCenter"
    centerPart.Size = Vector3.new(0.1, 0.1, 0.1)
    centerPart.Transparency = 1
    centerPart.CanCollide = false
    centerPart.CanTouch = false
    centerPart.CanQuery = false
    centerPart.Massless = true
    centerPart.CFrame = finalBBoxCFrame
    centerPart.Parent = model
    
    -- Prompt center is anchored since the chest is fully anchored
    centerPart.Anchored = true
    
    -- Proximity Prompt for interaction
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "OpenPrompt"
    prompt.ObjectText = isBoss and "Boss Chest" or "Treasure Chest"
    
    local currentCost = 30
    local firstPlayer = Players:GetPlayers()[1]
    if firstPlayer then
        local data = GetPlayerData:Invoke(firstPlayer)
        if data then
            currentCost = data.ChestOpenCost or 30
        end
    end
    prompt.ActionText = isBoss and "Open Chest (FREE)" or tostring(currentCost)
    
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 12
    prompt.UIOffset = Vector2.new(0, 40)
    prompt.Parent = centerPart
    
    prompt.Style = Enum.ProximityPromptStyle.Custom
    prompt:SetAttribute("PromptType", isBoss and "BossChest" or "MapChest")
    
    prompt.Triggered:Connect(function(player)
        if model:GetAttribute("Opening") then return end
        
        -- Upgrade ekranındayken veya oyun durmuşken sandık açılamaz!
        if ReplicatedStorage:GetAttribute("IsPaused") or player:GetAttribute("IsChoosingUpgrade") or PlayersOpeningChests[player] or isSomeoneChoosingUpgrade() then
            return
        end
        
        local data = GetPlayerData:Invoke(player)
        if not data then return end
        
        local cost = 0
        if not isBoss then
            cost = data.ChestOpenCost or 30
            if data.Coins < cost then
                local ShowMessageEvent = Events:FindFirstChild("ShowMessage")
                if ShowMessageEvent then
                    ShowMessageEvent:FireClient(player, "Not enough gold!", Color3.fromRGB(255, 50, 50))
                end
                return
            end
            
            -- Parayı sadece açan kişiden düş (Server master tablosunu güncellemek için BindableEvent kullan)
            local AddCoins = Events:FindFirstChild("AddCoins")
            if AddCoins then
                AddCoins:Fire(player, -cost)
            end
            
            -- Sandık açma sayısını ve yeni fiyatı TÜM oyuncular için güncelle
            local newCost = 30
            local allPlayers = Players:GetPlayers()
            local ChestOpened = Events:FindFirstChild("ChestOpened")
            for _, p in ipairs(allPlayers) do
                local pData = GetPlayerData:Invoke(p)
                if pData then
                    local updatedChestsOpened = (pData.ChestsOpened or 0) + 1
                    local updatedChestOpenCost = getChestCost(updatedChestsOpened)
                    newCost = updatedChestOpenCost
                    if ChestOpened then
                        ChestOpened:Fire(p, updatedChestsOpened, updatedChestOpenCost)
                    end
                end
            end
            
            -- Haritadaki diğer tüm açık sandıkların fiyatını güncelle
            local updatedPromptsCount = 0
            for _, child in ipairs(workspace:GetChildren()) do
                if child.Name == "MapChest" or child.Name == "Chest" then
                    local pCenter = child:FindFirstChild("PromptCenter")
                    local openPrompt = pCenter and pCenter:FindFirstChild("OpenPrompt")
                    if openPrompt and openPrompt:GetAttribute("PromptType") == "MapChest" then
                        openPrompt.ActionText = tostring(newCost)
                        updatedPromptsCount = updatedPromptsCount + 1
                    end
                end
            end
        end
        
        -- PAUSE GAME & HAREKETİ KISITLA (Sandık açma durumunu duraklatmadan ÖNCE belirle)
        local allPlayers = Players:GetPlayers()
        ReplicatedStorage:SetAttribute("IsOpeningChest", true)
        for _, p in ipairs(allPlayers) do
            p:SetAttribute("IsOpeningChest", true)
        end
        ReplicatedStorage:SetAttribute("IsPaused", true)
        local PauseEvent = Events:FindFirstChild("PauseEvent")
        if PauseEvent then
            PauseEvent:FireAllClients(true)
        end
        
        for _, p in ipairs(allPlayers) do
            if p.Character then
                local humanoid = p.Character:FindFirstChild("Humanoid")
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                
                if hrp then hrp.Anchored = true end
                if humanoid then humanoid.WalkSpeed = 0 end
            end
        end
        
        -- Lock interaction
        model:SetAttribute("Opening", true)
        prompt.Enabled = false
        
        -- Play opening animation on all clients
        PlayChestAnimationEvent:FireAllClients(model)
        
        -- Bütün oyunculara kendi şanslarına göre eşya ver ve animasyonu başlat
        local allPlayers = Players:GetPlayers()
        for _, p in ipairs(allPlayers) do
            PlayersOpeningChests[p] = true -- Claim edene kadar oyunu durduracak kişi listesine ekle
            
            local itemKey, itemInfo = rollItem(p)
            local AddItem = Events:FindFirstChild("AddItem")
            if AddItem then
                AddItem:Fire(p, itemKey, 1)
            end
            
            local PlayerUpgradedEvent = Events:FindFirstChild("PlayerUpgraded")
            if PlayerUpgradedEvent then
                PlayerUpgradedEvent:Fire(p)
            end
            
            ChestAwardedEvent:FireClient(p, itemKey, itemInfo.Rarity, 1)
        end
        
        -- Cleanup chest in workspace after animation finishes
        task.delay(2.5, function()
            model:Destroy()
        end)
    end)
    
    model.Parent = workspace
    return model
end

-- Listen to boss defeats to drop a free chest
BossDefeatedBindable.Event:Connect(function(position)
    -- Boss havada öldüyse sandık gökyüzünde kalmasın diye zemini bul
    local groundPos, normal = getValidSpawnPosition(position)
    if groundPos then
        spawnChest(groundPos, true, normal)
    else
        spawnChest(position, true)
    end
end)

-- Helper function to count active paid chests in the workspace
local function countActiveMapChests()
    local activeChests = 0
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "MapChest" and child:FindFirstChildWhichIsA("BasePart") then
            local pCenter = child:FindFirstChild("PromptCenter")
            local prompt = pCenter and pCenter:FindFirstChild("OpenPrompt")
            if not prompt then
                prompt = child:FindFirstChildWhichIsA("BasePart"):FindFirstChild("OpenPrompt")
            end
            if prompt and prompt:GetAttribute("PromptType") == "MapChest" then
                activeChests = activeChests + 1
            end
        end
    end
    return activeChests
end

-- Helper to spawn a paid chest near a random player
local function spawnRandomChest()
    local validPlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(validPlayers, p)
        end
    end
    if #validPlayers > 0 then
        local randomPlayer = validPlayers[math.random(1, #validPlayers)]
        local char = randomPlayer.Character
        local hrp = char.HumanoidRootPart
        
        local spawnPos = nil
        local spawnNormal = nil
        local found = false
        for attempt = 1, 10 do
            local angle = math.random() * math.pi * 2
            local radius = math.random(100, 200)
            local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            local rawPos = hrp.Position + offset
            
            local testPos, testNormal = getValidSpawnPosition(rawPos)
            if testPos then
                spawnPos = testPos
                spawnNormal = testNormal
                found = true
                break
            end
        end
        
        if found and spawnPos then
            spawnChest(spawnPos, false, spawnNormal)
            return true
        end
    end
    return false
end

local firstSpawnDone = false

-- Clean up chests when game ends or resets firstSpawnDone
ReplicatedStorage:GetAttributeChangedSignal("GameStarted"):Connect(function()
    if ReplicatedStorage:GetAttribute("GameStarted") == false then
        firstSpawnDone = false
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "MapChest" or child.Name == "BossChest" then
                child:Destroy()
            end
        end
    end
end)

-- Periodically spawn paid chests on the map
task.spawn(function()
    while true do
        if not firstSpawnDone then
            task.wait(2) -- Oyun başladıktan 2 saniye sonra ilk sandıkları at
        else
            task.wait(35) -- Sonrakiler 35 saniyede bir (daha hızlı)
        end
        
        if ReplicatedStorage:GetAttribute("GameStarted") and not ReplicatedStorage:GetAttribute("IsPaused") then
            if not firstSpawnDone then
                firstSpawnDone = true
                -- Spawn 2 chests immediately on start
                for i = 1, 2 do
                    local activeChests = countActiveMapChests()
                    if activeChests < 8 then
                        spawnRandomChest()
                    end
                end
            else
                local activeChests = countActiveMapChests()
                if activeChests < 8 then
                    spawnRandomChest()
                end
            end
        end
    end
end)
