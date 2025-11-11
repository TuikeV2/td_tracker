-- ============================================
-- TD TRACKER - CLIENT POLICE ALERTS (LB_TABLET)
-- ============================================

print('^2[TD TRACKER]^0 Police client loaded')

-- ============================================
-- OBSŁUGA ALERTU DLA POLICJI
-- ============================================

RegisterNetEvent('td_tracker:policeAlert', function(data)
    if not data then return end

    print(string.format('^2[TRACKER POLICE]^0 Received alert: %s at %s', data.message, data.coords))

    -- Sprawdź czy lb_tablet istnieje
    if not exports['lb_tablet'] then
        print('^1[TRACKER POLICE ERROR]^0 lb_tablet not found!')
        return
    end

    -- Wyślij powiadomienie do lb_tablet
    exports['lb_tablet']:sendNotification({
        title = data.code .. ' - TD Tracker',
        message = data.message,
        icon = 'car',
        duration = 10000
    })

    -- Dodaj blip na mapie
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(blip, 229) -- Ikona pojazdu
    SetBlipColour(blip, 1) -- Czerwony
    SetBlipScale(blip, 1.2)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.message)
    EndTextCommandSetBlipName(blip)

    -- Dodaj radius blip (okrąg)
    local radiusBlip = AddBlipForRadius(data.coords.x, data.coords.y, data.coords.z, 150.0)
    SetBlipColour(radiusBlip, 1)
    SetBlipAlpha(radiusBlip, 100)

    -- Usuń blip po 5 minutach
    SetTimeout(300000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        if DoesBlipExist(radiusBlip) then
            RemoveBlip(radiusBlip)
        end
    end)

    print('^2[TRACKER POLICE]^0 Alert displayed on map and tablet')
end)

print('^2[TD TRACKER]^0 Police alerts ready')
