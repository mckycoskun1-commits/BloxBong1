-- ============================================================
-- AIM ASSIST CONTROLLER (Yürüme Yolu / Hareket Yönü İleticisi)
-- Kamerayı asla ellemez, hiçbir görsel efekt/nişangah oluşturmaz.
-- Sadece oyuncunun yürüdüğü / yöneldiği rotayı sunucuya iletir.
-- ============================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events", 10)
local SetAimTargetEvent = Events and (Events:FindFirstChild("SetAimTarget") or Events:WaitForChild("SetAimTarget", 5))

local lastSentDir = nil
local lastSentTime = 0

-- Kontrollerden anlık hareket vektörünü al
local cachedControls = nil
local function getMoveVector()
    if not cachedControls then
        pcall(function()
            local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
            if playerScripts then
                local playerModule = require(playerScripts:WaitForChild("PlayerModule", 3))
                cachedControls = playerModule:GetControls()
            end
        end)
    end
    if cachedControls and cachedControls.GetMoveVector then
        local mv = cachedControls:GetMoveVector()
        if mv and mv.Magnitude > 0.05 then
            local cam = workspace.CurrentCamera
            if cam then
                local camCFrame = cam.CFrame
                local right = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z)
                local forward = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z)
                if right.Magnitude > 0.001 and forward.Magnitude > 0.001 then
                    local worldVec = (right.Unit * mv.X + forward.Unit * -mv.Z)
                    if worldVec.Magnitude > 0.01 then
                        return worldVec.Unit
                    end
                end
            end
        end
    end
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.1 then
        return Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z).Unit
    end

    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local vel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
        if vel.Magnitude > 1.2 then
            return vel.Unit
        end
        local look = hrp.CFrame.LookVector
        return Vector3.new(look.X, 0, look.Z).Unit
    end

    return Vector3.new(0, 0, -1)
end

RunService.Heartbeat:Connect(function()
    -- Duraklatma (Pause) ve Oyun Durumu Kontrolü
    if ReplicatedStorage:GetAttribute("IsPaused") or not ReplicatedStorage:GetAttribute("GameStarted") then
        return
    end

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or char:GetAttribute("IsDowned") or LocalPlayer:GetAttribute("IsDowned") then
        return
    end

    if LocalPlayer:GetAttribute("AimAssistEnabled") == false then
        return
    end

    local currentDir = getMoveVector()
    local now = os.clock()

    -- Yön değiştiğinde veya her 0.15 saniyede bir sunucuya hafifçe ilet
    local dirChanged = false
    if not lastSentDir then
        dirChanged = true
    else
        local dot = lastSentDir:Dot(currentDir)
        if dot < 0.96 then -- Yaklaşık 16 derece yön değişimi
            dirChanged = true
        end
    end

    if SetAimTargetEvent and (dirChanged or (now - lastSentTime >= 0.15)) then
        lastSentDir = currentDir
        lastSentTime = now
        SetAimTargetEvent:FireServer(currentDir)
    end
end)
