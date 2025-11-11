-- TuikeDevelopments - Logs & Cooldown System
-- WERSJA TESTOWA - MySQL WYŁĄCZONY!

function IsOnCooldown(identifier)
    print('^3[TRACKER DEBUG]^0 IsOnCooldown START for:', identifier)
    print('^2[TRACKER DEBUG]^0 MySQL DISABLED FOR TESTING - returning false')
    print('^3[TRACKER DEBUG]^0 IsOnCooldown END. Has cooldown: false')
    
    -- TYMCZASOWO WYŁĄCZONE - zawsze zwracaj false
    return false
end

function GetCooldownTime(identifier)
    print('^3[TRACKER DEBUG]^0 GetCooldownTime START')
    print('^2[TRACKER DEBUG]^0 MySQL DISABLED FOR TESTING - returning 0')
    print('^3[TRACKER DEBUG]^0 GetCooldownTime END. Time: 0')
    
    -- TYMCZASOWO WYŁĄCZONE - zawsze zwracaj 0
    return 0
end

function SetCooldown(identifier)
    print('^3[TRACKER DEBUG]^0 SetCooldown START for:', identifier)
    print('^2[TRACKER DEBUG]^0 MySQL DISABLED FOR TESTING - skipping')
    print('^2[TRACKER DEBUG]^0 SetCooldown END')
    
    -- TYMCZASOWO WYŁĄCZONE - nic nie rób
end

function LogAction(identifier, action, data)
    print(string.format('[TRACKER LOG] %s | %s | %s', identifier, action, json.encode(data)))
end