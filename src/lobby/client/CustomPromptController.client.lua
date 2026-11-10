local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local activePromptUIs = {}

-- Klas ve Şık bir "Özel Prompt" tasarımı oluşturur
local function createCustomPromptUI(prompt)
    local vis = LobbyConfig.Visuals
    local isShop = (prompt.Name == "ShopPrompt" or string.find(string.lower(prompt.ActionText or ""), "shop") ~= nil)
    
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "CustomPrompt"
    bgui.AlwaysOnTop = true
    bgui.ResetOnSpawn = false
    bgui.Active = true
    
    local uiSize = vis.ClassNPC_UI_Size or Vector2.new(190, 45)
    bgui.Size = UDim2.new(0, 0, 0, 0) -- Başlangıçta 0 animasyon için
    bgui.StudsOffset = Vector3.new(0, vis.ClassNPC_UI_HeightOffset or 3, 0)
    bgui.LightInfluence = 0
    bgui.MaxDistance = 0 -- Kameraya göre değil, ProximityPrompt'un karakter mesafesine göre görünsün
    
    -- Tıklanabilir TextButton (Hem fareyle tıklama hem dokunmatik destekli)
    local button = Instance.new("TextButton")
    button.Name = "PromptButton"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.Position = UDim2.new(0.5, 0, 0.5, 0)
    button.BackgroundColor3 = vis.ClassNPC_BackgroundColor or Color3.fromRGB(15, 15, 15)
    button.BackgroundTransparency = vis.ClassNPC_BackgroundTransparency or 0.2
    button.AutoButtonColor = false
    button.Active = true
    button.Text = ""
    button.Parent = bgui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = isShop and Color3.fromRGB(255, 190, 45) or (vis.ClassNPC_StrokeColor or Color3.fromRGB(55, 175, 255))
    stroke.Thickness = 2
    stroke.Parent = button
    
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(0.25, 0, 1, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Active = false
    keyLabel.Font = Enum.Font.Arcade
    keyLabel.TextSize = vis.ClassNPC_UI_TextSize or 22
    keyLabel.TextColor3 = isShop and Color3.fromRGB(255, 215, 75) or (vis.ClassNPC_KeyColor or Color3.fromRGB(55, 175, 255))
    keyLabel.Text = "[" .. string.gsub(prompt.KeyboardKeyCode.Name, "Return", "Enter") .. "]"
    keyLabel.Parent = button
    
    local actionLabel = Instance.new("TextLabel")
    actionLabel.Name = "ActionLabel"
    actionLabel.Size = UDim2.new(0.75, 0, 1, 0)
    actionLabel.Position = UDim2.new(0.25, 0, 0, 0)
    actionLabel.BackgroundTransparency = 1
    actionLabel.Active = false
    actionLabel.Font = Enum.Font.Arcade
    actionLabel.TextSize = vis.ClassNPC_UI_TextSize or 18
    actionLabel.TextColor3 = vis.ClassNPC_ActionTextColor or Color3.fromRGB(255, 255, 255)
    actionLabel.Text = prompt.ActionText
    actionLabel.TextXAlignment = Enum.TextXAlignment.Left
    actionLabel.Parent = button
    
    -- HOVER EFEKTİ (Fare üstüne geldiğinde parlama)
    button.MouseEnter:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Thickness = 3}):Play()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Thickness = 2}):Play()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = vis.ClassNPC_BackgroundTransparency or 0.2}):Play()
    end)
    
    -- TIKLAMA İŞLEMİ (UI'ın üstüne tıklandığında da açılsın)
    button.Activated:Connect(function()
        -- Basılma animasyonu (hafif küçülüp büyüme)
        local pressTween = TweenService:Create(button, TweenInfo.new(0.06), {Size = UDim2.new(0.93, 0, 0.93, 0)})
        pressTween:Play()
        pressTween.Completed:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 1, 0)}):Play()
        end)
        
        -- ProximityPrompt'u tetikle (Roblox standardı)
        prompt:InputHoldBegin()
        prompt:InputHoldEnd()
    end)
    
    return bgui, button
end

-- Roblox'un standart etkileşim sistemi bizim "Custom" taglı nesnelerimizi algıladığında
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
    if prompt.Style == Enum.ProximityPromptStyle.Custom then
        local vis = LobbyConfig.Visuals
        local uiSize = vis.ClassNPC_UI_Size or Vector2.new(190, 45)
        
        -- Eğer zaten varsa eskisini temizle
        if activePromptUIs[prompt] then
            activePromptUIs[prompt]:Destroy()
            activePromptUIs[prompt] = nil
        end
        
        local bgui, button = createCustomPromptUI(prompt)
        
        -- Tıklanabilir olabilmesi için PlayerGui altında durmalı ve Adornee part'a bağlanmalı
        bgui.Adornee = prompt.Parent
        bgui.Parent = playerGui
        activePromptUIs[prompt] = bgui
        
        local actionLabel = button:FindFirstChild("ActionLabel")
        if actionLabel then
            local conn = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
                actionLabel.Text = prompt.ActionText
            end)
            bgui.Destroying:Connect(function()
                conn:Disconnect()
            end)
        end
        
        -- Yaylanarak (Back) ekrana gelme efekti
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        local tween = TweenService:Create(bgui, tweenInfo, {Size = UDim2.new(0, uiSize.X, 0, uiSize.Y)})
        tween:Play()
    end
end)

-- Oyuncu uzaklaştığında yazıyı yumuşakça yok et
ProximityPromptService.PromptHidden:Connect(function(prompt, inputType)
    if prompt.Style == Enum.ProximityPromptStyle.Custom then
        local bgui = activePromptUIs[prompt]
        if bgui then
            activePromptUIs[prompt] = nil
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
            local tween = TweenService:Create(bgui, tweenInfo, {Size = UDim2.new(0, 0, 0, 0)})
            tween:Play()
            tween.Completed:Connect(function()
                bgui:Destroy()
            end)
        end
    end
end)
