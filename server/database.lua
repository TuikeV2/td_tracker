-- ============================================
-- TD TRACKER - DATABASE MANAGER
-- Zarządza konfiguracją opartą na MySQL
-- ============================================

local ESX = exports['es_extended']:getSharedObject()

-- Cache konfiguracji
local ConfigCache = {
    Stages = {},
    Vehicles = {},
    Rewards = {},
    Penalties = {},
    NPCLocations = {},
    VehicleLocations = {},
    SearchAreas = {},
    Settings = {},
    LastUpdate = 0
}

local CACHE_DURATION = 300000 -- 5 minut

-- ============================================
-- ŁADOWANIE KONFIGURACJI
-- ============================================

function LoadDatabaseConfig()
    print('^3[TD TRACKER DB]^0 Loading configuration from database...')

    -- Załaduj etapy misji
    LoadStages()

    -- Załaduj pojazdy
    LoadVehicles()

    -- Załaduj nagrody
    LoadRewards()

    -- Załaduj kary
    LoadPenalties()

    -- Załaduj lokacje NPC
    LoadNPCLocations()

    -- Załaduj lokacje pojazdów
    LoadVehicleLocations()

    -- Załaduj obszary wyszukiwania
    LoadSearchAreas()

    -- Załaduj ustawienia ogólne
    LoadSettings()

    ConfigCache.LastUpdate = GetGameTimer()
    print('^2[TD TRACKER DB]^0 Configuration loaded successfully!')

    return ConfigCache
end

function LoadStages()
    local result = MySQL.query.await('SELECT * FROM td_tracker_stages WHERE enabled = 1 ORDER BY stage ASC')

    if result then
        for _, stage in ipairs(result) do
            ConfigCache.Stages[stage.stage] = {
                name = stage.name,
                enabled = stage.enabled == 1,
                minReputation = stage.min_reputation,
                chanceToAorB = stage.chance_to_aorb,
                timeLimit = stage.time_limit
            }
        end
        print(string.format('^2[TD TRACKER DB]^0 Loaded %d stages', #result))
    end
end

function LoadVehicles()
    local result = MySQL.query.await('SELECT * FROM td_tracker_vehicle_pools WHERE enabled = 1')

    if result then
        for _, veh in ipairs(result) do
            if not ConfigCache.Vehicles[veh.stage] then
                ConfigCache.Vehicles[veh.stage] = {A = {}, B = {}, C = {}}
            end

            table.insert(ConfigCache.Vehicles[veh.stage][veh.tier], {
                model = veh.model,
                chance = veh.spawn_chance
            })
        end
        print(string.format('^2[TD TRACKER DB]^0 Loaded %d vehicles', #result))
    end
end

function LoadRewards()
    local result = MySQL.query.await('SELECT * FROM td_tracker_rewards')

    if result then
        for _, reward in ipairs(result) do
            if not ConfigCache.Rewards[reward.stage] then
                ConfigCache.Rewards[reward.stage] = {}
            end

            ConfigCache.Rewards[reward.stage][reward.tier] = {
                minMoney = reward.min_money,
                maxMoney = reward.max_money,
                minReputation = reward.min_reputation,
                maxReputation = reward.max_reputation
            }
        end
        print(string.format('^2[TD TRACKER DB]^0 Loaded %d rewards', #result))
    end
end

function LoadPenalties()
    local result = MySQL.query.await('SELECT * FROM td_tracker_penalties')

    if result then
        for _, penalty in ipairs(result) do
            ConfigCache.Penalties[penalty.stage] = penalty.reputation_loss
        end
        print(string.format('^2[TD TRACKER DB]^0 Loaded %d penalties', #result))
    end
end

function LoadNPCLocations()
    local result = MySQL.query.await('SELECT * FROM td_tracker_npc_locations WHERE enabled = 1')

    if result then
        ConfigCache.NPCLocations = {}
        for _, npc in ipairs(result) do
            if not ConfigCache.NPCLocations[npc.location_type] then
                ConfigCache.NPCLocations[npc.location_type] = {}
            end

            table.insert(ConfigCache.NPCLocations[npc.location_type], {
                id = npc.id,
                model = npc.model,
                coords = vector3(npc.x, npc.y, npc.z),
                heading = npc.heading,
                animation = npc.animation_dict and {
                    dict = npc.animation_dict,
                    name = npc.animation_name
                } or nil
            })
        end
        print(string.format('^2[TD TRACKER DB]^0 Loaded %d NPC locations', #result))
    end
end

function LoadVehicleLocations()
    local result = MySQL.query.await('SELECT * FROM td_tracker_vehicle_locations WHERE enabled = 1 ORDER BY priority DESC')

    if result then
        ConfigCache.VehicleLocations = {}
        for _, loc in ipairs(result) do
            local key = 'stage' .. loc.stage .. '_' .. loc.location_type
            if not ConfigCache.VehicleLocations[key] then
                ConfigCache.VehicleLocations[key] = {}
            end

            table.insert(ConfigCache.VehicleLocations[key], {
                id = loc.id,
                x = loc.x,
                y = loc.y,
                z = loc.z,
                w = loc.heading,
                model = loc.vehicle_model,
                priority = loc.priority
            })
        end
        print(string.format('^2[TD TRACKER DB]^0 Loaded %d vehicle locations', #result))
    end
end

function LoadSearchAreas()
    local result = MySQL.query.await('SELECT * FROM td_tracker_search_areas WHERE enabled = 1')

    if result then
        ConfigCache.SearchAreas = {}
        for _, area in ipairs(result) do
            table.insert(ConfigCache.SearchAreas, {
                id = area.id,
                name = area.name,
                center = vector3(area.center_x, area.center_y, area.center_z),
                radius = area.radius
            })
        end
        print(string.format('^2[TD TRACKER DB]^0 Loaded %d search areas', #result))
    end
end

function LoadSettings()
    local result = MySQL.query.await('SELECT * FROM td_tracker_config')

    if result then
        for _, setting in ipairs(result) do
            local value = setting.config_value

            -- Konwersja typów
            if setting.config_type == 'number' then
                value = tonumber(value)
            elseif setting.config_type == 'boolean' then
                value = value == '1' or value == 'true'
            elseif setting.config_type == 'json' then
                value = json.decode(value)
            end

            ConfigCache.Settings[setting.config_key] = value
        end
        print(string.format('^2[TD TRACKER DB]^0 Loaded %d settings', #result))
    end
end

-- ============================================
-- FUNKCJE POBIERANIA DANYCH
-- ============================================

function GetStageConfig(stage)
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    return ConfigCache.Stages[stage]
end

function GetVehiclePool(stage, tier)
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    return ConfigCache.Vehicles[stage] and ConfigCache.Vehicles[stage][tier] or {}
end

function GetReward(stage, tier)
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    return ConfigCache.Rewards[stage] and ConfigCache.Rewards[stage][tier]
end

function GetPenalty(stage)
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    return ConfigCache.Penalties[stage] or 20
end

function GetNPCLocations(locationType)
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    return ConfigCache.NPCLocations[locationType] or {}
end

function GetVehicleLocations(stage, locationType)
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    local key = 'stage' .. stage .. '_' .. locationType
    return ConfigCache.VehicleLocations[key] or {}
end

function GetSearchAreas()
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    return ConfigCache.SearchAreas
end

function GetSetting(key, default)
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    return ConfigCache.Settings[key] or default
end

function GetAllStages()
    if NeedsCacheRefresh() then
        LoadDatabaseConfig()
    end
    return ConfigCache.Stages
end

function NeedsCacheRefresh()
    return (GetGameTimer() - ConfigCache.LastUpdate) > CACHE_DURATION
end

function ForceRefreshCache()
    LoadDatabaseConfig()
end

-- ============================================
-- FUNKCJE ZAPISU DANYCH
-- ============================================

function UpdateStageConfig(stage, data)
    MySQL.query([[
        UPDATE td_tracker_stages
        SET name = ?, enabled = ?, min_reputation = ?, chance_to_aorb = ?, time_limit = ?
        WHERE stage = ?
    ]], {
        data.name,
        data.enabled and 1 or 0,
        data.minReputation,
        data.chanceToAorB,
        data.timeLimit,
        stage
    })

    ForceRefreshCache()
    print(string.format('^2[TD TRACKER DB]^0 Updated stage %d configuration', stage))
end

function AddNPCLocation(locationType, data)
    MySQL.insert([[
        INSERT INTO td_tracker_npc_locations
        (location_type, model, x, y, z, heading, animation_dict, animation_name, enabled)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
    ]], {
        locationType,
        data.model,
        data.coords.x,
        data.coords.y,
        data.coords.z,
        data.heading or 0.0,
        data.animation and data.animation.dict or nil,
        data.animation and data.animation.name or nil
    })

    ForceRefreshCache()
    print(string.format('^2[TD TRACKER DB]^0 Added NPC location: %s', locationType))
end

function UpdateNPCLocation(id, data)
    MySQL.query([[
        UPDATE td_tracker_npc_locations
        SET x = ?, y = ?, z = ?, heading = ?
        WHERE id = ?
    ]], {
        data.coords.x,
        data.coords.y,
        data.coords.z,
        data.heading or 0.0,
        id
    })

    ForceRefreshCache()
    print(string.format('^2[TD TRACKER DB]^0 Updated NPC location ID: %d', id))
end

function DeleteNPCLocation(id)
    MySQL.query('UPDATE td_tracker_npc_locations SET enabled = 0 WHERE id = ?', {id})
    ForceRefreshCache()
    print(string.format('^2[TD TRACKER DB]^0 Deleted NPC location ID: %d', id))
end

function AddVehicleLocation(stage, locationType, data)
    MySQL.insert([[
        INSERT INTO td_tracker_vehicle_locations
        (stage, location_type, x, y, z, heading, vehicle_model, enabled, priority)
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0)
    ]], {
        stage,
        locationType,
        data.x,
        data.y,
        data.z,
        data.w or 0.0,
        data.model or nil
    })

    ForceRefreshCache()
    print(string.format('^2[TD TRACKER DB]^0 Added vehicle location: Stage %d - %s', stage, locationType))
end

function UpdateVehicleLocation(id, data)
    MySQL.query([[
        UPDATE td_tracker_vehicle_locations
        SET x = ?, y = ?, z = ?, heading = ?
        WHERE id = ?
    ]], {
        data.x,
        data.y,
        data.z,
        data.w or 0.0,
        id
    })

    ForceRefreshCache()
    print(string.format('^2[TD TRACKER DB]^0 Updated vehicle location ID: %d', id))
end

function DeleteVehicleLocation(id)
    MySQL.query('UPDATE td_tracker_vehicle_locations SET enabled = 0 WHERE id = ?', {id})
    ForceRefreshCache()
    print(string.format('^2[TD TRACKER DB]^0 Deleted vehicle location ID: %d', id))
end

function UpdateSetting(key, value, valueType)
    MySQL.query([[
        UPDATE td_tracker_config
        SET config_value = ?, config_type = ?
        WHERE config_key = ?
    ]], {
        tostring(value),
        valueType or 'string',
        key
    })

    ForceRefreshCache()
    print(string.format('^2[TD TRACKER DB]^0 Updated setting: %s = %s', key, tostring(value)))
end

-- ============================================
-- EKSPORTY
-- ============================================

exports('GetStageConfig', GetStageConfig)
exports('GetVehiclePool', GetVehiclePool)
exports('GetReward', GetReward)
exports('GetPenalty', GetPenalty)
exports('GetNPCLocations', GetNPCLocations)
exports('GetVehicleLocations', GetVehicleLocations)
exports('GetSearchAreas', GetSearchAreas)
exports('GetSetting', GetSetting)
exports('GetAllStages', GetAllStages)
exports('ForceRefreshCache', ForceRefreshCache)
exports('UpdateStageConfig', UpdateStageConfig)
exports('UpdateSetting', UpdateSetting)

-- ============================================
-- INICJALIZACJA
-- ============================================

CreateThread(function()
    Wait(1000) -- Poczekaj na załadowanie ESX i MySQL
    LoadDatabaseConfig()
end)

-- Automatyczne odświeżanie co 5 minut
CreateThread(function()
    while true do
        Wait(CACHE_DURATION)
        LoadDatabaseConfig()
    end
end)

print('^2[TD TRACKER]^0 Database manager loaded')
