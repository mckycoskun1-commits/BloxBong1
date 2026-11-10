local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")

local DS_Silver = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_TopSilver_V1")
local DS_Coins = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_TopCoins_V2")
local DS_Kills = DataStoreService:GetOrderedDataStore("GlobalLeaderboard_TopKills_V2")

-- Otomatik doğmayı kapat (Biz kontrol edeceğiz)
Players.CharacterAutoLoads = false

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local AnimationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local CharacterUIConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterUIConfig"))
local LobbyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))

math.randomseed(os.time()) -- Rastgeleliği güçlendir

-- RemoteEvents oluştur
local Events = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

local LevelUpEvent = Events:FindFirstChild("LevelUp") or Instance.new("RemoteEvent")
LevelUpEvent.Name = "LevelUp"
LevelUpEvent.Parent = Events

local ApplyUpgradeEvent = Events:FindFirstChild("ApplyUpgrade") or Instance.new("RemoteEvent")
ApplyUpgradeEvent.Name = "ApplyUpgrade"
ApplyUpgradeEvent.Parent = Events

local UpdateHealthEvent = Events:FindFirstChild("UpdateHealth") or Instance.new("RemoteEvent")
UpdateHealthEvent.Name = "UpdateHealth"
UpdateHealthEvent.Parent = Events

local UpdateXPEvent = Events:FindFirstChild("UpdateXP") or Instance.new("RemoteEvent")
UpdateXPEvent.Name = "UpdateXP"
UpdateXPEvent.Parent = Events

local RetryEvent = Events:FindFirstChild("RetryGame") or Instance.new("RemoteEvent")
RetryEvent.Name = "RetryGame"
RetryEvent.Parent = Events

local ContinueEvent = Events:FindFirstChild("ContinueGame") or Instance.new("RemoteEvent")
ContinueEvent.Name = "ContinueGame"
ContinueEvent.Parent = Events

local ReturnToLobbyEvent = Events:FindFirstChild("ReturnToLobby") or Instance.new("RemoteEvent")
ReturnToLobbyEvent.Name = "ReturnToLobby"
ReturnToLobbyEvent.Parent = Events

local ShowGameOverEvent = Events:FindFirstChild("ShowGameOver") or Instance.new("RemoteEvent")
ShowGameOverEvent.Name = "ShowGameOver"
ShowGameOverEvent.Parent = Events

local ShowDamageEvent = Events:FindFirstChild("ShowDamage") or Instance.new("RemoteEvent")
ShowDamageEvent.Name = "ShowDamage"
ShowDamageEvent.Parent = Events

local PlayProjectileVisualEvent = Events:FindFirstChild("PlayProjectileVisual") or Instance.new("RemoteEvent")
PlayProjectileVisualEvent.Name = "PlayProjectileVisual"
PlayProjectileVisualEvent.Parent = Events

local ShowMessageEvent = Events:FindFirstChild("ShowMessage") or Instance.new("RemoteEvent")
ShowMessageEvent.Name = "ShowMessage"
ShowMessageEvent.Parent = Events

local ShowUpgradeNotificationEvent = Events:FindFirstChild("ShowUpgradeNotification") or Instance.new("RemoteEvent")
ShowUpgradeNotificationEvent.Name = "ShowUpgradeNotification"
ShowUpgradeNotificationEvent.Parent = Events

local PlayerReadyEvent = Events:FindFirstChild("PlayerReady") or Instance.new("RemoteEvent")
PlayerReadyEvent.Name = "PlayerReady"
PlayerReadyEvent.Parent = Events

local StartGameEvent = Events:FindFirstChild("StartGame") or Instance.new("RemoteEvent")
StartGameEvent.Name = "StartGame"
StartGameEvent.Parent = Events

local RevivePlayerEvent = Events:FindFirstChild("RevivePlayer") or Instance.new("RemoteEvent")
RevivePlayerEvent.Name = "RevivePlayer"
RevivePlayerEvent.Parent = Events

local HideRevivePromptEvent = Events:FindFirstChild("HideRevivePrompt") or Instance.new("RemoteEvent")
HideRevivePromptEvent.Name = "HideRevivePrompt"
HideRevivePromptEvent.Parent = Events

local PlayerSpawnedBindable = Events:FindFirstChild("PlayerSpawned") or Instance.new("BindableEvent")
PlayerSpawnedBindable.Name = "PlayerSpawned"
PlayerSpawnedBindable.Parent = Events

-- Chest events
local PlayChestAnimationEvent = Events:FindFirstChild("PlayChestAnimation") or Instance.new("RemoteEvent")
PlayChestAnimationEvent.Name = "PlayChestAnimation"
PlayChestAnimationEvent.Parent = Events

local ChestAwardedEvent = Events:FindFirstChild("ChestAwarded") or Instance.new("RemoteEvent")
ChestAwardedEvent.Name = "ChestAwarded"
ChestAwardedEvent.Parent = Events

local ChestClaimedEvent = Events:FindFirstChild("ChestClaimed") or Instance.new("RemoteEvent")
ChestClaimedEvent.Name = "ChestClaimed"
ChestClaimedEvent.Parent = Events

local BossDefeatedBindable = Events:FindFirstChild("BossDefeated") or Instance.new("BindableEvent")
BossDefeatedBindable.Name = "BossDefeated"
BossDefeatedBindable.Parent = Events

local TogglePauseEvent = Events:FindFirstChild("TogglePause") or Instance.new("RemoteEvent")
TogglePauseEvent.Name = "TogglePause"
TogglePauseEvent.Parent = Events

local ApplyKnockbackEvent = Events:FindFirstChild("ApplyKnockback") or Instance.new("RemoteEvent")
ApplyKnockbackEvent.Name = "ApplyKnockback"
ApplyKnockbackEvent.Parent = Events

local PlayerData = {}
local ReadyPlayers = {}
local PlayersChoosing = {} -- Kart seçen oyuncuları takip et
local PlayerRunTracks = {} -- Koşma animasyonlarını önbellekte tutmak için
local addXPToAll = nil

local function revivePlayer(downedPlayer, reviver)
    if not downedPlayer or not reviver or downedPlayer == reviver then return end
    
    local data = PlayerData[downedPlayer.UserId]
    if not data or not data.IsDowned then return end
    
    -- ATOMİK DURUM DEĞİŞİMİ
    data.IsDowned = false
    data.Health = data.MaxHealth * 0.4 -- %40 can
    
    local char = downedPlayer.Character
    if char then
        char:SetAttribute("IsDowned", false)
        
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            -- Tüm kısıtlamaları kaldır
            hum.PlatformStand = false
            hum.WalkSpeed = 17 + (data.SpeedBonus or 0)
            hum.JumpPower = 50
            hum.JumpHeight = 7.2
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum.AutoRotate = true
            hum.Health = data.Health
            
            -- Fiziksel durumu resetle
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            
            -- Animasyonları temizle
            local animator = hum:FindFirstChild("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop(0.1)
                end
            end
        end
        
        -- Tüm canlandırma UI ve Promptlarını temizle
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            for _, child in ipairs(root:GetChildren()) do
                if child.Name == "RevivePrompt" then
                    child:Destroy()
                end
            end
        end
    end
    
    if typeof(downedPlayer) == "Instance" and downedPlayer:IsA("Player") then
        UpdateHealthEvent:FireClient(downedPlayer, data.Health, data.MaxHealth)
        -- Canlanan oyuncuya 3 saniye hasar görmezlik
        data.InvulnerableUntil = os.clock() + 3
    end
    
    -- Canlandıran oyuncuya da 3 saniye hasar görmezlik
    local reviverData = PlayerData[reviver.UserId]
    if reviverData then
        reviverData.InvulnerableUntil = os.clock() + 3
    end

    -- SİLAH SIFIRLAMA SİNYALİ (CombatManager için)
    PlayerSpawnedBindable:Fire(downedPlayer)

    ShowMessageEvent:FireAllClients(reviver.Name .. " has revived " .. (downedPlayer.Name or "Unknown") .. "!", Color3.fromRGB(0, 255, 0))
end

-- TEST DUMMY SİSTEMİ (Revive test etmek için)
local function spawnTestDummy(creator)
    local char = creator.Character
    if not char then return end
    
    local dummy = Instance.new("Model", workspace)
    dummy.Name = "TestDummy"
    
    local hrp = Instance.new("Part", dummy)
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Position = char.HumanoidRootPart.Position + Vector3.new(5, 0, 0)
    dummy.PrimaryPart = hrp
    
    local hum = Instance.new("Humanoid", dummy)
    
    -- Mock Player Data
    local dummyId = -99 -- Sahte ID
    PlayerData[dummyId] = {
        Health = 0,
        MaxHealth = 100,
        IsDowned = true,
        UserId = dummyId
    }
    
    local prompt = Instance.new("ProximityPrompt", hrp)
    prompt.Name = "RevivePrompt"
    prompt.ActionText = "Revive Test Dummy"
    prompt.ObjectText = "TEST NPC"
    prompt.HoldDuration = 3
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    
    prompt.Triggered:Connect(function(reviver)
        -- revivePlayer fonksiyonunu çağır (Mock player objesi oluşturarak)
        local mockPlayer = { UserId = dummyId, Name = "TestDummy", Character = dummy }
        revivePlayer(mockPlayer, reviver)
        -- print("Test Dummy revived!")
        
        -- Tekrar denemek için 5 saniye sonra tekrar düşür
        task.delay(5, function()
            PlayerData[dummyId].IsDowned = true
            hum.PlatformStand = true
            local newPrompt = Instance.new("ProximityPrompt", hrp)
            newPrompt.Name = "RevivePrompt"
            newPrompt.ActionText = "Revive Test Dummy"
            newPrompt.HoldDuration = 3
            newPrompt.KeyboardKeyCode = Enum.KeyCode.E
            newPrompt.Triggered:Connect(function(r)
                revivePlayer(mockPlayer, r)
            end)
        end)
    end)
    
    hum.PlatformStand = true -- Yere düşmüş gibi görünsün
    -- print("Test Dummy created! Type /dummy to create again.")
end

local GetPlayerDataEvent = Events:FindFirstChild("GetPlayerData") or Instance.new("BindableFunction")
GetPlayerDataEvent.Name = "GetPlayerData"
GetPlayerDataEvent.Parent = Events

local CombatEvent = Events:FindFirstChild("CombatEvent") or Instance.new("RemoteEvent")
CombatEvent.Name = "CombatEvent"
CombatEvent.Parent = Events

CombatEvent.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if data and data.IsDowned then
        -- Ölü/Düşmüş oyuncu ateş edemez
        return
    end
end)

local SprintEvent = Events:FindFirstChild("SprintEvent") or Instance.new("RemoteEvent")
SprintEvent.Name = "SprintEvent"
SprintEvent.Parent = Events

SprintEvent.OnServerEvent:Connect(function(player, isSprinting)
    if ReplicatedStorage:GetAttribute("GameStarted") ~= true then return end
    if ReplicatedStorage:GetAttribute("CameraIntroActive") == true then return end
    local data = PlayerData[player.UserId]
    if not data or data.IsDowned then return end
    
    data.IsSprinting = (isSprinting == true)
    player:SetAttribute("IsSprinting", data.IsSprinting)
    
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid
        local baseSpeed = 17 + (data.SpeedBonus or 0)
        if not data.ActiveKnockbackCleanup then
            hum.WalkSpeed = data.IsSprinting and (baseSpeed * 1.5) or baseSpeed
        end
        
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
                if data.IsSprinting then
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


local ClientGetPlayerData = Events:FindFirstChild("ClientGetPlayerData") or Instance.new("RemoteFunction")
ClientGetPlayerData.Name = "ClientGetPlayerData"
ClientGetPlayerData.Parent = Events

local UpdateCoinsEvent = Instance.new("RemoteEvent")
UpdateCoinsEvent.Name = "UpdateCoins"
UpdateCoinsEvent.Parent = Events

local BuySlotEvent = Instance.new("RemoteEvent")
BuySlotEvent.Name = "BuySlot"
BuySlotEvent.Parent = Events

local RerollUpgradesEvent = Instance.new("RemoteEvent")
RerollUpgradesEvent.Name = "RerollUpgrades"
RerollUpgradesEvent.Parent = Events

local PlayerUpgradedEvent = Instance.new("BindableEvent")
PlayerUpgradedEvent.Name = "PlayerUpgraded"
PlayerUpgradedEvent.Parent = Events

ReplicatedStorage:SetAttribute("GameStarted", false)
ReplicatedStorage:SetAttribute("IsPaused", false)
ReplicatedStorage:SetAttribute("IsManualPaused", false)
ReplicatedStorage:SetAttribute("CameraIntroActive", false)

-- OYUNCULARI DONDUR / ÇÖZ
local function setPlayersFrozen(frozen)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = player.Character.HumanoidRootPart
            hrp.Anchored = frozen
        end
    end
end

-- Toggle pause connection
TogglePauseEvent.OnServerEvent:Connect(function(player)
    -- Don't allow manual unpause or toggle if a chest is being opened or upgrade being chosen
    if ReplicatedStorage:GetAttribute("IsOpeningChest") or player:GetAttribute("IsOpeningChest") or ReplicatedStorage:GetAttribute("IsChoosingUpgrade") or player:GetAttribute("IsChoosingUpgrade") then
        return
    end

    local isCurrentlyManual = ReplicatedStorage:GetAttribute("IsManualPaused") == true
    local nextPauseState = not isCurrentlyManual
    
    ReplicatedStorage:SetAttribute("IsManualPaused", nextPauseState)
    ReplicatedStorage:SetAttribute("IsPaused", nextPauseState)
    setPlayersFrozen(nextPauseState)
    
    if nextPauseState then
        ShowMessageEvent:FireAllClients("GAME PAUSED", Color3.fromRGB(255, 200, 50))
    else
        ShowMessageEvent:FireAllClients("GAME RESUMED", Color3.fromRGB(50, 255, 50))
    end
end)

-- Shift invulnerability timers during pause
local playerPauseStartTime = nil
ReplicatedStorage:GetAttributeChangedSignal("IsPaused"):Connect(function()
    local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
    if isPaused then
        playerPauseStartTime = os.clock()
    else
        if playerPauseStartTime then
            local pauseDuration = os.clock() - playerPauseStartTime
            playerPauseStartTime = nil
            
            for _, data in pairs(PlayerData) do
                if data and data.InvulnerableUntil and data.InvulnerableUntil > 0 then
                    data.InvulnerableUntil = data.InvulnerableUntil + pauseDuration
                end
            end
        end
    end
end)

-- DİĞER SCRİPTLER İÇİN VERİ SAĞLAMA
GetPlayerDataEvent.OnInvoke = function(player)
    return PlayerData[player.UserId]
end

ClientGetPlayerData.OnServerInvoke = function(player)
    return PlayerData[player.UserId]
end

local triggerLevelUp -- İleride tanımlanacak

-- GELİŞTİRMEYİ UYGULA
ApplyUpgradeEvent.OnServerEvent:Connect(function(player, upgradeType, bonusValue, subKey)
    if not PlayersChoosing[player.UserId] then
        warn(player.Name .. " unauthorized upgrade attempt!")
        return
    end
    
    if upgradeType ~= "Skip" then
        local success, err = pcall(function()
            local data = PlayerData[player.UserId]
            local foundOffer = nil
            if data and data.ActiveOffers then
                for _, offer in ipairs(data.ActiveOffers) do
                    if offer.Key == upgradeType and (subKey == nil or offer.SubKey == subKey or offer.MilestoneKey == subKey) then
                        foundOffer = offer
                        break
                    end
                end
                if not foundOffer then
                    for _, offer in ipairs(data.ActiveOffers) do
                        if (subKey and (offer.SubKey == subKey or offer.MilestoneKey == subKey)) or (upgradeType == "TurretMilestone" and offer.IsMilestone) then
                            foundOffer = offer
                            break
                        end
                    end
                end
            end

            local isMilestoneUpgrade = (foundOffer and foundOffer.IsMilestone)
                or (upgradeType == "TurretMilestone")
                or (UpgradeConfig.TurretMilestones and UpgradeConfig.TurretMilestones[upgradeType] ~= nil)
                or (subKey and UpgradeConfig.TurretMilestones and UpgradeConfig.TurretMilestones[subKey] ~= nil)

            -- TARET DÖNÜM NOKTASI (MILESTONE / OVERCLOCK) SEÇİMİ
            if isMilestoneUpgrade then
                local mKey = (foundOffer and (foundOffer.SubKey or foundOffer.MilestoneKey))
                    or (UpgradeConfig.TurretMilestones and UpgradeConfig.TurretMilestones[subKey] and subKey)
                    or (UpgradeConfig.TurretMilestones and UpgradeConfig.TurretMilestones[upgradeType] and upgradeType)
                    or "MinigunTurret"
                local rName = (foundOffer and foundOffer.RarityName) or "Rare"
                local mDef = UpgradeConfig.TurretMilestones and UpgradeConfig.TurretMilestones[mKey]
                local stats = (foundOffer and foundOffer.MilestoneStats) or (mDef and mDef.Rarities and (mDef.Rarities[rName] or mDef.Rarities["Rare"]))

                if stats then
                    if stats.Damage then
                        data.TurretDamage = math.max(4, math.floor((data.TurretDamage or 16) * (1 + stats.Damage) + 0.5))
                    end
                    if stats.AtkSpd then
                        data.TurretAttackSpeedBonus = (data.TurretAttackSpeedBonus or 0) + stats.AtkSpd
                        data.TurretFireRate = math.max(0.18, 1.0 / (1.0 + data.TurretAttackSpeedBonus))
                    end
                    if stats.Range then
                        data.TurretRange = math.max(15, math.floor((data.TurretRange or 40) * (1 + stats.Range) + 0.5))
                    end
                    if stats.Duration then
                        data.TurretDuration = math.max(8, math.floor((data.TurretDuration or 25) * (1 + stats.Duration) + 0.5))
                    end
                    if stats.ScrapCost then
                        data.TurretCost = math.max(10, (data.TurretCost or 100) + stats.ScrapCost)
                        player:SetAttribute("TurretCost", data.TurretCost)
                        player:SetAttribute("TurretReady", (data.Scrap or 0) >= data.TurretCost)
                    end
                    if stats.ExtraShots then
                        data.TurretExtraShots = (data.TurretExtraShots or 0) + stats.ExtraShots
                    end
                end

                data.Upgrades[mKey] = (data.Upgrades[mKey] or 0) + 1
                data.MatchUpgrades = data.MatchUpgrades or {}
                table.insert(data.MatchUpgrades, "TurretWeapon")

                -- 3. YÖNTEM: En Yüksek Nadirlik Önceliği (Dominant Model)
                local RARITY_RANKS = {
                    Common = 1,
                    Uncommon = 2,
                    Rare = 3,
                    Epic = 4,
                    Legendary = 5,
                }
                data.TurretMilestoneHistory = data.TurretMilestoneHistory or {}
                table.insert(data.TurretMilestoneHistory, {
                    Archetype = mKey,
                    Rarity = rName,
                    Rank = RARITY_RANKS[rName] or 3,
                    PickOrder = #data.TurretMilestoneHistory + 1
                })

                -- En yüksek nadirlik seviyesine (Rank) sahip olan model seçilir.
                -- Eşitlik durumunda (örn. 2 tane Epic) en son seçilen (>=) baskın olur.
                local bestRank = -1
                local bestArchetype = nil
                local bestRarity = nil

                for _, entry in ipairs(data.TurretMilestoneHistory) do
                    if entry.Rank >= bestRank then
                        bestRank = entry.Rank
                        bestArchetype = entry.Archetype
                        bestRarity = entry.Rarity
                    end
                end

                data.TurretDominantArchetype = bestArchetype
                data.TurretDominantRarity = bestRarity
                player:SetAttribute("TurretDominantArchetype", bestArchetype or "")
                player:SetAttribute("TurretDominantRarity", bestRarity or "")
                print(string.format("[MilestoneApplied] %s chose %s (%s). DominantArchetype is now: %s",
                    player.Name, tostring(mKey), tostring(rName), tostring(bestArchetype)))

                -- Milestone tamamlandı: İlerleme kutucuklarını ve pending durumunu sıfırla
                data.TurretMilestoneProgress = 0
                data.TurretMilestonePending = false
                player:SetAttribute("TurretMilestoneProgress", 0)
                player:SetAttribute("TurretMilestonePending", false)
                return
            end

            local upgradeBase = UpgradeConfig.Upgrades[upgradeType]
            if not data or not upgradeBase or not bonusValue then return end
        
        -- Slot Kontrolü (Silah ve Perk ayrımı)
        local weaponCount = (data.HasBullet and 1 or 0) + (data.HasFireball and 1 or 0) + (data.HasFireTrail and 1 or 0) + (data.HasLightning and 1 or 0) + (data.HasSnowball and 1 or 0) + (data.HasSpikedArmor and 1 or 0) + (data.HasTurret and 1 or 0)

        local perkCount = 0
        for k in pairs(data.Upgrades) do
            local uType = UpgradeConfig.Upgrades[k] and UpgradeConfig.Upgrades[k].Type
            if uType == "Perk" then
                perkCount = perkCount + 1
            end
        end
        
        if not data.Upgrades[upgradeType] then
            if upgradeBase.Type == "Weapon" and weaponCount >= data.MaxWeaponSlots then
                warn("Weapon slots full!")
                return
            elseif upgradeBase.Type == "Perk" and perkCount >= data.MaxPerkSlots then
                warn("Perk slots full!")
                return
            end
        end
        
        data.Upgrades[upgradeType] = (data.Upgrades[upgradeType] or 0) + 1
        data.MatchUpgrades = data.MatchUpgrades or {}
        table.insert(data.MatchUpgrades, upgradeType)
        
        -- Karttan gelen saf bonus değerini biriktir
        data.UpgradeBonuses = data.UpgradeBonuses or {}
        local key = subKey or upgradeType
        data.UpgradeBonuses[key] = (data.UpgradeBonuses[key] or 0) + bonusValue
        
        -- Silah alt özelliklerini uygulayan yardımcı fonksiyon (Dual/Çift geliştirmeler için de kullanılır)
        local function applyWeaponSubStat(uType, sKey, bVal)
            if not uType or not bVal then return end
            data.UpgradeBonuses = data.UpgradeBonuses or {}
            local keyToStore = sKey or uType
            data.UpgradeBonuses[keyToStore] = (data.UpgradeBonuses[keyToStore] or 0) + bVal

            if uType == "FireballWeapon" then
                if not data.HasFireball then
                    data.HasFireball = true
                else
                    if sKey == "FireballDamage" then data.FireballDamage = data.FireballDamage + bVal
                    elseif sKey == "FireballRadius" then data.FireballRadius = data.FireballRadius + (2.5 * bVal)
                    elseif sKey == "FireballCount" then data.FireballCount = (data.FireballCount or 1) + bVal
                    elseif sKey == "FireballSpeed" then data.FireballSpeedMultiplier = (data.FireballSpeedMultiplier or 1.0) + bVal
                    elseif sKey == "FireballCritChance" then data.FireballCritChance = (data.FireballCritChance or 0) + bVal
                    elseif sKey == "FireballCritDamage" then data.FireballCritDamage = (data.FireballCritDamage or 0) + bVal end
                end
            elseif uType == "FireTrailWeapon" then
                if not data.HasFireTrail then
                    data.HasFireTrail = true
                else
                    if sKey == "FireTrailDamage" then data.FireTrailDamage = data.FireTrailDamage + bVal
                    elseif sKey == "FireTrailRadius" then data.FireTrailRadius = data.FireTrailRadius + (3 * bVal)
                    elseif sKey == "FireTrailCount" then 
                        data.FireTrailCount = (data.FireTrailCount or 1) + bVal
                        data.FireTrailDamage = (data.FireTrailDamage or 3.5) + (bVal * 1.5)
                    elseif sKey == "FireTrailDuration" then data.FireTrailDurationBonus = (data.FireTrailDurationBonus or 0) + bVal
                    elseif sKey == "FireTrailCritChance" then data.FireTrailCritChance = (data.FireTrailCritChance or 0) + bVal
                    elseif sKey == "FireTrailCritDamage" then data.FireTrailCritDamage = (data.FireTrailCritDamage or 0) + bVal end
                end
            elseif uType == "BulletWeapon" then
                if not data.HasBullet then
                    data.HasBullet = true
                else
                    if sKey == "BulletDamage" then data.BulletDamage = data.BulletDamage + bVal
                    elseif sKey == "BulletCount" then data.BulletCount = data.BulletCount + bVal
                    elseif sKey == "BulletSpeed" then data.BulletSpeedMultiplier = (data.BulletSpeedMultiplier or 1.0) + bVal
                    elseif sKey == "BulletCritChance" then data.BulletCritChance = (data.BulletCritChance or 0) + bVal
                    elseif sKey == "BulletCritDamage" then data.BulletCritDamage = (data.BulletCritDamage or 0) + bVal end
                end
            elseif uType == "LightningWeapon" then
                if not data.HasLightning then
                    data.HasLightning = true
                else
                    if sKey == "LightningDamage" then data.LightningDamage = data.LightningDamage + bVal
                    elseif sKey == "LightningCount" then data.LightningCount = (data.LightningCount or 1) + bVal
                    elseif sKey == "LightningBounces" then data.LightningBounces = (data.LightningBounces or 3) + bVal
                    elseif sKey == "LightningCritChance" then data.LightningCritChance = (data.LightningCritChance or 0) + bVal
                    elseif sKey == "LightningCritDamage" then data.LightningCritDamage = (data.LightningCritDamage or 0) + bVal
                    elseif sKey == "LightningRange" then data.LightningRangeMultiplier = (data.LightningRangeMultiplier or 1.0) + bVal end
                end
            elseif uType == "SnowballWeapon" then
                if not data.HasSnowball then
                    data.HasSnowball = true
                else
                    if sKey == "SnowballDamage" then data.SnowballDamage = data.SnowballDamage + bVal
                    elseif sKey == "SnowballCount" then data.SnowballCount = data.SnowballCount + bVal
                    elseif sKey == "SnowballSlowPct" then data.SnowballSlowPct = data.SnowballSlowPct + bVal
                    elseif sKey == "SnowballDuration" then data.SnowballDuration = data.SnowballDuration + bVal
                    elseif sKey == "SnowballSpeed" then data.SnowballSpeedMultiplier = (data.SnowballSpeedMultiplier or 1.0) + bVal
                    elseif sKey == "SnowballCritChance" then data.SnowballCritChance = (data.SnowballCritChance or 0) + bVal
                    elseif sKey == "SnowballCritDamage" then data.SnowballCritDamage = (data.SnowballCritDamage or 0) + bVal end
                end
            elseif uType == "SpikedArmorWeapon" then
                if not data.HasSpikedArmor then
                    data.HasSpikedArmor = true
                else
                    if sKey == "SpikedArmorDamage" then data.SpikedArmorDamage = data.SpikedArmorDamage + bVal
                    elseif sKey == "SpikedArmorCooldown" then data.SpikedArmorCooldownBonus = (data.SpikedArmorCooldownBonus or 0) + bVal
                    elseif sKey == "SpikedArmorKnockback" then data.SpikedArmorKnockback = data.SpikedArmorKnockback + bVal
                    elseif sKey == "SpikedArmorCritChance" then data.SpikedArmorCritChance = (data.SpikedArmorCritChance or 0) + bVal
                    elseif sKey == "SpikedArmorCritDamage" then data.SpikedArmorCritDamage = (data.SpikedArmorCritDamage or 0) + bVal
                    elseif sKey == "SpikedArmorRadius" then data.SpikedArmorRadiusMultiplier = (data.SpikedArmorRadiusMultiplier or 1.0) + bVal end
                end
            elseif uType == "TurretWeapon" then
                if not data.HasTurret then
                    data.HasTurret = true
                    player:SetAttribute("HasTurret", true)
                    if data.AttackSpeedBonus and data.AttackSpeedBonus > 0 then
                        data.TurretAttackSpeedBonus = (data.TurretAttackSpeedBonus or 0) + data.AttackSpeedBonus
                        data.TurretFireRate = math.max(0.15, 0.8 / (1.0 + data.TurretAttackSpeedBonus))
                    end
                else
                    if sKey == "TurretDamage" then
                        data.TurretDamage = (data.TurretDamage or 9) + bVal
                    elseif sKey == "TurretFireRate" then
                        data.TurretAttackSpeedBonus = (data.TurretAttackSpeedBonus or 0) + bVal
                        data.TurretFireRate = math.max(0.15, 0.8 / (1.0 + data.TurretAttackSpeedBonus))
                    elseif sKey == "TurretDuration" then
                        data.TurretDuration = (data.TurretDuration or 25) + bVal
                    elseif sKey == "TurretCostReduction" then
                        local currentCost = data.TurretCost or 100
                        local pct = (bVal > 1) and (bVal / 100) or (bVal or 0.10)
                        local reduction = math.max(5, math.floor(currentCost * pct + 0.5))
                        data.TurretCost = math.max(10, currentCost - reduction)
                        player:SetAttribute("TurretCost", data.TurretCost)
                        player:SetAttribute("TurretReady", (data.Scrap or 0) >= data.TurretCost)
                    elseif sKey == "TurretCount" then
                        data.TurretExtraShots = (data.TurretExtraShots or 0) + bVal
                    elseif sKey == "TurretCritChance" then
                        data.TurretCritChance = (data.TurretCritChance or 0) + bVal
                    elseif sKey == "TurretCritDamage" then
                        data.TurretCritDamage = (data.TurretCritDamage or 0) + bVal
                    elseif sKey == "TurretRange" then
                        data.TurretRange = (data.TurretRange or 40) + (40 * bVal)
                    end
                end
            end
        end

        -- İstatistikleri uygula
        if upgradeType == "Damage" then
            data.DamageMultiplier = data.DamageMultiplier + bonusValue
        elseif upgradeType == "Speed" then
            local speedIncrease = 17 * bonusValue
            data.SpeedBonus = (data.SpeedBonus or 0) + speedIncrease
            player:SetAttribute("SpeedBonus", data.SpeedBonus)
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                local baseSpeed = 17 + data.SpeedBonus
                player.Character.Humanoid.WalkSpeed = data.IsSprinting and (baseSpeed * 1.5) or baseSpeed
            end
        elseif upgradeType == "Magnet" then
            data.MagnetRangeMultiplier = data.MagnetRangeMultiplier + bonusValue
            local compassBoost = 1 + (data.Items and data.Items.compass or 0) * 0.15
            local effectiveMagnet = data.MagnetRangeMultiplier * compassBoost
            if player.Character then
                player.Character:SetAttribute("MagnetMultiplier", effectiveMagnet)
            end
        elseif upgradeType == "Vitality" then
            data.MaxHealth = data.MaxHealth + bonusValue
            data.Health = math.min(data.MaxHealth, data.Health + bonusValue) -- Sadece eklenen miktar kadar can ver
            UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.MaxHealth = data.MaxHealth
                player.Character.Humanoid.Health = data.Health
            end
            
            -- Progress Regeneration quest: "Upgrade Health 3 times."
            ProgressionManager.AddProgress(player, "Regeneration", 1)
        elseif upgradeType == "Regeneration" then
            data.HealthRegen = data.HealthRegen + bonusValue
            local bandageBoost = 1 + (data.Items and data.Items.bandage or 0) * 0.25
            local effectiveRegen = data.HealthRegen * bandageBoost
            ProgressionManager.UpdateProgress(player, "Lifesteal", effectiveRegen)
        elseif upgradeType == "FireballWeapon"
            or upgradeType == "FireTrailWeapon"
            or upgradeType == "BulletWeapon"
            or upgradeType == "LightningWeapon"
            or upgradeType == "SnowballWeapon"
            or upgradeType == "SpikedArmorWeapon"
            or upgradeType == "TurretWeapon" then
            
            applyWeaponSubStat(upgradeType, subKey, bonusValue)
            if foundOffer and foundOffer.IsDual and foundOffer.SubKey2 and foundOffer.Value2 then
                applyWeaponSubStat(upgradeType, foundOffer.SubKey2, foundOffer.Value2)
            end
        elseif upgradeType == "CritChance" then
            data.CritChance = data.CritChance + bonusValue
        elseif upgradeType == "CritMultiplier" then
            data.CritMultiplier = data.CritMultiplier + bonusValue
        elseif upgradeType == "Lifesteal" then
            data.Lifesteal = data.Lifesteal + bonusValue
        elseif upgradeType == "XPBoost" then
            data.XPBoost = data.XPBoost + bonusValue
        elseif upgradeType == "Luck" then
            data.LuckBonus = (data.LuckBonus or 0) + bonusValue
            player:SetAttribute("LuckBonus", data.LuckBonus)
        elseif upgradeType == "AreaSize" then
            data.AreaMultiplier = data.AreaMultiplier + bonusValue
        elseif upgradeType == "AttackSpeed" then
            data.AttackSpeedBonus = (data.AttackSpeedBonus or 0) + bonusValue
            local elfBonus = (data.SelectedClassId == "Elf") and 0.95 or 1.0
            data.RangedCooldownMultiplier = elfBonus / (1.0 + data.AttackSpeedBonus)
            data.AttackSpeedMultiplier = 1.0 + data.AttackSpeedBonus
            player:SetAttribute("AttackSpeedMultiplier", data.AttackSpeedMultiplier)
            
            -- Taret saldırı hızı bonusunu da senkronize et
            data.TurretAttackSpeedBonus = (data.TurretAttackSpeedBonus or 0) + bonusValue
            data.TurretFireRate = math.max(0.15, 0.8 / (1.0 + data.TurretAttackSpeedBonus))
        elseif upgradeType == "ProjectileCount" or upgradeType == "Volley" then
            -- Oyuncunun sahip olduğu menzilli silahları belirle
            local candidates = {}
            if data.HasBullet then table.insert(candidates, { Key = "Bullet", Display = "Bullet" }) end
            if data.HasFireball then table.insert(candidates, { Key = "Fireball", Display = "Fireball" }) end
            if data.HasLightning then table.insert(candidates, { Key = "Lightning", Display = "Lightning" }) end
            if data.HasSnowball then table.insert(candidates, { Key = "Snowball", Display = "Snowball" }) end
            if data.HasFireTrail then table.insert(candidates, { Key = "FireTrail", Display = "Fire Trail" }) end
            if data.HasTurret then table.insert(candidates, { Key = "Turret", Display = "Turret" }) end
            
            -- Eğer henüz hiçbir menzilli silahı yoksa tüm adaylar arasından seç
            if #candidates == 0 then
                candidates = {
                    { Key = "Bullet", Display = "Bullet" },
                    { Key = "Fireball", Display = "Fireball" },
                    { Key = "Lightning", Display = "Lightning" },
                    { Key = "Snowball", Display = "Snowball" },
                    { Key = "FireTrail", Display = "Fire Trail" },
                    { Key = "Turret", Display = "Turret" }
                }
            end
            
            -- Rastgele bir silah seç ve mermi/sayı bonusunu sadece ona ver (sekmeye ASLA verilmez)
            local chosen = candidates[math.random(1, #candidates)]
            if chosen.Key == "Bullet" then
                data.BulletCount = (data.BulletCount or 1) + bonusValue
                data.UpgradeBonuses["BulletCount"] = (data.UpgradeBonuses["BulletCount"] or 0) + bonusValue
            elseif chosen.Key == "Fireball" then
                data.FireballCount = (data.FireballCount or 1) + bonusValue
                data.UpgradeBonuses["FireballCount"] = (data.UpgradeBonuses["FireballCount"] or 0) + bonusValue
            elseif chosen.Key == "Lightning" then
                -- Lightning: Yalnızca sayıya (bolt count) verilir, sekme (bounces) artırılmaz
                data.LightningCount = (data.LightningCount or 1) + bonusValue
                data.UpgradeBonuses["LightningCount"] = (data.UpgradeBonuses["LightningCount"] or 0) + bonusValue
            elseif chosen.Key == "Snowball" then
                data.SnowballCount = (data.SnowballCount or 1) + bonusValue
                data.UpgradeBonuses["SnowballCount"] = (data.UpgradeBonuses["SnowballCount"] or 0) + bonusValue
            elseif chosen.Key == "FireTrail" then
                data.FireTrailCount = (data.FireTrailCount or 1) + bonusValue
                data.FireTrailDamage = (data.FireTrailDamage or 3.5) + (bonusValue * 1.5)
                data.UpgradeBonuses["FireTrailCount"] = (data.UpgradeBonuses["FireTrailCount"] or 0) + bonusValue
            elseif chosen.Key == "Turret" then
                data.TurretExtraShots = (data.TurretExtraShots or 0) + bonusValue
                data.UpgradeBonuses["TurretExtraShots"] = (data.UpgradeBonuses["TurretExtraShots"] or 0) + bonusValue
            end
            
            -- Genel ProjectileCount ve Volley senkronizasyonu
            data.ProjectileCountBonus = data.UpgradeBonuses["ProjectileCount"] or bonusValue
            data.UpgradeBonuses["Volley"] = data.ProjectileCountBonus
            
            local bonusStr = (math.abs(bonusValue - math.floor(bonusValue)) > 0.001) and string.format("+%.1f", bonusValue) or string.format("+%d", math.floor(bonusValue))
            ShowMessageEvent:FireClient(player, string.format("%s Projectile -> %s!", bonusStr, chosen.Display), Color3.fromRGB(80, 200, 255))
        end

        -- Engineer ve Taret için Milestone (Dönüm Noktası) İlerlemesi: Her upgrade seçiminde +1 kutu dolar
        if data.HasTurret then
            data.TurretMilestoneProgress = (data.TurretMilestoneProgress or 0) + 1
            if data.TurretMilestoneProgress >= 5 then
                data.TurretMilestoneProgress = 5
                data.TurretMilestonePending = true
            else
                data.TurretMilestonePending = false
            end
            player:SetAttribute("TurretMilestoneProgress", data.TurretMilestoneProgress)
            player:SetAttribute("TurretMilestonePending", data.TurretMilestonePending)
        end
        
    end)
    
        if not success then
            warn("ApplyUpgrade Error: " .. tostring(err))
        end
    end
    
    PlayerUpgradedEvent:Fire(player)
    
    local data = PlayerData[player.UserId]
    if data and data.PendingLevelUps and data.PendingLevelUps > 0 then
        -- Eğer sırada bekleyen başka bir level atlama işlemi varsa hemen onu başlat
        triggerLevelUp(player, data)
        return
    end
    
    -- Temizlik ve Oyunu Devam Ettirme (Mutlaka Çalışmalı)
    if data then
        data.ActiveOffers = nil
    end
    PlayersChoosing[player.UserId] = nil
    player:SetAttribute("IsChoosingUpgrade", false)
    
    local remaining = 0
    for _ in pairs(PlayersChoosing) do remaining = remaining + 1 end
    
    if remaining == 0 then
        if not ReplicatedStorage:GetAttribute("IsOpeningChest") and not ReplicatedStorage:GetAttribute("IsManualPaused") then
            ReplicatedStorage:SetAttribute("IsPaused", false)
            setPlayersFrozen(false)
        end
    else
        ShowMessageEvent:FireClient(player, "Diğer oyuncunun kart seçmesi bekleniyor...", Color3.fromRGB(255, 200, 100))
    end
end)

local function checkAllReady()
    local players = Players:GetPlayers()
    if #players == 0 then return end
    
    local allReady = true
    for _, player in ipairs(players) do
        if not ReadyPlayers[player.UserId] then
            allReady = false
            break
        end
    end
    
    if allReady then
        for _, p in ipairs(Players:GetPlayers()) do
            local data = PlayerData[p.UserId]
            if data then
                data.DefeatedEnemies = {}
                data.WeaponDamage = {}
                local startingUpgrades = {}
                if data.HasBullet then table.insert(startingUpgrades, "BulletWeapon") end
                if data.HasTurret then table.insert(startingUpgrades, "TurretWeapon") end
                data.MatchUpgrades = startingUpgrades
                data.Coins = 0
                data.ChestsOpened = 0
                data.ChestOpenCost = 30
                local talentWeaponSlots = math.clamp(p:GetAttribute("Talent_WeaponSlots") or 0, 0, 2)
                local talentPerkSlots = math.clamp(p:GetAttribute("Talent_PerkSlots") or 0, 0, 2)
                local talentFreeRerolls = math.clamp(p:GetAttribute("Talent_FreeRerolls") or 0, 0, 3)
                data.MaxWeaponSlots = 2 + talentWeaponSlots
                data.MaxPerkSlots = 2 + talentPerkSlots
                data.FreeRerolls = talentFreeRerolls
                data.RerollCost = 50
                data.Items = {
                    dagger = 0,
                    bandage = 0,
                    fire_tome = 0,
                    bow = 0,
                    xp_tome = 0,
                    clover = 0,
                    sniper = 0,
                    piggy_bank = 0,
                    compass = 0,
                    iron_plating = 0,
                    blood_blade = 0,
                }
                data.TurretMilestoneProgress = 0
                data.TurretMilestonePending = false
                data.TurretMilestoneHistory = {}
                data.TurretDominantArchetype = nil
                data.TurretDominantRarity = nil
                p:SetAttribute("TurretMilestoneProgress", 0)
                p:SetAttribute("TurretMilestonePending", false)
                p:SetAttribute("TurretDominantArchetype", "")
                p:SetAttribute("TurretDominantRarity", "")
                p:SetAttribute("MatchPotsBroken", 0)
                p:SetAttribute("MatchCritHits", 0)
            end
        end
        isEndingMatch = false
        ReplicatedStorage:SetAttribute("GameStarted", true)
        ReplicatedStorage:SetAttribute("CameraIntroActive", true)
        
        -- Oyun başlamadan önce tüm oyuncuların zemin üzerinde doğru konumda olmasını garanti et
        local spawnPos = ReplicatedStorage:GetAttribute("SpawnPosition")
        local finalGroundY = spawnPos and spawnPos.Y or 0
        if spawnPos then
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Include
            local pMap = workspace:FindFirstChild("ProceduralMap")
            if pMap then rayParams.FilterDescendantsInstances = { pMap } end
            local hit = workspace:Raycast(Vector3.new(spawnPos.X, spawnPos.Y + 40, spawnPos.Z), Vector3.new(0, -80, 0), rayParams)
            if hit then finalGroundY = hit.Position.Y end
        end

        for _, p in ipairs(Players:GetPlayers()) do
            local pChar = p.Character
            if pChar then
                local hum = pChar:FindFirstChild("Humanoid")
                local hrp = pChar:FindFirstChild("HumanoidRootPart")
                if hum then
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                    hum.JumpHeight = 0
                    hum.AutoRotate = false
                end
                if hrp and spawnPos then
                    local hipHeight = (hum and hum.HipHeight > 0) and hum.HipHeight or 2.0
                    local rootOffset = hipHeight + (hrp.Size.Y / 2)
                    hrp.CFrame = CFrame.new(spawnPos.X, finalGroundY + rootOffset, spawnPos.Z)
                    hrp.Anchored = false
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Landed)
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end
        end

        -- Kamera geçiş animasyonu süresince (1.8 saniye) oyuncuları kilitli tut, ardından başlat
        task.delay(1.85, function()
            ReplicatedStorage:SetAttribute("CameraIntroActive", false)
            for _, p in ipairs(Players:GetPlayers()) do
                local pData = PlayerData[p.UserId]
                local pChar = p.Character
                if pChar then
                    local hum = pChar:FindFirstChild("Humanoid")
                    local hrp = pChar:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.Anchored = false end
                    if hum and pData then
                        hum.WalkSpeed = 17 + (pData.SpeedBonus or 0)
                        hum.JumpPower = 50
                        hum.JumpHeight = 7.2
                        hum.AutoRotate = true
                    end
                end
            end
        end)
        
        StartGameEvent:FireAllClients()
    end
end

PlayerReadyEvent.OnServerEvent:Connect(function(player)
    ReadyPlayers[player.UserId] = true
    -- Hazır veren oyuncuyu diğerleri de hazır olana kadar kilitli tut
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then
            hum.AutoRotate = false
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum.JumpHeight = 0
            hum:ChangeState(Enum.HumanoidStateType.Landed)
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
        if hrp then
            hrp.Anchored = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
    checkAllReady()
end)

local EndMatchBindable = Events:FindFirstChild("EndMatch") or Instance.new("BindableEvent")
EndMatchBindable.Name = "EndMatch"
EndMatchBindable.Parent = Events

local function saveLeaderboardScore(player)
    if not player then return 0, 0 end
    local data = PlayerData[player.UserId]
    if not data then return 0, 0 end
    
    local totalKills = 0
    if data.DefeatedEnemies then
        for _, count in pairs(data.DefeatedEnemies) do
            totalKills = totalKills + (tonumber(count) or 0)
        end
    end
    totalKills = math.max(totalKills, data.TotalKills or 0)
    local totalGold = math.max(data.TotalCoins or 0, data.Coins or 0)
    
    -- Player attribute'larını güncelle
    player:SetAttribute("Coins", totalGold)
    player:SetAttribute("Gold", totalGold)
    player:SetAttribute("TotalCoins", totalGold)
    player:SetAttribute("TotalGold", totalGold)
    player:SetAttribute("Kills", totalKills)
    player:SetAttribute("TotalKills", totalKills)
    
    local uId = player.UserId
    local totalSilver = player:GetAttribute("Silver") or 0
    if uId and uId > 0 then
        task.spawn(function()
            if totalSilver > 0 then
                pcall(function()
                    DS_Silver:UpdateAsync(tostring(uId), function(oldVal)
                        return math.max(oldVal or 0, math.floor(totalSilver))
                    end)
                end)
            end
            if totalGold > 0 then
                pcall(function()
                    DS_Coins:UpdateAsync(tostring(uId), function(oldVal)
                        return math.max(oldVal or 0, math.floor(totalGold))
                    end)
                end)
            end
            if totalKills > 0 then
                pcall(function()
                    DS_Kills:UpdateAsync(tostring(uId), function(oldVal)
                        return math.max(oldVal or 0, math.floor(totalKills))
                    end)
                end)
            end
        end)
    end
    
    return totalGold, totalKills
end

local function endGame(isVictory)
    if isEndingMatch then return end
    if ReplicatedStorage:GetAttribute("GameStarted") == false then return end
    isEndingMatch = true
    
    -- Stop the game loop and timer
    ReplicatedStorage:SetAttribute("GameStarted", false)
    ReplicatedStorage:SetAttribute("CameraIntroActive", false)
    
    -- Clear all enemies from the map
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        enemies:ClearAllChildren()
    end
    
    if isVictory then
        ShowMessageEvent:FireAllClients("SURVIVED! YOU WON THE RUN!", Color3.fromRGB(50, 255, 100))
    end
    
    task.delay(isVictory and 1.5 or 0.2, function()
        local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))
        local gameTimeVal = ReplicatedStorage:FindFirstChild("GameTime")
        local matchDuration = Config.Game and Config.Game.MatchDuration or 600
        local totalSeconds = math.clamp(gameTimeVal and gameTimeVal.Value or 0, 0, matchDuration)

        for _, player in ipairs(Players:GetPlayers()) do
            saveLeaderboardScore(player)
            local data = PlayerData[player.UserId]
            if data then
                local killsCount = 0
                if data.DefeatedEnemies then
                    for _, count in pairs(data.DefeatedEnemies) do
                        killsCount = killsCount + (tonumber(count) or 0)
                    end
                end
                
                local matchGold = data.Coins or 0
                local killsPerSilver = (Config.Currency and Config.Currency.KillsPerSilver) or 100
                local timePerSilver = (Config.Currency and Config.Currency.MinSurviveSecondsPerSilver) or 120
                local victoryBonus = (Config.Currency and Config.Currency.VictoryBonusSilver) or 10

                local killsSilver = math.floor(killsCount / killsPerSilver)
                local timeSilver = math.floor(totalSeconds / timePerSilver)
                local victorySilver = isVictory and victoryBonus or 0

                local baseSilver = killsSilver + timeSilver + victorySilver
                local DifficultyConfig = require(ReplicatedStorage.Shared.DifficultyConfig)
                local currentDiff = workspace:GetAttribute("Difficulty") or "Easy"
                local diffData = DifficultyConfig.Get(currentDiff)
                local rewardMult = diffData.RewardMult or 1.0

                local earnedSilver = math.floor(baseSilver * rewardMult)
                if earnedSilver < 1 and (killsCount > 0 or totalSeconds >= 30) then
                    earnedSilver = 1
                end

                local newTotalSilver = ProgressionManager.AddSilver(player, earnedSilver)
                local matchSilverCollected = data.MatchSilver or 0

                -- Zorluk Seviyesi Kilit Açma: Easy kazanılırsa Normal, Normal kazanılırsa Hard açılır
                local newDifficultyUnlocked = nil
                local mapId = workspace:GetAttribute("MapId") or "Forest"
                if isVictory then
                    local diffLower = string.lower(tostring(currentDiff))
                    if diffLower == "easy" or diffLower == "tier 1" or diffLower == "1" then
                        if not ProgressionManager.IsDifficultyUnlocked(player, "Medium") then
                            ProgressionManager.UnlockDifficulty(player, "Medium")
                            newDifficultyUnlocked = "NORMAL"
                        end
                    elseif diffLower == "medium" or diffLower == "normal" or diffLower == "tier 2" or diffLower == "2" then
                        if not ProgressionManager.IsDifficultyUnlocked(player, "Hard") then
                            ProgressionManager.UnlockDifficulty(player, "Hard")
                            newDifficultyUnlocked = "HARD"
                        end
                    end
                end

                if newDifficultyUnlocked then
                    player:SetAttribute("NewlyUnlockedDifficulty", newDifficultyUnlocked)
                    player:SetAttribute("NewlyUnlockedMap", mapId)
                    ShowMessageEvent:FireClient(player, "NEW DIFFICULTY UNLOCKED: " .. newDifficultyUnlocked .. "!", Color3.fromRGB(255, 215, 60))
                end

                local stats = {
                    DefeatedEnemies = data.DefeatedEnemies or {},
                    WeaponDamage = data.WeaponDamage or {},
                    MatchUpgrades = data.MatchUpgrades or {},
                    Gold = matchGold,
                    Items = data.Items or {},
                    IsVictory = isVictory or false,
                    EarnedSilver = earnedSilver + matchSilverCollected,
                    TotalSilver = newTotalSilver,
                    Difficulty = currentDiff,
                    RewardMult = rewardMult,
                    NewDifficultyUnlocked = newDifficultyUnlocked,
                    MapId = mapId
                }
                ShowGameOverEvent:FireClient(player, stats)
            end
        end
        isEndingMatch = false
    end)
end

EndMatchBindable.Event:Connect(function(isVictory)
    endGame(isVictory == true)
end)

local function checkAllDowned()
    local players = Players:GetPlayers()
    if #players == 0 then return end
    
    local allDowned = true
    for _, player in ipairs(players) do
        local data = PlayerData[player.UserId]
        if data and data.Health > 0 then
            allDowned = false
            break
        end
    end
    
    if allDowned then
        endGame(false)
    end
end

local function applyTalentsToPlayerData(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    local talentWeaponSlots = math.clamp(player:GetAttribute("Talent_WeaponSlots") or 0, 0, 2)
    local talentPerkSlots = math.clamp(player:GetAttribute("Talent_PerkSlots") or 0, 0, 2)
    local talentFreeRerolls = math.clamp(player:GetAttribute("Talent_FreeRerolls") or 0, 0, 3)
    local talentHealth = (player:GetAttribute("Talent_Health") or 0) * 0.05
    local talentDamage = (player:GetAttribute("Talent_Damage") or 0) * 0.05
    local talentSpeed = (player:GetAttribute("Talent_Speed") or 0) * 0.03
    local talentMagnet = (player:GetAttribute("Talent_Magnet") or 0) * 0.05

    local selectedClassId = data.SelectedClassId or "Human"
    local selectedClassData = nil
    for _, c in ipairs(CharacterUIConfig.Characters) do
        if c.Id == selectedClassId then selectedClassData = c; break end
    end
    local function parseMult(val)
        if type(val) == "string" then return tonumber((val:gsub("x", ""))) or 1 end
        return 1
    end
    local hMult, sMult, dMult = 1, 1, 1
    if selectedClassData then
        for _, stat in ipairs(selectedClassData.Stats) do
            if stat.Name == "Health" then hMult = parseMult(stat.Value)
            elseif stat.Name == "Speed" then sMult = parseMult(stat.Value)
            elseif stat.Name == "Damage" then dMult = parseMult(stat.Value) end
        end
    end

    local baseMaxHP = math.floor(100 * hMult * (1 + talentHealth))
    local hpDiff = baseMaxHP - data.MaxHealth
    if hpDiff ~= 0 then
        data.MaxHealth = baseMaxHP
        data.Health = math.clamp(data.Health + hpDiff, 1, baseMaxHP)
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.MaxHealth = data.MaxHealth
            player.Character.Humanoid.Health = data.Health
        end
        UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
    end
    
    data.DamageMultiplier = 1.0 * dMult * (1 + talentDamage)
    data.SpeedBonus = math.floor(17 * (sMult - 1 + talentSpeed))
    data.MagnetRangeMultiplier = 1.0 * (1 + talentMagnet)
    data.MaxWeaponSlots = 2 + talentWeaponSlots
    data.MaxPerkSlots = 2 + talentPerkSlots
    data.FreeRerolls = talentFreeRerolls
end

local function initializePlayer(player)
    -- Kalıcı Geliştirmelerin (Progression / Talents) DataStore'dan yüklenmesini bekle (en fazla 2.5 saniye)
    if not player:GetAttribute("ProgressionLoaded") then
        local waited = 0
        while not player:GetAttribute("ProgressionLoaded") and waited < 2.5 and player.Parent do
            task.wait(0.05)
            waited = waited + 0.05
        end
    end

    -- Kamera Uzaklaştırma Kısıtlaması
    player.CameraMinZoomDistance = Config.Game.CameraMinZoomDistance or 5
    player.CameraMaxZoomDistance = Config.Game.CameraMaxZoomDistance or 35

    -- Leaderstats oluştur (Sadece bir kere)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    local levelVal = Instance.new("IntValue")
    levelVal.Name = "Level"
    levelVal.Value = 1
    levelVal.Parent = leaderstats

    -- Sınıf Verilerini Al (TeleportData'dan veya Varsayılan)
    local joinData = player:GetJoinData()
    local teleportData = joinData and joinData.TeleportData
    local isFromLobby = (teleportData and teleportData.PlayerClasses) and true or false

    -- Zorluk ve Harita Bilgisini Global Olarak Ata
    if teleportData and teleportData.Difficulty then
        if not workspace:GetAttribute("Difficulty") then
            workspace:SetAttribute("Difficulty", teleportData.Difficulty)
            print("[GameServer] Lobi Seçimi - Zorluk: " .. tostring(teleportData.Difficulty))
        end
    elseif not workspace:GetAttribute("Difficulty") then
        workspace:SetAttribute("Difficulty", "Easy")
    end

    if teleportData and teleportData.MapId then
        if not workspace:GetAttribute("MapId") then
            workspace:SetAttribute("MapId", teleportData.MapId)
            print("[GameServer] Lobi Seçimi - Harita: " .. tostring(teleportData.MapId))
        end
    elseif not workspace:GetAttribute("MapId") then
        workspace:SetAttribute("MapId", "Forest")
    end
    
    -- Eğer oyuncu lobiden ışınlanarak gelmediyse (örn: Roblox profilinden doğrudan arkadaşına katıldıysa)
    -- ve canlı oyundaysak, aktif maça girmesin, otomatik olarak Lobiye aktarılsın!
    -- KRİTİK GÜVENLİK: Eğer oyun yanlışlıkla Lobi yerinde (game.PlaceId == lobbyPlaceId) çalışıyorsa,
    -- ASLA tekrar lobiye ışınlama yapma! Aksi halde oyuncu sunucular arası sonsuz ışınlanma (server-hopping loop) döngüsüne girer!
    if not isFromLobby and not RunService:IsStudio() then
        local lobbyPlaceId = Config.Game.LobbyPlaceId or 0
        if lobbyPlaceId > 0 and game.PlaceId ~= lobbyPlaceId then
            task.spawn(function()
                warn(player.Name .. " oyuna doğrudan katıldı (arkadaşına katılarak). Lobiye aktarılıyor...")
                local success, err = pcall(function()
                    TeleportService:TeleportAsync(lobbyPlaceId, {player})
                end)
                if not success then
                    warn("Lobiye aktarılamadı: ", err)
                    player:Kick("Doğrudan katılım desteklenmiyor. Lütfen oyuna Lobi üzerinden giriş yapın.")
                end
            end)
            return
        elseif game.PlaceId == lobbyPlaceId then
            warn("[GameServer] DİKKAT: Bölüm 1 (Oyun) kodları Lobi PlaceId'sinde (" .. tostring(game.PlaceId) .. ") çalışıyor! Sonsuz sunucu değiştirme döngüsünü önlemek için lobiye ışınlama engellendi.")
        end
    end
    
    local selectedClassId = teleportData and teleportData.PlayerClasses and teleportData.PlayerClasses[tostring(player.UserId)] or "Human"
    
    local selectedClassData = nil
    for _, c in ipairs(CharacterUIConfig.Characters) do
        if c.Id == selectedClassId then
            selectedClassData = c
            break
        end
    end
    
    if not selectedClassData then
        selectedClassData = CharacterUIConfig.Characters[1] -- Fallback
    end

    player:SetAttribute("SelectedClass", selectedClassData.Name)
    player:SetAttribute("SelectedClassId", selectedClassData.Id)
    player:SetAttribute("ClassColor", selectedClassData.Color)
    player:SetAttribute("HasTurret", (selectedClassId == "Engineer"))
    player:SetAttribute("TurretMilestoneProgress", 0)
    player:SetAttribute("TurretMilestonePending", false)

    -- Multiplier'ları parse et
    local function parseMult(val)
        if type(val) == "string" then
            return tonumber((val:gsub("x", ""))) or 1
        end
        return 1
    end

    local hMult, sMult, dMult = 1, 1, 1
    for _, stat in ipairs(selectedClassData.Stats) do
        if stat.Name == "Health" then hMult = parseMult(stat.Value)
        elseif stat.Name == "Speed" then sMult = parseMult(stat.Value)
        elseif stat.Name == "Damage" then dMult = parseMult(stat.Value) end
    end

    local startingLevel = 1
    local startingXP = 0
    local startingMaxXP = Config.GetXPRequirement(1)
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and PlayerData[otherPlayer.UserId] then
            local otherData = PlayerData[otherPlayer.UserId]
            if otherData.Level > startingLevel then
                startingLevel = otherData.Level
                startingXP = otherData.XP
                startingMaxXP = otherData.MaxXP
            end
        end
    end

    local talentWeaponSlots = math.clamp(player:GetAttribute("Talent_WeaponSlots") or 0, 0, 2)
    local talentPerkSlots = math.clamp(player:GetAttribute("Talent_PerkSlots") or 0, 0, 2)
    local talentFreeRerolls = math.clamp(player:GetAttribute("Talent_FreeRerolls") or 0, 0, 3)
    local talentHealth = (player:GetAttribute("Talent_Health") or 0) * 0.05
    local talentDamage = (player:GetAttribute("Talent_Damage") or 0) * 0.05
    local talentSpeed = (player:GetAttribute("Talent_Speed") or 0) * 0.03
    local talentMagnet = (player:GetAttribute("Talent_Magnet") or 0) * 0.05

    local baseMaxHP = math.floor(100 * hMult * (1 + talentHealth))
    local baseDamageMult = 1.0 * dMult * (1 + talentDamage)
    local baseSpeedBonus = math.floor(17 * (sMult - 1 + talentSpeed))
    local baseMagnet = 1.0 * (1 + talentMagnet)

    PlayerData[player.UserId] = {
        SelectedClassId = selectedClassId, -- Sınıf ID'sini sakla
        Level = startingLevel,
        XP = startingXP,
        MaxXP = startingMaxXP,
        PendingLevelUps = (startingLevel > 1) and (startingLevel - 1) or 0,
        MatchSilver = 0,
        Weapons = {},
        Health = baseMaxHP,
        MaxHealth = baseMaxHP,
        HealthRegen = 0,
        IsDowned = false,
        Upgrades = {
            BulletWeapon = (selectedClassId == "Knight") and 0 or 1, -- Knight Bullet ile başlamasın
            TurretWeapon = (selectedClassId == "Engineer") and 1 or 0, -- Engineer Turret ile başlasın
        },
        DamageMultiplier = baseDamageMult,
        SpeedBonus = baseSpeedBonus,
        MagnetRangeMultiplier = baseMagnet,
        
        -- Sınıf Pasifleri / Bonusları
        FireDamageMultiplier = (selectedClassId == "FireMage") and 1.2 or 1.0,
        RangedCooldownMultiplier = (selectedClassId == "Elf") and 0.95 or 1.0,
        
        HasBullet = (selectedClassId ~= "Knight"),
        BulletDamage = 4.5,
        BulletCount = 1,
        BulletSpeedMultiplier = 1.0,
        BulletCritChance = 0,
        BulletCritDamage = 0,

        -- Engineer Özel Silahı ve Taret Verileri
        HasTurret = (selectedClassId == "Engineer"),
        Scrap = 0,
        TurretDamage = 9,
        TurretFireRate = 0.8,
        TurretRange = 40,
        TurretDuration = 25,
        TurretCost = 100,
        TurretMaxCount = 1,
        TurretExtraShots = 0,
        TurretCritChance = 0,
        TurretCritDamage = 0,
        TurretMilestoneProgress = 0,
        TurretMilestonePending = false,
        TurretMilestoneHistory = {},
        TurretDominantArchetype = nil,
        TurretDominantRarity = nil,
        
        HasFireball = false,
        FireballDamage = 6.5,
        FireballRadius = 3, -- Yarıya indirildi (6 -> 3)
        FireballCount = 1,
        FireballSpeedMultiplier = 1.0,
        FireballCritChance = 0,
        FireballCritDamage = 0,

        HasFireTrail = false,
        FireTrailDamage = 3.5,
        FireTrailRadius = 3.5,
        FireTrailCount = 1,
        FireTrailDurationBonus = 0,
        FireTrailCritChance = 0,
        FireTrailCritDamage = 0,

        CritChance = 0.10,
        CritMultiplier = 1.5,
        
        Lifesteal = 0,
        XPBoost = 0,
        AreaMultiplier = 1.0,
        LuckBonus = 0,
        
        HasLightning = false,
        LightningDamage = 4.5,
        LightningCount = 1,
        LightningBounces = 3,
        LightningCritChance = 0,
        LightningCritDamage = 0,
        LightningRangeMultiplier = 1.0,
        
        HasSnowball = false,
        SnowballDamage = 2.8,
        SnowballCount = 1,
        SnowballSlowPct = 0.20,
        SnowballDuration = 3.0,
        SnowballSpeedMultiplier = 1.0,
        SnowballCritChance = 0,
        SnowballCritDamage = 0,
        
        HasSpikedArmor = false,
        SpikedArmorDamage = 7,
        SpikedArmorCooldownBonus = 0,
        SpikedArmorKnockback = 4.0,
        SpikedArmorCritChance = 0,
        SpikedArmorCritDamage = 0,
        SpikedArmorRadiusMultiplier = 1.0,
        LastSpikedArmorTime = 0,
        
        Coins = 0,
        RerollCost = 50,
        FreeRerolls = talentFreeRerolls,
        MaxWeaponSlots = 2 + talentWeaponSlots,
        MaxPerkSlots = 2 + talentPerkSlots,
        DefeatedEnemies = {},
        WeaponDamage = {},
        MatchUpgrades = (selectedClassId == "Engineer") and {"BulletWeapon", "TurretWeapon"} 
            or ((selectedClassId ~= "Knight") and {"BulletWeapon"} or {}),
        Items = {
            dagger = 0,
            bandage = 0,
            fire_tome = 0,
            bow = 0,
            xp_tome = 0,
            clover = 0,
            sniper = 0,
            piggy_bank = 0,
            compass = 0,
            iron_plating = 0,
            blood_blade = 0,
        },
        ChestsOpened = 0,
        ChestOpenCost = 30,
        UpgradeBonuses = {},
    }

    player:SetAttribute("MagnetMultiplier", baseMagnet)
    player:SetAttribute("SpeedBonus", baseSpeedBonus)
    player:SetAttribute("DamageMultiplier", baseDamageMult)
    player:SetAttribute("CritChance", 0.10)
    player:SetAttribute("CritMultiplier", 1.5)
    player:SetAttribute("AreaMultiplier", 1.0)
    player:SetAttribute("HealthRegen", 0)
    player:SetAttribute("AttackSpeedMultiplier", 1.0)
    player:SetAttribute("SelectedClassId", selectedClassId)
    player:SetAttribute("HasTurret", selectedClassId == "Engineer")
    player:SetAttribute("Scrap", 0)
    player:SetAttribute("TurretCost", 100)
    player:SetAttribute("TurretReady", false)
    player:SetAttribute("TurretDominantArchetype", "")
    player:SetAttribute("TurretDominantRarity", "")
    player:SetAttribute("AimAssistEnabled", true)
    player:SetAttribute("AimAssistStrength", 60)
    player:SetAttribute("SmartAimEnabled", true)
    
    player:GetAttributeChangedSignal("ProgressionLoaded"):Connect(function()
        applyTalentsToPlayerData(player)
    end)
    
    UpdateHealthEvent:FireClient(player, PlayerData[player.UserId].Health, PlayerData[player.UserId].MaxHealth)
    UpdateXPEvent:FireClient(player, 0, Config.GetXPRequirement(1), 1)
    
    player.Chatted:Connect(function(msg)
        -- Admin Kontrolü (Studio Testi veya Oyun Sahibi / CreatorId / Grup Yetkilisi)
        local isAdmin = RunService:IsStudio() 
            or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
            or (game.CreatorType == Enum.CreatorType.Group and pcall(function() return player:GetRankInGroup(game.CreatorId) end) and player:GetRankInGroup(game.CreatorId) >= 250)
            or (game.CreatorId > 0 and player.UserId == game.CreatorId)
        if not isAdmin then return end
        
        local lowerMsg = string.lower(msg)
        local args = string.split(lowerMsg, " ")
        local command = args[1]
        
        if command == "/dummy" then
            spawnTestDummy(player)
        elseif command == "/level" then
            local data = PlayerData[player.UserId]
            if data then
                local count = tonumber(args[2]) or 1
                ReplicatedStorage:SetAttribute("IsPaused", false)
                setPlayersFrozen(false)
                
                for _ = 1, count do
                    local neededXP = math.max(1, (data.MaxXP or 100) - (data.XP or 0))
                    if addXPToAll then
                        addXPToAll(neededXP)
                    end
                end
            end
        elseif command == "/upgrade" then
            local forcedRarity = nil
            local forcedUpgradeKey = nil
            
            local query = ""
            if #args > 1 then
                query = string.lower(table.concat(args, " ", 2))
            end
            
            -- 1. Nadirlik Anahtar Kelimeleri
            if string.find(query, "legendary") or string.find(query, "legendry") or string.find(query, "efsane") then
                forcedRarity = "Legendary"
            elseif string.find(query, "epic") or string.find(query, "destan") then
                forcedRarity = "Epic"
            elseif string.find(query, "rare") or string.find(query, "nadir") then
                forcedRarity = "Rare"
            elseif string.find(query, "uncommon") or string.find(query, "siradan") or string.find(query, "sıradan") then
                forcedRarity = "Uncommon"
            elseif string.find(query, "common") or string.find(query, "yaygin") or string.find(query, "yaygın") then
                forcedRarity = "Common"
            end
            
            -- 2. Silah ve Kart İsimleri
            if string.find(query, "spik") or string.find(query, "thorn") or string.find(query, "diken") or string.find(query, "armor") or string.find(query, "zırh") or string.find(query, "zirh") then
                forcedUpgradeKey = "SpikedArmorWeapon"
            elseif string.find(query, "fireball") or string.find(query, "ates top") or string.find(query, "ateş top") then
                forcedUpgradeKey = "FireballWeapon"
            elseif string.find(query, "trail") or string.find(query, "firetrail") or string.find(query, "ates iz") or string.find(query, "ateş iz") then
                forcedUpgradeKey = "FireTrailWeapon"
            elseif string.find(query, "bullet") or string.find(query, "mermi") then
                forcedUpgradeKey = "BulletWeapon"
            elseif string.find(query, "light") or string.find(query, "yildirim") or string.find(query, "yıldırım") or string.find(query, "simsek") or string.find(query, "şimşek") then
                forcedUpgradeKey = "LightningWeapon"
            elseif string.find(query, "snow") or string.find(query, "kar") then
                forcedUpgradeKey = "SnowballWeapon"
            elseif string.find(query, "crit") or string.find(query, "kritik") then
                forcedUpgradeKey = "CritChance"
            elseif string.find(query, "vamp") or string.find(query, "lifesteal") or string.find(query, "can calma") or string.find(query, "can çalma") then
                forcedUpgradeKey = "Lifesteal"
            elseif string.find(query, "speed") or string.find(query, "hiz") or string.find(query, "hız") or string.find(query, "agil") then
                forcedUpgradeKey = "Speed"
            elseif string.find(query, "damage") or string.find(query, "hasar") or string.find(query, "power") or string.find(query, "guc") or string.find(query, "güç") then
                forcedUpgradeKey = "Damage"
            elseif string.find(query, "vital") or string.find(query, "can") or string.find(query, "hp") or string.find(query, "health") then
                forcedUpgradeKey = "Vitality"
            elseif string.find(query, "regen") or string.find(query, "yenilen") then
                forcedUpgradeKey = "Regeneration"
            elseif string.find(query, "magnet") or string.find(query, "miknatis") or string.find(query, "mıknatıs") then
                forcedUpgradeKey = "Magnet"
            elseif string.find(query, "xp") or string.find(query, "scholar") or string.find(query, "bilgin") then
                forcedUpgradeKey = "XPBoost"
            elseif string.find(query, "area") or string.find(query, "alan") or string.find(query, "expans") or string.find(query, "radius") or string.find(query, "size") or string.find(query, "cap") or string.find(query, "çap") then
                forcedUpgradeKey = "AreaSize"
            end
            
            local data = PlayerData[player.UserId]
            if data then
                data.PendingLevelUps = (data.PendingLevelUps or 0) + 1
                triggerLevelUp(player, data, forcedRarity, forcedUpgradeKey)
            end
        elseif string.sub(lowerMsg, 1, 5) == "/gold" or string.sub(lowerMsg, 1, 6) == "/coins" then
            local args = string.split(msg, " ")
            local amount = tonumber(args[2]) or 100
            local data = PlayerData[player.UserId]
            if data then
                data.Coins = (data.Coins or 0) + amount
            end
        elseif lowerMsg == "/heal" then
            local data = PlayerData[player.UserId]
            if data then
                data.Health = data.MaxHealth
                UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid.Health = data.Health
                end
            end
        end
    end)
    
    player.CharacterAdded:Connect(function(char)
        -- 0. OYUNCU COLLISION GROUP SET (Düşmanlarla ve diğer oyuncularla çarpışmayı önler)
        local PhysicsService = game:GetService("PhysicsService")
        local PLAYER_GROUP = "Players"
        pcall(function()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CollisionGroup = PLAYER_GROUP
                end
            end
            char.DescendantAdded:Connect(function(desc)
                if desc:IsA("BasePart") then
                    desc.CollisionGroup = PLAYER_GROUP
                end
            end)
        end)

        -- 1. ROBLOX VARSAYILAN CAN YENİLENMESİNİ KAPAT
        task.defer(function()
            local defaultHealth = char:FindFirstChild("Health")
            if defaultHealth then defaultHealth:Destroy() end
            
            char.ChildAdded:Connect(function(child)
                if child.Name == "Health" then child:Destroy() end
            end)
        end)

        PlayerRunTracks[player.UserId] = nil -- Eski karakterin koşma animasyonunu temizle
        local data = PlayerData[player.UserId]
        if data then
            data.IsDowned = false
            local hum = char:WaitForChild("Humanoid")
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            local isStarted = ReplicatedStorage:GetAttribute("GameStarted") == true
            local isIntro = ReplicatedStorage:GetAttribute("CameraIntroActive") == true
            local canMove = isStarted and not isIntro
            hum.WalkSpeed = canMove and (17 + (data.SpeedBonus or 0)) or 0
            hum.JumpPower = canMove and 50 or 0
            hum.JumpHeight = canMove and 7.2 or 0
            hum.AutoRotate = canMove
            if hrp then
                hrp.Anchored = false
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end

            -- Güvenli Spawn / Zemin Hizalama (Havada kalmayı ve zemine gömülmeyi önler)
            task.spawn(function()
                if not hrp then return end
                
                -- Harita henüz oluşmadıysa bekle
                if not ReplicatedStorage:GetAttribute("MapGenerated") then
                    ReplicatedStorage:GetAttributeChangedSignal("MapGenerated"):Wait()
                end
                
                local spawnPos = ReplicatedStorage:GetAttribute("SpawnPosition")
                if not spawnPos then
                    local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
                    spawnPos = sp and sp.Position or Vector3.new(0, 5, 0)
                end
                
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                rayParams.FilterDescendantsInstances = { char }
                local hit = workspace:Raycast(Vector3.new(spawnPos.X, spawnPos.Y + 40, spawnPos.Z), Vector3.new(0, -80, 0), rayParams)
                local targetY = hit and hit.Position.Y or spawnPos.Y
                
                local hipHeight = (hum.HipHeight > 0) and hum.HipHeight or 2.0
                local rootOffset = hipHeight + (hrp.Size.Y / 2)
                hrp.CFrame = CFrame.new(spawnPos.X, targetY + rootOffset, spawnPos.Z)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.Anchored = false
                
                local currentCanMove = (ReplicatedStorage:GetAttribute("GameStarted") == true) and (ReplicatedStorage:GetAttribute("CameraIntroActive") ~= true)
                if not currentCanMove then
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                    hum.JumpHeight = 0
                    hum.AutoRotate = false
                end
                
                -- Karakterin yere sağlam basmasını ve Freefall yerine Running/Idle durumuna geçmesini sağla
                task.defer(function()
                    if hum then
                        hum:ChangeState(Enum.HumanoidStateType.Landed)
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end)
            end)
            hum.MaxHealth = data.MaxHealth
            hum.Health = data.Health
            local compassBoost = 1 + (data.Items and data.Items.compass or 0) * 0.15
            local effectiveMagnet = (data.MagnetRangeMultiplier or 1.0) * compassBoost
            char:SetAttribute("MagnetMultiplier", effectiveMagnet)
            char:SetAttribute("IsDowned", false) -- Her ihtimale karşı resetle
            
            -- DİĞER SİSTEMLERE (CombatManager vb.) DOĞUŞ HABERİ VER
            PlayerSpawnedBindable:Fire(player)
            
            -- ÖZEL ANİMASYONLARI UYGULA
            task.spawn(function()
                -- Roblox'un varsayılan Animate script'inin yüklenmesi için kısa bir süre bekle
                task.wait(0.2) 
                
                local animateScript = char:WaitForChild("Animate", 5)
                if animateScript then
                    local playerAnims = AnimationConfig.Player
                    
                    local function updateAnim(name, newId)
                        -- Boş veya geçersiz değerleri filtrele
                        if not newId or tostring(newId) == "" or tostring(newId) == "0" or tostring(newId) == "rbxassetid://0" then 
                            return 
                        end
                        
                        -- Eğer sadece rakam girilmişse protokolü ekle
                        local finalId = tostring(newId)
                        if not string.find(finalId, "rbxassetid://") and tonumber(finalId) then
                            finalId = "rbxassetid://" .. finalId
                        end
                        
                        local container = animateScript:FindFirstChild(name)
                        if container then
                            local found = false
                            for _, child in ipairs(container:GetChildren()) do
                                if child:IsA("Animation") then
                                    child.AnimationId = finalId
                                    found = true
                                end
                            end
                            if found then

                            end
                        end
                    end
                    
                    updateAnim("idle", playerAnims.Idle)
                    updateAnim("walk", playerAnims.Walk)
                    updateAnim("run", playerAnims.Run)
                    updateAnim("jump", playerAnims.Jump)
                    updateAnim("fall", playerAnims.Fall)
                    
                    -- ANİMASYON SİSTEMİNİ YENİLE (Stuck kalmasını önler)
                    animateScript.Enabled = false
                    task.wait(0.1)
                    animateScript.Enabled = true
                    
                    -- Mevcut animasyonları durdur ve temizle ki yenileri kesin yüklensin
                    local animator = hum:WaitForChild("Animator", 5)
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            track:Stop(0)
                        end
                    end
                else
                    warn("Animate script'i 5 saniye içinde bulunamadı!")
                end
            end)
            -- Zıplama bekleme süresi istemci tarafında (PlayerMovementInertiaController) 2 saniye ve pürüzsüz olarak yönetilir
        end
    end)
    
    task.spawn(function()
        if not ReplicatedStorage:GetAttribute("MapGenerated") then
            ReplicatedStorage:GetAttributeChangedSignal("MapGenerated"):Wait()
        end
        player:LoadCharacter()
    end)
end

-- CAN YENİLENME DÖNGÜSÜ
task.spawn(function()
    while true do
        task.wait(1)
        if ReplicatedStorage:GetAttribute("IsPaused") then continue end
        
        for _, player in ipairs(Players:GetPlayers()) do
            local data = PlayerData[player.UserId]
            if data and data.HealthRegen > 0 and not data.IsDowned and data.Health < data.MaxHealth then
                local bandageBoost = 1 + (data.Items and data.Items.bandage or 0) * 0.25
                local finalRegen = data.HealthRegen * bandageBoost
                data.Health = math.min(data.MaxHealth, data.Health + finalRegen)
                UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
                
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid.Health = data.Health
                end
            end
        end
    end
end)



local function rollRarity(luck)
    luck = luck or 0
    local sortedRarities = {
        UpgradeConfig.Rarities.Common,
        UpgradeConfig.Rarities.Uncommon,
        UpgradeConfig.Rarities.Rare,
        UpgradeConfig.Rarities.Epic,
        UpgradeConfig.Rarities.Legendary
    }
    
    local totalWeight = 0
    local weights = {}
    for i, rarity in ipairs(sortedRarities) do
        local weight = rarity.Weight
        -- Kademeli Şans Çarpanı: (1 + luck) ^ (Level - 1)
        -- Level 1 (Common) için çarpan = 1'dir (etkilenmez)
        -- Level 2 (Uncommon) için = (1 + luck)
        -- Level 3 (Rare) için = (1 + luck)^2, vb.
        -- Bu sayede şans arttıkça düşük nadirlikler sırayla elenir.
        local level = rarity.Level or i
        local multiplier = (1 + luck) ^ (level - 1)
        weight = weight * multiplier
        
        weights[i] = weight
        totalWeight = totalWeight + weight
    end
    
    local roll = math.random() * totalWeight
    local cumulative = 0
    for i, rarity in ipairs(sortedRarities) do
        cumulative = cumulative + weights[i]
        if roll <= cumulative then
            return rarity
        end
    end
    return sortedRarities[1]
end

local function rollMilestoneRarity(luck)
    luck = luck or 0
    local sortedRarities = {
        (UpgradeConfig.MilestoneRarities and UpgradeConfig.MilestoneRarities.Uncommon) or { Level = 1, Name = "Uncommon", Weight = 50, Color = Color3.fromRGB(100, 255, 100) },
        (UpgradeConfig.MilestoneRarities and UpgradeConfig.MilestoneRarities.Rare) or { Level = 2, Name = "Rare", Weight = 32, Color = Color3.fromRGB(100, 150, 255) },
        (UpgradeConfig.MilestoneRarities and UpgradeConfig.MilestoneRarities.Epic) or { Level = 3, Name = "Epic", Weight = 14, Color = Color3.fromRGB(200, 100, 255) },
        (UpgradeConfig.MilestoneRarities and UpgradeConfig.MilestoneRarities.Legendary) or { Level = 4, Name = "Legendary", Weight = 4, Color = Color3.fromRGB(255, 200, 50) }
    }
    
    local totalWeight = 0
    local weights = {}
    for i, rarity in ipairs(sortedRarities) do
        local weight = rarity.Weight
        local level = rarity.Level or i
        local multiplier = (1 + luck) ^ (level - 1)
        weight = weight * multiplier
        weights[i] = weight
        totalWeight = totalWeight + weight
    end
    
    local roll = math.random() * totalWeight
    local cumulative = 0
    for i, rarity in ipairs(sortedRarities) do
        cumulative = cumulative + weights[i]
        if roll <= cumulative then
            return rarity
        end
    end
    return sortedRarities[1]
end

function triggerLevelUp(player, data, forcedRarity, forcedUpgradeKey, isReroll)
    PlayersChoosing[player.UserId] = true
    player:SetAttribute("IsChoosingUpgrade", true)
    if not isReroll then
        data.PendingLevelUps = (data.PendingLevelUps or 1) - 1
    end
    
    local weaponCount = (data.HasBullet and 1 or 0) + (data.HasFireball and 1 or 0) + (data.HasFireTrail and 1 or 0) + (data.HasLightning and 1 or 0) + (data.HasSnowball and 1 or 0) + (data.HasSpikedArmor and 1 or 0) + (data.HasTurret and 1 or 0)
    local perkCount = 0
    for k in pairs(data.Upgrades) do
        local uType = UpgradeConfig.Upgrades[k] and UpgradeConfig.Upgrades[k].Type
        if uType == "Perk" then perkCount = perkCount + 1 end
    end
    
    local isWeaponFull = weaponCount >= (data.MaxWeaponSlots or 3)
    local isPerkFull = perkCount >= (data.MaxPerkSlots or 3)
    
    -- 1. ADIM: TÜM GEÇERLİ SEÇENEKLERİ HAVUZA EKLE
    local pool = {}
    for key, upgrade in pairs(UpgradeConfig.Upgrades) do
        local isValid = true
        
        -- Permanent progression unlock check!
        if upgrade.LockedByDefault then
            if not ProgressionManager.IsUnlocked(player, key) then
                isValid = false
            end
        end
        
        -- Perk/Weapon Slot Kontrolü
        if upgrade.Type == "Perk" and not data.Upgrades[key] and isPerkFull then isValid = false end
        if key == "FireballWeapon" and not data.HasFireball and isWeaponFull then isValid = false end
        if key == "FireTrailWeapon" and not data.HasFireTrail and isWeaponFull then isValid = false end
        if key == "BulletWeapon" and not data.HasBullet and isWeaponFull then isValid = false end
        if key == "LightningWeapon" and not data.HasLightning and isWeaponFull then isValid = false end
        if key == "SnowballWeapon" and not data.HasSnowball and isWeaponFull then isValid = false end
        if key == "SpikedArmorWeapon" and not data.HasSpikedArmor and isWeaponFull then isValid = false end
        if key == "TurretWeapon" and not data.HasTurret and isWeaponFull then isValid = false end
        
        -- SINIF KISITLAMALARI
        if data.SelectedClassId == "Knight" then
            if key == "BulletWeapon" or key == "LightningWeapon" or key == "SnowballWeapon" or key == "FireballWeapon" or key == "TurretWeapon" or key == "ProjectileCount" then
                isValid = false
            end
        elseif data.SelectedClassId ~= "Engineer" then
            -- TurretWeapon sadece Engineer'a özeldir!
            if key == "TurretWeapon" then
                isValid = false
            end
        end
        
        if isValid then
            table.insert(pool, key)
        end
    end

    -- Eğer admin belirli bir kart/silah zorladıysa, havuzdan çıkart (çift çıkmasın)
    local hasForcedKey = forcedUpgradeKey and UpgradeConfig.Upgrades[forcedUpgradeKey] ~= nil
    if hasForcedKey then
        for idx = #pool, 1, -1 do
            if pool[idx] == forcedUpgradeKey then
                table.remove(pool, idx)
                break
            end
        end
    end

    -- TARET DÖNÜM NOKTASI (MILESTONE / OVERCLOCK): 5 upgrade tamamlandıysa 3 taret uzmanlaşma kartı sunulur
    if data.TurretMilestonePending == true and data.HasTurret and UpgradeConfig.TurretMilestones then
        local availableMilestones = {}
        for mKey, _ in pairs(UpgradeConfig.TurretMilestones) do
            table.insert(availableMilestones, mKey)
        end
        for idx = #availableMilestones, 2, -1 do
            local r = math.random(1, idx)
            availableMilestones[idx], availableMilestones[r] = availableMilestones[r], availableMilestones[idx]
        end

        local milestoneOptions = {}
        local luck = ((data.Items and data.Items.clover or 0) * 0.05) + (data.LuckBonus or 0)
        for i = 1, math.min(3, #availableMilestones) do
            local mKey = availableMilestones[i]
            local mDef = UpgradeConfig.TurretMilestones[mKey]
            
            -- Nadirlik Zarı (Uncommon / Rare / Epic / Legendary - Dengeli Ağırlıklar)
            local rData = rollMilestoneRarity(luck)
            local rName = rData.Name
            local rColor = rData.Color or Color3.fromRGB(100, 255, 100)
            
            local rStats = (mDef.Rarities and mDef.Rarities[rName]) or (mDef.Rarities and (mDef.Rarities["Rare"] or mDef.Rarities["Uncommon"]))
            
            -- Renkli ve anlaşılır açıklama metni oluştur
            local descParts = {}
            if rStats.AtkSpd then
                local pct = math.floor(rStats.AtkSpd * 100 + 0.5)
                local color = (pct > 0) and "#22c55e" or "#ef4444"
                local sign = (pct > 0) and "+" or ""
                table.insert(descParts, string.format("<font color='%s'>%s%.0f%% Attack Speed</font>", color, sign, pct))
            end
            if rStats.Damage then
                local pct = math.floor(rStats.Damage * 100 + 0.5)
                local color = (pct > 0) and "#22c55e" or "#ef4444"
                local sign = (pct > 0) and "+" or ""
                table.insert(descParts, string.format("<font color='%s'>%s%.0f%% Damage</font>", color, sign, pct))
            end
            if rStats.Range then
                local pct = math.floor(rStats.Range * 100 + 0.5)
                local color = (pct > 0) and "#22c55e" or "#ef4444"
                local sign = (pct > 0) and "+" or ""
                table.insert(descParts, string.format("<font color='%s'>%s%.0f%% Range</font>", color, sign, pct))
            end
            if rStats.Duration then
                local pct = math.floor(rStats.Duration * 100 + 0.5)
                local color = (pct > 0) and "#22c55e" or "#ef4444"
                local sign = (pct > 0) and "+" or ""
                table.insert(descParts, string.format("<font color='%s'>%s%.0f%% Duration</font>", color, sign, pct))
            end
            if rStats.ExtraShots and rStats.ExtraShots > 0 then
                table.insert(descParts, string.format("<font color='#22c55e'>+%.0f Extra Shot</font>", rStats.ExtraShots))
            end
            if rStats.ScrapCost then
                local color = (rStats.ScrapCost > 0) and "#facc15" or "#4ade80"
                local sign = (rStats.ScrapCost > 0) and "+" or ""
                table.insert(descParts, string.format("<font color='%s'>%s%.0f Scrap</font>", color, sign, rStats.ScrapCost))
            end

            local formattedDesc = table.concat(descParts, "  ")

            table.insert(milestoneOptions, {
                Key = "TurretMilestone",
                Value = 1,
                SubKey = mKey,
                MilestoneKey = mKey,
                IsMilestone = true,
                Title = mDef.Title,
                Description = formattedDesc,
                Icon = mDef.Icon or "rbxassetid://116127630902574",
                RarityName = rName,
                RarityColor = rColor,
                MilestoneStats = rStats
            })
        end

        data.ActiveOffers = milestoneOptions
        LevelUpEvent:FireClient(player, data.Level, milestoneOptions, data)
        ReplicatedStorage:SetAttribute("IsPaused", true)
        setPlayersFrozen(true)
        return
    end

    -- 2. ADIM: HAVUZDAN 3 BENZERSİZ SEÇENEK SEÇ VE HER BİRİ İÇİN NADİRLİK ZARI AT
    local finalOptions = {}
    local forcedSlotIndex = nil
    if forcedRarity and UpgradeConfig.Rarities[forcedRarity] then
        forcedSlotIndex = hasForcedKey and 1 or math.random(1, 3)
    end
    
    for i = 1, 3 do
        local chosenKey = nil
        if i == 1 and hasForcedKey then
            chosenKey = forcedUpgradeKey
        else
            if #pool == 0 then break end
            local chosenIndex = math.random(1, #pool)
            chosenKey = table.remove(pool, chosenIndex)
        end
        if not chosenKey then break end
        
        local base = UpgradeConfig.Upgrades[chosenKey]
        
        -- Alt özellik ve Bonus hesaplama
        local minB, maxB, chosenSubStat = 0, 0, nil
        local isUnlocking = false
        if chosenKey == "FireballWeapon" and not data.HasFireball then isUnlocking = true
        elseif chosenKey == "FireTrailWeapon" and not data.HasFireTrail then isUnlocking = true
        elseif chosenKey == "BulletWeapon" and not data.HasBullet then isUnlocking = true
        elseif chosenKey == "LightningWeapon" and not data.HasLightning then isUnlocking = true
        elseif chosenKey == "SnowballWeapon" and not data.HasSnowball then isUnlocking = true
        elseif chosenKey == "SpikedArmorWeapon" and not data.HasSpikedArmor then isUnlocking = true
        elseif chosenKey == "TurretWeapon" and not data.HasTurret then isUnlocking = true
        elseif base.Type == "Weapon" and (not data.Upgrades[chosenKey] or data.Upgrades[chosenKey] == 0) then isUnlocking = true end
        
        -- NADİRLİK ZARI AT (Weight tablosuna göre veya Admin Komutu Zoruyla)
        local rarityData
        if forcedSlotIndex == i then
            rarityData = UpgradeConfig.Rarities[forcedRarity]
            isUnlocking = false -- Zorunlu nadirlikte sayısal bonus seçilsin
        elseif isUnlocking then
            rarityData = { Level = 1, Name = "New", Multiplier = 1.0, Color = Color3.fromRGB(200, 200, 200) }
        else
            local luck = ((data.Items and data.Items.clover or 0) * 0.05) + (data.LuckBonus or 0)
            rarityData = rollRarity(luck)
        end
        
        if isUnlocking then
            chosenSubStat = {Name = "Unlock", Display = "Unlock"}
        elseif base.SubStats then
            local validSubStats = {}
            for _, ss in ipairs(base.SubStats) do
                if ss.Name == "TurretCostReduction" and (data.TurretCost or 100) <= 15 then
                    -- Taret hurda maliyeti taban seviyede (<= 15) ise artık maliyet düşürme çıkarma
                else
                    table.insert(validSubStats, ss)
                end
            end
            if #validSubStats == 0 then validSubStats = base.SubStats end

            local subWeight = 0
            for _, ss in ipairs(validSubStats) do subWeight = subWeight + ss.Weight end
            local rW = math.random(1, subWeight)
            local cW = 0
            for _, ss in ipairs(validSubStats) do
                cW = cW + ss.Weight
                if rW <= cW then
                    chosenSubStat = ss
                    minB, maxB = ss.MinBonus, ss.MaxBonus
                    break
                end
            end
        else
            minB, maxB = base.MinBonus, base.MaxBonus
        end
        
        local randomBonus = 0
        local subRarityBonuses = chosenSubStat and chosenSubStat.RarityBonuses
        if subRarityBonuses and subRarityBonuses[rarityData.Name] then
            randomBonus = subRarityBonuses[rarityData.Name]
        elseif base.RarityBonuses and base.RarityBonuses[rarityData.Name] then
            randomBonus = base.RarityBonuses[rarityData.Name]
        elseif maxB > 0 then
            minB = minB * rarityData.Multiplier
            maxB = maxB * rarityData.Multiplier
            -- Daha hassas ondalık sayılar için (Örn: Lifesteal %0.5) 3 hane hassasiyet
            randomBonus = math.floor((math.random() * (maxB - minB) + minB) * 1000) / 1000
            
            -- Yüzdelik oranları temiz 2 basamağa yuvarla (Örn: %20, %14 - küsurat yapmaz)
            local statName = chosenSubStat and chosenSubStat.Name or chosenKey
            if statName == "ProjectileCount" or string.find(statName, "Count") or statName == "TurretExtraShots" then
                randomBonus = math.max(0.5, math.floor(randomBonus * 2 + 0.5) / 2)
            elseif statName == "LightningBounces" then
                randomBonus = math.max(1, math.floor(randomBonus + 0.5))
            elseif base.Suffix == "%" or base.Suffix == "x" or (chosenSubStat and (chosenSubStat.Suffix == "%" or chosenSubStat.Suffix == "x")) then
                randomBonus = math.floor(randomBonus * 100 + 0.5) / 100
            elseif maxB < 1.0 then
                randomBonus = math.floor(randomBonus * 10 + 0.5) / 10
            else
                randomBonus = math.floor(randomBonus * 10 + 0.5) / 10
            end
        end
        
        -- 2'li Geliştirme (Dual Upgrade) Kontrolü:
        -- Silah mevcutsa ve açılış kartı değilse (%70 ihtimalle) 2 farklı özellik birden verilir!
        local isDual = false
        local chosenSubStat2 = nil
        local randomBonus2 = 0
        if not isUnlocking and base.Type == "Weapon" and base.SubStats and #base.SubStats >= 2 and chosenSubStat then
            local cloverBonus = (data.Items and data.Items.clover or 0) * 0.03
            local dualChance = 0.70 + cloverBonus
            if math.random() < dualChance then
                local remainingSubStats = {}
                for _, ss in ipairs(validSubStats or base.SubStats) do
                    if ss.Name ~= chosenSubStat.Name then
                        table.insert(remainingSubStats, ss)
                    end
                end
                
                if #remainingSubStats > 0 then
                    local subWeight2 = 0
                    for _, ss in ipairs(remainingSubStats) do subWeight2 = subWeight2 + ss.Weight end
                    local rW2 = math.random(1, subWeight2)
                    local cW2 = 0
                    for _, ss in ipairs(remainingSubStats) do
                        cW2 = cW2 + ss.Weight
                        if rW2 <= cW2 then
                            chosenSubStat2 = ss
                            break
                        end
                    end
                    
                    if chosenSubStat2 then
                        isDual = true
                        local minB2, maxB2 = chosenSubStat2.MinBonus, chosenSubStat2.MaxBonus
                        local subRarity2 = chosenSubStat2.RarityBonuses
                        if subRarity2 and subRarity2[rarityData.Name] then
                            randomBonus2 = subRarity2[rarityData.Name]
                        elseif maxB2 > 0 then
                            minB2 = minB2 * rarityData.Multiplier
                            maxB2 = maxB2 * rarityData.Multiplier
                            randomBonus2 = math.floor((math.random() * (maxB2 - minB2) + minB2) * 1000) / 1000
                            
                            local sName2 = chosenSubStat2.Name
                            if sName2 == "ProjectileCount" or string.find(sName2, "Count") or sName2 == "TurretExtraShots" then
                                randomBonus2 = math.max(0.5, math.floor(randomBonus2 * 2 + 0.5) / 2)
                            elseif sName2 == "LightningBounces" then
                                randomBonus2 = math.max(1, math.floor(randomBonus2 + 0.5))
                            elseif chosenSubStat2.Suffix == "%" or chosenSubStat2.Suffix == "x" then
                                randomBonus2 = math.floor(randomBonus2 * 100 + 0.5) / 100
                            else
                                randomBonus2 = math.floor(randomBonus2 * 10 + 0.5) / 10
                            end
                        end
                    end
                end
            end
        end

        table.insert(finalOptions, {
            Key = chosenKey, 
            Value = randomBonus,
            SubKey = chosenSubStat and chosenSubStat.Name or nil,
            SubStatDisplay = chosenSubStat and chosenSubStat.Display or nil,
            IsUnlocking = isUnlocking,
            RarityName = rarityData.Name,
            RarityColor = rarityData.Color,
            IsDual = isDual,
            Value2 = isDual and randomBonus2 or nil,
            SubKey2 = isDual and chosenSubStat2 and chosenSubStat2.Name or nil,
            SubStatDisplay2 = isDual and chosenSubStat2 and chosenSubStat2.Display or nil,
        })
    end
    
    -- 3. ADIM: SON BİR KEZ KARIŞTIR (Görsel rastgelelik için, zorunlu kart yoksa)
    if not hasForcedKey then
        for i = #finalOptions, 2, -1 do
            local j = math.random(1, i)
            finalOptions[i], finalOptions[j] = finalOptions[j], finalOptions[i]
        end
    end
    
    data.ActiveOffers = finalOptions
    LevelUpEvent:FireClient(player, data.Level, finalOptions, data)
    ReplicatedStorage:SetAttribute("IsPaused", true)
    setPlayersFrozen(true)
end

addXPToAll = function(amount)
    if ReplicatedStorage:GetAttribute("IsPaused") then return end
    local playersList = Players:GetPlayers()
    if #playersList == 0 then return end
    local isMultiplayer = #playersList > 1
    
    -- Tüm oyuncuların toplam XP boostunu hesapla (Shared XP Boost: Scholar perk + Weird Glasses / xp_tome)
    local totalXPBoost = 0
    for _, p in ipairs(playersList) do
        local d = PlayerData[p.UserId]
        if d then
            if d.XPBoost then
                totalXPBoost = totalXPBoost + d.XPBoost
            end
            if d.Items and d.Items.xp_tome then
                totalXPBoost = totalXPBoost + (d.Items.xp_tome * 0.08)
            end
        end
    end
    
    -- Multiplayer durumunda toplam bonusu dengeli tut (yarıya böl)
    if isMultiplayer then
        totalXPBoost = totalXPBoost / 2
    end
    
    local finalAmount = amount * (1 + totalXPBoost)
    
    -- 1. ADIM: Her oyuncuya eşit finalAmount XP'yi ekle
    local anyLevelUp = false
    for _, player in ipairs(playersList) do
        local data = PlayerData[player.UserId]
        if not data then continue end
        
        data.XP = data.XP + finalAmount
        if data.XP >= data.MaxXP then
            anyLevelUp = true
        end
    end
    
    -- 2. ADIM: Çok oyunculu modda XP ve Seviyeyi Senkronize Et
    -- Biri seviye atlarsa, diğer oyuncular geride kalıp ekransız donmasın diye hepsi seviye atlamaya dahil edilir!
    if isMultiplayer and anyLevelUp then
        local highestXP = 0
        local highestMaxXP = Config.GetXPRequirement(1)
        for _, p in ipairs(playersList) do
            local d = PlayerData[p.UserId]
            if d and d.XP > highestXP then
                highestXP = d.XP
                highestMaxXP = d.MaxXP
            end
        end
        for _, p in ipairs(playersList) do
            local d = PlayerData[p.UserId]
            if d then
                d.XP = highestXP
                d.MaxXP = highestMaxXP
            end
        end
    end
    
    -- 3. ADIM: Seviye atlamaları uygula ve her iki oyuncuya da kart seçim ekranını aynı anda aç
    for _, player in ipairs(playersList) do
        local data = PlayerData[player.UserId]
        if not data then continue end
        
        local levelsGained = 0
        while data.XP >= data.MaxXP do
            data.XP = data.XP - data.MaxXP
            data.Level = data.Level + 1
            data.MaxXP = Config.GetXPRequirement(data.Level)
            
            -- SINIF PASİFLERİ
            if data.SelectedClassId == "Knight" then
                local healthIncrease = data.MaxHealth * 0.015
                data.MaxHealth = data.MaxHealth + healthIncrease
                data.Health = data.Health + healthIncrease
                data.DamageMultiplier = data.DamageMultiplier + 0.005
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid.MaxHealth = data.MaxHealth
                    player.Character.Humanoid.Health = data.Health
                end
                UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
            elseif data.SelectedClassId == "Elf" then
                data.RangedCooldownMultiplier = math.max(0.01, data.RangedCooldownMultiplier - 0.01)
                data.SpeedBonus = (data.SpeedBonus or 0) + 0.17
                player:SetAttribute("SpeedBonus", data.SpeedBonus)
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    local baseSpeed = 17 + data.SpeedBonus
                    player.Character.Humanoid.WalkSpeed = data.IsSprinting and (baseSpeed * 1.5) or baseSpeed
                end
            elseif data.SelectedClassId == "FireMage" then
                data.FireDamageMultiplier = data.FireDamageMultiplier + 0.02
                data.AreaMultiplier = data.AreaMultiplier + 0.01
            elseif data.SelectedClassId == "Human" then
                data.DamageMultiplier = data.DamageMultiplier + 0.01
                data.MaxHealth = data.MaxHealth + 2
                data.Health = data.Health + 2
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid.MaxHealth = data.MaxHealth
                    player.Character.Humanoid.Health = data.Health
                end
                UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
            elseif data.SelectedClassId == "Engineer" then
                data.TurretDamage = (data.TurretDamage or 16) + 1.0
                data.TurretDuration = (data.TurretDuration or 25) + 0.3
            end
            
            levelsGained = levelsGained + 1
        end
        
        if levelsGained > 0 then
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats and leaderstats:FindFirstChild("Level") then
                leaderstats.Level.Value = data.Level
            end
            
            data.PendingLevelUps = (data.PendingLevelUps or 0) + levelsGained
            if not PlayersChoosing[player.UserId] then
                triggerLevelUp(player, data)
            end
        end
        
        UpdateXPEvent:FireClient(player, data.XP, data.MaxXP, data.Level)
    end
end

Players.PlayerAdded:Connect(initializePlayer)

-- XP toplama testi için bir RemoteEvent (Daha sonra gem toplama ile değişecek)
local GiveXPEvent = Instance.new("RemoteEvent")
GiveXPEvent.Name = "GiveXP"
GiveXPEvent.Parent = Events

-- Sunucu içi XP verme (Diğer scriptler için)
local AddXP = Events:FindFirstChild("AddXP") or Instance.new("BindableEvent")
AddXP.Name = "AddXP"
AddXP.Parent = Events

AddXP.Event:Connect(function(player, amount)
    -- Ortak XP mantığı: player parametresi kimin topladığını belirtse de XP herkese gider.
    local actualAmount = (typeof(player) == "number") and player or amount
    addXPToAll(actualAmount or 10)
end)

-- Sunucu içi hasar verme (Diğer scriptler için)
local TakeDamageBindable = Instance.new("BindableEvent")
TakeDamageBindable.Name = "TakeDamage"
TakeDamageBindable.Parent = Events

local function takeDamage(player, amount, attackerPos, attackerEnemy)
    local data = PlayerData[player.UserId]
    if not data or data.Health <= 0 or data.IsDowned then return end
    
    -- HASAR GÖRMEZLİK KONTROLÜ (Revive, Upgrade veya Kalkan gibi özel korumalar)
    local nowClock = os.clock()
    if data.InvulnerableUntil and nowClock < data.InvulnerableUntil then
        return
    end
    
    -- Sub-frame koruma penceresi (aynı anda gelen çoklu sinyalleri filtrelemek için minik 0.08s tampon)
    -- Genel 0.16s hasar alma periyodu ve düşmanların kişisel 0.40s cooldown'ları EnemyManager tarafından senkron yönetilir
    data.InvulnerableUntil = math.max(data.InvulnerableUntil or 0, nowClock + 0.08)
    
    -- Iron Plating (Demir Plaka) Hasar Azaltımı:
    -- Stack başına 2 flat hasar düşürür (minimum alınabilecek hasar 2'dir).
    local ironPlatingCount = data.Items and data.Items.iron_plating or 0
    if ironPlatingCount > 0 and amount > 2 then
        local reduction = ironPlatingCount * 2
        amount = math.max(2, amount - reduction)
    end
    
    data.Health = math.max(0, data.Health - amount)
    UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
    
    -- Progress SpikedArmor quest: "Take 300 damage in total"
    ProgressionManager.AddProgress(player, "SpikedArmorWeapon", amount)
    
    -- Spiked Armor Retaliation
    if data.HasSpikedArmor then
        local SpikedArmorRetaliate = Events:FindFirstChild("SpikedArmorRetaliate")
        if SpikedArmorRetaliate then
            SpikedArmorRetaliate:Fire(player, amount, attackerPos, attackerEnemy)
        end
    end
    
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if hum then
        hum.Health = math.max(1, data.Health) -- Engine ölümü tetiklemesin diye min 1 HP
    end
    
    -- HASAR GÖRSEL EFEKTLERİ
    if char and root then
        -- Hasar oranına göre opaklık (intensity) hesapla (hasar / maxHealth oranına göre, maks %20 can götüren vuruş tam belirginlik sağlar)
        local damageRatio = amount / (data.MaxHealth or 100)
        local intensity = math.clamp(damageRatio * 5, 0.2, 0.9)
        
        -- Karakteri kırmızı renkte flaşlatma (Highlight)
        local highlight = Instance.new("Highlight")
        highlight.Name = "DamageHighlight"
        highlight.Adornee = char
        highlight.FillColor = Color3.fromRGB(255, 50, 50)
        highlight.FillTransparency = 1 - (intensity * 0.6) -- Hasar az ise daha saydam, çok ise daha belirgin
        highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineTransparency = 1 - intensity
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = char
        
        -- Yavaşça yok olması için Tween kullan (0.45 saniye sürer)
        local TweenService = game:GetService("TweenService")
        local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(highlight, tweenInfo, {
            FillTransparency = 1,
            OutlineTransparency = 1
        })
        
        tween:Play()
        game:GetService("Debris"):AddItem(highlight, 0.5)
    end
    
    -- Knockback efekti (Hasar Yüzdesine Göre Ölçülü Geri İtme)
    if root and attackerPos then
        local now = os.clock()
        data.LastKnockbackTime = data.LastKnockbackTime or 0
        local timeSinceLastKnockback = now - data.LastKnockbackTime
        
        -- Knockback Stack Koruması:
        -- Çoklu canavarlar arka arkaya vurduğunda knockback'ler üst üste binip oyuncuyu kilitlemesin (stunlock / ping-pong önleme)
        -- En az 0.35 saniye aralıkla fiziksel savrulma uygulanır; hasar normal şekilde işlenmeye devam eder.
        if timeSinceLastKnockback >= 0.35 then
            data.LastKnockbackTime = now
            local diff = root.Position - attackerPos
            local flatDiff = Vector3.new(diff.X, 0, diff.Z)
            local pushDir = Vector3.new(0, 0, 1)
            if flatDiff.Magnitude > 0.1 then
                pushDir = flatDiff.Unit
            end
            
            -- Alınan hasarın MaxHealth'e oranına göre ölçülü knockback gücü (aşırı fırlama sınırlandı)
            local damagePercent = amount / (data.MaxHealth or 100)
            local knockbackPower = math.clamp(0.20 + (damagePercent * 1.5), 0.25, 0.80)
            
            local ApplyKnockbackEvent = Events:FindFirstChild("ApplyKnockback")
            if ApplyKnockbackEvent then
                ApplyKnockbackEvent:FireClient(player, pushDir, knockbackPower)
            end
        end
    end
    
    if data.Health <= 0 then
        -- 1. DURUMU KİLİTLE
        data.IsDowned = true
        data.IsSprinting = false
        player:SetAttribute("IsSprinting", false)
        char:SetAttribute("IsDowned", true)
        
        local runTrack = PlayerRunTracks[player.UserId]
        if runTrack and runTrack.IsPlaying then
            runTrack:Stop(0.1)
        end
        
        -- Eğer aktif bir knockback varsa iptal et
        if data.ActiveKnockbackCleanup then
            data.ActiveKnockbackCleanup()
        end
        
        -- print(player.Name .. " is down!")
        
        -- 2. HAREKETİ VE SALDIRIYI DURDUR
        if hum then
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum.PlatformStand = true
            hum.AutoRotate = false
            
            -- Tüm oynayan animasyonları durdur (Ateş etme vb.)
            local animator = hum:FindFirstChild("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop(0.1)
                end
            end
        end
        
        -- 3. CANLANDIRMA PROMPT'U
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local prompt = Instance.new("ProximityPrompt")
            prompt.Name = "RevivePrompt"
            prompt.ActionText = "Revive " .. player.Name
            prompt.ObjectText = "Teammate Downed!"
            prompt.KeyboardKeyCode = Enum.KeyCode.E
            prompt.HoldDuration = 3
            prompt.RequiresLineOfSight = false
            prompt.UIOffset = Vector2.new(0, 50)
            prompt.Parent = root
            
            prompt.Triggered:Connect(function(reviver)
                if reviver ~= player then
                    revivePlayer(player, reviver)
                end
            end)
            
            HideRevivePromptEvent:FireClient(player)
        end
        
        ShowMessageEvent:FireAllClients(player.Name .. " is down!", Color3.fromRGB(255, 50, 50))
        checkAllDowned()
    end
end

TakeDamageBindable.Event:Connect(function(player, amount, attackerPos, attackerEnemy)
    takeDamage(player, amount, attackerPos, attackerEnemy)
end)

local HealPlayerBindable = Instance.new("BindableEvent")
HealPlayerBindable.Name = "HealPlayer"
HealPlayerBindable.Parent = Events

HealPlayerBindable.Event:Connect(function(player, amount)
    local data = PlayerData[player.UserId]
    if not data or data.Health <= 0 then return end
    
    local bandageBoost = 1 + (data.Items and data.Items.bandage or 0) * 0.25
    local finalHeal = amount * bandageBoost
    data.Health = math.min(data.MaxHealth, data.Health + finalHeal)
    UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
    
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.Health = data.Health
    end
end)

local AddCoinsBindable = Instance.new("BindableEvent")
AddCoinsBindable.Name = "AddCoins"
AddCoinsBindable.Parent = Events

AddCoinsBindable.Event:Connect(function(player, amount)
    local data = PlayerData[player.UserId]
    if data then
        data.Coins = math.max(0, (data.Coins or 0) + amount)
        if amount > 0 then
            data.TotalCoins = (data.TotalCoins or 0) + amount
        end
        player:SetAttribute("Coins", data.Coins)
        player:SetAttribute("Gold", data.Coins)
        player:SetAttribute("TotalCoins", data.TotalCoins or data.Coins)
        player:SetAttribute("TotalGold", data.TotalCoins or data.Coins)
        UpdateCoinsEvent:FireClient(player, data.Coins)
    end
end)

local AddScrapBindable = Events:FindFirstChild("AddScrap") or Instance.new("BindableEvent")
AddScrapBindable.Name = "AddScrap"
AddScrapBindable.Parent = Events

AddScrapBindable.Event:Connect(function(player, amount)
    local data = PlayerData[player.UserId]
    if data and (player:GetAttribute("SelectedClassId") == "Engineer" or player:GetAttribute("HasTurret") == true) then
        data.Scrap = math.max(0, (data.Scrap or 0) + (amount or 0))
        player:SetAttribute("Scrap", data.Scrap)
        local cost = data.TurretCost or 100
        player:SetAttribute("TurretReady", data.Scrap >= cost)
    end
end)

local AddSilverBindable = Events:FindFirstChild("AddSilver") or Instance.new("BindableEvent")
AddSilverBindable.Name = "AddSilver"
AddSilverBindable.Parent = Events

AddSilverBindable.Event:Connect(function(player, amount)
    local data = PlayerData[player.UserId]
    if data then
        data.MatchSilver = (data.MatchSilver or 0) + (amount or 0)
    end
    ProgressionManager.AddSilver(player, amount)
end)

local AddLuckBonusBindable = Events:FindFirstChild("AddLuckBonus") or Instance.new("BindableEvent")
AddLuckBonusBindable.Name = "AddLuckBonus"
AddLuckBonusBindable.Parent = Events

AddLuckBonusBindable.Event:Connect(function(player, amount)
    local data = PlayerData[player.UserId]
    if data then
        data.LuckBonus = (data.LuckBonus or 0) + (amount or 0.10)
        player:SetAttribute("LuckBonus", data.LuckBonus)
    end
end)

local SpendScrapFunction = Events:FindFirstChild("SpendScrap") or Instance.new("BindableFunction")
SpendScrapFunction.Name = "SpendScrap"
SpendScrapFunction.Parent = Events

SpendScrapFunction.OnInvoke = function(player, amount)
    local data = PlayerData[player.UserId]
    if data and (data.Scrap or 0) >= (amount or 0) then
        data.Scrap = data.Scrap - amount
        player:SetAttribute("Scrap", data.Scrap)
        local cost = data.TurretCost or 100
        player:SetAttribute("TurretReady", data.Scrap >= cost)
        return true
    end
    return false
end

local ChestOpenedBindable = Instance.new("BindableEvent")
ChestOpenedBindable.Name = "ChestOpened"
ChestOpenedBindable.Parent = Events

ChestOpenedBindable.Event:Connect(function(player, newChestsOpened, newCost)
    local data = PlayerData[player.UserId]
    if data then
        data.ChestsOpened = newChestsOpened
        data.ChestOpenCost = newCost
    end
end)

local AddItemBindable = Instance.new("BindableEvent")
AddItemBindable.Name = "AddItem"
AddItemBindable.Parent = Events

AddItemBindable.Event:Connect(function(player, itemKey, amount)
    local data = PlayerData[player.UserId]
    if data then
        data.Items = data.Items or {}
        data.Items[itemKey] = (data.Items[itemKey] or 0) + (amount or 1)
        
        -- Regen yüzüğü (bandage) alındığında can yenilemesi görevini güncelle
        if itemKey == "bandage" and data.HealthRegen and data.HealthRegen > 0 then
            local bandageBoost = 1 + data.Items.bandage * 0.25
            local effectiveRegen = data.HealthRegen * bandageBoost
            ProgressionManager.UpdateProgress(player, "Lifesteal", effectiveRegen)
        end
        
        -- Mıknatıslı pusula (compass) alındığında toplama menzilini anında güncelle
        if itemKey == "compass" then
            local compassBoost = 1 + (data.Items.compass or 0) * 0.15
            local effectiveMagnet = (data.MagnetRangeMultiplier or 1.0) * compassBoost
            if player.Character then
                player.Character:SetAttribute("MagnetMultiplier", effectiveMagnet)
            end
        end
    end
end)

local RecordCombatStatBindable = Instance.new("BindableEvent")
RecordCombatStatBindable.Name = "RecordCombatStat"
RecordCombatStatBindable.Parent = Events

RecordCombatStatBindable.Event:Connect(function(player, statType, key, value)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    if statType == "Damage" then
        data.WeaponDamage = data.WeaponDamage or {}
        data.WeaponDamage[key] = (data.WeaponDamage[key] or 0) + value
    elseif statType == "Kill" then
        data.DefeatedEnemies = data.DefeatedEnemies or {}
        data.DefeatedEnemies[key] = (data.DefeatedEnemies[key] or 0) + value
        data.TotalKills = (data.TotalKills or 0) + value
        player:SetAttribute("Kills", data.TotalKills)
        player:SetAttribute("TotalKills", data.TotalKills)
        
        -- Blood Blade: Her canavar öldürüldüğünde stack başına 1 can yenile
        local bloodBladeCount = data.Items and data.Items.blood_blade or 0
        if bloodBladeCount > 0 and data.Health > 0 and not data.IsDowned then
            local healAmount = bloodBladeCount * 1 * (value or 1)
            HealPlayerBindable:Fire(player, healAmount)
        end
    end
end)

-- Mistik Sunak (Shrine) İstatistiklerini Doğrudan Sunucu Verisine Uygula
local ApplyShrineStatBindable = Events:FindFirstChild("ApplyShrineStat") or Instance.new("BindableFunction")
ApplyShrineStatBindable.Name = "ApplyShrineStat"
ApplyShrineStatBindable.Parent = Events

ApplyShrineStatBindable.OnInvoke = function(player, statKey, customAmount, customRarity)
    local data = PlayerData[player.UserId]
    if not data then return false, "No player data" end

    data.ShrineUpgrades = data.ShrineUpgrades or {}
    table.insert(data.ShrineUpgrades, { Key = statKey, Rarity = customRarity, Amount = customAmount })
    data.ShrineBonuses = data.ShrineBonuses or {}
    data.ShrineBonuses[statKey] = (data.ShrineBonuses[statKey] or 0) + 1

    local msg = ""
    if statKey == "Damage" then
        local amt = customAmount or 0.15
        data.DamageMultiplier = (data.DamageMultiplier or 1.0) + amt
        player:SetAttribute("DamageMultiplier", data.DamageMultiplier)
        msg = string.format("+%.0f%% Damage", amt * 100)
    elseif statKey == "MaxHealth" then
        local amt = customAmount or 25
        data.MaxHealth = (data.MaxHealth or 100) + amt
        data.Health = math.min(data.MaxHealth, (data.Health or 100) + amt)
        player:SetAttribute("MaxHealth", data.MaxHealth)
        player:SetAttribute("Health", data.Health)
        UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.MaxHealth = data.MaxHealth
            player.Character.Humanoid.Health = data.Health
        end
        msg = string.format("+%d Max Health", amt)
    elseif statKey == "AttackSpeed" then
        local amt = customAmount or 0.12
        data.AttackSpeedBonus = (data.AttackSpeedBonus or 0) + amt
        local elfBonus = (data.SelectedClassId == "Elf") and 0.95 or 1.0
        data.RangedCooldownMultiplier = elfBonus / (1.0 + data.AttackSpeedBonus)
        data.AttackSpeedMultiplier = 1.0 + data.AttackSpeedBonus
        player:SetAttribute("AttackSpeedMultiplier", data.AttackSpeedMultiplier)
        data.TurretAttackSpeedBonus = (data.TurretAttackSpeedBonus or 0) + amt
        data.TurretFireRate = math.max(0.15, 0.8 / (1.0 + data.TurretAttackSpeedBonus))
        msg = string.format("+%.0f%% Attack Speed", amt * 100)
    elseif statKey == "MoveSpeed" then
        local amt = customAmount or 0.12
        local speedAdd = 17 * amt
        data.SpeedBonus = (data.SpeedBonus or 0) + speedAdd
        player:SetAttribute("SpeedBonus", data.SpeedBonus)
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            local baseSpeed = 17 + data.SpeedBonus
            local finalSpeed = data.IsSprinting and (baseSpeed * 1.5) or baseSpeed
            player.Character.Humanoid.WalkSpeed = finalSpeed
            player.Character.Humanoid:SetAttribute("PreUpgradeWalkSpeed", baseSpeed)
            player.Character.Humanoid:SetAttribute("PrePauseWalkSpeed", baseSpeed)
        end
        msg = string.format("+%.0f%% Move Speed", amt * 100)
    elseif statKey == "CritChance" then
        local amt = customAmount or 0.08
        data.CritChance = (data.CritChance or 0.10) + amt
        player:SetAttribute("CritChance", data.CritChance)
        msg = string.format("+%.0f%% Crit Chance", amt * 100)
    elseif statKey == "CritDamage" then
        local amt = customAmount or 0.25
        data.CritMultiplier = (data.CritMultiplier or 1.5) + amt
        player:SetAttribute("CritMultiplier", data.CritMultiplier)
        msg = string.format("+%.0f%% Crit Damage", amt * 100)
    elseif statKey == "Regen" then
        local amt = customAmount or 0.60
        data.HealthRegen = (data.HealthRegen or 0) + amt
        player:SetAttribute("HealthRegen", data.HealthRegen)
        local bandageBoost = 1 + (data.Items and data.Items.bandage or 0) * 0.25
        local effectiveRegen = data.HealthRegen * bandageBoost
        ProgressionManager.UpdateProgress(player, "Lifesteal", effectiveRegen)
        msg = string.format("+%.2f HP/s Health Regen", amt)
    elseif statKey == "Magnet" then
        local amt = customAmount or 0.25
        data.MagnetRangeMultiplier = (data.MagnetRangeMultiplier or 1.0) + amt
        local compassBoost = 1 + (data.Items and data.Items.compass or 0) * 0.15
        local effectiveMagnet = data.MagnetRangeMultiplier * compassBoost
        player:SetAttribute("MagnetMultiplier", effectiveMagnet)
        if player.Character then
            player.Character:SetAttribute("MagnetMultiplier", effectiveMagnet)
        end
        msg = string.format("+%.0f%% Pickup Range", amt * 100)
    elseif statKey == "Area" then
        local amt = customAmount or 0.15
        data.AreaMultiplier = (data.AreaMultiplier or 1.0) + amt
        player:SetAttribute("AreaMultiplier", data.AreaMultiplier)
        if player.Character then
            player.Character:SetAttribute("AreaMultiplier", data.AreaMultiplier)
        end
        msg = string.format("+%.0f%% Size", amt * 100)
    elseif statKey == "ProjectileCount" then
        local amt = customAmount or 1.0
        -- Oyuncunun sahip olduğu menzilli silahları belirle
        local candidates = {}
        if data.HasBullet then table.insert(candidates, { Key = "Bullet", Display = "Bullet" }) end
        if data.HasFireball then table.insert(candidates, { Key = "Fireball", Display = "Fireball" }) end
        if data.HasLightning then table.insert(candidates, { Key = "Lightning", Display = "Lightning" }) end
        if data.HasSnowball then table.insert(candidates, { Key = "Snowball", Display = "Snowball" }) end
        if data.HasFireTrail then table.insert(candidates, { Key = "FireTrail", Display = "Fire Trail" }) end
        if data.HasTurret then table.insert(candidates, { Key = "Turret", Display = "Turret" }) end
        
        if #candidates == 0 then
            candidates = {
                { Key = "Bullet", Display = "Bullet" },
                { Key = "Fireball", Display = "Fireball" },
                { Key = "Lightning", Display = "Lightning" },
                { Key = "Snowball", Display = "Snowball" },
                { Key = "FireTrail", Display = "Fire Trail" },
                { Key = "Turret", Display = "Turret" }
            }
        end
        
        local chosen = candidates[math.random(1, #candidates)]
        data.UpgradeBonuses = data.UpgradeBonuses or {}
        if chosen.Key == "Bullet" then
            data.BulletCount = (data.BulletCount or 1) + amt
            data.UpgradeBonuses["BulletCount"] = (data.UpgradeBonuses["BulletCount"] or 0) + amt
        elseif chosen.Key == "Fireball" then
            data.FireballCount = (data.FireballCount or 1) + amt
            data.UpgradeBonuses["FireballCount"] = (data.UpgradeBonuses["FireballCount"] or 0) + amt
        elseif chosen.Key == "Lightning" then
            data.LightningCount = (data.LightningCount or 1) + amt
            data.UpgradeBonuses["LightningCount"] = (data.UpgradeBonuses["LightningCount"] or 0) + amt
        elseif chosen.Key == "Snowball" then
            data.SnowballCount = (data.SnowballCount or 1) + amt
            data.UpgradeBonuses["SnowballCount"] = (data.UpgradeBonuses["SnowballCount"] or 0) + amt
        elseif chosen.Key == "FireTrail" then
            data.FireTrailCount = (data.FireTrailCount or 1) + amt
            data.FireTrailDamage = (data.FireTrailDamage or 3.5) + (amt * 1.5)
            data.UpgradeBonuses["FireTrailCount"] = (data.UpgradeBonuses["FireTrailCount"] or 0) + amt
        elseif chosen.Key == "Turret" then
            data.TurretExtraShots = (data.TurretExtraShots or 0) + amt
            data.UpgradeBonuses["TurretExtraShots"] = (data.UpgradeBonuses["TurretExtraShots"] or 0) + amt
        end
        
        data.ProjectileCountBonus = (data.ProjectileCountBonus or 0) + amt
        data.UpgradeBonuses["ProjectileCount"] = data.ProjectileCountBonus
        data.UpgradeBonuses["Volley"] = data.ProjectileCountBonus
        
        local bonusStr = (math.abs(amt - math.floor(amt)) > 0.001) and string.format("+%.1f", amt) or string.format("+%d", math.floor(amt))
        msg = string.format("%s Projectiles (%s)", bonusStr, chosen.Display)
    end

    data.InvulnerableUntil = math.max(data.InvulnerableUntil or 0, os.clock() + 1.5)
    
    -- CombatManager ve diğer sistemlerdeki oyuncu veri önbelleğini anında yenile
    PlayerUpgradedEvent:Fire(player)
    
    return true, msg
end

-- Geçici Dokunulmazlık Verme Bindable'ı
local SetInvulnerableBindable = Events:FindFirstChild("SetInvulnerable") or Instance.new("BindableEvent")
SetInvulnerableBindable.Name = "SetInvulnerable"
SetInvulnerableBindable.Parent = Events

SetInvulnerableBindable.Event:Connect(function(player, duration)
    local data = PlayerData[player.UserId]
    if data then
        data.InvulnerableUntil = math.max(data.InvulnerableUntil or 0, os.clock() + (duration or 1))
    end
end)

BuySlotEvent.OnServerEvent:Connect(function(player, slotType)
    -- Ekstra slot satın alma lobideki Gümüş Dükkanı'na taşındı (Oyun içi altınla slot satın alma devre dışı)
    warn("[PlayerManager] BuySlot oyun içi altın ile satın alınamaz. Lobideki Gümüş Dükkanı'ndan açılmalıdır.")
end)

RerollUpgradesEvent.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data or not PlayersChoosing[player.UserId] then return end
    
    if (data.FreeRerolls or 0) > 0 then
        -- Ücretsiz Reroll hakkı kullanıldı: Altın harcanmaz, RerollCost artmaz!
        data.FreeRerolls = data.FreeRerolls - 1
        triggerLevelUp(player, data, nil, nil, true)
    elseif data.Coins >= data.RerollCost then
        -- Normal Altınlı Reroll
        data.Coins = data.Coins - data.RerollCost
        data.RerollCost = math.floor(data.RerollCost * 1.5)
        
        local UpdateCoinsEvent = Events:FindFirstChild("UpdateCoins")
        if UpdateCoinsEvent then
            UpdateCoinsEvent:FireClient(player, data.Coins)
        end
        
        triggerLevelUp(player, data, nil, nil, true)
    end
end)

GiveXPEvent.OnServerEvent:Connect(function(player, amount)
    if RunService:IsStudio() then
        addXPToAll(amount or 10)
    else
        warn(player.Name .. " tried to call GiveXP on a live server!")
    end
end)

-- RETRY: Oyuncuyu başka bir sunucuya gönder (Aynı oyunun farklı bir sunucusu)
RetryEvent.OnServerEvent:Connect(function(player)
    -- Teleport işlemi Studio içinde çalışmaz, bu yüzden önce kontrol ediyoruz
    if RunService:IsStudio() then
        player:Kick("You chose Retry. (TeleportService doesn't work in Studio)")
        return
    end
    
    local success, err = pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, {player})
    end)
    
    if not success then
        warn("Teleport başarısız oldu: ", err)
        player:Kick("Could not connect to server, please rejoin.")
    end
end)

-- CONTINUE: Oyuncuyu özellikleri kaybolmadan sadece yeniden doğur
ContinueEvent.OnServerEvent:Connect(function(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    
    -- print(player.Name .. " chose Continue, respawning...")
    
    -- Canı doldur ve düşme durumunu kaldır
    data.Health = data.MaxHealth
    data.IsDowned = false
    
    -- Seviye, XP ve silahlar aynen kalır (sıfırlanmaz)
    
    -- Karakteri spawn noktasında yeniden doğur
    player:LoadCharacter()
    
    -- Arayüzü güncelle
    UpdateHealthEvent:FireClient(player, data.Health, data.MaxHealth)
end)

ReturnToLobbyEvent.OnServerEvent:Connect(function(player)
    -- Skorbord için skoru ve öldürmeleri DataStore'a kaydet
    local totalGold, totalKills = saveLeaderboardScore(player)
    totalGold = totalGold or 0
    totalKills = totalKills or 0

    ReturnToLobbyEvent:FireClient(player) -- Client'a yükleme ekranını açması için tetikle
    if RunService:IsStudio() then
        player:Kick("Returning to Lobby. (TeleportService doesn't work in Studio)")
        return
    end
    
    local success, err = pcall(function()
        local lobbyPlaceId = Config.Game.LobbyPlaceId or 0
        if lobbyPlaceId > 0 and game.PlaceId ~= lobbyPlaceId then
            local teleportOptions = Instance.new("TeleportOptions")
            teleportOptions:SetTeleportData({
                Silver = player:GetAttribute("Silver") or 0,
                TotalSilver = player:GetAttribute("Silver") or 0,
                Coins = totalGold,
                Gold = totalGold,
                TotalCoins = totalGold,
                TotalGold = totalGold,
                Kills = totalKills,
                TotalKills = totalKills,
                DefeatedEnemies = (PlayerData[player.UserId] and PlayerData[player.UserId].DefeatedEnemies) or {}
            })
            TeleportService:TeleportAsync(lobbyPlaceId, {player}, teleportOptions)
        elseif game.PlaceId == lobbyPlaceId then
            warn("[GameServer] Zaten Lobi yerindesiniz, lobiye ışınlanma atlandı.")
            player:Kick("Returning to Lobby. Please rejoin.")
        else
            player:Kick("Lobby Place ID is not configured in Config.lua.")
        end
    end)
    
    if not success then
        warn("Lobby teleport failed: ", err)
        player:Kick("Teleport to lobby failed. Please rejoin.")
    end
end)

Players.PlayerRemoving:Connect(function(player)
    saveLeaderboardScore(player)
    PlayerData[player.UserId] = nil
    ReadyPlayers[player.UserId] = nil
    PlayersChoosing[player.UserId] = nil
    PlayerRunTracks[player.UserId] = nil
    
    local remaining = 0
    for _ in pairs(PlayersChoosing) do remaining = remaining + 1 end
    if remaining == 0 and not ReplicatedStorage:GetAttribute("IsOpeningChest") and not ReplicatedStorage:GetAttribute("IsManualPaused") and ReplicatedStorage:GetAttribute("IsPaused") then
        ReplicatedStorage:SetAttribute("IsPaused", false)
        setPlayersFrozen(false)
    end
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        saveLeaderboardScore(player)
    end
end)

-- Spawn noktalarının CanCollide özelliğini kapat (içinden geçilebilir yapmak için)
local function disableSpawnCollisions()
    local function cleanSpawns(container)
        if not container then return end
        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("SpawnLocation") then
                desc.CanCollide = false
            end
        end
    end
    cleanSpawns(workspace)
    ReplicatedStorage:GetAttributeChangedSignal("MapGenerated"):Connect(function()
        if ReplicatedStorage:GetAttribute("MapGenerated") == true then
            cleanSpawns(workspace:FindFirstChild("ProceduralMap"))
        end
    end)
end
task.spawn(disableSpawnCollisions)
