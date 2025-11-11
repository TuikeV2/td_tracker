function LogAction(identifier, action, data)
    print(string.format('[TRACKER] %s | %s | %s', identifier, action, json.encode(data)))
end

function IsOnCooldown(identifier)
    print('^3[TRACKER DEBUG]^0 IsOnCooldown START for:', identifier)
    
    local success, result = pcall(function()
        print('^3[TRACKER DEBUG]^0 Executing MySQL query...')
        
        -- ZMIENIONE: query zamiast scalar
        local data = MySQL.query.await('SELECT expires_at FROM tracker_cooldowns WHERE identifier = ? AND expires_at > NOW()', {identifier})
        
        print('^3[TRACKER DEBUG]^0 MySQL query completed. Rows:', data and #data or 0)
        
        return data and #data > 0
    end)
    
    if not success then
        print('^1[TRACKER ERROR]^0 MySQL error in IsOnCooldown:', result)
        return false
    end
    
    print('^3[TRACKER DEBUG]^0 IsOnCooldown END. Has cooldown:', result)
    return result
end

function GetCooldownTime(identifier)
    print('^3[TRACKER DEBUG]^0 GetCooldownTime START')
    
    local success, result = pcall(function()
        -- ZMIENIONE: query zamiast scalar
        local data = MySQL.query.await('SELECT TIMESTAMPDIFF(SECOND, NOW(), expires_at) as time FROM tracker_cooldowns WHERE identifier = ? AND expires_at > NOW()', {identifier})
        
        if data and #data > 0 then
            return data[1].time
        end
        return 0
    end)
    
    if not success then
        print('^1[TRACKER ERROR]^0 MySQL error in GetCooldownTime:', result)
        return 0
    end
    
    print('^3[TRACKER DEBUG]^0 GetCooldownTime END. Time:', result or 0)
    return result or 0
end

function SetCooldown(identifier)
    print('^3[TRACKER DEBUG]^0 SetCooldown START')
    
    local cooldownTime = Config.GlobalCooldown and Config.GlobalCooldownTime or Config.PersonalCooldownTime
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (cooldownTime / 1000))
    
    local success, result = pcall(function()
        MySQL.query.await([[
            INSERT INTO tracker_cooldowns (identifier, cooldown_type, expires_at)
            VALUES (?, 'personal', ?)
            ON DUPLICATE KEY UPDATE expires_at = ?
        ]], {identifier, expiresAt, expiresAt})
    end)
    
    if not success then
        print('^1[TRACKER ERROR]^0 MySQL error in SetCooldown:', result)
    end
    
    print('^3[TRACKER DEBUG]^0 SetCooldown END')
end

function LogAction(identifier, action, data)
    print(string.format('[TRACKER] %s | %s | %s', identifier, action, json.encode(data)))
end

function GetCooldownTime(identifier)
    print('^3[TRACKER DEBUG]^0 GetCooldownTime START')
    
    local success, result = pcall(function()
        -- ZMIANA: query zamiast scalar
        local data = MySQL.query.await('SELECT TIMESTAMPDIFF(SECOND, NOW(), expires_at) as time FROM tracker_cooldowns WHERE identifier = ? AND expires_at > NOW()', {identifier})
        
        if data and #data > 0 then
            return data[1].time
        end
        return 0
    end)
    
    if not success then
        print('^1[TRACKER ERROR]^0 MySQL error in GetCooldownTime:', result)
        return 0
    end
    
    print('^3[TRACKER DEBUG]^0 GetCooldownTime END. Time:', result or 0)
    return result or 0
end

function SetCooldown(identifier)
    print('^3[TRACKER DEBUG]^0 SetCooldown START')
    
    local cooldownTime = Config.GlobalCooldown and Config.GlobalCooldownTime or Config.PersonalCooldownTime
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (cooldownTime / 1000))
    
    local success, result = pcall(function()
        -- ZMIANA: query.await zamiast scalar
        MySQL.query.await([[
            INSERT INTO tracker_cooldowns (identifier, cooldown_type, expires_at)
            VALUES (?, 'personal', ?)
            ON DUPLICATE KEY UPDATE expires_at = ?
        ]], {identifier, expiresAt, expiresAt})
    end)
    
    if not success then
        print('^1[TRACKER ERROR]^0 MySQL error in SetCooldown:', result)
    end
    
    print('^3[TRACKER DEBUG]^0 SetCooldown END')
end

function LogAction(identifier, action, data)
    print(string.format('[TRACKER] %s | %s | %s', identifier, action, json.encode(data)))
end
function GetCooldownTime(identifier)
    print('^3[TRACKER DEBUG]^0 GetCooldownTime START')
    
    local success, result = pcall(function()
        return MySQL.scalar.await('SELECT TIMESTAMPDIFF(SECOND, NOW(), expires_at) FROM tracker_cooldowns WHERE identifier = ? AND expires_at > NOW()', {identifier})
    end)
    
    if not success then
        print('^1[TRACKER ERROR]^0 MySQL error in GetCooldownTime:', result)
        return 0
    end
    
    print('^3[TRACKER DEBUG]^0 GetCooldownTime END. Time:', result or 0)
    return result or 0
end

function SetCooldown(identifier)
    local cooldownTime = Config.GlobalCooldown and Config.GlobalCooldownTime or Config.PersonalCooldownTime
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (cooldownTime / 1000))
    
    MySQL.query.await([[
        INSERT INTO tracker_cooldowns (identifier, cooldown_type, expires_at)
        VALUES (?, 'personal', ?)
        ON DUPLICATE KEY UPDATE expires_at = ?
    ]], {identifier, expiresAt, expiresAt})
end