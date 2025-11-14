local ESX = exports['es_extended']:getSharedObject()
_G.activeMissions = {}

local function DebugPrint(msg)
    if Config.Debug then
        print(msg)
    end
end

if Config.Debug then print('^2[TRACKER]^0 Main server loaded') end -- POPRAWKA: Dodano 'end'

-- ============================================
-- FUNKCJE GENEROWANIA MISJI
-- ============================================

function GeneratePlate()
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local plate = ''

    for i = 1, 3 do
        local idx = math.random(1, #letters)
        plate = plate .. letters:sub(idx, idx)
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
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Generating Stage 1 data...') end

    -- Pobierz obszary wyszukiwania z bazy danych
    local searchAreas = exports.td_tracker:GetSearchAreas()
    if not searchAreas or #searchAreas == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No search areas configured in database!') end
        return nil
    end

    -- Pobierz pulę pojazdów z bazy danych (tier C dla Stage 1)
    local vehiclePool = exports.td_tracker:GetVehiclePool(1, 'C')
    if not vehiclePool or #vehiclePool == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No vehicles configured for Stage 1!') end
        return nil
    end

    local area = searchAreas[math.random(#searchAreas)]
    local plate = GeneratePlate()
    local plates = GenerateSimilarPlates(plate, 5) -- 5 pojazdów jak w README
    local model = vehiclePool[math.random(#vehiclePool)].model

    if Config.Debug then print('^3[TRACKER DEBUG]^0 Target plate:', plate) end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Vehicle model:', model) end

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

    if Config.Debug then print('^2[TRACKER DEBUG]^0 Stage 1 data generated with', #vehicles, 'vehicles') end

    return {
        plate = plate,
        searchArea = area,
        vehicles = vehicles
    }
end

function GenerateStage2Data()
    if Config.Debug then print('^3[TRACKER DEBUG]^0 ========== GENERATE STAGE 2 ==========') end

    -- Pobierz lokacje NPC z bazy danych
    local npcLocations = exports.td_tracker:GetNPCLocations('stage2_npc')
    if not npcLocations or #npcLocations == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No NPC locations configured for Stage 2!') end
        return nil
    end

    -- Pobierz lokacje pojazdów z bazy danych
    local vehicleLocations = exports.td_tracker:GetVehicleLocations(2, 'spawn')
    if not vehicleLocations or #vehicleLocations == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No vehicle spawn locations configured for Stage 2!') end
        return nil
    end

    -- Pobierz kryjówki z bazy danych
    local hideouts = exports.td_tracker:GetVehicleLocations(2, 'hideout')
    if not hideouts or #hideouts == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No hideouts configured for Stage 2!') end
        return nil
    end

    -- Pobierz pulę pojazdów z bazy danych
    local vehiclePool = exports.td_tracker:GetVehiclePool(2, 'B')
    if not vehiclePool or #vehiclePool == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No vehicles configured for Stage 2!') end
        return nil
    end

    local npcLoc = npcLocations[math.random(#npcLocations)]
    local vehLoc = vehicleLocations[math.random(#vehicleLocations)]
    local hideout = hideouts[math.random(#hideouts)]
    local model = vehiclePool[math.random(#vehiclePool)].model

    if Config.Debug then print('^2[TRACKER DEBUG]^0 Stage 2 data generated') end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 NPC:', npcLoc.coords) end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Vehicle:', vector4(vehLoc.x, vehLoc.y, vehLoc.z, vehLoc.w)) end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Hideout:', vector3(hideout.x, hideout.y, hideout.z)) end

    return {
        npcSpawn = vector4(npcLoc.coords.x, npcLoc.coords.y, npcLoc.coords.z, npcLoc.heading),
        spawnPoint = vector4(vehLoc.x, vehLoc.y, vehLoc.z, vehLoc.w),
        hideout = vector3(hideout.x, hideout.y, hideout.z),
        vehicleModel = model
    }
end

function GenerateStage3Data()
    if Config.Debug then print('^3[TRACKER DEBUG]^0 ========== GENERATE STAGE 3 ==========') end

    -- Pobierz lokacje NPC z bazy danych
    local npcLocations = exports.td_tracker:GetNPCLocations('stage3_npc')
    if not npcLocations or #npcLocations == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No NPC locations configured for Stage 3!') end
        return nil
    end

    -- Pobierz lokacje pojazdów do rozbiórki z bazy danych
    local vehicleLocations = exports.td_tracker:GetVehicleLocations(3, 'spawn')
    if not vehicleLocations or #vehicleLocations == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No vehicle spawn locations configured for Stage 3!') end
        return nil
    end

    -- Pobierz lokacje busów z bazy danych
    local busLocations = exports.td_tracker:GetVehicleLocations(3, 'bus_spawn')
    if not busLocations or #busLocations == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No bus spawn locations configured for Stage 3!') end
        return nil
    end

    -- Pobierz punkty sprzedaży z bazy danych
    local sellPoints = exports.td_tracker:GetVehicleLocations(3, 'sell_point')
    if not sellPoints or #sellPoints == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No sell points configured for Stage 3!') end
        return nil
    end

    -- Pobierz pulę pojazdów z bazy danych
    local vehiclePool = exports.td_tracker:GetVehiclePool(3, 'A')
    if not vehiclePool or #vehiclePool == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No vehicles configured for Stage 3!') end
        return nil
    end

    local npcLoc = npcLocations[math.random(#npcLocations)]
    local vehLoc = vehicleLocations[math.random(#vehicleLocations)]
    local busLoc = busLocations[math.random(#busLocations)]
    local sellPoint = sellPoints[math.random(#sellPoints)]
    local model = vehiclePool[math.random(#vehiclePool)].model

    if Config.Debug then print('^2[TRACKER DEBUG]^0 Stage 3 data generated') end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 NPC:', npcLoc.coords) end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Vehicle:', vector4(vehLoc.x, vehLoc.y, vehLoc.z, vehLoc.w)) end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Bus:', vector4(busLoc.x, busLoc.y, busLoc.z, busLoc.w)) end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Sell point:', vector3(sellPoint.x, sellPoint.y, sellPoint.z)) end

    return {
        npcSpawn = vector4(npcLoc.coords.x, npcLoc.coords.y, npcLoc.coords.z, npcLoc.heading),
        vehicleSpawn = vector4(vehLoc.x, vehLoc.y, vehLoc.z, vehLoc.w),
        busSpawn = vector4(busLoc.x, busLoc.y, busLoc.z, busLoc.w),
        sellPoint = vector3(sellPoint.x, sellPoint.y, sellPoint.z),
        vehicleModel = model
    }
end

function GenerateMissionData(stage)
    if Config.Debug then print('^3[TRACKER DEBUG]^0 === GenerateMissionData called ===') end -- POPRAWIONE
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Stage:', stage) end -- POPRAWIONE
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Stage type:', type(stage)) end -- POPRAWIONE
    
    if stage == 1 then
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Calling GenerateStage1Data...') end -- POPRAWIONE
        return GenerateStage1Data()
    elseif stage == 2 then
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Calling GenerateStage2Data...') end -- POPRAWIONE
        local result = GenerateStage2Data()
        if Config.Debug then print('^3[TRACKER DEBUG]^0 GenerateStage2Data returned:', result ~= nil) end -- POPRAWIONE
        if result then
            if Config.Debug then print('^3[TRACKER DEBUG]^0 Stage2 result:', json.encode(result)) end -- POPRAWIONE
        end
        return result
    elseif stage == 3 then
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Calling GenerateStage3Data...') end -- POPRAWIONE
        return GenerateStage3Data()
    end
    
    if Config.Debug then print('^1[TRACKER ERROR]^0 Invalid stage:', stage) end -- POPRAWIONE
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
    -- DEBUG PRINTS (ZAMYKANE NATYCHMIAST)
    if Config.Debug then print('^3[TRACKER DEBUG]^0 ========== START MISSION ==========') end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Player:', src, 'Stage:', stage) end
    
    -- [STEP 1] WALIDACJA SOURCE
    if not src or src == 0 then
        if Config.Debug then print('^1[TRACKER ERROR]^0 Invalid player source') end
        return false
    end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 1] Source valid') end
    
    -- [STEP 2] POBRANIE GRACZA
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then 
        if Config.Debug then print('^1[TRACKER DEBUG]^0 xPlayer not found') end
        return false
    end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 2] xPlayer found:', xPlayer.identifier) end
    
    -- [STEP 3] AKTYWNA MISJA
    if activeMissions[src] then
        if Config.Debug then print('^1[TRACKER DEBUG]^0 Player has active mission') end
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Błąd',
            description = 'Masz aktywną misję',
            type = 'error'
        })
        return false
    end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 3] No active mission') end
    
    -- [STEP 4] COOLDOWN
    if IsOnCooldown(xPlayer.identifier) then
        if Config.Debug then print('^1[TRACKER DEBUG]^0 Player on cooldown') end
        local time = GetCooldownTime(xPlayer.identifier)
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Cooldown',
            description = 'Odczekaj: ' .. FormatTime(time),
            type = 'warning'
        })
        return false
    end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 4] Cooldown OK') end
    
    -- [STEP 5-7] REPUTACJA
    local rep = GetReputation(xPlayer.identifier)
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 5] Rep retrieved:', rep) end
    
    local req = Config.Stages[stage].minReputation
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 6] Required rep:', req) end
    
    if rep < req then
        if Config.Debug then print('^1[TRACKER DEBUG]^0 Insufficient reputation') end
        TriggerClientEvent('td_tracker:client:insufficientRep', src, req, rep)
        return false
    end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 7] Rep check passed') end
    
    -- [STEP 8-10] GENEROWANIE DANYCH
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 8] Calling GenerateMissionData...') end
    local data = GenerateMissionData(stage)
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 9] Data returned:', data ~= nil) end
    
    if not data then
        if Config.Debug then print('^1[TRACKER ERROR]^0 Failed to generate mission data') end
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Błąd',
            description = 'Nie udało się wygenerować misji',
            type = 'error'
        })
        return false
    end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 10] Data generated successfully') end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 10a] Data content:', json.encode(data)) end
    
    -- [STEP 11] UTWORZENIE AKTYWNEJ MISJI
    activeMissions[src] = {
        type = stage,
        data = data,
        startTime = os.time(),
        identifier = xPlayer.identifier
    }
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 11] Mission added to activeMissions') end
    
    -- [STEP 12-13] PRZYGOTOWANIE DANYCH DLA KLIENTA
    local clientData = {
        type = stage,
        active = true
    }
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 12] ClientData initialized') end
    
    if stage == 1 then
        clientData.plate = data.plate
        clientData.searchArea = data.searchArea
        clientData.vehicles = data.vehicles
        if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 13] Stage 1 data added') end
    elseif stage == 2 then
        if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 13] Adding Stage 2 data...') end
        clientData.npcSpawn = data.npcSpawn
        clientData.spawnPoint = data.spawnPoint
        clientData.hideout = data.hideout
        clientData.vehicleModel = data.vehicleModel
        if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 13a] Stage 2 data added') end
    elseif stage == 3 then
        if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 13] Adding Stage 3 data...') end
        clientData.npcSpawn = data.npcSpawn
        clientData.vehicleSpawn = data.vehicleSpawn
        clientData.busSpawn = data.busSpawn
        clientData.sellPoint = data.sellPoint
        clientData.vehicleModel = data.vehicleModel
        if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 13] Stage 3 data added') end
    end
    
    -- [STEP 14-16] WYSŁANIE DO KLIENTA I ZAKOŃCZENIE
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 14] Preparing to send to client') end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 14a] Final clientData:', json.encode(clientData)) end
    
    if Config.Debug then print('^3[TRACKER DEBUG]^0 [STEP 15] Triggering client event...') end
    TriggerClientEvent('td_tracker:client:startMission', src, clientData)
    
    if Config.Debug then print('^2[TRACKER DEBUG]^0 [STEP 16] Mission started successfully') end
    
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
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Dialog requested by:', src) end
    
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then 
        if Config.Debug then print('^1[TRACKER DEBUG]^0 xPlayer not found') end
        return 
    end
    
    local rep = GetReputation(xPlayer.identifier)
    local stages = GetAvailableStages(rep)
    
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Rep:', rep, 'Stages:', json.encode(stages)) end
    
    TriggerClientEvent('td_tracker:client:showDialog', src, rep, stages)
end)

RegisterNetEvent('td_tracker:server:startMission', function(stage)
    local src = source
    if Config.Debug then -- POPRAWIONE
        print('^3[TRACKER DEBUG]^0 Event startMission - Stage:', stage, 'Player:', src)
    end -- POPRAWIONE
    StartMissionForPlayer(src, stage) -- Upewnienie się, że funkcja jest wywoływana zawsze
end)

RegisterNetEvent('td_tracker:server:completeMission', function(type, timeTaken, timeLimit)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local mission = activeMissions[src]
    if not mission or mission.type ~= type then return end
    
    local rep = GetReputation(xPlayer.identifier)

    -- Pobierz nagrody z bazy danych
    local rewardConfig = exports.td_tracker:GetReward(type, 'B') -- Domyślnie tier B
    if not rewardConfig then
        if Config.Debug then print('^1[TRACKER ERROR]^0 No reward configuration found for stage', type) end
        return
    end

    -- Oblicz nagrody
    local money = math.random(rewardConfig.minMoney, rewardConfig.maxMoney)
    local reputation = math.random(rewardConfig.minReputation, rewardConfig.maxReputation)

    -- Bonus za szybkie ukończenie (50% czasu)
    local speedBonus = GetSetting('speed_bonus_enabled', true)
    if speedBonus and timeTaken <= (timeLimit * 0.5) then
        money = money + math.random(1000, 3000)
        reputation = reputation + math.random(5, 15)
    end

    -- Wypłać nagrody
    xPlayer.addMoney(money)

    AddReputation(xPlayer.identifier, reputation)
    SaveMission(xPlayer.identifier, type, 'completed', reputation, money, 0, timeTaken / 1000)
        
    TriggerClientEvent('ox_lib:notify', src, {
        title = ConfigTexts.Notifications.missionComplete.title,
        description = string.format(ConfigTexts.Notifications.missionComplete.description, money, 0, reputation),
        type = 'success'
    })

    SetCooldown(xPlayer.identifier)
    LogAction(xPlayer.identifier, 'mission_complete', {stage = type, money = money, reputation = reputation})
    
    activeMissions[src] = nil
end)

RegisterNetEvent('td_tracker:server:failMission', function(type, reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local mission = activeMissions[src]
    if not mission then return end
    
    -- Pobierz karę z bazy danych
    local penalty = exports.td_tracker:GetPenalty(type)
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

    -- Wywołaj nową funkcję NotifyPolice z lb_tablet (przekaż src dla pościgu NPC)
    NotifyPolice(coords, stage, vehicleModel, src)
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

-- NotifyPolice moved to server/police.lua

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

-- ============================================
-- CALLBACKS (MYSQL-BASED)
-- ============================================

ESX.RegisterServerCallback('td_tracker:getNPCLocations', function(source, cb)
    local npcLocations = exports.td_tracker:GetNPCLocations('quest_giver')
    cb(npcLocations)
end)

print('^2[TRACKER]^0 Main server fully loaded')