local DifficultyConfig = {
    Difficulties = {
        Easy = {
            Id = "Easy",
            Tier = 1,
            Name = "EASY",
            DisplayName = "Easy",
            Description = "• Standard enemy wave strength\n• Normal spawn rate\n• 1.0x Silver Reward",
            Color = Color3.fromRGB(80, 215, 105),
            BorderColor = Color3.fromRGB(50, 140, 65),
            HpMult = 1.0,
            DmgMult = 1.0,
            SpawnDelayMult = 1.0,
            RewardMult = 1.0,
            SilverBonusText = "1.0x",
            ShowLock = false,
        },
        Medium = {
            Id = "Medium",
            Tier = 2,
            Name = "NORMAL",
            DisplayName = "Normal",
            Description = "• +40% Enemy Health\n• +30% Enemy Damage\n• 1.5x Silver Reward",
            Color = Color3.fromRGB(245, 190, 50),
            BorderColor = Color3.fromRGB(170, 125, 25),
            HpMult = 1.4,
            DmgMult = 1.3,
            SpawnDelayMult = 0.85, -- 15% faster spawn rate
            RewardMult = 1.5,
            SilverBonusText = "1.5x",
            ShowLock = true,
            UnlockRequirement = "Defeat Easy to unlock",
        },
        Hard = {
            Id = "Hard",
            Tier = 3,
            Name = "HARD",
            DisplayName = "Hard",
            Description = "• +90% Enemy Health\n• +60% Enemy Damage\n• 30% faster spawn rate\n• 2.5x Silver Reward",
            Color = Color3.fromRGB(235, 65, 65),
            BorderColor = Color3.fromRGB(160, 40, 40),
            HpMult = 1.9,
            DmgMult = 1.6,
            SpawnDelayMult = 0.70, -- 30% faster spawn rate
            RewardMult = 2.5,
            SilverBonusText = "2.5x",
            ShowLock = true,
            UnlockRequirement = "Defeat Normal to unlock",
        }
    },
    
    Order = {"Easy", "Medium", "Hard"}
}

function DifficultyConfig.Get(difficultyId)
    if not difficultyId then
        return DifficultyConfig.Difficulties.Easy
    end
    return DifficultyConfig.Difficulties[difficultyId] or DifficultyConfig.Difficulties.Easy
end

return DifficultyConfig
