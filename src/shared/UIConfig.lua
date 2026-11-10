local UIConfig = {}

-- GENEL UI AYARLARI
UIConfig.General = {
    Font = Enum.Font.Arcade,
    MainColor = Color3.fromRGB(255, 255, 255),
    AccentColor = Color3.fromRGB(255, 50, 50),
}

-- OYUN SÜRESİ (TIMER) AYARLARI
UIConfig.Timer = {
    Position = UDim2.new(0.4, 0, -0.05, 0), -- Ekranın en üstü
    Size = UDim2.new(0.2, 0, 0.05, 0),
    TextSize = 32,
    DefaultColor = Color3.fromRGB(255, 255, 255),
    CountdownColor = Color3.fromRGB(255, 200, 50), -- Oyun başlarkenki renk ve son 1 dakika
    MatchDuration = 600, -- 10 dakika (saniye cinsinden)
}

-- BOSS CAN BARI AYARLARI
UIConfig.BossHealth = {
    -- Ana Liste Konteyneri
    ContainerPosition = UDim2.new(0.2, 0, 0.05, 0), -- Daha geniş olduğu için x konumunu sola çektik
    ContainerSize = UDim2.new(0.6, 0, 0.5, 0), -- Genişlik 0.4 -> 0.6 yapıldı
    Padding = 25, -- Barlar arası dikey boşluk
    
    -- Tekil Bar Tasarımı
    BarSize = UDim2.new(1, 0, 0.08, 0), -- Konteynerin tüm genişliğini kaplasın
    BarColor = Color3.fromRGB(220, 50, 50), -- Canlı kırmızı
    BgColor = Color3.fromRGB(20, 10, 10),
    StrokeColor = Color3.fromRGB(255, 50, 50),
    
    -- Yazı Ayarları
    NameTextSize = 18,
    HealthTextSize = 12,
}

-- OYUNCU HUD (CAN VE XP) AYARLARI
UIConfig.PlayerHUD = {
    ContainerPosition = UDim2.new(0.3, 0, 0.85, 0),
    HealthBarColor = Color3.fromRGB(255, 60, 60),
    XPBarColor = Color3.fromRGB(50, 220, 255),
    StaminaBarColor = Color3.fromRGB(255, 120, 0), -- Turuncu
}


return UIConfig
