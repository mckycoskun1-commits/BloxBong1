local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyConfig"))
local AnimationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local WaveConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WaveConfig"))

local gameTimeVal = ReplicatedStorage:WaitForChild("GameTime")
local function getCurrentSpawnDuration()
    local gameTime = math.max(0, gameTimeVal.Value)
    local activePhase = WaveConfig.Phases[1]
    for _, phase in ipairs(WaveConfig.Phases) do
        if gameTime >= phase.Time then
            activePhase = phase
        else
            break
        end
    end
    local delay = activePhase.SpawnDelay or 1.5
    local speedMult = math.clamp(1.5 / delay, 1.0, 5.0)
    return 1.0 / speedMult
end

-- Setup Replicated Storage Assets Folder
local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
local enemiesAssets = assetsFolder:WaitForChild("Enemies")

local enemiesFolder = workspace:WaitForChild("Enemies")

-- Local Visual State Cache
local activeVisuals = {}
local lastPositions = {}
local animTracks = {}

local hitboxByNetworkID = {}
local replicatedPositions = {}
local replicatedRotations = {}
local enemySnapshots = {} -- Key: networkID, Value: list of {time, position, rotY}

local Events = ReplicatedStorage:WaitForChild("Events")
local EnemyReplicationEvent = Events:WaitForChild("EnemyReplication")

-- Helper: Get interpolated state from snapshot history
local function getInterpolatedState(snapshots, renderTime, maxExtrapolateTime)
    local count = #snapshots
    if count == 0 then
        return nil, nil
    end
    
    -- Case 1: Only 1 snapshot
    if count == 1 then
        return snapshots[1].position, snapshots[1].rotY
    end
    
    -- Case 2: RenderTime is older than our oldest snapshot
    if renderTime < snapshots[1].time then
        return snapshots[1].position, snapshots[1].rotY
    end
    
    -- Case 3: RenderTime is newer than our newest snapshot (Extrapolation or Clamp)
    if renderTime > snapshots[count].time then
        local snapB = snapshots[count]
        if maxExtrapolateTime and maxExtrapolateTime > 0 then
            local snapA = snapshots[count - 1]
            local dt = snapB.time - snapA.time
            if dt > 0.0001 then
                local velocity = (snapB.position - snapA.position) / dt
                local timePassed = renderTime - snapB.time
                if timePassed <= maxExtrapolateTime then
                    local extPos = snapB.position + velocity * timePassed
                    local pos = Vector3.new(extPos.X, snapB.position.Y, extPos.Z)
                    return pos, snapB.rotY
                else
                    -- Decay velocity to zero after maxExtrapolateTime
                    local decay = math.max(0, 1 - (timePassed - maxExtrapolateTime) / 0.2)
                    local extPos = snapB.position + velocity * maxExtrapolateTime + (velocity * decay * (timePassed - maxExtrapolateTime))
                    local pos = Vector3.new(extPos.X, snapB.position.Y, extPos.Z)
                    return pos, snapB.rotY
                end
            end
        end
        return snapB.position, snapB.rotY
    end
    
    -- Case 4: General Interpolation between two snapshots
    local snapA, snapB
    for i = 1, count - 1 do
        if snapshots[i].time <= renderTime and snapshots[i+1].time >= renderTime then
            snapA = snapshots[i]
            snapB = snapshots[i+1]
            break
        end
    end
    
    if not snapA then
        return snapshots[count].position, snapshots[count].rotY
    end
    
    local timeDiff = snapB.time - snapA.time
    local alpha = timeDiff > 0.0001 and (renderTime - snapA.time) / timeDiff or 1
    alpha = math.clamp(alpha, 0, 1)
    
    local pos = snapA.position:Lerp(snapB.position, alpha)
    
    -- Angular lerp to prevent wrapping snaps
    local diff = (snapB.rotY - snapA.rotY + math.pi) % (2 * math.pi) - math.pi
    local rotY = snapA.rotY + diff * alpha
    
    return pos, rotY
end

local function updateModelTint(data, isSlowed)
    if data.LastSlowedState == isSlowed then return end
    data.LastSlowedState = isSlowed
    
    local visualModel = data.Model
    if not visualModel then return end
    
    if isSlowed then
        -- Apply blue tint (exclude eyes/face/dark parts to keep eyes black)
        for _, part in ipairs(visualModel:GetDescendants()) do
            if part:IsA("BasePart") then
                local nameLower = part.Name:lower()
                local isEyeOrFace = nameLower:find("eye") or nameLower:find("face") or nameLower:find("mouth") or nameLower:find("pupil")
                local isDarkPart = (part.Color.R < 0.15 and part.Color.G < 0.15 and part.Color.B < 0.15)
                if not isEyeOrFace and not isDarkPart then
                    -- Cache original color if not already cached
                    local originalColor = part:GetAttribute("OriginalVisualColor")
                    if not originalColor then
                        part:SetAttribute("OriginalVisualColor", part.Color)
                        originalColor = part.Color
                    end
                    -- Blend with blue color (e.g. 60% original, 40% light blue)
                    local tintColor = Color3.fromRGB(100, 180, 255)
                    part.Color = originalColor:Lerp(tintColor, 0.4)
                end
            end
        end
    else
        -- Restore original color
        for _, part in ipairs(visualModel:GetDescendants()) do
            if part:IsA("BasePart") then
                local originalColor = part:GetAttribute("OriginalVisualColor")
                if originalColor then
                    part.Color = originalColor
                    part:SetAttribute("OriginalVisualColor", nil)
                end
            end
        end
    end
end

EnemyReplicationEvent.OnClientEvent:Connect(function(replBuffer)
    local size = buffer.len(replBuffer)
    if size < 8 then return end
    
    local serverTime = buffer.readf64(replBuffer, 0)
    local count = (size - 8) / 10
    
    for i = 1, count do
        local offset = 8 + (i - 1) * 10
        local networkID = buffer.readu16(replBuffer, offset)
        local posX = buffer.readi16(replBuffer, offset + 2) / 10
        local posY = buffer.readi16(replBuffer, offset + 4) / 10
        local posZ = buffer.readi16(replBuffer, offset + 6) / 10
        local rotYInt = buffer.readi16(replBuffer, offset + 8)
        local rotY = (rotYInt / 32767) * math.pi
        
        replicatedPositions[networkID] = Vector3.new(posX, posY, posZ)
        replicatedRotations[networkID] = rotY
        
        local snapshots = enemySnapshots[networkID]
        if not snapshots then
            snapshots = {}
            enemySnapshots[networkID] = snapshots
        end
        
        -- Prevent out-of-order replication processing
        if #snapshots == 0 or serverTime > snapshots[#snapshots].time then
            table.insert(snapshots, {
                time = serverTime,
                position = Vector3.new(posX, posY, posZ),
                rotY = rotY
            })
            
            -- Keep a rolling buffer of 10 snapshots
            if #snapshots > 10 then
                table.remove(snapshots, 1)
            end
        end
    end
end)

-- Helper: Initialize Visuals for a server hitbox
local function setupVisualModel(hitbox)
    -- Wait for attributes to replicate from server
    local enemyType = hitbox:GetAttribute("EnemyType")
    if not enemyType then
        local start = os.clock()
        while not enemyType and os.clock() - start < 1.0 do
            task.wait()
            enemyType = hitbox:GetAttribute("EnemyType")
        end
    end
    if not enemyType then return end
    
    local scale = hitbox:GetAttribute("Scale") or 1.0
    local isBoss = hitbox:GetAttribute("IsBoss") == true
    
    local configData = EnemyConfig.Enemies[enemyType]
    if not configData then return end
    
    -- Clone model from ReplicatedStorage
    local modelName = configData.ModelName or "Slime"
    local template = enemiesAssets:FindFirstChild(modelName) or enemiesAssets:FindFirstChild("Slime")
    if not template then
        warn("No template model found for " .. modelName)
        return
    end
    
    local visualModel = template:Clone()
    visualModel.Name = "VisualModel"
    
    -- Customize colors (Only tints Slime model body, preserving eyes, face, and dark details)
    local configColor = configData.Color
    if modelName == "Slime" and configColor then
        for _, part in ipairs(visualModel:GetDescendants()) do
            if part:IsA("BasePart") then
                local nameLower = part.Name:lower()
                local isEyeOrFace = nameLower:find("eye") or nameLower:find("face") or nameLower:find("mouth") or nameLower:find("pupil")
                local isDarkPart = (part.Color.R < 0.15 and part.Color.G < 0.15 and part.Color.B < 0.15)
                
                if not isEyeOrFace and not isDarkPart then
                    part.Color = configColor
                end
            end
        end
    end
    
    -- Apply Scale
    visualModel:ScaleTo(scale)
    
    -- Calculate stable static Y offset once at spawn (prevents runtime GetBoundingBox jitter)
    local pivotOffset = 0
    pcall(function()
        local cframe, size = visualModel:GetBoundingBox()
        pivotOffset = visualModel:GetPivot().Position.Y - (cframe.Position.Y - size.Y/2)
    end)
    
    -- Fallback safety check if GetBoundingBox fails or returns 0
    if not pivotOffset or pivotOffset <= 0 then
        local isZombieModel = (modelName == "Zombie" or modelName == "FastZombie" or modelName == "ArmoredZombie" or modelName == "MegaZombie")
        if isZombieModel then
            -- Default R15 feet-to-waist offset is roughly 2.9 studs (scaled)
            pivotOffset = scale * 2.9
        else
            -- Default Slime radius is roughly 0.8 studs (scaled)
            pivotOffset = scale * 0.8
        end
    end
    
    -- 1. FIRST parent and position the model to the correct starting CFrame (prevents NaN/flinging bugs)
    visualModel.Parent = workspace
    
    -- Calculate and apply initial CFrame with ground alignment offset
    local initialPos = hitbox.Position
    local isZombieModel = (modelName == "Zombie" or modelName == "FastZombie" or modelName == "ArmoredZombie" or modelName == "MegaZombie")
    if isZombieModel then
        initialPos = initialPos - Vector3.new(0, scale * 1.7, 0)
    end
    local groundY = initialPos.Y - (scale * 0.8)
    local targetPivotY = groundY + pivotOffset
    local initialCFrame = CFrame.new(initialPos.X, targetPivotY, initialPos.Z) * hitbox.CFrame.Rotation
    visualModel:PivotTo(initialCFrame)
    
    -- Only humanoids/skeletal models (like Zombie) need unanchored physics for their animator to rotate limbs
    local needsPhysicsAnchor = isZombieModel
    
    -- 2. Clean up physics properties
    for _, part in ipairs(visualModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Anchored = not needsPhysicsAnchor -- Keep Slime anchored so its loose parts don't fall apart!
            part.Massless = true
            part.CollisionGroup = "Enemies" -- Prevent any player collisions (players walk through models)
        end
    end
    
    -- 3. Create client-side visual anchor for welding models
    local visualAnchor = Instance.new("Part")
    visualAnchor.Name = "VisualAnchor_" .. enemyType
    visualAnchor.Transparency = 1
    visualAnchor.CanCollide = false
    visualAnchor.CanTouch = false
    visualAnchor.CanQuery = false
    visualAnchor.Anchored = true
    visualAnchor.CollisionGroup = "Enemies"
    
    -- Custom box shapes and sizes matching each enemy type's physical appearance
    local isZombieModel = (modelName == "Zombie" or modelName == "FastZombie" or modelName == "ArmoredZombie" or modelName == "MegaZombie")
    if isZombieModel then
        visualAnchor.Shape = Enum.PartType.Block
        visualAnchor.Size = Vector3.new(scale * 2.4, scale * 5.2, scale * 2.4)
    elseif modelName == "Slime" then
        visualAnchor.Shape = Enum.PartType.Block
        visualAnchor.Size = Vector3.new(scale * 2.6, scale * 2.4, scale * 2.6)
    else
        visualAnchor.Shape = Enum.PartType.Block
        visualAnchor.Size = Vector3.new(scale * 2.4, scale * 3.5, scale * 2.4)
    end
    
    -- Position client hitbox so its bottom aligns perfectly with ground level
    local spawnGroundY = initialPos.Y - (scale * 0.8)
    local clientHitboxY = spawnGroundY + (visualAnchor.Size.Y / 2)
    visualAnchor.CFrame = CFrame.new(initialPos.X, clientHitboxY, initialPos.Z) * hitbox.CFrame.Rotation
    visualAnchor.Parent = workspace
    
    if needsPhysicsAnchor then
        -- Weld visual model to the visual anchor using standard Weld to apply relative pivot offset
        local rootPart = visualModel.PrimaryPart or visualModel:FindFirstChild("HumanoidRootPart") or visualModel:FindFirstChildOfClass("BasePart")
        if rootPart then
            local weld = Instance.new("Weld")
            weld.Name = "VisualWeld"
            weld.Part0 = visualAnchor
            weld.Part1 = rootPart
            -- Offset rootPart from visualAnchor center to visual model pivot (groundY + pivotOffset)
            weld.C0 = CFrame.new(0, -visualAnchor.Size.Y / 2 + pivotOffset, 0)
            weld.Parent = visualAnchor
        end
    end
    
    -- Keep Humanoid dormant to preserve clothing rendering, otherwise fall back to AnimationController
    local humanoid = visualModel:FindFirstChildOfClass("Humanoid")
    local animatorParent = humanoid
    
    if humanoid then
        -- Configure humanoid to be dormant (no physics, no tags) to save performance and keep clothes loading
        humanoid.PlatformStand = true
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.RequiresNeck = false
        pcall(function()
            humanoid.EvaluateStateMachine = false
        end)
    else
        -- Fallback to AnimationController if model has no Humanoid
        local animController = visualModel:FindFirstChildOfClass("AnimationController")
        if not animController then
            animController = Instance.new("AnimationController")
            animController.Name = "AnimationController"
            animController.Parent = visualModel
        end
        animatorParent = animController
    end
    
    local animator = animatorParent and (animatorParent:FindFirstChildOfClass("Animator") or Instance.new("Animator", animatorParent))
    
    local walkTrack = nil
    local animData = AnimationConfig.Enemies[enemyType]
    if animator and animData and animData.Walk and animData.Walk ~= "" then
        local animObj = Instance.new("Animation")
        
        local finalId = tostring(animData.Walk)
        if not string.find(finalId, "rbxasset://") and not string.find(finalId, "rbxassetid://") then
            finalId = "rbxassetid://" .. finalId
        end
        animObj.AnimationId = finalId
        
        local success, track = pcall(function()
            return animator:LoadAnimation(animObj)
        end)
        
        if success and track then
            walkTrack = track
            walkTrack.Looped = true
        end
    end
    
    local duration = getCurrentSpawnDuration()
    local state = "Emerging"
    local transitionDuration = duration
    
    if hitbox:GetAttribute("IsSinking") == true then
        state = "Sinking"
        transitionDuration = hitbox:GetAttribute("SinkDuration") or 1.0
    end
    
    local sinkingConn
    local function onIsSinkingChanged()
        local isSinking = hitbox:GetAttribute("IsSinking") == true
        local visualData = activeVisuals[hitbox]
        if visualData then
            if isSinking then
                visualData.State = "Sinking"
                visualData.TransitionStart = os.clock()
                visualData.TransitionDuration = hitbox:GetAttribute("SinkDuration") or 1.0
            else
                visualData.State = "Emerging"
                visualData.TransitionStart = os.clock()
                visualData.TransitionDuration = getCurrentSpawnDuration()
            end
        end
    end
    sinkingConn = hitbox:GetAttributeChangedSignal("IsSinking"):Connect(onIsSinkingChanged)
    
    local isZombieModel = (modelName == "Zombie" or modelName == "FastZombie" or modelName == "ArmoredZombie" or modelName == "MegaZombie")
    activeVisuals[hitbox] = {
        Model = visualModel,
        Anchor = visualAnchor,
        WalkTrack = walkTrack,
        BaseScale = scale,
        PivotOffset = pivotOffset,
        LastCFrame = hitbox.CFrame,
        Config = configData,
        ModelName = modelName,
        IsZombieModel = isZombieModel,
        State = state,
        TransitionStart = os.clock(),
        TransitionDuration = transitionDuration,
        SinkingConnection = sinkingConn
    }
    
    local networkID = hitbox:GetAttribute("NetworkID")
    if networkID then
        hitboxByNetworkID[networkID] = hitbox
    else
        local conn
        conn = hitbox:GetAttributeChangedSignal("NetworkID"):Connect(function()
            local nid = hitbox:GetAttribute("NetworkID")
            if nid then
                hitboxByNetworkID[nid] = hitbox
                conn:Disconnect()
            end
        end)
    end
end

-- Initialize existing hitboxes
for _, hitbox in ipairs(enemiesFolder:GetChildren()) do
    setupVisualModel(hitbox)
end

-- Listen to new hitboxes
enemiesFolder.ChildAdded:Connect(setupVisualModel)

enemiesFolder.ChildRemoved:Connect(function(hitbox)
    local networkID = hitbox:GetAttribute("NetworkID")
    if networkID then
        hitboxByNetworkID[networkID] = nil
        replicatedPositions[networkID] = nil
        replicatedRotations[networkID] = nil
        enemySnapshots[networkID] = nil
    end
    local data = activeVisuals[hitbox]
    if data then
        if data.Model then data.Model:Destroy() end
        if data.Anchor then data.Anchor:Destroy() end
        if data.SinkingConnection then data.SinkingConnection:Disconnect() end
    end
    activeVisuals[hitbox] = nil
    lastPositions[hitbox] = nil
end)

-- Pause handling: Shift visual transition timers and update stale snapshots on unpause
local clientPauseStartTime = nil
ReplicatedStorage:GetAttributeChangedSignal("IsPaused"):Connect(function()
    local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
    if isPaused then
        clientPauseStartTime = os.clock()
    else
        if clientPauseStartTime then
            local pauseDuration = os.clock() - clientPauseStartTime
            clientPauseStartTime = nil
            
            -- Shift emerging / sinking transition timers so visual animations resume seamlessly
            for _, data in pairs(activeVisuals) do
                if data and data.TransitionStart then
                    data.TransitionStart = data.TransitionStart + pauseDuration
                end
            end
            
            -- Reset snapshot timestamps to avoid stale extrapolation / position jumps on unpause
            local currentServerTime = workspace:GetServerTimeNow()
            for nid, snaps in pairs(enemySnapshots) do
                if #snaps > 0 then
                    local latest = snaps[#snaps]
                    latest.time = currentServerTime
                    enemySnapshots[nid] = { latest }
                end
            end
        end
    end
end)

-- Main Render Loop for smooth lerping, snapshot interpolation, and distance-based LOD
local camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

RunService.RenderStepped:Connect(function(dt)
    local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
    
    -- Freeze/Resume all players' animations when paused
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if isPaused then
                    local speed = track.Speed
                    if speed > 0 then
                        track:SetAttribute("OriginalSpeed", speed)
                        track:AdjustSpeed(0)
                    end
                else
                    local originalSpeed = track:GetAttribute("OriginalSpeed")
                    if originalSpeed then
                        track:AdjustSpeed(originalSpeed)
                        track:SetAttribute("OriginalSpeed", nil)
                    end
                end
            end
        end
    end
    
    local playerPos = Vector3.zero
    if localPlayer.Character and localPlayer.Character.PrimaryPart then
        playerPos = localPlayer.Character.PrimaryPart.Position
    else
        playerPos = camera.CFrame.Position
    end
    
    local nowTime = workspace:GetServerTimeNow()
    
    for hitbox, data in pairs(activeVisuals) do
        if not hitbox or not hitbox.Parent then
            if data then
                if data.Model then data.Model:Destroy() end
                if data.Anchor then data.Anchor:Destroy() end
                if data.SinkingConnection then data.SinkingConnection:Disconnect() end
            end
            activeVisuals[hitbox] = nil
            continue
        end
        
        local visualModel = data.Model
        local visualAnchor = data.Anchor
        local scale = data.BaseScale
        local networkID = hitbox:GetAttribute("NetworkID")
        
        -- Update model tint based on SnowballSlowed state
        local isSlowed = hitbox:GetAttribute("SnowballSlowed") == true
        updateModelTint(data, isSlowed)
        
        local currentCFrame = data.LastCFrame or hitbox.CFrame
        local dx = currentCFrame.Position.X - playerPos.X
        local dy = currentCFrame.Position.Y - playerPos.Y
        local dz = currentCFrame.Position.Z - playerPos.Z
        local distSq = dx * dx + dy * dy + dz * dz
        
        -- Emerging / Sinking transition animation calculations
        local heightOffset = 0
        if data.State ~= "Normal" then
            local elapsed = os.clock() - data.TransitionStart
            local progress = math.clamp(elapsed / data.TransitionDuration, 0, 1)
            
            -- Sinking depth starts deeper based on scale and anchor size to ensure thin models (like slimes) spawn fully under the ground
            local maxSubmergeDepth = math.max(visualAnchor and visualAnchor.Size.Y or 0, scale * 5.0) * 2.5
            
            if data.State == "Emerging" then
                heightOffset = (1 - progress) * (-maxSubmergeDepth)
                if progress >= 1 then
                    data.State = "Normal"
                end
            elseif data.State == "Sinking" then
                heightOffset = progress * (-maxSubmergeDepth)
            end
        end
        
        -- --- Level of Detail (LOD) and Performance Bands ---
        
        -- Band 3: Far Range (70+ studs, 70^2 = 4900) -> Throttle updates (every 2-3 frames) & Simple Lerp
        if distSq > 4900 then
            -- Make sure model is visible
            if visualModel.Parent ~= workspace then
                visualModel.Parent = workspace
            end
            if visualAnchor and visualAnchor.Parent ~= workspace then
                visualAnchor.Parent = workspace
            end
            
            data.FrameCount = (data.FrameCount or 0) + 1
            local skipFrames = distSq > 10000 and 3 or 2
            if data.FrameCount % skipFrames ~= 0 then
                -- Still adjust animation playback speed to prevent static poses
                local walkTrack = data.WalkTrack
                if walkTrack then
                    if isPaused then
                        walkTrack:AdjustSpeed(0)
                    end
                end
                continue
            end
            
            -- Simple lerp to latest packet
            local snapshots = networkID and enemySnapshots[networkID]
            local targetPos, targetRotY
            if snapshots and #snapshots > 0 then
                local latest = snapshots[#snapshots]
                targetPos = latest.position
                targetRotY = latest.rotY
            else
                if data.IsZombieModel then
                    targetPos = hitbox.Position - Vector3.new(0, scale * 1.7, 0)
                else
                    targetPos = hitbox.Position
                end
                targetRotY = 0
            end
            local targetCFrame = CFrame.new(targetPos) * CFrame.Angles(0, targetRotY, 0)
            
            -- Fast simple linear lerp (frame-rate independent)
            local nextCFrame
            if isPaused then
                nextCFrame = targetCFrame
            else
                local alpha = 1 - math.exp(-12 * dt)
                nextCFrame = currentCFrame:Lerp(targetCFrame, alpha)
            end
            data.LastCFrame = nextCFrame
            hitbox.CFrame = nextCFrame
            
            -- Sync physical anchor & model
            local groundY = nextCFrame.Position.Y - (scale * 0.8)
            local targetPivotY = groundY + data.PivotOffset
            local finalCFrame = CFrame.new(nextCFrame.Position.X, targetPivotY + heightOffset, nextCFrame.Position.Z) * nextCFrame.Rotation
            
            if visualAnchor then
                local clientHitboxY = groundY + (visualAnchor.Size.Y / 2)
                visualAnchor.CFrame = CFrame.new(nextCFrame.Position.X, clientHitboxY, nextCFrame.Position.Z) * nextCFrame.Rotation
                
                local weld = visualAnchor:FindFirstChild("VisualWeld")
                if weld then
                    weld.C0 = CFrame.new(0, -visualAnchor.Size.Y / 2 + data.PivotOffset + heightOffset, 0)
                end
            end
            if data.ModelName == "Slime" then
                visualModel:PivotTo(finalCFrame)
            end
            continue
        end
        
        -- Ensure model is visible for Bands 1 & 2
        if visualModel.Parent ~= workspace then
            visualModel.Parent = workspace
        end
        if visualAnchor and visualAnchor.Parent ~= workspace then
            visualAnchor.Parent = workspace
        end
        
        -- Band 1 & 2: Near Range (<100 studs) -> Snapshot Interpolation
        local targetPos, targetRotY
        local snapshots = networkID and enemySnapshots[networkID]
        
        if isPaused then
            -- Snap to the latest available snapshot immediately
            if snapshots and #snapshots > 0 then
                targetPos = snapshots[#snapshots].position
                targetRotY = snapshots[#snapshots].rotY
            else
                targetPos = hitbox.Position
                targetRotY = 0
            end
        elseif distSq <= 1600 then -- Band 1: Close Range (<40 studs, 40^2 = 1600)
            if snapshots then
                targetPos, targetRotY = getInterpolatedState(snapshots, nowTime - 0.10, 0.3)
            end
        else
            -- Band 2: Medium Range (40–100 studs) -> Sadece interpolation, extrapolation yok
            if snapshots then
                targetPos, targetRotY = getInterpolatedState(snapshots, nowTime - 0.12, 0)
            end
        end
        
        if not targetPos then
            if data.IsZombieModel then
                targetPos = hitbox.Position - Vector3.new(0, scale * 1.7, 0)
            else
                targetPos = hitbox.Position
            end
            targetRotY = 0
        end
        local targetCFrame = CFrame.new(targetPos) * CFrame.Angles(0, targetRotY, 0)
        
        local nextCFrame
        if isPaused then
            nextCFrame = targetCFrame
        else
            -- Frame-rate independent CFrame Lerp (to filter packet jitter)
            local lerpSpeed = 13
            local alpha = 1 - math.exp(-lerpSpeed * dt)
            
            -- Prevent excessive gliding/stretching on spawn or teleports (> 20 studs, 20^2 = 400)
            local tdx = targetCFrame.Position.X - currentCFrame.Position.X
            local tdy = targetCFrame.Position.Y - currentCFrame.Position.Y
            local tdz = targetCFrame.Position.Z - currentCFrame.Position.Z
            if (tdx * tdx + tdy * tdy + tdz * tdz) > 400 then
                currentCFrame = targetCFrame
            end
            nextCFrame = currentCFrame:Lerp(targetCFrame, alpha)
        end
        data.LastCFrame = nextCFrame
        hitbox.CFrame = nextCFrame
        
        -- Calculate movement velocity based on smooth client-side visual position
        local lastPos = lastPositions[hitbox] or nextCFrame.Position
        local distanceMoved = (nextCFrame.Position - lastPos).Magnitude
        local velocity = dt > 0 and (distanceMoved / dt) or 0
        lastPositions[hitbox] = nextCFrame.Position
        
        -- Align bottom of visual model with ground using calculated PivotOffset
        local groundY = nextCFrame.Position.Y - (scale * 0.8)
        local targetPivotY = groundY + data.PivotOffset
        local finalCFrame = CFrame.new(nextCFrame.Position.X, targetPivotY + heightOffset, nextCFrame.Position.Z) * nextCFrame.Rotation
        
        if visualAnchor then
            local clientHitboxY = groundY + (visualAnchor.Size.Y / 2)
            visualAnchor.CFrame = CFrame.new(nextCFrame.Position.X, clientHitboxY, nextCFrame.Position.Z) * nextCFrame.Rotation
            
            local weld = visualAnchor:FindFirstChild("VisualWeld")
            if weld then
                weld.C0 = CFrame.new(0, -visualAnchor.Size.Y / 2 + data.PivotOffset + heightOffset, 0)
            end
        end
        if data.ModelName == "Slime" then
            visualModel:PivotTo(finalCFrame)
        end
        
        -- Skeletal walk animation speed sync
        local walkTrack = data.WalkTrack
        if walkTrack then
            if isPaused then
                if walkTrack.IsPlaying then
                    walkTrack:AdjustSpeed(0)
                end
            elseif velocity > 0.6 then
                if not walkTrack.IsPlaying then
                    walkTrack:Play(0.2)
                end
                local targetSpeed = math.clamp(velocity / 12, 0.4, 2.0)
                walkTrack:AdjustSpeed(targetSpeed)
            else
                if walkTrack.IsPlaying then
                    walkTrack:Stop(0.2)
                end
            end
        end
    end
end)
