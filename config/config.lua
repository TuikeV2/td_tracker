Config = {}

Config.Framework = 'esx'
Config.DispatchSystem = 'cd_dispatch'

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
Config.PoliceJobs = {'police', 'sheriff', 'lspd'}

Config.Police = {
    dispatchEnabled = true,
    policeJobs = {'police', 'sheriff', 'lspd'},
    dispatchCode = '10-35',
    dispatchMessage = {
        stage1 = 'Kradzież pojazdu w toku',
        stage2 = 'Transport skradzionego pojazdu',
        stage3 = 'Rozbiórka nielegalnego pojazdu'
    }
}

Config.Stages = {
    [1] = {name = "Kradzież", minReputation = 0, chanceToAorB = 20, enabled = true},
    [2] = {name = "Transport", minReputation = 50, chanceToAorB = 40, enabled = true},
    [3] = {name = "Rozbiórka", minReputation = 100, chanceToAorB = 70, enabled = true},
}
-- ... inne konfiguracje