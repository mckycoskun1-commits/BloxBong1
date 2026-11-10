local AnimationConfig = {
    -- OYUNCU ANİMASYONLARI
    Player = {
		Idle = "rbxassetid://86186950532954", -- Buraya kendi ID'lerini yazabilirsin
		Walk = "rbxassetid://108216845064121",
		Run = "rbxassetid://89903474861587",
		Jump = "rbxassetid://125999213448348", -- Zıplama animasyonu
		Fall = "rbxassetid://112740953868556", -- Düşme animasyonu
        Attack = "",
    },

    -- CANAVAR ANİMASYONLARI
    Enemies = {
        Zombie = {
            Idle = "",
            Walk = "rbxassetid://71704200420898",
            Attack = "",
        },
        FastZombie = {
            Idle = "",
			Walk = "rbxassetid://72961077694648",
            Attack = "",
        },
        ArmoredZombie = {
            Idle = "",
			Walk = "rbxassetid://104405756342592",
            Attack = "",
        },
        MegaZombie = {
            Idle = "",
			Walk = "rbxassetid://126115999011130",
            Attack = "",
        }
    }
}

return AnimationConfig
