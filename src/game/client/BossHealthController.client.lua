local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local enemiesFolder = workspace:WaitForChild("Enemies")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- UI Visual Constants (1. Görseldeki Retro/Arcade Boss Barı Tasarımı)
local BAR_HEIGHT = 18 -- Can barı yüksekliği
local NAME_HEIGHT = 20 -- Boss ismi yüksekliği
local CARD_GAP = 3 -- İsim ile bar arasındaki dikey boşluk
local TOTAL_CARD_HEIGHT = NAME_HEIGHT + CARD_GAP + BAR_HEIGHT -- 41px

local BAR_COLOR = Color3.fromRGB(225, 20, 20) -- 1. görseldeki katı, parlak kırmızı
local TRACK_BG_COLOR = Color3.fromRGB(0, 0, 0) -- 1. görseldeki saf siyah zemin (#000000)
local BORDER_COLOR = Color3.fromRGB(20, 20, 20) -- Net, ince dış siyah çerçeve

-- Sayı formatlayıcı: 1. görseldeki gibi 2.7M / 6.3M veya 273 / 273 (yüzdelik yazılmaz)
local function formatHP(num)
    num = math.max(0, math.floor(num))
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 10000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

-- Boss ismi formatlayıcı: "MegaZombie" -> "Mega Zombie", "Juge Anubis" -> "Juge Anubis"
local function formatBossName(rawName)
    if not rawName or rawName == "" then return "Boss" end
    local spaced = rawName:gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
    spaced = spaced:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return spaced
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BossHealthGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = true
screenGui.DisplayOrder = 50
screenGui.Parent = playerGui

-- Create Outer Container for Boss Health Bars (Ekranın üst-orta kısmı)
local container = Instance.new("Frame")
container.Name = "BossContainer"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0.022, 0)
container.Size = UDim2.new(0.55, 0, 0, TOTAL_CARD_HEIGHT)
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.ClipsDescendants = false
container.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
local gap = 12
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, gap)
listLayout.Parent = container

local activeBossList = {} -- Sıralı boss listesi
local activeBossCards = {} -- Map: bossInstance -> { Card, Connection, Destroying, UpdateHP }

-- Boss barlarını 1, 2 veya 3 boss için yan yana dinamik boyutlandıran fonksiyon
local function relayoutBossBars()
    local totalActive = #activeBossList
    if totalActive == 0 then
        container.Visible = false
        return
    end
    container.Visible = true

    local visibleCount = math.clamp(totalActive, 1, 3)
    local targetContainerWidth
    local targetCardWidth

    if visibleCount == 1 then
        targetContainerWidth = 0.55
        targetCardWidth = UDim2.new(1, 0, 1, 0)
        listLayout.Padding = UDim.new(0, 0)
    elseif visibleCount == 2 then
        targetContainerWidth = 0.75
        targetCardWidth = UDim2.new(0.5, -math.floor(gap / 2), 1, 0)
        listLayout.Padding = UDim.new(0, gap)
    else -- 3 veya daha fazla (yan yana en fazla 3 tane)
        targetContainerWidth = 0.90
        targetCardWidth = UDim2.new(1 / 3, -math.floor(gap * 2 / 3), 1, 0)
        listLayout.Padding = UDim.new(0, gap)
    end

    TweenService:Create(container, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(targetContainerWidth, 0, 0, TOTAL_CARD_HEIGHT)
    }):Play()

    for idx, boss in ipairs(activeBossList) do
        local entry = activeBossCards[boss]
        if entry and entry.Card and entry.Card.Parent and not entry.Destroying then
            entry.Card.LayoutOrder = idx
            if idx <= 3 then
                entry.Card.Visible = true
                TweenService:Create(entry.Card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = targetCardWidth
                }):Play()
            else
                entry.Card.Visible = false
            end
            if entry.UpdateHP then
                entry.UpdateHP()
            end
        end
    end
end

local function createBossCard(boss)
    if activeBossCards[boss] then return end
    
    local enemyType = boss:GetAttribute("EnemyType") or "Boss"
    local formattedName = formatBossName(enemyType)
    
    -- Kart Taşıyıcısı (Üstte Boss İsmi, Altta Can Barı)
    local card = Instance.new("Frame")
    card.Name = "BossCard_" .. boss.Name
    card.Size = UDim2.new(0, 0, 1, 0)
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.ClipsDescendants = false
    card.Parent = container

    -- 1. Boss İsmi (Üstte, ortalanmış, beyaz yazı & siyah kontur)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "BossName"
    nameLabel.AnchorPoint = Vector2.new(0.5, 0)
    nameLabel.Position = UDim2.new(0.5, 0, 0, 0)
    nameLabel.Size = UDim2.new(1, 0, 0, NAME_HEIGHT)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.Arcade
    nameLabel.Text = formattedName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextSize = 16
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
    nameLabel.ZIndex = 5
    nameLabel.Parent = card

    -- 2. Can Barı Yolu (Altta, saf siyah zemin, keskin dikdörtgen hatlar)
    local barTrack = Instance.new("Frame")
    barTrack.Name = "BarTrack"
    barTrack.AnchorPoint = Vector2.new(0.5, 1)
    barTrack.Position = UDim2.new(0.5, 0, 1, 0)
    barTrack.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
    barTrack.BackgroundColor3 = TRACK_BG_COLOR
    barTrack.BackgroundTransparency = 0
    barTrack.BorderSizePixel = 0
    barTrack.ClipsDescendants = true
    barTrack.Parent = card

    local trackStroke = Instance.new("UIStroke")
    trackStroke.Color = BORDER_COLOR
    trackStroke.Thickness = 1.5
    trackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    trackStroke.LineJoinMode = Enum.LineJoinMode.Miter
    trackStroke.Parent = barTrack

    -- 3. Kırmızı Ana Dolgu Barı (Katı kırmızı dolgu, karartılmış gölgeli alan eklenmez)
    local fillBar = Instance.new("Frame")
    fillBar.Name = "FillBar"
    fillBar.AnchorPoint = Vector2.new(0, 0.5)
    fillBar.Position = UDim2.new(0, 0, 0.5, 0)
    fillBar.Size = UDim2.new(1, 0, 1, 0)
    fillBar.BackgroundColor3 = BAR_COLOR
    fillBar.BorderSizePixel = 0
    fillBar.ZIndex = 2
    fillBar.Parent = barTrack

    -- 4. Kalan Can Yazısı (Can barının tam ortasında, yüzdelik yok: örn. 273 / 273 veya 2.7M / 6.3M)
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Name = "HealthText"
    hpLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    hpLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    hpLabel.Size = UDim2.new(1, 0, 1, 0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.Font = Enum.Font.Arcade
    hpLabel.Text = ""
    hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    hpLabel.TextStrokeTransparency = 0
    hpLabel.TextSize = 13
    hpLabel.TextXAlignment = Enum.TextXAlignment.Center
    hpLabel.TextYAlignment = Enum.TextYAlignment.Center
    hpLabel.ZIndex = 5
    hpLabel.Parent = barTrack

    local function updateCardHP()
        if not boss or not boss.Parent then return end
        local healthVal = boss:FindFirstChild("Health")
        local maxHealth = boss:GetAttribute("MaxHealth") or 100
        if not healthVal then return end
        
        local currentHealth = math.max(0, healthVal.Value)
        local percent = math.clamp(currentHealth / maxHealth, 0, 1)
        
        -- Can tam ortada yazıyor, yüzdelik yok
        hpLabel.Text = formatHP(currentHealth) .. " / " .. formatHP(maxHealth)
        
        local targetSize = UDim2.new(percent, 0, 1, 0)
        TweenService:Create(fillBar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = targetSize
        }):Play()
    end

    local healthVal = boss:WaitForChild("Health", 5)
    local conn = nil
    if healthVal then
        conn = healthVal.Changed:Connect(updateCardHP)
    end
    updateCardHP()

    activeBossCards[boss] = {
        Card = card,
        Connection = conn,
        Destroying = false,
        UpdateHP = updateCardHP
    }
    table.insert(activeBossList, boss)
    relayoutBossBars()
end

local function removeBossCard(boss)
    local entry = activeBossCards[boss]
    if not entry or entry.Destroying then return end
    entry.Destroying = true
    
    if entry.Connection then
        entry.Connection:Disconnect()
    end

    for idx, b in ipairs(activeBossList) do
        if b == boss then
            table.remove(activeBossList, idx)
            break
        end
    end

    relayoutBossBars()
    
    local card = entry.Card
    if card and card.Parent then
        local tween = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 1, 0)
        })
        tween:Play()
        tween.Completed:Connect(function()
            card:Destroy()
        end)
    end
    
    activeBossCards[boss] = nil
end

local function checkBoss(child)
    if child:GetAttribute("IsBoss") == true then
        createBossCard(child)
    end
end

for _, child in ipairs(enemiesFolder:GetChildren()) do
    checkBoss(child)
end

enemiesFolder.ChildAdded:Connect(checkBoss)

enemiesFolder.ChildRemoved:Connect(function(child)
    removeBossCard(child)
end)

RunService.Heartbeat:Connect(function()
    for boss, entry in pairs(activeBossCards) do
        if not boss or not boss.Parent or boss.Parent ~= enemiesFolder then
            removeBossCard(boss)
        end
    end
end)
