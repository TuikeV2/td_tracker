-- [[ TD Tracker - Server Main ]] --

local ESX = exports['es_extended']:getSharedObject()
_G.activeMissions = {} -- Globalna zmienna

print('^2[TRACKER]^0 Main server loaded')

-- ============================================
-- FUNKCJE GENEROWANIA MISJI
-- ============================================

function GeneratePlate()
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local plate = ''
    
    for i = 1, 3 do
        plate = plate .. letters:sub(math.random(1, #letters), math.random(1, #letters))
    end
    
    plate = plate .. ' '
    
    for i = 1, 4 do
        plate = plate .. math.random(0, 9)
    end
    
    return plate
end

function GenerateSimilarPlates(orig, count)
    local plates = {orig}
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local nums = '0123456789'
    
    while #plates < count do
        local new = orig
        local pos = math.random(1, #orig)
        
        if orig:sub(pos, pos):match('%a') then
            local char = letters:sub(math.random(1, #letters), math.random(1, #letters))
            new = orig:sub(1, pos-1) .. char .. orig:sub(pos+1)
        elseif orig:sub(pos, pos):match('%d') then
            local char = nums:sub(math.random(1, #nums), math.random(1, #nums))
            new = orig:sub(1, pos-1) .. char .. orig:sub(pos+1)
        end
        
        if new ~= orig then
            local exists = false
            for _, p in ipairs(plates) do
                if p == new then exists = true break end
            end
            if not exists then table.insert(plates, new) end
        end
    end
    
    return plates
end

function GenerateStage1Data()
    print('^3[TRACKER DEBUG]^0 Generating Stage 1 data...')
    
    if not ConfigLocations or not ConfigLocations.Stage1 then
        print('^1[TRACKER ERROR]^0 ConfigLocations.Stage1 not found!')
        return nil
    end
    
    if not ConfigLocations.Stage1.searchAreas or #ConfigLocations.Stage1.searchAreas == 0 then
        print('^1[TRACKER ERROR]^0 No search areas configured!')
        return nil
    end
    
    local area = ConfigLocations.Stage1.searchAreas[math.random(#ConfigLocations.Stage1.searchAreas)]
    local plate = GeneratePlate()
    local plates = GenerateSimilarPlates(plate, 5) -- 5 pojazdów jak w README
    local model = ConfigLocations.Stage1.vehicles[math.random(#ConfigLocations.Stage1.vehicles)]
    
    print('^3[TRACKER DEBUG]^0 Target plate:', plate)
    print('^3[TRACKER DEBUG]^0 Vehicle model:', model)
    
    local vehicles = {}
    for i, p in ipairs(plates) do
        local offset = vector3(math.random(-100, 100), math.random(-100, 100), 0)
        local spawn = area.center + offset
        table.insert(vehicles, {
            model = model,
            plate = p,
            coords = vector4(spawn.x, spawn.y, spawn.z, math.random(0, 360))
        })
    end
    
    print('^2[TRACKER DEBUG]^0 Stage 1 data generated with', #vehicles, 'vehicles')
    
    return {
        plate = plate,
        searchArea = area,
        vehicles = vehicles
    }
end

function GenerateStage2Data()
    print('^3[TRACKER DEBUG]^0 ========== GENERATE STAGE 2 ==========')
    print('^3[TRACKER DEBUG]^0 ConfigLocations exists:', ConfigLocations ~= nil)
    print('^3[TRACKER DEBUG]^0 ConfigLocations.Stage2 exists:', ConfigLocations and ConfigLocations.Stage2 ~= nil)
    
    if ConfigLocations and ConfigLocations.Stage2 then
        print('^3[TRACKER DEBUG]^0 vehicleSpawns count:', ConfigLocations.Stage2.vehicleSpawns and #ConfigLocations.Stage2.vehicleSpawns or 0)
        print('^3[TRACKER DEBUG]^0 hideouts count:', ConfigLocations.Stage2.hideouts and #ConfigLocations.Stage2.hideouts or 0)
        print('^3[TRACKER DEBUG]^0 vehicles count:', ConfigLocations.Stage2.vehicles and #ConfigLocations.Stage2.vehicles or 0)
    end
    
    print('^3[TRACKER DEBUG]^0 Generating Stage 2 data...')
    
    if not ConfigLocations or not ConfigLocations.Stage2 then
        print('^1[TRACKER ERROR]^0 ConfigLocations.Stage2 not found!')
        return nil
    end
    
    if not ConfigLocations.Stage2.vehicleSpawns or #ConfigLocations.Stage2.vehicleSpawns == 0 then
        print('^1[TRACKER ERROR]^0 No vehicle spawns configured!')
        return nil
    end
    
    if not ConfigLocations.Stage2.hideouts or #ConfigLocations.Stage2.hideouts == 0 then
        print('^1[TRACKER ERROR]^0 No hideouts configured!')
        return nil
    end
    
    local spawn = ConfigLocations.Stage2.vehicleSpawns[math.random(#ConfigLocations.Stage2.vehicleSpawns)]
    local hideout = ConfigLocations.Stage2.hideouts[math.random(#ConfigLocations.Stage2.hideouts)]
    local model = ConfigLocations.Stage2.vehicles[math.random(#ConfigLocations.Stage2.vehicles)]
    
    -- Upewnij się że spawn jest vector4
    if type(spawn) ~= "vector4" then
        print('^1[TRACKER ERROR]^0 Spawn point is not vector4!')
        return nil
    end
    
    print('^2[TRACKER DEBUG]^0 Stage 2 data generated')
    print('^3[TRACKER DEBUG]^0 Spawn:', spawn)
    print('^3[TRACKER DEBUG]^0 Hideout:', hideout)
    
    return {
        spawnPoint = spawn,
        hideout = hideout,
        vehicleModel = model
    }
end

function GenerateStage3Data()
    print('^3[TRACKER DEBUG]^0 ========== GENERATE STAGE 3 ==========')
    print('^3[TRACKER DEBUG]^0 ConfigLocations exists:', ConfigLocations ~= nil)
    print('^3[TRACKER DEBUG]^0 ConfigLocations.Stage3 exists:', ConfigLocations and ConfigLocations.Stage3 ~= nil)
    
    if ConfigLocations and ConfigLocations.Stage3 then
        print('^3[TRACKER DEBUG]^0 vehicleSpawns count:', ConfigLocations.Stage3.vehicleSpawns and #ConfigLocations.Stage3.vehicleSpawns or 0)
        print('^3[TRACKER DEBUG]^0 hideouts count:', ConfigLocations.Stage3.hideouts and #ConfigLocations.Stage3.hideouts or 0)
        print('^3[TRACKER DEBUG]^0 vehicles count:', ConfigLocations.Stage3.vehicles and #ConfigLocations.Stage3.vehicles or 0)
    end
    
    print('^3[TRACKER DEBUG]^0 Generating Stage 3 data...')
    
    if not ConfigLocations or not ConfigLocations.Stage3 then
        print('^1[TRACKER ERROR]^0 ConfigLocations.Stage3 not found!')
        return nil
    end
    
    if not ConfigLocations.Stage3.dismantleLocations or #ConfigLocations.Stage3.dismantleLocations == 0 then
        print('^1[TRACKER ERROR]^0 No dismantle locations configured!')
        return nil
    end
    
    local loc = ConfigLocations.Stage3.dismantleLocations[math.random(#ConfigLocations.Stage3.dismantleLocations)]
    local model = ConfigLocations.Stage3.vehicles[math.random(#ConfigLocations.Stage3.vehicles)]
    
    print('^2[TRACKER DEBUG]^0 Stage 3 data generated')
    
    return {
        location = loc,
        vehicleModel = model
    }
end

function GenerateMissionData(stage)
    print('^3[TRACKER DEBUG]^0 === GenerateMissionData called ===')
    print('^3[TRACKER DEBUG]^0 Stage:', stage)
    print('^3[TRACKER DEBUG]^0 Stage type:', type(stage))
    
    if stage == 1 then
        print('^3[TRACKER DEBUG]^0 Calling GenerateStage1Data...')
        return GenerateStage1Data()
    elseif stage == 2 then
        print('^3[TRACKER DEBUG]^0 Calling GenerateStage2Data...')
        local result = GenerateStage2Data()
        print('^3[TRACKER DEBUG]^0 GenerateStage2Data returned:', result ~= nil)
        if result then
            print('^3[TRACKER DEBUG]^0 Stage2 result:', json.encode(result))
        end
        return result
    elseif stage == 3 then
        print('^3[TRACKER DEBUG]^0 Calling GenerateStage3Data...')
        return GenerateStage3Data()
    end
    
    print('^1[TRACKER ERROR]^0 Invalid stage:', stage)
    return nil
end

-- ============================================
-- POBIERANIE DOSTĘPNYCH MISJI DLA GRACZA
-- ============================================

RegisterNetEvent('td_tracker:server:getAvailableStages', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = xPlayer.identifier
    
    -- 1. Sprawdzenie, czy gracz już ma aktywną misję
    if activeMissions[src] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'TD Tracker', 
            description = 'Już masz aktywną misję!', 
            type = 'error'
        })
        return
    end

    -- 2. Sprawdzenie cooldownu
    -- UWAGA: Jeśli IsOnCooldown zwróci true, powiadamiamy i PRZERYWAMY
    if IsOnCooldown(identifier) then
        local remainingTime = GetCooldownTime(identifier) 
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'TD Tracker', 
            description = 'Musisz poczekać! Misja dostępna za: ' .. FormatTime(remainingTime), 
            type = 'error'
        })
        return
    end

    -- 3. Pobranie reputacji i dostępnych etapów
    local reputation = GetReputation(identifier)
    local availableStages = GetAvailableStages(reputation)

    -- 4. Wysłanie listy do klienta, aby wyświetlił menu
    TriggerClientEvent('td_tracker:client:showMissionSelection', src, availableStages)
end)

-- ============================================
-- OBSŁUGA ROZPOCZĘCIA MISJI PRZEZ GRACZA (SERVER)
-- ============================================

RegisterNetEvent('td_tracker:server:requestMissionStart', function(selectedStage)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local identifier = xPlayer.identifier
    
    -- Walidacja: Upewnienie się, że gracz wybrał etap
    if not selectedStage or type(selectedStage) ~= 'number' or selectedStage < 1 or selectedStage > 3 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'TD Tracker', 
            description = 'Błąd w wyborze misji. Spróbuj ponownie.', 
            type = 'error'
        })
        return
    end
    
    -- 1. Sprawdzenie, czy gracz już ma aktywną misję
    if activeMissions[src] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'TD Tracker', 
            description = 'Już masz aktywną misję!', 
            type = 'error'
        })
        return
    end

    -- 2. Sprawdzenie cooldownu
    if IsOnCooldown(identifier) then
        local remainingTime = GetCooldownTime(identifier) 
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'TD Tracker', 
            description = 'Musisz poczekać! Misja dostępna za: ' .. FormatTime(remainingTime), 
            type = 'error'
        })
        return
    end

    -- 3. Weryfikacja, czy wybrany etap jest dostępny na podstawie reputacji
    local reputation = GetReputation(identifier)
    local stageConfig = Config.Stages[selectedStage]
    
    if not stageConfig or reputation < stageConfig.minReputation then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'TD Tracker', 
            description = 'Nie możesz podjąć tej misji! Wymagana reputacja: ' .. (stageConfig and stageConfig.minReputation or 'N/A'), 
            type = 'error'
        })
        return
    end

    -- 4. Rozpoczęcie misji
    local success = StartMissionForPlayer(src, selectedStage)

    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'TD Tracker', 
            description = string.format('Rozpoczynasz misję Etap %d (%s)! Uważaj na siebie.', selectedStage, stageConfig.name), 
            type = 'success',
            duration = 5000
        })
        -- Ustawienie cooldownu po pomyślnym rozpoczęciu
        SetCooldown(identifier)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'TD Tracker', 
            description = 'Nie udało się rozpocząć misji. Spróbuj ponownie za chwilę.', 
            type = 'error'
        })
    end
end)

-- ============================================
-- FUNKCJA STARTOWANIA MISJI (TYLKO JEDNA!)
-- ============================================

function StartMissionForPlayer(src, stage)
    print('^3[TRACKER DEBUG]^0 ========== START MISSION ==========')
    print('^3[TRACKER DEBUG]^0 Player:', src, 'Stage:', stage)
    
    if not src or src == 0 then
        print('^1[TRACKER ERROR]^0 Invalid player source')
        return false
    end
    print('^3[TRACKER DEBUG]^0 [STEP 1] Source valid')
    
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then 
        print('^1[TRACKER DEBUG]^0 xPlayer not found')
        return false
    end
    print('^3[TRACKER DEBUG]^0 [STEP 2] xPlayer found:', xPlayer.identifier)
    
    if activeMissions[src] then
        print('^1[TRACKER DEBUG]^0 Player has active mission')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Błąd',
            description = 'Masz aktywną misję',
            type = 'error'
        })
        return false
    end
    print('^3[TRACKER DEBUG]^0 [STEP 3] No active mission')
    
    if IsOnCooldown(xPlayer.identifier) then
        print('^1[TRACKER DEBUG]^0 Player on cooldown')
        local time = GetCooldownTime(xPlayer.identifier)
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Cooldown',
            description = 'Odczekaj: ' .. FormatTime(time),
            type = 'warning'
        })
        return false
    end
    print('^3[TRACKER DEBUG]^0 [STEP 4] Cooldown OK')
    
    local rep = GetReputation(xPlayer.identifier)
    print('^3[TRACKER DEBUG]^0 [STEP 5] Rep retrieved:', rep)
    
    local req = Config.Stages[stage].minReputation
    print('^3[TRACKER DEBUG]^0 [STEP 6] Required rep:', req)
    
    if rep < req then
        print('^1[TRACKER DEBUG]^0 Insufficient reputation')
        TriggerClientEvent('td_tracker:client:insufficientRep', src, req, rep)
        return false
    end
    print('^3[TRACKER DEBUG]^0 [STEP 7] Rep check passed')
    
    print('^3[TRACKER DEBUG]^0 [STEP 8] Calling GenerateMissionData...')
    local data = GenerateMissionData(stage)
    print('^3[TRACKER DEBUG]^0 [STEP 9] Data returned:', data ~= nil)
    
    if not data then
        print('^1[TRACKER ERROR]^0 Failed to generate mission data')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Błąd',
            description = 'Nie udało się wygenerować misji',
            type = 'error'
        })
        return false
    end
    print('^3[TRACKER DEBUG]^0 [STEP 10] Data generated successfully')
    print('^3[TRACKER DEBUG]^0 [STEP 10a] Data content:', json.encode(data))
    
    activeMissions[src] = {
        type = stage,
        data = data,
        startTime = os.time(),
        identifier = xPlayer.identifier
    }
    print('^3[TRACKER DEBUG]^0 [STEP 11] Mission added to activeMissions')
    
    local clientData = {
        type = stage,
        active = true
    }
    print('^3[TRACKER DEBUG]^0 [STEP 12] ClientData initialized')
    
    if stage == 1 then
        clientData.plate = data.plate
        clientData.searchArea = data.searchArea
        clientData.vehicles = data.vehicles
        print('^3[TRACKER DEBUG]^0 [STEP 13] Stage 1 data added')
    elseif stage == 2 then
        print('^3[TRACKER DEBUG]^0 [STEP 13] Adding Stage 2 data...')
        print('^3[TRACKER DEBUG]^0 data.spawnPoint:', data.spawnPoint)
        print('^3[TRACKER DEBUG]^0 data.hideout:', data.hideout)
        print('^3[TRACKER DEBUG]^0 data.vehicleModel:', data.vehicleModel)
        
        clientData.spawnPoint = data.spawnPoint
        clientData.hideout = data.hideout
        clientData.vehicleModel = data.vehicleModel
        
        print('^3[TRACKER DEBUG]^0 [STEP 13a] Stage 2 data added')
    elseif stage == 3 then
        clientData.location = data.location
        clientData.vehicleModel = data.vehicleModel
        print('^3[TRACKER DEBUG]^0 [STEP 13] Stage 3 data added')
    end
    
    print('^3[TRACKER DEBUG]^0 [STEP 14] Preparing to send to client')
    print('^3[TRACKER DEBUG]^0 [STEP 14a] Final clientData:', json.encode(clientData))
    
    print('^3[TRACKER DEBUG]^0 [STEP 15] Triggering client event...')
    TriggerClientEvent('td_tracker:client:startMission', src, clientData)
    
    print('^2[TRACKER DEBUG]^0 [STEP 16] Mission started successfully')
    
    LogAction(xPlayer.identifier, 'mission_start', {stage = stage})
    return true
end

-- ============================================
-- EVENTY
-- ============================================

ESX.RegisterServerCallback('td_tracker:getPlayerStats', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then 
        cb({reputation = 0, total_missions = 0, successful_missions = 0, failed_missions = 0})
        return 
    end
    
    local stats = MySQL.single.await('SELECT * FROM tracker_reputation WHERE identifier = ?', {xPlayer.identifier})
    
    if stats then
        cb(stats)
    else
        cb({reputation = 0, total_missions = 0, successful_missions = 0, failed_missions = 0})
    end
end)

RegisterNetEvent('td_tracker:server:requestDialog', function()
    local src = source
    print('^3[TRACKER DEBUG]^0 Dialog requested by:', src)
    
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then 
        print('^1[TRACKER DEBUG]^0 xPlayer not found')
        return 
    end
    
    local rep = GetReputation(xPlayer.identifier)
    local stages = GetAvailableStages(rep)
    
    print('^3[TRACKER DEBUG]^0 Rep:', rep, 'Stages:', json.encode(stages))
    
    TriggerClientEvent('td_tracker:client:showDialog', src, rep, stages)
end)

RegisterNetEvent('td_tracker:server:startMission', function(stage)
    local src = source
    print('^3[TRACKER DEBUG]^0 Event startMission - Stage:', stage, 'Player:', src)
    StartMissionForPlayer(src, stage)
end)

RegisterNetEvent('td_tracker:server:completeMission', function(type, timeTaken, timeLimit)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local mission = activeMissions[src]
    if not mission or mission.type ~= type then return end
    
    local rep = GetReputation(xPlayer.identifier)
    local reward = ConfigRewards.Calculate(type, rep, timeTaken, timeLimit)
    
    if reward then
        xPlayer.addMoney(reward.money)
        xPlayer.addAccountMoney('black_money', reward.blackMoney)
        
        for _, item in ipairs(reward.items) do
            xPlayer.addInventoryItem(item.name, item.count)
        end
        
        AddReputation(xPlayer.identifier, reward.reputation)
        SaveMission(xPlayer.identifier, type, 'completed', reward.reputation, reward.money, reward.blackMoney, timeTaken / 1000)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = ConfigTexts.Notifications.missionComplete.title,
            description = string.format(ConfigTexts.Notifications.missionComplete.description, reward.money, reward.blackMoney, reward.reputation),
            type = 'success'
        })
        
        SetCooldown(xPlayer.identifier)
        LogAction(xPlayer.identifier, 'mission_complete', {stage = type, reward = reward})
    end
    
    activeMissions[src] = nil
end)

RegisterNetEvent('td_tracker:server:failMission', function(type, reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local mission = activeMissions[src]
    if not mission then return end
    
    local penalty = ConfigRewards.FailurePenalty[type] or 20
    RemoveReputation(xPlayer.identifier, penalty)
    SaveMission(xPlayer.identifier, type, 'failed', -penalty, 0, 0, 0)
    
    SetCooldown(xPlayer.identifier)
    activeMissions[src] = nil
    
    LogAction(xPlayer.identifier, 'mission_fail', {stage = type, reason = reason})
end)

RegisterNetEvent('td_tracker:server:vehicleStolen', function(coords, vehicleModel)
    local src = source

    -- Określ stage na podstawie aktywnej misji
    local mission = activeMissions[src]
    local stage = mission and mission.type or 1

    -- Wywołaj nową funkcję NotifyPolice z lb_tablet
    NotifyPolice(coords, stage, vehicleModel)
end)

RegisterNetEvent('td_tracker:server:chaseEnded', function()
    local src = source
    ClearPoliceNotification(src)
end)

RegisterNetEvent('td_tracker:server:checkLockpick', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local item = xPlayer.getInventoryItem(Config.LockpickItem)
    if item and item.count > 0 then
        TriggerClientEvent('td_tracker:client:startLockpick', src)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Brak',
            description = 'Potrzebujesz ' .. Config.LockpickItem,
            type = 'error'
        })
    end
end)

RegisterNetEvent('td_tracker:server:breakLockpick', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    xPlayer.removeInventoryItem(Config.LockpickItem, 1)
end)

-- ============================================
-- FUNKCJE POMOCNICZE
-- ============================================

function GetAvailableStages(rep)
    local stages = {}
    for stage, cfg in pairs(Config.Stages) do
        if cfg.enabled and rep >= cfg.minReputation then
            table.insert(stages, stage)
        end
    end
    return stages
end

function FormatTime(sec)
    local min = math.floor(sec / 60)
    local s = sec % 60
    return string.format('%02d:%02d', min, s)
end

function NotifyPolice(coords, msg, src)
    if Config.DispatchSystem == 'cd_dispatch' then
        TriggerClientEvent('cd_dispatch:AddNotification', -1, {
            job_table = {'police'},
            coords = coords,
            title = '10-35 - ' .. msg,
            message = 'Zgłoszenie kradzieży',
            flash = 0,
            unique_id = src,
            blip = {
                sprite = 229,
                colour = 1,
                scale = 1.0,
                text = msg,
                time = Config.ChaseTime,
                radius = Config.ChaseAreaSize
            }
        })
    elseif Config.DispatchSystem == 'ps-dispatch' then
        exports['ps-dispatch']:VehicleTheft(coords)
    end
end

function ClearPoliceNotification(src)
    -- Implementacja czyszczenia powiadomienia
end

AddEventHandler('playerDropped', function()
    local src = source
    if activeMissions[src] then
        local mission = activeMissions[src]
        SaveMission(mission.identifier, mission.type, 'abandoned', 0, 0, 0, 0)
        activeMissions[src] = nil
    end
end)

print('^2[TRACKER]^0 Main server fully loaded')