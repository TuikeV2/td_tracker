-- ============================================
-- TD TRACKER - ADMIN PANEL SERVER (FIXED)
-- Pełna integracja z MySQL
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

        MySQL.query([[
            INSERT INTO td_tracker_reputation (identifier, reputation, completed_missions, failed_missions)
            VALUES (?, ?, 0, 0)
            ON DUPLICATE KEY UPDATE reputation = ?
        ]], {
            target.identifier, data.value, data.value
        })

        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Ustawiono reputację %d dla %s', data.value, target.getName()), 'success')
        Wait(500)
        TriggerClientEvent('td_tracker:admin:updatePlayers', -1, GetAllPlayers())

    elseif command == 'addRep' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end

        MySQL.query([[
            INSERT INTO td_tracker_reputation (identifier, reputation, completed_missions, failed_missions)
            VALUES (?, ?, 0, 0)
            ON DUPLICATE KEY UPDATE reputation = reputation + ?
        ]], {
            target.identifier, data.value, data.value
        })

        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Dodano %d reputacji dla %s', data.value, target.getName()), 'success')
        Wait(500)
        TriggerClientEvent('td_tracker:admin:updatePlayers', -1, GetAllPlayers())

    elseif command == 'removeRep' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end

        MySQL.query([[
            INSERT INTO td_tracker_reputation (identifier, reputation, completed_missions, failed_missions)
            VALUES (?, 0, 0, 0)
            ON DUPLICATE KEY UPDATE reputation = GREATEST(reputation - ?, 0)
        ]], {
            target.identifier, data.value
        })

        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Odjęto %d reputacji dla %s', data.value, target.getName()), 'success')
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
        TriggerEvent('td_tracker:server:removeNPC', source)
        TriggerClientEvent('td_tracker:admin:notification', source, 'NPC usunięty', 'success')

    elseif command == 'startMission' then
        local target = ESX.GetPlayerFromId(data.playerId)
        if not target then
            TriggerClientEvent('td_tracker:admin:notification', source, 'Gracz nie znaleziony!', 'error')
            return
        end

        local stage = data.value or 1
        TriggerEvent('td_tracker:server:startMission', data.playerId, stage)
        TriggerClientEvent('td_tracker:admin:notification', source, string.format('Wystartowano misję Stage %d dla %s', stage, target.getName()), 'success')

    elseif command == 'respawnAllNPC' then
        TriggerClientEvent('td_tracker:client:spawnNPC', -1)
        TriggerClientEvent('td_tracker:admin:notification', source, 'Wszystkie NPC zespawnowane dla wszystkich graczy', 'success')

    elseif command == 'reloadConfig' then
        exports.td_tracker:ForceRefreshCache()
        TriggerClientEvent('td_tracker:admin:notification', source, 'Config przeładowany z MySQL', 'success')

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
end)

RegisterNetEvent('td_tracker:admin:saveMissionConfig', function(data)
    local source = source
    if not IsAdmin(source) then return end

    exports.td_tracker:UpdateStageConfig(data.stage, {
        name = Config.Stages[data.stage].name,
        enabled = data.enabled,
        minReputation = data.minReputation,
        chanceToAorB = data.chanceToAorB,
        timeLimit = data.timeLimit
    })

    exports.td_tracker:UpdateSetting('mission_time_limit_stage_' .. data.stage, data.timeLimit, 'number')

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

    for key, value in pairs(settings) do
        local valueType = type(value)
        if valueType == 'boolean' then
            exports.td_tracker:UpdateSetting(key, value and '1' or '0', 'boolean')
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
-- LOCATIONS (MYSQL)
-- ============================================

RegisterNetEvent('td_tracker:admin:getLocations', function(locationType)
    local source = source
    if not IsAdmin(source) then return end

    local locations = {}

    -- Mapowanie typów lokacji na typy w bazie danych
    local typeMapping = {
        ['stage1'] = {table = 'search_areas'},
        ['stage1-delivery'] = {table = 'vehicle_locations', stage = 1, location_type = 'delivery'},
        ['stage2-npc'] = {table = 'npc_locations', location_type = 'stage2_npc'},
        ['stage2-vehicle'] = {table = 'vehicle_locations', stage = 2, location_type = 'spawn'},
        ['stage2-hideout'] = {table = 'vehicle_locations', stage = 2, location_type = 'hideout'},
        ['stage3-npc'] = {table = 'npc_locations', location_type = 'stage3_npc'},
        ['stage3-vehicle'] = {table = 'vehicle_locations', stage = 3, location_type = 'spawn'},
        ['stage3-bus'] = {table = 'vehicle_locations', stage = 3, location_type = 'bus_spawn'},
        ['stage3-sell'] = {table = 'vehicle_locations', stage = 3, location_type = 'sell_point'},
    }

    local mapping = typeMapping[locationType]
    if not mapping then
        TriggerClientEvent('td_tracker:admin:updateLocations', source, {}, locationType)
        return
    end

    if mapping.table == 'search_areas' then
        -- Pobierz obszary wyszukiwania
        local result = MySQL.query.await('SELECT * FROM td_tracker_search_areas WHERE enabled = 1')
        for _, row in ipairs(result or {}) do
            table.insert(locations, {
                x = row.center_x,
                y = row.center_y,
                z = row.center_z,
                radius = row.radius,
                name = row.name
            })
        end

    elseif mapping.table == 'vehicle_locations' then
        -- Pobierz lokacje pojazdów
        local result = MySQL.query.await('SELECT * FROM td_tracker_vehicle_locations WHERE stage = ? AND location_type = ? AND enabled = 1', {
            mapping.stage, mapping.location_type
        })
        for _, row in ipairs(result or {}) do
            table.insert(locations, {
                x = row.x,
                y = row.y,
                z = row.z,
                w = row.heading,
                model = row.vehicle_model
            })
        end

    elseif mapping.table == 'npc_locations' then
        -- Pobierz lokacje NPC
        local result = MySQL.query.await('SELECT * FROM td_tracker_npc_locations WHERE location_type = ? AND enabled = 1', {
            mapping.location_type
        })
        for _, row in ipairs(result or {}) do
            table.insert(locations, {
                x = row.x,
                y = row.y,
                z = row.z,
                w = row.heading,
                model = row.model
            })
        end
    end

    TriggerClientEvent('td_tracker:admin:updateLocations', source, locations, locationType)
end)

RegisterNetEvent('td_tracker:admin:requestLocationCoords', function(data)
    local source = source
    if not IsAdmin(source) then return end

    -- TO-DO: Pobierz koordynaty z bazy danych na podstawie data.locationType i data.index
    -- Na razie zwróć pustą odpowiedź
    TriggerClientEvent('td_tracker:admin:notification', source, 'Edycja lokacji nie jest jeszcze w pełni zaimplementowana', 'warning')
end)

RegisterNetEvent('td_tracker:admin:saveLocation', function(data)
    local source = source
    if not IsAdmin(source) then return end

    -- Mapowanie typów lokacji
    local typeMapping = {
        ['stage1'] = {table = 'search_areas'},
        ['stage1-delivery'] = {table = 'vehicle_locations', stage = 1, location_type = 'delivery'},
        ['stage2-npc'] = {table = 'npc_locations', location_type = 'stage2_npc'},
        ['stage2-vehicle'] = {table = 'vehicle_locations', stage = 2, location_type = 'spawn'},
        ['stage2-hideout'] = {table = 'vehicle_locations', stage = 2, location_type = 'hideout'},
        ['stage3-npc'] = {table = 'npc_locations', location_type = 'stage3_npc'},
        ['stage3-vehicle'] = {table = 'vehicle_locations', stage = 3, location_type = 'spawn'},
        ['stage3-bus'] = {table = 'vehicle_locations', stage = 3, location_type = 'bus_spawn'},
        ['stage3-sell'] = {table = 'vehicle_locations', stage = 3, location_type = 'sell_point'},
        ['npc_quest_giver'] = {table = 'npc_locations', location_type = 'quest_giver'}
    }

    local mapping = typeMapping[data.locationType]
    if not mapping then
        TriggerClientEvent('td_tracker:admin:notification', source, 'Nieznany typ lokacji!', 'error')
        return
    end

    if mapping.table == 'vehicle_locations' then
        -- Zapisz lokację pojazdu
        MySQL.insert('INSERT INTO td_tracker_vehicle_locations (stage, location_type, x, y, z, heading, enabled) VALUES (?, ?, ?, ?, ?, ?, 1)', {
            mapping.stage,
            mapping.location_type,
            data.coords.x,
            data.coords.y,
            data.coords.z,
            data.coords.w or 0.0
        })

    elseif mapping.table == 'npc_locations' then
        -- Zapisz lokację NPC
        MySQL.insert('INSERT INTO td_tracker_npc_locations (location_type, model, x, y, z, heading, enabled) VALUES (?, ?, ?, ?, ?, ?, 1)', {
            mapping.location_type,
            'a_m_m_business_01', -- Domyślny model
            data.coords.x,
            data.coords.y,
            data.coords.z,
            data.coords.w or 0.0
        })

    elseif mapping.table == 'search_areas' then
        -- Zapisz obszar wyszukiwania
        MySQL.insert('INSERT INTO td_tracker_search_areas (name, center_x, center_y, center_z, radius, enabled) VALUES (?, ?, ?, ?, ?, 1)', {
            'Nowy obszar',
            data.coords.x,
            data.coords.y,
            data.coords.z,
            200.0 -- Domyślny promień
        })
    end

    -- Odśwież cache
    exports.td_tracker:ForceRefreshCache()

    TriggerClientEvent('td_tracker:admin:notification', source, 'Lokacja zapisana do MySQL!', 'success')
    print(string.format('[TRACKER ADMIN] Location saved to MySQL: %s [%s]', data.locationType, json.encode(data.coords)))
end)

RegisterNetEvent('td_tracker:admin:deleteLocation', function(data)
    local source = source
    if not IsAdmin(source) then return end

    -- TO-DO: Usuń lokację z bazy danych
    TriggerClientEvent('td_tracker:admin:notification', source, 'Usuwanie lokacji nie jest jeszcze w pełni zaimplementowane', 'warning')
end)

RegisterNetEvent('td_tracker:admin:teleportToLocation', function(data)
    local source = source
    if not IsAdmin(source) then return end

    -- TO-DO: Teleportuj do lokacji z bazy danych
    TriggerClientEvent('td_tracker:admin:notification', source, 'Teleportacja nie jest jeszcze w pełni zaimplementowana', 'warning')
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
-- NPC MANAGEMENT (MYSQL)
-- ============================================

RegisterNetEvent('td_tracker:admin:getNPCLocations', function()
    local source = source
    if not IsAdmin(source) then return end

    local result = MySQL.query.await('SELECT * FROM td_tracker_npc_locations WHERE location_type = "quest_giver"')
    local locations = {}

    for _, row in ipairs(result or {}) do
        table.insert(locations, {
            id = row.id,
            model = row.model,
            coords = {x = row.x, y = row.y, z = row.z},
            heading = row.heading,
            animation = row.animation_dict and {
                dict = row.animation_dict,
                name = row.animation_name
            } or nil,
            enabled = row.enabled == 1
        })
    end

    TriggerClientEvent('td_tracker:admin:updateNPCLocations', source, {locations = locations})
end)

RegisterNetEvent('td_tracker:admin:toggleNPC', function(data)
    local source = source
    if not IsAdmin(source) then return end

    MySQL.query('UPDATE td_tracker_npc_locations SET enabled = NOT enabled WHERE id = ?', {data.npcId})
    exports.td_tracker:ForceRefreshCache()

    TriggerClientEvent('td_tracker:admin:notification', source, 'Status NPC zmieniony!', 'success')
end)

RegisterNetEvent('td_tracker:admin:deleteNPC', function(data)
    local source = source
    if not IsAdmin(source) then return end

    MySQL.query('DELETE FROM td_tracker_npc_locations WHERE id = ?', {data.npcId})
    exports.td_tracker:ForceRefreshCache()

    TriggerClientEvent('td_tracker:admin:notification', source, 'NPC usunięty z bazy danych!', 'success')
end)

RegisterNetEvent('td_tracker:server:removeNPC', function(targetSource)
    local source = source
    if not IsAdmin(source) then return end

    if targetSource then
        TriggerClientEvent('td_tracker:client:removeNPC', targetSource)
    else
        TriggerClientEvent('td_tracker:client:removeNPC', -1)
    end
end)

print('^2[TD TRACKER]^0 Admin panel server loaded (MySQL integrated)')