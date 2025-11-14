-- ============================================
-- TD TRACKER - MIGRATION HELPER
-- Migruje istniejący config.lua do MySQL
-- UŻYCIE: Uruchom komendę `/tracker migrate` jako admin
-- ============================================

local ESX = exports['es_extended']:getSharedObject()

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

RegisterCommand('tracker', function(source, args)
    if args[1] == 'migrate' then
        if not IsAdmin(source) then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"TD Tracker", "Nie masz uprawnień!"}
            })
            return
        end

        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 215, 0},
            multiline = true,
            args = {"TD Tracker", "Rozpoczynam migrację config.lua do MySQL..."}
        })

        -- Migruj etapy
        for stage, data in pairs(Config.Stages) do
            MySQL.query([[
                INSERT INTO td_tracker_stages (stage, name, enabled, min_reputation, chance_to_aorb, time_limit)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    enabled = VALUES(enabled),
                    min_reputation = VALUES(min_reputation),
                    chance_to_aorb = VALUES(chance_to_aorb),
                    time_limit = VALUES(time_limit)
            ]], {
                stage,
                data.name,
                data.enabled and 1 or 0,
                data.minReputation,
                data.chanceToAorB,
                Config.MissionTimeLimit[stage] or 600000
            })
        end

        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            args = {"TD Tracker", string.format("✓ Zmigrowano %d etapów", #Config.Stages)}
        })

        -- Migruj pojazdy (jeśli są w ConfigVehicles)
        if ConfigVehicles then
            local count = 0
            for stage, tiers in pairs(ConfigVehicles) do
                for tier, vehicles in pairs(tiers) do
                    for _, model in ipairs(vehicles) do
                        MySQL.insert([[
                            INSERT INTO td_tracker_vehicle_pools (stage, tier, model, spawn_chance, enabled)
                            VALUES (?, ?, ?, 100, 1)
                            ON DUPLICATE KEY UPDATE
                                spawn_chance = VALUES(spawn_chance)
                        ]], {
                            stage,
                            tier,
                            model
                        })
                        count = count + 1
                    end
                end
            end

            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                args = {"TD Tracker", string.format("✓ Zmigrowano %d pojazdów", count)}
            })
        end

        -- Migruj nagrody
        if ConfigRewards then
            local count = 0
            for stage, tiers in pairs(ConfigRewards) do
                if type(tiers) == 'table' then
                    for tier, reward in pairs(tiers) do
                        if type(reward) == 'table' then
                            MySQL.query([[
                                INSERT INTO td_tracker_rewards (stage, tier, min_money, max_money, min_reputation, max_reputation)
                                VALUES (?, ?, ?, ?, ?, ?)
                                ON DUPLICATE KEY UPDATE
                                    min_money = VALUES(min_money),
                                    max_money = VALUES(max_money),
                                    min_reputation = VALUES(min_reputation),
                                    max_reputation = VALUES(max_reputation)
                            ]], {
                                stage,
                                tier,
                                reward.minMoney or 0,
                                reward.maxMoney or 0,
                                reward.minReputation or 0,
                                reward.maxReputation or 0
                            })
                            count = count + 1
                        end
                    end
                end
            end

            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                args = {"TD Tracker", string.format("✓ Zmigrowano %d nagród", count)}
            })
        end

        -- Migruj kary
        if ConfigRewards and ConfigRewards.FailurePenalty then
            for stage, penalty in pairs(ConfigRewards.FailurePenalty) do
                MySQL.query([[
                    INSERT INTO td_tracker_penalties (stage, reputation_loss)
                    VALUES (?, ?)
                    ON DUPLICATE KEY UPDATE
                        reputation_loss = VALUES(reputation_loss)
                ]], {
                    stage,
                    penalty
                })
            end

            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                args = {"TD Tracker", "✓ Zmigrowano kary"}
            })
        end

        -- Migruj lokacje NPC (quest giver)
        if ConfigMissions and ConfigMissions.NPCLocations then
            for _, npc in ipairs(ConfigMissions.NPCLocations) do
                MySQL.insert([[
                    INSERT INTO td_tracker_npc_locations
                    (location_type, model, x, y, z, heading, animation_dict, animation_name, enabled)
                    VALUES ('quest_giver', ?, ?, ?, ?, ?, ?, ?, 1)
                ]], {
                    npc.model,
                    npc.coords.x,
                    npc.coords.y,
                    npc.coords.z,
                    npc.heading or 0.0,
                    npc.animation and npc.animation.dict or nil,
                    npc.animation and npc.animation.name or nil
                })
            end

            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                args = {"TD Tracker", string.format("✓ Zmigrowano %d lokacji NPC", #ConfigMissions.NPCLocations)}
            })
        end

        -- Migruj lokacje Stage 1
        if ConfigLocations and ConfigLocations.Stage1 then
            -- Delivery points
            if ConfigLocations.Stage1.deliveryPoints then
                for _, loc in ipairs(ConfigLocations.Stage1.deliveryPoints) do
                    MySQL.insert([[
                        INSERT INTO td_tracker_vehicle_locations
                        (stage, location_type, x, y, z, heading, enabled)
                        VALUES (1, 'delivery', ?, ?, ?, 0.0, 1)
                    ]], {
                        loc.x,
                        loc.y,
                        loc.z
                    })
                end

                TriggerClientEvent('chat:addMessage', source, {
                    color = {0, 255, 0},
                    args = {"TD Tracker", string.format("✓ Zmigrowano %d punktów dostawy (Stage 1)", #ConfigLocations.Stage1.deliveryPoints)}
                })
            end

            -- Search areas
            if ConfigLocations.Stage1.searchAreas then
                for _, area in ipairs(ConfigLocations.Stage1.searchAreas) do
                    MySQL.insert([[
                        INSERT INTO td_tracker_search_areas
                        (name, center_x, center_y, center_z, radius, enabled)
                        VALUES (?, ?, ?, ?, ?, 1)
                    ]], {
                        area.name or 'Area',
                        area.center.x,
                        area.center.y,
                        area.center.z,
                        area.radius or 200.0
                    })
                end

                TriggerClientEvent('chat:addMessage', source, {
                    color = {0, 255, 0},
                    args = {"TD Tracker", string.format("✓ Zmigrowano %d obszarów wyszukiwania", #ConfigLocations.Stage1.searchAreas)}
                })
            end
        end

        -- Migruj ustawienia ogólne
        local settings = {
            {key = 'enable_anticheat', value = Config.EnableAntiCheat, type = 'boolean'},
            {key = 'max_distance_from_vehicle', value = Config.MaxDistanceFromVehicle, type = 'number'},
            {key = 'check_interval', value = Config.CheckInterval, type = 'number'},
            {key = 'require_lockpick_item', value = Config.RequireLockpickItem, type = 'boolean'},
            {key = 'lockpick_break_chance', value = Config.LockpickBreakChance, type = 'number'},
            {key = 'alarm_duration', value = Config.AlarmDuration, type = 'number'},
            {key = 'chase_time', value = Config.ChaseTime, type = 'number'},
            {key = 'dismantle_time', value = Config.DismantleTime, type = 'number'},
            {key = 'require_dismantle_minigame', value = Config.RequireDismantleMinigame, type = 'boolean'},
            {key = 'debug_mode', value = Config.Debug, type = 'boolean'},
        }

        if Config.NPCChase then
            table.insert(settings, {key = 'npc_chase_enabled', value = Config.NPCChase.enabled, type = 'boolean'})
            table.insert(settings, {key = 'min_police_for_npc_disable', value = Config.NPCChase.minPolicePlayersForNPCDisable, type = 'number'})
            table.insert(settings, {key = 'npc_initial_chasers', value = Config.NPCChase.initialChasers, type = 'number'})
            table.insert(settings, {key = 'npc_max_chasers', value = Config.NPCChase.maxChasers, type = 'number'})
            table.insert(settings, {key = 'npc_drive_speed', value = Config.NPCChase.driveSpeed, type = 'number'})
            table.insert(settings, {key = 'npc_exit_distance', value = Config.NPCChase.exitVehicleDistance, type = 'number'})
            table.insert(settings, {key = 'npc_exit_delay', value = Config.NPCChase.exitVehicleDelay, type = 'number'})
        end

        for _, setting in ipairs(settings) do
            if setting.value ~= nil then
                local valueStr = tostring(setting.value)
                if setting.type == 'boolean' then
                    valueStr = setting.value and '1' or '0'
                end

                MySQL.query([[
                    INSERT INTO td_tracker_config (config_key, config_value, config_type)
                    VALUES (?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                        config_value = VALUES(config_value),
                        config_type = VALUES(config_type)
                ]], {
                    setting.key,
                    valueStr,
                    setting.type
                })
            end
        end

        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            args = {"TD Tracker", string.format("✓ Zmigrowano %d ustawień", #settings)}
        })

        -- Odśwież cache
        Wait(1000)
        exports.td_tracker:ForceRefreshCache()

        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 255},
            multiline = true,
            args = {"TD Tracker", "════════════════════════════════"}
        })
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"TD Tracker", "✓ MIGRACJA ZAKOŃCZONA POMYŚLNIE!"}
        })
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 215, 0},
            multiline = true,
            args = {"TD Tracker", "Skrypt używa teraz MySQL do konfiguracji"}
        })
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 255},
            multiline = true,
            args = {"TD Tracker", "════════════════════════════════"}
        })
    end
end, false)

print('^2[TD TRACKER]^0 Migration helper loaded - use /tracker migrate')
