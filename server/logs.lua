function LogAction(identifier, action, data)
    print(string.format('[TRACKER] %s | %s | %s', identifier, action, json.encode(data)))
end

function IsOnCooldown(identifier)
    local result = MySQL.scalar.await('SELECT expires_at FROM tracker_cooldowns WHERE identifier = ? AND expires_at > NOW()', {identifier})
    return result ~= nil
end

function GetCooldownTime(identifier)
    local result = MySQL.scalar.await('SELECT TIMESTAMPDIFF(SECOND, NOW(), expires_at) FROM tracker_cooldowns WHERE identifier = ? AND expires_at > NOW()', {identifier})
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