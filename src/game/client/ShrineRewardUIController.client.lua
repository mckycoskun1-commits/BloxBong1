-- ============================================================
-- SHRINE REWARD & CHARGE UI CONTROLLER (MegaBonk Style)
-- Strict Rule: NO Images, NO Emojis. Pure clean typography.
-- Everything in ENGLISH as requested.
-- Neon Mint Palette (#1FF177 / Color3.fromRGB(31, 241, 119))
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")

local OpenShrineReward = Events:WaitForChild("OpenShrineReward")
local SelectShrineStat = Events:WaitForChild("SelectShrineStat")
local UpdateShrineCharge = Events:WaitForChild("UpdateShrineCharge")

-- Theme Colors
local COLOR_ACCENT = Color3.fromRGB(31, 241, 119)
local COLOR_ACCENT_DARK = Color3.fromRGB(15, 75, 40)
local COLOR_BG_DARK = Color3.fromRGB(12, 16, 20)
local COLOR_CARD_BG = Color3.fromRGB(18, 23, 28)
local COLOR_CARD_STROKE = Color3.fromRGB(38, 52, 45)

local currentRewardGui = nil
local activeShrineRings = {} -- [shrineModel] = { Billboard = BillboardGui, SetProgress = function }

-- ============================================================
-- 1. 3D WORLD RADIAL PROGRESS RING (MegaBonk Circular Charge Bar)
-- Sunak modelinin tam ortasında (görseldeki gibi) beliren ve dolan çember
-- Ekranın altında çıkan ekstra HUD kaldırılmıştır.
-- ============================================================
local function createRadialProgress(parent)
    local container = Instance.new("Frame")
    container.Name = "RadialRing"
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5, 0, 0.5, 0)
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent = parent

    -- Arka Plan Halka Kanalı (Koyu kömür / siyah zemin)
    local bgTrack = Instance.new("Frame")
    bgTrack.Name = "BgTrack"
    bgTrack.AnchorPoint = Vector2.new(0.5, 0.5)
    bgTrack.Position = UDim2.new(0.5, 0, 0.5, 0)
    bgTrack.Size = UDim2.new(1, 0, 1, 0)
    bgTrack.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
    bgTrack.BorderSizePixel = 0
    bgTrack.ZIndex = 1
    bgTrack.Parent = container

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = bgTrack

    local bgOuterStroke = Instance.new("UIStroke")
    bgOuterStroke.Color = Color3.fromRGB(0, 0, 0)
    bgOuterStroke.Thickness = 2.5
    bgOuterStroke.Parent = bgTrack

    -- Keskin geçişli saydamlık haritası (Yarım daireler için)
    local cutoffTrans = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.499, 0),
        NumberSequenceKeypoint.new(0.5, 1),
        NumberSequenceKeypoint.new(1, 1),
    })

    -- Sağ Yarım Taşıyıcı (0% -> 50% ilerleme)
    local rightContainer = Instance.new("Frame")
    rightContainer.Name = "RightContainer"
    rightContainer.Size = UDim2.new(0.5, 0, 1, 0)
    rightContainer.Position = UDim2.new(0.5, 0, 0, 0)
    rightContainer.BackgroundTransparency = 1
    rightContainer.ClipsDescendants = true
    rightContainer.ZIndex = 2
    rightContainer.Parent = container

    local rightCircle = Instance.new("Frame")
    rightCircle.Name = "RightCircle"
    rightCircle.Size = UDim2.new(2, 0, 1, 0)
    rightCircle.Position = UDim2.new(-1, 0, 0, 0)
    rightCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    rightCircle.BorderSizePixel = 0
    rightCircle.Visible = false
    rightCircle.ZIndex = 2
    rightCircle.Parent = rightContainer

    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(1, 0)
    rightCorner.Parent = rightCircle

    local rightGradient = Instance.new("UIGradient")
    rightGradient.Transparency = cutoffTrans
    rightGradient.Rotation = 0
    rightGradient.Parent = rightCircle

    -- Sol Yarım Taşıyıcı (50% -> 100% ilerleme)
    local leftContainer = Instance.new("Frame")
    leftContainer.Name = "LeftContainer"
    leftContainer.Size = UDim2.new(0.5, 0, 1, 0)
    leftContainer.Position = UDim2.new(0, 0, 0, 0)
    leftContainer.BackgroundTransparency = 1
    leftContainer.ClipsDescendants = true
    leftContainer.ZIndex = 2
    leftContainer.Parent = container

    local leftCircle = Instance.new("Frame")
    leftCircle.Name = "LeftCircle"
    leftCircle.Size = UDim2.new(2, 0, 1, 0)
    leftCircle.Position = UDim2.new(0, 0, 0, 0)
    leftCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    leftCircle.BorderSizePixel = 0
    leftCircle.Visible = false
    leftCircle.ZIndex = 2
    leftCircle.Parent = leftContainer

    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(1, 0)
    leftCorner.Parent = leftCircle

    local leftGradient = Instance.new("UIGradient")
    leftGradient.Transparency = cutoffTrans
    leftGradient.Rotation = 180
    leftGradient.Parent = leftCircle

    -- İç Oyuk / Delik (İçi koyu çember, halkanın kalınlığını belirler)
    local centerHole = Instance.new("Frame")
    centerHole.Name = "CenterHole"
    centerHole.AnchorPoint = Vector2.new(0.5, 0.5)
    centerHole.Position = UDim2.new(0.5, 0, 0.5, 0)
    centerHole.Size = UDim2.new(0.66, 0, 0.66, 0)
    centerHole.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
    centerHole.BorderSizePixel = 0
    centerHole.ZIndex = 4
    centerHole.Parent = container

    local holeCorner = Instance.new("UICorner")
    holeCorner.CornerRadius = UDim.new(1, 0)
    holeCorner.Parent = centerHole

    local holeStroke = Instance.new("UIStroke")
    holeStroke.Color = Color3.fromRGB(0, 0, 0)
    holeStroke.Thickness = 2.0
    holeStroke.Parent = centerHole

    local function setProgress(pct)
        local p = math.clamp(pct or 0, 0, 1)
        if p <= 0.01 then
            rightCircle.Visible = false
            leftCircle.Visible = false
        elseif p <= 0.5 then
            rightCircle.Visible = true
            rightGradient.Rotation = p * 2 * 180
            leftCircle.Visible = false
        else
            rightCircle.Visible = true
            rightGradient.Rotation = 180
            leftCircle.Visible = true
            leftGradient.Rotation = 180 + (p - 0.5) * 2 * 180
        end
    end

    setProgress(0)
    return container, setProgress
end

-- Bir sunağın tam merkez ve en tepe noktasını bul
local function getShrineTopAdornee(shrineModel)
    -- 1. Sunucunun oluşturduğu tam merkez ChargeAnchor varsa doğrudan kullan
    local anchor = shrineModel:FindFirstChild("ChargeAnchor") or shrineModel:WaitForChild("ChargeAnchor", 1.5)
    if anchor and anchor:IsA("BasePart") then
        return anchor, Vector3.new(0, 0.3, 0)
    end

    -- 2. Fallback: Modelin BoundingBox sınırlarına göre tam merkez üst pozisyon
    local bboxCF, bboxSize = shrineModel:GetBoundingBox()
    local part = shrineModel.PrimaryPart or shrineModel:FindFirstChildWhichIsA("BasePart")
    if part then
        local targetWorldPos = Vector3.new(bboxCF.Position.X, bboxCF.Position.Y + (bboxSize.Y * 0.5) + 1.2, bboxCF.Position.Z)
        local localOffset = part.CFrame:PointToObjectSpace(targetWorldPos)
        return part, localOffset
    end

    return nil, Vector3.zero
end

-- Bir sunağa 3D radyal çemberi bağla
local function setupShrineChargeRing(shrineModel)
    if not shrineModel:IsA("Model") then return end
    if activeShrineRings[shrineModel] then return end

    local adorneePart, offset = getShrineTopAdornee(shrineModel)
    if not adorneePart then
        task.defer(function()
            if shrineModel.Parent and not activeShrineRings[shrineModel] then
                setupShrineChargeRing(shrineModel)
            end
        end)
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ShrineChargeRadialRing"
    billboard.Size = UDim2.new(0, 40, 0, 40)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 90
    billboard.StudsOffset = offset
    billboard.Adornee = adorneePart
    billboard.Enabled = false
    billboard.Parent = shrineModel

    local _, setProgress = createRadialProgress(billboard)

    local function updateFromAttributes()
        if not shrineModel.Parent then return end
        local progress = shrineModel:GetAttribute("ChargeProgress") or 0
        local isCharging = shrineModel:GetAttribute("IsCharging") == true
        local isCompleted = shrineModel:GetAttribute("IsCompleted") == true

        -- Eğer sunucu ChargeAnchor oluşturduysa ve adornee henüz ona geçmediyse güncelle
        local sAnchor = shrineModel:FindFirstChild("ChargeAnchor")
        if sAnchor and sAnchor:IsA("BasePart") and billboard.Adornee ~= sAnchor then
            billboard.Adornee = sAnchor
            billboard.StudsOffset = Vector3.new(0, 0.3, 0)
        end

        if isCompleted or progress >= 1.0 then
            billboard.Enabled = false
        elseif progress > 0.01 or isCharging then
            billboard.Enabled = true
            setProgress(progress)
        else
            billboard.Enabled = false
            setProgress(0)
        end
    end

    local conn1 = shrineModel:GetAttributeChangedSignal("ChargeProgress"):Connect(updateFromAttributes)
    local conn2 = shrineModel:GetAttributeChangedSignal("IsCharging"):Connect(updateFromAttributes)
    local conn3 = shrineModel:GetAttributeChangedSignal("IsCompleted"):Connect(updateFromAttributes)
    updateFromAttributes()

    activeShrineRings[shrineModel] = {
        Billboard = billboard,
        SetProgress = setProgress,
    }

    shrineModel.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if conn1 then conn1:Disconnect() end
            if conn2 then conn2:Disconnect() end
            if conn3 then conn3:Disconnect() end
            if billboard and billboard.Parent then billboard:Destroy() end
            activeShrineRings[shrineModel] = nil
        end
    end)
end

-- Şarj Alanı Baloncuğu Görsel Efekti (Oyuncu yaklaştığında beliren koruyucu/şarj baloncuk alanı)
local function setupShrineZoneBubble(shrineModel)
    task.spawn(function()
        local bubble = shrineModel:WaitForChild("ChargeZoneBubble", 6)
        if not bubble or not bubble:IsA("BasePart") then return end

        local currentTransparency = 1
        bubble.Transparency = 1

        local conn
        conn = RunService.RenderStepped:Connect(function(dt)
            if not shrineModel.Parent or not bubble.Parent then
                if conn then conn:Disconnect() end
                return
            end

            -- Duraklatma (Pause) Kuralları: Oyun durduğunda efekti ve sayacı dondur
            if ReplicatedStorage:GetAttribute("IsPaused") == true then
                return
            end

            local isCompleted = shrineModel:GetAttribute("IsCompleted") == true
            if isCompleted then
                bubble.Transparency = 1
                if conn then conn:Disconnect() end
                return
            end

            local isCharging = shrineModel:GetAttribute("IsCharging") == true

            local targetTransparency = 1
            if isCharging then
                -- Sadece şarj edilirken alan görünür ve nabız gibi atar
                local pulse = math.sin(os.clock() * 4.5) * 0.08
                targetTransparency = 0.66 + pulse
            else
                -- Yanına gidildiğinde veya şarj edilmiyorken alan tamamen gizlidir
                targetTransparency = 1
            end

            -- Yumuşak interpolasyon
            currentTransparency = currentTransparency + (targetTransparency - currentTransparency) * math.clamp(dt * 8, 0, 1)
            bubble.Transparency = currentTransparency
        end)

        shrineModel.AncestryChanged:Connect(function(_, parent)
            if not parent and conn then
                conn:Disconnect()
            end
        end)
    end)
end

local function handleNewShrine(child)
    task.spawn(setupShrineChargeRing, child)
    task.spawn(setupShrineZoneBubble, child)
end

-- workspace.ActiveShrines içindeki tüm sunakları dinle
local shrinesFolder = workspace:WaitForChild("ActiveShrines", 15)
if shrinesFolder then
    for _, child in ipairs(shrinesFolder:GetChildren()) do
        handleNewShrine(child)
    end
    shrinesFolder.ChildAdded:Connect(function(child)
        handleNewShrine(child)
    end)
end

-- ============================================================
-- 2. STAT UPGRADE SELECTION UI (MegaBonk Style Horizontal Bars)
-- Sadece "Charge Shrine" başlığı, arka plan kutusu yok (Level Up UI gibi)
-- "Ignore Offers" butonu bulunmaz.
-- ============================================================
local RARITY_COLORS = {
    Common = Color3.fromRGB(180, 190, 205),
    Uncommon = Color3.fromRGB(31, 241, 119),
    Rare = Color3.fromRGB(60, 175, 255),
    Epic = Color3.fromRGB(195, 80, 255),
    Legendary = Color3.fromRGB(255, 200, 50),
}

local RARITY_HEX = {
    Common = "#B4BECD",
    Uncommon = "#1FF177",
    Rare = "#3CAFFF",
    Epic = "#C350FF",
    Legendary = "#FFC832",
}

local STAT_DISPLAY_MAP = {
    Damage = { Amount = "+8%", Name = "Damage" },
    MaxHealth = { Amount = "+15", Name = "Max Health" },
    AttackSpeed = { Amount = "+5%", Name = "Attack Speed" },
    MoveSpeed = { Amount = "+5%", Name = "Move Speed" },
    CritChance = { Amount = "+4%", Name = "Crit Chance" },
    CritDamage = { Amount = "+15%", Name = "Crit Damage" },
    Regen = { Amount = "+0.25 HP/s", Name = "Health Regen" },
    Magnet = { Amount = "+15%", Name = "Pickup Range" },
    Area = { Amount = "+8%", Name = "Area Size" },
    ProjectileCount = { Amount = "+1", Name = "Projectiles" },
}

local function closeShrineRewardUI()
    if not currentRewardGui then return end
    local gui = currentRewardGui
    currentRewardGui = nil
    
    -- Oyuncu hareketini serbest bırak
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hum then
        local speedBonus = Player:GetAttribute("SpeedBonus") or 0
        local baseSpeed = 17 + speedBonus
        local isSprinting = Player:GetAttribute("IsSprinting") == true
        hum.WalkSpeed = isSprinting and (baseSpeed * 1.5) or baseSpeed
    end
    if hrp then
        hrp.Anchored = false
    end
    
    local mainPanel = gui:FindFirstChild("MainPanel")
    local bgOverlay = gui:FindFirstChild("BackgroundOverlay")
    if bgOverlay then
        TweenService:Create(bgOverlay, TweenInfo.new(0.25), {
            BackgroundTransparency = 1
        }):Play()
    end
    if mainPanel then
        local tweenOut = TweenService:Create(mainPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0.65, 0)
        })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            gui:Destroy()
        end)
    else
        gui:Destroy()
    end
end

local function showShrineRewardUI(shrineId, offers)
    closeShrineRewardUI()
    
    -- Upgrade seçim ekranındayken oyuncunun hareketini istemcide de dondur
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hum then
        hum.WalkSpeed = 0
    end
    if hrp then
        hrp.Anchored = true
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ShrineRewardScreen"
    screenGui.DisplayOrder = 150
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = PlayerGui
    currentRewardGui = screenGui
    
    -- Serbest fare imleci
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    
    -- Karartma Katmanı (Level Up UI ile birebir aynı: Sadece sahneyi hafif karartır)
    local bgOverlay = Instance.new("Frame")
    bgOverlay.Name = "BackgroundOverlay"
    bgOverlay.Size = UDim2.new(10, 0, 10, 0)
    bgOverlay.Position = UDim2.new(-4.5, 0, -4.5, 0)
    bgOverlay.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
    bgOverlay.BackgroundTransparency = 1
    bgOverlay.BorderSizePixel = 0
    bgOverlay.Parent = screenGui
    
    TweenService:Create(bgOverlay, TweenInfo.new(0.4), {
        BackgroundTransparency = 0.6
    }):Play()
    
    -- Ana Panel (Kompakt ve Şık Arka Plan Kutusu)
    local mainPanel = Instance.new("Frame")
    mainPanel.Name = "MainPanel"
    mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
    mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainPanel.Size = UDim2.new(0, 716, 0, 376)
    mainPanel.BackgroundColor3 = Color3.fromRGB(8, 14, 11)
    mainPanel.BackgroundTransparency = 0.15
    mainPanel.BorderSizePixel = 0
    mainPanel.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainPanel
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(31, 241, 119)
    mainStroke.Transparency = 0.65
    mainStroke.Thickness = 1.5
    mainStroke.Parent = mainPanel
    
    -- Duyarlı Ölçeklendirme (UIScale)
    local uiScale = Instance.new("UIScale")
    uiScale.Parent = mainPanel
    
    local function updateScale()
        local camera = workspace.CurrentCamera
        if camera then
            local vpSize = camera.ViewportSize
            local targetScale = math.clamp(math.min(vpSize.X / 800, vpSize.Y / 550), 0.65, 1.15)
            uiScale.Scale = targetScale
        end
    end
    updateScale()
    local camConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    screenGui.Destroying:Connect(function()
        if camConn then camConn:Disconnect() end
    end)
    
    -- Başlık: Sadece "Charge Shrine" (Ekstra alt yazı / açıklama kesinlikle yok)
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0, 48)
    titleLabel.Position = UDim2.new(0, 0, 0, 12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Charge Shrine"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.FredokaOne
    titleLabel.TextSize = 40
    titleLabel.TextStrokeTransparency = 0
    titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.Parent = mainPanel
    
    -- Kartlar Taşıyıcısı (Alt alta dikey liste)
    local cardsContainer = Instance.new("Frame")
    cardsContainer.Name = "CardsContainer"
    cardsContainer.AnchorPoint = Vector2.new(0.5, 0)
    cardsContainer.Position = UDim2.new(0.5, 0, 0, 70)
    cardsContainer.Size = UDim2.new(0, 680, 0, 290)
    cardsContainer.BackgroundTransparency = 1
    cardsContainer.Parent = mainPanel
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Padding = UDim.new(0, 14)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = cardsContainer
    
    local hasSelected = false
    
    for i, offer in ipairs(offers) do
        local rarityName = offer.Rarity or "Common"
        local rarityColor = RARITY_COLORS[rarityName] or Color3.fromRGB(180, 190, 205)
        local rarityHex = offer.RarityHex or RARITY_HEX[rarityName] or "#B4BECD"

        local defaultCardBg = Color3.fromRGB(9, 24, 16)
        local defaultStrokeColor = Color3.fromRGB(165, 175, 170)
        local hoverCardBg = Color3.fromRGB(16, 40, 28)
        if rarityName == "Legendary" then
            defaultCardBg = Color3.fromRGB(24, 20, 10)
            defaultStrokeColor = Color3.fromRGB(255, 200, 50)
            hoverCardBg = Color3.fromRGB(36, 28, 12)
        elseif rarityName == "Epic" then
            defaultCardBg = Color3.fromRGB(18, 12, 24)
            defaultStrokeColor = Color3.fromRGB(195, 80, 255)
            hoverCardBg = Color3.fromRGB(28, 18, 36)
        elseif rarityName == "Rare" then
            defaultCardBg = Color3.fromRGB(10, 18, 26)
            defaultStrokeColor = Color3.fromRGB(80, 150, 220)
            hoverCardBg = Color3.fromRGB(14, 28, 42)
        elseif rarityName == "Uncommon" then
            defaultCardBg = Color3.fromRGB(9, 24, 16)
            defaultStrokeColor = Color3.fromRGB(31, 241, 119)
            hoverCardBg = Color3.fromRGB(14, 38, 24)
        end

        -- Kart Butonu (Görsel 1'deki gibi yatay şerit / bar)
        local card = Instance.new("TextButton")
        card.Name = "StatCard_" .. tostring(i)
        card.LayoutOrder = i
        card.Size = UDim2.new(1, 0, 0, 84)
        card.BackgroundColor3 = defaultCardBg
        card.BorderSizePixel = 0
        card.AutoButtonColor = false
        card.Text = ""
        card.ClipsDescendants = false
        card.Parent = cardsContainer
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 4)
        cardCorner.Parent = card
        
        -- Nadirlik çerçeve kenarlığı
        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = defaultStrokeColor
        cardStroke.Thickness = (rarityName == "Legendary" or rarityName == "Epic") and 2.5 or 2
        cardStroke.Parent = card
        
        -- 4 köşe metalik perçin / süslemeler
        local cornerPositions = {
            Vector2.new(0, 0),
            Vector2.new(1, 0),
            Vector2.new(0, 1),
            Vector2.new(1, 1),
        }
        for _, cp in ipairs(cornerPositions) do
            local rivet = Instance.new("Frame")
            rivet.Name = "CornerRivet"
            rivet.AnchorPoint = cp
            rivet.Position = UDim2.new(cp.X, cp.X == 0 and 2 or -2, cp.Y, cp.Y == 0 and 2 or -2)
            rivet.Size = UDim2.new(0, 6, 0, 6)
            rivet.BackgroundColor3 = (rarityName == "Legendary" and Color3.fromRGB(255, 225, 120)) or (rarityName == "Epic" and Color3.fromRGB(230, 160, 255)) or Color3.fromRGB(195, 205, 200)
            rivet.BorderSizePixel = 0
            rivet.ZIndex = 5
            rivet.Parent = card
            
            local rStroke = Instance.new("UIStroke")
            rStroke.Color = Color3.fromRGB(0, 0, 0)
            rStroke.Thickness = 1
            rStroke.Parent = rivet
        end
        
        -- 1. Nadirlik Rozeti (Sol Üst: Dinamik Nadirlik [Common -> Legendary])
        local tagFrame = Instance.new("Frame")
        tagFrame.Name = "TagFrame"
        tagFrame.Position = UDim2.new(0, 16, 0, 10)
        tagFrame.Size = UDim2.new(0, 84, 0, 20)
        tagFrame.BackgroundColor3 = Color3.fromRGB(6, 14, 10)
        tagFrame.BorderSizePixel = 0
        tagFrame.Parent = card
        
        local tagStroke = Instance.new("UIStroke")
        tagStroke.Color = rarityColor
        tagStroke.Thickness = 1.5
        tagStroke.Parent = tagFrame
        
        local tagCorner = Instance.new("UICorner")
        tagCorner.CornerRadius = UDim.new(0, 2)
        tagCorner.Parent = tagFrame
        
        local tagLabel = Instance.new("TextLabel")
        tagLabel.Name = "TagLabel"
        tagLabel.Size = UDim2.new(1, 0, 1, 0)
        tagLabel.BackgroundTransparency = 1
        tagLabel.Font = Enum.Font.GothamBold
        tagLabel.Text = rarityName
        tagLabel.TextSize = 12
        tagLabel.TextColor3 = rarityColor
        tagLabel.Parent = tagFrame
        
        -- 2. Ana Başlık ("Gain +8% Damage", vb. - Nadirlik Rengiyle Vurgulu)
        local statInfo = STAT_DISPLAY_MAP[offer.Key]
        local amountStr = offer.AmountDisplay or (statInfo and statInfo.Amount) or "+BONUS"
        local nameStr = offer.Name or (statInfo and statInfo.Name) or (offer.Title or "Stat")
        
        local mainLabel = Instance.new("TextLabel")
        mainLabel.Name = "MainLabel"
        mainLabel.Position = UDim2.new(0, 16, 0, 36)
        mainLabel.Size = UDim2.new(0.55, 0, 0, 38)
        mainLabel.BackgroundTransparency = 1
        mainLabel.Font = Enum.Font.GothamBold
        mainLabel.TextSize = 22
        mainLabel.TextXAlignment = Enum.TextXAlignment.Left
        mainLabel.RichText = true
        mainLabel.Text = string.format('<font color="#FFFFFF">Gain </font><font color="%s"><b>%s</b></font> <font color="#FFD54F"><b>%s</b></font>', rarityHex, amountStr, nameStr)
        mainLabel.TextStrokeTransparency = 0.5
        mainLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        mainLabel.Parent = card
        
        -- 3. Sağ Taraf Açıklama Metni
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "DescLabel"
        descLabel.Position = UDim2.new(0.56, 0, 0, 8)
        descLabel.Size = UDim2.new(0.40, 0, 1, -16)
        descLabel.BackgroundTransparency = 1
        descLabel.Font = Enum.Font.GothamMedium
        descLabel.TextSize = 12
        descLabel.TextColor3 = Color3.fromRGB(160, 180, 175)
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Right
        descLabel.TextYAlignment = Enum.TextYAlignment.Center
        descLabel.Text = offer.Description or ""
        descLabel.Parent = card
        
        -- Hover & Tıklama Etkileşimleri
        local function onHoverEnter()
            if hasSelected then return end
            TweenService:Create(card, TweenInfo.new(0.12), {
                Size = UDim2.new(1.02, 0, 0, 86),
                BackgroundColor3 = hoverCardBg
            }):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.12), {
                Color = rarityColor,
                Thickness = 3
            }):Play()
        end
        
        local function onHoverLeave()
            if hasSelected then return end
            TweenService:Create(card, TweenInfo.new(0.12), {
                Size = UDim2.new(1, 0, 0, 84),
                BackgroundColor3 = defaultCardBg
            }):Play()
            TweenService:Create(cardStroke, TweenInfo.new(0.12), {
                Color = defaultStrokeColor,
                Thickness = (rarityName == "Legendary" or rarityName == "Epic") and 2.5 or 2
            }):Play()
        end
        
        card.MouseEnter:Connect(onHoverEnter)
        card.MouseLeave:Connect(onHoverLeave)
        
        -- Kart Seçimi
        local function onSelect()
            if hasSelected then return end
            hasSelected = true
            
            for _, c in ipairs(cardsContainer:GetChildren()) do
                if c:IsA("TextButton") then
                    c.Interactable = false
                end
            end
            
            TweenService:Create(cardStroke, TweenInfo.new(0.08), {
                Color = Color3.fromRGB(255, 255, 255),
                Thickness = 4
            }):Play()
            
            SelectShrineStat:FireServer(shrineId, offer.Key)
            
            task.delay(0.2, function()
                closeShrineRewardUI()
            end)
        end
        
        card.MouseButton1Click:Connect(onSelect)
    end
    
    -- Ekrana Geliş Animasyonu (Level Up UI stili yumuşak geliş)
    mainPanel.Position = UDim2.new(0.5, 0, 0.54, 0)
    TweenService:Create(mainPanel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
end

OpenShrineReward.OnClientEvent:Connect(function(shrineId, offers)
    if offers and #offers > 0 then
        showShrineRewardUI(shrineId, offers)
    end
end)

-- Reset or Match End Cleanup
ReplicatedStorage:GetAttributeChangedSignal("GameStarted"):Connect(function()
    if not ReplicatedStorage:GetAttribute("GameStarted") then
        closeShrineRewardUI()
    end
end)
