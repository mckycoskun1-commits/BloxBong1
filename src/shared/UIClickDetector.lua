local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))

local UIClickDetector = {}
local isInitialized = false
local lastClickTime = 0
local CLICK_COOLDOWN = 0.05 -- 50ms bekleme süresi (çift tıklama/dokunma sıçramalarını önler)

---
-- Koordinatlardaki nesnelerin gerçek bir UI ögesi olup olmadığını denetler.
-- @param objects {GuiObject}: PlayerGui:GetGuiObjectsAtPosition çıktısı
-- @param viewport Vector2: Kamera görünüm boyutu
-- @return boolean: Tıklama bir UI elemanına veya içine mi yapıldı
---
local function isInsideUI(objects, viewport)
    if not objects or #objects == 0 then
        return false
    end

    local vpWidth = viewport.X
    local vpHeight = viewport.Y

    for _, obj in ipairs(objects) do
        -- 1. Butonlar ve Metin Giriş Kutuları (Her zaman UI etkileşimidir)
        if obj:IsA("GuiButton") or obj:IsA("TextBox") then
            local absSize = obj.AbsoluteSize
            local isFullScreen = (absSize.X >= vpWidth * 0.92 and absSize.Y >= vpHeight * 0.92 and obj.BackgroundTransparency >= 0.95)
            if not isFullScreen then
                return true
            end
        end

        -- 2. İçinde metin olan görünür TextLabel'lar (Kart içi başlıklar, yazılar, istatistikler)
        if obj:IsA("TextLabel") and obj.Text ~= "" and obj.TextTransparency < 0.95 then
            return true
        end

        -- 3. Görünür resmi olan ImageLabel'lar (İkonlar, eşya/silah görselleri)
        if obj:IsA("ImageLabel") and obj.Image ~= "" and obj.ImageTransparency < 0.95 then
            return true
        end

        -- 4. Kaydırılabilir içerik listeleri (ScrollingFrame)
        if obj:IsA("ScrollingFrame") and (obj.BackgroundTransparency < 0.95 or obj.ScrollBarImageTransparency < 0.95) then
            return true
        end

        -- 5. CanvasGroup (Grup halinde gösterilen UI pencereleri)
        if obj:IsA("CanvasGroup") and obj.GroupTransparency < 0.95 and obj.BackgroundTransparency < 0.95 then
            local absSize = obj.AbsoluteSize
            local isFullScreen = (absSize.X >= vpWidth * 0.92 and absSize.Y >= vpHeight * 0.92)
            if not isFullScreen then
                return true
            end
        end

        -- 6. Görünür Paneller / Çerçeveler (Frame)
        if obj:IsA("Frame") and obj.BackgroundTransparency < 0.95 then
            local absSize = obj.AbsoluteSize
            -- Ekranın tamamını kaplayan şeffaf karartma perdelerini (dimmer / modal backdrop) filtrele:
            -- Kullanıcı karartılmış boş alana değil, pencerenin kendisine veya içine tıklamış olmalıdır.
            local isFullScreen = (absSize.X >= vpWidth * 0.92 and absSize.Y >= vpHeight * 0.92)
            if not isFullScreen then
                return true
            end
        end

        -- 7. Görünür kenarlığı (UIStroke) olan çerçeveler (Slotlar, kart çerçeveleri)
        local stroke = obj:FindFirstChildOfClass("UIStroke")
        if stroke and stroke.Enabled and stroke.Transparency < 0.95 then
            local absSize = obj.AbsoluteSize
            local isFullScreen = (absSize.X >= vpWidth * 0.92 and absSize.Y >= vpHeight * 0.92)
            if not isFullScreen then
                return true
            end
        end
    end

    return false
end

function UIClickDetector.Init()
    if isInitialized then return end
    isInitialized = true

    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    local playerGui = localPlayer:WaitForChild("PlayerGui")

    UserInputService.InputBegan:Connect(function(input, _gameProcessedEvent)
        -- Sadece sol tık (MouseButton1) ve mobil dokunma (Touch) girdilerinde tetiklenir
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local now = os.clock()
        if now - lastClickTime < CLICK_COOLDOWN then
            return
        end

        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)

        local clickPos
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            clickPos = UserInputService:GetMouseLocation()
        else
            clickPos = Vector2.new(input.Position.X, input.Position.Y)
        end

        local objects = playerGui:GetGuiObjectsAtPosition(clickPos.X, clickPos.Y)
        if (#objects == 0) and input.Position then
            local altObjects = playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
            if #altObjects > 0 then
                objects = altObjects
            end
        end

        if isInsideUI(objects, viewport) then
            lastClickTime = now
            SoundManager.PlaySound("UIClick")
        end
    end)
end

return UIClickDetector
