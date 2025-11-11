local ESX = exports['es_extended']:getSharedObject()

print('^2[TRACKER]^0 Commands loaded')

function IsAdmin(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    print('^3[TRACKER DEBUG]^0 IsAdmin check for ID:', src)
    
    if not xPlayer then 
        print('^1[TRACKER DEBUG]^0 xPlayer not found')
        return false 
    end
    
    local playerGroup = xPlayer.getGroup()
    print('^3[TRACKER DEBUG]^0 Player group:', playerGroup)
    print('^3[TRACKER DEBUG]^0 Admin groups:', json.encode(Config.AdminGroups))
    
    for _, group in ipairs(Config.AdminGroups) do
        if playerGroup == group then 
            print('^2[TRACKER DEBUG]^0 Admin access granted')
            return true 
        end
    end
    
    print('^1[TRACKER DEBUG]^0 Admin access denied')
    return false
end

-- ============================================
-- KOMENDA /starttracker - TYLKO DLA ADMINÓW
-- ============================================

RegisterCommand('starttracker', function(src, args)
    print('^3[TRACKER DEBUG]^0 Command /starttracker executed by:', src)
    print('^3[TRACKER DEBUG]^0 Args:', json.encode(args))
    
    if src == 0 then
        print('^1[TRACKER DEBUG]^0 Command from console - not supported')
        return
    end
    
    if not IsAdmin(src) then 
        print('^1[TRACKER DEBUG]^0 No admin permission')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Brak uprawnień',
            description = 'Komenda tylko dla adminów',
            type = 'error'
        })
        return 
    end
    
    local stage = tonumber(args[1])
    print('^3[TRACKER DEBUG]^0 Stage parsed:', stage)
    
    if not stage or stage < 1 or stage > 3 then
        print('^1[TRACKER DEBUG]^0 Invalid stage')
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Błąd',
            description = 'Użyj: /starttracker [1-3]',
            type = 'error'
        })
        return
    end
    
    print('^2[TRACKER DEBUG]^0 Calling StartMissionForPlayer for stage', stage)
    
    local success = StartMissionForPlayer(src, stage)
    
    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sukces',
            description = 'Misja etap ' .. stage .. ' rozpoczęta',
            type = 'success'
        })
    end
end, false)

RegisterCommand('tracker', function(src, args)
    print('^3[TRACKER DEBUG]^0 Command /tracker executed by:', src, 'args:', json.encode(args))
    
    if src == 0 then
        print('^1[TRACKER DEBUG]^0 Command from console - not supported')
        return
    end
    
    if not IsAdmin(src) then 
        print('^1[TRACKER DEBUG]^0 No admin permission for /tracker')
        return 
    end
    
    local action = args[1]
    print('^3[TRACKER DEBUG]^0 Action:', action)
    
    if action == 'rep' then
        local target = tonumber(args[2])
        local amount = tonumber(args[3])
        
        print('^3[TRACKER DEBUG]^0 Rep change - Target:', target, 'Amount:', amount)
        
        if not target or not amount then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Użyj: /tracker rep [ID] [ilość]',
                type = 'error'
            })
            return
        end
        
        local xPlayer = ESX.GetPlayerFromId(target)
        if not xPlayer then
            print('^1[TRACKER DEBUG]^0 Target player offline')
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Gracz offline',
                type = 'error'
            })
            return
        end
        
        if amount > 0 then
            AddReputation(xPlayer.identifier, amount)
            print('^2[TRACKER DEBUG]^0 Added', amount, 'rep to', xPlayer.identifier)
        else
            RemoveReputation(xPlayer.identifier, math.abs(amount))
            print('^2[TRACKER DEBUG]^0 Removed', math.abs(amount), 'rep from', xPlayer.identifier)
        end
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sukces',
            description = string.format('Zmieniono reputację o %d', amount),
            type = 'success'
        })
        
    elseif action == 'stats' then
        local target = tonumber(args[2])
        
        print('^3[TRACKER DEBUG]^0 Stats check for target:', target)
        
        if not target then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Użyj: /tracker stats [ID]',
                type = 'error'
            })
            return
        end
        
        local xPlayer = ESX.GetPlayerFromId(target)
        if not xPlayer then
            print('^1[TRACKER DEBUG]^0 Target player offline for stats')
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Gracz offline',
                type = 'error'
            })
            return
        end
        
        local stats = MySQL.single.await('SELECT * FROM tracker_reputation WHERE identifier = ?', {xPlayer.identifier})
        
        print('^3[TRACKER DEBUG]^0 Stats result:', json.encode(stats))
        
        if stats then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Statystyki',
                description = string.format('Rep: %d\nUkończone: %d\nNieudane: %d', stats.reputation, stats.successful_missions, stats.failed_missions),
                type = 'info',
                duration = 8000
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Statystyki',
                description = 'Gracz nie ma jeszcze statystyk',
                type = 'info'
            })
        end
        
    elseif action == 'cooldown' then
        local target = tonumber(args[2]) or src
        
        print('^3[TRACKER DEBUG]^0 Removing cooldown for:', target)
        
        local xPlayer = ESX.GetPlayerFromId(target)
        if not xPlayer then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Gracz offline',
                type = 'error'
            })
            return
        end
        
        MySQL.query.await('DELETE FROM tracker_cooldowns WHERE identifier = ?', {xPlayer.identifier})
        
        print('^2[TRACKER DEBUG]^0 Cooldown removed for:', xPlayer.identifier)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sukces',
            description = 'Cooldown usunięty dla gracza ' .. target,
            type = 'success'
        })
        
        if target ~= src then
            TriggerClientEvent('ox_lib:notify', target, {
                title = 'Cooldown',
                description = 'Twój cooldown został usunięty',
                type = 'info'
            })
        end
        
    elseif action == 'clearall' then
        print('^3[TRACKER DEBUG]^0 Clearing all cooldowns')
        
        MySQL.query.await('DELETE FROM tracker_cooldowns')
        
        print('^2[TRACKER DEBUG]^0 All cooldowns cleared')
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sukces',
            description = 'Wszystkie cooldowny zostały usunięte',
            type = 'success'
        })
        
    elseif action == 'debug' then
        print('^3[TRACKER DEBUG]^0 === DEBUG INFO ===')
        print('^3[TRACKER DEBUG]^0 Active missions:', activeMissions and json.encode(activeMissions) or 'nil')
        print('^3[TRACKER DEBUG]^0 Player ID:', src)
        print('^3[TRACKER DEBUG]^0 Is Admin:', IsAdmin(src))
        print('^3[TRACKER DEBUG]^0 Config loaded:', Config ~= nil)
        print('^3[TRACKER DEBUG]^0 ConfigLocations loaded:', ConfigLocations ~= nil)
        print('^3[TRACKER DEBUG]^0 ConfigRewards loaded:', ConfigRewards ~= nil)
        print('^3[TRACKER DEBUG]^0 ConfigTexts loaded:', ConfigTexts ~= nil)
        print('^3[TRACKER DEBUG]^0 === END DEBUG ===')
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Debug',
            description = 'Sprawdź F8 console',
            type = 'info'
        })
        
    elseif action == 'cancel' then
        local target = tonumber(args[2]) or src
        
        print('^3[TRACKER DEBUG]^0 Canceling mission for:', target)
        
        if activeMissions and activeMissions[target] then
            TriggerClientEvent('td_tracker:client:cancelMission', target)
            activeMissions[target] = nil
            print('^2[TRACKER DEBUG]^0 Mission canceled')
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Sukces',
                description = 'Misja anulowana',
                type = 'success'
            })
        else
            print('^1[TRACKER DEBUG]^0 No active mission to cancel')
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Brak aktywnej misji',
                type = 'error'
            })
        end
        
    elseif action == 'start' then
        local target = tonumber(args[2])
        local stage = tonumber(args[3])

        if not target or not stage then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Użyj: /tracker start [ID] [1-3]',
                type = 'error'
            })
            return
        end

        print('^2[TRACKER DEBUG]^0 Starting mission for player', target, 'stage', stage)

        local xPlayer = ESX.GetPlayerFromId(target)
        if xPlayer then
            local success = StartMissionForPlayer(target, stage)
            if success then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Sukces',
                    description = string.format('Rozpoczęto misję %d dla gracza %d', stage, target),
                    type = 'success'
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Gracz offline',
                type = 'error'
            })
        end

    elseif action == 'npc' then
        print('^2[TRACKER DEBUG]^0 Spawning NPC for player', src)

        TriggerClientEvent('td_tracker:client:spawnNPC', src)

        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sukces',
            description = 'Zleceniodawca został zespawnowany',
            type = 'success'
        })

    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Komendy Tracker',
            description = '/starttracker [1-3]\n/tracker npc - Spawn NPC\n/tracker rep [ID] [ilość]\n/tracker stats [ID]\n/tracker cooldown [ID]\n/tracker clearall\n/tracker debug\n/tracker cancel [ID]\n/tracker start [ID] [1-3]\n\n**Dla graczy:**\n/cancelmission - Anuluj misję',
            type = 'info',
            duration = 15000
        })
    end
end, false)

print('^2[TRACKER]^0 Commands registered: /starttracker, /tracker')