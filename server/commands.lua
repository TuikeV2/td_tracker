local ESX = exports['es_extended']:getSharedObject()

if Config.Debug then print('^2[TRACKER]^0 Commands loaded') end

function IsAdmin(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if Config.Debug then print('^3[TRACKER DEBUG]^0 IsAdmin check for ID:', src) end
    
    if not xPlayer then 
        if Config.Debug then print('^1[TRACKER DEBUG]^0 xPlayer not found') end
        return false 
    end
    
    local playerGroup = xPlayer.getGroup()
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Player group:', playerGroup) end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Admin groups:', json.encode(Config.AdminGroups)) end
    
    for _, group in ipairs(Config.AdminGroups) do
        if playerGroup == group then 
            if Config.Debug then print('^2[TRACKER DEBUG]^0 Admin access granted') end
            return true 
        end
    end
    
    if Config.Debug then print('^1[TRACKER DEBUG]^0 Admin access denied') end
    return false
end

-- ============================================
-- KOMENDA /starttracker - TYLKO DLA ADMINÓW
-- ============================================

RegisterCommand('starttracker', function(src, args)
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Command /starttracker executed by:', src) end
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Args:', json.encode(args)) end
    
    if src == 0 then
        if Config.Debug then print('^1[TRACKER DEBUG]^0 Command from console - not supported') end
        return
    end
    
    if not IsAdmin(src) then 
        if Config.Debug then print('^1[TRACKER DEBUG]^0 No admin permission') end
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Brak uprawnień',
            description = 'Komenda tylko dla adminów',
            type = 'error'
        })
        return 
    end
    
    local stage = tonumber(args[1])
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Stage parsed:', stage) end
    
    if not stage or stage < 1 or stage > 3 then
        if Config.Debug then print('^1[TRACKER DEBUG]^0 Invalid stage') end
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Błąd',
            description = 'Użyj: /starttracker [1-3]',
            type = 'error'
        })
        return
    end
    
    if Config.Debug then print('^2[TRACKER DEBUG]^0 Calling StartMissionForPlayer for stage', stage) end
    
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
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Command /tracker executed by:', src, 'args:', json.encode(args)) end
    
    if src == 0 then
        if Config.Debug then print('^1[TRACKER DEBUG]^0 Command from console - not supported') end
        return
    end
    
    if not IsAdmin(src) then 
        if Config.Debug then print('^1[TRACKER DEBUG]^0 No admin permission for /tracker') end
        return 
    end
    
    local action = args[1]
    if Config.Debug then print('^3[TRACKER DEBUG]^0 Action:', action) end
    
    if action == 'rep' then
        local target = tonumber(args[2])
        local amount = tonumber(args[3])
        
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Rep change - Target:', target, 'Amount:', amount) end
        
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
            if Config.Debug then print('^1[TRACKER DEBUG]^0 Target player offline') end
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Gracz offline',
                type = 'error'
            })
            return
        end
        
        if amount > 0 then
            AddReputation(xPlayer.identifier, amount)
            if Config.Debug then print('^2[TRACKER DEBUG]^0 Added', amount, 'rep to', xPlayer.identifier) end
        else
            RemoveReputation(xPlayer.identifier, math.abs(amount))
            if Config.Debug then print('^2[TRACKER DEBUG]^0 Removed', math.abs(amount), 'rep from', xPlayer.identifier) end
        end
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sukces',
            description = string.format('Zmieniono reputację o %d', amount),
            type = 'success'
        })
        
    elseif action == 'stats' then
        local target = tonumber(args[2])
        
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Stats check for target:', target) end
        
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
            if Config.Debug then print('^1[TRACKER DEBUG]^0 Target player offline for stats') end
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Błąd',
                description = 'Gracz offline',
                type = 'error'
            })
            return
        end
        
        local stats = MySQL.single.await('SELECT * FROM tracker_reputation WHERE identifier = ?', {xPlayer.identifier})
        
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Stats result:', json.encode(stats)) end
        
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
        
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Removing cooldown for:', target) end
        
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
        
        if Config.Debug then print('^2[TRACKER DEBUG]^0 Cooldown removed for:', xPlayer.identifier) end
        
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
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Clearing all cooldowns') end
        
        MySQL.query.await('DELETE FROM tracker_cooldowns')
        
        if Config.Debug then print('^2[TRACKER DEBUG]^0 All cooldowns cleared') end
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sukces',
            description = 'Wszystkie cooldowny zostały usunięte',
            type = 'success'
        })
        
    elseif action == 'debug' then
        if Config.Debug then print('^3[TRACKER DEBUG]^0 === DEBUG INFO ===') end
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Active missions:', activeMissions and json.encode(activeMissions) or 'nil') end
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Player ID:', src) end
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Is Admin:', IsAdmin(src)) end
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Config loaded:', Config ~= nil) end
        if Config.Debug then print('^3[TRACKER DEBUG]^0 ConfigLocations loaded:', ConfigLocations ~= nil) end
        if Config.Debug then print('^3[TRACKER DEBUG]^0 ConfigRewards loaded:', ConfigRewards ~= nil) end
        if Config.Debug then print('^3[TRACKER DEBUG]^0 ConfigTexts loaded:', ConfigTexts ~= nil) end
        if Config.Debug then print('^3[TRACKER DEBUG]^0 === END DEBUG ===') end
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Debug',
            description = 'Sprawdź F8 console',
            type = 'info'
        })
        
    elseif action == 'cancel' then
        local target = tonumber(args[2]) or src
        
        if Config.Debug then print('^3[TRACKER DEBUG]^0 Canceling mission for:', target) end
        
        if activeMissions and activeMissions[target] then
            TriggerClientEvent('td_tracker:client:cancelMission', target)
            activeMissions[target] = nil
            if Config.Debug then print('^2[TRACKER DEBUG]^0 Mission canceled') end
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Sukces',
                description = 'Misja anulowana',
                type = 'success'
            })
        else
            if Config.Debug then print('^1[TRACKER DEBUG]^0 No active mission to cancel') end
            
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

        if Config.Debug then print('^2[TRACKER DEBUG]^0 Starting mission for player', target, 'stage', stage) end

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
        if Config.Debug then print('^2[TRACKER DEBUG]^0 Spawning NPC for player', src) end

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

if Config.Debug then print('^2[TRACKER]^0 Commands registered: /starttracker, /tracker') end