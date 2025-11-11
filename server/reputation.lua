function GetReputation(identifier)
    print('^3[TRACKER DEBUG]^0 GetReputation START')
    
    local success, result = pcall(function()
        -- ZMIENIONE: query zamiast scalar
        local data = MySQL.query.await('SELECT reputation FROM tracker_reputation WHERE identifier = ?', {identifier})
        
        if data and #data > 0 then
            return data[1].reputation
        end
        return 0
    end)
    
    if not success then
        print('^1[TRACKER ERROR]^0 MySQL error in GetReputation:', result)
        return 0
    end
    
    print('^3[TRACKER DEBUG]^0 GetReputation END. Rep:', result)
    return result
end

function AddReputation(identifier, amount)
    MySQL.query.await([[
        INSERT INTO tracker_reputation (identifier, reputation, total_missions, successful_missions)
        VALUES (?, ?, 1, 1)
        ON DUPLICATE KEY UPDATE
            reputation = reputation + ?,
            total_missions = total_missions + 1,
            successful_missions = successful_missions + 1,
            last_mission = NOW()
    ]], {identifier, amount, amount})
end

function RemoveReputation(identifier, amount)
    MySQL.query.await([[
        INSERT INTO tracker_reputation (identifier, reputation, total_missions, failed_missions)
        VALUES (?, ?, 1, 1)
        ON DUPLICATE KEY UPDATE
            reputation = GREATEST(0, reputation - ?),
            total_missions = total_missions + 1,
            failed_missions = failed_missions + 1,
            last_mission = NOW()
    ]], {identifier, -amount, amount})
end

function SaveMission(identifier, type, status, rep, money, black, duration)
    MySQL.insert.await([[
        INSERT INTO tracker_missions (identifier, mission_type, status, reputation_gained, reward_money, reward_black_money, duration)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {identifier, type, status, rep, money, black, duration})
end

function AddReputation(identifier, amount)
    print('^3[TRACKER DEBUG]^0 AddReputation START')
    
    MySQL.query.await([[
        INSERT INTO tracker_reputation (identifier, reputation, total_missions, successful_missions)
        VALUES (?, ?, 1, 1)
        ON DUPLICATE KEY UPDATE
            reputation = reputation + ?,
            total_missions = total_missions + 1,
            successful_missions = successful_missions + 1,
            last_mission = NOW()
    ]], {identifier, amount, amount})
    
    print('^3[TRACKER DEBUG]^0 AddReputation END')
end

function RemoveReputation(identifier, amount)
    print('^3[TRACKER DEBUG]^0 RemoveReputation START')
    
    MySQL.query.await([[
        INSERT INTO tracker_reputation (identifier, reputation, total_missions, failed_missions)
        VALUES (?, ?, 1, 1)
        ON DUPLICATE KEY UPDATE
            reputation = GREATEST(0, reputation - ?),
            total_missions = total_missions + 1,
            failed_missions = failed_missions + 1,
            last_mission = NOW()
    ]], {identifier, -amount, amount})
    
    print('^3[TRACKER DEBUG]^0 RemoveReputation END')
end

function SaveMission(identifier, type, status, rep, money, black, duration)
    print('^3[TRACKER DEBUG]^0 SaveMission START')
    
    MySQL.insert.await([[
        INSERT INTO tracker_missions (identifier, mission_type, status, reputation_gained, reward_money, reward_black_money, duration)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {identifier, type, status, rep, money, black, duration})
    
    print('^3[TRACKER DEBUG]^0 SaveMission END')
end

function AddReputation(identifier, amount)
    MySQL.query.await([[
        INSERT INTO tracker_reputation (identifier, reputation, total_missions, successful_missions)
        VALUES (?, ?, 1, 1)
        ON DUPLICATE KEY UPDATE
            reputation = reputation + ?,
            total_missions = total_missions + 1,
            successful_missions = successful_missions + 1,
            last_mission = NOW()
    ]], {identifier, amount, amount})
end

function RemoveReputation(identifier, amount)
    MySQL.query.await([[
        INSERT INTO tracker_reputation (identifier, reputation, total_missions, failed_missions)
        VALUES (?, ?, 1, 1)
        ON DUPLICATE KEY UPDATE
            reputation = GREATEST(0, reputation - ?),
            total_missions = total_missions + 1,
            failed_missions = failed_missions + 1,
            last_mission = NOW()
    ]], {identifier, -amount, amount})
end

function SaveMission(identifier, type, status, rep, money, black, duration)
    MySQL.insert.await([[
        INSERT INTO tracker_missions (identifier, mission_type, status, reputation_gained, reward_money, reward_black_money, duration)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {identifier, type, status, rep, money, black, duration})
end