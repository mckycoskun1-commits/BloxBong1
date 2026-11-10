local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
end)

-- Toggle weapons event setup
local Events = ReplicatedStorage:WaitForChild("Events")
local ToggleWeaponsEvent = Events:FindFirstChild("ToggleWeapons") or Instance.new("RemoteEvent", Events)
ToggleWeaponsEvent.Name = "ToggleWeapons"

-- L tuşu artık HealthUIController üzerinden silah devre dışı bırakma modunu açar

local Cooldowns = {}
local EquippedWeapons = {} -- Başlangıç silahı kaldırıldı

local function getNearestEnemy(range)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end
    
    local nearest = nil
    local minDist = range
    
    local root = Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        local enemyPos = enemy:GetPivot().Position
        local dist = (enemyPos - root.Position).Magnitude
        if dist < minDist then
            minDist = dist
            nearest = enemy
        end
    end
    
    return nearest
end

local function attack(weaponName, target)
    local weapon = Config.Weapons[weaponName]
    if not weapon then return end
    
    local targetPos = target:GetPivot().Position
    local rootPos = Character.HumanoidRootPart.Position
    
    -- Görsel Efekt (Basit bir ışın/vuruş efekti)
    local effect = Instance.new("Part")
    effect.Anchored = true
    effect.CanCollide = false
    effect.Material = Enum.Material.Neon
    effect.Color = Color3.new(1, 1, 1)
    effect.Size = Vector3.new(0.5, 0.5, (rootPos - targetPos).Magnitude)
    effect.CFrame = CFrame.lookAt(rootPos, targetPos) * CFrame.new(0, 0, -effect.Size.Z/2)
    effect.Parent = workspace
    
    task.delay(0.1, function()
        effect:Destroy()
    end)
    
    -- Hasar Ver (Server'a bildir)
    local Events = ReplicatedStorage:FindFirstChild("Events")
    if Events and Events:FindFirstChild("CombatEvent") then
        Events.CombatEvent:FireServer(target, weaponName)
    end
end

RunService.Heartbeat:Connect(function(dt)
    if Player:GetAttribute("WeaponsDisabled") == true then return end
    if #EquippedWeapons == 0 then return end
    if ReplicatedStorage:GetAttribute("IsPaused") then return end
    if not Character or not Character:FindFirstChild("HumanoidRootPart") or Character:GetAttribute("IsDowned") then return end
    
    for _, weaponName in ipairs(EquippedWeapons) do
        local weapon = Config.Weapons[weaponName]
        if not weapon then continue end
        
        -- Bekleme süresi kontrolü
        Cooldowns[weaponName] = (Cooldowns[weaponName] or 0) - dt
        
        if Cooldowns[weaponName] <= 0 then
            local target = getNearestEnemy(weapon.Range)
            if target then
                attack(weaponName, target)
                local speedMult = Player:GetAttribute("AttackSpeedMultiplier") or 1
                Cooldowns[weaponName] = weapon.Cooldown / speedMult
            end
        end
    end
end)
