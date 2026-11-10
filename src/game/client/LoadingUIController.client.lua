-- ============================================================
-- LOADING SCREEN UI (Premium Opaque Transition)
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local ReturnToLobby = Events:WaitForChild("ReturnToLobby")

local function showLoadingScreen()
    -- Eğer zaten varsa mükerrer oluşturma
    if PlayerGui:FindFirstChild("LoadingScreenUI") then return end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "LoadingScreenUI"
    sg.DisplayOrder = 999999 -- Her şeyin üstünde görünmesi için
    sg.IgnoreGuiInset = true -- Ekranın en üstünü de kaplaması için
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14) -- Derin obsidian rengi (tamamen opak)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Visible = true
    frame.Parent = sg
    
    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.new(0, 600, 0, 60)
    logo.Position = UDim2.new(0.5, -300, 0.45, -30)
    logo.BackgroundTransparency = 1
    logo.Text = "RETURNING TO LOBBY"
    logo.TextColor3 = Color3.fromRGB(245, 245, 250)
    logo.Font = Enum.Font.FredokaOne
    logo.TextSize = 42
    logo.TextXAlignment = Enum.TextXAlignment.Center
    logo.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 3
    stroke.Parent = logo
    
    -- Dönen Yükleme İkonu (Spinner)
    local spinner = Instance.new("ImageLabel")
    spinner.Size = UDim2.new(0, 50, 0, 50)
    spinner.Position = UDim2.new(0.5, -25, 0.45, 60)
    spinner.BackgroundTransparency = 1
    spinner.Image = "rbxassetid://6072120015" -- Standart dairesel gradyan yükleme ikonu
    spinner.ImageColor3 = Color3.fromRGB(0, 170, 255) -- Canlı Mavi
    spinner.Parent = frame
    
    sg.Parent = PlayerGui
    
    -- Animasyonlar
    task.spawn(function()
        -- İlk değerleri sıfırla (Fade-in için)
        frame.BackgroundTransparency = 1
        logo.TextTransparency = 1
        stroke.Transparency = 1
        spinner.ImageTransparency = 1
        
        TweenService:Create(frame, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        TweenService:Create(logo, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
        TweenService:Create(spinner, TweenInfo.new(0.3), {ImageTransparency = 0}):Play()
        
        task.wait(0.3)
        
        -- Dönme Animasyonu (C++ Tarafında Çalışan Sıfır CPU Tween)
        local rotateTween = TweenService:Create(spinner, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
        rotateTween:Play()
        
        -- Metinlerin nefes alma (pulsing) animasyonu
        while sg and sg.Parent do
            local fadeOutLogo = TweenService:Create(logo, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {TextTransparency = 0.4})
            fadeOutLogo:Play()
            task.wait(1)
            local fadeInLogo = TweenService:Create(logo, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {TextTransparency = 0})
            fadeInLogo:Play()
            task.wait(1)
        end
    end)
end

-- Sunucudan gelen dönüş sinyalini (OnClientEvent) dinle ve arayüzü göster
ReturnToLobby.OnClientEvent:Connect(showLoadingScreen)
