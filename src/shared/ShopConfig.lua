local ShopConfig = {}

-- Gümüş Dükkanı Kalıcı Geliştirme Tanımları (Meta Progression)
ShopConfig.Upgrades = {
    WeaponSlots = {
        Id = "WeaponSlots",
        Attribute = "Talent_WeaponSlots",
        Title = "WEAPON SLOTS",
        Category = "SLOT",
        Description = "+1 Max Weapon slot per level (Base: 2, Max: 4).",
        MaxLevel = 2,
        Costs = { 50, 100 },
        Icon = "rbxassetid://121994932649054",
        IconScale = 1.45,
        StatDisplay = "+1 Slot",
    },
    PerkSlots = {
        Id = "PerkSlots",
        Attribute = "Talent_PerkSlots",
        Title = "SCROLL SLOTS",
        Category = "SLOT",
        Description = "+1 Max Scroll slot per level (Base: 2, Max: 4).",
        MaxLevel = 2,
        Costs = { 50, 100 },
        Icon = "rbxassetid://91741016326013", -- Yüksek kontrastlı, net Grimoire/Kart ikonu
        IconScale = 1.35,
        StatDisplay = "+1 Slot",
    },
    FreeRerolls = {
        Id = "FreeRerolls",
        Attribute = "Talent_FreeRerolls",
        Title = "FREE REROLLS",
        Category = "UTILITY",
        Description = "Start every match with free scroll rerolls.",
        MaxLevel = 3,
        Costs = { 10, 20, 30 },
        Icon = "rbxassetid://131375222063624", -- Şans / Reroll için parlak yeşil yonca ikonu
        IconScale = 1.4,
        StatDisplay = "+1 Reroll",
    },
    Damage = {
        Id = "Damage",
        Attribute = "Talent_Damage",
        Title = "DAMAGE",
        Category = "STAT",
        Description = "+5% Damage Boost per rank.",
        MaxLevel = 5,
        Costs = { 10, 20, 30, 40, 50 },
        Icon = "rbxassetid://139399588848330",
        IconScale = 1.5,
        StatDisplay = "+5% Dmg",
    },
    Health = {
        Id = "Health",
        Attribute = "Talent_Health",
        Title = "HEALTH",
        Category = "STAT",
        Description = "+5% Health Boost per rank.",
        MaxLevel = 5,
        Costs = { 10, 20, 30, 40, 50 },
        Icon = "rbxassetid://82683805204983",
        IconScale = 1.4,
        StatDisplay = "+5% HP",
    },
    Speed = {
        Id = "Speed",
        Attribute = "Talent_Speed",
        Title = "SPEED",
        Category = "STAT",
        Description = "+3% Speed Boost per rank.",
        MaxLevel = 5,
        Costs = { 5, 10, 15, 20, 25 },
        Icon = "rbxassetid://129436264954195",
        IconScale = 1.5,
        StatDisplay = "+3% Spd",
    },
    Magnet = {
        Id = "Magnet",
        Attribute = "Talent_Magnet",
        Title = "MAGNET",
        Category = "STAT",
        Description = "+5% Magnet Range Boost per rank.",
        MaxLevel = 5,
        Costs = { 5, 10, 15, 20, 25 },
        Icon = "rbxassetid://86235492740853",
        IconScale = 1.5,
        StatDisplay = "+5% Range",
    }
}

-- Sıralama düzeni (Dükkanda hangi sırayla listeleneceği)
ShopConfig.Order = {
    "WeaponSlots",
    "PerkSlots",
    "FreeRerolls",
    "Damage",
    "Health",
    "Speed",
    "Magnet"
}

return ShopConfig
