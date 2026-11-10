-- ============================================================
-- SHRINE MANAGER (MegaBonk Style Altars / Sanctuaries)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Events = ReplicatedStorage:WaitForChild("Events")

local OpenShrineReward = Events:FindFirstChild("OpenShrineReward")
if not OpenShrineReward then
    OpenShrineReward = Instance.new("RemoteEvent")
    OpenShrineReward.Name = "OpenShrineReward"
    OpenShrineReward.Parent = Events
end

local SelectShrineStat = Events:FindFirstChild("SelectShrineStat")
if not SelectShrineStat then
    SelectShrineStat = Instance.new("RemoteEvent")
    SelectShrineStat.Name = "SelectShrineStat"
    SelectShrineStat.Parent = Events
end

local UpdateShrineCharge = Events:FindFirstChild("UpdateShrineCharge")
if not UpdateShrineCharge then
    UpdateShrineCharge = Instance.new("RemoteEvent")
    UpdateShrineCharge.Name = "UpdateShrineCharge"
    UpdateShrineCharge.Parent = Events
end

local MAX_ACTIVE_SHRINES = 3
local RESPAWN_COOLDOWN = 30 -- Cooldown before spawning next shrine after completion (seconds)
local CHARGE_RADIUS = 14 -- Radius of shrine zone (studs)
local CHARGE_TIME = 3.5 -- Charge time (seconds)
local DECHARGE_TIME = 2.8 -- Decharge time when players leave zone (seconds, faster gradual decay)

-- "Shrine Top" Colors
local COLOR_SHRINE_TOP_INACTIVE = Color3.fromRGB(0, 0, 0)
local COLOR_SHRINE_TOP_ACTIVE = Color3.fromRGB(31, 241, 119)

-- ============================================================
-- MEGABONK STYLE STAT POOL WITH 5 RARITY TIERS (Common -> Legendary)
-- English, Pure Text, No Icons, No Emojis
-- ============================================================
local SHRINE_RARITIES = {
    { Name = "Common",    Level = 1, Weight = 50, Color = Color3.fromRGB(180, 190, 205), Hex = "#B4BECD" },
    { Name = "Uncommon",  Level = 2, Weight = 28, Color = Color3.fromRGB(31, 241, 119),  Hex = "#1FF177" },
    { Name = "Rare",      Level = 3, Weight = 14, Color = Color3.fromRGB(60, 175, 255),  Hex = "#3CAFFF" },
    { Name = "Epic",      Level = 4, Weight = 6,  Color = Color3.fromRGB(195, 80, 255),  Hex = "#C350FF" },
    { Name = "Legendary", Level = 5, Weight = 2,  Color = Color3.fromRGB(255, 200, 50),  Hex = "#FFC832" },
}

local SHRINE_STATS_TIERS = {
    Damage = {
        Title = "DAMAGE",
        Name = "Damage",
        Description = "Permanently increases base damage of all weapons and attacks.",
        Tiers = {
            Common    = { Amount = 0.08, Display = "+8%" },
            Uncommon  = { Amount = 0.12, Display = "+12%" },
            Rare      = { Amount = 0.18, Display = "+18%" },
            Epic      = { Amount = 0.25, Display = "+25%" },
            Legendary = { Amount = 0.35, Display = "+35%" },
        }
    },
    MaxHealth = {
        Title = "MAX HEALTH",
        Name = "Max Health",
        Description = "Increases maximum health capacity and instantly heals that amount.",
        Tiers = {
            Common    = { Amount = 15, Display = "+15" },
            Uncommon  = { Amount = 25, Display = "+25" },
            Rare      = { Amount = 40, Display = "+40" },
            Epic      = { Amount = 60, Display = "+60" },
            Legendary = { Amount = 100, Display = "+100" },
        }
    },
    AttackSpeed = {
        Title = "ATTACK SPEED",
        Name = "Attack Speed",
        Description = "Reduces weapon cooldowns, allowing you to attack and fire much faster.",
        Tiers = {
            Common    = { Amount = 0.05, Display = "+5%" },
            Uncommon  = { Amount = 0.08, Display = "+8%" },
            Rare      = { Amount = 0.12, Display = "+12%" },
            Epic      = { Amount = 0.18, Display = "+18%" },
            Legendary = { Amount = 0.25, Display = "+25%" },
        }
    },
    MoveSpeed = {
        Title = "MOVE SPEED",
        Name = "Move Speed",
        Description = "Permanently increases your walking and sprinting movement speed.",
        Tiers = {
            Common    = { Amount = 0.05, Display = "+5%" },
            Uncommon  = { Amount = 0.08, Display = "+8%" },
            Rare      = { Amount = 0.12, Display = "+12%" },
            Epic      = { Amount = 0.18, Display = "+18%" },
            Legendary = { Amount = 0.25, Display = "+25%" },
        }
    },
    CritChance = {
        Title = "CRIT CHANCE",
        Name = "Crit Chance",
        Description = "Increases the chance to land devastating critical hits.",
        Tiers = {
            Common    = { Amount = 0.04, Display = "+4%" },
            Uncommon  = { Amount = 0.07, Display = "+7%" },
            Rare      = { Amount = 0.11, Display = "+11%" },
            Epic      = { Amount = 0.16, Display = "+16%" },
            Legendary = { Amount = 0.25, Display = "+25%" },
        }
    },
    CritDamage = {
        Title = "CRIT DAMAGE",
        Name = "Crit Damage",
        Description = "Greatly multiplies the bonus damage dealt by critical strikes.",
        Tiers = {
            Common    = { Amount = 0.15, Display = "+15%" },
            Uncommon  = { Amount = 0.25, Display = "+25%" },
            Rare      = { Amount = 0.40, Display = "+40%" },
            Epic      = { Amount = 0.60, Display = "+60%" },
            Legendary = { Amount = 1.00, Display = "+100%" },
        }
    },
    Regen = {
        Title = "HEALTH REGEN",
        Name = "Health Regen",
        Description = "Passively restores health every second over time.",
        Tiers = {
            Common    = { Amount = 0.25, Display = "+0.25 HP/s" },
            Uncommon  = { Amount = 0.45, Display = "+0.45 HP/s" },
            Rare      = { Amount = 0.75, Display = "+0.75 HP/s" },
            Epic      = { Amount = 1.20, Display = "+1.20 HP/s" },
            Legendary = { Amount = 2.00, Display = "+2.00 HP/s" },
        }
    },
    Magnet = {
        Title = "PICKUP RANGE",
        Name = "Pickup Range",
        Description = "Draws experience crystals and coins from a much larger distance.",
        Tiers = {
            Common    = { Amount = 0.15, Display = "+15%" },
            Uncommon  = { Amount = 0.25, Display = "+25%" },
            Rare      = { Amount = 0.40, Display = "+40%" },
            Epic      = { Amount = 0.60, Display = "+60%" },
            Legendary = { Amount = 1.00, Display = "+100%" },
        }
    },
    Area = {
        Title = "SIZE",
        Name = "Size",
        Description = "Expands the size of area abilities and attacks.",
        Tiers = {
            Common    = { Amount = 0.08, Display = "+8%" },
            Uncommon  = { Amount = 0.14, Display = "+14%" },
            Rare      = { Amount = 0.22, Display = "+22%" },
            Epic      = { Amount = 0.35, Display = "+35%" },
            Legendary = { Amount = 0.50, Display = "+50%" },
        }
    },
    ProjectileCount = {
        Title = "PROJECTILES",
        Name = "Projectile Count",
        Description = "Adds extra projectiles to a random equipped ranged weapon.",
        Tiers = {
            Common    = { Amount = 1.0, Display = "+1" },
            Uncommon  = { Amount = 1.5, Display = "+1.5" },
            Rare      = { Amount = 2.0, Display = "+2" },
            Epic      = { Amount = 2.5, Display = "+2.5" },
            Legendary = { Amount = 3.0, Display = "+3" },
        }
    }
}

local function rollShrineRarity(luck)
    luck = luck or 0
    local totalWeight = 0
    local weights = {}
    for i, r in ipairs(SHRINE_RARITIES) do
        local w = r.Weight * ((1 + luck) ^ (r.Level - 1))
        weights[i] = w
        totalWeight = totalWeight + w
    end
    local roll = math.random() * totalWeight
    local cumulative = 0
    for i, r in ipairs(SHRINE_RARITIES) do
        cumulative = cumulative + weights[i]
        if roll <= cumulative then
            return r
        end
    end
    return SHRINE_RARITIES[1]
end

local pendingShrineRewards = {} -- [player.UserId] = { ShrineId = string, Offers = table }

-- OYUNCULARI DONDUR / ÇÖZ (Upgrade ekranı sırasında hareket ve fizik kilitleme)
local function setPlayersFrozen(frozen)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.Anchored = frozen
        end
    end
end

-- Herhangi bir oyuncu hala upgrade/seçim ekranında mı kontrolü
local function isAnyUpgradeChoosing()
    for _, p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("IsChoosingUpgrade") == true then
            return true
        end
    end
    return false
end

local function pickShrineOffers(player)
    local GetPlayerData = Events:FindFirstChild("GetPlayerData")
    local pData = GetPlayerData and GetPlayerData:Invoke(player)
    local luck = ((pData and pData.Items and pData.Items.clover or 0) * 0.05) + (pData and pData.LuckBonus or 0)

    local statKeys = {}
    for k in pairs(SHRINE_STATS_TIERS) do
        table.insert(statKeys, k)
    end
    
    for i = #statKeys, 2, -1 do
        local r = math.random(1, i)
        statKeys[i], statKeys[r] = statKeys[r], statKeys[i]
    end
    
    local selected = {}
    for i = 1, 3 do
        local key = statKeys[i]
        local statDef = SHRINE_STATS_TIERS[key]
        local rarityObj = rollShrineRarity(luck)
        local tierData = statDef.Tiers[rarityObj.Name] or statDef.Tiers.Common
        
        table.insert(selected, {
            Key = key,
            Title = statDef.Title,
            Name = statDef.Name,
            Rarity = rarityObj.Name,
            RarityColor = { R = rarityObj.Color.R, G = rarityObj.Color.G, B = rarityObj.Color.B },
            RarityHex = rarityObj.Hex,
            Amount = tierData.Amount,
            AmountDisplay = tierData.Display,
            BonusDisplay = tierData.Display .. " " .. statDef.Title,
            Description = statDef.Description,
        })
    end
    return selected
end

local function offerShrineRewardToPlayer(player, shrineId)
    local SetInvulnerable = Events:FindFirstChild("SetInvulnerable")
    if SetInvulnerable then
        SetInvulnerable:Fire(player, 60)
    end
    
    local offers = pickShrineOffers(player)
    pendingShrineRewards[player.UserId] = {
        ShrineId = shrineId,
        Offers = offers
    }
    
    -- OYUNU DONDUR (Upgrade ekranındayken oyunun tamamen durmasını garanti eder)
    player:SetAttribute("IsChoosingUpgrade", true)
    ReplicatedStorage:SetAttribute("IsPaused", true)
    setPlayersFrozen(true)
    
    OpenShrineReward:FireClient(player, shrineId, offers)
end

SelectShrineStat.OnServerEvent:Connect(function(player, shrineId, statKey)
    local pending = pendingShrineRewards[player.UserId]
    if not pending or pending.ShrineId ~= shrineId then
        return
    end
    
    local chosenOffer = nil
    for _, off in ipairs(pending.Offers) do
        if off.Key == statKey then
            chosenOffer = off
            break
        end
    end
    if not chosenOffer then return end
    
    pendingShrineRewards[player.UserId] = nil
    player:SetAttribute("IsChoosingUpgrade", false)
    
    -- Başka seçim yapan yoksa ve sandık açılmıyorsa oyunu devam ettir (Unpause)
    if not isAnyUpgradeChoosing() and not ReplicatedStorage:GetAttribute("IsOpeningChest") and not ReplicatedStorage:GetAttribute("IsManualPaused") then
        ReplicatedStorage:SetAttribute("IsPaused", false)
        setPlayersFrozen(false)
    end
    
    -- İstatistiği PlayerManager içindeki ana oyuncu verisine doğrudan uygula
    local ApplyShrineStat = Events:FindFirstChild("ApplyShrineStat")
    local success, msg
    if ApplyShrineStat then
        success, msg = ApplyShrineStat:Invoke(player, statKey, chosenOffer.Amount, chosenOffer.Rarity)
    end

    if not msg or msg == "" then
        -- Fallback mesaj metni
        msg = chosenOffer.BonusDisplay or statKey
    end
    
    local ShowMessage = Events:FindFirstChild("ShowMessage")
    if ShowMessage then
        ShowMessage:FireClient(player, "Shrine: " .. tostring(msg) .. " (" .. tostring(chosenOffer.Rarity or "Common") .. ") granted!", Color3.fromRGB(31, 241, 119))
    end
end)

Players.PlayerRemoving:Connect(function(player)
    pendingShrineRewards[player.UserId] = nil
    player:SetAttribute("IsChoosingUpgrade", false)
    if not isAnyUpgradeChoosing() and not ReplicatedStorage:GetAttribute("IsOpeningChest") and not ReplicatedStorage:GetAttribute("IsManualPaused") then
        ReplicatedStorage:SetAttribute("IsPaused", false)
        setPlayersFrozen(false)
    end
end)

-- Folder to hold active shrines in workspace
local shrinesFolder = workspace:FindFirstChild("ActiveShrines")
if not shrinesFolder then
    shrinesFolder = Instance.new("Folder")
    shrinesFolder.Name = "ActiveShrines"
    shrinesFolder.Parent = workspace
end

-- Model Arama: ReplicatedStorage.Assets.Shrine, ReplicatedStorage.Assets.Shrines.Shrine veya ReplicatedStorage.Shrine
local function getShrineAsset()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if assets then
        local shrinesFolderAsset = assets:FindFirstChild("Shrines") or assets:FindFirstChild("Shrine")
        if shrinesFolderAsset then
            if shrinesFolderAsset:IsA("Model") then
                return shrinesFolderAsset
            end
            local model = shrinesFolderAsset:FindFirstChild("Shrine") or shrinesFolderAsset:FindFirstChildWhichIsA("Model")
            if model then
                return model
            end
        end
        local direct = assets:FindFirstChild("Shrine")
        if direct and direct:IsA("Model") then
            return direct
        end
    end
    if ReplicatedStorage:FindFirstChild("Shrine") and ReplicatedStorage.Shrine:IsA("Model") then
        return ReplicatedStorage.Shrine
    end
    
    -- ServerStorage fallback (kullanıcı oraya da koymuş olabilir)
    local ssAssets = ServerStorage:FindFirstChild("Assets")
    if ssAssets then
        local ssShrines = ssAssets:FindFirstChild("Shrines") or ssAssets:FindFirstChild("Shrine")
        if ssShrines then
            if ssShrines:IsA("Model") then return ssShrines end
            local ssModel = ssShrines:FindFirstChild("Shrine") or ssShrines:FindFirstChildWhichIsA("Model")
            if ssModel then return ssModel end
        end
        local directSS = ssAssets:FindFirstChild("Shrine")
        if directSS and directSS:IsA("Model") then return directSS end
    end
    if ServerStorage:FindFirstChild("Shrine") and ServerStorage.Shrine:IsA("Model") then
        return ServerStorage.Shrine
    end
    
    return nil
end

-- "Shrine Top" parçalarını / görsellerini esnek ve toleranslı şekilde bulma
local function getShrineTopElements(shrineModel)
    local elements = {}
    
    for _, desc in ipairs(shrineModel:GetDescendants()) do
        local nameClean = string.lower(string.gsub(desc.Name, "[%s_%-]", ""))
        if nameClean == "shrinetop" then
            if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
                table.insert(elements, desc)
            elseif desc:IsA("Model") or desc:IsA("Folder") then
                for _, sub in ipairs(desc:GetDescendants()) do
                    if sub:IsA("BasePart") or sub:IsA("Decal") or sub:IsA("Texture") then
                        table.insert(elements, sub)
                    end
                end
            end
        end
    end
    
    -- Fallback: Eğer tam temiz eşleşme bulunamazsa case-insensitive FindFirstChild dene
    if #elements == 0 then
        local direct = shrineModel:FindFirstChild("Shrine Top", true)
        if direct then
            if direct:IsA("BasePart") or direct:IsA("Decal") or direct:IsA("Texture") then
                table.insert(elements, direct)
            elseif direct:IsA("Model") or direct:IsA("Folder") then
                for _, sub in ipairs(direct:GetDescendants()) do
                    if sub:IsA("BasePart") or sub:IsA("Decal") or sub:IsA("Texture") then
                        table.insert(elements, sub)
                    end
                end
            end
        end
    end
    
    return elements
end

-- "Shrine Top" rengini yumuşakça (lerp) güncelleme (Neon parlama kesinlikle kaldırıldı)
local function applyShrineTopColor(elements, progress)
    local clampedProgress = math.clamp(progress, 0, 1)
    local currentColor = COLOR_SHRINE_TOP_INACTIVE:Lerp(COLOR_SHRINE_TOP_ACTIVE, clampedProgress)
    
    for _, elem in ipairs(elements) do
        if elem:IsA("BasePart") then
            elem.Color = currentColor
            elem.Material = Enum.Material.SmoothPlastic
        elseif elem:IsA("Decal") or elem:IsA("Texture") then
            elem.Color3 = currentColor
        end
    end
end

-- Kullanıcı modelini henüz eklemediyse sistemin çökmemesi için geçici zarif sunak modeli
local function createFallbackShrineModel()
    local model = Instance.new("Model")
    model.Name = "Shrine"
    
    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(4, 3, 4)
    base.Color = Color3.fromRGB(60, 65, 75)
    base.Material = Enum.Material.Slate
    base.Anchored = true
    base.CanCollide = true
    base.Parent = model
    
    local pillar = Instance.new("Part")
    pillar.Name = "Pillar"
    pillar.Size = Vector3.new(2.5, 4, 2.5)
    pillar.Position = base.Position + Vector3.new(0, 3.5, 0)
    pillar.Color = Color3.fromRGB(75, 80, 90)
    pillar.Material = Enum.Material.Cobblestone
    pillar.Anchored = true
    pillar.CanCollide = true
    pillar.Parent = model
    
    local shrineTop = Instance.new("Part")
    shrineTop.Name = "Shrine Top"
    shrineTop.Size = Vector3.new(1.8, 1.8, 1.8)
    shrineTop.Position = pillar.Position + Vector3.new(0, 3.2, 0)
    shrineTop.Color = COLOR_SHRINE_TOP_INACTIVE
    shrineTop.Material = Enum.Material.SmoothPlastic
    shrineTop.Anchored = true
    shrineTop.CanCollide = false
    shrineTop.Parent = model
    
    model.PrimaryPart = base
    return model
end

-- Üstten Işın Gönderme (Raycast) ile SADECE TAMAMEN DÜZ VE GERÇEK ZEMİNLERİ Bulma
local function findFlatSpawnPosition()
    local mapCenterPart = workspace:FindFirstChild("MapCenter") or workspace:FindFirstChild("MapCenterPart")
    local center = Vector3.new(0, 0, 0)
    local maxRadius = (Config and Config.Game and Config.Game.MaxMapRadius) or 180

    if mapCenterPart then
        center = mapCenterPart:GetPivot().Position
        local customRadius = mapCenterPart:GetAttribute("MaxMapRadius")
        if customRadius then maxRadius = customRadius end
    elseif Config and Config.Game and Config.Game.MapCenter then
        center = Config.Game.MapCenter
    end

    local maxSpawnRadius = maxRadius - 50
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local excludeList = { workspace:FindFirstChild("LobbyZones"), workspace:FindFirstChild("Enemies"), shrinesFolder }
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(excludeList, p.Character) end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "MapChest" or child.Name == "BossChest" or child.Name == "Chest" or child.Name == "Props" then
            table.insert(excludeList, child)
        end
    end
    rayParams.FilterDescendantsInstances = excludeList
    
    for attempt = 1, 45 do
        local angle = math.random() * math.pi * 2
        local dist = math.random(35, maxSpawnRadius)
        local checkX = center.X + math.cos(angle) * dist
        local checkZ = center.Z + math.sin(angle) * dist
        
        local currentOrigin = Vector3.new(checkX, 350, checkZ)
        local remainingDist = 700
        
        -- Ağaç, çalı veya görünmez parça varsa aşağıya doğru delerek gerçek zemini arayan çoklu adım
        for rayStep = 1, 8 do
            local rayDirection = Vector3.new(0, -remainingDist, 0)
            local result = workspace:Raycast(currentOrigin, rayDirection, rayParams)
            if not result or not result.Instance then break end
            
            local hitPart = result.Instance
            local normal = result.Normal
            local hitPos = result.Position
            local nameLower = string.lower(hitPart.Name)
            
            -- Havada asılı veya geçersiz parçalar (Ağaçlar, yapraklar, görünmez bloklar, triggerlar)
            local isNonSolid = (not hitPart.CanCollide) or (hitPart.Transparency > 0.6 and not hitPart:IsA("Terrain"))
            local isProp = string.find(nameLower, "tree") 
                or string.find(nameLower, "leaf") 
                or string.find(nameLower, "yaprak") 
                or string.find(nameLower, "agac") 
                or string.find(nameLower, "foliage") 
                or string.find(nameLower, "bush") 
                or string.find(nameLower, "prop") 
                or string.find(nameLower, "rock") 
                or string.find(nameLower, "kaya") 
                or string.find(nameLower, "flower")
            
            if isNonSolid or isProp then
                -- Bu parçayı hariç tut ve altından ışın atmaya devam et
                local parentModel = hitPart:FindFirstAncestorOfClass("Model")
                if parentModel and parentModel ~= workspace then
                    table.insert(excludeList, parentModel)
                else
                    table.insert(excludeList, hitPart)
                end
                rayParams.FilterDescendantsInstances = excludeList
                currentOrigin = hitPos - Vector3.new(0, 0.5, 0)
                remainingDist = math.max(10, remainingDist - (350 - hitPos.Y))
            else
                -- Katı ve collidable bir nesneye çarptık!
                -- 1. Zemin kontrolleri: Yüzey normali dik yukarı bakmalı (Normal.Y >= 0.985 eğimli yüzeyleri engeller)
                local isCompletelyFlat = normal.Y >= 0.985
                
                -- 2. Wedge (eğimli rampa) veya isimde merdiven/rampa/duvar/sınır olmamalı
                local isWedge = hitPart:IsA("WedgePart") or hitPart:IsA("CornerWedgePart")
                local isRampOrStair = string.find(nameLower, "slope") 
                    or string.find(nameLower, "ramp") 
                    or string.find(nameLower, "stair") 
                    or string.find(nameLower, "merdiven") 
                    or string.find(nameLower, "basamak")
                    or string.find(nameLower, "wall") 
                    or string.find(nameLower, "cliff") 
                    or string.find(nameLower, "border") 
                    or string.find(nameLower, "duvar") 
                    or string.find(nameLower, "sinir")
                local isBoundary = hitPart:GetAttribute("IsBoundary") == true
                
                -- 3. Diğer aktif sunaklara en az 35 stud mesafe olmalı
                local tooCloseToOtherShrine = false
                for _, otherShrine in ipairs(shrinesFolder:GetChildren()) do
                    if otherShrine:IsA("Model") then
                        local otherPos = otherShrine:GetPivot().Position
                        local flatDist = (Vector3.new(checkX, 0, checkZ) - Vector3.new(otherPos.X, 0, otherPos.Z)).Magnitude
                        if flatDist < 35 then
                            tooCloseToOtherShrine = true
                            break
                        end
                    end
                end
                
                if isCompletelyFlat and not isWedge and not isRampOrStair and not isBoundary and not tooCloseToOtherShrine then
                    return hitPos
                end
                break
            end
        end
    end
    return nil
end

-- Bir Sunak Doğurma ve Yönetme Fonksiyonu
local function spawnShrine()
    if #shrinesFolder:GetChildren() >= MAX_ACTIVE_SHRINES then
        return
    end
    
    local groundPos = findFlatSpawnPosition()
    if not groundPos then
        -- Düz alan bulunamadıysa 3 saniye sonra tekrar dene
        task.delay(3, spawnShrine)
        return
    end
    
    local shrineId = "Shrine_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000, 9999))
    local asset = getShrineAsset()
    local model
    if asset then
        model = asset:Clone()
    else
        model = createFallbackShrineModel()
    end
    
    model.Name = "Shrine"
    
    -- Parçaları sabitle (Anchored)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
        end
    end
    
    if not model.PrimaryPart then
        local bestBasePart = nil
        local lowestY = math.huge
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                local pName = string.lower(part.Name)
                if string.find(pName, "base") or string.find(pName, "bottom") or string.find(pName, "pedestal") then
                    bestBasePart = part
                    break
                end
                if part.Position.Y < lowestY then
                    lowestY = part.Position.Y
                    bestBasePart = part
                end
            end
        end
        model.PrimaryPart = bestBasePart or model:FindFirstChildWhichIsA("BasePart")
    end
    
    -- "Shrine Top" öğelerini tespit et ve rengini başlangıçta tam siyah (#000000) yap
    local topElements = getShrineTopElements(model)
    applyShrineTopColor(topElements, 0)
    
    -- Şarj durumu özelliklerini modele bağla (İstemci radyal çemberi buradan okur)
    model:SetAttribute("ChargeProgress", 0)
    model:SetAttribute("IsCharging", false)
    model:SetAttribute("IsCompleted", false)
    
    -- Modelin boyutlarını ve tabanını kusursuz hesapla (Yana kaymayı ve havada kalmayı önler)
    -- Kardinal 90 derecelik rotasyon (0°, 90°, 180°, 270°) - eğik/çarpık duruşu engeller
    local cardinalAngle = math.rad(math.random(0, 3) * 90)
    local rotationCF = CFrame.Angles(0, cardinalAngle, 0)
    model:PivotTo(CFrame.new(groundPos) * rotationCF)
    
    -- Bu rotasyondaki gerçek Bounding Box sınırlarını al
    local bboxCFrame, bboxSize = model:GetBoundingBox()
    local modelHeight = bboxSize.Y
    local lowestPointY = bboxCFrame.Position.Y - (modelHeight / 2)
    
    -- Modelin tabanını zemin Y'sine, merkezini tam groundPos X ve Z hizasına kusursuz oturt:
    local yShift = groundPos.Y - lowestPointY
    local xShift = groundPos.X - bboxCFrame.Position.X
    local zShift = groundPos.Z - bboxCFrame.Position.Z
    
    local targetPivotCF = model:GetPivot() + Vector3.new(xShift, yShift, zShift)
    model:PivotTo(targetPivotCF)
    
    -- Nihai doğru hedef pozisyon ve CFrame
    local finalBBoxCF, finalBBoxSize = model:GetBoundingBox()
    local targetCFrame = model:GetPivot()
    local targetPos = targetCFrame.Position
    local topY = finalBBoxCF.Position.Y + (finalBBoxSize.Y / 2) + 1.2
    local centerPos = Vector3.new(finalBBoxCF.Position.X, topY, finalBBoxCF.Position.Z)
    
    -- Sunulan sunağın tam merkezinin üstünde sabit duracak görünmez ChargeAnchor oluştur (Model ile kaynaklı)
    local chargeAnchor = Instance.new("Part")
    chargeAnchor.Name = "ChargeAnchor"
    chargeAnchor.Size = Vector3.new(0.4, 0.4, 0.4)
    chargeAnchor.CFrame = CFrame.new(centerPos)
    chargeAnchor.Transparency = 1
    chargeAnchor.CanCollide = false
    chargeAnchor.CanQuery = false
    chargeAnchor.CanTouch = false
    chargeAnchor.CastShadow = false
    chargeAnchor.Anchored = false
    
    local anchorWeld = Instance.new("WeldConstraint")
    anchorWeld.Part0 = model.PrimaryPart
    anchorWeld.Part1 = chargeAnchor
    anchorWeld.Parent = chargeAnchor
    chargeAnchor.Parent = model

    -- Şarj Alanı Baloncuğu (Charge Zone Bubble - 14 stud yarıçap = 28 stud küre)
    local bubblePart = Instance.new("Part")
    bubblePart.Name = "ChargeZoneBubble"
    bubblePart.Shape = Enum.PartType.Ball
    bubblePart.Size = Vector3.new(CHARGE_RADIUS * 2, CHARGE_RADIUS * 2, CHARGE_RADIUS * 2)
    bubblePart.CFrame = CFrame.new(finalBBoxCF.Position.X, groundPos.Y, finalBBoxCF.Position.Z)
    bubblePart.Color = Color3.fromRGB(31, 241, 119)
    bubblePart.Material = Enum.Material.ForceField
    bubblePart.Transparency = 1 -- İstemci yaklaşınca dinamik olarak belirecek
    bubblePart.CanCollide = false
    bubblePart.CanTouch = false
    bubblePart.CanQuery = false
    bubblePart.CastShadow = false
    bubblePart.Anchored = false
    
    local bubbleWeld = Instance.new("WeldConstraint")
    bubbleWeld.Part0 = model.PrimaryPart
    bubbleWeld.Part1 = bubblePart
    bubbleWeld.Parent = bubblePart
    bubblePart.Parent = model

    -- Başlangıçta yerin tamamen altında doğar
    local startPos = targetPos - Vector3.new(0, modelHeight + 3, 0)
    model:PivotTo(CFrame.new(startPos) * targetCFrame.Rotation)
    model.Parent = shrinesFolder
    
    -- ========================================================
    -- 1. YERDEN ÇIKIŞ ANİMASYONU (Dikey, Sarsıntısız ve Kusursuz)
    -- ========================================================
    local emergeDuration = 1.4
    local emergeElapsed = 0
    
    while emergeElapsed < emergeDuration do
        local dt = RunService.Heartbeat:Wait()
        if not ReplicatedStorage:GetAttribute("IsPaused") then
            emergeElapsed = emergeElapsed + dt
            local progress = math.min(emergeElapsed / emergeDuration, 1.0)
            -- Easing (QuadOut)
            local ease = 1 - (1 - progress) ^ 2
            local currentY = startPos.Y + (targetPos.Y - startPos.Y) * ease
            
            -- Sadece dikey eksende pürüzsüz yükselme (yana kayma/eğilme yok)
            local currentCFrame = CFrame.new(targetPos.X, currentY, targetPos.Z) * targetCFrame.Rotation
            model:PivotTo(currentCFrame)
        end
    end
    
    model:PivotTo(targetCFrame)
    chargeAnchor.CFrame = CFrame.new(centerPos)
    bubblePart.CFrame = CFrame.new(finalBBoxCF.Position.X, groundPos.Y, finalBBoxCF.Position.Z)
    
    -- ========================================================
    -- 2. ŞARJ VE İNTERAKTİF DÖNGÜ (Neon küre/zemin tamamen kaldırıldı)
    -- ========================================================
    local chargeProgress = 0
    local isCharging = false
    local isCompleted = false
    local lastHeartbeat = os.clock()
    
    local chargeConn
    chargeConn = RunService.Heartbeat:Connect(function()
        if isCompleted or not model.Parent then
            if chargeConn then chargeConn:Disconnect() end
            return
        end
        
        local now = os.clock()
        local dt = math.min(now - lastHeartbeat, 0.1)
        lastHeartbeat = now
        
        -- Oyun durmuşsa şarj ilerlemesini dondur
        if ReplicatedStorage:GetAttribute("IsPaused") == true then
            return
        end
        
        -- Çember içinde hayatta olan en az bir oyuncu var mı?
        local playerInRadius = false
        local playersInside = {}
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 and not char:GetAttribute("IsDowned") then
                local dist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(groundPos.X, 0, groundPos.Z)).Magnitude
                if dist <= CHARGE_RADIUS and math.abs(hrp.Position.Y - groundPos.Y) <= 10 then
                    playerInRadius = true
                    table.insert(playersInside, player)
                end
            end
        end
        
        if playerInRadius then
            isCharging = true
            chargeProgress = math.min(1.0, chargeProgress + (dt / CHARGE_TIME))
            applyShrineTopColor(topElements, chargeProgress)
        else
            isCharging = false
            if chargeProgress > 0 then
                chargeProgress = math.max(0, chargeProgress - (dt / DECHARGE_TIME))
                applyShrineTopColor(topElements, chargeProgress)
            end
        end
        
        -- Model özniteliklerini güncelle (Model üzerindeki radyal bar doğrudan bunu okur)
        model:SetAttribute("ChargeProgress", chargeProgress)
        model:SetAttribute("IsCharging", isCharging)
        
        -- ========================================================
        -- 3. ŞARJ TAMAMLANDI (%100) -> ÖDÜLLER VE AŞAĞI BATIŞ
        -- ========================================================
        if chargeProgress >= 1.0 and not isCompleted then
            isCompleted = true
            if chargeConn then chargeConn:Disconnect() end
            
            model:SetAttribute("ChargeProgress", 1.0)
            model:SetAttribute("IsCharging", false)
            model:SetAttribute("IsCompleted", true)
            
            -- "Shrine Top" tam aktif renkte kalır
            applyShrineTopColor(topElements, 1.0)
            
            -- Çemberdeki oyuncuları belirle
            local eligiblePlayers = {}
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 and not char:GetAttribute("IsDowned") then
                    local dist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(groundPos.X, 0, groundPos.Z)).Magnitude
                    if dist <= (CHARGE_RADIUS + 3) and math.abs(hrp.Position.Y - groundPos.Y) <= 10 then
                        table.insert(eligiblePlayers, p)
                    end
                end
            end
            if #eligiblePlayers == 0 and #playersInside > 0 then
                eligiblePlayers = playersInside
            end
            
            -- Stat seçimi sun ve oyunu dondur:
            for _, p in ipairs(eligiblePlayers) do
                offerShrineRewardToPlayer(p, shrineId)
            end
            
            -- Oyuncular kart seçimini tamamlayana kadar sunak yerinde bekler (oyun durmuşken aniden kaybolmaz)
            local waitStart = os.clock()
            while isAnyUpgradeChoosing() and (os.clock() - waitStart < 60) do
                task.wait(0.2)
            end
            
            task.wait(0.8)
            
            -- ========================================================
            -- 4. AŞAĞIYA DOĞRU DİKEY VE PÜRÜZSÜZ KAYBOLMA
            -- ========================================================
            local sinkDuration = 1.3
            local sinkElapsed = 0
            
            while sinkElapsed < sinkDuration do
                local dt = RunService.Heartbeat:Wait()
                if not ReplicatedStorage:GetAttribute("IsPaused") then
                    sinkElapsed = sinkElapsed + dt
                    local progress = math.min(sinkElapsed / sinkDuration, 1.0)
                    local ease = progress ^ 2 -- QuadIn
                    local currentY = targetPos.Y - (modelHeight + 3) * ease
                    
                    local currentCFrame = CFrame.new(targetPos.X, currentY, targetPos.Z) * targetCFrame.Rotation
                    model:PivotTo(currentCFrame)
                end
            end
            
            model:Destroy()
            
            -- ========================================================
            -- 5. 30 SANİYE BEKLEME SÜRESİ SONRASINDA YENİ SUNAK ÇIKMASI
            -- ========================================================
            task.delay(RESPAWN_COOLDOWN, function()
                local gameStarted = ReplicatedStorage:GetAttribute("GameStarted")
                if gameStarted ~= false then
                    spawnShrine()
                end
            end)
        end
    end)
end

-- Tüm aktif sunakları temizle
local function clearAllShrines()
    shrinesFolder:ClearAllChildren()
end

-- Başlangıç döngüsü: Haritada 3 sunak olana kadar doğur
local function maintainShrines()
    local currentCount = #shrinesFolder:GetChildren()
    local needed = MAX_ACTIVE_SHRINES - currentCount
    for i = 1, needed do
        task.spawn(function()
            task.wait((i - 1) * 1.5)
            spawnShrine()
        end)
    end
end

-- Harita oluşumunu bekleme helper'ı
local function ensureMapReady()
    if not ReplicatedStorage:GetAttribute("MapGenerated") then
        ReplicatedStorage:GetAttributeChangedSignal("MapGenerated"):Wait()
    end
    task.wait(0.5)
end

-- Oyun durumu değiştiğinde sunakları yönet
ReplicatedStorage:GetAttributeChangedSignal("GameStarted"):Connect(function()
    local started = ReplicatedStorage:GetAttribute("GameStarted")
    if started == true then
        -- DÜZELTME: Oyuna başlandığında var olan sunaklar YOK EDİLMEZ!
        -- Sadece eksik sunak varsa tamamlanır.
        maintainShrines()
    elseif started == false then
        -- Sadece maç tamamen bittiğinde veya lobiye dönüldüğünde temizlenir
        clearAllShrines()
    end
end)

-- İlk başlatma (Harita üretimi tamamlandığında 3 sunak hazırla)
task.spawn(function()
    ensureMapReady()
    maintainShrines()
end)
