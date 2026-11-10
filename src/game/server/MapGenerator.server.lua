-- ============================================================
-- PROCEDURAL MAP GENERATOR (Megabonk Style Grid & Perlin Noise)
-- ============================================================

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Grid ve Boyut Ayarları
local GRID_WIDTH = 37 -- X yönündeki blok sayısı (3 kat geniş harita için artırıldı)
local GRID_DEPTH = 37 -- Z yönündeki blok sayısı
local halfWidth = math.floor(GRID_WIDTH / 2)
local halfDepth = math.floor(GRID_DEPTH / 2)
local BLOCK_SIZE = Vector3.new(20, 8, 20) -- 2 Kat Büyütüldü (Genişlik, Yükseklik, Derinlik)
local NOISE_SCALE = 0.05 -- Geniş alanda tepelerin düzgün dağılması için gürültü sıklığı küçültüldü
local HEIGHT_STEPS = 3 -- Maksimum yükselme kademesi (playable alanda)
local CLIFF_HEIGHT = 5 -- Sınır duvarı yüksekliği (5 * 8 = 40 stud duvar)

-- Map Merkezi ve Yarıçapı (Config'den al)
local MAP_CENTER = Config.Game.MapCenter or Vector3.new(54.219, 0.767, 200.954)
local MAX_MAP_RADIUS = Config.Game.MaxMapRadius or 110

-- Varlık Klasörleri
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local MapAssets = Assets and Assets:FindFirstChild("MapAssets")

-- Rastgelelik için seed
local seedX = math.random(-10000, 10000)
local seedZ = math.random(-10000, 10000)

-- Eski Haritayı Gizleme Fonksiyonu
local function hideExistingMap()
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name ~= "ProceduralMap" 
           and child.Name ~= "LobbyZones" 
           and child.Name ~= "Camera" 
           and child.Name ~= "Terrain" 
           and not child:IsA("SpawnLocation")
           and not Players:GetPlayerFromCharacter(child) then
            
            if child:IsA("BasePart") then
                child.Transparency = 1
                child.CanCollide = false
            elseif child:IsA("Model") or child:IsA("Folder") then
                if child.Name ~= "Enemies" and child.Name ~= "Gems" and child.Name ~= "MapCenterPart" and child.Name ~= "MapCenter"
                   and child.Name ~= "Turrets" and child.Name ~= "ActiveShrines" and child.Name ~= "Pots" and child.Name ~= "Chests" then
                    for _, part in ipairs(child:GetDescendants()) do
                        if part:IsA("BasePart") and not part:IsA("SpawnLocation") then
                            part.Transparency = 1
                            part.CanCollide = false
                        end
                    end
                end
            end
        end
    end
end

-- Düşmanların spawnlanabilmesi için zemin işaretleme helperı
local function markAsGround(instance)
    if instance:IsA("BasePart") then
        instance:SetAttribute("IsGround", true)
    end
    for _, desc in ipairs(instance:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc:SetAttribute("IsGround", true)
        end
    end
end

-- Parçaları ve modelleri sabitleme (Anchored = true) helperı
local function anchorInstance(instance)
    if instance:IsA("BasePart") then
        instance.Anchored = true
    end
    for _, desc in ipairs(instance:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Anchored = true
        end
    end
end

-- Çevre süslemelerini (ağaç vb.) yere gömülmeden tam zemin yüzeyine hizalayan helper
local function alignToSurface(instance, surfaceY, cellPosX, cellPosZ)
    local heightOffset = 0
    
    if instance:IsA("Model") then
        -- Önce modelin yamukluğunu (X ve Z eğikliğini) sıfırlayalım (dik durmasını sağlayalım)
        local cf, modelSize = instance:GetBoundingBox()
        local rx, ry, rz = cf:ToOrientation()
        local straightCF = CFrame.new(cf.Position) * CFrame.Angles(0, ry, 0)
        local transform = straightCF * cf:Inverse()
        instance:PivotTo(transform * instance:GetPivot())
        
        -- Şimdi yüksekliği düzgünce hesaplayalım
        cf, modelSize = instance:GetBoundingBox()
        local bottomY = cf.Position.Y - (modelSize.Y / 2)
        heightOffset = instance:GetPivot().Position.Y - bottomY
    elseif instance:IsA("BasePart") then
        heightOffset = instance.Size.Y / 2
    end
    
    -- Küçük bir rastgele sapma ile yerleştir
    local spawnPos = Vector3.new(
        cellPosX + math.random(-4, 4), 
        surfaceY + heightOffset, 
        cellPosZ + math.random(-4, 4)
    )
    
    local finalCFrame = CFrame.new(spawnPos) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
    
    if instance:IsA("Model") then
        instance:PivotTo(finalCFrame)
    else
        instance.CFrame = finalCFrame
    end
end

local function alignModelToGridCenter(model, targetCenterPos, rotation)
    rotation = rotation or CFrame.new()
    
    local cf, modelSize = model:GetBoundingBox()
    local bottomY = cf.Position.Y - (modelSize.Y / 2)
    local heightOffset = model:GetPivot().Position.Y - bottomY
    
    -- Modelin pivotuna göre parça merkezinin lokal ofsetini bulalım
    local pivotCF = model:GetPivot()
    local localOffset = pivotCF:PointToObjectSpace(cf.Position)
    local localOffsetRotated = rotation:VectorToWorldSpace(localOffset)
    
    -- Dikeyde Y hizalamasını korurken yatayda (X/Z) pivot kaçıklığını düzelten doğru formül
    local pivotPos = Vector3.new(
        targetCenterPos.X - localOffsetRotated.X,
        targetCenterPos.Y + heightOffset,
        targetCenterPos.Z - localOffsetRotated.Z
    )
    
    model:PivotTo(CFrame.new(pivotPos) * rotation)
    return modelSize.Y
end

-- Varlık Yükleme Helpers
local function getAsset(name, fallbackType)
    if MapAssets then
        local found = MapAssets:FindFirstChild(name)
        if found then
            return found
        end
    end
    return nil
end

-- Rampa CFrame Açı Tablosu (Zemin yüksekliğine göre rampanın dönüş açısı)
local WedgeRotations = {
    Right = CFrame.Angles(0, math.rad(90), 0),   -- +X yönüne tırmanış
    Left = CFrame.Angles(0, math.rad(-90), 0),  -- -X yönüne tırmanış
    Forward = CFrame.Angles(0, 0, 0),             -- +Z yönüne tırmanış
    Backward = CFrame.Angles(0, math.rad(180), 0) -- -Z yönüne tırmanış
}

-- Prototip Fallback Oluşturucular (Kullanıcının modeli yoksa geçici part üretir)
local function createFallbackBlock(size, color, material)
    local part = Instance.new("Part")
    part.Size = size
    part.Color = color
    part.Material = material
    part.Anchored = true
    return part
end

local function createFallbackSlope(size, color, material)
    local part = Instance.new("WedgePart")
    part.Size = size
    part.Color = color
    part.Material = material
    part.Anchored = true
    return part
end

-- Haritayı Oluşturma
local function generateMap()
    -- print("[MAP GENERATOR] Generating procedural Megabonk level...")
    
    local mapFolder = workspace:FindFirstChild("ProceduralMap")
    if mapFolder then
        mapFolder:Destroy()
    end
    
    mapFolder = Instance.new("Folder")
    mapFolder.Name = "ProceduralMap"
    mapFolder.Parent = workspace
    
    hideExistingMap()
    
    local sourceBlock = getAsset("GrassBlock")
    local sourceSlope = getAsset("GrassSlope")
    local sourceTree = getAsset("Tree")
    local sourceRock = getAsset("Rock")
    local sourceFlowers = getAsset("Flowers") or getAsset("GrassProp")
    local sourceLog = getAsset("Log")
    local sourceWallBase = getAsset("WallBase")
    local sourceWallTop = getAsset("WallTop")
    
    -- Grid Yükseklik Matrisi
    local Heights = {}
    local AbsoluteHeights = {}
    local Slopes = {} -- Hangi koordinatta rampa olduğunu tutar (prop spawnını önlemek için)
    
    -- 1. ADIM: YÜKSEKLİK MATRİSİNİ HESAPLA VE BLOKLARI YIĞ
    for x = -halfWidth, halfWidth do
        Heights[x] = {}
        AbsoluteHeights[x] = {}
        Slopes[x] = {}
        for z = -halfDepth, halfDepth do
            local cellPosX = MAP_CENTER.X + x * BLOCK_SIZE.X
            local cellPosZ = MAP_CENTER.Z + z * BLOCK_SIZE.Z
            
            local dx = cellPosX - MAP_CENTER.X
            local dz = cellPosZ - MAP_CENTER.Z
            local dist = Vector2.new(dx, dz).Magnitude
            
            -- Merkezden olan açıya göre Perlin Noise örneklemesi yaparak sınır yarıçapını dalgalandırıyoruz
            local angle = dist > 0.001 and math.atan2(dz, dx) or 0
            local boundaryNoiseScale = 2.0 -- Dalgaların sıklığı
            local boundaryNoise = math.noise(
                math.cos(angle) * boundaryNoiseScale + (seedX % 1000) * 0.05, 
                math.sin(angle) * boundaryNoiseScale + (seedZ % 1000) * 0.05
            )
            
            -- Sınır yarıçapını Perlin Noise gürültüsüne göre +/- 35 stud esneterek doğal/organik bir yuvarlak oluşturuyoruz
            local localMaxRadius = MAX_MAP_RADIUS + (boundaryNoise * 35)
            local H = 0
            local isBoundary = dist > localMaxRadius
            
            if isBoundary then
                -- Sınır dışı: Devasa kaya duvarları (Cliffs) oluştur
                H = CLIFF_HEIGHT
            else
                -- Oynanabilir Alan: Perlin Noise ile yükseklik belirle (0 ile HEIGHT_STEPS arası)
                local noiseVal = math.noise((x + seedX) * NOISE_SCALE, (z + seedZ) * NOISE_SCALE)
                H = math.clamp(math.round((noiseVal + 0.4) * HEIGHT_STEPS), 0, HEIGHT_STEPS)
            end
            
            Heights[x][z] = H
            
            -- Dikeyde blokları üst üste yerleştir (Boşluk kalmaması için bounding-box tabanlı istifleme)
            local currentY = MAP_CENTER.Y
            for y = 0, H do
                local block
                local blockHeight = BLOCK_SIZE.Y -- Varsayılan yükseklik
                
                local assetToClone = sourceBlock
                if isBoundary then
                    if y < H then
                        assetToClone = sourceWallBase
                    else
                        assetToClone = sourceWallTop
                    end
                end

                if assetToClone then
                    block = assetToClone:Clone()
                    if block:IsA("Model") then
                        block:ScaleTo(2) -- 2 kat büyüt
                        blockHeight = alignModelToGridCenter(block, Vector3.new(cellPosX, currentY, cellPosZ))
                    else
                        block.Size = block.Size * 2 -- 2 kat büyüt
                        blockHeight = block.Size.Y
                        block.Position = Vector3.new(cellPosX, currentY + (blockHeight / 2), cellPosZ)
                    end
                else
                    -- Fallback part
                    local color = isBoundary and Color3.fromRGB(110, 105, 100) or Color3.fromRGB(80, 140, 70)
                    local mat = isBoundary and Enum.Material.Slate or Enum.Material.Grass
                    block = createFallbackBlock(BLOCK_SIZE, color, mat)
                    blockHeight = block.Size.Y
                    block.Position = Vector3.new(cellPosX, currentY + (blockHeight / 2), cellPosZ)
                end
                
                block.Name = "Block_" .. x .. "_" .. z .. "_" .. y
                if isBoundary then
                    block:SetAttribute("IsBoundary", true)
                    for _, desc in ipairs(block:GetDescendants()) do
                        if desc:IsA("BasePart") then
                            desc:SetAttribute("IsBoundary", true)
                        end
                    end
                end
                markAsGround(block)
                anchorInstance(block)
                block.Parent = mapFolder
                
                -- Bir sonraki katmanın zemin yüksekliğini güncelle
                currentY = currentY + blockHeight
            end
            
            -- Heights matrisine en son katmanın gerçek üst yüzey yüksekliğini (Y koordinatını) kaydet
            -- Böylece rampalar ve ağaçlar bu yüksekliğin üzerine tam olarak oturur!
            Heights[x][z] = H
            AbsoluteHeights[x][z] = currentY
        end
    end
    
    -- 2. ADIM: RAMPALARI (WEDGE) YERLEŞTİR
    for x = -halfWidth + 1, halfWidth - 1 do
        for z = -halfDepth + 1, halfDepth - 1 do
            local currentH = Heights[x][z]
            
            -- Sınırda veya zirvede rampa koymaya gerek yok
            if currentH < HEIGHT_STEPS then
                local cellPosX = MAP_CENTER.X + x * BLOCK_SIZE.X
                local cellPosZ = MAP_CENTER.Z + z * BLOCK_SIZE.Z
                
                -- Komşuların yüksekliklerini al
                local Hr = Heights[x+1][z]
                local Hl = Heights[x-1][z]
                local Hf = Heights[x][z+1]
                local Hb = Heights[x][z-1]
                
                local placedSlope = false
                local slopeCFrame = nil
                local targetH = currentH + 1
                
                -- Eğer komşu bizden tam 1 blok yukarıdaysa o yöne doğru rampa yerleştir
                local rotation = nil
                local direction = nil
                if Hr == targetH then
                    rotation = WedgeRotations.Right
                    direction = "Right"
                    placedSlope = true
                elseif Hl == targetH then
                    rotation = WedgeRotations.Left
                    direction = "Left"
                    placedSlope = true
                elseif Hf == targetH then
                    rotation = WedgeRotations.Forward
                    direction = "Forward"
                    placedSlope = true
                elseif Hb == targetH then
                    rotation = WedgeRotations.Backward
                    direction = "Backward"
                    placedSlope = true
                end
                
                -- Çakışma kontrolü: Komşu hücrelerde farklı yöne bakan rampa varsa görsel bozukluğu önlemek için rampa koyma
                if placedSlope and direction then
                    local neighbors = {
                        {x = x-1, z = z},
                        {x = x+1, z = z},
                        {x = x, z = z-1},
                        {x = x, z = z+1}
                    }
                    for _, n in ipairs(neighbors) do
                        if Slopes[n.x] and Slopes[n.x][n.z] then
                            local neighborDir = Slopes[n.x][n.z]
                            if neighborDir ~= direction then
                                placedSlope = false
                                break
                            end
                        end
                    end
                end
                
                if placedSlope and rotation and direction then
                    local slope
                    local surfaceY = AbsoluteHeights[x][z]
                    
                    if sourceSlope then
                        slope = sourceSlope:Clone()
                        if slope:IsA("Model") then
                            slope:ScaleTo(2) -- 2 kat büyüt
                            alignModelToGridCenter(slope, Vector3.new(cellPosX, surfaceY, cellPosZ), rotation)
                        else
                            slope.Size = slope.Size * 2 -- 2 kat büyüt
                            slope.CFrame = CFrame.new(cellPosX, surfaceY + slope.Size.Y / 2, cellPosZ) * rotation
                        end
                    else
                        slope = createFallbackSlope(BLOCK_SIZE, Color3.fromRGB(90, 150, 80), Enum.Material.Grass)
                        slope.CFrame = CFrame.new(cellPosX, surfaceY + BLOCK_SIZE.Y / 2, cellPosZ) * rotation
                    end
                    slope.Name = "Slope_" .. x .. "_" .. z
                    markAsGround(slope)
                    anchorInstance(slope)
                    slope.Parent = mapFolder
                    Slopes[x][z] = direction
                end
            end
        end
    end
    
    -- 3. ADIM: ÇEVRE SÜSLEMELERİNİ YERLEŞTİR (Ağaç, Kaya, Ot)
    local OccupiedProps = {}
    for x = -halfWidth, halfWidth do
        OccupiedProps[x] = {}
    end
    
    for x = -halfWidth + 1, halfWidth - 1 do
        for z = -halfDepth + 1, halfDepth - 1 do
            -- Eğer burada rampa yoksa süsleme yerleştirebiliriz
            if not Slopes[x][z] then
                local H = Heights[x][z]
                
                -- Sadece oynanabilir yüksekliklerde ve düzlüklerde spawnla
                if H >= 0 and H <= HEIGHT_STEPS then
                    local cellPosX = MAP_CENTER.X + x * BLOCK_SIZE.X
                    local cellPosZ = MAP_CENTER.Z + z * BLOCK_SIZE.Z
                    
                    -- Komşu hücrelerde başka süsleme var mı kontrol et (Megabonk Grid Neighbor Check)
                    local neighborOccupied = false
                    for dx = -1, 1 do
                        for dz = -1, 1 do
                            if OccupiedProps[x + dx] and OccupiedProps[x + dx][z + dz] then
                                neighborOccupied = true
                                break
                            end
                        end
                        if neighborOccupied then break end
                    end
                    
                    if not neighborOccupied then
                        local rand = math.random()
                        local prop = nil
                        
                        -- %6 Şansla Ağaç
                        if rand < 0.06 and sourceTree then
                            prop = sourceTree:Clone()
                        -- %4 Şansla Kaya
                        elseif rand >= 0.06 and rand < 0.10 and sourceRock then
                            prop = sourceRock:Clone()
                        -- %12 Şansla Çiçek (Flowers)
                        elseif rand >= 0.10 and rand < 0.22 and sourceFlowers then
                            prop = sourceFlowers:Clone()
                        -- %3 Şansla Kütük (Log) - Düşük olasılık
                        elseif rand >= 0.22 and rand < 0.25 and sourceLog then
                            prop = sourceLog:Clone()
                        end
                        
                        if prop then
                            local spawnY = AbsoluteHeights[x][z]
                            alignToSurface(prop, spawnY, cellPosX, cellPosZ)
                            anchorInstance(prop)
                            prop.Parent = mapFolder
                            
                            -- Doluluk tablosunu güncelle
                            OccupiedProps[x][z] = true
                        end
                    end
                end
            end
        end
    end
    
    -- 4. ADIM: SPAWN NOKTALARINI YENİ HARİTAYA HİZALA
    local spawnX = MAP_CENTER.X
    local spawnY = MAP_CENTER.Y
    local spawnZ = MAP_CENTER.Z
    
    -- Bir GrassBlock bul (Öncelikli olarak merkezdeki 0,0 koordinatı)
    local foundGrassBlock = nil
    for y = HEIGHT_STEPS, 0, -1 do
        local blockName = "Block_0_0_" .. y
        local b = mapFolder:FindFirstChild(blockName)
        if b then
            foundGrassBlock = b
            break
        end
    end
    
    -- Eğer merkezde yoksa haritadaki herhangi bir bloğu bul
    if not foundGrassBlock then
        for _, child in ipairs(mapFolder:GetChildren()) do
            if child.Name:sub(1, 6) == "Block_" then
                foundGrassBlock = child
                break
            end
        end
    end
    
    if foundGrassBlock then
        if foundGrassBlock:IsA("Model") then
            local cf, sz = foundGrassBlock:GetBoundingBox()
            spawnX = cf.Position.X
            spawnY = cf.Position.Y + sz.Y / 2
            spawnZ = cf.Position.Z
        else
            spawnX = foundGrassBlock.Position.X
            spawnY = foundGrassBlock.Position.Y + foundGrassBlock.Size.Y / 2
            spawnZ = foundGrassBlock.Position.Z
        end
    end
    
    local spawnPos = Vector3.new(spawnX, spawnY, spawnZ)
    ReplicatedStorage:SetAttribute("SpawnPosition", spawnPos)

    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("SpawnLocation") then
            desc.Size = Vector3.new(desc.Size.X, 0.1, desc.Size.Z)
            desc.Position = Vector3.new(spawnX, spawnY + 0.05, spawnZ)
            desc.Transparency = 1 -- Şeffaf kalsın
            desc.CanCollide = false -- Oyuncunun havada durmasını engellemek için çarpışmayı kapat
            
            -- Decal'leri silerek tamamen gizle
            for _, child in ipairs(desc:GetChildren()) do
                if child:IsA("Decal") then
                    child:Destroy()
                end
            end
        end
    end
    
    -- Harita oluştuğu an oyunda zaten bulunan karakterleri doğrudan zemin hizasına taşı
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local hum = char:FindFirstChild("Humanoid")
            local hipHeight = (hum and hum.HipHeight > 0) and hum.HipHeight or 2.0
            local rootOffset = hipHeight + (hrp.Size.Y / 2)
            hrp.CFrame = CFrame.new(spawnX, spawnY + rootOffset, spawnZ)
            hrp.Anchored = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end

    -- print("[MAP GENERATOR] Procedural level generated successfully!")
    ReplicatedStorage:SetAttribute("MapGenerated", true)
end

-- Server başladığında veya oyun yüklendiğinde haritayı oluştur
task.spawn(function()
    generateMap()
end)
