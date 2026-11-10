local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local WeaponSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponSystem"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))

local Events = ReplicatedStorage:WaitForChild("Events")
local GetPlayerData = Events:WaitForChild("GetPlayerData")
local CombatEvent = Events:WaitForChild("CombatEvent")
local WeaponCooldownEvent = Events:FindFirstChild("WeaponCooldown") or Instance.new("RemoteEvent", Events)
WeaponCooldownEvent.Name = "WeaponCooldown"

local SetAimTargetEvent = Events:FindFirstChild("SetAimTarget") or Instance.new("UnreliableRemoteEvent", Events)
SetAimTargetEvent.Name = "SetAimTarget"

local UpdateAimSettingsEvent = Events:FindFirstChild("UpdateAimSettings") or Instance.new("RemoteEvent", Events)
UpdateAimSettingsEvent.Name = "UpdateAimSettings"

local PlayerWalkDirections = {}

SetAimTargetEvent.OnServerEvent:Connect(function(player, walkDir)
    if not player then return end
    if typeof(walkDir) == "Vector3" and walkDir.Magnitude > 0.05 then
        PlayerWalkDirections[player.UserId] = Vector3.new(walkDir.X, 0, walkDir.Z).Unit
    else
        PlayerWalkDirections[player.UserId] = nil
    end
end)

local function getPlayerWalkDirection(player, hrp)
    local sentDir = player and PlayerWalkDirections[player.UserId]
    if sentDir and sentDir.Magnitude > 0.1 then
        return sentDir
    end
    local char = player and player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.1 then
        return Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z).Unit
    end
    if hrp then
        local vel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
        if vel.Magnitude > 1.2 then
            return vel.Unit
        end
        local look = hrp.CFrame.LookVector
        return Vector3.new(look.X, 0, look.Z).Unit
    end
    return Vector3.new(0, 0, -1)
end

UpdateAimSettingsEvent.OnServerEvent:Connect(function(player, enabled, strength, smartAim)
    if not player then return end
    if typeof(enabled) == "boolean" then
        player:SetAttribute("AimAssistEnabled", enabled)
    end
    if typeof(strength) == "number" then
        player:SetAttribute("AimAssistStrength", math.clamp(strength, 0, 100))
    end
    if typeof(smartAim) == "boolean" then
        player:SetAttribute("SmartAimEnabled", smartAim)
    end
end)


local function delayWithPause(duration, callback)
    task.spawn(function()
        local remaining = duration
        while remaining > 0 do
            local dt = task.wait()
            if not ReplicatedStorage:GetAttribute("IsPaused") then
                remaining = remaining - dt
            end
        end
        callback()
    end)
end

local function getEnemyPosition(enemy)
    if not enemy then return Vector3.zero end
    if enemy:IsA("BasePart") then
        return enemy.Position
    end
    if enemy:IsA("Model") then
        local torso = enemy:FindFirstChild("UpperTorso") or enemy:FindFirstChild("Torso") or enemy:FindFirstChild("HumanoidRootPart")
        if torso then
            return torso.Position
        end
    end
    local enemyData = _G.ActiveEnemies and _G.ActiveEnemies[enemy]
    if enemyData then
        local scale = enemyData.Scale or 1.0
        return enemyData.Position + Vector3.new(0, scale * 1.7, 0)
    end
    return enemy:GetPivot().Position
end

local function isEnemyTargetable(enemy)
    if not enemy or not enemy.Parent then return false end
    local isEmerging = enemy:GetAttribute("IsEmerging")
    if isEmerging then
        local spawnTime = enemy:GetAttribute("SpawnTime")
        local duration = enemy:GetAttribute("EmergingDuration") or 1.0
        if spawnTime and (os.clock() - spawnTime) < (duration * 0.35) then
            return false
        end
    end
    return true
end

local getPlayerDamageMultiplier
local dealDamageWithLifesteal

-- Manuel Saldırı (Sword vb.) İşleyicisi
CombatEvent.OnServerEvent:Connect(function(player, target, weaponName)
    local data = GetPlayerData:Invoke(player)
    if not data or data.IsDowned then return end
    
    local weaponStats = Config.Weapons[weaponName]
    if not weaponStats then return end
    
    -- Hedef ve Mesafe Kontrolü
    if target and target.Parent and target:FindFirstChild("Health") and isEnemyTargetable(target) then
        local char = player.Character
        if not char then return end
        
        local dist = (char:GetPivot().Position - getEnemyPosition(target)).Magnitude
        if dist <= weaponStats.Range + 5 then -- Küçük bir tolerans payı
            local isCrit = math.random() < (data.CritChance or 0.05)
            local baseDamage = weaponStats.Damage * getPlayerDamageMultiplier(player, data)
            local finalDamage = isCrit and (baseDamage * (data.CritMultiplier or 2)) or baseDamage
            
            dealDamageWithLifesteal(player, data, target, finalDamage, isCrit, weaponName)
        end
    end
end)

-- Toggle Weapons feature for developer/testing
local ToggleWeaponsEvent = Events:FindFirstChild("ToggleWeapons") or Instance.new("RemoteEvent", Events)
ToggleWeaponsEvent.Name = "ToggleWeapons"
ToggleWeaponsEvent.Parent = Events

ToggleWeaponsEvent.OnServerEvent:Connect(function(player, weaponName)
    if weaponName and typeof(weaponName) == "string" then
        local attrName = "DisabledWeapon_" .. weaponName
        local current = player:GetAttribute(attrName) == true
        player:SetAttribute(attrName, not current)
        print("--- PLAYER " .. player.Name .. " WEAPON " .. weaponName .. " DISABLED: " .. tostring(not current) .. " ---")
    else
        local current = player:GetAttribute("WeaponsDisabled") == true
        player:SetAttribute("WeaponsDisabled", not current)
        print("--- PLAYER " .. player.Name .. " WEAPONS DISABLED: " .. tostring(not current) .. " ---")
    end
end)

local Cooldowns = {}
local BurstState = {} -- [userId][weaponName] = salvo içindeki kalan mermi sayısı
local TrailCooldowns = {}
local CachedPlayerData = {}
local GlobalStaggerCooldowns = {}
local RecentTargets = {}

local function registerRecentTarget(player, target)
    if not player or not target then return end
    local uid = player.UserId
    RecentTargets[uid] = RecentTargets[uid] or {}
    RecentTargets[uid][target] = os.clock() + 0.45
end

local function getActiveIgnoreList(player)
    local uid = player.UserId
    local tbl = RecentTargets[uid]
    if not tbl then return {} end
    local now = os.clock()
    local active = {}
    for enemy, expireTime in pairs(tbl) do
        if expireTime > now and enemy.Parent then
            active[enemy] = true
        else
            tbl[enemy] = nil
        end
    end
    return active
end

local function resetPlayerCooldowns(userId)
    -- Megabonk stili: Başlangıçta tüm silahlar aynı anda ateşlenmesin diye bekleme süreleri kademeli (staggered) dağıtılır
    Cooldowns[userId] = {
        Bullet = 0.19,
        Fireball = 0.49,
        Lightning = 0.79,
        Snowball = 1.09,
        SpikedArmor = 1.20,
    }
    GlobalStaggerCooldowns[userId] = 0
    TrailCooldowns[userId] = 0.5
    RecentTargets[userId] = {}
    BurstState[userId] = {}
end

local LastHitSoundTimes = {}
local function shouldPlayHitSound(player, weaponName, minInterval)
    if not player then return false end
    local key = player.UserId .. "_" .. weaponName
    local now = os.clock()
    local lastTime = LastHitSoundTimes[key] or 0
    if now - lastTime >= (minInterval or 0.04) then
        LastHitSoundTimes[key] = now
        return true
    end
    return false
end

getPlayerDamageMultiplier = function(player, data)
    if not data then return 1.0 end
    local multiplier = data.DamageMultiplier or 1.0
    
    -- Dagger boost
    local daggerCount = data.Items and data.Items.dagger or 0
    if daggerCount > 0 then
        multiplier = multiplier * (1 + daggerCount * 0.10)
    end
    
    -- Sniper boost
    local sniperCount = data.Items and data.Items.sniper or 0
    if sniperCount > 0 then
        local standTime = player:GetAttribute("TimeStandingStill") or 0
        local pct = math.min(1.0, standTime * 0.10)
        multiplier = multiplier * (1 + pct * sniperCount * 1.0)
    end
    
    return multiplier
end

-- Cache temizliği için Event
local PlayerUpgradedEvent = Events:WaitForChild("PlayerUpgraded", 5)
if PlayerUpgradedEvent then
    PlayerUpgradedEvent.Event:Connect(function(player)
        CachedPlayerData[player.UserId] = nil
    end)
end

local PlayerSpawnedEvent = Events:WaitForChild("PlayerSpawned", 5)
if PlayerSpawnedEvent then
    PlayerSpawnedEvent.Event:Connect(function(player)
        -- Oyuncu doğduğunda cache'i hemen sil
        CachedPlayerData[player.UserId] = nil
        
        -- Sadece oyun başladıysa ve aktifse cooldown'ları resetle
        if ReplicatedStorage:GetAttribute("GameStarted") == true then
            resetPlayerCooldowns(player.UserId)
        end
    end)
end

-- Oyun gerçekten başladığında (Start Game butonuna basıldığında) tüm oyuncuların combat verilerini resetle
ReplicatedStorage:GetAttributeChangedSignal("GameStarted"):Connect(function()
    if ReplicatedStorage:GetAttribute("GameStarted") == true then
        for _, player in ipairs(Players:GetPlayers()) do
            CachedPlayerData[player.UserId] = nil
            resetPlayerCooldowns(player.UserId)
        end
    end
end)


local enemiesFolder = workspace:FindFirstChild("Enemies")
if not enemiesFolder then
    enemiesFolder = Instance.new("Folder")
    enemiesFolder.Name = "Enemies"
    enemiesFolder.Parent = workspace
end

local enemyOverlapParams = OverlapParams.new()
enemyOverlapParams.FilterType = Enum.RaycastFilterType.Include
enemyOverlapParams.FilterDescendantsInstances = {enemiesFolder}

dealDamageWithLifesteal = function(player, data, target, finalDamage, isCrit, weaponName)
    if not target or not target.Parent then return false end
    
    -- Track weapon damage
    if weaponName then
        data.WeaponDamage = data.WeaponDamage or {}
        data.WeaponDamage[weaponName] = (data.WeaponDamage[weaponName] or 0) + finalDamage
        
        local RecordCombatStat = Events:FindFirstChild("RecordCombatStat")
        if RecordCombatStat then
            RecordCombatStat:Fire(player, "Damage", weaponName, finalDamage)
        end
    end
    
    -- Track Critical Strike Quests
    if isCrit then
        -- 1. CritChance Quest: "Deal 10 critical hits in a single match."
        local critCount = player:GetAttribute("MatchCritHits") or 0
        critCount = critCount + 1
        player:SetAttribute("MatchCritHits", critCount)
        
        ProgressionManager.UpdateProgress(player, "CritChance", critCount)
        
        -- 2. CritMultiplier Quest: "Deal a single critical strike over 100 damage."
        ProgressionManager.UpdateProgress(player, "CritMultiplier", finalDamage)
    end

    local killed = WeaponSystem.DealDamage(target, finalDamage, isCrit)
    if killed then
        -- Track defeated enemy
        local enemyType = target:GetAttribute("EnemyType") or target.Name
        if enemyType then
            data.DefeatedEnemies = data.DefeatedEnemies or {}
            data.DefeatedEnemies[enemyType] = (data.DefeatedEnemies[enemyType] or 0) + 1
            
            local RecordCombatStat = Events:FindFirstChild("RecordCombatStat")
            if RecordCombatStat then
                RecordCombatStat:Fire(player, "Kill", enemyType, 1)
            end
        end
    end
    
    if data.Lifesteal and data.Lifesteal > 0 then
        local healAmount = finalDamage * data.Lifesteal
        local HealPlayerEvent = Events:FindFirstChild("HealPlayer")
        if HealPlayerEvent then
            HealPlayerEvent:Fire(player, healAmount)
        end
    end
    return killed
end

local losRayParams = RaycastParams.new()
losRayParams.FilterType = Enum.RaycastFilterType.Exclude
losRayParams.RespectCanCollide = true

-- Statik & Önbellekli Line-of-Sight Filtresi (Her raycast'te sıfırdan oluşturulmaz, CPU ve GC sızıntısını önler)
local cachedLosExclude = {
    enemiesFolder,
    workspace:FindFirstChild("Gems"),
    workspace:FindFirstChild("Chests"),
}

local function updateLosFilter()
    local exclude = {
        enemiesFolder,
        workspace:FindFirstChild("Gems"),
        workspace:FindFirstChild("Chests"),
    }
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            table.insert(exclude, p.Character)
        end
    end
    
    local mapFolder = workspace:FindFirstChild("ProceduralMap")
    if mapFolder then
        for _, child in ipairs(mapFolder:GetChildren()) do
            if child.Name == "Tree" or child.Name == "Rock" or child.Name == "Log" or child.Name == "Flowers" or child.Name == "GrassProp" then
                table.insert(exclude, child)
            end
        end
    end
    
    cachedLosExclude = exclude
    losRayParams.FilterDescendantsInstances = cachedLosExclude
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(updateLosFilter)
    p.CharacterRemoving:Connect(updateLosFilter)
    updateLosFilter()
end)
Players.PlayerRemoving:Connect(updateLosFilter)
for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(updateLosFilter)
    p.CharacterRemoving:Connect(updateLosFilter)
end

ReplicatedStorage:GetAttributeChangedSignal("MapGenerated"):Connect(updateLosFilter)
if ReplicatedStorage:GetAttribute("MapGenerated") == true then
    updateLosFilter()
end

-- Görüş Hattı (Line-of-Sight) Kontrolü: Oyuncu ile düşman arasında duvar/zemin var mı?
local function hasLineOfSight(rootPos, enemyPos, enemy)
    local diffX = enemyPos.X - rootPos.X
    local diffY = enemyPos.Y - rootPos.Y
    local diffZ = enemyPos.Z - rootPos.Z
    local distSq = diffX * diffX + diffY * diffY + diffZ * diffZ
    
    -- 10 stud ve daha yakındaki canavarlar doğrudan görüş alanındadır (kendi karakterine/omzuna ışın çarpmasını önler)
    if distSq <= 100 then
        return true
    end
    
    local rayOrigin = rootPos + Vector3.new(0, 1.5, 0)
    local rayTarget = enemyPos + Vector3.new(0, 1.0, 0)
    local direction = rayTarget - rayOrigin
    
    local result = workspace:Raycast(rayOrigin, direction, losRayParams)
    if not result then
        return true -- Engel yok, görüş hattı doğrudan açık!
    end
    
    if enemy and (result.Instance:IsDescendantOf(enemy) or result.Instance == enemy) then
        return true -- Doğrudan hedef düşmana çarptı!
    end
    
    return false -- Duvar, zemin veya başka bir engele çarptı!
end

local function getNearestEnemy(rootPos, maxDist, ignoreList, allowDoomed, player)
    local nearestVisible = nil
    local minDistVisible = maxDist
    
    local nearestAny = nil
    local minDistAny = maxDist

    -- Yürüme Yolu Hedefleme (Walking-Path Aim Assist)
    local aimEnabled = (player ~= nil) and (player:GetAttribute("AimAssistEnabled") ~= false)
    local smartAim = (player ~= nil) and (player:GetAttribute("SmartAimEnabled") ~= false)
    local strength = tonumber(player and player:GetAttribute("AimAssistStrength")) or 60
    local strengthMult = math.clamp(strength / 100, 0.1, 1.0)
    
    local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local walkDir = aimEnabled and getPlayerWalkDirection(player, hrp) or nil

    local bestScoredEnemy = nil
    local bestDist = maxDist
    local bestScore = -math.huge
    
    local function isIgnored(enemy, dist)
        if not enemy or not enemy.Parent then return true end
        if not isEnemyTargetable(enemy) then return true end
        
        -- Eğer canavar çok yakınsa (<= 12 stud), acil tehlikedir; doomed diye es geçip uzaktakine vurma!
        if not allowDoomed and (not dist or dist > 12) then
            local healthVal = enemy:FindFirstChild("Health")
            if healthVal then
                local projected = enemy:GetAttribute("ProjectedDamage") or 0
                if healthVal.Value - projected <= 0 then
                    return true
                end
            end
        end
        
        if not ignoreList then return false end
        -- Yakın mesafedeki canavarları ignoreList olsa dahi (aynı karede başka silah sıksa da) tamamen dışlama
        if ignoreList[enemy] == true and (not dist or dist > 12) then
            return true
        end
        return false
    end
    
    local candidates = {}
    
    if _G.SpatialGrid then
        local results = _G.SpatialGrid.GetNearby(rootPos, maxDist)
        for _, enemy in ipairs(results) do
            if enemy.Parent == enemiesFolder then
                local enemyData = _G.ActiveEnemies and _G.ActiveEnemies[enemy]
                local pos = enemyData and enemyData.Position or enemy:GetPivot().Position
                local dx = pos.X - rootPos.X
                local dy = pos.Y - rootPos.Y
                local dz = pos.Z - rootPos.Z
                local dSq = dx * dx + dy * dy + dz * dz
                if dSq <= (maxDist * maxDist) then
                    local d = math.sqrt(dSq)
                    if not isIgnored(enemy, d) then
                        table.insert(candidates, { enemy = enemy, pos = pos, dist = d, distSq = dSq })
                    end
                end
            end
        end
    elseif _G.ActiveEnemies then
        for hitbox, data in pairs(_G.ActiveEnemies) do
            if hitbox.Parent == enemiesFolder then
                local pos = data.Position
                local dx = pos.X - rootPos.X
                local dy = pos.Y - rootPos.Y
                local dz = pos.Z - rootPos.Z
                local dSq = dx * dx + dy * dy + dz * dz
                if dSq <= (maxDist * maxDist) then
                    local d = math.sqrt(dSq)
                    if not isIgnored(hitbox, d) then
                        table.insert(candidates, { enemy = hitbox, pos = pos, dist = d, distSq = dSq })
                    end
                end
            end
        end
    else
        local results = workspace:GetPartBoundsInRadius(rootPos, maxDist, enemyOverlapParams)
        local checked = {}
        for _, part in ipairs(results) do
            local enemy = part:FindFirstAncestorOfClass("Model") or (part.Parent == enemiesFolder and part)
            if enemy and not checked[enemy] then
                checked[enemy] = true
                local pos = enemy:GetPivot().Position
                local d = (pos - rootPos).Magnitude
                if not isIgnored(enemy, d) then
                    table.insert(candidates, { enemy = enemy, pos = pos, dist = d, distSq = d * d })
                end
            end
        end
    end
    
    -- Adayları mesafeye göre sırala (En yakındakiler önce değerlendirilir)
    if #candidates > 1 then
        table.sort(candidates, function(a, b)
            return a.distSq < b.distSq
        end)
    end
    
    local losCheckCount = 0
    for _, item in ipairs(candidates) do
        local enemy, pos, dist = item.enemy, item.pos, item.dist
        
        -- Genel en yakın hedefi yedek olarak kaydet
        if dist < minDistAny then
            minDistAny = dist
            nearestAny = enemy
        end
        
        -- Acil savunma: Eğer dibimizde (<= 10 stud) canavar varsa doğrudan vur, uzak canavarları tarama
        if minDistAny <= 10 then
            return nearestAny, minDistAny
        end
        
        -- Yalnızca en yakın ilk 6 adaya LOS raycast'i at (CPU koruması)
        local hasLOS = false
        if dist <= 10 then
            hasLOS = true
        elseif losCheckCount < 6 then
            losCheckCount = losCheckCount + 1
            hasLOS = hasLineOfSight(rootPos, pos, enemy)
        end
        
        if dist < minDistVisible and hasLOS then
            minDistVisible = dist
            nearestVisible = enemy
        end

        -- Yürüyeceğimiz yerdeki düşmanları hedef alma (Walking Path Priority)
        if aimEnabled and walkDir then
            local toEnemy = Vector3.new(pos.X - rootPos.X, 0, pos.Z - rootPos.Z)
            local enemyDir = toEnemy.Magnitude > 0.05 and toEnemy.Unit or walkDir
            local dot = walkDir:Dot(enemyDir) -- 1 = tam yürüdüğümüz rotada, -1 = tam arkamızda

            local score = 0

            -- Görüş hattı
            if hasLOS then
                score = score + 35
            else
                score = score - 45
            end

            -- Yürüme rotası üzerindeki canavarlara belirgin öncelik ver
            if dot > 0.15 then
                -- Oyuncunun tam yürüdüğü / koştuğu istikametteki canavarlar yolu temizlemek için önceliklidir
                score = score + (dot * 60 * strengthMult)
            elseif dot < -0.15 then
                -- Oyuncunun arkasında kalan (uzaklaştığı) canavarların önceliğini kır
                score = score - (math.abs(dot) * 35 * strengthMult)
            end

            -- Mesafe faktörü (rota üzerindekilerin yakınına daha da öncelik ver)
            local distFactor = math.clamp(1 - (dist / maxDist), 0, 1)
            score = score + distFactor * 25

            -- Boss & Elite önceliği
            if smartAim then
                local isBoss = enemy:GetAttribute("IsBoss") == true or (enemy:FindFirstChild("Humanoid") and enemy.Humanoid.MaxHealth > 1000)
                local isElite = enemy:GetAttribute("IsElite") == true
                if isBoss then
                    score = score + 35
                elseif isElite then
                    score = score + 20
                end
            end

            if score > bestScore then
                bestScore = score
                bestScoredEnemy = enemy
                bestDist = dist
            end
        end
    end
    
    -- ACİL YAKIN MESAFE ÖNCELİĞİ: Eğer oyuncunun dibinde (<= 10 stud) canavar varsa KESİNLİKLE ona vur!
    if nearestAny and minDistAny <= 10 then
        return nearestAny, minDistAny
    end

    -- Yürüme yolu üzerinde tespit edilen en iyi hedefe öncelik ver
    if aimEnabled and bestScoredEnemy and bestScore > 0 then
        return bestScoredEnemy, bestDist
    end
    
    -- Görüş hattı engelsiz (duvar/zemin arkasında olmayan) hedefe öncelik ver
    if nearestVisible then
        return nearestVisible, minDistVisible
    end
    return nearestAny, minDistAny
end

local function getEnemiesInRadius(pos, radius)
    local found = {}
    
    if _G.SpatialGrid then
        local results = _G.SpatialGrid.GetNearby(pos, radius + 8)
        local seen = {}
        for _, enemy in ipairs(results) do
            if enemy.Parent == enemiesFolder and not seen[enemy] then
                seen[enemy] = true
                local enemyCenter = enemy.Position
                local enemySize = enemy.Size
                local halfX = enemySize.X * 0.5
                local halfY = enemySize.Y * 0.5
                local halfZ = enemySize.Z * 0.5
                
                local closeX = math.clamp(pos.X, enemyCenter.X - halfX, enemyCenter.X + halfX)
                local closeY = math.clamp(pos.Y, enemyCenter.Y - halfY, enemyCenter.Y + halfY)
                local closeZ = math.clamp(pos.Z, enemyCenter.Z - halfZ, enemyCenter.Z + halfZ)
                
                local distSq = (pos.X - closeX)^2 + (pos.Y - closeY)^2 + (pos.Z - closeZ)^2
                if distSq <= (radius * radius) then
                    table.insert(found, enemy)
                end
            end
        end
    elseif _G.ActiveEnemies then
        for hitbox, data in pairs(_G.ActiveEnemies) do
            if hitbox.Parent == enemiesFolder then
                local enemyCenter = hitbox.Position
                local enemySize = hitbox.Size
                local halfX = enemySize.X * 0.5
                local halfY = enemySize.Y * 0.5
                local halfZ = enemySize.Z * 0.5
                
                local closeX = math.clamp(pos.X, enemyCenter.X - halfX, enemyCenter.X + halfX)
                local closeY = math.clamp(pos.Y, enemyCenter.Y - halfY, enemyCenter.Y + halfY)
                local closeZ = math.clamp(pos.Z, enemyCenter.Z - halfZ, enemyCenter.Z + halfZ)
                
                local distSq = (pos.X - closeX)^2 + (pos.Y - closeY)^2 + (pos.Z - closeZ)^2
                if distSq <= (radius * radius) then
                    table.insert(found, hitbox)
                end
            end
        end
    else
        local results = workspace:GetPartBoundsInRadius(pos, radius, enemyOverlapParams)
        local seen = {}
        for _, part in ipairs(results) do
            local enemy = part:FindFirstAncestorOfClass("Model") or (part.Parent == enemiesFolder and part)
            if enemy and not seen[enemy] then
                seen[enemy] = true
                table.insert(found, enemy)
            end
        end
    end
    return found
end

local function getEffectiveProjectileCount(rawVal, defaultVal)
    local num = math.max(1, rawVal or (defaultVal or 1))
    local base = math.floor(num)
    local fraction = num - base
    if fraction > 0.001 and math.random() < fraction then
        return base + 1
    end
    return base
end

-- Single Bullet Atışı (Görsel istemcide, hesaplama sunucuda)
local function castSingleBullet(player, rootPos, target, data)
    if not target or not target.Parent or not target:FindFirstChild("Health") or target.Health.Value <= 0 then
        return false
    end
    
    local isCrit = math.random() < ((data.CritChance or 0.05) + (data.BulletCritChance or 0))
    local baseDamage = data.BulletDamage * getPlayerDamageMultiplier(player, data)
    local critMult = (data.CritMultiplier or 2) + (data.BulletCritDamage or 0)
    local finalDamage = isCrit and (baseDamage * critMult) or baseDamage
    
    target:SetAttribute("ProjectedDamage", (target:GetAttribute("ProjectedDamage") or 0) + finalDamage)
    
    local targetPos = getEnemyPosition(target)
    local dist = (targetPos - rootPos).Magnitude
    local speed = 80 * (1 + (data.Items and data.Items.bow or 0) * 0.10) * (data.BulletSpeedMultiplier or 1.0)
    local flightTime = dist / speed
    
    -- İstemcilere mermi çizmesi için sinyal gönder
    local bCount = getEffectiveProjectileCount(data.BulletCount, 1)
    local PlayProjectileVisual = Events:FindFirstChild("PlayProjectileVisual")
    if PlayProjectileVisual then
        PlayProjectileVisual:FireAllClients("Bullet", player, target, speed, targetPos, bCount)
    end
    
    -- Projectile Count Scroll görevi ilerlemesi: 3000 mermi at
    ProgressionManager.AddProgress(player, "ProjectileCount", bCount)
    
    -- Hasar verme işlemini uçuştan sonraya ertele (Gecikmesiz eşitleme)
    local currentTarget = target
    local targetLastPos = targetPos
    delayWithPause(flightTime, function()
        if currentTarget and currentTarget.Parent then
            currentTarget:SetAttribute("ProjectedDamage", math.max(0, (currentTarget:GetAttribute("ProjectedDamage") or 0) - finalDamage))
        end
        
        if not player or not player.Parent then return end
        
        local hitTarget = nil
        if currentTarget and currentTarget.Parent and currentTarget:FindFirstChild("Health") and currentTarget.Health.Value > 0 then
            hitTarget = currentTarget
        else
            -- Hedef canavar öldüyse, öldüğü noktanın yakınlarındaki (15 stud yarıçapta) en yakın canavarı bul
            hitTarget = getNearestEnemy(targetLastPos, 15, nil, true, player)
        end
        
        if hitTarget then
            dealDamageWithLifesteal(player, data, hitTarget, finalDamage, isCrit, "BulletWeapon")
            
            if shouldPlayHitSound(player, "Bullet", 0.04) then
                -- Play bullet hit sound
                local hitSoundPart = Instance.new("Attachment")
                hitSoundPart.WorldPosition = hitTarget:GetPivot().Position
                hitSoundPart.Parent = workspace.Terrain
                
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxassetid://160432334" -- Hitmarker Tick sound
                sound.Volume = 0.05 -- Quiet and extremely clean
                sound.Pitch = math.random(88, 112) / 100 -- Pitch randomization (suggested 1)
                sound.RollOffMaxDistance = 75 -- Tighter 3D limits (suggested 4)
                sound.RollOffMinDistance = 5
                sound.Parent = hitSoundPart
                sound:Play()
                Debris:AddItem(hitSoundPart, 1.0)
            end
        end
    end)
    return true
end

-- Fireball Patlama Yardımcısı (Sadece sunucuda hasar hesaplar, görsel istemcidedir)
local function explodeFireball(player, pos, data, precalculatedDamage, precalculatedIsCrit, directTarget)
    local radius = (data.FireballRadius or 3) * (data.AreaMultiplier or 1.0)
    local damageRadius = radius -- Tam yarıçap hasar uygular
    
    local isCrit = precalculatedIsCrit ~= nil and precalculatedIsCrit or (math.random() < ((data.CritChance or 0.05) + (data.FireballCritChance or 0)))
    local finalDamage = precalculatedDamage
    if not finalDamage then
        local fireTomeBoost = 1 + (data.Items and data.Items.fire_tome or 0) * 0.25
        local baseDamage = data.FireballDamage * getPlayerDamageMultiplier(player, data) * (data.FireDamageMultiplier or 1) * fireTomeBoost
        local critMult = (data.CritMultiplier or 2) + (data.FireballCritDamage or 0)
        finalDamage = isCrit and (baseDamage * critMult) or baseDamage
    end
    
    local enemiesHit = getEnemiesInRadius(pos, damageRadius)
    
    -- Doğrudan hedef canlı ve hedef alınabilirse, isabet listesinde yer almasını garanti et
    if directTarget and directTarget.Parent and isEnemyTargetable(directTarget) then
        local found = false
        for _, enemy in ipairs(enemiesHit) do
            if enemy == directTarget then
                found = true
                break
            end
        end
        if not found then
            table.insert(enemiesHit, directTarget)
        end
    end
    
    -- 1. Radius Quest Check
    local ProgressionManager = require(ReplicatedStorage.Shared.ProgressionManager)
    ProgressionManager.UpdateProgress(player, "AreaSize", #enemiesHit)
    
    local killedCount = 0
    for _, enemy in ipairs(enemiesHit) do
        local wasKilled = dealDamageWithLifesteal(player, data, enemy, finalDamage, isCrit, "FireballWeapon")
        if wasKilled then
            killedCount = killedCount + 1
        end
    end
    
    -- 2. Fire Trail Quest Check
    ProgressionManager.UpdateProgress(player, "FireTrailWeapon", killedCount)
end

local function fireSingleFireball(player, rootPos, target, data)
    local isCrit = math.random() < ((data.CritChance or 0.05) + (data.FireballCritChance or 0))
    local fireTomeBoost = 1 + (data.Items and data.Items.fire_tome or 0) * 0.25
    local baseDamage = data.FireballDamage * getPlayerDamageMultiplier(player, data) * (data.FireDamageMultiplier or 1) * fireTomeBoost
    local critMult = (data.CritMultiplier or 2) + (data.FireballCritDamage or 0)
    local finalDamage = isCrit and (baseDamage * critMult) or baseDamage
    
    target:SetAttribute("ProjectedDamage", (target:GetAttribute("ProjectedDamage") or 0) + finalDamage)

    local targetPos = getEnemyPosition(target)
    local flightDir = (targetPos - rootPos).Magnitude > 0.001 and (targetPos - rootPos).Unit or Vector3.new(0, 0, -1)
    local dist = (targetPos - rootPos).Magnitude
    local speed = 60 * (1 + (data.Items and data.Items.bow or 0) * 0.10) * (data.FireballSpeedMultiplier or 1.0)
    local flightTime = dist / speed
    
    -- İstemcilere alev topu çizmesi için sinyal gönder (Alan çarpanı dahil tam yarıçap gönderilir)
    local PlayProjectileVisual = Events:FindFirstChild("PlayProjectileVisual")
    if PlayProjectileVisual then
        local actualRadius = (data.FireballRadius or 3) * (data.AreaMultiplier or 1.0)
        PlayProjectileVisual:FireAllClients("Fireball", player, target, speed, actualRadius)
    end
    
    -- Projectile Count Scroll görevi ilerlemesi: 3000 mermi at
    ProgressionManager.AddProgress(player, "ProjectileCount", 1)
    
    -- Uçuştan sonra patlama hasarını uygula
    local currentTarget = target
    delayWithPause(flightTime, function()
        if currentTarget and currentTarget.Parent then
            currentTarget:SetAttribute("ProjectedDamage", math.max(0, (currentTarget:GetAttribute("ProjectedDamage") or 0) - finalDamage))
        end
        
        if not player or not player.Parent then return end
        local explosionPos = targetPos
        if currentTarget and currentTarget.Parent then
            explosionPos = getEnemyPosition(currentTarget)
        else
            -- Hedeflenen canavar yok edilmiş olsa bile alev topu vardığı noktada patlar
            explosionPos = rootPos + (flightDir * dist)
        end
        explodeFireball(player, explosionPos, data, finalDamage, isCrit, currentTarget)
    end)
end


-- Fire Trail (Ateş İzi)
local function dropFiretrail(player, rootPos, data)
    local radius = (data.FireTrailRadius or 2) * (data.AreaMultiplier or 1.0)
    local trail = Instance.new("Part")
    trail.Name = "FireTrail"
    trail.Shape = Enum.PartType.Cylinder
    trail.Size = Vector3.new(0.2, radius * 2, radius * 2)
    trail.Color = Color3.new(1, 0.4, 0)
    trail.Material = Enum.Material.Neon
    trail.Anchored = true
    trail.CanCollide = false
    -- Zemini bulmak için aşağı doğru ray atıyoruz (Üst üste binmeyi ve nesnelere çarpmayı önlemek için döngüsel raycast)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local excludeList = {player.Character, workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Gems")}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "FireTrail" or obj.Name == "Chest" or obj.Name == "Bullet" or obj.Name == "Snowball" then
            table.insert(excludeList, obj)
        end
    end
    rayParams.FilterDescendantsInstances = excludeList
    
    local spawnPos = rootPos - Vector3.new(0, 3, 0)
    local attempts = 0
    local rayOrigin = rootPos
    local rayDirection = Vector3.new(0, -150, 0)
    
    while attempts < 10 do
        attempts = attempts + 1
        local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
        if result then
            local hitInstance = result.Instance
            local nameLower = string.lower(hitInstance.Name)
            
            if hitInstance:IsA("Terrain") or nameLower == "baseplate" or string.find(nameLower, "floor") or string.find(nameLower, "ground") or string.find(nameLower, "zemin") or hitInstance:GetAttribute("IsGround") then
                spawnPos = result.Position + Vector3.new(0, 0.1, 0)
                break
            else
                local parentModel = hitInstance:FindFirstAncestorOfClass("Model")
                if parentModel and parentModel ~= workspace then
                    table.insert(excludeList, parentModel)
                else
                    table.insert(excludeList, hitInstance)
                end
                rayParams.FilterDescendantsInstances = excludeList
            end
        else
            break
        end
    end
    
    trail.CFrame = CFrame.new(spawnPos) * CFrame.Angles(0, 0, math.pi/2)
    trail.Parent = workspace
    
    -- İz hasar döngüsü ve görsel kaybolma (Zaman Durdurma Uyumlu)
    task.spawn(function()
        local duration = 3 + (data.FireTrailDurationBonus or 0)
        local interval = 0.25
        local elapsed = 0
        local nextDamage = interval
        
        local conn
        conn = RunService.Heartbeat:Connect(function(dt)
            if ReplicatedStorage:GetAttribute("IsPaused") then return end
            
            elapsed = elapsed + dt
            
            local pct = math.clamp(1 - (elapsed / duration), 0, 1)
            local baseRadius = (data.FireTrailRadius or 2) * (data.AreaMultiplier or 1.0)
            local currentRadius = baseRadius * pct
            
            if elapsed >= nextDamage then
                nextDamage = nextDamage + interval
                local pos = trail.Position
                
                local enemies = getEnemiesInRadius(pos, currentRadius)
                
                local ProgressionManager = require(ReplicatedStorage.Shared.ProgressionManager)
                ProgressionManager.UpdateProgress(player, "AreaSize", #enemies)
                
                for _, enemy in ipairs(enemies) do
                    local isCrit = math.random() < ((data.CritChance or 0.05) + (data.FireTrailCritChance or 0))
                    local fireTomeBoost = 1 + (data.Items and data.Items.fire_tome or 0) * 0.25
                    local baseDamage = (data.FireTrailDamage * getPlayerDamageMultiplier(player, data) * (data.FireDamageMultiplier or 1)) * interval * fireTomeBoost
                    local critMult = (data.CritMultiplier or 2) + (data.FireTrailCritDamage or 0)
                    local finalDamage = isCrit and (baseDamage * critMult) or baseDamage
                    
                    dealDamageWithLifesteal(player, data, enemy, finalDamage, isCrit, "FireTrailWeapon")
                end
            end
            
            -- Görsel olarak yavaşça kaybolma ve küçülme (Transparency & Size)
            if trail and trail.Parent then
                trail.Size = Vector3.new(0.2, currentRadius * 2, currentRadius * 2)
                trail.Transparency = elapsed / duration
            end
            
            if elapsed >= duration then
                if trail then trail:Destroy() end
                conn:Disconnect()
            end
        end)
    end)
end

-- Lightning Weapon
local function castSingleLightningBolt(player, rootPos, initialTarget, data, initialHitEnemies)
    local maxBounces = getEffectiveProjectileCount(data.LightningBounces, 3)
    local currentTarget = initialTarget
    local currentPos = rootPos
    local hitEnemies = initialHitEnemies or {}
    
    task.spawn(function()
        for i = 1, maxBounces do
            if not currentTarget or not currentTarget.Parent then break end
            
            local targetPos = getEnemyPosition(currentTarget)
            
            local beam = Instance.new("Part")
            beam.Name = "LightningBeam"
            beam.Anchored = true
            beam.CanCollide = false
            beam.Material = Enum.Material.Neon
            beam.Color = Color3.fromRGB(100, 200, 255)
            
            local dist = (targetPos - currentPos).Magnitude
            beam.Size = Vector3.new(0.2, 0.2, dist)
            beam.CFrame = CFrame.lookAt(currentPos, targetPos) * CFrame.new(0, 0, -dist / 2)
            beam.Parent = workspace
            
            Debris:AddItem(beam, 0.2)
            
            local isCrit = math.random() < ((data.CritChance or 0.05) + (data.LightningCritChance or 0))
            local baseDamage = data.LightningDamage * getPlayerDamageMultiplier(player, data)
            local critMult = (data.CritMultiplier or 2) + (data.LightningCritDamage or 0)
            local finalDamage = isCrit and (baseDamage * critMult) or baseDamage
            
            dealDamageWithLifesteal(player, data, currentTarget, finalDamage, isCrit, "LightningWeapon")
            hitEnemies[currentTarget] = true
            
            if shouldPlayHitSound(player, "Lightning", 0.04) then
                local hitSoundPart = Instance.new("Attachment")
                hitSoundPart.WorldPosition = targetPos
                hitSoundPart.Parent = workspace.Terrain
                
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxasset://sounds/electronicpingshort.wav" -- Dahili Elektronik Spark/Zap sesi
                sound.Volume = 0.15
                sound.Pitch = math.random(110, 130) / 100
                sound.RollOffMaxDistance = 75
                sound.RollOffMinDistance = 5
                sound.Parent = hitSoundPart
                sound:Play()
                Debris:AddItem(hitSoundPart, 1.0)
            end
            
            currentPos = targetPos
            local nextTarget = nil
            local minDist = 16 * (data.LightningRangeMultiplier or 1.0) -- Şimşek sekme menzili (Geliştirmelerle artabilir)
            
            local nearby = getEnemiesInRadius(currentPos, minDist)
            for _, enemy in ipairs(nearby) do
                if not hitEnemies[enemy] and isEnemyTargetable(enemy) then
                    local d = (getEnemyPosition(enemy) - currentPos).Magnitude
                    if d < minDist then
                        minDist = d
                        nextTarget = enemy
                    end
                end
            end
            
            currentTarget = nextTarget
            
            -- Zaman durdurulmuşsa bekle
            local waited = 0
            while waited < 0.06 do -- Sekmeler arası hızlı ve dinamik sıçrama (0.1s -> 0.06s)
                local dt = task.wait()
                if not ReplicatedStorage:GetAttribute("IsPaused") then
                    waited = waited + dt
                end
            end
        end
    end)
end

-- Snowball Weapon (Tekil Kartopu Atışı)
local function fireSingleSnowball(player, rootPos, target, data)
    if not target or not target.Parent or not target:FindFirstChild("Health") or target.Health.Value <= 0 then
        return false
    end
    
    local isCrit = math.random() < ((data.CritChance or 0.05) + (data.SnowballCritChance or 0))
    local baseDamage = data.SnowballDamage * getPlayerDamageMultiplier(player, data)
    local critMult = (data.CritMultiplier or 2) + (data.SnowballCritDamage or 0)
    local finalDamage = isCrit and (baseDamage * critMult) or baseDamage
    
    target:SetAttribute("ProjectedDamage", (target:GetAttribute("ProjectedDamage") or 0) + finalDamage)
    
    local targetPos = getEnemyPosition(target)
    local dist = (targetPos - rootPos).Magnitude
    local speed = 50 * (1 + (data.Items and data.Items.bow or 0) * 0.10) * (data.SnowballSpeedMultiplier or 1.0)
    local flightTime = dist / speed
    
    -- İstemcilere kartopu çizmesi için sinyal gönder
    local PlayProjectileVisual = Events:FindFirstChild("PlayProjectileVisual")
    if PlayProjectileVisual then
        PlayProjectileVisual:FireAllClients("Snowball", player, target, speed, data.SnowballSlowPct or 0.20, data.SnowballDuration or 3.0)
    end
    
    -- Projectile Count Scroll görevi ilerlemesi: 3000 mermi at
    ProgressionManager.AddProgress(player, "ProjectileCount", 1)
    
    -- Hasar verme ve yavaşlatma işlemini uçuştan sonraya ertele
    local currentTarget = target
    local targetLastPos = targetPos
    delayWithPause(flightTime, function()
        if currentTarget and currentTarget.Parent then
            currentTarget:SetAttribute("ProjectedDamage", math.max(0, (currentTarget:GetAttribute("ProjectedDamage") or 0) - finalDamage))
        end
        
        if not player or not player.Parent then return end
        
        local hitTarget = nil
        if currentTarget and currentTarget.Parent and currentTarget:FindFirstChild("Health") and currentTarget.Health.Value > 0 then
            hitTarget = currentTarget
        else
            -- Hedef canavar öldüyse, yakınlarındaki en yakın canavarı bul
            hitTarget = getNearestEnemy(targetLastPos, 15, nil, true, player)
        end
        
        if hitTarget then
            dealDamageWithLifesteal(player, data, hitTarget, finalDamage, isCrit, "SnowballWeapon")
            
            if shouldPlayHitSound(player, "Snowball", 0.05) then
                local hitSoundPart = Instance.new("Attachment")
                hitSoundPart.WorldPosition = hitTarget:GetPivot().Position
                hitSoundPart.Parent = workspace.Terrain
                
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxassetid://9119310633" -- Snowball Soft Splat/Hit
                sound.Volume = 0.08
                sound.Pitch = math.random(88, 112) / 100
                sound.RollOffMaxDistance = 75
                sound.RollOffMinDistance = 5
                sound.Parent = hitSoundPart
                sound:Play()
                Debris:AddItem(hitSoundPart, 1.0)
            end
            
            -- YAVAŞLATMA EFEKTİ
            local slowDuration = data.SnowballDuration or 3.0
            local slowPct = math.clamp(data.SnowballSlowPct or 0.20, 0, 0.85)
            local slowMultiplier = math.clamp(1 - slowPct, 0.15, 1.0)
            local expireTime = os.clock() + slowDuration
            
            hitTarget:SetAttribute("SnowballSlowed", true)
            hitTarget:SetAttribute("SlowMultiplier", slowMultiplier)
            hitTarget:SetAttribute("SlowExpireTime", expireTime)
            
            local t = hitTarget
            task.spawn(function()
                local remaining = slowDuration
                while remaining > 0 do
                    local dt = task.wait()
                    if not ReplicatedStorage:GetAttribute("IsPaused") then
                        remaining = remaining - dt
                    end
                end
                
                if t and t.Parent then
                    local currentExpiry = t:GetAttribute("SlowExpireTime") or 0
                    if os.clock() >= (currentExpiry - 0.05) then
                        t:SetAttribute("SnowballSlowed", nil)
                        t:SetAttribute("SlowMultiplier", 1.0)
                    end
                end
            end)
        end
    end)
    return true
end

-- 6. Spiked Armor (Dikenli Zırh - Periyodik Patlama & Misilleme)
-- 6. Spiked Armor (Dikenli Zırh - Tek Hedefe Karşı Saldırı & Parlama)
local SpikedArmorRetaliate = Events:FindFirstChild("SpikedArmorRetaliate") or Instance.new("BindableEvent", Events)
SpikedArmorRetaliate.Name = "SpikedArmorRetaliate"
SpikedArmorRetaliate.Event:Connect(function(player, amount, attackerPos, attackerEnemy)
    local data = CachedPlayerData[player.UserId]
    if not data or not data.HasSpikedArmor or player:GetAttribute("DisabledWeapon_SpikedArmor") == true then return end
    
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local rootPos = hrp.Position
    
    -- Bekleme Süresi Kontrolü (%25 düşürüldü: 5.0 -> 3.75s)
    local now = os.clock()
    local cooldown = math.max(1.15, 3.75 - (data.SpikedArmorCooldownBonus or 0))
    local lastTime = data.LastSpikedArmorTime or 0
    if (now - lastTime) < cooldown then
        return -- Henüz bekleme süresi dolmadı
    end
    data.LastSpikedArmorTime = now
    
    -- Client'a bekleme süresi bildir (Cooldown UI)
    if WeaponCooldownEvent then
        WeaponCooldownEvent:FireClient(player, "SpikedArmorWeapon", cooldown)
    end
    
    -- Hedef Belirleme: Sadece bize hasar vuran düşmana tekil misilleme yap (Count upgrade yok)
    local primaryTarget = attackerEnemy
    if not primaryTarget or not primaryTarget.Parent or not primaryTarget:FindFirstChild("Health") then
        primaryTarget = getNearestEnemy(attackerPos or rootPos, 15, nil, true, player)
    end
    if not primaryTarget or not primaryTarget.Parent or not isEnemyTargetable(primaryTarget) then
        return
    end
    local targetsToHit = { primaryTarget }
    if data.SpikedArmorRadiusMultiplier and data.SpikedArmorRadiusMultiplier > 1.0 then
        local extraRadius = 10 * data.SpikedArmorRadiusMultiplier
        local nearbyEnemies = getEnemiesInRadius(rootPos, extraRadius)
        for _, e in ipairs(nearbyEnemies) do
            if e ~= primaryTarget and isEnemyTargetable(e) then
                table.insert(targetsToHit, e)
            end
        end
    end
    
    local baseDamage = (data.SpikedArmorDamage or 7) * getPlayerDamageMultiplier(player, data)
    local reflectBonus = (amount or 10) * 1.5
    baseDamage = baseDamage + reflectBonus
    
    local isCrit = math.random() < ((data.CritChance or 0.05) + (data.SpikedArmorCritChance or 0))
    local critMult = (data.CritMultiplier or 2) + (data.SpikedArmorCritDamage or 0)
    local finalDamage = isCrit and (baseDamage * critMult) or baseDamage
    local knockbackPower = data.SpikedArmorKnockback or 4.0
    
    for _, targetEnemy in ipairs(targetsToHit) do
        dealDamageWithLifesteal(player, data, targetEnemy, finalDamage, isCrit, "SpikedArmorWeapon")
        
        -- Knockback
        local enemyPos = getEnemyPosition(targetEnemy)
        local diff = enemyPos - rootPos
        local flatDiff = Vector3.new(diff.X, 0, diff.Z)
        if flatDiff.Magnitude > 0.05 then
            local pushDir = flatDiff.Unit
            if _G.ApplyEnemyKnockback then
                _G.ApplyEnemyKnockback(targetEnemy, pushDir, knockbackPower * 14)
            end
            if targetEnemy:IsA("BasePart") then
                targetEnemy.AssemblyLinearVelocity = targetEnemy.AssemblyLinearVelocity + (pushDir * knockbackPower * 18)
            elseif targetEnemy:IsA("Model") and targetEnemy.PrimaryPart then
                targetEnemy.PrimaryPart.AssemblyLinearVelocity = targetEnemy.PrimaryPart.AssemblyLinearVelocity + (pushDir * knockbackPower * 18)
            end
        end
        
        -- Ses Efekti (Tok metal çarpma)
        local hitSoundPart = Instance.new("Attachment")
        hitSoundPart.WorldPosition = enemyPos
        hitSoundPart.Parent = workspace.Terrain
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://9114223170"
        sound.Volume = 0.35
        sound.Pitch = math.random(95, 110) / 100
        sound.RollOffMaxDistance = 60
        sound.RollOffMinDistance = 5
        sound.Parent = hitSoundPart
        sound:Play()
        Debris:AddItem(hitSoundPart, 1.0)
        
        -- İstemcilere sinyal: Bize hasar vuran canavarın etrafı biraz parlasın (Highlight)
        local PlayProjectileVisual = Events:FindFirstChild("PlayProjectileVisual")
        if PlayProjectileVisual then
            PlayProjectileVisual:FireAllClients("SpikedArmor", targetEnemy)
        end
    end
end)

local WeaponDefinitions = {
    Bullet = {
        BaseCooldown = 1.01, -- %25 düşürüldü (1.35 -> 1.01)
        BurstInterval = 0.09, -- Seri mermiler arası bekleme aralığı (Çoklu mermide seri tarama)
        GetCount = function(data)
            return getEffectiveProjectileCount(data.BulletCount, 1)
        end,
        TryFire = function(player, hrp, data, ignoreList)
            local rootPos = hrp.Position
            local target = getNearestEnemy(rootPos, 40, ignoreList, false, player)
            if not target then target = getNearestEnemy(rootPos, 40, nil, true, player) end
            if target then
                registerRecentTarget(player, target)
                return castSingleBullet(player, rootPos, target, data)
            end
            return false
        end,
    },
    Fireball = {
        BaseCooldown = 1.65, -- %25 düşürüldü (2.20 -> 1.65)
        BurstInterval = 0.22, -- Alev topları arası bekleme aralığı
        GetCount = function(data)
            return getEffectiveProjectileCount(data.FireballCount, 1)
        end,
        TryFire = function(player, hrp, data, ignoreList)
            local rootPos = hrp.Position
            local target = getNearestEnemy(rootPos, 40, ignoreList, false, player)
            if not target then target = getNearestEnemy(rootPos, 40, nil, true, player) end
            if target then
                registerRecentTarget(player, target)
                fireSingleFireball(player, rootPos, target, data)
                return true
            end
            return false
        end,
    },
    Lightning = {
        BaseCooldown = 1.50, -- %25 düşürüldü (2.00 -> 1.50)
        BurstInterval = 0.18, -- Yıldırımlar arası bekleme aralığı
        GetCount = function(data)
            return getEffectiveProjectileCount(data.LightningCount, 1)
        end,
        TryFire = function(player, hrp, data, ignoreList)
            local rootPos = hrp.Position
            local target = getNearestEnemy(rootPos, 35, ignoreList, false, player)
            if not target then target = getNearestEnemy(rootPos, 35, nil, true, player) end
            if target then
                registerRecentTarget(player, target)
                castSingleLightningBolt(player, rootPos, target, data, {})
                return true
            end
            return false
        end,
    },
    Snowball = {
        BaseCooldown = 1.42, -- %25 düşürüldü (1.90 -> 1.42)
        BurstInterval = 0.16, -- Kar topları arası bekleme aralığı
        GetCount = function(data)
            return getEffectiveProjectileCount(data.SnowballCount, 1)
        end,
        TryFire = function(player, hrp, data, ignoreList)
            local rootPos = hrp.Position
            local enemies = getEnemiesInRadius(rootPos, 40)
            local target = nil
            local minDist = 40
            for _, enemy in ipairs(enemies) do
                if enemy:FindFirstChild("Health") and enemy.Health.Value > 0 and not ignoreList[enemy] and isEnemyTargetable(enemy) then
                    local projected = enemy:GetAttribute("ProjectedDamage") or 0
                    if enemy.Health.Value - projected > 0 and not enemy:GetAttribute("SnowballSlowed") then
                        local d = (getEnemyPosition(enemy) - rootPos).Magnitude
                        if d < minDist then
                            minDist = d
                            target = enemy
                        end
                    end
                end
            end
            if not target then target = getNearestEnemy(rootPos, 40, ignoreList, false, player) end
            if not target then target = getNearestEnemy(rootPos, 40, nil, true, player) end
            if target then
                registerRecentTarget(player, target)
                return fireSingleSnowball(player, rootPos, target, data)
            end
            return false
        end,
    },
}

RunService.Heartbeat:Connect(function(dt)
    if not ReplicatedStorage:GetAttribute("GameStarted") or ReplicatedStorage:GetAttribute("IsPaused") then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            local rootPos = hrp.Position
            
            local data = CachedPlayerData[player.UserId]
            if not data then
                data = GetPlayerData:Invoke(player)
                CachedPlayerData[player.UserId] = data
            end
            
            if not data or data.IsDowned or character:GetAttribute("IsDowned") or player:GetAttribute("WeaponsDisabled") == true then 
                continue 
            end

            -- Track standing still for Sniper item
            local isStanding = hrp.AssemblyLinearVelocity.Magnitude < 0.5
            if isStanding then
                local standTime = player:GetAttribute("TimeStandingStill") or 0
                player:SetAttribute("TimeStandingStill", standTime + dt)
            else
                player:SetAttribute("TimeStandingStill", 0)
            end

            -- CoolDown init
            if not Cooldowns[player.UserId] then 
                resetPlayerCooldowns(player.UserId)
            end
            if not TrailCooldowns[player.UserId] then TrailCooldowns[player.UserId] = 0 end
            if not GlobalStaggerCooldowns[player.UserId] then GlobalStaggerCooldowns[player.UserId] = 0 end

            local pCooldowns = Cooldowns[player.UserId]
            local cooldownMult = data.RangedCooldownMultiplier or 1.0

            -- Global Stagger (Silahlar arası nefes payı) azaltımı
            if GlobalStaggerCooldowns[player.UserId] > 0 then
                GlobalStaggerCooldowns[player.UserId] -= dt
            end

            -- Silahların bireysel bekleme sürelerini azalt
            for weaponName, def in pairs(WeaponDefinitions) do
                if pCooldowns[weaponName] == nil then
                    -- Yeni açılan silah: hafifçe ofsetli başlat (aynı anda sıfırlanmasın)
                    pCooldowns[weaponName] = math.random(3, 7) * 0.1
                else
                    pCooldowns[weaponName] -= dt
                    -- Hedef yokken cooldown'un sonsuza kadar eksiye düşüp yığılmasını engelle
                    if pCooldowns[weaponName] < -1.5 then
                        pCooldowns[weaponName] = -0.3
                        local userBursts = BurstState[player.UserId]
                        if userBursts and userBursts[weaponName] then
                            userBursts[weaponName] = 0
                        end
                    end
                end
            end

            -- SİLAH ATEŞLEME DAĞITICISI (Burst / Salvo & Cooldown Sistemi)
            -- Mermileri aralıklı salvo (burst) halinde atar, salvo bitince tam bekleme süresine (cooldown) girer!
            if GlobalStaggerCooldowns[player.UserId] <= 0 then
                local userBursts = BurstState[player.UserId]
                if not userBursts then
                    userBursts = {}
                    BurstState[player.UserId] = userBursts
                end

                local readyWeapons = {}
                for weaponName, def in pairs(WeaponDefinitions) do
                    local hasWeapon = data["Has" .. weaponName]
                    local isDisabled = player:GetAttribute("DisabledWeapon_" .. weaponName) == true
                    if hasWeapon and not isDisabled and pCooldowns[weaponName] <= 0 then
                        local isMidBurst = (userBursts[weaponName] or 0) > 0
                        table.insert(readyWeapons, {
                            Name = weaponName,
                            Def = def,
                            WaitTime = isMidBurst and 9999 or -pCooldowns[weaponName],
                        })
                    end
                end

                if #readyWeapons > 0 then
                    -- Salvo ortasında olan veya en uzun bekleyen silahı ilk sıraya al
                    table.sort(readyWeapons, function(a, b)
                        return a.WaitTime > b.WaitTime
                    end)

                    local activeIgnoreList = getActiveIgnoreList(player)

                    -- Sırayla dene: Menzilinde hedef olan ilk silahı ateşle ve döngüyü tamamla
                    for _, cand in ipairs(readyWeapons) do
                        local success = cand.Def.TryFire(player, hrp, data, activeIgnoreList)
                        if success then
                            local wName = cand.Name
                            local remaining = userBursts[wName]

                            if not remaining or remaining <= 0 then
                                -- Yeni bir salvo (burst) başlatıldı
                                local totalCount = cand.Def.GetCount(data)
                                if totalCount > 1 then
                                    userBursts[wName] = totalCount - 1
                                    -- Salvo içindeki mermiler arası kısa mermi aralığı (0.12 - 0.22s)
                                    pCooldowns[wName] = cand.Def.BurstInterval
                                else
                                    userBursts[wName] = 0
                                    -- Tek mermili: Doğrudan tam silah bekleme süresine (Cooldown) girer
                                    local fullCooldown = cand.Def.BaseCooldown * cooldownMult
                                    pCooldowns[wName] = fullCooldown
                                    WeaponCooldownEvent:FireClient(player, wName .. "Weapon", fullCooldown)
                                end
                            else
                                -- Salvo devam ediyor (2., 3. mermi vb.)
                                remaining = remaining - 1
                                if remaining > 0 then
                                    userBursts[wName] = remaining
                                    pCooldowns[wName] = cand.Def.BurstInterval
                                else
                                    userBursts[wName] = 0
                                    -- Salvo tamamlandı! Şimdi silah TAM bekleme süresine girer (üst üste attıktan sonra bekler)
                                    local fullCooldown = cand.Def.BaseCooldown * cooldownMult
                                    pCooldowns[wName] = fullCooldown
                                    WeaponCooldownEvent:FireClient(player, wName .. "Weapon", fullCooldown)
                                end
                            end

                            -- Mikro nefes payı (0.05s): Farklı silahların aynı milisaniyede çakışmasını engeller
                            GlobalStaggerCooldowns[player.UserId] = math.clamp(0.05 * cooldownMult, 0.03, 0.08)
                            break
                        end
                    end
                end
            end

            -- 5. Fire Trail (Ateş İzi - Hareket tabanlı pasif alan)
            if data.HasFireTrail and player:GetAttribute("DisabledWeapon_FireTrail") ~= true then
                TrailCooldowns[player.UserId] -= dt
                if TrailCooldowns[player.UserId] <= 0 then
                    local count = getEffectiveProjectileCount(data.FireTrailCount, 1)
                    local baseSpawnPos = hrp.Position - (hrp.CFrame.LookVector * 2.5)
                    local rightVec = hrp.CFrame.RightVector
                    local radius = (data.FireTrailRadius or 2) * (data.AreaMultiplier or 1.0)
                    
                    if count <= 1 then
                        dropFiretrail(player, baseSpawnPos, data)
                    elseif count == 2 then
                        dropFiretrail(player, baseSpawnPos - (rightVec * (radius * 0.75)), data)
                        dropFiretrail(player, baseSpawnPos + (rightVec * (radius * 0.75)), data)
                    else
                        dropFiretrail(player, baseSpawnPos, data)
                        for c = 1, count - 1 do
                            local sign = (c % 2 == 1) and 1 or -1
                            local step = math.ceil(c / 2)
                            dropFiretrail(player, baseSpawnPos + (rightVec * (sign * radius * 0.75 * step)), data)
                        end
                    end
                    -- Fire Trail bekleme süresi %25 düşürüldü (1.0 -> 0.75s)
                    TrailCooldowns[player.UserId] = 0.75 * (data.RangedCooldownMultiplier or 1)
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerWalkDirections[player.UserId] = nil
    Cooldowns[player.UserId] = nil
    BurstState[player.UserId] = nil
    TrailCooldowns[player.UserId] = nil
    GlobalStaggerCooldowns[player.UserId] = nil
    RecentTargets[player.UserId] = nil
    CachedPlayerData[player.UserId] = nil
end)
