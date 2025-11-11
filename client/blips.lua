local activeBlips = {}

function CreateSearchAreaBlip(center, radius)
    if not center then
        print('^1[TRACKER CLIENT ERROR]^0 CreateSearchAreaBlip: center is nil')
        return nil
    end

    local area = AddBlipForRadius(center.x, center.y, center.z, radius)
    SetBlipColour(area, ConfigBlips.SearchArea.color)
    SetBlipAlpha(area, ConfigBlips.SearchArea.alpha or 128)

    local marker = AddBlipForCoord(center.x, center.y, center.z)
    SetBlipSprite(marker, ConfigBlips.SearchArea.sprite)
    SetBlipScale(marker, ConfigBlips.SearchArea.scale)
    SetBlipColour(marker, ConfigBlips.SearchArea.color)
    SetBlipAsShortRange(marker, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(ConfigBlips.SearchArea.name)
    EndTextCommandSetBlipName(marker)

    table.insert(activeBlips, area)
    table.insert(activeBlips, marker)

    print('^2[TRACKER CLIENT]^0 Search area blip created (red, alpha:', ConfigBlips.SearchArea.alpha or 128, ')')

    return {area = area, marker = marker}
end

function CreateWaypointBlip(coords)
    if not coords then 
        print('^1[TRACKER CLIENT ERROR]^0 CreateWaypointBlip: coords is nil')
        return nil
    end
    
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, ConfigBlips.DeliveryPoint.sprite)
    SetBlipScale(blip, ConfigBlips.DeliveryPoint.scale)
    SetBlipColour(blip, ConfigBlips.DeliveryPoint.color)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, ConfigBlips.DeliveryPoint.color)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(ConfigBlips.DeliveryPoint.name)
    EndTextCommandSetBlipName(blip)
    
    table.insert(activeBlips, blip)
    
    print('^2[TRACKER CLIENT]^0 Waypoint blip created')
    
    return blip
end

function RemoveAllBlips()
    local count = 0
    for _, blip in ipairs(activeBlips) do
        if DoesBlipExist(blip) then 
            RemoveBlip(blip)
            count = count + 1
        end
    end
    activeBlips = {}
    
    if count > 0 then
        print('^3[TRACKER CLIENT]^0 Removed', count, 'blips')
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then 
        RemoveAllBlips() 
    end
end)