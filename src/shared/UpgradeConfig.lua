local UpgradeConfig = {}

UpgradeConfig.MaxSlots = 3

-- Nadirlik Seviyeleri (Zar Atma Oranları ve Güç Çarpanları)
UpgradeConfig.Rarities = {
    Common =    { Level = 1, Name = "Common",    Weight = 55.5,  Multiplier = 1.0, Color = Color3.fromRGB(200, 200, 200) },
    Uncommon =  { Level = 2, Name = "Uncommon",  Weight = 25,    Multiplier = 1.2, Color = Color3.fromRGB(100, 255, 100) },
    Rare =      { Level = 3, Name = "Rare",      Weight = 10,    Multiplier = 1.5, Color = Color3.fromRGB(100, 150, 255) },
    Epic =      { Level = 4, Name = "Epic",      Weight = 5,     Multiplier = 2.0, Color = Color3.fromRGB(200, 100, 255) },
    Legendary = { Level = 5, Name = "Legendary", Weight = 2,     Multiplier = 3.0, Color = Color3.fromRGB(255, 200, 50)  }
}

-- Silah Mermi/Sayı (Count) Geliştirmeleri için Dengeli Nadirlik Oranları (Legendary +2.5)
local COUNT_RARITY_BONUSES = {
    Common = 0.5,
    Uncommon = 1.0,
    Rare = 1.5,
    Epic = 2.0,
    Legendary = 2.5
}

-- Mermi (Bullet) silahı alan veya sekme hasarı vurmadığı için dengeli mermi artışı
local BULLET_COUNT_RARITY_BONUSES = {
    Common = 1.0,
    Uncommon = 1.5,
    Rare = 2.0,
    Epic = 2.5,
    Legendary = 3.5
}

UpgradeConfig.Upgrades = {
    Damage = {
        Title = "Damage Scroll",
        Description = "Increases weapon damage.",
        StatDisplay = "Damage",
        Icon = "rbxassetid://136816438423321",
        MinBonus = 0.08, 
        MaxBonus = 0.08, 
        Suffix = "%",
        BaseRarity = 2, -- Uncommon
        Type = "Perk",
        IconScale = 1.5
    },
    Speed = {
        Title = "Speed",
        Description = "Increases movement speed.",
        StatDisplay = "Speed",
        Icon = "rbxassetid://129436264954195",
        MinBonus = 0.08,
        MaxBonus = 0.08,
        Suffix = "%",
        BaseRarity = 1, -- Common
        Type = "Perk",
        IconScale = 1.5
    },
    Magnet = {
        Title = "Magnet",
        Description = "Increases pickup range.",
        StatDisplay = "Range",
        Icon = "rbxassetid://86235492740853",
        MinBonus = 0.25,
        MaxBonus = 0.25,
        Suffix = "%",
        BaseRarity = 2, -- Uncommon
        Type = "Perk",
        IconScale = 1.5
    },
    Vitality = {
        Title = "Health Scroll",
        Description = "Increases maximum health.",
        StatDisplay = "Health",
        Icon = "rbxassetid://121321337790833",
        MinBonus = 20,
        MaxBonus = 20,
        Suffix = " HP",
        BaseRarity = 1, -- Common
        Type = "Perk",
        IconScale = 1.8
    },
    Regeneration = {
        Title = "Regeneration",
        Description = "Slowly restores health over time.",
        StatDisplay = "Regen",
        Icon = "rbxassetid://77668620961118", -- Regeneration
        MinBonus = 0.35, -- 0.35 HP/s
        MaxBonus = 0.35, -- 0.35 HP/s
        Suffix = " HP/s",
        BaseRarity = 1,
        Type = "Perk",
        IconScale = 1.2,
        LockedByDefault = true,
    },
    FireballWeapon = {
        Title = "Fireball",
        Description = "Shoots a fireball.",
        StatDisplay = "Fireball",
        Icon = "rbxassetid://125265167476470", 
        Type = "Weapon",
        BaseRarity = 1,
        IconScale = 1.3,
        SubStats = {
            { Name = "FireballDamage", Display = "Damage", Weight = 30, MinBonus = 2.0, MaxBonus = 2.0, Suffix = "" },
            { Name = "FireballRadius", Display = "Size", Weight = 20, MinBonus = 0.16, MaxBonus = 0.16, Suffix = "%" },
            { Name = "FireballCount", Display = "Count", Weight = 15, MinBonus = 0.5, MaxBonus = 0.5, Suffix = "", RarityBonuses = COUNT_RARITY_BONUSES },
            { Name = "FireballSpeed", Display = "Projectile Speed", Weight = 20, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "%" },
            { Name = "FireballCritChance", Display = "Crit Chance", Weight = 15, MinBonus = 0.075, MaxBonus = 0.075, Suffix = "%" },
            { Name = "FireballCritDamage", Display = "Crit Dmg", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "x" }
        }
    },
    FireTrailWeapon = {
        Title = "Fire Trail",
        Description = "Leaves a burning trail behind.",
        StatDisplay = "Trail",
        Icon = "rbxassetid://133361532069305",
        Type = "Weapon",
        BaseRarity = 2,
        IconScale = 1.0,
        LockedByDefault = true,
        SubStats = {
            { Name = "FireTrailDamage", Display = "Damage", Weight = 30, MinBonus = 3.0, MaxBonus = 3.0, Suffix = "" },
            { Name = "FireTrailRadius", Display = "Size", Weight = 20, MinBonus = 0.18, MaxBonus = 0.18, Suffix = "%" },
            { Name = "FireTrailCount", Display = "Count", Weight = 15, MinBonus = 0.5, MaxBonus = 0.5, Suffix = "", RarityBonuses = COUNT_RARITY_BONUSES },
            { Name = "FireTrailDuration", Display = "Duration", Weight = 20, MinBonus = 1.5, MaxBonus = 1.5, Suffix = "s" },
            { Name = "FireTrailCritChance", Display = "Crit Chance", Weight = 15, MinBonus = 0.075, MaxBonus = 0.075, Suffix = "%" },
            { Name = "FireTrailCritDamage", Display = "Crit Dmg", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "x" }
        }
    },
    BulletWeapon = {
        Title = "Bullet",
        Description = "Fires bullets at the nearest enemy.",
        StatDisplay = "Bullet",
        Icon = "rbxassetid://121994932649054",
        Type = "Weapon",
        BaseRarity = 1,
        IconScale = 1.0,
        SubStats = {
            { Name = "BulletDamage", Display = "Damage", Weight = 30, MinBonus = 1.35, MaxBonus = 1.35, Suffix = "" },
            { Name = "BulletCount", Display = "Count", Weight = 25, MinBonus = 1.0, MaxBonus = 1.0, Suffix = "", RarityBonuses = BULLET_COUNT_RARITY_BONUSES },
            { Name = "BulletSpeed", Display = "Projectile Speed", Weight = 25, MinBonus = 0.20, MaxBonus = 0.20, Suffix = "%" },
            { Name = "BulletCritChance", Display = "Crit Chance", Weight = 20, MinBonus = 0.075, MaxBonus = 0.075, Suffix = "%" },
            { Name = "BulletCritDamage", Display = "Crit Dmg", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "x" }
        }
    },
    CritChance = {
        Title = "Crit Chance",
        Description = "Increases chance to deal critical hits.",
        StatDisplay = "Crit Chance",
        Icon = "rbxassetid://70609716017598", 
        MinBonus = 0.075, -- %7.5 (Common)
        MaxBonus = 0.075, -- %7.5 (Common)
        Suffix = "%",
        BaseRarity = 1, -- Common
        Type = "Perk",
        IconScale = 1.5,
        LockedByDefault = true,
        RarityBonuses = {
            Common = 0.075,     -- %7.5
            Uncommon = 0.10,    -- %10
            Rare = 0.125,       -- %12.5
            Epic = 0.15,        -- %15
            Legendary = 0.20    -- %20
        }
    },
    Lifesteal = {
        Title = "Lifesteal Scroll",
        Description = "Heal for a percentage of damage dealt.",
        StatDisplay = "Lifesteal",
        Icon = "rbxassetid://80370021530658", 
        MinBonus = 0.02, -- %2.0
        MaxBonus = 0.02, -- %2.0
        Suffix = "%",
        BaseRarity = 4, -- Epic
        Type = "Perk",
        IconScale = 1.3,
        LockedByDefault = true
    },
    XPBoost = {
        Title = "XP Scroll",
        Description = "Increases XP gained.",
        StatDisplay = "XP Boost",
        Icon = "rbxassetid://99019752047882", 
        MinBonus = 0.10, -- %10
        MaxBonus = 0.10, -- %10
        Suffix = "%",
        BaseRarity = 2, -- Uncommon
        Type = "Perk",
        IconScale = 1.6,
        LockedByDefault = true
    },
    Luck = {
        Title = "Luck Scroll",
        Description = "+10% Luck per level (Higher rarity upgrades & chest items).",
        StatDisplay = "Luck",
        Icon = "rbxassetid://124295705156617",
        MinBonus = 0.10,
        MaxBonus = 0.10,
        Suffix = "%",
        BaseRarity = 2, -- Uncommon
        Type = "Perk",
        IconScale = 1.35,
        LockedByDefault = true,
        RarityBonuses = {
            Common = 0.08,      -- +8%
            Uncommon = 0.12,    -- +12%
            Rare = 0.18,        -- +18%
            Epic = 0.25,        -- +25%
            Legendary = 0.35    -- +35%
        }
    },
    AreaSize = {
        Title = "Size",
        Description = "Increases attack and explosion size of all weapons.",
        StatDisplay = "Size",
        Icon = "rbxassetid://76536499349513", 
        MinBonus = 0.08, -- %8
        MaxBonus = 0.08, -- %8
        Suffix = "%",
        BaseRarity = 3, -- Rare
        Type = "Perk",
        IconScale = 1.5,
        LockedByDefault = true
    },
    LightningWeapon = {
        Title = "Lightning",
        Description = "Fires lightning that bounces between enemies.",
        StatDisplay = "Lightning",
        Icon = "rbxassetid://78042234318237", 
        Type = "Weapon",
        BaseRarity = 2,
        IconScale = 1.0,
        SubStats = {
            { Name = "LightningDamage", Display = "Damage", Weight = 30, MinBonus = 1.0, MaxBonus = 1.0, Suffix = "" },
            { Name = "LightningCount", Display = "Count", Weight = 20, MinBonus = 0.5, MaxBonus = 0.5, Suffix = "", RarityBonuses = COUNT_RARITY_BONUSES },
            { Name = "LightningBounces", Display = "Bounces", Weight = 20, MinBonus = 1, MaxBonus = 1, Suffix = "" },
            { Name = "LightningCritChance", Display = "Crit Chance", Weight = 15, MinBonus = 0.075, MaxBonus = 0.075, Suffix = "%" },
            { Name = "LightningCritDamage", Display = "Crit Dmg", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "x" },
            { Name = "LightningRange", Display = "Bounce Range", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "%" }
        }
    },
    SnowballWeapon = {
        Title = "Frost Snowball",
        Description = "Throws a snowball that damages and slows enemies.",
        StatDisplay = "Snowball",
        Icon = "rbxassetid://81692544462569", 
        Type = "Weapon",
        BaseRarity = 2,
        IconScale = 1.7,
        SubStats = {
            { Name = "SnowballDamage", Display = "Damage", Weight = 25, MinBonus = 1.25, MaxBonus = 1.25, Suffix = "" },
            { Name = "SnowballCount", Display = "Count", Weight = 15, MinBonus = 0.5, MaxBonus = 0.5, Suffix = "", RarityBonuses = COUNT_RARITY_BONUSES },
            { Name = "SnowballSlowPct", Display = "Slow", Weight = 15, MinBonus = 0.15, MaxBonus = 0.15, Suffix = "%" },
            { Name = "SnowballDuration", Display = "Duration", Weight = 15, MinBonus = 0.75, MaxBonus = 0.75, Suffix = "s" },
            { Name = "SnowballSpeed", Display = "Projectile Speed", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "%" },
            { Name = "SnowballCritChance", Display = "Crit Chance", Weight = 15, MinBonus = 0.075, MaxBonus = 0.075, Suffix = "%" },
            { Name = "SnowballCritDamage", Display = "Crit Dmg", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "x" }
        }
    },
    SpikedArmorWeapon = {
        Title = "Spiked Armor",
        Description = "Damages and knocks back attackers when hit.",
        StatDisplay = "Thorns",
        Icon = "rbxassetid://97729722814774",
        Type = "Weapon",
        BaseRarity = 2,
        IconScale = 1.2,
        LockedByDefault = true,
        SubStats = {
            { Name = "SpikedArmorDamage", Display = "Damage", Weight = 30, MinBonus = 2.0, MaxBonus = 2.0, Suffix = "" },
            { Name = "SpikedArmorCooldown", Display = "Cooldown", Weight = 20, MinBonus = 0.5, MaxBonus = 0.5, Suffix = "s" },
            { Name = "SpikedArmorKnockback", Display = "Knockback", Weight = 20, MinBonus = 2.5, MaxBonus = 2.5, Suffix = "" },
            { Name = "SpikedArmorCritChance", Display = "Crit Chance", Weight = 15, MinBonus = 0.075, MaxBonus = 0.075, Suffix = "%" },
            { Name = "SpikedArmorCritDamage", Display = "Crit Dmg", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "x" },
            { Name = "SpikedArmorRadius", Display = "Size", Weight = 15, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "%" }
        }
    },
    TurretWeapon = {
        Title = "Turret",
        Description = "Deploys automated combat turrets that shred nearby enemies.",
        StatDisplay = "Turret",
        Icon = "rbxassetid://116127630902574",
        Type = "Weapon",
        BaseRarity = 2,
        IconScale = 1.3,
        SubStats = {
            { Name = "TurretDamage", Display = "Damage", Weight = 20, MinBonus = 2.0, MaxBonus = 2.0, Suffix = "" },
            { Name = "TurretFireRate", Display = "Attack Speed", Weight = 20, MinBonus = 0.15, MaxBonus = 0.15, Suffix = "%" },
            { Name = "TurretDuration", Display = "Duration", Weight = 15, MinBonus = 4, MaxBonus = 4, Suffix = "s" },
            { Name = "TurretCostReduction", Display = "Scrap Cost", Weight = 10, MinBonus = 0.08, MaxBonus = 0.08, Suffix = "%" },
            { Name = "TurretCount", Display = "Count", Weight = 15, MinBonus = 0.5, MaxBonus = 0.5, Suffix = "", RarityBonuses = COUNT_RARITY_BONUSES },
            { Name = "TurretCritChance", Display = "Crit Chance", Weight = 10, MinBonus = 0.075, MaxBonus = 0.075, Suffix = "%" },
            { Name = "TurretCritDamage", Display = "Crit Dmg", Weight = 10, MinBonus = 0.25, MaxBonus = 0.25, Suffix = "x" },
            { Name = "TurretRange", Display = "Range", Weight = 10, MinBonus = 0.20, MaxBonus = 0.20, Suffix = "%" }
        }
    },
    AttackSpeed = {
        Title = "Attack Speed Scroll",
        Description = "Increases attack speed of all weapons.",
        StatDisplay = "Atk Speed",
        Icon = "rbxassetid://111855876294905",
        MinBonus = 0.10,
        MaxBonus = 0.10,
        Suffix = "%",
        BaseRarity = 2, -- Uncommon
        Type = "Perk",
        IconScale = 1.4,
        RarityBonuses = {
            Common = 0.08,      -- +8%
            Uncommon = 0.10,    -- +10%
            Rare = 0.14,        -- +14%
            Epic = 0.18,        -- +18%
            Legendary = 0.25    -- +25%
        }
    },
    ProjectileCount = {
        Title = "Projectile Count Scroll",
        Description = "Adds extra projectiles to a random equipped ranged weapon.",
        StatDisplay = "Projectiles",
        Icon = "rbxassetid://101001542265389",
        MinBonus = 0.5,
        MaxBonus = 0.5,
        Suffix = "",
        BaseRarity = 1, -- Common'dan başlar
        Type = "Perk",
        IconScale = 1.3,
        LockedByDefault = true,
        RarityBonuses = {
            Common = 0.5,
            Uncommon = 1.0,
            Rare = 1.5,
            Epic = 2.0,
            Legendary = 2.5
        }
    }
}

-- Taret Dönüm Noktası Nadirlikleri (Ağırlıklar: Uncommon %50, Rare %32, Epic %14, Legendary %4)
UpgradeConfig.MilestoneRarities = {
    Uncommon =  { Level = 1, Name = "Uncommon",  Weight = 50, Color = Color3.fromRGB(100, 255, 100) },
    Rare =      { Level = 2, Name = "Rare",      Weight = 32, Color = Color3.fromRGB(100, 150, 255) },
    Epic =      { Level = 3, Name = "Epic",      Weight = 14, Color = Color3.fromRGB(200, 100, 255) },
    Legendary = { Level = 4, Name = "Legendary", Weight = 4,  Color = Color3.fromRGB(255, 200, 50)  }
}

-- Taret Dönüm Noktası (Milestone / Overclock) Geliştirmeleri (Nerflü & Dengeli)
UpgradeConfig.TurretMilestones = {
    MinigunTurret = {
        Title = "Minigun",
        Description = "High fire rate, but reduced range and damage.",
        Icon = "rbxassetid://116127630902574",
        Rarities = {
            Uncommon = {
                AtkSpd = 0.20,        -- +20% Attack Speed (Nerfed from +35%)
                Damage = -0.15,       -- -15% Damage (Nerfed from -25%)
                Range = -0.15,        -- -15% Range
                ScrapCost = 15,       -- +15 Scrap Cost
            },
            Rare = {
                AtkSpd = 0.35,        -- +35% Attack Speed (Nerfed from +50%)
                Damage = -0.20,       -- -20% Damage (Nerfed from -35%)
                Range = -0.20,        -- -20% Range
                ScrapCost = 25,       -- +25 Scrap Cost
            },
            Epic = {
                AtkSpd = 0.50,        -- +50% Attack Speed (Nerfed from +80%)
                Damage = -0.25,       -- -25% Damage (Nerfed from -40%)
                Range = -0.25,        -- -25% Range
                ScrapCost = 35,       -- +35 Scrap Cost
            },
            Legendary = {
                AtkSpd = 0.70,        -- +70% Attack Speed (Nerfed from +130%)
                Damage = -0.30,       -- -30% Damage (Nerfed from -50%)
                Range = -0.30,        -- -30% Range
                ScrapCost = 50,       -- +50 Scrap Cost
            }
        }
    },
    RailgunTurret = {
        Title = "Railgun",
        Description = "High range and lethal damage, but slower fire rate.",
        Icon = "rbxassetid://116127630902574",
        Rarities = {
            Uncommon = {
                Damage = 0.30,        -- +30% Damage (Nerfed from +50%)
                Range = 0.20,         -- +20% Range
                AtkSpd = -0.20,       -- -20% Attack Speed
                ScrapCost = 15,       -- +15 Scrap Cost
            },
            Rare = {
                Damage = 0.45,        -- +45% Damage (Nerfed from +80%)
                Range = 0.30,         -- +30% Range
                AtkSpd = -0.25,       -- -25% Attack Speed
                ScrapCost = 25,       -- +25 Scrap Cost
            },
            Epic = {
                Damage = 0.65,        -- +65% Damage (Nerfed from +120%)
                Range = 0.40,         -- +40% Range
                AtkSpd = -0.30,       -- -30% Attack Speed
                ScrapCost = 35,       -- +35 Scrap Cost
            },
            Legendary = {
                Damage = 0.90,        -- +90% Damage (Nerfed from +180%)
                Range = 0.50,         -- +50% Range
                AtkSpd = -0.35,       -- -35% Attack Speed
                ScrapCost = 50,       -- +50 Scrap Cost
            }
        }
    },
    SiegeTurret = {
        Title = "Bunker Fortress",
        Description = "Reinforced heavy armor and longer duration, but slower fire rate.",
        Icon = "rbxassetid://116127630902574",
        Rarities = {
            Uncommon = {
                Duration = 0.18,      -- +18% Duration (Nerfed from +25%)
                Damage = 0.15,        -- +15% Damage
                AtkSpd = -0.15,       -- -15% Attack Speed
                ScrapCost = 15,       -- +15 Scrap Cost
            },
            Rare = {
                Duration = 0.30,      -- +30% Duration (Nerfed from +40%)
                Damage = 0.20,        -- +20% Damage
                AtkSpd = -0.20,       -- -20% Attack Speed
                ScrapCost = 25,       -- +25 Scrap Cost
            },
            Epic = {
                Duration = 0.45,      -- +45% Duration (Nerfed from +60%)
                Damage = 0.30,        -- +30% Damage
                AtkSpd = -0.25,       -- -25% Attack Speed
                ScrapCost = 35,       -- +35 Scrap Cost
            },
            Legendary = {
                Duration = 0.60,      -- +60% Duration (Nerfed from +80%)
                Damage = 0.45,        -- +45% Damage
                AtkSpd = -0.30,       -- -30% Attack Speed
                ScrapCost = 50,       -- +50 Scrap Cost
            }
        }
    },
    TwinCannonTurret = {
        Title = "Twin Cannon",
        Description = "Fires multiple projectiles per shot, but with balanced damage and attack speed.",
        Icon = "rbxassetid://116127630902574",
        Rarities = {
            Uncommon = {
                ExtraShots = 1,       -- +1 Extra Shot
                Damage = -0.45,       -- -45% Damage
                AtkSpd = -0.25,       -- -25% Attack Speed
                ScrapCost = 20,       -- +20 Scrap Cost
            },
            Rare = {
                ExtraShots = 1,       -- +1 Extra Shot
                Damage = -0.40,       -- -40% Damage
                AtkSpd = -0.20,       -- -20% Attack Speed
                ScrapCost = 30,       -- +30 Scrap Cost
            },
            Epic = {
                ExtraShots = 1,       -- +1 Extra Shot
                Damage = -0.30,       -- -30% Damage
                AtkSpd = -0.15,       -- -15% Attack Speed
                Range = 0.15,         -- +15% Range
                ScrapCost = 45,       -- +45 Scrap Cost
            },
            Legendary = {
                ExtraShots = 2,       -- +2 Extra Shots (Total 3)
                Damage = -0.45,       -- -45% Damage (Prevents triple damage explosion)
                AtkSpd = -0.20,       -- -20% Attack Speed
                Range = 0.25,         -- +25% Range
                ScrapCost = 60,       -- +60 Scrap Cost
            }
        }
    },
    RecyclerTurret = {
        Title = "Nano Recycler",
        Description = "Cheaper and faster to deploy, but has reduced frame durability.",
        Icon = "rbxassetid://116127630902574",
        Rarities = {
            Uncommon = {
                ScrapCost = -15,      -- -15 Scrap Cost (Nerfed from -25)
                AtkSpd = 0.08,        -- +8% Attack Speed
                Damage = -0.20,       -- -20% Damage
                Duration = -0.15,     -- -15% Duration
            },
            Rare = {
                ScrapCost = -25,      -- -25 Scrap Cost (Nerfed from -35)
                AtkSpd = 0.12,        -- +12% Attack Speed
                Damage = -0.25,       -- -25% Damage
                Duration = -0.20,     -- -20% Duration
            },
            Epic = {
                ScrapCost = -35,      -- -35 Scrap Cost (Nerfed from -50)
                AtkSpd = 0.18,        -- +18% Attack Speed
                Damage = -0.30,       -- -30% Damage
                Duration = -0.25,     -- -25% Duration
            },
            Legendary = {
                ScrapCost = -45,      -- -45 Scrap Cost (Nerfed from -65)
                AtkSpd = 0.25,        -- +25% Attack Speed (Nerfed from +35%)
                Damage = -0.35,       -- -35% Damage
                Duration = -0.25,     -- -25% Duration
            }
        }
    }
}

return UpgradeConfig

