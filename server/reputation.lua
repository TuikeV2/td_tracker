-- TuikeDevelopments - Reputation System
-- WERSJA TESTOWA - MySQL WYŁĄCZONY!

function GetReputation(identifier)
    print('^3[TRACKER DEBUG]^0 GetReputation START for:', identifier)
    print('^2[TRACKER DEBUG]^0 MySQL DISABLED FOR TESTING - returning 999')
    print('^3[TRACKER DEBUG]^0 GetReputation END. Rep: 999')
    
    -- TYMCZASOWO WYŁĄCZONE - zwróć wysoką reputację żeby wszystkie stage były dostępne
    return 999
end

function AddReputation(identifier, amount)
    print('^3[TRACKER DEBUG]^0 AddReputation START - Amount:', amount)
    print('^2[TRACKER DEBUG]^0 MySQL DISABLED FOR TESTING - skipping')
    print('^2[TRACKER DEBUG]^0 AddReputation END')
    
    -- TYMCZASOWO WYŁĄCZONE - nic nie rób
end

function RemoveReputation(identifier, amount)
    print('^3[TRACKER DEBUG]^0 RemoveReputation START - Amount:', amount)
    print('^2[TRACKER DEBUG]^0 MySQL DISABLED FOR TESTING - skipping')
    print('^2[TRACKER DEBUG]^0 RemoveReputation END')
    
    -- TYMCZASOWO WYŁĄCZONE - nic nie rób
end

function SaveMission(identifier, type, status, rep, money, black, duration)
    print('^3[TRACKER DEBUG]^0 SaveMission START')
    print('^2[TRACKER DEBUG]^0 MySQL DISABLED FOR TESTING - skipping')
    print('^2[TRACKER DEBUG]^0 SaveMission END')
    
    -- TYMCZASOWO WYŁĄCZONE - nic nie rób
end