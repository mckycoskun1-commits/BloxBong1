local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))

-- Remote olaylar
local Events = ReplicatedStorage:WaitForChild("Events")
local LobbyEvents = Events:WaitForChild("LobbyEvents")
local OpenShopUI = LobbyEvents:WaitForChild("OpenShopUI")
local BuyShopUpgrade = LobbyEvents:WaitForChild("BuyShopUpgrade")
local RefundShopUpgrades = LobbyEvents:WaitForChild("RefundShopUpgrades")

-- Ana UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntigravityShopUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.DisplayOrder = 15
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- Responsive Ölçeklendirme (UIScale)
local uiScale = Instance.new("UIScale")
uiScale.Parent = screenGui
local function updateScale()
    local viewport = workspace.CurrentCamera.ViewportSize
    local scale = math.min(viewport.X / 1600, viewport.Y / 900)
    uiScale.Scale = math.clamp(scale, 0.55, 1.8)
end
local viewportConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- Arka Plan Bulanıklığı (Lighting Blur)
local blurEffect = Lighting:FindFirstChild("ShopUIBlur") or Instance.new("BlurEffect")
blurEffect.Name = "ShopUIBlur"
blurEffect.Size = 0
blurEffect.Parent = Lighting

-- Tam Ekran Karartma Overlay'i (Kamera dönüşünü bloke etmemesi için Frame ve Active = false)
local overlay = Instance.new("Frame")
overlay.Name = "ShopOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Active = false -- Kamerayı sağ tık / dokunma ile serbestçe döndürebilmek için
overlay.ZIndex = 1
overlay.Parent = screenGui

-- Retro Köşe Braketleri Yardımcı Fonksiyonu
local function addCornerBrackets(frame, color, size, thick)
    size = size or 8
    thick = thick or 2
    color = color or Color3.fromRGB(175, 190, 210)
    
    local function part(anchor, pos, w, h)
        local p = Instance.new("Frame")
        p.BackgroundColor3 = color
        p.BackgroundTransparency = 0.2
        p.BorderSizePixel = 0
        p.AnchorPoint = anchor
        p.Position = pos
        p.Size = UDim2.new(0, w, 0, h)
        p.ZIndex = frame.ZIndex + 4
        p.Parent = frame
    end
    
    -- Sol Üst (┌)
    part(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), size, thick)
    part(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), thick, size)
    -- Sağ Üst (┐)
    part(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), size, thick)
    part(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), thick, size)
    -- Sol Alt (└)
    part(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), size, thick)
    part(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), thick, size)
    -- Sağ Alt (┘)
    part(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), size, thick)
    part(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), thick, size)
end

-- ==========================================
-- ANA DÜKKAN PANELİ
-- ==========================================
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 1080, 0, 680)
mainPanel.Position = UDim2.new(0.5, 0, 1.4, 0) -- Ekranın tamamen altında başlar
mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
mainPanel.BackgroundColor3 = Color3.fromRGB(24, 25, 30)
mainPanel.BackgroundTransparency = 0.08
mainPanel.BorderSizePixel = 0
mainPanel.ZIndex = 5
mainPanel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = mainPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(65, 70, 85)
panelStroke.Thickness = 2.5
panelStroke.Parent = mainPanel

addCornerBrackets(mainPanel, Color3.fromRGB(120, 140, 175), 14, 3)

-- ==========================================
-- BAŞLIK VE GÜMÜŞ GÖSTERGE BARI
-- ==========================================
local headerBar = Instance.new("Frame")
headerBar.Name = "HeaderBar"
headerBar.Size = UDim2.new(1, 0, 0, 80)
headerBar.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
headerBar.BorderSizePixel = 0
headerBar.ZIndex = 6
headerBar.Parent = mainPanel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 16)
headerCorner.Parent = headerBar

local headerDivider = Instance.new("Frame")
headerDivider.Size = UDim2.new(1, 0, 0, 2)
headerDivider.Position = UDim2.new(0, 0, 1, -2)
headerDivider.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
headerDivider.BorderSizePixel = 0
headerDivider.ZIndex = 7
headerDivider.Parent = headerBar

-- Başlık Yazısı
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(0, 450, 0, 42)
titleLabel.Position = UDim2.new(0, 28, 0, 12)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.Arcade
titleLabel.TextSize = 36
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
titleLabel.Text = "SILVER SHOP"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 8
titleLabel.Parent = headerBar

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(15, 15, 20)
titleStroke.Thickness = 1.5
titleStroke.Parent = titleLabel

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.new(0, 450, 0, 20)
subtitleLabel.Position = UDim2.new(0, 28, 0, 50)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Font = Enum.Font.Arcade
subtitleLabel.TextSize = 16
subtitleLabel.TextColor3 = Color3.fromRGB(170, 180, 200)
subtitleLabel.Text = "PERMANENT TALENTS & SLOTS"
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.ZIndex = 8
subtitleLabel.Parent = headerBar

-- Sağ Üst: Oyuncunun Gümüş Parası (Retro Kutu)
local silverBox = Instance.new("Frame")
silverBox.Name = "SilverBox"
silverBox.Size = UDim2.new(0, 235, 0, 64)
silverBox.Position = UDim2.new(1, -110, 0.5, 0)
silverBox.AnchorPoint = Vector2.new(1, 0.5)
silverBox.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
silverBox.BorderSizePixel = 0
silverBox.ZIndex = 8
silverBox.Parent = headerBar

local silverBoxCorner = Instance.new("UICorner")
silverBoxCorner.CornerRadius = UDim.new(0, 10)
silverBoxCorner.Parent = silverBox

local silverBoxStroke = Instance.new("UIStroke")
silverBoxStroke.Color = Color3.fromRGB(80, 90, 115)
silverBoxStroke.Thickness = 1.5
silverBoxStroke.Parent = silverBox

addCornerBrackets(silverBox, Color3.fromRGB(180, 200, 230), 6, 2)

local silverIcon = Instance.new("ImageLabel")
silverIcon.Name = "SilverIcon"
silverIcon.Size = UDim2.new(0, 72, 0, 72) -- 2 kat büyütüldü (38x38 -> 72x72)
silverIcon.Position = UDim2.new(0, 4, 0.5, 0)
silverIcon.AnchorPoint = Vector2.new(0, 0.5)
silverIcon.BackgroundTransparency = 1
silverIcon.Image = "rbxassetid://104534575155839"
silverIcon.ZIndex = 9
silverIcon.Parent = silverBox

local silverLabel = Instance.new("TextLabel")
silverLabel.Name = "SilverLabel"
silverLabel.Size = UDim2.new(1, -80, 1, 0)
silverLabel.Position = UDim2.new(0, 76, 0, 0)
silverLabel.BackgroundTransparency = 1
silverLabel.Font = Enum.Font.Arcade
silverLabel.TextSize = 32
silverLabel.TextColor3 = Color3.fromRGB(245, 250, 255)
silverLabel.Text = tostring(math.floor(Player:GetAttribute("Silver") or 0))
silverLabel.TextXAlignment = Enum.TextXAlignment.Center
silverLabel.ZIndex = 9
silverLabel.Parent = silverBox

local function updateSilverDisplay()
    local val = math.floor(Player:GetAttribute("Silver") or 0)
    silverLabel.Text = tostring(val)
end
Player:GetAttributeChangedSignal("Silver"):Connect(function()
    updateSilverDisplay()
    local pop = TweenService:Create(silverIcon, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 82, 0, 82)
    })
    pop:Play()
    pop.Completed:Connect(function()
        TweenService:Create(silverIcon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 72, 0, 72)
        }):Play()
    end)
end)
-- ==========================================
-- GÜMÜŞ DÜKKANI: TÜM GELİŞTİRMELERİ İADE ET (REFUND) BUTONU
-- Paranın (SilverBox) hemen solunda yer alır
-- ==========================================
local refundBtn = Instance.new("TextButton")
refundBtn.Name = "RefundBtn"
refundBtn.Size = UDim2.new(0, 150, 0, 52)
refundBtn.Position = UDim2.new(1, -360, 0.5, 0)
refundBtn.AnchorPoint = Vector2.new(1, 0.5)
refundBtn.BackgroundColor3 = Color3.fromRGB(42, 28, 34)
refundBtn.BorderSizePixel = 0
refundBtn.Text = ""
refundBtn.AutoButtonColor = false
refundBtn.ZIndex = 8
refundBtn.Parent = headerBar

local refundCorner = Instance.new("UICorner")
refundCorner.CornerRadius = UDim.new(0, 10)
refundCorner.Parent = refundBtn

local refundStroke = Instance.new("UIStroke")
refundStroke.Color = Color3.fromRGB(180, 75, 80)
refundStroke.Thickness = 1.5
refundStroke.Parent = refundBtn

addCornerBrackets(refundBtn, Color3.fromRGB(240, 110, 115), 6, 2)

local refundLabel = Instance.new("TextLabel")
refundLabel.Name = "RefundLabel"
refundLabel.Size = UDim2.new(1, 0, 1, 0)
refundLabel.Position = UDim2.new(0.5, 0, 0.5, -2)
refundLabel.AnchorPoint = Vector2.new(0.5, 0.5)
refundLabel.BackgroundTransparency = 1
refundLabel.Font = Enum.Font.Arcade
refundLabel.TextSize = 20
refundLabel.TextColor3 = Color3.fromRGB(255, 140, 130)
refundLabel.Text = "↺ REFUND"
refundLabel.ZIndex = 9
refundLabel.Parent = refundBtn

local isRefunding = false

local function updateRefundButtonState()
    local total = 0
    for _, upg in pairs(ShopConfig.Upgrades) do
        total = total + (Player:GetAttribute(upg.Attribute) or 0)
    end
    if isRefunding then return end

    if total > 0 then
        refundBtn.Interactable = true
        refundBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 36)
        refundStroke.Color = Color3.fromRGB(180, 75, 80)
        refundLabel.TextColor3 = Color3.fromRGB(255, 140, 130)
    else
        refundBtn.Interactable = false
        refundBtn.BackgroundColor3 = Color3.fromRGB(28, 26, 32)
        refundStroke.Color = Color3.fromRGB(65, 62, 72)
        refundLabel.TextColor3 = Color3.fromRGB(120, 115, 125)
    end
end

refundBtn.MouseEnter:Connect(function()
    if refundBtn.Interactable and not isRefunding then
        TweenService:Create(refundBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(65, 35, 45) }):Play()
        TweenService:Create(refundStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(255, 110, 115) }):Play()
        TweenService:Create(refundLabel, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255, 220, 220) }):Play()
    end
end)

refundBtn.MouseLeave:Connect(function()
    if refundBtn.Interactable and not isRefunding then
        TweenService:Create(refundBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(45, 30, 36) }):Play()
        TweenService:Create(refundStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(180, 75, 80) }):Play()
        TweenService:Create(refundLabel, TweenInfo.new(0.15), { TextColor3 = Color3.fromRGB(255, 140, 130) }):Play()
    end
end)

refundBtn.MouseButton1Click:Connect(function()
    if not refundBtn.Interactable or isRefunding then return end
    isRefunding = true
    refundBtn.Interactable = false

    local success, totalRefunded, newBalance = RefundShopUpgrades:InvokeServer()
    if success and totalRefunded and totalRefunded > 0 then
        local pop = TweenService:Create(refundBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 160, 0, 56)
        })
        pop:Play()
        pop.Completed:Connect(function()
            TweenService:Create(refundBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 150, 0, 52)
            }):Play()
        end)

        refundLabel.Text = "+" .. tostring(totalRefunded) .. " SILVER!"
        refundLabel.TextColor3 = Color3.fromRGB(80, 255, 140)

        updateAllCards()
        updateSilverDisplay()

        task.delay(1.6, function()
            refundLabel.Text = "↺ REFUND"
            isRefunding = false
            updateRefundButtonState()
        end)
    else
        refundLabel.Text = "NO TALENTS"
        refundLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
        task.delay(1.2, function()
            refundLabel.Text = "↺ REFUND"
            isRefunding = false
            updateRefundButtonState()
        end)
    end
end)

-- Sağ Üst: Kapatma Butonu [X]
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 44, 0, 44)
closeBtn.Position = UDim2.new(1, -22, 0.5, 0)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(42, 28, 32)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "" -- Metni içine ekleyeceğimiz TextLabel ile tam ortalayacağız
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 8
closeBtn.Parent = headerBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeBtn

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(120, 45, 55)
closeStroke.Thickness = 1.5
closeStroke.Parent = closeBtn

addCornerBrackets(closeBtn, Color3.fromRGB(220, 90, 100), 6, 2)

-- Tam geometrik ve optik olarak ortalanmış Çarpı (X)
local closeText = Instance.new("TextLabel")
closeText.Name = "CloseText"
closeText.Size = UDim2.new(1, 0, 1, 0)
closeText.Position = UDim2.new(0.5, 0, 0.5, -3) -- Arcade fontundaki font-baseline farkını tam dengeler
closeText.AnchorPoint = Vector2.new(0.5, 0.5)
closeText.BackgroundTransparency = 1
closeText.Font = Enum.Font.Arcade
closeText.TextSize = 26
closeText.TextColor3 = Color3.fromRGB(255, 120, 120)
closeText.Text = "X"
closeText.TextXAlignment = Enum.TextXAlignment.Center
closeText.TextYAlignment = Enum.TextYAlignment.Center
closeText.ZIndex = 9
closeText.Parent = closeBtn

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(90, 32, 40)}):Play()
    TweenService:Create(closeText, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 170, 170)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(42, 28, 32)}):Play()
    TweenService:Create(closeText, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 120, 120)}):Play()
end)

-- ==========================================
-- GELİŞTİRME KARTLARI LİSTESİ (ScrollingFrame)
-- ==========================================
local scrollContainer = Instance.new("ScrollingFrame")
scrollContainer.Name = "CardsScroll"
scrollContainer.Size = UDim2.new(1, -44, 1, -100)
scrollContainer.Position = UDim2.new(0, 22, 0, 92)
scrollContainer.BackgroundTransparency = 1
scrollContainer.BorderSizePixel = 0
scrollContainer.ScrollBarThickness = 6
scrollContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 90, 115)
scrollContainer.CanvasSize = UDim2.new(0, 0, 0, 0) -- Otomatik hesaplanacak
scrollContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollContainer.ScrollingDirection = Enum.ScrollingDirection.Y
scrollContainer.ZIndex = 6
scrollContainer.Parent = mainPanel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 325, 0, 310)
gridLayout.CellPadding = UDim2.new(0, 22, 0, 20)
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollContainer

-- Kartları ve Butonları Saklama
local upgradeCardFrames = {}

-- Kart Çizim ve Güncelleme Fonksiyonu
local function renderUpgradeCard(upgradeKey, orderIndex)
    local upgrade = ShopConfig.Upgrades[upgradeKey]
    if not upgrade then return end
    
    local currentLevel = Player:GetAttribute(upgrade.Attribute) or 0
    local isMaxed = currentLevel >= upgrade.MaxLevel
    local nextCost = not isMaxed and upgrade.Costs[currentLevel + 1] or 0
    local playerSilver = math.floor(Player:GetAttribute("Silver") or 0)
    local canAfford = not isMaxed and (playerSilver >= nextCost)
    
    local card = upgradeCardFrames[upgradeKey]
    if not card then
        -- Kart ilk kez oluşturuluyor
        card = Instance.new("Frame")
        card.Name = "Card_" .. upgradeKey
        card.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
        card.BorderSizePixel = 0
        card.LayoutOrder = orderIndex
        card.ZIndex = 7
        card.Parent = scrollContainer
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 14)
        cardCorner.Parent = card
        
        local cardStroke = Instance.new("UIStroke")
        cardStroke.Name = "CardStroke"
        cardStroke.Color = Color3.fromRGB(60, 65, 80)
        cardStroke.Thickness = 2
        cardStroke.Parent = card
        
        addCornerBrackets(card, Color3.fromRGB(140, 155, 185), 8, 2)
        
        -- İkon Çerçevesi (1.5 kat büyütüldü: 96x96)
        local iconBox = Instance.new("Frame")
        iconBox.Name = "IconBox"
        iconBox.Size = UDim2.new(0, 96, 0, 96)
        iconBox.Position = UDim2.new(0, 16, 0, 16)
        iconBox.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
        iconBox.BorderSizePixel = 0
        iconBox.ClipsDescendants = true
        iconBox.ZIndex = 8
        iconBox.Parent = card
        
        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0, 14)
        iconCorner.Parent = iconBox
        
        local iconStroke = Instance.new("UIStroke")
        iconStroke.Color = Color3.fromRGB(70, 78, 100)
        iconStroke.Thickness = 1.5
        iconStroke.Parent = iconBox
        
        local iconScale = upgrade.IconScale or 1.0
        local iconImg = Instance.new("ImageLabel")
        iconImg.Name = "Icon"
        iconImg.Size = UDim2.new(0.64 * iconScale, 0, 0.64 * iconScale, 0)
        iconImg.Position = UDim2.new(0.5, 0, 0.5, 0)
        iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
        iconImg.BackgroundTransparency = 1
        iconImg.Image = upgrade.Icon
        iconImg.ZIndex = 9
        iconImg.Parent = iconBox
        
        -- Kategori Rozeti (SLOT, UTILITY, STAT)
        local catBadge = Instance.new("TextLabel")
        catBadge.Name = "CategoryBadge"
        catBadge.Size = UDim2.new(0, 76, 0, 20)
        catBadge.Position = UDim2.new(0, 124, 0, 20)
        catBadge.BackgroundColor3 = (upgrade.Category == "SLOT") and Color3.fromRGB(80, 50, 120) 
            or (upgrade.Category == "UTILITY" and Color3.fromRGB(40, 90, 120) or Color3.fromRGB(50, 100, 70))
        catBadge.BackgroundTransparency = 0.3
        catBadge.BorderSizePixel = 0
        catBadge.Font = Enum.Font.Arcade
        catBadge.TextSize = 13
        catBadge.TextColor3 = Color3.fromRGB(220, 230, 255)
        catBadge.Text = upgrade.Category or "STAT"
        catBadge.ZIndex = 8
        catBadge.Parent = card
        
        local catCorner = Instance.new("UICorner")
        catCorner.CornerRadius = UDim.new(0, 4)
        catCorner.Parent = catBadge
        
        -- Başlık
        local cardTitle = Instance.new("TextLabel")
        cardTitle.Name = "CardTitle"
        cardTitle.Size = UDim2.new(1, -136, 0, 48)
        cardTitle.Position = UDim2.new(0, 124, 0, 46)
        cardTitle.BackgroundTransparency = 1
        cardTitle.Font = Enum.Font.Arcade
        cardTitle.TextSize = 20
        cardTitle.TextColor3 = Color3.fromRGB(255, 240, 200)
        cardTitle.Text = upgrade.Title
        cardTitle.TextWrapped = true
        cardTitle.TextXAlignment = Enum.TextXAlignment.Left
        cardTitle.TextYAlignment = Enum.TextYAlignment.Top
        cardTitle.ZIndex = 8
        cardTitle.Parent = card
        
        -- Kademe (Rank / Pip) Konteyneri
        local pipContainer = Instance.new("Frame")
        pipContainer.Name = "PipContainer"
        pipContainer.Size = UDim2.new(1, -32, 0, 12)
        pipContainer.Position = UDim2.new(0, 16, 0, 122)
        pipContainer.BackgroundTransparency = 1
        pipContainer.ZIndex = 8
        pipContainer.Parent = card
        
        local pipLayout = Instance.new("UIListLayout")
        pipLayout.FillDirection = Enum.FillDirection.Horizontal
        pipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        pipLayout.Padding = UDim.new(0, 6)
        pipLayout.Parent = pipContainer
        
        -- Açıklama (Ultra Okunaklı ve Ferah)
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "Description"
        descLabel.Size = UDim2.new(1, -32, 0, 68)
        descLabel.Position = UDim2.new(0, 16, 0, 144)
        descLabel.BackgroundTransparency = 1
        descLabel.Font = Enum.Font.GothamMedium
        descLabel.TextSize = 17
        descLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
        descLabel.Text = upgrade.Description
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.LineHeight = 1.15
        descLabel.ZIndex = 8
        descLabel.Parent = card
        
        -- Satın Alma / Durum Butonu
        local buyBtn = Instance.new("TextButton")
        buyBtn.Name = "BuyBtn"
        buyBtn.Size = UDim2.new(1, -32, 0, 52)
        buyBtn.Position = UDim2.new(0, 16, 1, -66)
        buyBtn.BorderSizePixel = 0
        buyBtn.Text = "" -- Varsayılan "Button" yazısını engelle
        buyBtn.AutoButtonColor = false
        buyBtn.ZIndex = 8
        buyBtn.Parent = card
        
        local buyCorner = Instance.new("UICorner")
        buyCorner.CornerRadius = UDim.new(0, 10)
        buyCorner.Parent = buyBtn
        
        local buyStroke = Instance.new("UIStroke")
        buyStroke.Name = "BuyStroke"
        buyStroke.Thickness = 1.5
        buyStroke.Parent = buyBtn
        
        -- Satın al butonu içeriği (İkon + Metin)
        local btnIcon = Instance.new("ImageLabel")
        btnIcon.Name = "CoinIcon"
        btnIcon.Size = UDim2.new(0, 44, 0, 44)
        btnIcon.Position = UDim2.new(0, 10, 0.5, 0)
        btnIcon.AnchorPoint = Vector2.new(0, 0.5)
        btnIcon.BackgroundTransparency = 1
        btnIcon.Image = "rbxassetid://104534575155839"
        btnIcon.ZIndex = 9
        btnIcon.Parent = buyBtn
        
        local btnText = Instance.new("TextLabel")
        btnText.Name = "BtnText"
        btnText.Size = UDim2.new(1, -64, 1, 0)
        btnText.Position = UDim2.new(0, 56, 0, 0)
        btnText.BackgroundTransparency = 1
        btnText.Font = Enum.Font.Arcade
        btnText.TextSize = 22
        btnText.TextXAlignment = Enum.TextXAlignment.Center
        btnText.ZIndex = 9
        btnText.Parent = buyBtn
        
        upgradeCardFrames[upgradeKey] = card
    end
    
    -- PIP'LERİ (Kademe Kutularını) GÜNCELLE
    local pipContainer = card:FindFirstChild("PipContainer")
    if pipContainer then
        for _, child in ipairs(pipContainer:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        
        local totalPips = upgrade.MaxLevel
        local pipWidth = math.floor((293 - (totalPips - 1) * 6) / totalPips)
        for p = 1, totalPips do
            local pip = Instance.new("Frame")
            pip.Name = "Pip_" .. p
            pip.Size = UDim2.new(0, pipWidth, 0, 10)
            pip.BorderSizePixel = 0
            pip.ZIndex = 8
            pip.Parent = pipContainer
            
            local pCorn = Instance.new("UICorner")
            pCorn.CornerRadius = UDim.new(0, 3)
            pCorn.Parent = pip
            
            if p <= currentLevel then
                -- Kazanılmış seviye (Canlı yeşil/altın parıltı)
                pip.BackgroundColor3 = (totalPips == 2) and Color3.fromRGB(180, 110, 255) or Color3.fromRGB(55, 230, 125)
            else
                -- Boş seviye
                pip.BackgroundColor3 = Color3.fromRGB(45, 48, 60)
            end
        end
    end
    
    -- BUTON VE RENKLERİ GÜNCELLE
    local buyBtn = card:FindFirstChild("BuyBtn")
    if buyBtn then
        local btnIcon = buyBtn:FindFirstChild("CoinIcon")
        local btnText = buyBtn:FindFirstChild("BtnText")
        local buyStroke = buyBtn:FindFirstChild("BuyStroke")
        
        if isMaxed then
            -- MAKSİMUM SEVİYE
            buyBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 44)
            buyBtn.Interactable = false
            if btnIcon then btnIcon.Visible = false end
            if btnText then
                btnText.Size = UDim2.new(1, 0, 1, 0)
                btnText.Position = UDim2.new(0, 0, 0, 0)
                btnText.Text = "★ MAXED"
                btnText.TextColor3 = Color3.fromRGB(255, 215, 60)
            end
            if buyStroke then
                buyStroke.Color = Color3.fromRGB(120, 105, 50)
            end
        elseif canAfford then
            -- SATIN ALINABİLİR
            buyBtn.BackgroundColor3 = Color3.fromRGB(35, 130, 75)
            buyBtn.Interactable = true
            if btnIcon then btnIcon.Visible = true end
            if btnText then
                btnText.Size = UDim2.new(1, -64, 1, 0)
                btnText.Position = UDim2.new(0, 56, 0, 0)
                btnText.Text = tostring(nextCost) .. " SILVER"
                btnText.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
            if buyStroke then
                buyStroke.Color = Color3.fromRGB(75, 205, 120)
            end
        else
            -- YETERSİZ GÜMÜŞ
            buyBtn.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
            buyBtn.Interactable = false
            if btnIcon then btnIcon.Visible = true end
            if btnText then
                btnText.Size = UDim2.new(1, -64, 1, 0)
                btnText.Position = UDim2.new(0, 56, 0, 0)
                btnText.Text = tostring(nextCost) .. " SILVER"
                btnText.TextColor3 = Color3.fromRGB(160, 165, 180)
            end
            if buyStroke then
                buyStroke.Color = Color3.fromRGB(70, 75, 90)
            end
        end
        
        -- Click Eventini sadece 1 kez bağla
        if not buyBtn:GetAttribute("Connected") then
            buyBtn:SetAttribute("Connected", true)
            
            buyBtn.MouseEnter:Connect(function()
                if buyBtn.Interactable then
                    TweenService:Create(buyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 160, 95)}):Play()
                end
            end)
            
            buyBtn.MouseLeave:Connect(function()
                if buyBtn.Interactable then
                    TweenService:Create(buyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 130, 75)}):Play()
                end
            end)
            
            buyBtn.MouseButton1Click:Connect(function()
                if not buyBtn.Interactable then return end
                buyBtn.Interactable = false
                
                -- Satın Alma İsteği Gönder
                local success, result, remaining = BuyShopUpgrade:InvokeServer(upgradeKey)
                if success then
                    SoundManager.PlaySound("Purchase")

                    -- Başarılı Animasyonu (Kart sıçraması)
                    local bounce = TweenService:Create(card, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Size = UDim2.new(0, 335, 0, 268)
                    })
                    bounce:Play()
                    bounce.Completed:Connect(function()
                        TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                            Size = UDim2.new(0, 325, 0, 260)
                        }):Play()
                    end)
                    
                    -- Tüm kartları ve gümüşü hemen güncelle
                    updateAllCards()
                else
                    warn("[ShopUI] Satin alma basarisiz: " .. tostring(result))
                    buyBtn.Interactable = true
                end
            end)
        end
    end
end

function updateAllCards()
    for index, key in ipairs(ShopConfig.Order) do
        renderUpgradeCard(key, index)
    end
    if updateRefundButtonState then
        updateRefundButtonState()
    end
end

-- ==========================================
-- EFEKTLİ AÇILMA / KAPANMA SİSTEMİ (CLASS UI GİBİ)
-- ==========================================
local isUIOpen = false
local isAnimating = false

local function closeOtherLobbyUIs()
    -- Class UI kapat
    if typeof(_G.CloseBloxBongClassUI) == "function" then
        _G.CloseBloxBongClassUI()
    else
        local classUI = PlayerGui:FindFirstChild("AntigravityClassUI")
        if classUI and classUI.Enabled then
            classUI.Enabled = false
            local classBlur = Lighting:FindFirstChild("ClassUIBlur")
            if classBlur then classBlur.Size = 0 end
        end
    end
    
    -- Index UI kapat
    if typeof(_G.CloseBloxBongIndexUI) == "function" then
        _G.CloseBloxBongIndexUI()
    else
        local indexUI = PlayerGui:FindFirstChild("IndexUI")
        if indexUI then
            indexUI:SetAttribute("Open", false)
            indexUI.Enabled = false
        end
    end
    local sidebarUI = PlayerGui:FindFirstChild("SidebarUI")
    if sidebarUI then
        local indexPanel = sidebarUI:FindFirstChild("IndexPanel")
        local indexOverlay = sidebarUI:FindFirstChild("IndexOverlay")
        if indexPanel and indexPanel.Visible then
            indexPanel.Visible = false
            if indexOverlay then indexOverlay.Visible = false end
            local indexBlur = Lighting:FindFirstChild("IndexBlur")
            if indexBlur then indexBlur.Size = 0 end
        end
    end

    -- Settings UI kapat
    if typeof(_G.CloseBloxBongSettingsUI) == "function" then
        _G.CloseBloxBongSettingsUI()
    end
    
    -- Lobi Matchmaking UI kapat
    if typeof(_G.CloseBloxBongLobbyUI) == "function" then
        _G.CloseBloxBongLobbyUI()
    else
        local lobbyUI = PlayerGui:FindFirstChild("SolidLobbyUI")
        if lobbyUI then
            local mainP = lobbyUI:FindFirstChild("MainPanel")
            if mainP and mainP.Visible then
                mainP.Visible = false
                local lobbyBlur = Lighting:FindFirstChild("LobbyUIBlur")
                if lobbyBlur then lobbyBlur.Size = 0 end
            end
        end
    end
end

local function toggleShopUI(state)
    if state == isUIOpen then return end
    if state == true and isAnimating then return end
    isAnimating = true
    isUIOpen = state
    
    -- Dükkan NPC prompt'unu UI açıkken gizle
    local npcName = LobbyConfig.Visuals.ShopNPC_ModelName or "Shop"
    local npc = workspace:FindFirstChild(npcName) or workspace:FindFirstChild("Shop") or workspace:FindFirstChild("ShopNPC")
    if npc then
        local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then prompt.Enabled = not state end
    end
    
    if state then
        closeOtherLobbyUIs()
        screenGui.Enabled = true
        updateSilverDisplay()
        updateAllCards()
        
        -- Başlangıç pozisyonu: Ekranın tamamen altında
        mainPanel.Position = UDim2.new(0.5, 0, 1.4, 0)
        overlay.BackgroundTransparency = 1
        
        -- EFEKTLİ AÇILMA: Blur + Exponential yumuşak yükselme
        TweenService:Create(blurEffect, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 24}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.55}):Play()
        
        local openTween = TweenService:Create(mainPanel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0.5, 0)
        })
        openTween:Play()
        openTween.Completed:Connect(function()
            isAnimating = false
        end)
    else
        -- EFEKTLİ KAPANMA: Ekranın tamamen altına kayma + Blur sıfırlama (Kesilme olmadan pürüzsüz)
        TweenService:Create(blurEffect, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
        
        local closeTween = TweenService:Create(mainPanel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 1.4, 0)
        })
        closeTween:Play()
        closeTween.Completed:Connect(function()
            screenGui.Enabled = false
            isAnimating = false
        end)
    end
end

-- Server'dan tetiklenme (NPC etkileşimi)
OpenShopUI.OnClientEvent:Connect(function()
    toggleShopUI(true)
end)

-- Kapatma Etkileşimleri
closeBtn.MouseButton1Click:Connect(function()
    toggleShopUI(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not isUIOpen then return end
    
    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Escape then
        toggleShopUI(false)
        return
    end
    
    -- Panel dışına sol tıklandığında menüyü kapat (Kamera döndürmeyi engellemeden)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
        local mousePos = UserInputService:GetMouseLocation()
        local pPos = mainPanel.AbsolutePosition
        local pSize = mainPanel.AbsoluteSize
        
        local inPanel = (mousePos.X >= pPos.X and mousePos.X <= pPos.X + pSize.X 
            and mousePos.Y >= pPos.Y and mousePos.Y <= pPos.Y + pSize.Y)
            
        if not inPanel then
            toggleShopUI(false)
        end
    end
end)

-- Shift ile koşarken MouseWheel dikey kaydırma düzeltmesi:
-- Roblox, Shift tuşuna basılıyken tekerlek dönüşünü yatay (X) kaydırmaya çevirir.
-- Menümüz yalnızca dikey eksende (Y) çalıştığından ve yatay kaydırma olmadığından kaydırma kilitlenirdi.
UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if not isUIOpen then return end
    
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        local isShiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) 
            or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
            
        if isShiftHeld then
            local mousePos = UserInputService:GetMouseLocation()
            local pPos = mainPanel.AbsolutePosition
            local pSize = mainPanel.AbsoluteSize
            
            local inPanel = (mousePos.X >= pPos.X and mousePos.X <= pPos.X + pSize.X 
                and mousePos.Y >= pPos.Y and mousePos.Y <= pPos.Y + pSize.Y)
                
            if inPanel then
                local delta = input.Position.Z -- Yukarı: +1, Aşağı: -1
                local currentY = scrollContainer.CanvasPosition.Y
                local maxY = math.max(0, scrollContainer.AbsoluteCanvasSize.Y - scrollContainer.AbsoluteWindowSize.Y)
                local step = 70
                
                local targetY = math.clamp(currentY - (delta * step), 0, maxY)
                scrollContainer.CanvasPosition = Vector2.new(0, targetY)
            end
        end
    end
end)

-- Global erişim (Sidebar veya diğer scriptlerden kolayca açabilmek için)
_G.OpenBloxBongShopUI = function()
    toggleShopUI(true)
end
_G.CloseBloxBongShopUI = function()
    toggleShopUI(false)
end
