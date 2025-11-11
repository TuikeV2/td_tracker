local activeNPC = nil

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
    
    CreateNPCInteraction()
    return npc
end

function CreateNPCInteraction()
    if not activeNPC then return end
    
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

function RemoveNPC()
    if activeNPC and DoesEntityExist(activeNPC.ped) then
        DeleteEntity(activeNPC.ped)
    end
    activeNPC = nil
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then RemoveNPC() end
end)