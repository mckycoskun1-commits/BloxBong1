local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
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

--[[ Automatically handle text wrapping and size scaling for Arcade font to prevent overflows
local originalInstanceNew = Instance.new
local Instance = {
    new = function(className, parent)
        local inst = originalInstanceNew(className, parent)
        if className == "TextLabel" or className == "TextButton" or className == "TextBox" then
            inst.TextWrapped = true
            
            local function applyArcadeScale()
                if inst.Font == Enum.Font.Arcade then
                    if not inst:GetAttribute("ScaledForArcade") then
                        inst:SetAttribute("ScaledForArcade", true)
                        inst.TextSize = math.clamp(math.round(inst.TextSize * 0.78), 8, 100)
                    end
                end
            end
            
            inst:GetPropertyChangedSignal("Font"):Connect(applyArcadeScale)
            inst:GetPropertyChangedSignal("TextSize"):Connect(function()
                if inst.Font == Enum.Font.Arcade and not inst:GetAttribute("ScalingInProgress") then
                    inst:SetAttribute("ScalingInProgress", true)
                    inst.TextSize = math.clamp(math.round(inst.TextSize * 0.78), 8, 100)
                    inst:SetAttribute("ScalingInProgress", nil)
                end
            end)
            
            task.spawn(applyArcadeScale)
        end
        return inst
    end
} ]]--


local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

---------------------------------------------------------
-- [ KAMERA AYARLARI ]
-- Kamera açısını ve konumunu buradan değiştirebilirsin!
-- CAMERA_POS: Kameranın haritadaki konumu (X, Y, Z)
-- CAMERA_LOOK: Kameranın nereye baktığı (X, Y, Z)
---------------------------------------------------------
local CAMERA_POS = Vector3.new(9, 87.5, 107)
local CAMERA_LOOK = Vector3.new(9, 5, 45)
---------------------------------------------------------

-- Ana Ekran UI Oluşturma
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainMenuGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
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

-- Arka Plan Karartma (Opsiyonel, daha şık durması için)
local bgFrame = Instance.new("Frame")
bgFrame.Size = UDim2.new(10, 0, 10, 0)
bgFrame.Position = UDim2.new(-4.5, 0, -4.5, 0)
bgFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
bgFrame.BackgroundTransparency = 0.3
bgFrame.BorderSizePixel = 0
bgFrame.ZIndex = 1
bgFrame.Parent = screenGui

-- Blur Efekti Oluşturma
local blur = Instance.new("BlurEffect")
blur.Size = 24
blur.Parent = Lighting

-- Yükleniyor Yazısı
local loadingText = Instance.new("TextLabel")
loadingText.Size = UDim2.new(1, 0, 0, 100)
loadingText.Position = UDim2.new(0, 0, 0.5, -50)
loadingText.BackgroundTransparency = 1
loadingText.Font = Enum.Font.FredokaOne
loadingText.Text = "LOADING..."
loadingText.TextSize = 48
loadingText.TextColor3 = Color3.fromRGB(255, 255, 255)
loadingText.ZIndex = 2
loadingText.Parent = screenGui

-- Play Butonu
local playBtn = Instance.new("TextButton")
playBtn.Size = UDim2.new(0, 300, 0, 80)
playBtn.Position = UDim2.new(0.5, -150, 0.7, -40)
playBtn.BackgroundColor3 = Color3.fromRGB(45, 220, 85)
playBtn.Text = "PLAY"
playBtn.Font = Enum.Font.FredokaOne
playBtn.TextSize = 42
playBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
playBtn.Visible = false
playBtn.ZIndex = 2
playBtn.Parent = screenGui

local playCorner = Instance.new("UICorner")
playCorner.CornerRadius = UDim.new(0, 16)
playCorner.Parent = playBtn

local playStroke = Instance.new("UIStroke")
playStroke.Color = Color3.fromRGB(0, 0, 0)
playStroke.Thickness = 3
playStroke.Parent = playBtn

-- Buton Animasyonları
playBtn.MouseEnter:Connect(function()
    TweenService:Create(playBtn, TweenInfo.new(0.2), {Size = UDim2.new(0, 320, 0, 90), Position = UDim2.new(0.5, -160, 0.7, -45)}):Play()
end)

playBtn.MouseLeave:Connect(function()
    TweenService:Create(playBtn, TweenInfo.new(0.2), {Size = UDim2.new(0, 300, 0, 80), Position = UDim2.new(0.5, -150, 0.7, -40)}):Play()
end)


-- Başlangıç Ayarları: Diğer UI'ların orijinal durumlarını saklayıp geçici olarak gizle
local originalStates = {}
local childAddedConn = nil

local function disableGui(gui)
    if gui:IsA("ScreenGui") and gui.Name ~= "MainMenuGui" then
        if originalStates[gui] == nil then
            originalStates[gui] = gui.Enabled
        end
        gui.Enabled = false
    end
end

local function lockOtherGuis()
    -- Mevcut UI'ları gizle
    for _, child in ipairs(PlayerGui:GetChildren()) do
        disableGui(child)
    end
    -- Yeni eklenen UI'ları da otomatik yakalayıp gizle
    childAddedConn = PlayerGui.ChildAdded:Connect(function(child)
        disableGui(child)
    end)
end

local function restoreOtherGuis()
    if childAddedConn then
        childAddedConn:Disconnect()
        childAddedConn = nil
    end
    -- Orijinal durumlarını geri yükle
    for gui, wasEnabled in pairs(originalStates) do
        if gui and gui.Parent then
            gui.Enabled = wasEnabled
        end
    end
end

-- Kamerayı sabitle
local function lockCamera()
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = CFrame.new(CAMERA_POS, CAMERA_LOOK)
end

lockCamera()
lockOtherGuis()

pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

-- Hareketleri durdur (Karakter yüklendiğinde)
local Controls = nil
task.spawn(function()
    local PlayerModule = Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
    Controls = require(PlayerModule):GetControls()
    Controls:Disable()
end)

-- Kamera bazen karakter doğduğunda sıfırlanabilir, o yüzden Play basılana kadar sabit kalmasını zorlayalım:
local camConnection
camConnection = RunService.RenderStepped:Connect(function()
    if screenGui.Parent then
        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CFrame = CFrame.new(CAMERA_POS, CAMERA_LOOK)
    end
end)


-- OYUN YÜKLENMESİNİ BEKLE
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Yükleme Efekti
local dots = 0
local loadingLoop = task.spawn(function()
    while playBtn.Visible == false do
        dots = (dots + 1) % 4
        loadingText.Text = "LOADING" .. string.rep(".", dots)
        task.wait(0.4)
    end
end)

-- Oyun Assets yüklemesi için ContentProvider
task.spawn(function()
    -- workspace içindeki büyük parçaları önden yükle
    pcall(function()
        local ContentProvider = game:GetService("ContentProvider")
        ContentProvider:PreloadAsync({workspace})
    end)
end)

task.wait(2) -- En az 2 saniye yükleme ekranı göstererek şık bir his yarat

-- Yükleme bitti!
task.cancel(loadingLoop)
loadingText.Visible = false
playBtn.Visible = true


-- PLAY BUTONUNA TIKLANDIĞINDA
playBtn.MouseButton1Click:Connect(function()
    -- Buton tıklama efekti
    TweenService:Create(playBtn, TweenInfo.new(0.1), {Size = UDim2.new(0, 280, 0, 70), Position = UDim2.new(0.5, -140, 0.7, -35)}):Play()
    task.wait(0.1)
    
    -- Kamera Döngüsünü İptal Et
    if camConnection then
        camConnection:Disconnect()
        camConnection = nil
    end

    -- Menüyü Sil
    screenGui:Destroy()
    
    -- Blur Efektini Yavaşça Kaldır
    local blurTween = TweenService:Create(blur, TweenInfo.new(1, Enum.EasingStyle.Sine), {Size = 0})
    blurTween:Play()
    blurTween.Completed:Connect(function()
        blur:Destroy()
    end)
    
    -- Kamerayı Karakterine Geri Ver
    Camera.CameraType = Enum.CameraType.Custom
    
    -- UI'ları ve Hareketi Geri Aç
    restoreOtherGuis()
    
    if Controls then
        Controls:Enable()
    end
    
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
    end)
end)
