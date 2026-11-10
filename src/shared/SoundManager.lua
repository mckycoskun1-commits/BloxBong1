local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local SoundConfig = require(script.Parent:WaitForChild("SoundConfig"))

local SoundManager = {}

-- İstemci tarafında sesleri önceden belleğe yükle (Preload) - Gecikmesiz anında çalma için
local SoundCacheFolder = nil
if RunService:IsClient() then
    SoundCacheFolder = Instance.new("Folder")
    SoundCacheFolder.Name = "SoundManager_Cache"
    SoundCacheFolder.Parent = SoundService

    task.spawn(function()
        local assets = {}
        for _, cfg in pairs(SoundConfig) do
            local ids = cfg.Ids or (cfg.Id and {cfg.Id}) or {}
            for _, id in ipairs(ids) do
                if id and id ~= "" then
                    local s = Instance.new("Sound")
                    s.Name = tostring(id)
                    s.SoundId = id
                    s.Volume = 0
                    s.Parent = SoundCacheFolder
                    table.insert(assets, s)
                end
            end
        end
        if #assets > 0 then
            pcall(function()
                ContentProvider:PreloadAsync(assets)
            end)
        end
    end)
end

---
-- Belirtilen ses anahtarına (soundName) göre rastgele veya tekil ses çalar.
-- @param soundName string: SoundConfig içindeki anahtar (örneğin "BushBreak")
-- @param positionOrParent Vector3 | Instance | nil: 3D pozisyon, hedef parça veya 2D çalmak için nil
-- @param customProps table | nil: İsteğe bağlı geçersiz kılınacak özellikler ({Volume = ..., Pitch = ...})
-- @return Sound | nil: Oluşturulan ses örneği
---
function SoundManager.PlaySound(soundName, positionOrParent, customProps)
    local cfg = SoundConfig[soundName]
    if not cfg then
        warn("[SoundManager] Ses yapılandırması bulunamadı:", soundName)
        return nil
    end

    -- Ses ID'sini belirle (Dizi ise rastgele birini seç)
    local soundId = nil
    if cfg.Ids and #cfg.Ids > 0 then
        soundId = cfg.Ids[math.random(1, #cfg.Ids)]
    elseif cfg.Id then
        soundId = cfg.Id
    end

    if not soundId or soundId == "" then
        return nil
    end

    local sound = nil
    if SoundCacheFolder then
        local cached = SoundCacheFolder:FindFirstChild(tostring(soundId))
        if cached then
            sound = cached:Clone()
        end
    end
    if not sound then
        sound = Instance.new("Sound")
        sound.SoundId = soundId
    end
    sound.Name = soundName .. "Sound"

    -- Ses seviyesi (Volume)
    local volume = (customProps and customProps.Volume) or cfg.Volume or 0.7
    sound.Volume = volume
    sound:SetAttribute("OriginalVolume", volume)

    -- Ses tonu (Pitch)
    if customProps and customProps.Pitch then
        sound.Pitch = customProps.Pitch
    elseif cfg.PitchMin and cfg.PitchMax then
        sound.Pitch = math.random(math.floor(cfg.PitchMin * 100), math.floor(cfg.PitchMax * 100)) / 100
    elseif cfg.Pitch then
        sound.Pitch = cfg.Pitch
    else
        sound.Pitch = 1.0
    end

    -- 3D Pozisyonel Ses mi yoksa 2D Global Ses mi?
    if positionOrParent then
        local attachParent = nil
        local tempAttachment = nil

        if typeof(positionOrParent) == "Vector3" then
            tempAttachment = Instance.new("Attachment")
            tempAttachment.Name = soundName .. "_AudioAttachment"
            tempAttachment.WorldPosition = positionOrParent
            tempAttachment.Parent = workspace.Terrain
            attachParent = tempAttachment
        elseif typeof(positionOrParent) == "Instance" then
            if positionOrParent:IsA("Attachment") or positionOrParent:IsA("BasePart") then
                attachParent = positionOrParent
            else
                local root = positionOrParent:FindFirstChild("HumanoidRootPart") or positionOrParent.PrimaryPart
                attachParent = root or positionOrParent
            end
        end

        sound.RollOffMinDistance = (customProps and customProps.RollOffMinDistance) or cfg.RollOffMinDistance or 5
        sound.RollOffMaxDistance = (customProps and customProps.RollOffMaxDistance) or cfg.RollOffMaxDistance or 80
        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.Parent = attachParent or workspace

        -- Başlangıç Ofseti (Baştaki sessizliği atlayıp doğrudan ses dalgasından başlatma)
        local startTime = (customProps and customProps.StartTime) or (cfg.StartTimes and cfg.StartTimes[soundId]) or cfg.StartTime or 0
        if startTime > 0 then
            if sound.IsLoaded then
                sound.TimePosition = startTime
            else
                task.spawn(function()
                    if not sound.IsLoaded then
                        pcall(function() sound.Loaded:Wait() end)
                    end
                    if sound and sound.Parent then
                        sound.TimePosition = startTime
                    end
                end)
            end
        end

        sound:Play()

        local cleanupTarget = tempAttachment or sound
        local life = (sound.TimeLength > 0 and sound.TimeLength or 2.5) + 0.5
        Debris:AddItem(cleanupTarget, life)
    else
        -- 2D Arayüz / Küresel Ses (SoundService içine konur)
        sound.Parent = SoundService

        -- Başlangıç Ofseti (Baştaki sessizliği atlayıp doğrudan ses dalgasından başlatma)
        local startTime = (customProps and customProps.StartTime) or (cfg.StartTimes and cfg.StartTimes[soundId]) or cfg.StartTime or 0
        if startTime > 0 then
            if sound.IsLoaded then
                sound.TimePosition = startTime
            else
                task.spawn(function()
                    if not sound.IsLoaded then
                        pcall(function() sound.Loaded:Wait() end)
                    end
                    if sound and sound.Parent then
                        sound.TimePosition = startTime
                    end
                end)
            end
        end

        sound:Play()
        local life = (sound.TimeLength > 0 and sound.TimeLength or 2.5) + 0.5
        Debris:AddItem(sound, life)
    end

    return sound
end

return SoundManager
