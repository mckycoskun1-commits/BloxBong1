local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundConfig"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))

local Player = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local PlayProjectileVisual = Events:WaitForChild("PlayProjectileVisual")

-- Hedef Düşmanın Göğüs/Gövde Merkez Pozisyonunu Hesaplayan Yardımcı (Bacaklar yerine gövdeye nişan alma)
local function getTargetCenterPos(target)
    if not target then return nil end
    if typeof(target) == "Vector3" then return target end
    if not target.Parent then return nil end
    if target:IsA("BasePart") then
        return target.Position
    elseif target:IsA("Model") then
        local torso = target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart")
        if torso then
            return torso.Position
        end
        return target:GetPivot().Position
    end
    return target:GetPivot().Position
end

local function getDefaultDirection(startPos)
    local char = Player and Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local look = hrp.CFrame.LookVector
        local dir = Vector3.new(look.X, 0, look.Z)
        if dir.Magnitude > 0.001 then
            return dir.Unit
        end
    end
    return Vector3.new(1, 0, 0)
end

local function getProjectileExcludeList(projectilePart)
    local excludeList = {projectilePart}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            table.insert(excludeList, p.Character)
        end
    end
    local folders = {"Enemies", "Gems", "Pots", "Chests"}
    for _, name in ipairs(folders) do
        local f = workspace:FindFirstChild(name)
        if f then
            table.insert(excludeList, f)
        end
    end
    return excludeList
end

-- ============================================================
-- DURAKLATMA (PAUSE) VE EFEKT DONDURMA YÖNETİMİ
-- ============================================================
local activeEmitters = {}
local activeTweens = {}

-- ParticleEmitter'ı duraklatma sistemine kaydet
local function registerEmitter(emitter)
    if not emitter or not emitter:IsA("ParticleEmitter") then return end
    activeEmitters[emitter] = true
    
    local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
    if isPaused then
        if not emitter:GetAttribute("OriginalRate") then
            emitter:SetAttribute("OriginalRate", emitter.Rate)
        end
        emitter.TimeScale = 0
        emitter.Rate = 0
    else
        emitter.TimeScale = 1
        local orig = emitter:GetAttribute("OriginalRate")
        if orig ~= nil then
            emitter.Rate = orig
            emitter:SetAttribute("OriginalRate", nil)
        end
    end
    
    emitter.Destroying:Connect(function()
        activeEmitters[emitter] = nil
    end)
end

-- Bir instance altındaki tüm ParticleEmitter'ları otomatik tara ve kaydet
local function registerEmittersInInstance(inst)
    if not inst then return end
    for _, desc in ipairs(inst:GetDescendants()) do
        if desc:IsA("ParticleEmitter") then
            registerEmitter(desc)
        end
    end
    if inst:IsA("ParticleEmitter") then
        registerEmitter(inst)
    end
    inst.DescendantAdded:Connect(function(desc)
        if desc:IsA("ParticleEmitter") then
            registerEmitter(desc)
        end
    end)
end

-- Tween'leri duraklatma sistemine kaydet
local function registerTween(tween)
    if not tween then return end
    activeTweens[tween] = true
    if ReplicatedStorage:GetAttribute("IsPaused") == true then
        pcall(function() tween:Pause() end)
    end
    tween.Completed:Connect(function()
        activeTweens[tween] = nil
    end)
end

-- Debris yerine duraklatma duyarlı silme (Oyun duraklatıldığında süre saymaz, nesneler asla kaybolmaz!)
local function cleanupWithPause(instance, duration)
    if not instance then return end
    task.spawn(function()
        local remaining = duration
        while remaining > 0 do
            local dt = task.wait()
            if not ReplicatedStorage:GetAttribute("IsPaused") then
                remaining = remaining - dt
            end
        end
        if instance and instance.Parent then
            instance:Destroy()
        end
    end)
end

-- IsPaused değiştiğinde tüm aktif efektleri dondur veya devam ettir
ReplicatedStorage:GetAttributeChangedSignal("IsPaused"):Connect(function()
    local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
    
    -- Parçacık efektlerini dondur / devam ettir
    for emitter in pairs(activeEmitters) do
        if emitter and emitter.Parent then
            if isPaused then
                if not emitter:GetAttribute("OriginalRate") then
                    emitter:SetAttribute("OriginalRate", emitter.Rate)
                end
                emitter.TimeScale = 0
                emitter.Rate = 0
            else
                emitter.TimeScale = 1
                local orig = emitter:GetAttribute("OriginalRate")
                if orig ~= nil then
                    emitter.Rate = orig
                    emitter:SetAttribute("OriginalRate", nil)
                end
            end
        else
            activeEmitters[emitter] = nil
        end
    end
    
    -- Animasyon / Tween'leri dondur / devam ettir
    for tween in pairs(activeTweens) do
        if isPaused then
            pcall(function() tween:Pause() end)
        else
            pcall(function() tween:Play() end)
        end
    end
end)

-- ParticleEmitter boyut, hız ve ömrünü (Lifetime) ölçekleyen yardımcı
local function scaleParticleEmitter(emitter, factor, lifetimeMult)
    if not emitter or not emitter:IsA("ParticleEmitter") then return end
    lifetimeMult = lifetimeMult or 0.55 -- Partiküllerin kalma süresini kısalt (daha temiz ve net patlama)
    
    local originalSize = emitter.Size
    local newKeypoints = {}
    for _, kp in ipairs(originalSize.Keypoints) do
        table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, kp.Value * factor, kp.Envelope * factor))
    end
    emitter.Size = NumberSequence.new(newKeypoints)
    
    local originalSpeed = emitter.Speed
    emitter.Speed = NumberRange.new(originalSpeed.Min * factor, originalSpeed.Max * factor)
    
    local originalLifetime = emitter.Lifetime
    emitter.Lifetime = NumberRange.new(
        math.max(0.12, originalLifetime.Min * lifetimeMult),
        math.max(0.22, originalLifetime.Max * lifetimeMult)
    )
end

-- Çarpışma efekti yardımcı fonksiyonu (Yalnızca kullanıcının ReplicatedStorage.Assets.VFX içindeki FireExplosionVFX'i kullanılır)
local function playExplosionVisual(pos, radius)
    -- Fireball Hit / Yüzeye ve Hedefe Çarpma Sesi (3D pozisyonda çalar)
    SoundManager.PlaySound("FireballHit", pos)

    radius = (typeof(radius) == "number" and radius > 0) and radius or 3
    local scaleFactor = math.max(0.4, (radius / 3.0) * 0.75) -- Patlama efekti boyutu da alev topu yarıçapıyla orantılı büyür

    -- Anlık hafif ışık parlaması
    local lightPart = Instance.new("Part")
    lightPart.Size = Vector3.new(0.1, 0.1, 0.1)
    lightPart.Position = pos
    lightPart.Transparency = 1
    lightPart.Anchored = true
    lightPart.CanCollide = false
    lightPart.CanQuery = false
    lightPart.CanTouch = false
    lightPart.Parent = workspace
    cleanupWithPause(lightPart, 0.4)

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 140, 30)
    light.Range = math.clamp(radius * 1.5, 4, 25)
    light.Brightness = 2.5
    light.Parent = lightPart
    local lightTween = TweenService:Create(light, TweenInfo.new(0.22), {
        Brightness = 0,
        Range = 0
    })
    registerTween(lightTween)
    lightTween:Play()

    -- ReplicatedStorage.Assets.VFX içindeki özel FireExplosionVFX efektlerini kullan
    local vfxFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("VFX")
    if vfxFolder then
        local attachParent = nil
        
        local function applyVFX(emitter)
            scaleParticleEmitter(emitter, scaleFactor, 0.55)
            registerEmitter(emitter)
            emitter.Enabled = false
            local emitCount = math.clamp(math.floor(14 * scaleFactor), 8, 30)
            emitter:Emit(emitCount)
        end

        for _, originalVFX in ipairs(vfxFolder:GetChildren()) do
            if string.find(originalVFX.Name, "FireExplosionVFX") then
                local vfx = originalVFX:Clone()
                
                if vfx:IsA("Model") then
                    vfx:ScaleTo(scaleFactor)
                    vfx:PivotTo(CFrame.new(pos))
                    vfx.Parent = workspace
                    for _, desc in ipairs(vfx:GetDescendants()) do
                        if desc:IsA("ParticleEmitter") then
                            applyVFX(desc)
                        end
                    end
                    cleanupWithPause(vfx, 1.2)
                elseif vfx:IsA("BasePart") then
                    vfx.Size *= scaleFactor
                    vfx.Position = pos
                    vfx.Anchored = true
                    vfx.CanCollide = false
                    vfx.Parent = workspace
                    for _, desc in ipairs(vfx:GetDescendants()) do
                        if desc:IsA("ParticleEmitter") then
                            applyVFX(desc)
                        end
                    end
                    cleanupWithPause(vfx, 1.2)
                elseif vfx:IsA("Attachment") then
                    if not attachParent then
                        attachParent = Instance.new("Part")
                        attachParent.Size = Vector3.new(0.1, 0.1, 0.1)
                        attachParent.Position = pos
                        attachParent.Transparency = 1
                        attachParent.Anchored = true
                        attachParent.CanCollide = false
                        attachParent.CanQuery = false
                        attachParent.CanTouch = false
                        attachParent.Parent = workspace
                        cleanupWithPause(attachParent, 1.2)
                    end
                    vfx.Position = Vector3.zero
                    vfx.Parent = attachParent
                    for _, desc in ipairs(vfx:GetDescendants()) do
                        if desc:IsA("ParticleEmitter") then
                            applyVFX(desc)
                        end
                    end
                    if vfx:IsA("ParticleEmitter") then
                        applyVFX(vfx)
                    end
                elseif vfx:IsA("ParticleEmitter") then
                    if not attachParent then
                        attachParent = Instance.new("Part")
                        attachParent.Size = Vector3.new(0.1, 0.1, 0.1)
                        attachParent.Position = pos
                        attachParent.Transparency = 1
                        attachParent.Anchored = true
                        attachParent.CanCollide = false
                        attachParent.CanQuery = false
                        attachParent.CanTouch = false
                        attachParent.Parent = workspace
                        cleanupWithPause(attachParent, 1.2)
                    end
                    local att = Instance.new("Attachment", attachParent)
                    vfx.Parent = att
                    applyVFX(vfx)
                else
                    if not attachParent then
                        attachParent = Instance.new("Part")
                        attachParent.Size = Vector3.new(0.1, 0.1, 0.1)
                        attachParent.Position = pos
                        attachParent.Transparency = 1
                        attachParent.Anchored = true
                        attachParent.CanCollide = false
                        attachParent.CanQuery = false
                        attachParent.CanTouch = false
                        attachParent.Parent = workspace
                        cleanupWithPause(attachParent, 1.2)
                    end
                    vfx.Parent = attachParent
                    for _, desc in ipairs(vfx:GetDescendants()) do
                        if desc:IsA("ParticleEmitter") then
                            applyVFX(desc)
                        end
                    end
                end
            end
        end
    end
end

-- Mermi (Bullet) İstemci Efekti
local function drawBullet(startPos, target, speed, fallbackTargetPos, projectileCount)
    -- Mermi Ateşlenme Sesi (Fırlatma noktasında 3D pozisyonda çalar)
    -- Mermi sayısı arttıkça sesi hafifçe kısarak çoklu salvo ateşlerinde kulağı yormaz
    local count = tonumber(projectileCount) or 1
    local volMultiplier = math.clamp(1 / (1 + (count - 1) * 0.15), 0.50, 1.0)
    local baseVolume = (SoundConfig and SoundConfig.BulletShoot and SoundConfig.BulletShoot.Volume) or 0.20
    SoundManager.PlaySound("BulletShoot", startPos, { Volume = baseVolume * volMultiplier })

    local bullet = Instance.new("Part")
    bullet.Name = "ClientBullet"
    bullet.Shape = Enum.PartType.Ball
    bullet.Size = Vector3.new(0.6, 0.6, 0.6)
    bullet.Color = Color3.new(1, 1, 0.5)
    bullet.Material = Enum.Material.Neon
    bullet.Anchored = true
    bullet.CanCollide = false
    bullet.Position = startPos
    bullet.Parent = workspace
    
    local initialTargetPos = getTargetCenterPos(target) or fallbackTargetPos
    local lastDir
    local lastTargetPos
    if initialTargetPos then
        local diff = (initialTargetPos - startPos)
        lastDir = diff.Magnitude > 0.001 and diff.Unit or getDefaultDirection(startPos)
        lastTargetPos = initialTargetPos
    else
        lastDir = getDefaultDirection(startPos)
        lastTargetPos = startPos + lastDir * 30
    end

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if ReplicatedStorage:GetAttribute("IsPaused") then return end
        if not bullet.Parent then
            connection:Disconnect()
            return
        end
        
        local currentPos = bullet.Position
        local targetPos = getTargetCenterPos(target) or lastTargetPos
        local diff = (targetPos - currentPos)
        local direction = lastDir
        if diff.Magnitude > 0.001 then
            direction = diff.Unit
            lastDir = direction
            lastTargetPos = targetPos
        end
        local distance = diff.Magnitude
        
        local moveDist = speed * dt
        if distance < moveDist + 1 then
            bullet:Destroy()
            connection:Disconnect()
        else
            bullet.Position = currentPos + (direction * moveDist)
        end
    end)
    cleanupWithPause(bullet, 5)
end

-- Kartopu (Snowball) İstemci Efekti
local function drawSnowball(startPos, target, speed, slowPct, duration)
    local sb = Instance.new("Part")
    sb.Name = "ClientSnowball"
    sb.Shape = Enum.PartType.Ball
    sb.Size = Vector3.new(1.2, 1.2, 1.2)
    sb.Color = Color3.fromRGB(200, 240, 255)
    sb.Material = Enum.Material.Ice
    sb.Anchored = true
    sb.CanCollide = false
    sb.Position = startPos
    sb.Parent = workspace
    
    local lastDir = getDefaultDirection(startPos)
    local lastTargetPos = startPos + lastDir * 30
    local initialTargetPos = getTargetCenterPos(target)
    if initialTargetPos then
        lastDir = (initialTargetPos - startPos).Unit
        lastTargetPos = initialTargetPos
    end

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if ReplicatedStorage:GetAttribute("IsPaused") then return end
        if not sb.Parent then
            connection:Disconnect()
            return
        end
        
        local currentPos = sb.Position
        local targetPos = getTargetCenterPos(target)
        if targetPos then
            local diff = (targetPos - currentPos)
            if diff.Magnitude > 0.001 then
                lastDir = diff.Unit
                lastTargetPos = targetPos
            end
        else
            targetPos = lastTargetPos
        end
        
        local diff = (targetPos - currentPos)
        local direction = lastDir
        if diff.Magnitude > 0.001 then
            direction = diff.Unit
        end
        local distance = diff.Magnitude
        
        local moveDist = speed * dt
        
        -- Raycast to detect collision with surfaces (ground, obstacles) after moving away from spawn point
        local distFromStart = (currentPos - startPos).Magnitude
        if distFromStart > 5 then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            raycastParams.FilterDescendantsInstances = getProjectileExcludeList(sb)
            
            local raycastResult = workspace:Raycast(currentPos, direction * (moveDist + 0.5), raycastParams)
            if raycastResult then
                sb:Destroy()
                connection:Disconnect()
                
                -- Spawn collision snowflake visual at the hit position
                local p = Instance.new("Part")
                p.Size = Vector3.new(1, 1, 1)
                p.Transparency = 1
                p.CFrame = CFrame.new(raycastResult.Position)
                p.Anchored = true
                p.CanCollide = false
                p.Parent = workspace
                
                local attachment = Instance.new("Attachment", p)
                local particles = Instance.new("ParticleEmitter", attachment)
                particles.Texture = "rbxassetid://241537084"
                particles.Size = NumberSequence.new(0.6)
                particles.Transparency = NumberSequence.new(0, 1)
                particles.Lifetime = NumberRange.new(0.5, 0.8)
                particles.Rate = 50
                particles.Speed = NumberRange.new(5, 10)
                particles.SpreadAngle = Vector2.new(360, 360)
                registerEmittersInInstance(p)
                particles:Emit(20)
                cleanupWithPause(p, 1)
                return
            end
        end
        
        if distance < moveDist + 1 then
            sb:Destroy()
            connection:Disconnect()
            
            -- Çarpışma kar tanesi efekti
            local p = Instance.new("Part")
            p.Size = Vector3.new(1, 1, 1)
            p.Transparency = 1
            p.CFrame = CFrame.new(targetPos)
            p.Anchored = true
            p.CanCollide = false
            p.Parent = workspace
            
            local attachment = Instance.new("Attachment", p)
            local particles = Instance.new("ParticleEmitter", attachment)
            particles.Texture = "rbxassetid://241537084"
            particles.Size = NumberSequence.new(0.6)
            particles.Transparency = NumberSequence.new(0, 1)
            particles.Lifetime = NumberRange.new(0.5, 0.8)
            particles.Rate = 50
            particles.Speed = NumberRange.new(5, 10)
            particles.SpreadAngle = Vector2.new(360, 360)
            registerEmittersInInstance(p)
            particles:Emit(20)
            cleanupWithPause(p, 1)
            
            -- Mavi buzlanma efekti (sadece canavar hala hayattaysa)
            if target and target.Parent then
                local highlight = target:FindFirstChild("SnowballHighlight")
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "SnowballHighlight"
                    highlight.FillColor = Color3.fromRGB(100, 200, 255)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = Color3.new(1, 1, 1)
                    highlight.OutlineTransparency = 0
                    highlight.Parent = target
                    cleanupWithPause(highlight, duration or 1.5)
                end
            end
        else
            sb.Position = currentPos + (direction * moveDist)
        end
    end)
    cleanupWithPause(sb, 5)
end

-- Alev Topu (Fireball) İstemci Efekti
local function drawFireball(startPos, target, speed, radius)
    -- Fireball Cast Sesi (Ateşlenme anında oyuncunun/fırlatma noktasının 3D konumunda çalar)
    SoundManager.PlaySound("FireballCast", startPos)

    radius = (typeof(radius) == "number" and radius > 0) and radius or 3
    -- Taban yarıçap 3.0'a oranlanır; Size geliştirmesi model büyüklüğünü ekranı kaplamayacak şekilde çok az (dengeli) artırır
    local radiusRatio = math.max(0.5, radius / 3.0)
    local sizeRatio = math.clamp(1.0 + (radiusRatio - 1.0) * 0.25, 0.75, 1.40)

    local fb = Instance.new("Part")
    fb.Name = "ClientFireball"
    fb.Shape = Enum.PartType.Ball
    fb.Size = Vector3.new(1.2, 1.2, 1.2) * sizeRatio
    fb.Color = Color3.new(1, 0.3, 0)
    fb.Material = Enum.Material.Neon
    fb.Anchored = true
    fb.CanCollide = false
    fb.CanQuery = false
    fb.CanTouch = false
    fb.Position = startPos
    fb.Parent = workspace
    
    -- Alev topu dinamik aydınlatması (Aura)
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 120, 20)
    light.Range = 6 * sizeRatio
    light.Brightness = 2.0
    light.Parent = fb

    local vfxFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("VFX")
    local fireballVFX = vfxFolder and vfxFolder:FindFirstChild("FireballModel")
    local attachedModel = nil
    if fireballVFX then
        local vfx = fireballVFX:Clone()
        if vfx:IsA("Model") then
            vfx:ScaleTo(sizeRatio)
            vfx:PivotTo(CFrame.new(startPos))
            for _, item in ipairs(vfx:GetDescendants()) do
                if item:IsA("BasePart") then
                    item.CanCollide = false
                    item.CanQuery = false
                    item.CanTouch = false
                    item.Anchored = false
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = fb
                    weld.Part1 = item
                    weld.Parent = fb
                elseif item:IsA("ParticleEmitter") then
                    scaleParticleEmitter(item, sizeRatio, 0.7)
                end
            end
            vfx.Parent = fb
            attachedModel = vfx
        elseif vfx:IsA("ParticleEmitter") or vfx:IsA("Attachment") then
            if vfx:IsA("ParticleEmitter") then
                scaleParticleEmitter(vfx, sizeRatio, 0.7)
            end
            vfx.Parent = fb
        else
            for _, item in ipairs(vfx:GetChildren()) do
                if item:IsA("ParticleEmitter") then
                    scaleParticleEmitter(item, sizeRatio, 0.7)
                elseif item:IsA("BasePart") then
                    item.Size = item.Size * sizeRatio
                    item.CanCollide = false
                    item.CanQuery = false
                    item.CanTouch = false
                    item.Anchored = false
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = fb
                    weld.Part1 = item
                    weld.Parent = fb
                end
                item.Parent = fb
            end
        end
    else
        -- Varsayılan parçacık alev kuyruğu
        local trail = Instance.new("ParticleEmitter")
        trail.Texture = "rbxassetid://241537084"
        trail.Color = ColorSequence.new(Color3.fromRGB(255, 180, 50), Color3.fromRGB(220, 40, 0))
        trail.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.4 * sizeRatio),
            NumberSequenceKeypoint.new(1, 0)
        })
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1)
        })
        trail.Lifetime = NumberRange.new(0.18, 0.35)
        trail.Rate = math.clamp(math.floor(35 * sizeRatio), 25, 70)
        trail.Speed = NumberRange.new(2 * sizeRatio, 5 * sizeRatio)
        trail.SpreadAngle = Vector2.new(180, 180)
        trail.Parent = fb
    end
    
    -- Alev topundaki tüm parçacıkları duraklatma / dondurma yöneticisine kaydet
    registerEmittersInInstance(fb)
    
    local initialTargetPos = getTargetCenterPos(target) or (startPos + getDefaultDirection(startPos) * 40)
    local targetDir = (initialTargetPos - startPos).Magnitude > 0.001 and (initialTargetPos - startPos).Unit or getDefaultDirection(startPos)
    local totalExpectedDist = math.max(15, (initialTargetPos - startPos).Magnitude)
    local traveledDist = 0
    local lastDir = targetDir
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    
    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if ReplicatedStorage:GetAttribute("IsPaused") then return end
        if not fb.Parent then
            connection:Disconnect()
            return
        end
        
        local currentPos = fb.Position
        local moveDist = speed * dt
        traveledDist = traveledDist + moveDist
        
        local isTargetAlive = target and target.Parent and target:FindFirstChild("Health") and (target.Health.Value > 0)
        
        if isTargetAlive then
            local targetPos = getTargetCenterPos(target)
            if targetPos then
                local diff = (targetPos - currentPos)
                if diff.Magnitude > 0.001 then
                    lastDir = diff.Unit
                end
                
                -- Hedefe ulaşıldı mı? (İsabet toleransı ile pürüzsüz temas)
                if diff.Magnitude <= moveDist + 1.5 then
                    fb:Destroy()
                    connection:Disconnect()
                    playExplosionVisual(targetPos, radius)
                    return
                end
            end
        else
            -- Hedeflenen canavar yok edilmiş veya ölmüş:
            -- Alev topu yoluna düz bir hatta devam eder (aniden havada patlamaz)
            -- Yolundaki başka bir canavarın hitbox'ına çarparsa patlar
            if enemiesFolder then
                for _, enemyHitbox in ipairs(enemiesFolder:GetChildren()) do
                    if enemyHitbox:IsA("BasePart") and enemyHitbox:FindFirstChild("Health") and enemyHitbox.Health.Value > 0 then
                        local enemyCenter = enemyHitbox.Position
                        local halfExtent = math.max(enemyHitbox.Size.X, enemyHitbox.Size.Z) * 0.5 + 1.2
                        local dX = enemyCenter.X - currentPos.X
                        local dZ = enemyCenter.Z - currentPos.Z
                        local horizDist = math.sqrt(dX * dX + dZ * dZ)
                        local vertDist = math.abs(enemyCenter.Y - currentPos.Y)
                        if horizDist <= halfExtent and vertDist <= (enemyHitbox.Size.Y * 0.5 + 2.0) then
                            fb:Destroy()
                            connection:Disconnect()
                            playExplosionVisual(currentPos, radius)
                            return
                        end
                    end
                end
            end
            
            -- Hedef ölmüşse ve beklenen mesafeye ulaşılmışsa patla
            if traveledDist >= totalExpectedDist then
                fb:Destroy()
                connection:Disconnect()
                playExplosionVisual(currentPos, radius)
                return
            end
        end
        
        -- İleri hareket et
        fb.Position = currentPos + (lastDir * moveDist)
        fb.CFrame = CFrame.lookAt(fb.Position, fb.Position + lastDir)
        if attachedModel then
            attachedModel:PivotTo(fb.CFrame)
        end
    end)
    cleanupWithPause(fb, 5)
end

local function drawSpikedArmorHit(target)
    if not target or not target.Parent then return end
    local highlight = target:FindFirstChild("SpikedArmorHighlight")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "SpikedArmorHighlight"
        highlight.FillColor = Color3.fromRGB(220, 230, 255)
        highlight.FillTransparency = 0.4
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Parent = target
        cleanupWithPause(highlight, 0.45)
    end
end

PlayProjectileVisual.OnClientEvent:Connect(function(projectileType, startPosOrPlayer, target, speed, param1, param2)
    local startPos = startPosOrPlayer
    if typeof(startPosOrPlayer) == "Instance" and startPosOrPlayer:IsA("Player") then
        local char = startPosOrPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            startPos = hrp.Position + Vector3.new(0, 0.5, 0)
        else
            startPos = Vector3.zero
        end
    elseif typeof(startPosOrPlayer) == "Instance" and startPosOrPlayer:IsA("Model") then
        startPos = getTargetCenterPos(startPosOrPlayer) or startPosOrPlayer:GetPivot().Position
    end
    
    if projectileType == "Bullet" then
        drawBullet(startPos, target, speed, param1, param2)
    elseif projectileType == "Snowball" then
        drawSnowball(startPos, target, speed, param1, param2)
    elseif projectileType == "Fireball" then
        drawFireball(startPos, target, speed, param1)
    elseif projectileType == "SpikedArmor" then
        local targetEnemy = (typeof(startPosOrPlayer) == "Instance") and startPosOrPlayer or target
        drawSpikedArmorHit(targetEnemy)
    end
end)

