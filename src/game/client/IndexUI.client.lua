--!strict
-- IndexUI (LocalScript) -> StarterPlayer > StarterPlayerScripts
-- Piksel / koyu yeşil "UNLOCKS" tarzı Index arayüzü.
-- Tamamen kodla oluşturulur, Studio'da elle UI yapmana gerek yok.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionManager"))
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- AYARLAR
----------------------------------------------------------------
local Config = {
	Title = "INDEX",
	ToggleKey = Enum.KeyCode.I,
	Font = Enum.Font.Arcade, -- piksel font. İstersen Enum.Font.Code yap
}

local Theme = {
	Panel       = Color3.fromRGB(28, 42, 37),
	PanelDark   = Color3.fromRGB(20, 31, 27),
	Header      = Color3.fromRGB(38, 68, 58),
	TabActive   = Color3.fromRGB(28, 42, 37),
	TabIdle     = Color3.fromRGB(33, 56, 48),
	Slot        = Color3.fromRGB(122, 138, 142),
	SlotLocked  = Color3.fromRGB(44, 52, 52),
	SlotReady   = Color3.fromRGB(45, 95, 70),
	Border      = Color3.fromRGB(150, 135, 120), -- bronz çerçeve
	BorderDark  = Color3.fromRGB(14, 20, 18),
	BorderReady = Color3.fromRGB(80, 200, 120),
	Text        = Color3.fromRGB(240, 236, 224),
	TextDim     = Color3.fromRGB(150, 160, 155),
	Check       = Color3.fromRGB(255, 232, 60),
	Red         = Color3.fromRGB(230, 40, 40),
	Green       = Color3.fromRGB(35, 155, 75),
	GreenHover  = Color3.fromRGB(45, 185, 90),
}

----------------------------------------------------------------
-- VERİ
----------------------------------------------------------------
type Entry = {
	name: string,
	icon: string,
	unlocked: boolean,
	claimed: boolean?,
	desc: string?,
	hint: string?,
	scale: number?,
	key: string?,
	cost: number?,
	isQuestDone: boolean?,
	progress: number?,
	target: number?,
}

local function getItemStatus(key: string?)
	if not key then
		return {
			isUnlocked = true,
			isQuestDone = true,
			progress = 0,
			target = 0,
			cost = 0,
			quest = nil,
		}
	end

	local quest = ProgressionManager.Quests[key]
	local isUnlocked = player:GetAttribute("Unlocked_" .. key) == true
	local target = (quest and quest.Target) or 1
	local progress = player:GetAttribute("Progress_" .. key) or 0
	local isQuestDone = isUnlocked
		or (progress >= target)
		or (player:GetAttribute("QuestCompleted_" .. key) == true)
		or (player:GetAttribute("NewlyCompletedQuest_" .. key) == true)
	local cost = (quest and quest.UnlockCost) or 25

	return {
		isUnlocked = isUnlocked,
		isQuestDone = isQuestDone,
		progress = progress,
		target = target,
		cost = cost,
		quest = quest,
	}
end

local function makeEntry(name: string, icon: string, scale: number, desc: string, key: string?, hint: string?): Entry
	local status = getItemStatus(key)
	return {
		name = name,
		icon = icon,
		scale = scale,
		desc = desc,
		hint = hint or (status.quest and status.quest.Description),
		key = key,
		unlocked = status.isUnlocked,
		claimed = status.isUnlocked,
		isQuestDone = status.isQuestDone,
		progress = status.progress,
		target = status.target,
		cost = status.cost,
	}
end

local function getData(): { [string]: { Entry } }
	return {
		Weapons = {
			makeEntry("Bullet",         "rbxassetid://121994932649054", 1.15, "Fires high-speed bullets directly at the nearest target."),
			makeEntry("Fireball",       "rbxassetid://125265167476470", 1.35, "Launches explosive fiery spheres dealing area of effect damage."),
			makeEntry("Frost Snowball", "rbxassetid://81692544462569",  1.40, "Hurls freezing snowballs that slow and damage enemies."),
			makeEntry("Lightning",      "rbxassetid://78042234318237",  1.25, "Calls down lightning bolts that bounce between nearby enemies."),
			makeEntry("Turret",         "rbxassetid://116127630902574", 1.12, "Deploys automated combat turrets that shred nearby hostiles."),
			makeEntry("Fire Trail",     "rbxassetid://133361532069305", 1.08, "Leaves an infernal burning trail behind you that burns monsters.", "FireTrailWeapon", "Defeat 5 monsters at once with Fireball."),
			makeEntry("Spiked Armor",   "rbxassetid://97729722814774",  1.25, "Inflicts return damage and heavy knockback on attacking foes.", "SpikedArmorWeapon", "Take 300 damage in total across matches."),
		},
		Scrolls = {
			makeEntry("Damage Scroll",           "rbxassetid://136816438423321", 1.45, "Increases all weapon damage by a percentage."),
			makeEntry("Health Scroll",           "rbxassetid://121321337790833", 1.45, "Increases maximum health capacity."),
			makeEntry("XP Scroll",               "rbxassetid://99019752047882",  1.40, "Increases experience points gained from crystals.", "XPBoost", "Break 20 pots in a single match."),
			makeEntry("Luck Scroll",             "rbxassetid://124295705156617", 1.35, "+10% Luck per level (Higher rarity scrolls & chest items).", "Luck", "Find and collect a Luck Scroll dropped by a monster."),
			makeEntry("Attack Speed Scroll",     "rbxassetid://111855876294905", 1.40, "Reduces weapon cooldowns and increases attack speed."),
			makeEntry("Projectile Count Scroll", "rbxassetid://101001542265389", 1.30, "Adds extra projectiles to equipped ranged weapons.", "ProjectileCount", "Fire 3,000 projectiles in total across matches."),
			makeEntry("Lifesteal Scroll",        "rbxassetid://80370021530658",  1.35, "Heals you for a portion of damage dealt to monsters.", "Lifesteal", "Reach 2.5 or more Health Regeneration."),
			makeEntry("Speed",            "rbxassetid://129436264954195", 1.22, "Increases player movement speed."),
			makeEntry("Magnet",           "rbxassetid://86235492740853",  1.24, "Increases pickup range for gems and coins."),
			makeEntry("Size",             "rbxassetid://76536499349513",  1.24, "Increases attack and explosion size of all weapons.", "AreaSize", "Deal damage to 10 targets at once with a single weapon attack."),
			makeEntry("Regeneration",     "rbxassetid://77668620961118",  1.26, "Gradually restores health per second over time.", "Regeneration", "Upgrade Health 3 times."),
			makeEntry("Crit Chance",      "rbxassetid://70609716017598", 1.24, "Increases chance to land critical strikes for bonus damage.", "CritChance", "Deal 10 critical hits in a single match."),
		},
		Monsters = {
			makeEntry("Slime",          "rbxassetid://92131315850362",  1.05, "Bouncy green slime. Fast and persistent in large swarms."),
			makeEntry("Zombie",         "rbxassetid://93261504869253",  1.05, "Standard undead horde enemy. Slow moving but lethal up close."),
			makeEntry("Fast Zombie",    "rbxassetid://73309065587857",  1.05, "Agile and rapid runner zombie that sprints toward survivors."),
			makeEntry("Armored Zombie", "rbxassetid://113437280682700", 1.05, "Heavily armored brute with high resistance and crushing blows."),
			makeEntry("Mega Zombie",    "rbxassetid://110114708389769", 1.05, "Colossal boss monster with devastating damage and massive health."),
		},
		Items = {
			makeEntry("Assassin's Dagger", "rbxassetid://93774505146481",  1.10, "+10% Attack Damage per stack."),
			makeEntry("Iron Plating",      "rbxassetid://93850208491165", 1.10, "-2 Damage taken from all hits per stack."),
			makeEntry("Healing Ring",      "rbxassetid://134854765599380", 1.12, "+25% Healing and Regen per stack."),
			makeEntry("Blood Blade",       "rbxassetid://123017566034664", 1.40, "+1 Health restored on kill per stack."),
			makeEntry("Fire Tome",         "rbxassetid://130199164992973", 1.10, "+25% Fire Weapon Damage per stack."),
			makeEntry("Hunter's Gloves",   "rbxassetid://136724572151361", 1.14, "+10% Projectile Speed per stack."),
			makeEntry("Weird Glasses",     "rbxassetid://71360950886930",  1.25, "+8% XP Gain per stack."),
			makeEntry("Lucky Clover",      "rbxassetid://131375222063624", 1.15, "+5% Luck per stack (Better Chest & Upgrade Rarity)."),
			makeEntry("Sniper Scope",      "rbxassetid://119974502384687", 1.10, "Damage increases up to +100% standing still. Resets on move."),
			makeEntry("Magnetic Compass",  "rbxassetid://71378683667776",  2.25, "+15% Magnet Collection Range per stack.", "compass", "Collect 400 collectables (crystals/coins) in total."),
			makeEntry("Piggy Bank",        "rbxassetid://80065483190470",  2.10, "+15% XP and Gold from Pots & Bushes per stack.", "piggy_bank", "Break or open 50 pots / bushes in total."),
		},
	}
end

local TabOrder = { "Weapons", "Scrolls", "Monsters", "Items" }

----------------------------------------------------------------
-- YARDIMCILAR
----------------------------------------------------------------
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
	}, parent)
end

local function label(parent: Instance, text: string, size: number, color: Color3?, props: { [string]: any }?)
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		Font = Config.Font,
		TextColor3 = color or Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	if props then
		for k, v in pairs(props) do
			l[k] = v
		end
	end
	return l
end

----------------------------------------------------------------
-- ANA UI
----------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "IndexUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 50,
	Enabled = false,
}, playerGui)

local dim = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
}, gui)

local main = make("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1020, 680),
	BackgroundColor3 = Theme.Panel,
	BorderSizePixel = 0,
}, gui)
stroke(main, Theme.Border, 3)
stroke(main, Theme.BorderDark, 1)

local uiScale = make("UIScale", {}, main)
local function updateScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X / 1060, vp.Y / 720), 0.5, 1.35)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- Başlık
local header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundColor3 = Theme.Header,
	BorderSizePixel = 0,
}, main)

label(header, Config.Title, 30, Theme.Text, {
	Position = UDim2.fromOffset(20, 0),
	Size = UDim2.new(0.4, 0, 1, 0),
})

-- Header Silver Badge
local silverBadge = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -190, 0.5, 0),
	Size = UDim2.fromOffset(130, 32),
	BackgroundColor3 = Color3.fromRGB(20, 31, 27),
	BorderSizePixel = 0,
}, header)
stroke(silverBadge, Theme.Border, 1)

make("ImageLabel", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 6, 0.5, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Image = ProgressionManager.SILVER_ICON,
	ResampleMode = Enum.ResamplerMode.Pixelated,
	ScaleType = Enum.ScaleType.Fit,
}, silverBadge)

local silverText = label(silverBadge, tostring(ProgressionManager.GetSilver(player)), 20, Color3.fromRGB(245, 248, 255), {
	Position = UDim2.new(0, 34, 0, 0),
	Size = UDim2.new(1, -38, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
})

local function updateHeaderSilver()
	local s = ProgressionManager.GetSilver(player)
	silverText.Text = tostring(s)
end

local counter = label(header, "0/0", 20, Theme.TextDim, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -66, 0, 0),
	Size = UDim2.fromOffset(110, 48),
	TextXAlignment = Enum.TextXAlignment.Right,
})

local closeBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(34, 34),
	BackgroundTransparency = 1,
	Text = "X",
	TextSize = 36,
	Font = Config.Font,
	TextColor3 = Theme.Red,
	AutoButtonColor = false,
}, header)

-- Sekmeler
local tabBar = make("Frame", {
	Position = UDim2.fromOffset(0, 48),
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = Theme.PanelDark,
	BorderSizePixel = 0,
}, main)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

-- Izgara alanı
local gridHolder = make("ScrollingFrame", {
	Position = UDim2.fromOffset(18, 102),
	Size = UDim2.new(1, -36, 0, 416),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Theme.Border,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(96, 96),
	CellPadding = UDim2.fromOffset(14, 14),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, gridHolder)
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, gridHolder)

-- Alt detay paneli
local detail = make("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 150),
	BackgroundColor3 = Theme.PanelDark,
	BorderSizePixel = 0,
}, main)
stroke(detail, Theme.Border, 2)

local detailSlot = make("Frame", {
	Position = UDim2.fromOffset(22, 27),
	Size = UDim2.fromOffset(96, 96),
	BackgroundColor3 = Theme.Slot,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, detail)
stroke(detailSlot, Theme.Border, 2)

local detailIcon = make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.8, 0.8),
	BackgroundTransparency = 1,
	ResampleMode = Enum.ResamplerMode.Pixelated,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 1,
}, detailSlot)

local detailLock = make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.55, 0.55),
	BackgroundTransparency = 1,
	Image = "rbxassetid://72480127691513",
	ImageColor3 = Color3.fromRGB(240, 235, 220),
	ResampleMode = Enum.ResamplerMode.Pixelated,
	ScaleType = Enum.ScaleType.Fit,
	Visible = false,
	ZIndex = 3,
}, detailSlot)

local detailName = label(detail, "", 28, Theme.Text, {
	Position = UDim2.fromOffset(136, 20),
	Size = UDim2.new(1, -380, 0, 32),
})

local detailDesc = label(detail, "Select an item.", 19, Theme.TextDim, {
	Position = UDim2.fromOffset(136, 56),
	Size = UDim2.new(1, -380, 0, 80),
	RichText = true,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
})

-- Sağ Taraf İşlem / Satın Alma Paneli
local actionContainer = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -22, 0.5, 0),
	Size = UDim2.fromOffset(210, 84),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, detail)

local unlockedBadge = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(22, 42, 32),
	BorderSizePixel = 0,
	Visible = false,
}, actionContainer)
stroke(unlockedBadge, Color3.fromRGB(60, 130, 80), 2)

label(unlockedBadge, "✓ UNLOCKED", 22, Color3.fromRGB(120, 235, 145), {
	Size = UDim2.fromScale(1, 1),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
})

local unlockBtn = make("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Green,
	BorderSizePixel = 0,
	AutoButtonColor = true,
	Text = "",
	Visible = false,
}, actionContainer)
local unlockBtnStroke = stroke(unlockBtn, Color3.fromRGB(140, 255, 170), 2)

local unlockContent = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, unlockBtn)

local unlockActionText = label(unlockContent, "UNLOCK", 22, Color3.fromRGB(255, 255, 255), {
	Position = UDim2.new(0, 0, 0, 8),
	Size = UDim2.new(1, 0, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Center,
})

local unlockPriceRow = make("Frame", {
	Position = UDim2.new(0, 0, 0, 38),
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
}, unlockContent)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
}, unlockPriceRow)

make("ImageLabel", {
	Size = UDim2.fromOffset(26, 26),
	BackgroundTransparency = 1,
	Image = ProgressionManager.SILVER_ICON,
	ResampleMode = Enum.ResamplerMode.Pixelated,
	ScaleType = Enum.ScaleType.Fit,
}, unlockPriceRow)

local unlockCostText = label(unlockPriceRow, "25", 22, Color3.fromRGB(255, 255, 255), {
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
})

local lockedStatusLabel = label(unlockBtn, "🔒 LOCKED", 20, Color3.fromRGB(160, 170, 165), {
	Size = UDim2.fromScale(1, 1),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	Visible = false,
})

----------------------------------------------------------------
-- MANTIK
----------------------------------------------------------------
local currentTab = TabOrder[1]
local tabButtons: { [string]: TextButton } = {}
local selectedSlotInfo: { slot: GuiObject, stroke: UIStroke, defaultColor: Color3 }? = nil
local currentShowingEntry: Entry? = nil
local unlockBtnActive = false

local function showDetail(entry: Entry)
	currentShowingEntry = entry
	local s = math.clamp(0.88 * (entry.scale or 1.0), 0.5, 2.50)
	detailIcon.Size = UDim2.fromScale(s, s)

	local playerSilver = ProgressionManager.GetSilver(player)

	if entry.unlocked then
		detailName.Text = entry.name
		detailName.TextColor3 = Theme.Text
		detailDesc.Text = entry.desc or ""
		detailIcon.Image = entry.icon
		detailIcon.ImageColor3 = Color3.new(1, 1, 1)
		detailIcon.ImageTransparency = 0
		detailLock.Visible = false
		detailSlot.BackgroundColor3 = Theme.Slot

		unlockedBadge.Visible = true
		unlockBtn.Visible = false
		unlockBtnActive = false

	elseif entry.isQuestDone then
		detailName.Text = entry.name
		detailName.TextColor3 = Color3.fromRGB(255, 220, 60)
		detailDesc.Text = entry.desc or ""

		detailIcon.Image = entry.icon
		detailIcon.ImageColor3 = Color3.new(1, 1, 1)
		detailIcon.ImageTransparency = 0
		detailLock.Visible = false
		detailSlot.BackgroundColor3 = Theme.SlotReady

		unlockedBadge.Visible = false
		unlockBtn.Visible = true
		unlockContent.Visible = true
		lockedStatusLabel.Visible = false

		local cost = entry.cost or 25
		if playerSilver >= cost then
			unlockActionText.Text = "UNLOCK"
			unlockActionText.TextColor3 = Color3.fromRGB(255, 255, 255)
			unlockCostText.Text = tostring(cost)
			unlockCostText.TextColor3 = Color3.fromRGB(255, 255, 255)
			unlockBtn.BackgroundColor3 = Theme.Green
			unlockBtnStroke.Color = Color3.fromRGB(140, 255, 170)
			unlockBtn.AutoButtonColor = true
			unlockBtnActive = true
		else
			unlockActionText.Text = "NEED SILVER"
			unlockActionText.TextColor3 = Color3.fromRGB(255, 160, 160)
			unlockCostText.Text = string.format("%d (%d/%d)", cost, playerSilver, cost)
			unlockCostText.TextColor3 = Color3.fromRGB(255, 160, 160)
			unlockBtn.BackgroundColor3 = Color3.fromRGB(80, 42, 45)
			unlockBtnStroke.Color = Color3.fromRGB(160, 60, 60)
			unlockBtn.AutoButtonColor = false
			unlockBtnActive = false
		end

	else
		detailName.Text = "???"
		detailName.TextColor3 = Theme.TextDim

		local progressText = ""
		if entry.target and entry.target > 0 then
			progressText = string.format(" [Progress: %s / %s]", tostring(entry.progress or 0), tostring(entry.target))
		end
		detailDesc.Text = (entry.hint and ("Locked: " .. entry.hint .. progressText)) or "Locked: Not unlocked yet."

		detailIcon.Image = entry.icon
		detailIcon.ImageColor3 = Color3.fromRGB(20, 26, 26)
		detailIcon.ImageTransparency = 0.35
		detailLock.Visible = true
		detailSlot.BackgroundColor3 = Theme.SlotLocked

		unlockedBadge.Visible = false
		unlockBtn.Visible = true
		unlockContent.Visible = false
		lockedStatusLabel.Visible = true
		lockedStatusLabel.Text = "🔒 LOCKED"
		lockedStatusLabel.TextColor3 = Color3.fromRGB(160, 170, 165)
		unlockBtn.BackgroundColor3 = Color3.fromRGB(38, 48, 42)
		unlockBtnStroke.Color = Color3.fromRGB(60, 75, 65)
		unlockBtn.AutoButtonColor = false
		unlockBtnActive = false
	end
end

local function selectSlot(slot: GuiObject, st: UIStroke, defaultColor: Color3, entry: Entry)
	if selectedSlotInfo and selectedSlotInfo.slot ~= slot then
		local prevStroke = selectedSlotInfo.stroke
		local prevDefault = selectedSlotInfo.defaultColor
		if prevStroke and prevStroke.Parent then
			TweenService:Create(prevStroke, TweenInfo.new(0.12), { Color = prevDefault }):Play()
		end
	end

	selectedSlotInfo = {
		slot = slot,
		stroke = st,
		defaultColor = defaultColor,
	}

	TweenService:Create(st, TweenInfo.new(0.12), { Color = Theme.Check }):Play()
	showDetail(entry)
end

local function buildSlot(entry: Entry, order: number, targetKeyOrName: string?, populateFn: (string, string?) -> ())
	local defaultColor = Theme.BorderDark
	local bgColor = Theme.SlotLocked
	local iconColor = Color3.fromRGB(20, 26, 26)
	local iconTrans = 0.35

	if entry.unlocked then
		defaultColor = Theme.Border
		bgColor = Theme.Slot
		iconColor = Color3.new(1, 1, 1)
		iconTrans = 0
	elseif entry.isQuestDone then
		defaultColor = Theme.BorderReady
		bgColor = Theme.SlotReady
		iconColor = Color3.new(1, 1, 1)
		iconTrans = 0
	end

	local slot = make("TextButton", {
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gridHolder)
	local st = stroke(slot, defaultColor, 2)

	local s = math.clamp(0.88 * (entry.scale or 1.0), 0.5, 2.50)
	local icon = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(s, s),
		BackgroundTransparency = 1,
		Image = entry.icon,
		ImageColor3 = iconColor,
		ImageTransparency = iconTrans,
		ResampleMode = Enum.ResamplerMode.Pixelated,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 1,
	}, slot)

	if not entry.unlocked and not entry.isQuestDone then
		make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.55, 0.55),
			BackgroundTransparency = 1,
			Image = "rbxassetid://72480127691513",
			ImageColor3 = Color3.fromRGB(240, 235, 220),
			ResampleMode = Enum.ResamplerMode.Pixelated,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		}, slot)
	end

	if entry.icon == "" then
		icon.Visible = false
		label(slot, entry.unlocked and string.upper(string.sub(entry.name, 1, 1)) or "?", 48,
			entry.unlocked and Theme.Text or Color3.new(0, 0, 0), {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
	end

	slot.MouseEnter:Connect(function()
		if not selectedSlotInfo or selectedSlotInfo.slot ~= slot then
			TweenService:Create(st, TweenInfo.new(0.1), { Color = Theme.Check }):Play()
		end
	end)
	slot.MouseLeave:Connect(function()
		if not selectedSlotInfo or selectedSlotInfo.slot ~= slot then
			TweenService:Create(st, TweenInfo.new(0.1), { Color = defaultColor }):Play()
		end
	end)
	slot.MouseButton1Click:Connect(function()
		selectSlot(slot, st, defaultColor, entry)
	end)

	local shouldSelect = false
	if targetKeyOrName then
		if (entry.key and entry.key == targetKeyOrName) or entry.name == targetKeyOrName then
			shouldSelect = true
		end
	elseif order == 1 then
		shouldSelect = true
	end

	if shouldSelect then
		selectSlot(slot, st, defaultColor, entry)
	end
end

local function populate(tabName: string, selectKeyOrName: string?)
	currentTab = tabName
	selectedSlotInfo = nil
	for _, child in ipairs(gridHolder:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local Data = getData()
	local list = Data[tabName] or {}
	local unlockedCount = 0
	for i, entry in ipairs(list) do
		if entry.unlocked then unlockedCount += 1 end
		buildSlot(entry, i, selectKeyOrName, populate)
	end
	counter.Text = ("%d/%d"):format(unlockedCount, #list)

	for name, btn in pairs(tabButtons) do
		local active = name == tabName
		btn.BackgroundColor3 = active and Theme.TabActive or Theme.TabIdle
		btn.TextColor3 = active and Theme.Text or Theme.TextDim
	end

	if #list == 0 then
		detailName.Text = ""
		detailDesc.Text = "Nothing here yet."
		detailIcon.Image = ""
		unlockedBadge.Visible = false
		unlockBtn.Visible = false
	end
end

unlockBtn.MouseEnter:Connect(function()
	if unlockBtnActive then
		TweenService:Create(unlockBtn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.GreenHover }):Play()
	end
end)
unlockBtn.MouseLeave:Connect(function()
	if unlockBtnActive then
		TweenService:Create(unlockBtn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Green }):Play()
	end
end)

unlockBtn.MouseButton1Click:Connect(function()
	if not unlockBtnActive or not currentShowingEntry then return end
	local itemKey = currentShowingEntry.key
	if not itemKey then return end

	unlockBtnActive = false
	unlockContent.Visible = false
	lockedStatusLabel.Visible = true
	lockedStatusLabel.Text = "UNLOCKING..."
	lockedStatusLabel.TextColor3 = Color3.fromRGB(255, 232, 60)

	local Events = ReplicatedStorage:FindFirstChild("Events")
	local UnlockIndexItem = Events and (Events:FindFirstChild("UnlockIndexItem") :: RemoteFunction?)
	if not UnlockIndexItem then
		lockedStatusLabel.Text = "ERROR"
		lockedStatusLabel.TextColor3 = Theme.Red
		task.wait(1.0)
		if currentShowingEntry then showDetail(currentShowingEntry) end
		return
	end

	local success, res = UnlockIndexItem:InvokeServer(itemKey)
	if success then
		SoundManager.PlaySound("Purchase")
		updateHeaderSilver()
		local keepKey = itemKey
		populate(currentTab, keepKey)
	else
		lockedStatusLabel.Text = tostring(res or "FAILED")
		lockedStatusLabel.TextColor3 = Theme.Red
		task.wait(1.0)
		if currentShowingEntry then
			showDetail(currentShowingEntry)
		end
	end
end)

for i, name in ipairs(TabOrder) do
	local btn = make("TextButton", {
		LayoutOrder = i,
		Size = UDim2.new(1 / #TabOrder, 0, 1, 0),
		BorderSizePixel = 0,
		Text = string.upper(name),
		TextSize = 20,
		Font = Config.Font,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.TabIdle,
		TextColor3 = Theme.TextDim,
	}, tabBar)
	tabButtons[name] = btn
	btn.MouseButton1Click:Connect(function()
		populate(name)
	end)
end

----------------------------------------------------------------
-- AÇ / KAPA
----------------------------------------------------------------
local function setOpen(open: boolean)
	if gui.Enabled == open then return end
	if open then
		updateHeaderSilver()
		populate(currentTab)
		gui.Enabled = true
		main.Size = UDim2.fromOffset(980, 650)
		TweenService:Create(main, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(1020, 680),
		}):Play()
	else
		gui.Enabled = false
	end
	if gui:GetAttribute("Open") ~= open then
		gui:SetAttribute("Open", open)
	end
end

closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Config.ToggleKey then
		setOpen(not gui.Enabled)
	end
end)

-- Silver or unlock attribute changes while open
player:GetAttributeChangedSignal("Silver"):Connect(function()
	updateHeaderSilver()
	if gui.Enabled and currentShowingEntry then
		showDetail(currentShowingEntry)
	end
end)

gui:GetAttributeChangedSignal("Open"):Connect(function()
	local isOpen = gui:GetAttribute("Open") == true
	if gui.Enabled ~= isOpen then
		setOpen(isOpen)
	end
end)

populate(currentTab)
