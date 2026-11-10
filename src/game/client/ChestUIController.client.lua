local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")

local PlayChestAnimationEvent = Events:WaitForChild("PlayChestAnimation")
local ChestAwardedEvent = Events:WaitForChild("ChestAwarded")
local ChestClaimedEvent = Events:WaitForChild("ChestClaimed")

local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))
local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))

-- Setup a BindableEvent to signal HUD to update when inventory changes
local UpdateInventoryUI = Events:FindFirstChild("UpdateInventoryUI")
if not UpdateInventoryUI then
    UpdateInventoryUI = Instance.new("BindableEvent")
    UpdateInventoryUI.Name = "UpdateInventoryUI"
    UpdateInventoryUI.Parent = Events
end

-- Font overriding logic for pixel aesthetic
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
})

-- Helper to extract cost details from ProximityPrompt ActionText
local function getCostDetails(prompt)
    local promptType = prompt:GetAttribute("PromptType")
    local isBoss = promptType == "BossChest"
    local isPot = promptType == "Pot"
    local actionText = prompt.ActionText or ""
    
    if isBoss or isPot then
        return "FREE", false
    end
    
    local cost = string.match(actionText, "%d+")
    if cost then
        return cost, true
    else
        return "30", true
    end
end

-- Özel Sandık Etkileşim UI'ı (Custom Prompt)
local function createChestPromptUI(prompt)
    local promptType = prompt:GetAttribute("PromptType")
    local isBoss = promptType == "BossChest"
    local isPot = promptType == "Pot"
    local costText, hasCoin = getCostDetails(prompt)
    
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "CustomPrompt"
    bgui.AlwaysOnTop = true
    bgui.Size = UDim2.new(0, 0, 0, 0) -- Starts at zero for tween pop-in
    bgui.StudsOffset = Vector3.new(0, 0, 0)
    local offsetHeight = 2.6
    if isPot and prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent:IsA("Model") then
        local bboxCFrame, bboxSize = prompt.Parent.Parent:GetBoundingBox()
        offsetHeight = (bboxSize.Y / 2) + 0.6
    elseif isPot then
        offsetHeight = 1.8
    end
    bgui.StudsOffsetWorldSpace = Vector3.new(0, offsetHeight, 0)
    bgui.LightInfluence = 0
    bgui.MaxDistance = math.huge
    bgui.Adornee = prompt.Parent 
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1 -- Şeffaf arka plan
    frame.Parent = bgui
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.SortOrder = globalEnum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0.05, 0)
    listLayout.Parent = frame
    
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Name = "KeyLabel"
    keyLabel.Size = isPot and UDim2.new(0.9, 0, 0.9, 0) or UDim2.new(0.26, 0, 0.84, 0)
    keyLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    keyLabel.BackgroundTransparency = 0.15
    keyLabel.Font = globalEnum.Font.GothamBold -- Bypasses Arcade override metatable
    keyLabel.TextScaled = true
    keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyLabel.Text = prompt.KeyboardKeyCode.Name
    keyLabel.LayoutOrder = 1
    keyLabel.Parent = frame
    
    local keyPadding = Instance.new("UIPadding")
    keyPadding.PaddingTop = UDim.new(0.15, 0)
    keyPadding.PaddingBottom = UDim.new(0.15, 0)
    keyPadding.PaddingLeft = UDim.new(0.15, 0)
    keyPadding.PaddingRight = UDim.new(0.15, 0)
    keyPadding.Parent = keyLabel
    
    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 8)
    keyCorner.Parent = keyLabel
    
    local keyStroke = Instance.new("UIStroke")
    keyStroke.Color = Color3.fromRGB(255, 255, 255)
    keyStroke.Thickness = 2
    keyStroke.ApplyStrokeMode = globalEnum.ApplyStrokeMode.Border
    keyStroke.Parent = keyLabel
    
    if not isPot then
        local costLabel = Instance.new("TextLabel")
        costLabel.Name = "CostLabel"
        costLabel.Size = UDim2.new(0.38, 0, 0.84, 0)
        costLabel.BackgroundTransparency = 1
        costLabel.Font = Enum.Font.Arcade
        costLabel.TextScaled = true
        
        local textColor = Color3.fromRGB(255, 200, 50)
        if isBoss then
            textColor = Color3.fromRGB(220, 30, 30)
        end
        costLabel.TextColor3 = textColor
        costLabel.Text = costText
        costLabel.TextXAlignment = Enum.TextXAlignment.Center
        costLabel.TextYAlignment = Enum.TextYAlignment.Center
        costLabel.LayoutOrder = 2
        costLabel.Parent = frame
        
        local costPadding = Instance.new("UIPadding")
        costPadding.PaddingTop = UDim.new(0.08, 0)
        costPadding.PaddingBottom = UDim.new(0.08, 0)
        costPadding.Parent = costLabel
        
        local coinIcon = Instance.new("ImageLabel")
        coinIcon.Name = "CoinIcon"
        coinIcon.Size = UDim2.new(0.2, 0, 0.64, 0)
        coinIcon.BackgroundTransparency = 1
        coinIcon.Image = "rbxassetid://126941861587473"
        coinIcon.Visible = hasCoin
        coinIcon.LayoutOrder = 3
        coinIcon.Parent = frame
    end
    
    return bgui, frame
end

ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt.Style == Enum.ProximityPromptStyle.Custom then
        local isBoss = prompt:GetAttribute("PromptType") == "BossChest"
        local isMapChest = prompt:GetAttribute("PromptType") == "MapChest"
        local isPot = prompt:GetAttribute("PromptType") == "Pot"
        
        if prompt.Parent:FindFirstChild("CustomPrompt") then
            prompt.Parent.CustomPrompt:Destroy()
        end
        
        local bgui, frame = createChestPromptUI(prompt)
        bgui.Parent = prompt.Parent 
        
        local costLabel = frame:FindFirstChild("CostLabel")
        local coinIcon = frame:FindFirstChild("CoinIcon")
        
        local textConn = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
            if costLabel and coinIcon then
                local costText, hasCoin = getCostDetails(prompt)
                costLabel.Text = costText
                coinIcon.Visible = hasCoin
            end
        end)
        
        -- Karakter uzaklığına göre sandık arayüzünü göster/gizle (Canavarlardaki gibi karakter mesafesi)
        local heartbeatConn
        heartbeatConn = RunService.Heartbeat:Connect(function()
            if not bgui or not bgui.Parent or not prompt or not prompt.Parent then
                if heartbeatConn then
                    heartbeatConn:Disconnect()
                end
                return
            end
            
            local char = Player.Character
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")
            local targetPart = prompt.Parent
            local isUpgradeOpen = PlayerGui:FindFirstChild("UpgradeUI") ~= nil or Player:GetAttribute("IsChoosingUpgrade") == true
            if rootPart and targetPart and not isUpgradeOpen and not ReplicatedStorage:GetAttribute("IsPaused") then
                local dist = (rootPart.Position - targetPart:GetPivot().Position).Magnitude
                bgui.Enabled = (dist <= prompt.MaxActivationDistance)
            else
                bgui.Enabled = false
            end
        end)
        
        bgui.Destroying:Connect(function()
            textConn:Disconnect()
            if heartbeatConn then
                heartbeatConn:Disconnect()
            end
        end)
        
        local targetSize = isPot and UDim2.new(1.4, 0, 1.4, 0) or UDim2.new(4.5, 0, 1.4, 0)
        TweenService:Create(bgui, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    if prompt.Style == Enum.ProximityPromptStyle.Custom then
        if prompt.Parent then
            for _, child in ipairs(prompt.Parent:GetChildren()) do
                if child.Name == "CustomPrompt" then
                    TweenService:Create(child, TweenInfo.new(0.15), {Size = UDim2.new(0, 0, 0, 0)}):Play()
                    task.delay(0.15, function()
                        child:Destroy()
                    end)
                end
            end
        end
    end
end)

-- Çalı Kırma Sesleri (Gecikmesiz Anında Çalma Sistemi)
local PlayBushBreakEvent = Events:WaitForChild("PlayBushBreak", 5)
if PlayBushBreakEvent then
    PlayBushBreakEvent.OnClientEvent:Connect(function(potPos, triggeringPlayer)
        -- Eğer başka bir oyuncu kırdıysa sesi 3D olarak çal
        if triggeringPlayer ~= Player and potPos then
            SoundManager.PlaySound("BushBreak", potPos)
        end
    end)
end

-- Yerel oyuncu çalıyı (Pot) tetiklediği anda HİÇBİR sunucu gecikmesi (0ms ping) olmadan sesi anında patlat
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
    if triggeringPlayer == Player and prompt:GetAttribute("PromptType") == "Pot" then
        local targetPart = prompt.Parent
        local pos = targetPart and targetPart.Position
        if not pos then
            local model = prompt:FindFirstAncestorWhichIsA("Model")
            pos = model and model:GetPivot().Position
        end
        if pos then
            SoundManager.PlaySound("BushBreak", pos)
        end
    end
end)



-- Play chest lid rotate / glow / dissolve animation locally
local function playChestAnimation(chest)
    if not chest or not chest.Parent then return end
    
    local function tweenModelPivot(model, targetCFrame, duration)
        local val = Instance.new("NumberValue")
        val.Value = 0
        local startCFrame = model:GetPivot()
        local connection = val.Changed:Connect(function(t)
            if model and model.Parent then
                model:PivotTo(startCFrame:Lerp(targetCFrame, t))
            end
        end)
        local tween = TweenService:Create(val, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = 1})
        tween:Play()
        tween.Completed:Connect(function()
            connection:Disconnect()
            val:Destroy()
        end)
    end
    
    local lid = chest:FindFirstChild("Lid")
    if lid then
        local lidStartPivot = lid:GetPivot()
        local targetCFrame = lidStartPivot * CFrame.Angles(math.rad(-70), 0, 0)
        tweenModelPivot(lid, targetCFrame, 0.4)
    end
    
    local primaryPart = chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        local attachment = Instance.new("Attachment", primaryPart)
        
        local light = Instance.new("PointLight", primaryPart)
        light.Color = chest.Name == "BossChest" and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 215, 0)
        light.Range = 8
        light.Brightness = 0
        
        local lightTween = TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 2.5})
        lightTween:Play()
        lightTween.Completed:Connect(function()
            TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Brightness = 0}):Play()
        end)
        
        local particles = Instance.new("ParticleEmitter", attachment)
        particles.Texture = "rbxassetid://241537084"
        particles.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.2, 0.5),
            NumberSequenceKeypoint.new(1, 0)
        })
        particles.Color = ColorSequence.new(chest.Name == "BossChest" and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 215, 0))
        particles.Lifetime = NumberRange.new(0.3, 0.5)
        particles.Rate = 40
        particles.Speed = NumberRange.new(4, 8)
        particles.VelocityInheritance = 0
        particles.SpreadAngle = Vector2.new(45, 45)
        particles.EmissionDirection = Enum.NormalId.Top
        
        task.delay(0.2, function()
            if particles then particles.Enabled = false end
        end)
        
        task.delay(0.5, function()
            local val = Instance.new("NumberValue")
            val.Value = 0
            local connection = val.Changed:Connect(function(t)
                if chest and chest.Parent then
                    for _, part in ipairs(chest:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Transparency = math.clamp(t, 0, 1)
                        end
                    end
                end
            end)
            local tween = TweenService:Create(val, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Value = 1})
            tween:Play()
            tween.Completed:Connect(function()
                connection:Disconnect()
                val:Destroy()
            end)
        end)
    end
end
PlayChestAnimationEvent.OnClientEvent:Connect(playChestAnimation)

-- Pop up a card flipping presentation modal with roulette spin
local function showChestAwardUI(itemKey, rarity, amount)
    local actualItemInfo = ItemConfig.Items[itemKey]
    if not actualItemInfo then return end
    
    -- Fetch total owned count of this item
    local itemCount = amount or 1
    local ClientGetPlayerData = Events:FindFirstChild("ClientGetPlayerData")
    if ClientGetPlayerData then
        local success, pData = pcall(function()
            return ClientGetPlayerData:InvokeServer()
        end)
        if success and pData and pData.Items and pData.Items[itemKey] then
            itemCount = pData.Items[itemKey]
        end
    end
    
    -- Tiered VFX Configuration based on Item Rarity
    local vfxConfig = {
        Common = {
            GodRayCount = 0,
            GodRayTransparency = 1,
            AmbientSparksRate = 0.04,
            BurstParticles = 6,
            HasShockwave = false,
            ShockwaveSize = 0,
            HasSheen = false,
            GlowTransparency = 0.85
        },
        Uncommon = {
            GodRayCount = 1,
            GodRayTransparency = 0.80,
            AmbientSparksRate = 0.15,
            BurstParticles = 12,
            HasShockwave = true,
            ShockwaveSize = 220,
            HasSheen = true,
            GlowTransparency = 0.70
        },
        Rare = {
            GodRayCount = 1,
            GodRayTransparency = 0.65,
            AmbientSparksRate = 0.25,
            BurstParticles = 18,
            HasShockwave = true,
            ShockwaveSize = 280,
            HasSheen = true,
            GlowTransparency = 0.60
        },
        Epic = {
            GodRayCount = 2,
            GodRayTransparency = 0.50,
            AmbientSparksRate = 0.40,
            BurstParticles = 30,
            HasShockwave = true,
            ShockwaveSize = 340,
            HasSheen = true,
            GlowTransparency = 0.45
        },
        Legendary = {
            GodRayCount = 2,
            GodRayTransparency = 0.30,
            AmbientSparksRate = 0.65,
            BurstParticles = 48,
            HasShockwave = true,
            ShockwaveSize = 420,
            HasSheen = true,
            GlowTransparency = 0.30
        }
    }
    local tierVFX = vfxConfig[rarity] or vfxConfig.Common

    local spinConnection, floatConnection, ambientParticleConnection
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ChestAwardUI"
    screenGui.DisplayOrder = 500
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = PlayerGui

    -- Dynamic UI Scaling for Mobile & Desktop
    local uiScale = Instance.new("UIScale")
    uiScale.Parent = screenGui
    local function updateScale()
        local viewport = workspace.CurrentCamera.ViewportSize
        local scale = math.min(viewport.X / 1400, viewport.Y / 800)
        uiScale.Scale = math.clamp(scale, 0.6, 2.2)
    end
    local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    ProximityPromptService.Enabled = false
    updateScale()
    screenGui.Destroying:Connect(function()
        if viewportConnection then viewportConnection:Disconnect() end
        if spinConnection then spinConnection:Disconnect() end
        if floatConnection then floatConnection:Disconnect() end
        if ambientParticleConnection then ambientParticleConnection:Disconnect() end
        if not PlayerGui:FindFirstChild("UpgradeUI") and not Player:GetAttribute("IsChoosingUpgrade") then
            ProximityPromptService.Enabled = true
        end
    end)
    
    -- Clean Dark Backdrop Overlay (0.6 Transparency)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(10, 0, 10, 0)
    bg.Position = UDim2.new(-4.5, 0, -4.5, 0)
    bg.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
    bg.BackgroundTransparency = 1
    bg.Parent = screenGui
    
    TweenService:Create(bg, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.4}):Play()
    
    local blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Parent = game:GetService("Lighting")
    TweenService:Create(blur, TweenInfo.new(0.35), {Size = 24}):Play()
    
    -- Clean Rarity Color Palette Definitions
    local rarityColors = {
        Common = Color3.fromRGB(180, 190, 205),
        Uncommon = Color3.fromRGB(40, 170, 255),
        Rare = Color3.fromRGB(40, 170, 255),
        Epic = Color3.fromRGB(170, 60, 255),
        Legendary = Color3.fromRGB(255, 190, 30)
    }
    local activeColor = rarityColors[rarity] or actualItemInfo.Color or Color3.fromRGB(255, 190, 30)
    local mysteryColor = Color3.fromRGB(140, 155, 185) -- Neutral mystery silver during roulette spin
    
    -- Main Canvas: Deep Slate Glassmorphism Frame
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 480, 0, 600)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = bg
    
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
    
    -- Background Gradient (Starts Neutral Mystery Silver during spin)
    local cardGradient = Instance.new("UIGradient", card)
    local neutralTopColor = mysteryColor:Lerp(Color3.fromRGB(15, 18, 26), 0.8)
    local bottomColor = Color3.fromRGB(12, 14, 20)
    cardGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, neutralTopColor),
        ColorSequenceKeypoint.new(1, bottomColor)
    })
    cardGradient.Rotation = 90
    
    -- Outer Border Stroke (Starts Neutral Mystery Silver)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.ApplyStrokeMode = globalEnum.ApplyStrokeMode.Border
    stroke.Color = mysteryColor
    stroke.Parent = card

    local strokeGradient = Instance.new("UIGradient")
    strokeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, mysteryColor),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    })
    strokeGradient.Rotation = 45
    strokeGradient.Parent = stroke

    -- ROTATING SUNBURST GOD RAYS (HIDDEN during roulette spin!)
    local godRays = Instance.new("ImageLabel")
    godRays.Name = "GodRays"
    godRays.Size = UDim2.new(2.4, 0, 2.4, 0)
    godRays.Position = UDim2.new(-0.7, 0, -0.7, 0)
    godRays.BackgroundTransparency = 1
    godRays.Image = "rbxassetid://4996891970"
    godRays.ImageColor3 = mysteryColor
    godRays.ImageTransparency = 1
    godRays.Visible = false -- Kept hidden until spin lands!
    godRays.ZIndex = card.ZIndex - 2
    godRays.Parent = card

    local godRays2 = godRays:Clone()
    godRays2.Size = UDim2.new(3.0, 0, 3.0, 0)
    godRays2.Position = UDim2.new(-1.0, 0, -1.0, 0)
    godRays2.ImageTransparency = 1
    godRays2.Visible = false
    godRays2.ZIndex = card.ZIndex - 3
    godRays2.Parent = card
    
    -- Radial Ambient Glow behind Card (Neutral during spin)
    local glow = Instance.new("ImageLabel")
    glow.Name = "Glow"
    glow.Size = UDim2.new(1.8, 0, 1.8, 0)
    glow.Position = UDim2.new(-0.4, 0, -0.4, 0)
    glow.BackgroundTransparency = 1
    glow.Image = "rbxassetid://5028824237"
    glow.ImageColor3 = mysteryColor
    glow.ImageTransparency = 0.85
    glow.ZIndex = card.ZIndex - 1
    glow.Parent = card
    
    -- SHINY CARD SHEEN SWIPE EFFECT
    local sheenFrame = Instance.new("Frame", card)
    sheenFrame.Size = UDim2.new(0, 70, 1.4, 0)
    sheenFrame.Position = UDim2.new(-0.5, 0, -0.2, 0)
    sheenFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sheenFrame.BackgroundTransparency = 1
    sheenFrame.BorderSizePixel = 0
    sheenFrame.Rotation = 25
    sheenFrame.ZIndex = card.ZIndex + 8

    local sheenGradient = Instance.new("UIGradient", sheenFrame)
    sheenGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.45),
        NumberSequenceKeypoint.new(1, 1)
    })

    local function playCardSheen()
        if not tierVFX.HasSheen then return end
        sheenFrame.Position = UDim2.new(-0.5, 0, -0.2, 0)
        TweenService:Create(sheenFrame, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(1.5, 0, -0.2, 0)
        }):Play()
    end
    
    -- 2D UI PARTICLE CONTAINER
    local particleContainer = Instance.new("Frame", card)
    particleContainer.Size = UDim2.new(1, 0, 1, 0)
    particleContainer.BackgroundTransparency = 1
    particleContainer.ZIndex = card.ZIndex + 10

    -- Function to emit particle sparkles explosion outward
    local function emitParticleBurst(originPos, count, color)
        if count <= 0 then return end
        for _ = 1, count do
            local p = Instance.new("ImageLabel")
            local sz = math.random(10, 22)
            p.Size = UDim2.new(0, sz, 0, sz)
            p.Position = originPos
            p.AnchorPoint = Vector2.new(0.5, 0.5)
            p.BackgroundTransparency = 1
            p.Image = "rbxassetid://6031097225"
            p.ImageColor3 = color or activeColor
            p.ZIndex = card.ZIndex + 10
            p.Parent = particleContainer
            
            local angle = math.random() * math.pi * 2
            local dist = math.random(60, 180 + (count * 2))
            local targetPos = originPos + UDim2.new(0, math.cos(angle) * dist, 0, math.sin(angle) * dist)
            
            local dur = 0.5 + math.random() * 0.5
            TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = targetPos,
                ImageTransparency = 1,
                Rotation = math.random(-180, 180),
                Size = UDim2.new(0, 4, 0, 4)
            }):Play()
            
            game:GetService("Debris"):AddItem(p, dur + 0.1)
        end
    end

    -- Expanding Shockwave Ring Effect
    local function playShockwave(originPos, color, targetSize)
        if not tierVFX.HasShockwave then return end
        local ring = Instance.new("ImageLabel")
        ring.Size = UDim2.new(0, 30, 0, 30)
        ring.Position = originPos
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.BackgroundTransparency = 1
        ring.Image = "rbxassetid://4996891970"
        ring.ImageColor3 = color or activeColor
        ring.ImageTransparency = 0.1
        ring.ZIndex = card.ZIndex + 9
        ring.Parent = particleContainer
        
        local maxSz = targetSize or 300
        TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, maxSz, 0, maxSz),
            ImageTransparency = 1,
            Rotation = 90
        }):Play()
        
        game:GetService("Debris"):AddItem(ring, 0.6)
    end

    -- Continuous Ambient Rising Sparks Loop (Neutral low rate during spin)
    local activeSparkRate = 0.05
    ambientParticleConnection = RunService.RenderStepped:Connect(function()
        if math.random() < activeSparkRate and particleContainer and particleContainer.Parent then
            local p = Instance.new("ImageLabel")
            local sz = math.random(8, 16)
            p.Size = UDim2.new(0, sz, 0, sz)
            p.Position = UDim2.new(math.random() * 0.9 + 0.05, 0, 1.05, 0)
            p.AnchorPoint = Vector2.new(0.5, 0.5)
            p.BackgroundTransparency = 1
            p.Image = "rbxassetid://6031097225"
            p.ImageColor3 = (activeSparkRate > 0.05) and activeColor or mysteryColor
            p.ImageTransparency = 0.3
            p.ZIndex = card.ZIndex + 6
            p.Parent = particleContainer
            
            local upwardDist = math.random(150, 350)
            local sideSway = math.random(-40, 40)
            local dur = 1.6 + math.random() * 0.8
            
            TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = UDim2.new(p.Position.X.Scale, sideSway, p.Position.Y.Scale, -upwardDist),
                ImageTransparency = 1,
                Rotation = math.random(-90, 90)
            }):Play()
            
            game:GetService("Debris"):AddItem(p, dur + 0.1)
        end
    end)
    
    spinConnection = RunService.RenderStepped:Connect(function(dt)
        if glow and glow.Parent then
            glow.Rotation = glow.Rotation + 20 * dt
        end
        if godRays and godRays.Parent and godRays.Visible then
            godRays.Rotation = godRays.Rotation + 25 * dt
            godRays.ImageTransparency = tierVFX.GodRayTransparency + math.sin(os.clock() * 3) * 0.1
        end
        if godRays2 and godRays2.Parent and godRays2.Visible then
            godRays2.Rotation = godRays2.Rotation - 15 * dt
        end
    end)
    
    -- Header Title: "CHEST UNLOCKED!"
    local headerTitle = Instance.new("TextLabel", card)
    headerTitle.Size = UDim2.new(1, 0, 0, 46)
    headerTitle.Position = UDim2.new(0, 0, 0, 24)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "CHEST UNLOCKED!"
    headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    headerTitle.Font = Enum.Font.Arcade
    headerTitle.TextSize = 30
    headerTitle.TextStrokeTransparency = 0.6
    
    -- Rarity Badge Pill (Starts Neutral Mystery during spin)
    local badgeFrame = Instance.new("Frame", card)
    badgeFrame.Size = UDim2.new(0, 180, 0, 32)
    badgeFrame.Position = UDim2.new(0.5, -90, 0, 78)
    badgeFrame.BackgroundColor3 = mysteryColor
    badgeFrame.BackgroundTransparency = 0.85
    badgeFrame.BorderSizePixel = 0
    Instance.new("UICorner", badgeFrame).CornerRadius = UDim.new(1, 0)
    
    local badgeStroke = Instance.new("UIStroke", badgeFrame)
    badgeStroke.Color = mysteryColor
    badgeStroke.Thickness = 2
    
    local rarityBadge = Instance.new("TextLabel", badgeFrame)
    rarityBadge.Size = UDim2.new(1, 0, 1, 0)
    rarityBadge.BackgroundTransparency = 1
    rarityBadge.Text = "OPENING..."
    rarityBadge.TextColor3 = mysteryColor
    rarityBadge.Font = Enum.Font.Arcade
    rarityBadge.TextSize = 16
    
    -- Large Square Icon Box (190x190px)
    local iconBox = Instance.new("Frame", card)
    iconBox.Size = UDim2.new(0, 190, 0, 190)
    iconBox.Position = UDim2.new(0.5, -95, 0, 125)
    iconBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    iconBox.BackgroundTransparency = 0.2
    Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 20)
    
    local boxStroke = Instance.new("UIStroke", iconBox)
    boxStroke.Color = mysteryColor
    boxStroke.Thickness = 2.5
    
    local scaleMult = actualItemInfo.IconScale or 1.0
    local icon = Instance.new("ImageLabel", iconBox)
    icon.Size = UDim2.new(0.85 * scaleMult, 0, 0.85 * scaleMult, 0)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Image = actualItemInfo.Icon or ""
    
    -- Quantity Text (e.g. "1x", "2x") on Bottom-Left inside Icon Box (Hidden until item reveal)
    local countText = Instance.new("TextLabel", iconBox)
    countText.Size = UDim2.new(0, 60, 0, 26)
    countText.Position = UDim2.new(0, 10, 1, -30)
    countText.BackgroundTransparency = 1
    countText.Text = tostring(itemCount) .. "x"
    countText.TextColor3 = Color3.fromRGB(255, 255, 255)
    countText.Font = Enum.Font.Arcade
    countText.TextSize = 20
    countText.TextXAlignment = Enum.TextXAlignment.Left
    countText.TextStrokeTransparency = 0.1
    countText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    countText.TextTransparency = 1
    countText.Visible = false -- Kept hidden until spin finishes!
    
    -- Gentle Floating Motion
    local startY = iconBox.Position.Y.Offset
    floatConnection = RunService.RenderStepped:Connect(function()
        if iconBox and iconBox.Parent then
            local offset = math.sin(os.clock() * 3.5) * 6
            iconBox.Position = UDim2.new(0.5, -95, 0, startY + offset)
        end
    end)
    
    -- Massive Item Display Title
    local itemTitle = Instance.new("TextLabel", card)
    itemTitle.Size = UDim2.new(1, -30, 0, 42)
    itemTitle.Position = UDim2.new(0, 15, 0, 335)
    itemTitle.BackgroundTransparency = 1
    itemTitle.Text = "DECRYPTER..."
    itemTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemTitle.Font = Enum.Font.Arcade
    itemTitle.TextSize = 26
    itemTitle.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Item Description (Hidden during spin)
    local descTag = Instance.new("TextLabel", card)
    descTag.Size = UDim2.new(1, -40, 0, 60)
    descTag.Position = UDim2.new(0, 20, 0, 388)
    descTag.BackgroundTransparency = 1
    descTag.Text = ""
    descTag.TextColor3 = Color3.fromRGB(220, 230, 245)
    descTag.Font = Enum.Font.Arcade
    descTag.TextSize = 17
    descTag.TextWrapped = true
    descTag.TextYAlignment = Enum.TextYAlignment.Top
    
    -- Large Prominent Collect Button (Hidden & Disabled during spin to prevent premature click)
    local claimBtn = Instance.new("TextButton", card)
    claimBtn.Size = UDim2.new(0.86, 0, 0, 64)
    claimBtn.Position = UDim2.new(0.07, 0, 0.84, 0)
    claimBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
    claimBtn.Text = ""
    claimBtn.AutoButtonColor = false
    claimBtn.Visible = false -- Kept hidden until spin finishes!
    claimBtn.Active = false
    Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 14)
    
    local btnGradient = Instance.new("UIGradient", claimBtn)
    btnGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 200, 140)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 140, 90))
    })
    btnGradient.Rotation = 90
    
    local btnStroke = Instance.new("UIStroke", claimBtn)
    btnStroke.Color = Color3.fromRGB(255, 255, 255)
    btnStroke.Thickness = 2
    btnStroke.Transparency = 0.7
    
    -- Child TextLabel to prevent parent UIGradient from tinting the text green
    local btnText = Instance.new("TextLabel", claimBtn)
    btnText.Size = UDim2.new(1, 0, 1, 0)
    btnText.BackgroundTransparency = 1
    btnText.Text = "COLLECT ITEM"
    btnText.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnText.TextStrokeTransparency = 0.1
    btnText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    btnText.Font = Enum.Font.Arcade
    btnText.TextSize = 22
    btnText.ZIndex = claimBtn.ZIndex + 2
    
    -- Interactive Button Scale Hover Effects
    claimBtn.MouseEnter:Connect(function()
        TweenService:Create(claimBtn, TweenInfo.new(0.15), {Size = UDim2.new(0.90, 0, 0, 66), Position = UDim2.new(0.05, 0, 0.835, 0)}):Play()
    end)
    claimBtn.MouseLeave:Connect(function()
        TweenService:Create(claimBtn, TweenInfo.new(0.15), {Size = UDim2.new(0.86, 0, 0, 64), Position = UDim2.new(0.07, 0, 0.84, 0)}):Play()
    end)
    
    claimBtn.MouseButton1Click:Connect(function()
        spinConnection:Disconnect()
        floatConnection:Disconnect()
        if ambientParticleConnection then ambientParticleConnection:Disconnect() end
        
        ChestClaimedEvent:FireServer()
        
        TweenService:Create(bg, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
        TweenService:Create(blur, TweenInfo.new(0.25), {Size = 0}):Play()
        TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)}):Play()
        
        task.delay(0.25, function()
            blur:Destroy()
            screenGui:Destroy()
            UpdateInventoryUI:Fire()
        end)
    end)
    
    -- Entry Scale Sequence (Spring Elastic Ease)
    card.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 480, 0, 600)}):Play()
    
    -- Staggered Roulette Spin Presentation (Keeps UI Neutral until Final Landed State)
    task.spawn(function()
        local itemKeys = {}
        for k, item in pairs(ItemConfig.Items) do
            if not item.LockedByDefault or ProgressionManager.IsUnlocked(Player, k) then
                table.insert(itemKeys, k)
            end
        end
        if #itemKeys == 0 then
            table.insert(itemKeys, itemKey)
        end
        
        local spinTime = 0.04
        local totalSpins = 18
        
        for i = 1, totalSpins do
            local randomKey = itemKeys[math.random(1, #itemKeys)]
            local tempItem = ItemConfig.Items[randomKey]
            
            icon.Image = tempItem.Icon or ""
            itemTitle.Text = tempItem.DisplayName:upper()
            
            local tempScale = tempItem.IconScale or 1.0
            icon.Size = UDim2.new(0.65 * tempScale, 0, 0.65 * tempScale, 0)
            TweenService:Create(icon, TweenInfo.new(spinTime), {Size = UDim2.new(0.82 * tempScale, 0, 0.82 * tempScale, 0)}):Play()
            
            task.wait(spinTime)
            if i > totalSpins - 5 then
                spinTime = spinTime + 0.04
            end
        end
        
        -- FINAL LANDED REVEAL STATE (Triggers Rarity Transition & Visual Effects Simultaneously!)
        icon.Image = actualItemInfo.Icon or ""
        itemTitle.Text = actualItemInfo.DisplayName:upper()
        descTag.Text = actualItemInfo.Description or ""
        rarityBadge.Text = rarity:upper() .. " ITEM"
        rarityBadge.TextColor3 = activeColor
        badgeFrame.BackgroundColor3 = activeColor
        badgeStroke.Color = activeColor
        stroke.Color = activeColor
        boxStroke.Color = activeColor
        glow.ImageColor3 = activeColor
        
        cardGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, activeColor:Lerp(Color3.fromRGB(15, 18, 26), 0.75)),
            ColorSequenceKeypoint.new(1, bottomColor)
        })
        strokeGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, activeColor),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
        })
        
        -- Reveal Quantity Count Text ("1x", "2x")
        countText.Visible = true
        TweenService:Create(countText, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
        
        -- Reveal & Enable Collect Button with Spring Pop-In
        claimBtn.Visible = true
        claimBtn.Active = true
        claimBtn.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(claimBtn, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.86, 0, 0, 64),
            Position = UDim2.new(0.07, 0, 0.84, 0)
        }):Play()
        
        -- Activate God Rays based on winning item's Rarity Tier
        godRays.ImageColor3 = activeColor
        godRays2.ImageColor3 = activeColor
        godRays.Visible = (tierVFX.GodRayCount >= 1)
        godRays2.Visible = (tierVFX.GodRayCount >= 2)
        godRays.ImageTransparency = tierVFX.GodRayTransparency
        godRays2.ImageTransparency = math.clamp(tierVFX.GodRayTransparency + 0.15, 0, 1)
        
        -- Trigger Tiered VFX Burst, Shockwave & Sheen right at the reveal moment!
        local centerPos = UDim2.new(0.5, 0, 0.38, 0)
        emitParticleBurst(centerPos, tierVFX.BurstParticles, activeColor)
        playShockwave(centerPos, activeColor, tierVFX.ShockwaveSize)
        playCardSheen()
        
        activeSparkRate = tierVFX.AmbientSparksRate
        
        local finalScale = actualItemInfo.IconScale or 1.0
        icon.Size = UDim2.new(0.3 * finalScale, 0, 0.3 * finalScale, 0)
        TweenService:Create(icon, TweenInfo.new(0.55, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = UDim2.new(0.85 * finalScale, 0, 0.85 * finalScale, 0)}):Play()
        TweenService:Create(glow, TweenInfo.new(0.4), {ImageTransparency = tierVFX.GlowTransparency}):Play()
    end)
end
ChestAwardedEvent.OnClientEvent:Connect(showChestAwardUI)

-- Dynamically fade out Highlights based on distance from the player
task.spawn(function()
    while true do
        task.wait(0.1) -- Run 10 times a second for efficiency
        
        local character = Player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        
        local playerPos = hrp.Position
        
        -- 1. Update Pot Highlights
        local PotsFolder = workspace:FindFirstChild("Pots")
        if PotsFolder then
            for _, pot in ipairs(PotsFolder:GetChildren()) do
                if pot:IsA("Model") then
                    local highlight = pot:FindFirstChild("PotHighlight")
                    if highlight and highlight:IsA("Highlight") then
                        local dist = (pot:GetPivot().Position - playerPos).Magnitude
                        
                        -- Fades from 0.45 (at 40 studs) to 1.0 (at 100 studs)
                        local minTrans = 0.45
                        local fadeStart = 40
                        local fadeEnd = 100
                        
                        local targetTrans = 1.0
                        if dist <= fadeStart then
                            targetTrans = minTrans
                        elseif dist >= fadeEnd then
                            targetTrans = 1.0
                        else
                            local pct = (dist - fadeStart) / (fadeEnd - fadeStart)
                            targetTrans = minTrans + (1.0 - minTrans) * pct
                        end
                        highlight.OutlineTransparency = targetTrans
                    end
                end
            end
        end
        
        -- 2. Update Chest Highlights (ChestHighlight)
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "MapChest" or child.Name == "BossChest" then
                local highlight = child:FindFirstChild("ChestHighlight")
                if highlight and highlight:IsA("Highlight") then
                    local dist = (child:GetPivot().Position - playerPos).Magnitude
                    
                    -- Fades from 0.5 (at 60 studs) to 1.0 (at 150 studs)
                    local minTrans = 0.5
                    local fadeStart = 60
                    local fadeEnd = 150
                    
                    local targetTrans = 1.0
                    if dist <= fadeStart then
                        targetTrans = minTrans
                    elseif dist >= fadeEnd then
                        targetTrans = 1.0
                    else
                        local pct = (dist - fadeStart) / (fadeEnd - fadeStart)
                        targetTrans = minTrans + (1.0 - minTrans) * pct
                    end
                    highlight.OutlineTransparency = targetTrans
                end
            end
        end
    end
end)

