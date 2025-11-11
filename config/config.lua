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

Config.Stages = {
    [1] = {enabled = true, minReputation = 0},
    [2] = {enabled = true, minReputation = 100},
    [3] = {enabled = true, minReputation = 500}
}