local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WaveConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WaveConfig"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyConfig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DifficultyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DifficultyConfig"))

local function getDifficultyData()
    local diffId = workspace:GetAttribute("Difficulty") or "Easy"
    return DifficultyConfig.Get(diffId)
end

-- Events folder and RemoteEvents
local Events = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder", ReplicatedStorage)
Events.Name = "Events"

local ShowMessageEvent = Events:FindFirstChild("ShowMessage") or Instance.new("RemoteEvent", Events)
ShowMessageEvent.Name = "ShowMessage"

local SwarmWarningEvent = Events:FindFirstChild("SwarmWarning") or Instance.new("RemoteEvent", Events)
SwarmWarningEvent.Name = "SwarmWarning"

local BossDefeatedBindable = Events:FindFirstChild("BossDefeated") or Instance.new("BindableEvent", Events)
BossDefeatedBindable.Name = "BossDefeated"

local EndMatchBindable = Events:FindFirstChild("EndMatch") or Instance.new("BindableEvent", Events)
EndMatchBindable.Name = "EndMatch"

-- Setup Enemies Folder
local enemiesFolder = workspace:FindFirstChild("Enemies")
if not enemiesFolder then
    enemiesFolder = Instance.new("Folder")
    enemiesFolder.Name = "Enemies"
    enemiesFolder.Parent = workspace
end

-- Initialize GameTime Value
local gameTimeVal = ReplicatedStorage:FindFirstChild("GameTime")
if not gameTimeVal then
    gameTimeVal = Instance.new("NumberValue")
    gameTimeVal.Name = "GameTime"
    gameTimeVal.Value = -5
    gameTimeVal.Parent = ReplicatedStorage
end

-- Physics Collision Groups Setup (Players vs Enemies physical pushing enabled for solid blocking)
local PhysicsService = game:GetService("PhysicsService")
pcall(function()
    PhysicsService:RegisterCollisionGroup("Players")
end)
pcall(function()
    PhysicsService:RegisterCollisionGroup("Enemies")
end)
pcall(function()
    PhysicsService:CollisionGroupSetCollidable("Players", "Enemies", true)
end)
pcall(function()
    PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
end)
pcall(function()
    PhysicsService:CollisionGroupSetCollidable("Enemies", "Enemies", false) -- CPU Optimizasyonu: Canavarlar arası itme Lua SpatialGrid boids ile yönetilir, fizik motoru zorlanmaz
end)

-- Server State
local activeEnemies = {}
local lastDamageTimes = {}
local lastSpawnTime = 0

_G.ActiveEnemies = activeEnemies

local nextNetworkID = 1

local EnemyReplicationEvent = Events:FindFirstChild("EnemyReplication") or Instance.new("UnreliableRemoteEvent", Events)
EnemyReplicationEvent.Name = "EnemyReplication"
EnemyReplicationEvent.Parent = Events

-- Spatial Grid Implementation (Optimized with zero string GC and table reuse)
local SpatialGrid = {}
SpatialGrid.Grid = {}
local CELL_SIZE = 15

-- 32-bit mathematical key: 100% collision-free integer key for coordinates between -32768 and 32767
local function getCellKey(cx, cz)
    return (cx + 32768) * 65536 + (cz + 32768)
end

function SpatialGrid.Clear()
    SpatialGrid.Grid = {}
end

function SpatialGrid.Insert(enemy, pos)
    local cx = math.floor(pos.X / CELL_SIZE)
    local cz = math.floor(pos.Z / CELL_SIZE)
    local key = getCellKey(cx, cz)
    
    local cell = SpatialGrid.Grid[key]
    if not cell then
        cell = {}
        SpatialGrid.Grid[key] = cell
    end
    cell[enemy] = true
    
    local data = activeEnemies[enemy]
    if data then
        data.LastCellX = cx
        data.LastCellZ = cz
    end
end

function SpatialGrid.Remove(enemy, cx, cz)
    if not cx or not cz then return end
    local key = getCellKey(cx, cz)
    local cell = SpatialGrid.Grid[key]
    if cell then
        cell[enemy] = nil
        if not next(cell) then
            SpatialGrid.Grid[key] = nil
        end
    end
end

function SpatialGrid.Update(enemy, pos)
    local data = activeEnemies[enemy]
    if not data then return end
    
    local cx = math.floor(pos.X / CELL_SIZE)
    local cz = math.floor(pos.Z / CELL_SIZE)
    
    if cx ~= data.LastCellX or cz ~= data.LastCellZ then
        SpatialGrid.Remove(enemy, data.LastCellX, data.LastCellZ)
        SpatialGrid.Insert(enemy, pos)
    end
end

local defaultQueryBuffer = {}
function SpatialGrid.GetNearby(pos, radius, outTable)
    local results = outTable or defaultQueryBuffer
    table.clear(results)
    
    local startX = math.floor((pos.X - radius) / CELL_SIZE)
    local endX = math.floor((pos.X + radius) / CELL_SIZE)
    local startZ = math.floor((pos.Z - radius) / CELL_SIZE)
    local endZ = math.floor((pos.Z + radius) / CELL_SIZE)
    
    for cx = startX, endX do
        for cz = startZ, endZ do
            local key = getCellKey(cx, cz)
            local cell = SpatialGrid.Grid[key]
            if cell then
                for enemy in pairs(cell) do
                    table.insert(results, enemy)
                end
            end
        end
    end
    return results
end

_G.SpatialGrid = SpatialGrid

-- Global Enemy Knockback Handler (used by weapon systems, spiked armor, explosives)
local function applyEnemyKnockback(hitbox, pushDir, force)
    if not hitbox then return end
    local data = activeEnemies[hitbox]
    if not data or data.IsBoss then return end -- Bosses have unstoppability immunity
    
    local flatPush = Vector3.new(pushDir.X, 0, pushDir.Z)
    if flatPush.Magnitude > 0.01 then
        flatPush = flatPush.Unit
        local mass = data.Mass or (data.Scale or 1.0)
        local knockSpeed = (force or 25) / math.max(0.6, mass)
        data.KnockbackVelocity = flatPush * knockSpeed
    end
end
_G.ApplyEnemyKnockback = applyEnemyKnockback

-- Map props exclusion list (for spawning enemies safely and ignoring decorative non-solid props)
local mapSpawnExcludeList = {}
local mapDecorativeExcludeList = {}

local function updateMapPropsExcludeList()
    mapSpawnExcludeList = {}
    mapDecorativeExcludeList = {}
    local mapFolder = workspace:FindFirstChild("ProceduralMap")
    if mapFolder then
        for _, child in ipairs(mapFolder:GetChildren()) do
            local name = child.Name
            if name == "Tree" or name == "Rock" or name == "Log" or name == "Flowers" or name == "GrassProp" then
                mapSpawnExcludeList[#mapSpawnExcludeList + 1] = child
            end
            -- Only non-collidable decorative props are excluded from runtime movement/climb raycasts
            if name == "Flowers" or name == "GrassProp" or name == "Grass" then
                mapDecorativeExcludeList[#mapDecorativeExcludeList + 1] = child
            end
        end
    end
end

-- ── CACHED RAYCAST PARAMS & CLIMB CONFIG ────────────────────────────────────
local CLIMB_COOLDOWN = 0.2
local MAX_LEDGE_HEIGHT = 28.0 -- Allows climbing multi-tier procedural terraces (8, 16, 24 studs)
local PROBE_DEPTHS = {0.8, 1.8, 3.0, 4.5, 6.0}

local rayGround    = RaycastParams.new()
local rayWall      = RaycastParams.new()
local rayTerrain   = RaycastParams.new()
local overlapClimb = OverlapParams.new()

rayGround.FilterType    = Enum.RaycastFilterType.Exclude; rayGround.RespectCanCollide    = true
rayWall.FilterType      = Enum.RaycastFilterType.Exclude; rayWall.RespectCanCollide      = true
rayTerrain.FilterType   = Enum.RaycastFilterType.Exclude; rayTerrain.RespectCanCollide   = true
overlapClimb.FilterType = Enum.RaycastFilterType.Exclude; overlapClimb.RespectCanCollide = true

-- Güvenli başlangıç değeri: en azından düşman hitbox'larını dışlar
rayGround.FilterDescendantsInstances    = { enemiesFolder }
rayWall.FilterDescendantsInstances      = { enemiesFolder }
rayTerrain.FilterDescendantsInstances   = { enemiesFolder }
overlapClimb.FilterDescendantsInstances = { enemiesFolder }

local function rebuildRaycastFilters()
    -- Shared exclude: enemies folder + purely decorative non-solid props (Rocks and Logs remain collidable and climbable!)
    local shared = { enemiesFolder }
    for _, prop in ipairs(mapDecorativeExcludeList) do
        shared[#shared + 1] = prop
    end
    
    -- Ground snap exclude: also excludes player characters to prevent jitter/floating
    local groundExclude = {}
    for i = 1, #shared do
        groundExclude[i] = shared[i]
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char then groundExclude[#groundExclude + 1] = char end
    end
    rayGround.FilterDescendantsInstances    = groundExclude
    rayWall.FilterDescendantsInstances      = groundExclude
    overlapClimb.FilterDescendantsInstances = groundExclude

    -- Terrain-only: keep player characters in the cast (they stand on terrain too)
    local terrain = { enemiesFolder }
    for _, prop in ipairs(mapDecorativeExcludeList) do
        terrain[#terrain + 1] = prop
    end
    rayTerrain.FilterDescendantsInstances = terrain
end

-- Rebuild whenever the character roster changes
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(rebuildRaycastFilters)
    p.CharacterRemoving:Connect(rebuildRaycastFilters)
    rebuildRaycastFilters()
end)
Players.PlayerRemoving:Connect(rebuildRaycastFilters)
for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(rebuildRaycastFilters)
    p.CharacterRemoving:Connect(rebuildRaycastFilters)
end

ReplicatedStorage:GetAttributeChangedSignal("MapGenerated"):Connect(function()
    updateMapPropsExcludeList()
    rebuildRaycastFilters()
end)
if ReplicatedStorage:GetAttribute("MapGenerated") == true then
    updateMapPropsExcludeList()
    rebuildRaycastFilters()
end
local processedSwarms = {}
local processedBosses = {}
local phaseSpawnedCounts = {}
local lastActivePhase = nil

-- Helper: Get current wave phase
local function getCurrentPhase(currentTime)
    local activePhase = WaveConfig.Phases[1]
    for _, phase in ipairs(WaveConfig.Phases) do
        if currentTime >= phase.Time then
            activePhase = phase
        else
            break
        end
    end
    return activePhase
end

-- Helper: Get current wave spawn duration scaled by spawn delay
local function getCurrentSpawnDuration()
    local gameTime = math.max(0, gameTimeVal.Value)
    local activePhase = getCurrentPhase(gameTime)
    local delay = activePhase.SpawnDelay or 1.5
    local speedMult = math.clamp(1.5 / delay, 1.0, 5.0)
    return 1.0 / speedMult
end

-- Helper: Check if a position is within the playable map boundaries (well inside boundary cliffs)
local function isWithinMapBounds(position)
    local center = Config.Game.MapCenter or Vector3.new(54.219, 0.767, 200.954)
    local maxRadius = (Config.Game.MaxMapRadius or 330) - 55 -- Sınır duvarları ~295 stud mesafede başlar; 275 stud güvenli oynanabilir alandır
    local dx = position.X - center.X
    local dz = position.Z - center.Z
    return (dx * dx + dz * dz) <= (maxRadius * maxRadius)
end

-- Helper: Get unlocked enemy types based on game time and current phase limits
local function getUnlockedEnemyTypes(currentTime, phase)
    local unlocked = {}
    local limits = phase and phase.EnemyLimits
    local players = Players:GetPlayers()
    local playerCount = math.max(1, #players)
    
    for name, data in pairs(EnemyConfig.Enemies) do
        if not data.IsBoss then
            if limits then
                local limit = limits[name] or 0
                if limit > 0 then
                    local spawned = phaseSpawnedCounts[name] or 0
                    local maxLimit = limit * playerCount
                    if spawned < maxLimit then
                        table.insert(unlocked, {
                            Name = name,
                            Weight = data.SpawnWeight > 0 and data.SpawnWeight or 50,
                            Data = data
                        })
                    end
                end
            else
                -- Fallback old method if phase limits not defined
                local unlockTimes = {
                    Slime = 0,
                    Zombie = 20,
                    FastZombie = 60,
                    ArmoredZombie = 120
                }
                local unlockTime = unlockTimes[name] or 9999
                if currentTime >= unlockTime then
                    table.insert(unlocked, {
                        Name = name,
                        Weight = data.SpawnWeight > 0 and data.SpawnWeight or 50,
                        Data = data
                    })
                end
            end
        end
    end

    -- GÜVENCE / KESİNTİSİZ DOĞUŞ (Safety Net):
    -- Eğer mevcut faz henüz bitmediği halde tüm canavarların limitleri dolmuşsa (örneğin oyuncular faz bitmeden hepsini kestiyse),
    -- oyun asla boş/sessiz kalmasın! Faz bitene kadar o fazın tanımlı canavar türlerini oranlarına göre doğurmaya kesintisiz devam et.
    if #unlocked == 0 and limits then
        for name, data in pairs(EnemyConfig.Enemies) do
            if not data.IsBoss and limits[name] and limits[name] > 0 then
                table.insert(unlocked, {
                    Name = name,
                    Weight = limits[name] or (data.SpawnWeight > 0 and data.SpawnWeight or 50),
                    Data = data
                })
            end
        end
    end

    return unlocked
end

-- Helper: Apply responsive contact damage to a player when touched by an enemy
local function tryDealContactDamage(hitbox, data, player, playerRootPos)
    if not hitbox or not hitbox.Parent or hitbox.Parent ~= enemiesFolder then return false end
    if ReplicatedStorage:GetAttribute("GameStarted") ~= true then return false end
    if ReplicatedStorage:GetAttribute("IsPaused") == true then return false end
    if not player or not player.Character then return false end
    if player.Character:GetAttribute("IsDowned") then return false end
    if hitbox:GetAttribute("IsEmerging") then return false end
    if hitbox:GetAttribute("IsSinking") then return false end
    
    local now = os.clock()
    local lastPlayerDmg = lastDamageTimes[player] or 0
    local enemyLastHit = data.LastHitTime or 0
    
    -- Seri ve hassas temas hasarı (i-frame ve canavar bekleme süreleri):
    -- Oyuncu global i-frame: 0.16s (Sürü içine dalındığında aynı karede anında ölümü engeller)
    -- Canavarın kişisel vuruş cooldown'ı: 0.40s (Dokunulduğunda beklemeden vurur, temas sürdükçe saniyede 2.5 vuruş yapar)
    if (now - lastPlayerDmg >= 0.16) and (now - enemyLastHit >= 0.40) then
        lastDamageTimes[player] = now
        data.LastHitTime = now
        
        local currentPos = data.Position or hitbox.Position
        local targetPos = playerRootPos or (player.Character.PrimaryPart and player.Character.PrimaryPart.Position) or currentPos
        local dmg = data.Damage or hitbox:GetAttribute("Damage") or 1
        
        Events.TakeDamage:Fire(player, dmg, currentPos, hitbox)
        
        -- YALNIZCA hasar vuran canavar hafifçe geriye adımlar (Mikro Recoil)
        local rdx = currentPos.X - targetPos.X
        local rdz = currentPos.Z - targetPos.Z
        local rLenSq = rdx * rdx + rdz * rdz
        local recoilDir = Vector3.new(0, 0, 1)
        if rLenSq > 0.01 then
            local rLen = math.sqrt(rLenSq)
            recoilDir = Vector3.new(rdx / rLen, 0, rdz / rLen)
        end
        
        data.RecoilDir = recoilDir
        data.RecoilEndTime = now + 0.12
        local speed = (hitbox:FindFirstChild("Speed") and hitbox.Speed.Value) or data.Speed or 12
        data.RecoilSpeed = math.max(speed * 0.8, 8)
        return true
    end
    return false
end

-- Helper: Spawn an enemy
local function spawnEnemy(enemyType, isBoss, customSpawnPos, isSwarm, healthOverride, maxHealthOverride)
    local configData = EnemyConfig.Enemies[enemyType]
    if not configData then return end
    
    local players = Players:GetPlayers()
    if #players == 0 then return end
    
    local scale = configData.Scale or 1.0
    local finalSpawnPos = customSpawnPos
    
    if finalSpawnPos then
        if not isWithinMapBounds(finalSpawnPos) then
            return
        end
    else
        -- Pick a random alive player to spawn around
        local targetPlayer = players[math.random(1, #players)]
        local char = targetPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local pX = root.Position.X
        local pZ = root.Position.Z
        
        -- Calculate offset based on current movement velocity (half of speed in movement direction)
        local velocity = root.AssemblyLinearVelocity
        local speed2D = Vector3.new(velocity.X, 0, velocity.Z)
        local offset = speed2D * 0.4
        if offset.Magnitude > 25 then
            offset = offset.Unit * 25
        end
        local spawnCenter = root.Position + offset
        
        -- Try finding a valid spawn point in safe playable bounds
        local spawned = false
        local mapCenter = Config.Game.MapCenter or Vector3.new(54.219, 0.767, 200.954)
        local maxSafeRadius = (Config.Game.MaxMapRadius or 330) - 55
        local maxHeightAllowed = mapCenter.Y + 32 -- Oynanabilir zemin kademesi (0-25 + rampalar); sınır kayalıkları 40+ stud yüksekliktedir
        
        -- Oyuncunun harita merkezine mesafesi ve yönü
        local toCenterX = mapCenter.X - pX
        local toCenterZ = mapCenter.Z - pZ
        local playerDistFromCenter = math.sqrt(toCenterX * toCenterX + toCenterZ * toCenterZ)
        
        -- Haritanın dış kenarlarına yaklaşıldı mı? (Sınıra 85 stud'dan daha yakınsa)
        local isNearMapEdge = playerDistFromCenter > (maxSafeRadius - 85)
        local centerAngle = math.atan2(toCenterZ, toCenterX)
        
        local minSpawnRadius = Config.Game.MinEnemySpawnRadius or 35
        local maxSpawnRadius = Config.Game.EnemySpawnRadius or 91
        
        for i = 1, 24 do
            local angle
            if isNearMapEdge then
                -- Haritanın dış kenarındayken doğuş açısını harita merkezine doğru (içeriye) geniş bir yayla sınırla.
                -- Böylece canavarlar asla oyuncunun dibine sıkışmaz veya arkasındaki sınır duvarına çarpıp yakında doğmaz!
                local spread = (math.random() - 0.5) * math.rad(160) -- ±80 derece harita içine doğru
                angle = centerAngle + spread
            else
                -- Haritanın iç kısımlarındayken 360 derece serbest doğuş
                angle = math.random() * math.pi * 2
            end
            
            local distance = math.random(minSpawnRadius + 10, maxSpawnRadius)
            local testX = spawnCenter.X + math.cos(angle) * distance
            local testZ = spawnCenter.Z + math.sin(angle) * distance
            
            -- 1) Kesin Oyuncu Güvenlik Mesafesi Kontrolü:
            -- Canavar oyuncunun asla çok yakınında (minSpawnRadius içinde) doğamaz!
            local distToPlayerSq = (testX - pX)^2 + (testZ - pZ)^2
            if distToPlayerSq < (minSpawnRadius * minSpawnRadius) then
                continue
            end
            
            -- 2) Harita Sınırı Kontrolü: Güvenli oynanabilir alan içinde mi?
            local dx = testX - mapCenter.X
            local dz = testZ - mapCenter.Z
            local distFromCenter = math.sqrt(dx * dx + dz * dz)
            if distFromCenter > maxSafeRadius then
                -- Sınır dışına taştıysa bu noktayı reddet (asla oyuncunun üstüne doğru geri çekme!)
                continue
            end
            
            -- Işını oyuncunun dikey konumunun makul bir yükseklik seviyesinden aşağı at
            local checkPos = Vector3.new(testX, root.Position.Y + 25, testZ)
            
            -- Raycast down to find ground level
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.RespectCanCollide = true
            
            local excludeList = {enemiesFolder, char}
            for _, prop in ipairs(mapSpawnExcludeList) do
                table.insert(excludeList, prop)
            end
            rayParams.FilterDescendantsInstances = excludeList
            
            local groundRay = workspace:Raycast(checkPos, Vector3.new(0, -70, 0), rayParams)
            if groundRay and groundRay.Instance then
                local hitInst = groundRay.Instance
                
                -- Sınır duvarı (Boundary Cliff) kontrolleri:
                -- 1) Attribute kontrolü (MapGenerator IsBoundary set ediyor)
                local isBoundary = hitInst:GetAttribute("IsBoundary") == true
                if not isBoundary and hitInst.Parent then
                    isBoundary = hitInst.Parent:GetAttribute("IsBoundary") == true
                end
                
                -- 2) İsim kontrolü
                local hitNameLower = string.lower(hitInst.Name)
                local isWallOrCliff = string.find(hitNameLower, "wall")
                    or string.find(hitNameLower, "cliff")
                    or string.find(hitNameLower, "border")
                    or string.find(hitNameLower, "barrier")
                    or string.find(hitNameLower, "sinir")
                    or string.find(hitNameLower, "duvar")
                
                -- 3) Zemin eğim ve yükseklik kontrolü:
                -- Dik duvarlara (normal.Y < 0.7) ve sınır tepelerine (Y > maxHeightAllowed) doğmayı engelle
                local normalOK = groundRay.Normal.Y >= 0.7
                local heightOK = groundRay.Position.Y <= maxHeightAllowed and math.abs(groundRay.Position.Y - root.Position.Y) <= 18
                
                -- 4) 3D Nihai Oyuncu Mesafesi Kontrolü
                local finalDistSq = (groundRay.Position.X - pX)^2 + (groundRay.Position.Z - pZ)^2
                local distOK = finalDistSq >= (minSpawnRadius * minSpawnRadius)
                
                if not isBoundary and not isWallOrCliff and normalOK and heightOK and distOK then
                    finalSpawnPos = Vector3.new(checkPos.X, groundRay.Position.Y + scale * 0.8, checkPos.Z)
                    spawned = true
                    break
                end
            end
        end
        if not spawned then return end
    end
    
    -- Create mathematical Server Hitbox Part
    local hitbox = Instance.new("Part")
    hitbox.Name = isBoss and "BossHitbox" or "EnemyHitbox"
    
    local modelName = configData.ModelName or "Zombie"
    local isZombieModel = (modelName == "Zombie" or modelName == "FastZombie" or modelName == "ArmoredZombie" or modelName == "MegaZombie")
    local radius
    if isZombieModel then
        hitbox.Shape = Enum.PartType.Block
        hitbox.Size = Vector3.new(scale * 2.4, scale * 5.2, scale * 2.4)
        hitbox.Position = finalSpawnPos + Vector3.new(0, scale * 1.8, 0)
        radius = scale * 1.25
    elseif modelName == "Slime" then
        hitbox.Shape = Enum.PartType.Block
        hitbox.Size = Vector3.new(scale * 2.6, scale * 2.4, scale * 2.6)
        hitbox.Position = finalSpawnPos + Vector3.new(0, scale * 0.4, 0)
        radius = scale * 1.35
    else
        hitbox.Shape = Enum.PartType.Block
        hitbox.Size = Vector3.new(scale * 2.4, scale * 3.5, scale * 2.4)
        hitbox.Position = finalSpawnPos + Vector3.new(0, scale * 0.95, 0)
        radius = scale * 1.25
    end
    
    hitbox.Color = Color3.fromRGB(255, 0, 0)
    hitbox.Material = Enum.Material.Neon
    hitbox.Transparency = 1.0
    hitbox.Anchored = true
    hitbox.CanCollide = true
    hitbox.CollisionGroup = "Enemies" -- Collides with Players
    
    -- Setup Health ValueObject
    local gameTime = math.max(0, gameTimeVal.Value)
    local currentPhase = getCurrentPhase(gameTime)
    local healthVal = Instance.new("NumberValue")
    healthVal.Name = "Health"
    
    local diffData = getDifficultyData()
    local maxHealthVal = maxHealthOverride or math.round(configData.Health * currentPhase.Difficulty * (diffData.HpMult or 1.0))
    healthVal.Value = healthOverride or maxHealthVal
    healthVal.Parent = hitbox
    
    -- Setup Speed ValueObject
    local speedVal = Instance.new("NumberValue")
    speedVal.Name = "Speed"
    speedVal.Value = configData.Speed
    speedVal.Parent = hitbox
    
    -- Setup Attributes required by other systems
    local damageVal = math.round(configData.Damage * (1 + (currentPhase.Difficulty - 1) * 0.12) * (diffData.DmgMult or 1.0))
    hitbox:SetAttribute("EnemyType", enemyType)
    hitbox:SetAttribute("IsBoss", isBoss == true)
    hitbox:SetAttribute("Scale", scale)
    hitbox:SetAttribute("Damage", damageVal)
    hitbox:SetAttribute("MaxHealth", maxHealthVal)
    hitbox:SetAttribute("LastDamageTime", os.clock())
    hitbox:SetAttribute("RelocateThreshold", math.random(30, 50))
    
    -- Emerging attributes to prevent movement/tracking during spawn animation
    local spawnDuration = getCurrentSpawnDuration()
    hitbox:SetAttribute("IsEmerging", true)
    hitbox:SetAttribute("SpawnTime", os.clock())
    hitbox:SetAttribute("EmergingDuration", spawnDuration)
    
    local networkID = nextNetworkID
    nextNetworkID = (nextNetworkID % 65535) + 1
    hitbox:SetAttribute("NetworkID", networkID)
    
    -- Parent to Enemies folder
    hitbox.Parent = enemiesFolder
    
    -- Track internally
    activeEnemies[hitbox] = {
        Position = finalSpawnPos,
        Speed = configData.Speed,
        Scale = scale,
        Damage = damageVal,
        IsBoss = isBoss == true,
        IsSwarm = isSwarm == true,
        VerticalVelocity = 0,
        Climb = nil,
        ClimbCooldownUntil = 0,
        NextLedgeCheck = 0,
        StuckTimer = 0,
        LastStuckPos = finalSpawnPos,
        EnemyType = enemyType,
        ModelName = configData.ModelName or "Zombie",
        Archetype = configData.Archetype or (isBoss and "Boss" or "Horde"),
        Mass = configData.Mass or (isBoss and (scale * 25) or scale),
        Radius = radius,
        FlankBias = (math.random(0, 1) == 0 and 1 or -1),
        ApproachAngleOffset = math.random() * math.pi * 2,
        FlankAngle = (math.random(0, 1) == 0 and 0.15 or -0.15),
        KnockbackVelocity = nil,
        NetworkID = networkID,
        TickOffset = math.random(0, 4),
        IsSleeping = false,
        IsOnGround = true,
        LastSentPos = finalSpawnPos,
        LastSentRotY = 0,
        LastAbilityCastTime = isBoss and (os.clock() + math.random(1, 4)) or 0
    }
    
    SpatialGrid.Insert(hitbox, finalSpawnPos)
    
    -- Fiziksel temas anında gecikmesiz vuruş algılama (Touched Event fallback)
    hitbox.Touched:Connect(function(otherPart)
        if not otherPart or not otherPart.Parent then return end
        local player = Players:GetPlayerFromCharacter(otherPart.Parent)
        if player then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local targetPos = root and root.Position or otherPart.Position
            local d = activeEnemies[hitbox]
            if d then
                tryDealContactDamage(hitbox, d, player, targetPos)
            end
        end
    end)
    
    return hitbox
end

-- Clear all enemies
local function clearAllEnemies()
    enemiesFolder:ClearAllChildren()
    table.clear(activeEnemies)
    SpatialGrid.Clear()
end

-- Listen to GameStarted state to reset or clean up
ReplicatedStorage:GetAttributeChangedSignal("GameStarted"):Connect(function()
    local started = ReplicatedStorage:GetAttribute("GameStarted")
    if started then
        clearAllEnemies()
        gameTimeVal.Value = -5
        local matchDuration = Config.Game and Config.Game.MatchDuration or 600
        ReplicatedStorage:SetAttribute("TimeRemaining", matchDuration)
        processedSwarms = {}
        processedBosses = {}
        table.clear(phaseSpawnedCounts)
        lastActivePhase = nil
        ReplicatedStorage:SetAttribute("IsPaused", false)
    else
        clearAllEnemies()
    end
end)

-- Shift boss ability cast timers and enemy damage/spawn timers during pause
-- so abilities don't trigger immediately and idle enemies don't falsely sink into the ground
local pauseStartTime = nil
ReplicatedStorage:GetAttributeChangedSignal("IsPaused"):Connect(function()
    local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
    if isPaused then
        pauseStartTime = os.clock()
    else
        if pauseStartTime then
            local pauseDuration = os.clock() - pauseStartTime
            pauseStartTime = nil
            
            -- Shift player damage lockout timestamps
            for p, t in pairs(lastDamageTimes) do
                lastDamageTimes[p] = t + pauseDuration
            end
            
            -- Shift boss ability timers and climb cooldowns
            for hitbox, data in pairs(activeEnemies) do
                if data then
                    if data.IsBoss and data.LastAbilityCastTime then
                        data.LastAbilityCastTime = data.LastAbilityCastTime + pauseDuration
                    end
                    if data.ClimbCooldownUntil then
                        data.ClimbCooldownUntil = data.ClimbCooldownUntil + pauseDuration
                    end
                    if data.NextLedgeCheck then
                        data.NextLedgeCheck = data.NextLedgeCheck + pauseDuration
                    end
                    if data.LastHitTime then
                        data.LastHitTime = data.LastHitTime + pauseDuration
                    end
                    if data.RecoilEndTime then
                        data.RecoilEndTime = data.RecoilEndTime + pauseDuration
                    end
                end
                
                if hitbox and hitbox.Parent then
                    -- Shift last damage time so enemies don't exceed the relocation threshold during pause
                    local lastDmg = hitbox:GetAttribute("LastDamageTime")
                    if lastDmg then
                        hitbox:SetAttribute("LastDamageTime", lastDmg + pauseDuration)
                    end
                    
                    -- Shift emerging spawn timer so emerging enemies aren't cut short
                    local spawnTime = hitbox:GetAttribute("SpawnTime")
                    if spawnTime then
                        hitbox:SetAttribute("SpawnTime", spawnTime + pauseDuration)
                    end
                    
                    -- Shift slow effect expire time so slowed enemies don't lose their slow effect during pause
                    local slowExpiry = hitbox:GetAttribute("SlowExpireTime")
                    if slowExpiry then
                        hitbox:SetAttribute("SlowExpireTime", slowExpiry + pauseDuration)
                    end
                end
            end
            
            -- Shift player contact damage cooldowns
            for playerRef, t in pairs(lastDamageTimes) do
                lastDamageTimes[playerRef] = t + pauseDuration
            end
        end
    end
end)

-- Main Spawning and Clock Loop
task.spawn(function()
    local lastClockTick = 0
    while true do
        task.wait(0.05) -- Run spawn checks at 20 Hz
        
        -- Only update when game is active and not paused
        if ReplicatedStorage:GetAttribute("GameStarted") ~= true then continue end
        if ReplicatedStorage:GetAttribute("IsPaused") == true then continue end
        
        local now = os.clock()
        
        -- 1 Hz Clock Increment
        if now - lastClockTick >= 1.0 then
            lastClockTick = now
            local gameTime = gameTimeVal.Value
            gameTime = gameTime + 1
            gameTimeVal.Value = gameTime
            
            -- Wait during preparation phase
            if gameTime < 0 then continue end
            
            local matchDuration = Config.Game and Config.Game.MatchDuration or 600
            local remaining = math.max(0, matchDuration - gameTime)
            ReplicatedStorage:SetAttribute("TimeRemaining", remaining)

            -- Son 1 dakika uyarısı
            if remaining == 60 then
                ShowMessageEvent:FireAllClients("1 MINUTE REMAINING - SURVIVE!", Color3.fromRGB(255, 120, 40))
            end

            -- 15 Dakika (900 saniye) tamamlandığında oyunu zafer ile sonlandır
            if remaining <= 0 then
                EndMatchBindable:Fire(true)
                continue
            end
            
            -- 1. Check for Swarms (only check on whole seconds)
            for _, swarm in ipairs(WaveConfig.Swarms) do
                if gameTime == swarm.Time and not processedSwarms[swarm.Time] then
                    processedSwarms[swarm.Time] = true
                    
                    SwarmWarningEvent:FireAllClients()
                    
                    -- Sürüyü 10 saniye içine eşit ve akıcı dağıtarak spawnla
                    task.spawn(function()
                        local totalToSpawn = swarm.Count
                        local duration = 10.0
                        local batchInterval = 0.20 -- Her 0.2 saniyede bir mikro paket
                        local totalBatches = math.floor(duration / batchInterval) -- 50 paket
                        local countPerBatch = totalToSpawn / totalBatches
                        local spawned = 0
                        local accumulator = 0
                        
                        for batch = 1, totalBatches do
                            if ReplicatedStorage:GetAttribute("GameStarted") ~= true then break end
                            
                            accumulator = accumulator + countPerBatch
                            local toSpawnNow = math.floor(accumulator) - spawned
                            for _ = 1, toSpawnNow do
                                spawnEnemy(swarm.Type, false, nil, true)
                                spawned = spawned + 1
                            end
                            
                            local waited = 0
                            while waited < batchInterval do
                                local dt = task.wait()
                                if not ReplicatedStorage:GetAttribute("IsPaused") then
                                    waited = waited + dt
                                end
                            end
                        end
                        
                        -- Kalan yuvarlama farkını tamamla
                        while spawned < totalToSpawn do
                            if ReplicatedStorage:GetAttribute("GameStarted") ~= true then break end
                            spawnEnemy(swarm.Type, false, nil, true)
                            spawned = spawned + 1
                        end
                    end)
                end
            end
            
            -- 2. Check for Bosses (only check on whole seconds)
            for _, boss in ipairs(EnemyConfig.Bosses) do
                if gameTime == boss.Time and not processedBosses[boss.Time] then
                    processedBosses[boss.Time] = true
                    
                    ShowMessageEvent:FireAllClients("WARNING: BOSS SPAWNED!", Color3.fromRGB(255, 30, 30))
                    
                    task.spawn(function()
                        for i = 1, boss.Count do
                            if ReplicatedStorage:GetAttribute("GameStarted") ~= true then return end
                            
                            -- Eğer oyun şu an duraklatılmışsa, duraklatma bitene kadar bekle
                            while ReplicatedStorage:GetAttribute("IsPaused") == true do
                                task.wait(0.1)
                                if ReplicatedStorage:GetAttribute("GameStarted") ~= true then return end
                            end
                            
                            spawnEnemy(boss.Type, true)
                            
                            if i < boss.Count then
                                -- Duraklatma kurallarına tam uyumlu 3.5 saniyelik aktif oyun süresi beklemesi
                                local waited = 0
                                local delayBetweenBosses = 3.5 -- 3.5 saniye arayla doğsunlar (yetenekleri aynı anda atmamaları için)
                                while waited < delayBetweenBosses do
                                    local dt = task.wait()
                                    if ReplicatedStorage:GetAttribute("GameStarted") ~= true then return end
                                    if not ReplicatedStorage:GetAttribute("IsPaused") then
                                        waited = waited + dt
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end
        
        -- 3. Regular Spawning (runs at 20 Hz)
        local gameTime = gameTimeVal.Value
        if gameTime >= 0 then
            local currentPhase = getCurrentPhase(gameTime)
            
            -- Phase change detection to reset spawn limit counters
            if currentPhase ~= lastActivePhase then
                lastActivePhase = currentPhase
                table.clear(phaseSpawnedCounts)
            end
            
            local players = Players:GetPlayers()
            if #players > 0 then
                local activeCount = 0
                local totalEnemyCount = 0
                for hitbox, data in pairs(activeEnemies) do
                    if hitbox and hitbox.Parent == enemiesFolder then
                        totalEnemyCount = totalEnemyCount + 1
                        if not data.IsSwarm and not data.IsBoss then
                            activeCount = activeCount + 1
                        end
                    end
                end
                
                local diffData = getDifficultyData()
                local enemyCapMult = (diffData.Tier and diffData.Tier >= 3 and 1.25) or (diffData.Tier and diffData.Tier >= 2 and 1.1) or 1.0
                local maxEnemies = math.round(currentPhase.MaxEnemiesPerPlayer * enemyCapMult * #players)
                local absoluteMax = 180 * #players -- Sunucu performansını koruyan sert tavan
                local effectiveSpawnDelay = currentPhase.SpawnDelay * (diffData.SpawnDelayMult or 1.0)
                if activeCount < maxEnemies and totalEnemyCount < absoluteMax and now - lastSpawnTime >= effectiveSpawnDelay then
                    lastSpawnTime = now
                    
                    -- Choose random unlocked enemy type
                    local unlockedTypes = getUnlockedEnemyTypes(gameTime, currentPhase)
                    if #unlockedTypes > 0 then
                        local totalWeight = 0
                        for _, t in ipairs(unlockedTypes) do
                            totalWeight = totalWeight + t.Weight
                        end
                        
                        local roll = math.random() * totalWeight
                        local cumulative = 0
                        local chosenType = unlockedTypes[1].Name
                        for _, t in ipairs(unlockedTypes) do
                            cumulative = cumulative + t.Weight
                            if roll <= cumulative then
                                chosenType = t.Name
                                break
                            end
                        end
                        
                        spawnEnemy(chosenType, false)
                        phaseSpawnedCounts[chosenType] = (phaseSpawnedCounts[chosenType] or 0) + 1
                    end
                end
            end
        end
    end
end)

-- Remote Event for Boss Ability Visuals
local PlayBossAbilityVisual = Events:FindFirstChild("PlayBossAbilityVisual") or Instance.new("RemoteEvent", Events)
PlayBossAbilityVisual.Name = "PlayBossAbilityVisual"
PlayBossAbilityVisual.Parent = Events

-- Boss Ability Casting Trigger
local function castBossAbility(bossPart, data)
    data.IsCastingAbility = true
    bossPart:SetAttribute("IsCastingAbility", true)
    
    -- Choose target player position with predictive offset
    local targetPos = data.Position
    local players = Players:GetPlayers()
    local nearestPlayer, minDist = nil, math.huge
    for _, p in ipairs(players) do
        local char = p.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and not char:GetAttribute("IsDowned") then
            local dist = (root.Position - data.Position).Magnitude
            if dist < minDist then
                minDist = dist
                nearestPlayer = p
            end
        end
    end
    
    if nearestPlayer and nearestPlayer.Character then
        local root = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = nearestPlayer.Character:FindFirstChild("Humanoid")
        if root and hum then
            local pos = root.Position
            local moveDir = hum.MoveDirection
            
            if moveDir.Magnitude > 0.1 then
                -- Oyuncu yürüyorsa: Hareket hızına (WalkSpeed) orantılı olarak yürüyeceği yolu tahmin et!
                local currentSpeed = hum.WalkSpeed or 16
                local leadDistance = math.clamp(currentSpeed * 0.95, 8, 26)
                local flatMove = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
                targetPos = pos + flatMove * leadDistance
            else
                -- Oyuncu duruyorsa: Tam oyuncunun bulunduğu yere (kendi üzerine) at!
                targetPos = pos
            end
        end
    end
    
    local duration = 1.6
    local radius = 11.2
    
    -- Send signal to all clients for 60 FPS AAA visual rendering
    PlayBossAbilityVisual:FireAllClients(targetPos, duration, radius)
    
    -- Wait for warning charge duration (with game pause awareness and safety checks)
    task.spawn(function()
        local elapsed = 0
        while elapsed < duration do
            local dt = task.wait()
            if ReplicatedStorage:GetAttribute("GameStarted") ~= true or not bossPart or not bossPart.Parent then
                data.IsCastingAbility = false
                if bossPart and bossPart.Parent then
                    bossPart:SetAttribute("IsCastingAbility", false)
                end
                return
            end
            if not ReplicatedStorage:GetAttribute("IsPaused") then
                elapsed = elapsed + dt
            end
        end
        
        if bossPart and bossPart.Parent then
            -- Deal AoE damage to all players standing in the blast zone
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and not char:GetAttribute("IsDowned") then
                    local dist = (root.Position - targetPos).Magnitude
                    if dist <= radius then
                        Events.TakeDamage:Fire(p, math.round(data.Damage * 1.5), targetPos, hitbox)
                    end
                end
            end
        end
        
        -- End casting state
        data.IsCastingAbility = false
        if bossPart and bossPart.Parent then
            bossPart:SetAttribute("IsCastingAbility", false)
        end
    end)
end

-- ── LEDGE HOP TIRMANIŞ SİSTEMİ ──────────────────────────────────────────────
-- Tırmanabilir çıkıntı ve teras tespiti: Çoklu derinlik kontrolü, ağaç/yaprak filtreleme
-- ve engel kontrolü ile duvarlara takılmadan yukarı tırmanmayı sağlar.
local function findLedge(currentPos, moveDelta, toPlayerDir, scale, networkId)
    local mapCenterY = (Config.Game.MapCenter and Config.Game.MapCenter.Y) or 0.767
    local maxClimbHeightAllowed = mapCenterY + 36.0
    
    if currentPos.Y > maxClimbHeightAllowed then
        return nil, nil
    end
    
    local feetY = currentPos.Y - scale * 0.8
    local isSlime = (scale <= 1.0)
    local rayOrigin = Vector3.new(currentPos.X, feetY + (isSlime and 0.5 or math.clamp(scale * 0.8, 0.8, 2.0)), currentPos.Z)
    local checkDist = scale * 1.5 + 3.0
    
    local function testWall(dir)
        if not dir or dir.Magnitude < 0.01 then return nil end
        local dirUnit = dir.Unit
        local startPos = rayOrigin - dirUnit * 0.4
        local hit = workspace:Raycast(startPos, dirUnit * (checkDist + 0.4), rayWall)
        if not hit then
            local lowOrigin = Vector3.new(currentPos.X, feetY + 0.4, currentPos.Z)
            hit = workspace:Raycast(lowOrigin - dirUnit * 0.4, dirUnit * (checkDist + 0.4), rayWall)
        end
        return hit
    end
    
    -- Birincil olarak hedefe (oyuncuya) veya hareket yönüne doğru test et
    local wallRay = nil
    if toPlayerDir and toPlayerDir.Magnitude > 0.01 then
        wallRay = testWall(toPlayerDir)
    end
    if not wallRay and moveDelta and moveDelta.Magnitude > 0.01 then
        wallRay = testWall(moveDelta)
    end
    
    if not wallRay or not wallRay.Instance then
        return nil, nil
    end
    
    local normal = wallRay.Normal
    if math.abs(normal.Y) >= 0.70 then
        -- Yüzey dik duvar değil (hafif eğimli rampa), normal yürüyüşe bırak
        return nil, wallRay
    end
    
    local hitInst = wallRay.Instance
    local isBoundary = hitInst:GetAttribute("IsBoundary") == true
        or (hitInst.Parent and hitInst.Parent:GetAttribute("IsBoundary") == true)
    if isBoundary then
        return nil, wallRay
    end
    
    local flatNormal = Vector3.new(normal.X, 0, normal.Z)
    if flatNormal.Magnitude < 0.01 then return nil, wallRay end
    local into = -flatNormal.Unit
    local baseWallX = wallRay.Position.X
    local baseWallZ = wallRay.Position.Z
    local boxSize = Vector3.new(scale * 1.6, scale * 1.2, scale * 1.6)
    
    -- Ağaçları ve engelleri atlayarak gerçek zemin yüzeyini bulan yardımcı
    local function findSolidGroundBelow(probeXZ, fromY, maxDist)
        local currOrigin = Vector3.new(probeXZ.X, fromY, probeXZ.Z)
        local remDist = maxDist
        while remDist > 0 do
            local hit = workspace:Raycast(currOrigin, Vector3.new(0, -remDist, 0), rayGround)
            if not hit or not hit.Instance then return nil end
            local inst = hit.Instance
            local isTree = inst.Name == "Tree" or (inst.Parent and inst.Parent.Name == "Tree") or inst:FindFirstAncestor("Tree")
            if isTree then
                local hitY = hit.Position.Y
                local drop = math.max(0.5, (currOrigin.Y - hitY) + 0.2)
                remDist = remDist - drop
                currOrigin = Vector3.new(probeXZ.X, hitY - 0.2, probeXZ.Z)
            else
                return hit
            end
        end
        return nil
    end
    
    for _, depth in ipairs(PROBE_DEPTHS) do
        local probeXZ = Vector3.new(baseWallX, 0, baseWallZ) + into * (depth + scale * 0.35)
        local ledgeHit = findSolidGroundBelow(probeXZ, feetY + MAX_LEDGE_HEIGHT + 0.5, MAX_LEDGE_HEIGHT + 2.0)
        
        if ledgeHit and ledgeHit.Instance and ledgeHit.Normal.Y >= 0.55 then
            local hitLedgeInst = ledgeHit.Instance
            local isLedgeBoundary = hitLedgeInst:GetAttribute("IsBoundary") == true
                or (hitLedgeInst.Parent and hitLedgeInst.Parent:GetAttribute("IsBoundary") == true)
            
            if not isLedgeBoundary then
                local h = ledgeHit.Position.Y - feetY
                local landingY = ledgeHit.Position.Y + (scale * 0.8 + 0.05)
                
                -- Hem göreli yükseklik (0.8 - MAX_LEDGE_HEIGHT) hem de mutlak harita sınırı kontrolü
                if h > 0.8 and h <= MAX_LEDGE_HEIGHT and landingY <= maxClimbHeightAllowed then
                    local landing = Vector3.new(probeXZ.X, landingY, probeXZ.Z)
                    
                    -- İniş noktasında kafa seviyesinde tavan/çatı engelleyici var mı kontrolü
                    local blockers = workspace:GetPartBoundsInBox(CFrame.new(landing + Vector3.new(0, 0.3, 0)), boxSize, overlapClimb)
                    local hasSolidBlocker = false
                    local hitModel = hitLedgeInst:FindFirstAncestorOfClass("Model")
                    for _, b in ipairs(blockers) do
                        if b.CanCollide and b ~= hitLedgeInst and (not hitModel or not b:IsDescendantOf(hitModel)) then
                            if (b.Position.Y + b.Size.Y * 0.5) > (landingY + 0.8) then
                                hasSolidBlocker = true
                                break
                            end
                        end
                    end
                    
                    if not hasSolidBlocker then
                        local wallDist = scale * 1.05 + 0.1
                        local wallStand = Vector3.new(
                            baseWallX + normal.X * wallDist,
                            currentPos.Y,
                            baseWallZ + normal.Z * wallDist
                        )
                        return {
                            wallStand = wallStand,
                            landing = landing,
                            height = h,
                            normal = normal
                        }
                    end
                end
            end
        end
    end
    
    return nil
end

local function testQuickWallRay(currentPos, dir, scale)
    if not dir or dir.Magnitude < 0.001 then return nil end
    local feetY = currentPos.Y - scale * 0.8
    local origin = Vector3.new(currentPos.X, feetY + math.clamp(scale * 0.8, 0.8, 2.0), currentPos.Z)
    local checkDist = scale * 1.5 + 2.5
    local dirUnit = dir.Unit
    local hit = workspace:Raycast(origin - dirUnit * 0.3, dirUnit * (checkDist + 0.3), rayWall)
    if not hit then
        local lowOrigin = Vector3.new(currentPos.X, feetY + 0.4, currentPos.Z)
        hit = workspace:Raycast(lowOrigin - dirUnit * 0.3, dirUnit * (checkDist + 0.3), rayWall)
    end
    return hit
end

local function startClimb(data, currentPos, ledge, actualSpeed)
    local climbSpeed = math.max(14.0, actualSpeed * 1.3)
    local duration = math.max(0.28, ledge.height / climbSpeed) + 0.15
    data.Climb = {
        p0 = currentPos,
        p1 = Vector3.new(ledge.wallStand.X, ledge.landing.Y, ledge.wallStand.Z),
        p2 = ledge.landing,
        normal = ledge.normal,
        t = 0,
        duration = duration,
    }
end

local function updateClimb(data, dt)
    local c = data.Climb
    if not c then return data.Position, nil end
    c.t = math.min(1.0, c.t + dt / c.duration)
    
    local pos
    if c.t < 0.75 then
        -- 1. Aşama: Duvar boyunca yukarı pürüzsüz interpolasyon
        local a = c.t / 0.75
        local smoothA = math.sin(a * math.pi * 0.5)
        pos = c.p0:Lerp(c.p1, smoothA)
    else
        -- 2. Aşama: Terasın üstüne adım atma (Ledge shelf hop)
        local a = (c.t - 0.75) / 0.25
        local smoothA = a * a * (3 - 2 * a)
        pos = c.p1:Lerp(c.p2, smoothA)
    end
    
    local climbNormal = c.normal
    
    if c.t >= 1.0 then
        local landingPos = c.p2
        local scale = data.Scale or 1.0
        data.Climb = nil
        data.VerticalVelocity = 0
        data.IsOnGround = true
        data.CachedGroundY = landingPos.Y - (scale * 0.8)
        data.LastRaycastPos = landingPos
        data.ClimbCooldownUntil = os.clock() + CLIMB_COOLDOWN
    end
    
    return pos, climbNormal
end

local function validatePosition(hitbox, data, nextPos, currentPos, safeDt, isClimbing)
    local scale = data.Scale or 1.0
    
    if nextPos.Y < -80 then
        return nextPos
    end
    
    -- Map boundary clamp (Canavarların sınır duvarlarının üzerine veya harita dışına itilmesini engelle)
    local center = Config.Game.MapCenter or Vector3.new(54.219, 0.767, 200.954)
    local maxPlayableRadius = (Config.Game.MaxMapRadius or 330) - 45
    local cdx = nextPos.X - center.X
    local cdz = nextPos.Z - center.Z
    local flatDistSq = cdx * cdx + cdz * cdz
    if flatDistSq > (maxPlayableRadius * maxPlayableRadius) then
        local flatDist = math.sqrt(flatDistSq)
        if flatDist > 0.001 then
            local ratio = maxPlayableRadius / flatDist
            nextPos = Vector3.new(center.X + cdx * ratio, nextPos.Y, center.Z + cdz * ratio)
        end
    end
    
    -- Ledge Hop tırmanışı sırasında veya iniş karesinde zemin hizalama veya dikey clamp müdahale etmesin
    if isClimbing or data.Climb then
        return nextPos
    end
    
    -- 1. Clamp if went below the ground
    local checkDistance = scale * 0.8 + 4.5
    local rayOrigin = nextPos + Vector3.new(0, 5, 0)
    local groundRay = workspace:Raycast(rayOrigin, Vector3.new(0, -(5 + checkDistance), 0), rayGround)
    
    local groundY = groundRay and groundRay.Position.Y or nil
    if groundY and (nextPos.Y - scale * 0.8) < groundY then
        nextPos = Vector3.new(nextPos.X, groundY + (scale * 0.8), nextPos.Z)
        data.VerticalVelocity = 0
        -- Also refresh cache so the main loop doesn't use stale value
        data.CachedGroundY = groundY
        data.LastRaycastPos = nextPos
    end
    
    -- 3. Dynamic vertical delta clamp
    local slowMultiplier = hitbox:GetAttribute("SlowMultiplier") or 1.0
    local baseSpeed = (hitbox:FindFirstChild("Speed") and hitbox.Speed.Value or data.Speed)
    local maxClimbSpeed = 14 * ((baseSpeed * slowMultiplier) / 11)
    local maxVerticalDelta = math.max(6.0, maxClimbSpeed * safeDt + 2.0)
    local verticalDelta = math.abs(nextPos.Y - currentPos.Y)
    if verticalDelta > maxVerticalDelta then
        local dirSign = math.sign(nextPos.Y - currentPos.Y)
        nextPos = Vector3.new(nextPos.X, currentPos.Y + dirSign * maxVerticalDelta, nextPos.Z)
    end
    
    return nextPos
end

-- Main 20 Hz Movement and Physics Loop
local tickCounter = 0

-- Static preallocated tables to eliminate 40+ GC allocations per second
local alivePlayers = {}
local movingEnemies = {}
local separationQueryBuffer = {}

Players.PlayerRemoving:Connect(function(player)
    lastDamageTimes[player] = nil
end)

task.spawn(function()
    while true do
        local dt = task.wait(0.05)  -- sabit 20 Hz
        tickCounter = tickCounter + 1
        local safeDt = math.min(dt, 0.08)
        
        -- Respect paused or unstarted game
        if ReplicatedStorage:GetAttribute("GameStarted") ~= true then continue end
        if ReplicatedStorage:GetAttribute("IsPaused") == true then continue end
        
        local players = Players:GetPlayers()
        table.clear(alivePlayers)
        
        -- Filter alive and non-downed players
        for _, p in ipairs(players) do
            local char = p.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and not char:GetAttribute("IsDowned") then
                table.insert(alivePlayers, {Player = p, Root = root, Position = root.Position})
            end
        end
        
        -- Update all enemies
        for hitbox, data in pairs(activeEnemies) do
            -- Check if enemy is dead or deleted
            if not hitbox or not hitbox.Parent or hitbox.Parent ~= enemiesFolder then
                SpatialGrid.Remove(hitbox, data.LastCellX, data.LastCellZ)
                activeEnemies[hitbox] = nil
                continue
            end
            
            -- If enemy is currently sinking (relocating), freeze its movement on server
            if hitbox:GetAttribute("IsSinking") then
                continue
            end
            
            -- If enemy is currently emerging (spawning), check if transition is complete
            if hitbox:GetAttribute("IsEmerging") then
                local spawnTime = hitbox:GetAttribute("SpawnTime")
                local duration = hitbox:GetAttribute("EmergingDuration") or 1.0
                if not spawnTime or (os.clock() - spawnTime >= duration) then
                    hitbox:SetAttribute("IsEmerging", nil)
                else
                    continue -- Freeze movement and skip AI during emergence
                end
            end
            
            local currentPos = data.Position
            
            -- Void Safety Check: Delete if fell out of world
            if currentPos.Y < -80 then
                SpatialGrid.Remove(hitbox, data.LastCellX, data.LastCellZ)
                hitbox:Destroy()
                activeEnemies[hitbox] = nil
                continue
            end
            
            local scale = data.Scale
            local baseSpeed = (hitbox:FindFirstChild("Speed") and hitbox.Speed.Value or data.Speed)
            local slowMultiplier = hitbox:GetAttribute("SlowMultiplier") or 1.0
            local speed = baseSpeed * slowMultiplier
            
            -- Target Nearest Player (Magnitude-Squared optimization: avoids sqrt math calls)
            local nearestTarget = nil
            local minDistSq = math.huge
            for _, ap in ipairs(alivePlayers) do
                local dx = ap.Position.X - currentPos.X
                local dy = ap.Position.Y - currentPos.Y
                local dz = ap.Position.Z - currentPos.Z
                local distSq = dx * dx + dy * dy + dz * dz
                if distSq < minDistSq then
                    minDistSq = distSq
                    nearestTarget = ap
                end
            end
            
            -- Sleep System: enemies far from ALL players freeze to save CPU (220^2 = 48400, 250^2 = 62500)
            if data.IsSleeping then
                if minDistSq < 48400 then
                    -- Yeniden uyandır + cached params ile zemin hizala
                    data.IsSleeping = false
                    data.VerticalVelocity = 0
                    data.CachedGroundY   = nil
                    data.LastRaycastPos  = nil
                    local wakeRay = workspace:Raycast(
                        currentPos + Vector3.new(0, 5, 0),
                        Vector3.new(0, -(5 + scale * 0.8 + 4.5), 0),
                        rayGround
                    )
                    if wakeRay then
                        currentPos = Vector3.new(currentPos.X, wakeRay.Position.Y + scale * 0.8, currentPos.Z)
                        data.Position = currentPos
                        data.CachedGroundY = wakeRay.Position.Y
                    end
                else
                    continue  -- hâlâ uyuyor
                end
            elseif minDistSq > 62500 and not data.IsBoss then
                data.IsSleeping    = true
                data.NeedsFinalSync = true
                continue
            end
            
            -- Check Damage Contact (Proximity Check)
            if nearestTarget then
                -- Check flat horizontal overlap (Magnitude-Squared optimized)
                local diffX = nearestTarget.Position.X - currentPos.X
                local diffZ = nearestTarget.Position.Z - currentPos.Z
                local flatDistSq = diffX * diffX + diffZ * diffZ
                local deltaY = nearestTarget.Position.Y - currentPos.Y
                
                -- Cömert yakın dövüş menzili: Oyuncu hareket hızı (16-24 stud/s), ping ve kalabalık itmesini telafi eder
                local maxHorizontalDist = math.max((scale * 2.0) + 4.5, 6.2)
                local absDeltaY = math.abs(deltaY)
                if absDeltaY > 0.3 then
                    maxHorizontalDist = maxHorizontalDist + math.min(absDeltaY * 0.5 + 1.2, 4.0)
                end
                
                if flatDistSq <= (maxHorizontalDist * maxHorizontalDist) then
                    -- Dikey kapsama: Rampalarda, basamaklarda, kayalıklarda veya zıplama anında hasarın ıskalanmasını kesin olarak önler
                    local maxDownwardDist = (scale * 2.5) + 8.5 -- Canavar yukarıda/oyuncu aşağıdayken vuruş erişimi
                    local maxUpwardDist = (scale * 2.6) + 11.5   -- Oyuncu zıplarken veya canavarın üzerindeyken vuruş erişimi
                    
                    if deltaY >= -maxDownwardDist and deltaY <= maxUpwardDist then
                        tryDealContactDamage(hitbox, data, nearestTarget.Player, nearestTarget.Position)
                    end
                end
            end
            
            -- If casting a boss ability, stop movement
            if data.IsBoss and not data.IsCastingAbility then
                local lastCast = data.LastAbilityCastTime or 0
                if os.clock() - lastCast >= 10.0 and nearestTarget then
                    data.LastAbilityCastTime = os.clock()
                    castBossAbility(hitbox, data)
                end
            end
            
            if data.IsCastingAbility then
                continue
            end
            
            -- Movement direction calculation: clean, focused march toward player
            local dir = Vector3.zero
            local actualSpeed = speed
            local toPlayerDirX, toPlayerDirZ = 0, 0
            local distToPlayer = 0
            local myRadius = data.Radius or (scale * 1.0)
            local minStopDist = myRadius + 1.25
            
            if nearestTarget then
                local targetPos = nearestTarget.Position
                local diffX = targetPos.X - currentPos.X
                local diffZ = targetPos.Z - currentPos.Z
                local lenSq = diffX * diffX + diffZ * diffZ
                
                if lenSq > 0.0001 then
                    distToPlayer = math.sqrt(lenSq)
                    toPlayerDirX = diffX / distToPlayer
                    toPlayerDirZ = diffZ / distToPlayer
                end
                
                if distToPlayer > minStopDist then
                    dir = Vector3.new(toPlayerDirX, 0, toPlayerDirZ)
                else
                    -- Stops right at the player's collision boundary
                    dir = Vector3.zero
                end
            end
            
            -- 1. Elastic Physical Collision & Bumping (MegaBonk Solid Hitbox Contacts)
            local sepX, sepZ = 0, 0
            local relaxationX, relaxationZ = 0, 0
            local myMass = data.Mass or (data.IsBoss and (scale * 25) or scale)
            
            -- Solid stop at player boundary: gently push out if inside minStopDist
            if nearestTarget and distToPlayer > 0.001 and distToPlayer < minStopDist then
                local playerPenetration = math.min(minStopDist - distToPlayer, 0.3)
                relaxationX = relaxationX - toPlayerDirX * playerPenetration
                relaxationZ = relaxationZ - toPlayerDirZ * playerPenetration
            end
            
            -- Disable separation force if climbing
            if not data.Climb then
                -- Bumping contact radius: only immediate touching neighbors
                local maxSeparationDist = (myRadius * 2.0) + 1.4
                local nearbyEnemies = SpatialGrid.GetNearby(currentPos, maxSeparationDist, separationQueryBuffer)
                
                for _, otherHitbox in ipairs(nearbyEnemies) do
                    if otherHitbox ~= hitbox then
                        local otherData = activeEnemies[otherHitbox]
                        if otherData and not otherData.Climb then
                            local otherPos = otherData.Position
                            local dx = currentPos.X - otherPos.X
                            local dz = currentPos.Z - otherPos.Z
                            local distSq = dx * dx + dz * dz
                            
                            local otherRadius = otherData.Radius or (otherData.Scale * 1.0)
                            local hardMinDist = myRadius + otherRadius
                            local softMinDist = hardMinDist * 1.25
                            local softMinDistSq = softMinDist * softMinDist
                            
                            if distSq < softMinDistSq and distSq > 0.0001 then
                                local dist = math.sqrt(distSq)
                                local unitX = dx / dist
                                local unitZ = dz / dist
                                local yDiff = math.abs(currentPos.Y - otherPos.Y)
                                
                                if yDiff < (scale * 1.5) then
                                    local otherMass = otherData.Mass or (otherData.IsBoss and (otherData.Scale * 25) or otherData.Scale)
                                    local massRatio = otherMass / (myMass + otherMass)
                                    
                                    -- A) Elastic repulsive velocity (smooth bumper bounce)
                                    local overlap = softMinDist - dist
                                    local pushStrength = (overlap / softMinDist) * (actualSpeed * 1.1) * (massRatio * 2)
                                    sepX = sepX + unitX * pushStrength
                                    sepZ = sepZ + unitZ * pushStrength
                                    
                                    -- B) Solid Hitbox Contact (gentle position depenetration to guarantee no overlapping)
                                    if dist < hardMinDist then
                                        local penetration = (hardMinDist - dist) * 0.45 * massRatio
                                        relaxationX = relaxationX + unitX * penetration
                                        relaxationZ = relaxationZ + unitZ * penetration
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Clamp maximum separation velocity to prevent jitter or explosive bouncing
                local sepLenSq = sepX * sepX + sepZ * sepZ
                local maxSep = actualSpeed * 1.2
                if sepLenSq > (maxSep * maxSep) then
                    local scaleDown = maxSep / math.sqrt(sepLenSq)
                    sepX = sepX * scaleDown
                    sepZ = sepZ * scaleDown
                end
                
                -- Clamp maximum position relaxation per frame (prevents vibrating in tight crowds)
                local relLenSq = relaxationX * relaxationX + relaxationZ * relaxationZ
                local maxRel = 0.35 * scale
                if relLenSq > (maxRel * maxRel) then
                    local scaleDown = maxRel / math.sqrt(relLenSq)
                    relaxationX = relaxationX * scaleDown
                    relaxationZ = relaxationZ * scaleDown
                end
            end
            
            local separation = Vector3.new(sepX, 0, sepZ)
            
            -- 2. Combine forces (with Recoil Knockback handling)
            local moveDir
            local nowTime = os.clock()
            if data.RecoilEndTime and nowTime < data.RecoilEndTime then
                -- Canavar oyuncuya vurunca kendisi geriye seker (recoil)
                moveDir = data.RecoilDir * (data.RecoilSpeed or 16)
            else
                data.RecoilEndTime = nil
                data.RecoilDir = nil
                -- Combine forward intention with crowd separation
                moveDir = dir * actualSpeed + separation
            end
            
            -- Apply weapon knockback impulse if present
            if data.KnockbackVelocity and data.KnockbackVelocity.Magnitude > 0.1 then
                moveDir = moveDir + data.KnockbackVelocity
                -- Rapid exponential decay
                data.KnockbackVelocity = data.KnockbackVelocity * math.exp(-12 * safeDt)
                if data.KnockbackVelocity.Magnitude < 0.2 then
                    data.KnockbackVelocity = nil
                end
            end
            
            -- Apply horizontal slide-off force if stacked (Uses cached terrain Y to avoid per-tick raycast overhead)
            local currentGroundY = currentPos.Y - (scale * 0.8)
            local terrainY = data.CachedGroundY or currentGroundY
            local heightAboveTerrain = currentGroundY - terrainY
            
            if heightAboveTerrain > (scale * 2.0) then
                local pushDir = data.PushDir
                if not pushDir then
                    local angle = math.random() * math.pi * 2
                    pushDir = Vector3.new(math.cos(angle), 0, math.sin(angle)).Unit
                    data.PushDir = pushDir
                end
                moveDir = moveDir + pushDir * (actualSpeed * 1.5)
            else
                data.PushDir = nil
            end
            
            -- Allow slight expansion speed boost when being squeezed out of dense crowds
            local maxAllowedSpeed = actualSpeed * 1.35
            if not data.KnockbackVelocity and moveDir.Magnitude > maxAllowedSpeed then
                moveDir = moveDir.Unit * maxAllowedSpeed
            end
            
            -- 3. Next Position & Ledge Hop Climbing Execution
            local nextPos
            local isClimbing = false
            local climbNormal = nil
            
            if data.Climb then
                -- ── AKTİF TIRMANIŞ (LEDGE HOP) ──────────────────────────────
                -- Tırmanış aktif: raycast yok, yerçekimi yok, ayrılma (separation) yok, hedef flicker yok!
                nextPos, climbNormal = updateClimb(data, safeDt)
                isClimbing = true
                data.StuckTimer = 0
            else
                -- ── NORMAL ZEMİN HAREKETİ & TIRMANIŞ TESPİTİ ─────────────────
                nextPos = currentPos + moveDir * safeDt + Vector3.new(relaxationX, 0, relaxationZ)
                local flatDelta = Vector3.new(nextPos.X - currentPos.X, 0, nextPos.Z - currentPos.Z)
                local nowTime = os.clock()
                local canTryClimb = nowTime >= (data.ClimbCooldownUntil or 0)
                local playerIsHigher = nearestTarget and (nearestTarget.Position.Y > currentPos.Y + 0.4)
                
                local isBlockedByWall = false
                local testWallHit = nil
                
                -- Duvar tespiti: Önce anlık hareket vektöründe, sonra hedefe (oyuncuya) doğru kontrol et
                local testDir = (flatDelta.Magnitude > 0.01) and flatDelta or dir
                if testDir.Magnitude < 0.01 and nearestTarget then
                    testDir = Vector3.new(toPlayerDirX, 0, toPlayerDirZ)
                end
                
                testWallHit = testQuickWallRay(currentPos, testDir, scale)
                if not testWallHit and nearestTarget and (toPlayerDirX ~= 0 or toPlayerDirZ ~= 0) then
                    local pDir = Vector3.new(toPlayerDirX, 0, toPlayerDirZ)
                    testWallHit = testQuickWallRay(currentPos, pDir, scale)
                end
                
                if testWallHit and testWallHit.Normal and math.abs(testWallHit.Normal.Y) < 0.70 then
                    isBlockedByWall = true
                end
                
                -- 1) Tırmanış Arayışı / Tetikleyici
                -- Önünde bir duvar varsa VEYA oyuncu yukarıda ve canavar duvara yaklaşmışsa tırmanmayı dene
                local shouldCheckClimb = canTryClimb and (isBlockedByWall or (playerIsHigher and testWallHit)) and nowTime >= (data.NextLedgeCheck or 0)
                if shouldCheckClimb then
                    data.NextLedgeCheck = nowTime + 0.15 + ((data.NetworkID or 0) % 4) * 0.04
                    local toPlayerVec = (toPlayerDirX ~= 0 or toPlayerDirZ ~= 0) and Vector3.new(toPlayerDirX, 0, toPlayerDirZ) or nil
                    local moveVec = (dir.Magnitude > 0.01) and dir or toPlayerVec
                    
                    local ledge = findLedge(currentPos, moveVec, toPlayerVec, scale, data.NetworkID)
                    if ledge then
                        startClimb(data, currentPos, ledge, actualSpeed)
                        nextPos, climbNormal = updateClimb(data, safeDt)
                        isClimbing = true
                        data.StuckTimer = 0
                    end
                end
                
                -- 2) Duvara Giriş / Penetrasyon Engeli: İlk sorgudan gelen testWallHit kullanılır
                if not isClimbing and testWallHit and testWallHit.Normal and math.abs(testWallHit.Normal.Y) < 0.70 then
                    local n = Vector3.new(testWallHit.Normal.X, 0, testWallHit.Normal.Z)
                    if n.Magnitude > 0.01 then
                        n = n.Unit
                        local wallDist = scale * 1.05 + 0.1
                        local sep = Vector3.new(nextPos.X - testWallHit.Position.X, 0, nextPos.Z - testWallHit.Position.Z):Dot(n)
                        if sep < wallDist then
                            nextPos = nextPos + n * (wallDist - sep)
                        end
                    end
                end
                
                -- 4. Ground Clamping & Gravity (Sadece tırmanışta DEĞİLKEN çalışır)
                if not isClimbing then
                    local groundY = nil
                    local lastRayPos = data.LastRaycastPos
                    local horizDistSq = lastRayPos and ((nextPos.X - lastRayPos.X)^2 + (nextPos.Z - lastRayPos.Z)^2) or 9999
                    
                    -- Periyodik raycast yenileme (1.5 saniyede bir / 30 tick)
                    local forceRefresh = false
                    if not data.GroundCacheTicks then
                        data.GroundCacheTicks = 0
                    else
                        data.GroundCacheTicks = data.GroundCacheTicks + 1
                        if data.GroundCacheTicks >= 30 then
                            data.GroundCacheTicks = 0
                            forceRefresh = true
                        end
                    end
                    
                    if not forceRefresh and horizDistSq < 6.25 and data.IsOnGround and data.CachedGroundY then
                        groundY = data.CachedGroundY
                    else
                        data.GroundCacheTicks = 0
                        local groundRay = workspace:Raycast(
                            nextPos + Vector3.new(0, 5, 0),
                            Vector3.new(0, -(5 + scale * 0.8 + 4.5), 0),
                            rayGround
                        )
                        
                        if groundRay then
                            groundY = groundRay.Position.Y
                            data.CachedGroundY = groundY
                            data.LastRaycastPos = nextPos
                        else
                            local terrainRay = workspace:Raycast(nextPos + Vector3.new(0, 10, 0), Vector3.new(0, -80, 0), rayTerrain)
                            groundY = terrainRay and terrainRay.Position.Y or (nextPos.Y - scale * 0.8)
                            data.CachedGroundY = groundY
                            data.LastRaycastPos = nextPos
                        end
                    end
                    
                    local groundDist = (nextPos.Y - scale * 0.8) - groundY
                    -- Smooth step-up up to 1.2 studs, and step-down/snap down up to 0.8 studs
                    local shouldSnap = (groundDist >= -1.2 and groundDist <= 0.8)
                    
                    if shouldSnap then
                        nextPos = Vector3.new(nextPos.X, groundY + (scale * 0.8), nextPos.Z)
                        data.VerticalVelocity = 0
                        data.IsOnGround = true
                    else
                        data.VerticalVelocity = data.VerticalVelocity - 196.2 * safeDt
                        nextPos = nextPos + Vector3.new(0, data.VerticalVelocity * safeDt, 0)
                        data.IsOnGround = false
                    end
                else
                    data.VerticalVelocity = 0
                    data.IsOnGround = true
                end
                
                -- 5. Stuck Detector (Canavar duvara karşı 0.55 saniye boyunca takılı kaldıysa derhal tırmanış dene)
                if not data.IsSleeping and not data.IsBoss and nearestTarget then
                    local movedSq = (currentPos.X - (data.LastStuckPos and data.LastStuckPos.X or currentPos.X))^2 +
                                    (currentPos.Z - (data.LastStuckPos and data.LastStuckPos.Z or currentPos.Z))^2
                    if movedSq < 0.25 then
                        data.StuckTimer = (data.StuckTimer or 0) + safeDt
                        if data.StuckTimer >= 0.55 then
                            data.StuckTimer = 0
                            data.VerticalVelocity = 0
                            data.CachedGroundY = nil
                            data.ClimbCooldownUntil = 0
                            
                            local nudgeDir = (toPlayerDirX ~= 0 or toPlayerDirZ ~= 0) and Vector3.new(toPlayerDirX, 0, toPlayerDirZ) or Vector3.new(0, 0, 1)
                            -- 1. Doğrudan önündeki yüzeye tırmanmayı dene
                            local ledge = findLedge(currentPos, nudgeDir, nudgeDir, scale, data.NetworkID)
                            -- 2. Eğer düz hat bulamazsa, duvarın köşesi veya eğimi için açılı tarama yap
                            if not ledge then
                                for _, angleOffset in ipairs({0.4, -0.4, 0.8, -0.8}) do
                                    local rotDir = Vector3.new(
                                        nudgeDir.X * math.cos(angleOffset) - nudgeDir.Z * math.sin(angleOffset),
                                        0,
                                        nudgeDir.X * math.sin(angleOffset) + nudgeDir.Z * math.cos(angleOffset)
                                    )
                                    ledge = findLedge(currentPos, rotDir, rotDir, scale, data.NetworkID)
                                    if ledge then break end
                                end
                            end
                            
                            if ledge then
                                startClimb(data, currentPos, ledge, actualSpeed)
                                nextPos, climbNormal = updateClimb(data, safeDt)
                                isClimbing = true
                            else
                                local testPos = currentPos + nudgeDir * 2.5 + Vector3.new(0, 5.0, 0)
                                local groundCheck = workspace:Raycast(testPos, Vector3.new(0, -18, 0), rayGround)
                                if groundCheck then
                                    nextPos = Vector3.new(testPos.X, groundCheck.Position.Y + scale * 0.8, testPos.Z)
                                    data.Position = nextPos
                                    data.LastStuckPos = nextPos
                                end
                            end
                        end
                    else
                        data.StuckTimer = 0
                        data.LastStuckPos = currentPos
                    end
                else
                    data.StuckTimer = 0
                    data.LastStuckPos = currentPos
                end
            end
            
            -- Store rotation for replication
            local rotY = 0
            if isClimbing and climbNormal then
                -- Face directly into the wall/ledge while climbing (yüzü tam duvara dönük)
                local lookDir = -Vector3.new(climbNormal.X, 0, climbNormal.Z)
                if lookDir.Magnitude > 0.01 then
                    lookDir = lookDir.Unit
                    rotY = math.atan2(-lookDir.X, -lookDir.Z)
                else
                    rotY = data.RotationY or 0
                end
            elseif toPlayerDirX ~= 0 or toPlayerDirZ ~= 0 then
                -- Always face the player directly (clean, focused mob facing)
                rotY = math.atan2(-toPlayerDirX, -toPlayerDirZ)
            elseif dir.Magnitude > 0.05 then
                rotY = math.atan2(-dir.X, -dir.Z)
            else
                rotY = data.RotationY or 0
            end
            data.RotationY = rotY
            
            -- Validate nextPos logic before applying (isClimbing sırasında ve iniş karesinde zemin/dikey clamp baypas edilir)
            nextPos = validatePosition(hitbox, data, nextPos, currentPos, safeDt, isClimbing)
            
            -- Store velocity for extrapolation
            data.LastVelocity = (nextPos - currentPos) / safeDt
            data.Position = nextPos
            
            local visualPos = nextPos
            local isZombieModel = (data.ModelName == "Zombie" or data.ModelName == "FastZombie" or data.ModelName == "ArmoredZombie" or data.ModelName == "MegaZombie")
            if isZombieModel then
                visualPos = nextPos + Vector3.new(0, scale * 1.8, 0)
            elseif data.ModelName == "Slime" then
                visualPos = nextPos + Vector3.new(0, scale * 0.4, 0)
            else
                visualPos = nextPos + Vector3.new(0, scale * 0.95, 0)
            end
            hitbox.CFrame = CFrame.new(visualPos) * CFrame.Angles(0, rotY, 0)
            SpatialGrid.Update(hitbox, nextPos)
            
            -- Canavar bu karede hareket ederek oyuncunun temas alanına girdiyse gecikmesiz hasar ver
            if nearestTarget and (not data.LastHitTime or (os.clock() - data.LastHitTime >= 0.40)) then
                local ndx = nearestTarget.Position.X - nextPos.X
                local ndz = nearestTarget.Position.Z - nextPos.Z
                local nFlatDistSq = ndx * ndx + ndz * ndz
                local nDeltaY = nearestTarget.Position.Y - nextPos.Y
                local maxHorizontalDist = math.max((scale * 2.0) + 4.5, 6.2)
                if math.abs(nDeltaY) > 0.3 then
                    maxHorizontalDist = maxHorizontalDist + math.min(math.abs(nDeltaY) * 0.5 + 1.2, 4.0)
                end
                if nFlatDistSq <= (maxHorizontalDist * maxHorizontalDist) then
                    local maxDownwardDist = (scale * 2.5) + 8.5
                    local maxUpwardDist = (scale * 2.6) + 11.5
                    if nDeltaY >= -maxDownwardDist and nDeltaY <= maxUpwardDist then
                        tryDealContactDamage(hitbox, data, nearestTarget.Player, nearestTarget.Position)
                    end
                end
            end
        end
        
        -- After updating all active enemies, construct position replication buffer
        table.clear(movingEnemies)
        for hitbox, data in pairs(activeEnemies) do
            local parentOk = hitbox.Parent == enemiesFolder
            if parentOk and (not data.IsSleeping or data.NeedsFinalSync) then
                local currentPos = data.Position
                local rotY = data.RotationY or 0
                
                local lastSent = data.LastSentPos
                local posChanged = true
                if lastSent then
                    local dx = currentPos.X - lastSent.X
                    local dy = currentPos.Y - lastSent.Y
                    local dz = currentPos.Z - lastSent.Z
                    posChanged = (dx*dx + dy*dy + dz*dz) > 0.0025 -- > 0.05 studs
                end
                local rotChanged = not data.LastSentRotY or math.abs(rotY - data.LastSentRotY) > 0.03
                
                if posChanged or rotChanged or data.NeedsFinalSync then
                    data.LastSentPos = currentPos
                    data.LastSentRotY = rotY
                    data.NeedsFinalSync = nil -- Reset final sync flag
                    table.insert(movingEnemies, {
                        NetworkID = data.NetworkID,
                        Position = currentPos,
                        RotationY = rotY
                    })
                end
            end
        end
        
        local count = #movingEnemies
        if count > 0 then
            local CHUNK_SIZE = 80
            local serverTime = workspace:GetServerTimeNow()
            for startIndex = 1, count, CHUNK_SIZE do
                local endIndex = math.min(startIndex + CHUNK_SIZE - 1, count)
                local chunkSize = endIndex - startIndex + 1
                local replBuffer = buffer.create(8 + chunkSize * 10)
                
                buffer.writef64(replBuffer, 0, serverTime)
                
                for idx = startIndex, endIndex do
                    local i = idx - startIndex + 1
                    local offset = 8 + (i - 1) * 10
                    local enemy = movingEnemies[idx]
                    
                    buffer.writeu16(replBuffer, offset, enemy.NetworkID)
                    buffer.writei16(replBuffer, offset + 2, math.clamp(math.round(enemy.Position.X * 10), -32768, 32767))
                    buffer.writei16(replBuffer, offset + 4, math.clamp(math.round(enemy.Position.Y * 10), -32768, 32767))
                    buffer.writei16(replBuffer, offset + 6, math.clamp(math.round(enemy.Position.Z * 10), -32768, 32767))
                    buffer.writei16(replBuffer, offset + 8, math.clamp(math.round((enemy.RotationY / math.pi) * 32767), -32768, 32767))
                end
                EnemyReplicationEvent:FireAllClients(replBuffer)
            end
        end
    end
end)

-- Relocation mechanic: Checks enemies that haven't taken damage for 20+ seconds, sinks them, and respawns them near the player
task.spawn(function()
    while true do
        task.wait(1.0)
        
        if ReplicatedStorage:GetAttribute("GameStarted") ~= true then continue end
        if ReplicatedStorage:GetAttribute("IsPaused") == true then continue end
        
        -- To avoid modifying table during iteration, keep a list of enemies to relocate
        local toRelocate = {}
        local now = os.clock()
        
        for hitbox, data in pairs(activeEnemies) do
            if hitbox and hitbox.Parent == enemiesFolder then
                local lastDmg = hitbox:GetAttribute("LastDamageTime")
                local threshold = hitbox:GetAttribute("RelocateThreshold")
                if not threshold then
                    threshold = math.random(30, 50)
                    hitbox:SetAttribute("RelocateThreshold", threshold)
                end
                
                -- Ensure it is not already in the process of sinking
                if lastDmg and now - lastDmg >= threshold and not hitbox:GetAttribute("IsSinking") then
                    -- Oyuncuya yakınsa yok olmasın (Do not relocate if close to any player)
                    local isNearPlayer = false
                    local rootPart = hitbox
                    if rootPart then
                        for _, player in ipairs(Players:GetPlayers()) do
                            local char = player.Character
                            local pHrp = char and char:FindFirstChild("HumanoidRootPart")
                            if pHrp then
                                local dist = (rootPart.Position - pHrp.Position).Magnitude
                                if dist < 50 then
                                    isNearPlayer = true
                                    break
                                end
                            end
                        end
                    end
                    
                    if not isNearPlayer then
                        -- Set the timer temporarily to avoid multiple triggers during the animation transition
                        hitbox:SetAttribute("LastDamageTime", now + threshold)
                        -- Re-roll threshold for after relocation completes
                        hitbox:SetAttribute("RelocateThreshold", math.random(30, 50))
                    
                    local healthVal = hitbox:FindFirstChild("Health")
                    local maxHealth = hitbox:GetAttribute("MaxHealth") or (healthVal and healthVal.Value or 100)
                    
                    if healthVal and healthVal.Value > 0 then
                        table.insert(toRelocate, {
                            Hitbox = hitbox,
                            EnemyType = data.EnemyType,
                            IsBoss = data.IsBoss,
                            IsSwarm = data.IsSwarm,
                            Health = healthVal.Value,
                            MaxHealth = maxHealth
                        })
                    end
                end
            end
        end
    end
        
        -- Process relocations asynchronously
        for _, dup in ipairs(toRelocate) do
            task.spawn(function()
                local hitbox = dup.Hitbox
                if not hitbox or not hitbox.Parent then return end
                
                local duration = getCurrentSpawnDuration()
                
                -- Signal the client that the enemy is sinking
                hitbox:SetAttribute("SinkDuration", duration)
                hitbox:SetAttribute("IsSinking", true)
                
                -- Wait for sinking transition (respecting pause)
                local elapsed = 0
                while elapsed < duration do
                    local dt = task.wait()
                    if ReplicatedStorage:GetAttribute("IsPaused") ~= true then
                        elapsed = elapsed + dt
                    end
                end
                
                -- If the hitbox survived, destroy it and spawn a new one near the player
                if hitbox and hitbox.Parent then
                    -- Oyun duraklatılmışsa bekle
                    while ReplicatedStorage:GetAttribute("IsPaused") == true do
                        task.wait(0.1)
                        if ReplicatedStorage:GetAttribute("GameStarted") ~= true then return end
                    end
                    
                    if hitbox and hitbox.Parent then
                        -- Destroy the old hitbox (client will automatically remove visual model)
                        hitbox:Destroy()
                        
                        -- Spawn the same enemy again near the player (will automatically find position and emerge)
                        spawnEnemy(dup.EnemyType, dup.IsBoss, nil, dup.IsSwarm, dup.Health, dup.MaxHealth)
                    end
                end
            end)
        end
    end
end)
