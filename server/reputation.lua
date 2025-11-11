-- ============================================
-- TD TRACKER - REPUTATION SYSTEM
-- TuikeDevelopments 2025
-- ============================================

print('^2[TD TRACKER]^0 Loading reputation.lua...')

-- ============================================
-- POBIERANIE REPUTACJI GRACZA
-- ============================================

---@param identifier string
---@return number reputation
function GetReputation(identifier)
    if not identifier then
        print('^1[TRACKER REPUTATION ERROR]^0 Invalid identifier!')
        return 0
    end

    -- Sprawdź czy gracz istnieje w bazie
    local result = MySQL.single.await('SELECT reputation FROM tracker_reputation WHERE identifier = ?', {identifier})

    if result then
        print(string.format('^3[TRACKER REPUTATION]^0 %s has %d reputation', identifier, result.reputation))
        return result.reputation
    else
        -- Jeśli gracz nie istnieje, utwórz nowy rekord z reputacją 0
        MySQL.insert.await('INSERT INTO tracker_reputation (identifier, reputation) VALUES (?, ?)', {identifier, 0})
        print(string.format('^2[TRACKER REPUTATION]^0 Created new reputation record for %s', identifier))
        return 0
    end
end

-- ============================================
-- DODAWANIE REPUTACJI
-- ============================================

---@param identifier string
---@param amount number
function AddReputation(identifier, amount)
    if not identifier or not amount or amount <= 0 then
        print('^1[TRACKER REPUTATION ERROR]^0 Invalid parameters for AddReputation!')
        return
    end

    -- Sprawdź czy gracz istnieje
    local exists = MySQL.single.await('SELECT id FROM tracker_reputation WHERE identifier = ?', {identifier})

    if exists then
        -- Zaktualizuj reputację
        MySQL.update.await('UPDATE tracker_reputation SET reputation = reputation + ?, successful_missions = successful_missions + 1, total_missions = total_missions + 1, last_mission = NOW(), updated_at = NOW() WHERE identifier = ?',
            {amount, identifier})

        local newRep = GetReputation(identifier)
        print(string.format('^2[TRACKER REPUTATION]^0 %s gained %d reputation (total: %d)', identifier, amount, newRep))

        -- Powiadom gracza
        local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
        if xPlayer then
            TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                title = 'Reputacja',
                description = string.format('Zdobyłeś +%d reputacji! (Łącznie: %d)', amount, newRep),
                type = 'success',
                duration = 5000
            })
        end
    else
        -- Utwórz nowy rekord
        MySQL.insert.await('INSERT INTO tracker_reputation (identifier, reputation, successful_missions, total_missions, last_mission) VALUES (?, ?, 1, 1, NOW())',
            {identifier, amount})
        print(string.format('^2[TRACKER REPUTATION]^0 Created new record for %s with %d reputation', identifier, amount))
    end
end

-- ============================================
-- ODEJMOWANIE REPUTACJI (KARA)
-- ============================================

---@param identifier string
---@param amount number
function RemoveReputation(identifier, amount)
    if not identifier or not amount or amount <= 0 then
        print('^1[TRACKER REPUTATION ERROR]^0 Invalid parameters for RemoveReputation!')
        return
    end

    -- Sprawdź czy gracz istnieje
    local exists = MySQL.single.await('SELECT id FROM tracker_reputation WHERE identifier = ?', {identifier})

    if exists then
        -- Zaktualizuj reputację (nie pozwalaj zejść poniżej 0)
        MySQL.update.await('UPDATE tracker_reputation SET reputation = GREATEST(0, reputation - ?), failed_missions = failed_missions + 1, total_missions = total_missions + 1, last_mission = NOW(), updated_at = NOW() WHERE identifier = ?',
            {amount, identifier})

        local newRep = GetReputation(identifier)
        print(string.format('^1[TRACKER REPUTATION]^0 %s lost %d reputation (total: %d)', identifier, amount, newRep))

        -- Powiadom gracza
        local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
        if xPlayer then
            TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                title = 'Reputacja',
                description = string.format('Straciłeś -%d reputacji! (Pozostało: %d)', amount, newRep),
                type = 'error',
                duration = 5000
            })
        end
    else
        -- Utwórz nowy rekord z 0 reputacją
        MySQL.insert.await('INSERT INTO tracker_reputation (identifier, reputation, failed_missions, total_missions, last_mission) VALUES (?, 0, 1, 1, NOW())',
            {identifier})
        print(string.format('^2[TRACKER REPUTATION]^0 Created new record for %s with 0 reputation (failed mission)', identifier))
    end
end

-- ============================================
-- ZAPISYWANIE HISTORII MISJI
-- ============================================

---@param identifier string
---@param missionType number
---@param status string completed/failed/abandoned
---@param reputationGained number
---@param moneyReward number
---@param blackMoneyReward number
---@param duration number w sekundach
function SaveMission(identifier, missionType, status, reputationGained, moneyReward, blackMoneyReward, duration)
    if not identifier or not missionType or not status then
        print('^1[TRACKER REPUTATION ERROR]^0 Invalid parameters for SaveMission!')
        return
    end

    -- Zapisz misję do historii
    MySQL.insert.await([[
        INSERT INTO tracker_missions
        (identifier, mission_type, status, reputation_gained, reward_money, reward_black_money, duration, completed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        identifier,
        missionType,
        status,
        reputationGained or 0,
        moneyReward or 0,
        blackMoneyReward or 0,
        math.floor(duration or 0)
    })

    local statusEmoji = {
        completed = '✅',
        failed = '❌',
        abandoned = '⚠️'
    }

    print(string.format('^3[TRACKER MISSION]^0 %s Mission %d | Status: %s %s | Rep: %+d | Money: $%d | Black: $%d | Time: %ds',
        statusEmoji[status] or '❓',
        missionType,
        status,
        statusEmoji[status] or '',
        reputationGained or 0,
        moneyReward or 0,
        blackMoneyReward or 0,
        math.floor(duration or 0)
    ))
end

-- ============================================
-- POBIERANIE STATYSTYK GRACZA
-- ============================================

---@param identifier string
---@return table stats
function GetPlayerStats(identifier)
    if not identifier then
        return {
            reputation = 0,
            total_missions = 0,
            successful_missions = 0,
            failed_missions = 0,
            last_mission = 'Brak'
        }
    end

    local stats = MySQL.single.await('SELECT * FROM tracker_reputation WHERE identifier = ?', {identifier})

    if stats then
        -- Formatuj datę ostatniej misji
        if stats.last_mission then
            stats.last_mission = os.date('%Y-%m-%d %H:%M', stats.last_mission)
        else
            stats.last_mission = 'Brak'
        end
        return stats
    else
        return {
            reputation = 0,
            total_missions = 0,
            successful_missions = 0,
            failed_missions = 0,
            last_mission = 'Brak'
        }
    end
end

-- ============================================
-- RESETOWANIE REPUTACJI (ADMIN)
-- ============================================

---@param identifier string
function ResetReputation(identifier)
    if not identifier then
        print('^1[TRACKER REPUTATION ERROR]^0 Invalid identifier for reset!')
        return false
    end

    MySQL.update.await('UPDATE tracker_reputation SET reputation = 0, successful_missions = 0, failed_missions = 0, total_missions = 0, last_mission = NULL WHERE identifier = ?', {identifier})
    print(string.format('^3[TRACKER REPUTATION]^0 Reset reputation for %s', identifier))
    return true
end

-- ============================================
-- USTAWIANIE REPUTACJI (ADMIN)
-- ============================================

---@param identifier string
---@param amount number
function SetReputation(identifier, amount)
    if not identifier or not amount then
        print('^1[TRACKER REPUTATION ERROR]^0 Invalid parameters for SetReputation!')
        return false
    end

    -- Sprawdź czy gracz istnieje
    local exists = MySQL.single.await('SELECT id FROM tracker_reputation WHERE identifier = ?', {identifier})

    if exists then
        MySQL.update.await('UPDATE tracker_reputation SET reputation = ? WHERE identifier = ?', {amount, identifier})
    else
        MySQL.insert.await('INSERT INTO tracker_reputation (identifier, reputation) VALUES (?, ?)', {identifier, amount})
    end

    print(string.format('^3[TRACKER REPUTATION]^0 Set reputation for %s to %d', identifier, amount))
    return true
end

-- ============================================
-- TOP GRACZY (LEADERBOARD)
-- ============================================

---@param limit number
---@return table topPlayers
function GetTopPlayers(limit)
    limit = limit or 10

    local results = MySQL.query.await([[
        SELECT
            identifier,
            reputation,
            total_missions,
            successful_missions,
            failed_missions
        FROM tracker_reputation
        ORDER BY reputation DESC
        LIMIT ?
    ]], {limit})

    return results or {}
end

print('^2[TD TRACKER]^0 Reputation system loaded successfully!')
