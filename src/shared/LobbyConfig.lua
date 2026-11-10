local LobbyConfig = {}

-- KAMERA AYARLARI (Uzaklaştırma / Yakınlaştırma Sınırları)
LobbyConfig.CameraMinZoomDistance = 5  -- Minimum yakınlaşma (stud)
LobbyConfig.CameraMaxZoomDistance = 30 -- Maksimum uzaklaşma (stud)

-- LOBİ SİSTEMİ AYARLARI
LobbyConfig.GamePlaceId = 113718379878551 -- Işınlanılacak yerin ID'si

LobbyConfig.Visuals = {
    WallHeight = 6, -- Görsel duvarların yüksekliği
    EdgeThickness = 0.3, -- Alt kısımdaki neon çizginin kalınlığı
    EdgeHeight = 0.2, -- Alt kısımdaki neon çizginin yerden yüksekliği
    Color = Color3.fromRGB(0, 255, 50), -- Duvarların ve çizgilerin rengi
    
    WallThickness = 0.05, -- Enerji duvarlarının kalınlığı
    WallOverlap = 0.2, -- Köşelerdeki boşlukları kapatmak için duvarların birbirine geçme payı
    CollisionHeight = 13, -- Geçilemeyen (katı) duvarın yüksekliği
    
    -- Durum Yazıları (BillboardUI) Ayarları
    UI_HeightOffset = 9, -- Yazıların yerden yüksekliği
    UI_MaxDistance = 50, -- Yazıların kaç stud mesafeden görüneceği
    UI_TextSize = 33, -- Yazı boyutu
    UI_DefaultColor = Color3.fromRGB(0, 255, 0), -- Boşken yazı rengi
    UI_ConfiguringColor = Color3.fromRGB(255, 170, 0), -- Ayarlanırken yazı rengi
    UI_WaitingColor = Color3.fromRGB(0, 255, 170), -- Bekleme aşamasında yazı rengi
    
    -- Sınıf Seçim (Class NPC) Etkileşim Ayarları
    ClassNPC_ModelName = "ClassNPC", -- NPC modelinin Workspace'teki ismi (Bu isimde olmalı)
    ClassNPC_ActionText = "Class Select", -- Ekranda yazacak olan metin
    ClassNPC_Key = Enum.KeyCode.E, -- Etkileşim tuşu
    ClassNPC_MaxDistance = 15, -- Etkileşim yazısının çıkacağı maksimum mesafe (stud)
    ClassNPC_HoldDuration = 0, -- Tuşa basılı tutma süresi (0 ise anında basılır)
    ClassNPC_StrokeColor = Color3.fromRGB(24, 55, 255), -- UI çerçeve (altın) rengi
    ClassNPC_KeyColor = Color3.fromRGB(55, 175, 255), -- [E] tuşunun rengi
    ClassNPC_ActionTextColor = Color3.fromRGB(255, 255, 255), -- "Class Select" metninin rengi
    ClassNPC_BackgroundColor = Color3.fromRGB(15, 15, 15), -- UI arkaplan rengi
    ClassNPC_BackgroundTransparency = 0.2, -- Arkaplan saydamlığı
    ClassNPC_UI_HeightOffset = 3, -- Yazının karakterin ne kadar üstünde duracağı
    ClassNPC_UI_Size = Vector2.new(220, 60), -- UI penceresinin genişlik ve yüksekliği
    ClassNPC_UI_TextSize = 24, -- Metin boyutu
    
    -- Gümüş Dükkanı (Shop NPC) Etkileşim Ayarları
    ShopNPC_ModelName = "Shop", -- Dükkan NPC modelinin Workspace'teki ismi
    ShopNPC_ActionText = "Silver Shop",
    ShopNPC_ObjectText = "Shop",
    ShopNPC_Key = Enum.KeyCode.E,
    ShopNPC_MaxDistance = 15, -- Karakter etkileşim mesafesi (stud)
    
    -- Duvar saydamlık ayarları (0: Tamamen Görünür, 1: Tamamen Saydam)
    TransparencyTop = 1,    -- En üst kısmın saydamlığı
    TransparencyMiddle = 0.7, -- Orta kısmın saydamlığı
    TransparencyBottom = 0.2  -- En alt kısmın saydamlığı (parlaması için)
}

-- ============================================================
--  YENİ LOBİ ARAYÜZ (UI) AYARLARI (Solid / Karikatürize Tarz)
-- ============================================================

LobbyConfig.UI = {
    Theme = {
        Background = Color3.fromRGB(38, 28, 22),      -- Koyu toprak/kahve arkaplan
        PanelBorder = Color3.fromRGB(92, 66, 48),     -- Ahşap/bronz panel dış çizgisi
        ButtonNormal = Color3.fromRGB(52, 38, 30),    -- Kahve buton rengi
        ButtonHover = Color3.fromRGB(72, 54, 42),     -- Buton hover
        ButtonSelected = Color3.fromRGB(60, 170, 85), -- Canlı yaprak yeşili seçili durumu
        ButtonBorder = Color3.fromRGB(30, 22, 16),    -- Buton dış çizgisi
        TitleColor = Color3.fromRGB(255, 220, 85),    -- Harita başlığı (Altın/Amber)
        TextColor = Color3.fromRGB(245, 235, 220),    -- Parşömen beyazı metin
    },

    Texts = {
        ChallengesTitle = "Challenges:",
        ChallengesDesc = "Higher difficulty increases enemy spawn rate and their power.",
        PlayerTitle = "Player:",
        CreateButton = "Create Room",
        FooterInfo = "We will add new maps and bosses"
    },

    Maps = {
        {
            Id = "Forest",
            Name = "Forest",
            Description = "A green place full of trees, birds, and great vibes. Also everything will try to kill you.",
            Image = "rbxassetid://98851830327389",
            Stages = 3,
            Waves = 20,
            BestScore = "366.7K",
            BestSpeedrun = "31:31.0"
        },
        {
            Id = "Desert",
            Name = "Desert",
            Description = "A hot, dry and dusty place filled with relentless scorpions and undead.",
            Image = "",
            Stages = 3,
            Waves = 20,
            BestScore = "0",
            BestSpeedrun = "--:--"
        },
        {
            Id = "Graveyard",
            Name = "Graveyard",
            Description = "The home of ghosts, ancient curses and dark wandering spooks.",
            Image = "",
            Stages = 3,
            Waves = 20,
            BestScore = "0",
            BestSpeedrun = "--:--"
        }
    },

    Challenges = {
        {
            Id = "Easy",
            Tier = 1,
            Name = "Tier 1",
            DifficultyTitle = "EASY",
            Description = "• Standard enemy wave power\n• Normal spawn rate\n• 1.0x Rewards",
            RewardText = "1.0x",
            Color = Color3.fromRGB(80, 215, 105),
            BorderColor = Color3.fromRGB(50, 140, 65),
            ShowLock = false,
        },
        {
            Id = "Medium",
            Tier = 2,
            Name = "Tier 2",
            DifficultyTitle = "NORMAL",
            Description = "• +40% Enemy HP & Damage\n• Faster spawns\n• 1.5x Rewards",
            RewardText = "1.5x",
            Color = Color3.fromRGB(245, 190, 50),
            BorderColor = Color3.fromRGB(170, 125, 25),
            ShowLock = true,
            UnlockRequirement = "Defeat Easy to unlock",
        },
        {
            Id = "Hard",
            Tier = 3,
            Name = "Tier 3",
            DifficultyTitle = "HARD",
            Description = "• +90% Enemy HP & Damage\n• Elite swarms & faster spawns\n• 2.5x Rewards",
            RewardText = "2.5x",
            Color = Color3.fromRGB(235, 65, 65),
            BorderColor = Color3.fromRGB(160, 40, 40),
            ShowLock = true,
            UnlockRequirement = "Defeat Normal to unlock",
        }
    },
    
    PlayerOptions = {1, 2, 3, 4},

    OverheadUI = {
        HeightOffset = 1.85,    -- Karakterin ne kadar üstünde duracağı (şapka/aksesuarlar ile çakışmaması için hafifçe yukarı alındı)
        MaxDistance = 60,       -- Görünme mesafesi
        FontSize = 24,          -- Yazı boyutu
        StrokeThickness = 2.5,  -- Dış çizgi kalınlığı
        Font = Enum.Font.Arcade,
        AlwaysOnTop = false     -- Duvar arkasından görünmesin (bakış açısına göre 'delirmemesi' için)
    }
}

return LobbyConfig
