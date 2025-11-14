-- ============================================
-- TD TRACKER - ADMIN PANEL SERVER
-- ============================================

local ESX = exports['es_extended']:getSharedObject()

-- ============================================
-- PERMISSION CHECK
-- ============================================

local function IsAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    for _, group in ipairs(Config.AdminGroups) do
        if xPlayer.getGroup() == group then
            return true
        end
    end

    return false
end

RegisterNetEvent('td_tracker:admin:checkPermission', function()
    local source = source

    if IsAdmin(source) then
        TriggerClientEvent('td_tracker:admin:openPanel', source)
    else
        TriggerClientEvent('td_tracker:admin:notification', source, 'Nie masz uprawnień!', 'error')
    end
end)

-- ============================================
-- STATS & PLAYERS
-- ============================================

RegisterNetEvent('td_tracker:admin:getStats', function()
    local source = source
    if not IsAdmin(source) then return end

    local activePlayers = 0
    local activeMissions = 0
    local completedToday = 0
    local failedToday = 0

    -- Zlicz aktywnych graczy i misje
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in pairs(xPlayers) do
        activePlayers = activePlayers + 1
        -- Tu możesz dodać logikę sprawdzającą aktywne misje
    end

    -- Pobierz statystyki z bazy (dzisiejsze)
    local result = MySQL.query.await([[
        SELECT
            SUM(CASE WHEN success = 1 AND DATE(completed_at) = CURDATE() THEN 1 ELSE 0 END) as completed,
            SUM(CASE WHEN success = 0 AND DATE(completed_at) = CURDATE() THEN 1 ELSE 0 END) as failed
        FROM td_tracker_logs
    ]])

    if result and result[1] then
        completedToday = result[1].completed or 0
        failedToday = result[1].failed or 0
    end

    TriggerClientEvent('td_tracker:admin:updateStats', source, {
        activePlayers = activePlayers,
        activeMissions = activeMissions,
        completedToday = completedToday,
        failedToday = failedToday
    })
end)

function GetAllPlayers()
    local players = {}
    local xPlayers = ESX.GetExtendedPlayers()

    for _, xPlayer in pairs(xPlayers) do
        local stats = MySQL.query.await('SELECT reputation, completed_missions, failed_missions FROM td_tracker_reputation WHERE identifier = ?', {
            xPlayer.identifier
        })

        local playerData = {
            id = xPlayer.source,
            name = xPlayer.getName(),
            reputation = stats and stats[1] and stats[1].reputation or 0,
            completed = stats and stats[1] and stats[1].completed_missions or 0,
            failed = stats and stats[1] and stats[1].failed_missions or 0,
            active = true
        }

        table.insert(players, playerData)
    end

    return players
end

RegisterNetEvent('td_tracker:admin:getPlayers', function()
    local source = source
    if not IsAdmin(source) then return end

    local players = GetAllPlayers()
    TriggerClientEvent('td_tracker:admin:updatePlayers', source, players)
end)

-- ============================================
-- COMMANDS
-- ============================================

RegisterNetEvent('td_tracker:admin:executeCommand', function(data)
    local source = source
    if not IsAdmin(source) then return end

    local command = data.command

    if command == 'setRep' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end

        -- Upewnij się że rekord istnieje
        MySQL.query([[
            INSERT INTO td_tracker_reputation (identifier, reputation, completed_missions, failed_missions)
            VALUES (?, ?, 0, 0)
            ON DUPLICATE KEY UPDATE reputation = ?
        ]], {
            target.identifier, data.value, data.value
        })

        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Ustawiono reputację %d dla %s', data.value, target.getName()), 'success')
        -- Odśwież dane graczy
        Wait(500)
        TriggerClientEvent('td_tracker:admin:updatePlayers', -1, GetAllPlayers())

    elseif command == 'addRep' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end

        -- Upewnij się że rekord istnieje
        MySQL.query([[
            INSERT INTO td_tracker_reputation (identifier, reputation, completed_missions, failed_missions)
            VALUES (?, ?, 0, 0)
            ON DUPLICATE KEY UPDATE reputation = reputation + ?
        ]], {
            target.identifier, data.value, data.value
        })

        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Dodano %d reputacji dla %s', data.value, target.getName()), 'success')
        -- Odśwież dane graczy
        Wait(500)
        TriggerClientEvent('td_tracker:admin:updatePlayers', -1, GetAllPlayers())

    elseif command == 'removeRep' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end

        -- Upewnij się że rekord istnieje
        MySQL.query([[
            INSERT INTO td_tracker_reputation (identifier, reputation, completed_missions, failed_missions)
            VALUES (?, 0, 0, 0)
            ON DUPLICATE KEY UPDATE reputation = GREATEST(reputation - ?, 0)
        ]], {
            target.identifier, data.value
        })

        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Odjęto %d reputacji dla %s', data.value, target.getName()), 'success')
        -- Odśwież dane graczy
        Wait(500)
        TriggerClientEvent('td_tracker:admin:updatePlayers', -1, GetAllPlayers())

    elseif command == 'resetRep' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end

        MySQL.query([[
            INSERT INTO td_tracker_reputation (identifier, reputation, completed_missions, failed_missions)
            VALUES (?, 0, 0, 0)
            ON DUPLICATE KEY UPDATE reputation = 0
        ]], {
            target.identifier
        })

        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Zresetowano reputację dla %s', target.getName()), 'success')
        -- Odśwież dane graczy
        Wait(500)
        TriggerClientEvent('td_tracker:admin:updatePlayers', -1, GetAllPlayers())

    elseif command == 'cancelMission' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end
        TriggerClientEvent('td_tracker:client:cancelMission', data.playerId)
        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Anulowano misję dla %s', target.getName()), 'success')

    elseif command == 'completeMission' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end
        -- Wymusza ukończenie misji
        TriggerClientEvent('td_tracker:admin:forceCompleteMission', data.playerId)
        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Wymuszono ukończenie misji dla %s', target.getName()), 'success')

    elseif command == 'failMission' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end
        TriggerClientEvent('td_tracker:client:cancelMission', data.playerId)
        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Przegrano misję dla %s', target.getName()), 'success')

    elseif command == 'spawnNPC' then
        TriggerClientEvent('td_tracker:client:spawnNPC', source)
        TriggerClientEvent('td_tracker:admin:notification', source, 'NPC zespawnowany dla ciebie', 'success')

    elseif command == 'removeNPC' then
        -- Usuń NPC tylko dla admina
        TriggerEvent('td_tracker:server:removeNPC', source)
        TriggerClientEvent('td_tracker:admin:notification', source, 'NPC usunięty', 'success')

    elseif command == 'startMission' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end

        -- Wymuś start misji dla gracza
        local stage = data.value or 1
        TriggerEvent('td_tracker:server:startMission', data.playerId, stage)
        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Wystartowano misję Stage %d dla %s', stage, target.getName()), 'success')

    elseif command == 'respawnAllNPC' then
        -- Zrespawnuj NPC dla wszystkich graczy
        TriggerClientEvent('td_tracker:client:spawnNPC', -1)
        TriggerClientEvent('td_tracker:admin:notification', source, 'Wszystkie NPC zespawnowane dla wszystkich graczy', 'success')

    elseif command == 'reloadConfig' then
        -- Reload config from file
        TriggerClientEvent('td_tracker:admin:notification', source, 'Config przeładowany (wymaga restartu)', 'info')

    elseif command == 'clearLogs' then
        MySQL.query('DELETE FROM td_tracker_logs WHERE DATE(completed_at) < DATE_SUB(CURDATE(), INTERVAL 30 DAY)')
        TriggerClientEvent('td_tracker:admin:notification', source, 'Logi starsze niż 30 dni zostały wyczyszczone', 'success')

    elseif command == 'toggleDebug' then
        Config.Debug = not Config.Debug
        TriggerClientEvent('td_tracker:admin:notification', source, 'Debug: ' .. tostring(Config.Debug), 'info')
    end
end)

-- ============================================
-- MISSIONS
-- ============================================

RegisterNetEvent('td_tracker:admin:getMissions', function()
    local source = source
    if not IsAdmin(source) then return end

    -- Missions config jest dostępny globalnie w Config.Stages
    -- NUI ma już wartości, więc nie trzeba nic wysyłać
end)

RegisterNetEvent('td_tracker:admin:saveMissionConfig', function(data)
    local source = source
    if not IsAdmin(source) then return end

    -- Zapisz do MySQL
    exports.td_tracker:UpdateStageConfig(data.stage, {
        name = Config.Stages[data.stage].name,
        enabled = data.enabled,
        minReputation = data.minReputation,
        chanceToAorB = data.chanceToAorB,
        timeLimit = data.timeLimit
    })

    -- Zapisz także ustawienia do MySQL settings
    exports.td_tracker:UpdateSetting('mission_time_limit_stage_' .. data.stage, data.timeLimit, 'number')

    -- Aktualizuj lokalny config (dla kompatybilności)
    Config.Stages[data.stage].enabled = data.enabled
    Config.Stages[data.stage].minReputation = data.minReputation
    Config.Stages[data.stage].chanceToAorB = data.chanceToAorB
    Config.MissionTimeLimit[data.stage] = data.timeLimit

    TriggerClientEvent('td_tracker:admin:notification', source, 'Konfiguracja zapisana do MySQL!', 'success')
end)

-- ============================================
-- SETTINGS
-- ============================================

RegisterNetEvent('td_tracker:admin:saveSettings', function(settings)
    local source = source
    if not IsAdmin(source) then return end

    -- Zapisz wszystkie ustawienia do MySQL
    for key, value in pairs(settings) do
        local valueType = type(value)
        if valueType == 'boolean' then
            exports.td_tracker:UpdateSetting(key, value and '1' or '0', 'boolean')
            -- Aktualizuj także Config
            if Config[key] ~= nil then
                Config[key] = value
            end
        elseif valueType == 'number' then
            exports.td_tracker:UpdateSetting(key, tostring(value), 'number')
            if Config[key] ~= nil then
                Config[key] = value
            end
        elseif valueType == 'string' then
            exports.td_tracker:UpdateSetting(key, value, 'string')
            if Config[key] ~= nil then
                Config[key] = value
            end
        end
    end

    TriggerClientEvent('td_tracker:admin:notification', source, 'Ustawienia zapisane do MySQL!', 'success')
end)

RegisterNetEvent('td_tracker:admin:getSettings', function()
    local source = source
    if not IsAdmin(source) then return end

    -- Wyślij wszystkie edytowalne ustawienia z Config
    local settings = {
        Debug = Config.Debug,
        EnableAntiCheat = Config.EnableAntiCheat,
        MaxDistanceFromVehicle = Config.MaxDistanceFromVehicle,
        CheckInterval = Config.CheckInterval,
        RequireLockpickItem = Config.RequireLockpickItem,
        LockpickBreakChance = Config.LockpickBreakChance,
        AlarmDuration = Config.AlarmDuration,
        ChaseTime = Config.ChaseTime,
        DismantleTime = Config.DismantleTime,
        RequireDismantleMinigame = Config.RequireDismantleMinigame,
        -- NPCChase settings
        NPCChaseEnabled = Config.NPCChase.enabled,
        NPCMinPolice = Config.NPCChase.minPolicePlayersForNPCDisable,
        NPCInitialChasers = Config.NPCChase.initialChasers,
        NPCMaxChasers = Config.NPCChase.maxChasers,
        NPCDriveSpeed = Config.NPCChase.driveSpeed,
        NPCExitDistance = Config.NPCChase.exitVehicleDistance,
        NPCExitDelay = Config.NPCChase.exitVehicleDelay,
    }

    TriggerClientEvent('td_tracker:admin:updateSettings', source, settings)
end)

-- ============================================
-- LOCATIONS
-- ============================================

local function LoadConfigLocations()
    -- Tutaj musisz załadować odpowiedni plik configu lokacji
    return ConfigLocations
end

RegisterNetEvent('td_tracker:admin:getLocations', function(locationType)
    local source = source
    if not IsAdmin(source) then return end

    local locations = {}
    local configLocs = LoadConfigLocations()

    if locationType == 'stage1' then
        locations = configLocs.Stage1.searchAreas or {}
    elseif locationType == 'stage1-delivery' then
        locations = configLocs.Stage1.deliveryPoints or {}
    elseif locationType == 'stage2-npc' then
        locations = configLocs.Stage2.npcSpawns or {}
    elseif locationType == 'stage2-vehicle' then
        locations = configLocs.Stage2.vehicleSpawns or {}
    elseif locationType == 'stage2-hideout' then
        locations = configLocs.Stage2.hideouts or {}
    elseif locationType == 'stage3-npc' then
        locations = configLocs.Stage3.npcSpawns or {}
    elseif locationType == 'stage3-vehicle' then
        locations = configLocs.Stage3.vehicleSpawns or {}
    elseif locationType == 'stage3-bus' then
        locations = configLocs.Stage3.busSpawns or {}
    elseif locationType == 'stage3-sell' then
        locations = configLocs.Stage3.sellPoints or {}
    end

    TriggerClientEvent('td_tracker:admin:updateLocations', source, locations, locationType)
end)

-- Callback musi być osobnym eventem dla klienta
RegisterNetEvent('td_tracker:admin:requestLocationCoords', function(data)
    local source = source
    if not IsAdmin(source) then return end

    local configLocs = LoadConfigLocations()
    local locations = {}

    -- Pobierz odpowiednią lokację według typu
    if data.locationType == 'stage1' then
        locations = configLocs.Stage1.searchAreas or {}
    elseif data.locationType == 'stage1-delivery' then
        locations = configLocs.Stage1.deliveryPoints or {}
    elseif data.locationType == 'stage2-npc' then
        locations = configLocs.Stage2.npcSpawns or {}
    elseif data.locationType == 'stage2-vehicle' then
        locations = configLocs.Stage2.vehicleSpawns or {}
    elseif data.locationType == 'stage2-hideout' then
        locations = configLocs.Stage2.hideouts or {}
    elseif data.locationType == 'stage3-npc' then
        locations = configLocs.Stage3.npcSpawns or {}
    elseif data.locationType == 'stage3-vehicle' then
        locations = configLocs.Stage3.vehicleSpawns or {}
    elseif data.locationType == 'stage3-bus' then
        locations = configLocs.Stage3.busSpawns or {}
    elseif data.locationType == 'stage3-sell' then
        locations = configLocs.Stage3.sellPoints or {}
    end

    -- Wyślij koordynaty z powrotem do klienta
    if locations and locations[data.index + 1] then
        local loc = locations[data.index + 1]
        local coords = loc.center or loc
        TriggerClientEvent('td_tracker:admin:receiveLocationCoords', source, coords)
    else
        TriggerClientEvent('td_tracker:admin:notification', source, 'Nie znaleziono lokacji!', 'error')
    end
end)

RegisterNetEvent('td_tracker:admin:saveLocation', function(data)
    local source = source
    if not IsAdmin(source) then return end

    -- Tu możesz zapisać do pliku lub bazy
    -- Na razie tylko logowanie
    print(string.format('[TRACKER ADMIN] Location saved: %s [%s]', data.locationType, json.encode(data.coords)))

    TriggerClientEvent('td_tracker:admin:notification', source, 'Lokacja zapisana! (wymaga ręcznej edycji pliku config)', 'info')
end)

RegisterNetEvent('td_tracker:admin:deleteLocation', function(data)
    local source = source
    if not IsAdmin(source) then return end

    print(string.format('[TRACKER ADMIN] Location deleted: %s #%d', data.locationType, data.index))
    TriggerClientEvent('td_tracker:admin:notification', source, 'Lokacja usunięta! (wymaga ręcznej edycji pliku config)', 'info')
end)

RegisterNetEvent('td_tracker:admin:teleportToLocation', function(data)
    local source = source
    if not IsAdmin(source) then return end

    local configLocs = LoadConfigLocations()
    local locations = {}

    -- Pobierz odpowiednią lokację
    if data.locationType:find('stage1') then
        if data.locationType == 'stage1-delivery' then
            locations = configLocs.Stage1.deliveryPoints
        else
            locations = configLocs.Stage1.searchAreas
        end
    elseif data.locationType:find('stage2') then
        if data.locationType == 'stage2-npc' then
            locations = configLocs.Stage2.npcSpawns
        elseif data.locationType == 'stage2-vehicle' then
            locations = configLocs.Stage2.vehicleSpawns
        elseif data.locationType == 'stage2-hideout' then
            locations = configLocs.Stage2.hideouts
        end
    elseif data.locationType:find('stage3') then
        if data.locationType == 'stage3-npc' then
            locations = configLocs.Stage3.npcSpawns
        elseif data.locationType == 'stage3-vehicle' then
            locations = configLocs.Stage3.vehicleSpawns
        elseif data.locationType == 'stage3-bus' then
            locations = configLocs.Stage3.busSpawns
        elseif data.locationType == 'stage3-sell' then
            locations = configLocs.Stage3.sellPoints
        end
    end

    if locations and locations[data.index + 1] then
        local loc = locations[data.index + 1]
        local coords = loc.center or loc
        SetEntityCoords(GetPlayerPed(source), coords.x, coords.y, coords.z, false, false, false, false)
        TriggerClientEvent('td_tracker:admin:notification', source, 'Teleportowano!', 'success')
    end
end)

-- ============================================
-- PLAYER MANAGEMENT
-- ============================================

RegisterNetEvent('td_tracker:admin:viewPlayer', function(playerId)
    local source = source
    if not IsAdmin(source) then return end

    local target = ESX.GetPlayerFromId(playerId)
    if not target then
        TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
        return
    end

    local stats = MySQL.query.await('SELECT * FROM td_tracker_reputation WHERE identifier = ?', {
        target.identifier
    })

    if stats and stats[1] then
        TriggerClientEvent('td_tracker:admin:notification', source,
            string.format('%s | Rep: %d | Completed: %d | Failed: %d',
                target.getName(), stats[1].reputation, stats[1].completed_missions, stats[1].failed_missions
            ), 'info')
    end
end)

RegisterNetEvent('td_tracker:admin:teleportToPlayer', function(playerId)
    local source = source
    if not IsAdmin(source) then return end

    local targetPed = GetPlayerPed(playerId)
    if targetPed == 0 then
        TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
        return
    end

    local coords = GetEntityCoords(targetPed)
    SetEntityCoords(GetPlayerPed(source), coords.x, coords.y, coords.z, false, false, false, false)
    TriggerClientEvent('td_tracker:admin:notification', source, 'Teleportowano!', 'success')
end)

RegisterNetEvent('td_tracker:admin:resetPlayer', function(playerId)
    local source = source
    if not IsAdmin(source) then return end

    local target = ESX.GetPlayerFromId(playerId)
    if not target then
        TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
        return
    end

    MySQL.query('UPDATE td_tracker_reputation SET reputation = 0, completed_missions = 0, failed_missions = 0 WHERE identifier = ?', {
        target.identifier
    })

    TriggerClientEvent('td_tracker:admin:notification', source, string.format('Zresetowano gracza: %s', target.getName()), 'success')
end)

-- ============================================
-- NPC MANAGEMENT
-- ============================================

RegisterNetEvent('td_tracker:server:removeNPC', function(targetSource)
    local source = source
    if not IsAdmin(source) then return end

    -- Wyślij event do gracza aby usunął NPC
    if targetSource then
        TriggerClientEvent('td_tracker:client:removeNPC', targetSource)
    else
        -- Usuń dla wszystkich
        TriggerClientEvent('td_tracker:client:removeNPC', -1)
    end
end)

print('^2[TD TRACKER]^0 Admin panel server loaded')
