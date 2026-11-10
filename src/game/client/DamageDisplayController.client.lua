local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Events = ReplicatedStorage:WaitForChild("Events")
local ShowDamageEvent = Events:WaitForChild("ShowDamage")

-- ============================================================
-- HIGH-PERFORMANCE DAMAGE NUMBER OBJECT POOL
-- Bellek sızıntısı ve Garbage Collection takılmalarını sıfırlamak
-- için her vuruşta yeni Part/UI üretilmez; havuzdaki nesneler yeniden kullanılır.
-- ============================================================
local POOL_SIZE = 36
local pool = {}
local activeIndex = 0

local tweenInfoMove = TweenInfo.new(0.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local tweenInfoFade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

for i = 1, POOL_SIZE do
    local attachment = Instance.new("Attachment")
    attachment.Name = "DamageNumberAttachment_" .. i
    attachment.Parent = Workspace.Terrain

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DamageBillboard"
    billboard.Size = UDim2.new(0, 110, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    billboard.StudsOffset = Vector3.zero
    billboard.Parent = attachment

    local label = Instance.new("TextLabel")
    label.Name = "DamageLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Arcade
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = billboard

    pool[i] = {
        Attachment = attachment,
        Billboard = billboard,
        Label = label,
        InUse = false,
        Token = 0,
    }
end

local function getNextSlot()
    -- Boşta olan ilk slotu ara
    for i = 1, POOL_SIZE do
        if not pool[i].InUse then
            return pool[i]
        end
    end
    -- Havuz tamamen doluysa en eski kullanılan slotu geri dönüştür (LRU)
    activeIndex = (activeIndex % POOL_SIZE) + 1
    return pool[activeIndex]
end

local function showDamage(pos, amount, isCrit)
    local slot = getNextSlot()
    slot.InUse = true
    slot.Token = slot.Token + 1
    local currentToken = slot.Token

    local rndOffset = Vector3.new(
        (math.random() - 0.5) * 1.6,
        math.random() * 0.8,
        (math.random() - 0.5) * 1.6
    )
    slot.Attachment.WorldPosition = pos + rndOffset

    -- Görünüm ve Kritik Ayarları
    local label = slot.Label
    label.Text = string.format("%.0f", amount) .. (isCrit and "!" or "")
    label.TextTransparency = 0
    label.TextStrokeTransparency = 0

    if isCrit then
        label.TextColor3 = Color3.fromRGB(255, 50, 50) -- Kritik: Parlak Kırmızı
        label.TextSize = 28
    else
        label.TextColor3 = Color3.fromRGB(255, 255, 255) -- Normal: Beyaz
        label.TextSize = 18
    end

    local billboard = slot.Billboard
    billboard.StudsOffset = Vector3.zero
    billboard.Enabled = true

    -- Yukarı doğru akış animasyonu
    local moveTween = TweenService:Create(billboard, tweenInfoMove, { StudsOffset = Vector3.new(0, 2.8, 0) })
    moveTween:Play()

    -- 0.4 saniye sonra şeffaflaşma
    task.delay(0.4, function()
        if slot.Token ~= currentToken then return end
        local fadeTween = TweenService:Create(label, tweenInfoFade, {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        })
        fadeTween:Play()
    end)

    -- Animasyon tamamlandığında havuz yuvasını serbest bırak
    task.delay(0.75, function()
        if slot.Token ~= currentToken then return end
        billboard.Enabled = false
        billboard.StudsOffset = Vector3.zero
        slot.InUse = false
    end)
end

ShowDamageEvent.OnClientEvent:Connect(function(pos, amount, isCrit)
    showDamage(pos, amount, isCrit)
end)
