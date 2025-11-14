-- ============================================
-- TD TRACKER - POLICE SYSTEM
-- ============================================

local ESX = exports['es_extended']:getSharedObject()

print('^2[TD TRACKER]^0 Police system loaded')

-- ============================================
-- FUNKCJA POWIADAMIANIA POLICJI (LB_TABLET)
-- ============================================

function NotifyPolice(coords, stage, vehicleModel, targetSource)
    if not Config.Police or not Config.Police.dispatchEnabled then
        if Config.Debug then print('^3[TRACKER POLICE]^0 Dispatch disabled in config') end
        return
    end

    local message = Config.Police.dispatchMessage['stage' .. stage] or 'Zgłoszenie'
    local code = Config.Police.dispatchCode or '10-35'

    print(string.format('^2[TRACKER POLICE]^0 Sending dispatch: %s at %s', message, coords))

    -- Pobierz wszystkich graczy
    local xPlayers = ESX.GetExtendedPlayers()

    for _, xTarget in pairs(xPlayers) do
        -- Sprawdź czy gracz ma job policji
        for _, policeJob in pairs(Config.Police.policeJobs) do
            if xTarget.job.name == policeJob then
                -- Wyślij alert do lb_tablet
                TriggerClientEvent('td_tracker:policeAlert', xTarget.source, {
                    coords = coords,
                    vehicle = vehicleModel or 'Nieznany',
                    message = message,
                    code = code,
                    stage = stage
                })

                print(string.format('^2[TRACKER POLICE]^0 Alert sent to %s (ID: %d)', xTarget.getName(), xTarget.source))
            end
        end
    end

    -- Wywołaj pościg NPC jeśli włączony i jest mniej niż wymagana liczba policjantów
    if Config.NPCChase and Config.NPCChase.enabled and targetSource then
        -- Policz graczy na służbie policji
        local policeCount = 0
        for _, xTarget in pairs(xPlayers) do
            for _, policeJob in pairs(Config.Police.policeJobs) do
                if xTarget.job.name == policeJob then
                    policeCount = policeCount + 1
                    break
                end
            end
        end

        print(string.format('^3[TRACKER POLICE]^0 Police players online: %d / min required: %d', policeCount, Config.NPCChase.minPolicePlayersForNPCDisable))

        if policeCount < Config.NPCChase.minPolicePlayersForNPCDisable then
            TriggerClientEvent('td_tracker:startNPCChase', targetSource, {
                coords = coords,
                stage = stage
            })
            print(string.format('^2[TRACKER POLICE]^0 NPC chase started for player %d', targetSource))
        else
            print(string.format('^3[TRACKER POLICE]^0 NPC chase disabled - enough police online (%d)', policeCount))
        end
    end
end

-- Export funkcji dla innych skryptów
exports('NotifyPolice', NotifyPolice)

print('^2[TD TRACKER]^0 Police notifications ready')
