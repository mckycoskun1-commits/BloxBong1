local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- 0.45 Saniyelik Zıplama Bekleme Süresi (Karakter yere bastığı an pürüzsüzce tekrar zıplayabilir)
local JUMP_COOLDOWN = 0.45
local jumpCooldownUntil = 0
local pauseStartTime = nil
local jumpStateConn = nil
local jumpPropConn = nil

local currentVelocityVector = Vector3.new(0, 0, 0)
local currentFacingDirection = Vector3.new(0, 0, -1)
local skidEmitter = nil
local lastSkidTick = 0

-- Kontrol Modülü Entegrasyonu (Gecikmesiz, temiz kullanıcı girdisi için)
local cachedControls = nil
local function getControls()
    if not cachedControls then
        pcall(function()
            local playerScripts = Player:FindFirstChild("PlayerScripts") or Player:WaitForChild("PlayerScripts", 3)
            if playerScripts then
                local playerModule = require(playerScripts:WaitForChild("PlayerModule", 3))
                cachedControls = playerModule:GetControls()
            end
        end)
    end
    return cachedControls
end

local function getTargetInput()
    local ctrl = getControls()
    if ctrl and ctrl.GetMoveVector then
        local mv = ctrl:GetMoveVector()
        if mv and mv.Magnitude > 0.05 then
            local cam = workspace.CurrentCamera
            if cam then
                local camCFrame = cam.CFrame
                local right = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z)
                local forward = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z)
                if right.Magnitude > 0.001 and forward.Magnitude > 0.001 then
                    local worldVec = (right.Unit * mv.X + forward.Unit * -mv.Z)
                    if worldVec.Magnitude > 1 then
                        worldVec = worldVec.Unit
                    end
                    return worldVec
                end
            end
        else
            return Vector3.new(0, 0, 0)
        end
    end
    -- Fallback: Humanoid.MoveDirection (deadzone ile)
    if Humanoid and Humanoid.MoveDirection.Magnitude > 0.05 then
        return Humanoid.MoveDirection
    end
    return Vector3.new(0, 0, 0)
end

-- Kayma Animasyonu Durum Değişkenleri
local isSkidding = false
local skidProgress = 0
local skidDirSign = 1

-- MegaBonk Knockback Durum Değişkenleri
local knockbackEndTime = 0
local knockbackDuration = 0.22
local knockbackDir = Vector3.new(0, 0, 0)

-- RemoteEvents Dinleyicisi
local Events = ReplicatedStorage:WaitForChild("Events")
local ApplyKnockbackEvent = Events:WaitForChild("ApplyKnockback")

-- Ayak Tabanında Toz/Skid Efekti Oluştur (İsteğe bağlı)
local function setupParticles(hrp)
    if not hrp then return end
    local existing = hrp:FindFirstChild("SkidAttachment")
    if existing then existing:Destroy() end

    local cfg = Config.MovementInertia
    if not cfg or not cfg.EnableSkidParticles then
        skidEmitter = nil
        return
    end

    local att = Instance.new("Attachment")
    att.Name = "SkidAttachment"
    att.Position = Vector3.new(0, -2.8, 0) -- Tam ayak tabanı hizası
    att.Parent = hrp

    local pe = Instance.new("ParticleEmitter")
    pe.Name = "SkidDust"
    pe.Texture = "rbxasset://textures/particles/smoke_main.dds" -- Roblox yerleşik duman dokusu
    pe.Color = ColorSequence.new(Color3.fromRGB(240, 230, 210))
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(0.4, 2.4),
        NumberSequenceKeypoint.new(1, 3.8)
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1, 1.0)
    })
    pe.Lifetime = NumberRange.new(0.25, 0.60)
    pe.Rate = 0
    pe.Speed = NumberRange.new(6, 12)
    pe.SpreadAngle = Vector2.new(90, 90)
    pe.Acceleration = Vector3.new(0, 6, 0) -- Yukarı doğru savrulan duman kalkması
    pe.Orientation = Enum.ParticleOrientation.FacingCamera
    pe.Parent = att

    skidEmitter = pe
end

-- Canavarlardan Darbe Alınca Ölçülü Fiziksel Geri İtme (Hasar Yüzdesine Göre)
ApplyKnockbackEvent.OnClientEvent:Connect(function(pushDir, pushPower)
    if not Character or not RootPart or not Humanoid then return end
    if Humanoid.Health <= 0 or Character:GetAttribute("IsDowned") then return end
    
    pushPower = pushPower or 0.5
    
    local rawPush = (pushDir.Magnitude > 0.01) and pushDir or -RootPart.CFrame.LookVector
    local unitPush = Vector3.new(rawPush.X, 0, rawPush.Z)
    if unitPush.Magnitude > 0.01 then
        unitPush = unitPush.Unit
    else
        unitPush = Vector3.new(0, 0, 1)
    end
    
    -- 1. Ölçülü Fiziksel Darbe İmpulse'ı:
    -- Karakteri abartısız, kontrollü bir hızla hafifçe iter (4 ila 14 stud/sn)
    -- Havaya fırlama (popY) neredeyse sıfıra yakın tutulur ki ayaklar yere bassın ve yürüme hızı kesilmesin
    local horizSpeed = math.clamp(pushPower * 11, 4, 14)
    local popY = math.clamp(pushPower * 0.8, 0, 1.2)
    
    local curVel = RootPart.AssemblyLinearVelocity
    RootPart.AssemblyLinearVelocity = Vector3.new(
        unitPush.X * horizSpeed,
        math.max(curVel.Y * 0.1, 0) + popY,
        unitPush.Z * horizSpeed
    )
    
    -- 2. Çok Kısa Geriye İtme Momentum Süresi (0.05 - 0.10s - anlık hafif refleks)
    knockbackDuration = math.clamp(pushPower * 0.08, 0.05, 0.10)
    knockbackEndTime = os.clock() + knockbackDuration
    knockbackDir = unitPush
    
    -- 3. NOT: isSkidding bilerek tetiklenmez. Skid duruşu dönüş hızını ve ivmeyi kesip
    -- canavarların arasında kıstırılmaya ve stunlock hissine sebep oluyordu.
    if skidEmitter then
        local particleCount = math.floor(math.clamp(pushPower * 4, 2, 6))
        skidEmitter:Emit(particleCount)
    end
end)

-- Görünmez Zıplama Bekleme Süresi (0.45 Saniye - Karakter yere bastığı an pürüzsüzce tekrar zıplayabilir)
local function bindJumpCooldown(hum)
    if jumpStateConn then
        jumpStateConn:Disconnect()
        jumpStateConn = nil
    end
    if jumpPropConn then
        jumpPropConn:Disconnect()
        jumpPropConn = nil
    end
    jumpCooldownUntil = 0
    if not hum then return end
    
    -- Zıplama durumunun açık ve zıplama güçlerinin tam olduğunu garantile
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    if hum.JumpPower <= 0 then hum.JumpPower = 50 end
    if hum.JumpHeight <= 0 then hum.JumpHeight = 7.2 end

    jumpStateConn = hum.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            local now = os.clock()
            if now >= jumpCooldownUntil and ReplicatedStorage:GetAttribute("IsPaused") ~= true then
                jumpCooldownUntil = now + JUMP_COOLDOWN
            end
        end
    end)
    
    jumpPropConn = hum:GetPropertyChangedSignal("Jump"):Connect(function()
        local isBlocked = (os.clock() < jumpCooldownUntil) or (ReplicatedStorage:GetAttribute("IsPaused") == true)
        if isBlocked and hum.Jump then
            hum.Jump = false
        end
    end)
end

-- Tuş / mobil zıplama isteğinde bekleme süresi dolmadan zıplamayı engelle
UserInputService.JumpRequest:Connect(function()
    local isBlocked = (os.clock() < jumpCooldownUntil) or (ReplicatedStorage:GetAttribute("IsPaused") == true)
    if isBlocked and Humanoid and Humanoid.Parent then
        Humanoid.Jump = false
    end
end)

-- Karakter Doğduğunda Efektleri ve AutoRotate Ayarını Bağla
local function onCharacterAdded(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    RootPart = newChar:WaitForChild("HumanoidRootPart")
    currentVelocityVector = Vector3.new(0, 0, 0)
    
    if Humanoid then
        Humanoid.AutoRotate = false -- Otomatik dönmeyi kalıcı olarak kapat
        bindJumpCooldown(Humanoid)
    end
    if RootPart then
        currentFacingDirection = RootPart.CFrame.LookVector
    end
    
    isSkidding = false
    skidProgress = 0
    
    task.delay(0.2, function()
        if RootPart then
            setupParticles(RootPart)
        end
    end)
end

Player.CharacterAdded:Connect(onCharacterAdded)

if Humanoid then
    Humanoid.AutoRotate = false
    bindJumpCooldown(Humanoid)
end
if RootPart then
    currentFacingDirection = RootPart.CFrame.LookVector
    setupParticles(RootPart)
end

-- Oyun duraklatıldığında fizik momentumunu anında sıfırla ve sabitle
ReplicatedStorage:GetAttributeChangedSignal("IsPaused"):Connect(function()
    local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
    if isPaused then
        pauseStartTime = os.clock()
        currentVelocityVector = Vector3.new(0, 0, 0)
        isSkidding = false
        if RootPart then
            RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            RootPart.Anchored = true
        end
        if Humanoid and Humanoid.WalkSpeed > 0 then
            Humanoid.WalkSpeed = 0
        end
    else
        if pauseStartTime then
            local pauseDuration = os.clock() - pauseStartTime
            pauseStartTime = nil
            if jumpCooldownUntil > 0 then
                jumpCooldownUntil = jumpCooldownUntil + pauseDuration
            end
        end

        local playerGui = Player:FindFirstChild("PlayerGui")
        local isChoosing = Player:GetAttribute("IsChoosingUpgrade") == true
        local hasUpgradeUI = playerGui and playerGui:FindFirstChild("UpgradeUI") ~= nil
        local isOpeningChest = Player:GetAttribute("IsOpeningChest") == true or ReplicatedStorage:GetAttribute("IsOpeningChest") == true or (playerGui and playerGui:FindFirstChild("ChestAwardUI") ~= nil)
        if not isChoosing and not hasUpgradeUI and not isOpeningChest then
            if RootPart then
                RootPart.Anchored = false
            end
            if Humanoid then
                local speedBonus = Player:GetAttribute("SpeedBonus") or 0
                local currentCalculatedSpeed = 17 + speedBonus
                local isSprinting = Player:GetAttribute("IsSprinting") == true
                local targetSpeed = isSprinting and (currentCalculatedSpeed * 1.5) or currentCalculatedSpeed
                Humanoid.WalkSpeed = targetSpeed
                Humanoid.JumpPower = 50
                Humanoid.JumpHeight = 7.2
                Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                Humanoid:SetAttribute("PrePauseWalkSpeed", nil)
                Humanoid:SetAttribute("PreUpgradeWalkSpeed", currentCalculatedSpeed)
            end
        end
    end
end)

-- Vektör İnovasyonu ile Ağırlaştırılmış Dönüş Fiziği, Yumuşak Yönlenme & Kayma Animasyonu
RunService.RenderStepped:Connect(function(dt)
    if not Character or not Character.Parent or not Humanoid or not Humanoid.Parent or not RootPart or not RootPart.Parent or Player.Character ~= Character then return end
    if Humanoid.Health <= 0 or Character:GetAttribute("IsDowned") then return end
    if ReplicatedStorage:GetAttribute("IsPaused") == true then
        if not RootPart.Anchored then
            RootPart.Anchored = true
        end
        if Humanoid.WalkSpeed > 0 then
            Humanoid.WalkSpeed = 0
        end
        return
    end
    if ReplicatedStorage:GetAttribute("GameStarted") ~= true then return end
    if ReplicatedStorage:GetAttribute("CameraIntroActive") == true then return end

    -- Zıplama Güvenlik / Self-Healing Kontrolü:
    -- Oyuncu aktif oyundayken zıplamanın takılı veya 0 kalmasını anında düzeltir
    if not Humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end
    if Humanoid.JumpPower <= 0 then
        Humanoid.JumpPower = 50
    end
    if Humanoid.JumpHeight <= 0 then
        Humanoid.JumpHeight = 7.2
    end

    -- Roblox Varsayılan Otomatik Dönmesini Kalıcı Olarak Devre Dışı Bırak
    if Humanoid.AutoRotate then
        Humanoid.AutoRotate = false
    end

    local cfg = Config.MovementInertia
    if not cfg or not cfg.Enabled then return end

    -- Girdi yönü (Doğrudan kullanıcı girdisinden, 0ms gecikmesiz)
    local targetInput = getTargetInput()

    -- Darbe anında (0.08s) hafif itme kuvveti ekle, ANCAK oyuncunun kendi WASD girdisini baskılama!
    -- Oyuncu kaçmak istediğinde hızı ve yön kontrolü kesilmez, çevik şekilde canavarların arasından çıkabilir.
    local nowTime = os.clock()
    if knockbackEndTime and nowTime < knockbackEndTime then
        local remaining = (knockbackEndTime - nowTime) / (knockbackDuration or 0.10)
        targetInput = targetInput + (knockbackDir * (remaining * 0.40))
        if targetInput.Magnitude > 1 then
            targetInput = targetInput.Unit
        end
    end

    local rotSpeed = cfg.RotationSpeed or 7.5

    if targetInput.Magnitude > 0.05 then
        local lerpSpeed = cfg.InertiaResponsiveness or 6.0
        
        local minTurnDeg = cfg.MinTurnAngle or 55
        local skidAnimDeg = cfg.SkidAnimAngle or 100
        
        local turnStartDot = math.cos(math.rad(minTurnDeg)) -- 55°
        local skidAnimDot = math.cos(math.rad(skidAnimDeg)) -- 100°
        
        if currentVelocityVector.Magnitude > 0.08 then
            local dot = currentVelocityVector.Unit:Dot(targetInput.Unit)
            
            -- 55° ve Üzeri Dönüş Tespiti
            if dot < turnStartDot then
                local turnSeverity = math.clamp((turnStartDot - dot) / (1 + turnStartDot), 0, 1)
                local minTurnDampening = cfg.TurnInertiaDampening or 1.2
                
                -- Lerp hızını düşürerek karakterin dönüş anında daha ağır yavaşlamasını sağla
                lerpSpeed = lerpSpeed - (turnSeverity * (lerpSpeed - minTurnDampening))
                
                -- Arkaya dönüşlerde gövde dönme hızını belirgin şekilde yavaşlat
                if dot < 0 then
                    rotSpeed = rotSpeed * 0.55
                end
                
                -- 100° ve Üzeri Dönüşlerde Kayma Animasyonunu Tetikle
                if dot < skidAnimDot and not isSkidding then
                    isSkidding = true
                    skidProgress = 1.0
                    local crossY = currentVelocityVector.X * targetInput.Z - currentVelocityVector.Z * targetInput.X
                    skidDirSign = (crossY >= 0) and 1 or -1
                end

                -- 55° ve Üzeri Dönüşlerde Yoğun Toz Efekti Saç (Skid Particles)
                if cfg.EnableSkidParticles and skidEmitter then
                    local now = tick()
                    if now - lastSkidTick > 0.08 then
                        lastSkidTick = now
                        local emitCount = cfg.SkidParticleAmount or 12
                        skidEmitter:Emit(emitCount)
                    end
                end
            end
        end

        -- Mevcut hareket vektörünü yumuşakça hedef girdi yönüne kaydır
        currentVelocityVector = currentVelocityVector:Lerp(targetInput, math.clamp(dt * lerpSpeed, 0, 1))
        
        -- Bakılan hedef yönü güncelle
        if currentVelocityVector.Magnitude > 0.05 then
            currentFacingDirection = Vector3.new(currentVelocityVector.X, 0, currentVelocityVector.Z).Unit
        end
    else
        -- Girdi bırakıldığında kayarak fren yapma (Deceleration / Friction)
        local fricDecel = cfg.FrictionDeceleration or 7.0
        currentVelocityVector = currentVelocityVector:Lerp(Vector3.new(0, 0, 0), math.clamp(dt * fricDecel, 0, 1))
        -- Hız eşiğin altına indiğinde tamamen sıfırla (Artık kayma ve hız takılması olamaz)
        if currentVelocityVector.Magnitude < 0.04 then
            currentVelocityVector = Vector3.new(0, 0, 0)
        end
        isSkidding = false
        skidProgress = 0
    end

    -- Kayma Animasyonu İlerlemesi (Skid Progress Lerp)
    if isSkidding then
        skidProgress = math.max(0, skidProgress - (dt * 3.0))
        if skidProgress <= 0 then
            isSkidding = false
        end
    end
    
    -- Prosedürel Kayma Yatması (Kayma Animasyonu Offset - 18 Derece Yatma)
    local skidOffsetCFrame = CFrame.new()
    if isSkidding and skidProgress > 0 and (cfg.EnableSkidAnimation ~= false) then
        local sineVal = math.sin(skidProgress * math.pi)
        local maxTiltDeg = cfg.SkidTiltAngle or 18
        local pitchTilt = math.rad(-maxTiltDeg * sineVal) -- Geriye doğru topuk basıp yatma
        local rollTilt = math.rad(maxTiltDeg * 0.45 * sineVal * skidDirSign) -- Dönüş yönüne doğru yan yatma
        
        skidOffsetCFrame = CFrame.Angles(pitchTilt, 0, rollTilt)
    end

    -- KESİNTİSİZ YUMUŞAK VE AĞIRLAŞTIRILMIŞ GÖVDE DÖNÜŞÜ
    if currentFacingDirection.Magnitude > 0.01 then
        local targetCFrame = CFrame.lookAt(RootPart.Position, RootPart.Position + currentFacingDirection)
        RootPart.CFrame = RootPart.CFrame:Lerp(targetCFrame * skidOffsetCFrame, math.clamp(dt * rotSpeed, 0, 1))
    end

    -- İvmeli hareket vektörünü doğrudan Humanoid:Move() ile uygula
    if currentVelocityVector.Magnitude > 0 then
        Humanoid:Move(currentVelocityVector, false)
    else
        Humanoid:Move(Vector3.new(0, 0, 0), false)
    end
end)
