local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PositionUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PositionUtil"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))
local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))
local Events = ReplicatedStorage:WaitForChild("Events")
local SpawnGemEvent = Events:WaitForChild("SpawnGemEvent")
local PlayBushBreakEvent = Events:FindFirstChild("PlayBushBreak") or Instance.new("RemoteEvent", Events)
PlayBushBreakEvent.Name = "PlayBushBreak"

local PotsFolder = workspace:FindFirstChild("Pots")
if not PotsFolder then
    PotsFolder = Instance.new("Folder")
    PotsFolder.Name = "Pots"
    PotsFolder.Parent = workspace
end

local SPAWN_COOLDOWN = 25.0 -- 25 saniyede bir yeni pot kontrolü

local function getMaxPots(minutes)
    if minutes < 2 then
        return 8 -- Erken oyunda (0-2 dk) haritada en fazla 8 pot
    elseif minutes < 5 then
        return 14 -- Orta oyunda (2-5 dk) en fazla 14 pot
    elseif minutes < 8 then
        return 22 -- Geç oyunda en fazla 22 pot
    else
        return 28 -- Son dalgalarda en fazla 28 pot
    end
end

local MAP_CENTER = Config.Game.MapCenter or Vector3.new(54.219, 0.767, 200.954)
local MAX_MAP_RADIUS = Config.Game.MaxMapRadius or 330

-- Helper function to count active pots
local function countPots()
    local count = 0
    for _, child in ipairs(PotsFolder:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("OpenPrompt") then
            count = count + 1
        end
    end
    return count
end

local function hasEngineerPlayer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("SelectedClassId") == "Engineer" or p:GetAttribute("HasTurret") == true then
            return true
        end
    end
    return false
end

-- Helper to create a fallback pot model if assets don't exist
local function createFallbackPot(potType)
    local model = Instance.new("Model")
    model.Name = potType .. "Pot"
    
    local part = Instance.new("Part")
    part.Name = "MainPart"
    part.Shape = Enum.PartType.Cylinder
    
    if potType == "Silver" then
        part.Size = Vector3.new(2.8, 2.2, 2.2)
        part.Color = Color3.fromRGB(205, 215, 230) -- Shiny metallic silver
        part.Material = Enum.Material.Metal
        part.Reflectance = 0.35
    elseif potType == "Small" then
        part.Size = Vector3.new(2.2, 1.8, 1.8)
        part.Color = Color3.fromRGB(180, 100, 60) -- Terracotta brown
        part.Material = Enum.Material.Slate
    else
        part.Size = Vector3.new(3.8, 3.2, 3.2)
        part.Color = Color3.fromRGB(150, 80, 50) -- Darker terracotta
        part.Material = Enum.Material.Slate
    end
    
    -- Stand upright (rotate cylinder)
    part.CFrame = CFrame.Angles(0, 0, math.pi / 2)
    part.Anchored = true
    part.CanCollide = true
    part.Parent = model
    
    model.PrimaryPart = part
    
    -- Add a small collar on top to make it look like a pot
    local collar = Instance.new("Part")
    collar.Name = "Collar"
    collar.Shape = Enum.PartType.Cylinder
    if potType == "Silver" then
        collar.Size = Vector3.new(0.5, 2.4, 2.4)
        collar.Color = Color3.fromRGB(225, 235, 245)
        collar.Material = Enum.Material.Metal
        collar.Reflectance = 0.4
    elseif potType == "Small" then
        collar.Size = Vector3.new(0.4, 2.0, 2.0)
        collar.Color = part.Color
        collar.Material = part.Material
    else
        collar.Size = Vector3.new(0.6, 3.5, 3.5)
        collar.Color = part.Color
        collar.Material = part.Material
    end
    collar.Anchored = true
    collar.CanCollide = true
    collar.CFrame = part.CFrame * CFrame.new(part.Size.X / 2, 0, 0)
    collar.Parent = model
    
    -- Weld them
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = part
    weld.Part1 = collar
    weld.Parent = part
    
    collar.Anchored = false
    
    return model
end

-- Spawn a breaking particle and sound effect (vibrant green debris on open)
local function playBreakEffect(position, potColor, triggeringPlayer)
    -- Diğer oyuncuların da duyması için RemoteEvent tetikle (çalıyı kıran oyuncu bunu istemcide anında duydu)
    if PlayBushBreakEvent then
        PlayBushBreakEvent:FireAllClients(position, triggeringPlayer)
    end

    task.spawn(function()
        for i = 1, 6 do
            local fragment = Instance.new("Part")
            fragment.Size = Vector3.new(0.4, 0.4, 0.4)
            fragment.Color = potColor or Color3.fromRGB(50, 220, 100) -- Vibrant green particles on pickup
            fragment.Material = Enum.Material.Neon -- Make them glow nicely!
            fragment.CanCollide = true
            fragment.CFrame = CFrame.new(position + Vector3.new(math.random(-1,1)/2, 0.5, math.random(-1,1)/2))
            
            local force = Vector3.new(
                math.random(-15, 15),
                math.random(15, 25),
                math.random(-15, 15)
            )
            fragment.AssemblyLinearVelocity = force
            fragment.Parent = workspace
            
            -- Smoothly fade out transparency (0.6 seconds total)
            local fadeTime = 0.5
            local tweenInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tween = game:GetService("TweenService"):Create(fragment, tweenInfo, {Transparency = 1})
            
            task.delay(0.1, function()
                if fragment and fragment.Parent then
                    tween:Play()
                end
            end)
            
            Debris:AddItem(fragment, fadeTime + 0.15)
        end
    end)
end

-- Robust helper to search for user models in all possible locations
local function findUserPotModel(potType)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local possibleNames = {
        potType .. "Pot",
        potType,
        potType .. " Pot",
        potType .. "_Pot",
        string.lower(potType) .. "pot",
        string.lower(potType) .. " pot",
        string.lower(potType) .. "_pot",
        string.lower(potType)
    }
    
    local searchContainers = {}
    if assets then
        local mapAssetsFolder = assets:FindFirstChild("MapAssets")
        if mapAssetsFolder then table.insert(searchContainers, mapAssetsFolder) end
        local potsFolder = assets:FindFirstChild("Pots") or assets:FindFirstChild("Pot")
        if potsFolder then table.insert(searchContainers, potsFolder) end
        table.insert(searchContainers, assets)
    end
    if ReplicatedStorage:FindFirstChild("MapAssets") then
        table.insert(searchContainers, ReplicatedStorage.MapAssets)
    end
    if workspace:FindFirstChild("MapAssets") then
        table.insert(searchContainers, workspace.MapAssets)
    end
    table.insert(searchContainers, ReplicatedStorage)

    local serverStorage = game:GetService("ServerStorage")
    local ssAssets = serverStorage:FindFirstChild("Assets")
    if ssAssets then table.insert(searchContainers, ssAssets) end
    local ssMapAssets = ssAssets and ssAssets:FindFirstChild("MapAssets") or serverStorage:FindFirstChild("MapAssets")
    if ssMapAssets then table.insert(searchContainers, ssMapAssets) end
    local ssPots = serverStorage:FindFirstChild("Pots") or serverStorage:FindFirstChild("Pot")
    if ssPots then table.insert(searchContainers, ssPots) end
    table.insert(searchContainers, serverStorage)

    for _, container in ipairs(searchContainers) do
        for _, name in ipairs(possibleNames) do
            local found = container:FindFirstChild(name)
            if found and found:IsA("Model") then
                return found
            end
        end
    end
    
    return nil
end

-- Helper to forward declare spawnRandomPotOnMap
local spawnRandomPotOnMap

local function spawnPot(position, potType, normal)
    local model
    
    -- Try to find the user's model
    local sourceModel = findUserPotModel(potType)
    
    if sourceModel then
        model = sourceModel:Clone()
    else
        model = createFallbackPot(potType)
    end
    
    model:SetAttribute("IsPot", true)
    model:SetAttribute("PotType", potType)
    
    local groundPosition = position - Vector3.new(0, 3, 0)
    
    -- Pots should spawn completely upright to avoid deformation/clipping on stairs and slopes
    local useNormal = Vector3.new(0, 1, 0)
    local baseCFrame = CFrame.new(groundPosition)
    
    model:PivotTo(baseCFrame)
    
    -- Adjust height so model base sits exactly on ground
    local bboxCFrame, bboxSize = model:GetBoundingBox()
    local localBottom = bboxCFrame.Position - useNormal * (bboxSize.Y / 2)
    local offset = groundPosition - localBottom
    
    model:PivotTo(model:GetPivot() + offset)
    
    -- Apply subtle highlight glow around the pot model
    local highlight = Instance.new("Highlight")
    highlight.Name = "PotHighlight"
    highlight.OutlineColor = potType == "Silver" and Color3.fromRGB(205, 220, 245) or Color3.fromRGB(100, 240, 100)
    highlight.OutlineTransparency = 0.45 -- Make it look thin and subtle
    highlight.FillTransparency = 1 -- Fully transparent inside
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded -- Let the highlight be hidden by walls and obstacles
    highlight.Adornee = model
    highlight.Parent = model
    
    -- Interaction Prompt (ProximityPrompt styled like Chests)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "OpenPrompt"
    prompt.ObjectText = potType == "Small" and "Small Pot" or (potType == "Silver" and "Silver Pot" or "Large Pot")
    prompt.ActionText = "Open"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0 -- Instant opening
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    
    -- Use the Custom Chest-like Prompt Style
    prompt.Style = Enum.ProximityPromptStyle.Custom
    prompt:SetAttribute("PromptType", "Pot")
    
    -- Arayüzün tam ortada durması için modelin geometrik merkezini hesapla ve görünmez bir merkez parçası oluştur
    local centerPart = Instance.new("Part")
    centerPart.Name = "PromptCenter"
    centerPart.Size = Vector3.new(0.1, 0.1, 0.1)
    centerPart.Transparency = 1
    centerPart.CanCollide = false
    centerPart.CanTouch = false
    centerPart.CanQuery = false
    centerPart.Massless = true
    centerPart.CFrame = bboxCFrame
    centerPart.Parent = model
    
    -- Hareket ve animasyon durumlarında yerinin kaymaması için ana gövdeye kaynak yap (Weld)
    local rootPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if rootPart and rootPart ~= centerPart then
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = rootPart
        weld.Part1 = centerPart
        weld.Parent = centerPart
        centerPart.Anchored = false
    else
        centerPart.Anchored = true
    end
    
    prompt.Parent = centerPart
    
    -- Trigger connection
    prompt.Triggered:Connect(function(player)
        if model:GetAttribute("Opening") or ReplicatedStorage:GetAttribute("IsPaused") or player:GetAttribute("IsChoosingUpgrade") then
            return
        end
        model:SetAttribute("Opening", true)
        prompt.Enabled = false
        
        local potPos = model:GetPivot().Position
        
        -- Play physical break visual with green neon glowing debris fragments (or silver for silver pot)!
        local breakColor = potType == "Silver" and Color3.fromRGB(205, 220, 245) or Color3.fromRGB(50, 220, 100)
        playBreakEffect(potPos, breakColor, player)
        
        -- Piggy Bank görevi ilerlemesi: 50 Pot / Bush kır
        ProgressionManager.AddProgress(player, "piggy_bank", 1)
        
        -- XP Scroll görevi ilerlemesi: Tek bir maçta / run'da 20 pot kır
        local matchPots = (player:GetAttribute("MatchPotsBroken") or 0) + 1
        player:SetAttribute("MatchPotsBroken", matchPots)
        ProgressionManager.UpdateProgress(player, "XPBoost", matchPots)
        
        -- Piggy Bank eşyası bonusu: Pot/Bushlardan kazanılan XP ve Altını her stack için +%15 artırır
        local GetPlayerData = Events:FindFirstChild("GetPlayerData")
        local pData = GetPlayerData and GetPlayerData:Invoke(player)
        local piggyCount = pData and pData.Items and pData.Items.piggy_bank or 0
        local potBoost = 1 + (piggyCount * 0.15)
        
        -- Get game time elapsed and calculate scaling multiplier
        local seconds = math.max(0, ReplicatedStorage:FindFirstChild("GameTime") and ReplicatedStorage.GameTime.Value or 0)
        local minutes = seconds / 60
        -- Erken oyunda aşırı level atlamayı ve zenginleşmeyi önleyen, geç oyunda ise sürü yoğunluğuna denk artan kademeli çarpan:
        -- 0. dk: 0.35x, 1. dk: 0.65x, 2. dk: 1.0x, 5. dk: ~3.5x, 8. dk: ~15x, 10. dk: ~30x
        local timeMultiplier
        if minutes < 2 then
            timeMultiplier = 0.35 + (minutes * 0.30)
        elseif minutes < 5 then
            timeMultiplier = 1.0 + ((minutes - 2) * 0.85)
        else
            timeMultiplier = 3.55 + ((minutes - 5) ^ 1.7) * 1.8
        end

        -- Değere göre doğru kristal türünü belirle (büyük değerlerde dev kristaller düşsün)
        local function getGemTypeForXP(val)
            if val >= 150 then
                return "Ultra"
            elseif val >= 25 then
                return "Big"
            elseif val >= 6 then
                return "Medium"
            else
                return "Basic"
            end
        end
        
        -- Spawn Loot (xp/gold/silver)
        if potType == "Silver" then
            -- Geç oyunda gümüş potlar 2-4 adet gümüş düşürebilir
            local silverVal = (minutes >= 5) and math.random(2, 4) or math.random(1, 2)
            SpawnGemEvent:Fire(potPos, "Silver", silverVal)
        elseif potType == "Small" then
            local rand = math.random()
            if rand < 0.40 then
                local baseGold = math.random(3, 5)
                local scaledGold = math.max(1, math.floor(baseGold * timeMultiplier * potBoost))
                SpawnGemEvent:Fire(potPos, "Coin", scaledGold)
            elseif rand < 0.80 then
                local baseXP = math.random(4, 7)
                local scaledXP = math.max(2, math.floor(baseXP * timeMultiplier * potBoost))
                SpawnGemEvent:Fire(potPos, getGemTypeForXP(scaledXP), scaledXP)
            else
                local baseXP = math.random(8, 12)
                local scaledXP = math.max(3, math.floor(baseXP * timeMultiplier * potBoost))
                SpawnGemEvent:Fire(potPos, getGemTypeForXP(scaledXP), scaledXP)
            end

            -- Normal Çalı / Pot Hurda: Sadece Engineer varsa (%65) - dakikaya göre ölçeklenir
            if hasEngineerPlayer() and math.random() < 0.65 then
                local scrapScale = math.min(3.0, 0.4 + (minutes * 0.25))
                local scrapVal = math.max(3, math.floor(math.random(10, 14) * scrapScale))
                local scrapPos = potPos + Vector3.new(math.random(-1,1), 0.2, math.random(-1,1))
                SpawnGemEvent:Fire(scrapPos, "Scrap", scrapVal)
            end
        else
            -- Büyük / Altın Çalı
            local rand = math.random()
            -- Geç oyunda (5. dk ve sonrası) hem Altın hem de devasa XP düşürme şansı (%35)
            local dropsBoth = (minutes >= 5) and (math.random() < 0.35)

            if rand < 0.35 or dropsBoth then
                local baseGold = math.random(8, 12)
                local scaledGold = math.max(2, math.floor(baseGold * timeMultiplier * potBoost))
                local goldPos = potPos + Vector3.new(math.random(-1, 1), 0.2, math.random(-1, 1))
                SpawnGemEvent:Fire(goldPos, "Coin", scaledGold)
            end

            if rand >= 0.35 or dropsBoth then
                local xpRoll = math.random()
                local baseXP
                if xpRoll < 0.55 then
                    baseXP = 16
                elseif xpRoll < 0.90 then
                    baseXP = 28
                else
                    baseXP = 45 -- Büyük Jackpot!
                end
                local scaledXP = math.max(4, math.floor(baseXP * timeMultiplier * potBoost))
                SpawnGemEvent:Fire(potPos, getGemTypeForXP(scaledXP), scaledXP)
            end

            -- Altın Çalı / Büyük Pot Hurda: Sadece Engineer varsa (%85) - dakikaya göre ölçeklenir
            if hasEngineerPlayer() and math.random() < 0.85 then
                local scrapScale = math.min(3.0, 0.4 + (minutes * 0.25))
                local scrapVal = math.max(6, math.floor(math.random(20, 26) * scrapScale))
                local scrapPos = potPos + Vector3.new(math.random(-1,1), 0.2, math.random(-1,1))
                SpawnGemEvent:Fire(scrapPos, "Scrap", scrapVal)
            end
        end
        
        -- Vakum gücü düşme ihtimali (Geç oyunda %2'den %5.5'e kadar artar, yerdeki devasa küreleri çeker)
        local vacuumChance = math.min(0.055, 0.02 + (minutes * 0.004))
        if math.random() < vacuumChance then
            SpawnGemEvent:Fire(potPos, "Vacuum")
        end
        
        model:Destroy()

        -- Erken oyunda haritayı potla doldurmamak için yeniden doğma şansını kısıtla
        local respawnChance = (minutes < 2) and 0.20 or ((minutes < 5) and 0.45 or 0.70)
        if math.random() < respawnChance then
            if countPots() < getMaxPots(minutes) then
                spawnRandomPotOnMap(false, 120)
            end
        end
    end)
    
    model.Parent = PotsFolder
    
    -- Ensure everything is anchored and collidable (if user forgot in Studio)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = true
        end
    end
    
    return model
end

-- Helper to find a completely random valid location on the map, far from players
spawnRandomPotOnMap = function(ignorePlayerProximity, minPlayerDistance)
    local attempts = 0
    local minDistance = minPlayerDistance or 60
    while attempts < 25 do
        attempts = attempts + 1
        
        -- Choose a random position on the map
        local angle = math.random() * math.pi * 2
        local dist = math.random(15, MAX_MAP_RADIUS - 15)
        local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
        local targetPos = MAP_CENTER + offset
        
        -- Ensure NOT near any player (distance > minDistance studs) - unless ignorePlayerProximity is active
        local tooCloseToPlayer = false
        if not ignorePlayerProximity then
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if (hrp.Position - targetPos).Magnitude < minDistance then
                        tooCloseToPlayer = true
                        break
                    end
                end
            end
        end
        
        if not tooCloseToPlayer then
            local groundPos, normal = PositionUtil.getValidSpawnPosition(targetPos, Config, PotsFolder)
            if groundPos then
                -- Check proximity to other pots
                local tooCloseToOtherPot = false
                for _, otherPot in ipairs(PotsFolder:GetChildren()) do
                    if (otherPot:GetPivot().Position - groundPos).Magnitude < 15 then
                        tooCloseToOtherPot = true
                        break
                    end
                end
                
                if not tooCloseToOtherPot then
                    local sec = math.max(0, ReplicatedStorage:FindFirstChild("GameTime") and ReplicatedStorage.GameTime.Value or 0)
                    local mins = sec / 60
                    local rand = math.random()
                    local potType
                    if mins < 2 then
                        -- Erken oyunda (0-2 dk) neredeyse tamamen Küçük pot
                        if rand < 0.88 then
                            potType = "Small"
                        elseif rand < 0.98 then
                            potType = "Large"
                        else
                            potType = "Silver"
                        end
                    elseif mins < 5 then
                        -- Orta oyun (2-5 dk)
                        if rand < 0.75 then
                            potType = "Small"
                        elseif rand < 0.95 then
                            potType = "Large"
                        else
                            potType = "Silver"
                        end
                    else
                        -- Geç oyun (5+ dk)
                        if rand < 0.60 then
                            potType = "Small"
                        elseif rand < 0.92 then
                            potType = "Large"
                        else
                            potType = "Silver"
                        end
                    end
                    spawnPot(groundPos, potType, normal)
                    return true
                end
            end
        end
    end
    return false
end

-- Spawns the initial batch of pots across the map
local function spawnInitialPots()
    local potsToSpawn = 8 -- Erken oyun için başlangıç pot sayısı azaltıldı (24 -> 8)
    for i = 1, potsToSpawn do
        spawnRandomPotOnMap(true) -- ignorePlayerProximity is true on start
    end
end

-- Periodically spawn pots when game is active
task.spawn(function()
    while true do
        task.wait(SPAWN_COOLDOWN)
        
        if ReplicatedStorage:GetAttribute("GameStarted") == true and not ReplicatedStorage:GetAttribute("IsPaused") then
            local sec = math.max(0, ReplicatedStorage:FindFirstChild("GameTime") and ReplicatedStorage.GameTime.Value or 0)
            local mins = sec / 60
            local maxAllowed = getMaxPots(mins)
            local currentCount = countPots()
            if currentCount < maxAllowed then
                spawnRandomPotOnMap()
                if mins >= 5 and (currentCount + 1 < math.floor(maxAllowed * 0.65)) then
                    spawnRandomPotOnMap()
                end
            end
        end
    end
end)

-- Clean up pots when game ends
ReplicatedStorage:GetAttributeChangedSignal("GameStarted"):Connect(function()
    if ReplicatedStorage:GetAttribute("GameStarted") == false then
        PotsFolder:ClearAllChildren()
    end
end)

-- Spawn initial pots as soon as map generation is complete
task.spawn(function()
    if not ReplicatedStorage:GetAttribute("MapGenerated") then
        ReplicatedStorage:GetAttributeChangedSignal("MapGenerated"):Wait()
    end
    spawnInitialPots()
end)
