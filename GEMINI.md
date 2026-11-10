# Çalışma Kuralları

- **Transcript Kısıtlaması**: Önceki konuşma transcript'lerini okuma.
- **/rojo Komutu**: Kullanıcı `/rojo game` veya `/rojo lobby` yazdığında hiç vakit kaybetmeden, ekstra açıklama veya gevezelik yapmadan derhal ilgili projeyi terminalde arka plan görevi (`IsDaemon: true`) olarak başlat (`rojo serve game.project.json` veya `rojo serve lobby.project.json`). Sadece terminal komutunu çalıştır ve doğrudan başlat.
- **Durdurma (Pause) Kuralları Uyumluluğu**: Kullanıcı oyuna yeni bir özellik, mekanik, sayaç/zamanlayıcı (timer), yetenek (ability), mermi/proje, spawner, animasyon veya döngü (loop) eklenmesini istediğinde, bu özelliği MUTLAKA oyunun duraklatma sistemine (`ReplicatedStorage:GetAttribute("IsPaused")`) ve durdurma kurallarına tam uyumlu olarak geliştir:
  - Döngülerde ve periyodik işlemlerde `if ReplicatedStorage:GetAttribute("IsPaused") then ... end` kontrollerini eksiksiz koy.
  - `os.clock()` veya zaman farkı (`elapsed`) bazlı çalışan tüm zamanlayıcılarda, oyun duraklatıldığında geçen duraklatma süresini (`pauseDuration`) ilgili zaman damgalarına ekle/kaydır (shift timers).
  - Fizik, hareket, mermiler, parçacıklar ve görsel animasyonlar oyun durduğunda dondurulmalı, duraklatma bittiğinde hiçbir gecikme, ani teleport/fırlama veya zamansal taşma olmadan pürüzsüzce devam etmelidir.

- **Paralel Oturum / Git İzolasyonu (Kod Ezmeyi Önleme)**: Bu klasörde aynı anda birden fazla AI oturumu (Claude, Gemini vb.) çalışabilir. Birbirinin kodunu ezmemek için:
  - Paralel çalışan her oturum kendi **git worktree + branch**'inde çalışır. Claude Code masaüstünde yeni oturumu "worktree" seçeneği açık başlat (worktree'ler `.claude/worktrees/` altında, gitignore'da). Elle: `git worktree add .claude/worktrees/<isim> -b <isim>`.
  - Ana klasörde (`main`) çalışan oturum, dosya düzenlemeden önce `git status` çalıştırır. Kendisinin yapmadığı commit edilmemiş değişiklik varsa başka bir oturum aktif demektir: o dosyalara dokunma, kullanıcıya sor veya worktree'ye geç.
  - Her anlamlı adımın sonunda değişiklikleri kendi branch'ine commit et; commit edilmemiş iş başka oturumlar tarafından ezilebilir. Branch'ler `main`'e yalnızca kullanıcı onayıyla merge edilir.
  - Rojo: `rojo serve` hangi klasörden çalıştırılırsa o klasörün kodunu Studio'ya sync eder; aynı portta tek seferde yalnız bir `rojo serve` çalışabilir.

# Proje Dosya ve Sistem Haritası (Hızlı Erişim)

Arama yapmadan doğrudan ilgili dosyaya gitmek için bu dizini referans al:

### 1. Paylaşılan Yapılandırmalar (Shared Configs)
- **Genel Oyun & Harita Ayarları**: `src/shared/Config.lua`
- **Düşman & Boss İstatistikleri**: `src/shared/EnemyConfig.lua`
- **Dalga (Wave) & Swarm Zamanlaması**: `src/shared/WaveConfig.lua`
- **Silah Verileri & Hasar Formülleri**: `src/shared/WeaponSystem.lua`
- **Yükseltmeler (Upgrades / Perks)**: `src/shared/UpgradeConfig.lua`
- **Eşyalar (Items / Relics)**: `src/shared/ItemConfig.lua`
- **Görev & Başarım İlerlemesi (Quests)**: `src/shared/ProgressionManager.lua`
- **Karakterler & Sınıflar (Classes)**: `src/shared/CharacterUIConfig.lua`
- **Gümüş Dükkanı & Kalıcı Geliştirmeler (Shop)**: `src/shared/ShopConfig.lua`
- **Lobi Ayarları**: `src/shared/LobbyConfig.lua`
- **Arayüz & Ses Ayarları**: `src/shared/SettingsConfig.lua`, `src/shared/UIConfig.lua`, `src/shared/SoundConfig.lua`, `src/shared/SoundManager.lua`

### 2. Oyun Sunucusu (Game Server)
- **Oyuncu, Can, Seviye, Altın & Lobiye Dönüş**: `src/game/server/PlayerManager.server.lua`
- **Düşman Spawn, Yapay Zeka & Boss Mekanikleri**: `src/game/server/EnemyManager.server.lua`
- **Savaş, Vuruş & Hasar Hesaplama**: `src/game/server/CombatManager.server.lua`
- **XP, Kristal & Altın Toplama**: `src/game/server/GemManager.server.lua`
- **Sandık Açma & Mağaza**: `src/game/server/ChestManager.server.lua`
- **Kırılabilir Çömlekler (Pots)**: `src/game/server/PotManager.server.lua`
- **Mistik Sunakklar (Shrines / Altars)**: `src/game/server/ShrineManager.server.lua`
- **Prosedürel Harita Oluşturma**: `src/game/server/MapGenerator.server.lua`
- **Kalıcı İlerleme Kaydı**: `src/game/server/GameProgression.server.lua`

### 3. Oyun İstemcisi (Game Client)
- **Oyuncu Can, Seviye & Deneyim UI**: `src/game/client/HealthUIController.client.lua`
- **Oyun Sonu Ekranı (End of Round / Game Over)**: `src/game/client/EndOfRoundUIController.client.lua`
- **Boss Yetenek & Uyarı Efektleri (AoE Telegraph)**: `src/game/client/BossAbilityVisualController.client.lua`
- **Boss Can Barı**: `src/game/client/BossHealthController.client.lua`
- **Mermi / Proje Efektleri**: `src/game/client/ProjectileVisualController.client.lua`
- **Hasar Sayıları**: `src/game/client/DamageDisplayController.client.lua`
- **Sandık UI**: `src/game/client/ChestUIController.client.lua`
- **Mistik Sunak Stat Seçim UI**: `src/game/client/ShrineRewardUIController.client.lua`
- **Oyuncu Hareket / Kayma Fiziği (Inertia)**: `src/game/client/PlayerMovementInertiaController.client.lua`

### 4. Lobi (Lobby Server & Client)
- **Liderlik Tabloları (Leaderboards)**: `src/lobby/server/LeaderboardManager.server.lua`
- **Lobi Odaları, Eşleştirme & Işınlanma**: `src/lobby/server/LobbyManager.server.lua`
- **Sınıf Seçim NPC & Overhead**: `src/lobby/server/ClassNPCManager.server.lua`, `src/lobby/server/ClassOverheadManager.server.lua`
- **Gümüş Dükkanı NPC & Satın Alma**: `src/lobby/server/ShopNPCManager.server.lua`
- **Lobi Arayüzleri & Dükkan**: `src/lobby/client/LobbyUIController.client.lua`, `src/lobby/client/MainMenuController.client.lua`, `src/lobby/client/SidebarUIController.client.lua`, `src/lobby/client/ShopUIController.client.lua`

### 5. Görsel Üretim & Pixel Art Standartları (UI / Kart İkonları)
- **Sade & Zarif Tasarım Dili (Göze Sokmayan Detaylar):**
  - Göze sokulan kaba, çiğ veya aşırı belirgin figürler (örn: hasar için kırmızı yumruk vb.) KULLANILMAYACAKTIR.
  - Tasarımlar sade, minimalist ve şık detaylarla (zarif rünler, ince renk vurguları, mühür veya estetik sembollerle) statı yansıtmalıdır.
  - Benzer gruptaki tasarımların duruşu, perspektifi ve açısı birbiriyle tam uyumlu olmalı; rastgele ve birbirinden kopuk durmamalıdır.
- **Tekil & En Büyük Boyut Kuralı (Farklı Boyutlar/Kopyalar Yasak):**
  - Kesinlikle farklı farklı boyutlarda (16x16, 32x32, 64x64 vb.) fazladan varyasyonlar, küçültülmüş dosyalar veya kopyalar **ÜRETİLMEYECEKTİR**.
  - Her ikon için **yalnızca tek bir adet**, doğrudan en büyük boyutta (orijinal tam çözünürlük) görsel kaydedilecektir.
- **Arka Plan (Siyah Arka Plan KESİNLİKLE Yasaktır - Şeffaf / Transparent):**
  - Tasarımlar **kesinlikle siyah arka plan üzerinde YAPILMAYACAKTIR**. Kartların ve UI panellerinin rengini bozan siyah kutu/zemin kesinlikle yasaktır.
  - İkonlar her zaman **tamamen şeffaf arka planlı (transparent PNG)** olarak hazırlanacaktır. Dış çerçeve, kutucuk veya arka plan dokusu bulunmaz.
- **Anti-AI Slop & Gerçek Pixel Art Disiplini:**
  - AI'ın ürettiği milyonlarca mikro-piksel, sahte piksel filtreleri, yumuşak hava fırçası (airbrush/blur), gradyanlar ve "mixel" (farklı boyuttaki pikseller) kesinlikle YASAKTIR.
  - Belirgin, iri ve nizami kare pikseller (`chunky blocky square pixels`, `uniform pixel grid`).
  - Katı renk blokları ve basit gölgelendirme (`flat colors`, `cel-shaded`, `no smooth gradients`, `no anti-aliasing`).
  - Sıkı sınırlı renk paleti (maksimum 6-10 renk, retro palet disiplini).
- **Zorunlu Prompt Şablonu:**
  `Authentic 16-bit retro arcade pixel art sprite of [OBJE], minimal elegant design, subtle [RENK] accent details indicating [STAT/FONKSİYON], chunky blocky square pixels, uniform 32x32 pixel grid look, flat colors with simple cel-shading, strictly limited 8-color retro palette, crisp hard pixel outlines, no anti-aliasing, no smooth gradients, no blur, no airbrush, no mixels, no subpixels, no 3d render, isolated centered sprite on a solid pure white background (NO black background), high contrast, zero noise, no borders, no text`


