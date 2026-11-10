-- ============================================================
-- LOBBY UI CONTROLLER (Multi-Map, Difficulty & Room Settings)
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local UIConfig = Config.UI
local Theme = UIConfig.Theme

-- ── Mevcut Remote'lar ───────────────────────────────────────
local Events = ReplicatedStorage:WaitForChild("Events", 10)
if not Events then return end
local LobbyEvents = Events:WaitForChild("LobbyEvents", 10)

local OpenLobbyUI = LobbyEvents:WaitForChild("OpenLobbyUI")
local CreateLobby = LobbyEvents:WaitForChild("CreateLobby")
local UpdateLobbyState = LobbyEvents:WaitForChild("UpdateLobbyState")
local LeaveLobby = LobbyEvents:WaitForChild("LeaveLobby")

-- ── Blur Effect (Hafif tutularak karakterin görünmesi sağlanır) ──
local blurEffect = Lighting:FindFirstChild("LobbyUIBlur") or Instance.new("BlurEffect")
blurEffect.Name = "LobbyUIBlur"
blurEffect.Size = 0
blurEffect.Parent = Lighting

-- ── State ───────────────────────────────────────────────────
local selectedMapIdx = 1
local selectedChallengeIdx = 1
local selectedPlayerCount = 1
local isFriendsOnly = false
local uiVisible = false

local mapCards = {}
local tierRows = {}
local playerBtns = {}

local musicTracks = {"Random", "Forest Theme", "Action Synth", "Chill Ambient"}
local selectedMusicIdx = 1

-- ── Yardımcı UI Fonksiyonları ───────────────────────────────
local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.new(0, 0, 0)
    s.Thickness = thickness or 2
    s.Parent = parent
    return s
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function addTextStroke(parent, thickness)
    local s = Instance.new("UIStroke")
    s.Color = Color3.new(0, 0, 0)
    s.Thickness = thickness or 2
    s.Parent = parent
    return s
end

-- ── UI İnşa Edici ───────────────────────────────────────────
local function buildUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "SolidLobbyUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = PlayerGui

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = sg
    local function updateScale()
        local viewport = workspace.CurrentCamera.ViewportSize
        local scale = math.min(viewport.X / 1600, viewport.Y / 900)
        uiScale.Scale = math.clamp(scale, 0.6, 1.4)
    end
    local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    updateScale()

    -- ============================================================
    -- 1. AŞAMA: HARİTA VE ZORLUK SEÇİM EKRANI
    -- ============================================================
    local selectionContainer = Instance.new("Frame", sg)
    selectionContainer.Name = "SelectionContainer"
    selectionContainer.Size = UDim2.new(1, 0, 1, 0)
    selectionContainer.BackgroundTransparency = 1
    selectionContainer.Visible = false

    -- SOL PANEL (MAP SELECTION)
    local leftPanel = Instance.new("Frame", selectionContainer)
    leftPanel.Name = "MapSelectionPanel"
    leftPanel.AnchorPoint = Vector2.new(0, 0.5)
    leftPanel.Position = UDim2.new(0.04, 0, 0.5, 0)
    leftPanel.Size = UDim2.new(0, 480, 0, 520)
    leftPanel.BackgroundColor3 = Color3.fromRGB(38, 28, 22)
    leftPanel.BorderSizePixel = 0
    addCorner(leftPanel, 10)
    addStroke(leftPanel, Color3.fromRGB(92, 66, 48), 2)

    -- Sol Başlık Çubuğu
    local leftHeader = Instance.new("Frame", leftPanel)
    leftHeader.Size = UDim2.new(1, 0, 0, 46)
    leftHeader.BackgroundColor3 = Color3.fromRGB(50, 36, 28)
    leftHeader.BorderSizePixel = 0
    addCorner(leftHeader, 10)

    -- Alt köşeleri düzeltmek için alt kapatma çizgisi
    local leftHeaderFix = Instance.new("Frame", leftHeader)
    leftHeaderFix.Size = UDim2.new(1, 0, 0, 10)
    leftHeaderFix.Position = UDim2.new(0, 0, 1, -10)
    leftHeaderFix.BackgroundColor3 = Color3.fromRGB(50, 36, 28)
    leftHeaderFix.BorderSizePixel = 0

    local leftTitle = Instance.new("TextLabel", leftHeader)
    leftTitle.Size = UDim2.new(1, -50, 1, 0)
    leftTitle.Position = UDim2.new(0, 16, 0, 0)
    leftTitle.BackgroundTransparency = 1
    leftTitle.Text = "MAP SELECTION"
    leftTitle.TextColor3 = Color3.fromRGB(255, 248, 235)
    leftTitle.Font = Enum.Font.GothamBlack
    leftTitle.TextSize = 18
    leftTitle.TextXAlignment = Enum.TextXAlignment.Left
    addTextStroke(leftTitle, 1.5)

    -- Kapat Butonu [X]
    local closeBtn = Instance.new("TextButton", leftHeader)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 16
    addCorner(closeBtn, 6)
    addStroke(closeBtn, Color3.fromRGB(130, 25, 25), 1.5)

    -- Harita Listesi (Scrollable)
    local mapScroll = Instance.new("ScrollingFrame", leftPanel)
    mapScroll.Name = "MapScroll"
    mapScroll.Size = UDim2.new(1, -16, 1, -54)
    mapScroll.Position = UDim2.new(0, 8, 0, 50)
    mapScroll.BackgroundTransparency = 1
    mapScroll.ScrollBarThickness = 5
    mapScroll.ScrollBarImageColor3 = Color3.fromRGB(115, 84, 60)
    mapScroll.BorderSizePixel = 0

    local mapLayout = Instance.new("UIListLayout", mapScroll)
    mapLayout.FillDirection = Enum.FillDirection.Vertical
    mapLayout.Padding = UDim.new(0, 8)
    mapLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- SAĞ PANEL (DETAILS & TIERS / DIFFICULTY)
    local rightPanel = Instance.new("Frame", selectionContainer)
    rightPanel.Name = "DetailsPanel"
    rightPanel.AnchorPoint = Vector2.new(1, 0.5)
    rightPanel.Position = UDim2.new(0.96, 0, 0.5, 0)
    rightPanel.Size = UDim2.new(0, 420, 0, 520)
    rightPanel.BackgroundColor3 = Color3.fromRGB(38, 28, 22)
    rightPanel.BorderSizePixel = 0
    addCorner(rightPanel, 10)
    addStroke(rightPanel, Color3.fromRGB(92, 66, 48), 2)

    -- Sağ Üst: Seçili Harita Başlık Kartı
    local rightHeader = Instance.new("Frame", rightPanel)
    rightHeader.Size = UDim2.new(1, -24, 0, 104)
    rightHeader.Position = UDim2.new(0, 12, 0, 14)
    rightHeader.BackgroundColor3 = Color3.fromRGB(50, 36, 28)
    rightHeader.BorderSizePixel = 0
    addCorner(rightHeader, 8)
    addStroke(rightHeader, Color3.fromRGB(95, 70, 50), 1.5)

    local miniThumb = Instance.new("ImageLabel", rightHeader)
    miniThumb.Size = UDim2.new(0, 96, 0, 86)
    miniThumb.Position = UDim2.new(0, 9, 0.5, -43)
    miniThumb.BackgroundColor3 = Color3.fromRGB(30, 22, 18)
    miniThumb.ScaleType = Enum.ScaleType.Crop
    addCorner(miniThumb, 6)
    addStroke(miniThumb, Color3.fromRGB(75, 54, 40), 1)

    local mapTitle = Instance.new("TextLabel", rightHeader)
    mapTitle.Size = UDim2.new(1, -120, 0, 36)
    mapTitle.Position = UDim2.new(0, 114, 0, 18)
    mapTitle.BackgroundTransparency = 1
    mapTitle.Text = "Forest"
    mapTitle.TextColor3 = Color3.fromRGB(255, 220, 85)
    mapTitle.Font = Enum.Font.GothamBlack
    mapTitle.TextSize = 28
    mapTitle.TextXAlignment = Enum.TextXAlignment.Left
    addTextStroke(mapTitle, 1.5)

    local tierSubtitle = Instance.new("TextLabel", rightHeader)
    tierSubtitle.Size = UDim2.new(1, -120, 0, 24)
    tierSubtitle.Position = UDim2.new(0, 114, 0, 56)
    tierSubtitle.BackgroundTransparency = 1
    tierSubtitle.Text = "Tier 1 (Easy)"
    tierSubtitle.TextColor3 = Color3.fromRGB(80, 215, 105)
    tierSubtitle.Font = Enum.Font.GothamBold
    tierSubtitle.TextSize = 16
    tierSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    addTextStroke(tierSubtitle, 1)

    -- TIER / ZORLUK SEÇİM LİSTESİ
    local tiersContainer = Instance.new("Frame", rightPanel)
    tiersContainer.Size = UDim2.new(1, -24, 0, 170)
    tiersContainer.Position = UDim2.new(0, 12, 0, 132)
    tiersContainer.BackgroundTransparency = 1

    local tLayout = Instance.new("UIListLayout", tiersContainer)
    tLayout.FillDirection = Enum.FillDirection.Vertical
    tLayout.Padding = UDim.new(0, 10)

    -- Alt Özet Bilgileri (Gümüş Çarpanı)
    local infoBanner = Instance.new("Frame", rightPanel)
    infoBanner.Size = UDim2.new(1, -24, 0, 42)
    infoBanner.Position = UDim2.new(0, 12, 0, 316)
    infoBanner.BackgroundColor3 = Color3.fromRGB(28, 20, 16)
    addCorner(infoBanner, 6)
    addStroke(infoBanner, Color3.fromRGB(75, 54, 40), 1)

    local silverGainText = Instance.new("TextLabel", infoBanner)
    silverGainText.Size = UDim2.new(1, -20, 1, 0)
    silverGainText.Position = UDim2.new(0, 10, 0, 0)
    silverGainText.BackgroundTransparency = 1
    silverGainText.Text = "1.0x Silver Gain"
    silverGainText.TextColor3 = Color3.fromRGB(80, 215, 105)
    silverGainText.Font = Enum.Font.GothamBold
    silverGainText.TextSize = 15
    silverGainText.TextXAlignment = Enum.TextXAlignment.Center
    addTextStroke(silverGainText, 1)

    -- CHALLENGES Butonu
    local challengesBtn = Instance.new("TextButton", rightPanel)
    challengesBtn.Size = UDim2.new(1, -24, 0, 52)
    challengesBtn.Position = UDim2.new(0, 12, 0, 372)
    challengesBtn.BackgroundColor3 = Color3.fromRGB(215, 135, 20)
    challengesBtn.Text = "CHALLENGES"
    challengesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    challengesBtn.Font = Enum.Font.GothamBlack
    challengesBtn.TextSize = 20
    challengesBtn.AutoButtonColor = false
    addCorner(challengesBtn, 8)
    addStroke(challengesBtn, Color3.fromRGB(145, 90, 12), 2)
    addTextStroke(challengesBtn, 1.5)

    -- CONFIRM Butonu
    local confirmBtn = Instance.new("TextButton", rightPanel)
    confirmBtn.Size = UDim2.new(1, -24, 0, 64)
    confirmBtn.Position = UDim2.new(0, 12, 0, 438)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 75)
    confirmBtn.Text = "CONFIRM"
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.Font = Enum.Font.GothamBlack
    confirmBtn.TextSize = 24
    confirmBtn.AutoButtonColor = false
    addCorner(confirmBtn, 8)
    addStroke(confirmBtn, Color3.fromRGB(28, 100, 45), 2.5)
    addTextStroke(confirmBtn, 2)

    confirmBtn.MouseEnter:Connect(function()
        TweenService:Create(confirmBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(65, 180, 90)}):Play()
    end)
    confirmBtn.MouseLeave:Connect(function()
        TweenService:Create(confirmBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(50, 160, 75)}):Play()
    end)

    -- ============================================================
    -- 2. AŞAMA: ODA AYARLARI MODALI (ROOM SETTINGS / PARTY SETUP)
    -- ============================================================
    local roomModal = Instance.new("Frame", sg)
    roomModal.Name = "RoomSettingsModal"
    roomModal.AnchorPoint = Vector2.new(0.5, 0.5)
    roomModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    roomModal.Size = UDim2.new(0, 520, 0, 430)
    roomModal.BackgroundColor3 = Color3.fromRGB(36, 26, 20)
    roomModal.BorderSizePixel = 0
    roomModal.Visible = false
    addCorner(roomModal, 12)
    addStroke(roomModal, Color3.fromRGB(92, 66, 48), 2.5)

    -- Modal Başlık
    local modalHeader = Instance.new("Frame", roomModal)
    modalHeader.Size = UDim2.new(1, 0, 0, 48)
    modalHeader.BackgroundColor3 = Color3.fromRGB(50, 36, 28)
    modalHeader.BorderSizePixel = 0
    addCorner(modalHeader, 12)

    local modalHeaderFix = Instance.new("Frame", modalHeader)
    modalHeaderFix.Size = UDim2.new(1, 0, 0, 10)
    modalHeaderFix.Position = UDim2.new(0, 0, 1, -10)
    modalHeaderFix.BackgroundColor3 = Color3.fromRGB(50, 36, 28)
    modalHeaderFix.BorderSizePixel = 0

    local modalTitle = Instance.new("TextLabel", modalHeader)
    modalTitle.Size = UDim2.new(1, -50, 1, 0)
    modalTitle.Position = UDim2.new(0, 20, 0, 0)
    modalTitle.BackgroundTransparency = 1
    modalTitle.Text = "ROOM CONFIGURATION"
    modalTitle.TextColor3 = Color3.fromRGB(255, 248, 235)
    modalTitle.Font = Enum.Font.GothamBlack
    modalTitle.TextSize = 18
    modalTitle.TextXAlignment = Enum.TextXAlignment.Left
    addTextStroke(modalTitle, 1.5)

    local modalCloseBtn = Instance.new("TextButton", modalHeader)
    modalCloseBtn.Size = UDim2.new(0, 30, 0, 30)
    modalCloseBtn.AnchorPoint = Vector2.new(1, 0.5)
    modalCloseBtn.Position = UDim2.new(1, -12, 0.5, 0)
    modalCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
    modalCloseBtn.Text = "X"
    modalCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    modalCloseBtn.Font = Enum.Font.GothamBlack
    modalCloseBtn.TextSize = 16
    addCorner(modalCloseBtn, 6)
    addStroke(modalCloseBtn, Color3.fromRGB(130, 25, 25), 1.5)

    -- Seçilen Harita & Zorluk Özeti (Badge)
    local summaryChip = Instance.new("Frame", roomModal)
    summaryChip.Size = UDim2.new(1, -40, 0, 34)
    summaryChip.Position = UDim2.new(0, 20, 0, 60)
    summaryChip.BackgroundColor3 = Color3.fromRGB(26, 19, 15)
    addCorner(summaryChip, 6)
    addStroke(summaryChip, Color3.fromRGB(75, 54, 40), 1)

    local summaryText = Instance.new("TextLabel", summaryChip)
    summaryText.Size = UDim2.new(1, -20, 1, 0)
    summaryText.Position = UDim2.new(0, 10, 0, 0)
    summaryText.BackgroundTransparency = 1
    summaryText.Text = "Forest  •  Tier 1 (Easy)  •  1.0x Silver"
    summaryText.TextColor3 = Color3.fromRGB(250, 215, 85)
    summaryText.Font = Enum.Font.GothamBold
    summaryText.TextSize = 13
    summaryText.TextXAlignment = Enum.TextXAlignment.Left
    addTextStroke(summaryText, 1)

    -- Oyuncu Sayısı Seçimi Başlığı
    local playerCountTitle = Instance.new("TextLabel", roomModal)
    playerCountTitle.Size = UDim2.new(1, -40, 0, 20)
    playerCountTitle.Position = UDim2.new(0, 20, 0, 106)
    playerCountTitle.BackgroundTransparency = 1
    playerCountTitle.Text = "PLAYER CAPACITY"
    playerCountTitle.TextColor3 = Color3.fromRGB(215, 190, 165)
    playerCountTitle.Font = Enum.Font.GothamBlack
    playerCountTitle.TextSize = 14
    playerCountTitle.TextXAlignment = Enum.TextXAlignment.Left
    addTextStroke(playerCountTitle, 1)

    local playerRow = Instance.new("Frame", roomModal)
    playerRow.Size = UDim2.new(1, -40, 0, 80)
    playerRow.Position = UDim2.new(0, 20, 0, 132)
    playerRow.BackgroundTransparency = 1

    local pLayout = Instance.new("UIListLayout", playerRow)
    pLayout.FillDirection = Enum.FillDirection.Horizontal
    pLayout.Padding = UDim.new(0, 10)
    pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local roleNames = {"SOLO", "DUO", "TRIO", "SQUAD"}

    local function selectPlayerCount(idx)
        selectedPlayerCount = UIConfig.PlayerOptions[idx] or idx
        for i, btn in ipairs(playerBtns) do
            local isSel = (i == idx)
            btn.BackgroundColor3 = isSel and Color3.fromRGB(50, 160, 75) or Color3.fromRGB(45, 33, 26)
            local s = btn:FindFirstChildOfClass("UIStroke")
            if s then
                s.Color = isSel and Color3.fromRGB(28, 100, 45) or Color3.fromRGB(80, 58, 44)
                s.Thickness = isSel and 2.5 or 1.5
            end
            local lbl = btn:FindFirstChild("RoleLbl")
            if lbl then
                lbl.TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(195, 175, 155)
            end
        end
    end

    for i, count in ipairs(UIConfig.PlayerOptions) do
        local btn = Instance.new("TextButton", playerRow)
        btn.Size = UDim2.new(0, 112, 0, 78)
        btn.BackgroundColor3 = Color3.fromRGB(45, 33, 26)
        btn.Text = ""
        btn.AutoButtonColor = false
        addCorner(btn, 8)
        addStroke(btn, Color3.fromRGB(80, 58, 44), 1.5)

        local num = Instance.new("TextLabel", btn)
        num.Size = UDim2.new(1, 0, 0, 34)
        num.Position = UDim2.new(0, 0, 0, 10)
        num.BackgroundTransparency = 1
        num.Text = tostring(count)
        num.TextColor3 = Color3.fromRGB(255, 255, 255)
        num.Font = Enum.Font.GothamBlack
        num.TextSize = 28
        addTextStroke(num, 1.5)

        local role = Instance.new("TextLabel", btn)
        role.Name = "RoleLbl"
        role.Size = UDim2.new(1, 0, 0, 18)
        role.Position = UDim2.new(0, 0, 0, 48)
        role.BackgroundTransparency = 1
        role.Text = roleNames[i] or ("P" .. count)
        role.TextColor3 = Color3.fromRGB(195, 175, 155)
        role.Font = Enum.Font.GothamBold
        role.TextSize = 13
        addTextStroke(role, 1)

        playerBtns[i] = btn
        btn.Activated:Connect(function()
            selectPlayerCount(i)
        end)
    end

    -- SADECE ARKADAŞLAR (FRIENDS ONLY) TOGGLE KARTI
    local friendsCard = Instance.new("Frame", roomModal)
    friendsCard.Size = UDim2.new(1, -40, 0, 68)
    friendsCard.Position = UDim2.new(0, 20, 0, 226)
    friendsCard.BackgroundColor3 = Color3.fromRGB(26, 19, 15)
    addCorner(friendsCard, 8)
    local friendsCardStroke = addStroke(friendsCard, Color3.fromRGB(75, 54, 40), 1.5)

    local fTitle = Instance.new("TextLabel", friendsCard)
    fTitle.Size = UDim2.new(1, -140, 0, 20)
    fTitle.Position = UDim2.new(0, 18, 0, 14)
    fTitle.BackgroundTransparency = 1
    fTitle.Text = "FRIENDS ONLY LOBBY"
    fTitle.TextColor3 = Color3.fromRGB(250, 240, 225)
    fTitle.Font = Enum.Font.GothamBlack
    fTitle.TextSize = 15
    fTitle.TextXAlignment = Enum.TextXAlignment.Left
    addTextStroke(fTitle, 1)

    local fSub = Instance.new("TextLabel", friendsCard)
    fSub.Size = UDim2.new(1, -140, 0, 16)
    fSub.Position = UDim2.new(0, 18, 0, 36)
    fSub.BackgroundTransparency = 1
    fSub.Text = "Only your Roblox friends can join this pad."
    fSub.TextColor3 = Color3.fromRGB(190, 170, 150)
    fSub.Font = Enum.Font.GothamMedium
    fSub.TextSize = 12
    fSub.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", friendsCard)
    toggleBtn.Size = UDim2.new(0, 96, 0, 36)
    toggleBtn.AnchorPoint = Vector2.new(1, 0.5)
    toggleBtn.Position = UDim2.new(1, -14, 0.5, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(52, 40, 32)
    toggleBtn.Text = "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(195, 175, 155)
    toggleBtn.Font = Enum.Font.GothamBlack
    toggleBtn.TextSize = 15
    toggleBtn.AutoButtonColor = false
    addCorner(toggleBtn, 18)
    local toggleStroke = addStroke(toggleBtn, Color3.fromRGB(80, 60, 46), 1.5)

    local function updateFriendsToggle()
        if isFriendsOnly then
            toggleBtn.Text = "ON"
            toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 75)
            toggleStroke.Color = Color3.fromRGB(28, 100, 45)
            friendsCardStroke.Color = Color3.fromRGB(50, 160, 75)
        else
            toggleBtn.Text = "OFF"
            toggleBtn.TextColor3 = Color3.fromRGB(195, 175, 155)
            toggleBtn.BackgroundColor3 = Color3.fromRGB(52, 40, 32)
            toggleStroke.Color = Color3.fromRGB(80, 60, 46)
            friendsCardStroke.Color = Color3.fromRGB(75, 54, 40)
        end
    end

    toggleBtn.Activated:Connect(function()
        isFriendsOnly = not isFriendsOnly
        updateFriendsToggle()
    end)

    -- Alt Butonlar: GERİ ve CREATE ROOM
    local backBtn = Instance.new("TextButton", roomModal)
    backBtn.Size = UDim2.new(0, 130, 0, 52)
    backBtn.Position = UDim2.new(0, 20, 1, -66)
    backBtn.BackgroundColor3 = Color3.fromRGB(55, 42, 34)
    backBtn.Text = "< BACK"
    backBtn.TextColor3 = Color3.fromRGB(235, 220, 205)
    backBtn.Font = Enum.Font.GothamBlack
    backBtn.TextSize = 16
    addCorner(backBtn, 8)
    addStroke(backBtn, Color3.fromRGB(85, 65, 50), 1.5)

    local startRoomBtn = Instance.new("TextButton", roomModal)
    startRoomBtn.Size = UDim2.new(1, -190, 0, 52)
    startRoomBtn.AnchorPoint = Vector2.new(1, 0)
    startRoomBtn.Position = UDim2.new(1, -20, 1, -66)
    startRoomBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 75)
    startRoomBtn.Text = "START ROOM >"
    startRoomBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    startRoomBtn.Font = Enum.Font.GothamBlack
    startRoomBtn.TextSize = 20
    addCorner(startRoomBtn, 8)
    addStroke(startRoomBtn, Color3.fromRGB(28, 100, 45), 2.5)
    addTextStroke(startRoomBtn, 2)

    -- ============================================================
    -- SEÇİM GÜNCELLEME LOJİĞİ
    -- ============================================================
    local function updateDetailsPanel()
        local mapData = UIConfig.Maps[selectedMapIdx]
        local challData = UIConfig.Challenges[selectedChallengeIdx]

        if mapData then
            mapTitle.Text = mapData.Name
            if mapData.Image and mapData.Image ~= "" then
                miniThumb.Image = mapData.Image
                miniThumb.Visible = true
            else
                miniThumb.Image = ""
            end
        end

        if challData then
            local tierColor = challData.Color or Color3.fromRGB(80, 215, 105)
            tierSubtitle.Text = string.format("%s (%s)", challData.Name or "Tier", challData.DifficultyTitle or "EASY")
            tierSubtitle.TextColor3 = tierColor
            silverGainText.Text = string.format("%s Silver Gain", challData.RewardText or "1.0x")
            silverGainText.TextColor3 = tierColor
        end

        -- Modal chip özeti
        if mapData and challData then
            summaryText.Text = string.format("%s  •  %s (%s)  •  %s Silver",
                mapData.Name, challData.Name, challData.DifficultyTitle or "EASY", challData.RewardText or "1.0x")
        end
    end

    -- ============================================================
    -- 3D SAHNE & KAMERA KONTROLÜ (MAP SHOWCASE CAMERA)
    -- ============================================================
    local camera = workspace.CurrentCamera
    local showcaseDummy = nil

    local function cleanupDummy()
        if showcaseDummy then
            showcaseDummy:Destroy()
            showcaseDummy = nil
        end
    end

    local function spawnShowcaseDummy(charSpot, camPart)
        cleanupDummy()

        local char = LocalPlayer.Character
        if not char then return end

        char.Archivable = true
        local dummy = char:Clone()
        char.Archivable = false

        dummy.Name = "ShowcaseDummy"

        local humanoid = dummy:FindFirstChildOfClass("Humanoid")
        local rootPart = dummy:FindFirstChild("HumanoidRootPart") or dummy.PrimaryPart
        if not rootPart or not humanoid then
            dummy:Destroy()
            return
        end

        dummy.PrimaryPart = rootPart

        -- 1. Raycast ile Zemin Yüksekliğini Kesin Olarak Bul
        local rayOrigin = charSpot.Position + Vector3.new(0, 50, 0)
        local rayDirection = Vector3.new(0, -100, 0)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char, dummy}

        local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
        local hitY = rayResult and rayResult.Position.Y
        local spotTopY = charSpot.Position.Y + (charSpot.Size.Y / 2)
        -- En yüksek zemini baz al (böylece charSpot'tan veya altındaki zeminden asla aşağı düşemez)
        local groundY = hitY and math.max(hitY, spotTopY) or spotTopY

        -- 2. Ayak Tabanından HumanoidRootPart Merkezine Mesafeyi Hesapla
        local leftLeg = dummy:FindFirstChild("Left Leg") or dummy:FindFirstChild("LeftFoot")
        local rightLeg = dummy:FindFirstChild("Right Leg") or dummy:FindFirstChild("RightFoot")
        local footPart = leftLeg or rightLeg
        local footOffset = 3.0 -- R6 standart ayak mesafesi

        if footPart then
            local footBottom = footPart.Position.Y - (footPart.Size.Y / 2)
            local measured = rootPart.Position.Y - footBottom
            if measured > 1.5 and measured < 5 then
                footOffset = measured
            end
        elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
            local hHeight = humanoid.HipHeight > 0 and humanoid.HipHeight or 2.0
            footOffset = hHeight + (rootPart.Size.Y / 2)
        end

        -- Ayak tabanının zeminin tam üstüne basması için +0.1 stud pay
        local targetY = groundY + footOffset + 0.1
        local targetPos = Vector3.new(charSpot.Position.X, targetY, charSpot.Position.Z)

        -- 3. Karakterin Yüzünü KAMERAYA Doğru Çevir
        local dirToCam = Vector3.new(camPart.Position.X - targetPos.X, 0, camPart.Position.Z - targetPos.Z)
        local lookCFrame = nil
        if dirToCam.Magnitude > 0.1 then
            lookCFrame = CFrame.lookAt(targetPos, targetPos + dirToCam)
        else
            lookCFrame = CFrame.new(targetPos) * (charSpot.CFrame - charSpot.Position)
        end

        -- 4. Klonlandığı Andaki Koşma/Yürüme Pozunu Sıfırla (Doğal Duruşa Getir)
        for _, motor in ipairs(dummy:GetDescendants()) do
            if motor:IsA("Motor6D") then
                motor.Transform = CFrame.new()
            end
        end

        -- Parçaları ayarla: Sadece rootPart sabitlenir, bacakların aşağı sarkmaması için PlatformStand açılır
        for _, child in ipairs(dummy:GetDescendants()) do
            if child:IsA("LocalScript") or child:IsA("Script") then
                child:Destroy()
            elseif child:IsA("BasePart") then
                child.CanCollide = false
                if child == rootPart then
                    child.Anchored = true
                else
                    child.Anchored = false
                end
            end
        end

        dummy:PivotTo(lookCFrame)
        dummy.Parent = workspace
        showcaseDummy = dummy

        -- 5. Humanoid Ayarları ve Canlı Idle Animasyonu
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.PlatformStand = true -- Fiziğin bacakları yere çekmesini engeller

        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

        for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
            t:Stop(0)
        end

        -- Standart Roblox Idle animasyonunu yükle ve döngüde oynat
        local idleAnim = Instance.new("Animation")
        if humanoid.RigType == Enum.HumanoidRigType.R15 then
            idleAnim.AnimationId = "rbxassetid://507766388"
        else
            idleAnim.AnimationId = "rbxassetid://180435571"
        end

        local track = animator:LoadAnimation(idleAnim)
        track.Looped = true
        track.Priority = Enum.AnimationPriority.Action4
        track:Play(0.1)

        return dummy
    end

    local function findCameraForMap(mapId)
        if not mapId then return nil end
        -- 1. Workspace.MapCameras klasörü altında ara
        local mapCams = workspace:FindFirstChild("MapCameras")
        if mapCams then
            local cam = mapCams:FindFirstChild(mapId) or mapCams:FindFirstChild(mapId .. "Cam") or mapCams:FindFirstChild(mapId .. "_Camera")
            if cam and cam:IsA("BasePart") then return cam end
        end
        -- 2. Workspace.MapShowcases klasörü altında ara
        local mapShowcases = workspace:FindFirstChild("MapShowcases")
        if mapShowcases then
            local showcase = mapShowcases:FindFirstChild(mapId)
            if showcase then
                local cam = showcase:FindFirstChild("Camera") or showcase:FindFirstChild("CameraPart") or showcase:FindFirstChild("Cam")
                if cam and cam:IsA("BasePart") then return cam end
            end
        end
        -- 3. Workspace'te doğrudan ara
        local directCam = workspace:FindFirstChild(mapId .. "Cam") or workspace:FindFirstChild(mapId .. "_Camera")
        if directCam and directCam:IsA("BasePart") then return directCam end
        return nil
    end

    local function findCharacterSpotForMap(mapId)
        if not mapId then return nil end
        local mapShowcases = workspace:FindFirstChild("MapShowcases")
        if mapShowcases then
            local showcase = mapShowcases:FindFirstChild(mapId)
            if showcase then
                local spot = showcase:FindFirstChild("CharacterSpot") or showcase:FindFirstChild("PlayerSpot") or showcase:FindFirstChild("Spot")
                if spot and spot:IsA("BasePart") then return spot end
            end
        end
        local mapCams = workspace:FindFirstChild("MapCameras")
        if mapCams then
            local spot = mapCams:FindFirstChild(mapId .. "_CharacterSpot") or mapCams:FindFirstChild(mapId .. "Spot")
            if spot and spot:IsA("BasePart") then return spot end
        end
        return nil
    end

    local function applyCameraForMap(mapId)
        local camPart = findCameraForMap(mapId)
        if not camPart then return end

        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = camPart.CFrame

        -- Gerçek oyuncuyu ışınlamak yerine, sahnede oyuncunun bir klonunu (ShowcaseDummy) oluştur
        local charSpot = findCharacterSpotForMap(mapId)
        if charSpot then
            spawnShowcaseDummy(charSpot, camPart)
        else
            cleanupDummy()
        end
    end

    local function restoreCamera()
        cleanupDummy()
        camera.CameraType = Enum.CameraType.Custom
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            camera.CameraSubject = char.Humanoid
        end
    end

    local function selectMap(idx, force)
        if selectedMapIdx == idx and not force then
            return
        end
        selectedMapIdx = idx
        for i, card in ipairs(mapCards) do
            local isSel = (i == idx)
            card.BackgroundColor3 = isSel and Color3.fromRGB(70, 50, 36) or Color3.fromRGB(45, 33, 26)
            local s = card:FindFirstChildOfClass("UIStroke")
            if s then
                s.Color = isSel and Color3.fromRGB(235, 175, 55) or Color3.fromRGB(80, 58, 44)
                s.Thickness = isSel and 2.5 or 1.5
            end
        end
        updateDetailsPanel()

        local mapData = UIConfig.Maps[idx]
        if mapData and uiVisible then
            applyCameraForMap(mapData.Id)
        end
    end

    local function isChallengeUnlocked(idx)
        local chData = UIConfig.Challenges[idx]
        if not chData then return false end
        if chData.Id == "Easy" or chData.Tier == 1 or chData.DifficultyTitle == "EASY" then
            return true
        elseif chData.Id == "Medium" or chData.Tier == 2 or chData.DifficultyTitle == "NORMAL" then
            return LocalPlayer:GetAttribute("DifficultyUnlocked_Medium") == true
        elseif chData.Id == "Hard" or chData.Tier == 3 or chData.DifficultyTitle == "HARD" then
            return LocalPlayer:GetAttribute("DifficultyUnlocked_Hard") == true
        end
        return true
    end

    local function selectChallenge(idx, force)
        if not isChallengeUnlocked(idx) then
            idx = 1
        end
        if selectedChallengeIdx == idx and not force then
            return
        end
        selectedChallengeIdx = idx

        for i, row in ipairs(tierRows) do
            local chall = UIConfig.Challenges[i]
            local unlocked = isChallengeUnlocked(i)
            local isSel = (i == selectedChallengeIdx) and unlocked
            local cColor = chall and chall.Color or Color3.fromRGB(80, 215, 105)

            local check = row:FindFirstChild("CheckBox", true)
            local tName = row:FindFirstChild("TierName")
            local rwd = row:FindFirstChild("RewardLabel")
            local checkmarkRight = row:FindFirstChild("RightCheck")
            local s = row:FindFirstChildOfClass("UIStroke")

            if not unlocked then
                row.BackgroundColor3 = Color3.fromRGB(28, 20, 16)
                if s then
                    s.Color = Color3.fromRGB(55, 40, 32)
                    s.Thickness = 1
                end
                if check then
                    check.Text = "🔒"
                    check.TextColor3 = Color3.fromRGB(160, 130, 110)
                    check.BackgroundColor3 = Color3.fromRGB(22, 16, 13)
                end
                if tName then
                    local req = (chall.Id == "Medium" or chall.DifficultyTitle == "NORMAL") and "(Beat Easy)" or "(Beat Normal)"
                    tName.Text = string.format("%s %s", chall.DifficultyTitle or "TIER", req)
                    tName.TextColor3 = Color3.fromRGB(150, 120, 100)
                end
                if rwd then
                    rwd.Text = "LOCKED"
                    rwd.TextColor3 = Color3.fromRGB(195, 85, 85)
                end
                if checkmarkRight then
                    checkmarkRight.Visible = false
                end
            else
                row.BackgroundColor3 = isSel and Color3.fromRGB(65, 46, 32) or Color3.fromRGB(42, 31, 24)
                if s then
                    s.Color = isSel and cColor or Color3.fromRGB(75, 54, 40)
                    s.Thickness = isSel and 2 or 1
                end
                if check then
                    check.Text = isSel and "✓" or ""
                    check.TextColor3 = cColor
                    check.BackgroundColor3 = isSel and Color3.fromRGB(52, 38, 28) or Color3.fromRGB(26, 19, 15)
                end
                if tName then
                    tName.Text = string.format("%s (%s)", chall.Name or "Tier", chall.DifficultyTitle or "EASY")
                    tName.TextColor3 = chall.Color or Color3.fromRGB(255, 255, 255)
                end
                if rwd then
                    rwd.Text = (chall.RewardText or "1.0x") .. " Silver"
                    rwd.TextColor3 = Color3.fromRGB(245, 215, 160)
                end
                if checkmarkRight then
                    checkmarkRight.Visible = isSel
                    checkmarkRight.TextColor3 = cColor
                end
            end
        end
        updateDetailsPanel()
    end

    -- Harita Kartlarını Oluştur
    for i, mapData in ipairs(UIConfig.Maps) do
        local card = Instance.new("TextButton", mapScroll)
        card.Name = "MapCard_" .. mapData.Name
        card.Size = UDim2.new(1, -6, 0, 144)
        card.BackgroundColor3 = Color3.fromRGB(45, 33, 26)
        card.Text = ""
        card.AutoButtonColor = false
        card.ClipsDescendants = true
        addCorner(card, 8)
        addStroke(card, Color3.fromRGB(80, 58, 44), 1.5)

        -- Sol Thumbnail (Genişletildi ve Büyütüldü: 216x100)
        local thumb = Instance.new("ImageLabel", card)
        thumb.Size = UDim2.new(0, 216, 0, 100)
        thumb.Position = UDim2.new(0, 10, 0, 8)
        thumb.BackgroundColor3 = Color3.fromRGB(30, 22, 18)
        thumb.ScaleType = Enum.ScaleType.Crop
        addCorner(thumb, 6)
        addStroke(thumb, Color3.fromRGB(75, 54, 40), 1)

        if mapData.Image and mapData.Image ~= "" then
            thumb.Image = mapData.Image
        else
            thumb.Image = ""
            thumb.BackgroundColor3 = Color3.fromRGB(48, 36, 26)
            local placeholder = Instance.new("TextLabel", thumb)
            placeholder.Size = UDim2.new(1, 0, 1, 0)
            placeholder.BackgroundTransparency = 1
            placeholder.Text = "COMING SOON"
            placeholder.TextColor3 = Color3.fromRGB(180, 145, 115)
            placeholder.Font = Enum.Font.GothamBold
            placeholder.TextSize = 16
        end

        -- Thumbnail Altı İsim Şeridi (Görselle tam hizalı: 216px)
        local nameTag = Instance.new("Frame", card)
        nameTag.Size = UDim2.new(0, 216, 0, 26)
        nameTag.Position = UDim2.new(0, 10, 0, 110)
        nameTag.BackgroundColor3 = Color3.fromRGB(24, 17, 13)
        addCorner(nameTag, 4)

        local nameLabel = Instance.new("TextLabel", nameTag)
        nameLabel.Size = UDim2.new(1, 0, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = mapData.Name
        nameLabel.TextColor3 = Color3.fromRGB(255, 248, 235)
        nameLabel.Font = Enum.Font.GothamBlack
        nameLabel.TextSize = 15
        addTextStroke(nameLabel, 1)

        -- Sağ Açıklama (Yeni görsel genişliğine göre hizalandı)
        local descLabel = Instance.new("TextLabel", card)
        descLabel.Size = UDim2.new(1, -250, 1, -24)
        descLabel.Position = UDim2.new(0, 238, 0, 12)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = mapData.Description or ""
        descLabel.TextColor3 = Color3.fromRGB(235, 222, 205)
        descLabel.Font = Enum.Font.GothamMedium
        descLabel.TextSize = 14
        descLabel.TextWrapped = true
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        addTextStroke(descLabel, 1)

        mapCards[i] = card
        card.Activated:Connect(function()
            if selectedMapIdx == i then
                return
            end
            selectMap(i)
        end)
    end

    mapScroll.CanvasSize = UDim2.new(0, 0, 0, #UIConfig.Maps * 152 + 10)

    -- Tier / Zorluk Satırlarını Oluştur
    for i, chData in ipairs(UIConfig.Challenges) do
        local row = Instance.new("TextButton", tiersContainer)
        row.Name = "TierRow_" .. tostring(chData.Name)
        row.Size = UDim2.new(1, 0, 0, 50)
        row.BackgroundColor3 = Color3.fromRGB(42, 31, 24)
        row.Text = ""
        row.AutoButtonColor = false
        addCorner(row, 6)
        addStroke(row, Color3.fromRGB(75, 54, 40), 1)

        -- CheckBox (Kare)
        local cb = Instance.new("TextLabel", row)
        cb.Name = "CheckBox"
        cb.Size = UDim2.new(0, 26, 0, 26)
        cb.Position = UDim2.new(0, 12, 0.5, -13)
        cb.BackgroundColor3 = Color3.fromRGB(26, 19, 15)
        cb.Text = ""
        cb.Font = Enum.Font.GothamBlack
        cb.TextSize = 16
        addCorner(cb, 4)
        addStroke(cb, Color3.fromRGB(80, 58, 44), 1)

        -- Tier İsmi
        local tName = Instance.new("TextLabel", row)
        tName.Name = "TierName"
        tName.Size = UDim2.new(0, 150, 1, 0)
        tName.Position = UDim2.new(0, 48, 0, 0)
        tName.BackgroundTransparency = 1
        tName.Text = string.format("%s (%s)", chData.Name or "Tier", chData.DifficultyTitle or "EASY")
        tName.TextColor3 = chData.Color or Color3.fromRGB(255, 255, 255)
        tName.Font = Enum.Font.GothamBold
        tName.TextSize = 15
        tName.TextXAlignment = Enum.TextXAlignment.Left
        addTextStroke(tName, 1)

        -- Gümüş Çarpanı
        local rwd = Instance.new("TextLabel", row)
        rwd.Name = "RewardLabel"
        rwd.Size = UDim2.new(0, 95, 1, 0)
        rwd.Position = UDim2.new(1, -125, 0, 0)
        rwd.BackgroundTransparency = 1
        rwd.Text = (chData.RewardText or "1.0x") .. " Silver"
        rwd.TextColor3 = Color3.fromRGB(245, 215, 160)
        rwd.Font = Enum.Font.GothamBold
        rwd.TextSize = 13
        rwd.TextXAlignment = Enum.TextXAlignment.Right
        addTextStroke(rwd, 1)

        -- Sağ Onay İkonu
        local rightCheck = Instance.new("TextLabel", row)
        rightCheck.Name = "RightCheck"
        rightCheck.Size = UDim2.new(0, 24, 1, 0)
        rightCheck.Position = UDim2.new(1, -28, 0, 0)
        rightCheck.BackgroundTransparency = 1
        rightCheck.Text = "✓"
        rightCheck.TextColor3 = chData.Color or Color3.fromRGB(80, 215, 105)
        rightCheck.Font = Enum.Font.GothamBlack
        rightCheck.TextSize = 16
        rightCheck.Visible = false
        addTextStroke(rightCheck, 1)

        tierRows[i] = row
        row.Activated:Connect(function()
            if not isChallengeUnlocked(i) then
                TweenService:Create(row, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true), {
                    Position = UDim2.new(0, 4, row.Position.Y.Scale, row.Position.Y.Offset)
                }):Play()
                return
            end
            if selectedChallengeIdx == i then
                return
            end
            selectChallenge(i)
        end)
    end

    -- Dinamik Kilit Güncellemesi: Oyuncu Easy veya Normal'i kazandığında anında satırları tazele
    LocalPlayer:GetAttributeChangedSignal("DifficultyUnlocked_Medium"):Connect(function()
        selectChallenge(selectedChallengeIdx, true)
    end)
    LocalPlayer:GetAttributeChangedSignal("DifficultyUnlocked_Hard"):Connect(function()
        selectChallenge(selectedChallengeIdx, true)
    end)

    -- İlk Seçimleri Uygula
    selectMap(1, true)
    selectChallenge(1, true)
    selectPlayerCount(1)
    updateFriendsToggle()

    -- ============================================================
    -- 3. AŞAMA: GERİ SAYIM / BEKLEME PANELİ (INFO FRAME)
    -- ============================================================
    local infoFrame = Instance.new("Frame", sg)
    infoFrame.Size = UDim2.new(0, 320, 0, 140)
    infoFrame.Position = UDim2.new(0.5, -160, 0.1, 0)
    infoFrame.BackgroundColor3 = Theme.Background
    infoFrame.Visible = false
    addCorner(infoFrame, 10)
    addStroke(infoFrame, Theme.PanelBorder, 3)

    local infoText = Instance.new("TextLabel", infoFrame)
    infoText.Size = UDim2.new(1, 0, 0.6, 0)
    infoText.BackgroundTransparency = 1
    infoText.Text = "Waiting for players..."
    infoText.TextColor3 = Theme.ButtonSelected
    infoText.Font = Enum.Font.GothamBlack
    infoText.TextSize = 22
    addTextStroke(infoText, 2)

    local leaveBtn = Instance.new("TextButton", infoFrame)
    leaveBtn.Size = UDim2.new(0.8, 0, 0.28, 0)
    leaveBtn.Position = UDim2.new(0.5, 0, 0.8, 0)
    leaveBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    leaveBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    leaveBtn.Font = Enum.Font.GothamBlack
    leaveBtn.Text = "LEAVE LOBBY"
    leaveBtn.TextColor3 = Theme.TextColor
    leaveBtn.TextSize = 16
    addCorner(leaveBtn, 6)
    addStroke(leaveBtn, Theme.ButtonBorder, 2)

    -- ============================================================
    -- GEÇİŞ VE KAPATMA FONKSİYONLARI
    -- ============================================================
    local function closeAllAnim()
        selectionContainer.Visible = false
        roomModal.Visible = false
        uiVisible = false
        blurEffect.Size = 0
        restoreCamera()

        local sidebarUI = PlayerGui:FindFirstChild("SidebarUI")
        local sidebarContainer = sidebarUI and sidebarUI:FindFirstChild("SidebarContainer")
        if sidebarContainer then
            sidebarContainer.Visible = true
        end
    end

    local function closeOtherLobbyUIs()
        if typeof(_G.CloseBloxBongShopUI) == "function" then _G.CloseBloxBongShopUI() end
        if typeof(_G.CloseBloxBongIndexUI) == "function" then _G.CloseBloxBongIndexUI() end
        if typeof(_G.CloseBloxBongClassUI) == "function" then _G.CloseBloxBongClassUI() end
        if typeof(_G.CloseBloxBongSettingsUI) == "function" then _G.CloseBloxBongSettingsUI() end
    end

    local function openLobbyAnim()
        closeOtherLobbyUIs()
        selectionContainer.Visible = true
        roomModal.Visible = false
        uiVisible = true
        blurEffect.Size = 4 -- Hafif tutulur, karakter net görünür

        selectMap(selectedMapIdx, true)
        selectChallenge(selectedChallengeIdx, true)

        local sidebarUI = PlayerGui:FindFirstChild("SidebarUI")
        local sidebarContainer = sidebarUI and sidebarUI:FindFirstChild("SidebarContainer")
        if sidebarContainer then
            sidebarContainer.Visible = false
        end

        -- Panel giriş animasyonu
        leftPanel.Position = UDim2.new(0, -500, 0.5, 0)
        rightPanel.Position = UDim2.new(1, 450, 0.5, 0)
        TweenService:Create(leftPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.04, 0, 0.5, 0)
        }):Play()
        TweenService:Create(rightPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.96, 0, 0.5, 0)
        }):Play()
    end

    -- [X] Kapatma Butonları
    closeBtn.Activated:Connect(function()
        LeaveLobby:FireServer()
        closeAllAnim()
    end)
    modalCloseBtn.Activated:Connect(function()
        LeaveLobby:FireServer()
        closeAllAnim()
    end)

    -- CONFIRM Butonu -> 2. Aşamaya (Room Settings) Geçiş
    confirmBtn.Activated:Connect(function()
        selectionContainer.Visible = false
        roomModal.Visible = true
        roomModal.Size = UDim2.new(0, 480, 0, 400)
        TweenService:Create(roomModal, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 520, 0, 430)
        }):Play()
    end)

    -- BACK Butonu -> 1. Aşamaya (Harita/Zorluk Seçimine) Geri Dönüş
    backBtn.Activated:Connect(function()
        roomModal.Visible = false
        selectionContainer.Visible = true
    end)

    -- START ROOM Butonu -> Lobi Sunucusuna Odayı Başlatma İsteği Gönder
    startRoomBtn.Activated:Connect(function()
        local selectedMap = UIConfig.Maps[selectedMapIdx]
        local mapId = selectedMap and selectedMap.Id or "Forest"
        local challenge = UIConfig.Challenges[selectedChallengeIdx]
        local challengeId = challenge and (challenge.Id or challenge.DifficultyTitle) or "Easy"

        CreateLobby:FireServer(selectedPlayerCount, mapId, challengeId, isFriendsOnly)
        closeAllAnim()
    end)

    leaveBtn.Activated:Connect(function()
        LeaveLobby:FireServer()
        infoFrame.Visible = false
        local sidebarUI = PlayerGui:FindFirstChild("SidebarUI")
        local sidebarContainer = sidebarUI and sidebarUI:FindFirstChild("SidebarContainer")
        if sidebarContainer then
            sidebarContainer.Visible = true
        end
    end)

    return {
        open = openLobbyAnim,
        close = closeAllAnim,
        infoFrame = infoFrame,
        infoText = infoText
    }
end

local ui = buildUI()

_G.CloseBloxBongLobbyUI = function()
    if uiVisible then
        ui.close()
    end
end

-- ── Event Dinleyicileri ─────────────────────────────────────
OpenLobbyUI.OnClientEvent:Connect(function()
    if not uiVisible then ui.open() end
end)

UpdateLobbyState.OnClientEvent:Connect(function(countdown, current, max)
    local sidebarUI = PlayerGui:FindFirstChild("SidebarUI")
    local sidebarContainer = sidebarUI and sidebarUI:FindFirstChild("SidebarContainer")
    
    if current == 0 then
        ui.infoFrame.Visible = false
        if sidebarContainer then
            sidebarContainer.Visible = true
        end
        return
    end
    
    -- Eğer oda kurulduysa veya başkasına katılıyorsak ayar panellerini kapat
    if uiVisible then
        ui.close()
    end
    
    if sidebarContainer then
        sidebarContainer.Visible = false
    end
    
    ui.infoFrame.Visible = true
    if countdown == -1 then
        ui.infoText.Text = "TELEPORTING..."
    else
        ui.infoText.Text = "Players: " .. current .. "/" .. max .. "\nStarting in: " .. countdown .. "s"
    end
end)

-- ── Zone Algılama ───────────────────────────────────────────
local lobbyZone = workspace:FindFirstChild("LobbyZone")
if lobbyZone then
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart  = character:WaitForChild("HumanoidRootPart")

    RunService.Heartbeat:Connect(function()
        if not rootPart or not rootPart.Parent then return end
        local dist = (rootPart.Position - lobbyZone.Position).Magnitude
        local inside = dist < (lobbyZone.Size.X / 2 + 4)
        
        if inside and not uiVisible and not ui.infoFrame.Visible then
            ui.open()
        elseif not inside and uiVisible then
            ui.close()
        end
    end)
end
