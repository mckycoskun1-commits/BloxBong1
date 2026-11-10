local CharacterUIConfig = {}

-- Bütün arayüz tasarım değişkenleri buradan yönetilir.
CharacterUIConfig.Design = {
    -- Izgara (Grid) Düzeni
    GridPosition = UDim2.new(0.05, 0, 0.5, 0),
    GridAnchor = Vector2.new(0, 0.5),
    GridSize = UDim2.new(0, 540, 0, 760),
    CellSize = UDim2.new(0, 90, 0, 90),
    CellPadding = UDim2.new(0, 15, 0, 15),
    
    -- Bilgi Paneli (Hover Panel)
    PanelPosition = UDim2.new(0.95, 0, 0.5, 0),
    PanelAnchor = Vector2.new(1, 0.5),
    PanelSize = UDim2.new(0, 540, 0, 760), -- Panel Genişliği ve Yüksekliği
    PanelBackgroundColor = Color3.fromRGB(20, 20, 24),
    PanelTransparency = 0.15,
    
    -- Stil & Çizgiler
    StrokeColor = Color3.fromRGB(200, 200, 255),
    StrokeThickness = 2,
    StrokeTransparencyIdle = 0.7,
    StrokeTransparencyHover = 0.1,
    
    -- Animasyonlar
    TweenDuration = 0.3,
    CellHoverScale = 1.15,
    
    -- Başlık Ayarları (Karakter Adı)
    TitleFont = Enum.Font.Arcade,
    TitleSize = 56,
    TitleYPos = 0.1, -- Başlığı biraz yukarı çektik
    TitleColor = Color3.fromRGB(255, 255, 255),
    
    -- Özellikler/Açıklama Ayarları (Traits)
    DescFont = Enum.Font.Arcade,
    DescSize = 28,
    DescYPos = 0.28, -- Özellikleri biraz yukarı çektik
    DescColor = Color3.fromRGB(255, 255, 255),
    
    -- İstatistik Ayarları (Health, Speed, Damage)
    StatFont = Enum.Font.Arcade,
    StatSize = 28,
    StatYPos = 0.6, -- İstatistikleri biraz yukarı çektik
    
    -- Seçim Butonu (SELECT Button) Ayarları
    ButtonText = "SELECT",
    ButtonTextSize = 36,
    ButtonYPos = 0.88, -- Buton konumu
    ButtonSize = UDim2.new(0.85, 0, 0, 65),
    
    -- Renk Kodları
    BuffColor = Color3.fromRGB(80, 255, 120),  -- Olumlu (Yeşil)
    NerfColor = Color3.fromRGB(255, 80, 80),   -- Olumsuz (Kırmızı)
    NeutralColor = Color3.fromRGB(200, 200, 200) -- Etkisiz (Gri)
}

-- Karakter Verileri
CharacterUIConfig.Characters = {
    {
        Id = "Human",
        Name = "Human",
        Description = "<font color=\"#50ff78\">+ Gains +1% Damage per Level</font>\n<font color=\"#50ff78\">+ Gains +2 Max HP per Level</font>\n<font color=\"#aaaaaa\">- No specific starting bonuses or weaknesses</font>",
        Color = Color3.fromRGB(220, 220, 220),
        Icon = "rbxassetid://83484049457782", -- Yeni Human İkonu
        Stats = {
            {Name = "Health", Value = "1.0x", Type = "Neutral", Icon = "rbxassetid://84078792736531"},
            {Name = "Speed", Value = "1.0x", Type = "Neutral", Icon = "rbxassetid://135229953268492"},
            {Name = "Damage", Value = "1.0x", Type = "Neutral", Icon = "rbxassetid://78682552204417"}
        }
    },
    {
        Id = "Elf",
        Name = "Elf",
        Description = "<font color=\"#50ff78\">+ Gains +1% Ranged Fire Rate per Level</font>\n<font color=\"#50ff78\">+ Gains +1% Speed per Level</font>\n<font color=\"#ff5050\">- Reduced starting maximum health</font>",
        Color = Color3.fromRGB(120, 255, 150),
        Icon = "rbxassetid://113292577527717", -- Yeni Elf İkonu
        Stats = {
            {Name = "Health", Value = "0.85x", Type = "Nerf", Icon = "rbxassetid://84078792736531"},
            {Name = "Speed", Value = "1.15x", Type = "Buff", Icon = "rbxassetid://135229953268492"},
            {Name = "Damage", Value = "1.05x", Type = "Buff", Icon = "rbxassetid://78682552204417"}
        }
    },
    {
        Id = "FireMage",
        Name = "Fire Mage",
        Description = "<font color=\"#50ff78\">+ Gains +2% Fire Damage per Level</font>\n<font color=\"#50ff78\">+ Gains +1% Size per Level</font>\n<font color=\"#ff5050\">- Low physical defense and health</font>",
        Color = Color3.fromRGB(255, 100, 50),
        Icon = "rbxassetid://123585878124548", -- Yeni Fire Mage İkonu
        Stats = {
            {Name = "Health", Value = "0.75x", Type = "Nerf", Icon = "rbxassetid://84078792736531"},
            {Name = "Speed", Value = "1.0x", Type = "Neutral", Icon = "rbxassetid://135229953268492"},
            {Name = "Damage", Value = "1.15x", Type = "Buff", Icon = "rbxassetid://78682552204417"}
        }
    },
    {
        Id = "Knight",
        Name = "Knight",
        Description = "<font color=\"#50ff78\">+ Gains +1.5% Max HP per Level</font>\n<font color=\"#50ff78\">+ Gains +0.5% Melee Damage per Level</font>\n<font color=\"#ff5050\">- CANNOT use Ranged Weapons</font>",
        Color = Color3.fromRGB(255, 230, 100),
        Icon = "rbxassetid://137313886130891", -- Yeni Knight İkonu
        Stats = {
            {Name = "Health", Value = "1.30x", Type = "Buff", Icon = "rbxassetid://84078792736531"},
            {Name = "Speed", Value = "0.85x", Type = "Nerf", Icon = "rbxassetid://135229953268492"},
            {Name = "Damage", Value = "1.0x", Type = "Neutral", Icon = "rbxassetid://78682552204417"}
        }
    },
    {
        Id = "Engineer",
        Name = "Engineer",
        Description = "<font color=\"#50ff78\">+ Starts with Bullet and Special Turret Deploy</font>\n<font color=\"#50ff78\">+ Collect Scrap from enemies & bushes to deploy Turrets</font>\n<font color=\"#50ff78\">+ Turrets are invincible and automatically attack nearby enemies</font>",
        Color = Color3.fromRGB(245, 165, 35),
        Icon = "rbxassetid://134569790979078",
        Stats = {
            {Name = "Health", Value = "1.0x", Type = "Neutral", Icon = "rbxassetid://84078792736531"},
            {Name = "Speed", Value = "1.0x", Type = "Neutral", Icon = "rbxassetid://135229953268492"},
            {Name = "Damage", Value = "1.0x", Type = "Neutral", Icon = "rbxassetid://78682552204417"}
        }
    }
}

return CharacterUIConfig
