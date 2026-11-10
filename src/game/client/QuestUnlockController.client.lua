local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))

local Events = ReplicatedStorage:WaitForChild("Events")
local QuestUnlocked = Events:WaitForChild("QuestUnlocked")

-- Kart Temaları: Siyah yerine açılan kartın rengiyle uyumlu, hafif açık, göz yormayan zemin paleti
local cardThemeMap = {
    Regeneration = {
        BgTop = Color3.fromRGB(38, 72, 48),       -- Canlı Zümrüt / Healing Forest Green
        BgBottom = Color3.fromRGB(24, 48, 32),
        Border = Color3.fromRGB(80, 165, 105),
        Accent = Color3.fromRGB(120, 245, 155),
        IconBg = Color3.fromRGB(20, 42, 28),
        IconBorder = Color3.fromRGB(60, 120, 80),
    },
    Lifesteal = {
        BgTop = Color3.fromRGB(72, 42, 52),       -- Yumuşak Şarap / Rose Slate
        BgBottom = Color3.fromRGB(48, 28, 36),
        Border = Color3.fromRGB(155, 90, 105),
        Accent = Color3.fromRGB(245, 140, 155),
        IconBg = Color3.fromRGB(42, 24, 30),
        IconBorder = Color3.fromRGB(110, 62, 75),
    },
    CritMultiplier = {
        BgTop = Color3.fromRGB(74, 58, 38),       -- Sıcak Kehribar / Warm Honey Amber
        BgBottom = Color3.fromRGB(52, 40, 26),
        Border = Color3.fromRGB(168, 132, 82),
        Accent = Color3.fromRGB(255, 205, 110),
        IconBg = Color3.fromRGB(44, 34, 22),
        IconBorder = Color3.fromRGB(120, 94, 58),
    },
    CritChance = {
        BgTop = Color3.fromRGB(76, 48, 42),       -- Yumuşak Mercan / Warm Terracotta
        BgBottom = Color3.fromRGB(54, 32, 28),
        Border = Color3.fromRGB(170, 102, 90),
        Accent = Color3.fromRGB(255, 150, 130),
        IconBg = Color3.fromRGB(46, 28, 24),
        IconBorder = Color3.fromRGB(124, 72, 64),
    },
    FireTrailWeapon = {
        BgTop = Color3.fromRGB(80, 52, 34),       -- Sıcak Köz / Warm Ember
        BgBottom = Color3.fromRGB(56, 34, 22),
        Border = Color3.fromRGB(175, 112, 70),
        Accent = Color3.fromRGB(255, 168, 95),
        IconBg = Color3.fromRGB(48, 30, 18),
        IconBorder = Color3.fromRGB(128, 80, 50),
    },
    AreaSize = {
        BgTop = Color3.fromRGB(38, 64, 82),       -- Dingin Okyanus / Slate Cyan
        BgBottom = Color3.fromRGB(26, 46, 60),
        Border = Color3.fromRGB(85, 140, 180),
        Accent = Color3.fromRGB(130, 215, 255),
        IconBg = Color3.fromRGB(22, 38, 52),
        IconBorder = Color3.fromRGB(60, 102, 132),
    },
    compass = {
        BgTop = Color3.fromRGB(36, 58, 76),       -- Okyanus Pusulası Mavisi
        BgBottom = Color3.fromRGB(24, 40, 54),
        Border = Color3.fromRGB(80, 145, 195),
        Accent = Color3.fromRGB(120, 220, 255),
        IconBg = Color3.fromRGB(20, 34, 46),
        IconBorder = Color3.fromRGB(60, 110, 150),
    },
    piggy_bank = {
        BgTop = Color3.fromRGB(76, 52, 60),       -- Pembe-Altın Kumbara
        BgBottom = Color3.fromRGB(52, 34, 42),
        Border = Color3.fromRGB(185, 115, 135),
        Accent = Color3.fromRGB(255, 180, 200),
        IconBg = Color3.fromRGB(44, 28, 36),
        IconBorder = Color3.fromRGB(135, 80, 95),
    },
    ProjectileCount = {
        BgTop = Color3.fromRGB(78, 62, 38),       -- Bronz / Sıcak Pirinç
        BgBottom = Color3.fromRGB(52, 42, 26),
        Border = Color3.fromRGB(175, 142, 85),
        Accent = Color3.fromRGB(255, 215, 120),
        IconBg = Color3.fromRGB(46, 36, 22),
        IconBorder = Color3.fromRGB(125, 100, 60),
    },
    Luck = {
        BgTop = Color3.fromRGB(34, 76, 52),       -- Dört Yapraklı Yonca Yeşili / Mint Emerald
        BgBottom = Color3.fromRGB(22, 50, 34),
        Border = Color3.fromRGB(75, 175, 115),
        Accent = Color3.fromRGB(115, 255, 170),
        IconBg = Color3.fromRGB(18, 44, 30),
        IconBorder = Color3.fromRGB(55, 125, 85),
    },
    XPBoost = {
        BgTop = Color3.fromRGB(40, 58, 84),       -- Bilge Kristal Mavisi / Deep Azure
        BgBottom = Color3.fromRGB(26, 38, 56),
        Border = Color3.fromRGB(90, 135, 195),
        Accent = Color3.fromRGB(140, 205, 255),
        IconBg = Color3.fromRGB(24, 34, 50),
        IconBorder = Color3.fromRGB(65, 95, 140),
    },
}

local defaultTheme = {
    BgTop = Color3.fromRGB(64, 56, 46),
    BgBottom = Color3.fromRGB(46, 40, 32),
    Border = Color3.fromRGB(145, 128, 100),
    Accent = Color3.fromRGB(240, 210, 135),
    IconBg = Color3.fromRGB(38, 32, 26),
    IconBorder = Color3.fromRGB(105, 92, 72),
}

-- Bildirim Kuyruğu (Üst üste binen kilit açılışlarını sırayla göstermek için)
local notificationQueue = {}
local isProcessingQueue = false

local function showUnlockNotification(upgradeKey)
    local quest = ProgressionManager.GetQuest(upgradeKey)
    local item = UpgradeConfig.Upgrades[upgradeKey] or ItemConfig.Items[upgradeKey]
    if not quest or not item then return end
    
    local theme = cardThemeMap[upgradeKey] or defaultTheme
    
    -- ScreenGui Oluştur
    local notificationGui = Instance.new("ScreenGui")
    notificationGui.Name = "QuestUnlockNotification"
    notificationGui.ResetOnSpawn = false
    notificationGui.DisplayOrder = 999
    notificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    notificationGui.Parent = PlayerGui

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = notificationGui
    local function updateScale()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local scale = math.min(viewport.X / 1600, viewport.Y / 900)
        uiScale.Scale = math.clamp(scale, 0.55, 1.8)
    end
    local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    updateScale()

    notificationGui.Destroying:Connect(function()
        if viewportConnection then
            viewportConnection:Disconnect()
            viewportConnection = nil
        end
    end)
    
    -- Ses Efekti
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9114223126"
    sound.Volume = 0.8
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 3)
    
    -- Panel Boyutları (430x118)
    local panelHeight = 118
    local panelWidth = 430
    local hiddenPosition = UDim2.new(0, -panelWidth - 70, 1, -panelHeight - 85)
    local targetPosition = UDim2.new(0, 24, 1, -panelHeight - 85)

    -- Ana Panel (Siyah yerine karta özel hafif açık renkli zemin)
    local panel = Instance.new("Frame")
    panel.Name = "NotificationPanel"
    panel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
    panel.Position = hiddenPosition
    panel.BackgroundColor3 = theme.BgTop
    panel.BackgroundTransparency = 0.04
    panel.BorderSizePixel = 0
    panel.ZIndex = 1000
    panel.Parent = notificationGui
    
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 14)
    panelCorner.Parent = panel

    -- Karta Özel Yumuşak Ton Geçişi (Üstten alta hafif koyulaşma)
    local panelGradient = Instance.new("UIGradient")
    panelGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.BgTop),
        ColorSequenceKeypoint.new(1, theme.BgBottom)
    })
    panelGradient.Rotation = 90
    panelGradient.Parent = panel

    -- Karta Uyumlu Zarif Kenarlık
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = theme.Border
    panelStroke.Thickness = 1.4
    panelStroke.Transparency = 0.25
    panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    panelStroke.Parent = panel

    -- Sol Kenar Dikey Vurgu Şeridi
    local leftAccentBar = Instance.new("Frame")
    leftAccentBar.Name = "LeftAccentBar"
    leftAccentBar.Size = UDim2.new(0, 4, 0, 76)
    leftAccentBar.Position = UDim2.new(0, 7, 0.5, -3)
    leftAccentBar.AnchorPoint = Vector2.new(0, 0.5)
    leftAccentBar.BackgroundColor3 = theme.Accent
    leftAccentBar.BackgroundTransparency = 0.1
    leftAccentBar.BorderSizePixel = 0
    leftAccentBar.ZIndex = 1001
    leftAccentBar.Parent = panel

    local leftAccentCorner = Instance.new("UICorner")
    leftAccentCorner.CornerRadius = UDim.new(1, 0)
    leftAccentCorner.Parent = leftAccentBar

    -- İkon Çerçevesi (Merkezden ölçeklenen ve metni asla itmeyen tasarım)
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.Size = UDim2.new(0, 60, 0, 60)
    iconFrame.Position = UDim2.new(0, 52, 0.5, -3)
    iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    iconFrame.BackgroundColor3 = theme.IconBg
    iconFrame.BackgroundTransparency = 0.05
    iconFrame.BorderSizePixel = 0
    iconFrame.ZIndex = 1002
    iconFrame.Parent = panel

    local iconScale = Instance.new("UIScale")
    iconScale.Scale = 0.65
    iconScale.Parent = iconFrame

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 12)
    iconCorner.Parent = iconFrame

    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = theme.IconBorder
    iconStroke.Thickness = 1.2
    iconStroke.Transparency = 0.2
    iconStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    iconStroke.Parent = iconFrame

    -- İkon Görseli
    local scaleMult = item.IconScale or 1.0
    local icon = Instance.new("ImageLabel")
    icon.Name = "IconImage"
    icon.Size = UDim2.new(0.82 * scaleMult, 0, 0.82 * scaleMult, 0)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Image = item.Icon or ""
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 1003
    icon.Parent = iconFrame

    -- Metin Konteyneri (İkonun sağında net ve orantılı alan)
    local textFrame = Instance.new("Frame")
    textFrame.Name = "TextFrame"
    textFrame.Size = UDim2.new(1, -114, 0, 94)
    textFrame.Position = UDim2.new(0, 98, 0.5, -3)
    textFrame.AnchorPoint = Vector2.new(0, 0.5)
    textFrame.BackgroundTransparency = 1
    textFrame.ZIndex = 1002
    textFrame.Parent = panel

    local textLayout = Instance.new("UIListLayout")
    textLayout.SortOrder = Enum.SortOrder.LayoutOrder
    textLayout.FillDirection = Enum.FillDirection.Vertical
    textLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    textLayout.Padding = UDim.new(0, 2)
    textLayout.Parent = textFrame

    -- Üst Rozet / Kategori Başlığı (Kutu/glitch yapmayan temiz metin)
    local categoryText = "QUEST COMPLETED!"
    if item.Type == "Weapon" then
        categoryText = "NEW WEAPON READY TO UNLOCK"
    elseif item.Type == "Perk" then
        categoryText = "NEW PERK READY TO UNLOCK"
    else
        categoryText = "NEW ITEM READY TO UNLOCK"
    end

    local badgeLabel = Instance.new("TextLabel")
    badgeLabel.Name = "BadgeLabel"
    badgeLabel.LayoutOrder = 1
    badgeLabel.Size = UDim2.new(1, 0, 0, 14)
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.Font = Enum.Font.GothamBold
    badgeLabel.Text = categoryText
    badgeLabel.TextColor3 = theme.Accent
    badgeLabel.TextSize = 11
    badgeLabel.TextXAlignment = Enum.TextXAlignment.Left
    badgeLabel.TextYAlignment = Enum.TextYAlignment.Center
    badgeLabel.ZIndex = 1003
    badgeLabel.Parent = textFrame

    -- Özellik / Silah Adı (Net Beyaz Başlık)
    local itemNameLabel = Instance.new("TextLabel")
    itemNameLabel.Name = "ItemNameLabel"
    itemNameLabel.LayoutOrder = 2
    itemNameLabel.Size = UDim2.new(1, 0, 0, 20)
    itemNameLabel.BackgroundTransparency = 1
    itemNameLabel.Font = Enum.Font.Arcade
    itemNameLabel.Text = item.DisplayName or item.Title or upgradeKey
    itemNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemNameLabel.TextSize = 18
    itemNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    itemNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemNameLabel.TextYAlignment = Enum.TextYAlignment.Center
    itemNameLabel.ZIndex = 1003
    itemNameLabel.Parent = textFrame

    -- Açıklama Metni: Kartın ne işe yaradığı
    local itemDesc = item.Description or ""
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "DescriptionLabel"
    descLabel.LayoutOrder = 3
    descLabel.Size = UDim2.new(1, 0, 0, 0)
    descLabel.AutomaticSize = Enum.AutomaticSize.Y
    descLabel.BackgroundTransparency = 1
    descLabel.Font = Enum.Font.GothamMedium
    descLabel.Text = itemDesc
    descLabel.TextColor3 = Color3.fromRGB(235, 240, 248)
    descLabel.TextSize = 12
    descLabel.TextWrapped = true
    descLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.LineHeight = 1.15
    descLabel.Visible = (itemDesc ~= "")
    descLabel.ZIndex = 1003
    descLabel.Parent = textFrame

    -- Kilit Açma Görevi Metni: Nasıl açıldığı (Daha küçük ve soluk)
    local cost = quest and quest.UnlockCost or 25
    local howUnlockedLabel = Instance.new("TextLabel")
    howUnlockedLabel.Name = "HowUnlockedLabel"
    howUnlockedLabel.LayoutOrder = 4
    howUnlockedLabel.Size = UDim2.new(1, 0, 0, 0)
    howUnlockedLabel.AutomaticSize = Enum.AutomaticSize.Y
    howUnlockedLabel.BackgroundTransparency = 1
    howUnlockedLabel.Font = Enum.Font.GothamMedium
    howUnlockedLabel.TextColor3 = Color3.fromRGB(255, 215, 120)
    howUnlockedLabel.TextTransparency = 0.1
    howUnlockedLabel.TextSize = 11
    howUnlockedLabel.TextWrapped = true
    howUnlockedLabel.TextTruncate = Enum.TextTruncate.AtEnd
    howUnlockedLabel.TextXAlignment = Enum.TextXAlignment.Left
    howUnlockedLabel.TextYAlignment = Enum.TextYAlignment.Top
    howUnlockedLabel.LineHeight = 1.15
    howUnlockedLabel.ZIndex = 1003
    howUnlockedLabel.Text = string.format("Unlock in Index with %d Silver!", cost)
    howUnlockedLabel.Visible = true
    howUnlockedLabel.Parent = textFrame

    -- Alt Süre / Zamanlayıcı Çubuğu
    local timerTrack = Instance.new("Frame")
    timerTrack.Name = "TimerTrack"
    timerTrack.Size = UDim2.new(1, -32, 0, 3)
    timerTrack.Position = UDim2.new(0, 16, 1, -8)
    timerTrack.BackgroundColor3 = theme.IconBg
    timerTrack.BackgroundTransparency = 0.3
    timerTrack.BorderSizePixel = 0
    timerTrack.ClipsDescendants = true
    timerTrack.ZIndex = 1002
    timerTrack.Parent = panel

    local timerTrackCorner = Instance.new("UICorner")
    timerTrackCorner.CornerRadius = UDim.new(1, 0)
    timerTrackCorner.Parent = timerTrack

    local timerFill = Instance.new("Frame")
    timerFill.Name = "TimerFill"
    timerFill.Size = UDim2.new(1, 0, 1, 0)
    timerFill.Position = UDim2.new(0, 0, 0, 0)
    timerFill.BackgroundColor3 = theme.Accent
    timerFill.BackgroundTransparency = 0.1
    timerFill.BorderSizePixel = 0
    timerFill.ZIndex = 1003
    timerFill.Parent = timerTrack

    local timerFillCorner = Instance.new("UICorner")
    timerFillCorner.CornerRadius = UDim.new(1, 0)
    timerFillCorner.Parent = timerFill

    -- Animasyon 1: Soldan Yaylı Giriş
    local introTween = TweenService:Create(panel, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = targetPosition
    })
    local iconPunchTween = TweenService:Create(iconScale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = 1.0
    })
    
    introTween:Play()
    iconPunchTween:Play()

    -- Süre Çubuğu Animasyonu (Giriş tamamlanınca 3.8 saniyede küçülür)
    introTween.Completed:Wait()
    
    local timerTween = TweenService:Create(timerFill, TweenInfo.new(3.8, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 1, 0)
    })
    timerTween:Play()
    timerTween.Completed:Wait()

    -- Animasyon 2: Sola Doğru Akıcı Çıkış
    local outroTween = TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = hiddenPosition
    })
    outroTween:Play()
    outroTween.Completed:Wait()

    notificationGui:Destroy()
end

local function processQueue()
    if isProcessingQueue or #notificationQueue == 0 then return end
    isProcessingQueue = true

    while #notificationQueue > 0 do
        local nextKey = table.remove(notificationQueue, 1)
        showUnlockNotification(nextKey)
        task.wait(0.2)
    end

    isProcessingQueue = false
end

QuestUnlocked.OnClientEvent:Connect(function(upgradeKey)
    table.insert(notificationQueue, upgradeKey)
    processQueue()
end)

-- ============================================================
-- TEST KOMUTU: /unlock [isteğe bağlı özellik adı]
-- ============================================================
local lastTestTime = 0
local function triggerTestUnlock(arg)
    local now = os.clock()
    if now - lastTestTime < 0.4 then return end
    lastTestTime = now

    local questKeys = {}
    for k in pairs(ProgressionManager.Quests) do
        table.insert(questKeys, k)
    end
    table.sort(questKeys)

    local chosenKey = nil
    if arg and type(arg) == "string" and string.gsub(arg, "%s+", "") ~= "" then
        local clean = string.lower(string.gsub(arg, "%s+", ""))
        for _, k in ipairs(questKeys) do
            local q = ProgressionManager.GetQuest(k)
            local item = UpgradeConfig.Upgrades[k]
            if string.lower(k) == clean
                or (q and string.find(string.lower(q.Title), clean, 1, true))
                or (item and string.find(string.lower(item.Title), clean, 1, true)) then
                chosenKey = k
                break
            end
        end
    end

    if not chosenKey and #questKeys > 0 then
        chosenKey = questKeys[math.random(1, #questKeys)]
    end

    if chosenKey then
        table.insert(notificationQueue, chosenKey)
        processQueue()
    end
end

local function handleChatMessage(msg)
    if not msg then return end
    local trimmed = string.match(msg, "^%s*(.-)%s*$") or msg
    local lower = string.lower(trimmed)
    if lower == "/unlock" then
        triggerTestUnlock()
    elseif string.sub(lower, 1, 8) == "/unlock " then
        local param = string.sub(trimmed, 9)
        triggerTestUnlock(param)
    end
end

Player.Chatted:Connect(handleChatMessage)

-- Modern Roblox TextChatService desteği
pcall(function()
    local TextChatService = game:GetService("TextChatService")
    local textCommands = TextChatService:FindFirstChild("TextChatCommands")
    if textCommands then
        local unlockCommand = textCommands:FindFirstChild("UnlockTestCommand") or Instance.new("TextChatCommand")
        unlockCommand.Name = "UnlockTestCommand"
        unlockCommand.PrimaryAlias = "/unlock"
        unlockCommand.SecondaryAlias = "/testunlock"
        unlockCommand.Parent = textCommands
        unlockCommand.Triggered:Connect(function(_, rawText)
            local parts = string.split(rawText or "", " ")
            local param = parts[2]
            triggerTestUnlock(param)
        end)
    end
end)
