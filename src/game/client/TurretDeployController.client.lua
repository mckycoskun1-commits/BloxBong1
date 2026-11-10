local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local function getDeployEvent()
    return Events:FindFirstChild("DeployTurret") or Events:WaitForChild("DeployTurret", 5)
end

-- Responsive UI Scale (Panelin kendi içine uygulanır, AnchorPoint (0, 1) üzerinden sol alt köşede sabit kalır)
local function applyUIScale(targetInstance)
    local uiScale = Instance.new("UIScale")
    uiScale.Parent = targetInstance
    local function updateScale()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local scale = math.min(viewport.X / 1600, viewport.Y / 900)
        uiScale.Scale = math.clamp(scale, 0.6, 1.5)
    end
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
        updateScale()
    end
end

-- Eski GUI varsa temizle
local oldGui = PlayerGui:FindFirstChild("EngineerTurretUI")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EngineerTurretUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 65
screenGui.Enabled = false
screenGui.Parent = PlayerGui

-- Sabit Konum ve Boyut (Ekran dışına kaymayı kesinlikle önler)
local BASE_POSITION = UDim2.new(0, 18, 1, -18)
local BASE_SIZE = UDim2.new(0, 252, 0, 70)

-- Ana Konteyner Kartı (Sol alt köşe, rahatça görünen ve mobilde de basılabilen retro panel)
local container = Instance.new("TextButton")
container.Name = "ScrapDeployPanel"
container.Size = BASE_SIZE
container.AnchorPoint = Vector2.new(0, 1)
container.Position = BASE_POSITION
container.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
container.BackgroundTransparency = 0.15
container.AutoButtonColor = false
container.Text = ""
container.Parent = screenGui
applyUIScale(container)

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = container

local stroke = Instance.new("UIStroke")
stroke.Name = "PanelStroke"
stroke.Thickness = 2.0
stroke.Color = Color3.fromRGB(180, 120, 40)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = container

-- Taret İkonu
local turretIcon = Instance.new("ImageLabel")
turretIcon.Name = "TurretIcon"
turretIcon.Size = UDim2.new(0, 38, 0, 38)
turretIcon.Position = UDim2.new(0, 8, 0.5, 0)
turretIcon.AnchorPoint = Vector2.new(0, 0.5)
turretIcon.BackgroundTransparency = 1
turretIcon.Image = "rbxassetid://116127630902574"
turretIcon.Parent = container

-- Hurda Sayaç Metni
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0, 118, 0, 20)
titleLabel.Position = UDim2.new(0, 52, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.Arcade
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
titleLabel.TextStrokeTransparency = 0.2
titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
titleLabel.Text = "SCRAP: 0 / 100"
titleLabel.Parent = container

-- 5 Adet Milestone (Dönüm Noktası) Kutucuğu
local pipsContainer = Instance.new("Frame")
pipsContainer.Name = "MilestonePips"
pipsContainer.Size = UDim2.new(0, 70, 0, 14)
pipsContainer.Position = UDim2.new(1, -76, 0, 11)
pipsContainer.BackgroundTransparency = 1
pipsContainer.Parent = container

local pipsLayout = Instance.new("UIListLayout", pipsContainer)
pipsLayout.FillDirection = Enum.FillDirection.Horizontal
pipsLayout.SortOrder = Enum.SortOrder.LayoutOrder
pipsLayout.Padding = UDim.new(0, 3)

local pipBoxes = {}
for i = 1, 5 do
    local pip = Instance.new("Frame", pipsContainer)
    pip.Name = "Pip_" .. i
    pip.LayoutOrder = i
    pip.Size = UDim2.new(0, 11, 0, 11)
    pip.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
    pip.BorderSizePixel = 0
    
    local pipCorner = Instance.new("UICorner", pip)
    pipCorner.CornerRadius = UDim.new(0, 2)
    
    local pipStroke = Instance.new("UIStroke", pip)
    pipStroke.Name = "PipStroke"
    pipStroke.Thickness = 1.0
    pipStroke.Color = Color3.fromRGB(60, 75, 100)
    
    table.insert(pipBoxes, pip)
end

-- İlerleme Çubuğu Arka Planı
local barBg = Instance.new("Frame")
barBg.Name = "BarBg"
barBg.Size = UDim2.new(1, -62, 0, 8)
barBg.Position = UDim2.new(0, 52, 0, 31)
barBg.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
barBg.BorderSizePixel = 0
barBg.Parent = container

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 4)
barCorner.Parent = barBg

-- İlerleme Çubuğu Dolgusu
local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(245, 160, 35)
barFill.BorderSizePixel = 0
barFill.Parent = barBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 4)
fillCorner.Parent = barFill

-- Alt Bilgi / Tuş İpucu (F Deploy / Click to Deploy)
local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.new(1, -60, 0, 16)
hintLabel.Position = UDim2.new(0, 52, 0, 45)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Arcade
hintLabel.TextSize = 11
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
hintLabel.TextStrokeTransparency = 0.4
hintLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hintLabel.Text = "[F] DEPLOY TURRET"
hintLabel.Parent = container

-- Durum Takibi & Cooldown (5 Saniye)
local TURRET_COOLDOWN = 5.0
local localCooldownEnd = 0
local cooldownTask = nil
local isReady = false
local pulseTween = nil

local function getCooldownRemaining()
    local now = os.clock()
    local serverCd = Player:GetAttribute("TurretCooldownEnd") or 0
    local cdEnd = math.max(localCooldownEnd, serverCd)
    return math.max(0, cdEnd - now)
end

local function setReadyState(ready)
    if isReady == ready then return end
    isReady = ready

    if ready then
        titleLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
        barFill.BackgroundColor3 = Color3.fromRGB(80, 240, 120) -- Hazır olduğunda yeşil/altın parıltı
        hintLabel.TextColor3 = Color3.fromRGB(100, 255, 160)
        hintLabel.Text = "[F] CLICK / PRESS TO DEPLOY!"

        -- Nabız animasyonu (Stroke Glow)
        pulseTween = TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Color = Color3.fromRGB(255, 220, 60),
            Thickness = 3.5
        })
        pulseTween:Play()
    else
        if pulseTween then
            pulseTween:Cancel()
            pulseTween = nil
        end
        stroke.Thickness = 2.0
        stroke.Color = Color3.fromRGB(180, 120, 40)
        titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
        barFill.BackgroundColor3 = Color3.fromRGB(245, 160, 35)
        
        local remaining = getCooldownRemaining()
        if remaining > 0 then
            hintLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            hintLabel.Text = string.format("[F] COOLDOWN (%.1fs)", remaining)
        else
            hintLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
            hintLabel.Text = "[F] DEPLOY TURRET"
        end
    end
end

local function startCooldownLoop()
    if cooldownTask then return end
    cooldownTask = task.spawn(function()
        while true do
            local remaining = getCooldownRemaining()
            if remaining <= 0 then break end
            hintLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            hintLabel.Text = string.format("[F] COOLDOWN (%.1fs)", remaining)
            task.wait(0.1)
        end
        cooldownTask = nil
        local scrap = Player:GetAttribute("Scrap") or 0
        local cost = Player:GetAttribute("TurretCost") or 100
        setReadyState(scrap >= cost)
    end)
end

local function updateHUD()
    local scrap = Player:GetAttribute("Scrap") or 0
    local cost = Player:GetAttribute("TurretCost") or 100
    local pct = math.clamp(scrap / math.max(1, cost), 0, 1)

    titleLabel.Text = "SCRAP: " .. tostring(scrap) .. " / " .. tostring(cost)
    TweenService:Create(barFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(pct, 0, 1, 0)
    }):Play()

    local cdRemaining = getCooldownRemaining()
    if cdRemaining > 0 then
        setReadyState(false)
        startCooldownLoop()
    else
        setReadyState(scrap >= cost)
    end
end

local milestoneGlowTask = nil

local function updateMilestoneHUD()
    local progress = math.clamp(Player:GetAttribute("TurretMilestoneProgress") or 0, 0, 5)
    local isPending = Player:GetAttribute("TurretMilestonePending") == true or (progress >= 5)

    for i = 1, 5 do
        local pip = pipBoxes[i]
        if pip then
            local pStroke = pip:FindFirstChild("PipStroke")
            if i <= progress then
                -- Dolu kutucuk (Parlak altın rengi)
                pip.BackgroundColor3 = Color3.fromRGB(250, 204, 21)
                if pStroke then pStroke.Color = Color3.fromRGB(254, 240, 138) end
            else
                -- Boş kutucuk (Koyu taban)
                pip.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
                if pStroke then pStroke.Color = Color3.fromRGB(60, 75, 100) end
            end
        end
    end

    if isPending then
        if not milestoneGlowTask then
            milestoneGlowTask = task.spawn(function()
                while Player:GetAttribute("TurretMilestonePending") == true or (Player:GetAttribute("TurretMilestoneProgress") or 0) >= 5 do
                    for _, pip in ipairs(pipBoxes) do
                        local s = pip:FindFirstChild("PipStroke")
                        if s then s.Color = Color3.fromRGB(255, 255, 220) end
                    end
                    task.wait(0.4)
                    for _, pip in ipairs(pipBoxes) do
                        local s = pip:FindFirstChild("PipStroke")
                        if s then s.Color = Color3.fromRGB(235, 160, 20) end
                    end
                    task.wait(0.4)
                end
            end)
        end
    else
        if milestoneGlowTask then
            task.cancel(milestoneGlowTask)
            milestoneGlowTask = nil
        end
    end
end

local isShaking = false
local function playShake(offsetAmount, color)
    TweenService:Create(stroke, TweenInfo.new(0.08), {Color = color}):Play()
    if isShaking then return end
    isShaking = true
    task.spawn(function()
        for i = 1, 2 do
            container.Position = BASE_POSITION + UDim2.new(0, offsetAmount, 0, 0)
            task.wait(0.035)
            container.Position = BASE_POSITION - UDim2.new(0, offsetAmount, 0, 0)
            task.wait(0.035)
        end
        container.Position = BASE_POSITION
        isShaking = false
        stroke.Color = isReady and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(180, 120, 40)
    end)
end

local function triggerDeploy()
    local cdRemaining = getCooldownRemaining()
    if cdRemaining > 0 then
        -- Cooldown sırasında basılırsa turuncu titreme geri bildirimi
        playShake(4, Color3.fromRGB(245, 150, 40))
        return
    end

    local scrap = Player:GetAttribute("Scrap") or 0
    local cost = Player:GetAttribute("TurretCost") or 100

    if scrap >= cost then
        localCooldownEnd = os.clock() + TURRET_COOLDOWN
        startCooldownLoop()

        -- Küçük tıklama/başarı yaylanması (her zaman BASE_SIZE ve BASE_POSITION'a geri döner)
        TweenService:Create(container, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 260, 0, 74)
        }):Play()
        task.delay(0.12, function()
            if container and container.Parent then
                TweenService:Create(container, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = BASE_SIZE
                }):Play()
            end
        end)

        local deployEvent = getDeployEvent()
        if deployEvent then
            deployEvent:FireServer()
        end
    else
        -- Yetersiz Hurda Geri Bildirimi: Kırmızı titreme
        playShake(5, Color3.fromRGB(255, 60, 60))
    end
end

-- Tıklama / Dokunma ile Deploy
container.MouseButton1Click:Connect(triggerDeploy)

-- Klavye [F] Tuşu ile Deploy
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        if screenGui.Enabled then
            triggerDeploy()
        end
    end
end)

-- Sınıf Kontrolü & Attribute Dinleyicileri
local function checkClassActive()
    local classId = Player:GetAttribute("SelectedClassId") or Player:GetAttribute("SelectedClass")
    local hasTurret = Player:GetAttribute("HasTurret") == true or classId == "Engineer"

    if hasTurret then
        container.Position = BASE_POSITION
        container.Size = BASE_SIZE
        screenGui.Enabled = true
        updateHUD()
        updateMilestoneHUD()
    else
        screenGui.Enabled = false
    end
end

Player:GetAttributeChangedSignal("SelectedClassId"):Connect(checkClassActive)
Player:GetAttributeChangedSignal("HasTurret"):Connect(checkClassActive)
Player:GetAttributeChangedSignal("Scrap"):Connect(updateHUD)
Player:GetAttributeChangedSignal("TurretCost"):Connect(updateHUD)
Player:GetAttributeChangedSignal("TurretCooldownEnd"):Connect(updateHUD)
Player:GetAttributeChangedSignal("TurretMilestoneProgress"):Connect(updateMilestoneHUD)
Player:GetAttributeChangedSignal("TurretMilestonePending"):Connect(updateMilestoneHUD)

-- İlk Kontrol
task.spawn(function()
    task.wait(0.5)
    checkClassActive()
end)
