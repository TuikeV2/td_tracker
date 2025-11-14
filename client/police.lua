-- ============================================
-- TD TRACKER - CLIENT POLICE ALERTS (LB_TABLET)
-- ============================================

print('^2[TD TRACKER]^0 Police client loaded')

-- ============================================
-- FUNKCJE POMOCNICZE
-- ============================================

local function DebugPrint(msg)
    if Config.Debug then
        print(msg)
    end
end

function ShowNotification(msg, title, type)
    lib.notify({
        title = title or 'Tracker',
        description = msg,
        type = type or 'info'
    })
end

-- ============================================
-- OBSŁUGA ALERTU DLA POLICJI
-- ============================================

RegisterNetEvent('td_tracker:policeAlert', function(data)
    if not data then return end

    print(string.format('^2[TRACKER POLICE]^0 Received alert: %s at %s', data.message, data.coords))

    -- Sprawdź czy lb_tablet istnieje i wyślij powiadomienie
    if GetResourceState('lb_tablet') == 'started' then
        -- lb_tablet używa TriggerEvent zamiast exportu
        TriggerEvent('lb-phone:phone:sendNotification', {
            source = 'police',
            title = data.code .. ' - TD Tracker',
            content = data.message,
            icon = 'police',
            app = 'DISPATCH'
        })
    else
        if Config.Debug then print('^3[TRACKER POLICE]^0 lb_tablet not running, skipping notification') end
    end

    -- Dodaj blip na mapie
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 229) -- Ikona pojazdu
    SetBlipColour(blip, 1) -- Czerwony
    SetBlipScale(blip, 1.2)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.message)
    EndTextCommandSetBlipName(blip)

    -- Dodaj radius blip (okrąg)
    local radiusBlip = AddBlipForRadius(data.coords.x, data.coords.y, data.coords.z, 150.0)
    SetBlipColour(radiusBlip, 1)
    SetBlipAlpha(radiusBlip, 100)

    -- Usuń blip po 5 minutach
    SetTimeout(300000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        if DoesBlipExist(radiusBlip) then
            RemoveBlip(radiusBlip)
        end
    end)

    if Config.Debug then print('^2[TRACKER POLICE]^0 Alert displayed on map and tablet') end
end)

print('^2[TD TRACKER]^0 Police alerts ready')

-- ============================================
-- NPC CHASE SYSTEM
-- ============================================

local isChaseActive = false
local chaseData = {}
local localChasers = {}
local waveTimer = 0
local chaseStartTime = 0

-- Utility: load model z timeoutem
local function loadModel(hash)
    local t0 = GetGameTimer()
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() - t0 > 5000 then
            return false
        end
    end
    return true
end

-- Spawnuje jednego chasera (veh + wielu pedów) lokalnie
local function spawnChaserAt(coords, targetPed)
    if not Config.NPCChase then return nil end
    if not Config.NPCChase.enabled then return nil end
    if not coords then
        DebugPrint('^1[TRACKER CHASE]^0 Invalid coords provided')
        return nil
    end

    -- Konwertuj coords do tabeli jeśli to vector3
    local spawnCoords = coords
    if type(coords) ~= "table" then
        spawnCoords = {x = coords.x, y = coords.y, z = coords.z}
    end

    local vehModel = Config.NPCChase.vehModels[math.random(1, #Config.NPCChase.vehModels)]
    local vehHash = GetHashKey(vehModel)

    if not loadModel(vehHash) then
        DebugPrint('^1[TRACKER CHASE]^0 Failed to load vehicle model')
        return nil
    end

    -- Spawn point z offsetem
    local spawnOffset = 50.0 + math.random() * 30.0
    local angle = math.random() * math.pi * 2
    local sx = spawnCoords.x + math.cos(angle) * spawnOffset
    local sy = spawnCoords.y + math.sin(angle) * spawnOffset
    local sz = spawnCoords.z

    local veh = CreateVehicle(vehHash, sx, sy, sz, math.random(0, 360), true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, "LSPD"..tostring(math.random(100, 999)))
    SetVehicleEngineOn(veh, true, true, true)
    SetVehicleSiren(veh, true)
    SetVehicleModKit(veh, 0)
    ToggleVehicleMod(veh, 22, true) -- Xenon lights

    -- Określ liczbę policjantów (2 lub 3)
    local numPeds = Config.NPCChase.chasersPerVehicle[math.random(1, #Config.NPCChase.chasersPerVehicle)]
    local peds = {}

    -- Spawn policjantów
    for i = 0, numPeds - 1 do
        local pedModel = Config.NPCChase.pedModels[math.random(1, #Config.NPCChase.pedModels)]
        local pedHash = GetHashKey(pedModel)

        if loadModel(pedHash) then
            local ped = CreatePedInsideVehicle(veh, 4, pedHash, i == 0 and -1 or i - 1, true, false)
            SetPedAsCop(ped, true)
            SetPedRelationshipGroupHash(ped, GetHashKey("COP"))
            SetEntityAsMissionEntity(ped, true, true)

            -- Ustawienia zdrowia i pancerza
            SetPedMaxHealth(ped, Config.NPCChase.pedHealth or 200)
            SetEntityHealth(ped, Config.NPCChase.pedHealth or 200)
            SetPedArmour(ped, Config.NPCChase.pedArmor or 100)

            -- Ustawienia walki
            SetPedCombatAttributes(ped, 46, true)  -- Can use cover
            SetPedCombatAttributes(ped, 5, true)   -- Can fight armed peds when not armed
            SetPedCombatAttributes(ped, 0, true)   -- Can use dynamic strafe decisions
            SetPedCombatAbility(ped, 2)            -- Professional
            SetPedCombatRange(ped, 2)              -- Far range
            SetPedCombatMovement(ped, 2)           -- Offensive
            SetPedFleeAttributes(ped, 0, false)    -- Don't flee
            SetPedAlertness(ped, 3)                -- Maximum alertness

            -- Broń
            if Config.NPCChase.chasersCanShoot then
                local weapon = Config.NPCChase.weapons[math.random(1, #Config.NPCChase.weapons)]
                GiveWeaponToPed(ped, GetHashKey(weapon), 500, false, true)
                SetPedAccuracy(ped, Config.NPCChase.pedAccuracy or 40)
                SetPedShootRate(ped, 600)
                SetCurrentPedWeapon(ped, GetHashKey(weapon), true)
            end

            table.insert(peds, ped)

            -- Kierowca dostaje zadanie jazdy
            if i == 0 and targetPed and DoesEntityExist(targetPed) then
                local tx, ty, tz = table.unpack(GetEntityCoords(targetPed))
                TaskVehicleDriveToCoordLongrange(ped, veh, tx, ty, tz, Config.NPCChase.driveSpeed, Config.NPCChase.driveStyle, 1.0)
            end

            SetModelAsNoLongerNeeded(pedHash)
        end
    end

    -- Blip nad pojazdem
    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 56)
    SetBlipColour(blip, 1)  -- Czerwony
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Jednostka LSPD")
    EndTextCommandSetBlipName(blip)

    SetModelAsNoLongerNeeded(vehHash)

    local chaserData = {
        veh = veh,
        peds = peds,
        driver = peds[1],
        blip = blip,
        spawn = GetGameTimer(),
        hasExited = false
    }
    table.insert(localChasers, chaserData)
    DebugPrint('^2[TRACKER CHASE]^0 Spawned chaser vehicle with ' .. #peds .. ' officers')
    return chaserData
end

-- Zakończ pościg
local function StopChase(reason)
    DebugPrint('^3[TRACKER CHASE]^0 Stopping chase: '..tostring(reason))
    isChaseActive = false
    chaseData = {}

    for _, c in ipairs(localChasers) do
        if c.blip and DoesBlipExist(c.blip) then RemoveBlip(c.blip) end

        -- Usuń wszystkich pedów
        if c.peds then
            for _, ped in ipairs(c.peds) do
                if DoesEntityExist(ped) then
                    DeleteEntity(ped)
                end
            end
        end

        -- Usuń pojazd
        if c.veh and DoesEntityExist(c.veh) then
            DeleteEntity(c.veh)
        end
    end
    localChasers = {}
end

-- Sprawdź warunki zakończenia pościgu
local function chaseCleanupCheck()
    if not isChaseActive then return end
    local now = GetGameTimer()

    -- Timeout
    if now - chaseStartTime > Config.NPCChase.chaseTimeout then
        StopChase("timeout")
        return
    end

    -- Sprawdź czy target istnieje
    if not chaseData.targetPed or not DoesEntityExist(chaseData.targetPed) then
        StopChase("target_gone")
        return
    end

    -- Sprawdź dystans tylko jeśli są jakieś chasery
    if #localChasers > 0 then
        local tx, ty, tz = table.unpack(GetEntityCoords(chaseData.targetPed))
        local closest = 99999
        local validChasers = 0

        for _, c in ipairs(localChasers) do
            if c.veh and DoesEntityExist(c.veh) then
                validChasers = validChasers + 1
                local vx, vy, vz = table.unpack(GetEntityCoords(c.veh))
                local d = #(vector3(tx, ty, tz) - vector3(vx, vy, vz))
                if d < closest then closest = d end
            end
        end

        -- Tylko zakończ jeśli są chasery i wszyscy są za daleko
        if validChasers > 0 and closest > Config.NPCChase.maxChaseDistance then
            StopChase("too_far")
            return
        end
    end
end

-- Event: rozpocznij pościg NPC
RegisterNetEvent('td_tracker:startNPCChase', function(data)
    if not Config.NPCChase or not Config.NPCChase.enabled then
        DebugPrint('^1[TRACKER CHASE]^0 NPC Chase disabled in config')
        return
    end
    if isChaseActive then
        DebugPrint('^3[TRACKER CHASE]^0 Chase already active, ignoring')
        return
    end

    print('^2[TRACKER CHASE]^0 Starting NPC chase with ' .. Config.NPCChase.initialChasers .. ' vehicles')

    chaseData = data or {}
    chaseData.targetPed = PlayerPedId()
    local coords = GetEntityCoords(chaseData.targetPed)
    chaseData.targetCoords = {x = coords.x, y = coords.y, z = coords.z}

    isChaseActive = true
    chaseStartTime = GetGameTimer()
    waveTimer = GetGameTimer()

    -- Spawn initial chasers
    local spawned = 0
    for i = 1, Config.NPCChase.initialChasers do
        local result = spawnChaserAt(chaseData.targetCoords, chaseData.targetPed)
        if result then
            spawned = spawned + 1
        end
        Wait(300)
    end

    print('^2[TRACKER CHASE]^0 Successfully spawned ' .. spawned .. ' chase vehicles')
    ShowNotification(spawned .. ' policyjnych radiowozów zostało wysłanych w Twój rejon!', 'Alarm LSPD', 'error')
end)

-- Respawn distant vehicles thread
CreateThread(function()
    while true do
        Wait(Config.NPCChase.respawnCheckInterval or 5000)

        if isChaseActive and Config.NPCChase.respawnDistantVehicles then
            if chaseData.targetPed and DoesEntityExist(chaseData.targetPed) then
                local targetCoords = GetEntityCoords(chaseData.targetPed)
                local respawnDistance = Config.NPCChase.respawnCheckDistance or 500.0

                -- Iteruj przez wszystkie chasery i sprawdź ich odległość
                for i = #localChasers, 1, -1 do
                    local c = localChasers[i]

                    if c.veh and DoesEntityExist(c.veh) then
                        local vehCoords = GetEntityCoords(c.veh)
                        local distance = #(targetCoords - vehCoords)

                        -- Jeśli radiowóz jest za daleko i nie wysiedli jeszcze
                        if distance > respawnDistance and not c.hasExited then
                            DebugPrint('^3[TRACKER CHASE]^0 Vehicle too far (' .. math.floor(distance) .. 'm), respawning closer')

                            -- Usuń stary radiowóz
                            if c.blip and DoesBlipExist(c.blip) then RemoveBlip(c.blip) end

                            if c.peds then
                                for _, ped in ipairs(c.peds) do
                                    if DoesEntityExist(ped) then
                                        DeleteEntity(ped)
                                    end
                                end
                            end

                            if DoesEntityExist(c.veh) then
                                DeleteEntity(c.veh)
                            end

                            -- Usuń z listy
                            table.remove(localChasers, i)

                            -- Zespawnuj nowy radiowóz bliżej gracza
                            spawnChaserAt({x = targetCoords.x, y = targetCoords.y, z = targetCoords.z}, chaseData.targetPed)
                        end
                    end
                end
            end
        end
    end
end)

-- Wave manager i AI controller
CreateThread(function()
    while true do
        Wait(500)
        if isChaseActive then
            local now = GetGameTimer()

            -- Aktualizuj zadania dla chaserów
            if chaseData.targetPed and DoesEntityExist(chaseData.targetPed) then
                local targetCoords = GetEntityCoords(chaseData.targetPed)
                local tx, ty, tz = targetCoords.x, targetCoords.y, targetCoords.z

                for _, c in ipairs(localChasers) do
                    if c.veh and DoesEntityExist(c.veh) then
                        local vehCoords = GetEntityCoords(c.veh)
                        local distance = #(targetCoords - vehCoords)

                        -- Sprawdź czy policjanci powinni wysiadać
                        if Config.NPCChase.chasersCanExitVehicle and not c.hasExited and not c.exitInitiated then
                            if distance < (Config.NPCChase.exitVehicleDistance or 30.0) then
                                -- Oznacz że rozpoczęto proces wysiadania
                                c.exitInitiated = true
                                local exitDelay = Config.NPCChase.exitVehicleDelay or 3000

                                DebugPrint('^3[TRACKER CHASE]^0 Officers will exit vehicle in ' .. (exitDelay/1000) .. ' seconds')

                                -- Zatrzymaj pojazd
                                if c.driver and DoesEntityExist(c.driver) then
                                    TaskVehicleTempAction(c.driver, c.veh, 1, 2000) -- Zwolnij
                                end

                                -- Po opóźnieniu wysiądź i zaatakuj
                                SetTimeout(exitDelay, function()
                                    if c.veh and DoesEntityExist(c.veh) and not c.hasExited then
                                        c.hasExited = true
                                        DebugPrint('^3[TRACKER CHASE]^0 Officers exiting vehicle now')

                                        for i, ped in ipairs(c.peds) do
                                            if DoesEntityExist(ped) then
                                                -- Wysiądź z pojazdu
                                                TaskLeaveVehicle(ped, c.veh, 256)

                                                -- Po 2 sekundach zaatakuj gracza
                                                SetTimeout(2000, function()
                                                    if DoesEntityExist(ped) and DoesEntityExist(chaseData.targetPed) then
                                                        TaskCombatPed(ped, chaseData.targetPed, 0, 16)
                                                        SetPedKeepTask(ped, true)
                                                    end
                                                end)
                                            end
                                        end
                                    end
                                end)
                            end
                        end

                        -- Aktualizuj kierowcę (jeśli jeszcze nie wysiedli)
                        if c.driver and DoesEntityExist(c.driver) and not c.hasExited then
                            if (now - (c.lastUpdate or 0)) > 3000 then
                                TaskVehicleDriveToCoordLongrange(c.driver, c.veh, tx, ty, tz, Config.NPCChase.driveSpeed, Config.NPCChase.driveStyle, 1.0)
                                c.lastUpdate = now
                            end
                        end

                        -- Jeśli wysiedli, upewnij się że atakują
                        if c.hasExited then
                            for _, ped in ipairs(c.peds) do
                                if DoesEntityExist(ped) and DoesEntityExist(chaseData.targetPed) then
                                    if GetIsTaskActive(ped, 1) == false then -- Nie ma aktywnego zadania
                                        TaskCombatPed(ped, chaseData.targetPed, 0, 16)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Dodaj fale wsparcia
            if Config.NPCChase.waveInterval > 0 and (now - waveTimer) > Config.NPCChase.waveInterval then
                local activeCount = 0
                for _, c in ipairs(localChasers) do
                    if c.veh and DoesEntityExist(c.veh) then
                        activeCount = activeCount + 1
                    end
                end

                if activeCount < (Config.NPCChase.waveAddIfLessThan or Config.NPCChase.maxChasers) then
                    if chaseData.targetPed and DoesEntityExist(chaseData.targetPed) then
                        local coords = GetEntityCoords(chaseData.targetPed)
                        spawnChaserAt({x = coords.x, y = coords.y, z = coords.z}, chaseData.targetPed)
                        ShowNotification('Dodatkowe jednostki policji zostały wysłane!', 'Wsparcie LSPD', 'error')
                    end
                end
                waveTimer = now
            end

            -- Check cleanup
            chaseCleanupCheck()
        end
    end
end)

-- Event do zatrzymania pościgu (wywoływany po zakończeniu misji)
RegisterNetEvent('td_tracker:client:stopNPCChase', function(reason)
    if isChaseActive then
        StopChase(reason or "mission_ended")
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    StopChase("resource_stop")
end)

print('^2[TD TRACKER]^0 NPC Chase system ready')
