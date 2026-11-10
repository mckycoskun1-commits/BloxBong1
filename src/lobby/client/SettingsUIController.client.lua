-- ============================================================
-- SETTINGS UI CONTROLLER (Ayarlar & Reset Index Sistemi)
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local SettingsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsConfig"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))
local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundConfig"))

-- Remote Events
local Events = ReplicatedStorage:WaitForChild("Events", 10)
local ResetIndexProgression = Events and Events:WaitForChild("ResetIndexProgression", 5)
local ResetIndexResult = Events and Events:WaitForChild("ResetIndexResult", 5)

-- State
local settings = {
    MasterVolume = 100,
    MusicVolume = 80,
    SFXVolume = 100,
    Muted = false,
    ScreenShake = true,
    ShowDamageNumbers = true,
    AimAssist = true,
    AimAssistStrength = 60,
    SmartAim = true,
}

LocalPlayer:SetAttribute("AimAssistEnabled", settings.AimAssist)
LocalPlayer:SetAttribute("AimAssistStrength", settings.AimAssistStrength)
LocalPlayer:SetAttribute("SmartAimEnabled", settings.SmartAim)

local uiOpen = false

-- ── Blur Effect ─────────────────────────────────────────────
local blurEffect = Lighting:FindFirstChild("SettingsBlur") or Instance.new("BlurEffect")
blurEffect.Name = "SettingsBlur"
blurEffect.Size = 0
blurEffect.Parent = Lighting

-- ── Ses Denetim Mantığı (Audio Engine) ────────────────────────
local function isMusicSound(sound)
    local name = string.lower(sound.Name)
    local parentName = sound.Parent and string.lower(sound.Parent.Name) or ""
    if string.find(name, "music") or string.find(name, "bgm") or string.find(name, "song") or string.find(name, "theme") or string.find(name, "background") then
        return true
    end
    if string.find(parentName, "music") or string.find(parentName, "bgm") then
        return true
    end
    if sound.SoundGroup and string.lower(sound.SoundGroup.Name) == "music" then
        return true
    end
    return false
end

local function applyVolumeToSound(sound)
    if not sound:IsA("Sound") then return end
    
    local orig = sound:GetAttribute("OriginalVolume")
    if not orig then
        orig = sound.Volume > 0 and sound.Volume or 0.5
        sound:SetAttribute("OriginalVolume", orig)
    end
    
    if settings.Muted then
        sound.Volume = 0
        return
    end
    
    local isMusic = isMusicSound(sound)
    local typeMult = isMusic and (settings.MusicVolume / 100) or (settings.SFXVolume / 100)
    local masterMult = (settings.MasterVolume / 100)
    
    sound.Volume = math.clamp(orig * masterMult * typeMult, 0, 10)
end

local function updateAllSounds()
    -- workspace içindeki sesler
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Sound") then
            applyVolumeToSound(desc)
        end
    end
    -- SoundService içindeki sesler
    for _, desc in ipairs(SoundService:GetDescendants()) do
        if desc:IsA("Sound") then
            applyVolumeToSound(desc)
        end
    end
end

-- Yeni eklenen sesleri otomatik dinle
workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Sound") then
        task.defer(function()
            applyVolumeToSound(desc)
        end)
    end
end)

SoundService.DescendantAdded:Connect(function(desc)
    if desc:IsA("Sound") then
        task.defer(function()
            applyVolumeToSound(desc)
        end)
    end
end)

-- ── UI Oluşturma ─────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SettingsUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 150
screenGui.Parent = PlayerGui

local uiScale = Instance.new("UIScale")
uiScale.Parent = screenGui
local function updateScale()
    local viewport = workspace.CurrentCamera.ViewportSize
    local scale = math.min(viewport.X / 1600, viewport.Y / 900)
    uiScale.Scale = math.clamp(scale, 0.6, 1.8)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- ── Ekrandaki SETTINGS Butonu (HUD) ─────────────────────────
local settingsBtn = Instance.new("TextButton")
settingsBtn.Name = "OpenSettingsButton"
settingsBtn.Size = UDim2.new(0, 140, 0, 44)
settingsBtn.Position = UDim2.new(0, 24, 0, 24)
settingsBtn.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
settingsBtn.Text = ""
settingsBtn.AutoButtonColor = false
settingsBtn.ZIndex = 10
settingsBtn.Parent = screenGui

local btnCorner = Instance.new("UICorner", settingsBtn)
btnCorner.CornerRadius = UDim.new(0, 10)

local btnStroke = Instance.new("UIStroke", settingsBtn)
btnStroke.Color = Color3.fromRGB(60, 68, 88)
btnStroke.Thickness = 2

local btnLayout = Instance.new("UIListLayout", settingsBtn)
btnLayout.FillDirection = Enum.FillDirection.Horizontal
btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
btnLayout.Padding = UDim.new(0, 8)

local btnIcon = Instance.new("TextLabel", settingsBtn)
btnIcon.Size = UDim2.new(0, 24, 0, 24)
btnIcon.BackgroundTransparency = 1
btnIcon.Text = "⚙️"
btnIcon.TextSize = 20
btnIcon.Font = Enum.Font.GothamBold
btnIcon.TextColor3 = Color3.new(1, 1, 1)
btnIcon.Active = false

local btnText = Instance.new("TextLabel", settingsBtn)
btnText.Size = UDim2.new(0, 80, 0, 24)
btnText.BackgroundTransparency = 1
btnText.Text = "SETTINGS"
btnText.TextSize = 16
btnText.Font = Enum.Font.Arcade
btnText.TextColor3 = Color3.fromRGB(240, 242, 248)
btnText.Active = false
btnText.TextXAlignment = Enum.TextXAlignment.Left

settingsBtn.MouseEnter:Connect(function()
    TweenService:Create(settingsBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(36, 42, 56),
        Size = UDim2.new(0, 144, 0, 46)
    }):Play()
    TweenService:Create(btnStroke, TweenInfo.new(0.15), {
        Color = Color3.fromRGB(90, 140, 255)
    }):Play()
end)

settingsBtn.MouseLeave:Connect(function()
    TweenService:Create(settingsBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(24, 27, 36),
        Size = UDim2.new(0, 140, 0, 44)
    }):Play()
    TweenService:Create(btnStroke, TweenInfo.new(0.15), {
        Color = Color3.fromRGB(60, 68, 88)
    }):Play()
end)

-- ── Ana Ayarlar Paneli (Modal Frame) ─────────────────────────
local modalFrame = Instance.new("Frame")
modalFrame.Name = "SettingsModal"
modalFrame.Size = UDim2.new(0, 560, 0, 580)
modalFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
modalFrame.BackgroundColor3 = SettingsConfig.Theme.Background
modalFrame.BorderSizePixel = 0
modalFrame.Active = true
modalFrame.Visible = false
modalFrame.ZIndex = 50
modalFrame.Parent = screenGui

local modalCorner = Instance.new("UICorner", modalFrame)
modalCorner.CornerRadius = UDim.new(0, 16)

local modalStroke = Instance.new("UIStroke", modalFrame)
modalStroke.Color = SettingsConfig.Theme.PanelBorder
modalStroke.Thickness = 2.5

-- Başlık Barı (Header)
local headerBar = Instance.new("Frame", modalFrame)
headerBar.Name = "HeaderBar"
headerBar.Size = UDim2.new(1, 0, 0, 62)
headerBar.BackgroundColor3 = SettingsConfig.Theme.Header
headerBar.BorderSizePixel = 0
headerBar.ZIndex = 51

local headerCorner = Instance.new("UICorner", headerBar)
headerCorner.CornerRadius = UDim.new(0, 16)

local headerDivider = Instance.new("Frame", headerBar)
headerDivider.Size = UDim2.new(1, 0, 0, 2)
headerDivider.Position = UDim2.new(0, 0, 1, -2)
headerDivider.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
headerDivider.BorderSizePixel = 0

local headerTitle = Instance.new("TextLabel", headerBar)
headerTitle.Size = UDim2.new(1, -75, 1, 0)
headerTitle.Position = UDim2.new(0, 22, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "⚙️ SETTINGS"
headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
headerTitle.Font = Enum.Font.Arcade
headerTitle.TextSize = 28
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.ZIndex = 52

local closeBtn = Instance.new("TextButton", headerBar)
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 38, 0, 38)
closeBtn.Position = UDim2.new(1, -16, 0.5, 0)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(200, 205, 215)
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 20
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 52

local closeBtnCorner = Instance.new("UICorner", closeBtn)
closeBtnCorner.CornerRadius = UDim.new(0, 8)

closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
    closeBtn.TextColor3 = Color3.fromRGB(200, 205, 215)
end)

-- Kaydırılabilir İçerik Alanı (Content Scroll)
-- Kaydırılabilir İçerik Alanı (Content Scroll)
local contentScroll = Instance.new("ScrollingFrame", modalFrame)
contentScroll.Name = "ContentScroll"
contentScroll.Size = UDim2.new(1, -28, 1, -82)
contentScroll.Position = UDim2.new(0, 14, 0, 72)
contentScroll.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
contentScroll.BackgroundTransparency = 0.999
contentScroll.BorderSizePixel = 0
contentScroll.Active = true
contentScroll.Selectable = true
contentScroll.ScrollingEnabled = true
contentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
contentScroll.ScrollBarThickness = 10
contentScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 150, 255)
contentScroll.ScrollBarImageTransparency = 0
contentScroll.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
contentScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
contentScroll.CanvasSize = UDim2.new(0, 0, 0, 920)
contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentScroll.ZIndex = 51

local contentPadding = Instance.new("UIPadding", contentScroll)
contentPadding.PaddingLeft = UDim.new(0, 2)
contentPadding.PaddingRight = UDim.new(0, 8)
contentPadding.PaddingTop = UDim.new(0, 4)
contentPadding.PaddingBottom = UDim.new(0, 44)

local contentLayout = Instance.new("UIListLayout", contentScroll)
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 16)

local function updateCanvasSize()
    local h = math.max(contentLayout.AbsoluteContentSize.Y + 90, 920)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, h)
end
contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)

-- Yardımcı: Bölüm Başlığı (Category Header)
local function createCategoryHeader(titleText, layoutOrder)
    local header = Instance.new("Frame", contentScroll)
    header.Size = UDim2.new(1, 0, 0, 32)
    header.BackgroundTransparency = 1
    header.LayoutOrder = layoutOrder
    header.ZIndex = 52

    local lbl = Instance.new("TextLabel", header)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "──  " .. string.upper(titleText) .. "  ──"
    lbl.TextColor3 = Color3.fromRGB(80, 160, 255)
    lbl.Font = Enum.Font.Arcade
    lbl.TextSize = 18
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 52
    return header
end

-- ── 1. SES AYARLARI (AUDIO SLIDERS) ──────────────────────────
createCategoryHeader("AUDIO SETTINGS", 1)

local function createSliderRow(nameText, initialVal, layoutOrder, onValueChanged)
    local row = Instance.new("Frame", contentScroll)
    row.Name = "SliderRow_" .. nameText
    row.Size = UDim2.new(1, 0, 0, 72)
    row.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
    row.LayoutOrder = layoutOrder
    row.ZIndex = 52
    
    local rCorner = Instance.new("UICorner", row)
    rCorner.CornerRadius = UDim.new(0, 10)
    
    local rStroke = Instance.new("UIStroke", row)
    rStroke.Color = Color3.fromRGB(42, 46, 60)
    rStroke.Thickness = 1.5

    -- İsim Etiketi
    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(0.65, 0, 0, 28)
    nameLbl.Position = UDim2.new(0, 16, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = nameText
    nameLbl.TextColor3 = Color3.fromRGB(240, 242, 248)
    nameLbl.Font = Enum.Font.Arcade
    nameLbl.TextSize = 18
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 53

    -- Değer Etiketi (%100)
    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size = UDim2.new(0.3, 0, 0, 28)
    valLbl.Position = UDim2.new(0.7, -16, 0, 8)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(math.floor(initialVal)) .. "%"
    valLbl.TextColor3 = Color3.fromRGB(85, 205, 255)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 17
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex = 53

    -- Slider Rayı (Track)
    local track = Instance.new("Frame", row)
    track.Name = "Track"
    track.Size = UDim2.new(1, -32, 0, 14)
    track.Position = UDim2.new(0, 16, 0, 44)
    track.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
    track.BorderSizePixel = 0
    track.ZIndex = 53
    
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(1, 0)

    -- Slider Doldurma Çubuğu (Fill)
    local fill = Instance.new("Frame", track)
    fill.Name = "Fill"
    fill.Size = UDim2.new(math.clamp(initialVal / 100, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = SettingsConfig.Theme.SliderFill
    fill.BorderSizePixel = 0
    fill.ZIndex = 54
    
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(1, 0)

    -- Tutamaç (Thumb)
    local thumb = Instance.new("Frame", fill)
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 22, 0, 22)
    thumb.Position = UDim2.new(1, 0, 0.5, 0)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 55
    
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(1, 0)

    local isDragging = false

    local function updateValueFromMouse(mouseX)
        local absPos = track.AbsolutePosition.X
        local absSize = track.AbsoluteSize.X
        if absSize <= 0 then return end
        
        local rel = math.clamp((mouseX - absPos) / absSize, 0, 1)
        local newPct = math.floor(rel * 100 + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valLbl.Text = tostring(newPct) .. "%"
        onValueChanged(newPct)
    end

    local trackButton = Instance.new("TextButton", track)
    trackButton.Size = UDim2.new(1, 0, 1, 0)
    trackButton.BackgroundTransparency = 1
    trackButton.Text = ""
    trackButton.ZIndex = 56

    trackButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateValueFromMouse(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValueFromMouse(input.Position.X)
        end
    end)

    return row
end

-- Master Volume Slider
createSliderRow("MASTER VOLUME", settings.MasterVolume, 2, function(val)
    settings.MasterVolume = val
    updateAllSounds()
end)

-- Music Volume Slider
createSliderRow("MUSIC VOLUME", settings.MusicVolume, 3, function(val)
    settings.MusicVolume = val
    updateAllSounds()
end)

-- SFX Volume Slider
createSliderRow("SFX VOLUME", settings.SFXVolume, 4, function(val)
    settings.SFXVolume = val
    updateAllSounds()
end)

-- Mute Toggle Row
local function createToggleRow(nameText, initialVal, layoutOrder, onToggleChanged)
    local row = Instance.new("Frame", contentScroll)
    row.Name = "ToggleRow_" .. nameText
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
    row.LayoutOrder = layoutOrder
    row.ZIndex = 52
    
    local rCorner = Instance.new("UICorner", row)
    rCorner.CornerRadius = UDim.new(0, 10)
    
    local rStroke = Instance.new("UIStroke", row)
    rStroke.Color = Color3.fromRGB(42, 46, 60)
    rStroke.Thickness = 1.5

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(0.65, 0, 1, 0)
    nameLbl.Position = UDim2.new(0, 16, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = nameText
    nameLbl.TextColor3 = Color3.fromRGB(240, 242, 248)
    nameLbl.Font = Enum.Font.Arcade
    nameLbl.TextSize = 18
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 53

    local toggleBtn = Instance.new("TextButton", row)
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(0, 96, 0, 36)
    toggleBtn.Position = UDim2.new(1, -16, 0.5, 0)
    toggleBtn.AnchorPoint = Vector2.new(1, 0.5)
    toggleBtn.BackgroundColor3 = initialVal and Color3.fromRGB(65, 185, 95) or Color3.fromRGB(45, 48, 60)
    toggleBtn.Text = initialVal and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBlack
    toggleBtn.TextSize = 16
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 53
    
    local tCorner = Instance.new("UICorner", toggleBtn)
    tCorner.CornerRadius = UDim.new(0, 8)

    local currentState = initialVal
    toggleBtn.MouseButton1Click:Connect(function()
        currentState = not currentState
        toggleBtn.BackgroundColor3 = currentState and Color3.fromRGB(65, 185, 95) or Color3.fromRGB(45, 48, 60)
        toggleBtn.Text = currentState and "ON" or "OFF"
        onToggleChanged(currentState)
    end)

    return row
end

createToggleRow("MUTE ALL AUDIO", settings.Muted, 5, function(val)
    settings.Muted = val
    updateAllSounds()
end)

-- ── 1.5. AYRINTILI SES SEVİYELERİ (SOUND ASSET VOLUMES) ──────
createCategoryHeader("SOUND EFFECT VOLUMES (SFX BALANCING)", 10)

local function createSoundAssetSliderRow(soundItem, layoutOrder)
    local soundKey = soundItem.key
    local nameText = soundItem.name
    local minVal = soundItem.min or 0.0
    local maxVal = soundItem.max or 2.0
    local stepVal = soundItem.step or 0.01
    local currentVal = soundItem.default or 0.50

    local row = Instance.new("Frame", contentScroll)
    row.Name = "SoundSliderRow_" .. soundKey
    row.Size = UDim2.new(1, 0, 0, 72)
    row.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
    row.LayoutOrder = layoutOrder
    row.ZIndex = 52
    
    local rCorner = Instance.new("UICorner", row)
    rCorner.CornerRadius = UDim.new(0, 10)
    
    local rStroke = Instance.new("UIStroke", row)
    rStroke.Color = Color3.fromRGB(42, 46, 60)
    rStroke.Thickness = 1.5

    -- İsim Etiketi
    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(0.55, 0, 0, 28)
    nameLbl.Position = UDim2.new(0, 16, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = nameText
    nameLbl.TextColor3 = Color3.fromRGB(240, 242, 248)
    nameLbl.Font = Enum.Font.Arcade
    nameLbl.TextSize = 17
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 53

    -- Ses Testi Butonu (▶)
    local testBtn = Instance.new("TextButton", row)
    testBtn.Name = "TestBtn"
    testBtn.Size = UDim2.new(0, 32, 0, 26)
    testBtn.Position = UDim2.new(1, -16, 0, 9)
    testBtn.AnchorPoint = Vector2.new(1, 0)
    testBtn.BackgroundColor3 = Color3.fromRGB(35, 120, 75)
    testBtn.Text = "▶"
    testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 14
    testBtn.AutoButtonColor = true
    testBtn.ZIndex = 54

    local testCorner = Instance.new("UICorner", testBtn)
    testCorner.CornerRadius = UDim.new(0, 6)
    local testStroke = Instance.new("UIStroke", testBtn)
    testStroke.Color = Color3.fromRGB(80, 200, 120)
    testStroke.Thickness = 1

    local function playTestSample()
        if soundKey == "Footstep" then
            SoundManager.PlaySound("Footstep")
        else
            SoundManager.PlaySound(soundKey)
        end
    end

    testBtn.MouseButton1Click:Connect(playTestSample)

    -- Değer Etiketi (örn. 0.20)
    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size = UDim2.new(0, 70, 0, 28)
    valLbl.Position = UDim2.new(1, -54, 0, 8)
    valLbl.AnchorPoint = Vector2.new(1, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = string.format("%.2f", currentVal)
    valLbl.TextColor3 = Color3.fromRGB(85, 205, 255)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 16
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex = 53

    -- Slider Rayı (Track)
    local track = Instance.new("Frame", row)
    track.Name = "Track"
    track.Size = UDim2.new(1, -32, 0, 14)
    track.Position = UDim2.new(0, 16, 0, 44)
    track.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
    track.BorderSizePixel = 0
    track.ZIndex = 53
    
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(1, 0)

    -- Slider Doldurma Çubuğu (Fill)
    local initialRatio = math.clamp((currentVal - minVal) / (maxVal - minVal), 0, 1)
    local fill = Instance.new("Frame", track)
    fill.Name = "Fill"
    fill.Size = UDim2.new(initialRatio, 0, 1, 0)
    fill.BackgroundColor3 = SettingsConfig.Theme.SliderFill
    fill.BorderSizePixel = 0
    fill.ZIndex = 54
    
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(1, 0)

    -- Tutamaç (Thumb)
    local thumb = Instance.new("Frame", fill)
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 22, 0, 22)
    thumb.Position = UDim2.new(1, 0, 0.5, 0)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 55
    
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(1, 0)

    local isDragging = false

    local function applyValue(newVal)
        currentVal = newVal
        valLbl.Text = string.format("%.2f", newVal)

        if soundKey == "Footstep" then
            if SoundConfig.Footstep then
                SoundConfig.Footstep.Volume = newVal
                SoundConfig.Footstep.ClimbingVolume = newVal
                SoundConfig.Footstep.LandingVolume = newVal * 1.4
            end
            LocalPlayer:SetAttribute("FootstepVolume", newVal)
        else
            if SoundConfig[soundKey] then
                SoundConfig[soundKey].Volume = newVal
            end
        end
    end

    local function updateValueFromMouse(mouseX)
        local absPos = track.AbsolutePosition.X
        local absSize = track.AbsoluteSize.X
        if absSize <= 0 then return end
        
        local rel = math.clamp((mouseX - absPos) / absSize, 0, 1)
        local raw = minVal + rel * (maxVal - minVal)
        local stepped = math.floor(raw / stepVal + 0.5) * stepVal
        stepped = math.clamp(stepped, minVal, maxVal)

        local actualRel = math.clamp((stepped - minVal) / (maxVal - minVal), 0, 1)
        fill.Size = UDim2.new(actualRel, 0, 1, 0)
        applyValue(stepped)
    end

    local trackButton = Instance.new("TextButton", track)
    trackButton.Size = UDim2.new(1, 0, 1, 0)
    trackButton.BackgroundTransparency = 1
    trackButton.Text = ""
    trackButton.ZIndex = 56

    trackButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateValueFromMouse(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isDragging then
                isDragging = false
                playTestSample()
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValueFromMouse(input.Position.X)
        end
    end)

    return row
end

local SoundAssetItems = {
    {
        key = "BushBreak",
        name = "BUSH & POT BREAK",
        default = (SoundConfig.BushBreak and SoundConfig.BushBreak.Volume) or 2.40,
        min = 0.0,
        max = 4.0,
        step = 0.05,
    },
    {
        key = "FireballCast",
        name = "FIREBALL CAST",
        default = (SoundConfig.FireballCast and SoundConfig.FireballCast.Volume) or 0.40,
        min = 0.0,
        max = 1.5,
        step = 0.02,
    },
    {
        key = "FireballHit",
        name = "FIREBALL HIT",
        default = (SoundConfig.FireballHit and SoundConfig.FireballHit.Volume) or 0.50,
        min = 0.0,
        max = 1.5,
        step = 0.02,
    },
    {
        key = "BulletShoot",
        name = "BULLET SHOOT",
        default = (SoundConfig.BulletShoot and SoundConfig.BulletShoot.Volume) or 0.20,
        min = 0.0,
        max = 1.0,
        step = 0.01,
    },
    {
        key = "CoinPickup",
        name = "GOLD PICKUP",
        default = (SoundConfig.CoinPickup and SoundConfig.CoinPickup.Volume) or 0.20,
        min = 0.0,
        max = 1.0,
        step = 0.01,
    },
    {
        key = "MagnetDrop",
        name = "MAGNET DROP",
        default = (SoundConfig.MagnetDrop and SoundConfig.MagnetDrop.Volume) or 0.30,
        min = 0.0,
        max = 1.0,
        step = 0.01,
    },
    {
        key = "Purchase",
        name = "PURCHASE & UNLOCK",
        default = (SoundConfig.Purchase and SoundConfig.Purchase.Volume) or 0.35,
        min = 0.0,
        max = 1.5,
        step = 0.02,
    },
    {
        key = "UIClick",
        name = "UI CLICK",
        default = (SoundConfig.UIClick and SoundConfig.UIClick.Volume) or 0.65,
        min = 0.0,
        max = 1.5,
        step = 0.02,
    },
    {
        key = "Footstep",
        name = "FOOTSTEPS (RUNNING)",
        default = (SoundConfig.Footstep and SoundConfig.Footstep.Volume) or 0.07,
        min = 0.0,
        max = 0.50,
        step = 0.01,
    },
}

for i, sItem in ipairs(SoundAssetItems) do
    createSoundAssetSliderRow(sItem, 10 + i)
end

-- ── 2. OYNANIŞ AYARLARI (GAMEPLAY SETTINGS) ──────────────────
createCategoryHeader("GAMEPLAY SETTINGS", 30)

local UpdateAimSettingsEvent = Events and (Events:FindFirstChild("UpdateAimSettings") or Events:WaitForChild("UpdateAimSettings", 3))
local function syncAimAssistSettings()
    if not UpdateAimSettingsEvent and Events then
        UpdateAimSettingsEvent = Events:FindFirstChild("UpdateAimSettings")
    end
    if UpdateAimSettingsEvent then
        UpdateAimSettingsEvent:FireServer(settings.AimAssist, settings.AimAssistStrength, settings.SmartAim)
    end
end

createToggleRow("AIM ASSIST (CLEAR WALKING PATH)", settings.AimAssist, 31, function(val)
    settings.AimAssist = val
    LocalPlayer:SetAttribute("AimAssistEnabled", val)
    syncAimAssistSettings()
end)

createSliderRow("AIM ASSIST STRENGTH", settings.AimAssistStrength, 32, function(val)
    settings.AimAssistStrength = val
    LocalPlayer:SetAttribute("AimAssistStrength", val)
    syncAimAssistSettings()
end)

createToggleRow("SMART AIM (PRIORITIZE ELITES & BOSSES)", settings.SmartAim, 33, function(val)
    settings.SmartAim = val
    LocalPlayer:SetAttribute("SmartAimEnabled", val)
    syncAimAssistSettings()
end)
task.spawn(syncAimAssistSettings)

createToggleRow("SCREEN SHAKE", settings.ScreenShake, 34, function(val)
    settings.ScreenShake = val
    LocalPlayer:SetAttribute("ScreenShakeEnabled", val)
end)

createToggleRow("DAMAGE NUMBERS", settings.ShowDamageNumbers, 35, function(val)
    settings.ShowDamageNumbers = val
    LocalPlayer:SetAttribute("ShowDamageNumbers", val)
end)

-- ── 3. SIFIRLAMA BÖLÜMÜ (RESET INDEX - DANGER ZONE) ──────────
createCategoryHeader("PROGRESSION & DATA", 40)

local dangerContainer = Instance.new("Frame", contentScroll)
dangerContainer.Name = "DangerContainer"
dangerContainer.Size = UDim2.new(1, 0, 0, 146)
dangerContainer.BackgroundColor3 = Color3.fromRGB(32, 20, 24)
dangerContainer.LayoutOrder = 41
dangerContainer.ZIndex = 52

local dangerCorner = Instance.new("UICorner", dangerContainer)
dangerCorner.CornerRadius = UDim.new(0, 10)

local dangerStroke = Instance.new("UIStroke", dangerContainer)
dangerStroke.Color = Color3.fromRGB(130, 32, 38)
dangerStroke.Thickness = 2

-- Açıklama Metni (İngilizce & Büyütülmüş)
local dangerDesc = Instance.new("TextLabel", dangerContainer)
dangerDesc.Size = UDim2.new(1, -28, 0, 46)
dangerDesc.Position = UDim2.new(0, 14, 0, 12)
dangerDesc.BackgroundTransparency = 1
dangerDesc.Text = "Use the button below to wipe your index quest progress and unlocked items."
dangerDesc.TextColor3 = Color3.fromRGB(240, 180, 185)
dangerDesc.Font = Enum.Font.GothamMedium
dangerDesc.TextSize = 14
dangerDesc.TextWrapped = true
dangerDesc.TextXAlignment = Enum.TextXAlignment.Left
dangerDesc.ZIndex = 53

-- Kırmızı Reset Butonu
local resetBtn = Instance.new("TextButton", dangerContainer)
resetBtn.Name = "ResetIndexButton"
resetBtn.Size = UDim2.new(1, -28, 0, 56)
resetBtn.Position = UDim2.new(0, 14, 0, 68)
resetBtn.BackgroundColor3 = SettingsConfig.Theme.DangerRed
resetBtn.Text = "🗑️ RESET INDEX"
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetBtn.Font = Enum.Font.GothamBlack
resetBtn.TextSize = 18
resetBtn.AutoButtonColor = false
resetBtn.ZIndex = 53

local resetBtnCorner = Instance.new("UICorner", resetBtn)
resetBtnCorner.CornerRadius = UDim.new(0, 8)

local resetBtnStroke = Instance.new("UIStroke", resetBtn)
resetBtnStroke.Color = SettingsConfig.Theme.DangerRedBorder
resetBtnStroke.Thickness = 2

resetBtn.MouseEnter:Connect(function()
    TweenService:Create(resetBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = SettingsConfig.Theme.DangerRedHover
    }):Play()
end)

resetBtn.MouseLeave:Connect(function()
    TweenService:Create(resetBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = SettingsConfig.Theme.DangerRed
    }):Play()
end)

-- ── 4. UYARI PENCERESİ (CONFIRMATION MODAL) ──────────────────
local overlayGui = Instance.new("ScreenGui")
overlayGui.Name = "SettingsOverlayGui"
overlayGui.ResetOnSpawn = false
overlayGui.IgnoreGuiInset = true
overlayGui.DisplayOrder = 300
overlayGui.Parent = PlayerGui

local confirmOverlay = Instance.new("Frame")
confirmOverlay.Name = "ConfirmOverlay"
confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
confirmOverlay.Position = UDim2.new(0, 0, 0, 0)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.55
confirmOverlay.Active = true
confirmOverlay.Visible = false
confirmOverlay.ZIndex = 200
confirmOverlay.Parent = overlayGui

local confirmBox = Instance.new("Frame", confirmOverlay)
confirmBox.Name = "ConfirmBox"
confirmBox.Size = UDim2.new(0, 520, 0, 310)
confirmBox.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmBox.AnchorPoint = Vector2.new(0.5, 0.5)
confirmBox.BackgroundColor3 = Color3.fromRGB(24, 18, 22)
confirmBox.ZIndex = 201

local cBoxCorner = Instance.new("UICorner", confirmBox)
cBoxCorner.CornerRadius = UDim.new(0, 14)

local cBoxStroke = Instance.new("UIStroke", confirmBox)
cBoxStroke.Color = Color3.fromRGB(245, 50, 55)
cBoxStroke.Thickness = 3

-- Uyarı Başlığı (İngilizce & Büyük Font)
local warnTitle = Instance.new("TextLabel", confirmBox)
warnTitle.Size = UDim2.new(1, -30, 0, 42)
warnTitle.Position = UDim2.new(0, 15, 0, 18)
warnTitle.BackgroundTransparency = 1
warnTitle.Text = "⚠️ WARNING: PERMANENT WIPE!"
warnTitle.TextColor3 = Color3.fromRGB(255, 65, 65)
warnTitle.Font = Enum.Font.Arcade
warnTitle.TextSize = 24
warnTitle.TextXAlignment = Enum.TextXAlignment.Center
warnTitle.ZIndex = 202

-- Uyarı Açıklaması (İngilizce & Büyük Font)
local warnMessage = Instance.new("TextLabel", confirmBox)
warnMessage.Size = UDim2.new(1, -40, 0, 110)
warnMessage.Position = UDim2.new(0, 20, 0, 66)
warnMessage.BackgroundTransparency = 1
warnMessage.Text = "All your index unlocks, quest progress, and saved data will be PERMANENTLY ERASED!\n\nThis action cannot be undone. Are you sure you want to proceed?"
warnMessage.TextColor3 = Color3.fromRGB(235, 235, 240)
warnMessage.Font = Enum.Font.GothamMedium
warnMessage.TextSize = 16
warnMessage.TextWrapped = true
warnMessage.TextXAlignment = Enum.TextXAlignment.Center
warnMessage.ZIndex = 202

-- Buton Konteyneri
local btnContainer = Instance.new("Frame", confirmBox)
btnContainer.Size = UDim2.new(1, -40, 0, 56)
btnContainer.Position = UDim2.new(0, 20, 1, -80)
btnContainer.BackgroundTransparency = 1
btnContainer.ZIndex = 202

local bLayout = Instance.new("UIListLayout", btnContainer)
bLayout.FillDirection = Enum.FillDirection.Horizontal
bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bLayout.Padding = UDim.new(0, 16)

-- İptal Butonu
local cancelBtn = Instance.new("TextButton", btnContainer)
cancelBtn.Name = "CancelButton"
cancelBtn.Size = UDim2.new(0.46, 0, 1, 0)
cancelBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
cancelBtn.Text = "CANCEL"
cancelBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextSize = 17
cancelBtn.AutoButtonColor = false
cancelBtn.ZIndex = 203
Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)

-- Onayla & Sil Butonu
local confirmDeleteBtn = Instance.new("TextButton", btnContainer)
confirmDeleteBtn.Name = "ConfirmDeleteButton"
confirmDeleteBtn.Size = UDim2.new(0.46, 0, 1, 0)
confirmDeleteBtn.BackgroundColor3 = Color3.fromRGB(225, 45, 45)
confirmDeleteBtn.Text = "YES, RESET"
confirmDeleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
confirmDeleteBtn.Font = Enum.Font.GothamBlack
confirmDeleteBtn.TextSize = 17
confirmDeleteBtn.AutoButtonColor = false
confirmDeleteBtn.ZIndex = 203
Instance.new("UICorner", confirmDeleteBtn).CornerRadius = UDim.new(0, 8)

-- Durum Bildirim Etiketi (Toast Feedback)
local statusToast = Instance.new("TextLabel", confirmBox)
statusToast.Size = UDim2.new(1, 0, 0, 26)
statusToast.Position = UDim2.new(0, 0, 1, -24)
statusToast.BackgroundTransparency = 1
statusToast.Text = ""
statusToast.TextColor3 = Color3.fromRGB(80, 255, 120)
statusToast.Font = Enum.Font.GothamBold
statusToast.TextSize = 15
statusToast.ZIndex = 203

-- ── Modal Aç / Kapa Animasyonları ────────────────────────────
local function closeOtherLobbyUIs()
    if typeof(_G.CloseBloxBongShopUI) == "function" then _G.CloseBloxBongShopUI() end
    if typeof(_G.CloseBloxBongIndexUI) == "function" then _G.CloseBloxBongIndexUI() end
    if typeof(_G.CloseBloxBongClassUI) == "function" then _G.CloseBloxBongClassUI() end
    if typeof(_G.CloseBloxBongLobbyUI) == "function" then _G.CloseBloxBongLobbyUI() end
end

local function toggleSettings(forceState)
    if forceState ~= nil then
        uiOpen = forceState
    else
        uiOpen = not uiOpen
    end

    if uiOpen then
        closeOtherLobbyUIs()
        modalFrame.Visible = true
        contentScroll.CanvasPosition = Vector2.new(0, 0)
        updateCanvasSize()
        modalFrame.Size = UDim2.new(0, 520, 0, 540)
        TweenService:Create(modalFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 560, 0, 580)
        }):Play()
        TweenService:Create(blurEffect, TweenInfo.new(0.25), {Size = 16}):Play()
    else
        confirmOverlay.Visible = false
        TweenService:Create(blurEffect, TweenInfo.new(0.2), {Size = 0}):Play()
        local t = TweenService:Create(modalFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 520, 0, 540)
        })
        t:Play()
        t.Completed:Connect(function()
            if not uiOpen then
                modalFrame.Visible = false
            end
        end)
    end
end

settingsBtn.MouseButton1Click:Connect(function()
    toggleSettings()
end)

closeBtn.MouseButton1Click:Connect(function()
    toggleSettings(false)
end)

-- Tuş Dinleyici (O Tuşu)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == SettingsConfig.Keybinds.ToggleSettings then
        toggleSettings()
    end
end)

-- ── Reset Butonu Tıklama & Onaylama Olayları ─────────────────
resetBtn.MouseButton1Click:Connect(function()
    statusToast.Text = ""
    confirmDeleteBtn.Text = "YES, RESET"
    confirmDeleteBtn.Active = true
    confirmDeleteBtn.BackgroundColor3 = Color3.fromRGB(225, 45, 45)
    confirmOverlay.Visible = true
    
    confirmBox.Size = UDim2.new(0, 480, 0, 280)
    TweenService:Create(confirmBox, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 520, 0, 310)
    }):Play()
end)

cancelBtn.MouseButton1Click:Connect(function()
    confirmOverlay.Visible = false
end)

confirmDeleteBtn.MouseButton1Click:Connect(function()
    confirmDeleteBtn.Active = false
    confirmDeleteBtn.Text = "RESETTING..."
    confirmDeleteBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 35)

    -- Sunucuya sıfırlama komutu gönder
    local EventsFolder = ReplicatedStorage:FindFirstChild("Events")
    local remote = EventsFolder and EventsFolder:FindFirstChild("ResetIndexProgression")
    if remote then
        remote:FireServer()
    else
        warn("[SettingsUIController] ResetIndexProgression remote bulunamadı!")
    end
end)

-- Sunucudan gelen sıfırlama sonucunu dinle
if ResetIndexResult then
    ResetIndexResult.OnClientEvent:Connect(function(success)
        if success then
            statusToast.Text = "✓ Index progression successfully reset!"
            statusToast.TextColor3 = Color3.fromRGB(80, 255, 120)
            task.delay(1.2, function()
                confirmOverlay.Visible = false
            end)
        else
            statusToast.Text = "✕ Reset failed! Please try again."
            statusToast.TextColor3 = Color3.fromRGB(255, 80, 80)
            confirmDeleteBtn.Active = true
            confirmDeleteBtn.Text = "TRY AGAIN"
        end
    end)
end

print("[SettingsUIController] Initialized successfully.")

_G.CloseBloxBongSettingsUI = function()
    toggleSettings(false)
end
