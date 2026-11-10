local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))

local Events = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

local SprintEvent = Events:FindFirstChild("SprintEvent") or Instance.new("RemoteEvent")
SprintEvent.Name = "SprintEvent"
SprintEvent.Parent = Events

local PlayerRunTracks = {}

SprintEvent.OnServerEvent:Connect(function(player, isSprinting)
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid
        local baseSpeed = 19
        hum.WalkSpeed = isSprinting and (baseSpeed * 1.5) or baseSpeed
        
        -- Koşma Animasyonunu Doğrudan Yönet
        local animator = hum:FindFirstChild("Animator")
        if animator then
            local runTrack = PlayerRunTracks[player.UserId]
            
            -- Eğer track yoksa, önbelleğe alıp oluştur
            if not runTrack and AnimationConfig.Player.Run ~= "" then
                local runAnim = Instance.new("Animation")
                local finalId = tostring(AnimationConfig.Player.Run)
                if not string.find(finalId, "rbxassetid://") then
                    finalId = "rbxassetid://" .. finalId
                end
                runAnim.AnimationId = finalId
                
                runTrack = animator:LoadAnimation(runAnim)
                runTrack.Priority = Enum.AnimationPriority.Movement
                PlayerRunTracks[player.UserId] = runTrack
            end
            
            if runTrack then
                if isSprinting then
                    if not runTrack.IsPlaying then
                        runTrack:Play()
                    end
                else
                    if runTrack.IsPlaying then
                        runTrack:Stop()
                    end
                end
            end
        end
    end
end)

-- Lobi Karakter Animasyonlarını Yükle ve Koşma Animasyonlarını Sıfırla
local function setupPlayer(player)
    player.CharacterAdded:Connect(function(char)
        PlayerRunTracks[player.UserId] = nil -- Eski animasyonu sıfırla
        
        local hum = char:WaitForChild("Humanoid")
        
        task.spawn(function()
            task.wait(0.2) -- Roblox default Animate script'inin yüklenmesi için
            
            local animateScript = char:WaitForChild("Animate", 5)
            if animateScript then
                local playerAnims = AnimationConfig.Player
                
                local function updateAnim(name, newId)
                    if not newId or tostring(newId) == "" or tostring(newId) == "0" or tostring(newId) == "rbxassetid://0" then 
                        return 
                    end
                    
                    local finalId = tostring(newId)
                    if not string.find(finalId, "rbxassetid://") and tonumber(finalId) then
                        finalId = "rbxassetid://" .. finalId
                    end
                    
                    local container = animateScript:FindFirstChild(name)
                    if container then
                        for _, child in ipairs(container:GetChildren()) do
                            if child:IsA("Animation") then
                                child.AnimationId = finalId
                            end
                        end
                    end
                end
                
                updateAnim("idle", playerAnims.Idle)
                updateAnim("walk", playerAnims.Walk)
                updateAnim("run", playerAnims.Run)
                updateAnim("jump", playerAnims.Jump)
                updateAnim("fall", playerAnims.Fall)
                
                animateScript.Enabled = false
                task.wait(0.1)
                animateScript.Enabled = true
            end
        end)
    end)
    
    if player.Character then
        -- Eğer oyuncu çoktan doğduysa tetikle
        local hum = player.Character:FindFirstChild("Humanoid")
        if hum then
            player.Character:BreakJoints() -- Yeniden doğmasını sağla ki animasyonlar yüklensin
        end
    end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, p)
end
