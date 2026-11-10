local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")

local ClassDataStore = DataStoreService:GetDataStore("PlayerClassData_V1")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))

-- Çoklu Lobi Klasörü
local ZonesFolder = workspace:WaitForChild("LobbyZones", 10)
if not ZonesFolder then
    warn("LobbyZones klasörü bulunamadı! Lütfen workspace'e ekleyin.")
    return
end

-- Remote Events Klasörü Kontrolü
local Events = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder", ReplicatedStorage)
Events.Name = "Events"

local LobbyEvents = Events:FindFirstChild("LobbyEvents") or Instance.new("Folder", Events)
LobbyEvents.Name = "LobbyEvents"

local OpenLobbyUI = LobbyEvents:FindFirstChild("OpenLobbyUI") or Instance.new("RemoteEvent", LobbyEvents)
OpenLobbyUI.Name = "OpenLobbyUI"

local CreateLobby = LobbyEvents:FindFirstChild("CreateLobby") or Instance.new("RemoteEvent", LobbyEvents)
CreateLobby.Name = "CreateLobby"

local UpdateLobbyState = LobbyEvents:FindFirstChild("UpdateLobbyState") or Instance.new("RemoteEvent", LobbyEvents)
UpdateLobbyState.Name = "UpdateLobbyState"

local OpenClassUI = LobbyEvents:FindFirstChild("OpenClassUI") or Instance.new("RemoteEvent", LobbyEvents)
OpenClassUI.Name = "OpenClassUI"

local LeaveLobby = LobbyEvents:FindFirstChild("LeaveLobby") or Instance.new("RemoteEvent", LobbyEvents)
LeaveLobby.Name = "LeaveLobby"

local SelectClass = LobbyEvents:FindFirstChild("SelectClass") or Instance.new("RemoteEvent", LobbyEvents)
SelectClass.Name = "SelectClass"

-- Lobi Verileri
local Lobbies = {} -- [Part] = {Data}
local PlayerToLobby = {} -- [Player] = LobbyData
local PlayerClasses = {} -- [Player] = ClassData (Name, Color)
local LeaveCooldowns = {} -- [UserId] = os.clock()

-- Sınıf Seçimi İşleyici
SelectClass.OnServerEvent:Connect(function(player, classId)
    local CharacterUIConfig = require(ReplicatedStorage.Shared.CharacterUIConfig)
    local selectedClass = nil
    
    for _, classData in ipairs(CharacterUIConfig.Characters) do
        if classData.Id == classId then
            selectedClass = classData
            break
        end
    end
    
    if selectedClass then
        PlayerClasses[player] = {
            Name = selectedClass.Name,
            Color = selectedClass.Color
        }
        -- Bu veriyi diğer scriptlerin (Overhead UI gibi) okuyabilmesi için Player üzerinde bir Attribute olarak saklayalım
        player:SetAttribute("SelectedClass", selectedClass.Name)
        player:SetAttribute("SelectedClassId", selectedClass.Id)
        player:SetAttribute("ClassColor", selectedClass.Color)
    end
end)

local ExitedPlayers = {}

-- Yeni Oyuncu Girişinde Varsayılan "Human" Sınıfı
Players.PlayerAdded:Connect(function(player)
    ExitedPlayers[player.UserId] = nil
    -- Kamera Uzaklaştırma Kısıtlaması
    player.CameraMinZoomDistance = LobbyConfig.CameraMinZoomDistance or 5
    player.CameraMaxZoomDistance = LobbyConfig.CameraMaxZoomDistance or 35

    player.CharacterAdded:Connect(function(character)
        -- Kayıtlı veriyi yükle (veya varsayılan Human yap)
        if not player:GetAttribute("SelectedClass") then
            local CharacterUIConfig = require(ReplicatedStorage.Shared.CharacterUIConfig)
            
            local savedClassId = "Human"
            local success, result = pcall(function()
                return ClassDataStore:GetAsync(tostring(player.UserId))
            end)
            
            if success and result then
                savedClassId = result
            end
            
            local targetClass = nil
            for _, c in ipairs(CharacterUIConfig.Characters) do
                if c.Id == savedClassId then
                    targetClass = c
                    break
                end
            end
            
            -- Eğer kaydedilen ID artık yoksa Human yap
            if not targetClass then
                targetClass = CharacterUIConfig.Characters[1]
            end

            if targetClass then
                player:SetAttribute("SelectedClass", targetClass.Name)
                player:SetAttribute("SelectedClassId", targetClass.Id)
                player:SetAttribute("ClassColor", targetClass.Color)
            end
        end
    end)
end)

-- BillboardGui Oluşturucu (Dairelerin üstünde durum göstermek için)
-- BillboardGui Oluşturucu (Dairelerin üstünde durum göstermek için)
local function createStatusUI(part)
    local vis = LobbyConfig.Visuals
    
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "StatusUI"
    bgui.Size = UDim2.new(0, 300, 0, 100)
    bgui.AlwaysOnTop = true
    bgui.StudsOffset = Vector3.new(0, vis.UI_HeightOffset or 7, 0)
    bgui.MaxDistance = vis.UI_MaxDistance or 100
    bgui.LightInfluence = 0
    bgui.Parent = part
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = vis.UI_DefaultColor or Color3.new(1, 1, 1)
    textLabel.Font = Enum.Font.Arcade
    textLabel.TextSize = vis.UI_TextSize or 35
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Text = "EMPTY"
    textLabel.Parent = bgui
    
    return textLabel
end

-- Lobi Görselleri Oluşturucu (Neon Kenarlıklar ve Saydamlaşan Duvarlar)
local function createLobbyVisuals(zonePart)
    local wallParts = {}
    zonePart.Transparency = 1 -- Orijinal parçayı gizle, kendi efektlerimizi koyacağız
    
    local visualsFolder = Instance.new("Folder")
    visualsFolder.Name = "Visuals_" .. zonePart.Name
    visualsFolder.Parent = zonePart
    
    local size = zonePart.Size
    local cf = zonePart.CFrame
    
    -- Config yoksa varsayılan değerleri kullan
    local visConfig = LobbyConfig.Visuals or {
        WallHeight = 8,
        EdgeThickness = 0.3,
        EdgeHeight = 0.2,
        Color = Color3.fromRGB(0, 255, 50),
        TransparencyTop = 1,
        TransparencyMiddle = 0.7,
        TransparencyBottom = 0.2
    }
    
    -- 1. ZEMİNDEKİ NEON YEŞİL ÇERÇEVELER
    local thickness = visConfig.EdgeThickness
    local height = visConfig.EdgeHeight
    local bottomY = -size.Y/2 + height/2
    
    local edges = {
        {CFrame.new(0, bottomY, -size.Z/2), Vector3.new(size.X + thickness, height, thickness)}, -- Ön
        {CFrame.new(0, bottomY, size.Z/2), Vector3.new(size.X + thickness, height, thickness)},  -- Arka
        {CFrame.new(-size.X/2, bottomY, 0), Vector3.new(thickness, height, size.Z + thickness)}, -- Sol
        {CFrame.new(size.X/2, bottomY, 0), Vector3.new(thickness, height, size.Z + thickness)}   -- Sağ
    }
    
    for _, edgeData in ipairs(edges) do
        local edge = Instance.new("Part")
        edge.Anchored = true
        edge.CanCollide = false
        edge.Size = edgeData[2]
        edge.CFrame = cf * edgeData[1]
        edge.Material = Enum.Material.Neon
        edge.Color = visConfig.Color
        edge.Parent = visualsFolder
    end
    
    -- 2. YUKARI DOĞRU SAYDAMLAŞAN DUVARLAR (4 AYRI DUVAR, İÇ VE DIŞ YÜZEYLİ)
    local wallHeight = visConfig.CollisionHeight or visConfig.WallHeight or 6
    local wallBottomY = -size.Y/2 + wallHeight/2
    
    local wThick = visConfig.WallThickness or 0.05
    local wOverlap = visConfig.WallOverlap or 0.2
    
    local walls = {
        {CFrame.new(0, wallBottomY, -size.Z/2), Vector3.new(size.X + wOverlap, wallHeight, wThick), {Enum.NormalId.Front, Enum.NormalId.Back}}, -- Ön
        {CFrame.new(0, wallBottomY, size.Z/2), Vector3.new(size.X + wOverlap, wallHeight, wThick), {Enum.NormalId.Front, Enum.NormalId.Back}},  -- Arka
        {CFrame.new(-size.X/2, wallBottomY, 0), Vector3.new(wThick, wallHeight, size.Z + wOverlap), {Enum.NormalId.Left, Enum.NormalId.Right}}, -- Sol
        {CFrame.new(size.X/2, wallBottomY, 0), Vector3.new(wThick, wallHeight, size.Z + wOverlap), {Enum.NormalId.Left, Enum.NormalId.Right}}   -- Sağ
    }

    for _, wallData in ipairs(walls) do
        local wall = Instance.new("Part")
        wall.Name = "FadingWall"
        wall.Anchored = true
        wall.CanCollide = true -- Artık her zaman katı
        wall.Transparency = 1 
        wall.Size = wallData[2]
        wall.CFrame = cf * wallData[1]
        wall.Parent = visualsFolder
        table.insert(wallParts, wall)

        -- Her duvarın kendi geniş yüzeylerine (İç ve Dış) ekle
        local faces = wallData[3]
        for _, face in ipairs(faces) do
            local sg = Instance.new("SurfaceGui")
            sg.Face = face
            sg.Adornee = wall
            sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
            sg.PixelsPerStud = 20
            sg.Parent = visualsFolder
            
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundColor3 = visConfig.Color
            frame.BorderSizePixel = 0
            frame.Parent = sg
            
            local gradient = Instance.new("UIGradient")
            gradient.Rotation = 90
            
            -- Görsel yüksekliğin toplam yüksekliğe oranı (Alttan yukarı doğru)
            local visualRatio = math.clamp(visConfig.WallHeight / wallHeight, 0, 1)
            local boundary = 1 - visualRatio
            
            gradient.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), -- En üst (Görünmez)
                NumberSequenceKeypoint.new(math.max(0, boundary - 0.01), 1), -- Sınırın hemen üstü (Hala Görünmez)
                NumberSequenceKeypoint.new(boundary, visConfig.TransparencyTop or 1), -- Görselin başladığı yer
                NumberSequenceKeypoint.new(boundary + (1 - boundary) * 0.6, visConfig.TransparencyMiddle or 0.7), -- Orta
                NumberSequenceKeypoint.new(1, visConfig.TransparencyBottom or 0.2) -- En alt
            })
            gradient.Parent = frame
        end
    end
    
    return wallParts
end

-- Bariyerleri Aç/Kapat (Artık her zaman kapalı olduğu için bu fonksiyonu boşaltıyoruz veya siliyoruz)
local function setLobbyBarrier(lobby, enabled)
    -- Duvarlar artık hep katı, bu yüzden işlem gerekmiyor.
end

-- Lobi Mantığı Başlangıcı
local function setupLobbyZone(part)
    local wallParts = createLobbyVisuals(part) -- Görselleri otomatik oluştur
    
    local statusLabel = createStatusUI(part)
    
    local lobby = {
        Part = part,
        StatusLabel = statusLabel,
        WallParts = wallParts,
        State = "Idle", -- Idle, Configuring, Waiting
        Host = nil,
        MaxPlayers = 0,
        CurrentPlayers = {},
        Countdown = 30
    }
    Lobbies[part] = lobby
    
    -- Hem zemine hem de duvarlara dokunma olayını ekle (Dışarıdan çarpanı içeri ışınlamak için)
    local function onTouched(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if not player or PlayerToLobby[player] then return end

        local cooldown = LeaveCooldowns[player.UserId]
        if cooldown and os.clock() - cooldown < 2 then
            return
        end

        if lobby.State == "Idle" then
            lobby.State = "Configuring"
            lobby.Host = player
            PlayerToLobby[player] = lobby
            hit.Parent:PivotTo(part.CFrame + Vector3.new(0, 3, 0)) -- İçeri ışınla
            OpenLobbyUI:FireClient(player)
            statusLabel.Text = "CONFIGURING..."
            statusLabel.TextColor3 = LobbyConfig.Visuals.UI_ConfiguringColor or Color3.fromRGB(255, 170, 0)
            
            -- Host için zaman aşımı ekle (60 saniye içinde kurmazsa iptal et)
            task.delay(60, function()
                if lobby.State == "Configuring" and lobby.Host == player then
                    LeaveCooldowns[player.UserId] = os.clock()
                    lobby.State = "Idle"
                    lobby.Host = nil
                    PlayerToLobby[player] = nil
                    statusLabel.Text = "EMPTY"
                    statusLabel.TextColor3 = LobbyConfig.Visuals.UI_DefaultColor or Color3.new(1, 1, 1)
                    -- Oyuncuyu dışarı at
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        player.Character.HumanoidRootPart.CFrame = part.CFrame * CFrame.new(0, 5, 15)
                    end
                end
            end)
            
        elseif lobby.State == "Waiting" then
            if #lobby.CurrentPlayers < lobby.MaxPlayers and not table.find(lobby.CurrentPlayers, player) then
                -- Sadece Arkadaşlar (Friends Only) Kontrolü
                if lobby.FriendsOnly and lobby.Host and player ~= lobby.Host then
                    local isFriend = false
                    local s, res = pcall(function()
                        return player:IsFriendsWith(lobby.Host.UserId)
                    end)
                    if s and res then
                        isFriend = true
                    end
                    if not isFriend then
                        -- Arkadaş değilse lobiye almayıp hafifçe geri itelim
                        if hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart") then
                            hit.Parent.HumanoidRootPart.CFrame = part.CFrame * CFrame.new(0, 5, 14)
                        end
                        return
                    end
                end

                table.insert(lobby.CurrentPlayers, player)
                PlayerToLobby[player] = lobby
                hit.Parent:PivotTo(part.CFrame + Vector3.new(0, 3, 0)) -- İçeri ışınla
                
                if #lobby.CurrentPlayers >= lobby.MaxPlayers and lobby.Countdown > 10 then
                    lobby.Countdown = 10
                end

                for _, p in ipairs(lobby.CurrentPlayers) do
                    UpdateLobbyState:FireClient(p, lobby.Countdown, #lobby.CurrentPlayers, lobby.MaxPlayers)
                end
                local mapText = (lobby.MapId or "Forest"):upper()
                local diffText = (lobby.Difficulty or "Easy"):upper()
                local lockIcon = lobby.FriendsOnly and " 🔒" or ""
                lobby.StatusLabel.Text = mapText .. " • " .. diffText .. lockIcon .. "\nPLAYERS: " .. #lobby.CurrentPlayers .. "/" .. lobby.MaxPlayers .. "\n" .. lobby.Countdown .. "s"
            end
        end
    end

    part.Touched:Connect(onTouched)
    for _, wall in ipairs(wallParts) do
        wall.Touched:Connect(onTouched)
    end
end

-- Her daireyi lobiye çevir
for _, part in ipairs(ZonesFolder:GetChildren()) do
    if part:IsA("BasePart") then
        setupLobbyZone(part)
    end
end

-- Lobi Başlatma İşlemi
CreateLobby.OnServerEvent:Connect(function(player, capacity, mapId, difficultyId, isFriendsOnly)
    local lobby = PlayerToLobby[player]
    if not lobby or lobby.Host ~= player or lobby.State ~= "Configuring" then return end

    local ProgressionManager = require(ReplicatedStorage.Shared.ProgressionManager)
    local validDifficulty = difficultyId or "Easy"
    if not ProgressionManager.IsDifficultyUnlocked(player, validDifficulty) then
        validDifficulty = "Easy"
    end

    lobby.MaxPlayers = capacity or 2
    lobby.MapId = mapId or "Forest"
    lobby.Difficulty = validDifficulty
    lobby.FriendsOnly = (isFriendsOnly == true)
    lobby.State = "Waiting"
    lobby.Countdown = 30
    table.insert(lobby.CurrentPlayers, player)
    player.Character:PivotTo(lobby.Part.CFrame + Vector3.new(0, 3, 0))

    -- EĞER ODA ANINDA DOLDUYSA (Örn: 1 Kişilik oda), SÜREYİ 10'A DÜŞÜR
    if #lobby.CurrentPlayers >= lobby.MaxPlayers then
        lobby.Countdown = 10
    end

    local mapText = (lobby.MapId or "Forest"):upper()
    local diffText = (lobby.Difficulty or "Easy"):upper()
    local lockIcon = lobby.FriendsOnly and " 🔒" or ""

    -- Geri Sayım Döngüsü
    task.spawn(function()
        while lobby.Countdown > 0 and lobby.State == "Waiting" do
            lobby.StatusLabel.Text = mapText .. " • " .. diffText .. lockIcon .. "\nPLAYERS: " .. #lobby.CurrentPlayers .. "/" .. lobby.MaxPlayers .. "\n" .. lobby.Countdown .. "s"
            lobby.StatusLabel.TextColor3 = LobbyConfig.Visuals.UI_WaitingColor or Color3.fromRGB(0, 255, 0)
            
            -- Sadece bu lobideki oyunculara UI güncellemesi yolla
            for _, p in ipairs(lobby.CurrentPlayers) do
                UpdateLobbyState:FireClient(p, lobby.Countdown, #lobby.CurrentPlayers, lobby.MaxPlayers)
            end
            
            -- Max oyuncu sayısına ulaşıldığında süre 4 kat daha hızlı ilerlesin (1 / 4 = 0.25s)
            local isMaxPlayers = #lobby.CurrentPlayers >= lobby.MaxPlayers
            local stepDuration = isMaxPlayers and (1 / 4) or 1
            
            task.wait(stepDuration)
            lobby.Countdown = lobby.Countdown - 1
        end

        if lobby.State == "Waiting" then
            -- Işınlama
            local success, err = pcall(function()
                local teleportOptions = Instance.new("TeleportOptions")
                
                -- Her lobi grubuna özel, taze bir sunucu ayır (ReserveServer)
                local accessCode = TeleportService:ReserveServer(LobbyConfig.GamePlaceId or 0)
                teleportOptions.ReservedServerAccessCode = accessCode
                
                -- Karakter Sınıflarını, Haritayı ve Zorluğu TeleportData olarak ekle
                local playerClassMap = {}
                for _, p in ipairs(lobby.CurrentPlayers) do
                    playerClassMap[tostring(p.UserId)] = p:GetAttribute("SelectedClassId") or "Human"
                end
                teleportOptions:SetTeleportData({
                    PlayerClasses = playerClassMap,
                    MapId = lobby.MapId or "Forest",
                    Difficulty = lobby.Difficulty or "Easy"
                })
                
                TeleportService:TeleportAsync(LobbyConfig.GamePlaceId or 0, lobby.CurrentPlayers, teleportOptions)
            end)
            
            if not success then
                warn("TELEPORT FAILED! Error: " .. tostring(err))
            end
            
            -- Sıfırlama ve Teleport Durumu
            lobby.State = "Teleporting"
            lobby.StatusLabel.Text = "TELEPORTING..."
            lobby.StatusLabel.TextColor3 = Color3.fromRGB(0, 170, 255)

            for _, p in ipairs(lobby.CurrentPlayers) do
                UpdateLobbyState:FireClient(p, -1, #lobby.CurrentPlayers, lobby.MaxPlayers)
            end

            -- 5 saniye sonra alanı sıfırla, oyuncuları temizle ve yeniden kullanılabilir yap
            task.delay(5, function()
                for _, p in ipairs(lobby.CurrentPlayers) do
                    UpdateLobbyState:FireClient(p, 0, 0, 0)
                    PlayerToLobby[p] = nil
                end
                
                lobby.Host = nil
                lobby.CurrentPlayers = {}
                
                setLobbyBarrier(lobby, false) -- Bariyerleri aç
                lobby.State = "Idle"
                lobby.StatusLabel.Text = "EMPTY"
                lobby.StatusLabel.TextColor3 = LobbyConfig.Visuals.UI_DefaultColor or Color3.new(1, 1, 1)
            end)
        end
    end)
end)

local function saveClassData(player)
    if ExitedPlayers[player.UserId] == "Saved" then return end
    
    local classId = player:GetAttribute("SelectedClassId")
    if classId then
        if ExitedPlayers[player.UserId] == true then
            ExitedPlayers[player.UserId] = "Saved"
        end
        pcall(function()
            ClassDataStore:SetAsync(tostring(player.UserId), classId)
        end)
    end
end

-- Oyuncu çıkarsa temizle
Players.PlayerRemoving:Connect(function(player)
    ExitedPlayers[player.UserId] = true
    saveClassData(player)
    PlayerClasses[player] = nil

    local lobby = PlayerToLobby[player]
    if lobby then
        if lobby.Host == player then
            -- Host çıkarsa lobiyi dağıt
            for _, p in ipairs(lobby.CurrentPlayers) do
                UpdateLobbyState:FireClient(p, 0, 0, 0)
                PlayerToLobby[p] = nil
            end
            setLobbyBarrier(lobby, false) -- Bariyerleri aç
            lobby.State = "Idle"
            lobby.Host = nil
            lobby.CurrentPlayers = {}
            lobby.StatusLabel.Text = "EMPTY"
            lobby.StatusLabel.TextColor3 = LobbyConfig.Visuals.UI_DefaultColor or Color3.new(1, 1, 1)
        else
            -- Normal oyuncu çıkarsa listeden sil
            local index = table.find(lobby.CurrentPlayers, player)
            if index then table.remove(lobby.CurrentPlayers, index) end
            PlayerToLobby[player] = nil
        end
    end
end)

-- Sunucu/Studio kapandığında aktif tüm oyuncuların sınıfını kaydet
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        ExitedPlayers[player.UserId] = true
        saveClassData(player)
    end
    task.wait(1) -- Kayıtların tamamlanması için bekle
end)

-- Lobiden Ayrılma İşlemi
LeaveLobby.OnServerEvent:Connect(function(player)
    LeaveCooldowns[player.UserId] = os.clock()
    local lobby = PlayerToLobby[player]
    if lobby then
        local isHost = (lobby.Host == player)
        
        if isHost then
            -- Host ise her şeyi sıfırla
            for _, p in ipairs(lobby.CurrentPlayers) do
                UpdateLobbyState:FireClient(p, 0, 0, 0)
                PlayerToLobby[p] = nil
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    p.Character.HumanoidRootPart.CFrame = lobby.Part.CFrame * CFrame.new(0, 5, 20)
                end
            end
            
            -- Host'u ayrıca temizle (Henüz CurrentPlayers'a girmemiş olabilir)
            PlayerToLobby[player] = nil
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = lobby.Part.CFrame * CFrame.new(0, 5, 20)
            end
            
            lobby.State = "Idle"
            lobby.Host = nil
            lobby.CurrentPlayers = {}
            lobby.StatusLabel.Text = "EMPTY"
            lobby.StatusLabel.TextColor3 = LobbyConfig.Visuals.UI_DefaultColor or Color3.new(1, 1, 1)
        else
            -- Normal oyuncuysa sadece onu çıkar
            local index = table.find(lobby.CurrentPlayers, player)
            if index then table.remove(lobby.CurrentPlayers, index) end
            PlayerToLobby[player] = nil
            
            -- Kalanlara bilgi ver
            for _, p in ipairs(lobby.CurrentPlayers) do
                UpdateLobbyState:FireClient(p, lobby.Countdown, #lobby.CurrentPlayers, lobby.MaxPlayers)
            end
            
            UpdateLobbyState:FireClient(player, 0, 0, 0)
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = lobby.Part.CFrame * CFrame.new(0, 5, 20)
            end
        end
    end
end)

-- Spawn noktalarının CanCollide özelliğini kapat (içinden geçilebilir yapmak için)
local function disableSpawnCollisions()
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("SpawnLocation") then
            desc.CanCollide = false
        end
    end
    workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("SpawnLocation") then
            desc.CanCollide = false
        end
    end)
end
task.spawn(disableSpawnCollisions)

