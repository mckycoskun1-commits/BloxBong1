local Players = game:GetService("Players")

local PositionUtil = {}

function PositionUtil.getValidSpawnPosition(rawPos, config, enemiesFolder)
    local mapCenterPart = workspace:FindFirstChild("MapCenter") or workspace:FindFirstChild("MapCenterPart")
    local center = Vector3.new(0, 0, 0)
    local maxRadius = config and config.Game and config.Game.MaxMapRadius or 180

    if mapCenterPart then
        center = mapCenterPart:GetPivot().Position
        local customRadius = mapCenterPart:GetAttribute("MaxMapRadius")
        if customRadius then
            maxRadius = customRadius
        end
    elseif config and config.Game and config.Game.MapCenter then
        center = config.Game.MapCenter
    end
    
    -- Harita Sınırı Kontrolü (Dış duvarlara en az 55 stud mesafe kalacak şekilde daraltıldı)
    local flatOffset = Vector3.new(rawPos.X - center.X, 0, rawPos.Z - center.Z)
    local dist = flatOffset.Magnitude
    
    local finalPos = rawPos
    local maxSpawnRadius = maxRadius - 55
    if dist > maxSpawnRadius and dist > 0.001 then
        local clamped = flatOffset.Unit * maxSpawnRadius
        finalPos = Vector3.new(center.X + clamped.X, rawPos.Y, center.Z + clamped.Z)
    end
    
    -- Işını çok yüksek bir noktadan aşağı atıyoruz (Gökyüzü engellerinden etkilenmemek için 400 stud)
    local rayOrigin = Vector3.new(finalPos.X, 400, finalPos.Z)
    local rayDirection = Vector3.new(0, -800, 0)
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    -- Dışlanacak klasörleri ve oyuncu karakterlerini listeye ekle
    local excludeList = {workspace:FindFirstChild("LobbyZones")}
    if enemiesFolder then
        table.insert(excludeList, enemiesFolder)
    else
        local workspaceEnemies = workspace:FindFirstChild("Enemies")
        if workspaceEnemies then
            table.insert(excludeList, workspaceEnemies)
        end
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(excludeList, player.Character)
        end
    end
    rayParams.FilterDescendantsInstances = excludeList
    
    -- Döngü ile sadece zemine çarpanı bulana kadar yukarıdaki engelleri (ağaç vb.) eliyoruz
    local attempts = 0
    while attempts < 10 do
        attempts = attempts + 1
        local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
        if result then
            local hitInstance = result.Instance
            local nameLower = string.lower(hitInstance.Name)
            
            if hitInstance:IsA("Terrain") or nameLower == "baseplate" or string.find(nameLower, "floor") or string.find(nameLower, "ground") or string.find(nameLower, "zemin") or hitInstance:GetAttribute("IsGround") then
                local hitPos = result.Position
                local normal = result.Normal
                
                -- Detaylı Zemin Doğrulama (Duvar, Sınır, Yamaç Engellemesi)
                local normalYOK = normal.Y >= 0.85 -- Aşırı dik yamaç/duvar olmamalı
                local heightOK = math.abs(hitPos.Y - finalPos.Y) <= 30 -- Oyuncunun yüksekliğinden en fazla 30 stud dikey fark olabilir
                
                local isBoundaryBlock = hitInstance:GetAttribute("IsBoundary") == true
                if not isBoundaryBlock then
                    local parentModel = hitInstance:FindFirstAncestorOfClass("Model")
                    if parentModel and parentModel:GetAttribute("IsBoundary") == true then
                        isBoundaryBlock = true
                    end
                end
                
                local nameOK = not (isBoundaryBlock 
                                  or string.find(nameLower, "wall") 
                                  or string.find(nameLower, "border") 
                                  or string.find(nameLower, "barrier") 
                                  or string.find(nameLower, "cliff") 
                                  or string.find(nameLower, "mountain") 
                                  or string.find(nameLower, "rock") 
                                  or string.find(nameLower, "kaya") 
                                  or string.find(nameLower, "duvar") 
                                  or string.find(nameLower, "sinir") 
                                  or string.find(nameLower, "engel"))
                
                if normalYOK and heightOK and nameOK then
                    return hitPos + Vector3.new(0, 3, 0), normal
                else
                    -- Geçersiz bir zemin türü ise (örn. duvar tepesi veya dik yamaç), hariç tutup aşağısını aramaya devam et
                    local parentModel = hitInstance:FindFirstAncestorOfClass("Model")
                    if parentModel and parentModel ~= workspace then
                        table.insert(excludeList, parentModel)
                    else
                        table.insert(excludeList, hitInstance)
                    end
                    rayParams.FilterDescendantsInstances = excludeList
                end
            else
                local parentModel = hitInstance:FindFirstAncestorOfClass("Model")
                if parentModel and parentModel ~= workspace then
                    table.insert(excludeList, parentModel)
                else
                    table.insert(excludeList, hitInstance)
                end
                rayParams.FilterDescendantsInstances = excludeList
            end
        else
            break
        end
    end
    
    -- Eğer hiçbir geçerli güvenli konum bulunamazsa nil dön (çağıran döngüler yeni bir konum deneyecektir)
    return nil
end

return PositionUtil
