local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))

local ProgressionManager = {}

ProgressionManager.SILVER_ICON = "rbxassetid://104534575155839"

-- Defined locked upgrades and their english quest descriptions and targets
ProgressionManager.Quests = {
    FireTrailWeapon = {
        Title = "Fire Trail",
        Description = "Defeat 5 monsters at once with the Fireball weapon.",
        Target = 5,
        ProgressText = "Max Fireball Kills at Once",
        UnlockCost = 25
    },
    Regeneration = {
        Title = "Regeneration",
        Description = "Upgrade Health 3 times.",
        Target = 3,
        ProgressText = "Health Upgrades",
        UnlockCost = 25
    },
    Lifesteal = {
        Title = "Lifesteal Scroll",
        Description = "Reach 2.5 or more Health Regeneration.",
        Target = 2.5,
        ProgressText = "Max Regen Reached",
        UnlockCost = 25
    },
    CritChance = {
        Title = "Crit Chance",
        Description = "Deal 10 critical hits in a single match.",
        Target = 10,
        ProgressText = "Most Crits in a Match",
        UnlockCost = 25
    },
    AreaSize = {
        Title = "Size",
        Description = "Deal damage to 10 targets at once with a single weapon attack.",
        Target = 10,
        ProgressText = "Max Targets Hit at Once",
        UnlockCost = 25
    },
    SpikedArmorWeapon = {
        Title = "Spiked Armor",
        Description = "Take 300 damage in total.",
        Target = 300,
        ProgressText = "Damage Taken",
        UnlockCost = 25
    },
    compass = {
        Title = "Magnetic Compass",
        Description = "Collect 400 collectables (crystals/coins) in total.",
        Target = 400,
        ProgressText = "Collectables Gathered",
        UnlockCost = 20
    },
    piggy_bank = {
        Title = "Piggy Bank",
        Description = "Break or open 50 pots / bushes in total.",
        Target = 50,
        ProgressText = "Pots / Bushes Broken",
        UnlockCost = 20
    },
    ProjectileCount = {
        Title = "Projectile Count Scroll",
        Description = "Fire 3,000 projectiles in total across matches.",
        Target = 3000,
        ProgressText = "Projectiles Fired",
        UnlockCost = 25
    },
    Luck = {
        Title = "Luck Scroll",
        Description = "Find and collect a Luck Scroll dropped by a monster.",
        Target = 1,
        ProgressText = "Luck Scroll Found",
        UnlockCost = 25
    },
    XPBoost = {
        Title = "XP Scroll",
        Description = "Break 20 pots in a single match.",
        Target = 20,
        ProgressText = "Pots Broken in a Match",
        UnlockCost = 25
    }
}


-- Server-only DataStore configuration
local ProgressionDataStore = nil
if RunService:IsServer() then
    local DataStoreService = game:GetService("DataStoreService")
    ProgressionDataStore = DataStoreService:GetDataStore("PlayerProgressionData_V2")
end

-- Check if an upgrade or item is unlocked
function ProgressionManager.IsUnlocked(player, upgradeKey)
    local base = UpgradeConfig.Upgrades[upgradeKey] or ItemConfig.Items[upgradeKey]
    if not base then return true end
    if not base.LockedByDefault then return true end
    
    -- Eğer bu el (oyun içinde) yeni açıldıysa, bu el boyunca kilitli gibi davransın
    if player:GetAttribute("NewlyUnlocked_" .. upgradeKey) then
        return false
    end
    
    return player:GetAttribute("Unlocked_" .. upgradeKey) == true
end

-- Get Quest Description
function ProgressionManager.GetQuest(upgradeKey)
    return ProgressionManager.Quests[upgradeKey]
end

-- Get player's current Silver balance (Client & Server safe)
function ProgressionManager.GetSilver(player)
    if not player then return 0 end
    return math.floor(player:GetAttribute("Silver") or 0)
end

-- Check if a difficulty tier is unlocked (Client & Server safe)
function ProgressionManager.IsDifficultyUnlocked(player, difficultyId)
    if not player or not difficultyId then return true end
    local idLower = string.lower(tostring(difficultyId))
    if idLower == "easy" or idLower == "tier 1" or idLower == "1" then
        return true
    elseif idLower == "medium" or idLower == "normal" or idLower == "tier 2" or idLower == "2" then
        return player:GetAttribute("DifficultyUnlocked_Medium") == true
    elseif idLower == "hard" or idLower == "tier 3" or idLower == "3" then
        return player:GetAttribute("DifficultyUnlocked_Hard") == true
    end
    return true
end

-- Unlock a difficulty tier
function ProgressionManager.UnlockDifficulty(player, difficultyId)
    if not player or not difficultyId then return false end
    local idLower = string.lower(tostring(difficultyId))
    local attrName = nil
    if idLower == "medium" or idLower == "normal" or idLower == "tier 2" or idLower == "2" then
        attrName = "DifficultyUnlocked_Medium"
    elseif idLower == "hard" or idLower == "tier 3" or idLower == "3" then
        attrName = "DifficultyUnlocked_Hard"
    end
    
    if attrName and player:GetAttribute(attrName) ~= true then
        player:SetAttribute(attrName, true)
        if RunService:IsServer() and typeof(ProgressionManager._TriggerSave) == "function" then
            ProgressionManager._TriggerSave(player)
        end
        return true
    end
    return false
end

-- Server-only functions
if RunService:IsServer() then
    -- ====================================================================
    -- GÜVENLİ KAYIT SİSTEMİ (Session Lock)
    -- * Veri başarıyla yüklenmeden ASLA kayıt yapılmaz (yükleme hatası = veri silinmesi riski).
    -- * Kayıt kaydı üzerinde "SessionLock" tutulur: Lobi <-> Oyun ışınlanmasında iki sunucu
    --   aynı anda yazıp birbirinin verisini ezemez. Yeni sunucu, eski sunucu kilidi bırakana kadar bekler.
    -- * Kayıtlar birleştirilir (debounce) ve periyodik otomatik kayıt ile kilit tazelenir.
    -- ====================================================================
    local SESSION_ID = (game.JobId ~= "" and game.JobId) or ("studio-" .. tostring(os.time()))
    local LOCK_STALE_SECONDS = 180 -- Bu süre boyunca tazelenmeyen kilit "terk edilmiş" sayılır
    local LOAD_ATTEMPTS = 8
    local LOAD_RETRY_DELAY = 2
    local SAVE_DEBOUNCE = 5
    local AUTOSAVE_INTERVAL = 60

    local LoadedPlayers = {}   -- [UserId] = true: veri yüklendi ve kilit bu sunucuda
    local ReleasedPlayers = {} -- [UserId] = true: çıkışta kilit bırakıldı
    local SaveScheduled = {}   -- [UserId] = true: ertelenmiş kayıt bekliyor

    local function buildSaveData(player)
        local dataToSave = {}
        for key in pairs(ProgressionManager.Quests) do
            dataToSave[key] = player:GetAttribute("Unlocked_" .. key) == true
            dataToSave["Progress_" .. key] = player:GetAttribute("Progress_" .. key) or 0
            dataToSave["QuestCompleted_" .. key] = (player:GetAttribute("QuestCompleted_" .. key) == true) or (player:GetAttribute("Unlocked_" .. key) == true)
        end
        dataToSave.Silver = math.floor(player:GetAttribute("Silver") or 0)
        dataToSave.UnlockedDifficulties = {
            Medium = (player:GetAttribute("DifficultyUnlocked_Medium") == true),
            Hard = (player:GetAttribute("DifficultyUnlocked_Hard") == true)
        }
        dataToSave.Talents = {
            WeaponSlots = player:GetAttribute("Talent_WeaponSlots") or 0,
            PerkSlots = player:GetAttribute("Talent_PerkSlots") or 0,
            FreeRerolls = player:GetAttribute("Talent_FreeRerolls") or 0,
            Damage = player:GetAttribute("Talent_Damage") or 0,
            Health = player:GetAttribute("Talent_Health") or 0,
            Speed = player:GetAttribute("Talent_Speed") or 0,
            Magnet = player:GetAttribute("Talent_Magnet") or 0,
        }
        return dataToSave
    end

    -- Kaydı DataStore'a yazar. releaseLock = true ise kilidi bırakır (oyuncu çıkarken).
    local function writeSave(player, releaseLock)
        local userId = player.UserId
        if not LoadedPlayers[userId] then return false end

        local dataToSave = buildSaveData(player)
        local lostLock = false
        local ok, err = pcall(function()
            ProgressionDataStore:UpdateAsync(tostring(userId), function(old)
                if type(old) == "table" and old.SessionLock and old.SessionLock ~= SESSION_ID then
                    -- Başka bir sunucu kilidi devralmış: onun verisini EZME
                    lostLock = true
                    return nil
                end
                lostLock = false
                dataToSave.SessionLock = (not releaseLock) and SESSION_ID or nil
                dataToSave.SessionLockTime = os.time()
                return dataToSave
            end)
        end)

        if not ok then
            warn("[ProgressionManager] Failed to save progression for " .. player.Name .. ": " .. tostring(err))
            return false
        end
        if lostLock then
            warn("[ProgressionManager] Session lock for " .. player.Name .. " is held by another server; save skipped.")
            LoadedPlayers[userId] = nil
            return false
        end
        return true
    end

    -- Yalnızca kilidi bırakır, veriye dokunmaz (yükleme sırasında oyuncu çıkarsa)
    local function releaseLockOnly(userId)
        pcall(function()
            ProgressionDataStore:UpdateAsync(tostring(userId), function(old)
                if type(old) ~= "table" or old.SessionLock ~= SESSION_ID then return nil end
                old.SessionLock = nil
                return old
            end)
        end)
    end

    local function releasePlayer(player)
        local userId = player.UserId
        SaveScheduled[userId] = nil
        if ReleasedPlayers[userId] or not LoadedPlayers[userId] then return end
        ReleasedPlayers[userId] = true
        writeSave(player, true)
        LoadedPlayers[userId] = nil
    end

    -- Kayıt isteği: varsayılan olarak birkaç saniye birleştirilir (DataStore limitlerini korur).
    -- isSync = true ise hemen ve beklenerek kaydeder.
    function ProgressionManager._TriggerSave(player, isSync)
        if not player then return end
        local userId = player.UserId
        if not LoadedPlayers[userId] or ReleasedPlayers[userId] then return end

        if isSync then
            writeSave(player, false)
            return
        end

        if SaveScheduled[userId] then return end
        SaveScheduled[userId] = true
        task.delay(SAVE_DEBOUNCE, function()
            if not SaveScheduled[userId] then return end
            SaveScheduled[userId] = nil
            if player.Parent and LoadedPlayers[userId] and not ReleasedPlayers[userId] then
                writeSave(player, false)
            end
        end)
    end

    -- Load player progression
    function ProgressionManager.Load(player)
        local userId = player.UserId
        ReleasedPlayers[userId] = nil
        LoadedPlayers[userId] = nil

        local savedData = nil
        local loaded = false
        for attempt = 1, LOAD_ATTEMPTS do
            if not player.Parent then return end
            local lockedByOther = false
            local ok, err = pcall(function()
                ProgressionDataStore:UpdateAsync(tostring(userId), function(old)
                    local now = os.time()
                    local isLastAttempt = attempt >= LOAD_ATTEMPTS
                    if type(old) == "table" and old.SessionLock and old.SessionLock ~= SESSION_ID
                        and (now - (tonumber(old.SessionLockTime) or 0)) < LOCK_STALE_SECONDS
                        and not isLastAttempt then
                        -- Önceki sunucu (lobi/oyun) henüz son kaydını bitirmedi: bekle
                        lockedByOther = true
                        return nil
                    end
                    lockedByOther = false
                    local data = (type(old) == "table") and old or {}
                    data.SessionLock = SESSION_ID
                    data.SessionLockTime = now
                    savedData = data
                    return data
                end)
            end)

            if ok and not lockedByOther then
                loaded = true
                break
            end
            if not ok then
                warn(string.format("[ProgressionManager] Load attempt %d failed for %s: %s", attempt, player.Name, tostring(err)))
                -- Studio'da DataStore erişimi kapalıysa boşuna bekleme
                if RunService:IsStudio() then break end
            end
            task.wait(LOAD_RETRY_DELAY)
        end

        if loaded and not player.Parent then
            -- Oyuncu yükleme sırasında çıktı: aldığımız kilidi geri bırak
            releaseLockOnly(userId)
            return
        end

        if loaded then
            LoadedPlayers[userId] = true
        else
            -- KRİTİK: Yükleme başarısız. Boş veriyle oynatıp kaydedersek gerçek veriyi sileriz.
            warn("[ProgressionManager] Could not load progression for " .. player.Name .. ". Saving is DISABLED for this session.")
            player:SetAttribute("ProgressionLoadFailed", true)
            if not RunService:IsStudio() then
                player:Kick("We couldn't load your saved data. Please rejoin in a minute - your progress is safe.")
                return
            end
        end

        local unlockedTable = {}
        if type(savedData) == "table" then
            unlockedTable = savedData
        end

        -- Set attributes on the player for replication and ease of use
        for key, questData in pairs(ProgressionManager.Quests) do
            local isUnlocked = unlockedTable[key] == true
            player:SetAttribute("Unlocked_" .. key, isUnlocked)
            
            local progress = unlockedTable["Progress_" .. key] or 0
            player:SetAttribute("Progress_" .. key, progress)
            
            if isUnlocked or progress >= questData.Target or unlockedTable["QuestCompleted_" .. key] == true then
                player:SetAttribute("QuestCompleted_" .. key, true)
            end
        end

        -- Load persistent Silver
        local savedSilver = tonumber(unlockedTable.Silver) or 0
        player:SetAttribute("Silver", math.floor(savedSilver))

        -- Load unlocked difficulty modes (Easy is always unlocked; Medium/Normal and Hard require beating previous difficulty)
        local diffTable = (type(unlockedTable.UnlockedDifficulties) == "table") and unlockedTable.UnlockedDifficulties or {}
        player:SetAttribute("DifficultyUnlocked_Easy", true)
        player:SetAttribute("DifficultyUnlocked_Medium", diffTable.Medium == true)
        player:SetAttribute("DifficultyUnlocked_Hard", diffTable.Hard == true)

        -- Load permanent Talents / Shop Upgrades
        local talents = (type(unlockedTable.Talents) == "table") and unlockedTable.Talents or {}
        player:SetAttribute("Talent_WeaponSlots", tonumber(talents.WeaponSlots) or 0)
        player:SetAttribute("Talent_PerkSlots", tonumber(talents.PerkSlots) or 0)
        player:SetAttribute("Talent_FreeRerolls", tonumber(talents.FreeRerolls) or 0)
        player:SetAttribute("Talent_Damage", tonumber(talents.Damage) or 0)
        player:SetAttribute("Talent_Health", tonumber(talents.Health) or 0)
        player:SetAttribute("Talent_Speed", tonumber(talents.Speed) or 0)
        player:SetAttribute("Talent_Magnet", tonumber(talents.Magnet) or 0)
        player:SetAttribute("ProgressionLoaded", true)
    end
    
    -- Update progress towards a quest
    function ProgressionManager.UpdateProgress(player, upgradeKey, value)
        local quest = ProgressionManager.Quests[upgradeKey]
        if not quest then return end
        if player:GetAttribute("Unlocked_" .. upgradeKey) then return end -- Already unlocked
        
        -- Yuvarlama işlemi (100.5 gibi küsuratlı damage'leri tam sayı yap)
        if upgradeKey ~= "Lifesteal" then
            value = math.floor(value)
        end
        
        local currentMax = player:GetAttribute("Progress_" .. upgradeKey) or 0
        if value > currentMax then
            local newMax = math.min(value, quest.Target)
            player:SetAttribute("Progress_" .. upgradeKey, newMax)
            
            if newMax >= quest.Target then
                ProgressionManager.CompleteQuest(player, upgradeKey)
            end
        end
    end
    
    -- Accumulate progress towards a quest (e.g. cumulative damage taken)
    function ProgressionManager.AddProgress(player, upgradeKey, amount)
        local quest = ProgressionManager.Quests[upgradeKey]
        if not quest then return end
        if player:GetAttribute("Unlocked_" .. upgradeKey) then return end -- Already unlocked
        
        amount = math.floor(amount or 0)
        if amount <= 0 then return end
        
        local current = player:GetAttribute("Progress_" .. upgradeKey) or 0
        local newProgress = math.min(current + amount, quest.Target)
        player:SetAttribute("Progress_" .. upgradeKey, newProgress)
        
        if newProgress >= quest.Target then
            ProgressionManager.CompleteQuest(player, upgradeKey)
        end
    end

    -- Complete a quest (notifies player and makes it purchasable with Silver in Index)
    function ProgressionManager.CompleteQuest(player, upgradeKey)
        local quest = ProgressionManager.Quests[upgradeKey]
        if not quest then return end
        if player:GetAttribute("QuestCompleted_" .. upgradeKey) then return end
        
        player:SetAttribute("QuestCompleted_" .. upgradeKey, true)
        player:SetAttribute("NewlyCompletedQuest_" .. upgradeKey, true)
        player:SetAttribute("Progress_" .. upgradeKey, quest.Target)
        
        -- Fire notification event so player knows quest is done
        local Events = ReplicatedStorage:FindFirstChild("Events")
        local QuestUnlocked = Events and Events:FindFirstChild("QuestUnlocked")
        if QuestUnlocked then
            QuestUnlocked:FireClient(player, upgradeKey)
        end
        
        ProgressionManager._TriggerSave(player)
    end
    
    -- Direct unlock (for admin/developer or backwards compatibility)
    function ProgressionManager.Unlock(player, upgradeKey)
        if not ProgressionManager.Quests[upgradeKey] then return end
        if player:GetAttribute("Unlocked_" .. upgradeKey) then return end
        
        player:SetAttribute("Unlocked_" .. upgradeKey, true)
        player:SetAttribute("QuestCompleted_" .. upgradeKey, true)
        player:SetAttribute("Progress_" .. upgradeKey, ProgressionManager.Quests[upgradeKey].Target)
        player:SetAttribute("NewlyUnlocked_" .. upgradeKey, true)
        
        local Events = ReplicatedStorage:FindFirstChild("Events")
        local QuestUnlocked = Events and Events:FindFirstChild("QuestUnlocked")
        if QuestUnlocked then
            QuestUnlocked:FireClient(player, upgradeKey)
        end
        
        ProgressionManager._TriggerSave(player)
    end

    -- Buy/Unlock an Index item using Silver (after quest requirement is met)
    function ProgressionManager.UnlockIndexItem(player, upgradeKey)
        if not player or not upgradeKey then return false, "No player or key" end
        local quest = ProgressionManager.Quests[upgradeKey]
        if not quest then return false, "Quest not found" end
        
        if player:GetAttribute("Unlocked_" .. upgradeKey) == true then
            return false, "Already unlocked"
        end
        
        local currentProgress = player:GetAttribute("Progress_" .. upgradeKey) or 0
        local isCompleted = (currentProgress >= quest.Target) or (player:GetAttribute("QuestCompleted_" .. upgradeKey) == true)
        if not isCompleted then
            return false, "Quest requirement not met"
        end
        
        local cost = quest.UnlockCost or 25
        local currentSilver = ProgressionManager.GetSilver(player)
        if currentSilver < cost then
            return false, "Not enough silver"
        end
        
        local success, remaining = ProgressionManager.SpendSilver(player, cost)
        if not success then
            return false, "Not enough silver"
        end
        
        player:SetAttribute("Unlocked_" .. upgradeKey, true)
        player:SetAttribute("Progress_" .. upgradeKey, quest.Target)
        player:SetAttribute("QuestCompleted_" .. upgradeKey, true)
        
        ProgressionManager._TriggerSave(player)
        return true, remaining
    end

    -- Add persistent Silver to player
    function ProgressionManager.AddSilver(player, amount)
        if not player then return 0 end
        amount = math.floor(amount or 0)
        if amount == 0 then return ProgressionManager.GetSilver(player) end

        local current = ProgressionManager.GetSilver(player)
        local updated = math.max(0, current + amount)
        player:SetAttribute("Silver", updated)
        ProgressionManager._TriggerSave(player)
        return updated
    end

    -- Spend persistent Silver (returns true if successful)
    function ProgressionManager.SpendSilver(player, amount)
        if not player then return false, 0 end
        amount = math.max(0, math.floor(amount or 0))
        local current = ProgressionManager.GetSilver(player)
        if current >= amount then
            local updated = current - amount
            player:SetAttribute("Silver", updated)
            ProgressionManager._TriggerSave(player)
            return true, updated
        end
        return false, current
    end

    -- Buy permanent upgrade from Silver Shop
    function ProgressionManager.BuyUpgrade(player, upgradeKey)
        if not player then return false, "No player" end
        local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
        local upgrade = ShopConfig.Upgrades[upgradeKey]
        if not upgrade then return false, "Upgrade not found" end
        
        local currentLevel = player:GetAttribute(upgrade.Attribute) or 0
        if currentLevel >= upgrade.MaxLevel then
            return false, "Already max level"
        end
        
        local nextLevel = currentLevel + 1
        local cost = upgrade.Costs[nextLevel]
        if not cost then return false, "Invalid cost" end
        
        local success, remaining = ProgressionManager.SpendSilver(player, cost)
        if not success then
            return false, "Not enough silver"
        end
        
        player:SetAttribute(upgrade.Attribute, nextLevel)
        ProgressionManager._TriggerSave(player)
        return true, nextLevel, remaining
    end

    -- Refund all permanent upgrades from Silver Shop and return 100% of spent silver
    function ProgressionManager.RefundAllUpgrades(player)
        if not player then return false, "No player", 0 end
        local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)

        local totalRefund = 0
        local attributesToReset = {}

        for _, upgrade in pairs(ShopConfig.Upgrades) do
            local currentLevel = player:GetAttribute(upgrade.Attribute) or 0
            if currentLevel > 0 then
                for lvl = 1, currentLevel do
                    local cost = upgrade.Costs and upgrade.Costs[lvl] or 0
                    totalRefund = totalRefund + cost
                end
                table.insert(attributesToReset, upgrade.Attribute)
            end
        end

        if totalRefund <= 0 and #attributesToReset == 0 then
            return false, "No upgrades to refund", 0
        end

        -- Reset all talent attributes to 0
        for _, attr in ipairs(attributesToReset) do
            player:SetAttribute(attr, 0)
        end

        -- Add refunded silver to balance
        local newSilver = ProgressionManager.AddSilver(player, totalRefund)
        ProgressionManager._TriggerSave(player)

        return true, totalRefund, newSilver
    end

    -- İlerlemeyi / Index kayıtlarını tamamen sıfırla
    function ProgressionManager.Reset(player)
        for key in pairs(ProgressionManager.Quests) do
            player:SetAttribute("Unlocked_" .. key, false)
            player:SetAttribute("Progress_" .. key, 0)
            player:SetAttribute("NewlyUnlocked_" .. key, nil)
            player:SetAttribute("QuestCompleted_" .. key, nil)
        end
        player:SetAttribute("Silver", 0)

        player:SetAttribute("DifficultyUnlocked_Easy", true)
        player:SetAttribute("DifficultyUnlocked_Medium", false)
        player:SetAttribute("DifficultyUnlocked_Hard", false)

        player:SetAttribute("Talent_WeaponSlots", 0)
        player:SetAttribute("Talent_PerkSlots", 0)
        player:SetAttribute("Talent_FreeRerolls", 0)
        player:SetAttribute("Talent_Damage", 0)
        player:SetAttribute("Talent_Health", 0)
        player:SetAttribute("Talent_Speed", 0)
        player:SetAttribute("Talent_Magnet", 0)

        -- Sıfırlanmış veriyi hemen kaydet (kilit korunur; oturumun geri kalanında kayıt normal devam eder)
        SaveScheduled[player.UserId] = nil
        return writeSave(player, false)
    end

    -- ====================================================================
    -- ADMIN KOMUTU: /silver [oyuncu] [miktar]
    -- ====================================================================
    -- NOT: Grup oyunlarında game.CreatorId GRUP ID'sidir. Bu yüzden UserId == CreatorId
    -- karşılaştırması YALNIZCA oyun bir kullanıcıya aitse yapılır (aksi halde UserId'si
    -- grup ID'sine denk gelen rastgele bir oyuncu admin olurdu).
    local function isPlayerAdmin(player)
        if not player then return false end
        if RunService:IsStudio() then return true end
        if game.CreatorType == Enum.CreatorType.User then
            if player.UserId == game.CreatorId then return true end
        elseif game.CreatorType == Enum.CreatorType.Group then
            local success, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
            if success and rank >= 250 then return true end
        end
        if player:GetAttribute("IsAdmin") == true then return true end
        return false
    end
    ProgressionManager.IsAdmin = isPlayerAdmin

    local function findPlayer(query, senderPlayer)
        if not query or query == "" then return nil end
        local lowerQuery = string.lower(query)
        if lowerQuery == "me" or lowerQuery == "ben" or lowerQuery == "self" then
            return senderPlayer
        end

        local allPlayers = Players:GetPlayers()
        -- 1. Tam Eşleşme (Username)
        for _, p in ipairs(allPlayers) do
            if string.lower(p.Name) == lowerQuery then
                return p
            end
        end
        -- 2. Tam Eşleşme (DisplayName)
        for _, p in ipairs(allPlayers) do
            if string.lower(p.DisplayName) == lowerQuery then
                return p
            end
        end
        -- 3. Ön Ek (Prefix) Eşleşme
        for _, p in ipairs(allPlayers) do
            if string.sub(string.lower(p.Name), 1, #lowerQuery) == lowerQuery then
                return p
            end
            if string.sub(string.lower(p.DisplayName), 1, #lowerQuery) == lowerQuery then
                return p
            end
        end
        -- 4. İçerir (Substring) Eşleşme
        for _, p in ipairs(allPlayers) do
            if string.find(string.lower(p.Name), lowerQuery, 1, true) or string.find(string.lower(p.DisplayName), lowerQuery, 1, true) then
                return p
            end
        end
        return nil
    end

    local lastCommandDebounce = {}
    local function handleSilverCommand(senderPlayer, rawMessage)
        if not senderPlayer or not rawMessage then return end
        
        -- Admin yetki kontrolü
        if not isPlayerAdmin(senderPlayer) then return end
        
        -- Normalize: '+' işaretlerini ve fazla boşlukları temizle
        local clean = string.gsub(rawMessage, "%+", " ")
        clean = string.gsub(clean, "%s+", " ")
        clean = string.gsub(clean, "^%s*(.-)%s*$", "%1")
        
        local parts = string.split(clean, " ")
        local cmd = string.lower(parts[1] or "")
        if cmd ~= "/silver" and cmd ~= "/givesilver" then return end
        
        -- Çift tetiklenmeyi engelle (TextChatService + Chatted)
        local now = os.clock()
        if lastCommandDebounce[senderPlayer.UserId] and (now - lastCommandDebounce[senderPlayer.UserId]) < 0.25 then
            return
        end
        lastCommandDebounce[senderPlayer.UserId] = now
        
        table.remove(parts, 1)
        if #parts == 0 then
            warn("[Admin /silver] Kullanım: /silver <miktar> veya /silver <oyuncu> <miktar>")
            return
        end
        
        local targetPlayer = nil
        local amount = nil
        
        if #parts == 1 then
            -- /silver 100 -> Komutu yazan oyuncuya ver
            amount = tonumber(parts[1])
            if amount then
                targetPlayer = senderPlayer
            end
        else
            -- 2 veya daha fazla argüman: son veya ilk argüman sayı olabilir
            local lastNum = tonumber(parts[#parts])
            local firstNum = tonumber(parts[1])
            
            if lastNum then
                amount = lastNum
                local q = table.concat(parts, " ", 1, #parts - 1)
                targetPlayer = findPlayer(q, senderPlayer)
            elseif firstNum then
                amount = firstNum
                local q = table.concat(parts, " ", 2, #parts)
                targetPlayer = findPlayer(q, senderPlayer)
            end
        end
        
        if not amount then
            warn("[Admin /silver] Geçersiz miktar belirtildi: " .. tostring(rawMessage))
            return
        end
        
        if not targetPlayer then
            warn("[Admin /silver] Hedef oyuncu bulunamadı: " .. tostring(rawMessage))
            return
        end
        
        local updated = ProgressionManager.AddSilver(targetPlayer, amount)
        print(string.format("[Admin /silver] %s oyuncusuna %d Gümüş eklendi. (Yeni Bakiye: %d) | Yetkili: %s",
            targetPlayer.Name, amount, updated, senderPlayer.Name))
    end

    -- Oyuncular için Chatted dinleyicisi bağla
    local function setupPlayerChat(player)
        player.Chatted:Connect(function(msg)
            handleSilverCommand(player, msg)
        end)
    end

    Players.PlayerAdded:Connect(setupPlayerChat)
    for _, p in ipairs(Players:GetPlayers()) do
        setupPlayerChat(p)
    end

    -- Modern Roblox TextChatService TextChatCommand desteği
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        local textCommands = TextChatService:FindFirstChild("TextChatCommands")
        if not textCommands then
            textCommands = Instance.new("Folder")
            textCommands.Name = "TextChatCommands"
            textCommands.Parent = TextChatService
        end
        
        local silverCmd = textCommands:FindFirstChild("AdminSilverCommand") or Instance.new("TextChatCommand")
        silverCmd.Name = "AdminSilverCommand"
        silverCmd.PrimaryAlias = "/silver"
        silverCmd.SecondaryAlias = "/givesilver"
        silverCmd.Parent = textCommands
        silverCmd.Triggered:Connect(function(textSource, rawText)
            local p = Players:GetPlayerByUserId(textSource.UserId)
            if p then
                handleSilverCommand(p, rawText)
            end
        end)
    end)

    -- RemoteFunction for unlocking Index items with Silver
    local Events = ReplicatedStorage:FindFirstChild("Events")
    if not Events then
        Events = Instance.new("Folder")
        Events.Name = "Events"
        Events.Parent = ReplicatedStorage
    end
    local UnlockIndexItem = Events:FindFirstChild("UnlockIndexItem") or Instance.new("RemoteFunction")
    UnlockIndexItem.Name = "UnlockIndexItem"
    UnlockIndexItem.Parent = Events
    UnlockIndexItem.OnServerInvoke = function(player, itemKey)
        return ProgressionManager.UnlockIndexItem(player, itemKey)
    end

    -- Oyuncu oyundan çıktığında kaydet ve kilidi bırak (sonraki sunucu hemen yükleyebilsin)
    Players.PlayerRemoving:Connect(function(player)
        releasePlayer(player)
    end)

    -- Periyodik otomatik kayıt: veriyi korur ve session lock'u taze tutar
    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_INTERVAL)
            for _, player in ipairs(Players:GetPlayers()) do
                if LoadedPlayers[player.UserId] and not ReleasedPlayers[player.UserId] then
                    SaveScheduled[player.UserId] = nil
                    task.spawn(writeSave, player, false)
                end
            end
        end
    end)

    -- Sunucu/Studio kapandığında aktif tüm oyuncuları paralel kaydet ve bitmesini bekle
    game:BindToClose(function()
        local pending = 0
        for _, player in ipairs(Players:GetPlayers()) do
            pending = pending + 1
            task.spawn(function()
                releasePlayer(player)
                pending = pending - 1
            end)
        end
        local start = os.clock()
        while pending > 0 and os.clock() - start < 25 do
            task.wait(0.1)
        end
    end)
end

return ProgressionManager
