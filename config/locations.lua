ConfigLocations = {}

-- NPC Spawns
ConfigLocations.NPCSpawns = {
    {
        coords = vector3(707.95, -966.32, 30.41),
        heading = 90.0,
        model = 'a_m_m_business_01',
        anim = {dict = 'amb@world_human_smoking@male@male_a@idle_a', name = 'idle_a'}
    }
}

-- STAGE 1: Kradzież
ConfigLocations.Stage1 = {
    searchAreas = {
        {name = 'Legion Square', center = vector3(195.0, -933.0, 30.0), radius = 150.0},
        {name = 'Pillbox Hill', center = vector3(85.0, -1960.0, 21.0), radius = 150.0},
        {name = 'Vespucci', center = vector3(-1037.0, -2735.0, 20.0), radius = 150.0}
    },
    vehicles = {'sultan', 'futo', 'blista', 'dilettante', 'issi2'},
    deliveryPoints = {
        vector3(2340.0, 3054.0, 48.0),
        vector3(1737.0, 3710.0, 34.0),
        vector3(-106.0, 6528.0, 30.0)
    }
}

-- STAGE 2: Transport (UPEWNIJ SIĘ ŻE TO JEST!)
ConfigLocations.Stage2 = {
    vehicleSpawns = {
        vector4(2340.0, 3054.0, 48.0, 90.0),
        vector4(1737.0, 3710.0, 34.0, 180.0),
        vector4(-106.0, 6528.0, 30.0, 270.0),
        vector4(1392.0, 3608.0, 38.0, 200.0),
        vector4(-1153.0, -1425.0, 4.0, 120.0)
    },
    hideouts = {
        vector3(2522.0, 4100.0, 38.0),
        vector3(1737.0, 3710.0, 34.0),
        vector3(-106.0, 6528.0, 30.0),
        vector3(1392.0, 3608.0, 38.0)
    },
    vehicles = {'baller', 'dubsta', 'cavalcade', 'patriot', 'granger'}
}

-- STAGE 3: Rozbiórka (UPEWNIJ SIĘ ŻE TO JEST!)
ConfigLocations.Stage3 = {
    dismantleLocations = {
        vector4(2340.0, 3054.0, 48.0, 90.0),
        vector4(1737.0, 3710.0, 34.0, 180.0),
        vector4(-106.0, 6528.0, 30.0, 270.0)
    },
    vehicles = {'baller', 'dubsta', 'cavalcade', 'patriot'},
    busModel = 'boxville2',
    sellPoints = {
        vector3(2522.0, 4100.0, 38.0),
        vector3(1392.0, 3608.0, 38.0),
        vector3(-1153.0, -1425.0, 4.0)
    },
    parts = {
        {name = 'door_fl', label = 'Drzwi przednie lewe', bone = 'door_dside_f'},
        {name = 'door_fr', label = 'Drzwi przednie prawe', bone = 'door_pside_f'},
        {name = 'door_rl', label = 'Drzwi tylne lewe', bone = 'door_dside_r'},
        {name = 'door_rr', label = 'Drzwi tylne prawe', bone = 'door_pside_r'},
        {name = 'hood', label = 'Maska', bone = 'bonnet'},
        {name = 'trunk', label = 'Bagażnik', bone = 'boot'},
        {name = 'wheel_fl', label = 'Koło przednie lewe', offset = vector3(-1.0, 1.5, -0.5)},
        {name = 'wheel_fr', label = 'Koło przednie prawe', offset = vector3(1.0, 1.5, -0.5)},
        {name = 'wheel_rl', label = 'Koło tylne lewe', offset = vector3(-1.0, -1.5, -0.5)},
        {name = 'wheel_rr', label = 'Koło tylne prawe', offset = vector3(1.0, -1.5, -0.5)},
        {name = 'engine', label = 'Silnik', offset = vector3(0.0, 2.0, 0.5)}
    }
}