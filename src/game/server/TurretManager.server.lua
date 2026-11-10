local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local WeaponSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponSystem"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))

local Events = ReplicatedStorage:WaitForChild("Events")
local DeployTurretEvent = Events:FindFirstChild("DeployTurret") or Instance.new("RemoteEvent", Events)
DeployTurretEvent.Name = "DeployTurret"

local GetPlayerData = Events:WaitForChild("GetPlayerData")
local SpendScrap = Events:WaitForChild("SpendScrap")
local PlayProjectileVisual = Events:FindFirstChild("PlayProjectileVisual")

-- Turrets Klasörü
local TurretsFolder = workspace:FindFirstChild("Turrets")
if not TurretsFolder then
    TurretsFolder = Instance.new("Folder")
    TurretsFolder.Name = "Turrets"
    TurretsFolder.Parent = workspace
end

local enemiesFolder = workspace:FindFirstChild("Enemies")

-- Duraklatma (Pause) duyarlı gecikme fonksiyonu
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

-- Fallback Turret Model Oluşturucu (Model bulunamazsa kullanılır)
local function createFallbackTurret()
    local model = Instance.new("Model")
    model.Name = "FallbackTurret"

    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(2.4, 0.6, 2.4)
    base.Color = Color3.fromRGB(55, 60, 70)
    base.Material = Enum.Material.Metal
    base.Anchored = true
    base.CanCollide = false
    base.Parent = model

    local stand = Instance.new("Part")
    stand.Name = "Stand"
    stand.Size = Vector3.new(0.8, 1.4, 0.8)
    stand.Color = Color3.fromRGB(75, 80, 90)
    stand.Material = Enum.Material.Metal
    stand.Anchored = true
    stand.CanCollide = false
    stand.Position = base.Position + Vector3.new(0, 1.0, 0)
    stand.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.4, 1.0, 1.8)
    head.Color = Color3.fromRGB(240, 150, 30) -- Bronze/Orange engineer theme
    head.Material = Enum.Material.Neon
    head.Anchored = true
    head.CanCollide = false
    head.Position = stand.Position + Vector3.new(0, 1.2, 0)
    head.Parent = model

    local barrel = Instance.new("Part")
    barrel.Name = "Muzzle"
    barrel.Size = Vector3.new(0.5, 0.5, 1.5)
    barrel.Color = Color3.fromRGB(30, 30, 35)
    barrel.Material = Enum.Material.Metal
    barrel.Anchored = true
    barrel.CanCollide = false
    barrel.Position = head.Position + Vector3.new(0, 0, -1.2)
    barrel.Parent = model

    model.PrimaryPart = base
    return model
end

-- ReplicatedStorage'daki Taret Modelini Bulma (Dominant Archetype ve Fallback Destekli)
-- Desteklenen klasörler:
-- 1. ReplicatedStorage.Assets.Class.TurretModels
local function findChildFuzzy(parent, targetNames)
    if not parent then return nil end
    for _, name in ipairs(targetNames) do
        local direct = parent:FindFirstChild(name)
        if direct then return direct end
    end
    for _, child in ipairs(parent:GetChildren()) do
        local cleanChild = string.lower(string.gsub(child.Name, "[%s_]", ""))
        for _, name in ipairs(targetNames) do
            local cleanTarget = string.lower(string.gsub(name, "[%s_]", ""))
            if cleanChild == cleanTarget or string.lower(child.Name) == string.lower(name) then
                return child
            end
        end
    end
    return nil
end

-- ReplicatedStorage, ServerStorage ve Workspace'teki Taret Modellerini Bulma
local function getTurretModelTemplate(archetype)
    local searchContainers = {}
    local function addContainer(c)
        if c and not table.find(searchContainers, c) then
            table.insert(searchContainers, c)
        end
    end

    -- 1. ReplicatedStorage ve olası tüm alt klasörleri
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if assets then
        local classFolder = assets:FindFirstChild("Class")
        if classFolder then
            addContainer(classFolder:FindFirstChild("TurretModels"))
            addContainer(classFolder:FindFirstChild("Turrets"))
            addContainer(classFolder)
        end
        addContainer(assets:FindFirstChild("TurretModels"))
        addContainer(assets:FindFirstChild("Turrets"))
        addContainer(assets)
    end
    addContainer(ReplicatedStorage:FindFirstChild("Class"))
    addContainer(ReplicatedStorage:FindFirstChild("TurretModels"))
    addContainer(ReplicatedStorage:FindFirstChild("Turrets"))
    addContainer(ReplicatedStorage)

    -- 2. ServerStorage ve olası alt klasörleri
    local serverStorage = game:GetService("ServerStorage")
    if serverStorage then
        local sAssets = serverStorage:FindFirstChild("Assets")
        if sAssets then
            addContainer(sAssets:FindFirstChild("Class"))
            addContainer(sAssets)
        end
        addContainer(serverStorage:FindFirstChild("Class"))
        addContainer(serverStorage:FindFirstChild("TurretModels"))
        addContainer(serverStorage:FindFirstChild("Turrets"))
        addContainer(serverStorage)
    end

    -- 3. Workspace
    addContainer(workspace:FindFirstChild("Assets"))
    addContainer(workspace:FindFirstChild("Class"))
    addContainer(workspace:FindFirstChild("TurretModels"))
    addContainer(workspace:FindFirstChild("Turrets"))

    -- Özel tür arama
    if archetype and archetype ~= "Turret" and archetype ~= "" then
        local possibleNames = {}

        if archetype == "MinigunTurret" then
            table.insert(possibleNames, "Turret_Minigun")
            table.insert(possibleNames, "MinigunTurret")
            table.insert(possibleNames, "TurretMinigun")
            table.insert(possibleNames, "Minigun")
        elseif archetype == "RailgunTurret" then
            table.insert(possibleNames, "Turret_Railgun")
            table.insert(possibleNames, "RailgunTurret")
            table.insert(possibleNames, "TurretRailgun")
            table.insert(possibleNames, "Railgun")
        elseif archetype == "TwinCannonTurret" then
            table.insert(possibleNames, "Turret_TwinCannon")
            table.insert(possibleNames, "TwinCannonTurret")
            table.insert(possibleNames, "TurretTwinCannon")
            table.insert(possibleNames, "TwinCannon")
        elseif archetype == "SiegeTurret" then
            table.insert(possibleNames, "Turret_Siege")
            table.insert(possibleNames, "SiegeTurret")
            table.insert(possibleNames, "TurretSiege")
            table.insert(possibleNames, "Siege")
        elseif archetype == "RecyclerTurret" then
            table.insert(possibleNames, "Turret_Recycler")
            table.insert(possibleNames, "RecyclerTurret")
            table.insert(possibleNames, "TurretRecycler")
            table.insert(possibleNames, "Recycler")
        else
            table.insert(possibleNames, "Turret_" .. tostring(archetype))
            table.insert(possibleNames, tostring(archetype))
        end

        for _, container in ipairs(searchContainers) do
            local found = findChildFuzzy(container, possibleNames)
            if found and (found:IsA("Model") or found:IsA("Folder") or found:IsA("BasePart")) then
                print(string.format("[TurretTemplate] Archetype '%s' matched model '%s' in '%s'", tostring(archetype), found.Name, container:GetFullName()))
                return found
            end
        end

        -- Eğer arama konteynerlerinde bulunamadıysa ReplicatedStorage ve ServerStorage'ın derinliklerine kadar tara
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc:IsA("Model") or desc:IsA("Folder") then
                local cleanDesc = string.lower(string.gsub(desc.Name, "[%s_]", ""))
                for _, name in ipairs(possibleNames) do
                    local cleanTarget = string.lower(string.gsub(name, "[%s_]", ""))
                    if cleanDesc == cleanTarget or string.lower(desc.Name) == string.lower(name) then
                        print(string.format("[TurretTemplate] Deep search matched archetype '%s' to '%s' in '%s'", tostring(archetype), desc.Name, desc:GetFullName()))
                        return desc
                    end
                end
            end
        end
    end

    -- Varsayılan (Normal) model arama
    local defaultNames = { "Turret", "Turret_Default", "DefaultTurret", "NormalTurret" }
    for _, container in ipairs(searchContainers) do
        local found = findChildFuzzy(container, defaultNames)
        if found and (found:IsA("Model") or found:IsA("Folder") or found:IsA("BasePart")) then
            print(string.format("[TurretTemplate] Using default turret '%s' from '%s'", found.Name, container:GetFullName()))
            return found
        end
    end

    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("Model") or desc:IsA("Folder") then
            local cleanDesc = string.lower(string.gsub(desc.Name, "[%s_]", ""))
            for _, name in ipairs(defaultNames) do
                local cleanTarget = string.lower(string.gsub(name, "[%s_]", ""))
                if cleanDesc == cleanTarget or string.lower(desc.Name) == string.lower(name) then
                    print(string.format("[TurretTemplate] Deep search found default turret '%s' in '%s'", desc.Name, desc:GetFullName()))
                    return desc
                end
            end
        end
    end

    warn("[TurretTemplate] No turret model template found in game! Using fallback procedural turret.")
    return nil
end

-- Taban parçalarının gerçek açılı/eğimli (Oriented) sınırlarını ve en alt noktasını tam olarak hesaplama
local function getExactBaseBounds(parts)
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge

    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then
            local cf = part.CFrame
            local sz = part.Size * 0.5
            local pos = cf.Position

            local rx = cf.RightVector
            local up = cf.UpVector
            local lk = cf.LookVector

            local hx = sz.X * math.abs(rx.X) + sz.Y * math.abs(up.X) + sz.Z * math.abs(lk.X)
            local hy = sz.X * math.abs(rx.Y) + sz.Y * math.abs(up.Y) + sz.Z * math.abs(lk.Y)
            local hz = sz.X * math.abs(rx.Z) + sz.Y * math.abs(up.Z) + sz.Z * math.abs(lk.Z)

            local pMinX, pMaxX = pos.X - hx, pos.X + hx
            local pMinY, pMaxY = pos.Y - hy, pos.Y + hy
            local pMinZ, pMaxZ = pos.Z - hz, pos.Z + hz

            if pMinX < minX then minX = pMinX end
            if pMaxX > maxX then maxX = pMaxX end
            if pMinY < minY then minY = pMinY end
            if pMaxY > maxY then maxY = pMaxY end
            if pMinZ < minZ then minZ = pMinZ end
            if pMaxZ > maxZ then maxZ = pMaxZ end
        end
    end

    if minX == math.huge then
        return Vector3.zero, 0
    end

    local center = Vector3.new((minX + maxX) * 0.5, minY, (minZ + maxZ) * 0.5)
    return center, minY
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

-- En yakın düşmanı bulma (SpatialGrid ve Aşırı hasar / Overkill önleme destekli)
local function getNearestEnemyForTurret(turretPos, maxRange, pendingDamageMap)
    local nearestEnemy = nil
    local minDist = maxRange

    -- 1. _G.SpatialGrid üzerinden anlık yakın çevre sorgusu (CPU Optimizasyonu)
    if _G.SpatialGrid then
        local candidates = _G.SpatialGrid.GetNearby(turretPos, maxRange)
        for _, hitbox in ipairs(candidates) do
            if hitbox.Parent and hitbox.Parent == enemiesFolder then
                local health = hitbox:FindFirstChild("Health")
                if health and health.Value > 0 then
                    local pendingDmg = (pendingDamageMap and pendingDamageMap[hitbox]) or 0
                    local effectiveHealth = health.Value - pendingDmg
                    if effectiveHealth > 0 then
                        local isEmerging = hitbox:GetAttribute("IsEmerging")
                        local canTarget = true
                        if isEmerging then
                            local spawnTime = hitbox:GetAttribute("SpawnTime")
                            local duration = hitbox:GetAttribute("EmergingDuration") or 1.0
                            if spawnTime and (os.clock() - spawnTime) < (duration * 0.35) then
                                canTarget = false
                            end
                        end
                        if canTarget then
                            local enemyPos = hitbox.Position
                            local d = (enemyPos - turretPos).Magnitude
                            if d < minDist then
                                minDist = d
                                nearestEnemy = hitbox
                            end
                        end
                    end
                end
            end
        end
    elseif _G.ActiveEnemies then
        for hitbox, data in pairs(_G.ActiveEnemies) do
            if hitbox.Parent and hitbox.Parent == enemiesFolder then
                local health = hitbox:FindFirstChild("Health")
                if health and health.Value > 0 then
                    local pendingDmg = (pendingDamageMap and pendingDamageMap[hitbox]) or 0
                    local effectiveHealth = health.Value - pendingDmg
                    if effectiveHealth > 0 then
                        local isEmerging = hitbox:GetAttribute("IsEmerging")
                        local canTarget = true
                        if isEmerging then
                            local spawnTime = hitbox:GetAttribute("SpawnTime")
                            local duration = hitbox:GetAttribute("EmergingDuration") or 1.0
                            if spawnTime and (os.clock() - spawnTime) < (duration * 0.35) then
                                canTarget = false
                            end
                        end
                        if canTarget then
                            local enemyPos = hitbox.Position
                            local d = (enemyPos - turretPos).Magnitude
                            if d < minDist then
                                minDist = d
                                nearestEnemy = hitbox
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Fallback olarak workspace.Enemies klasörünü tara
    if not nearestEnemy and enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            local health = enemy:FindFirstChild("Health")
            if health and health.Value > 0 then
                local pendingDmg = (pendingDamageMap and pendingDamageMap[enemy]) or 0
                local effectiveHealth = health.Value - pendingDmg
                if effectiveHealth > 0 then
                    local enemyPos = enemy:GetPivot().Position
                    local d = (enemyPos - turretPos).Magnitude
                    if d < minDist then
                        minDist = d
                        nearestEnemy = enemy
                    end
                end
            end
        end
    end

    return nearestEnemy, minDist
end

-- Taret kurma bekleme süresi %25 düşürüldü (5.0 -> 3.75s)
local TURRET_COOLDOWN = 3.75
local lastDeployTimes = {}

Players.PlayerRemoving:Connect(function(player)
    lastDeployTimes[player.UserId] = nil
end)

-- Taret Kurma Olayı
DeployTurretEvent.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    local now = os.clock()
    local lastDeploy = lastDeployTimes[player.UserId] or 0
    if (now - lastDeploy) < TURRET_COOLDOWN then
        return
    end

    local data = GetPlayerData:Invoke(player)
    if not data or not data.HasTurret then return end

    local cost = data.TurretCost or 100
    if (data.Scrap or 0) < cost then
        warn(player.Name .. " tried to deploy turret without enough scrap! (Have: " .. tostring(data.Scrap) .. ", Need: " .. tostring(cost) .. ")")
        return
    end

    -- Hurda harca
    local spent = SpendScrap:Invoke(player, cost)
    if not spent then return end

    lastDeployTimes[player.UserId] = now
    player:SetAttribute("TurretCooldownEnd", now + TURRET_COOLDOWN)

    -- 1. Zemin ve Yüzey Tespiti (Akıllı ve engellere duyarlı raycast)
    local hrpPos = hrp.Position
    local lookVec = hrp.CFrame.LookVector
    local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z)
    flatLook = (flatLook.Magnitude > 0.001) and flatLook.Unit or Vector3.new(0, 0, -1)

    -- Raycast filtre listesi: Karakterler, taretler, canavarlar, çömlekler, kristaller, mermiler hariç tutulur
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true -- Yalnızca katı zeminlere çarpsın, görünmez tetikleyicileri yoksaysın

    local ignoreList = {TurretsFolder, enemiesFolder}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            table.insert(ignoreList, p.Character)
        end
    end
    local potsFolder = workspace:FindFirstChild("Pots")
    if potsFolder then table.insert(ignoreList, potsFolder) end
    local gemsFolder = workspace:FindFirstChild("Gems")
    if gemsFolder then table.insert(ignoreList, gemsFolder) end
    local projFolder = workspace:FindFirstChild("Projectiles")
    if projFolder then table.insert(ignoreList, projFolder) end

    rayParams.FilterDescendantsInstances = ignoreList

    -- A) Referans: Oyuncunun bastığı zemin seviyesini bul
    local footRay = workspace:Raycast(hrpPos + Vector3.new(0, 1.0, 0), Vector3.new(0, -10, 0), rayParams)
    local playerGroundY = footRay and footRay.Position.Y or (hrpPos.Y - 2.8)

    -- B) Önünde engel (duvar/kaya) var mı kontrol et, varsa tareti duvarın içine değil önüne koy
    local maxDeployDist = 3.5
    local chestRayOrigin = hrpPos + Vector3.new(0, 0.5, 0)
    local wallCheck = workspace:Raycast(chestRayOrigin, flatLook * maxDeployDist, rayParams)
    local actualDist = wallCheck and math.max(1.2, wallCheck.Distance - 1.0) or maxDeployDist
    local targetXZ = hrpPos + flatLook * actualDist

    -- C) Hedef zemin raycast'i: Bel hizasından (hrpPos.Y + 2.5) aşağıya doğru tara
    -- Bu sayede ağaç dalları veya tavanlar yerine doğrudan zemin algılanır
    local rayOrigin = Vector3.new(targetXZ.X, hrpPos.Y + 2.5, targetXZ.Z)
    local rayDir = Vector3.new(0, -14, 0)
    local groundRay = workspace:Raycast(rayOrigin, rayDir, rayParams)

    local groundY = playerGroundY
    if groundRay then
        -- Eğer çarptığı yüzey dik bir uçurum/duvar değilse (Normal.Y >= 0.45) hedef yüksekliği kullan
        if groundRay.Normal.Y >= 0.45 then
            groundY = groundRay.Position.Y
        end
    end
    local groundPos = Vector3.new(targetXZ.X, groundY, targetXZ.Z)

    -- 2. Model Şablonunu Klonla (Dominant Archetype ve Fallback Destekli)
    local dominantArchetype = data.TurretDominantArchetype or player:GetAttribute("TurretDominantArchetype")
    print(string.format("[TurretDeploy] Player: %s, DominantArchetype: %s", player.Name, tostring(dominantArchetype)))
    local template = getTurretModelTemplate(dominantArchetype)
    local turretModel
    if template then
        turretModel = template:Clone()
    else
        turretModel = createFallbackTurret()
    end

    turretModel.Name = "DeployedTurret_" .. player.Name
    turretModel:SetAttribute("IsTurret", true)
    turretModel:SetAttribute("OwnerUserId", player.UserId)

    -- Bütün parçaları güvenle sabitle (Anchored = true)
    for _, part in ipairs(turretModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
        end
    end

    -- Model yapısını tespit et (Turret -> Head -> Barrel)
    local headObj = turretModel:FindFirstChild("Head") or turretModel:FindFirstChild("Kafa")
    local barrelObj = (headObj and (headObj:FindFirstChild("Barrel") or headObj:FindFirstChild("Namlu")))
        or turretModel:FindFirstChild("Barrel") 
        or turretModel:FindFirstChild("Namlu")

    -- Dönen parçaları (Head ve Barrel) ve sabit taban parçalarını (Base, Legs, Stand) ayır
    local headParts = {}
    local headPartSet = {}
    local function registerHeadPart(p)
        if p:IsA("BasePart") and not headPartSet[p] then
            headPartSet[p] = true
            table.insert(headParts, p)
        end
    end

    if headObj then
        if headObj:IsA("BasePart") then registerHeadPart(headObj) end
        for _, p in ipairs(headObj:GetDescendants()) do registerHeadPart(p) end
    end
    if barrelObj then
        if barrelObj:IsA("BasePart") then registerHeadPart(barrelObj) end
        for _, p in ipairs(barrelObj:GetDescendants()) do registerHeadPart(p) end
    end

    local baseParts = {}
    for _, p in ipairs(turretModel:GetDescendants()) do
        if p:IsA("BasePart") and not headPartSet[p] then
            table.insert(baseParts, p)
        end
    end
    if #baseParts == 0 then
        baseParts = { turretModel:FindFirstChildWhichIsA("BasePart") }
    end

    -- Tabanın gerçek açılı/eğimli (Oriented) sınırlarını ve alt seviyesini tam olarak hesapla
    local baseCenterInitial, baseMinY = getExactBaseBounds(baseParts)
    local targetBasePos = Vector3.new(groundPos.X, groundY, groundPos.Z)

    -- Geçici merkez kökü (Anchor) ile tüm modeli taban merkezinden hedefe yerleştir
    local anchor = Instance.new("Part")
    anchor.Name = "TempTurretAnchor"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.Anchored = true
    anchor.CFrame = CFrame.new(baseCenterInitial, baseCenterInitial + flatLook)
    anchor.Parent = turretModel
    turretModel.PrimaryPart = anchor
    turretModel:PivotTo(CFrame.new(targetBasePos, targetBasePos + flatLook))
    anchor:Destroy()

    -- Tabanın ana parçasını PrimaryPart olarak sabitle
    local primaryPart = baseParts[1]
    for _, name in ipairs({"Base", "Stand", "Gövde", "Body", "Root", "Plate", "Platform"}) do
        for _, p in ipairs(baseParts) do
            if string.lower(p.Name) == string.lower(name) then
                primaryPart = p
                break
            end
        end
        if primaryPart and primaryPart ~= baseParts[1] then break end
    end
    turretModel.PrimaryPart = primaryPart or turretModel:FindFirstChildWhichIsA("BasePart")

    -- SABİT DÖNÜŞ EKSENİ: Tabanın tam merkez düşey çizgisi (axisX, axisZ)
    local axisX = targetBasePos.X
    local axisZ = targetBasePos.Z

    -- Yerleşim sonrası tüm kafa parçalarının başlangıç CFrame'lerini dondur
    local initialHeadCFrames = {}
    for _, part in ipairs(headParts) do
        initialHeadCFrames[part] = part.CFrame
    end

    -- Namlu parçalarını ve doğal ileri yönü belirle
    local barrelParts = {}
    local barrelPartSet = {}
    local function registerBarrelPart(p)
        if p:IsA("BasePart") and not barrelPartSet[p] then
            barrelPartSet[p] = true
            table.insert(barrelParts, p)
        end
    end

    local possibleBarrelContainers = {}
    if headObj then
        for _, child in ipairs(headObj:GetChildren()) do
            local n = string.lower(child.Name)
            if string.find(n, "barrel") or string.find(n, "namlu") or string.find(n, "gun") or string.find(n, "cannon") then
                table.insert(possibleBarrelContainers, child)
            end
        end
    end
    if turretModel then
        for _, child in ipairs(turretModel:GetChildren()) do
            local n = string.lower(child.Name)
            if string.find(n, "barrel") or string.find(n, "namlu") or string.find(n, "gun") then
                table.insert(possibleBarrelContainers, child)
            end
        end
    end

    for _, container in ipairs(possibleBarrelContainers) do
        if container:IsA("BasePart") then
            registerBarrelPart(container)
        end
        for _, p in ipairs(container:GetDescendants()) do
            if p:IsA("BasePart") then
                registerBarrelPart(p)
            end
        end
    end

    if #barrelParts == 0 and headObj then
        for _, p in ipairs(headObj:GetDescendants()) do
            if p:IsA("BasePart") then
                local n = string.lower(p.Name)
                if string.find(n, "barrel") or string.find(n, "namlu") or string.find(n, "muzzle") or string.find(n, "gun") or string.find(n, "cannon") or string.find(n, "tip") then
                    registerBarrelPart(p)
                end
            end
        end
    end

    -- Eğer hala özel barrel parçası bulunamadıysa, kafa haricindeki yan parçaları al
    if #barrelParts == 0 and #headParts > 1 then
        for _, p in ipairs(headParts) do
            local n = string.lower(p.Name)
            if n ~= "head" and n ~= "kafa" and n ~= "neck" and n ~= "boyun" and n ~= "stand" then
                registerBarrelPart(p)
            end
        end
    end

    local allMuzzleParts = {}
    for _, p in ipairs(barrelParts) do
        local n = string.lower(p.Name)
        if string.find(n, "muzzle") or string.find(n, "tip") or string.find(n, "namluucu") or string.find(n, "firepoint") then
            table.insert(allMuzzleParts, p)
        end
    end
    if #allMuzzleParts == 0 and #barrelParts > 0 then
        for _, p in ipairs(barrelParts) do
            table.insert(allMuzzleParts, p)
        end
    end
    if #allMuzzleParts == 0 and #headParts > 0 then
        table.insert(allMuzzleParts, headParts[1])
    end
    local muzzlePart = allMuzzleParts[1]

    -- Doğal ileri yön açısı (Heading): Namlu ağırlık merkezinin merkez eksene olan açısı
    local forwardHeading = math.atan2(flatLook.X, flatLook.Z)
    if #barrelParts > 0 then
        local avgPos = Vector3.zero
        for _, p in ipairs(barrelParts) do
            avgPos = avgPos + p.Position
        end
        avgPos = avgPos / #barrelParts
        local offset = Vector3.new(avgPos.X - axisX, 0, avgPos.Z - axisZ)
        if offset.Magnitude > 0.15 then
            forwardHeading = math.atan2(offset.X, offset.Z)
        end
    end

    -- Kurulma Efekti (Küçük parlama ve zemin şok dalgası)
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 1, 1)
    ring.CFrame = CFrame.new(Vector3.new(groundPos.X, groundY + 0.1, groundPos.Z)) * CFrame.Angles(0, 0, math.pi / 2)
    ring.Color = Color3.fromRGB(255, 180, 50)
    ring.Material = Enum.Material.Neon
    ring.Anchored = true
    ring.CanCollide = false
    ring.Parent = workspace
    TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 8, 8),
        Transparency = 1
    }):Play()
    Debris:AddItem(ring, 0.45)

    -- Baş üstü Süre Göstergesi (BillboardGui)
    -- Kullanıcı isteği: "taretlerin üstünde sadece süresinin bitmesine ne kadar kalacağı yazsın"
    local duration = data.TurretDuration or 25
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "TurretTimerUI"
    bgui.Size = UDim2.new(3.5, 0, 0.85, 0)

    -- Model yüksekliğine göre baş üstü ofseti dinamik hesapla
    local heightOffset = 3.6
    if turretModel:IsA("Model") then
        local _, modelSize = turretModel:GetBoundingBox()
        heightOffset = math.max(3.2, modelSize.Y + 0.8)
    end
    bgui.StudsOffset = Vector3.new(0, heightOffset, 0)
    bgui.AlwaysOnTop = true
    bgui.LightInfluence = 0
    bgui.MaxDistance = 70
    bgui.Adornee = primaryPart or turretModel.PrimaryPart
    bgui.Parent = turretModel

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(1, 0, 1, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font = Enum.Font.Arcade
    timerLabel.TextScaled = true
    timerLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
    timerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    timerLabel.TextStrokeTransparency = 0.1
    timerLabel.Text = tostring(math.ceil(duration)) .. "s"
    timerLabel.Parent = bgui

    turretModel.Parent = TurretsFolder

    -- Taret Çalışma Döngüsü
    task.spawn(function()
        local duration = data.TurretDuration or 25
        local remainingTime = duration
        local lastShot = 0
        local fireRate = data.TurretFireRate or 1.0
        local range = data.TurretRange or 40
        local currentAngle = 0 -- Spawn anındaki doğrultudan sapma açısı (Radyan)
        local recoilDist = 0 -- Namlu geri tepme mesafesi (stud)

        while remainingTime > 0 do
            local dt = task.wait(0.03)
            -- Model veya oyuncu silinmişse taret döngüsünü sonlandır (Zombie thread önleme)
            if not (turretModel and turretModel.Parent) or not (player and player.Parent) then break end
            if ReplicatedStorage:GetAttribute("IsPaused") or player:GetAttribute("DisabledWeapon_Turret") == true then continue end

            remainingTime = remainingTime - dt
            if timerLabel and timerLabel.Parent then
                timerLabel.Text = tostring(math.max(0, math.ceil(remainingTime))) .. "s"
                if remainingTime <= 5 then
                    timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
            end

            -- Geri tepme sönümleme (Geriye tepen namlu 0.16 saniyede pürüzsüzce ileri yaylansın)
            if recoilDist > 0 then
                recoilDist = math.max(0, recoilDist - (dt * 4.2))
            end

            -- Canlı hedef bul (Arama merkezi olarak taret taban merkezi)
            local centerPos = Vector3.new(axisX, groundY + 2.0, axisZ)
            local currentRange = data.TurretRange or range or 40
            local target, dist = getNearestEnemyForTurret(centerPos, currentRange)

            if target and target.Parent then
                local targetPos = target:GetPivot().Position
                local aimOffset = Vector3.new(targetPos.X - axisX, 0, targetPos.Z - axisZ)

                -- Hedefe doğru yumuşak açısal servo motor takibi
                if aimOffset.Magnitude > 0.1 then
                    local enemyHeading = math.atan2(aimOffset.X, aimOffset.Z)
                    local targetAngle = enemyHeading - forwardHeading

                    -- En kısa açısal farkı bul (-pi ile +pi arası)
                    local diff = (targetAngle - currentAngle + math.pi) % (2 * math.pi) - math.pi

                    -- Hızlı ve pürüzsüz servo motor dönüşü (saniyede 14 radyan ~800 derece/sn)
                    local maxStep = 14.0 * dt
                    local step = math.clamp(diff, -maxStep, maxStep)
                    currentAngle = currentAngle + step
                end

                -- Ateş etme süresi geldi mi?
                local currentFireRate = data.TurretFireRate or fireRate or 1.0
                if (os.clock() - lastShot) >= currentFireRate then
                    lastShot = os.clock()

                    local extraShots = data.TurretExtraShots or 0
                    local totalShots = getEffectiveProjectileCount(1 + extraShots, 1)

                    task.spawn(function()
                        local pendingDamageMap = {}

                        for shotIndex = 1, totalShots do
                            if shotIndex > 1 then
                                task.wait(0.08)
                                if not (turretModel and turretModel.Parent) then break end
                            end

                            -- Her atışta hedefi kontrol et: Ölecek hedefe fazladan mermi gönderme (overkill önleme)
                            local currentTarget, cDist = getNearestEnemyForTurret(centerPos, currentRange, pendingDamageMap)
                            if not currentTarget or not currentTarget.Parent then
                                -- Vurulacak başka canlı hedef kalmadıysa atışı sonlandır
                                break
                            end

                            local isCrit = math.random() < ((data.CritChance or 0.10) + (data.TurretCritChance or 0))
                            local baseDmg = (data.TurretDamage or 9) * (data.DamageMultiplier or 1.0)
                            local critMult = (data.CritMultiplier or 1.5) + (data.TurretCritDamage or 0)
                            local finalDmg = isCrit and (baseDmg * critMult) or baseDmg

                            -- Bu hedefe gidecek hasarı sanal olarak ekle (sonraki atış bu hedefin öleceğini bilsin)
                            pendingDamageMap[currentTarget] = (pendingDamageMap[currentTarget] or 0) + finalDmg

                            -- Hedefe doğru anlık kafa/namlu yönelmesi (farklı bir hedefe geçerse namlu oraya dönsün)
                            local curTargetPos = currentTarget:GetPivot().Position
                            local curAimOffset = Vector3.new(curTargetPos.X - axisX, 0, curTargetPos.Z - axisZ)
                            if curAimOffset.Magnitude > 0.1 then
                                local enemyHeading = math.atan2(curAimOffset.X, curAimOffset.Z)
                                currentAngle = enemyHeading - forwardHeading
                            end

                            -- Muzzle (Namlu ucu) anlık pozisyonu (Çok namlulu modellerde namlular arası sırayla ateşler)
                            local currentMuzzle = allMuzzleParts[((shotIndex - 1) % #allMuzzleParts) + 1] or muzzlePart
                            local currentMuzzlePos = currentMuzzle and currentMuzzle.Position or Vector3.new(axisX, groundY + 2.0, axisZ)

                            -- NAMLU GERİ TEPME (RECOIL KICKBACK)
                            recoilDist = 0.70

                            -- Canavarın konumu ve mermi uçuş süresi
                            local shotDist = (curTargetPos - currentMuzzlePos).Magnitude
                            local bulletSpeed = 95
                            local flightTime = math.clamp(shotDist / bulletSpeed, 0.05, 0.40)

                            -- İstemcilere mermi çizdir
                            if PlayProjectileVisual then
                                PlayProjectileVisual:FireAllClients("Bullet", currentMuzzlePos, currentTarget, bulletSpeed, curTargetPos, 1)
                            end
                            if player then
                                ProgressionManager.AddProgress(player, "ProjectileCount", 1)
                            end

                            -- Ateş sesi / Muzzle flash
                            local flash = Instance.new("PointLight")
                            flash.Color = Color3.fromRGB(255, 200, 100)
                            flash.Range = 8
                            flash.Brightness = 4
                            flash.Parent = currentMuzzle or muzzlePart or primaryPart
                            Debris:AddItem(flash, 0.08)

                            -- Hasarı mermi hedefe vardığında uygula (Duraklatma / Pause uyumlu)
                            local targetToHit = currentTarget
                            local damageToApply = finalDmg
                            local critToApply = isCrit
                            delayWithPause(flightTime, function()
                                if targetToHit and targetToHit.Parent and targetToHit:FindFirstChild("Health") and targetToHit.Health.Value > 0 then
                                    local enemyType = targetToHit:GetAttribute("EnemyType")
                                    local wasKilled = WeaponSystem.DealDamage(targetToHit, damageToApply, critToApply)

                                    -- Savaş ve hasar istatistiklerini kaydet (RecordCombatStat)
                                    local RecordCombatStat = Events:FindFirstChild("RecordCombatStat")
                                    if RecordCombatStat and player and player.Parent then
                                        RecordCombatStat:Fire(player, "Damage", "TurretWeapon", damageToApply)
                                        if wasKilled and enemyType then
                                            RecordCombatStat:Fire(player, "Kill", enemyType, 1)
                                        end
                                    end
                                end
                            end)
                        end
                    end)
                end
            end

            -- DÖNÜŞ VE GERİ TEPME (RECOIL) GÜNCELLEMESİ:
            -- Her frame tüm kafa ve namlu parçalarını güncel CFrame'lerine oturt
            local rotCFrame = CFrame.new(axisX, 0, axisZ) * CFrame.Angles(0, currentAngle, 0) * CFrame.new(-axisX, 0, -axisZ)
            local aimAngle = forwardHeading + currentAngle
            local aimDir = Vector3.new(math.sin(aimAngle), 0, math.cos(aimAngle))
            local recoilOffset = -aimDir * recoilDist

            for _, part in ipairs(headParts) do
                if part and part.Parent then
                    local initCF = initialHeadCFrames[part]
                    if initCF then
                        local baseCF = rotCFrame * initCF
                        if barrelPartSet[part] and recoilDist > 0 then
                            -- Namlu parçası tam namlu doğrultusunda geriye teper
                            part.CFrame = baseCF + recoilOffset
                        elseif recoilDist > 0 then
                            -- Kafa ve gövde parçaları hafifçe (0.12x) tok bir sarsıntı ile teper
                            part.CFrame = baseCF + (recoilOffset * 0.12)
                        else
                            part.CFrame = baseCF
                        end
                    end
                end
            end
        end

        -- Süre bittiğinde yok olma animasyonu
        if turretModel and turretModel.Parent then
            local pPos = turretModel:GetPivot().Position
            local smoke = Instance.new("Part")
            smoke.Size = Vector3.new(1, 1, 1)
            smoke.Position = pPos + Vector3.new(0, 1, 0)
            smoke.Anchored = true
            smoke.CanCollide = false
            smoke.Transparency = 1
            smoke.Parent = workspace

            local pe = Instance.new("ParticleEmitter")
            pe.Texture = "rbxassetid://241908477"
            pe.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
            pe.Size = NumberSequence.new(0.5, 2.0)
            pe.Rate = 30
            pe.Lifetime = NumberRange.new(0.3, 0.6)
            pe.Speed = NumberRange.new(2, 6)
            pe.Parent = smoke
            task.delay(0.2, function() pe.Enabled = false end)
            Debris:AddItem(smoke, 1.0)

            turretModel:Destroy()
        end
    end)
end)
