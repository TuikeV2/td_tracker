-- TuikeDevelopments - Vehicles Config

ConfigVehicles = {}

ConfigVehicles.Stage1Models = {
    'sultan',
    'kuruma',
    'fugitive',
    'tailgater',
    'felon',
    'oracle',
    'schwarzer',
    'jackal',
    'sentinel',
    'dubsta'
}

ConfigVehicles.Stage2Models = {
    'baller',
    'cavalcade',
    'granger',
    'huntley',
    'landstalker',
    'mesa',
    'patriot',
    'radius',
    'rocoto',
    'seminole'
}

ConfigVehicles.Stage3Models = {
    'zentorno',
    'entityxf',
    'turismor',
    't20',
    'osiris',
    'reaper',
    'xa21',
    'vagner',
    'cyclone',
    'visione'
}

ConfigVehicles.DecoySimilarity = {
    letters = 2,
    numbers = 3
}

ConfigVehicles.PlateFormats = {
    'ABC 123',
    'XYZ 456',
    'DEF 789',
    'GHI 012',
    'JKL 345',
    'MNO 678',
    'PQR 901',
    'STU 234',
    'VWX 567',
    'YZA 890'
}

function ConfigVehicles.GeneratePlate()
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local plate = ''
    
    for i = 1, 3 do
        plate = plate .. letters:sub(math.random(1, #letters), math.random(1, #letters))
    end
    
    plate = plate .. ' '
    
    for i = 1, 4 do
        plate = plate .. math.random(0, 9)
    end
    
    return plate
end

function ConfigVehicles.GenerateSimilarPlates(originalPlate, count)
    local plates = {originalPlate}
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local nums = '0123456789'
    
    while #plates < count do
        local newPlate = originalPlate
        local changeType = math.random(1, 2)
        local pos = math.random(1, #originalPlate)
        
        if changeType == 1 and originalPlate:sub(pos, pos):match('%a') then
            local randLetter = letters:sub(math.random(1, #letters), math.random(1, #letters))
            newPlate = originalPlate:sub(1, pos-1) .. randLetter .. originalPlate:sub(pos+1)
        elseif changeType == 2 and originalPlate:sub(pos, pos):match('%d') then
            local randNum = nums:sub(math.random(1, #nums), math.random(1, #nums))
            newPlate = originalPlate:sub(1, pos-1) .. randNum .. originalPlate:sub(pos+1)
        end
        
        if newPlate ~= originalPlate and not table.contains(plates, newPlate) then
            table.insert(plates, newPlate)
        end
    end
    
    return plates
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end
