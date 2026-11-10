local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterUIConfig"))
local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local LobbyEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("LobbyEvents")
local OpenClassUI = LobbyEvents:WaitForChild("OpenClassUI")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local design = Config.Design

local lastToggleTime = 0
local toggleCooldown = 1 
local toggleUI -- forward declaration

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntigravityClassUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

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

-- Arka Plan Bulanıklığı (Sadece oyun dünyasını arkada gösterip bulanıklaştırıyoruz)
local blurEffect = Lighting:FindFirstChild("ClassUIBlur") or Instance.new("BlurEffect")
blurEffect.Name = "ClassUIBlur"
blurEffect.Size = 0
blurEffect.Parent = Lighting

-- ==========================================
-- SOL TARAF: Izgara (Grid) Düzeni (Panel İçinde)
-- ==========================================
local gridPanel = Instance.new("Frame")
gridPanel.Name = "GridPanel"
gridPanel.Size = design.GridSize
gridPanel.Position = UDim2.new(design.GridPosition.X.Scale, design.GridPosition.X.Offset - 500, design.GridPosition.Y.Scale, design.GridPosition.Y.Offset)
gridPanel.AnchorPoint = design.GridAnchor
gridPanel.BackgroundColor3 = design.PanelBackgroundColor
gridPanel.BackgroundTransparency = design.PanelTransparency
gridPanel.Parent = screenGui

-- Keskin köşeli dual-border (Metalik çerçeve)
local gridStroke = Instance.new("UIStroke", gridPanel)
gridStroke.Color = Color3.fromRGB(60, 60, 65)
gridStroke.Thickness = 3
gridStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local gridInnerBorder = Instance.new("Frame", gridPanel)
gridInnerBorder.Name = "InnerBorder"
gridInnerBorder.Size = UDim2.new(1, -10, 1, -10)
gridInnerBorder.Position = UDim2.new(0.5, 0, 0.5, 0)
gridInnerBorder.AnchorPoint = Vector2.new(0.5, 0.5)
gridInnerBorder.BackgroundTransparency = 1
local gridInnerStroke = Instance.new("UIStroke", gridInnerBorder)
gridInnerStroke.Color = Color3.fromRGB(120, 120, 120)
gridInnerStroke.Thickness = 1

-- Başlık Barı (CHARACTER SELECTION)
local titleBar = Instance.new("Frame", gridPanel)
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 2

local titleBarStroke = Instance.new("Frame", titleBar)
titleBarStroke.Size = UDim2.new(1, 0, 0, 2)
titleBarStroke.Position = UDim2.new(0, 0, 1, 0)
titleBarStroke.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
titleBarStroke.BorderSizePixel = 0

local titleText = Instance.new("TextLabel", titleBar)
titleText.Name = "TitleText"
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.SpecialElite
titleText.TextSize = 22
titleText.TextColor3 = Color3.fromRGB(220, 220, 220)
titleText.Text = "CHARACTER SELECTION"
titleText.TextXAlignment = Enum.TextXAlignment.Left

-- Kırmızı Kapatma (X) Butonu
local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
closeBtn.Font = Enum.Font.SpecialElite
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Text = "X"
closeBtn.ZIndex = 3

local closeStroke = Instance.new("UIStroke", closeBtn)
closeStroke.Color = Color3.fromRGB(80, 20, 20)
closeStroke.Thickness = 2

closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
end)

closeBtn.MouseButton1Click:Connect(function()
    toggleUI(false)
end)

local gridContainer = Instance.new("Frame")
gridContainer.Name = "GridContainer"
gridContainer.Size = UDim2.new(1, -20, 1, -70)
gridContainer.Position = UDim2.new(0.5, 0, 0, 60)
gridContainer.AnchorPoint = Vector2.new(0.5, 0)
gridContainer.BackgroundTransparency = 1
gridContainer.ClipsDescendants = true
gridContainer.Parent = gridPanel

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingLeft = UDim.new(0, 15)
gridPadding.PaddingRight = UDim.new(0, 15)
gridPadding.PaddingTop = UDim.new(0, 15)
gridPadding.PaddingBottom = UDim.new(0, 15)
gridPadding.Parent = gridContainer

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 110, 0, 110) -- 4 kolon tam sığar
gridLayout.CellPadding = UDim2.new(0, 16, 0, 16)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridContainer

-- ==========================================
-- SAĞ TARAF: Dinamik Bilgi Paneli
-- ==========================================
local hoverPanel = Instance.new("Frame")
hoverPanel.Name = "HoverPanel"
hoverPanel.Size = design.PanelSize
hoverPanel.Position = UDim2.new(design.PanelPosition.X.Scale, design.PanelPosition.X.Offset + 500, design.PanelPosition.Y.Scale, design.PanelPosition.Y.Offset)
hoverPanel.AnchorPoint = design.PanelAnchor
hoverPanel.BackgroundColor3 = design.PanelBackgroundColor
hoverPanel.BackgroundTransparency = design.PanelTransparency
hoverPanel.Parent = screenGui

-- Keskin köşeli dual-border (Metalik çerçeve)
local panelStroke = Instance.new("UIStroke", hoverPanel)
panelStroke.Color = Color3.fromRGB(60, 60, 65)
panelStroke.Thickness = 3
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local panelInnerBorder = Instance.new("Frame", hoverPanel)
panelInnerBorder.Name = "InnerBorder"
panelInnerBorder.Size = UDim2.new(1, -10, 1, -10)
panelInnerBorder.Position = UDim2.new(0.5, 0, 0.5, 0)
panelInnerBorder.AnchorPoint = Vector2.new(0.5, 0.5)
panelInnerBorder.BackgroundTransparency = 1
local panelInnerStroke = Instance.new("UIStroke", panelInnerBorder)
panelInnerStroke.Color = Color3.fromRGB(120, 120, 120)
panelInnerStroke.Thickness = 1

-- Panel Elemanları: Üst Kısım (Header)
local headerFrame = Instance.new("Frame", hoverPanel)
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, -30, 0, 90)
headerFrame.Position = UDim2.new(0.5, 0, 0, 20)
headerFrame.AnchorPoint = Vector2.new(0.5, 0)
headerFrame.BackgroundTransparency = 1

local headerIconFrame = Instance.new("Frame", headerFrame)
headerIconFrame.Name = "IconFrame"
headerIconFrame.Size = UDim2.new(0, 80, 0, 80)
headerIconFrame.Position = UDim2.new(0, 0, 0.5, 0)
headerIconFrame.AnchorPoint = Vector2.new(0, 0.5)
headerIconFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)

local headerIconStroke = Instance.new("UIStroke", headerIconFrame)
headerIconStroke.Color = Color3.fromRGB(100, 100, 100)
headerIconStroke.Thickness = 2

local headerIcon = Instance.new("ImageLabel", headerIconFrame)
headerIcon.Name = "Icon"
headerIcon.Size = UDim2.new(1, -4, 1, -4)
headerIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
headerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
headerIcon.BackgroundTransparency = 1
headerIcon.ScaleType = Enum.ScaleType.Crop

local titleLabel = Instance.new("TextLabel", headerFrame)
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -96, 0, 32)
titleLabel.Position = UDim2.new(0, 96, 0.1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.SpecialElite
titleLabel.TextSize = 28
titleLabel.TextColor3 = design.TitleColor
titleLabel.Text = "SELECT CLASS"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local classSubLabel = Instance.new("TextLabel", headerFrame)
classSubLabel.Name = "SubLabel"
classSubLabel.Size = UDim2.new(1, -96, 0, 20)
classSubLabel.Position = UDim2.new(0, 96, 0.55, 0)
classSubLabel.BackgroundTransparency = 1
classSubLabel.Font = Enum.Font.SpecialElite
classSubLabel.TextSize = 14
classSubLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
classSubLabel.Text = "PLAYABLE CLASS"
classSubLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Ayırıcı Çizgi (Separator Line)
local separator = Instance.new("Frame", hoverPanel)
separator.Name = "Separator"
separator.Size = UDim2.new(1, -30, 0, 2)
separator.Position = UDim2.new(0.5, 0, 0, 115)
separator.AnchorPoint = Vector2.new(0.5, 0)
separator.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
separator.BorderSizePixel = 0

-- Özellikler/Açıklama Ayarları (Traits)
local descLabel = Instance.new("TextLabel", hoverPanel)
descLabel.Name = "Description"
descLabel.Size = UDim2.new(0.9, 0, 0, 170)
descLabel.Position = UDim2.new(0.5, 0, 0, 130)
descLabel.AnchorPoint = Vector2.new(0.5, 0)
descLabel.BackgroundTransparency = 1
descLabel.Font = Enum.Font.SpecialElite
descLabel.TextSize = 22
descLabel.TextColor3 = design.DescColor
descLabel.TextWrapped = true
descLabel.RichText = true
descLabel.TextXAlignment = Enum.TextXAlignment.Left
descLabel.TextYAlignment = Enum.TextYAlignment.Top
descLabel.Text = "Hover over icons to see details."

-- İstatistikler Başlığı
local statsTitle = Instance.new("TextLabel", hoverPanel)
statsTitle.Name = "StatsTitle"
statsTitle.Size = UDim2.new(0.9, 0, 0, 25)
statsTitle.Position = UDim2.new(0.5, 0, 0, 315)
statsTitle.AnchorPoint = Vector2.new(0.5, 0)
statsTitle.BackgroundTransparency = 1
statsTitle.Font = Enum.Font.SpecialElite
statsTitle.TextSize = 16
statsTitle.TextColor3 = Color3.fromRGB(120, 150, 255)
statsTitle.Text = "BASE STATS"
statsTitle.TextXAlignment = Enum.TextXAlignment.Left

local statsFrame = Instance.new("Frame", hoverPanel)
statsFrame.Name = "StatsFrame"
statsFrame.Size = UDim2.new(0.9, 0, 0, 190)
statsFrame.Position = UDim2.new(0.5, 0, 0, 345)
statsFrame.AnchorPoint = Vector2.new(0.5, 0)
statsFrame.BackgroundTransparency = 1

local statsLayout = Instance.new("UIListLayout", statsFrame)
statsLayout.Padding = UDim.new(0, 10)

-- Seçim Butonu (CONFIRM Button) - Referans stile uygun mavi tasarım
local selectButton = Instance.new("TextButton", hoverPanel)
selectButton.Name = "SelectButton"
selectButton.Size = UDim2.new(0.9, 0, 0, 60)
selectButton.Position = UDim2.new(0.5, 0, 0.95, 0)
selectButton.AnchorPoint = Vector2.new(0.5, 1)
selectButton.BackgroundColor3 = Color3.fromRGB(50, 110, 180)
selectButton.Font = Enum.Font.SpecialElite
selectButton.TextSize = 24
selectButton.Text = "CONFIRM"
selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
selectButton.Visible = false

local btnStroke = Instance.new("UIStroke", selectButton)
btnStroke.Color = Color3.fromRGB(25, 60, 110)
btnStroke.Thickness = 3

selectButton.MouseEnter:Connect(function()
    TweenService:Create(selectButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(70, 140, 220)}):Play()
end)
selectButton.MouseLeave:Connect(function()
    TweenService:Create(selectButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50, 110, 180)}):Play()
end)

-- ==========================================
-- MANTIK VE ANİMASYONLAR
-- ==========================================
local activeTargetClass = nil
local lockedClass = nil

local function updateHoverPanel(charData)
    TweenService:Create(panelStroke, TweenInfo.new(design.TweenDuration), {Color = charData.Color}):Play()
    
    headerIcon.Image = charData.Icon or ""
    titleLabel.Text = string.upper(charData.Name)
    titleLabel.TextColor3 = charData.Color
    descLabel.Text = charData.Description
    selectButton.Visible = true
    
    for _, child in ipairs(statsFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for _, stat in ipairs(charData.Stats) do
        local row = Instance.new("Frame", statsFrame)
        row.Size = UDim2.new(1, 0, 0, 55)
        row.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
        row.BackgroundTransparency = 0.4
        row.BorderSizePixel = 0
        
        local rowPadding = Instance.new("UIPadding", row)
        rowPadding.PaddingLeft = UDim.new(0, 10)
        rowPadding.PaddingRight = UDim.new(0, 10)
        
        local icon = Instance.new("ImageLabel", row)
        icon.Size = UDim2.new(0, 48, 0, 48)
        icon.Position = UDim2.new(0, 5, 0.5, 0)
        icon.AnchorPoint = Vector2.new(0, 0.5)
        icon.BackgroundTransparency = 1
        icon.Image = stat.Icon or ""
        icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        
        local statName = Instance.new("TextLabel", row)
        statName.Size = UDim2.new(0.4, -65, 1, 0)
        statName.Position = UDim2.new(0, 65, 0, 0) -- Pushed right to leave a 65px gap for icons
        statName.BackgroundTransparency = 1
        statName.Font = Enum.Font.SpecialElite
        statName.TextSize = 18
        statName.TextColor3 = Color3.fromRGB(200, 200, 200)
        statName.Text = stat.Name
        statName.TextXAlignment = Enum.TextXAlignment.Left
        
        local statVal = Instance.new("TextLabel", row)
        statVal.Size = UDim2.new(0.4, 0, 1, 0)
        statVal.Position = UDim2.new(1, 0, 0, 0)
        statVal.AnchorPoint = Vector2.new(1, 0)
        statVal.BackgroundTransparency = 1
        statVal.Font = Enum.Font.SpecialElite
        statVal.TextSize = 18
        statVal.Text = stat.Value
        statVal.TextXAlignment = Enum.TextXAlignment.Right
        
        if stat.Type == "Buff" then
            statVal.TextColor3 = design.BuffColor
        elseif stat.Type == "Nerf" then
            statVal.TextColor3 = design.NerfColor
        else
            statVal.TextColor3 = design.NeutralColor
        end
    end
end

local function resetPanelToDefault()
    headerIcon.Image = ""
    titleLabel.Text = "SELECT CLASS"
    titleLabel.TextColor3 = design.TitleColor
    descLabel.Text = "Hover over icons to see details."
    selectButton.Visible = false
    TweenService:Create(panelStroke, TweenInfo.new(design.TweenDuration), {Color = design.StrokeColor}):Play()
    for _, child in ipairs(statsFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end

for i, charData in ipairs(Config.Characters) do
    local cell = Instance.new("TextButton")
    cell.Name = charData.Id
    cell.BackgroundTransparency = 1
    cell.Text = ""
    cell.Parent = gridContainer
    
    local cardContent = Instance.new("CanvasGroup", cell)
    cardContent.Size = UDim2.new(1, 0, 1, 0)
    cardContent.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    cardContent.BackgroundTransparency = 0.1
    cardContent.BorderSizePixel = 0
    
    local cardStroke = Instance.new("UIStroke", cardContent)
    cardStroke.Color = Color3.fromRGB(80, 80, 85)
    cardStroke.Thickness = 2
    cardStroke.Transparency = 0.5
    
    -- Diorama
    local diorama = Instance.new("ImageLabel", cardContent)
    diorama.Size = UDim2.new(0.836, 0, 0.836, 0)
    diorama.Position = UDim2.new(0.5, 0, 0.018, 0)
    diorama.AnchorPoint = Vector2.new(0.5, 0)
    diorama.BackgroundTransparency = 1
    diorama.Image = charData.Icon or "rbxassetid://139314084681197"
    diorama.ScaleType = Enum.ScaleType.Crop
    diorama.ImageTransparency = 0
    
    -- Küçük İsim Etiketi (Alt Kısım)
    local nameTag = Instance.new("TextLabel", cardContent)
    nameTag.Size = UDim2.new(1, 0, 0.2, 0)
    nameTag.Position = UDim2.new(0, 0, 1, 0)
    nameTag.AnchorPoint = Vector2.new(0, 1)
    nameTag.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    nameTag.BackgroundTransparency = 0.2
    nameTag.Font = Enum.Font.SpecialElite
    nameTag.TextSize = 14
    nameTag.TextColor3 = Color3.new(1, 1, 1)
    nameTag.Text = string.upper(charData.Name)
    
    local tagBorder = Instance.new("Frame", nameTag)
    tagBorder.Size = UDim2.new(1, 0, 0, 1)
    tagBorder.Position = UDim2.new(0, 0, 0, 0)
    tagBorder.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
    tagBorder.BorderSizePixel = 0

    cell.MouseEnter:Connect(function()
        activeTargetClass = charData
        TweenService:Create(cardContent, TweenInfo.new(0.2), {Size = UDim2.new(1.1, 0, 1.1, 0)}):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.2), {Color = charData.Color, Transparency = 0, Thickness = 3}):Play()
        updateHoverPanel(charData)
    end)
    
    cell.MouseLeave:Connect(function()
        TweenService:Create(cardContent, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 1, 0)}):Play()
        
        if lockedClass ~= charData then
            TweenService:Create(cardStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(80, 80, 85), Transparency = 0.5, Thickness = 2}):Play()
        end

        if lockedClass then
            activeTargetClass = lockedClass
            updateHoverPanel(lockedClass)
        else
            activeTargetClass = nil
            resetPanelToDefault()
        end
    end)
    
    cell.MouseButton1Click:Connect(function()
        lockedClass = charData
        activeTargetClass = charData
        
        -- Diğerlerini sıfırla
        for _, otherCell in ipairs(gridContainer:GetChildren()) do
            if otherCell:IsA("TextButton") and otherCell ~= cell then
                local otherContent = otherCell:FindFirstChildWhichIsA("CanvasGroup")
                if otherContent then
                    local otherStroke = otherContent:FindFirstChild("UIStroke")
                    if otherStroke then TweenService:Create(otherStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(80, 80, 85), Transparency = 0.5, Thickness = 2}):Play() end
                end
            end
        end

        TweenService:Create(cardStroke, TweenInfo.new(0.2), {Color = charData.Color, Transparency = 0, Thickness = 3}):Play()
        updateHoverPanel(charData)
    end)
end

local function closeOtherLobbyUIs()
    if typeof(_G.CloseBloxBongShopUI) == "function" then _G.CloseBloxBongShopUI() end
    if typeof(_G.CloseBloxBongIndexUI) == "function" then _G.CloseBloxBongIndexUI() end
    if typeof(_G.CloseBloxBongSettingsUI) == "function" then _G.CloseBloxBongSettingsUI() end
    if typeof(_G.CloseBloxBongLobbyUI) == "function" then _G.CloseBloxBongLobbyUI() end
end

toggleUI = function(state)
    if state == true and (tick() - lastToggleTime < toggleCooldown) then return end
    lastToggleTime = tick()

    local npcName = LobbyConfig.Visuals.ClassNPC_ModelName or "ClassNPC"
    local npc = workspace:FindFirstChild(npcName)
    if npc then
        local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then prompt.Enabled = not state end
    end

    if state then
        closeOtherLobbyUIs()
        screenGui.Enabled = true
        activeTargetClass = nil
        selectButton.Visible = false
        titleLabel.Text = "SELECT CLASS"
        titleLabel.TextColor3 = design.TitleColor
        descLabel.Text = "Hover over icons to see details."
        headerIcon.Image = ""
        
        for _, child in ipairs(statsFrame:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        
        TweenService:Create(blurEffect, TweenInfo.new(0.5), {Size = 24}):Play()
        TweenService:Create(gridPanel, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = design.GridPosition}):Play()
        TweenService:Create(hoverPanel, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = design.PanelPosition}):Play()
    else
        TweenService:Create(blurEffect, TweenInfo.new(0.4), {Size = 0}):Play()
        TweenService:Create(gridPanel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(design.GridPosition.X.Scale, design.GridPosition.X.Offset - 500, design.GridPosition.Y.Scale, design.GridPosition.Y.Offset)}):Play()
        local t = TweenService:Create(hoverPanel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(design.PanelPosition.X.Scale, design.PanelPosition.X.Offset + 500, design.PanelPosition.Y.Scale, design.PanelPosition.Y.Offset)})
        t:Play()
        t.Completed:Connect(function() screenGui.Enabled = false end)
    end
end

OpenClassUI.OnClientEvent:Connect(function() toggleUI(true) end)

local SelectClass = LobbyEvents:WaitForChild("SelectClass")

selectButton.MouseButton1Click:Connect(function()
    if activeTargetClass then
        -- print("Class Selected: " .. activeTargetClass.Name)
        SelectClass:FireServer(activeTargetClass.Id)
        toggleUI(false)
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not screenGui.Enabled then return end
    if input.KeyCode == Enum.KeyCode.E then toggleUI(false) return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
        local mousePos = UserInputService:GetMouseLocation()
        
        local gridX1, gridY1 = gridPanel.AbsolutePosition.X, gridPanel.AbsolutePosition.Y
        local gridX2, gridY2 = gridX1 + gridPanel.AbsoluteSize.X, gridY1 + gridPanel.AbsoluteSize.Y
        
        local hoverX1, hoverY1 = hoverPanel.AbsolutePosition.X, hoverPanel.AbsolutePosition.Y
        local hoverX2, hoverY2 = hoverX1 + hoverPanel.AbsoluteSize.X, hoverY1 + hoverPanel.AbsoluteSize.Y
        
        local inGrid = (mousePos.X >= gridX1 and mousePos.X <= gridX2 and mousePos.Y >= gridY1 and mousePos.Y <= gridY2)
        local inHover = (mousePos.X >= hoverX1 and mousePos.X <= hoverX2 and mousePos.Y >= hoverY1 and mousePos.Y <= hoverY2)
        
        if not inGrid and not inHover then
            toggleUI(false)
        end
    end
end)

_G.CloseBloxBongClassUI = function()
    toggleUI(false)
end
