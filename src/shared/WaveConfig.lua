local WaveConfig = {}

-- 10 DAKİKALIK ZORLUK VE DALGA SEVİYE SİSTEMİ (Dinamik Dakika Bazlı Ölçekleme)
-- 10:00'dan geri sayan maç süresine tam uyarlanmıştır.
-- Erken oyun sakin, akıcı ve ferah başlar (oyuncu başına 5-20 canavar).
-- İlerleyen dakikalarda zorluk ve yoğunluk kademeli olarak tırmanır, son dakikalarda tam kaos ve meydan okuma yaşatır.

WaveConfig.Phases = {
    -- ============================================================
    -- 0.0 - 2.0 DAKİKA: BAŞLANGIÇ & ISINMA (ERKEN OYUN)
    -- Sayılar 20 ve altında tutulur, canlar düşüktür (tek-çift vuruşta ölürler).
    -- ============================================================
    { 
        Time = 0,   
        SpawnDelay = 2.40, 
        Difficulty = 0.85,  
        MaxEnemiesPerPlayer = 5,
        EnemyLimits = { Slime = 10 }
    },  -- 0:00 (Kalan: 10:00 - Rahat ilk seviye atlama)
    { 
        Time = 25,  
        SpawnDelay = 1.90, 
        Difficulty = 0.90, 
        MaxEnemiesPerPlayer = 8,
        EnemyLimits = { Slime = 14, Zombie = 5 }
    }, -- 0:25 (Kalan: 09:35)
    { 
        Time = 55,  
        SpawnDelay = 1.50, 
        Difficulty = 0.95,  
        MaxEnemiesPerPlayer = 12,
        EnemyLimits = { Slime = 18, Zombie = 9 }
    }, -- 0:55 (Kalan: 09:05)
    { 
        Time = 85,  
        SpawnDelay = 1.20, 
        Difficulty = 1.05, 
        MaxEnemiesPerPlayer = 16,
        EnemyLimits = { Slime = 20, Zombie = 14, FastZombie = 5 }
    }, -- 1:25 (Kalan: 08:35)
    { 
        Time = 115, 
        SpawnDelay = 0.95, 
        Difficulty = 1.15,  
        MaxEnemiesPerPlayer = 20,
        EnemyLimits = { Slime = 22, Zombie = 18, FastZombie = 8 }
    }, -- 1:55 (Kalan: 08:05 - Tam 20 canavar tavanı)

    -- ============================================================
    -- 2.0 - 4.0 DAKİKA: GELİŞİM & İLK BOSS (ORTA-ERKEN OYUN)
    -- ============================================================
    { 
        Time = 135, 
        SpawnDelay = 0.80, 
        Difficulty = 1.30,  
        MaxEnemiesPerPlayer = 22,
        EnemyLimits = { Slime = 24, Zombie = 22, FastZombie = 10, ArmoredZombie = 6 }
    }, -- 2:15 (MegaZombie x1 - İlk Boss)
    { 
        Time = 175, 
        SpawnDelay = 0.65, 
        Difficulty = 1.50,  
        MaxEnemiesPerPlayer = 26,
        EnemyLimits = { Slime = 25, Zombie = 28, FastZombie = 14, ArmoredZombie = 10 }
    }, -- 2:55
    { 
        Time = 210, 
        SpawnDelay = 0.50, 
        Difficulty = 1.80,  
        MaxEnemiesPerPlayer = 32,
        EnemyLimits = { Slime = 28, Zombie = 38, FastZombie = 18, ArmoredZombie = 14 }
    }, -- 3:30

    -- ============================================================
    -- 4.0 - 6.0 DAKİKA: ORTA OYUN (ZORLAŞMA FAZI)
    -- Oyuncu 3-4 silaha sahip; canavarlar hızlanır ve dayanıklılaşır.
    -- ============================================================
    { 
        Time = 240, 
        SpawnDelay = 0.40, 
        Difficulty = 2.20,  
        MaxEnemiesPerPlayer = 42,
        EnemyLimits = { Zombie = 50, FastZombie = 25, ArmoredZombie = 20 }
    }, -- 4:00 (MegaZombie x2 - Çift Boss)
    { 
        Time = 280, 
        SpawnDelay = 0.32, 
        Difficulty = 2.70,  
        MaxEnemiesPerPlayer = 55,
        EnemyLimits = { Zombie = 70, FastZombie = 38, ArmoredZombie = 28 }
    }, -- 4:40
    { 
        Time = 320, 
        SpawnDelay = 0.25, 
        Difficulty = 3.30,  
        MaxEnemiesPerPlayer = 68,
        EnemyLimits = { Zombie = 90, FastZombie = 50, ArmoredZombie = 38 }
    }, -- 5:20

    -- ============================================================
    -- 6.0 - 8.0 DAKİKA: GEÇ OYUN (LATE GAME - YÜKSEK CAN & BASKIN)
    -- Canavarlar devasa canlara ulaşır, oyuncunun dps'ini test eder.
    -- ============================================================
    { 
        Time = 360, 
        SpawnDelay = 0.22, 
        Difficulty = 4.20,  
        MaxEnemiesPerPlayer = 80,
        EnemyLimits = { Zombie = 100, FastZombie = 65, ArmoredZombie = 50 }
    }, -- 6:00 (MegaZombie x3 - Üçlü Boss)
    { 
        Time = 400, 
        SpawnDelay = 0.18, 
        Difficulty = 5.40,  
        MaxEnemiesPerPlayer = 95,
        EnemyLimits = { Zombie = 130, FastZombie = 85, ArmoredZombie = 65 }
    }, -- 6:40
    { 
        Time = 440, 
        SpawnDelay = 0.16, 
        Difficulty = 6.80,  
        MaxEnemiesPerPlayer = 110,
        EnemyLimits = { Zombie = 160, FastZombie = 110, ArmoredZombie = 85 }
    }, -- 7:20

    -- ============================================================
    -- 8.0 - 10.0 DAKİKA: END GAME (CLIMAX - MAKSİMUM ZORLUK & DEVASA CANLAR)
    -- ============================================================
    { 
        Time = 480,  
        SpawnDelay = 0.14,  
        Difficulty = 8.50,  
        MaxEnemiesPerPlayer = 125,
        EnemyLimits = { Zombie = 180, FastZombie = 130, ArmoredZombie = 105 }
    }, -- 8:00 (MegaZombie x4)
    { 
        Time = 515,  
        SpawnDelay = 0.12, 
        Difficulty = 10.20,  
        MaxEnemiesPerPlayer = 140,
        EnemyLimits = { Zombie = 220, FastZombie = 160, ArmoredZombie = 130 }
    }, -- 8:35
    { 
        Time = 540, 
        SpawnDelay = 0.11,  
        Difficulty = 12.00, 
        MaxEnemiesPerPlayer = 150,
        EnemyLimits = { Zombie = 250, FastZombie = 200, ArmoredZombie = 150 }
    }  -- 9:00 (MegaZombie x5 - Final Boss & Son 1 Dakika!)
}

-- SÜRÜ (SWARM) ETKİNLİKLERİ
-- 10 saniye içine dağıtılarak spawnlanan sürü akınları
WaveConfig.Swarms = {
    -- 1:45: İlk hafif Slime ısınması
    { Time = 105,  Type = "Slime",         Count = 12 },
    
    -- 2:45: İlk Zombi akını
    { Time = 165,  Type = "Zombie",        Count = 18 },
    
    -- 3:45: Zırhlı grup akını
    { Time = 225,  Type = "ArmoredZombie", Count = 24 },
    
    -- 4:45: Kalabalık Zombi akını
    { Time = 285,  Type = "Zombie",        Count = 45 },
    
    -- 5:45: Büyük Slime baskını
    { Time = 345,  Type = "Slime",         Count = 60 },
    
    -- 6:45: Geç oyun Zırhlı akın
    { Time = 405,  Type = "ArmoredZombie", Count = 50 },
    
    -- 7:45: Kaos Zombi akını
    { Time = 465,  Type = "Zombie",        Count = 65 },
    
    -- 8:30: Büyük Zombi kuşamı
    { Time = 510,  Type = "Zombie",        Count = 80 },
    
    -- 9:15: Final öncesi son zırhlı savunma
    { Time = 555,  Type = "ArmoredZombie", Count = 65 },
    
    -- 9:40: Son 20 saniye mutlak kaos
    { Time = 580,  Type = "Zombie",        Count = 90 }
}

return WaveConfig
