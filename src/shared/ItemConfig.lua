local ItemConfig = {}

ItemConfig.Items = {
    dagger = {
        Name = "dagger",
        DisplayName = "Assassin's Dagger",
        Description = "+10% Attack Damage per stack",
        Rarity = "Common",
        Color = Color3.fromRGB(200, 200, 200),
        Icon = "rbxassetid://93774505146481"
    },
    bandage = {
        Name = "bandage",
        DisplayName = "Healing Ring",
        Description = "+25% Healing and Regen per stack",
        Rarity = "Uncommon",
        Color = Color3.fromRGB(100, 255, 100),
        Icon = "rbxassetid://134854765599380"
    },
    fire_tome = {
        Name = "fire_tome",
        DisplayName = "Fire Tome",
        Description = "+25% Fire Weapon Damage per stack",
        Rarity = "Rare",
        Color = Color3.fromRGB(100, 150, 255),
        Icon = "rbxassetid://130199164992973"
    },
    bow = {
        Name = "bow",
        DisplayName = "Hunter's Gloves",
        Description = "+10% Projectile Speed per stack",
        Rarity = "Common",
        Color = Color3.fromRGB(200, 200, 200),
        Icon = "rbxassetid://136724572151361"
    },
    xp_tome = {
        Name = "xp_tome",
        DisplayName = "Weird Glasses",
        Description = "+8% XP Gain per stack",
        Rarity = "Common",
        Color = Color3.fromRGB(200, 200, 200),
        Icon = "rbxassetid://71360950886930",
        IconScale = 1.25
    },
    clover = {
        Name = "clover",
        DisplayName = "Lucky Clover",
        Description = "+5% Luck per stack (Better Chest & Upgrade Rarity)",
        Rarity = "Common",
        Color = Color3.fromRGB(200, 200, 200),
        Icon = "rbxassetid://131375222063624"
    },
    piggy_bank = {
        Name = "piggy_bank",
        DisplayName = "Piggy Bank",
        Description = "+15% XP and Gold from Pots & Bushes per stack",
        Rarity = "Uncommon",
        Color = Color3.fromRGB(100, 255, 100),
        Icon = "rbxassetid://80065483190470",
        IconScale = 2.10,
        LockedByDefault = true
    },
    compass = {
        Name = "compass",
        DisplayName = "Magnetic Compass",
        Description = "+15% Magnet Collection Range per stack",
        Rarity = "Common",
        Color = Color3.fromRGB(200, 200, 200),
        Icon = "rbxassetid://71378683667776",
        IconScale = 2.25,
        LockedByDefault = true
    },
    iron_plating = {
        Name = "iron_plating",
        DisplayName = "Iron Plating",
        Description = "-2 Damage taken from all hits per stack",
        Rarity = "Common",
        Color = Color3.fromRGB(200, 200, 200),
        Icon = "rbxassetid://93850208491165"
    },
    blood_blade = {
        Name = "blood_blade",
        DisplayName = "Blood Blade",
        Description = "+1 Health restored on kill per stack",
        Rarity = "Uncommon",
        Color = Color3.fromRGB(100, 255, 100),
        Icon = "rbxassetid://123017566034664",
        IconScale = 1.40
    },
    sniper = {
        Name = "sniper",
        DisplayName = "Sniper Scope",
        Description = "Damage increases +10% per stack every second standing still (up to +100% per stack). Resets on move.",
        Rarity = "Epic",
        Color = Color3.fromRGB(200, 100, 255),
        Icon = "rbxassetid://119974502384687"
    }
}

ItemConfig.Rarities = {
    Common = { Name = "Common", Color = Color3.fromRGB(200, 200, 200), Weight = 60 },
    Uncommon = { Name = "Uncommon", Color = Color3.fromRGB(100, 255, 100), Weight = 25 },
    Rare = { Name = "Rare", Color = Color3.fromRGB(100, 150, 255), Weight = 11 },
    Epic = { Name = "Epic", Color = Color3.fromRGB(200, 100, 255), Weight = 4 }
}

return ItemConfig
