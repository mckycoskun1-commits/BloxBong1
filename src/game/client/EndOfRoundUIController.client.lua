-- ============================================================
--  EndOfRoundUIController  |  LocalScript
-- ============================================================

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer  = Players.LocalPlayer

local Config        = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local ItemConfig    = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))
local WaveConfig    = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WaveConfig"))
local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))

local Events = ReplicatedStorage:WaitForChild("Events")
local ShowGameOverEvent = Events:WaitForChild("ShowGameOver")

-- ============================================================
--  YAZI STİLİ VE TASARIM SİSTEMİ
-- ============================================================
local FONT_TITLE = Enum.Font.Arcade
local FONT_BODY = Enum.Font.GothamBold

local C = {
    BG          = Color3.fromRGB(18, 22, 28),        -- ana arkaplan (koyu mavi-gri / obsidian)
    PanelDark   = Color3.fromRGB(12, 14, 18),        -- panel iç (koyu obsidian)
    PanelMid    = Color3.fromRGB(28, 34, 44),        -- başlık şeridi (koyu slate blue)
    PanelLight  = Color3.fromRGB(36, 44, 56),        -- hover / slot
    Border      = Color3.fromRGB(160, 170, 185),     -- çerçeve platin / cool gümüş
    BorderInner = Color3.fromRGB(75, 85, 100),       -- iç çerçeve çelik mavi
    Accent      = Color3.fromRGB(230, 235, 245),     -- vurgu platin beyazı
    AccentDim   = Color3.fromRGB(130, 140, 155),     -- soluk çelik
    TextHigh    = Color3.fromRGB(255, 255, 255),     -- birincil yazı (saf beyaz)
    TextMid     = Color3.fromRGB(185, 195, 205),     -- ikincil yazı (gümüş)
    TextLow     = Color3.fromRGB(125, 135, 145),     -- üçüncül yazı (soluk çelik)
    DmgColor    = Color3.fromRGB(235, 90, 100),      -- hasar sayısı (koyu gül rengi)
    DmgBg       = Color3.fromRGB(36, 18, 22),        -- hasar arka
    DmgBorder   = Color3.fromRGB(120, 65, 75),       -- hasar çerçeve
    GreenTint   = Color3.fromRGB(200, 210, 225),     -- envanter başlık platin
    BlueTint    = Color3.fromRGB(175, 195, 220),     -- kilit başlık çelik mavi
    BtnBg       = Color3.fromRGB(34, 42, 54),        -- buton arkaplan
    BtnHover    = Color3.fromRGB(48, 60, 78),        -- buton hover
    BtnText     = Color3.fromRGB(235, 240, 248),     -- buton yazı
    Overlay     = Color3.fromRGB(0, 0, 0),
}

-- ============================================================
--  YARDIMCI FONKSİYONLAR
-- ============================================================
local function formatNumber(n)
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
        if k == 0 then
            break
        end
    end
    return formatted
end

local function Frame(parent, props)
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    for k,v in pairs(props) do f[k] = v end
    f.Parent = parent
    return f
end

local function Label(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Font = FONT_BODY
    l.TextColor3 = C.TextHigh
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    for k,v in pairs(props) do l[k] = v end
    l.Parent = parent
    return l
end

local function Image(parent, props)
    local i = Instance.new("ImageLabel")
    i.BackgroundTransparency = 1
    i.BorderSizePixel = 0
    i.ScaleType = Enum.ScaleType.Fit
    for k,v in pairs(props) do i[k] = v end
    i.Parent = parent
    return i
end

local function Stroke(parent, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Border
    s.Thickness = thick or 1.5
    s.Transparency = trans or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

-- Retro/Arcade Köşe Braketleri (L-şeklinde destekler)
local function CornerBrackets(frame, color, size, thickness)
    size = size or 8
    thickness = thickness or 2
    color = color or C.Border
    
    -- Top-Left (┌)
    Frame(frame, {
        Position = UDim2.new(0, -thickness, 0, -thickness),
        Size = UDim2.new(0, size, 0, thickness),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        ZIndex = frame.ZIndex + 4,
    })
    Frame(frame, {
        Position = UDim2.new(0, -thickness, 0, -thickness),
        Size = UDim2.new(0, thickness, 0, size),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        ZIndex = frame.ZIndex + 4,
    })

    -- Top-Right (┐)
    Frame(frame, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, thickness, 0, -thickness),
        Size = UDim2.new(0, size, 0, thickness),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        ZIndex = frame.ZIndex + 4,
    })
    Frame(frame, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, thickness, 0, -thickness),
        Size = UDim2.new(0, thickness, 0, size),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        ZIndex = frame.ZIndex + 4,
    })

    -- Bottom-Left (└)
    Frame(frame, {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, -thickness, 1, thickness),
        Size = UDim2.new(0, size, 0, thickness),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        ZIndex = frame.ZIndex + 4,
    })
    Frame(frame, {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, -thickness, 1, thickness),
        Size = UDim2.new(0, thickness, 0, size),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        ZIndex = frame.ZIndex + 4,
    })

    -- Bottom-Right (┘)
    Frame(frame, {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, thickness, 1, thickness),
        Size = UDim2.new(0, size, 0, thickness),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        ZIndex = frame.ZIndex + 4,
    })
    Frame(frame, {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, thickness, 1, thickness),
        Size = UDim2.new(0, thickness, 0, size),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        ZIndex = frame.ZIndex + 4,
    })
end

-- Yatay ayırıcı çizgi
local function Divider(parent, yPx, xPad, color, alpha)
    local d = Frame(parent, {
        Position = UDim2.new(0, xPad or 10, 0, yPx),
        Size     = UDim2.new(1, -(xPad or 10)*2, 0, 1),
        BackgroundColor3 = color or C.Border,
        BackgroundTransparency = alpha or 0.45,
    })
    return d
end

-- ============================================================
--  GUI KÖK (TÜM EKRANI KAPLAYACAK ŞEKİLDE)
-- ============================================================
local Gui = Instance.new("ScreenGui")
Gui.Name           = "EndOfRoundUI"
Gui.ResetOnSpawn   = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset = true
Gui.Enabled        = false
Gui.Parent         = LocalPlayer:WaitForChild("PlayerGui")

-- Karartma overlay
local Overlay = Frame(Gui, {
    Size = UDim2.new(1,0,1,0),
    BackgroundColor3 = C.Overlay,
    BackgroundTransparency = 0,
    ZIndex = 1,
})

-- ============================================================
--  ANA EKRAN KAPSAYICI (KENAR BOŞLUKLU RETRO - GÖRSEL 1 LİMİTİ)
-- ============================================================
local Root = Frame(Gui, {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position    = UDim2.new(0.5, 0, 0.5, 0),
    Size        = UDim2.new(0.95, -40, 0.9, -40), -- Ekran kenarlarında hafif siyah boşluk bırakır
    BackgroundColor3 = C.BG,
    BackgroundTransparency = 0,
    ZIndex = 2,
})

-- İnce iç çerçeve efekti
local InnerBorder = Frame(Root, {
    Position = UDim2.new(0,6,0,6),
    Size     = UDim2.new(1,-12,1,-12),
    BackgroundTransparency = 1,
    ZIndex = 2,
})
Stroke(InnerBorder, C.BorderInner, 1.5, 0.4)

-- ============================================================
--  DİNAMİK PANELLER YERLEŞİMİ (3 SÜTUN YAN YANA - TAM YÜKSEKLİK)
-- ============================================================
local PanelsContainer = Frame(Root, {
    Position = UDim2.new(0, 20, 0, 20),
    Size     = UDim2.new(1, -40, 1, -40), -- Üst bar kalktığı için paneller tam yüksekliğe yakın
    ZIndex   = 3,
})

local PanelsLayout = Instance.new("UIListLayout")
PanelsLayout.FillDirection = Enum.FillDirection.Horizontal
PanelsLayout.Padding = UDim.new(0, 16)
PanelsLayout.SortOrder = Enum.SortOrder.LayoutOrder
PanelsLayout.Parent = PanelsContainer

local function MakePanel(parent, titleText, titleColor, layoutOrder, bottomPadding)
    bottomPadding = bottomPadding or 0
    local panel = Frame(parent, {
        Size     = UDim2.new(0.333, -10, 1, 0),
        BackgroundColor3 = C.PanelDark,
        BackgroundTransparency = 0,
        ZIndex = 3,
        LayoutOrder = layoutOrder,
    })
    Stroke(panel, C.Border, 1.5)
    
    local innerLine = Frame(panel, {
        Position = UDim2.new(0, 3, 0, 3),
        Size = UDim2.new(1, -6, 1, -6),
        BackgroundTransparency = 1,
        ZIndex = 3,
    })
    Stroke(innerLine, C.BorderInner, 1, 0.4)
    CornerBrackets(panel, titleColor or C.Accent, 10, 2)

    -- Başlık şeridi
    local tbar = Frame(panel, {
        Size = UDim2.new(1, -6, 0, 32),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = C.PanelMid,
        BackgroundTransparency = 0,
        ZIndex = 4,
    })

    Label(tbar, {
        Text = titleText,
        TextSize = 24,
        Font = FONT_TITLE,
        TextColor3 = titleColor or C.Accent,
        Size = UDim2.new(1,0,1,0),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 5,
    })

    Divider(panel, 35, 3, C.Border, 0.35)

    -- Kaydırılabilir İçerik Alanı
    local content = Instance.new("ScrollingFrame")
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Position = UDim2.new(0,10,0,44)
    content.Size     = UDim2.new(1,-20,1,-54 - bottomPadding)
    content.ScrollBarThickness = 5
    content.ScrollBarImageColor3 = C.BorderInner
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    content.ZIndex   = 4
    content.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 12)
    layout.Parent = content

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)

    return panel, content
end

-- Üç ana panelin oluşturulması (Middle Panel buton için 60px boşluk bırakır)
local _p1, P1 = MakePanel(PanelsContainer, "DAMAGE", C.Accent, 1)
local _p2, P2 = MakePanel(PanelsContainer, "SUMMARY", C.GreenTint, 2, 60)
local _p3, P3 = MakePanel(PanelsContainer, "UNLOCKS", C.BlueTint, 3)

-- ============================================================
--  DİNAMİK ELEMAN ŞABLONLARI
-- ============================================================

-- Hasar Satırı (Görsel 1'deki gibi düz kartlar yerine divider'lı sütun hizalama)
local function WeaponRow(parent, imageId, name, lvl, dmg)
    local row = Frame(parent, {
        Size = UDim2.new(1, 0, 0, 48),
        ZIndex = 5,
    })

    -- Görsel kutusu (Retro)
    local icon = Image(row, {
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 38, 0, 38),
        Image = imageId or "rbxassetid://0",
        ZIndex = 6,
    })

    -- Silah İsmi (Büyük Yazı)
    Label(row, {
        Text = name,
        Font = FONT_BODY,
        TextSize = 16,
        TextColor3 = C.TextHigh,
        Position = UDim2.new(0, 44, 0, 0),
        Size = UDim2.new(0.35, -44, 1, 0),
        ZIndex = 6,
    })

    -- Seviye
    Label(row, {
        Text = tostring(lvl),
        Font = FONT_TITLE,
        TextSize = 19,
        TextColor3 = C.TextMid,
        Position = UDim2.new(0.62, 0, 0, 0),
        Size = UDim2.new(0.15, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 6,
    })

    -- Hasar (Sağda, kutu olmadan düz yazı)
    Label(row, {
        Text = formatNumber(dmg),
        Font = FONT_TITLE,
        TextSize = 26,
        TextColor3 = C.DmgColor,
        Position = UDim2.new(0.8, 0, 0, 0),
        Size = UDim2.new(0.2, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 6,
    })

    Divider(row, 47, 0, C.BorderInner, 0.3)
    return row
end

-- Envanter Izgarası (UIGridLayout ile kutu içine yazılan LVL / x bilgileri)
local function IconGrid(parent, items, isLevel)
    local gridFrame = Frame(parent, {
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 5,
        LayoutOrder = 2,
    })

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 76, 0, 76) -- İkon kutusu boyutu büyütüldü (76x76)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = gridFrame

    for idx, item in ipairs(items) do
        local cell = Frame(gridFrame, {
            Size = UDim2.new(0, 76, 0, 76),
            ZIndex = 6,
            LayoutOrder = idx,
        })

        local slot = Frame(cell, {
            Size     = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = C.PanelMid,
            BackgroundTransparency = 0,
            ZIndex = 6,
        })
        Stroke(slot, C.BorderInner, 1)
        CornerBrackets(slot, C.BorderInner, 5, 1)

        -- Görseli slotun içinde hafif yukarı alalım ki yazıyla çakışmasın
        local itemScale = item.scale or 1.0
        Image(slot, {
            Size   = UDim2.new(itemScale, -20 * itemScale, itemScale, -20 * itemScale),
            Position = UDim2.new(0.5, 0, 0.4, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Image  = item.image or "rbxassetid://0",
            ZIndex = 7,
        })

        -- Seviye veya adet yazısı
        local labelText = ""
        if isLevel then
            labelText = "LVL " .. tostring(item.count)
        else
            labelText = "x" .. tostring(item.count)
        end

        Label(slot, {
            Text = labelText,
            TextSize = 13,
            Font = FONT_TITLE,
            TextColor3 = C.TextMid,
            Position = UDim2.new(0, 0, 1, -18),
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 8,
        })
    end

    gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        gridFrame.Size = UDim2.new(1, 0, 0, gridLayout.AbsoluteContentSize.Y)
    end)
end

-- Envanter Alt Grubu
local function CreateInventoryGroup(parent, titleText, items, isLevel)
    local group = Frame(parent, {
        Size = UDim2.new(1, 0, 0, 30),
        ZIndex = 5,
    })
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = group
    
    Label(group, {
        Text = titleText,
        TextSize = 15,
        Font = FONT_TITLE,
        TextColor3 = C.TextLow,
        Size = UDim2.new(1, 0, 0, 16),
        ZIndex = 6,
        LayoutOrder = 1,
    })
    
    if #items == 0 then
        Label(group, {
            Text = "- Empty -",
            TextSize = 11,
            Font = FONT_BODY,
            TextColor3 = C.TextLow,
            Size = UDim2.new(1, 0, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 6,
            LayoutOrder = 2,
        })
    else
        IconGrid(group, items, isLevel)
    end
    
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        group.Size = UDim2.new(1, 0, 0, listLayout.AbsoluteContentSize.Y + 4)
    end)
    
    return group
end

-- ============================================================
--  RETURN TO LOBBY BUTONU (SUMMARY PANELİ ALTINA SABİTLENİR)
-- ============================================================
local ReturnBtn = Instance.new("TextButton")
ReturnBtn.BackgroundColor3 = C.BtnBg
ReturnBtn.BorderSizePixel  = 0
ReturnBtn.Text             = "RETURN TO LOBBY"
ReturnBtn.TextColor3       = C.BtnText
ReturnBtn.TextSize         = 20
ReturnBtn.Font             = FONT_TITLE
ReturnBtn.ZIndex           = 5
ReturnBtn.AutoButtonColor  = false
ReturnBtn.Parent           = _p2 -- SUMMARY panelinin içine yerleşir
ReturnBtn.AnchorPoint      = Vector2.new(0.5, 1)
ReturnBtn.Position         = UDim2.new(0.5, 0, 1, -10)
ReturnBtn.Size             = UDim2.new(1, -24, 0, 42)

Stroke(ReturnBtn, C.Border, 1.5)
CornerBrackets(ReturnBtn, C.AccentDim, 6, 1.5)

-- Buton süs çizgileri
for _,side in ipairs({{0,8},{1,-8}}) do
    local deco = Frame(ReturnBtn, {
        AnchorPoint = Vector2.new(side[1], 0.5),
        Position = UDim2.new(side[1], side[2], 0.5, 0),
        Size = UDim2.new(0, 24, 0, 1),
        BackgroundColor3 = C.AccentDim,
        BackgroundTransparency = 0.3,
        ZIndex = 6,
    })
end

local function BtnTween(bg, tc)
    TweenService:Create(ReturnBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
        BackgroundColor3 = bg,
        TextColor3 = tc,
    }):Play()
end

ReturnBtn.MouseEnter:Connect(function()
    BtnTween(C.BtnHover, Color3.fromRGB(255, 255, 255))
end)
ReturnBtn.MouseLeave:Connect(function()
    BtnTween(C.BtnBg, C.BtnText)
end)
ReturnBtn.MouseButton1Down:Connect(function()
    TweenService:Create(ReturnBtn, TweenInfo.new(0.08), {
        Size = UDim2.new(1, -30, 0, 40)
    }):Play()
end)
ReturnBtn.MouseButton1Up:Connect(function()
    TweenService:Create(ReturnBtn, TweenInfo.new(0.1), {
        Size = UDim2.new(1, -24, 0, 42)
    }):Play()
end)

ReturnBtn.MouseButton1Click:Connect(function()
    Events.ReturnToLobby:FireServer()
    Gui.Enabled = false
end)

-- ============================================================
--  OYUN SONU EKRANI DİNAMİK DOLUM MANTIĞI
-- ============================================================
local function showEndOfRound(stats)
    stats = stats or {}
    stats.DefeatedEnemies = stats.DefeatedEnemies or {}
    stats.WeaponDamage = stats.WeaponDamage or {}
    stats.MatchUpgrades = stats.MatchUpgrades or {}
    stats.Gold = stats.Gold or 0
    stats.Items = stats.Items or {}

    -- Diğer tüm ekran arayüzlerini gizle
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    for _, child in ipairs(PlayerGui:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name ~= "EndOfRoundUI" and child.Name ~= "BubbleChat" then
            child.Enabled = false
        end
    end

    -- Önceki dinamik elemanları temizle
    for _, child in ipairs(P1:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    for _, child in ipairs(P2:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    for _, child in ipairs(P3:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end

    -- Süreyi hesapla (Maksimum 10:00)
    local gameTimeVal = ReplicatedStorage:FindFirstChild("GameTime")
    local matchDuration = Config.Game and Config.Game.MatchDuration or 600
    local totalSeconds = math.clamp(gameTimeVal and gameTimeVal.Value or 0, 0, matchDuration)
    local mins = math.floor(totalSeconds / 60)
    local secs = totalSeconds % 60
    local timeString = string.format("%02d:%02d", mins, secs)

    -- Defeated enemies count
    local killsCount = 0
    for _, count in pairs(stats.DefeatedEnemies) do
        killsCount = killsCount + count
    end

    -- ============================================================
    --  SUMMARY PANELİ TOP STATS (Görsel 1 Tarzı)
    -- ============================================================
    local summaryHeader = Frame(P2, {
        Size = UDim2.new(1, 0, 0, 90),
        ZIndex = 5,
    })

    -- Kare Avatar
    local avatarFrame = Frame(summaryHeader, {
        Size = UDim2.new(0, 80, 0, 80),
        BackgroundColor3 = C.PanelDark,
        BackgroundTransparency = 0,
        ZIndex = 5,
    })
    Stroke(avatarFrame, C.Border, 1.5)
    CornerBrackets(avatarFrame, C.Border, 6, 1.5)

    Image(avatarFrame, {
        Size   = UDim2.new(1, -6, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        Image  = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
        ZIndex = 6,
    })

    -- Sınıf Adı Etiketi (Avatar Altı)
    local selectedClass = LocalPlayer:GetAttribute("SelectedClass") or "Human"
    Label(avatarFrame, {
        Text = tostring(selectedClass):upper(),
        TextSize = 11,
        Font = FONT_BODY,
        TextColor3 = C.TextLow,
        Position = UDim2.new(0, 0, 1, 4),
        Size = UDim2.new(1, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 6,
    })

    -- Sağ İstatistik Metinleri
    local isVictory = stats.IsVictory or totalSeconds >= matchDuration
    local statsStr
    if isVictory then
        local unlockNote = stats.NewDifficultyUnlocked and ("\n★ " .. stats.NewDifficultyUnlocked .. " DIFFICULTY UNLOCKED!") or ""
        statsStr = string.format(
            "VICTORY (SURVIVED!)%s\nKills: %d | LVL %d | Time: %s",
            unlockNote,
            killsCount,
            LocalPlayer.leaderstats.Level.Value,
            timeString
        )
    else
        statsStr = string.format(
            "Kills: %d\nTime Alive: %s\nLVL %d",
            killsCount,
            timeString,
            LocalPlayer.leaderstats.Level.Value
        )
    end

    Label(summaryHeader, {
        Text = statsStr,
        TextSize = 17,
        Font = FONT_BODY,
        TextColor3 = C.TextHigh,
        Position = UDim2.new(0, 92, 0, 0),
        Size = UDim2.new(1, -225, 1, 0),
        TextYAlignment = Enum.TextYAlignment.Center,
        LineHeight = 1.25,
        ZIndex = 6,
    })

    -- Gümüş Para Rozeti (Sağ Kısım)
    local earnedSilver = stats.EarnedSilver or 0
    local totalSilver = stats.TotalSilver or (LocalPlayer:GetAttribute("Silver") or 0)
    
    local silverBadge = Frame(summaryHeader, {
        Size = UDim2.new(0, 125, 0, 68),
        Position = UDim2.new(1, -125, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C.PanelDark,
        BackgroundTransparency = 0,
        ZIndex = 6,
    })
    Stroke(silverBadge, C.Border, 1.5)
    CornerBrackets(silverBadge, C.Border, 5, 1)

    local silverIcon = Image(silverBadge, {
        Image = "rbxassetid://104534575155839",
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(0, 8, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 7,
    })

    Label(silverBadge, {
        Text = string.format("+%d", earnedSilver),
        Font = FONT_TITLE,
        TextSize = 20,
        TextColor3 = Color3.fromRGB(225, 235, 245), -- Parlak Gümüş Beyazı
        Position = UDim2.new(0, 48, 0, 10),
        Size = UDim2.new(1, -52, 0, 24),
        ZIndex = 7,
    })

    Label(silverBadge, {
        Text = string.format("Total: %d", totalSilver),
        Font = FONT_BODY,
        TextSize = 11,
        TextColor3 = C.TextLow,
        Position = UDim2.new(0, 48, 0, 36),
        Size = UDim2.new(1, -52, 0, 16),
        ZIndex = 7,
    })

    -- Ara Boşluk
    local spacer = Frame(P2, {
        Size = UDim2.new(1, 0, 0, 10),
        ZIndex = 5,
    })

    -- ============================================================

    -- ============================================================
    --  PANEL 1: Weapon Damage Sütun Başlıkları
    -- ============================================================
    local dmgHeader = Frame(P1, {
        Size = UDim2.new(1, 0, 0, 20),
        ZIndex = 5,
    })
    Label(dmgHeader, {
        Text = "SOURCE",
        Font = FONT_TITLE,
        TextSize = 18,
        TextColor3 = C.TextLow,
        Size = UDim2.new(0.6, 0, 1, 0),
        ZIndex = 6,
    })
    Label(dmgHeader, {
        Text = "LVL",
        Font = FONT_TITLE,
        TextSize = 19,
        TextColor3 = C.TextLow,
        Position = UDim2.new(0.62, 0, 0, 0),
        Size = UDim2.new(0.15, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 6,
    })
    Label(dmgHeader, {
        Text = "DMG",
        Font = FONT_TITLE,
        TextSize = 19,
        TextColor3 = C.TextLow,
        Position = UDim2.new(0.8, 0, 0, 0),
        Size = UDim2.new(0.2, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 6,
    })
    Divider(dmgHeader, 19, 0, C.BorderInner, 0.4)

    -- PANEL 1 Doldurma
    local weaponLevels = {}
    local perkLevels = {}
    for _, upgradeKey in ipairs(stats.MatchUpgrades) do
        local base = UpgradeConfig.Upgrades[upgradeKey]
        if base then
            if base.Type == "Weapon" then
                weaponLevels[upgradeKey] = (weaponLevels[upgradeKey] or 0) + 1
            elseif base.Type == "Perk" then
                perkLevels[upgradeKey] = (perkLevels[upgradeKey] or 0) + 1
            end
        end
    end

    for weaponKey in pairs(stats.WeaponDamage) do
        if not weaponLevels[weaponKey] then
            weaponLevels[weaponKey] = 1
        end
    end

    local damageList = {}
    for weaponKey, dmg in pairs(stats.WeaponDamage) do
        local upgradeBase = UpgradeConfig.Upgrades[weaponKey]
        local name = upgradeBase and upgradeBase.Title or weaponKey
        local icon = upgradeBase and upgradeBase.Icon or ""
        local lvl = weaponLevels[weaponKey] or 1
        table.insert(damageList, { Key = weaponKey, Name = name, Damage = dmg, Icon = icon, Level = lvl })
    end
    table.sort(damageList, function(a, b) return a.Damage > b.Damage end)

    if #damageList == 0 then
        Label(P1, {
            Text = "- No Damage -",
            TextSize = 12,
            Font = FONT_BODY,
            TextColor3 = C.TextLow,
            Size = UDim2.new(1,0,0,30),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 5,
        })
    else
        for _, entry in ipairs(damageList) do
            WeaponRow(P1, entry.Icon, entry.Name, entry.Level, entry.Damage)
        end
    end

    -- PANEL 2: Match Inventory Doldurma
    local weaponsInv = {}
    for wKey, lvl in pairs(weaponLevels) do
        local upgradeBase = UpgradeConfig.Upgrades[wKey]
        if upgradeBase then
            table.insert(weaponsInv, { image = upgradeBase.Icon, count = lvl, scale = upgradeBase.IconScale })
        end
    end

    local cardsInv = {}
    for pKey, lvl in pairs(perkLevels) do
        local upgradeBase = UpgradeConfig.Upgrades[pKey]
        if upgradeBase then
            table.insert(cardsInv, { image = upgradeBase.Icon, count = lvl, scale = upgradeBase.IconScale })
        end
    end

    local itemsInv = {}
    for itemKey, count in pairs(stats.Items) do
        if count > 0 then
            local itemInfo = ItemConfig.Items[itemKey]
            if itemInfo then
                table.insert(itemsInv, { image = itemInfo.Icon, count = count, scale = itemInfo.IconScale })
            end
        end
    end

    CreateInventoryGroup(P2, "WEAPONS", weaponsInv, true)
    CreateInventoryGroup(P2, "SCROLLS", cardsInv, true)
    CreateInventoryGroup(P2, "ITEMS COLLECTED", itemsInv, false)

    -- PANEL 3: Quests & Map/Difficulty Unlocks Doldurma
    local newUnlocks = {}

    -- 1. Zorluk / Harita Kilidi Açıldıysa (Örn: Forest (Hard) veya Forest (Normal))
    local unlockedDiff = stats.NewDifficultyUnlocked or LocalPlayer:GetAttribute("NewlyUnlockedDifficulty")
    if unlockedDiff and tostring(unlockedDiff) ~= "" then
        local mapName = stats.MapId or workspace:GetAttribute("MapId") or LocalPlayer:GetAttribute("NewlyUnlockedMap") or "Forest"
        local diffUpper = string.upper(tostring(unlockedDiff))
        local diffDisplay = (diffUpper == "NORMAL" and "Normal") or (diffUpper == "HARD" and "Hard") or diffUpper
        local rewardText = (diffUpper == "HARD" and "2.0x Rewards") or "1.5x Rewards"
        local descText = string.format("Unlocked %s (%s) mode!\nSelectable in Lobby • %s", mapName, diffDisplay, rewardText)

        table.insert(newUnlocks, {
            key = "Difficulty_" .. diffUpper,
            name = mapName .. " (" .. diffDisplay .. ")",
            desc = descText,
            badge = "UNLOCKED!",
            badgeColor = Color3.fromRGB(80, 255, 120),
            isDifficulty = true,
            image = "rbxassetid://98851830327389", -- Forest Harita Thumbnail
        })
    end

    -- 2. Görev / Başarım Kilitleri (Quests)
    for key, quest in pairs(ProgressionManager.Quests) do
        if LocalPlayer:GetAttribute("NewlyUnlocked_" .. key) == true or LocalPlayer:GetAttribute("NewlyCompletedQuest_" .. key) == true then
            local upgradeBase = UpgradeConfig.Upgrades[key] or ItemConfig.Items[key]
            table.insert(newUnlocks, {
                key = key,
                name = quest.Title or key,
                desc = (quest.Description or "") .. string.format("\nUnlock in Index for %d Silver", quest.UnlockCost or 25),
                badge = "READY TO UNLOCK",
                badgeColor = Color3.fromRGB(255, 215, 60),
                cost = quest.UnlockCost or 25,
                image = upgradeBase and upgradeBase.Icon or "rbxassetid://0",
            })
        end
    end

    if #newUnlocks == 0 then
        local emptyWrap = Frame(P3, { Size = UDim2.new(1, 0, 0, 200) })
        
        local emptyIcon = Frame(emptyWrap, {
            AnchorPoint = Vector2.new(0.5,0),
            Position = UDim2.new(0.5,0,0,30),
            Size = UDim2.new(0,80,0,80),
            BackgroundColor3 = C.PanelMid,
            BackgroundTransparency = 0,
            ZIndex = 5,
        })
        Stroke(emptyIcon, C.BorderInner, 1)
        CornerBrackets(emptyIcon, C.BorderInner, 5, 1)

        Image(emptyIcon, {
            Size  = UDim2.new(0.7,0,0.7,0),
            AnchorPoint = Vector2.new(0.5,0.5),
            Position = UDim2.new(0.5,0,0.5,0),
            Image = "rbxassetid://6031087120",
            ImageTransparency = 0.5,
            ZIndex = 6,
        })

        Label(emptyWrap, {
            Text = "No new items\nunlocked this round.",
            TextSize = 15,
            Font = FONT_BODY,
            TextColor3 = C.TextLow,
            Position = UDim2.new(0,0,0,114),
            Size = UDim2.new(1,0,0,50),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 5,
        })
    else
        for idx, unlock in ipairs(newUnlocks) do
            local card = Frame(P3, {
                Size = UDim2.new(1,0,0,92),
                BackgroundColor3 = C.PanelMid,
                BackgroundTransparency = 0,
                ZIndex = 5,
            })
            Stroke(card, C.BorderInner, 1)
            CornerBrackets(card, C.BorderInner, 6, 1)

            local iconBox = Frame(card, {
                Position = UDim2.new(0,6,0.5,0),
                AnchorPoint = Vector2.new(0,0.5),
                Size = UDim2.new(0,72,0,72),
                BackgroundColor3 = C.PanelDark,
                BackgroundTransparency = 0,
                ZIndex = 6,
            })
            Stroke(iconBox, C.BorderInner, 1)
            CornerBrackets(iconBox, C.BorderInner, 4, 1)
            
            Image(iconBox, {
                Size = unlock.isDifficulty and UDim2.new(1, -6, 1, -6) or UDim2.new(0.8, 0, 0.8, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Image = unlock.image or "rbxassetid://0",
                ScaleType = unlock.isDifficulty and Enum.ScaleType.Crop or Enum.ScaleType.Fit,
                ZIndex = 7,
            })

            Label(card, {
                Text = unlock.name or "New Unlock",
                TextSize = 16,
                Font = FONT_BODY,
                TextColor3 = C.TextHigh,
                Position = UDim2.new(0, 86, 0, 16),
                Size = UDim2.new(1, -220, 0, 22),
                ZIndex = 6,
            })
            
            -- Sağ üst köşeye durum etiketi (UNLOCKED! veya READY TO UNLOCK)
            Label(card, {
                Text = unlock.badge or "READY TO UNLOCK",
                TextSize = 12,
                Font = FONT_BODY,
                TextColor3 = unlock.badgeColor or Color3.fromRGB(255, 215, 60),
                Position = UDim2.new(1, -10, 0, 16),
                AnchorPoint = Vector2.new(1, 0),
                Size = UDim2.new(0, 140, 0, 22),
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 6,
            })

            Label(card, {
                Text = unlock.desc or "",
                TextSize = 12,
                Font = FONT_BODY,
                TextColor3 = C.TextMid,
                Position = UDim2.new(0, 86, 0, 42),
                Size = UDim2.new(1, -96, 0, 40),
                TextWrapped = true,
                ZIndex = 6,
            })
        end
    end

    -- UI Aktifleştirme ve Giriş Animasyonu
    Gui.Enabled = true

    Root.BackgroundTransparency    = 1
    Overlay.BackgroundTransparency = 1
    Root.Position = UDim2.new(0.5, 0, 0.5, 30)

    TweenService:Create(Overlay, TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play()
    TweenService:Create(Root,    TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }):Play()
end

ShowGameOverEvent.OnClientEvent:Connect(showEndOfRound)
