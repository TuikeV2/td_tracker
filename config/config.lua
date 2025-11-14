Config = {}

Config.Framework = 'esx'
Config.DispatchSystem = 'lb_tablet'
Config.Debug = true

Config.EnableAntiCheat = false
Config.MaxDistanceFromVehicle = 150.0
Config.MaxDistanceFromNPC = 10.0
Config.CheckInterval = 5000

Config.NPCAttemptsBeforeShooting = 3
Config.NPCShootingDamage = 50

Config.RequireLockpickItem = false
Config.LockpickItem = 'lockpick'
Config.LockpickBreakChance = 15
Config.LockpickDifficulty = {'easy', 'medium', 'medium'}

Config.RequireDismantleMinigame = false
Config.DismantleDifficulty = {'medium', 'medium', 'hard'}
Config.DismantleTime = 16000

Config.AlarmDuration = 15000

Config.ChaseTime = 30000
Config.ChaseAreaSize = 500.0
Config.ChaseUpdateInterval = 5000

Config.GlobalCooldown = false
Config.GlobalCooldownTime = 0
Config.PersonalCooldownTime = 0

Config.MissionTimeLimit = {
    [1] = 600000,
    [2] = 900000,
    [3] = 1800000
}

Config.AdminGroups = {'admin', 'superadmin', 'owner'}
Config.PoliceJobs = {'police', 'sheriff', 'lspd', 'captain'}

Config.Police = {
    dispatchEnabled = true,
    policeJobs = {'police', 'sheriff', 'lspd', 'captain'},
    dispatchCode = '10-35',
    dispatchMessage = {
        stage1 = 'Kradzież pojazdu w toku',
        stage2 = 'Transport skradzionego pojazdu',
        stage3 = 'Rozbiórka nielegalnego pojazdu'
    }
}

Config.Stages = {
    [1] = {name = "Kradzież", minReputation = 0, chanceToAorB = 20, enabled = true},
    [2] = {name = "Transport", minReputation = 500, chanceToAorB = 40, enabled = true},
    [3] = {name = "Rozbiórka", minReputation = 1000, chanceToAorB = 70, enabled = true},
}

Config.NPCChase = {
    enabled = true,
    minPolicePlayersForNPCDisable = 5, -- Jeśli jest >= 5 graczy policji, NPC nie spawnie
    initialChasers = 10,                -- Początkowa liczba radiowozów
    maxChasers = 30,                    -- Maksymalna liczba radiowozów
    chasersPerVehicle = {2, 3, 4},        -- Losowo 2-3 policjantów na radiowóz
    chasersCanShoot = true,
    chasersCanExitVehicle = true,      -- Mogą wysiadać z pojazdu
    exitVehicleDistance = 200.0,        -- Dystans, w którym wysiadają
    exitVehicleDelay = 1000,           -- Opóźnienie przed wysiadaniem (3 sekundy)
    respawnDistantVehicles = true,     -- Czy respawnować daleko oddalone radiowózy
    respawnCheckDistance = 500.0,      -- Odległość, po przekroczeniu której radiowóz zostanie usunięty
    respawnCheckInterval = 5000,       -- Co ile ms sprawdzać odległość (5 sekund)
    pedModels = {
        's_m_y_cop_01',
        's_f_y_cop_01',
        's_m_y_sheriff_01',
        's_m_y_hwaycop_01'
    },
    vehModels = {
        'police',
        'police2',
        'police3',
        'police4',
        'sheriff',
        'sheriff2'
    },
    weapons = {                       -- Bronie dla policjantów
        'WEAPON_PISTOL',
        'WEAPON_COMBATPISTOL',
        'WEAPON_PUMPSHOTGUN',
        'WEAPON_CARBINERIFLE'
    },
    driveSpeed = 200.0,                -- Prędkość radiowozów (zwiększona z 50 na 80)
    driveStyle = 786603,              -- Agresywny styl jazdy
    maxChaseDistance = 1500.0,        -- Większy zasięg pościgu
    chaseTimeout = 180000,            -- 3 minuty timeout
    waveInterval = 30000,             -- Fale wsparcia co 30s
    waveAddIfLessThan = 3,            -- Dodaj wsparcie jeśli mniej niż 3
    pedAccuracy = 90,                 -- Celność policjantów
    pedHealth = 250,                  -- Wytrzymałość policjantów
    pedArmor = 100                    -- Pancerz policjantów
}
