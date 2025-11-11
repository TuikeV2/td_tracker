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
<<<<<<< HEAD
        vector4(1409.4042, 3619.8838, 34.8943, 291.8324),
        vector4(1750.4076, 3715.4587, 34.1005, 18.5932),
        vector4(-103.3659, 6534.1694, 29.8092, 43.6376),
        vector4(1123.9783, 2649.7183, 37.9965, 359.4629),
        vector4(-1158.2853, -1415.9420, 4.7738, 69.8420)
    },
    hideouts = {
        vector3(3830.7781, 4457.1152, 4.3411),
        vector3(2807.9690, -709.0909, 2.7066),
        vector3(-96.0157, -2767.0366, 6.1156),
        vector3(1234.9996, -3203.9021, 5.5853)
=======
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
>>>>>>> 3f40447af142f4db5cc26f5c568cbf4aff9aa968
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