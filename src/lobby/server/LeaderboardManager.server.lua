local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
local ProgressionManager = Shared and Shared:FindFirstChild("ProgressionManager") and require(Shared.ProgressionManager)

-- DataStores for Global Leaderboards
local DS_Silver   = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_TopSilver_V1")
local DS_Coins    = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_TopCoins_V2")
local DS_Kills    = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_TopKills_V2")
local DS_PlayTime = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_TopPlayTime_V2")

-- Remote Events
local Events = ReplicatedStorage:WaitForChild("Events", 10) or Instance.new("Folder", ReplicatedStorage)
Events.Name = "Events"

local SubmitScoreEvent = Events:FindFirstChild("SubmitLeaderboardScore") or Instance.new("RemoteEvent", Events)
SubmitScoreEvent.Name = "SubmitLeaderboardScore"

-- State & Cache
local UsernameCache = {}
local PlayerJoinTimes = {}
local LeaderboardData = {
    Kills = {},
    Silver = {},
    Coins = {},
    PlayTime = {}
}

-- 3 AYRI ÖZEL TABLO YAPILANDIRMASI (Kills, Silver, PlayTime)
local BOARDS_CONFIG = {
    {
        Category = "Kills",
        DataStore = DS_Kills,
        PossibleNames = {
            "LeaderboardKills", "KillLeaderboard", "KillsLeaderboard", 
            "MostKills", "Most Kills", "KillsBoard", "Leaderboard_Kills", "Leaderboard Kills",
            "KillBoard", "Kill Board", "Kills", "Kill", "Most kills", "most kills", "most_kills"
        }
    },
    {
        Category = "Silver",
        DataStore = DS_Silver,
        PossibleNames = {
            "LeaderboardSilver", "SilverLeaderboard", "TopSilver", 
            "SilverBoard", "Leaderboard_Silver", "Leaderboard Silver", 
            "MostSilver", "Most Silver", "Most silver", "most silver", "most_silver",
            "Silver", "Silvers", "LeaderboardSilvers", "Leaderboard_Silvers",
            -- Eski / geriye uyumluluk isimleri (Workspace'teki parça henüz MostGold/Coins ise de bulsun):
            "LeaderboardCoins", "CoinsLeaderboard", "TopCoins", 
            "CoinsBoard", "Leaderboard_Coins", "Leaderboard Coins", 
            "LeaderboardGold", "GoldLeaderboard", "TopGold", "GoldBoard", "Coins", "Gold", "Golds",
            "MostGold", "Most Gold", "MostCoins", "Most Coins", "Leaderboard Gold", "Leaderboard_Gold",
            "MostGolds", "Most Golds", "Most golds", "most golds", "Most gold", "most gold",
            "LeaderboardGolds", "Leaderboard_Golds"
        }
    },
    {
        Category = "PlayTime",
        DataStore = DS_PlayTime,
        PossibleNames = {
            "LeaderboardPlayTime", "PlayTimeLeaderboard", "PlayTime", 
            "Leaderboard_PlayTime", "Leaderboard PlayTime", "PlayTimeBoard", 
            "TimeLeaderboard", "LeaderboardTime", "TimeBoard", "Playtime",
            "MostTime", "Most Time", "Most time", "most time"
        }
    }
}

local ActiveBoardGuis = {}

local function getUsername(userId)
    if UsernameCache[userId] then return UsernameCache[userId] end
    local success, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    if success and name then
        UsernameCache[userId] = name
        return name
    end
    return "Player_" .. userId
end

-- SAYILARI VE ALTINLARI K / M FORMATINDA GÖSTERME (Örn: 15.4K, 1.2M)
local function formatNumber(val)
    val = tonumber(val) or 0
    if val >= 1000000 then
        return string.format("%.1fM", val / 1000000)
    elseif val >= 1000 then
        return string.format("%.1fK", val / 1000)
    else
        return tostring(val)
    end
end

-- OYNAMA SÜRESİNİ FORMATLA (Saat, Dakika, Saniye)
local function formatPlayTime(totalSec)
    totalSec = tonumber(totalSec) or 0
    local hours = math.floor(totalSec / 3600)
    local mins = math.floor((totalSec % 3600) / 60)
    local secs = totalSec % 60

    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    elseif mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

-- PARÇANIN OYUNCULARA / LOBİYE BAKAN YÜZÜNÜ OTOMATİK HESAPLAMA
local function getAutoFacingFace(displayPart)
    local manualAttr = displayPart:GetAttribute("Face") or (displayPart.Parent and displayPart.Parent:GetAttribute("Face"))
    if manualAttr and Enum.NormalId[manualAttr] then
        return Enum.NormalId[manualAttr]
    end

    local spawnLoc = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    local targetPoint = spawnLoc and spawnLoc.Position or Vector3.new(0, 0, 0)
    
    local dirToTarget = (targetPoint - displayPart.Position)
    dirToTarget = Vector3.new(dirToTarget.X, 0, dirToTarget.Z)
    if dirToTarget.Magnitude < 0.1 then
        return Enum.NormalId.Front
    end
    dirToTarget = dirToTarget.Unit

    local faces = {
        {Enum.NormalId.Front, displayPart.CFrame.LookVector},
        {Enum.NormalId.Back,  -displayPart.CFrame.LookVector},
        {Enum.NormalId.Right, displayPart.CFrame.RightVector},
        {Enum.NormalId.Left,  -displayPart.CFrame.RightVector}
    }

    local bestFace = Enum.NormalId.Front
    local maxDot = -999

    for _, fInfo in ipairs(faces) do
        local dot = fInfo[2]:Dot(dirToTarget)
        if dot > maxDot then
            maxDot = dot
            bestFace = fInfo[1]
        end
    end

    return bestFace
end

-- WORKSPACE'TEN PARÇAYI/MODELİ BULAN YARDIMCI FONKSİYON
local function findTargetInstance(possibleNames)
    for _, name in ipairs(possibleNames) do
        local found = workspace:FindFirstChild(name, true)
        if found then
            return found
        end
    end

    local cleanMap = {}
    for _, name in ipairs(possibleNames) do
        cleanMap[string.lower(name):gsub("[%s_%-]+", "")] = true
    end

    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Model") then
            local cleanName = string.lower(desc.Name):gsub("[%s_%-]+", "")
            if cleanMap[cleanName] then
                return desc
            end
        end
    end
    return nil
end

-- PARÇALARA SURFACEGUI ATAMA
local function setupAllCustomBoards()
    ActiveBoardGuis = {}

    local oldAutoStand = workspace:FindFirstChild("LeaderboardStand")
    if oldAutoStand then oldAutoStand:Destroy() end

    for _, config in ipairs(BOARDS_CONFIG) do
        local target = findTargetInstance(config.PossibleNames)
        if target then
            local displayPart = nil
            if target:IsA("BasePart") then
                displayPart = target
            elseif target:IsA("Model") then
                displayPart = target:FindFirstChild("Screen", true) 
                    or target:FindFirstChild("Display", true)
                    or target:FindFirstChild("Front", true)
                    or target:FindFirstChild("Board", true)
                    or target:FindFirstChild("Main", true)
                    or target.PrimaryPart
                    
                if not displayPart then
                    for _, descendant in ipairs(target:GetDescendants()) do
                        if descendant:IsA("BasePart") then
                            displayPart = descendant
                            break
                        end
                    end
                end
            end

            if displayPart then
                local chosenFaceEnum = getAutoFacingFace(displayPart)

                for _, child in ipairs(displayPart:GetChildren()) do
                    if child:IsA("SurfaceGui") and child.Name:sub(1, 16) == "BoardSurfaceGui_" then
                        child:Destroy()
                    end
                end

                local sgName = "BoardSurfaceGui_" .. config.Category
                local sg = Instance.new("SurfaceGui")
                sg.Name = sgName
                sg.Face = chosenFaceEnum
                sg.Adornee = displayPart
                sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
                sg.CanvasSize = Vector2.new(800, 1000)
                sg.AlwaysOnTop = false
                sg.LightInfluence = 0
                sg.Parent = displayPart

                ActiveBoardGuis[config.Category] = sg
                print("[LeaderboardManager] '" .. target.Name .. "' nesnesine (" .. config.Category .. ") SurfaceGui bağlandı! Yüzey:", chosenFaceEnum.Name)

                -- Eğer model içinde veya tabelasında 'Gold' yazılı TextLabel/TextButton varsa 'Silver' olarak güncelle
                if config.Category == "Silver" then
                    for _, desc in ipairs(target:GetDescendants()) do
                        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and not desc:IsDescendantOf(displayPart) then
                            local txt = desc.Text
                            if txt:find("Gold") or txt:find("Coins") or txt:find("GOLD") or txt:find("gold") then
                                desc.Text = txt:gsub("Gold", "Silver"):gsub("GOLD", "SILVER"):gsub("gold", "silver"):gsub("Coins", "Silver")
                            end
                        end
                    end
                end
            end
        else
            warn("[LeaderboardManager] Workspace'te " .. config.Category .. " tablosu için uygun nesne bulunamadı. Aranan isimler:", table.concat(config.PossibleNames, ", "))
        end
    end
end

-- ŞIK, ŞEFFAF SİYAH-GRİ ARKA PLANLI VE FERAH TASARIM
local function buildLeaderboardUIForCategory(category)
    local sg = ActiveBoardGuis[category]
    if not sg then return end

    sg:ClearAllChildren()

    -- ŞEFFAF SİYAH-GRİ ARKA PLAN FRAME (Dark Glass Panel)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0.96, 0, 0.96, 0)
    mainFrame.Position = UDim2.new(0.02, 0, 0.02, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
    mainFrame.BackgroundTransparency = 0.35 -- Şeffaf Siyah-Gri Görünüm
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = sg

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(45, 55, 75)
    mainStroke.Thickness = 2
    mainStroke.Transparency = 0.4
    mainStroke.Parent = mainFrame

    -- İÇERİK LİSTESİ (Daha ferah kenar boşlukları ile)
    local listContainer = Instance.new("ScrollingFrame")
    listContainer.Name = "ListContainer"
    listContainer.Size = UDim2.new(1, 0, 1, 0)
    listContainer.BackgroundTransparency = 1
    listContainer.BorderSizePixel = 0
    listContainer.ScrollBarThickness = 8
    listContainer.ScrollBarImageColor3 = Color3.fromRGB(255, 200, 50)
    listContainer.Parent = mainFrame

    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingTop = UDim.new(0, 14)
    listPadding.PaddingBottom = UDim.new(0, 14)
    listPadding.PaddingLeft = UDim.new(0, 14)
    listPadding.PaddingRight = UDim.new(0, 14)
    listPadding.Parent = listContainer

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 12) -- Oyuncular arası 12px boşluk
    listLayout.Parent = listContainer
end

local function buildAllUI()
    for _, config in ipairs(BOARDS_CONFIG) do
        buildLeaderboardUIForCategory(config.Category)
    end
end

-- LİSTEYİ GÜNCELLE (Daha Büyük Satırlar & Ferah Oyuncu Kartları)
local function updateCategoryDisplay(category)
    local sg = ActiveBoardGuis[category]
    if not sg then return end

    local mainFrame = sg:FindFirstChild("MainFrame")
    if not mainFrame then return end

    local listContainer = mainFrame:FindFirstChild("ListContainer")
    if not listContainer then return end

    listContainer:ClearAllChildren()

    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingTop = UDim.new(0, 14)
    listPadding.PaddingBottom = UDim.new(0, 14)
    listPadding.PaddingLeft = UDim.new(0, 14)
    listPadding.PaddingRight = UDim.new(0, 14)
    listPadding.Parent = listContainer

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 12) -- Boşluk artırıldı
    listLayout.Parent = listContainer

    local dataList = LeaderboardData[category] or {}

    if #dataList == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 100)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "NO RECORDS YET"
        emptyLabel.TextColor3 = Color3.fromRGB(160, 175, 200)
        emptyLabel.Font = Enum.Font.Arcade
        emptyLabel.TextSize = 30
        emptyLabel.Parent = listContainer
    else
        for rank, entry in ipairs(dataList) do
            local userId = entry.UserId
            local val = tonumber(entry.Value or entry.value) or 0
            local username = entry.Username or getUsername(userId)

            local displayVal = formatNumber(val)
            if category == "PlayTime" then
                displayVal = formatPlayTime(val)
            elseif category == "Kills" then
                displayVal = formatNumber(val) .. " Kills"
            elseif category == "Silver" or category == "Coins" or category == "Gold" or category == "Golds" then
                displayVal = formatNumber(val) .. " Silver"
            end

            -- DAHA BÜYÜK OYUNCU KARTI (76px Yükseklik)
            local row = Instance.new("Frame")
            row.Name = "Row_" .. rank
            row.Size = UDim2.new(1, 0, 0, 76)
            row.LayoutOrder = rank
            row.BorderSizePixel = 0
            row.Parent = listContainer

            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 8)
            rowCorner.Parent = row

            local rankColor = Color3.fromRGB(255, 215, 50)
            local nameColor = Color3.fromRGB(240, 245, 255)
            local valColor  = (category == "Silver") and Color3.fromRGB(220, 235, 255) or Color3.fromRGB(255, 215, 50)

            if rank == 1 then
                row.BackgroundColor3 = Color3.fromRGB(255, 195, 30)
                row.BackgroundTransparency = 0.35 -- Şeffaf Altın Işıma
                rankColor = Color3.fromRGB(255, 220, 60)
                nameColor = Color3.fromRGB(255, 245, 220)
                valColor  = (category == "Silver") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 220, 60)
            elseif rank == 2 then
                row.BackgroundColor3 = Color3.fromRGB(190, 205, 225)
                row.BackgroundTransparency = 0.40 -- Şeffaf Gümüş Işıma
                rankColor = Color3.fromRGB(215, 225, 245)
                nameColor = Color3.fromRGB(240, 245, 255)
                valColor  = Color3.fromRGB(215, 225, 245)
            elseif rank == 3 then
                row.BackgroundColor3 = Color3.fromRGB(210, 130, 50)
                row.BackgroundTransparency = 0.40 -- Şeffaf Bronz Işıma
                rankColor = Color3.fromRGB(240, 160, 80)
                nameColor = Color3.fromRGB(255, 235, 220)
                valColor  = Color3.fromRGB(240, 160, 80)
            else
                row.BackgroundColor3 = Color3.fromRGB(30, 36, 50)
                row.BackgroundTransparency = 0.50 -- Şeffaf Koyu Gri
                rankColor = Color3.fromRGB(180, 195, 215)
                nameColor = Color3.fromRGB(220, 230, 245)
                valColor  = (category == "Silver") and Color3.fromRGB(215, 230, 255) or Color3.fromRGB(255, 215, 50)
            end

            local rowStroke = Instance.new("UIStroke")
            rowStroke.Color = (rank == 1 and Color3.fromRGB(255, 215, 60))
                or (rank == 2 and Color3.fromRGB(220, 230, 245))
                or (rank == 3 and Color3.fromRGB(235, 150, 70))
                or Color3.fromRGB(55, 65, 85)
            rowStroke.Thickness = (rank <= 3) and 2 or 1.5
            rowStroke.Transparency = 0.2
            rowStroke.Parent = row

            -- Rank Etiketi (#1, #2, #3...) - Daha Büyük Font
            local rankLabel = Instance.new("TextLabel")
            rankLabel.Size = UDim2.new(0.14, 0, 1, 0)
            rankLabel.Position = UDim2.new(0, 14, 0, 0)
            rankLabel.BackgroundTransparency = 1
            rankLabel.Text = "#" .. rank
            rankLabel.TextColor3 = rankColor
            rankLabel.Font = Enum.Font.Arcade
            rankLabel.TextSize = 32
            rankLabel.TextXAlignment = Enum.TextXAlignment.Left
            rankLabel.Parent = row

            -- Profil Resmi (Daha Büyük Avatar Headshot: 56x56)
            local avatarImg = Instance.new("ImageLabel")
            avatarImg.Size = UDim2.new(0, 56, 0, 56)
            avatarImg.Position = UDim2.new(0, 88, 0.5, -28)
            avatarImg.BackgroundTransparency = 1
            avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
            avatarImg.Parent = row

            local imgCorner = Instance.new("UICorner")
            imgCorner.CornerRadius = UDim.new(1, 0)
            imgCorner.Parent = avatarImg

            -- Oyuncu İsmi - Daha Büyük Font (28px)
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0.44, 0, 1, 0)
            nameLabel.Position = UDim2.new(0, 156, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = username
            nameLabel.TextColor3 = nameColor
            nameLabel.Font = Enum.Font.Arcade
            nameLabel.TextSize = 28
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = row

            -- Skor / Metrik Değeri
            local valueLabel = Instance.new("TextLabel")
            valueLabel.Size = UDim2.new(0.40, 0, 1, 0)
            valueLabel.Position = UDim2.new(1, -16, 0, 0)
            valueLabel.AnchorPoint = Vector2.new(1, 0)
            valueLabel.BackgroundTransparency = 1
            valueLabel.Text = displayVal
            valueLabel.TextColor3 = valColor
            valueLabel.Font = Enum.Font.Arcade
            valueLabel.TextSize = 28
            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
            valueLabel.Parent = row
        end
    end
end

-- DataStore Verilerini Çek
local function fetchCategoryData(ds, catName)
    local success, pages = pcall(function()
        return ds:GetSortedAsync(false, 10)
    end)

    if success and pages then
        local list = {}
        local entries = pages:GetCurrentPage()
        for _, entry in ipairs(entries) do
            local uId = tonumber(entry.key)
            if uId then
                table.insert(list, {
                    UserId = uId,
                    Value = entry.value,
                    Username = getUsername(uId)
                })
            end
        end
        LeaderboardData[catName] = list
        updateCategoryDisplay(catName)
    else
        warn("[LeaderboardManager] DataStore verisi çekilemedi (" .. catName .. "):", tostring(pages))
    end
end

local function refreshAllLeaderboards()
    for _, config in ipairs(BOARDS_CONFIG) do
        fetchCategoryData(config.DataStore, config.Category)
    end
end

-- Oyuncudan İstatistikleri (Silver, Kills, Coins) Otomatik Çıkarma
local function extractPlayerStats(player)
    local silver = 0
    local coins = 0
    local kills = 0
    if not player then return silver, kills, coins end

    -- 1. ProgressionManager kontrolü (Kalıcı Gümüş bakiyesi)
    if ProgressionManager and ProgressionManager.GetSilver then
        local pSilver = ProgressionManager.GetSilver(player)
        if pSilver and tonumber(pSilver) then
            silver = math.max(silver, tonumber(pSilver))
        end
    end

    -- 2. leaderstats kontrolü
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local sVal = leaderstats:FindFirstChild("Silver") or leaderstats:FindFirstChild("Silvers")
        if sVal and tonumber(sVal.Value) then
            silver = math.max(silver, tonumber(sVal.Value))
        end
        local cVal = leaderstats:FindFirstChild("Coins") or leaderstats:FindFirstChild("Gold") or leaderstats:FindFirstChild("Coin")
        if cVal and tonumber(cVal.Value) then
            coins = math.max(coins, tonumber(cVal.Value))
        end
        local kVal = leaderstats:FindFirstChild("Kills") or leaderstats:FindFirstChild("Kill")
        if kVal and tonumber(kVal.Value) then
            kills = math.max(kills, tonumber(kVal.Value))
        end
    end

    -- 3. Attribute kontrolü
    local attrSilver = player:GetAttribute("Silver") or player:GetAttribute("TotalSilver")
    if attrSilver and tonumber(attrSilver) then
        silver = math.max(silver, tonumber(attrSilver))
    end
    local attrCoins = player:GetAttribute("Coins") or player:GetAttribute("Gold") or player:GetAttribute("TotalCoins") or player:GetAttribute("TotalGold")
    if attrCoins and tonumber(attrCoins) then
        coins = math.max(coins, tonumber(attrCoins))
    end
    local attrKills = player:GetAttribute("Kills") or player:GetAttribute("TotalKills") or player:GetAttribute("DefeatedEnemies")
    if attrKills and tonumber(attrKills) then
        kills = math.max(kills, tonumber(attrKills))
    end

    -- 4. TeleportData kontrolü (Oyundan lobiye dönüldüğünde gelen veriler)
    local success, joinData = pcall(function() return player:GetJoinData() end)
    if success and joinData and joinData.TeleportData then
        local td = joinData.TeleportData
        if type(td) == "table" then
            local tdSilver = td.Silver or td.TotalSilver or td.silver
            if tdSilver and tonumber(tdSilver) then
                silver = math.max(silver, tonumber(tdSilver))
            end
            local tdCoins = td.Coins or td.Gold or td.TotalCoins or td.TotalGold or td.coins or td.gold
            if tdCoins and tonumber(tdCoins) then
                coins = math.max(coins, tonumber(tdCoins))
            end
            local tdKills = td.Kills or td.TotalKills or td.kills or td.totalKills
            if tdKills and tonumber(tdKills) then
                kills = math.max(kills, tonumber(tdKills))
            end
            if td.DefeatedEnemies and type(td.DefeatedEnemies) == "table" then
                local sum = 0
                for _, count in pairs(td.DefeatedEnemies) do
                    sum = sum + (tonumber(count) or 0)
                end
                kills = math.max(kills, sum)
            end
        end
    end

    return silver, kills, coins
end

-- Skor, Gümüş, Altın & Oynama Süresi Kaydetme İşlevi
local function saveScore(player, silverOrCoins, killsParam, optionalCoins)
    if not player or not player.UserId then return end
    local uId = player.UserId

    local silver = 0
    local kills = 0
    local coins = 0

    -- Tablo olarak geldiyse ayrıştır
    if type(silverOrCoins) == "table" then
        local tbl = silverOrCoins
        silver = tbl.Silver or tbl.TotalSilver or tbl.silver or tbl.Coins or tbl.Gold or tbl.TotalCoins or 0
        kills = tbl.Kills or tbl.TotalKills or tbl.kills or 0
        coins = tbl.Coins or tbl.Gold or 0
    else
        silver = tonumber(silverOrCoins) or 0
        kills = tonumber(killsParam) or 0
        coins = tonumber(optionalCoins) or 0
    end

    -- Eğer parametre olarak verilmediyse veya 0 ise, oyuncudan otomatik al
    local autoSilver, autoKills, autoCoins = extractPlayerStats(player)
    silver = math.max(silver, autoSilver)
    kills = math.max(kills, autoKills)
    coins = math.max(coins, autoCoins)

    if silver and silver > 0 then
        local s, err = pcall(function()
            DS_Silver:UpdateAsync(tostring(uId), function(oldVal)
                return math.max(oldVal or 0, math.floor(silver))
            end)
        end)
        if not s then
            warn("[LeaderboardManager] DS_Silver update hatası (" .. player.Name .. "):", tostring(err))
        end
    end

    if coins and coins > 0 then
        pcall(function()
            DS_Coins:UpdateAsync(tostring(uId), function(oldVal)
                return math.max(oldVal or 0, math.floor(coins))
            end)
        end)
    end

    if kills and kills > 0 then
        local s, err = pcall(function()
            DS_Kills:UpdateAsync(tostring(uId), function(oldVal)
                return math.max(oldVal or 0, math.floor(kills))
            end)
        end)
        if not s then
            warn("[LeaderboardManager] DS_Kills update hatası (" .. player.Name .. "):", tostring(err))
        end
    end

    -- Oynama Süresini Akümülatif Ekle (Saniye Cinsinden)
    local joinTime = PlayerJoinTimes[uId] or os.time()
    local sessionSec = os.time() - joinTime
    if sessionSec > 0 then
        local s, err = pcall(function()
            DS_PlayTime:UpdateAsync(tostring(uId), function(oldVal)
                return (oldVal or 0) + sessionSec
            end)
        end)
        if not s then
            warn("[LeaderboardManager] DS_PlayTime update hatası (" .. player.Name .. "):", tostring(err))
        end
        PlayerJoinTimes[uId] = os.time()
    end
end

-- Global erişim için fonksiyonu aç
_G.SaveLeaderboardScore = saveScore
_G.SubmitLeaderboardScore = saveScore

-- Oyuncu Oyuna Girdiğinde / Ayrıldığında Zaman ve Skor Takibi
local function onPlayerAdded(player)
    PlayerJoinTimes[player.UserId] = os.time()

    -- Oyuncu lobiden oyuna veya oyundan lobiye geldiyse TeleportData / Attribute kontrolü yap
    task.spawn(function()
        task.wait(0.5)
        if player and player.Parent then
            local s, k, c = extractPlayerStats(player)
            if s > 0 or k > 0 or c > 0 then
                saveScore(player, s, k, c)
            end
            -- Her oyuncu katıldığında DataStore'dan güncel skorları çek ve tabloları yenile
            task.delay(1.0, refreshAllLeaderboards)
        end
    end)

    -- Attribute değişikliklerini dinle
    player.AttributeChanged:Connect(function(attr)
        if attr == "Silver" or attr == "Coins" or attr == "Gold" or attr == "Kills" or attr == "TotalKills" or attr == "TotalCoins" or attr == "TotalGold" then
            saveScore(player)
            task.delay(0.5, refreshAllLeaderboards)
        end
    end)
end

local function onPlayerRemoving(player)
    -- Ayrılırken oyuncunun mevcut tüm istatistiklerini (Silver, Kills, Coins) otomatik kaydet
    local s, k, c = extractPlayerStats(player)
    saveScore(player, s, k, c)
    PlayerJoinTimes[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Sunucu kapanırken tüm oyuncuların verilerini kaydet
game:BindToClose(function()
    for _, p in ipairs(Players:GetPlayers()) do
        local s, k, c = extractPlayerStats(p)
        saveScore(p, s, k, c)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end

SubmitScoreEvent.OnServerEvent:Connect(function(player)
    -- Güvenlik Koruması: İstemciden gelen kontrolsüz skor sayıları kabul edilmez.
    -- Skor doğrudan sunucu attribute ve doğrulanmış verilerinden çekilerek kaydedilir.
    saveScore(player)
    task.delay(1, refreshAllLeaderboards)
end)

-- Sunucu içi (Bindable) skor gönderme desteği
local SubmitScoreBindable = Events:FindFirstChild("SubmitLeaderboardScoreBindable") or Instance.new("BindableEvent", Events)
SubmitScoreBindable.Name = "SubmitLeaderboardScoreBindable"
SubmitScoreBindable.Event:Connect(function(player, coins, kills)
    saveScore(player, coins, kills)
    task.delay(1, refreshAllLeaderboards)
end)

-- Bağlanma İşlemi
local function tryInit()
    setupAllCustomBoards()
    buildAllUI()
    refreshAllLeaderboards()
end

tryInit()

-- Partlar sonradan yüklenirse algıla
workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") or desc:IsA("Model") then
        local descClean = string.lower(desc.Name):gsub("[%s_%-]+", "")
        for _, config in ipairs(BOARDS_CONFIG) do
            for _, pName in ipairs(config.PossibleNames) do
                if desc.Name == pName or descClean == string.lower(pName):gsub("[%s_%-]+", "") then
                    task.wait(0.2)
                    tryInit()
                    return
                end
            end
        end
    end
end)

-- Otomatik Yenileme Döngüsü (Her 60 saniyede bir)
task.spawn(function()
    while true do
        refreshAllLeaderboards()
        task.wait(60)
    end
end)
