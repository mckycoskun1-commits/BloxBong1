local SettingsConfig = {}

-- Varsayılan Ayarlar
SettingsConfig.Defaults = {
    MasterVolume = 100,  -- 0 - 100 (%)
    MusicVolume = 80,    -- 0 - 100 (%)
    SFXVolume = 100,     -- 0 - 100 (%)
    Muted = false,
    ScreenShake = true,
    ShowDamageNumbers = true,
    AimAssist = true,          -- MegaBonk Aim Assist (Açık/Kapalı)
    AimAssistStrength = 60,    -- 0 - 100 (%) Yumuşak Kamera & Kilitlenme Çekim Gücü
    SmartAim = true,           -- Smart Targeting (Bakılan yöne, Elit & Boss'lara akıllı öncelik)
}

-- Tuş Atamaları
SettingsConfig.Keybinds = {
    ToggleSettings = Enum.KeyCode.O, -- Menüyü açıp kapama tuşu (O veya ekrandaki buton)
}

-- Görsel Tema (Arcade / Solid Dark)
SettingsConfig.Theme = {
    Background = Color3.fromRGB(20, 22, 28),
    Header = Color3.fromRGB(28, 32, 42),
    PanelBorder = Color3.fromRGB(50, 56, 72),
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(170, 178, 195),
    AccentBlue = Color3.fromRGB(55, 145, 255),
    AccentGreen = Color3.fromRGB(65, 215, 95),
    DangerRed = Color3.fromRGB(225, 45, 45),
    DangerRedHover = Color3.fromRGB(250, 60, 60),
    DangerRedBorder = Color3.fromRGB(150, 25, 25),
    SliderTrack = Color3.fromRGB(35, 40, 52),
    SliderFill = Color3.fromRGB(65, 185, 255),
}

return SettingsConfig
