local EnemyConfig = {}

-- XP / KRİSTAL TÜRLERİ VE DEĞERLERİ
EnemyConfig.Gems = {
    Basic = {
        Value = 1, -- Erken oyun taban XP değeri 4 -> 1 dengelendi
        Color = Color3.fromRGB(80, 150, 255),
        Scale = 0.8,
    },
    Medium = {
        Value = 5,
        Color = Color3.fromRGB(80, 255, 150),
        Scale = 1.2,
    },
    Big = {
        Value = 20,
        Color = Color3.fromRGB(255, 200, 50),
        Scale = 1.8,
    },
    Ultra = {
        Value = 150,
        Color = Color3.fromRGB(255, 50, 255),
        Scale = 2.5,
    },
    Coin = {
        Value = 5,
        Color = Color3.fromRGB(255, 215, 0),
        Scale = 1.0,
        IsCoin = true
    },
    Vacuum = {
        Value = 0,
        Color = Color3.fromRGB(170, 85, 255), -- Bright neon purple/magenta
        Scale = 1.5,
        IsVacuum = true
    },
    Scrap = {
        Value = 10,
        Color = Color3.fromRGB(240, 160, 40), -- Bronze/copper industrial gear color
        Scale = 1.0,
        IsScrap = true
    },
    Silver = {
        Value = 1,
        Color = Color3.fromRGB(205, 215, 230), -- Shiny metallic silver / light gray
        Scale = 1.0,
        IsSilver = true
    },
    LuckScroll = {
        Value = 1,
        Color = Color3.fromRGB(80, 255, 160), -- Vibrant emerald / mint green
        Scale = 1.6,
        IsLuckScroll = true
    }
}

-- DÜŞMAN TÜRLERİ VE İSTATİSTİKLERİ
EnemyConfig.Enemies = {
    Slime = {
        DisplayName = "Slime",
        Description = "Bouncy green slime. Fast and persistent in large groups.",
        Icon = "rbxassetid://92131315850362",
        Order = 1,
        Health = 2.2,
        Damage = 2,
        Speed = 12,
        MinXP = 1,
        MaxXP = 1,
        XPDrop = "Basic",
        CoinDrop = 1,
        ModelName = "Slime",
        Scale = 0.9,
        Color = Color3.fromRGB(0, 240, 100),
        SpawnTime = 0,
        SpawnWeight = 100,
        VisualOffset = 0.5,
        Archetype = "Horde",
        Mass = 0.8,
    },
    Zombie = {
        DisplayName = "Zombie",
        Description = "Standard undead enemy. Slow moving but lethal up close.",
        Icon = "rbxassetid://93261504869253",
        Order = 2,
        Health = 3.0,
        Damage = 3,
        Speed = 13.2,
        MinXP = 2,
        MaxXP = 2,
        XPDrop = "Basic",
        CoinDrop = 2,
        ModelName = "Zombie",
        Scale = 1.0,
        Color = Color3.fromRGB(80, 150, 80),
        SpawnTime = 9999,
        SpawnWeight = 0,
        Archetype = "Horde",
        Mass = 1.0,
    },
    FastZombie = {
        DisplayName = "Fast Zombie",
        Description = "Agile and rapid runner zombie that sprints toward survivors.",
        Icon = "rbxassetid://73309065587857",
        Order = 3,
        Health = 1.5,
        Damage = 2,
        Speed = 19.2,
        MinXP = 1,
        MaxXP = 2,
        XPDrop = "Basic",
        CoinDrop = 1,
        ModelName = "FastZombie",
        Scale = 0.8,
        Color = Color3.fromRGB(150, 150, 50),
        SpawnTime = 9999,
        SpawnWeight = 0,
        Archetype = "Flanker",
        Mass = 0.7,
    },
    ArmoredZombie = {
        DisplayName = "Armored Zombie",
        Description = "Heavily armored brute with high resistance and crushing blows.",
        Icon = "rbxassetid://113437280682700",
        Order = 4,
        Health = 7.5,
        Damage = 10,
        Speed = 10.8,
        MinXP = 10,
        MaxXP = 15,
        XPDrop = "Big",
        CoinDrop = 20,
        ModelName = "ArmoredZombie",
        Scale = 1.0,
        Color = Color3.fromRGB(150, 50, 50),
        SpawnTime = 9999,
        SpawnWeight = 0,
        Archetype = "Tank",
        Mass = 2.5,
    },
    MegaZombie = {
        DisplayName = "Mega Zombie",
        Description = "Colossal boss monster with devastating damage and massive health.",
        Icon = "rbxassetid://110114708389769",
        Order = 5,
        Health = 150,
        Damage = 18,
        Speed = 12,
        MinXP = 150,
        MaxXP = 150,
        XPDrop = "Ultra",
        CoinDrop = 50,
        ModelName = "MegaZombie",
        Scale = 2.8,
        Color = Color3.fromRGB(255, 0, 0),
        VisualOffset = 0.5,
        IsBoss = true,
        Archetype = "Boss",
        Mass = 30.0,
    }
}

-- BOSS DOĞUŞ TAKVİMİ (WaveConfig ile uyumlu - 10 Dakikalık Maç)
EnemyConfig.Bosses = {
    { Time = 135, Type = "MegaZombie", Count = 1 }, -- 2:15 (İlk boss oyuncu biraz güçlenince gelsin)
    { Time = 240, Type = "MegaZombie", Count = 2 }, -- 4:00 (240. saniye)
    { Time = 360, Type = "MegaZombie", Count = 3 }, -- 6:00 (360. saniye)
    { Time = 480, Type = "MegaZombie", Count = 4 }, -- 8:00 (480. saniye)
    { Time = 540, Type = "MegaZombie", Count = 5 }, -- 9:00 (540. saniye - Final Boss! Son 1 dakika hayatta kalma)
}

return EnemyConfig
