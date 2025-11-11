-- [[ TD Tracker - Client Main ]] --
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
-- PODSTAWOWE ZMIENNE NPC/BLIP
-- ============================================

local npcEntity = nil
local npcBlip = nil
local areaBlip = nil
local activeNPC = nil

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    playerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    playerData.job = job
end)

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
-- CZYSZCZENIE NPC (SKONSOLIDOWANA FUNKCJA)
-- ============================================

function RemoveNPC()
    if npcEntity and DoesEntityExist(npcEntity) then
        pcall(function()
            exports.ox_target:removeLocalEntity(npcEntity) 
            Wait(200)
        end)
        DeleteEntity(npcEntity)
        npcEntity = nil
    end

    if activeNPC and DoesEntityExist(activeNPC) then
        pcall(function()
            DeleteEntity(activeNPC)
            activeNPC = nil
        end)
    end

    if npcBlip and DoesBlipExist(npcBlip) then
        RemoveBlip(npcBlip)
        npcBlip = nil
    end
    if areaBlip and DoesBlipExist(areaBlip) then
        RemoveBlip(areaBlip)
        areaBlip = nil
    end
    print('^3[TRACKER CLIENT]^0 NPC(s) removed and cleanup attempted')
end

-- ============================================
-- FUNKCJE SPAWNOWANIA I TARGETU GŁÓWNEGO NPC
-- ============================================

local currentNPCLocation = nil

function SpawnMissionGiver()
    if activeNPC and DoesEntityExist(activeNPC) then
        exports.ox_target:removeLocalEntity(activeNPC)
        DeleteEntity(activeNPC)
        activeNPC = nil
    end

    local locations = ConfigMissions.NPCLocations
    if not locations or #locations == 0 then
        print('^1[TRACKER CLIENT]^0 Błąd: Brak konfiguracji NPCLocations w missions.lua.')
        return
    end

    currentNPCLocation = locations[math.random(1, #locations)]
    local coords = currentNPCLocation.coords
    local model = GetHashKey(currentNPCLocation.model)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    -- Spawnowanie NPC
    activeNPC = CreatePed(2, model, coords.x, coords.y, coords.z - 1.0, currentNPCLocation.heading, false, false)
    SetPedFleeAttributes(activeNPC, 0, false)
    SetPedDiesWhenInjured(activeNPC, false)
    SetPedCanRagdoll(activeNPC, false)
    SetEntityInvincible(activeNPC, true)
    FreezeEntityPosition(activeNPC, true)
    SetModelAsNoLongerNeeded(model)

    -- Animacja
    local anim = currentNPCLocation.animation
    if anim and anim.dict and anim.name then
        RequestAnimDict(anim.dict)
        while not HasAnimDictLoaded(anim.dict) do
            Wait(10)
        end
        TaskPlayAnim(activeNPC, anim.dict, anim.name, 8.0, 1.0, -1, 1, 0, false, false, false)
        RemoveAnimDict(anim.dict)
    end

    -- Dodanie interakcji z ox_lib (używa E zamiast ALT)
    local npcPoint = lib.points.new({
        coords = coords,
        distance = 2.5,
        npc = activeNPC
    })

    function npcPoint:onEnter()
        lib.showTextUI('[E] Zapytaj o robotę', {
            position = "left-center",
            icon = 'fas fa-handshake'
        })
    end

    function npcPoint:onExit()
        lib.hideTextUI()
    end

    function npcPoint:nearby()
        if IsControlJustReleased(0, 38) then -- E key
            if currentMission and currentMission.active then
                lib.notify({title = 'TD Tracker', description = 'Już masz aktywną misję!', type = 'error'})
                return
            end

            -- Wysłanie żądania na serwer o listę dostępnych misji dla gracza
            TriggerServerEvent('td_tracker:server:getAvailableStages')
        end
    end

    print(string.format('^2[TRACKER CLIENT]^0 NPC (Quest Giver) spawned at %s', tostring(coords)))
end

-- ============================================
-- OBSŁUGA WYBORU MISJI (OX_LIB)
-- ============================================

RegisterNetEvent('td_tracker:client:showMissionSelection', function(availableStages)
    if not availableStages or #availableStages == 0 then
        lib.notify({
            title = 'TD Tracker',
            description = 'Twoja reputacja jest zbyt niska, by podjąć misję.',
            type = 'error'
        })
        return
    end

    local options = {}

    -- Tworzenie opcji menu z dostępnych etapów (Stages)
    for _, stage in ipairs(availableStages) do
        local config = Config.Stages[stage]
        if config then
             table.insert(options, {
                title = 'Etap ' .. stage .. ' - ' .. config.name,
                description = 'Wymagana Reputacja: ' .. config.minReputation .. ' | Szansa na A-B: ' .. config.chanceToAorB .. '%',
                icon = 'fas fa-layer-group',
                onSelect = function()
                    TriggerServerEvent('td_tracker:server:requestMissionStart', stage)
                end
             })
        end
    end

    table.insert(options, {
        title = 'Anuluj',
        icon = 'fas fa-times',
        onSelect = function()
            lib.notify({title = 'TD Tracker', description = 'Anulowano wybór misji.', type = 'info'})
        end
    })

    lib.registerContext({
        id = 'td_tracker_mission_selection',
        title = 'Wybierz Rodzaj Roboty',
        options = options
    })

    lib.showContext('td_tracker_mission_selection')
end)

-- ============================================
-- SPAWN NPC PODCZAS MISJI
-- ============================================

function SpawnMissionNPC(coords, heading)
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
    SetBlipColour(npcBlip, 5)
    SetBlipRoute(npcBlip, true)
    SetBlipRouteColour(npcBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Kontakt')
    EndTextCommandSetBlipName(npcBlip)
    
    print('^2[TRACKER CLIENT]^0 Mission NPC spawned with waypoint')
    
    -- Zmieniona nazwa, aby nie nadpisywać funkcji dla głównego NPC
    CreateMissionStageNPCInteraction(npcEntity, coords) 
    
    -- Notyfikacja dla gracza
    if currentMission then
        if currentMission.type == 1 then
            ShowNotification('📍 Udaj się do punktu poszukiwań pojazdu (żółty marker na mapie)', 'Etap 1: Kradzież', 'info')
        elseif currentMission.type == 2 then
            ShowNotification('📍 Jedź do kontaktu po pojazd (żółty marker na mapie)', 'Etap 2: Transport', 'info')
        elseif currentMission.type == 3 then
            ShowNotification('📍 Jedź do punktu rozbiórki (żółty marker na mapie)', 'Etap 3: Rozbiórka', 'info')
        end
    end
end


-- ============================================
-- INTERAKCJE Z NPC NA ETAPACH MISJI
-- ============================================
function CreateMissionStageNPCInteraction(npc, coords)
    if not npc or not DoesEntityExist(npc) then
        print("CreateMissionStageNPCInteraction: npc nie istnieje")
        return
    end

    local interactionDistance = 3.0

    local function buildOptions()
        local options = {}

        if currentMission and currentMission.active then
            if currentMission.type == 1 then
                -- Etap 1: Kradzież
                table.insert(options, {
                    name = 'npc_stage1_info',
                    label = '💬 Porozmawiaj z kontaktem',
                    icon = 'fa-solid fa-user-secret',
                    distance = interactionDistance,
                    onSelect = function()
                        local alert = lib.alertDialog({
                            header = 'Zlecenie: Kradzież',
                            content = 'Znajdź i ukradnij pojazd o podanych tablicach rejestracyjnych.\n\n🚨 Policja będzie ostrzeżona!\n🎯 Unikaj pościgu i dostarcz pojazd do wyznaczonego punktu.',
                            centered = true,
                            cancel = true,
                            labels = {confirm = 'Rozumiem', cancel = 'Anuluj'}
                        })
                        if alert == 'confirm' then
                            print('Gracz potwierdził etap 1: Kradzież')
                        end
                    end
                })

            elseif currentMission.type == 2 then
                table.insert(options, {
                    name = 'npc_stage2_info',
                    label = '💬 Porozmawiaj z kontaktem',
                    icon = 'fa-solid fa-handshake',
                    distance = interactionDistance,
                    onSelect = function()
                        print('^3[TRACKER DEBUG]^0 Stage 2 NPC interaction - showing dialog')

                        CreateThread(function()
                            local alert = lib.alertDialog({
                                header = 'Zlecenie: Transport',
                                content = 'Odbierz ten pojazd i dostarcz go do kryjówki.\n\n⚠️ Policja będzie ostrzeżona!\n🎯 Unikaj pościgu i jedź do punktu na mapie.',
                                centered = true,
                                cancel = true,
                                labels = {confirm = 'Rozumiem', cancel = 'Anuluj'}
                            })

                            print('^3[TRACKER DEBUG]^0 Dialog response:', alert)

                            if alert == 'confirm' then
                                print('^2[TRACKER]^0 Gracz potwierdził etap 2: Transport - spawning vehicle')
                                print('^3[TRACKER DEBUG]^0 currentMission.spawnPoint:', json.encode(currentMission.spawnPoint))
                                print('^3[TRACKER DEBUG]^0 currentMission.vehicleModel:', currentMission.vehicleModel)

                                local spawnPoint = currentMission.spawnPoint
                                local vehicleModel = currentMission.vehicleModel
                                local deliveryPoint = currentMission.deliveryPoint

                                RemoveNPC()
                                SpawnTransportVehicle(spawnPoint, vehicleModel, deliveryPoint)
                                currentMission.stage = 'pickup'
                                print('^2[TRACKER]^0 Stage changed to pickup')
                            else
                                print('^1[TRACKER]^0 Dialog cancelled or closed')
                            end
                        end)
                    end
                })

            elseif currentMission.type == 3 then
                table.insert(options, {
                    name = 'npc_stage3_info',
                    label = '💬 Porozmawiaj z kontaktem',
                    icon = 'fa-solid fa-wrench',
                    distance = interactionDistance,
                    onSelect = function()
                        print('^3[TRACKER DEBUG]^0 Stage 3 NPC interaction - showing dialog')

                        CreateThread(function()
                            local alert = lib.alertDialog({
                                header = 'Zlecenie: Rozbiórka',
                                content = 'Rozmontuj ten pojazd na części.\n\n🔨 Kliknij na każdą część pojazdu aby ją zdemontować\n📦 Załaduj części do busa\n💰 Dostarcz bus z częściami do punktu sprzedaży',
                                centered = true,
                                cancel = true,
                                labels = {confirm = 'Rozumiem', cancel = 'Anuluj'}
                            })

                            print('^3[TRACKER DEBUG]^0 Dialog response:', alert)

                            if alert == 'confirm' then
                                print('^2[TRACKER]^0 Gracz potwierdził etap 3: Rozbiórka - spawning vehicles')
                                print('^3[TRACKER DEBUG]^0 currentMission.location:', json.encode(currentMission.location))
                                print('^3[TRACKER DEBUG]^0 currentMission.vehicleModel:', currentMission.vehicleModel)

                                local location = currentMission.location
                                local vehicleModel = currentMission.vehicleModel

                                RemoveNPC()
                                SpawnDismantleVehicles(location, vehicleModel)
                                currentMission.stage = 'dismantle'
                                print('^2[TRACKER]^0 Stage changed to dismantle')
                            else
                                print('^1[TRACKER]^0 Dialog cancelled or closed')
                            end
                        end)
                    end
                })
            end
        end

        return options
    end

    -- ✅ Rejestracja w ox_target
    local options = buildOptions()
    if #options > 0 then
        exports.ox_target:addLocalEntity(npc, options)
        print(string.format('^2[TRACKER CLIENT]^0 Mission Stage NPC ox_target added for stage %s', currentMission and currentMission.type or "unknown"))
    end

    -- 🔸 Fallback: Text3D + klawisz [E]
    CreateThread(function()
        while DoesEntityExist(npc) do
            Wait(0)
            
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - coords)

            if dist < 3.0 then
                -- Wyświetl 3D tekst (jeśli masz taką funkcję)
                if ConfigBlips and ConfigBlips.Text3D and ConfigBlips.Text3D.enabled and dist < ConfigBlips.Text3D.distance then
                    DrawText3D(coords.x, coords.y, coords.z + 1.0, ConfigTexts.Text3D.npc)
                else
                    lib.showTextUI('[E] - Porozmawiaj z NPC', {icon = 'fa-solid fa-comments'})
                end
                lib.hideTextUI()

                if IsControlJustPressed(0, 38) then -- E
                    local header, content = '', ''

                    if currentMission and currentMission.type == 1 then
                        header = '🚗 Zlecenie: Kradzież'
                        content = 'Znajdź i ukradnij pojazd o podanych tablicach.\n🚨 Policja będzie ostrzeżona!\n🎯 Dostarcz pojazd do punktu.'
                    elseif currentMission and currentMission.type == 2 then
                        header = '🚗 Zlecenie: Transport'
                        content = 'Odbierz pojazd i dostarcz do kryjówki.\n⚠️ Policja będzie ostrzeżona!\n🎯 Jedź do punktu na mapie.'
                    elseif currentMission and currentMission.type == 3 then
                        header = '🔧 Zlecenie: Rozbiórka'
                        content = 'Rozmontuj pojazd na części i dostarcz do punktu sprzedaży.'
                    else
                        header = '📜 Informacja'
                        content = 'NPC potwierdza zlecenie.'
                    end

                    local alert = lib.alertDialog({
                        header = header,
                        content = content,
                        centered = true,
                        cancel = true,
                        labels = {confirm = 'OK', cancel = 'Anuluj'}
                    })

                    if alert == 'confirm' then
                        print('Dialog potwierdzony przez gracza')
                    end
                end
            end
        end
    end)
end

function ShowNotification(msg, title, type)
    lib.notify({
        title = title or 'Tracker',
        description = msg,
        type = type or 'info'
    })
end

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function ShowHelp(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function FormatTime(sec)
    local min = math.floor(sec / 60)
    local s = sec % 60
    return string.format('%02d:%02d', min, s)
end

function SpawnNPC()
    local cfg = ConfigLocations.NPCSpawns[math.random(#ConfigLocations.NPCSpawns)]
    
    RequestModel(GetHashKey(cfg.model))
    while not HasModelLoaded(GetHashKey(cfg.model)) do Wait(0) end
    
    local npc = CreatePed(4, GetHashKey(cfg.model), cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.heading, false, true)
    
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
    
    if cfg.anim then
        RequestAnimDict(cfg.anim.dict)
        while not HasAnimDictLoaded(cfg.anim.dict) do Wait(0) end
        TaskPlayAnim(npc, cfg.anim.dict, cfg.anim.name, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
    
    activeNPC = {
        ped = npc,
        coords = cfg.coords,
        attempts = 0
    }
    
    -- Zmieniona nazwa, aby nie nadpisywać funkcji dla etapów misji
    CreateMainNPCInteraction() 
    return npc
end


function CreateMainNPCInteraction()
    if not activeNPC then return end
    
    local npc = activeNPC.ped
    -- Właściwa rejestracja ox_target dla głównego NPC, który uruchamia dialog
    exports.ox_target:addLocalEntity(npc, {
        {
            name = 'npc_mission_start',
            label = '💰 Rozpocznij Zlecenie',
            icon = 'fa-solid fa-handshake',
            distance = 2.0,
            onSelect = function()
                TriggerServerEvent('td_tracker:server:requestDialog')
            end
        }
    })
    
    CreateThread(function()
        while activeNPC do
            Wait(0)
            
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local dist = #(coords - activeNPC.coords)
            
            if ConfigBlips.Text3D.enabled and dist < ConfigBlips.Text3D.distance then
                DrawText3D(activeNPC.coords.x, activeNPC.coords.y, activeNPC.coords.z + 1.0, ConfigTexts.Text3D.npc)
                
                if dist < 2.0 and IsControlJustPressed(0, 38) then
                    TriggerServerEvent('td_tracker:server:requestDialog')
                end
            end
        end
    end)
end

RegisterNetEvent('td_tracker:client:showDialog', function(rep, stages)
    if IsPolice() then
        lib.alertDialog({
            header = ConfigTexts.Dialogs.policeWarning.title,
            content = ConfigTexts.Dialogs.policeWarning.description,
            centered = true,
            labels = {confirm = 'Zakończ'}
        })
        return
    end
    
    local stageText = table.concat(stages, ', ')
    local options = {}
    
    for _, stage in ipairs(stages) do
        local cfg = ConfigTexts.Context['stage' .. stage]
        table.insert(options, {
            title = cfg.title,
            description = cfg.description,
            icon = cfg.icon,
            onSelect = function()
                TriggerServerEvent('td_tracker:server:startMission', stage)
            end
        })
    end
    
    table.insert(options, {
        title = ConfigTexts.Context.close.title,
        icon = ConfigTexts.Context.close.icon
    })
    
    lib.registerContext({
        id = 'td_tracker_menu',
        title = string.format(ConfigTexts.Dialogs.npcGreeting.description, rep, stageText),
        options = options
    })
    
    lib.showContext('td_tracker_menu')
end)

RegisterNetEvent('td_tracker:client:insufficientRep', function(req, cur)
    if not activeNPC then return end
    
    activeNPC.attempts = activeNPC.attempts + 1
    
    ShowNotification(string.format(ConfigTexts.Dialogs.insufficientRep.description, req, cur), ConfigTexts.Dialogs.insufficientRep.title, 'error')
    
    if activeNPC.attempts >= Config.NPCAttemptsBeforeShooting then
        MakeNPCHostile()
    else
        ShowNotification(string.format(ConfigTexts.Notifications.npcAngry.description, activeNPC.attempts, Config.NPCAttemptsBeforeShooting), ConfigTexts.Notifications.npcAngry.title, 'warning')
    end
end)

function MakeNPCHostile()
    if not activeNPC or not DoesEntityExist(activeNPC.ped) then return end
    
    local npc = activeNPC.ped
    local ped = PlayerPedId()
    
    SetEntityInvincible(npc, false)
    SetBlockingOfNonTemporaryEvents(npc, false)
    FreezeEntityPosition(npc, false)
    
    GiveWeaponToPed(npc, GetHashKey('WEAPON_PISTOL'), 250, false, true)
    TaskCombatPed(npc, ped, 0, 16)
    
    ShowNotification('NPC zaatakował!', 'Uwaga', 'error')
    
    SetTimeout(30000, function()
        if DoesEntityExist(npc) then DeleteEntity(npc) end
        activeNPC = nil
    end)
end


AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then RemoveNPC() end
end)
function ShowNPCDialog(reputation, attempts, npc)
    if IsPolice() then
        lib.alertDialog({
            header = ConfigTexts.Dialogs.policeWarning.title,
            content = ConfigTexts.Dialogs.policeWarning.description,
            centered = true,
            cancel = false,
            labels = {confirm = 'Zakończ'}
        })
        return
    end
    
    if currentMission and currentMission.active then
        lib.alertDialog({
            header = 'Masz już zlecenie',
            content = 'Dokończ obecne zlecenie zanim weźmiesz kolejne.',
            centered = true,
            cancel = false,
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
        
        local description = stageConfig.description .. '\n\n' ..
            '💰 Nagroda: $' .. rewardConfig.money.min .. '-' .. rewardConfig.money.max .. '\n' ..
            '⭐ Reputacja: +' .. rewardConfig.reputation.min .. '-' .. rewardConfig.reputation.max .. '\n' ..
            '⏱️ Czas: ~' .. math.floor(Config.MissionTimeLimit[stage] / 60000) .. ' min'
        
        table.insert(options, {
            title = stageConfig.title,
            description = description,
            icon = stageConfig.icon,
            onSelect = function()
                local alert = lib.alertDialog({
                    header = stageConfig.title,
                    content = 'Czy na pewno chcesz rozpocząć to zlecenie?',
                    centered = true,
                    cancel = true,
                    labels = {confirm = 'Tak', cancel = 'Nie'}
                })
                if alert == 'confirm' then
                    print('^2[TRACKER CLIENT]^0 Player selected stage:', stage)
                    TriggerServerEvent('td_tracker:server:startMission', stage)
                    RemoveNPC()
                end
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
        header = '📊 Twoje statystyki',
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
        cancel = false,
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
            -- Wyczyść wszystkie targety dla tego pojazdu
            exports.ox_target:removeLocalEntity(veh)
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

    currentMission.stage = 'talk_to_npc'
    currentMission.active = true
    currentMission.deliveryPoint = hideout
    currentMission.vehicleModel = data.vehicleModel
    currentMission.spawnPoint = spawn

    SpawnMissionNPC(vector3(spawn.x, spawn.y, spawn.z), spawn.w or 0.0)

    print('^2[TRACKER CLIENT DEBUG]^0 Stage 2 initialized - waiting for NPC interaction')
end

function SpawnTransportVehicle(spawn, model, hideout)
    print('^3[TRACKER DEBUG]^0 SpawnTransportVehicle called')
    print('^3[TRACKER DEBUG]^0 spawn:', json.encode(spawn))
    print('^3[TRACKER DEBUG]^0 model:', model)

    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    transportVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    SetVehicleDoorsLocked(transportVehicle, 1)
    SetVehicleEngineOn(transportVehicle, false, true, false)

    currentMission.targetVehicle = transportVehicle
    print('^2[TRACKER DEBUG]^0 Transport vehicle spawned:', transportVehicle)
    
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
        exports.ox_target:removeLocalEntity(transportVehicle) -- Wyczyść target na wszelki wypadek
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

    currentMission.stage = 'talk_to_npc'
    currentMission.active = true
    currentMission.totalParts = #ConfigLocations.Stage3.parts
    currentMission.loadedParts = 0
    currentMission.location = loc
    currentMission.vehicleModel = data.vehicleModel
    dismantledParts = {}

    SpawnMissionNPC(vector3(loc.x, loc.y, loc.z), loc.w or 0.0)

    print('^2[TRACKER CLIENT DEBUG]^0 Stage 3 initialized - waiting for NPC interaction')
end

function SpawnDismantleVehicles(loc, model)
    print('^3[TRACKER DEBUG]^0 SpawnDismantleVehicles called')
    print('^3[TRACKER DEBUG]^0 loc:', json.encode(loc))
    print('^3[TRACKER DEBUG]^0 model:', model)

    local vehHash = GetHashKey(model)
    local busHash = GetHashKey(ConfigLocations.Stage3.busModel)

    RequestModel(vehHash)
    RequestModel(busHash)
    while not HasModelLoaded(vehHash) or not HasModelLoaded(busHash) do Wait(0) end

    dismantleVehicle = CreateVehicle(vehHash, loc.x, loc.y, loc.z, loc.w or 0.0, true, false)
    SetVehicleDoorsLocked(dismantleVehicle, 3)
    SetEntityInvincible(dismantleVehicle, true)
    print('^2[TRACKER DEBUG]^0 Dismantle vehicle spawned:', dismantleVehicle)

    local busCoords = GetOffsetFromEntityInWorldCoords(dismantleVehicle, 5.0, 0.0, 0.0)
    busVehicle = CreateVehicle(busHash, busCoords.x, busCoords.y, busCoords.z, loc.w or 0.0, true, false)
    SetVehicleDoorsLocked(busVehicle, 3)
    print('^2[TRACKER DEBUG]^0 Bus vehicle spawned:', busVehicle)

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
            coords = GetOffsetFromEntityInWorldCoords(dismantleVehicle, part.offset.x, part.offset.y, part.offset.z)
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
        exports.ox_target:removeLocalEntity(busVehicle)
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

-- Funkcja anulowania misji z potwierdzeniem
function CancelMissionWithConfirmation()
    if not currentMission or not currentMission.active then
        lib.notify({
            title = 'TD Tracker',
            description = 'Nie masz aktywnej misji',
            type = 'error'
        })
        return
    end

    local alert = lib.alertDialog({
        header = '⚠️ Anuluj misję',
        content = string.format('Czy na pewno chcesz anulować misję?\n\n**Kara:** -%d reputacji\n**Aktywna misja:** Etap %d - %s',
            ConfigRewards.FailurePenalty[currentMission.type] or 20,
            currentMission.type,
            Config.Stages[currentMission.type].name
        ),
        centered = true,
        cancel = true,
        labels = {confirm = 'Anuluj misję', cancel = 'Kontynuuj misję'}
    })

    if alert == 'confirm' then
        print('^1[TRACKER]^0 Player manually cancelled mission')
        FailMission('Anulowano ręcznie')
    end
end

-- Komenda do anulowania misji (dla gracza)
RegisterCommand('cancelmission', function()
    CancelMissionWithConfirmation()
end, false)

RegisterNetEvent('td_tracker:client:spawnNPC', function()
    SpawnMissionGiver()
    lib.notify({
        title = 'TD Tracker',
        description = 'Zleceniodawca zespawnowany! Szukaj go w okolicy',
        type = 'success'
    })
end)

print('^2[TRACKER CLIENT]^0 Main loaded with all stages')