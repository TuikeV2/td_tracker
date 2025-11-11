RegisterNetEvent('td_tracker:alertPolice')
AddEventHandler('td_tracker:alertPolice', function(coords, stage)
    local xPlayers = ESX.GetExtendedPlayers('job', 'police')
    for _, xPlayer in pairs(xPlayers) do
        TriggerClientEvent('cd_dispatch:AddNotification', xPlayer.source, {
            job_table = {'police'},
            coords = coords,
            title = '10-35 - Kradzież pojazdu',
            message = 'Zgłoszono kradzież pojazdu'
        })
    end
end)
