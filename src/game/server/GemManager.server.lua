local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyConfig"))

local GemManager = {}

local GemsFolder = Instance.new("Folder")
GemsFolder.Name = "Gems"
GemsFolder.Parent = workspace

local Events = ReplicatedStorage:WaitForChild("Events")

-- RemoteEvent oluştur
local CollectGemEvent = Events:FindFirstChild("CollectGem") or Instance.new("RemoteEvent")
CollectGemEvent.Name = "CollectGem"
CollectGemEvent.Parent = Events

function GemManager.SpawnGem(position, gemType, customValue)
    local stats = EnemyConfig.Gems[gemType or "Basic"]
    if not stats then stats = EnemyConfig.Gems.Basic end
    
    local totalValue = customValue or stats.Value
    local isCoin = stats.IsCoin == true
    local isVacuum = stats.IsVacuum == true
    local isScrap = stats.IsScrap == true
    local isSilver = stats.IsSilver == true
    local isLuckScroll = (gemType == "LuckScroll") or (stats and stats.IsLuckScroll == true)
    
    local numParts = 1
    local valuesList = {}
    
    if isVacuum or isLuckScroll then
        numParts = 1
        table.insert(valuesList, 1)
    elseif isScrap then
        numParts = 1
        table.insert(valuesList, totalValue)
    elseif isSilver then
        numParts = totalValue
        for i = 1, totalValue do
            table.insert(valuesList, 1)
        end
    elseif totalValue <= 0 then
        return
    elseif gemType == "Ultra" or totalValue >= 50 then
        -- Boss ödülleri için daha fazla parça fırlat (10 adet)
        numParts = 10
        local baseVal = math.floor(totalValue / numParts)
        local remainder = totalValue % numParts
        for i = 1, numParts do
            local val = baseVal + (i <= remainder and 1 or 0)
            if val > 0 then
                table.insert(valuesList, val)
            end
        end
        numParts = #valuesList
    else
        -- Normal düşmanlar için tek parça düşsün (harita gereksiz kürelerle dolmasın)
        numParts = 1
        table.insert(valuesList, totalValue)
    end
    
    -- Her bir parçayı oluştur ve etrafa saç
    for i, itemVal in ipairs(valuesList) do
        local gem = Instance.new("Part")
        gem.Name = isCoin and "CoinGem" or (isVacuum and "VacuumGem" or (isScrap and "ScrapGem" or (isSilver and "SilverGem" or (isLuckScroll and "LuckScrollGem" or "XPGem"))))
        gem.Shape = isScrap and Enum.PartType.Cylinder or Enum.PartType.Ball
        
        -- Boyutu çok daha küçük olacak şekilde ölçeklendir
        local baseScale = 0.4 -- Taban boyutu 1.0'dan 0.4'e düşürüldü
        local scaleFactor = 1
        if isScrap then
            scaleFactor = 1.3 -- Hurda silindiri belirgin olsun
        elseif isCoin then
            scaleFactor = 0.9 -- Coinler küçük olsun (yaklaşık 0.36 stud)
        elseif isVacuum then
            scaleFactor = stats.Scale or 1.5 -- Vakum küresi biraz daha büyük olsun
        elseif isLuckScroll then
            scaleFactor = stats.Scale or 1.8 -- Şans parşömeni belirgin olsun
        else
            if itemVal <= 1 then
                scaleFactor = 0.75 -- En küçük orblar (0.3 stud)
            elseif itemVal <= 3 then
                scaleFactor = 0.95 -- Orta orblar (0.38 stud)
            elseif itemVal <= 15 then
                scaleFactor = 1.25 -- Büyük orblar (0.5 stud)
            else
                scaleFactor = 1.6 -- En büyük orblar (0.64 stud)
            end
        end
        if isScrap then
            gem.Size = Vector3.new(0.3, 0.75, 0.75)
            gem.Material = Enum.Material.Metal
        elseif isLuckScroll then
            gem.Size = Vector3.new(1.2, 1.2, 1.2)
            gem.Material = Enum.Material.Neon
            gem.Transparency = 0.25
        else
            gem.Size = Vector3.new(1, 1, 1) * (baseScale * scaleFactor)
            gem.Material = Enum.Material.Neon
        end
        gem.Color = stats.Color
        
        -- Tamamen bağımsız rastgele dairesel saçılma (XP ve Altınların yan yana eşleşerek düşmesini önler)
        local angle = math.random() * math.pi * 2
        local radius = math.random(15, 65) / 10 -- 1.5 ile 6.5 stud arası bağımsız yarıçap
        local offset = Vector3.new(math.cos(angle) * radius, 0.2, math.sin(angle) * radius)
        
        -- Resmi pozisyonu hemen son hedef olarak ayarla (Server için resmi konum)
        gem.Position = position + offset
        
        -- Pop-out fırlama efekti için istemciye başlangıç ve bitiş konumlarını ilet
        gem:SetAttribute("StartPos", position)
        gem:SetAttribute("LandPos", position + offset)
        
        gem.CanCollide = false
        gem.Anchored = true
        
        if isVacuum then
            gem:SetAttribute("IsVacuum", true)
            -- Vakum parlaklığı ve particleları
            local pointLight = Instance.new("PointLight")
            pointLight.Color = stats.Color
            pointLight.Range = 8
            pointLight.Brightness = 2.0
            pointLight.Parent = gem
            
            local attachment = Instance.new("Attachment")
            attachment.Parent = gem
            
            local particles = Instance.new("ParticleEmitter")
            particles.Texture = "rbxassetid://241908477" -- Sparkle/star particle
            particles.Color = ColorSequence.new(stats.Color)
            particles.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(0.5, 0.4),
                NumberSequenceKeypoint.new(1, 0)
            })
            particles.Lifetime = NumberRange.new(0.4, 0.8)
            particles.Speed = NumberRange.new(1, 3)
            particles.Rate = 20
            particles.Parent = attachment
        elseif isLuckScroll then
            gem:SetAttribute("IsLuckScroll", true)
            
            -- Parşömen görsel ikonu (BillboardGui)
            local bGui = Instance.new("BillboardGui")
            bGui.Name = "ScrollVisualGui"
            bGui.Size = UDim2.new(0, 48, 0, 48)
            bGui.StudsOffset = Vector3.new(0, 1.2, 0)
            bGui.AlwaysOnTop = false
            bGui.MaxDistance = 150
            bGui.Parent = gem
            
            local iconImg = Instance.new("ImageLabel")
            iconImg.Size = UDim2.new(1, 0, 1, 0)
            iconImg.BackgroundTransparency = 1
            iconImg.Image = "rbxassetid://124295705156617" -- Luck Scroll Sprite
            iconImg.Parent = bGui
            
            -- Zümrüt parıltısı ve ışıltı parçacıkları
            local pointLight = Instance.new("PointLight")
            pointLight.Color = stats.Color or Color3.fromRGB(80, 255, 160)
            pointLight.Range = 9
            pointLight.Brightness = 2.5
            pointLight.Parent = gem
            
            local attachment = Instance.new("Attachment")
            attachment.Parent = gem
            
            local particles = Instance.new("ParticleEmitter")
            particles.Texture = "rbxassetid://241908477"
            particles.Color = ColorSequence.new(stats.Color or Color3.fromRGB(80, 255, 160))
            particles.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.15),
                NumberSequenceKeypoint.new(0.5, 0.45),
                NumberSequenceKeypoint.new(1, 0)
            })
            particles.Lifetime = NumberRange.new(0.5, 1.0)
            particles.Speed = NumberRange.new(1, 2.5)
            particles.Rate = 14
            particles.Parent = attachment
        elseif isScrap then
            gem:SetAttribute("IsScrap", true)
        elseif isCoin then
            gem:SetAttribute("IsCoin", true)
        elseif isSilver then
            gem:SetAttribute("IsSilver", true)
            -- Parlak gümüş parıltısı (Nadir ganimet)
            local pointLight = Instance.new("PointLight")
            pointLight.Color = stats.Color or Color3.fromRGB(205, 215, 230)
            pointLight.Range = 4.5
            pointLight.Brightness = 1.8
            pointLight.Parent = gem
        end
        
        gem.Parent = GemsFolder
        
        local val = Instance.new("IntValue")
        val.Name = "Value"
        val.Value = itemVal
        val.Parent = gem
    end
end

-- Toplama işlemini dinle
CollectGemEvent.OnServerEvent:Connect(function(player, gem)
    if gem and gem.Parent == GemsFolder then
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        -- Mesafe Kontrolü (Hile Koruması)
        local baseMagnetRange = Config.Game.XPPickupRadius or 15
        local magnetMultiplier = char:GetAttribute("MagnetMultiplier") or 1
        local maxRange = (baseMagnetRange * magnetMultiplier) + 30 -- Genişletilmiş ağ gecikmesi toleransı
        
        local dist = (char.HumanoidRootPart.Position - gem.Position).Magnitude
        
        -- Vakum kontrolü (Magnet sadece XP ve Altınları çeker, diğer Mıknatıs kürelerini çekmez)
        local isVacuum = gem:GetAttribute("IsVacuum") == true
        local hasVacuum = (char:GetAttribute("VacuumActive") == true or gem:GetAttribute("VacuumPulled") == true) and not isVacuum
        
        if not isVacuum and not hasVacuum and dist > maxRange then
            warn(player.Name .. " tried to collect gem from a distance of " .. tostring(dist) .. " studs (Max: " .. tostring(maxRange) .. ")")
            return
        end
        
        if isVacuum then
            -- Mıknatısı 5 saniyeliğine aktif et
            char:SetAttribute("VacuumActive", true)
            
            local isCollectorEng = player:GetAttribute("SelectedClassId") == "Engineer" or player:GetAttribute("HasTurret") == true
            -- Mevcut tüm XP ve Altın gem'lerini VacuumPulled olarak işaretle (Hurda sadece toplayan kişi Engineer ise çekilir)
            for _, g in ipairs(GemsFolder:GetChildren()) do
                if g:IsA("BasePart") and not g:GetAttribute("IsVacuum") then
                    if g:GetAttribute("IsScrap") then
                        if isCollectorEng then
                            g:SetAttribute("VacuumPulled", true)
                        end
                    else
                        g:SetAttribute("VacuumPulled", true)
                    end
                end
            end
            
            task.delay(5.0, function()
                if char and char.Parent then
                    char:SetAttribute("VacuumActive", nil)
                end
            end)
            
            gem:Destroy()
            return
        end
        
        local amount = gem:FindFirstChild("Value") and gem.Value.Value or 1
        
        -- Magnetic Compass görevi: Toplanabilir nesne topla (400 adet)
        local ProgressionManager = require(ReplicatedStorage.Shared.ProgressionManager)
        ProgressionManager.AddProgress(player, "compass", 1)
        
        if gem:GetAttribute("IsLuckScroll") then
            -- Luck Scroll Görevi İlerlemesi / Tamamlanması
            ProgressionManager.AddProgress(player, "Luck", 1)
            
            -- Maç içi Şans Bonusu (+%10)
            local AddLuckBonus = Events:FindFirstChild("AddLuckBonus")
            if AddLuckBonus then
                AddLuckBonus:Fire(player, 0.10)
            else
                player:SetAttribute("LuckBonus", (player:GetAttribute("LuckBonus") or 0) + 0.10)
            end
            
            local ShowMessageEvent = Events:FindFirstChild("ShowMessage")
            if ShowMessageEvent then
                ShowMessageEvent:FireClient(player, "LUCK SCROLL COLLECTED! (+10% Luck)", Color3.fromRGB(80, 255, 160))
            end
            
            gem:Destroy()
            return
        elseif gem:GetAttribute("IsScrap") then
            local isCollectorEng = player:GetAttribute("SelectedClassId") == "Engineer" or player:GetAttribute("HasTurret") == true
            if not isCollectorEng then
                return
            end
            local AddScrap = Events:FindFirstChild("AddScrap") or Instance.new("BindableEvent", Events)
            AddScrap.Name = "AddScrap"
            AddScrap:Fire(player, amount)
        elseif gem:GetAttribute("IsCoin") then
            local AddCoins = Events:WaitForChild("AddCoins", 5)
            if AddCoins then
                AddCoins:Fire(player, amount)
            else
                warn("AddCoins BindableEvent NOT FOUND!")
            end
        elseif gem:GetAttribute("IsSilver") then
            local AddSilver = Events:FindFirstChild("AddSilver")
            if AddSilver then
                AddSilver:Fire(player, amount)
            else
                ProgressionManager.AddSilver(player, amount)
            end
        else
            -- PlayerManager'a bildir
            local AddXP = Events:WaitForChild("AddXP", 5)
            if AddXP then
                AddXP:Fire(player, amount)
            else
                warn("AddXP BindableEvent NOT FOUND in Events folder!")
            end
        end
        
        gem:Destroy()
    end
end)

-- Global erişim
local SpawnGemEvent = ReplicatedStorage:WaitForChild("Events"):FindFirstChild("SpawnGemEvent") or Instance.new("BindableEvent")
SpawnGemEvent.Name = "SpawnGemEvent"
SpawnGemEvent.Parent = ReplicatedStorage:WaitForChild("Events")

SpawnGemEvent.Event:Connect(function(pos, gemType, customValue)
    GemManager.SpawnGem(pos, gemType, customValue)
end)

-- Yakındaki orbları/altınları birleştirme mekanizması (Spatial Grid Optimizasyonu & Lag Koruması)
local MERGE_COOLDOWN = 1.5 -- 1.5 saniyede bir hafif kontrol
local MERGE_RADIUS = 4.0   -- 4.0 stud içerisindeki aynı tür nesneleri birleştir
local MAX_TOTAL_GEMS = 200 -- Haritada en fazla bulunabilecek toplam kristal limiti

local function getGemTypeKey(gem)
    if gem:GetAttribute("IsCoin") then return "Coin" end
    if gem:GetAttribute("IsScrap") then return "Scrap" end
    if gem:GetAttribute("IsSilver") then return "Silver" end
    if gem:GetAttribute("IsVacuum") then return "Vacuum" end
    if gem:GetAttribute("IsLuckScroll") then return "LuckScroll" end
    return "XP"
end

local function updateGemVisualSize(gem, newVal, typeKey)
    local baseScale = 0.4
    local scaleFactor = 1
    if typeKey == "Coin" then
        scaleFactor = 0.9 + math.min(newVal * 0.05, 0.6)
        gem.Size = Vector3.new(1, 1, 1) * (baseScale * scaleFactor)
    elseif typeKey == "Scrap" then
        scaleFactor = 1.0 + math.min(newVal * 0.005, 0.5)
        gem.Size = Vector3.new(0.3, 0.75, 0.75) * scaleFactor
    elseif typeKey == "Silver" then
        scaleFactor = 1.0 + math.min(newVal * 0.1, 0.5)
        gem.Size = Vector3.new(1, 1, 1) * (baseScale * scaleFactor)
    elseif typeKey == "XP" then
        if newVal <= 1 then
            scaleFactor = 0.75
        elseif newVal <= 3 then
            scaleFactor = 0.95
        elseif newVal <= 20 then
            scaleFactor = 1.25
        else
            scaleFactor = 1.6 + math.min(newVal * 0.005, 1.0)
        end
        gem.Size = Vector3.new(1, 1, 1) * (baseScale * scaleFactor)
    end
end

task.spawn(function()
    while true do
        task.wait(MERGE_COOLDOWN)
        
        -- Pause uyumluluğu
        if ReplicatedStorage:GetAttribute("IsPaused") == true then
            continue
        end
        
        local gems = GemsFolder:GetChildren()
        local gemCount = #gems
        if gemCount < 2 then continue end
        
        -- Spatial Hash Grid (8 stud hücreler) - O(N) karmaşıklık ile sıfır lag
        local grid = {}
        local CELL_SIZE = 8
        local mergedSet = {}
        
        for i = 1, gemCount do
            local gem = gems[i]
            if gem:IsA("BasePart") and gem.Parent == GemsFolder then
                local pos = gem.Position
                local cx = math.floor(pos.X / CELL_SIZE)
                local cz = math.floor(pos.Z / CELL_SIZE)
                local key = cx * 65536 + cz
                local cell = grid[key]
                if not cell then
                    cell = {}
                    grid[key] = cell
                end
                table.insert(cell, gem)
            end
        end
        
        local mergeRadiusSq = MERGE_RADIUS * MERGE_RADIUS
        
        for key, cell in pairs(grid) do
            local count = #cell
            for i = 1, count do
                local gem1 = cell[i]
                if gem1 and gem1.Parent == GemsFolder and not mergedSet[gem1] then
                    local val1Obj = gem1:FindFirstChild("Value")
                    if val1Obj then
                        local type1 = getGemTypeKey(gem1)
                        if type1 ~= "Vacuum" and type1 ~= "LuckScroll" then
                            local pos1 = gem1.Position
                            for j = i + 1, count do
                                local gem2 = cell[j]
                                if gem2 and gem2.Parent == GemsFolder and not mergedSet[gem2] then
                                    local val2Obj = gem2:FindFirstChild("Value")
                                    if val2Obj and getGemTypeKey(gem2) == type1 then
                                        local pos2 = gem2.Position
                                        local dx = pos1.X - pos2.X
                                        local dy = pos1.Y - pos2.Y
                                        local dz = pos1.Z - pos2.Z
                                        local distSq = dx * dx + dy * dy + dz * dz
                                        if distSq <= mergeRadiusSq then
                                            val1Obj.Value = val1Obj.Value + val2Obj.Value
                                            mergedSet[gem2] = true
                                            updateGemVisualSize(gem1, val1Obj.Value, type1)
                                            gem2:Destroy()
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Kristal Güvenlik Tavanı (Maksimum 200 kristal kalacak şekilde agresif kümeleme)
        local remainingGems = GemsFolder:GetChildren()
        if #remainingGems > MAX_TOTAL_GEMS then
            local toCombine = #remainingGems - MAX_TOTAL_GEMS
            local combinedCount = 0
            local targetGem = nil
            local targetType = nil
            local targetVal = nil

            for i = 1, #remainingGems do
                local g = remainingGems[i]
                if g and g.Parent == GemsFolder then
                    local gType = getGemTypeKey(g)
                    local vObj = g:FindFirstChild("Value")
                    if vObj and gType ~= "Vacuum" and gType ~= "LuckScroll" then
                        if not targetGem then
                            targetGem = g
                            targetType = gType
                            targetVal = vObj
                        elseif gType == targetType then
                            targetVal.Value = targetVal.Value + vObj.Value
                            updateGemVisualSize(targetGem, targetVal.Value, targetType)
                            g:Destroy()
                            combinedCount = combinedCount + 1
                            if combinedCount >= toCombine then
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

return GemManager
