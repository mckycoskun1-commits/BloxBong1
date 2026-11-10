local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

--[[ Local Font Override to Arcade for Retro Rogue-like Aesthetic
local globalEnum = Enum
local Enum = {
	Font = setmetatable({
		FredokaOne = globalEnum.Font.Arcade,
		Gotham = globalEnum.Font.Arcade,
		GothamBold = globalEnum.Font.Arcade,
		GothamMedium = globalEnum.Font.Arcade,
		GothamBlack = globalEnum.Font.Arcade,
	}, {
		__index = globalEnum.Font
	})
}
setmetatable(Enum, {
	__index = globalEnum
}) ]]--

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Ana UI oluÅŸtur
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SidebarUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Bulletproof rendering!
screenGui.Parent = PlayerGui

local uiScale = Instance.new("UIScale")
uiScale.Parent = screenGui
local function updateScale()
    local viewport = workspace.CurrentCamera.ViewportSize
    local scale = math.min(viewport.X / 1600, viewport.Y / 900)
    uiScale.Scale = math.clamp(scale, 0.5, 2)
end
local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()
screenGui.Destroying:Connect(function()
    if viewportConnection then
        viewportConnection:Disconnect()
    end
end)

-- ==========================================
-- GÃœMÃœÅ PARA GÃ–STERGESÄ° (Retro Pixel Box)
-- ==========================================
local currencyGui = Instance.new("ScreenGui")
currencyGui.Name = "LobbyCurrencyUI"
currencyGui.ResetOnSpawn = false
currencyGui.IgnoreGuiInset = true
currencyGui.DisplayOrder = 20
currencyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
currencyGui.Parent = PlayerGui

-- Retro KÃ¶ÅŸe Braketleri Fonksiyonu (TÃ¼m butonlar iÃ§in ortak L-Ã§entikler)
local function addCornerBrackets(frame, color, size, thick)
    size = size or 8
    thick = thick or 2
    color = color or Color3.fromRGB(175, 190, 210)
    
    local function part(anchor, pos, w, h)
        local p = Instance.new("Frame")
        p.BackgroundColor3 = color
        p.BackgroundTransparency = 0.25
        p.BorderSizePixel = 0
        p.AnchorPoint = anchor
        p.Position = pos
        p.Size = UDim2.new(0, w, 0, h)
        p.ZIndex = frame.ZIndex + 4
        p.Parent = frame
    end
    
    -- Sol Ãœst (â”Œ)
    part(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), size, thick)
    part(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), thick, size)
    -- SaÄŸ Ãœst (â”)
    part(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), size, thick)
    part(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), thick, size)
    -- Sol Alt (â””)
    part(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), size, thick)
    part(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), thick, size)
    -- SaÄŸ Alt (â”˜)
    part(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), size, thick)
    part(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), thick, size)
end

-- Tekil Retro Piksel Kutusu
local silverBadge = Instance.new("Frame")
silverBadge.Name = "SilverCurrencyBadge"
silverBadge.Size = UDim2.new(0, 185, 0, 68)
silverBadge.AnchorPoint = Vector2.new(0, 1)
silverBadge.Position = UDim2.new(0, 24, 1, -24)
silverBadge.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
silverBadge.BackgroundTransparency = 0.35
silverBadge.BorderSizePixel = 0
silverBadge.ClipsDescendants = false
silverBadge.ZIndex = 10
silverBadge.Parent = currencyGui

-- Siyah Ã§izgi yerine kÃ¶ÅŸelere retro braketler
addCornerBrackets(silverBadge)

-- BÃ¼yÃ¼k ve Dikeyde Tam OrtalanmÄ±ÅŸ Sikke (68x68)
local silverIcon = Instance.new("ImageLabel")
silverIcon.Name = "SilverIcon"
silverIcon.Size = UDim2.new(0, 66, 0, 66)
silverIcon.Position = UDim2.new(0, 6, 0.5, 0)
silverIcon.AnchorPoint = Vector2.new(0, 0.5)
silverIcon.BackgroundTransparency = 1
silverIcon.Image = "rbxassetid://104534575155839"
silverIcon.ZIndex = 12
silverIcon.Parent = silverBadge

-- SayÄ± DeÄŸeri (Tek Arka Plan Ä°Ã§inde HizalanmÄ±ÅŸ)
local silverAmount = Instance.new("TextLabel")
silverAmount.Name = "SilverAmount"
silverAmount.Size = UDim2.new(1, -82, 1, 0)
silverAmount.Position = UDim2.new(0, 76, 0, 0)
silverAmount.BackgroundTransparency = 1
silverAmount.Font = Enum.Font.Arcade
silverAmount.TextSize = 34
silverAmount.TextColor3 = Color3.fromRGB(245, 248, 255)
silverAmount.TextXAlignment = Enum.TextXAlignment.Center
silverAmount.TextYAlignment = Enum.TextYAlignment.Center
silverAmount.Text = tostring(math.floor(Player:GetAttribute("Silver") or 0))
silverAmount.ZIndex = 12
silverAmount.Parent = silverBadge

local textStroke = Instance.new("UIStroke")
textStroke.Color = Color3.fromRGB(15, 18, 22)
textStroke.Thickness = 1.5
textStroke.Parent = silverAmount

local function updateSilverDisplay()
    local val = math.floor(Player:GetAttribute("Silver") or 0)
    silverAmount.Text = tostring(val)
end

Player:GetAttributeChangedSignal("Silver"):Connect(function()
    updateSilverDisplay()
    local popTween = TweenService:Create(silverIcon, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 74, 0, 74)
    })
    popTween:Play()
    popTween.Completed:Connect(function()
        TweenService:Create(silverIcon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 66, 0, 66)
        }):Play()
    end)
end)
updateSilverDisplay()

-- Ä°leride tanÄ±mlanan lokal fonksiyonlarÄ±n Ã¼st kapsamlarda gÃ¼venle Ã§aÄŸrÄ±labilmesi iÃ§in forward declarations
local closeOtherLobbyUIs
local closeIndex
local openIndex
local showDetails

-- Sol Panel Konteyneri
local container = Instance.new("Frame")
container.Name = "SidebarContainer"
container.Size = UDim2.new(0, 265, 0, 210)
container.Position = UDim2.new(0, 15, 0.58, 0)
container.AnchorPoint = Vector2.new(0, 0.5)
container.BackgroundTransparency = 1
container.ZIndex = 5
container.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 18)
layout.Parent = container

-- ==========================================
-- 1. CLASS SELECT (GeniÅŸ DikdÃ¶rtgen)
-- ==========================================
local classSelectBtn = Instance.new("TextButton")
classSelectBtn.Name = "ClassSelectBtn"
classSelectBtn.Size = UDim2.new(1, 0, 0, 88)
classSelectBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
classSelectBtn.BackgroundTransparency = 0.35
classSelectBtn.BorderSizePixel = 0
classSelectBtn.ClipsDescendants = false
classSelectBtn.Text = ""
classSelectBtn.AutoButtonColor = false
classSelectBtn.LayoutOrder = 1
classSelectBtn.Parent = container

-- Siyah Ã§izgi yerine kÃ¶ÅŸelere retro braketler
addCornerBrackets(classSelectBtn)

-- Ä°Ã§erik Ã‡erÃ§evesi (Efekt iÃ§in bunu saÄŸa kaydÄ±racaÄŸÄ±z)
local classContent = Instance.new("Frame")
classContent.Size = UDim2.new(1, 0, 1, 0)
classContent.BackgroundTransparency = 1
classContent.Parent = classSelectBtn

-- Ä°kon (Merkezden pÃ¼rÃ¼zsÃ¼z bÃ¼yÃ¼me iÃ§in AnchorPoint 0.5, 0.5)
local classIcon = Instance.new("ImageLabel")
classIcon.Size = UDim2.new(0, 78, 0, 78)
classIcon.Position = UDim2.new(0, 44, 0.5, 0)
classIcon.AnchorPoint = Vector2.new(0.5, 0.5)
classIcon.BackgroundTransparency = 1
classIcon.Image = "rbxassetid://94495483738058"
classIcon.Parent = classContent

-- Metin Konteyneri (Ä°ki kelime arasÄ± sÄ±kÄ± retro aralÄ±k ile yatay taÅŸmayÄ± kÄ±sÄ±tlar)
local textContainer = Instance.new("Frame")
textContainer.Name = "ClassTextContainer"
textContainer.Size = UDim2.new(1, -88, 1, 0)
textContainer.Position = UDim2.new(0, 86, 0, 0)
textContainer.BackgroundTransparency = 1
textContainer.Parent = classContent

local textLayout = Instance.new("UIListLayout")
textLayout.FillDirection = Enum.FillDirection.Horizontal
textLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
textLayout.Padding = UDim.new(0, 5) -- GeniÅŸ space karakteri yerine yatay yayÄ±lmayÄ± kÄ±sÄ±tlayan sÄ±kÄ± 5px aralÄ±k
textLayout.Parent = textContainer

local classText1 = Instance.new("TextLabel")
classText1.Name = "WordClass"
classText1.AutomaticSize = Enum.AutomaticSize.XY
classText1.BackgroundTransparency = 1
classText1.Text = "CLASS"
classText1.TextColor3 = Color3.fromRGB(255, 215, 60)
classText1.Font = Enum.Font.Arcade
classText1.TextSize = 24
classText1.TextWrapped = false
classText1.Parent = textContainer

local stroke1 = Instance.new("UIStroke")
stroke1.Color = Color3.fromRGB(15, 18, 22)
stroke1.Thickness = 1.2
stroke1.Parent = classText1

local classText2 = Instance.new("TextLabel")
classText2.Name = "WordSelect"
classText2.AutomaticSize = Enum.AutomaticSize.XY
classText2.BackgroundTransparency = 1
classText2.Text = "SELECT"
classText2.TextColor3 = Color3.fromRGB(255, 215, 60)
classText2.Font = Enum.Font.Arcade
classText2.TextSize = 24
classText2.TextWrapped = false
classText2.Parent = textContainer

local stroke2 = Instance.new("UIStroke")
stroke2.Color = Color3.fromRGB(15, 18, 22)
stroke2.Thickness = 1.2
stroke2.Parent = classText2

-- Hover Efekti (GÃ¶rsel ve yazÄ± birlikte bÃ¼yÃ¼r, 24'ten 28'e Ã§Ä±karken yatay yayÄ±lma kÄ±sÄ±tlÄ± kalÄ±r)
classSelectBtn.MouseEnter:Connect(function()
    TweenService:Create(classIcon, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 84, 0, 84)
    }):Play()
    TweenService:Create(classText1, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextSize = 28
    }):Play()
    TweenService:Create(classText2, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextSize = 28
    }):Play()
end)

classSelectBtn.MouseLeave:Connect(function()
    TweenService:Create(classIcon, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 78, 0, 78)
    }):Play()
    TweenService:Create(classText1, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextSize = 24
    }):Play()
    TweenService:Create(classText2, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextSize = 24
    }):Play()
end)

-- TÄ±klama: IÅŸÄ±nlanma
classSelectBtn.MouseButton1Click:Connect(function()
    local char = Player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local targetPart = workspace:FindFirstChild("ClassSelectTeleport")
        if targetPart then
            char:SetPrimaryPartCFrame(targetPart.CFrame + Vector3.new(0, 3, 0))
        else
            warn("ClassSelectTeleport adinda bir Part bulunamadi!")
        end
    end
end)

_G.UpdateQuestSidebarBadge = function(count) end

-- ==========================================
-- 2. INDEX / KÃœÃ‡ÃœK KUTULAR ALANI
-- ==========================================
local gridContainer = Instance.new("Frame")
gridContainer.Name = "GridContainer"
gridContainer.Size = UDim2.new(1, 0, 0, 96)
gridContainer.BackgroundTransparency = 1
gridContainer.LayoutOrder = 2
gridContainer.Parent = container

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 86, 0, 86)
gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridContainer

-- Index Butonu (Piksel Kare)
local indexBtn = Instance.new("TextButton")
indexBtn.Name = "IndexBtn"
indexBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
indexBtn.BackgroundTransparency = 0.35
indexBtn.BorderSizePixel = 0
indexBtn.ClipsDescendants = false
indexBtn.Text = ""
indexBtn.AutoButtonColor = false
indexBtn.Parent = gridContainer

-- Siyah Ã§izgi yerine kÃ¶ÅŸelere retro braketler
addCornerBrackets(indexBtn)

-- Index Ä°konu
local indexIcon = Instance.new("ImageLabel")
indexIcon.Size = UDim2.new(0.92, 0, 0.92, 0)
indexIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
indexIcon.AnchorPoint = Vector2.new(0.5, 0.5)
indexIcon.BackgroundTransparency = 1
indexIcon.Image = "rbxassetid://91741016326013"
indexIcon.Parent = indexBtn

-- Hover Efekti
indexBtn.MouseEnter:Connect(function()
    TweenService:Create(indexBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(58, 60, 70),
        BackgroundTransparency = 0.2
    }):Play()
    TweenService:Create(indexIcon, TweenInfo.new(0.2), {Size = UDim2.new(0.98, 0, 0.98, 0)}):Play()
end)

indexBtn.MouseLeave:Connect(function()
    TweenService:Create(indexBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(45, 45, 52),
        BackgroundTransparency = 0.35
    }):Play()
    TweenService:Create(indexIcon, TweenInfo.new(0.2), {Size = UDim2.new(0.92, 0, 0.92, 0)}):Play()
end)


-- GÃ¶rÃ¼nmez/TÄ±klama engelleyici arka plan overlay'i
local overlay = Instance.new("Frame")
overlay.Name = "IndexOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.Position = UDim2.new(0, 0, 0, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1 -- Animasyonla 0.45 yapÄ±lacak
overlay.Active = false -- KamerayÄ± dÃ¶ndÃ¼rebilmek iÃ§in tÄ±klamayÄ± bloke etmiyoruz
overlay.Visible = false
overlay.ZIndex = 8
overlay.Parent = screenGui

-- BulanÄ±klÄ±k Efekti (Lighting iÃ§inde)
local Lighting = game:GetService("Lighting")
local indexBlur = Lighting:FindFirstChild("IndexBlur") or Instance.new("BlurEffect")
indexBlur.Name = "IndexBlur"
indexBlur.Size = 0
indexBlur.Parent = Lighting

-- UI'larÄ± senkronize kapatma
closeOtherLobbyUIs = function(exceptQuest)
    -- Class Seçim UI'ını kapat
    local classUI = PlayerGui:FindFirstChild("AntigravityClassUI")
    if classUI and classUI.Enabled then
        if typeof(_G.CloseBloxBongClassUI) == "function" then
            _G.CloseBloxBongClassUI()
        else
            classUI.Enabled = false
            local classBlur = Lighting:FindFirstChild("ClassUIBlur")
            if classBlur then classBlur.Size = 0 end
        end
    end
    
    -- Dükkan UI'ını kapat
    local shopUI = PlayerGui:FindFirstChild("AntigravityShopUI")
    if shopUI and shopUI.Enabled then
        if typeof(_G.CloseBloxBongShopUI) == "function" then
            _G.CloseBloxBongShopUI()
        else
            shopUI.Enabled = false
            local shopBlur = Lighting:FindFirstChild("ShopUIBlur")
            if shopBlur then shopBlur.Size = 0 end
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
    
    -- Lobi Matchmaking UI'ını kapat
    local lobbyUI = PlayerGui:FindFirstChild("SolidLobbyUI")
    if lobbyUI then
        if typeof(_G.CloseBloxBongLobbyUI) == "function" then
            _G.CloseBloxBongLobbyUI()
        else
            local mainPanel = lobbyUI:FindFirstChild("MainPanel")
            if mainPanel and mainPanel.Visible then
                mainPanel.Visible = false
                local lobbyBlur = Lighting:FindFirstChild("LobbyUIBlur")
                if lobbyBlur then lobbyBlur.Size = 0 end
            end
        end
    end

    -- Ayarlar UI kapat
    if typeof(_G.CloseBloxBongSettingsUI) == "function" then
        _G.CloseBloxBongSettingsUI()
    end
    
    -- Görevler UI'ını kapat
    if not exceptQuest and typeof(_G.CloseQuestUI) == "function" then
        _G.CloseQuestUI()
    end
end
-- ==========================================
-- 3. UNLOCKS / INDEX PANEL (Retro Roguelite Aesthetic)
-- ==========================================
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))
local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))
local CharacterUIConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterUIConfig"))

local selectedCard = nil
local selectedItem = nil
local currentCategoryName = "WEAPONS"
local currentShowingData = nil
local unlockBtnActive = false
local updateIndexSilver = nil
local showDetails = nil

-- Ana Unlocks Penceresi
local indexPanel = Instance.new("Frame")
indexPanel.Name = "IndexPanel"
indexPanel.Size = UDim2.new(0, 1080, 0, 680)
indexPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
indexPanel.AnchorPoint = Vector2.new(0.5, 0.5)
indexPanel.BackgroundColor3 = Color3.fromRGB(20, 32, 26) -- Koyu Ã§am/orman yeÅŸili
indexPanel.BackgroundTransparency = 0
indexPanel.BorderSizePixel = 0
indexPanel.Visible = false
indexPanel.ZIndex = 10
indexPanel.Parent = screenGui

local indexPanelCorner = Instance.new("UICorner")
indexPanelCorner.CornerRadius = UDim.new(0, 4)
indexPanelCorner.Parent = indexPanel

local indexPanelStroke = Instance.new("UIStroke")
indexPanelStroke.Color = Color3.fromRGB(10, 16, 12)
indexPanelStroke.Thickness = 3
indexPanelStroke.Parent = indexPanel

-- Ä°Ã§ Metalik Ã‡erÃ§eve Ã‡izgisi (GÃ¶rseldeki gibi aÃ§Ä±k adaÃ§ayÄ±/gÃ¼mÃ¼ÅŸ iÃ§ hat)
local innerBorder = Instance.new("Frame")
innerBorder.Name = "InnerBorder"
innerBorder.Size = UDim2.new(1, -6, 1, -6)
innerBorder.Position = UDim2.new(0, 3, 0, 3)
innerBorder.BackgroundTransparency = 1
innerBorder.BorderSizePixel = 0
innerBorder.ZIndex = 10.5
innerBorder.Parent = indexPanel

local innerStroke = Instance.new("UIStroke")
innerStroke.Color = Color3.fromRGB(110, 135, 120)
innerStroke.Thickness = 1.5
innerStroke.Parent = innerBorder

-- DÄ±ÅŸ kÃ¶ÅŸe sÃ¼sleri (4 kÃ¶ÅŸede L braketler)
addCornerBrackets(indexPanel, Color3.fromRGB(180, 208, 192), 12, 2.5)

-- Kapatma Fonksiyonu
closeIndex = function()
    local indexUI = PlayerGui:FindFirstChild("IndexUI")
    if indexUI then
        indexUI:SetAttribute("Open", false)
    end
    selectedCard = nil
    selectedItem = nil
    TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    local t = TweenService:Create(indexBlur, TweenInfo.new(0.2), {Size = 0})
    t:Play()
    t.Completed:Connect(function()
        overlay.Visible = false
        indexPanel.Visible = false
    end)
end

-- AÃ§ma Fonksiyonu
openIndex = function()
    closeOtherLobbyUIs()
    overlay.Visible = true
    indexPanel.Visible = true
    TweenService:Create(overlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(indexBlur, TweenInfo.new(0.3), {Size = 15}):Play()
    if updateIndexSilver then
        updateIndexSilver()
    end
end

-- Index butonu tıklama
indexBtn.MouseButton1Click:Connect(function()
    local indexUI = PlayerGui:FindFirstChild("IndexUI")
    if indexUI then
        local willOpen = not indexUI.Enabled
        if willOpen and typeof(closeOtherLobbyUIs) == "function" then
            closeOtherLobbyUIs()
        end
        indexUI:SetAttribute("Open", willOpen)
        return
    end

    if indexPanel.Visible then
        closeIndex()
    else
        openIndex()
    end
end)

-- DiÄŸer UI'lar aÃ§Ä±ldÄ±ÄŸÄ±nda otomatik olarak Index'i kapat ve Sidebar'Ä± Class UI iÃ§in gizle/gÃ¶ster
task.spawn(function()
    local classUI = PlayerGui:WaitForChild("AntigravityClassUI", 5)
    if classUI then
        classUI:GetPropertyChangedSignal("Enabled"):Connect(function()
            if classUI.Enabled then
                if indexPanel.Visible then
                    closeIndex()
                end
                container.Visible = false
            else
                container.Visible = true
            end
        end)
    end

    local lobbyUI = PlayerGui:WaitForChild("SolidLobbyUI", 5)
    if lobbyUI then
        local mainPanel = lobbyUI:WaitForChild("MainPanel", 5)
        if mainPanel then
            mainPanel:GetPropertyChangedSignal("Visible"):Connect(function()
                if mainPanel.Visible and indexPanel.Visible then
                    closeIndex()
                end
            end)
        end
    end
end)

-- ==========================================
-- HEADER: BAÅLIK, GÃœMÃœÅ SAYACI & KIRMIZI Ã‡IKIÅ BUTONU
-- ==========================================
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Parent = indexPanel
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.new(0, 24, 0, 10)
titleLabel.Size = UDim2.new(0, 300, 0, 32)
titleLabel.Font = Enum.Font.Arcade
titleLabel.Text = "UNLOCKS"
titleLabel.TextSize = 28
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(245, 252, 246)
titleLabel.ZIndex = 11

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(8, 14, 10)
titleStroke.Thickness = 2
titleStroke.Parent = titleLabel

-- GÃ¼mÃ¼ÅŸ Rozeti (Header iÃ§i)
local indexSilverBadge = Instance.new("Frame")
indexSilverBadge.Name = "IndexSilverBadge"
indexSilverBadge.Size = UDim2.new(0, 140, 0, 30)
indexSilverBadge.Position = UDim2.new(1, -190, 0, 10)
indexSilverBadge.BackgroundColor3 = Color3.fromRGB(15, 24, 19)
indexSilverBadge.BorderSizePixel = 0
indexSilverBadge.ZIndex = 11
indexSilverBadge.Parent = indexPanel

local isbCorner = Instance.new("UICorner")
isbCorner.CornerRadius = UDim.new(0, 3)
isbCorner.Parent = indexSilverBadge

local isbStroke = Instance.new("UIStroke")
isbStroke.Color = Color3.fromRGB(75, 95, 82)
isbStroke.Thickness = 1.5
isbStroke.Parent = indexSilverBadge
addCornerBrackets(indexSilverBadge, Color3.fromRGB(140, 165, 150), 6, 1.5)

local isbIcon = Instance.new("ImageLabel")
isbIcon.Size = UDim2.new(0, 22, 0, 22)
isbIcon.Position = UDim2.new(0, 8, 0.5, 0)
isbIcon.AnchorPoint = Vector2.new(0, 0.5)
isbIcon.BackgroundTransparency = 1
isbIcon.Image = ProgressionManager.SILVER_ICON
isbIcon.ZIndex = 12
isbIcon.Parent = indexSilverBadge

local isbAmount = Instance.new("TextLabel")
isbAmount.Name = "IndexSilverAmount"
isbAmount.Size = UDim2.new(1, -38, 1, 0)
isbAmount.Position = UDim2.new(0, 34, 0, 0)
isbAmount.BackgroundTransparency = 1
isbAmount.Font = Enum.Font.Arcade
isbAmount.TextSize = 20
isbAmount.TextColor3 = Color3.fromRGB(240, 248, 255)
isbAmount.TextXAlignment = Enum.TextXAlignment.Center
isbAmount.TextYAlignment = Enum.TextYAlignment.Center
isbAmount.Text = tostring(math.floor(Player:GetAttribute("Silver") or 0))
isbAmount.ZIndex = 12
isbAmount.Parent = indexSilverBadge

updateIndexSilver = function()
    isbAmount.Text = tostring(math.floor(Player:GetAttribute("Silver") or 0))
end
Player:GetAttributeChangedSignal("Silver"):Connect(function()
    updateIndexSilver()
    if currentShowingData and showDetails then
        showDetails(currentShowingData, currentCategoryName)
    end
end)
updateIndexSilver()

-- KÄ±rmÄ±zÄ± Kapatma Butonu (GÃ¶rseldeki kÄ±rmÄ±zÄ± kare X butonu)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Parent = indexPanel
closeBtn.Size = UDim2.new(0, 32, 0, 30)
closeBtn.Position = UDim2.new(1, -44, 0, 10)
closeBtn.Text = "âœ•"
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BackgroundColor3 = Color3.fromRGB(165, 25, 25)
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 11

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 3)
closeCorner.Parent = closeBtn

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(8, 14, 10)
closeStroke.Thickness = 2
closeStroke.Parent = closeBtn

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(225, 35, 35)
    }):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(165, 25, 25)
    }):Play()
end)
closeBtn.MouseButton1Click:Connect(closeIndex)

-- ==========================================
-- YATAY SEKMELER (HORIZONTAL TABS)
-- ==========================================
local categories = {"CHARACTERS", "WEAPONS", "TOMES", "ITEMS", "MONSTERS"}
local categoryButtons = {}

local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Parent = indexPanel
tabContainer.Size = UDim2.new(1, -48, 0, 34)
tabContainer.Position = UDim2.new(0, 24, 0, 46)
tabContainer.BackgroundTransparency = 1
tabContainer.ZIndex = 11

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabContainer

-- Sekmelerin altÄ±ndaki yatay ayÄ±rÄ±cÄ± Ã§izgi
local tabDivider = Instance.new("Frame")
tabDivider.Name = "TabDivider"
tabDivider.Parent = indexPanel
tabDivider.Size = UDim2.new(1, -48, 0, 2)
tabDivider.Position = UDim2.new(0, 24, 0, 80)
tabDivider.BackgroundColor3 = Color3.fromRGB(90, 115, 100)
tabDivider.BorderSizePixel = 0
tabDivider.ZIndex = 11

-- ==========================================
-- RETRO KÃ–ÅE PARÃ‡ACIKLARI YARDIMCISI (Selection Brackets â”Œ â” â”” â”˜)
-- ==========================================
local function makeBrackets(parent, color, size, thick)
    local brackets = Instance.new("Frame")
    brackets.Name = "Brackets"
    brackets.Size = UDim2.new(1, 0, 1, 0)
    brackets.BackgroundTransparency = 1
    brackets.ZIndex = (parent.ZIndex or 10) + 5
    brackets.Parent = parent
    
    size = size or 8
    thick = thick or 2
    color = color or Color3.fromRGB(255, 255, 255)
    
    local function part(anchor, pos, w, h)
        local p = Instance.new("Frame")
        p.BackgroundColor3 = color
        p.BorderSizePixel = 0
        p.AnchorPoint = anchor
        p.Position = pos
        p.Size = UDim2.new(0, w, 0, h)
        p.ZIndex = brackets.ZIndex
        p.Parent = brackets
    end
    -- â”Œ
    part(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), size, thick)
    part(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), thick, size)
    -- â”
    part(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), size, thick)
    part(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), thick, size)
    -- â””
    part(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), size, thick)
    part(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), thick, size)
    -- â”˜
    part(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), size, thick)
    part(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), thick, size)
    
    return brackets
end

-- ==========================================
-- ANA IZGARA ALANI (COMPACT SQUARE SLOTS)
-- ==========================================
local itemArea = Instance.new("ScrollingFrame")
itemArea.Name = "ItemArea"
itemArea.Parent = indexPanel
itemArea.Size = UDim2.new(1, -48, 0, 420)
itemArea.Position = UDim2.new(0, 24, 0, 88)
itemArea.BackgroundTransparency = 1
itemArea.ScrollBarThickness = 6
itemArea.ScrollBarImageColor3 = Color3.fromRGB(90, 118, 102)
itemArea.BorderSizePixel = 0
itemArea.ZIndex = 11

local itemPadding = Instance.new("UIPadding")
itemPadding.PaddingLeft = UDim.new(0, 4)
itemPadding.PaddingRight = UDim.new(0, 4)
itemPadding.PaddingTop = UDim.new(0, 8)
itemPadding.PaddingBottom = UDim.new(0, 12)
itemPadding.Parent = itemArea

local grid = Instance.new("UIGridLayout")
grid.Parent = itemArea
grid.CellSize = UDim2.new(0, 78, 0, 78)
grid.CellPadding = UDim2.new(0, 10, 0, 10)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
grid.VerticalAlignment = Enum.VerticalAlignment.Top
grid.SortOrder = Enum.SortOrder.LayoutOrder

grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    itemArea.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 24)
end)

-- ==========================================
-- ALT DETAY & Ã–NÄ°ZLEME ALANI (BOTTOM DETAIL BAR)
-- ==========================================
local bottomDivider = Instance.new("Frame")
bottomDivider.Name = "BottomDivider"
bottomDivider.Parent = indexPanel
bottomDivider.Size = UDim2.new(1, -48, 0, 2)
bottomDivider.Position = UDim2.new(0, 24, 0, 516)
bottomDivider.BackgroundColor3 = Color3.fromRGB(90, 115, 100)
bottomDivider.BorderSizePixel = 0
bottomDivider.ZIndex = 11

local bottomDetailFrame = Instance.new("Frame")
bottomDetailFrame.Name = "BottomDetailFrame"
bottomDetailFrame.Parent = indexPanel
bottomDetailFrame.Size = UDim2.new(1, -48, 0, 150)
bottomDetailFrame.Position = UDim2.new(0, 24, 0, 522)
bottomDetailFrame.BackgroundTransparency = 1
bottomDetailFrame.ZIndex = 11

-- Sol BÃ¼yÃ¼k Ã–nizleme Kutusu (GÃ¶rseldeki sol alttaki bÃ¼yÃ¼k kutu)
local previewBox = Instance.new("Frame")
previewBox.Name = "PreviewBox"
previewBox.Parent = bottomDetailFrame
previewBox.Size = UDim2.new(0, 136, 0, 136)
previewBox.Position = UDim2.new(0, 4, 0, 7)
previewBox.BackgroundColor3 = Color3.fromRGB(28, 40, 33)
previewBox.BorderSizePixel = 0
previewBox.ZIndex = 12

local pbCorner = Instance.new("UICorner")
pbCorner.CornerRadius = UDim.new(0, 4)
pbCorner.Parent = previewBox

local pbStroke = Instance.new("UIStroke")
pbStroke.Color = Color3.fromRGB(80, 102, 90)
pbStroke.Thickness = 1.5
pbStroke.Parent = previewBox

addCornerBrackets(previewBox, Color3.fromRGB(180, 205, 190), 8, 2)

local previewIcon = Instance.new("ImageLabel")
previewIcon.Name = "PreviewIcon"
previewIcon.Size = UDim2.new(0, 104, 0, 104)
previewIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
previewIcon.AnchorPoint = Vector2.new(0.5, 0.5)
previewIcon.BackgroundTransparency = 1
previewIcon.ScaleType = Enum.ScaleType.Fit
previewIcon.ZIndex = 13
previewIcon.Parent = previewBox

-- Orta Bilgi AlanÄ± (BaÅŸlÄ±k, Kategori, GÃ¶rev / AÃ§Ä±klama)
local infoContainer = Instance.new("Frame")
infoContainer.Name = "InfoContainer"
infoContainer.Parent = bottomDetailFrame
infoContainer.Size = UDim2.new(1, -430, 1, -14)
infoContainer.Position = UDim2.new(0, 156, 0, 7)
infoContainer.BackgroundTransparency = 1
infoContainer.ZIndex = 12

local detailTitle = Instance.new("TextLabel")
detailTitle.Name = "DetailTitle"
detailTitle.Parent = infoContainer
detailTitle.Size = UDim2.new(1, 0, 0, 26)
detailTitle.Position = UDim2.new(0, 0, 0, 2)
detailTitle.BackgroundTransparency = 1
detailTitle.Font = Enum.Font.Arcade
detailTitle.Text = "SELECT AN UNLOCK"
detailTitle.TextSize = 22
detailTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
detailTitle.TextXAlignment = Enum.TextXAlignment.Left
detailTitle.ZIndex = 13

local detailCategory = Instance.new("TextLabel")
detailCategory.Name = "DetailCategory"
detailCategory.Parent = infoContainer
detailCategory.Size = UDim2.new(1, 0, 0, 18)
detailCategory.Position = UDim2.new(0, 0, 0, 28)
detailCategory.BackgroundTransparency = 1
detailCategory.Font = Enum.Font.FredokaOne
detailCategory.Text = ""
detailCategory.TextSize = 13
detailCategory.TextColor3 = Color3.fromRGB(140, 200, 160)
detailCategory.TextXAlignment = Enum.TextXAlignment.Left
detailCategory.ZIndex = 13

local detailDesc = Instance.new("TextLabel")
detailDesc.Name = "DetailDesc"
detailDesc.Parent = infoContainer
detailDesc.Size = UDim2.new(1, 0, 1, -50)
detailDesc.Position = UDim2.new(0, 0, 0, 48)
detailDesc.BackgroundTransparency = 1
detailDesc.Font = Enum.Font.GothamMedium
detailDesc.Text = "Select any weapon, character, tome, or item above to view its unlock challenge, stats, and effects."
detailDesc.TextSize = 13
detailDesc.TextColor3 = Color3.fromRGB(200, 215, 205)
detailDesc.TextXAlignment = Enum.TextXAlignment.Left
detailDesc.TextYAlignment = Enum.TextYAlignment.Top
detailDesc.TextWrapped = true
detailDesc.RichText = true
detailDesc.ZIndex = 13

-- SaÄŸ Aksiyon / AÃ§ma Butonu
local actionContainer = Instance.new("Frame")
actionContainer.Name = "ActionContainer"
actionContainer.Parent = bottomDetailFrame
actionContainer.Size = UDim2.new(0, 240, 1, -14)
actionContainer.Position = UDim2.new(1, -244, 0, 7)
actionContainer.BackgroundTransparency = 1
actionContainer.ZIndex = 12

local unlockBtn = Instance.new("TextButton")
unlockBtn.Name = "UnlockButton"
unlockBtn.Parent = actionContainer
unlockBtn.Size = UDim2.new(1, 0, 0, 50)
unlockBtn.Position = UDim2.new(0, 0, 0.5, 0)
unlockBtn.AnchorPoint = Vector2.new(0, 0.5)
unlockBtn.Font = Enum.Font.FredokaOne
unlockBtn.TextSize = 15
unlockBtn.BorderSizePixel = 0
unlockBtn.AutoButtonColor = false
unlockBtn.ZIndex = 13

local ubCorner = Instance.new("UICorner")
ubCorner.CornerRadius = UDim.new(0, 4)
ubCorner.Parent = unlockBtn

local ubStroke = Instance.new("UIStroke")
ubStroke.Color = Color3.fromRGB(10, 16, 12)
ubStroke.Thickness = 2
ubStroke.Parent = unlockBtn

local unlockContent = Instance.new("Frame")
unlockContent.Name = "UnlockContent"
unlockContent.Size = UDim2.new(1, 0, 1, 0)
unlockContent.BackgroundTransparency = 1
unlockContent.ZIndex = 14
unlockContent.Visible = false
unlockContent.Parent = unlockBtn

local unlockLayout = Instance.new("UIListLayout")
unlockLayout.FillDirection = Enum.FillDirection.Horizontal
unlockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
unlockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
unlockLayout.Padding = UDim.new(0, 8)
unlockLayout.SortOrder = Enum.SortOrder.LayoutOrder
unlockLayout.Parent = unlockContent

local unlockActionText = Instance.new("TextLabel")
unlockActionText.Name = "ActionText"
unlockActionText.AutomaticSize = Enum.AutomaticSize.XY
unlockActionText.BackgroundTransparency = 1
unlockActionText.Font = Enum.Font.FredokaOne
unlockActionText.TextSize = 16
unlockActionText.TextColor3 = Color3.fromRGB(255, 255, 255)
unlockActionText.Text = "UNLOCK"
unlockActionText.LayoutOrder = 1
unlockActionText.ZIndex = 15
unlockActionText.Parent = unlockContent

local unlockCoinIcon = Instance.new("ImageLabel")
unlockCoinIcon.Name = "CoinIcon"
unlockCoinIcon.Size = UDim2.new(0, 24, 0, 24)
unlockCoinIcon.BackgroundTransparency = 1
unlockCoinIcon.Image = ProgressionManager.SILVER_ICON
unlockCoinIcon.LayoutOrder = 2
unlockCoinIcon.ZIndex = 15
unlockCoinIcon.Parent = unlockContent

local unlockCoinAmount = Instance.new("TextLabel")
unlockCoinAmount.Name = "CoinAmount"
unlockCoinAmount.AutomaticSize = Enum.AutomaticSize.XY
unlockCoinAmount.BackgroundTransparency = 1
unlockCoinAmount.Font = Enum.Font.Arcade
unlockCoinAmount.TextSize = 22
unlockCoinAmount.TextColor3 = Color3.fromRGB(255, 255, 255)
unlockCoinAmount.Text = "25"
unlockCoinAmount.LayoutOrder = 3
unlockCoinAmount.ZIndex = 15
unlockCoinAmount.Parent = unlockContent

unlockBtn.MouseEnter:Connect(function()
    if unlockBtnActive then
        TweenService:Create(unlockBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(45, 185, 90)
        }):Play()
    end
end)

unlockBtn.MouseLeave:Connect(function()
    if unlockBtnActive then
        TweenService:Create(unlockBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(35, 155, 75)
        }):Play()
    end
end)

local function formatAssetId(id)
    if not id or id == "" then return "" end
    local s = tostring(id):gsub("%s+", "")
    if tonumber(s) then
        return "rbxassetid://" .. s
    elseif not s:find("://") and not s:find("roblox.com") then
        return "rbxassetid://" .. s
    end
    return s
end

local loadCategory

showDetails = function(data, catType)
    currentShowingData = data
    if not data then return end
    
    local isLocked = false
    local isQuestDone = false
    local currentProgress = 0
    local target = 1
    local quest = nil
    
    if data.LockedByDefault then
        isLocked = not ProgressionManager.IsUnlocked(Player, data.Key)
        quest = ProgressionManager.GetQuest(data.Key)
        currentProgress = Player:GetAttribute("Progress_" .. data.Key) or 0
        target = quest and quest.Target or 1
        isQuestDone = (currentProgress >= target) or (Player:GetAttribute("QuestCompleted_" .. data.Key) == true)
    end
    
    local playerSilver = ProgressionManager.GetSilver(Player)
    local cost = quest and quest.UnlockCost or 25
    
    previewIcon.Image = formatAssetId(data.Icon)
    
    if isLocked then
        -- Kilitli eÅŸyalar gÃ¶rseldeki gibi tamamen simsiyah silÃ¼et (#000000) olarak gÃ¶sterilir
        previewIcon.ImageColor3 = Color3.fromRGB(0, 0, 0)
        
        if isQuestDone then
            detailTitle.Text = data.DisplayName or data.Title or data.Name or "UNKNOWN"
            detailTitle.TextColor3 = Color3.fromRGB(255, 220, 60)
            detailCategory.Text = string.format("[%s • CHALLENGE COMPLETE]", string.upper(catType or "UNLOCK"))
            detailCategory.TextColor3 = Color3.fromRGB(80, 255, 120)
            
            local desc = "<font color='#55ff78'><b>CHALLENGE COMPLETED!</b></font>\n" .. (quest and quest.Description or "")
            if data.Description and data.Description ~= "" then
                desc = desc .. "\n\n<i>" .. data.Description .. "</i>"
            end
            detailDesc.Text = desc
            
            unlockBtn.Visible = true
            unlockBtn.Text = ""
            unlockContent.Visible = true
            
            if playerSilver >= cost then
                unlockActionText.Text = "UNLOCK"
                unlockActionText.TextColor3 = Color3.fromRGB(255, 255, 255)
                unlockCoinAmount.Text = tostring(cost)
                unlockCoinAmount.TextColor3 = Color3.fromRGB(255, 255, 255)
                unlockBtn.BackgroundColor3 = Color3.fromRGB(35, 155, 75)
                unlockBtn.AutoButtonColor = true
                unlockBtnActive = true
            else
                unlockActionText.Text = "NEED"
                unlockActionText.TextColor3 = Color3.fromRGB(255, 160, 160)
                unlockCoinAmount.Text = string.format("%d (%d/%d)", cost, playerSilver, cost)
                unlockCoinAmount.TextColor3 = Color3.fromRGB(255, 160, 160)
                unlockBtn.BackgroundColor3 = Color3.fromRGB(80, 42, 45)
                unlockBtn.AutoButtonColor = false
                unlockBtnActive = false
            end
        else
            detailTitle.Text = "🔒 " .. (data.DisplayName or data.Title or data.Name or "UNKNOWN")
            detailTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
            detailCategory.Text = string.format("[%s • LOCKED]", string.upper(catType or "UNLOCK"))
            detailCategory.TextColor3 = Color3.fromRGB(255, 120, 120)
            
            local progressText = ""
            if quest and quest.Target then
                progressText = string.format("\n\n<b>[Progress: %s / %s]</b>", tostring(currentProgress), tostring(target))
            end
            detailDesc.Text = "<font color='#ff7878'><b>HOW TO UNLOCK:</b></font>\n" .. (quest and quest.Description or "Complete special challenge in matches.") .. progressText
            
            unlockBtn.Visible = true
            unlockContent.Visible = false
            unlockBtn.Text = "🔒 LOCKED"
            unlockBtn.BackgroundColor3 = Color3.fromRGB(38, 48, 42)
            unlockBtn.TextColor3 = Color3.fromRGB(150, 160, 155)
            unlockBtn.AutoButtonColor = false
            unlockBtnActive = false
        end
    else
        -- Kilitli olmayan / Açılmış eşya: Canlı tam renk
        previewIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        detailTitle.Text = data.DisplayName or data.Title or data.Name or "UNKNOWN"
        detailTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        
        local catTag = string.upper(catType or "UNLOCK")
        if data.Rarity then
            catTag = catTag .. " â€¢ " .. string.upper(data.Rarity)
        end
        detailCategory.Text = string.format("[%s]", catTag)
        detailCategory.TextColor3 = Color3.fromRGB(140, 210, 170)
        
        if catType == "MONSTERS" then
            local desc = "Type: " .. (data.IsBoss and "BOSS" or "Regular Monster")
            if data.Description and data.Description ~= "" then
                desc = desc .. "\n\n" .. data.Description
            end
            desc = desc .. string.format("\n\nHP: %s | Damage: %s | Speed: %s | XP Drop: %s", tostring(data.Health or 0), tostring(data.Damage or 0), tostring(data.Speed or 0), tostring(data.XPDrop or "-"))
            detailDesc.Text = desc
        elseif catType == "CHARACTERS" then
            local desc = data.Description or ""
            if data.Stats then
                local statLines = {}
                for _, s in ipairs(data.Stats) do
                    table.insert(statLines, string.format("%s: %s", s.Name, s.Value))
                end
                desc = desc .. "\n\n" .. table.concat(statLines, " | ")
            end
            detailDesc.Text = desc
        else
            detailDesc.Text = data.Description or ""
        end
        
        if data.LockedByDefault then
            unlockBtn.Visible = true
            unlockContent.Visible = false
            unlockBtn.Text = "âœ“ UNLOCKED"
            unlockBtn.BackgroundColor3 = Color3.fromRGB(28, 52, 36)
            unlockBtn.TextColor3 = Color3.fromRGB(120, 235, 145)
            unlockBtn.AutoButtonColor = false
            unlockBtnActive = false
        else
            unlockBtn.Visible = false
            unlockContent.Visible = false
            unlockBtnActive = false
        end
    end
end

unlockBtn.MouseButton1Click:Connect(function()
    if not unlockBtnActive or not currentShowingData then return end
    local itemKey = currentShowingData.Key
    if not itemKey then return end
    
    unlockBtnActive = false
    unlockContent.Visible = false
    unlockBtn.Text = "UNLOCKING..."
    
    local Events = ReplicatedStorage:WaitForChild("Events")
    local UnlockIndexItem = Events:WaitForChild("UnlockIndexItem")
    local success, res = UnlockIndexItem:InvokeServer(itemKey)
    
    if success then
        local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))
        SoundManager.PlaySound("Purchase")
        
        if loadCategory then
            loadCategory(currentCategoryName)
        end
        showDetails(currentShowingData, currentCategoryName)
    else
        unlockContent.Visible = false
        unlockBtn.Text = tostring(res or "FAILED")
        task.wait(1)
        showDetails(currentShowingData, currentCategoryName)
    end
end)

loadCategory = function(catName)
    currentCategoryName = catName
    selectedCard = nil
    selectedItem = nil

    for _, child in ipairs(itemArea:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local items = {}
    if catName == "CHARACTERS" then
        for _, c in ipairs(CharacterUIConfig.Characters) do
            table.insert(items, {
                Key = c.Id,
                Title = c.Name,
                DisplayName = c.Name,
                Description = c.Description,
                Icon = c.Icon,
                Stats = c.Stats,
                Color = c.Color,
                Category = "CHARACTERS",
                LockedByDefault = (c.Id ~= "Human")
            })
        end
    elseif catName == "WEAPONS" then
        for k, v in pairs(UpgradeConfig.Upgrades) do
            if v.Type == "Weapon" then
                v.Key = k
                v.Category = "WEAPONS"
                table.insert(items, v)
            end
        end
        table.sort(items, function(a, b) return (a.Title or "") < (b.Title or "") end)
    elseif catName == "TOMES" then
        for k, v in pairs(UpgradeConfig.Upgrades) do
            if v.Type == "Perk" then
                v.Key = k
                v.Category = "TOMES"
                table.insert(items, v)
            end
        end
        table.sort(items, function(a, b) return (a.Title or "") < (b.Title or "") end)
    elseif catName == "ITEMS" then
        for k, v in pairs(ItemConfig.Items) do
            v.Key = k
            v.Category = "ITEMS"
            table.insert(items, v)
        end
        table.sort(items, function(a, b) return (a.Title or "") < (b.Title or "") end)
    elseif catName == "MONSTERS" then
        for k, v in pairs(EnemyConfig.Enemies) do
            v.Key = k
            v.Category = "MONSTERS"
            table.insert(items, v)
        end
        table.sort(items, function(a, b)
            return (a.Order or 99) < (b.Order or 99)
        end)
    end
    
    local firstCard = nil
    local firstItem = nil
    
    for i, item in ipairs(items) do
        local isLocked = false
        local isQuestDone = false
        local currentProgress = 0
        local quest = nil
        
        if item.LockedByDefault then
            isLocked = not ProgressionManager.IsUnlocked(Player, item.Key)
            quest = ProgressionManager.GetQuest(item.Key)
            currentProgress = Player:GetAttribute("Progress_" .. item.Key) or 0
            isQuestDone = (currentProgress >= (quest and quest.Target or 999999)) or (Player:GetAttribute("QuestCompleted_" .. item.Key) == true)
        end

        local card = Instance.new("Frame")
        card.Name = "Slot_" .. (item.Key or i)
        card.Parent = itemArea
        card.Size = UDim2.new(0, 78, 0, 78)
        card.BackgroundColor3 = Color3.fromRGB(34, 46, 39)
        card.BorderSizePixel = 0
        card.ZIndex = 12
        card:SetAttribute("IsLocked", isLocked)
        card:SetAttribute("IsQuestDone", isQuestDone)
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 4)
        cardCorner.Parent = card
        
        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Color3.fromRGB(18, 26, 21)
        cardStroke.Thickness = 1.5
        cardStroke.Parent = card
        
        -- SeÃ§im ve Hover kÃ¶ÅŸelikleri (GÃ¶rseldeki beyaz L-braketler)
        local selectBrackets = makeBrackets(card, Color3.fromRGB(255, 255, 255), 8, 2)
        selectBrackets.Visible = false
        
        -- OrtalanmÄ±ÅŸ Ä°kon
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 56, 0, 56)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.ScaleType = (catName == "MONSTERS") and Enum.ScaleType.Crop or Enum.ScaleType.Fit
        icon.Image = formatAssetId(item.Icon)
        icon.ImageColor3 = isLocked and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        icon.ZIndex = 13
        icon.Parent = card
        
        -- Sol Ãœst Durum Rozeti (GÃ¶rseldeki Checkbox)
        local badge = Instance.new("Frame")
        badge.Name = "StatusBadge"
        badge.Size = UDim2.new(0, 16, 0, 16)
        badge.Position = UDim2.new(0, 4, 0, 4)
        badge.BackgroundColor3 = Color3.fromRGB(16, 24, 20)
        badge.BorderSizePixel = 0
        badge.ZIndex = 14
        badge.Parent = card
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 2)
        bCorner.Parent = badge
        
        local bStroke = Instance.new("UIStroke")
        bStroke.Color = Color3.fromRGB(55, 75, 65)
        bStroke.Thickness = 1
        bStroke.Parent = badge
        
        if not isLocked then
            local checkLabel = Instance.new("TextLabel")
            checkLabel.Size = UDim2.new(1, 0, 1, 0)
            checkLabel.BackgroundTransparency = 1
            checkLabel.Font = Enum.Font.FredokaOne
            checkLabel.Text = "âœ“"
            checkLabel.TextSize = 13
            checkLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
            checkLabel.ZIndex = 15
            checkLabel.Parent = badge
        elseif isQuestDone then
            badge.BackgroundColor3 = Color3.fromRGB(28, 80, 45)
            local coinImg = Instance.new("ImageLabel")
            coinImg.Size = UDim2.new(0, 12, 0, 12)
            coinImg.Position = UDim2.new(0.5, 0, 0.5, 0)
            coinImg.AnchorPoint = Vector2.new(0.5, 0.5)
            coinImg.BackgroundTransparency = 1
            coinImg.Image = ProgressionManager.SILVER_ICON
            coinImg.ZIndex = 15
            coinImg.Parent = badge
        end

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.ZIndex = 16
        btn.Parent = card
        
        btn.MouseEnter:Connect(function()
            if selectedCard ~= card then
                selectBrackets.Visible = true
            end
            showDetails(item, catName)
        end)
        
        btn.MouseLeave:Connect(function()
            if selectedCard ~= card then
                selectBrackets.Visible = false
                if selectedItem then
                    showDetails(selectedItem, catName)
                end
            end
        end)
        
        btn.MouseButton1Click:Connect(function()
            if selectedCard and selectedCard ~= card then
                local prevBrackets = selectedCard:FindFirstChild("Brackets")
                if prevBrackets then prevBrackets.Visible = false end
            end
            selectedCard = card
            selectedItem = item
            selectBrackets.Visible = true
            showDetails(item, catName)
        end)
        
        if i == 1 then
            firstCard = card
            firstItem = item
        end
    end
    
    if firstCard and firstItem then
        selectedCard = firstCard
        selectedItem = firstItem
        local b = firstCard:FindFirstChild("Brackets")
        if b then b.Visible = true end
        showDetails(firstItem, catName)
    end
end

local function updateCategoryTabs(activeName)
    for name, tabBtn in pairs(categoryButtons) do
        local topBrackets = tabBtn:FindFirstChild("TopBrackets")
        local isSelected = (name == activeName)
        if isSelected then
            tabBtn.BackgroundColor3 = Color3.fromRGB(16, 26, 21)
            tabBtn.BackgroundTransparency = 0
            tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            if topBrackets then topBrackets.Visible = true end
        else
            tabBtn.BackgroundColor3 = Color3.fromRGB(20, 32, 26)
            tabBtn.BackgroundTransparency = 1
            tabBtn.TextColor3 = Color3.fromRGB(120, 142, 130)
            if topBrackets then topBrackets.Visible = false end
        end
    end
end

for i, catName in ipairs(categories) do
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. catName
    btn.Parent = tabContainer
    btn.Size = UDim2.new(0, 140, 1, 0)
    btn.Text = catName
    btn.Font = Enum.Font.Arcade
    btn.TextSize = 17
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = i
    btn.ZIndex = 12

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 4)
    tabCorner.Parent = btn

    local topBrackets = Instance.new("Frame")
    topBrackets.Name = "TopBrackets"
    topBrackets.Size = UDim2.new(1, 0, 1, 0)
    topBrackets.BackgroundTransparency = 1
    topBrackets.ZIndex = 13
    topBrackets.Visible = false
    topBrackets.Parent = btn

    local function part(anchor, pos, w, h)
        local p = Instance.new("Frame")
        p.BackgroundColor3 = Color3.fromRGB(220, 235, 225)
        p.BorderSizePixel = 0
        p.AnchorPoint = anchor
        p.Position = pos
        p.Size = UDim2.new(0, w, 0, h)
        p.ZIndex = 14
        p.Parent = topBrackets
    end
    -- â”Œ
    part(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), 8, 2)
    part(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), 2, 8)
    -- â”
    part(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), 8, 2)
    part(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), 2, 8)

    categoryButtons[catName] = btn

    btn.MouseEnter:Connect(function()
        if btn.TextColor3 ~= Color3.fromRGB(255, 255, 255) then
            TweenService:Create(btn, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(220, 235, 225)}):Play()
        end
    end)

    btn.MouseLeave:Connect(function()
        if btn.TextColor3 ~= Color3.fromRGB(255, 255, 255) then
            TweenService:Create(btn, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(120, 142, 130)}):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        updateCategoryTabs(catName)
        loadCategory(catName)
    end)
end

-- Ä°lk BaÅŸlatma: WEAPONS varsayÄ±lan seÃ§ili gelsin
updateCategoryTabs("WEAPONS")
loadCategory("WEAPONS")
