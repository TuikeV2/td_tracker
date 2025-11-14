-- ============================================
-- TD TRACKER - ADMIN PANEL CLIENT
-- ============================================

local ESX = exports['es_extended']:getSharedObject()
local adminPanelOpen = false
local freecamActive = false
local freecamEntity = nil
local freecamCoords = nil
local freecamHeading = 0.0
local editingLocation = nil

-- ============================================
-- FREECAM SYSTEM
-- ============================================

local function StopFreecam(save)
    if not freecamActive then return end

    freecamActive = false

    -- Przywróć gracza
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)

    -- Usuń freecam entity
    if freecamEntity and DoesEntityExist(freecamEntity) then
        DeleteEntity(freecamEntity)
        freecamEntity = nil
    end

    -- Wyłącz kamerę
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(GetRenderingCam(), false)

    -- Zapisz jeśli potwierdzone
    if save and editingLocation then
        SendNUIMessage({
            action = 'notification',
            message = 'Lokacja zapisana!',
            type = 'success'
        })

        TriggerServerEvent('td_tracker:admin:saveLocation', {
            locationType = editingLocation.type,
            index = editingLocation.index,
            coords = {
                x = freecamCoords.x,
                y = freecamCoords.y,
                z = freecamCoords.z,
                w = freecamHeading
            }
        })

        editingLocation = nil
    else
        SendNUIMessage({
            action = 'notification',
            message = 'Anulowano',
            type = 'info'
        })
    end

    freecamCoords = nil
    freecamHeading = 0.0
end

local function StartFreecam(initialCoords, initialHeading)
    if freecamActive then return end

    freecamActive = true
    freecamCoords = initialCoords or GetEntityCoords(PlayerPedId())
    freecamHeading = initialHeading or GetEntityHeading(PlayerPedId())

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)

    -- Spawn invisible entity dla kamery
    local model = GetHashKey('prop_ld_greenscreen_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    freecamEntity = CreateObject(model, freecamCoords.x, freecamCoords.y, freecamCoords.z, false, false, false)
    SetEntityVisible(freecamEntity, false, false)
    SetEntityCollision(freecamEntity, false, false)
    SetEntityInvincible(freecamEntity, true)

    -- Ustaw kamerę
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, freecamCoords.x, freecamCoords.y, freecamCoords.z)
    SetCamRot(cam, 0.0, 0.0, freecamHeading, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Spawn marker preview
    CreateThread(function()
        while freecamActive do
            Wait(0)

            if not freecamCoords then break end

            -- Rysuj marker na pozycji
            DrawMarker(
                1, -- Typ: Cylinder
                freecamCoords.x, freecamCoords.y, freecamCoords.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                2.0, 2.0, 1.0,
                255, 215, 0, 150,
                false, true, 2, false
            )

            -- Rysuj strzałkę kierunku (heading)
            local headingRad = math.rad(freecamHeading)
            local forwardX = freecamCoords.x + math.sin(headingRad) * 2.0
            local forwardY = freecamCoords.y + math.cos(headingRad) * 2.0

            DrawLine(
                freecamCoords.x, freecamCoords.y, freecamCoords.z,
                forwardX, forwardY, freecamCoords.z,
                255, 0, 0, 255
            )

            -- Wyświetl współrzędne na ekranie
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString(string.format(
                "~y~Freecam Mode~w~\nX: ~b~%.2f~w~  Y: ~b~%.2f~w~  Z: ~b~%.2f~w~\nHeading: ~b~%.2f°~w~\n\n" ..
                "~g~WASD~w~ - Ruch | ~g~Q/E~w~ - Góra/Dół | ~g~Shift~w~ - Szybciej\n" ..
                "~g~Strzałki~w~ - Obrót | ~g~Enter~w~ - Zapisz | ~g~ESC~w~ - Anuluj",
                freecamCoords.x, freecamCoords.y, freecamCoords.z, freecamHeading
            ))
            DrawText(0.5, 0.85)
        end
    end)

    -- Kontrola ruchu
    CreateThread(function()
        while freecamActive do
            Wait(0)

            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- Push to talk

            local speed = 0.5
            if IsControlPressed(0, 21) then -- Shift
                speed = 2.0
            end

            -- Wyłącz normalne kontrolki
            DisableAllControlActions(0)

            -- Ruch WASD (klawisze na klawiaturze)
            if IsDisabledControlPressed(0, 32) then -- W
                local rad = math.rad(freecamHeading)
                freecamCoords = vector3(
                    freecamCoords.x + math.sin(rad) * speed,
                    freecamCoords.y + math.cos(rad) * speed,
                    freecamCoords.z
                )
            end
            if IsDisabledControlPressed(0, 33) then -- S
                local rad = math.rad(freecamHeading)
                freecamCoords = vector3(
                    freecamCoords.x - math.sin(rad) * speed,
                    freecamCoords.y - math.cos(rad) * speed,
                    freecamCoords.z
                )
            end
            if IsDisabledControlPressed(0, 34) then -- A
                local rad = math.rad(freecamHeading + 90)
                freecamCoords = vector3(
                    freecamCoords.x + math.sin(rad) * speed,
                    freecamCoords.y + math.cos(rad) * speed,
                    freecamCoords.z
                )
            end
            if IsDisabledControlPressed(0, 35) then -- D
                local rad = math.rad(freecamHeading - 90)
                freecamCoords = vector3(
                    freecamCoords.x + math.sin(rad) * speed,
                    freecamCoords.y + math.cos(rad) * speed,
                    freecamCoords.z
                )
            end

            -- Góra/Dół Q/E
            if IsDisabledControlPressed(0, 44) then -- Q
                freecamCoords = vector3(freecamCoords.x, freecamCoords.y, freecamCoords.z + speed)
            end
            if IsDisabledControlPressed(0, 38) then -- E
                freecamCoords = vector3(freecamCoords.x, freecamCoords.y, freecamCoords.z - speed)
            end

            -- Obrót strzałkami
            if IsDisabledControlPressed(0, 174) then -- Left Arrow
                freecamHeading = (freecamHeading + 2.0) % 360
            end
            if IsDisabledControlPressed(0, 175) then -- Right Arrow
                freecamHeading = (freecamHeading - 2.0) % 360
            end

            -- Aktualizuj kamerę
            local cam = GetRenderingCam()
            if DoesEntityExist(freecamEntity) then
                SetEntityCoords(freecamEntity, freecamCoords.x, freecamCoords.y, freecamCoords.z, false, false, false, true)
                SetEntityHeading(freecamEntity, freecamHeading)
            end
            SetCamCoord(cam, freecamCoords.x, freecamCoords.y, freecamCoords.z + 50.0)
            PointCamAtCoord(cam, freecamCoords.x, freecamCoords.y, freecamCoords.z)

            -- Enter - Zapisz
            if IsDisabledControlJustPressed(0, 18) then -- Enter
                StopFreecam(true)
                break
            end

            -- Backspace - Anuluj
            if IsDisabledControlJustPressed(0, 177) then -- Backspace
                StopFreecam(false)
                break
            end
        end
    end)
end

-- ============================================
-- NUI CALLBACKS
-- ============================================

RegisterNUICallback('closePanel', function(data, cb)
    SetNuiFocus(false, false)
    adminPanelOpen = false
    cb('ok')
end)

RegisterNUICallback('requestData', function(data, cb)
    if data.tab == 'stats' then
        TriggerServerEvent('td_tracker:admin:getStats')
        TriggerServerEvent('td_tracker:admin:getPlayers')
    elseif data.tab == 'missions' then
        TriggerServerEvent('td_tracker:admin:getMissions')
    end
    cb('ok')
end)

RegisterNUICallback('executeCommand', function(data, cb)
    TriggerServerEvent('td_tracker:admin:executeCommand', data)
    cb('ok')
end)

RegisterNUICallback('saveMissionConfig', function(data, cb)
    TriggerServerEvent('td_tracker:admin:saveMissionConfig', data)
    cb('ok')
end)

RegisterNUICallback('loadLocations', function(data, cb)
    TriggerServerEvent('td_tracker:admin:getLocations', data.locationType)
    cb('ok')
end)

RegisterNUICallback('teleportToLocation', function(data, cb)
    TriggerServerEvent('td_tracker:admin:teleportToLocation', data)
    cb('ok')
end)

RegisterNUICallback('editLocation', function(data, cb)
    editingLocation = data
    -- Poproś serwer o koordynaty
    TriggerServerEvent('td_tracker:admin:requestLocationCoords', data)
    cb('ok')
end)

RegisterNUICallback('addLocation', function(data, cb)
    editingLocation = {type = data.locationType, index = -1}
    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    StartFreecam(coords, heading)
    cb('ok')
end)

RegisterNUICallback('deleteLocation', function(data, cb)
    TriggerServerEvent('td_tracker:admin:deleteLocation', data)
    cb('ok')
end)

RegisterNUICallback('viewPlayer', function(data, cb)
    TriggerServerEvent('td_tracker:admin:viewPlayer', data.playerId)
    cb('ok')
end)

RegisterNUICallback('teleportToPlayer', function(data, cb)
    TriggerServerEvent('td_tracker:admin:teleportToPlayer', data.playerId)
    cb('ok')
end)

RegisterNUICallback('resetPlayer', function(data, cb)
    TriggerServerEvent('td_tracker:admin:resetPlayer', data.playerId)
    cb('ok')
end)

-- Settings callbacks
RegisterNUICallback('getSettings', function(data, cb)
    TriggerServerEvent('td_tracker:admin:getSettings')
    cb('ok')
end)

RegisterNUICallback('saveSettings', function(data, cb)
    TriggerServerEvent('td_tracker:admin:saveSettings', data.settings)
    cb('ok')
end)

-- NPC Quest Giver callbacks
RegisterNUICallback('getNPCLocations', function(data, cb)
    TriggerServerEvent('td_tracker:admin:getNPCLocations')
    cb('ok')
end)

RegisterNUICallback('addNewNPC', function(data, cb)
    editingLocation = {type = 'npc_quest_giver', index = -1}
    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    StartFreecam(coords, heading)
    cb('ok')
end)

RegisterNUICallback('editNPCLocation', function(data, cb)
    editingLocation = {type = 'npc_quest_giver', index = data.npcId}
    TriggerServerEvent('td_tracker:admin:requestNPCCoords', data.npcId)
    cb('ok')
end)

RegisterNUICallback('teleportToNPC', function(data, cb)
    TriggerServerEvent('td_tracker:admin:teleportToNPC', data.npcId)
    cb('ok')
end)

RegisterNUICallback('toggleNPC', function(data, cb)
    TriggerServerEvent('td_tracker:admin:toggleNPC', data.npcId)
    cb('ok')
end)

RegisterNUICallback('deleteNPC', function(data, cb)
    TriggerServerEvent('td_tracker:admin:deleteNPC', data.npcId)
    cb('ok')
end)

RegisterNUICallback('spawnAllNPC', function(data, cb)
    TriggerServerEvent('td_tracker:admin:spawnAllNPC')
    cb('ok')
end)

-- ============================================
-- SERVER EVENTS
-- ============================================

RegisterNetEvent('td_tracker:admin:openPanel', function()
    adminPanelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openPanel'
    })
end)

RegisterNetEvent('td_tracker:admin:updateStats', function(stats)
    SendNUIMessage({
        action = 'updateStats',
        stats = stats
    })
end)

RegisterNetEvent('td_tracker:admin:updatePlayers', function(players)
    SendNUIMessage({
        action = 'updatePlayers',
        players = players
    })
end)

RegisterNetEvent('td_tracker:admin:updateLocations', function(locations, locationType)
    SendNUIMessage({
        action = 'updateLocations',
        locations = locations,
        locationType = locationType
    })
end)

RegisterNetEvent('td_tracker:admin:notification', function(message, type)
    SendNUIMessage({
        action = 'notification',
        message = message,
        type = type or 'info'
    })

    lib.notify({
        title = 'Admin Panel',
        description = message,
        type = type or 'info'
    })
end)

RegisterNetEvent('td_tracker:admin:receiveLocationCoords', function(coords)
    -- Rozpocznij freecam z otrzymanymi współrzędnymi
    StartFreecam(vector3(coords.x, coords.y, coords.z), coords.w or 0.0)
end)

RegisterNetEvent('td_tracker:admin:forceCompleteMission', function()
    -- Wymusza ukończenie misji (wywołuje funkcję z main.lua)
    if CompleteMission then
        CompleteMission()
        lib.notify({
            title = 'Admin',
            description = 'Twoja misja została zakończona przez admina',
            type = 'success'
        })
    end
end)

RegisterNetEvent('td_tracker:client:removeNPC', function()
    -- Wywołuje funkcję usuwania NPC z main.lua
    if RemoveNPC then
        RemoveNPC()
        lib.notify({
            title = 'Admin',
            description = 'NPC został usunięty',
            type = 'info'
        })
    end
end)

-- ============================================
-- COMMANDS
-- ============================================

RegisterCommand('tracker', function(source, args)
    if args[1] == 'admin' then
        TriggerServerEvent('td_tracker:admin:checkPermission')
    end
end, false)

print('^2[TD TRACKER]^0 Admin panel client loaded')
