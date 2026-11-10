local SoundConfig = {}

-- ============================================================
-- OYUN SES YAPILANDIRMASI (SOUND CONFIG)
-- ============================================================

-- Çalı Kırma Sesleri (3 Farklı varyasyon arasından rastgele seçilir)
SoundConfig.BushBreak = {
    Ids = {
        "rbxassetid://90421983715388",
        "rbxassetid://115728521743263",
        "rbxassetid://129789167046753",
    },
    Volume = 2.4, -- Tok, net ve doyurucu kırılma sesi seviyesi
    PitchMin = 0.96,
    PitchMax = 1.04,
    RollOffMinDistance = 20, -- Uzak kamera açılarında da sesin net duyulması için artırıldı
    RollOffMaxDistance = 120,
    StartTime = 0.26, -- Baştaki ~0.26 saniyelik sessizliği yok sayar, doğrudan sesin başladığı yerden çalar!
}

-- Alev Topu Ateşleme / Fırlatma Sesi (Fireball Cast - 2 Farklı sesten rastgele seçilir)
SoundConfig.FireballCast = {
    Ids = {
        "rbxassetid://123196430925903",
        "rbxassetid://95141010400123",
    },
    Volume = 0.40, -- Kulağı yormayan dengeli ateşleme seviyesi
    PitchMin = 0.95,
    PitchMax = 1.05,
    RollOffMinDistance = 6,
    RollOffMaxDistance = 80,
    StartTime = 0,
}

-- Alev Topu Çarpma / Patlama Sesi (Fireball Hit / Impact)
SoundConfig.FireballHit = {
    Ids = {
        "rbxassetid://128671072268385",
    },
    Volume = 0.50, -- Dengeli patlama seviyesi
    PitchMin = 0.95,
    PitchMax = 1.05,
    RollOffMinDistance = 6,
    RollOffMaxDistance = 90,
    StartTime = 0,
}

-- Standart Mermi Ateşlenme Sesi (Bullet Shoot)
SoundConfig.BulletShoot = {
    Ids = {
        "rbxassetid://130657402181588",
    },
    Volume = 0.20, -- Kısık, seri atışlarda kulağı yormayan dengeli seviye
    PitchMin = 0.94,
    PitchMax = 1.06,
    RollOffMinDistance = 5,
    RollOffMaxDistance = 70,
    StartTime = 0.20, -- Baştaki ~0.20 saniyelik sessizliği atlar, mermi çıkar çıkmaz ses patlar!
}

-- Genel Arayüz / UI Tıklama Sesi (UI Click Sound)
SoundConfig.UIClick = {
    Ids = {
        "rbxassetid://122431792024148",
    },
    Volume = 0.65, -- Net, tatlı ve dengeli tıklama seviyesi
    PitchMin = 0.98,
    PitchMax = 1.02,
    StartTime = 0,
}

-- Oyun İçi Altın / Para Toplama Sesi (Coin / Gold Pickup)
SoundConfig.CoinPickup = {
    Ids = {
        "rbxassetid://104754976070094",
    },
    Volume = 0.20, -- Seri toplamalarda kulağı yormayan, kısık, tatlı ve doyurucu altın sesi
    PitchMin = 0.96,
    PitchMax = 1.06,
    StartTime = 0,
}

-- Mıknatıs / Vakum Düşme Sesi (Magnet / Vacuum Drop Sound)
SoundConfig.MagnetDrop = {
    Ids = {
        "rbxassetid://93214508807308",
    },
    Volume = 0.30, -- Kulağı yormayan, hafif kısık ve net uyarı seviyesi
    PitchMin = 0.98,
    PitchMax = 1.02,
    StartTime = 0,
}

-- Satın Alma / İndex & Market Kilit Açma Sesi (Purchase / Unlock Sound)
SoundConfig.Purchase = {
    Ids = {
        "rbxassetid://135192579587427",
    },
    Volume = 0.35, -- Kulağı yormayan, kısık, net ve tatlı satın alma seviyesi
    PitchMin = 0.98,
    PitchMax = 1.02,
    StartTime = 0,
}

-- Karakter Adım ve Hareket Sesleri (Roblox Varsayılan Karakter Sesleri)
SoundConfig.Footstep = {
    Ids = {
        "rbxasset://sounds/action_footsteps_plastic.mp3",
    },
    Volume = 0.07, -- Roblox'un varsayılan yüksek sesli (0.65) adım (Running) sesini çok kısık seviyeye çeker
    LandingVolume = 0.10, -- Yere iniş (Landing) sesi
    ClimbingVolume = 0.07, -- Tırmanma (Climbing) sesi
}

-- Sürü (Swarm) Gelme / Uyarı Sesi
SoundConfig.SwarmWarning = {
    Ids = {
        "rbxassetid://136161148349782",
    },
    Volume = 0.22, -- Kısık, kulağı tırmalamayan dengeli uyarı seviyesi
    PitchMin = 1.0,
    PitchMax = 1.0,
    StartTime = 0,
}

return SoundConfig
