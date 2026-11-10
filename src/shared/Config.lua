local Config = {}

-- Genel Oyun Ayarları
Config.Game = {
    MatchDuration = 600,        -- 10 Dakikalık maç süresi (saniye)
    EnemySpawnRadius = 91,
    MinEnemySpawnRadius = 35,
    XPPickupRadius = 15,
    GemMagnetSpeed = 60,
    MapCenter = Vector3.new(54.219, 0.767, 200.954),
    MaxMapRadius = 330,
    CameraMinZoomDistance = 5,  -- Minimum yakınlaşma (stud)
    CameraMaxZoomDistance = 30, -- Maksimum uzaklaşma (stud)
    LobbyPlaceId = 113207876623887, -- Lobiye dönüş için lobi yerinin ID'si (Kendinizinkiyle değiştirin)
}

-- Harekete Ağırlık ve Dönüş Fiziği Ayarları (Megabonk-style Turning Inertia)
Config.MovementInertia = {
    Enabled = true,
    MinTurnAngle = 55,            -- 55° ve üzeri dönüşlerde yavaşlama & toz başlar (daha erken tepki)
    SkidAnimAngle = 100,          -- 100° ve üzeri dönüşlerde kayma animasyonu tetiklenir
    InertiaResponsiveness = 6.0,  -- Yön değiştirme tepki hızı düşürüldü (daha ağır momentum)
    TurnInertiaDampening = 1.2,   -- Keskin dönüşlerdeki yavaşlama artırtıldı (dönüşte hız %20-25'e kadar düşer)
    RotationSpeed = 7.5,          -- Gövde dönme hızı düşürüldü (kavisli ve ağır dönüş zorluğu)
    FrictionDeceleration = 7.0,   -- Durma fren mesafesi (bırakıldığında hafif kayarak durur)
    EnableSkidParticles = false,  -- Keskin dönüşlerde toz/duman efekti (Kullanıcı isteğiyle devre dışı bırakıldı)
    SkidParticleAmount = 12,      -- Her keskin dönüşte çıkarılacak toz parçacığı sayısı
    EnableSkidAnimation = true,   -- Prosedürel kayma/yatma animasyonu
    SkidTiltAngle = 18,           -- Kayma anındaki geriye yatma açısı (18 derece)
}

-- Canavar Arayüz Ayarları
Config.MonsterUI = {
    HealthBarColor = Color3.fromRGB(100, 255, 100),
    LevelTextColor = Color3.fromRGB(255, 220, 50),
    NameTextColor = Color3.fromRGB(255, 255, 255),
    BarSize = Vector2.new(130, 18),
    InfoSize = Vector2.new(160, 25),
}

-- Silah Ayarları (CombatController için)
Config.Weapons = {
}

Config.GetXPRequirement = function(level)
    if level <= 1 then
        return 12
    elseif level <= 10 then
        -- 1-10 arası: Erken aşama akıcı ilerleme (5-8 seviye aralığı rahatlatıldı)
        local diff = level - 1
        return math.floor(12 + (diff * 9) + (diff ^ 1.25) * 2.2)
    elseif level <= 25 then
        -- 10-25 arası: Orta aşama dengeli artış (~128 -> ~750 XP)
        local base = 128
        local extra = level - 10
        return math.floor(base + (extra * 32) + (extra ^ 1.3) * 8)
    else
        -- 25+ (Oyun sonu): Her canavarda seviye atlamayı engelleyen güçlü artış
        local base = 750
        local extra = level - 25
        return math.floor(base + (extra * 75) + (extra ^ 1.7) * 20)
    end
end

Config.Currency = {
    SilverIcon = "rbxassetid://104534575155839",
    KillsPerSilver = 100,            -- Her 100 canavar için +1 Gümüş
    GoldPerSilver = 0,               -- Altın için gümüş kaldırıldı
    VictoryBonusSilver = 10,         -- 15 dakika hayatta kalma zafer bonusu (+10)
    MinSurviveSecondsPerSilver = 120 -- Hayatta kalınan her 120 saniye (2 dk) için +1 Gümüş
}

return Config
