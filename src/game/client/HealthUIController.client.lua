local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Oyun içindeyken görev sekmesi/paneli gösterilmez (varsa temizle)
local existingQuestUI = PlayerGui:FindFirstChild("QuestUI")
if existingQuestUI then
    existingQuestUI:Destroy()
end
local Events = ReplicatedStorage:WaitForChild("Events")
local UpdateHealthEvent = Events:WaitForChild("UpdateHealth")
local UpdateXPEvent = Events:WaitForChild("UpdateXP")
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ItemConfig"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIConfig"))
local CharacterUIConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterUIConfig"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ToggleWeaponsEvent = Events:FindFirstChild("ToggleWeapons") or Instance.new("RemoteEvent", Events)
local weaponDisableMode = false

--[[ Local Font Override to Arcade for Retro Rogue-like Aesthetic
local globalEnum = Enum
local Enum = {
	Font = setmetatable({
		FredokaOne = globalEnum.Font.Arcade,
		Gotham = globalEnum.Font.Arcade,
		GothamBold = globalEnum.Font.Arcade,
		GothamMedium = globalEnum.Font.Arcade,
		GothamBlack = globalEnum.Font.Arcade,
	}, {
		__index = globalEnum.Font
	})
}
setmetatable(Enum, {
	__index = globalEnum
}) ]]--


local function applyUIScale(screenGui)
    local uiScale = Instance.new("UIScale")
    uiScale.Parent = screenGui
    local function updateScale()
        local viewport = workspace.CurrentCamera.ViewportSize
        local scale = math.min(viewport.X / 1600, viewport.Y / 900)
        uiScale.Scale = math.clamp(scale, 0.5, 2)
    end
    local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    updateScale()
    screenGui.Destroying:Connect(function()
        if viewportConnection then
            viewportConnection:Disconnect()
        end
    end)
end

local tooltipFrame = nil
local tooltipTitle = nil
local tooltipStatsContainer = nil
local updateActiveItemsUI = nil

local function createTooltipUI(parent)
    local existing = PlayerGui:FindFirstChild("TooltipGui")
    if existing then existing:Destroy() end

    local tooltipGui = Instance.new("ScreenGui")
    tooltipGui.Name = "TooltipGui"
    tooltipGui.DisplayOrder = 999
    tooltipGui.IgnoreGuiInset = true
    tooltipGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    tooltipGui.Parent = PlayerGui

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = tooltipGui
    local function updateScale()
        local viewport = workspace.CurrentCamera.ViewportSize
        local scale = math.min(viewport.X / 1600, viewport.Y / 900)
        uiScale.Scale = math.clamp(scale, 0.5, 2)
    end
    local viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    updateScale()
    tooltipGui.Destroying:Connect(function()
        if viewportConnection then
            viewportConnection:Disconnect()
        end
    end)

    tooltipFrame = Instance.new("Frame")
    tooltipFrame.Name = "SlotTooltip"
    tooltipFrame.Size = UDim2.new(0, 240, 0, 90)
    tooltipFrame.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
    tooltipFrame.BorderSizePixel = 0
    tooltipFrame.ZIndex = 1000
    tooltipFrame.Visible = false
    tooltipFrame.Parent = tooltipGui

    Instance.new("UICorner", tooltipFrame).CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke", tooltipFrame)
    stroke.Name = "Stroke"
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(45, 52, 70)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    -- Header Frame (No Badge, Clean In-Game Font Title)
    local headerFrame = Instance.new("Frame", tooltipFrame)
    headerFrame.Name = "HeaderFrame"
    headerFrame.Size = UDim2.new(1, -24, 0, 24)
    headerFrame.Position = UDim2.new(0, 12, 0, 10)
    headerFrame.BackgroundTransparency = 1
    headerFrame.ZIndex = 1010

    -- Item Title (Uses UIConfig.General.Font)
    tooltipTitle = Instance.new("TextLabel", headerFrame)
    tooltipTitle.Name = "Title"
    tooltipTitle.Size = UDim2.new(1, 0, 1, 0)
    tooltipTitle.Position = UDim2.new(0, 0, 0, 0)
    tooltipTitle.BackgroundTransparency = 1
    tooltipTitle.Text = "ITEM NAME"
    tooltipTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltipTitle.Font = UIConfig.General.Font or Enum.Font.Arcade
    tooltipTitle.TextSize = 18
    tooltipTitle.TextXAlignment = Enum.TextXAlignment.Left
    tooltipTitle.TextTruncate = Enum.TextTruncate.AtEnd
    tooltipTitle.ZIndex = 1011

    -- Separator
    local separator = Instance.new("Frame", tooltipFrame)
    separator.Name = "Separator"
    separator.Size = UDim2.new(1, -24, 0, 1)
    separator.Position = UDim2.new(0, 12, 0, 38)
    separator.BackgroundColor3 = Color3.fromRGB(38, 44, 60)
    separator.BorderSizePixel = 0
    separator.ZIndex = 1010

    -- Stats Container
    tooltipStatsContainer = Instance.new("Frame", tooltipFrame)
    tooltipStatsContainer.Name = "StatsContainer"
    tooltipStatsContainer.Size = UDim2.new(1, -24, 0, 0)
    tooltipStatsContainer.Position = UDim2.new(0, 12, 0, 46)
    tooltipStatsContainer.BackgroundTransparency = 1
    tooltipStatsContainer.ZIndex = 1010

    local statsLayout = Instance.new("UIListLayout", tooltipStatsContainer)
    statsLayout.FillDirection = Enum.FillDirection.Vertical
    statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statsLayout.Padding = UDim.new(0, 4)
end

local function showTooltip(key, data)
    if not tooltipFrame or not key or not data then return end
    local base = UpgradeConfig.Upgrades[key] or ItemConfig.Items[key]
    if not base then return end

    -- Set Title
    tooltipTitle.Text = base.Title or base.DisplayName or key

    -- Dynamic Stroke Accent
    local stroke = tooltipFrame:FindFirstChild("Stroke")
    if ItemConfig.Items[key] then
        if stroke then stroke.Color = Color3.fromRGB(59, 130, 246) end
    elseif base.Type == "Weapon" then
        if stroke then stroke.Color = Color3.fromRGB(245, 158, 11) end
    elseif base.Type == "Perk" then
        if stroke then stroke.Color = Color3.fromRGB(52, 211, 153) end
    else
        if stroke then stroke.Color = Color3.fromRGB(75, 85, 99) end
    end

    -- Clear previous stat rows
    for _, child in ipairs(tooltipStatsContainer:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    -- Helper to add structured key-value stat row (Uses UIConfig.General.Font)
    local rowCount = 0
    local function addStatRow(labelStr, valStr, labelColorHex, valColorHex)
        rowCount = rowCount + 1
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundTransparency = 1
        row.LayoutOrder = rowCount
        row.ZIndex = 1011
        row.Parent = tooltipStatsContainer

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelStr
        lbl.TextColor3 = Color3.fromHex(labelColorHex or "#94a3b8")
        lbl.Font = UIConfig.General.Font or Enum.Font.Arcade
        lbl.TextSize = 15
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 1011

        local val = Instance.new("TextLabel", row)
        val.Size = UDim2.new(0.45, 0, 1, 0)
        val.Position = UDim2.new(0.55, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = valStr
        val.TextColor3 = Color3.fromHex(valColorHex or "#f8fafc")
        val.Font = UIConfig.General.Font or Enum.Font.Arcade
        val.TextSize = 19
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.ZIndex = 1011
    end

    local function addDescRow(descText)
        rowCount = rowCount + 1
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 36)
        lbl.BackgroundTransparency = 1
        lbl.Text = descText
        lbl.TextColor3 = Color3.fromRGB(203, 213, 225)
        lbl.Font = UIConfig.General.Font or Enum.Font.Arcade
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Top
        lbl.TextWrapped = true
        lbl.RichText = true
        lbl.LayoutOrder = rowCount
        lbl.ZIndex = 1011
        lbl.Parent = tooltipStatsContainer
    end

    local function fmtCount(val)
        local n = val or 1
        if math.abs(n - math.floor(n)) > 0.001 then
            return string.format("%.1f", n)
        end
        return string.format("%d", math.floor(n))
    end

    if ItemConfig.Items[key] then
        local stack = data.Items and data.Items[key] or 0
        local rarityHex = "#94a3b8"
        if base.Rarity == "Uncommon" then rarityHex = "#4ade80"
        elseif base.Rarity == "Rare" then rarityHex = "#60a5fa"
        elseif base.Rarity == "Epic" then rarityHex = "#c084fc" end

        addStatRow("Rarity", base.Rarity or "Common", "#94a3b8", rarityHex)
        addStatRow("Stacks", tostring(stack), "#94a3b8", "#38bdf8")
        if base.Description then
            addDescRow(base.Description)
        end
    elseif key == "BulletWeapon" then
        addStatRow("Damage", string.format("%.0f", data.BulletDamage * data.DamageMultiplier), "#94a3b8", "#fb923c")
        addStatRow("Count", fmtCount(data.BulletCount), "#94a3b8", "#38bdf8")
        if data.BulletSpeedMultiplier and data.BulletSpeedMultiplier > 1.001 then
            addStatRow("Projectile Speed", string.format("+%.0f%%", (data.BulletSpeedMultiplier - 1) * 100), "#94a3b8", "#38bdf8")
        end
        if data.BulletCritChance and data.BulletCritChance > 0.001 then
            addStatRow("Crit Chance", string.format("+%.0f%%", math.floor(data.BulletCritChance * 100 + 0.5)), "#94a3b8", "#38bdf8")
        end
    elseif key == "FireballWeapon" then
        addStatRow("Damage", string.format("%.0f", data.FireballDamage * data.DamageMultiplier), "#94a3b8", "#fb923c")
        addStatRow("Count", fmtCount(data.FireballCount), "#94a3b8", "#38bdf8")
        addStatRow("Size", string.format("%.0f", data.FireballRadius), "#94a3b8", "#38bdf8")
        if data.FireballSpeedMultiplier and data.FireballSpeedMultiplier > 1.001 then
            addStatRow("Projectile Speed", string.format("+%.0f%%", (data.FireballSpeedMultiplier - 1) * 100), "#94a3b8", "#38bdf8")
        end
        if data.FireballCritChance and data.FireballCritChance > 0.001 then
            addStatRow("Crit Chance", string.format("+%.0f%%", math.floor(data.FireballCritChance * 100 + 0.5)), "#94a3b8", "#38bdf8")
        end
    elseif key == "FireTrailWeapon" then
        addStatRow("Damage", string.format("%.0f", data.FireTrailDamage * data.DamageMultiplier), "#94a3b8", "#fb923c")
        addStatRow("Trails", fmtCount(data.FireTrailCount), "#94a3b8", "#38bdf8")
        addStatRow("Size", string.format("%.0f", data.FireTrailRadius), "#94a3b8", "#38bdf8")
        if data.FireTrailDurationBonus and data.FireTrailDurationBonus > 0.001 then
            addStatRow("Duration", string.format("%.1fs", 3.0 + data.FireTrailDurationBonus), "#94a3b8", "#38bdf8")
        end
        if data.FireTrailCritChance and data.FireTrailCritChance > 0.001 then
            addStatRow("Crit Chance", string.format("+%.0f%%", math.floor(data.FireTrailCritChance * 100 + 0.5)), "#94a3b8", "#38bdf8")
        end
    elseif key == "LightningWeapon" then
        addStatRow("Damage", string.format("%.0f", data.LightningDamage * data.DamageMultiplier), "#94a3b8", "#fb923c")
        addStatRow("Count", fmtCount(data.LightningCount), "#94a3b8", "#38bdf8")
        addStatRow("Bounces", string.format("%d", math.floor((data.LightningBounces or 3) + 0.5)), "#94a3b8", "#38bdf8")
        if data.LightningCritChance and data.LightningCritChance > 0.001 then
            addStatRow("Crit Chance", string.format("+%.0f%%", math.floor(data.LightningCritChance * 100 + 0.5)), "#94a3b8", "#38bdf8")
        end
        if data.LightningRangeMultiplier and data.LightningRangeMultiplier > 1.001 then
            addStatRow("Bounce Range", string.format("+%.0f%%", (data.LightningRangeMultiplier - 1) * 100), "#94a3b8", "#38bdf8")
        end
    elseif key == "SnowballWeapon" then
        addStatRow("Damage", string.format("%.0f", data.SnowballDamage * data.DamageMultiplier), "#94a3b8", "#fb923c")
        addStatRow("Count", fmtCount(data.SnowballCount), "#94a3b8", "#38bdf8")
        addStatRow("Slow", string.format("%.0f%%", (data.SnowballSlowPct or 0.2)*100), "#94a3b8", "#38bdf8")
        addStatRow("Duration", string.format("%.1fs", data.SnowballDuration or 1.5), "#94a3b8", "#38bdf8")
        if data.SnowballSpeedMultiplier and data.SnowballSpeedMultiplier > 1.001 then
            addStatRow("Projectile Speed", string.format("+%.0f%%", (data.SnowballSpeedMultiplier - 1) * 100), "#94a3b8", "#38bdf8")
        end
        if data.SnowballCritChance and data.SnowballCritChance > 0.001 then
            addStatRow("Crit Chance", string.format("+%.0f%%", math.floor(data.SnowballCritChance * 100 + 0.5)), "#94a3b8", "#38bdf8")
        end
    elseif key == "SpikedArmorWeapon" then
        addStatRow("Damage", string.format("%.0f", (data.SpikedArmorDamage or 12) * (data.DamageMultiplier or 1)), "#94a3b8", "#fb923c")
        addStatRow("Cooldown", string.format("%.1fs", math.max(1.5, 5.0 - (data.SpikedArmorCooldownBonus or 0))), "#94a3b8", "#38bdf8")
        addStatRow("Knockback", string.format("%.1f", data.SpikedArmorKnockback or 3.0), "#94a3b8", "#38bdf8")
        if data.SpikedArmorCritChance and data.SpikedArmorCritChance > 0.001 then
            addStatRow("Crit Chance", string.format("+%.0f%%", math.floor(data.SpikedArmorCritChance * 100 + 0.5)), "#94a3b8", "#38bdf8")
        end
        if data.SpikedArmorRadiusMultiplier and data.SpikedArmorRadiusMultiplier > 1.001 then
            addStatRow("Size", string.format("+%.0f%%", (data.SpikedArmorRadiusMultiplier - 1) * 100), "#94a3b8", "#38bdf8")
        end
    elseif key == "TurretWeapon" then
        local atkSpdBonus = data.TurretAttackSpeedBonus or (data.TurretFireRate and (1.0 / data.TurretFireRate - 1.0)) or 0
        local atkSpdPct = math.floor((atkSpdBonus * 100) + 0.5)
        addStatRow("Damage", string.format("%.0f", (data.TurretDamage or 16) * (data.DamageMultiplier or 1)), "#94a3b8", "#fb923c")
        addStatRow("Attack Speed", string.format("+%.0f%%", math.max(0, atkSpdPct)), "#94a3b8", "#38bdf8")
        addStatRow("Duration", string.format("%.0fs", data.TurretDuration or 25), "#94a3b8", "#38bdf8")
        addStatRow("Scrap Cost", string.format("%.0f", data.TurretCost or 100), "#94a3b8", "#facc15")
        if data.TurretCritChance and data.TurretCritChance > 0.001 then
            addStatRow("Crit Chance", string.format("+%.0f%%", math.floor(data.TurretCritChance * 100 + 0.5)), "#94a3b8", "#38bdf8")
        end
        if data.TurretRange and data.TurretRange > 40.5 then
            addStatRow("Range", string.format("%.0f", data.TurretRange), "#94a3b8", "#38bdf8")
        end
    elseif base.Type == "Perk" then
        local bonusText = ""
        if key == "Damage" then bonusText = string.format("+%.0f%% Damage", (data.DamageMultiplier - 1) * 100)
        elseif key == "Speed" then bonusText = string.format("+%.0f Speed", data.SpeedBonus)
        elseif key == "Magnet" then bonusText = string.format("+%.0f%% Range", (data.MagnetRangeMultiplier - 1) * 100)
        elseif key == "Vitality" then bonusText = string.format("+%.0f Max Health", data.MaxHealth - 100)
        elseif key == "Regeneration" then bonusText = string.format("+%.1f HP/s Regen", data.HealthRegen)
        elseif key == "AttackSpeed" then bonusText = string.format("+%.0f%% Attack Speed", (data.AttackSpeedMultiplier - 1) * 100)
        elseif key == "CritChance" then
            local critPct = math.floor(data.CritChance * 100 + 0.5)
            bonusText = string.format("+%.0f%% Crit Chance", critPct)
        elseif key == "CritMultiplier" then
            local cm = math.floor(data.CritMultiplier * 10 + 0.5) / 10
            bonusText = string.format((cm % 1 == 0) and "+%.0fx Crit Dmg" or "+%.1fx Crit Dmg", cm)
        elseif key == "Lifesteal" then
            local ls = math.floor(data.Lifesteal * 100 + 0.5)
            bonusText = string.format("+%.0f%% Lifesteal", ls)
        elseif key == "XPBoost" then bonusText = string.format("+%.0f%% XP Boost", data.XPBoost * 100)
        elseif key == "AreaSize" then bonusText = string.format("+%.0f%% Size", (data.AreaMultiplier - 1) * 100)
        elseif key == "Luck" then
            local luckVal = (data.LuckBonus or (data.Upgrades and data.Upgrades["Luck"] and data.Upgrades["Luck"] * 0.10) or 0.10) * 100
            local luckPct = math.floor(luckVal + 0.5)
            bonusText = string.format("+%d%% Luck", math.max(10, luckPct))
        elseif key == "ProjectileCount" or key == "Volley" then
            local projBonus = (data.UpgradeBonuses and (data.UpgradeBonuses["ProjectileCount"] or data.UpgradeBonuses["Volley"])) or data.ProjectileCountBonus or 0
            if projBonus <= 0 and data.Upgrades and (data.Upgrades["ProjectileCount"] or data.Upgrades["Volley"]) then
                projBonus = (data.Upgrades["ProjectileCount"] or data.Upgrades["Volley"] or 1) * 1
            end
            local numStr
            if math.abs(projBonus * 10 - math.floor(projBonus * 10)) > 0.001 then
                numStr = string.format("%.2f", projBonus)
            elseif math.abs(projBonus - math.floor(projBonus)) > 0.001 then
                numStr = string.format("%.1f", projBonus)
            else
                numStr = string.format("%d", math.floor(projBonus + 0.5))
            end
            bonusText = string.format("+%s Projectile Count", numStr)
        else bonusText = base.Description or "Special perk effect." end
        
        addDescRow(string.format("<font color='#38bdf8'>%s</font>", bonusText))
    end

    -- Dynamic frame height calculation
    local containerHeight = (rowCount * 28) + 6
    tooltipStatsContainer.Size = UDim2.new(1, -24, 0, containerHeight)
    tooltipFrame.Size = UDim2.new(0, 240, 0, 54 + containerHeight)
    tooltipFrame.Visible = true
end

local function hideTooltip()
    if tooltipFrame then tooltipFrame.Visible = false end
end

RunService.RenderStepped:Connect(function()
    if tooltipFrame and tooltipFrame.Visible then
        local mousePos = UserInputService:GetMouseLocation()
        local viewport = workspace.CurrentCamera.ViewportSize
        local scale = math.clamp(math.min(viewport.X / 1600, viewport.Y / 900), 0.5, 2)
        
        local posX = (mousePos.X + 15) / scale
        local posY = (mousePos.Y - 20) / scale
        
        -- Ekran dışına çıkmasını engelle
        if (posX * scale) + 240 * scale > viewport.X then
            posX = (mousePos.X - 255) / scale
        end
        if (posY * scale) + tooltipFrame.Size.Y.Offset * scale > viewport.Y then
            posY = (viewport.Y - tooltipFrame.Size.Y.Offset * scale - 10) / scale
        end
        
        tooltipFrame.Position = UDim2.new(0, posX, 0, posY)
    end
end)

local updateActiveSlotsUI
local function drawSlots(container, items, maxAllowed, slotType, data)
    if not container or not data then return end
    
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") or child:IsA("ImageButton") then child:Destroy() end
    end
    
    for i = 1, 4 do -- Her zaman 4 slot çizilir (Maksimum 4)
        local slot = Instance.new("Frame")
        slot.Name = "Slot" .. i
        slot.Size = UDim2.new(0, 68, 0, 68)
        slot.BackgroundColor3 = (i > maxAllowed) and Color3.fromRGB(10, 10, 15) or Color3.fromRGB(25, 30, 40)
        slot.BackgroundTransparency = (i > maxAllowed) and 0.85 or 0.45
        slot.BorderSizePixel = 0
        slot.Parent = container

        local stroke = Instance.new("UIStroke")
        stroke.Color = (i > maxAllowed) and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(180, 180, 180)
        stroke.Thickness = 1.5
        stroke.Parent = slot
        
        if i > maxAllowed then
            -- Kilit Ikonu (Lobideki Gümüş Dükkanı'ndan açılır)
            local lockIcon = Instance.new("ImageLabel", slot)
            lockIcon.Size = UDim2.new(0, 26, 0, 26)
            lockIcon.Position = UDim2.new(0.5, 0, 0.35, 0)
            lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            lockIcon.ScaleType = Enum.ScaleType.Fit
            lockIcon.BackgroundTransparency = 1
            lockIcon.Image = "rbxassetid://72480127691513"
            lockIcon.ImageColor3 = Color3.fromRGB(180, 180, 190)
            lockIcon.ImageTransparency = 0.3

            local lockLabel = Instance.new("TextLabel", slot)
            lockLabel.Size = UDim2.new(1, -4, 0, 16)
            lockLabel.Position = UDim2.new(0.5, 0, 0.74, 0)
            lockLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            lockLabel.BackgroundTransparency = 1
            lockLabel.Text = "LOCKED"
            lockLabel.Font = Enum.Font.GothamBold
            lockLabel.TextSize = 10
            lockLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
            lockLabel.TextStrokeTransparency = 0.5
            lockLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        else
            local itemData = items[i]
            if itemData then
                local upgradeBase = UpgradeConfig.Upgrades[itemData.Key]
                local iconScale = (upgradeBase and upgradeBase.IconScale) or 1.0
                
                local icon = Instance.new("ImageLabel", slot)
                icon.Size = UDim2.new(0.8 * iconScale, 0, 0.8 * iconScale, 0)
                icon.Position = UDim2.new((1 - 0.8 * iconScale)/2, 0, (1 - 0.8 * iconScale)/2, 0)
                icon.BackgroundTransparency = 1
                icon.Image = itemData.Icon
                icon.Active = false -- Eventleri engellememesi için
                
                local levelLabel = Instance.new("TextLabel", slot)
                levelLabel.Size = UDim2.new(0, 30, 0, 15)
                levelLabel.Position = UDim2.new(1, -25, 0, -5)
                levelLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                levelLabel.Text = "Lv." .. itemData.Level
                levelLabel.TextColor3 = Color3.new(1, 1, 1)
                levelLabel.Font = Enum.Font.GothamBold
                levelLabel.TextSize = 12
                levelLabel.Active = false -- Eventleri engellememesi için
                
                local lblStroke = Instance.new("UIStroke", levelLabel)
                lblStroke.Color = Color3.fromRGB(150, 150, 50)
                lblStroke.Thickness = 1
                
                -- DEVRE DIŞI BIRAKMA (TEST MODU) GÖRSELİ
                local weaponName = string.gsub(itemData.Key, "Weapon$", "")
                local isDisabled = (slotType == "Weapon") and (Player:GetAttribute("DisabledWeapon_" .. weaponName) == true)
                
                if isDisabled then
                    slot.BackgroundColor3 = Color3.fromRGB(65, 18, 18)
                    slot.BackgroundTransparency = 0.25
                    stroke.Color = Color3.fromRGB(240, 50, 50)
                    stroke.Thickness = 2.2
                    icon.ImageTransparency = 0.55
                    icon.ImageColor3 = Color3.fromRGB(255, 120, 120)

                    local offBadge = Instance.new("TextLabel")
                    offBadge.Name = "OffBadge"
                    offBadge.Size = UDim2.new(1, 0, 1, 0)
                    offBadge.BackgroundTransparency = 1
                    offBadge.Text = "✕"
                    offBadge.TextColor3 = Color3.fromRGB(255, 60, 60)
                    offBadge.Font = Enum.Font.GothamBold
                    offBadge.TextSize = 34
                    offBadge.ZIndex = 8
                    offBadge.Parent = slot
                elseif slotType == "Weapon" and weaponDisableMode then
                    -- Test modu aktifken tıklanabilir olduğunu gösteren sarı/turuncu çerçeve
                    stroke.Color = Color3.fromRGB(250, 180, 50)
                    stroke.Thickness = 2.0
                end

                -- TIKLAMA BUTONU (Test Modunda Silahı Aç/Kapat)
                if slotType == "Weapon" then
                    local clickBtn = Instance.new("TextButton")
                    clickBtn.Name = "DisableToggleBtn"
                    clickBtn.Size = UDim2.new(1, 0, 1, 0)
                    clickBtn.BackgroundTransparency = 1
                    clickBtn.Text = ""
                    clickBtn.ZIndex = 10
                    clickBtn.Parent = slot

                    clickBtn.MouseButton1Click:Connect(function()
                        if weaponDisableMode then
                            local attrName = "DisabledWeapon_" .. weaponName
                            local cur = Player:GetAttribute(attrName) == true
                            Player:SetAttribute(attrName, not cur)
                            ToggleWeaponsEvent:FireServer(weaponName)
                            updateActiveSlotsUI()
                        end
                    end)
                end

                -- TOOLTIP EVENTLERI
                slot.MouseEnter:Connect(function()
                    showTooltip(itemData.Key, data)
                end)
                
                slot.MouseLeave:Connect(function()
                    hideTooltip()
                end)
            end
        end
    end
end

updateActiveSlotsUI = function(screenGui)
    if not screenGui then
        screenGui = PlayerGui:FindFirstChild("PlayerHUD")
    end
    if not screenGui then return end
    
    local wContainer = screenGui:FindFirstChild("WeaponSlotsContainer", true)
    local pContainer = screenGui:FindFirstChild("PerkSlotsContainer", true)
    
    local ClientGetPlayerData = Events:FindFirstChild("ClientGetPlayerData")
    if not ClientGetPlayerData then return end
    
    local data = ClientGetPlayerData:InvokeServer()
    if not data then return end
    
    local weapons = {}
    local perks = {}
    
    -- Silahlari tespit et (Yeni Weapon Sistemi)
    if data.HasBullet then
        local lvl = data.Upgrades["BulletWeapon"] or 1
        local icon = UpgradeConfig.Upgrades["BulletWeapon"] and UpgradeConfig.Upgrades["BulletWeapon"].Icon or ""
        table.insert(weapons, {Key = "BulletWeapon", Icon = icon, Level = lvl})
    end
    if data.HasFireball then
        local lvl = data.Upgrades["FireballWeapon"] or 1
        local icon = UpgradeConfig.Upgrades["FireballWeapon"] and UpgradeConfig.Upgrades["FireballWeapon"].Icon or ""
        table.insert(weapons, {Key = "FireballWeapon", Icon = icon, Level = lvl})
    end
    if data.HasFireTrail then
        local lvl = data.Upgrades["FireTrailWeapon"] or 1
        local icon = UpgradeConfig.Upgrades["FireTrailWeapon"] and UpgradeConfig.Upgrades["FireTrailWeapon"].Icon or ""
        table.insert(weapons, {Key = "FireTrailWeapon", Icon = icon, Level = lvl})
    end
    
    if data.HasLightning then
        local lvl = data.Upgrades["LightningWeapon"] or 1
        local icon = UpgradeConfig.Upgrades["LightningWeapon"] and UpgradeConfig.Upgrades["LightningWeapon"].Icon or ""
        table.insert(weapons, {Key = "LightningWeapon", Icon = icon, Level = lvl})
    end
    if data.HasSnowball then
        local lvl = data.Upgrades["SnowballWeapon"] or 1
        local icon = UpgradeConfig.Upgrades["SnowballWeapon"] and UpgradeConfig.Upgrades["SnowballWeapon"].Icon or ""
        table.insert(weapons, {Key = "SnowballWeapon", Icon = icon, Level = lvl})
    end
    if data.HasSpikedArmor then
        local lvl = data.Upgrades["SpikedArmorWeapon"] or 1
        local icon = UpgradeConfig.Upgrades["SpikedArmorWeapon"] and UpgradeConfig.Upgrades["SpikedArmorWeapon"].Icon or ""
        table.insert(weapons, {Key = "SpikedArmorWeapon", Icon = icon, Level = lvl})
    end
    if data.HasTurret then
        local lvl = data.Upgrades["TurretWeapon"] or 1
        local icon = UpgradeConfig.Upgrades["TurretWeapon"] and UpgradeConfig.Upgrades["TurretWeapon"].Icon or ""
        table.insert(weapons, {Key = "TurretWeapon", Icon = icon, Level = lvl})
    end
    
    -- Yetenekleri tespit et (Sadece Perk tipindekiler)
    for k, v in pairs(data.Upgrades) do
        local uBase = UpgradeConfig.Upgrades[k]
        if uBase and uBase.Type == "Perk" then
            table.insert(perks, {Key = k, Icon = uBase.Icon, Level = v})
        end
    end
    
    local wTitle = screenGui:FindFirstChild("Title", true)
    if wTitle and wTitle.Parent and wTitle.Parent.Name == "WeaponGroup" then
        if weaponDisableMode then
            wTitle.Text = "WEAPONS [TEST (L): CLICK]"
            wTitle.TextColor3 = Color3.fromRGB(255, 160, 60)
        else
            wTitle.Text = "WEAPONS (MAX " .. (data.MaxWeaponSlots or 2) .. ")"
            wTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
    local pTitle = screenGui:FindFirstChild("Title", true)
    if pTitle and pTitle.Parent and pTitle.Parent.Name == "PerkGroup" then
        pTitle.Text = "SCROLLS (MAX " .. (data.MaxPerkSlots or 2) .. ")"
    end
    
    drawSlots(wContainer, weapons, data.MaxWeaponSlots or 2, "Weapon", data)
    drawSlots(pContainer, perks, data.MaxPerkSlots or 2, "Perk", data)
    
    -- Draw items list
    if typeof(updateActiveItemsUI) == "function" then
        updateActiveItemsUI(screenGui)
    end
end

-- BASLATMA ARAYÜZÜ (Lobi & Loading)
local isCameraTransitioning = false

local function createStartUI()
    if ReplicatedStorage:GetAttribute("GameStarted") then return end
    isCameraTransitioning = true
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StartUI"
    screenGui.Parent = PlayerGui
    applyUIScale(screenGui)
    
    -- Karakter ve Kamera Degiskenleri
    local camera = workspace.CurrentCamera
    local cameraConnection = nil
    local angle = 0
    local rotationSpeed = 0.35
    local height = 8
    local distance = 15
    
    local charAddedConn = nil

    -- 1. Oyuncu Kontrollerini Devre Dışı Bırak (WASD, zıplama ve yön tuşları kilitlenir)
    local Controls = nil
    local function disableControls()
        pcall(function()
            if not Controls then
                local playerScripts = Player:WaitForChild("PlayerScripts", 5)
                if playerScripts then
                    local playerModule = require(playerScripts:WaitForChild("PlayerModule", 5))
                    Controls = playerModule:GetControls()
                end
            end
            if Controls then
                Controls:Disable()
            end
        end)
    end
    disableControls()
    
    -- 2. Kamera zumunu ve açısını sabitle (Tekerlekle veya fareyle değiştirilmesini engelle)
    Player.CameraMinZoomDistance = distance
    Player.CameraMaxZoomDistance = distance

    -- 3. Karakteri Hareketsizleştir ve Hızını 0 Yap
    local function lockCharacter(char)
        if not char then return end
        local hum = char:WaitForChild("Humanoid", 10)
        local hrp = char:WaitForChild("HumanoidRootPart", 10)
        if hum then
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum.JumpHeight = 0
            hum.AutoRotate = false
            hum:ChangeState(Enum.HumanoidStateType.Landed)
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
        if hrp then
            hrp.Anchored = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        disableControls()
    end
    if Player.Character then
        lockCharacter(Player.Character)
    end
    charAddedConn = Player.CharacterAdded:Connect(lockCharacter)
    
    -- 4. Kamera Dönüş Animasyonunu Başlat (RenderPriority.Camera.Value + 5 ile bağlayarak farenin bakış açısını değiştirmesini engelle)
    camera.CameraType = Enum.CameraType.Scriptable
    RunService:BindToRenderStep("PreGameCamera", Enum.RenderPriority.Camera.Value + 5, function(dt)
        camera.CameraType = Enum.CameraType.Scriptable
        disableControls()
        local char = Player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            angle = angle + rotationSpeed * dt
            local offset = Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
            local cameraPos = hrp.Position + offset
            camera.CFrame = CFrame.new(cameraPos, hrp.Position + Vector3.new(0, 2, 0))
        end
    end)

    -- Basit Yükleme Yazisi (Oyunun Yazi Stilinde)
    local loadingLabel = Instance.new("TextLabel")
    loadingLabel.Name = "LoadingLabel"
    loadingLabel.Size = UDim2.new(0.6, 0, 0.1, 0)
    loadingLabel.Position = UDim2.new(0.2, 0, 0.12, 0)
    loadingLabel.BackgroundTransparency = 1
    loadingLabel.Text = "LOADING GAME ASSETS..."
    loadingLabel.TextColor3 = Color3.new(1, 1, 1)
    loadingLabel.Font = Enum.Font.FredokaOne
    loadingLabel.TextSize = 36
    loadingLabel.Parent = screenGui
    
    -- Start Butonu
    local startBtn = Instance.new("TextButton")
    startBtn.Name = "StartButton"
    startBtn.Size = UDim2.new(0.2, 0, 0.08, 0)
    startBtn.Position = UDim2.new(0.4, 0, 0.12, 0)
    startBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    startBtn.Text = "START GAME"
    startBtn.TextColor3 = Color3.new(1, 1, 1)
    startBtn.Font = Enum.Font.FredokaOne
    startBtn.TextSize = 24
    startBtn.Visible = false
    startBtn.BackgroundTransparency = 1
    startBtn.TextTransparency = 1
    startBtn.Parent = screenGui
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = startBtn
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.3, 0, 0.05, 0)
    statusLabel.Position = UDim2.new(0.35, 0, 0.22, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Waiting for all players..."
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.Font = Enum.Font.GothamMedium
    statusLabel.TextSize = 16
    statusLabel.Visible = false
    statusLabel.Parent = screenGui

    -- YÜKLEME SÜRECI & VARLIK ÖN YÜKLEME (Asset Preloader)
    task.spawn(function()
        if not game:IsLoaded() then
            game.Loaded:Wait()
        end

        -- Haritanın sunucuda tamamen oluşmasını bekle
        if not ReplicatedStorage:GetAttribute("MapGenerated") then
            ReplicatedStorage:GetAttributeChangedSignal("MapGenerated"):Wait()
        end
        
        -- Görsellerin 3 saniye gecikmeli yüklenmesini engellemek için tüm ikonları önden belleğe alıyoruz
        local ContentProvider = game:GetService("ContentProvider")
        local assetsToPreload = {}
        
        for _, uData in pairs(UpgradeConfig.Upgrades) do
            if uData.Icon and uData.Icon ~= "" then
                table.insert(assetsToPreload, uData.Icon)
            end
        end
        for _, itemData in pairs(ItemConfig.Items) do
            if itemData.Icon and itemData.Icon ~= "" then
                table.insert(assetsToPreload, itemData.Icon)
            end
        end
        if CharacterUIConfig and CharacterUIConfig.Characters then
            for _, charData in ipairs(CharacterUIConfig.Characters) do
                if charData.Icon and charData.Icon ~= "" then
                    table.insert(assetsToPreload, charData.Icon)
                end
                if charData.Stats then
                    for _, stat in ipairs(charData.Stats) do
                        if stat.Icon and stat.Icon ~= "" then
                            table.insert(assetsToPreload, stat.Icon)
                        end
                    end
                end
            end
        end
        
        pcall(function()
            ContentProvider:PreloadAsync(assetsToPreload)
        end)
        
        task.wait(0.5) -- Yükleme tamamlandıktan sonra kısa bir bekleme
        
        -- Yükleme yazisini kapat
        TweenService:Create(loadingLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
        task.wait(0.5)
        loadingLabel.Visible = false
        
        -- Start butonunu aç
        startBtn.Visible = true
        TweenService:Create(startBtn, TweenInfo.new(0.5), {BackgroundTransparency = 0, TextTransparency = 0}):Play()
    end)

    startBtn.MouseButton1Click:Connect(function()
        startBtn.Visible = false
        statusLabel.Visible = true
        disableControls()
        if Player.Character then
            lockCharacter(Player.Character)
        end
        Events.PlayerReady:FireServer()
    end)
    
    Events.StartGame.OnClientEvent:Connect(function()
        screenGui:Destroy()
        
        -- Kamera Dönüş Bağlantısını Kaldır
        pcall(function()
            RunService:UnbindFromRenderStep("PreGameCamera")
        end)
        if cameraConnection then
            cameraConnection:Disconnect()
            cameraConnection = nil
        end
        
        -- Kamera geçiş animasyonu süresince kontrolleri kesinlikle devre dışı tut
        if Controls then
            Controls:Disable()
        end
        
        -- Yavaş Kamera Geçiş Animasyonu
        local char = Player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                hum.WalkSpeed = 0
                hum.JumpPower = 0
                hum.JumpHeight = 0
                hum.AutoRotate = false
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
            hrp.Anchored = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            
            -- Karakterin arkasına doğru doğal Custom kamera pozisyonunu hesapla (arkasından ileriye doğru bakar)
            local targetCFrame = CFrame.new(hrp.Position - hrp.CFrame.LookVector * 12.5 + Vector3.new(0, 4.5, 0), hrp.Position + Vector3.new(0, 1.5, 0))
            
            local tween = TweenService:Create(camera, TweenInfo.new(1.8, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {CFrame = targetCFrame})
            tween:Play()
            
            local function unlockPlayer()
                if not isCameraTransitioning then return end
                isCameraTransitioning = false
                
                if charAddedConn then
                    charAddedConn:Disconnect()
                    charAddedConn = nil
                end

                -- Snapping'i önlemek için kamerayı Custom yapıp ardından CFrame'i ve odağı güncelliyoruz
                camera.CameraType = Enum.CameraType.Custom
                camera.CFrame = targetCFrame
                camera.Focus = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0))
                
                local currentDistance = (camera.CFrame.Position - (hrp.Position + Vector3.new(0, 1.5, 0))).Magnitude
                Player.CameraMinZoomDistance = currentDistance
                Player.CameraMaxZoomDistance = currentDistance
                
                -- Kamera zum sınırlarını sıfırla (oyuncunun serbestçe yaklaşabilmesi için) ve yönü garantile
                task.defer(function()
                    task.wait(0.05)
                    camera.CFrame = targetCFrame
                    camera.Focus = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0))
                    Player.CameraMinZoomDistance = Config.Game.CameraMinZoomDistance or 0.5
                    Player.CameraMaxZoomDistance = Config.Game.CameraMaxZoomDistance or 30
                end)
                
                hrp.Anchored = false
                if hum then
                    hum.WalkSpeed = 17
                    hum.JumpPower = 50
                    hum.JumpHeight = 7.2
                end
                if Controls then
                    Controls:Enable()
                end
            end
            
            local completedConn = nil
            completedConn = tween.Completed:Connect(function()
                if completedConn then
                    completedConn:Disconnect()
                    completedConn = nil
                end
                unlockPlayer()
            end)
            
            -- Güvenlik Fallback: Herhangi bir aksilikte oyuncunun kilitli kalmasını engelle
            task.delay(2.0, function()
                if isCameraTransitioning then
                    unlockPlayer()
                end
            end)
        else
            if charAddedConn then
                charAddedConn:Disconnect()
                charAddedConn = nil
            end
            camera.CameraType = Enum.CameraType.Custom
            Player.CameraMinZoomDistance = Config.Game.CameraMinZoomDistance or 0.5
            Player.CameraMaxZoomDistance = Config.Game.CameraMaxZoomDistance or 30
            local c = Player.Character
            if c and c:FindFirstChild("HumanoidRootPart") then
                c.HumanoidRootPart.Anchored = false
            end
            if c and c:FindFirstChild("Humanoid") then
                c.Humanoid.WalkSpeed = 17
                c.Humanoid.JumpPower = 50
                c.Humanoid.JumpHeight = 7.2
            end
            if Controls then
                Controls:Enable()
            end
            isCameraTransitioning = false
        end
    end)
end

createStartUI()

-- 1. ANA OYUNCU ARAYÜZÜ (HUD)
local function createPlayerHUD()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PlayerHUD"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = false -- Main HUD için false kalmali, sadece tooltip için true olmali
    screenGui.Parent = PlayerGui
    applyUIScale(screenGui)

    -- PAUSE BUTTON UI & DURDURMA MENÜSÜ TANIMLARI
    local pauseMenuGui = nil
    local openPauseMenu = nil
    local closePauseMenu = nil

    local function isAnyModalActive()
        local isOpeningChest = ReplicatedStorage:GetAttribute("IsOpeningChest") == true or Player:GetAttribute("IsOpeningChest") == true or (PlayerGui and PlayerGui:FindFirstChild("ChestAwardUI") ~= nil)
        local isChoosingUpgrade = Player:GetAttribute("IsChoosingUpgrade") == true or (PlayerGui and (PlayerGui:FindFirstChild("UpgradeUI") ~= nil or PlayerGui:FindFirstChild("ShrineRewardUI") ~= nil))
        local isGameOver = PlayerGui and PlayerGui:FindFirstChild("GameOverUI") ~= nil
        return isOpeningChest or isChoosingUpgrade or isGameOver
    end

    local pauseBtn = Instance.new("TextButton")
    pauseBtn.Name = "PauseButton"
    pauseBtn.Size = UDim2.new(0, 40, 0, 40)
    pauseBtn.Position = UDim2.new(1, -55, 0, 15)
    pauseBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 45)
    pauseBtn.Text = "⏸"
    pauseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pauseBtn.Font = Enum.Font.GothamBold
    pauseBtn.TextSize = 18
    pauseBtn.Parent = screenGui
    
    local pauseCorner = Instance.new("UICorner")
    pauseCorner.CornerRadius = UDim.new(0.5, 0)
    pauseCorner.Parent = pauseBtn
    
    local pauseStroke = Instance.new("UIStroke")
    pauseStroke.Color = Color3.fromRGB(150, 150, 180)
    pauseStroke.Thickness = 2
    pauseStroke.Parent = pauseBtn
    
    pauseBtn.MouseEnter:Connect(function()
        TweenService:Create(pauseBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 52, 65)}):Play()
    end)
    pauseBtn.MouseLeave:Connect(function()
        TweenService:Create(pauseBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 32, 45)}):Play()
    end)
    
    pauseBtn.MouseButton1Click:Connect(function()
        if isAnyModalActive() then return end
        local TogglePauseEvent = Events:FindFirstChild("TogglePause")
        if TogglePauseEvent then
            TogglePauseEvent:FireServer()
        end
    end)
    
    local function updatePauseUI()
        local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
        local isManualPaused = ReplicatedStorage:GetAttribute("IsManualPaused") == true
        local modalActive = isAnyModalActive()
        
        -- Pause butonu SADECE kullanıcı oyunu manuel durdurduğunda '▶' (Devam Et) olur.
        -- Sandık açılırken, kart seçilirken veya normal oyunda '⏸' olarak kalır.
        local showResumeIcon = isManualPaused and not modalActive
        pauseBtn.Text = showResumeIcon and "▶" or "⏸"
        pauseBtn.TextColor3 = showResumeIcon and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 255, 255)
        pauseStroke.Color = showResumeIcon and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(150, 150, 180)
        
        -- Oyun durduğunda / devam ettiğinde oyuncu hareketini senkronize et
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if isPaused then
            if hum and hum.WalkSpeed > 0 then
                hum.WalkSpeed = 0
            end
            if hrp then
                hrp.Anchored = true
            end

            -- DURDURMA MENÜSÜNÜ AÇ: SADECE manuel duraklatılmışsa ve hiçbir oyun içi modal açık değilse!
            if isManualPaused and not modalActive then
                if openPauseMenu then
                    openPauseMenu()
                end
            else
                if closePauseMenu then
                    closePauseMenu()
                end
            end
        else
            if closePauseMenu then
                closePauseMenu()
            end

            -- Sadece aktif modal yoksa hareketi serbest bırak
            if not modalActive then
                if hum then
                    local speedBonus = Player:GetAttribute("SpeedBonus") or 0
                    local baseSpeed = 17 + speedBonus
                    local isSprinting = Player:GetAttribute("IsSprinting") == true
                    hum.WalkSpeed = isSprinting and (baseSpeed * 1.5) or baseSpeed
                end
                if hrp then
                    hrp.Anchored = false
                end
            end
        end
    end

    ReplicatedStorage:GetAttributeChangedSignal("IsPaused"):Connect(updatePauseUI)
    ReplicatedStorage:GetAttributeChangedSignal("IsManualPaused"):Connect(updatePauseUI)
    ReplicatedStorage:GetAttributeChangedSignal("IsOpeningChest"):Connect(updatePauseUI)
    Player:GetAttributeChangedSignal("IsOpeningChest"):Connect(updatePauseUI)
    Player:GetAttributeChangedSignal("IsChoosingUpgrade"):Connect(updatePauseUI)

    -- Ana Konteyner
    local container = Instance.new("Frame")
    container.Name = "HUDContainer"
    container.Size = UDim2.new(0.4, 0, 0.22, 0)
    container.Position = UIConfig.PlayerHUD.ContainerPosition
    container.BackgroundTransparency = 1
    container.Parent = screenGui

    createTooltipUI(screenGui)

    -- ============================================================
    -- DURDURMA MENÜSÜ & ENVANTER SİSTEMİ (PAUSE MENU & INVENTORY)
    -- Sol tarafta oyuncunun silahları, kartları ve eşyalarını gösteren retro panel
    -- ============================================================
    local ASSET_PAUSE_BG = "rbxassetid://128546682524083"       -- Ana arka plan
    local ASSET_PAUSE_FRAME = "rbxassetid://138090530037394"    -- Dış çerçeve (Inventory başlıklı)
    local ASSET_TXT_WEAPONS = "rbxassetid://113537378475992"    -- Weapons yazısı
    local ASSET_TXT_CARDS = "rbxassetid://91395217234032"       -- Cards yazısı
    local ASSET_TXT_ITEMS = "rbxassetid://71139661314694"       -- Items yazısı

    local function setupPauseMenuUI()
        local existingPause = PlayerGui:FindFirstChild("PauseMenuGui")
        if existingPause then existingPause:Destroy() end

        pauseMenuGui = Instance.new("ScreenGui")
        pauseMenuGui.Name = "PauseMenuGui"
        pauseMenuGui.ResetOnSpawn = false
        pauseMenuGui.DisplayOrder = 140
        pauseMenuGui.IgnoreGuiInset = true
        pauseMenuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        pauseMenuGui.Enabled = false
        pauseMenuGui.Parent = PlayerGui

        -- 1. ARKA PLAN TAM EKRAN KARARTMA (DIMMER)
        -- Dimmer UIScale'e dahil edilmez; böylece ekranın tamamını kenardan kenara kaplar
        -- ve ZIndex=1 sayesinde UI panellerinin (ZIndex>=5) KESİNLİKLE arkasında kalır!
        local dimmer = Instance.new("TextButton")
        dimmer.Name = "PauseDimmer"
        dimmer.Size = UDim2.new(1, 0, 1, 0)
        dimmer.Position = UDim2.new(0, 0, 0, 0)
        dimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        dimmer.BackgroundTransparency = 0.55
        dimmer.BorderSizePixel = 0
        dimmer.Text = ""
        dimmer.AutoButtonColor = false
        dimmer.ZIndex = 1
        dimmer.Parent = pauseMenuGui

        -- 2. İÇERİK KONTEYNERİ (Tüm paneller burada ölçeklenir ve dimmer'ın üstünde kalır)
        -- AnchorPoint (0.5, 0.5) ve Position (0.5, 0.5) sayesinde ekranın tam ortasında kilitlenir
        -- UIScale ekran çözünürlüğüne göre ölçeklendiğinde asla yukarı kaymaz, merkezde kalır!
        local contentContainer = Instance.new("Frame")
        contentContainer.Name = "ContentContainer"
        contentContainer.AnchorPoint = Vector2.new(0.5, 0.5)
        contentContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
        contentContainer.Size = UDim2.new(0, 1600, 0, 900)
        contentContainer.BackgroundTransparency = 1
        contentContainer.BorderSizePixel = 0
        contentContainer.ZIndex = 5
        contentContainer.Parent = pauseMenuGui

        applyUIScale(contentContainer)

        -- ============================================================
        -- SOL ORTA: ENVANTER PANELİ (Dikeyde ve yatayda hizalı sol-orta)
        -- ============================================================
        local invPanel = Instance.new("Frame")
        invPanel.Name = "InventoryPanel"
        invPanel.AnchorPoint = Vector2.new(0.5, 0.5)
        invPanel.Position = UDim2.new(0, 290, 0.5, 0) -- Sol-orta hizası
        invPanel.Size = UDim2.new(0, 410, 0, 680)
        invPanel.BackgroundTransparency = 1
        invPanel.ClipsDescendants = false
        invPanel.ZIndex = 10
        invPanel.Parent = contentContainer

        local invCorner = Instance.new("UICorner")
        invCorner.CornerRadius = UDim.new(0, 8)
        invCorner.Parent = invPanel

        local invStroke = Instance.new("UIStroke")
        invStroke.Name = "InvBorderStroke"
        invStroke.Color = Color3.fromRGB(0, 60, 5) -- Çerçevenin solundaki eksik kenarlığı tamamlayan piksel kontur
        invStroke.Thickness = 2.5
        invStroke.Parent = invPanel

        -- Doku Dolgu Arka Planı (Ana Arka Plan: rbxassetid://128546682524083)
        local bgTexture = Instance.new("ImageLabel")
        bgTexture.Name = "BgTexture"
        bgTexture.Size = UDim2.new(1, -6, 1, -6)
        bgTexture.Position = UDim2.new(0.5, 0, 0.5, 0)
        bgTexture.AnchorPoint = Vector2.new(0.5, 0.5)
        bgTexture.Image = ASSET_PAUSE_BG
        bgTexture.ScaleType = Enum.ScaleType.Crop
        bgTexture.BackgroundTransparency = 1
        bgTexture.ZIndex = 1
        bgTexture.Parent = invPanel

        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(0, 6)
        bgCorner.Parent = bgTexture

        -- Slotların doku üzerinde okunaklı durması için hafif kontrast filtre
        local bgFilter = Instance.new("Frame")
        bgFilter.Name = "BgFilter"
        bgFilter.Size = UDim2.new(1, 0, 1, 0)
        bgFilter.BackgroundColor3 = Color3.fromRGB(10, 15, 20)
        bgFilter.BackgroundTransparency = 0.65 -- Yeşil tuğla dokusunun canlı görünmesi için şeffaflaştırıldı
        bgFilter.BorderSizePixel = 0
        bgFilter.ZIndex = 2
        bgFilter.Parent = bgTexture

        -- Dış Çerçeve (Inventory Başlıklı Çerçeve: rbxassetid://138090530037394)
        local outerFrame = Instance.new("ImageLabel")
        outerFrame.Name = "OuterFrame"
        outerFrame.Size = UDim2.new(1, 0, 1, 0)
        outerFrame.Position = UDim2.new(0, 0, 0, 0)
        outerFrame.Image = ASSET_PAUSE_FRAME
        outerFrame.BackgroundTransparency = 1
        outerFrame.Active = false
        outerFrame.ZIndex = 15
        outerFrame.Parent = invPanel

        -- Kaydırılabilir İçerik Alanı (ScrollingFrame)
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Name = "InventoryScroll"
        scrollFrame.AnchorPoint = Vector2.new(0.5, 0)
        scrollFrame.Position = UDim2.new(0.5, 0, 0, 74) -- Üstteki yeşil Inventory başlığının altı
        scrollFrame.Size = UDim2.new(1, -24, 1, -98)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.BorderSizePixel = 0
        scrollFrame.ScrollBarThickness = 5
        scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(31, 241, 119)
        scrollFrame.ScrollBarImageTransparency = 0.25
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scrollFrame.ZIndex = 20
        scrollFrame.Parent = invPanel

        local scrollPadding = Instance.new("UIPadding")
        scrollPadding.PaddingLeft = UDim.new(0, 6)
        scrollPadding.PaddingRight = UDim.new(0, 6)
        scrollPadding.PaddingTop = UDim.new(0, 2)
        scrollPadding.PaddingBottom = UDim.new(0, 14)
        scrollPadding.Parent = scrollFrame

        local scrollLayout = Instance.new("UIListLayout")
        scrollLayout.FillDirection = Enum.FillDirection.Vertical
        scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
        scrollLayout.Padding = UDim.new(0, 18)
        scrollLayout.Parent = scrollFrame

        -- ============================================================
        -- ORTA KISIM: DURAKLATMA KONTROLLERİ VE MAÇ ÖZETİ (Artık Ortada!)
        -- ============================================================
        local actionPanel = Instance.new("Frame")
        actionPanel.Name = "ActionPanel"
        actionPanel.AnchorPoint = Vector2.new(0.5, 0.5)
        actionPanel.Position = UDim2.new(0.50, 0, 0.5, 0) -- Tam ekran ortası
        actionPanel.Size = UDim2.new(0, 440, 0, 540)
        actionPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
        actionPanel.BackgroundTransparency = 0.05
        actionPanel.BorderSizePixel = 0
        actionPanel.ZIndex = 10
        actionPanel.Parent = contentContainer

        local actionCorner = Instance.new("UICorner")
        actionCorner.CornerRadius = UDim.new(0, 16)
        actionCorner.Parent = actionPanel

        local actionStroke = Instance.new("UIStroke")
        actionStroke.Color = Color3.fromRGB(56, 189, 248)
        actionStroke.Thickness = 2
        actionStroke.Parent = actionPanel

        local actionLayout = Instance.new("UIListLayout")
        actionLayout.FillDirection = Enum.FillDirection.Vertical
        actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
        actionLayout.Padding = UDim.new(0, 14)
        actionLayout.Parent = actionPanel

        local actionPadding = Instance.new("UIPadding")
        actionPadding.PaddingTop = UDim.new(0, 24)
        actionPadding.PaddingBottom = UDim.new(0, 24)
        actionPadding.PaddingLeft = UDim.new(0, 24)
        actionPadding.PaddingRight = UDim.new(0, 24)
        actionPadding.Parent = actionPanel

        -- Başlık (GAME PAUSED)
        local pauseTitle = Instance.new("TextLabel")
        pauseTitle.Name = "PauseTitle"
        pauseTitle.Size = UDim2.new(1, 0, 0, 42)
        pauseTitle.BackgroundTransparency = 1
        pauseTitle.Text = "GAME PAUSED"
        pauseTitle.Font = Enum.Font.GothamBlack
        pauseTitle.TextSize = 34
        pauseTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        pauseTitle.LayoutOrder = 1
        pauseTitle.Parent = actionPanel

        local titleGradient = Instance.new("UIGradient")
        titleGradient.Rotation = 90
        titleGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 240, 130)),
            ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 170, 45)),
        })
        titleGradient.Parent = pauseTitle

        local titleStroke = Instance.new("UIStroke")
        titleStroke.Thickness = 3
        titleStroke.Color = Color3.fromRGB(15, 10, 5)
        titleStroke.Parent = pauseTitle

        -- İstatistik Kartı (Run Stats Summary)
        local statsCard = Instance.new("Frame")
        statsCard.Name = "StatsCard"
        statsCard.Size = UDim2.new(1, 0, 0, 115)
        statsCard.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
        statsCard.BackgroundTransparency = 0.3
        statsCard.LayoutOrder = 2
        statsCard.Parent = actionPanel

        local statsCorner = Instance.new("UICorner")
        statsCorner.CornerRadius = UDim.new(0, 12)
        statsCorner.Parent = statsCard

        local statsStroke = Instance.new("UIStroke")
        statsStroke.Color = Color3.fromRGB(38, 50, 68)
        statsStroke.Thickness = 1.5
        statsStroke.Parent = statsCard

        local statsGrid = Instance.new("UIGridLayout")
        statsGrid.CellSize = UDim2.new(0.5, -8, 0.5, -6)
        statsGrid.CellPadding = UDim2.new(0, 8, 0, 6)
        statsGrid.Parent = statsCard

        local statsPadding = Instance.new("UIPadding")
        statsPadding.PaddingTop = UDim.new(0, 10)
        statsPadding.PaddingBottom = UDim.new(0, 10)
        statsPadding.PaddingLeft = UDim.new(0, 12)
        statsPadding.PaddingRight = UDim.new(0, 12)
        statsPadding.Parent = statsCard

        local function createStatBox(name, icon, defaultVal)
            local box = Instance.new("Frame")
            box.Name = name .. "Box"
            box.BackgroundTransparency = 1
            box.Parent = statsCard

            local lbl = Instance.new("TextLabel")
            lbl.Name = "Label"
            lbl.Size = UDim2.new(1, 0, 0, 16)
            lbl.BackgroundTransparency = 1
            lbl.Text = icon .. " " .. name
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 12
            lbl.TextColor3 = Color3.fromRGB(140, 155, 175)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = box

            local val = Instance.new("TextLabel")
            val.Name = "Value"
            val.Size = UDim2.new(1, 0, 0, 24)
            val.Position = UDim2.new(0, 0, 0, 18)
            val.BackgroundTransparency = 1
            val.Text = defaultVal
            val.Font = Enum.Font.GothamBold
            val.TextSize = 18
            val.TextColor3 = Color3.fromRGB(240, 245, 255)
            val.TextXAlignment = Enum.TextXAlignment.Left
            val.Parent = box

            return val
        end

        local timeVal = createStatBox("Survive Time", "⏱", "00:00")
        local killsVal = createStatBox("Enemies Slain", "⚔", "0")
        local goldVal = createStatBox("Gold Earned", "🪙", "0")
        local lvlVal = createStatBox("Player Level", "⭐", "1")

        -- Ayırıcı Çizgi
        local sep = Instance.new("Frame")
        sep.Name = "Divider"
        sep.Size = UDim2.new(1, 0, 0, 1)
        sep.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
        sep.BorderSizePixel = 0
        sep.LayoutOrder = 3
        sep.Parent = actionPanel

        -- Buton 1: DEVAM ET (RESUME)
        local resumeBtn = Instance.new("TextButton")
        resumeBtn.Name = "ResumeButton"
        resumeBtn.Size = UDim2.new(1, 0, 0, 52)
        resumeBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
        resumeBtn.Text = "RESUME"
        resumeBtn.Font = Enum.Font.GothamBlack
        resumeBtn.TextSize = 20
        resumeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        resumeBtn.AutoButtonColor = false
        resumeBtn.LayoutOrder = 4
        resumeBtn.Parent = actionPanel

        local rStroke = Instance.new("UIStroke")
        rStroke.Color = Color3.fromRGB(22, 101, 52)
        rStroke.Thickness = 1.5
        rStroke.Parent = resumeBtn

        local resumeCorner = Instance.new("UICorner")
        resumeCorner.CornerRadius = UDim.new(0, 10)
        resumeCorner.Parent = resumeBtn

        resumeBtn.MouseEnter:Connect(function()
            TweenService:Create(resumeBtn, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(52, 211, 153) }):Play()
        end)
        resumeBtn.MouseLeave:Connect(function()
            TweenService:Create(resumeBtn, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(34, 197, 94) }):Play()
        end)
        resumeBtn.MouseButton1Click:Connect(function()
            local TogglePauseEvent = Events:FindFirstChild("TogglePause")
            if TogglePauseEvent then
                TogglePauseEvent:FireServer()
            end
        end)

        -- Buton 2: AYARLAR (SETTINGS)
        local settingsBtnModal = Instance.new("TextButton")
        settingsBtnModal.Name = "SettingsButton"
        settingsBtnModal.Size = UDim2.new(1, 0, 0, 46)
        settingsBtnModal.BackgroundColor3 = Color3.fromRGB(28, 34, 46)
        settingsBtnModal.Text = "SETTINGS"
        settingsBtnModal.Font = Enum.Font.GothamBold
        settingsBtnModal.TextSize = 16
        settingsBtnModal.TextColor3 = Color3.fromRGB(230, 235, 245)
        settingsBtnModal.AutoButtonColor = false
        settingsBtnModal.LayoutOrder = 5
        settingsBtnModal.Parent = actionPanel

        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(0, 10)
        sCorner.Parent = settingsBtnModal

        local sStroke = Instance.new("UIStroke")
        sStroke.Color = Color3.fromRGB(52, 65, 86)
        sStroke.Thickness = 1.5
        sStroke.Parent = settingsBtnModal

        settingsBtnModal.MouseEnter:Connect(function()
            TweenService:Create(settingsBtnModal, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(40, 50, 68) }):Play()
        end)
        settingsBtnModal.MouseLeave:Connect(function()
            TweenService:Create(settingsBtnModal, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(28, 34, 46) }):Play()
        end)
        settingsBtnModal.MouseButton1Click:Connect(function()
            if typeof(_G.ToggleBloxBongSettingsUI) == "function" then
                _G.ToggleBloxBongSettingsUI(true)
            end
        end)

        -- Buton 3: LOBİYE DÖN (RETURN TO LOBBY)
        local lobbyBtn = Instance.new("TextButton")
        lobbyBtn.Name = "LobbyButton"
        lobbyBtn.Size = UDim2.new(1, 0, 0, 46)
        lobbyBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
        lobbyBtn.Text = "RETURN TO LOBBY"
        lobbyBtn.Font = Enum.Font.GothamBold
        lobbyBtn.TextSize = 16
        lobbyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        lobbyBtn.AutoButtonColor = false
        lobbyBtn.LayoutOrder = 6
        lobbyBtn.Parent = actionPanel

        local lCorner = Instance.new("UICorner")
        lCorner.CornerRadius = UDim.new(0, 10)
        lCorner.Parent = lobbyBtn

        local lStroke = Instance.new("UIStroke")
        lStroke.Color = Color3.fromRGB(200, 60, 60)
        lStroke.Thickness = 1.5
        lStroke.Parent = lobbyBtn

        -- Onay Bildirimi (Quit Confirmation)
        local quitConfirm = false
        lobbyBtn.MouseEnter:Connect(function()
            if not quitConfirm then
                TweenService:Create(lobbyBtn, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(190, 50, 50) }):Play()
            end
        end)
        lobbyBtn.MouseLeave:Connect(function()
            if not quitConfirm then
                TweenService:Create(lobbyBtn, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(160, 40, 40) }):Play()
            end
        end)
        lobbyBtn.MouseButton1Click:Connect(function()
            if not quitConfirm then
                quitConfirm = true
                lobbyBtn.Text = "SURE? CLICK AGAIN TO QUIT"
                lobbyBtn.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
                task.delay(4, function()
                    if quitConfirm then
                        quitConfirm = false
                        if lobbyBtn and lobbyBtn.Parent then
                            lobbyBtn.Text = "RETURN TO LOBBY"
                            lobbyBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
                        end
                    end
                end)
            else
                local ReturnToLobbyEvent = Events:FindFirstChild("ReturnToLobby")
                if ReturnToLobbyEvent then
                    ReturnToLobbyEvent:FireServer()
                end
            end
        end)

        -- ============================================================
        -- ENVANTERİ VE VERİLERİ DOLDURMA (POPULATE INVENTORY & STATS)
        -- ============================================================
        local function refreshInventoryUI()
            local ClientGetPlayerData = Events:FindFirstChild("ClientGetPlayerData")
            local data = ClientGetPlayerData and ClientGetPlayerData:InvokeServer()
            if not data then return end

            -- İstatistikleri güncelle
            local matchDuration = (Config and Config.Game and Config.Game.MatchDuration) or 600
            local timeRem = ReplicatedStorage:GetAttribute("TimeRemaining") or 600
            local elapsed = math.max(0, matchDuration - timeRem)
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            timeVal.Text = string.format("%02d:%02d", mins, secs)
            killsVal.Text = tostring(data.Kills or Player:GetAttribute("Kills") or 0)
            goldVal.Text = tostring(data.Coins or Player:GetAttribute("Coins") or 0)
            lvlVal.Text = "Lv. " .. tostring(data.Level or Player:GetAttribute("Level") or 1)

            -- Scroll içeriğini temizle
            for _, child in ipairs(scrollFrame:GetChildren()) do
                if child:IsA("Frame") then
                    child:Destroy()
                end
            end

            -- 1. SILAHLAR (WEAPONS) BÖLÜMÜ
            local weapons = {}
            if data.HasBullet then
                local lvl = (data.Upgrades and data.Upgrades["BulletWeapon"]) or 1
                local icon = (UpgradeConfig.Upgrades["BulletWeapon"] and UpgradeConfig.Upgrades["BulletWeapon"].Icon) or ""
                table.insert(weapons, {Key = "BulletWeapon", Icon = icon, Level = lvl})
            end
            if data.HasFireball then
                local lvl = (data.Upgrades and data.Upgrades["FireballWeapon"]) or 1
                local icon = (UpgradeConfig.Upgrades["FireballWeapon"] and UpgradeConfig.Upgrades["FireballWeapon"].Icon) or ""
                table.insert(weapons, {Key = "FireballWeapon", Icon = icon, Level = lvl})
            end
            if data.HasFireTrail then
                local lvl = (data.Upgrades and data.Upgrades["FireTrailWeapon"]) or 1
                local icon = (UpgradeConfig.Upgrades["FireTrailWeapon"] and UpgradeConfig.Upgrades["FireTrailWeapon"].Icon) or ""
                table.insert(weapons, {Key = "FireTrailWeapon", Icon = icon, Level = lvl})
            end
            if data.HasLightning then
                local lvl = (data.Upgrades and data.Upgrades["LightningWeapon"]) or 1
                local icon = (UpgradeConfig.Upgrades["LightningWeapon"] and UpgradeConfig.Upgrades["LightningWeapon"].Icon) or ""
                table.insert(weapons, {Key = "LightningWeapon", Icon = icon, Level = lvl})
            end
            if data.HasSnowball then
                local lvl = (data.Upgrades and data.Upgrades["SnowballWeapon"]) or 1
                local icon = (UpgradeConfig.Upgrades["SnowballWeapon"] and UpgradeConfig.Upgrades["SnowballWeapon"].Icon) or ""
                table.insert(weapons, {Key = "SnowballWeapon", Icon = icon, Level = lvl})
            end
            if data.HasSpikedArmor then
                local lvl = (data.Upgrades and data.Upgrades["SpikedArmorWeapon"]) or 1
                local icon = (UpgradeConfig.Upgrades["SpikedArmorWeapon"] and UpgradeConfig.Upgrades["SpikedArmorWeapon"].Icon) or ""
                table.insert(weapons, {Key = "SpikedArmorWeapon", Icon = icon, Level = lvl})
            end
            if data.HasTurret then
                local lvl = (data.Upgrades and data.Upgrades["TurretWeapon"]) or 1
                local icon = (UpgradeConfig.Upgrades["TurretWeapon"] and UpgradeConfig.Upgrades["TurretWeapon"].Icon) or ""
                table.insert(weapons, {Key = "TurretWeapon", Icon = icon, Level = lvl})
            end

            local wSection = Instance.new("Frame")
            wSection.Name = "WeaponsSection"
            wSection.Size = UDim2.new(1, 0, 0, 106)
            wSection.BackgroundTransparency = 1
            wSection.LayoutOrder = 1
            wSection.Parent = scrollFrame

            local wHeader = Instance.new("ImageLabel")
            wHeader.Name = "WeaponsHeader"
            wHeader.Size = UDim2.new(0, 135, 0, 28)
            wHeader.Position = UDim2.new(0, 36, 0, 0) -- İlk slotla aynı X hizası
            wHeader.BackgroundTransparency = 1
            wHeader.Image = ASSET_TXT_WEAPONS
            wHeader.ScaleType = Enum.ScaleType.Fit
            wHeader.Parent = wSection

            local wSlotsContainer = Instance.new("Frame")
            wSlotsContainer.Name = "Slots"
            wSlotsContainer.Size = UDim2.new(1, 0, 0, 72)
            wSlotsContainer.Position = UDim2.new(0, 0, 0, 32)
            wSlotsContainer.BackgroundTransparency = 1
            wSlotsContainer.Parent = wSection

            local wLayout = Instance.new("UIListLayout")
            wLayout.FillDirection = Enum.FillDirection.Horizontal
            wLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            wLayout.Padding = UDim.new(0, 10)
            wLayout.Parent = wSlotsContainer

            local maxAllowedW = data.MaxWeaponSlots or 2
            local maxW = math.max(4, maxAllowedW)
            for i = 1, maxW do
                local wData = weapons[i]
                local isLocked = (i > maxAllowedW)
                
                local slot = Instance.new("Frame")
                slot.Name = "Slot" .. i
                slot.Size = UDim2.new(0, 68, 0, 68)
                slot.BackgroundColor3 = isLocked and Color3.fromRGB(8, 12, 18) or (wData and Color3.fromRGB(10, 16, 24) or Color3.fromRGB(15, 22, 32))
                slot.BackgroundTransparency = isLocked and 0.65 or (wData and 0.35 or 0.55)
                slot.BorderSizePixel = 0
                slot.Parent = wSlotsContainer

                local sCorner = Instance.new("UICorner", slot)
                sCorner.CornerRadius = UDim.new(0, 10)

                local sStroke = Instance.new("UIStroke", slot)
                sStroke.Color = isLocked and Color3.fromRGB(45, 55, 68) or (wData and Color3.fromRGB(245, 158, 11) or Color3.fromRGB(50, 70, 90))
                sStroke.Transparency = isLocked and 0.4 or (wData and 0 or 0.25)
                sStroke.Thickness = 1.5

                if wData then
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(0.82, 0, 0.82, 0)
                    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
                    icon.AnchorPoint = Vector2.new(0.5, 0.5)
                    icon.BackgroundTransparency = 1
                    icon.Image = wData.Icon
                    icon.Parent = slot

                    local lvlBadge = Instance.new("TextLabel")
                    lvlBadge.Size = UDim2.new(0, 32, 0, 18)
                    lvlBadge.Position = UDim2.new(1, -3, 1, -3)
                    lvlBadge.AnchorPoint = Vector2.new(1, 1)
                    lvlBadge.BackgroundTransparency = 1
                    lvlBadge.Text = "Lv." .. tostring(wData.Level)
                    lvlBadge.Font = Enum.Font.GothamBold
                    lvlBadge.TextSize = 12
                    lvlBadge.TextColor3 = Color3.fromRGB(255, 215, 60)
                    lvlBadge.TextStrokeTransparency = 0
                    lvlBadge.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    lvlBadge.Parent = slot

                    -- Tooltip
                    slot.MouseEnter:Connect(function()
                        showTooltip(wData.Key, data)
                    end)
                    slot.MouseLeave:Connect(hideTooltip)
                elseif isLocked then
                    local lockIcon = Instance.new("ImageLabel")
                    lockIcon.Name = "LockIcon"
                    lockIcon.Size = UDim2.new(0, 24, 0, 24)
                    lockIcon.Position = UDim2.new(0.5, 0, 0.35, 0)
                    lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
                    lockIcon.BackgroundTransparency = 1
                    lockIcon.Image = "rbxassetid://72480127691513"
                    lockIcon.ImageColor3 = Color3.fromRGB(150, 160, 175)
                    lockIcon.ImageTransparency = 0.25
                    lockIcon.Parent = slot

                    local lockLabel = Instance.new("TextLabel")
                    lockLabel.Name = "LockLabel"
                    lockLabel.Size = UDim2.new(1, -4, 0, 16)
                    lockLabel.Position = UDim2.new(0.5, 0, 0.74, 0)
                    lockLabel.AnchorPoint = Vector2.new(0.5, 0.5)
                    lockLabel.BackgroundTransparency = 1
                    lockLabel.Text = "LOCKED"
                    lockLabel.Font = Enum.Font.GothamBold
                    lockLabel.TextSize = 10
                    lockLabel.TextColor3 = Color3.fromRGB(150, 160, 175)
                    lockLabel.TextStrokeTransparency = 0.5
                    lockLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    lockLabel.Parent = slot
                end
            end

            -- 2. KARTLAR (CARDS) BÖLÜMÜ
            local cards = {}
            if data.Upgrades then
                for k, v in pairs(data.Upgrades) do
                    local uBase = UpgradeConfig.Upgrades[k]
                    if uBase and uBase.Type == "Perk" then
                        table.insert(cards, {Key = k, Icon = uBase.Icon or "", Level = v})
                    end
                end
            end

            local cSection = Instance.new("Frame")
            cSection.Name = "CardsSection"
            cSection.Size = UDim2.new(1, 0, 0, 106)
            cSection.BackgroundTransparency = 1
            cSection.LayoutOrder = 2
            cSection.Parent = scrollFrame

            local cHeader = Instance.new("ImageLabel")
            cHeader.Name = "CardsHeader"
            cHeader.Size = UDim2.new(0, 110, 0, 28)
            cHeader.Position = UDim2.new(0, 36, 0, 0) -- İlk kart slotuyla aynı X hizası
            cHeader.BackgroundTransparency = 1
            cHeader.Image = ASSET_TXT_CARDS
            cHeader.ScaleType = Enum.ScaleType.Fit
            cHeader.Parent = cSection

            local cSlotsContainer = Instance.new("Frame")
            cSlotsContainer.Name = "Slots"
            cSlotsContainer.Size = UDim2.new(1, 0, 0, 72)
            cSlotsContainer.Position = UDim2.new(0, 0, 0, 32)
            cSlotsContainer.BackgroundTransparency = 1
            cSlotsContainer.Parent = cSection

            local cLayout = Instance.new("UIListLayout")
            cLayout.FillDirection = Enum.FillDirection.Horizontal
            cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            cLayout.Padding = UDim.new(0, 10)
            cLayout.Parent = cSlotsContainer

            local maxAllowedC = data.MaxPerkSlots or 2
            local maxC = math.max(4, maxAllowedC)
            for i = 1, maxC do
                local cData = cards[i]
                local isLocked = (i > maxAllowedC)
                
                local slot = Instance.new("Frame")
                slot.Name = "CardSlot" .. i
                slot.Size = UDim2.new(0, 68, 0, 68)
                slot.BackgroundColor3 = isLocked and Color3.fromRGB(8, 12, 18) or (cData and Color3.fromRGB(10, 16, 24) or Color3.fromRGB(15, 22, 32))
                slot.BackgroundTransparency = isLocked and 0.65 or (cData and 0.35 or 0.55)
                slot.BorderSizePixel = 0
                slot.Parent = cSlotsContainer

                local sCorner = Instance.new("UICorner", slot)
                sCorner.CornerRadius = UDim.new(0, 10)

                local sStroke = Instance.new("UIStroke", slot)
                sStroke.Color = isLocked and Color3.fromRGB(45, 55, 68) or (cData and Color3.fromRGB(52, 211, 153) or Color3.fromRGB(50, 70, 90))
                sStroke.Transparency = isLocked and 0.4 or (cData and 0 or 0.25)
                sStroke.Thickness = 1.5

                if cData then
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(0.82, 0, 0.82, 0)
                    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
                    icon.AnchorPoint = Vector2.new(0.5, 0.5)
                    icon.BackgroundTransparency = 1
                    icon.Image = cData.Icon
                    icon.Parent = slot

                    local lvlBadge = Instance.new("TextLabel")
                    lvlBadge.Size = UDim2.new(0, 32, 0, 18)
                    lvlBadge.Position = UDim2.new(1, -3, 1, -3)
                    lvlBadge.AnchorPoint = Vector2.new(1, 1)
                    lvlBadge.BackgroundTransparency = 1
                    lvlBadge.Text = "Lv." .. tostring(cData.Level)
                    lvlBadge.Font = Enum.Font.GothamBold
                    lvlBadge.TextSize = 12
                    lvlBadge.TextColor3 = Color3.fromRGB(52, 211, 153)
                    lvlBadge.TextStrokeTransparency = 0
                    lvlBadge.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    lvlBadge.Parent = slot

                    -- Tooltip
                    slot.MouseEnter:Connect(function()
                        showTooltip(cData.Key, data)
                    end)
                    slot.MouseLeave:Connect(hideTooltip)
                elseif isLocked then
                    local lockIcon = Instance.new("ImageLabel")
                    lockIcon.Name = "LockIcon"
                    lockIcon.Size = UDim2.new(0, 24, 0, 24)
                    lockIcon.Position = UDim2.new(0.5, 0, 0.35, 0)
                    lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
                    lockIcon.BackgroundTransparency = 1
                    lockIcon.Image = "rbxassetid://72480127691513"
                    lockIcon.ImageColor3 = Color3.fromRGB(150, 160, 175)
                    lockIcon.ImageTransparency = 0.25
                    lockIcon.Parent = slot

                    local lockLabel = Instance.new("TextLabel")
                    lockLabel.Name = "LockLabel"
                    lockLabel.Size = UDim2.new(1, -4, 0, 16)
                    lockLabel.Position = UDim2.new(0.5, 0, 0.74, 0)
                    lockLabel.AnchorPoint = Vector2.new(0.5, 0.5)
                    lockLabel.BackgroundTransparency = 1
                    lockLabel.Text = "LOCKED"
                    lockLabel.Font = Enum.Font.GothamBold
                    lockLabel.TextSize = 10
                    lockLabel.TextColor3 = Color3.fromRGB(150, 160, 175)
                    lockLabel.TextStrokeTransparency = 0.5
                    lockLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    lockLabel.Parent = slot
                end
            end

            -- 3. EŞYALAR (ITEMS) BÖLÜMÜ
            local items = {}
            if data.Items then
                for itemKey, count in pairs(data.Items) do
                    if count and count > 0 then
                        local itemDef = ItemConfig.Items[itemKey]
                        if itemDef then
                            table.insert(items, {
                                Key = itemKey,
                                Count = count,
                                Def = itemDef,
                                Icon = itemDef.Icon or "",
                                IconScale = itemDef.IconScale or 1,
                                Rarity = itemDef.Rarity or "Common"
                            })
                        end
                    end
                end
            end

            -- Nadirliğe göre sırala (Legendary -> Epic -> Rare -> Uncommon -> Common)
            local rarityRanks = { Legendary = 5, Epic = 4, Rare = 3, Uncommon = 2, Common = 1 }
            table.sort(items, function(a, b)
                local rankA = rarityRanks[a.Rarity] or 1
                local rankB = rarityRanks[b.Rarity] or 1
                if rankA ~= rankB then return rankA > rankB end
                return a.Key < b.Key
            end)

            local iSection = Instance.new("Frame")
            iSection.Name = "ItemsSection"
            iSection.Size = UDim2.new(1, 0, 0, 0)
            iSection.AutomaticSize = Enum.AutomaticSize.Y
            iSection.BackgroundTransparency = 1
            iSection.LayoutOrder = 3
            iSection.Parent = scrollFrame

            local iHeader = Instance.new("ImageLabel")
            iHeader.Name = "ItemsHeader"
            iHeader.Size = UDim2.new(0, 105, 0, 28)
            iHeader.Position = UDim2.new(0, 12, 0, 0)
            iHeader.BackgroundTransparency = 1
            iHeader.Image = ASSET_TXT_ITEMS
            iHeader.ScaleType = Enum.ScaleType.Fit
            iHeader.Parent = iSection

            local iGridContainer = Instance.new("Frame")
            iGridContainer.Name = "Grid"
            iGridContainer.Size = UDim2.new(0, 350, 0, 0)
            iGridContainer.Position = UDim2.new(0, 12, 0, 34)
            iGridContainer.AutomaticSize = Enum.AutomaticSize.Y
            iGridContainer.BackgroundTransparency = 1
            iGridContainer.Parent = iSection

            local iGrid = Instance.new("UIGridLayout")
            iGrid.CellSize = UDim2.new(0, 62, 0, 62)
            iGrid.CellPadding = UDim2.new(0, 10, 0, 10)
            iGrid.Parent = iGridContainer

            if #items > 0 then
                for _, itm in ipairs(items) do
                    local slot = Instance.new("Frame")
                    slot.Name = "Item_" .. itm.Key
                    slot.BackgroundColor3 = Color3.fromRGB(10, 16, 24)
                    slot.BackgroundTransparency = 0.35 -- Şeffaflaştırıldı
                    slot.BorderSizePixel = 0
                    slot.Parent = iGridContainer

                    local sCorner = Instance.new("UICorner", slot)
                    sCorner.CornerRadius = UDim.new(0, 10)

                    -- Nadirlik Çerçeve Rengi
                    local sColor = Color3.fromRGB(148, 163, 184) -- Common
                    if itm.Rarity == "Uncommon" then sColor = Color3.fromRGB(74, 222, 128)
                    elseif itm.Rarity == "Rare" then sColor = Color3.fromRGB(96, 165, 250)
                    elseif itm.Rarity == "Epic" then sColor = Color3.fromRGB(192, 132, 252)
                    elseif itm.Rarity == "Legendary" then sColor = Color3.fromRGB(250, 204, 21) end

                    local sStroke = Instance.new("UIStroke", slot)
                    sStroke.Color = sColor
                    sStroke.Thickness = 1.5

                    -- İkon
                    local iconSize = 0.74 * itm.IconScale
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(iconSize, 0, iconSize, 0)
                    icon.Position = UDim2.new(0.5, 0, 0.44, 0)
                    icon.AnchorPoint = Vector2.new(0.5, 0.5)
                    icon.BackgroundTransparency = 1
                    icon.Image = itm.Icon
                    icon.Parent = slot

                    -- SOL ALTTA KAÇ X OLDUKLARI ("xN")
                    local stackLbl = Instance.new("TextLabel")
                    stackLbl.Name = "StackCount"
                    stackLbl.Size = UDim2.new(0, 32, 0, 18)
                    stackLbl.Position = UDim2.new(0, 5, 1, -4)
                    stackLbl.AnchorPoint = Vector2.new(0, 1)
                    stackLbl.BackgroundTransparency = 1
                    stackLbl.Text = "x" .. tostring(itm.Count)
                    stackLbl.Font = Enum.Font.GothamBlack
                    stackLbl.TextSize = 13
                    stackLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                    stackLbl.TextStrokeTransparency = 0
                    stackLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    stackLbl.TextXAlignment = Enum.TextXAlignment.Left
                    stackLbl.ZIndex = 5
                    stackLbl.Parent = slot

                    -- Üstüne İmleç Götürünce Ne Yaptıkları (Tooltip)
                    slot.MouseEnter:Connect(function()
                        showTooltip(itm.Key, data)
                    end)
                    slot.MouseLeave:Connect(hideTooltip)
                end
            else
                local emptyLbl = Instance.new("TextLabel")
                emptyLbl.Size = UDim2.new(1, 0, 0, 32)
                emptyLbl.BackgroundTransparency = 1
                emptyLbl.Text = "No items collected yet."
                emptyLbl.Font = Enum.Font.GothamMedium
                emptyLbl.TextSize = 14
                emptyLbl.TextColor3 = Color3.fromRGB(120, 130, 145)
                emptyLbl.Parent = iGridContainer
            end
        end

        openPauseMenu = function()
            if not ReplicatedStorage:GetAttribute("IsManualPaused") or isAnyModalActive() then
                return
            end
            refreshInventoryUI()
            quitConfirm = false
            lobbyBtn.Text = "RETURN TO LOBBY"
            lobbyBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
            pauseMenuGui.Enabled = true

            -- Yumuşak Pop-in Animasyonu
            dimmer.BackgroundTransparency = 1
            TweenService:Create(dimmer, TweenInfo.new(0.2), { BackgroundTransparency = 0.55 }):Play()

            invPanel.Position = UDim2.new(0, 240, 0.5, 0)
            TweenService:Create(invPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 290, 0.5, 0)
            }):Play()

            actionPanel.Position = UDim2.new(0.50, 0, 0.46, 0)
            TweenService:Create(actionPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.50, 0, 0.5, 0)
            }):Play()
        end

        closePauseMenu = function()
            hideTooltip()
            quitConfirm = false
            if pauseMenuGui and pauseMenuGui.Enabled then
                if isAnyModalActive() then
                    pauseMenuGui.Enabled = false
                    dimmer.BackgroundTransparency = 1
                else
                    local t = TweenService:Create(dimmer, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
                    t:Play()
                    t.Completed:Connect(function()
                        if ReplicatedStorage:GetAttribute("IsManualPaused") ~= true or isAnyModalActive() then
                            pauseMenuGui.Enabled = false
                        end
                    end)
                end
            end
        end

        -- Klavye P Tuşu ile Durdurma
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.P then
                if isAnyModalActive() then return end
                local TogglePauseEvent = Events:FindFirstChild("TogglePause")
                if TogglePauseEvent then
                    TogglePauseEvent:FireServer()
                end
            end
        end)
    end

    setupPauseMenuUI()


    -- CAN BARI TASARIMI
    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBg"
    healthBg.Size = UDim2.new(0.8, 0, 0.25, 0)
    healthBg.Position = UDim2.new(0.1, 0, 0.05, 0)
    healthBg.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    healthBg.BackgroundTransparency = 0.3
    healthBg.BorderSizePixel = 0
    healthBg.Parent = container
    
    local healthBgStroke = Instance.new("UIStroke", healthBg)
    healthBgStroke.Color = Color3.fromRGB(80, 100, 120)
    healthBgStroke.Thickness = 2
    healthBgStroke.Transparency = 0.4

    local healthCorner = Instance.new("UICorner")
    healthCorner.CornerRadius = UDim.new(0.5, 0)
    healthCorner.Parent = healthBg

    local healthFill = Instance.new("Frame")
    healthFill.Name = "Fill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBg
    
    local healthGradient = Instance.new("UIGradient")
    healthGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UIConfig.PlayerHUD.HealthBarColor:lerp(Color3.new(0,0,0), 0.3)),
        ColorSequenceKeypoint.new(1, UIConfig.PlayerHUD.HealthBarColor)
    })
    healthGradient.Parent = healthFill

    local healthFillCorner = Instance.new("UICorner")
    healthFillCorner.CornerRadius = UDim.new(0.5, 0)
    healthFillCorner.Parent = healthFill
    
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Size = UDim2.new(1, 0, 1, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.Text = "100 / 100"
    healthLabel.TextColor3 = Color3.new(1, 1, 1)
    healthLabel.Font = Enum.Font.GothamBold
    healthLabel.TextSize = 16
    healthLabel.TextStrokeTransparency = 0.8
    healthLabel.Parent = healthBg

    -- XP BARI TASARIMI
    local xpBg = Instance.new("Frame")
    xpBg.Name = "XpBg"
    xpBg.Size = UDim2.new(0.8, 0, 0.15, 0)
    xpBg.Position = UDim2.new(0.1, 0, 0.35, 0)
    xpBg.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    xpBg.BackgroundTransparency = 0.3
    xpBg.BorderSizePixel = 0
    xpBg.Parent = container
    
    local xpBgStroke = Instance.new("UIStroke", xpBg)
    xpBgStroke.Color = Color3.fromRGB(80, 100, 120)
    xpBgStroke.Thickness = 2
    xpBgStroke.Transparency = 0.4

    local xpCorner = Instance.new("UICorner")
    xpCorner.CornerRadius = UDim.new(0.5, 0)
    xpCorner.Parent = xpBg

    local xpFill = Instance.new("Frame")
    xpFill.Name = "Fill"
    xpFill.Size = UDim2.new(0, 0, 1, 0)
    xpFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    xpFill.BorderSizePixel = 0
    xpFill.Parent = xpBg
    
    local xpGradient = Instance.new("UIGradient")
    xpGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UIConfig.PlayerHUD.XPBarColor:lerp(Color3.new(0,0,0), 0.3)),
        ColorSequenceKeypoint.new(1, UIConfig.PlayerHUD.XPBarColor)
    })
    xpGradient.Parent = xpFill

    local xpFillCorner = Instance.new("UICorner")
    xpFillCorner.CornerRadius = UDim.new(0.5, 0)
    xpFillCorner.Parent = xpFill
    
    local xpLabel = Instance.new("TextLabel")
    xpLabel.Size = UDim2.new(1, 0, 1, 0)
    xpLabel.BackgroundTransparency = 1
    xpLabel.Text = ""
    xpLabel.TextColor3 = Color3.new(1, 1, 1)
    xpLabel.Font = Enum.Font.GothamBold
    xpLabel.TextSize = 12
    xpLabel.TextStrokeTransparency = 0.8
    xpLabel.Parent = xpBg
    
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Size = UDim2.new(0.2, 0, 0.25, 0)
    levelLabel.Position = UDim2.new(0.91, 0, 0.05, -2) -- Can barinin saginda
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "LV. 1"
    levelLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.TextSize = 22
    levelLabel.TextXAlignment = Enum.TextXAlignment.Left -- Sola hizala (saga dogru büyür)
    levelLabel.ZIndex = 10
    levelLabel.Parent = container

    -- PARALAR ETIKETI
    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 24, 0, 24)
    coinIcon.Position = UDim2.new(0.91, 0, 0.35, -2)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Image = "rbxassetid://126941861587473"
    coinIcon.ZIndex = 10
    coinIcon.Parent = container

    local coinLabel = Instance.new("TextLabel")
    coinLabel.Name = "CoinLabel"
    coinLabel.Size = UDim2.new(0.2, 0, 0.15, 0)
    coinLabel.Position = UDim2.new(0.945, 0, 0.35, -2) -- XP barinin saginda
    coinLabel.BackgroundTransparency = 1
    coinLabel.Text = "0"
    coinLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    coinLabel.Font = Enum.Font.GothamBold
    coinLabel.TextSize = 22
    coinLabel.TextXAlignment = Enum.TextXAlignment.Left -- Sola hizala (saga dogru büyür)
    coinLabel.ZIndex = 10
    coinLabel.Parent = container

    -- STAMINA BARI TASARIMI
    local staminaBg = Instance.new("Frame")
    staminaBg.Name = "StaminaBg"
    staminaBg.Size = UDim2.new(0.8, 0, 0.15, 0)
    staminaBg.Position = UDim2.new(0.1, 0, 0.55, 0)
    staminaBg.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    staminaBg.BackgroundTransparency = 0.3
    staminaBg.BorderSizePixel = 0
    staminaBg.Parent = container
    
    local staminaBgStroke = Instance.new("UIStroke", staminaBg)
    staminaBgStroke.Color = Color3.fromRGB(80, 100, 120)
    staminaBgStroke.Thickness = 2
    staminaBgStroke.Transparency = 0.4

    local staminaCorner = Instance.new("UICorner")
    staminaCorner.CornerRadius = UDim.new(0.5, 0)
    staminaCorner.Parent = staminaBg

    local staminaFill = Instance.new("Frame")
    staminaFill.Name = "Fill"
    staminaFill.Size = UDim2.new(1, 0, 1, 0)
    staminaFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    staminaFill.BorderSizePixel = 0
    staminaFill.Parent = staminaBg
    
    local staminaGradient = Instance.new("UIGradient")
    staminaGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UIConfig.PlayerHUD.StaminaBarColor:lerp(Color3.new(0,0,0), 0.3)),
        ColorSequenceKeypoint.new(1, UIConfig.PlayerHUD.StaminaBarColor)
    })
    staminaGradient.Parent = staminaFill

    local staminaFillCorner = Instance.new("UICorner")
    staminaFillCorner.CornerRadius = UDim.new(0.5, 0)
    staminaFillCorner.Parent = staminaFill
    
    -- STAMINA MANTIGI
    local maxStamina = 125
    local currentStamina = 125
    local isSprintKeyHeld = false
    local isSprinting = false
    local isExhausted = false -- Stamina bittiğinde basılı tutmayı bozar
    local SprintEvent = Events:WaitForChild("SprintEvent")
    local Camera = workspace.CurrentCamera

    -- Kontrol modülünden doğrudan ham girdi okuma (0ms gecikmesiz, inertia kirlenmesi olmadan)
    local sprintControls = nil
    local function getPlayerControls()
        if not sprintControls then
            pcall(function()
                local playerScripts = Player:FindFirstChild("PlayerScripts") or Player:WaitForChild("PlayerScripts", 3)
                if playerScripts then
                    local playerModule = require(playerScripts:WaitForChild("PlayerModule", 3))
                    sprintControls = playerModule:GetControls()
                end
            end)
        end
        return sprintControls
    end

    local function getIsPlayerMoving()
        if not Player.Character then return false end
        local hum = Player.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or Player.Character:GetAttribute("IsDowned") then return false end

        -- 1. Doğrudan tuş / analog çubuğu girdi vektörü
        local ctrl = getPlayerControls()
        if ctrl and ctrl.GetMoveVector then
            local mv = ctrl:GetMoveVector()
            if mv and mv.Magnitude > 0.05 then
                return true
            end
        end

        -- 2. Fallback: Humanoid.MoveDirection (0.1 eşiği ile floating point artıklarını filtrele)
        if hum.MoveDirection.Magnitude > 0.1 then
            return true
        end

        return false
    end

    -- SpeedBonus değiştikçe yerel yürüme hızını anında senkronize et
    Player:GetAttributeChangedSignal("SpeedBonus"):Connect(function()
        if Player.Character and Player.Character:FindFirstChild("Humanoid") then
            local hum = Player.Character.Humanoid
            if hum.Health > 0 and not Player.Character:GetAttribute("IsDowned") and ReplicatedStorage:GetAttribute("IsPaused") ~= true then
                local speedBonus = Player:GetAttribute("SpeedBonus") or 0
                local baseSpeed = 17 + speedBonus
                hum.WalkSpeed = isSprinting and (baseSpeed * 1.5) or baseSpeed
            end
        end
    end)
    
    -- Change Shift Lock keybind to Alt (LeftAlt, RightAlt) dynamically
    task.spawn(function()
        local playerScripts = Player:WaitForChild("PlayerScripts")
        local playerModule = playerScripts:WaitForChild("PlayerModule")
        local cameraModule = playerModule:WaitForChild("CameraModule")
        local mouseLockController = cameraModule:WaitForChild("MouseLockController")
        local boundKeys = mouseLockController:FindFirstChild("BoundKeys")
        if boundKeys then
            boundKeys.Value = "LeftAlt,RightAlt"
        else
            local obj = Instance.new("StringValue")
            obj.Name = "BoundKeys"
            obj.Value = "LeftAlt,RightAlt"
            obj.Parent = mouseLockController
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not ReplicatedStorage:GetAttribute("GameStarted") or isCameraTransitioning or ReplicatedStorage:GetAttribute("CameraIntroActive") == true then return end
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            if currentStamina > 10 then
                isExhausted = false
            end
            isSprintKeyHeld = true
        elseif input.KeyCode == Enum.KeyCode.K then
            if not isAnyModalActive() then
                local TogglePauseEvent = Events:FindFirstChild("TogglePause")
                if TogglePauseEvent then
                    TogglePauseEvent:FireServer()
                end
            end
        elseif input.KeyCode == Enum.KeyCode.L then
            weaponDisableMode = not weaponDisableMode
            local hud = PlayerGui:FindFirstChild("PlayerHUD")
            if hud then
                updateActiveSlotsUI(hud)
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            isSprintKeyHeld = false
            isExhausted = false
        end
    end)

    local regenTimer = 0
    
    RunService.Heartbeat:Connect(function(dt)
        if not ReplicatedStorage:GetAttribute("GameStarted") or isCameraTransitioning or ReplicatedStorage:GetAttribute("CameraIntroActive") == true then
            if isSprinting then
                isSprinting = false
                Player:SetAttribute("IsSprinting", false)
                SprintEvent:FireServer(false)
                TweenService:Create(staminaFill, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(200, 200, 200)
                }):Play()
                TweenService:Create(Camera, TweenInfo.new(0.4), {
                    FieldOfView = 70
                }):Play()
            end
            return
        end
        if ReplicatedStorage:GetAttribute("IsPaused") then
            if isSprinting then
                isSprinting = false
                Player:SetAttribute("IsSprinting", false)
                SprintEvent:FireServer(false)
                TweenService:Create(staminaFill, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(200, 200, 200)
                }):Play()
                TweenService:Create(Camera, TweenInfo.new(0.4), {
                    FieldOfView = 70
                }):Play()
            end
            return
        end

        local moving = getIsPlayerMoving()
        local stateChanged = false
        
        -- KOŞMA DURUMU KONTROLÜ
        local canSprint = isSprintKeyHeld and not isExhausted and (currentStamina > 0) and moving
        
        local speedBonus = Player:GetAttribute("SpeedBonus") or 0
        local baseSpeed = 17 + speedBonus

        if canSprint then
            if not isSprinting then
                isSprinting = true
                Player:SetAttribute("IsSprinting", true)
                SprintEvent:FireServer(true)
                stateChanged = true
            end
            currentStamina = math.max(0, currentStamina - (25 * dt)) -- 5 saniyede biter
            regenTimer = 1.0 -- Koşarken her karede timer'ı 1 saniyeye sabitle
            
            -- Stamina bittiğinde basılı tutmayı anında boz ve koşmayı durdur
            if currentStamina <= 0 then
                isExhausted = true
                isSprinting = false
                Player:SetAttribute("IsSprinting", false)
                SprintEvent:FireServer(false)
                stateChanged = true
                regenTimer = 1.0
            end
        else
            -- Koşma bittiğinde veya stamina tükendiğinde
            if isSprinting then
                isSprinting = false
                Player:SetAttribute("IsSprinting", false)
                SprintEvent:FireServer(false)
                stateChanged = true
                regenTimer = 1.0 -- Durduğunda 1 saniyelik bekleme başlat
            end
            
            -- Bekleme süresini düşür
            if regenTimer > 0 then
                regenTimer = math.max(0, regenTimer - dt)
            end
            
            -- Sadece bekleme süresi bittiyse ve stamina dolu değilse yenile
            if regenTimer <= 0 and currentStamina < maxStamina then
                currentStamina = math.min(maxStamina, currentStamina + (12.5 * dt)) -- 10 saniyede dolar
            end

            -- Koşulmuyorken hızın asla sprint hızında takılı kalmasına izin verme (Korumalı Sınırlayıcı)
            if Player.Character and Player.Character:FindFirstChild("Humanoid") then
                local hum = Player.Character.Humanoid
                if hum.Health > 0 and not Player.Character:GetAttribute("IsDowned") and ReplicatedStorage:GetAttribute("IsPaused") ~= true then
                    if hum.WalkSpeed > (baseSpeed + 0.1) then
                        hum.WalkSpeed = baseSpeed
                    end
                end
            end
        end
        
        -- Görseli güncelle
        staminaFill.Size = UDim2.new(currentStamina / maxStamina, 0, 1, 0)
        
        if stateChanged then
            if Player.Character and Player.Character:FindFirstChild("Humanoid") then
                local hum = Player.Character.Humanoid
                if hum.Health > 0 and not Player.Character:GetAttribute("IsDowned") then
                    if ReplicatedStorage:GetAttribute("IsPaused") ~= true then
                        hum.WalkSpeed = isSprinting and (baseSpeed * 1.5) or baseSpeed
                    end
                end
            end

            TweenService:Create(staminaFill, TweenInfo.new(0.2), {
                BackgroundColor3 = isSprinting and Color3.new(1,1,1) or Color3.fromRGB(200, 200, 200)
            }):Play()
            
            -- FOV Efekti
            TweenService:Create(Camera, TweenInfo.new(0.4), {
                FieldOfView = isSprinting and 85 or 70
            }):Play()
        end
    end)

    -- ZAMAN SAYACI (TIMER)
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UIConfig.Timer.Size
    timerLabel.Position = UIConfig.Timer.Position
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = "15:00"
    timerLabel.TextColor3 = UIConfig.Timer.DefaultColor
    timerLabel.Font = UIConfig.General.Font
    timerLabel.TextSize = UIConfig.Timer.TextSize
    timerLabel.TextStrokeTransparency = 0
    timerLabel.Parent = screenGui

    local matchDuration = (UIConfig.Timer and UIConfig.Timer.MatchDuration) or 900

    local gameTime = ReplicatedStorage:WaitForChild("GameTime", math.huge)
    local function updateTimer()
        local seconds = gameTime.Value
        
        if seconds < 0 then
            -- Hazırlık Aşaması (Renkli Geri Sayım: 5, 4, 3, 2, 1)
            timerLabel.Text = string.format("START IN: %d", math.abs(seconds))
            timerLabel.TextColor3 = UIConfig.Timer.CountdownColor
            timerLabel.TextSize = UIConfig.Timer.TextSize + 4
        else
            -- 15 Dakikadan Geriye Doğru Sayım (15:00 -> 00:00)
            local remaining = math.max(0, matchDuration - seconds)
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            timerLabel.Text = string.format("%02d:%02d", mins, secs)
            
            -- Son 60 saniyede uyarı rengi
            if remaining <= 60 and remaining > 0 then
                timerLabel.TextColor3 = UIConfig.Timer.CountdownColor
            else
                timerLabel.TextColor3 = UIConfig.Timer.DefaultColor
            end
            timerLabel.TextSize = UIConfig.Timer.TextSize
        end
    end
    
    gameTime.Changed:Connect(updateTimer)
    updateTimer()

    -- MESAJ SİSTEMİ (DALGA DUYURULARI)
    Events:WaitForChild("ShowMessage").OnClientEvent:Connect(function(message, color)
        local msgLabel = Instance.new("TextLabel")
        msgLabel.Name = "AnnounceMessage"
        msgLabel.Size = UDim2.new(1, 0, 0.05, 0)
        msgLabel.Position = UDim2.new(0, 0, 0.75, 0)
        msgLabel.BackgroundTransparency = 1
        msgLabel.Text = message
        msgLabel.TextColor3 = color or Color3.new(1, 1, 1)
        msgLabel.Font = Enum.Font.FredokaOne
        msgLabel.TextSize = 24
        msgLabel.TextStrokeTransparency = 0.5
        msgLabel.ZIndex = 100
        msgLabel.Parent = screenGui
        
        -- Pop-up Animasyonu
        msgLabel.TextTransparency = 1
        msgLabel.TextStrokeTransparency = 1
        TweenService:Create(msgLabel, TweenInfo.new(0.5), {TextTransparency = 0, TextStrokeTransparency = 0.2}):Play()
        
        task.delay(2, function()
            local tween = TweenService:Create(msgLabel, TweenInfo.new(1), {TextTransparency = 1, TextStrokeTransparency = 1})
            tween:Play()
            tween.Completed:Connect(function()
                msgLabel:Destroy()
            end)
        end)
    end)

    -- ============================================================
    -- SÜRÜ (SWARM) UYARI ANİMASYONU (ÖZEL TİPOGRAFİ - EKRAN ORTASININ BİRAZ ÜSTÜ)
    -- Arka plan/kutu kesinlikle yoktur; saf, ateşli ve katmanlı tipografi ile vurucu pop-up animasyonu.
    -- ============================================================
    local activeSwarmAnnouncement = nil

    local function showSwarmWarning()
        if activeSwarmAnnouncement and activeSwarmAnnouncement.Parent then
            activeSwarmAnnouncement:Destroy()
            activeSwarmAnnouncement = nil
        end

        -- Swarm sesini kısık ve dengeli olarak çal
        pcall(function()
            SoundManager.PlaySound("SwarmWarning")
        end)

        local container = Instance.new("Frame")
        container.Name = "SwarmAnnouncement"
        container.AnchorPoint = Vector2.new(0.5, 0.5)
        container.Position = UDim2.new(0.5, 0, 0.28, 0) -- Ekranın ortasının biraz üstü
        container.Size = UDim2.new(0, 700, 0, 75)
        container.BackgroundTransparency = 1 -- Arka plan kesinlikle yok
        container.BorderSizePixel = 0
        container.ZIndex = 250
        container.Parent = screenGui
        activeSwarmAnnouncement = container

        local uiScale = Instance.new("UIScale")
        uiScale.Scale = 1.45
        uiScale.Parent = container

        -- 1. Üst Mini Uyarı Başlığı (Tag)
        local topTag = Instance.new("TextLabel")
        topTag.Name = "WarningTag"
        topTag.AnchorPoint = Vector2.new(0.5, 0)
        topTag.Position = UDim2.new(0.5, 0, 0, 0)
        topTag.Size = UDim2.new(1, 0, 0, 18)
        topTag.BackgroundTransparency = 1
        topTag.Text = "— WARNING —"
        topTag.Font = Enum.Font.GothamBold
        topTag.TextSize = 15
        topTag.TextColor3 = Color3.fromRGB(255, 175, 40)
        topTag.TextTransparency = 1
        topTag.ZIndex = 251
        topTag.Parent = container

        local topStroke = Instance.new("UIStroke")
        topStroke.Thickness = 2.5
        topStroke.Color = Color3.fromRGB(0, 0, 0)
        topStroke.Transparency = 1
        topStroke.Parent = topTag

        -- 2. Arka Plan Neon Işıma Katmanı (Backing Glow - Tamamen Yazı, Kutu Yok)
        local glowTitle = Instance.new("TextLabel")
        glowTitle.Name = "GlowTitle"
        glowTitle.AnchorPoint = Vector2.new(0.5, 0)
        glowTitle.Position = UDim2.new(0.5, 0, 0, 18)
        glowTitle.Size = UDim2.new(1, 0, 0, 52)
        glowTitle.BackgroundTransparency = 1
        glowTitle.Text = "SWARM INCOMING!"
        glowTitle.Font = Enum.Font.GothamBlack
        glowTitle.TextSize = 46
        glowTitle.TextColor3 = Color3.fromRGB(255, 60, 20)
        glowTitle.TextTransparency = 1
        glowTitle.ZIndex = 251
        glowTitle.Parent = container

        local glowStroke = Instance.new("UIStroke")
        glowStroke.Thickness = 9
        glowStroke.Color = Color3.fromRGB(255, 75, 20)
        glowStroke.Transparency = 1
        glowStroke.Parent = glowTitle

        -- 3. Ön Plan Keskin Başlık (Vibrant Fiery Gradient + Black Stroke)
        local mainTitle = Instance.new("TextLabel")
        mainTitle.Name = "MainTitle"
        mainTitle.AnchorPoint = Vector2.new(0.5, 0)
        mainTitle.Position = UDim2.new(0.5, 0, 0, 18)
        mainTitle.Size = UDim2.new(1, 0, 0, 52)
        mainTitle.BackgroundTransparency = 1
        mainTitle.Text = "SWARM INCOMING!"
        mainTitle.Font = Enum.Font.GothamBlack
        mainTitle.TextSize = 46
        mainTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        mainTitle.TextTransparency = 1
        mainTitle.ZIndex = 252
        mainTitle.Parent = container

        local mainStroke = Instance.new("UIStroke")
        mainStroke.Thickness = 3.5
        mainStroke.Color = Color3.fromRGB(10, 5, 5)
        mainStroke.Transparency = 1
        mainStroke.Parent = mainTitle

        local mainGradient = Instance.new("UIGradient")
        mainGradient.Rotation = 90
        mainGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 245, 140)), -- Parlak altın sarısı tepe ışığı
            ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 140, 25)), -- Ateşli amber / turuncu
            ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 35, 20)),   -- Derin akkor kırmızı
        })
        mainGradient.Parent = mainTitle

        -- Punch Giriş Animasyonu (Büyük boyuttan çarparak ekranın ortasının biraz üstüne oturur)
        local punchTween = TweenService:Create(uiScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Scale = 1.0
        })
        local fadeInTop = TweenService:Create(topTag, TweenInfo.new(0.2), { TextTransparency = 0 })
        local fadeInTopStroke = TweenService:Create(topStroke, TweenInfo.new(0.2), { Transparency = 0.25 })
        local fadeInMain = TweenService:Create(mainTitle, TweenInfo.new(0.2), { TextTransparency = 0 })
        local fadeInMainStroke = TweenService:Create(mainStroke, TweenInfo.new(0.2), { Transparency = 0 })
        local fadeInGlow = TweenService:Create(glowTitle, TweenInfo.new(0.2), { TextTransparency = 0.45 })
        local fadeInGlowStroke = TweenService:Create(glowStroke, TweenInfo.new(0.2), { Transparency = 0.55 })

        punchTween:Play()
        fadeInTop:Play()
        fadeInTopStroke:Play()
        fadeInMain:Play()
        fadeInMainStroke:Play()
        fadeInGlow:Play()
        fadeInGlowStroke:Play()

        -- Nefes Alma / Nabız Efekti (Ekrandayken hafif parlama titreşimi)
        local pulseGlow = TweenService:Create(glowStroke, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Transparency = 0.30,
            Thickness = 12
        })
        pulseGlow:Play()

        -- Ekranda Kalma Süresi (Duraklatma / Pause Kurallarına Tam Uyumlu)
        task.spawn(function()
            local displayDuration = 2.8
            local elapsed = 0
            while elapsed < displayDuration do
                local dt = task.wait()
                if not ReplicatedStorage:GetAttribute("IsPaused") then
                    elapsed = elapsed + dt
                end
                if not container.Parent then return end
            end

            if not container.Parent then return end
            pulseGlow:Cancel()

            -- Çıkış Animasyonu (Hafifçe yukarı süzülerek pürüzsüz kaybolur)
            local fadeOutTop = TweenService:Create(topTag, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
            local fadeOutTopStroke = TweenService:Create(topStroke, TweenInfo.new(0.45), { Transparency = 1 })
            local fadeOutMain = TweenService:Create(mainTitle, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
            local fadeOutMainStroke = TweenService:Create(mainStroke, TweenInfo.new(0.45), { Transparency = 1 })
            local fadeOutGlow = TweenService:Create(glowTitle, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
            local fadeOutGlowStroke = TweenService:Create(glowStroke, TweenInfo.new(0.45), { Transparency = 1 })
            local driftPos = TweenService:Create(container, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0.25, 0)
            })

            fadeOutTop:Play()
            fadeOutTopStroke:Play()
            fadeOutMain:Play()
            fadeOutMainStroke:Play()
            fadeOutGlow:Play()
            fadeOutGlowStroke:Play()
            driftPos:Play()

            driftPos.Completed:Connect(function()
                if container and container.Parent then
                    container:Destroy()
                end
                if activeSwarmAnnouncement == container then
                    activeSwarmAnnouncement = nil
                end
            end)
        end)
    end

    local swarmWarningEvent = Events:FindFirstChild("SwarmWarning") or Events:WaitForChild("SwarmWarning", 10)
    if swarmWarningEvent then
        swarmWarningEvent.OnClientEvent:Connect(function()
            showSwarmWarning()
        end)
    end
    
    -- SİLAH GRUBU
    local weaponGroup = Instance.new("Frame")
    weaponGroup.Name = "WeaponGroup"
    weaponGroup.Size = UDim2.new(0, 380, 0, 94)
    weaponGroup.AnchorPoint = Vector2.new(1, 1)
    weaponGroup.Position = UDim2.new(1, -10, 1, -114)
    weaponGroup.BackgroundTransparency = 1
    weaponGroup.Parent = screenGui
    
    local wTitle = Instance.new("TextLabel")
    wTitle.Name = "Title"
    wTitle.Size = UDim2.new(1, 0, 0.25, 0)
    wTitle.BackgroundTransparency = 1
    wTitle.Text = "WEAPONS (MAX 3)"
    wTitle.TextColor3 = Color3.new(1, 1, 1)
    wTitle.Font = Enum.Font.FredokaOne
    wTitle.TextSize = 16
    wTitle.TextXAlignment = Enum.TextXAlignment.Right
    wTitle.TextStrokeTransparency = 0.5
    wTitle.Parent = weaponGroup

    local weaponSlotsContainer = Instance.new("Frame")
    weaponSlotsContainer.Name = "WeaponSlotsContainer"
    weaponSlotsContainer.Size = UDim2.new(1, 0, 0.75, 0)
    weaponSlotsContainer.Position = UDim2.new(0, 0, 0.25, 0)
    weaponSlotsContainer.BackgroundTransparency = 1
    weaponSlotsContainer.Parent = weaponGroup
    
    local wLayout = Instance.new("UIListLayout")
    wLayout.FillDirection = Enum.FillDirection.Horizontal
    wLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    wLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    wLayout.Padding = UDim.new(0, 6)
    wLayout.Parent = weaponSlotsContainer

    -- YETENEK GRUBU
    local perkGroup = Instance.new("Frame")
    perkGroup.Name = "PerkGroup"
    perkGroup.Size = UDim2.new(0, 380, 0, 94)
    perkGroup.AnchorPoint = Vector2.new(1, 1)
    perkGroup.Position = UDim2.new(1, -10, 1, -10)
    perkGroup.BackgroundTransparency = 1
    perkGroup.Parent = screenGui
    
    local pTitle = Instance.new("TextLabel")
    pTitle.Name = "Title"
    pTitle.Size = UDim2.new(1, 0, 0.25, 0)
    pTitle.BackgroundTransparency = 1
    pTitle.Text = "SCROLLS (MAX 3)"
    pTitle.TextColor3 = Color3.new(1, 1, 1)
    pTitle.Font = Enum.Font.FredokaOne
    pTitle.TextSize = 16
    pTitle.TextXAlignment = Enum.TextXAlignment.Right
    pTitle.TextStrokeTransparency = 0.5
    pTitle.Parent = perkGroup

    local perkSlotsContainer = Instance.new("Frame")
    perkSlotsContainer.Name = "PerkSlotsContainer"
    perkSlotsContainer.Size = UDim2.new(1, 0, 0.75, 0)
    perkSlotsContainer.Position = UDim2.new(0, 0, 0.25, 0)
    perkSlotsContainer.BackgroundTransparency = 1
    perkSlotsContainer.Parent = perkGroup
    
    local pLayout = Instance.new("UIListLayout")
    pLayout.FillDirection = Enum.FillDirection.Horizontal
    pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    pLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    pLayout.Padding = UDim.new(0, 6)
    pLayout.Parent = perkSlotsContainer
    
    updateActiveSlotsUI(screenGui)

    -- Güncelleme Dinleyicileri
    local currentLevel = 1
    local currentXP = 0
    local currentMaxXP = 100

    UpdateHealthEvent.OnClientEvent:Connect(function(health, maxHealth)
        local percent = math.clamp(health / maxHealth, 0, 1)
        TweenService:Create(healthFill, TweenInfo.new(0.3), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
        healthLabel.Text = "HP: " .. math.ceil(health) .. " / " .. math.ceil(maxHealth)
        
        if health <= 0 then
            healthLabel.Text = "DOWNED"
            healthLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        else
            healthLabel.TextColor3 = Color3.new(1, 1, 1)
        end
    end)

    UpdateXPEvent.OnClientEvent:Connect(function(xp, maxXp, level)
        currentXP = xp
        currentMaxXP = maxXp
        currentLevel = level
        
        local percent = math.clamp(xp / maxXp, 0, 1)
        TweenService:Create(xpFill, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
        xpLabel.Text = ""
        levelLabel.Text = "LV. " .. level
        
        updateActiveSlotsUI(screenGui)
    end)
    
    local UpdateCoinsEvent = Events:FindFirstChild("UpdateCoins")
    if UpdateCoinsEvent then
        UpdateCoinsEvent.OnClientEvent:Connect(function(coins)
            local lbl = container:FindFirstChild("CoinLabel")
            if lbl then
                lbl.Text = tostring(coins)
            end
        end)
    end
end


function createGameOverUI(level, xp, stats)
    if true then return end
    
    stats = stats or {}
    stats.DefeatedEnemies = stats.DefeatedEnemies or {}
    stats.WeaponDamage = stats.WeaponDamage or {}
    stats.MatchUpgrades = stats.MatchUpgrades or {}
    stats.Gold = stats.Gold or 0
    stats.Items = stats.Items or {}
    
    local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))
    
    -- Calculate total kills
    local totalKills = 0
    for _, count in pairs(stats.DefeatedEnemies) do
        totalKills = totalKills + count
    end
    
    -- Calculate game time string
    local gameTimeVal = ReplicatedStorage:FindFirstChild("GameTime")
    local totalSeconds = gameTimeVal and gameTimeVal.Value or 0
    local mins = math.floor(totalSeconds / 60)
    local secs = totalSeconds % 60
    local timeString = string.format("%02d:%02d", mins, secs)
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GameOverUI"
    screenGui.DisplayOrder = 1000
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = PlayerGui
    applyUIScale(screenGui)
    
    -- Hide other UIs
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "GameOverUI" then
            gui.Enabled = false
        end
    end
    
    -- Main full-screen background frame
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.Position = UDim2.new(0, 0, 0, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    bg.BackgroundTransparency = 1
    bg.Parent = screenGui
    
    TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 0.15}):Play()
    
    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 25, 45))
    })
    bgGradient.Rotation = 45
    bgGradient.Parent = bg
    
    -- Main Container Frame
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0.9, 0, 0.85, 0)
    container.Position = UDim2.new(0.5, 0, 0.48, 0)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundTransparency = 1
    container.Parent = bg
    
    -- Top Profile & Stat Panel
    local topPanel = Instance.new("Frame")
    topPanel.Size = UDim2.new(1, 0, 0.18, 0)
    topPanel.Position = UDim2.new(0, 0, 0, 0)
    topPanel.BackgroundColor3 = Color3.fromRGB(22, 24, 35)
    topPanel.Parent = container
    
    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 16)
    topCorner.Parent = topPanel
    
    local topStroke = Instance.new("UIStroke")
    topStroke.Thickness = 2.5
    topStroke.Color = Color3.fromRGB(0, 230, 120) -- Green neon border
    topStroke.Parent = topPanel
    
    -- Roblox Avatar Image
    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size = UDim2.new(0, 96, 0, 96)
    avatarImg.Position = UDim2.new(0, 20, 0.5, -48)
    avatarImg.BackgroundColor3 = Color3.fromRGB(30, 32, 45)
    avatarImg.BorderSizePixel = 0
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0.5, 0) -- Circular
    avatarCorner.Parent = avatarImg
    
    local avatarStroke = Instance.new("UIStroke")
    avatarStroke.Thickness = 2
    avatarStroke.Color = Color3.fromRGB(255, 255, 255)
    avatarStroke.Parent = avatarImg
    
    -- Load avatar thumbnail
    pcall(function()
        local avatarUrl = Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        avatarImg.Image = avatarUrl
    end)
    avatarImg.Parent = topPanel
    
    -- Player Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.2, 0, 0.4, 0)
    nameLabel.Position = UDim2.new(0, 132, 0.3, -10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = Player.DisplayName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 22
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = topPanel
    
    -- Stats Row inside Top Panel
    local statsContainer = Instance.new("Frame")
    statsContainer.Size = UDim2.new(0.7, 0, 0.8, 0)
    statsContainer.Position = UDim2.new(0.28, 0, 0.1, 0)
    statsContainer.BackgroundTransparency = 1
    statsContainer.Parent = topPanel
    
    local statsLayout = Instance.new("UIListLayout")
    statsLayout.FillDirection = Enum.FillDirection.Horizontal
    statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    statsLayout.Padding = UDim.new(0.02, 0)
    statsLayout.Parent = statsContainer
    
    local function createTopStat(iconId, valueText, color)
        local statBox = Instance.new("Frame")
        statBox.Size = UDim2.new(0.22, 0, 0.85, 0)
        statBox.BackgroundColor3 = Color3.fromRGB(30, 32, 45)
        statBox.Parent = statsContainer
        
        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 10)
        boxCorner.Parent = statBox
        
        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 32, 0, 32)
        icon.Position = UDim2.new(0.1, 0, 0.5, -16)
        icon.BackgroundTransparency = 1
        icon.Image = iconId
        icon.ImageColor3 = color or Color3.new(1, 1, 1)
        icon.Parent = statBox
        
        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.75, 0, 1, 0)
        val.Position = UDim2.new(0.25, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = valueText
        val.TextColor3 = color or Color3.new(1, 1, 1)
        val.Font = Enum.Font.GothamBold
        val.TextSize = 22
        val.TextXAlignment = Enum.TextXAlignment.Center
        val.Parent = statBox
        
        return statBox
    end
    
    -- Stats with icons: Skull, Star, Clock, Coin
    createTopStat("rbxassetid://6031267868", tostring(totalKills), Color3.fromRGB(255, 80, 80)) -- Kills (Skull icon)
    createTopStat("rbxassetid://6031225818", tostring(level) .. " Lv.", Color3.fromRGB(80, 180, 255)) -- Level (Star/Level icon)
    createTopStat("rbxassetid://6031278142", timeString, Color3.fromRGB(240, 240, 240)) -- Time (Clock icon)
    createTopStat("rbxassetid://126941861587473", "+" .. tostring(stats.Gold), Color3.fromRGB(255, 200, 50)) -- Gold (Coin icon)

    -- Three Columns Below
    local contentY = 0.21
    local contentHeight = 0.65
    
    -- 1. LEFT COLUMN: WEAPON DAMAGE ANALYSIS
    local leftCard = Instance.new("Frame")
    leftCard.Size = UDim2.new(0.31, 0, contentHeight, 0)
    leftCard.Position = UDim2.new(0, 0, contentY, 0)
    leftCard.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    leftCard.BorderSizePixel = 0
    leftCard.Parent = container
    
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 16)
    leftCorner.Parent = leftCard
    
    local leftStroke = Instance.new("UIStroke")
    leftStroke.Thickness = 2
    leftStroke.Color = Color3.fromRGB(0, 180, 255)
    leftStroke.Parent = leftCard
    
    local leftHeader = Instance.new("TextLabel")
    leftHeader.Size = UDim2.new(0.9, 0, 0.1, 0)
    leftHeader.Position = UDim2.new(0.05, 0, 0.03, 0)
    leftHeader.BackgroundTransparency = 1
    leftHeader.Text = "WEAPON DAMAGE"
    leftHeader.TextColor3 = Color3.fromRGB(0, 180, 255)
    leftHeader.Font = Enum.Font.GothamBold
    leftHeader.TextSize = 20
    leftHeader.TextXAlignment = Enum.TextXAlignment.Center
    leftHeader.Parent = leftCard
    
    local leftScroll = Instance.new("ScrollingFrame")
    leftScroll.Size = UDim2.new(0.9, 0, 0.82, 0)
    leftScroll.Position = UDim2.new(0.05, 0, 0.14, 0)
    leftScroll.BackgroundTransparency = 1
    leftScroll.BorderSizePixel = 0
    leftScroll.ScrollBarThickness = 6
    leftScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    leftScroll.Parent = leftCard
    
    local leftScrollLayout = Instance.new("UIListLayout")
    leftScrollLayout.FillDirection = Enum.FillDirection.Vertical
    leftScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftScrollLayout.Padding = UDim.new(0, 12)
    leftScrollLayout.Parent = leftScroll
    
    leftScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        leftScroll.CanvasSize = UDim2.new(0, 0, 0, leftScrollLayout.AbsoluteContentSize.Y + 20)
    end)
    
    -- Format helper
    local function formatNumber(n)
        local formatted = tostring(math.floor(n))
        local k
        while true do
            formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
            if k == 0 then break end
        end
        return formatted
    end
    
    -- Populate Weapon Damage
    local weaponLevels = {}
    local perkLevels = {}
    for _, upgradeKey in ipairs(stats.MatchUpgrades) do
        local base = UpgradeConfig.Upgrades[upgradeKey]
        if base then
            if base.Type == "Weapon" then
                weaponLevels[upgradeKey] = (weaponLevels[upgradeKey] or 0) + 1
            elseif base.Type == "Perk" then
                perkLevels[upgradeKey] = (perkLevels[upgradeKey] or 0) + 1
            end
        end
    end
    
    for weaponKey in pairs(stats.WeaponDamage) do
        if not weaponLevels[weaponKey] then
            weaponLevels[weaponKey] = 1
        end
    end
    
    local damageList = {}
    for weaponKey, dmg in pairs(stats.WeaponDamage) do
        local upgradeBase = UpgradeConfig.Upgrades[weaponKey]
        local name = upgradeBase and upgradeBase.Title or weaponKey
        local icon = upgradeBase and upgradeBase.Icon or ""
        local lvl = weaponLevels[weaponKey] or 1
        table.insert(damageList, { Key = weaponKey, Name = name, Damage = dmg, Icon = icon, Level = lvl })
    end
    table.sort(damageList, function(a, b) return a.Damage > b.Damage end)
    
    if #damageList > 0 then
        for i, entry in ipairs(damageList) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 56)
            row.BackgroundColor3 = Color3.fromRGB(30, 32, 45)
            row.BorderSizePixel = 0
            row.LayoutOrder = i
            row.Parent = leftScroll
            
            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 10)
            rowCorner.Parent = row
            
            local iconImg = Instance.new("ImageLabel")
            iconImg.Size = UDim2.new(0, 40, 0, 40)
            iconImg.Position = UDim2.new(0.05, 0, 0.5, -20)
            iconImg.BackgroundTransparency = 1
            iconImg.Image = entry.Icon
            iconImg.Parent = row
            
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.5, 0, 0.5, 0)
            nameLbl.Position = UDim2.new(0, 65, 0.1, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = entry.Name:upper()
            nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 14
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = row
            
            local lvlLbl = Instance.new("TextLabel")
            lvlLbl.Size = UDim2.new(0.5, 0, 0.4, 0)
            lvlLbl.Position = UDim2.new(0, 65, 0.55, 0)
            lvlLbl.BackgroundTransparency = 1
            lvlLbl.Text = "Level " .. tostring(entry.Level)
            lvlLbl.TextColor3 = Color3.fromRGB(150, 155, 170)
            lvlLbl.Font = Enum.Font.GothamBold
            lvlLbl.TextSize = 12
            lvlLbl.TextXAlignment = Enum.TextXAlignment.Left
            lvlLbl.Parent = row
            
            local dmgLbl = Instance.new("TextLabel")
            dmgLbl.Size = UDim2.new(0.35, 0, 1, 0)
            dmgLbl.Position = UDim2.new(0.65, -10, 0, 0)
            dmgLbl.BackgroundTransparency = 1
            dmgLbl.Text = formatNumber(entry.Damage) .. " DMG"
            dmgLbl.TextColor3 = Color3.fromRGB(255, 140, 0)
            dmgLbl.Font = Enum.Font.GothamBold
            dmgLbl.TextSize = 15
            dmgLbl.TextXAlignment = Enum.TextXAlignment.Right
            dmgLbl.Parent = row
            
            -- Hover effect
            row.MouseEnter:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 42, 58)}):Play()
            end)
            row.MouseLeave:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 32, 45)}):Play()
            end)
        end
    else
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, 0, 0, 50)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = "No weapon damage dealt."
        emptyLbl.TextColor3 = Color3.fromRGB(130, 135, 145)
        emptyLbl.Font = Enum.Font.GothamBold
        emptyLbl.TextSize = 15
        emptyLbl.TextXAlignment = Enum.TextXAlignment.Center
        emptyLbl.Parent = leftScroll
    end
    
    -- 2. MIDDLE COLUMN: MATCH INVENTORY (Weapons, Upgrades, Items)
    local middleCard = Instance.new("Frame")
    middleCard.Size = UDim2.new(0.34, 0, contentHeight, 0)
    middleCard.Position = UDim2.new(0.33, 0, contentY, 0)
    middleCard.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    middleCard.BorderSizePixel = 0
    middleCard.Parent = container
    
    local middleCorner = Instance.new("UICorner")
    middleCorner.CornerRadius = UDim.new(0, 16)
    middleCorner.Parent = middleCard
    
    local middleStroke = Instance.new("UIStroke")
    middleStroke.Thickness = 2
    middleStroke.Color = Color3.fromRGB(255, 200, 50)
    middleStroke.Parent = middleCard
    
    local middleHeader = Instance.new("TextLabel")
    middleHeader.Size = UDim2.new(0.9, 0, 0.1, 0)
    middleHeader.Position = UDim2.new(0.05, 0, 0.03, 0)
    middleHeader.BackgroundTransparency = 1
    middleHeader.Text = "MATCH INVENTORY"
    middleHeader.TextColor3 = Color3.fromRGB(255, 200, 50)
    middleHeader.Font = Enum.Font.GothamBold
    middleHeader.TextSize = 20
    middleHeader.TextXAlignment = Enum.TextXAlignment.Center
    middleHeader.Parent = middleCard
    
    local middleScroll = Instance.new("ScrollingFrame")
    middleScroll.Size = UDim2.new(0.9, 0, 0.82, 0)
    middleScroll.Position = UDim2.new(0.05, 0, 0.14, 0)
    middleScroll.BackgroundTransparency = 1
    middleScroll.BorderSizePixel = 0
    middleScroll.ScrollBarThickness = 6
    middleScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    middleScroll.Parent = middleCard
    
    local middleScrollLayout = Instance.new("UIListLayout")
    middleScrollLayout.FillDirection = Enum.FillDirection.Vertical
    middleScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    middleScrollLayout.Padding = UDim.new(0, 16)
    middleScrollLayout.Parent = middleScroll
    
    middleScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        middleScroll.CanvasSize = UDim2.new(0, 0, 0, middleScrollLayout.AbsoluteContentSize.Y + 20)
    end)
    
    local function createInventorySection(titleText, itemsData, layoutOrder)
        local sect = Instance.new("Frame")
        sect.Size = UDim2.new(1, 0, 0, 85)
        sect.BackgroundTransparency = 1
        sect.LayoutOrder = layoutOrder
        sect.Parent = middleScroll
        
        local sectHeader = Instance.new("TextLabel")
        sectHeader.Size = UDim2.new(1, 0, 0, 20)
        sectHeader.BackgroundTransparency = 1
        sectHeader.Text = titleText
        sectHeader.TextColor3 = Color3.fromRGB(180, 185, 200)
        sectHeader.Font = Enum.Font.GothamBold
        sectHeader.TextSize = 14
        sectHeader.TextXAlignment = Enum.TextXAlignment.Left
        sectHeader.Parent = sect
        
        local sectScroll = Instance.new("ScrollingFrame")
        sectScroll.Size = UDim2.new(1, 0, 0, 58)
        sectScroll.Position = UDim2.new(0, 0, 0, 22)
        sectScroll.BackgroundTransparency = 1
        sectScroll.BorderSizePixel = 0
        sectScroll.ScrollBarThickness = 4
        sectScroll.ScrollingDirection = Enum.ScrollingDirection.X
        sectScroll.CanvasSize = UDim2.new(0, #itemsData * 56, 0, 0)
        sectScroll.Parent = sect
        
        local sectLayout = Instance.new("UIListLayout")
        sectLayout.FillDirection = Enum.FillDirection.Horizontal
        sectLayout.SortOrder = Enum.SortOrder.LayoutOrder
        sectLayout.Padding = UDim.new(0, 8)
        sectLayout.Parent = sectScroll
        
        if #itemsData > 0 then
            for idx, item in ipairs(itemsData) do
                local iconBox = Instance.new("Frame")
                iconBox.Size = UDim2.new(0, 48, 0, 48)
                iconBox.BackgroundColor3 = Color3.fromRGB(30, 32, 45)
                iconBox.BorderSizePixel = 0
                iconBox.ClipsDescendants = true
                iconBox.LayoutOrder = idx
                iconBox.Parent = sectScroll
                
                local boxCorner = Instance.new("UICorner")
                boxCorner.CornerRadius = UDim.new(0, 8)
                boxCorner.Parent = iconBox
                
                local itemScale = item.Scale or 1.0
                local sX = 0.8 * itemScale
                local img = Instance.new("ImageLabel")
                img.Size = UDim2.new(sX, 0, sX, 0)
                img.Position = UDim2.new(0.5, 0, 0.5, 0)
                img.AnchorPoint = Vector2.new(0.5, 0.5)
                img.ScaleType = Enum.ScaleType.Fit
                img.BackgroundTransparency = 1
                img.Image = item.Icon
                img.Parent = iconBox
                
                local badge = Instance.new("TextLabel")
                badge.Size = UDim2.new(0.45, 0, 0.45, 0)
                badge.Position = UDim2.new(0.55, 0, 0.55, 0)
                badge.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                badge.Font = Enum.Font.GothamBold
                badge.Text = tostring(item.Value)
                badge.TextColor3 = Color3.fromRGB(255, 255, 255)
                badge.TextScaled = true
                badge.Parent = iconBox
                
                local badgeCorner = Instance.new("UICorner")
                badgeCorner.CornerRadius = UDim.new(0.5, 0)
                badgeCorner.Parent = badge
                
                local badgeStroke = Instance.new("UIStroke")
                badgeStroke.Color = Color3.fromRGB(255, 255, 255)
                badgeStroke.Thickness = 1
                badgeStroke.Parent = badge
            end
        else
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 1, 0)
            empty.BackgroundTransparency = 1
            empty.Text = "- Empty -"
            empty.TextColor3 = Color3.fromRGB(110, 115, 125)
            empty.Font = Enum.Font.GothamBold
            empty.TextSize = 13
            empty.TextXAlignment = Enum.TextXAlignment.Center
            empty.Parent = sectScroll
        end
    end
    
    -- Sub-section A: Weapons (Silahlar)
    local weaponsInv = {}
    for wKey, lvl in pairs(weaponLevels) do
        local upgradeBase = UpgradeConfig.Upgrades[wKey]
        if upgradeBase then
            table.insert(weaponsInv, { Icon = upgradeBase.Icon, Value = lvl, Scale = upgradeBase.IconScale })
        end
    end
    createInventorySection("WEAPONS", weaponsInv, 1)
    
    -- Sub-section B: Upgrades/Cards (Kartlar)
    local cardsInv = {}
    for pKey, lvl in pairs(perkLevels) do
        local upgradeBase = UpgradeConfig.Upgrades[pKey]
        if upgradeBase then
            table.insert(cardsInv, { Icon = upgradeBase.Icon, Value = lvl, Scale = upgradeBase.IconScale })
        end
    end
    createInventorySection("SCROLLS", cardsInv, 2)
    
    -- Sub-section C: Acquired Items (Alinan Esyalar)
    local itemsInv = {}
    for itemKey, count in pairs(stats.Items or {}) do
        if count > 0 then
            local itemInfo = ItemConfig.Items[itemKey]
            if itemInfo then
                table.insert(itemsInv, { Icon = itemInfo.Icon, Value = count, Scale = itemInfo.IconScale })
            end
        end
    end
    createInventorySection("ACQUIRED ITEMS", itemsInv, 3)
    
    -- 3. RIGHT COLUMN: NEW UNLOCKS
    local rightCard = Instance.new("Frame")
    rightCard.Size = UDim2.new(0.31, 0, contentHeight, 0)
    rightCard.Position = UDim2.new(0.69, 0, contentY, 0)
    rightCard.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    rightCard.BorderSizePixel = 0
    rightCard.Parent = container
    
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 16)
    rightCorner.Parent = rightCard
    
    local rightStroke = Instance.new("UIStroke")
    rightStroke.Thickness = 2
    rightStroke.Color = Color3.fromRGB(0, 230, 120) -- Neon green
    rightStroke.Parent = rightCard
    
    local rightHeader = Instance.new("TextLabel")
    rightHeader.Size = UDim2.new(0.9, 0, 0.1, 0)
    rightHeader.Position = UDim2.new(0.05, 0, 0.03, 0)
    rightHeader.BackgroundTransparency = 1
    rightHeader.Text = "NEW UNLOCKS"
    rightHeader.TextColor3 = Color3.fromRGB(0, 230, 120)
    rightHeader.Font = Enum.Font.GothamBold
    rightHeader.TextSize = 20
    rightHeader.TextXAlignment = Enum.TextXAlignment.Center
    rightHeader.Parent = rightCard
    
    local rScroll = Instance.new("ScrollingFrame")
    rScroll.Size = UDim2.new(0.9, 0, 0.82, 0)
    rScroll.Position = UDim2.new(0.05, 0, 0.14, 0)
    rScroll.BackgroundTransparency = 1
    rScroll.BorderSizePixel = 0
    rScroll.ScrollBarThickness = 6
    rScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    rScroll.Parent = rightCard
    
    local rLayout = Instance.new("UIListLayout")
    rLayout.FillDirection = Enum.FillDirection.Vertical
    rLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rLayout.Padding = UDim.new(0, 12)
    rLayout.Parent = rScroll
    
    rLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        rScroll.CanvasSize = UDim2.new(0, 0, 0, rLayout.AbsoluteContentSize.Y + 20)
    end)
    
    local unlockedList = {}
    for key, quest in pairs(ProgressionManager.Quests) do
        if Player:GetAttribute("NewlyUnlocked_" .. key) == true then
            table.insert(unlockedList, quest)
        end
    end
    
    if #unlockedList > 0 then
        for idx, quest in ipairs(unlockedList) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 56)
            row.BackgroundColor3 = Color3.fromRGB(30, 32, 45)
            row.BorderSizePixel = 0
            row.LayoutOrder = idx
            row.Parent = rScroll
            
            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 10)
            rowCorner.Parent = row
            
            local unlockLbl = Instance.new("TextLabel")
            unlockLbl.Size = UDim2.new(1, -20, 0.45, 0)
            unlockLbl.Position = UDim2.new(0, 10, 0.1, 0)
            unlockLbl.BackgroundTransparency = 1
            unlockLbl.Text = "🔓 " .. quest.Title:upper() .. " UNLOCKED!"
            unlockLbl.TextColor3 = Color3.fromRGB(0, 230, 120)
            unlockLbl.Font = Enum.Font.GothamBold
            unlockLbl.TextSize = 13
            unlockLbl.TextXAlignment = Enum.TextXAlignment.Left
            unlockLbl.Parent = row
            
            local descLbl = Instance.new("TextLabel")
            descLbl.Size = UDim2.new(1, -20, 0.4, 0)
            descLbl.Position = UDim2.new(0, 10, 0.52, 0)
            descLbl.BackgroundTransparency = 1
            descLbl.Text = quest.Description or ""
            descLbl.TextColor3 = Color3.fromRGB(160, 165, 175)
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.TextSize = 11
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
            descLbl.Parent = row
            
            -- Hover effect
            row.MouseEnter:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 42, 58)}):Play()
            end)
            row.MouseLeave:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 32, 45)}):Play()
            end)
        end
    else
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, 0, 0, 50)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = "No new unlocks this run."
        emptyLbl.TextColor3 = Color3.fromRGB(130, 135, 145)
        emptyLbl.Font = Enum.Font.GothamBold
        emptyLbl.TextSize = 15
        emptyLbl.TextXAlignment = Enum.TextXAlignment.Center
        emptyLbl.Parent = rScroll
    end
    
    -- RETURN TO LOBBY BUTTON
    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0.25, 0, 0.065, 0)
    confirmBtn.Position = UDim2.new(0.5, 0, 0.91, 0)
    confirmBtn.AnchorPoint = Vector2.new(0.5, 0)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    confirmBtn.Text = "RETURN TO LOBBY"
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = 20
    confirmBtn.Parent = bg
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = confirmBtn
    
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Thickness = 2
    btnStroke.Color = Color3.fromRGB(120, 200, 255)
    btnStroke.Parent = confirmBtn
    
    confirmBtn.MouseEnter:Connect(function()
        TweenService:Create(confirmBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 150, 255)}):Play()
    end)
    confirmBtn.MouseLeave:Connect(function()
        TweenService:Create(confirmBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 120, 255)}):Play()
    end)
    
    confirmBtn.MouseButton1Click:Connect(function()
        Events.ReturnToLobby:FireServer()
        screenGui:Destroy()
    end)
end

-- 2. DÜSMAN CAN BARLARI (BillboardGui)
local function createEnemyHealthBar(enemy) return end

local enemiesFolder = workspace:WaitForChild("Enemies")
enemiesFolder.ChildAdded:Connect(function(child)
    task.spawn(createEnemyHealthBar, child)
end)
for _, enemy in ipairs(enemiesFolder:GetChildren()) do
    createEnemyHealthBar(enemy)
end

-- 3. GELİŞTİRME KARTLARI (Upgrade UI)
local function createUpgradeUI(options, currentStats)
    local existingGui = PlayerGui:FindFirstChild("UpgradeUI")
    if existingGui then
        existingGui:Destroy()
    end

    ProximityPromptService.Enabled = false
    
    -- Seviye atlama kart seçim ekranındayken oyuncu hareketini kesin olarak dondur
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hum and hum.WalkSpeed > 0 then
        hum.WalkSpeed = 0
    end
    if hrp then
        hrp.Anchored = true
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UpgradeUI"
    screenGui.Parent = PlayerGui
    applyUIScale(screenGui)
    screenGui.DisplayOrder = 100
    
    screenGui.Destroying:Connect(function()
        if not PlayerGui:FindFirstChild("ChestAwardUI") then
            ProximityPromptService.Enabled = true
        end
        -- DİKKAT: Oyun duraklatılmışsa veya oyuncu kart seçmeye devam ediyorsa (Reroll dahil) ASLA hareketi çözme!
        if ReplicatedStorage:GetAttribute("IsPaused") == true or Player:GetAttribute("IsChoosingUpgrade") == true then
            return
        end
        if hum then
            local speedBonus = Player:GetAttribute("SpeedBonus") or 0
            local baseSpeed = 17 + speedBonus
            local isSprinting = Player:GetAttribute("IsSprinting") == true
            hum.WalkSpeed = isSprinting and (baseSpeed * 1.5) or baseSpeed
        end
        if hrp then
            hrp.Anchored = false
        end
    end)
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(10, 0, 10, 0)
    bg.Position = UDim2.new(-4.5, 0, -4.5, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 10, 25)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.Parent = screenGui
    
    TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 0.6}):Play()

    -- Ana Panel (Şeffaf Konteyner)
    local mainPanel = Instance.new("Frame")
    mainPanel.Size = UDim2.new(0.7, 0, 0.75, 0)
    mainPanel.Position = UDim2.new(0.15, 0, 0.125, 0)
    mainPanel.BackgroundTransparency = 1
    mainPanel.BorderSizePixel = 0
    mainPanel.Parent = screenGui
    
    -- Başlık (Panel İçinde)
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.15, 0)
    titleLabel.Position = UDim2.new(0, 0, 0.02, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "UPGRADE OFFERS"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.Font = Enum.Font.FredokaOne
    titleLabel.TextSize = 48
    titleLabel.TextStrokeTransparency = 0
    titleLabel.TextStrokeColor3 = Color3.new(0,0,0)
    titleLabel.Parent = mainPanel
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0.94, 0, 0.72, 0)
    container.Position = UDim2.new(0.03, 0, 0.16, 0)
    container.BackgroundTransparency = 1
    container.Parent = mainPanel
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0.02, 0)
    layout.Parent = container

    -- Silah element renkleri: Açık, ferah ve silaha özel renk tonları
    local weaponColorMap = {
        LightningWeapon = {
            Bg = Color3.fromHex("53bcff"),     -- Kullanıcının istediği #53bcff (Açık elektrik mavisi)
            Bottom = Color3.fromHex("2e93dc"),
            Stroke = Color3.fromHex("c4edff"),
        },
        Lightning = {
            Bg = Color3.fromHex("53bcff"),
            Bottom = Color3.fromHex("2e93dc"),
            Stroke = Color3.fromHex("c4edff"),
        },
        FireTrailWeapon = {
            Bg = Color3.fromHex("ff7034"),     -- Canlı sıcak alev turuncusu
            Bottom = Color3.fromHex("d94814"),
            Stroke = Color3.fromHex("ffd2bc"),
        },
        FireTrail = {
            Bg = Color3.fromHex("ff7034"),
            Bottom = Color3.fromHex("d94814"),
            Stroke = Color3.fromHex("ffd2bc"),
        },
        SnowballWeapon = {
            Bg = Color3.fromHex("74c6ff"),     -- Açık tatlı kar/buz mavisi
            Bottom = Color3.fromHex("469bda"),
            Stroke = Color3.fromHex("d8efff"),
        },
        Snowball = {
            Bg = Color3.fromHex("74c6ff"),
            Bottom = Color3.fromHex("469bda"),
            Stroke = Color3.fromHex("d8efff"),
        },
        FireballWeapon = {
            Bg = Color3.fromHex("ff5c47"),     -- Canlı ateş kırmızısı
            Bottom = Color3.fromHex("d63925"),
            Stroke = Color3.fromHex("ffb8ad"),
        },
        Fireball = {
            Bg = Color3.fromHex("ff5c47"),
            Bottom = Color3.fromHex("d63925"),
            Stroke = Color3.fromHex("ffb8ad"),
        },
        BulletWeapon = {
            Bg = Color3.fromHex("f5ab38"),     -- Canlı pirinç/altın sarısı
            Bottom = Color3.fromHex("cf8519"),
            Stroke = Color3.fromHex("ffe2aa"),
        },
        Bullet = {
            Bg = Color3.fromHex("f5ab38"),
            Bottom = Color3.fromHex("cf8519"),
            Stroke = Color3.fromHex("ffe2aa"),
        },
        SpikedArmorWeapon = {
            Bg = Color3.fromHex("748396"),     -- Çelik / Dikenli Demir Gri-Mavi
            Bottom = Color3.fromHex("465463"),
            Stroke = Color3.fromHex("c6d3df"),
        },
        SpikedArmor = {
            Bg = Color3.fromHex("748396"),
            Bottom = Color3.fromHex("465463"),
            Stroke = Color3.fromHex("c6d3df"),
        },
        TurretWeapon = {
            Bg = Color3.fromHex("f59e0b"),     -- Amber / Bakır Turuncu
            Bottom = Color3.fromHex("d97706"),
            Stroke = Color3.fromHex("fde68a"),
        },
        Turret = {
            Bg = Color3.fromHex("f59e0b"),
            Bottom = Color3.fromHex("d97706"),
            Stroke = Color3.fromHex("fde68a"),
        },
    }

    local rerollBtn = nil
    local skipBtn = nil

    for i = 1, math.min(3, #options) do
        local opt = options[i]
        local upgradeKey = opt.Key
        local bonusValue = opt.Value
        local subKey = opt.SubKey
        local isUnlocking = opt.IsUnlocking
        local isMilestone = opt.IsMilestone == true
        local rarityName = opt.RarityName or "Common"
        local upgradeBase = UpgradeConfig.Upgrades[upgradeKey] or (UpgradeConfig.TurretMilestones and UpgradeConfig.TurretMilestones[subKey or upgradeKey]) or { Title = opt.Title or "OVERCLOCK", Icon = opt.Icon }
        local currentLvl = (currentStats.Upgrades and currentStats.Upgrades[upgradeKey] or 0)
        local isWeaponUnlock = (not isMilestone) and (isUnlocking or (currentLvl == 0 and upgradeBase and upgradeBase.Type == "Weapon"))
        
        local cardColor = Color3.fromRGB(120, 120, 120) -- Common / Default
        local strokeColor = Color3.fromRGB(220, 220, 220)
        local weaponColor = weaponColorMap[upgradeKey]

        if isWeaponUnlock and weaponColor then
            cardColor = weaponColor.Bg
            strokeColor = weaponColor.Stroke
        elseif rarityName == "New" then 
            if weaponColor then
                cardColor = weaponColor.Bg
                strokeColor = weaponColor.Stroke
            else
                cardColor = Color3.fromRGB(70, 75, 85)
                strokeColor = Color3.fromRGB(180, 185, 195)
            end
        elseif rarityName == "Uncommon" then 
            cardColor = Color3.fromRGB(0, 120, 0)
            strokeColor = Color3.fromRGB(60, 240, 90)
        elseif rarityName == "Epic" then 
            cardColor = Color3.fromRGB(120, 0, 180)
            strokeColor = Color3.fromRGB(210, 90, 255)
        elseif rarityName == "Rare" then 
            cardColor = Color3.fromRGB(0, 100, 160)
            strokeColor = Color3.fromRGB(50, 190, 255)
        elseif rarityName == "Legendary" then 
            cardColor = Color3.fromRGB(200, 150, 0) 
            strokeColor = Color3.fromRGB(255, 215, 40)
        end
        
        local card = Instance.new("TextButton")
        card.Name = upgradeKey
        card.LayoutOrder = i
        card.Size = UDim2.new(1, 0, 0.31, 0)
        card.BackgroundColor3 = cardColor
        card.BackgroundTransparency = 0
        card.BorderSizePixel = 0
        card.ClipsDescendants = true -- Efektlerin kartın dışına taşmasını kesin olarak önler
        card.Text = ""
        card.Parent = container
        
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = strokeColor
        stroke.Thickness = (isWeaponUnlock or rarityName == "Epic" or rarityName == "Legendary") and 4 or 3
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        -- Yeni silah kartlarına özel şık dikey gradyan
        if isWeaponUnlock and weaponColor then
            local cardGrad = Instance.new("UIGradient", card)
            cardGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, weaponColor.Bg),
                ColorSequenceKeypoint.new(1, weaponColor.Bottom)
            })
            cardGrad.Rotation = 90
        end
        
        -- KART İÇİ CANLI VEYA HIZLI EFEKTLER (Kartın içinde kalır, dışarı taşmaz)
        if rarityName == "Rare" then
            -- RARE: Sağdan sola yumuşak ve geniş kayan ışık parıltısı (Yavaş ve geniş çizgi)
            local shimmer = Instance.new("Frame")
            shimmer.Name = "RareShimmer"
            shimmer.Size = UDim2.new(1, 0, 1, 0)
            shimmer.BackgroundTransparency = 0.70
            shimmer.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
            shimmer.ZIndex = 1
            shimmer.Parent = card
            
            local gradient = Instance.new("UIGradient", shimmer)
            gradient.Rotation = 35
            gradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 120, 200)),
                ColorSequenceKeypoint.new(0.3, Color3.fromRGB(0, 120, 200)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 250, 255)),
                ColorSequenceKeypoint.new(0.7, Color3.fromRGB(0, 120, 200)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 120, 200))
            })
            gradient.Offset = Vector2.new(1.3, 0)
            TweenService:Create(gradient, TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false), {Offset = Vector2.new(-1.3, 0)}):Play()
            
        elseif rarityName == "Epic" then
            -- EPIC: Orijinal Mor Renginde Canlı Gradyan Zemin (Legendary gibi Beyaz Katman Üstüne Gradyan - Kararmaz)
            
            -- 1. Zemin: Orijinal Mor Renginde Canlı Gradyan (Kararma Olmaz)
            local epicAurora = Instance.new("Frame")
            epicAurora.Name = "EpicAurora"
            epicAurora.Size = UDim2.new(1, 0, 1, 0)
            epicAurora.BackgroundTransparency = 0
            epicAurora.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Beyaz katman sayesinde renkler tam parlaklığında görünür
            epicAurora.BorderSizePixel = 0
            epicAurora.ZIndex = 1
            epicAurora.Parent = card
            
            local epicGradient = Instance.new("UIGradient", epicAurora)
            epicGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 55, 240)), -- Canlı açık mor (üst)
                ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 30, 175))  -- Klasik zengin mor (alt)
            })
            epicGradient.Rotation = 90
            
            -- 2. Kartın Dışına Yağan Parlak Mor Neon Bloom Aurası (Outer Glow Frame - ZIndex = 0)
            local outerBloom = Instance.new("Frame")
            outerBloom.Name = "EpicOuterBloom"
            outerBloom.Size = UDim2.new(1.04, 0, 1.10, 0)
            outerBloom.AnchorPoint = Vector2.new(0.5, 0.5)
            outerBloom.Position = UDim2.new(0.5, 0, 0.5, 0)
            outerBloom.BackgroundColor3 = Color3.fromRGB(210, 60, 255)
            outerBloom.BackgroundTransparency = 0.65
            outerBloom.BorderSizePixel = 0
            outerBloom.ZIndex = 0 -- Kartın tam arkasında neon parlama
            outerBloom.Parent = card
            
            local bloomCorner = Instance.new("UICorner", outerBloom)
            bloomCorner.CornerRadius = UDim.new(0, 14)
            
            -- Dış neon auranın görkemli nefes alması (Pulsing Outer Neon Halo)
            TweenService:Create(outerBloom, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Size = UDim2.new(1.07, 0, 1.16, 0),
                BackgroundTransparency = 0.25
            }):Play()
            
            -- 3. Kartın Kenarlarında Parlayan Kalın Neon Çerçeve Halesi (Inner Neon Border Stroke - ZIndex = 1)
            local epicStroke = Instance.new("UIStroke", card)
            epicStroke.Color = Color3.fromRGB(255, 130, 255)
            epicStroke.Thickness = 4
            epicStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            
            TweenService:Create(epicStroke, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Color = Color3.fromRGB(200, 70, 255),
                Thickness = 5
            }):Play()
            
            -- 4. Yazıların Arkasında Kalan (ZIndex = 1) 6 Adet Mistik Elmas Kıvılcım
            local sparklePositions = {
                UDim2.new(0.12, 0, 0.25, 0),
                UDim2.new(0.88, 0, 0.20, 0),
                UDim2.new(0.35, 0, 0.75, 0),
                UDim2.new(0.70, 0, 0.80, 0),
                UDim2.new(0.50, 0, 0.18, 0),
                UDim2.new(0.20, 0, 0.70, 0)
            }
            
            for idx, pos in ipairs(sparklePositions) do
                local sparkle = Instance.new("Frame")
                sparkle.Name = "EpicSparkle_" .. idx
                sparkle.Size = UDim2.new(0, 4, 0, 4)
                sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
                sparkle.Position = pos
                sparkle.BackgroundColor3 = Color3.fromRGB(255, 235, 255)
                sparkle.BackgroundTransparency = 1
                sparkle.Rotation = 45
                sparkle.BorderSizePixel = 0
                sparkle.ZIndex = 1 -- YAZILARIN TAM ARKASINDA KALIR (ZIndex = 1)
                sparkle.Parent = card
                
                Instance.new("UICorner", sparkle).CornerRadius = UDim.new(0, 2)
                
                local delayTime = (idx * 0.3) % 1.8
                task.delay(delayTime, function()
                    if not card or not card.Parent or not sparkle or not sparkle.Parent then return end
                    
                    -- Kıvılcım çakım animasyonu (Twinkle pulse)
                    TweenService:Create(sparkle, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true), {
                        Size = UDim2.new(0, 16, 0, 16),
                        BackgroundTransparency = 0.05,
                        Rotation = 225
                    }):Play()
                end)
            end

        elseif rarityName == "Legendary" then
            -- LEGENDARY: Görkemli Çift Dönen Çark (Altın + Beyaz Işık), Dış Işıma Aurası & Çakımlı Beyaz Elmas Parlamaları
            
            -- 0. Kartın Arkasında Nefes Alan Dış Beyaz & Altın Işıma Aurası (Outer Radiant Glow Frame - ZIndex = 0)
            local outerLegBloom = Instance.new("Frame")
            outerLegBloom.Name = "LegendaryOuterBloom"
            outerLegBloom.Size = UDim2.new(1.05, 0, 1.12, 0)
            outerLegBloom.AnchorPoint = Vector2.new(0.5, 0.5)
            outerLegBloom.Position = UDim2.new(0.5, 0, 0.5, 0)
            outerLegBloom.BackgroundColor3 = Color3.fromRGB(255, 245, 200)
            outerLegBloom.BackgroundTransparency = 0.60
            outerLegBloom.BorderSizePixel = 0
            outerLegBloom.ZIndex = 0
            outerLegBloom.Parent = card
            
            local legBloomCorner = Instance.new("UICorner", outerLegBloom)
            legBloomCorner.CornerRadius = UDim.new(0, 14)
            
            TweenService:Create(outerLegBloom, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Size = UDim2.new(1.08, 0, 1.18, 0),
                BackgroundTransparency = 0.20
            }):Play()
            
            -- 1. Kart Kenarlarında Nefes Alan İç Altın Enerji Halesi
            local goldAura = Instance.new("Frame")
            goldAura.Name = "LegendaryGoldAura"
            goldAura.Size = UDim2.new(1, 0, 1, 0)
            goldAura.BackgroundColor3 = Color3.fromRGB(255, 215, 60)
            goldAura.BackgroundTransparency = 0.75
            goldAura.BorderSizePixel = 0
            goldAura.ZIndex = 1
            goldAura.Parent = card
            
            local auraGradient = Instance.new("UIGradient", goldAura)
            auraGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 235, 120)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 180, 40)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 235, 120))
            })
            auraGradient.Rotation = 45
            
            TweenService:Create(goldAura, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                BackgroundTransparency = 0.40
            }):Play()
            
            -- 2A. Saat Yönünde Dönen Altın Güneş Çarkı (Gold Sunwheel - Clockwise)
            local legWheel = Instance.new("ImageLabel")
            legWheel.Name = "LegendaryWheel"
            legWheel.Size = UDim2.new(2.6, 0, 5.2, 0)
            legWheel.Position = UDim2.new(-0.8, 0, -2.1, 0)
            legWheel.BackgroundTransparency = 1
            legWheel.Image = "rbxassetid://5028824237"
            legWheel.ImageColor3 = Color3.fromRGB(255, 225, 90)
            legWheel.ImageTransparency = 0.60
            legWheel.ZIndex = 1
            legWheel.Parent = card
            
            TweenService:Create(legWheel, TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()
            
            -- 2B. İKİNCİL KATMAN: Ters Yöne Dönen Beyaz Işık Işınları Katmanı (White Light Ray Wheel - Counter Clockwise)
            local legWhiteWheel = Instance.new("ImageLabel")
            legWhiteWheel.Name = "LegendaryWhiteWheel"
            legWhiteWheel.Size = UDim2.new(3.0, 0, 6.0, 0)
            legWhiteWheel.Position = UDim2.new(-1.0, 0, -2.5, 0)
            legWhiteWheel.BackgroundTransparency = 1
            legWhiteWheel.Image = "rbxassetid://5028824237"
            legWhiteWheel.ImageColor3 = Color3.fromRGB(255, 255, 255)
            legWhiteWheel.ImageTransparency = 0.82
            legWhiteWheel.ZIndex = 1
            legWhiteWheel.Parent = card
            
            TweenService:Create(legWhiteWheel, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = -360}):Play()

            -- 3. Kart Kenarlarında Ve Köşelerinde Çakan Beyaz Elmas Işık Parlamaları (Yazıların Arkasında - ZIndex = 1)
            local diamondPositions = {
                UDim2.new(0.04, 0, 0.15, 0), -- Sol üst köşe
                UDim2.new(0.96, 0, 0.15, 0), -- Sağ üst köşe
                UDim2.new(0.04, 0, 0.85, 0), -- Sol alt köşe
                UDim2.new(0.96, 0, 0.85, 0), -- Sağ alt köşe
                UDim2.new(0.50, 0, 0.08, 0), -- Üst orta kenar
                UDim2.new(0.50, 0, 0.92, 0), -- Alt orta kenar
                UDim2.new(0.02, 0, 0.50, 0), -- Sol orta kenar
                UDim2.new(0.98, 0, 0.50, 0)  -- Sağ orta kenar
            }
            
            for idx, pos in ipairs(diamondPositions) do
                local whiteDiamond = Instance.new("Frame")
                whiteDiamond.Name = "WhiteDiamondFlash_" .. idx
                whiteDiamond.Size = UDim2.new(0, 2, 0, 2)
                whiteDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
                whiteDiamond.Position = pos
                whiteDiamond.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                whiteDiamond.BackgroundTransparency = 1
                whiteDiamond.Rotation = 45
                whiteDiamond.BorderSizePixel = 0
                whiteDiamond.ZIndex = 1 -- KESİNLİKLE YAZILARIN ARKASINDA (ZIndex = 1)
                whiteDiamond.Parent = card
                
                Instance.new("UICorner", whiteDiamond).CornerRadius = UDim.new(0, 2)
                
                local diamondStroke = Instance.new("UIStroke", whiteDiamond)
                diamondStroke.Color = Color3.fromRGB(255, 255, 255)
                diamondStroke.Thickness = 1.2
                diamondStroke.Transparency = 1
                
                local flashDelay = (idx * 0.25) % 2.0
                task.delay(flashDelay, function()
                    if not card or not card.Parent or not whiteDiamond or not whiteDiamond.Parent then return end
                    
                    -- Yıldız ve Elmas Çakım Döngüsü (Yazıları Kapatmayan Yumuşak Işıma)
                    TweenService:Create(whiteDiamond, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true), {
                        Size = UDim2.new(0, 14, 0, 14),
                        BackgroundTransparency = 0.35, -- Yazıyı kapatmayacak yumuşaklıkta
                        Rotation = 225
                    }):Play()
                    
                    TweenService:Create(diamondStroke, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true), {
                        Transparency = 0.4
                    }):Play()
                end)
            end
        end
        
        local iconBg = Instance.new("Frame", card)
        iconBg.Size = UDim2.new(0, 100, 0, 100)
        iconBg.Position = UDim2.new(0, 20, 0.5, -50)
        iconBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        iconBg.BackgroundTransparency = 0.85
        iconBg.ZIndex = 2
        Instance.new("UICorner", iconBg).CornerRadius = UDim.new(0, 10)
        
        local iconScale = upgradeBase.IconScale or 1.0
        local icon = Instance.new("ImageLabel", iconBg)
        icon.Size = UDim2.new(0.85 * iconScale, 0, 0.85 * iconScale, 0)
        icon.Position = UDim2.new((1 - (0.85 * iconScale))/2, 0, (1 - (0.85 * iconScale))/2, 0)
        icon.BackgroundTransparency = 1
        icon.Image = opt.Icon or (upgradeBase and upgradeBase.Icon) or "rbxassetid://116127630902574"

        -- Yazı Alanı (Sağda - ZIndex = 5 ile Arka Plan Efektlerinin Tam Üstünde)
        local infoFrame = Instance.new("Frame", card)
        infoFrame.Size = UDim2.new(0.72, -140, 1, 0)
        infoFrame.Position = UDim2.new(0, 135, 0, 0)
        infoFrame.BackgroundTransparency = 1
        infoFrame.ZIndex = 5
        
        local title = Instance.new("TextLabel", infoFrame)
        title.Size = isMilestone and UDim2.new(1, 0, 0.38, 0) or UDim2.new(1, 0, 0.46, 0)
        title.Position = UDim2.new(0, 0, isMilestone and 0.05 or 0.08, 0)
        title.BackgroundTransparency = 1
        title.ZIndex = 5
        title.Text = opt.Title or (upgradeBase and upgradeBase.Title) or "OVERCLOCK"
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Font = Enum.Font.FredokaOne
        title.TextSize = isMilestone and 25 or 33
        title.TextWrapped = true
        title.TextStrokeTransparency = 0
        title.TextStrokeColor3 = Color3.new(0,0,0)
        title.TextXAlignment = Enum.TextXAlignment.Left
        
        local bonusDesc = Instance.new("TextLabel", infoFrame)
        bonusDesc.Size = isMilestone and UDim2.new(1, 0, 0.58, 0) or UDim2.new(1, 0, 0.52, 0)
        bonusDesc.Position = UDim2.new(0, 0, isMilestone and 0.40 or 0.44, 0)
        bonusDesc.BackgroundTransparency = 1
        bonusDesc.ZIndex = 5
        
        -- Değer Hesaplama ve Metin Formatlama (Mevcut -> Yeni)
        local function formatStatLine(lKey, disp, bVal)
            local curVal, nextVal = 0, 0
            local unit = ""
            local cardBonus = currentStats.UpgradeBonuses and currentStats.UpgradeBonuses[lKey] or 0

            -- Mermi hızı etiketini kesin olarak "Projectile Speed" yap
            if lKey == "FireballSpeed" or lKey == "BulletSpeed" or lKey == "SnowballSpeed" or (disp == "Speed" and lKey ~= "Speed") then
                disp = "Projectile Speed"
            end

            -- Kritik şansı etiketini kesin olarak "Crit Chance" yap
            if lKey == "CritChance" or string.find(lKey, "CritChance") ~= nil or disp == "Crit %" then
                disp = "Crit Chance"
            end

            if lKey == "Damage" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "Speed" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "Magnet" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "Vitality" then
                curVal = 100 + cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "Regeneration" then
                curVal = cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "AttackSpeed" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "FireballDamage" then
                curVal = 12 + cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "FireballRadius" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "FireballSpeed" or lKey == "BulletSpeed" or lKey == "SnowballSpeed" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "CritChance" or string.find(lKey, "CritChance") ~= nil then
                -- Taban kritik şansı (%10) + Varsa silaha özel mevcut bonus
                local globalCrit = (currentStats and currentStats.CritChance) or 0.10
                local weaponBonus = 0
                if lKey ~= "CritChance" then
                    weaponBonus = (currentStats and currentStats[lKey]) or cardBonus or 0
                end
                curVal = (globalCrit + weaponBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "CritMultiplier" or string.find(lKey, "CritDamage") ~= nil or string.find(lKey, "CritMultiplier") ~= nil then
                -- Taban kritik hasar çarpanı (1.5x) + Varsa silaha özel mevcut bonus
                local globalMult = (currentStats and currentStats.CritMultiplier) or 1.5
                local weaponBonus = 0
                if lKey ~= "CritMultiplier" then
                    weaponBonus = (currentStats and currentStats[lKey]) or cardBonus or 0
                end
                curVal = globalMult + weaponBonus
                nextVal = curVal + (bVal or 0)
                unit = "x"
            elseif lKey == "FireTrailDamage" then
                curVal = 6 + cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "FireTrailRadius" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "FireTrailDuration" then
                curVal = 3.0 + cardBonus
                nextVal = curVal + (bVal or 0)
                unit = "s"
            elseif lKey == "BulletDamage" then
                curVal = 8 + cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "BulletCount" then
                curVal = (currentStats and currentStats.BulletCount) or 1
                nextVal = curVal + (bVal or 1)
            elseif lKey == "FireballCount" then
                curVal = (currentStats and currentStats.FireballCount) or 1
                nextVal = curVal + (bVal or 1)
            elseif lKey == "FireTrailCount" then
                curVal = (currentStats and currentStats.FireTrailCount) or 1
                nextVal = curVal + (bVal or 1)
            elseif lKey == "LightningCount" then
                curVal = (currentStats and currentStats.LightningCount) or 1
                nextVal = curVal + (bVal or 1)
            elseif lKey == "LightningBounces" then
                curVal = (currentStats and currentStats.LightningBounces) or 3
                nextVal = curVal + (bVal or 1)
            elseif lKey == "LightningRange" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "SnowballCount" then
                curVal = (currentStats and currentStats.SnowballCount) or 1
                nextVal = curVal + (bVal or 1)
            elseif lKey == "SnowballSlowPct" then
                curVal = (0.20 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "SnowballDuration" then
                curVal = 1.5 + cardBonus
                nextVal = curVal + (bVal or 0)
                unit = "s"
            elseif lKey == "SpikedArmorDamage" then
                curVal = 12 + cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "SpikedArmorCooldown" then
                curVal = math.max(1.5, 5.0 - cardBonus)
                nextVal = math.max(1.5, curVal - (bVal or 0))
                unit = "s"
            elseif lKey == "SpikedArmorKnockback" then
                curVal = 3.0 + cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "SpikedArmorRadius" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "Volley" or lKey == "ProjectileCount" then
                curVal = 1 + cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "TurretDamage" then
                curVal = (currentStats and currentStats.TurretDamage) or (16 + cardBonus)
                nextVal = curVal + (bVal or 0)
            elseif lKey == "TurretFireRate" then
                local atkBonus = (currentStats and currentStats.TurretAttackSpeedBonus) or cardBonus
                curVal = math.floor((1 + atkBonus) * 100 + 0.5)
                nextVal = curVal + math.floor(((bVal or 0) * 100) + 0.5)
                unit = "%"
            elseif lKey == "TurretDuration" then
                curVal = (currentStats and currentStats.TurretDuration) or (25 + cardBonus)
                nextVal = curVal + (bVal or 0)
                unit = "s"
            elseif lKey == "TurretCostReduction" then
                curVal = (currentStats and currentStats.TurretCost) or Player:GetAttribute("TurretCost") or 100
                local pct = (bVal and bVal > 1) and (bVal / 100) or (bVal or 0.10)
                local reduction = math.max(5, math.floor(curVal * pct + 0.5))
                nextVal = math.max(10, curVal - reduction)
                unit = ""
            elseif lKey == "TurretCount" then
                curVal = 1 + (currentStats and currentStats.TurretExtraShots or 0)
                nextVal = curVal + (bVal or 1)
            elseif lKey == "TurretRange" then
                curVal = (1 + cardBonus) * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "Lifesteal" or lKey == "XPBoost" or lKey == "AreaMultiplier" or lKey == "AreaSize" or lKey == "Luck" then
                curVal = cardBonus * 100
                nextVal = curVal + ((bVal or 0) * 100)
                unit = "%"
            elseif lKey == "LightningDamage" then
                curVal = 8 + cardBonus
                nextVal = curVal + (bVal or 0)
            elseif lKey == "SnowballDamage" then
                curVal = 5 + cardBonus
                nextVal = curVal + (bVal or 0)
            else
                curVal = cardBonus
                nextVal = curVal + (bVal or 0)
            end

            local arrowColorHex = "#444444"
            if rarityName == "Uncommon" then arrowColorHex = "#004a00"
            elseif rarityName == "Rare" then arrowColorHex = "#00385c"
            elseif rarityName == "Epic" then arrowColorHex = "#3d005c"
            elseif rarityName == "Legendary" then arrowColorHex = "#8a6800" end

            -- Yüzdeler (%), Sayılar (Count), Düz Hasarlar ve Tam Sayı İstatistikler tam sayı yazılır
            -- DİKKAT: CritDamage çarpanı (x) ASLA tam sayıya yuvarlanmaz, ondalığı (ör. 1.75x) korunur!
            -- DİKKAT: Mermi/Sayı (Count, ProjectileCount) ondalıklı (ör. 2.5) olabileceği için cleanNum ile ondalık desteği korunur!
            local isCritDamage = (lKey == "CritMultiplier") or (string.find(lKey, "CritDamage") ~= nil) or (string.find(lKey, "CritMultiplier") ~= nil)
            local isCountStat = (string.find(lKey, "Count") ~= nil) or (lKey == "Volley") or (lKey == "ProjectileCount") or (lKey == "TurretCount")
            local isIntegerStat = not isCritDamage and not isCountStat and ((unit == "%") or (
                string.find(lKey, "Damage") ~= nil or
                string.find(lKey, "Bounces") ~= nil or
                string.find(lKey, "CritChance") ~= nil or
                lKey == "Vitality" or
                lKey == "TurretCostReduction"
            ))

            local curStr, nextStr
            if isIntegerStat then
                curStr = string.format("%.0f", math.floor(curVal + 0.5))
                nextStr = string.format("%.0f", math.floor(nextVal + 0.5))
            else
                local function cleanNum(v)
                    local rounded = math.floor(v * 100 + 0.5) / 100
                    if math.abs(rounded - math.floor(rounded + 0.5)) < 0.005 then
                        return string.format("%.0f", math.floor(rounded + 0.5))
                    end
                    local s = string.format("%.2f", rounded)
                    s = string.gsub(s, "%.?0+$", "")
                    return s
                end
                curStr = cleanNum(curVal)
                nextStr = cleanNum(nextVal)
            end

            local formatStr = "%s: %s%s <font face='GothamBold' color='" .. arrowColorHex .. "'> -> </font> <font color='#55FF55'>%s%s</font>"
            return string.format(formatStr, disp or "Stat", curStr, unit, nextStr, unit)
        end

        bonusDesc.RichText = true
        if isMilestone then
            bonusDesc.Text = opt.Description or "Special Turret Overclock"
            bonusDesc.TextSize = 18
        elseif isUnlocking then
            bonusDesc.Text = upgradeBase.Description or (upgradeBase.Title or "New Unlock!")
            bonusDesc.TextSize = 25
        elseif opt.IsDual and opt.SubKey2 and opt.Value2 then
            local l1 = formatStatLine(subKey or upgradeKey, opt.SubStatDisplay or upgradeBase.StatDisplay, bonusValue)
            local l2 = formatStatLine(opt.SubKey2, opt.SubStatDisplay2, opt.Value2)
            bonusDesc.Text = l1 .. "\n" .. l2
            bonusDesc.TextSize = 24
            bonusDesc.LineHeight = 1.12
            title.Size = UDim2.new(1, 0, 0.35, 0)
            title.Position = UDim2.new(0, 0, 0.05, 0)
            title.TextTruncate = Enum.TextTruncate.AtEnd
            bonusDesc.Size = UDim2.new(1, 0, 0.60, 0)
            bonusDesc.Position = UDim2.new(0, 0, 0.37, 0)
        else
            bonusDesc.Text = formatStatLine(subKey or upgradeKey, opt.SubStatDisplay or upgradeBase.StatDisplay, bonusValue)
            bonusDesc.TextSize = 26
            bonusDesc.Size = UDim2.new(1, 0, 0.50, 0)
            bonusDesc.Position = UDim2.new(0, 0, 0.44, 0)
        end
        bonusDesc.TextColor3 = Color3.new(1, 1, 1) -- Ana yazı beyaz, değerler RichText ile renkli
        bonusDesc.Font = Enum.Font.FredokaOne
        bonusDesc.TextWrapped = true
        bonusDesc.TextStrokeTransparency = 0
        bonusDesc.TextStrokeColor3 = Color3.new(0,0,0)
        bonusDesc.TextXAlignment = Enum.TextXAlignment.Left

        -- Sağ Taraf (Nadirlik Etiketi & Level / NEW Bilgisi)
        local rightInfo = Instance.new("Frame", card)
        rightInfo.Size = UDim2.new(0.28, 0, 0.85, 0)
        rightInfo.Position = UDim2.new(0.70, -10, 0.075, 0)
        rightInfo.BackgroundTransparency = 1
        rightInfo.ZIndex = 4
        
        local rightLayout = Instance.new("UIListLayout", rightInfo)
        rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rightLayout.Padding = UDim.new(0, 2)



        -- currentLvl ve isWeaponUnlock döngünün başında hesaplandı

        if isWeaponUnlock then
            -- Silah Açılış Kartlarında Nadirlik Yazılmaz, Sadece BÜYÜK "NEW" Yazar
            local unlockLabel = Instance.new("TextLabel", rightInfo)
            unlockLabel.Name = "LevelLabel"
            unlockLabel.LayoutOrder = 1
            unlockLabel.Size = UDim2.new(1, 0, 0, 32)
            unlockLabel.BackgroundTransparency = 1
            unlockLabel.ZIndex = 4
            unlockLabel.Text = "NEW"
            unlockLabel.TextColor3 = Color3.fromRGB(255, 215, 50)
            unlockLabel.Font = Enum.Font.FredokaOne
            unlockLabel.TextSize = 28 -- BÜYÜTÜLDÜ (22 -> 28)
            unlockLabel.TextStrokeTransparency = 0
            unlockLabel.TextStrokeColor3 = Color3.new(0,0,0)
            unlockLabel.TextXAlignment = Enum.TextXAlignment.Right
        else
            -- 1. Nadirlik Etiketi (Level'ın Üstünde, Ekstra Büyütülmüş)
            local rarityTag = Instance.new("TextLabel", rightInfo)
            rarityTag.Name = "RarityTag"
            rarityTag.LayoutOrder = 1
            rarityTag.Size = UDim2.new(1, 0, 0, 28)
            rarityTag.BackgroundTransparency = 1
            rarityTag.ZIndex = 4
            rarityTag.Text = string.upper(rarityName)
            rarityTag.TextColor3 = Color3.fromRGB(220, 220, 220) -- Common
            if rarityName == "Uncommon" then rarityTag.TextColor3 = Color3.fromRGB(130, 255, 130)
            elseif rarityName == "Epic" then rarityTag.TextColor3 = Color3.fromRGB(255, 140, 255)
            elseif rarityName == "Rare" then rarityTag.TextColor3 = Color3.fromRGB(130, 200, 255)
            elseif rarityName == "Legendary" then rarityTag.TextColor3 = Color3.fromRGB(255, 215, 50) end
            rarityTag.Font = Enum.Font.FredokaOne
            rarityTag.TextSize = 24 -- BÜYÜTÜLDÜ (20 -> 24)
            rarityTag.TextStrokeTransparency = 0
            rarityTag.TextStrokeColor3 = Color3.new(0,0,0)
            rarityTag.TextXAlignment = Enum.TextXAlignment.Right

            -- 2. Seviye Etiketi (LVL)
            local lvlLabel = Instance.new("TextLabel", rightInfo)
            lvlLabel.Name = "LevelLabel"
            lvlLabel.LayoutOrder = 2
            lvlLabel.Size = UDim2.new(1, 0, 0, 30)
            lvlLabel.BackgroundTransparency = 1
            lvlLabel.ZIndex = 4
            if isMilestone then
                lvlLabel.Text = "OVERCLOCK"
                lvlLabel.TextSize = 17
                lvlLabel.TextColor3 = Color3.fromRGB(255, 215, 50)
            else
                lvlLabel.Text = "LVL " .. (currentLvl + 1)
                lvlLabel.TextColor3 = Color3.fromRGB(255, 215, 50)
                lvlLabel.TextSize = 26
            end
            lvlLabel.Font = Enum.Font.FredokaOne
            lvlLabel.TextStrokeTransparency = 0
            lvlLabel.TextStrokeColor3 = Color3.new(0,0,0)
            lvlLabel.TextXAlignment = Enum.TextXAlignment.Right
        end

        -- Animasyonlar
        card.MouseEnter:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.1), {Size = UDim2.new(1.02, 0, 0.33, 0), BackgroundTransparency = 0}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.1), {Color = Color3.new(1,1,1)}):Play()
        end)
        
        card.MouseLeave:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 0.31, 0), BackgroundTransparency = 0}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.1), {Color = strokeColor}):Play()
        end)

        card.MouseButton1Click:Connect(function()
            for _, c in ipairs(container:GetChildren()) do
                if c:IsA("TextButton") then c.Interactable = false end
            end
            if rerollBtn then rerollBtn.Interactable = false end
            if skipBtn then skipBtn.Interactable = false end
            
            Events.ApplyUpgrade:FireServer(upgradeKey, bonusValue, subKey)
            
            task.delay(0.1, function()
                updateActiveSlotsUI()
            end)
            TweenService:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            TweenService:Create(mainPanel, TweenInfo.new(0.3), {Position = UDim2.new(0.225, 0, 1.5, 0)}):Play()
            task.delay(0.3, function() screenGui:Destroy() end)
        end)
        
        -- Geliş Animasyonu
        card.Size = UDim2.new(0.8, 0, 0.31, 0)
        card.BackgroundTransparency = 1
        task.delay(i * 0.1, function()
            if card.Parent then
                TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1, 0, 0.31, 0),
                    BackgroundTransparency = 0
                }):Play()
            end
        end)
    end
    
    -- REROLL BUTONU (Daha Büyük)
    local freeRerolls = currentStats.FreeRerolls or 0
    local rerollCost = currentStats.RerollCost or 10
    rerollBtn = Instance.new("TextButton")
    rerollBtn.Name = "RerollBtn"
    rerollBtn.Size = UDim2.new(0.4, 0, 0.08, 0)
    rerollBtn.Position = UDim2.new(0.05, 0, 0.88, 0)
    
    if freeRerolls > 0 then
        rerollBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 90) -- Canlı Yeşil (Bedava!)
        rerollBtn.Text = "FREE REROLL (" .. freeRerolls .. " Left)"
        rerollBtn.TextColor3 = Color3.new(1, 1, 1)
        rerollBtn.Interactable = true
    else
        rerollBtn.BackgroundColor3 = Color3.fromRGB(85, 145, 195) -- Açık silik mavi
        rerollBtn.Text = "REROLL (" .. rerollCost .. " Coins)"
        rerollBtn.TextColor3 = Color3.new(1, 1, 1)
        if currentStats.Coins and currentStats.Coins < rerollCost then
            rerollBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            rerollBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
            rerollBtn.Interactable = false
        end
    end
    rerollBtn.Font = Enum.Font.FredokaOne
    rerollBtn.TextSize = 22
    rerollBtn.Parent = mainPanel
    Instance.new("UICorner", rerollBtn).CornerRadius = UDim.new(0, 8)
    
    -- SKIP BUTONU (Daha Büyük)
    skipBtn = Instance.new("TextButton")
    skipBtn.Name = "SkipBtn"
    skipBtn.Size = UDim2.new(0.4, 0, 0.08, 0)
    skipBtn.Position = UDim2.new(0.55, 0, 0.88, 0)
    skipBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    skipBtn.Text = "SKIP"
    skipBtn.TextColor3 = Color3.new(1, 1, 1)
    skipBtn.Font = Enum.Font.FredokaOne
    skipBtn.TextSize = 22
    skipBtn.Parent = mainPanel
    Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 8)

    rerollBtn.MouseButton1Click:Connect(function()
        if not rerollBtn.Interactable then return end
        rerollBtn.Interactable = false
        skipBtn.Interactable = false
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("TextButton") then c.Interactable = false end
        end
        rerollBtn.Text = "REROLLING..."
        
        local RerollUpgradesEvent = Events:FindFirstChild("RerollUpgrades")
        if RerollUpgradesEvent then RerollUpgradesEvent:FireServer() end
        -- screenGui'yi burada gecikmeli kapatmıyoruz; sunucu yeni kartları gönderdiğinde
        -- createUpgradeUI mevcut UI'ı dondurmayı hiç bozmadan pürüzsüzce tazeleyecektir.
    end)

    skipBtn.MouseButton1Click:Connect(function()
        rerollBtn.Interactable = false
        skipBtn.Interactable = false
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("TextButton") then c.Interactable = false end
        end
        Events.ApplyUpgrade:FireServer("Skip")
        
        TweenService:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(mainPanel, TweenInfo.new(0.3), {Position = UDim2.new(0.225, 0, 1.5, 0)}):Play()
        task.delay(0.3, function() screenGui:Destroy() end)
    end)
end

-- Seviye atlama sinyalini dinle
Events:WaitForChild("LevelUp").OnClientEvent:Connect(function(level, options, currentStats)
    if options and #options > 0 then
        createUpgradeUI(options, currentStats)
    end
end)
Events:WaitForChild("HideRevivePrompt").OnClientEvent:Connect(function()
    local char = Player.Character
    if char then
        -- SALDIRI VE HAREKETI ISTEMCIDE DE DURDUR
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            local animator = hum:FindFirstChild("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop(0)
                end
            end
        end

        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            -- Prompt'un olusmasi için ok kisa bir süre bekle (Replikasyon gecikmesi için)
            task.delay(0.1, function()
                local prompt = root:FindFirstChild("RevivePrompt")
                if prompt then
                    prompt.Enabled = false
                end
            end)
        end
    end
end)

createPlayerHUD()

-- ITEM STORAGE & CHEST OPENING SYSTEM
local ProximityPromptService = game:GetService("ProximityPromptService")
local PlayChestAnimationEvent = Events:WaitForChild("PlayChestAnimation")
local ChestAwardedEvent = Events:WaitForChild("ChestAwarded")
local ChestClaimedEvent = Events:WaitForChild("ChestClaimed")

updateActiveItemsUI = function(screenGui)
    if not screenGui then
        screenGui = PlayerGui:FindFirstChild("PlayerHUD")
    end
    if screenGui then
        local itemsContainer = screenGui:FindFirstChild("ItemsContainer")
        if itemsContainer then
            itemsContainer:Destroy()
        end
    end
    return
end

-- BindableEvent to listen to inventory updates from other client scripts (like ChestUIController)
local UpdateInventoryUI = Events:FindFirstChild("UpdateInventoryUI")
if not UpdateInventoryUI then
    UpdateInventoryUI = Instance.new("BindableEvent")
    UpdateInventoryUI.Name = "UpdateInventoryUI"
    UpdateInventoryUI.Parent = Events
end

UpdateInventoryUI.Event:Connect(function()
    local hud = PlayerGui:FindFirstChild("PlayerHUD")
    if hud then
        updateActiveSlotsUI(hud)
    end
end)

-- Silah devre dışı bırakma attribute değişikliklerini dinle
Player.AttributeChanged:Connect(function(attr)
    if string.find(attr, "^DisabledWeapon_") then
        local hud = PlayerGui:FindFirstChild("PlayerHUD")
        if hud then
            updateActiveSlotsUI(hud)
        end
    end
end)

-- Initial HUD setup update
task.spawn(function()
    local hud = PlayerGui:WaitForChild("PlayerHUD", 10)
    if hud then
        updateActiveItemsUI(hud)
    end
end)