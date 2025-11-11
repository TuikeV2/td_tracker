-- TuikeDevelopments - Missions Config

ConfigMissions = {}

ConfigMissions.NPCLocations = {
    {coords = vector3(127.92, -1298.43, 29.27), heading = 225.0, model = 'a_m_m_business_01', animation = {dict = 'cellphone@', name = 'cellphone_call_listen_base'}},
    {coords = vector3(-1082.23, -247.46, 37.76), heading = 180.0, model = 'a_m_y_business_02', animation = {dict = 'amb@world_human_aa_smoke@male@idle_a', name = 'idle_c'}},
    {coords = vector3(265.73, -1347.59, 31.94), heading = 90.0, model = 'a_m_m_eastsa_02', animation = {dict = 'amb@world_human_drinking@coffee@male@idle_a', name = 'idle_c'}},
    {coords = vector3(1137.74, -982.48, 46.42), heading = 270.0, model = 'g_m_y_lost_01', animation = {dict = 'cellphone@', name = 'cellphone_text_read_base'}},
    {coords = vector3(-1520.69, -428.61, 35.59), heading = 45.0, model = 'a_m_m_hillbilly_02', animation = {dict = 'amb@world_human_smoking@male@male_a@idle_a', name = 'idle_c'}}
}

ConfigMissions.Stage1 = {
    searchAreas = {
        {center = vector3(215.0, -810.0, 30.0), radius = 300.0},
        {center = vector3(-200.0, -1400.0, 31.0), radius = 350.0},
        {center = vector3(400.0, -1600.0, 29.0), radius = 250.0},
        {center = vector3(-500.0, -800.0, 30.0), radius = 300.0},
        {center = vector3(1200.0, -900.0, 40.0), radius = 400.0}
    },
    deliveryPoints = {
        vector3(-1150.72, -1520.13, 10.63),
        vector3(2541.75, 2594.85, 37.94),
        vector3(1734.21, 3719.11, 34.04),
        vector3(-564.07, 5252.40, 70.47),
        vector3(-1044.75, 4920.06, 209.35)
    }
}

ConfigMissions.Stage2 = {
    vehicleSpawns = {
        vector4(-1150.72, -1520.13, 10.63, 125.0),
        vector4(2541.75, 2594.85, 37.94, 270.0),
        vector4(1734.21, 3719.11, 34.04, 180.0),
        vector4(-564.07, 5252.40, 70.47, 90.0),
        vector4(-1044.75, 4920.06, 209.35, 45.0)
    },
    hideouts = {
        vector3(-2192.68, 4289.49, 49.17),
        vector3(2434.87, 4968.42, 46.81),
        vector3(1395.03, 3606.63, 38.94),
        vector3(-450.43, 6042.09, 31.34),
        vector3(711.28, 4093.89, 35.75)
    }
}

ConfigMissions.Stage3 = {
    dismantleLocations = {
        vector4(2341.67, 3054.78, 48.15, 270.0),
        vector4(-564.07, 5252.40, 70.47, 90.0),
        vector4(1395.03, 3606.63, 38.94, 180.0),
        vector4(-1044.75, 4920.06, 209.35, 45.0),
        vector4(2541.75, 2594.85, 37.94, 270.0)
    },
    sellPoints = {
        vector3(2341.67, 3054.78, 48.15),
        vector3(-564.07, 5252.40, 70.47),
        vector3(1395.03, 3606.63, 38.94),
        vector3(-1044.75, 4920.06, 209.35),
        vector3(2541.75, 2594.85, 37.94)
    },
    busModel = 'burrito3',
    vehicleParts = {
        {name = 'hood', label = 'Maska', bone = 'bonnet', item = 'car_hood'},
        {name = 'trunk', label = 'Bagażnik', bone = 'boot', item = 'car_trunk'},
        {name = 'door_fl', label = 'Drzwi przednie lewe', bone = 'door_dside_f', item = 'car_door'},
        {name = 'door_fr', label = 'Drzwi przednie prawe', bone = 'door_pside_f', item = 'car_door'},
        {name = 'door_rl', label = 'Drzwi tylne lewe', bone = 'door_dside_r', item = 'car_door'},
        {name = 'door_rr', label = 'Drzwi tylne prawe', bone = 'door_pside_r', item = 'car_door'},
        {name = 'wheel_fl', label = 'Koło przednie lewe', offset = vector3(1.0, 1.5, -0.5), item = 'car_wheel'},
        {name = 'wheel_fr', label = 'Koło przednie prawe', offset = vector3(-1.0, 1.5, -0.5), item = 'car_wheel'},
        {name = 'wheel_rl', label = 'Koło tylne lewe', offset = vector3(1.0, -1.5, -0.5), item = 'car_wheel'},
        {name = 'wheel_rr', label = 'Koło tylne prawe', offset = vector3(-1.0, -1.5, -0.5), item = 'car_wheel'},
        {name = 'engine', label = 'Silnik', offset = vector3(0.0, 2.0, 0.5), item = 'car_engine'}
    }
}
