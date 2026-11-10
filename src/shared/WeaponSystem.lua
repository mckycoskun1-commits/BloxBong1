local WeaponSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyConfig"))

local function hasEngineerPlayer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p:GetAttribute("SelectedClassId") == "Engineer" or p:GetAttribute("HasTurret") == true then
            return true
        end
    end
    return false
end

function WeaponSystem.DealDamage(target, damage, isCrit)
    -- Block damage if target is still emerging (less than 70% complete)
    local isEmerging = target:GetAttribute("IsEmerging")
    if isEmerging then
        local spawnTime = target:GetAttribute("SpawnTime")
        local duration = target:GetAttribute("EmergingDuration") or 1.0
        if spawnTime and (os.clock() - spawnTime) < (duration * 0.70) then
            return false
        end
    end

    local health = target:FindFirstChild("Health")
    if health then
        health.Value = health.Value - damage
        target:SetAttribute("LastDamageTime", os.clock())
        
        -- Hasar Göstergesi (Client'lara sinyal gönder)
        local Events = ReplicatedStorage:FindFirstChild("Events")
        if Events and Events:FindFirstChild("ShowDamage") then
            Events.ShowDamage:FireAllClients(target:GetPivot().Position, damage, isCrit)
        end
        
        -- Görsel geri bildirim (Kısa süreli beyaz parlama - Canavar için canının %35 veya daha fazla hasar yemesi gerekir)
        local shouldFlash = true
        local maxHealth = target:GetAttribute("MaxHealth")
        if maxHealth then
            shouldFlash = damage >= (maxHealth * 0.35)
        end
        
        if shouldFlash then
            local partsToColor = {}
            if target:IsA("BasePart") then
                table.insert(partsToColor, target)
            elseif target:IsA("Model") then
                for _, child in ipairs(target:GetDescendants()) do
                    if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
                        table.insert(partsToColor, child)
                    end
                end
            end
            
            for _, part in ipairs(partsToColor) do
                local originalColor = part:GetAttribute("OriginalColor")
                if not originalColor then
                    part:SetAttribute("OriginalColor", part.Color)
                end
                local flashCount = (part:GetAttribute("FlashCount") or 0) + 1
                part:SetAttribute("FlashCount", flashCount)
                part.Color = Color3.new(1, 1, 1)
            end
            
            task.delay(0.1, function()
                for _, part in ipairs(partsToColor) do
                    if part and part.Parent then
                        local flashCount = part:GetAttribute("FlashCount") or 0
                        flashCount = flashCount - 1
                        if flashCount <= 0 then
                            part:SetAttribute("FlashCount", nil)
                            local originalColor = part:GetAttribute("OriginalColor")
                            if originalColor then
                                part.Color = originalColor
                                part:SetAttribute("OriginalColor", nil)
                            end
                        else
                            part:SetAttribute("FlashCount", flashCount)
                        end
                    end
                end
            end)
        end
        
        if health.Value <= 0 then
            local isBoss = target:GetAttribute("IsBoss")
            
            -- XP Gem Doğur
            local Events = ReplicatedStorage:FindFirstChild("Events")
            if Events then
                if isBoss and Events:FindFirstChild("BossDefeated") then
                    Events.BossDefeated:Fire(target:GetPivot().Position)
                end
                
                if Events:FindFirstChild("SpawnGemEvent") then
                    local enemyType = target:GetAttribute("EnemyType")
                    local enemyStats = enemyType and EnemyConfig.Enemies[enemyType]
                    
                    if enemyStats then
                        local gemType = enemyStats.XPDrop or "Basic"
                        local xpVal = 0
                        if enemyStats.MinXP and enemyStats.MaxXP then
                            xpVal = math.random(enemyStats.MinXP, enemyStats.MaxXP)
                        else
                            local stats = EnemyConfig.Gems[gemType]
                            xpVal = stats and stats.Value or 2
                        end
                        
                        -- Canavarın Can Artış Oranını Hesapla (MaxHealth / BaseHealth)
                        local baseHealth = enemyStats.Health or 1
                        local maxHealth = target:GetAttribute("MaxHealth") or baseHealth
                        local healthScale = math.max(1, maxHealth / baseHealth)
                        
                        -- XP Miktarını Can Artışına Orantılı Olarak Büyüt!
                        xpVal = math.floor(xpVal * healthScale + 0.5)
                        
                        -- Normal (basic) canavarlar için XP düşme olasılığı (%45 olasılıkla düşsün)
                        if not isBoss then
                            if math.random() > 0.45 then
                                xpVal = 0
                            end
                        end
                        
                        if xpVal > 0 then
                            Events.SpawnGemEvent:Fire(target:GetPivot().Position, gemType, xpVal)
                        end
                        
                        if enemyStats.CoinDrop and enemyStats.CoinDrop > 0 then
                            local coinVal = enemyStats.CoinDrop
                            
                            -- Altın Miktarını Can Artışına Orantılı Olarak Büyüt!
                            coinVal = math.floor(coinVal * healthScale + 0.5)
                            
                            -- Normal (basic) canavarlar için altın düşme olasılığı (%35 olasılık)
                            if not isBoss then
                                if math.random() > 0.35 then
                                    coinVal = 0
                                end
                            end
                            
                            if coinVal > 0 then
                                -- Coin için küçük bir ofset ekle ki üst üste binmesin
                                local coinPos = target:GetPivot().Position + Vector3.new(math.random(-1,1), 0, math.random(-1,1))
                                Events.SpawnGemEvent:Fire(coinPos, "Coin", coinVal)
                            end
                        end
                        
                        -- Vacuum/Magnet Drop Chance: 5% for bosses, 0.5% for normal enemies
                        local vacuumChance = isBoss and 0.05 or 0.005
                        if math.random() < vacuumChance then
                            local vacuumPos = target:GetPivot().Position + Vector3.new(math.random(-1,1), 1, math.random(-1,1))
                            Events.SpawnGemEvent:Fire(vacuumPos, "Vacuum")
                        end

                        -- Scrap (Hurda) Drop Chance: Sadece oyunda Engineer varsa düşer!
                        if hasEngineerPlayer() then
                            local scrapChance = isBoss and 1.0 or 0.18
                            if math.random() < scrapChance then
                                local scrapVal = isBoss and math.random(30, 50) or math.random(5, 10)
                                local scrapPos = target:GetPivot().Position + Vector3.new(math.random(-1,1), 0.2, math.random(-1,1))
                                Events.SpawnGemEvent:Fire(scrapPos, "Scrap", scrapVal)
                            end
                        end
                        
                        -- Luck Scroll Drop: Her canavardan rastgele 0.1 (10%) ihtimalle görseliyle yere düşer
                        local luckScrollChance = 0.10
                        if math.random() < luckScrollChance then
                            local luckPos = target:GetPivot().Position + Vector3.new(math.random(-1,1), 0.5, math.random(-1,1))
                            Events.SpawnGemEvent:Fire(luckPos, "LuckScroll")
                        end
                    end
                end
            end
            
            target:Destroy()
            return true -- Öldü
        end
    end
    return false -- Yaşıyor
end

return WeaponSystem
