local ESX = exports['es_extended']:getSharedObject()
local playerData = {}
local currentMission = nil
local missionStartTime = 0
local spawnedVehicles = {}
local transportVehicle = nil
local dismantleVehicle = nil
local busVehicle = nil
local currentPart = nil
local dismantledParts = {}
local dismantleZones = {}

-- ============================================
-- PODSTAWOWE EVENTY
-- ============================================

local npcEntity = nil
local npcBlip = nil
local areaBlip = nil

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    playerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    playerData.job = job
end)

-- USUNIĘTO AutoSpawnNPC() z onClientResourceStart!
-- NPC będzie spawnował się tylko podczas misji

-- ============================================
-- FUNKCJE POMOCNICZE
-- ============================================

function IsPolice()
    if not playerData.job then return false end
    for _, job in ipairs(Config.PoliceJobs) do
        if playerData.job.name == job then return true end
    end
    return false
end

function GetCurrentMission()
    return currentMission
end

-- ============================================
-- SPAWN NPC PODCZAS MISJI
-- ============================================

function SpawnMissionNPC(coords, heading)
    -- Usuń starego NPC jeśli istnieje
    RemoveNPC()
    
    print('^2[TRACKER CLIENT]^0 Spawning mission NPC at', coords)
    
    if not ConfigLocations or not ConfigLocations.NPCSpawns or #ConfigLocations.NPCSpawns == 0 then
        print('^1[TRACKER CLIENT ERROR]^0 No NPC spawns configured!')
        return
    end
    
    -- Użyj pierwszego NPC z konfiguracji jako model
    local npcConfig = ConfigLocations.NPCSpawns[1]
    
    RequestModel(GetHashKey(npcConfig.model))
    while not HasModelLoaded(GetHashKey(npcConfig.model)) do Wait(0) end
    
    -- Spawn NPC na podanych koordynatach
    npcEntity = CreatePed(4, GetHashKey(npcConfig.model), coords.x, coords.y, coords.z, heading or 0.0, false, true)
    
    SetEntityInvincible(npcEntity, true)
    SetBlockingOfNonTemporaryEvents(npcEntity, true)
    FreezeEntityPosition(npcEntity, true)
    
    if npcConfig.anim then
        RequestAnimDict(npcConfig.anim.dict)
        while not HasAnimDictLoaded(npcConfig.anim.dict) do Wait(0) end
        TaskPlayAnim(npcEntity, npcConfig.anim.dict, npcConfig.anim.name, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
    
    -- Blip NPC z waypointem
    npcBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(npcBlip, 480)
    SetBlipScale(npcBlip, 0.8)
    SetBlipColour(npcBlip, 5) -- Żółty kolor
    SetBlipRoute(npcBlip, true) -- WAYPOINT!
    SetBlipRouteColour(npcBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Kontakt')
    EndTextCommandSetBlipName(npcBlip)
    
    print('^2[TRACKER CLIENT]^0 Mission NPC spawned with waypoint')
    
    CreateNPCInteraction(npcEntity, coords)
    
    -- Notyfikacja dla gracza
    if currentMission then
        if currentMission.type == 2 then
            ShowNotification('📍 Jedź do kontaktu po pojazd (żółty marker na mapie)', 'Etap 2: Transport', 'info')
        elseif currentMission.type == 3 then
            ShowNotification('📍 Jedź do punktu rozbiórki (żółty marker na mapie)', 'Etap 3: Rozbiórka', 'info')
        end
    end
end

function RemoveNPC()
    if npcEntity and DoesEntityExist(npcEntity) then
        -- Usuń ox_target jeśli był dodany
        pcall(function()
            exports.ox_target:removeLocalEntity(npcEntity, {'npc_stage2_info', 'npc_stage3_info'})
        end)
        DeleteEntity(npcEntity)
        npcEntity = nil
    end
    if npcBlip and DoesBlipExist(npcBlip) then
        RemoveBlip(npcBlip)
        npcBlip = nil
    end
    if areaBlip and DoesBlipExist(areaBlip) then
        RemoveBlip(areaBlip)
        areaBlip = nil
    end
    print('^3[TRACKER CLIENT]^0 NPC removed')
end

function CreateNPCInteraction(npc, coords)
    -- Dodaj ox_target do NPC
    if currentMission and currentMission.active then
        local options = {}
        
        if currentMission.type == 2 then
            -- Stage 2: Transport
            table.insert(options, {
                name = 'npc_stage2_info',
                label = '💬 Porozmawiaj z kontaktem',
                icon = 'fa-solid fa-handshake',
                distance = 3.0,
                onSelect = function()
                    lib.alertDialog({
                        header = '🚗 Zlecenie: Transport',
                        content = 'Odbierz ten pojazd i dostarcz go do kryjówki.\n\n⚠️ Policja będzie ostrzeżona!\n🎯 Unikaj pościgu i jedź do punktu na mapie.',
                        centered = true,
                        labels = {confirm = 'Rozumiem'}
                    })
                end
            })
        elseif currentMission.type == 3 then
            -- Stage 3: Rozbiórka
            table.insert(options, {
                name = 'npc_stage3_info',
                label = '💬 Porozmawiaj z kontaktem',
                icon = 'fa-solid fa-wrench',
                distance = 3.0,
                onSelect = function()
                    lib.alertDialog({
                        header = '🔧 Zlecenie: Rozbiórka',
                        content = 'Rozmontuj ten pojazd na części.\n\n🔨 Kliknij na każdą część pojazdu aby ją zdemontować\n📦 Załaduj części do busa\n💰 Dostarcz bus z częściami do punktu sprzedaży',
                        centered = true,
                        labels = {confirm = 'Rozumiem'}
                    })
                end
            })
        end
        
        if #options > 0 then
            exports.ox_target:addLocalEntity(npc, options)
            print('^2[TRACKER CLIENT]^0 NPC ox_target added for stage', currentMission.type)
        end
    end
    
    -- Fallback: Text3D i E
    CreateThread(function()
        while DoesEntityExist(npc) and npc == npcEntity do
            Wait(0)
            
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - coords)
            
            if ConfigBlips and ConfigBlips.Text3D and ConfigBlips.Text3D.enabled and dist < ConfigBlips.Text3D.distance then
                DrawText3D(coords.x, coords.y, coords.z + 1.0, ConfigTexts.Text3D.npc)
                
                if dist < 2.0 and IsControlJustPressed(0, 38) then
                    if currentMission and currentMission.type == 2 then
                        lib.alertDialog({
                            header = '🚗 Zlecenie: Transport',
                            content = 'Odbierz ten pojazd i dostarcz go do kryjówki.\n\n⚠️ Policja będzie ostrzeżona!\n🎯 Unikaj pościgu i jedź do punktu na mapie.',
                            centered = true,
                            labels = {confirm = 'Rozumiem'}
                        })
                    elseif currentMission and currentMission.type == 3 then
                        lib.alertDialog({
                            header = '🔧 Zlecenie: Rozbiórka',
                            content = 'Rozmontuj ten pojazd na części.\n\n🔨 Kliknij na każdą część pojazdu aby ją zdemontować\n📦 Załaduj części do busa\n💰 Dostarcz bus z częściami do punktu sprzedaży',
                            centered = true,
                            labels = {confirm = 'Rozumiem'}
                        })
                    else
                        ShowNotification('NPC potwierdza zlecenie', 'Informacja', 'info')
                    end
                end
            end
        end
    end)
end

function ShowNPCDialog(reputation, attempts, npc)
    if IsPolice() then
        lib.alertDialog({
            header = ConfigTexts.Dialogs.policeWarning.title,
            content = ConfigTexts.Dialogs.policeWarning.description,
            centered = true,
            labels = {confirm = 'Zakończ'}
        })
        return
    end
    
    if currentMission and currentMission.active then
        lib.alertDialog({
            header = 'Masz już zlecenie',
            content = 'Dokończ obecne zlecenie zanim weźmiesz kolejne.',
            centered = true,
            labels = {confirm = 'OK'}
        })
        return
    end
    
    local availableStages = {}
    for stage, cfg in pairs(Config.Stages) do
        if cfg.enabled and reputation >= cfg.minReputation then
            table.insert(availableStages, stage)
        end
    end
    
    local options = {}
    
    for _, stage in ipairs(availableStages) do
        local stageKey = 'stage' .. stage
        local stageConfig = ConfigTexts.Context[stageKey]
        local rewardConfig = ConfigRewards['Stage' .. stage]
        
        local description = stageConfig.description .. '\n\n'
        description = description .. '💰 Nagroda: $' .. rewardConfig.money.min .. '-' .. rewardConfig.money.max .. '\n'
        description = description .. '⭐ Reputacja: +' .. rewardConfig.reputation.min .. '-' .. rewardConfig.reputation.max .. '\n'
        description = description .. '⏱️ Czas: ~' .. math.floor(Config.MissionTimeLimit[stage] / 60000) .. ' min'
        
        table.insert(options, {
            title = stageConfig.title,
            description = description,
            icon = stageConfig.icon,
            onSelect = function()
                print('^2[TRACKER CLIENT]^0 Player selected stage:', stage)
                TriggerServerEvent('td_tracker:server:startMission', stage)
                RemoveNPC()
            end
        })
    end
    
    table.insert(options, {
        title = ConfigTexts.Context.close.title,
        icon = ConfigTexts.Context.close.icon
    })
    
    local stageText = #availableStages > 0 and table.concat(availableStages, ', ') or 'Brak'
    
    lib.registerContext({
        id = 'td_tracker_npc_menu',
        title = 'Zleceniodawca',
        menu = 'td_tracker_main',
        options = options
    })
    
    lib.registerContext({
        id = 'td_tracker_main',
        title = string.format('Reputacja: %d pkt', reputation),
        options = {
            {
                title = 'Dostępne zlecenia',
                description = 'Etapy: ' .. stageText,
                icon = 'fa-solid fa-clipboard-list',
                menu = 'td_tracker_npc_menu'
            },
            {
                title = 'Twoje statystyki',
                description = 'Zobacz swoje osiągnięcia',
                icon = 'fa-solid fa-chart-line',
                onSelect = function()
                    ESX.TriggerServerCallback('td_tracker:getPlayerStats', function(stats)
                        ShowStatsDialog(stats)
                    end)
                end
            },
            {
                title = 'Zakończ rozmowę',
                icon = 'fa-solid fa-xmark'
            }
        }
    })
    
    lib.showContext('td_tracker_main')
end

function ShowStatsDialog(stats)
    local successRate = stats.total_missions > 0 and math.floor((stats.successful_missions / stats.total_missions) * 100) or 0
    
    lib.alertDialog({
        header = 'Twoje statystyki',
        content = string.format([[
**Reputacja:** %d punktów
**Misje ukończone:** %d
**Misje nieudane:** %d
**Wskaźnik sukcesu:** %d%%
**Ostatnia misja:** %s
        ]], 
            stats.reputation,
            stats.successful_missions,
            stats.failed_missions,
            successRate,
            stats.last_mission or 'Brak'
        ),
        centered = true,
        labels = {confirm = 'Zamknij'}
    })
end

-- ============================================
-- GŁÓWNA LOGIKA MISJI
-- ============================================

RegisterNetEvent('td_tracker:client:startMission', function(data)
    print('^3[TRACKER CLIENT DEBUG]^0 Starting mission type:', data.type)
    print('^3[TRACKER CLIENT DEBUG]^0 Data received:', json.encode(data))
    
    currentMission = data
    missionStartTime = GetGameTimer()
    
    if data.type == 1 then
        StartStage1(data)
    elseif data.type == 2 then
        StartStage2(data)
    elseif data.type == 3 then
        StartStage3(data)
    else
        print('^1[TRACKER CLIENT ERROR]^0 Unknown mission type:', data.type)
        return
    end
    
    if Config.MissionTimeLimit[data.type] then
        SetTimeout(Config.MissionTimeLimit[data.type], function()
            if currentMission and currentMission.active then
                FailMission('Przekroczono limit czasu')
            end
        end)
    end
    
    if Config.EnableAntiCheat then
        StartAntiCheat()
    end
end)

function CompleteMission()
    if not currentMission or not currentMission.active then return end
    
    print('^2[TRACKER CLIENT DEBUG]^0 Completing mission')
    
    local timeTaken = GetGameTimer() - missionStartTime
    local timeLimit = Config.MissionTimeLimit[currentMission.type]
    
    TriggerServerEvent('td_tracker:server:completeMission', currentMission.type, timeTaken, timeLimit)
    CleanupMission()
end

function FailMission(reason)
    if not currentMission or not currentMission.active then return end
    
    print('^1[TRACKER CLIENT DEBUG]^0 Failing mission:', reason)
    
    TriggerServerEvent('td_tracker:server:failMission', currentMission.type, reason)
    
    local penalty = ConfigRewards.FailurePenalty[currentMission.type] or 20
    ShowNotification(string.format(ConfigTexts.Notifications.missionFailed.description, reason, penalty), ConfigTexts.Notifications.missionFailed.title, 'error')
    
    CleanupMission()
end

function CleanupMission()
    print('^3[TRACKER CLIENT DEBUG]^0 Cleaning up mission')
    
    if currentMission then
        if currentMission.blips then
            for _, blip in ipairs(currentMission.blips) do
                if DoesBlipExist(blip) then RemoveBlip(blip) end
            end
        end
        
        CleanupStage1()
        CleanupStage2()
        CleanupStage3()
    end
    
    RemoveAllBlips()
    RemoveNPC() -- Usuń NPC po zakończeniu misji
    
    currentMission = nil
    missionStartTime = 0
end

function StartAntiCheat()
    CreateThread(function()
        while currentMission and currentMission.active do
            Wait(Config.CheckInterval)
            
            if currentMission.targetVehicle then
                local veh = currentMission.targetVehicle
                if DoesEntityExist(veh) then
                    local ped = PlayerPedId()
                    local dist = #(GetEntityCoords(ped) - GetEntityCoords(veh))
                    
                    if dist > Config.MaxDistanceFromVehicle and GetVehiclePedIsIn(ped, false) ~= veh then
                        FailMission('Oddaliłeś się za daleko')
                        break
                    end
                    
                    if GetEntityHealth(veh) <= 0 then
                        FailMission('Pojazd zniszczony')
                        break
                    end
                else
                    FailMission('Pojazd zniszczony')
                    break
                end
            end
        end
    end)
end

-- ============================================
-- STAGE 1: KRADZIEŻ
-- ============================================

function StartStage1(data)
    print('^3[TRACKER CLIENT DEBUG]^0 Starting Stage 1')
    
    if not data.plate or not data.searchArea or not data.vehicles then
        print('^1[TRACKER CLIENT ERROR]^0 Missing Stage 1 data!')
        FailMission('Błąd danych misji')
        return
    end
    
    local plate = data.plate
    local area = data.searchArea
    local vehicles = data.vehicles
    
    ShowNotification(string.format(ConfigTexts.Notifications.missionStarted.description, plate), ConfigTexts.Notifications.missionStarted.title, 'success')
    
    CreateSearchAreaBlip(area.center, area.radius)
    SpawnStage1Vehicles(vehicles, plate)
    
    currentMission.stage = 'search'
    currentMission.active = true
    currentMission.targetPlate = plate
end

function SpawnStage1Vehicles(vehicles, targetPlate)
    print('^3[TRACKER CLIENT DEBUG]^0 Spawning', #vehicles, 'vehicles')
    
    for _, veh in ipairs(vehicles) do
        local model = GetHashKey(veh.model)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(0) end
        
        local vehicle = CreateVehicle(model, veh.coords.x, veh.coords.y, veh.coords.z, veh.coords.w, true, false)
        SetVehicleNumberPlateText(vehicle, veh.plate)
        SetVehicleDoorsLocked(vehicle, 2)
        
        table.insert(spawnedVehicles, vehicle)
        
        exports.ox_target:addLocalEntity(vehicle, {
            {
                name = 'check_plate',
                label = 'Sprawdź tablice',
                icon = 'fa-solid fa-car',
                distance = 3.0,
                onSelect = function()
                    if veh.plate == targetPlate then
                        ShowNotification(ConfigTexts.Notifications.vehicleFound.description, ConfigTexts.Notifications.vehicleFound.title, 'info')
                        AttemptTheft(vehicle)
                    else
                        ShowNotification(string.format(ConfigTexts.Notifications.vehicleWrong.description, veh.plate), ConfigTexts.Notifications.vehicleWrong.title, 'error')
                    end
                end
            }
        })
    end
    
    print('^2[TRACKER CLIENT DEBUG]^0 Vehicles spawned successfully')
end

function AttemptTheft(vehicle)
    currentMission.targetVehicle = vehicle
    
    if Config.RequireLockpickItem then
        TriggerServerEvent('td_tracker:server:checkLockpick')
    else
        StartLockpick(vehicle)
    end
end

RegisterNetEvent('td_tracker:client:startLockpick', function()
    local vehicle = currentMission.targetVehicle
    if vehicle and DoesEntityExist(vehicle) then
        StartLockpick(vehicle)
    end
end)

function StartLockpick(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, vehicle, 1000)
    Wait(1000)
    
    if lib.progressBar({
        duration = 5000,
        label = ConfigTexts.Progress.lockpicking,
        useWhileDead = false,
        canCancel = true,
        disable = {move = true, car = true, combat = true},
        anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}
    }) then
        local success = lib.skillCheck(Config.LockpickDifficulty, {'w', 'a', 's', 'd'})
        
        if success then
            ShowNotification(ConfigTexts.Notifications.lockpickSuccess.description, ConfigTexts.Notifications.lockpickSuccess.title, 'success')
            SetVehicleDoorsLocked(vehicle, 1)
            SetVehicleEngineOn(vehicle, true, true, false)
            
            StartAlarm(vehicle)
            TriggerServerEvent('td_tracker:server:vehicleStolen', GetEntityCoords(vehicle))
            
            currentMission.targetVehicle = vehicle
            currentMission.stage = 'escape'
            MonitorEntry(vehicle)
        else
            ShowNotification(ConfigTexts.Notifications.lockpickFailed.description, ConfigTexts.Notifications.lockpickFailed.title, 'error')
            if math.random(100) <= Config.LockpickBreakChance then
                TriggerServerEvent('td_tracker:server:breakLockpick')
            end
        end
    end
end

function StartAlarm(vehicle)
    SetVehicleAlarm(vehicle, true)
    StartVehicleAlarm(vehicle)
    SetTimeout(Config.AlarmDuration, function()
        if DoesEntityExist(vehicle) then SetVehicleAlarm(vehicle, false) end
    end)
end

function MonitorEntry(vehicle)
    CreateThread(function()
        while DoesEntityExist(vehicle) and currentMission and currentMission.stage == 'escape' do
            Wait(500)
            
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == vehicle then
                StartChase()
                break
            end
        end
    end)
end

function StartChase()
    ShowNotification(ConfigTexts.Notifications.policeAlerted.description, ConfigTexts.Notifications.policeAlerted.title, 'error')
    
    SetTimeout(Config.ChaseTime, function()
        if currentMission and currentMission.active and currentMission.stage == 'escape' then
            EndChase()
        end
    end)
end

function EndChase()
    ShowNotification(ConfigTexts.Notifications.chaseEnded.description, ConfigTexts.Notifications.chaseEnded.title, 'success')
    
    TriggerServerEvent('td_tracker:server:chaseEnded')
    
    currentMission.stage = 'delivery'
    local point = ConfigLocations.Stage1.deliveryPoints[math.random(#ConfigLocations.Stage1.deliveryPoints)]
    CreateDeliveryMarker(point)
end

function CreateDeliveryMarker(coords)
    local blip = CreateWaypointBlip(coords)
    
    CreateThread(function()
        while currentMission and currentMission.stage == 'delivery' do
            Wait(0)
            
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local dist = #(pCoords - coords)
            
            if dist < 20.0 then
                DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 5.0, 5.0, 1.0, 255, 255, 0, 100, false, true, 2, false)
                
                if dist < 5.0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh ~= 0 and veh == currentMission.targetVehicle then
                        ShowHelp('~INPUT_CONTEXT~ Oddaj pojazd')
                        if IsControlJustPressed(0, 38) then
                            DeleteVehicle(veh)
                            RemoveBlip(blip)
                            CompleteMission()
                            break
                        end
                    end
                end
            end
        end
    end)
end

function CleanupStage1()
    for _, veh in ipairs(spawnedVehicles) do
        if DoesEntityExist(veh) then 
            exports.ox_target:removeLocalEntity(veh, 'check_plate')
            DeleteEntity(veh) 
        end
    end
    spawnedVehicles = {}
end

-- ============================================
-- STAGE 2: TRANSPORT
-- ============================================

function StartStage2(data)
    print('^3[TRACKER CLIENT DEBUG]^0 Starting Stage 2')
    print('^3[TRACKER CLIENT DEBUG]^0 Data received:', json.encode(data))
    
    if not data.spawnPoint then
        print('^1[TRACKER CLIENT ERROR]^0 Missing spawnPoint!')
        FailMission('Brak danych misji')
        return
    end
    
    if not data.hideout then
        print('^1[TRACKER CLIENT ERROR]^0 Missing hideout!')
        FailMission('Brak danych misji')
        return
    end
    
    if not data.vehicleModel then
        print('^1[TRACKER CLIENT ERROR]^0 Missing vehicleModel!')
        FailMission('Brak danych misji')
        return
    end
    
    local spawn = data.spawnPoint
    local hideout = data.hideout
    
    -- SPAWN NPC przy punkcie odbioru pojazdu!
    SpawnMissionNPC(vector3(spawn.x, spawn.y, spawn.z), spawn.w or 0.0)
    
    SpawnTransportVehicle(spawn, data.vehicleModel, hideout)
    
    currentMission.stage = 'pickup'
    currentMission.active = true
    currentMission.deliveryPoint = hideout
    
    print('^2[TRACKER CLIENT DEBUG]^0 Stage 2 initialized')
end

function SpawnTransportVehicle(spawn, model, hideout)
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    
    transportVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    SetVehicleDoorsLocked(transportVehicle, 1)
    SetVehicleEngineOn(transportVehicle, false, true, false)
    
    currentMission.targetVehicle = transportVehicle
    
    CreateThread(function()
        while DoesEntityExist(transportVehicle) and currentMission and currentMission.stage == 'pickup' do
            Wait(500)
            
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == transportVehicle then
                RemoveNPC() -- Usuń NPC gdy gracz odbierze pojazd
                StartStage2Chase(hideout)
                break
            end
        end
    end)
    
    print('^2[TRACKER CLIENT DEBUG]^0 Transport vehicle spawned')
end

function StartStage2Chase(hideout)
    currentMission.stage = 'transport'
    
    ShowNotification('Policja otrzymała zgłoszenie! Ukryj pojazd!', 'Transport w toku', 'error')
    TriggerServerEvent('td_tracker:server:vehicleStolen', GetEntityCoords(transportVehicle))
    
    SetTimeout(Config.ChaseTime, function()
        if currentMission and currentMission.active and currentMission.stage == 'transport' then
            EndStage2Chase(hideout)
        end
    end)
end

function EndStage2Chase(hideout)
    ShowNotification('Otrząsnąłeś policję! Dostarcz pojazd do dziupli', 'Bezpiecznie', 'success')
    
    TriggerServerEvent('td_tracker:server:chaseEnded')
    
    currentMission.stage = 'delivery'
    CreateStage2DeliveryMarker(hideout)
end

function CreateStage2DeliveryMarker(coords)
    local blip = CreateWaypointBlip(coords)
    
    CreateThread(function()
        while currentMission and currentMission.stage == 'delivery' do
            Wait(0)
            
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local dist = #(pCoords - coords)
            
            if dist < 20.0 then
                DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 5.0, 5.0, 1.0, 138, 43, 226, 100, false, true, 2, false)
                
                if dist < 5.0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh == transportVehicle then
                        ShowHelp('~INPUT_CONTEXT~ Dostarcz pojazd')
                        if IsControlJustPressed(0, 38) then
                            DeleteVehicle(veh)
                            RemoveBlip(blip)
                            CompleteMission()
                            break
                        end
                    end
                end
            end
        end
    end)
end

function CleanupStage2()
    if transportVehicle and DoesEntityExist(transportVehicle) then
        DeleteEntity(transportVehicle)
    end
    transportVehicle = nil
end

-- ============================================
-- STAGE 3: ROZBIÓRKA
-- ============================================

function StartStage3(data)
    print('^3[TRACKER CLIENT DEBUG]^0 Starting Stage 3')
    
    if not data.location or not data.vehicleModel then
        print('^1[TRACKER CLIENT ERROR]^0 Missing Stage 3 data!')
        FailMission('Błąd danych misji')
        return
    end
    
    local loc = data.location
    
    -- SPAWN NPC przy lokalizacji rozbiórki!
    SpawnMissionNPC(vector3(loc.x, loc.y, loc.z), loc.w or 0.0)
    
    SpawnDismantleVehicles(loc, data.vehicleModel)
    
    currentMission.stage = 'dismantle'
    currentMission.active = true
    currentMission.totalParts = #ConfigLocations.Stage3.parts
    currentMission.loadedParts = 0
    dismantledParts = {}
end

function SpawnDismantleVehicles(loc, model)
    local vehHash = GetHashKey(model)
    local busHash = GetHashKey(ConfigLocations.Stage3.busModel)
    
    RequestModel(vehHash)
    RequestModel(busHash)
    while not HasModelLoaded(vehHash) or not HasModelLoaded(busHash) do Wait(0) end
    
    dismantleVehicle = CreateVehicle(vehHash, loc.x, loc.y, loc.z, loc.w or 0.0, true, false)
    SetVehicleDoorsLocked(dismantleVehicle, 3)
    SetEntityInvincible(dismantleVehicle, true)
    
    local busCoords = GetOffsetFromEntityInCoords(dismantleVehicle, 5.0, 0.0, 0.0)
    busVehicle = CreateVehicle(busHash, busCoords.x, busCoords.y, busCoords.z, loc.w or 0.0, true, false)
    SetVehicleDoorsLocked(busVehicle, 3)
    
    SetupDismantlePoints()
    SetupBusTarget()
    
    print('^2[TRACKER CLIENT DEBUG]^0 Dismantle vehicles spawned')
end

function SetupDismantlePoints()
    dismantleZones = {}
    
    for _, part in ipairs(ConfigLocations.Stage3.parts) do
        local coords
        
        if part.bone then
            local bone = GetEntityBoneIndexByName(dismantleVehicle, part.bone)
            if bone ~= -1 then
                coords = GetWorldPositionOfEntityBone(dismantleVehicle, bone)
            end
        elseif part.offset then
            coords = GetOffsetFromEntityInCoords(dismantleVehicle, part.offset.x, part.offset.y, part.offset.z)
        end
        
        if coords then
            local zoneName = 'dismantle_' .. part.name
            
            exports.ox_target:addSphereZone({
                coords = coords,
                radius = 1.5,
                debug = false,
                options = {
                    {
                        name = zoneName,
                        label = string.format(ConfigTexts.Text3D.dismantle, part.label),
                        icon = 'fa-solid fa-wrench',
                        distance = 2.5,
                        canInteract = function()
                            return not dismantledParts[part.name] and currentMission and currentMission.active
                        end,
                        onSelect = function()
                            DismantlePart(part)
                        end
                    }
                }
            })
            
            table.insert(dismantleZones, zoneName)
        else
            print('^1[TRACKER CLIENT ERROR]^0 Could not get coords for part:', part.name)
        end
    end
    
    print('^2[TRACKER CLIENT DEBUG]^0 Setup', #dismantleZones, 'dismantle zones')
end

function DismantlePart(part)
    if dismantledParts[part.name] then return end
    
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, dismantleVehicle, 1000)
    Wait(1000)
    
    if lib.progressBar({
        duration = 8000,
        label = string.format('Demontaż: %s', part.label),
        useWhileDead = false,
        canCancel = true,
        disable = {move = true, car = true, combat = true},
        anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}
    }) then
        local success = lib.skillCheck({'medium', 'medium', 'hard'}, {'w', 'a', 's', 'd'})
        
        if success then
            dismantledParts[part.name] = true
            RemovePart(part)
            AttachProp(part)
            ShowNotification(string.format('Zdemontowano: %s\nZaładuj do busa', part.label), 'Część zdemontowana', 'success')
            
            local count = 0
            for _ in pairs(dismantledParts) do count = count + 1 end
            print('^3[TRACKER DEBUG]^0 Parts dismantled:', count, '/', currentMission.totalParts)
        else
            ShowNotification('Nie udało się zdemontować części', 'Porażka', 'error')
        end
    end
end

function RemovePart(part)
    if not DoesEntityExist(dismantleVehicle) then return end
    
    if part.name:find('door') then
        local idx = ({door_fl=0, door_fr=1, door_rl=2, door_rr=3})[part.name]
        if idx then SetVehicleDoorBroken(dismantleVehicle, idx, true) end
    elseif part.name == 'hood' then
        SetVehicleDoorBroken(dismantleVehicle, 4, true)
    elseif part.name == 'trunk' then
        SetVehicleDoorBroken(dismantleVehicle, 5, true)
    elseif part.name:find('wheel') then
        local idx = ({wheel_fl=0, wheel_fr=1, wheel_rl=4, wheel_rr=5})[part.name]
        if idx then SetVehicleTyreBurst(dismantleVehicle, idx, true, 1000.0) end
    end
end

function AttachProp(part)
    local model = GetHashKey('prop_ld_binbag_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    currentPart = {prop = prop, data = part}
end

function SetupBusTarget()
    exports.ox_target:addLocalEntity(busVehicle, {
        {
            name = 'load_part',
            label = ConfigTexts.Text3D.loadPart,
            icon = 'fa-solid fa-box',
            distance = 3.0,
            canInteract = function()
                return currentPart ~= nil and currentMission and currentMission.active
            end,
            onSelect = function()
                LoadPart()
            end
        }
    })
end

function LoadPart()
    if not currentPart then return end
    
    if lib.progressBar({
        duration = 3000,
        label = 'Ładowanie części do busa',
        useWhileDead = false,
        canCancel = false,
        disable = {move = true, car = true},
        anim = {dict = 'anim@heists@box_carry@', clip = 'idle'}
    }) then
        if DoesEntityExist(currentPart.prop) then
            DeleteEntity(currentPart.prop)
        end
        
        currentMission.loadedParts = (currentMission.loadedParts or 0) + 1
        ShowNotification(string.format('Załadowano %d/%d części', currentMission.loadedParts, currentMission.totalParts), 'Postęp', 'info')
        
        if currentMission.loadedParts >= currentMission.totalParts then
            AllPartsLoaded()
        end
        
        currentPart = nil
    end
end

function AllPartsLoaded()
    ShowNotification('Wszystkie części załadowane!\nJedź sprzedać bus z częściami', 'Gotowe', 'success')
    
    local sell = ConfigLocations.Stage3.sellPoints[math.random(#ConfigLocations.Stage3.sellPoints)]
    CreateSellMarker(sell)
end

function CreateSellMarker(coords)
    local blip = CreateWaypointBlip(coords)
    
    CreateThread(function()
        while currentMission and currentMission.active do
            Wait(0)
            
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local dist = #(pCoords - coords)
            
            if dist < 20.0 then
                DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 5.0, 5.0, 1.0, 255, 215, 0, 100, false, true, 2, false)
                
                if dist < 5.0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh == busVehicle then
                        ShowHelp('~INPUT_CONTEXT~ Sprzedaj części')
                        if IsControlJustPressed(0, 38) then
                            DeleteVehicle(busVehicle)
                            DeleteVehicle(dismantleVehicle)
                            RemoveBlip(blip)
                            CompleteMission()
                            break
                        end
                    end
                end
            end
        end
    end)
end

function CleanupStage3()
    -- Usuń wszystkie strefy ox_target
    for _, zoneName in ipairs(dismantleZones) do
        exports.ox_target:removeZone(zoneName)
    end
    dismantleZones = {}
    
    -- Usuń target z busa
    if DoesEntityExist(busVehicle) then
        exports.ox_target:removeLocalEntity(busVehicle, 'load_part')
        DeleteEntity(busVehicle)
    end
    
    if DoesEntityExist(dismantleVehicle) then 
        DeleteEntity(dismantleVehicle) 
    end
    
    if currentPart and DoesEntityExist(currentPart.prop) then 
        DeleteEntity(currentPart.prop) 
    end
    
    dismantleVehicle = nil
    busVehicle = nil
    currentPart = nil
    dismantledParts = {}
    
    print('^3[TRACKER CLIENT]^0 Stage 3 cleaned up')
end

-- ============================================
-- CLEANUP HANDLERS
-- ============================================

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if currentMission and currentMission.active then
            TriggerServerEvent('td_tracker:server:failMission', currentMission.type, 'Wylogowanie')
        end
        CleanupMission()
        RemoveNPC()
    end
end)

RegisterNetEvent('td_tracker:client:cancelMission', function()
    if currentMission and currentMission.active then
        FailMission('Anulowano')
    end
end)

print('^2[TRACKER CLIENT]^0 Main loaded with all stages')