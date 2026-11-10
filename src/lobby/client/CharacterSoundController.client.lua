--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundConfig"))

local trackedSounds: { [Sound]: { originalTarget: number, conn: RBXScriptConnection? } } = {}

local function getTargetVolume(soundName: string): number?
	local footstepCfg = SoundConfig.Footstep
	if not footstepCfg then return nil end

	if soundName == "Running" then
		return footstepCfg.Volume or 0.07
	elseif soundName == "Landing" then
		return footstepCfg.LandingVolume or 0.10
	elseif soundName == "Climbing" then
		return footstepCfg.ClimbingVolume or 0.07
	end

	return nil
end

local function hookSound(sound: Sound)
	if not sound:IsA("Sound") then return end
	if trackedSounds[sound] then return end

	local targetVol = getTargetVolume(sound.Name)
	if not targetVol then return end

	sound.Volume = targetVol

	local conn = sound:GetPropertyChangedSignal("Volume"):Connect(function()
		local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
		if isPaused then
			if sound.Volume ~= 0 then
				sound.Volume = 0
			end
			return
		end

		if sound.Volume > targetVol then
			sound.Volume = targetVol
		end
	end)

	trackedSounds[sound] = {
		originalTarget = targetVol,
		conn = conn,
	}

	sound.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if conn then conn:Disconnect() end
			trackedSounds[sound] = nil
		end
	end)
end

local function trackCharacter(char: Model)
	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("Sound") then
			hookSound(desc)
		end
	end

	char.DescendantAdded:Connect(function(desc)
		if desc:IsA("Sound") then
			hookSound(desc)
		end
	end)
end

local function trackPlayer(p: Player)
	if p.Character then
		task.spawn(trackCharacter, p.Character)
	end
	p.CharacterAdded:Connect(function(char)
		task.spawn(trackCharacter, char)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	trackPlayer(p)
end
Players.PlayerAdded:Connect(trackPlayer)

-- Duraklatma (Pause) Desteği
ReplicatedStorage:GetAttributeChangedSignal("IsPaused"):Connect(function()
	local isPaused = ReplicatedStorage:GetAttribute("IsPaused") == true
	for sound, data in pairs(trackedSounds) do
		if sound and sound.Parent then
			if isPaused then
				sound.Volume = 0
			else
				sound.Volume = data.originalTarget
			end
		end
	end
end)

-- Ayarlardan anlık adım sesi güncelleme
local LocalPlayer = Players.LocalPlayer
LocalPlayer:GetAttributeChangedSignal("FootstepVolume"):Connect(function()
	local targetVol = SoundConfig.Footstep and SoundConfig.Footstep.Volume or 0.07
	for sound, data in pairs(trackedSounds) do
		if sound and sound.Parent and sound.Name == "Running" then
			data.originalTarget = targetVol
			if ReplicatedStorage:GetAttribute("IsPaused") ~= true then
				sound.Volume = targetVol
			end
		end
	end
end)
