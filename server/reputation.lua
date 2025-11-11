function GetReputation(identifier)
    local result = MySQL.scalar.await('SELECT reputation FROM tracker_reputation WHERE identifier = ?', {identifier})
    return result or 0
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