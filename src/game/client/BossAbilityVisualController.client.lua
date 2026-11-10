local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local PlayBossAbilityVisual = Events:WaitForChild("PlayBossAbilityVisual")

-- Camera Shake Helper Function
local function playCameraShake(intensity, duration)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    
    task.spawn(function()
        local elapsed = 0
        while elapsed < duration do
            local dt = task.wait()
            if ReplicatedStorage:GetAttribute("GameStarted") ~= true then break end
            if ReplicatedStorage:GetAttribute("IsPaused") then continue end
            elapsed = elapsed + dt
            
            local progress = 1 - (elapsed / duration)
            local currentIntensity = intensity * progress
            local rx = (math.random() - 0.5) * currentIntensity * 0.04
            local ry = (math.random() - 0.5) * currentIntensity * 0.04
            local rz = (math.random() - 0.5) * currentIntensity * 0.02
            
            camera.CFrame = camera.CFrame * CFrame.Angles(rx, ry, rz)
        end
    end)
end

-- Robust & Clean 3D Audio Helper (Bulletproof playback with engine fallback)
local function playCleanSound(soundId, volume, pitch, pos, maxDist)
    task.spawn(function()
        local soundAttachment = Instance.new("Attachment")
        soundAttachment.Name = "BossAbilitySound"
        soundAttachment.WorldPosition = pos
        soundAttachment.Parent = Workspace.Terrain
        
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = volume or 0.35
        sound.Pitch = pitch or 1.0
        sound.RollOffMaxDistance = maxDist or 80
        sound.RollOffMinDistance = 10
        sound.RollOffMode = Enum.RollOffMode.Linear
        sound.Parent = soundAttachment
        
        local success = pcall(function()
            sound:Play()
        end)
        
        if not success or not sound.IsPlaying then
            -- Roblox dahili motor sesine otomatik düşüş (Lisans/Erişim hatası imkansızdır)
            sound.SoundId = "rbxasset://sounds/button.wav"
            sound.Pitch = 2.2
            sound.Volume = 0.5
            pcall(function() sound:Play() end)
        end
        
        sound.Ended:Connect(function()
            soundAttachment:Destroy()
        end)
        
        Debris:AddItem(soundAttachment, 3.0)
    end)
end

-- Clean & Highly Readable Boss AoE Warning & Blast Controller (Pause-Aware)
PlayBossAbilityVisual.OnClientEvent:Connect(function(targetPos, duration, radius)
    radius = radius or 11.2
    duration = duration or 1.6
    
    -- Ground CFrame for flat cylinder indicators on terrain
    local groundCFrame = CFrame.new(Vector3.new(targetPos.X, targetPos.Y - 1.85, targetPos.Z)) * CFrame.Angles(0, 0, math.pi / 2)
    
    -- ====================================================
    -- PHASE 1: TELEGRAPH WARNING (CLEAR PROGRESS FILL)
    -- ====================================================
    
    -- 1. Outer Boundary Ring (Yellow / Orange Solid Rim)
    local outerRing = Instance.new("Part")
    outerRing.Name = "BossAoE_OuterRing"
    outerRing.Shape = Enum.PartType.Cylinder
    outerRing.Size = Vector3.new(0.12, radius * 2, radius * 2)
    outerRing.CFrame = groundCFrame
    outerRing.Color = Color3.fromRGB(255, 190, 30) -- Bright readable yellow/gold
    outerRing.Material = Enum.Material.Neon
    outerRing.Transparency = 0.35
    outerRing.Anchored = true
    outerRing.CanCollide = false
    outerRing.Parent = Workspace
    
    -- 2. Inner Progress Fill Disc (Grows from center 0% to 100% to show exact explosion timer)
    local fillDisc = Instance.new("Part")
    fillDisc.Name = "BossAoE_FillDisc"
    fillDisc.Shape = Enum.PartType.Cylinder
    fillDisc.Size = Vector3.new(0.15, 0.2, 0.2)
    fillDisc.CFrame = groundCFrame
    fillDisc.Color = Color3.fromRGB(255, 170, 20) -- Starts Yellow/Orange
    fillDisc.Material = Enum.Material.Neon
    fillDisc.Transparency = 0.4
    fillDisc.Anchored = true
    fillDisc.CanCollide = false
    fillDisc.Parent = Workspace
    
    -- 3. Dynamic Warning Light
    local chargeLight = Instance.new("PointLight")
    chargeLight.Color = Color3.fromRGB(255, 180, 30)
    chargeLight.Range = radius * 1.5
    chargeLight.Brightness = 2.0
    chargeLight.Parent = outerRing
    
    -- Smooth Progress Fill Animation & Color Shift (Completely Pause-Aware)
    local elapsed = 0
    while elapsed < duration do
        local dt = task.wait()
        
        -- Cleanup if game ended or parts destroyed
        if ReplicatedStorage:GetAttribute("GameStarted") ~= true or not fillDisc or not fillDisc.Parent then
            if outerRing and outerRing.Parent then outerRing:Destroy() end
            if fillDisc and fillDisc.Parent then fillDisc:Destroy() end
            return
        end
        
        if not ReplicatedStorage:GetAttribute("IsPaused") then
            elapsed = elapsed + dt
            local progress = math.clamp(elapsed / duration, 0, 1)
            
            -- Smooth size growth
            local currentDiscDiameter = math.max(0.2, radius * 2 * progress)
            fillDisc.Size = Vector3.new(0.15, currentDiscDiameter, currentDiscDiameter)
            
            -- Color interpolation: 0% Yellow -> 70% Orange -> 90% Flash Red
            if progress < 0.7 then
                local t = progress / 0.7
                local c = Color3.fromRGB(255, 190 - (t * 70), 30 - (t * 20))
                fillDisc.Color = c
                outerRing.Color = c
                chargeLight.Color = c
                fillDisc.Transparency = 0.4
            else
                local t = (progress - 0.7) / 0.3
                local c = Color3.fromRGB(255, 120 - (t * 100), 10)
                fillDisc.Color = c
                outerRing.Color = c
                chargeLight.Color = c
                
                -- Pulse opacity rapidly right before detonation (Danger Flash!)
                local pulse = (math.sin(elapsed * 25) + 1) / 2
                fillDisc.Transparency = 0.2 + (pulse * 0.3)
            end
        end
    end
    
    -- Clean up Telegraph Parts
    if outerRing and outerRing.Parent then outerRing:Destroy() end
    if fillDisc and fillDisc.Parent then fillDisc:Destroy() end
    
    if ReplicatedStorage:GetAttribute("GameStarted") ~= true then return end
    
    -- ====================================================
    -- PHASE 2: CLEAN DETONATION BLAST
    -- ====================================================
    
    -- A. Clean Ground Shockwave Disc (Expands flat on floor)
    local shockwave = Instance.new("Part")
    shockwave.Name = "BossExplosionShockwave"
    shockwave.Shape = Enum.PartType.Cylinder
    shockwave.Size = Vector3.new(0.3, radius * 0.5, radius * 0.5)
    shockwave.CFrame = groundCFrame
    shockwave.Color = Color3.fromRGB(255, 60, 30)
    shockwave.Material = Enum.Material.Neon
    shockwave.Transparency = 0.1
    shockwave.Anchored = true
    shockwave.CanCollide = false
    shockwave.Parent = Workspace
    
    -- B. Kullanıcının belirttiği özel pop ses efekti (ID: 106879573498735)
    playCleanSound("rbxassetid://106879573498735", 0.75, 1.0, targetPos, 90)
    
    -- C. Minimal Clean Particle Burst (Only 25 particles, crisp and clear)
    local centerAttach = Instance.new("Attachment")
    centerAttach.WorldPosition = targetPos
    centerAttach.Parent = Workspace.Terrain
    
    local blastParticles = Instance.new("ParticleEmitter")
    blastParticles.Texture = "rbxassetid://241537084"
    blastParticles.Color = ColorSequence.new(Color3.fromRGB(255, 180, 40), Color3.fromRGB(255, 40, 10))
    blastParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0.0)
    })
    blastParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1.0)
    })
    blastParticles.Lifetime = NumberRange.new(0.3, 0.6)
    blastParticles.Rate = 0
    blastParticles.Speed = NumberRange.new(15, 35)
    blastParticles.SpreadAngle = Vector2.new(360, 360)
    blastParticles.Parent = centerAttach
    blastParticles:Emit(25)
    
    -- D. Pause-aware Shockwave Dissolve
    task.spawn(function()
        local shockElapsed = 0
        local shockDuration = 0.35
        local startSize = radius * 0.5
        local targetSize = radius * 2.4
        
        while shockElapsed < shockDuration do
            local dt = task.wait()
            if ReplicatedStorage:GetAttribute("GameStarted") ~= true then break end
            if not ReplicatedStorage:GetAttribute("IsPaused") then
                shockElapsed = shockElapsed + dt
                local p = math.clamp(shockElapsed / shockDuration, 0, 1)
                local currentR = startSize + (targetSize - startSize) * (1 - (1 - p) * (1 - p))
                if shockwave and shockwave.Parent then
                    shockwave.Size = Vector3.new(0.3 - (p * 0.15), currentR, currentR)
                    shockwave.Transparency = 0.1 + (p * 0.9)
                end
            end
        end
        if shockwave and shockwave.Parent then
            shockwave:Destroy()
        end
    end)
    
    -- E. Subtle Camera Shake
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local dist = (hrp.Position - targetPos).Magnitude
        if dist <= 40 then
            local intensity = math.clamp(1 - (dist / 40), 0.2, 1.0)
            playCameraShake(intensity * 1.2, 0.25)
        end
    end
    
    -- Clean up instances after animation
    Debris:AddItem(centerAttach, 1.5)
end)
