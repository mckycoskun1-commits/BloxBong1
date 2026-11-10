local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))
local CollectGemEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("CollectGem")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local function isEngineer(playerObj)
    if not playerObj then return false end
    return playerObj:GetAttribute("SelectedClassId") == "Engineer" or playerObj:GetAttribute("HasTurret") == true
end

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
end)

-- Special popup when vacuum is picked up (premium screen banner + screen vignette pulse)
local function showVacuumPopup()
    local playerGui = Player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    -- Create ScreenGui
    local sgui = Instance.new("ScreenGui")
    sgui.Name = "VacuumAlertGui"
    sgui.IgnoreGuiInset = true
    sgui.ResetOnSpawn = true
    sgui.Parent = playerGui
    
    -- 1. Fullscreen Vignette Flash/Shockwave
    local vignette = Instance.new("Frame")
    vignette.Size = UDim2.new(1, 0, 1, 0)
    vignette.BackgroundColor3 = Color3.fromRGB(170, 85, 255) -- Electric purple
    vignette.BackgroundTransparency = 0.65
    vignette.BorderSizePixel = 0
    vignette.Parent = sgui
    
    -- Fade out shockwave quickly
    TweenService:Create(vignette, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1.0
    }):Play()
    
    -- 2. Banner Frame (Sleek dark glass panel)
    local banner = Instance.new("Frame")
    banner.Size = UDim2.new(0, 380, 0, 65)
    banner.Position = UDim2.new(0.5, 0, -0.15, 0) -- Start off-screen (above)
    banner.AnchorPoint = Vector2.new(0.5, 0.5)
    banner.BackgroundColor3 = Color3.fromRGB(15, 8, 25)
    banner.BackgroundTransparency = 0.2
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = banner
    
    -- Add glowing neon border
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2.5
    stroke.Color = Color3.fromRGB(170, 85, 255)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = banner
    
    local strokeGradient = Instance.new("UIGradient")
    strokeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 85, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 85, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 85, 255))
    })
    strokeGradient.Parent = stroke
    
    -- Flowing neon stroke effect
    task.spawn(function()
        local elapsed = 0
        while banner and banner.Parent do
            elapsed = elapsed + task.wait()
            strokeGradient.Offset = Vector2.new(math.sin(elapsed * 2.5) * 0.5, 0)
        end
    end)
    
    -- Title Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.6, 0)
    label.Position = UDim2.new(0, 0, 0.1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Arcade
    label.TextScaled = true
    label.Text = "🧲 MAGNET ACTIVATED"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = banner
    
    local textGradient = Instance.new("UIGradient")
    textGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 180, 255))
    })
    textGradient.Parent = label
    
    -- Subtitle Label
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, 0, 0.3, 0)
    subtitle.Position = UDim2.new(0, 0, 0.65, 0)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.SourceSansBold
    subtitle.TextScaled = true
    subtitle.Text = "PULLING ALL XP GEMS & COINS"
    subtitle.TextColor3 = Color3.fromRGB(170, 85, 255)
    subtitle.TextStrokeTransparency = 0.8
    subtitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    subtitle.Parent = banner
    
    banner.Parent = sgui
    
    -- Slide banner down with back/bounce effect
    TweenService:Create(banner, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.12, 0)
    }):Play()
    
    -- Slide up and destroy
    task.delay(2.2, function()
        if sgui and sgui.Parent then
            TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, -0.15, 0)
            }):Play()
            
            task.delay(0.5, function()
                if sgui then sgui:Destroy() end
            end)
        end
    end)
end


local lastCoinSoundTime = 0
local function playCoinPickupSound()
    local now = os.clock()
    if now - lastCoinSoundTime < 0.04 then return end
    lastCoinSoundTime = now
    SoundManager.PlaySound("CoinPickup")
end

local lastMagnetSoundTime = 0
local function playMagnetDropSound()
    local now = os.clock()
    if now - lastMagnetSoundTime < 0.1 then return end
    lastMagnetSoundTime = now
    SoundManager.PlaySound("MagnetDrop")
end

-- Sahaya düşen magnetleri (Vacuum) anında tespit edip ses çalan dinleyici
local function monitorGemsFolder(folder)
    for _, child in ipairs(folder:GetChildren()) do
        if (child.Name == "VacuumGem") or (child:GetAttribute("IsVacuum") == true) then
            child:SetAttribute("VacuumDropSoundPlayed", true)
        end
    end

    folder.ChildAdded:Connect(function(child)
        task.defer(function()
            if not child or not child.Parent then return end
            if not child:IsA("BasePart") then return end
            if (child.Name == "VacuumGem") or (child:GetAttribute("IsVacuum") == true) then
                if not child:GetAttribute("VacuumDropSoundPlayed") then
                    child:SetAttribute("VacuumDropSoundPlayed", true)
                    playMagnetDropSound()
                end
            end
        end)
    end)
end

task.spawn(function()
    local folder = workspace:FindFirstChild("Gems") or workspace:WaitForChild("Gems", 5)
    if folder then
        monitorGemsFolder(folder)
    end
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "Gems" and child:IsA("Folder") then
            monitorGemsFolder(child)
        end
    end)
end)

-- Spawns and accumulates pickup values (Megabonk Style) using robust Instance-hierarchy state
local function showPickupPopup(isCoin, value, isScrap, isSilver, isLuckScroll)
    local root = Character and Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local popupName = isLuckScroll and "LuckScrollPopup" or (isSilver and "SilverPopup" or (isScrap and "ScrapPopup" or (isCoin and "CoinPopup" or "XPPopup")))
    local existing = root:FindFirstChild(popupName)
    
    -- If there's an active popup, accumulate the value and destroy the old one to reset all tweens/timers cleanly
    if existing then
        local prevValue = existing:GetAttribute("AccumulatedValue") or 0
        value = prevValue + value
        existing:Destroy()
    end
    
    -- Create the BillboardGui
    local bgui = Instance.new("BillboardGui")
    bgui.Name = popupName
    bgui.Size = UDim2.new(3, 0, 0.7, 0)
    bgui.AlwaysOnTop = true
    bgui.LightInfluence = 0
    bgui.Adornee = root
    bgui.ResetOnSpawn = true
    
    -- Store the accumulated value as an attribute
    bgui:SetAttribute("AccumulatedValue", value)
    -- Megabonk layout style: Symmetrical Left & Right for XP & Coin, Centered Directly Above for Silver and Scrap
    local fixedOffset
    if isLuckScroll then
        fixedOffset = Vector3.new(0, 4.8, 0) -- En üstte belirgin Şans Parşömeni
    elseif isSilver then
        fixedOffset = Vector3.new(0, 3.2, 0) -- Direkt karakterin üstünde
    elseif isScrap then
        fixedOffset = Vector3.new(0, 4.0, 0)
    elseif isCoin then
        fixedOffset = Vector3.new(2.3, 2.2, 0) -- Sağ taraf
    else
        fixedOffset = Vector3.new(-2.3, 2.2, 0) -- Sol taraf (XP)
    end
    bgui.StudsOffset = fixedOffset
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Arcade -- Arcade retro font
    label.TextScaled = true
    label.TextStrokeTransparency = 0.1 -- Black outline
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    if isLuckScroll then
        label.Text = "+10% LUCK!"
        label.TextColor3 = Color3.fromRGB(80, 255, 160) -- Zümrüt yeşili
    elseif isSilver then
        label.Text = "+" .. tostring(value) .. " Silver"
        label.TextColor3 = Color3.fromRGB(195, 205, 215) -- Silver metallic gray
    elseif isScrap then
        label.Text = "+⚙️ " .. tostring(value) .. " Scrap"
        label.TextColor3 = Color3.fromRGB(255, 175, 45) -- Industrial bronze/orange
    elseif isCoin then
        label.Text = "+$" .. tostring(value)
        label.TextColor3 = Color3.fromRGB(255, 205, 30) -- Gold yellow
    else
        label.Text = "+" .. tostring(value) .. " XP"
        label.TextColor3 = Color3.fromRGB(50, 215, 255) -- Cyan/light blue XP
    end
    
    label.Parent = bgui
    bgui.Parent = root
    
    -- Fade out logic: Wait 1s, then fade over 1.5s (completely pause-aware)
    task.spawn(function()
        -- Wait 1 second (respecting pause)
        local waited = 0
        while waited < 1.0 do
            local dt = task.wait()
            if not ReplicatedStorage:GetAttribute("IsPaused") then
                waited = waited + dt
            end
        end
        
        -- Fade out over 1.5 seconds (respecting pause)
        local faded = 0
        local fadeDuration = 1.5
        while faded < fadeDuration do
            local dt = task.wait()
            if not ReplicatedStorage:GetAttribute("IsPaused") then
                faded = faded + dt
                local t = math.clamp(faded / fadeDuration, 0, 1)
                -- Easing style quad out: 1 - (1 - t)^2
                local easeT = 1 - (1 - t) * (1 - t)
                if label and label.Parent then
                    label.TextTransparency = easeT
                    label.TextStrokeTransparency = 0.1 + 0.9 * easeT
                else
                    break
                end
            end
        end
        
        if bgui and bgui.Parent then
            bgui:Destroy()
        end
    end)
end

local function showUpgradePopup(weaponKey, rarityName, bonusValue)
    local root = Character and Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local popupName = "UpgradePopup"
    local existing = root:FindFirstChild(popupName)
    if existing then
        existing:Destroy()
    end
    
    local bgui = Instance.new("BillboardGui")
    bgui.Name = popupName
    bgui.Size = UDim2.new(6, 0, 0.8, 0)
    bgui.AlwaysOnTop = true
    bgui.LightInfluence = 0
    bgui.Adornee = root
    bgui.ResetOnSpawn = true
    bgui.StudsOffset = Vector3.new(4.3, 3.2, 0)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Arcade
    label.TextScaled = true
    label.RichText = true
    label.TextStrokeTransparency = 0.1
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextColor3 = Color3.fromRGB(255, 220, 120)
    
    local rarityHexColors = {
        Common = "#ffffff",
        New = "#ffffff",
        Uncommon = "#55ff55",
        Rare = "#55d5ff",
        Epic = "#d500ff",
        Legendary = "#ffc800"
    }
    
    local hexColor = rarityHexColors[rarityName] or "#ffffff"
    local weaponName = weaponKey .. " Count"
    label.Text = weaponName .. " <font color='" .. hexColor .. "'>+" .. tostring(bonusValue) .. "</font>"
    
    label.Parent = bgui
    bgui.Parent = root
    
    -- Float upwards and fade out logic (completely pause-aware)
    task.spawn(function()
        local startOffset = Vector3.new(4.3, 3.2, 0)
        local targetOffset = Vector3.new(4.3, 4.5, 0)
        
        local elapsed = 0
        local totalDuration = 2.5
        
        while elapsed < totalDuration do
            local dt = task.wait()
            if not ReplicatedStorage:GetAttribute("IsPaused") then
                elapsed = elapsed + dt
                local t = math.clamp(elapsed / totalDuration, 0, 1)
                -- Easing style quad out: 1 - (1 - t)^2
                local easeT = 1 - (1 - t) * (1 - t)
                
                if bgui and bgui.Parent then
                    bgui.StudsOffset = startOffset:Lerp(targetOffset, easeT)
                else
                    break
                end
                
                -- Fade out logic starting after 1.0 second
                if elapsed >= 1.0 and label and label.Parent then
                    local fadeT = math.clamp((elapsed - 1.0) / 1.5, 0, 1)
                    local easeFadeT = 1 - (1 - fadeT) * (1 - fadeT)
                    label.TextTransparency = easeFadeT
                    label.TextStrokeTransparency = 0.1 + 0.9 * easeFadeT
                end
            end
        end
        
        if bgui and bgui.Parent then
            bgui:Destroy()
        end
    end)
end

local poppingGems = {} -- Map from gem -> data { startTime, startPos, landPos }

RunService.Heartbeat:Connect(function(dt)
    local gemsFolder = workspace:FindFirstChild("Gems")
    if not gemsFolder then return end
    
    local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
    local localIsEngineer = isEngineer(Player)
    
    -- Sahadaki tüm canlı oyuncuları tara
    local activePlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local pChar = p.Character
        if pChar and pChar:FindFirstChild("HumanoidRootPart") then
            local hum = pChar:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health > 0 then
                local pMagnetMultiplier = pChar:GetAttribute("MagnetMultiplier") or 1.0
                local pHasVacuum = pChar:GetAttribute("VacuumActive") == true
                local pIsEng = isEngineer(p)
                table.insert(activePlayers, {
                    Player = p,
                    Character = pChar,
                    Root = pChar.HumanoidRootPart,
                    MagnetMultiplier = pMagnetMultiplier,
                    HasVacuum = pHasVacuum,
                    IsLocal = (p == Player),
                    IsEngineer = pIsEng,
                })
            end
        end
    end
    
    if #activePlayers == 0 then return end
    
    -- Yerel oyuncu UI menü kontrolü
    local playerGui = Player:FindFirstChild("PlayerGui")
    local hasUpgradeUI = playerGui and playerGui:FindFirstChild("UpgradeUI") ~= nil
    local hasChestAwardUI = playerGui and playerGui:FindFirstChild("ChestAwardUI") ~= nil
    local localShouldFly = not (hasUpgradeUI or hasChestAwardUI or isPaused)

    for _, gem in ipairs(gemsFolder:GetChildren()) do
        if not gem:IsA("BasePart") then continue end

        local isVacuumGem = (gem.Name == "VacuumGem") or (gem:GetAttribute("IsVacuum") == true)
        if isVacuumGem and not gem:GetAttribute("VacuumDropSoundPlayed") then
            gem:SetAttribute("VacuumDropSoundPlayed", true)
            playMagnetDropSound()
        end
        
        local isScrapGem = (gem.Name == "ScrapGem") or (gem:GetAttribute("IsScrap") == true)
        
        -- Hurda (Scrap) Görünürlük Kontrolü:
        -- Yerel oyuncu Engineer DEĞİLSE hurdayı tamamen gizle ve ışığını kapat!
        if isScrapGem then
            if not localIsEngineer then
                if gem.Transparency ~= 1 then
                    gem.Transparency = 1
                end
                local pl = gem:FindFirstChildOfClass("PointLight")
                if pl and pl.Enabled then
                    pl.Enabled = false
                end
            elseif not gem:GetAttribute("Collected") and not gem:GetAttribute("IsCollecting") then
                if gem.Transparency ~= 0 then
                    gem.Transparency = 0
                end
                local pl = gem:FindFirstChildOfClass("PointLight")
                if pl and not pl.Enabled then
                    pl.Enabled = true
                end
            end
        end
        
        -- Fırlama (Pop-out) animasyon kontrolü
        local startPosAttr = gem:GetAttribute("StartPos")
        local landPosAttr = gem:GetAttribute("LandPos")
        
        if startPosAttr and landPosAttr then
            local data = poppingGems[gem]
            if not data then
                data = {
                    startTime = os.clock(),
                    startPos = startPosAttr,
                    landPos = landPosAttr
                }
                poppingGems[gem] = data
            end
            
            local elapsed = os.clock() - data.startTime
            local duration = 0.225 -- Fırlama süresi
            
            if elapsed < duration then
                local t = elapsed / duration
                local horizontalPos = data.startPos:Lerp(data.landPos, t)
                local height = math.sin(t * math.pi) * 3.5
                gem.Position = horizontalPos + Vector3.new(0, height, 0)
                gem.CFrame = gem.CFrame * CFrame.Angles(0, math.rad(150 * dt), 0)
                continue
            else
                poppingGems[gem] = nil
                gem:SetAttribute("StartPos", nil)
                gem:SetAttribute("LandPos", nil)
                gem.Position = data.landPos
            end
        end
        
        -- Dönme Animasyonu
        gem.CFrame = gem.CFrame * CFrame.Angles(0, math.rad(150 * dt), 0)
        
        local isVacuumGem = gem:GetAttribute("IsVacuum") == true
        
        -- Hedef Oyuncuyu Bul (Mıknatısı aktif olan veya çekim menzilindeki oyuncu)
        local targetData = nil
        local targetUserId = gem:GetAttribute("TargetUserId")
        if targetUserId then
            for _, pData in ipairs(activePlayers) do
                if pData.Player.UserId == targetUserId then
                    if not isScrapGem or pData.IsEngineer then
                        targetData = pData
                    end
                    break
                end
            end
        end
        
        if not targetData then
            local minDist = 999999
            for _, pData in ipairs(activePlayers) do
                -- Hurda nesneleri SADECE Engineer olan oyuncular çekebilir!
                if isScrapGem and not pData.IsEngineer then
                    continue
                end
                
                local itemPickupRadius = (pData.HasVacuum and not isVacuumGem) and 99999 or (Config.Game.XPPickupRadius * pData.MagnetMultiplier)
                local d = (gem.Position - pData.Root.Position).Magnitude
                
                if d < itemPickupRadius then
                    if pData.HasVacuum and not isVacuumGem then
                        targetData = pData
                        minDist = d
                        break
                    elseif d < minDist then
                        minDist = d
                        targetData = pData
                    end
                end
            end
            if targetData then
                gem:SetAttribute("TargetUserId", targetData.Player.UserId)
            end
        end
        
        local beingPulled = gem:GetAttribute("BeingPulled") == true
        if not beingPulled and targetData then
            beingPulled = true
            gem:SetAttribute("BeingPulled", true)
        end
        
        if beingPulled and targetData and not isPaused then
            local canFly = true
            if targetData.IsLocal and not localShouldFly then
                canFly = false
            end
            
            if canFly then
                local rootPos = targetData.Root.Position
                local direction = (rootPos - gem.Position).Unit
                local speed = Config.Game.GemMagnetSpeed
                
                local dist = (gem.Position - rootPos).Magnitude
                if dist < 10 then
                    speed = speed * 1.5
                end
                
                gem.Position = gem.Position + (direction * speed * dt)
                
                -- Toplama Mesafesi (Çok yakınsa topla)
                if dist < 3 then
                    if targetData.IsLocal then
                        if not gem:GetAttribute("Collected") then
                            if isScrapGem and not localIsEngineer then
                                return
                            end
                            gem:SetAttribute("Collected", true)
                            
                            if isVacuumGem then
                                showVacuumPopup()
                            else
                                local isCoin = gem:GetAttribute("IsCoin") == true
                                local isScrap = isScrapGem
                                local isSilver = (gem:GetAttribute("IsSilver") == true) or (gem.Name == "SilverGem")
                                local isLuckScroll = (gem:GetAttribute("IsLuckScroll") == true) or (gem.Name == "LuckScrollGem")
                                local value = gem:FindFirstChild("Value") and gem.Value.Value or 1
                                showPickupPopup(isCoin, value, isScrap, isSilver, isLuckScroll)

                                if isCoin then
                                    playCoinPickupSound()
                                end
                            end
                            
                            CollectGemEvent:FireServer(gem)
                            gem.Transparency = 1
                            gem:SetAttribute("IsCollecting", true)
                        end
                    else
                        -- Diğer oyuncu topluyorsa küre onun karakterinin içine girip kaybolur
                        gem.Transparency = 1
                    end
                end
            end
        end
    end
end)

local ShowUpgradeNotificationEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ShowUpgradeNotification")
ShowUpgradeNotificationEvent.OnClientEvent:Connect(showUpgradePopup)
