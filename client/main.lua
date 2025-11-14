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

-- ============================================
-- UWAGA: Funkcje blipów zostały przeniesione do client/blips.lua
-- aby uniknąć duplikacji. Wszystkie funkcje CreateSearchAreaBlip,
-- CreateWaypointBlip i RemoveAllBlips są dostępne z client/blips.lua
-- ============================================

-- ============================================
-- POZOSTAŁA LOGIKA (POCZĄTEK main.lua)
-- ============================================

local function DebugPrint(msg)
	if Config.Debug then
		print(msg)
	end
end

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
	DebugPrint('^3[TRACKER CLIENT]^0 NPC(s) removed and cleanup attempted')
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

	-- Pobierz lokacje NPC z serwera (z bazy danych)
	ESX.TriggerServerCallback('td_tracker:getNPCLocations', function(locations)
		if not locations or #locations == 0 then
			DebugPrint('^1[TRACKER CLIENT]^0 Błąd: Brak lokacji NPC w bazie danych.')
			-- Fallback do ConfigMissions jeśli baza nie odpowiada
			if ConfigMissions and ConfigMissions.NPCLocations then
				locations = ConfigMissions.NPCLocations
			else
				return
			end
		end

		currentNPCLocation = locations[math.random(1, #locations)]
		local coords = currentNPCLocation.coords
		local model = GetHashKey(currentNPCLocation.model)

		RequestModel(model)
		while not HasModelLoaded(model) do
			Wait(10)
		end

		activeNPC = CreatePed(2, model, coords.x, coords.y, coords.z - 1.0, currentNPCLocation.heading, false, false)
		SetPedFleeAttributes(activeNPC, 0, false)
		SetPedDiesWhenInjured(activeNPC, false)
		SetPedCanRagdoll(activeNPC, false)
		SetEntityInvincible(activeNPC, true)
		FreezeEntityPosition(activeNPC, true)
		SetModelAsNoLongerNeeded(model)

		local anim = currentNPCLocation.animation
		if anim and anim.dict and anim.name then
			RequestAnimDict(anim.dict)
			while not HasAnimDictLoaded(anim.dict) do
				Wait(10)
			end
			TaskPlayAnim(activeNPC, anim.dict, anim.name, 8.0, 1.0, -1, 1, 0, false, false, false)
			RemoveAnimDict(anim.dict)
		end

		exports.ox_target:addLocalEntity(activeNPC, {
			{
				name = 'td_tracker_main_npc',
				label = '💼 Zapytaj o robotę',
				icon = 'fa-solid fa-handshake',
				distance = 2.5,
				onSelect = function()
					if currentMission and currentMission.active then
						lib.notify({title = 'TD Tracker', description = 'Już masz aktywną misję!', type = 'error'})
						return
					end
					TriggerServerEvent('td_tracker:server:getAvailableStages')
				end
			}
		})

		DebugPrint(string.format('^2[TRACKER CLIENT]^0 NPC (Quest Giver) spawned at %s', tostring(coords)))
	end)
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
	
	DebugPrint('^2[TRACKER CLIENT]^0 Spawning mission NPC at', coords)
	
	if not ConfigLocations or not ConfigLocations.NPCSpawns or #ConfigLocations.NPCSpawns == 0 then
		DebugPrint('^1[TRACKER CLIENT ERROR]^0 No NPC spawns configured!')
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
	
	DebugPrint('^2[TRACKER CLIENT]^0 Mission NPC spawned with waypoint')
	
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
						DebugPrint('^3[TRACKER DEBUG]^0 Stage 2 NPC interaction - showing dialog')

						local alert = lib.alertDialog({
							header = 'Zlecenie: Transport',
							content = 'Odbierz ten pojazd i dostarcz go do kryjówki.\n\n⚠️ Policja będzie ostrzeżona!\n🎯 Unikaj pościgu i jedź do punktu na mapie.',
							centered = true,
							cancel = true,
							labels = {confirm = 'Rozumiem', cancel = 'Anuluj'}
						})

						DebugPrint('^3[TRACKER DEBUG]^0 Dialog response:', alert)

						if alert == 'confirm' then
							DebugPrint('^2[TRACKER]^0 Gracz potwierdził etap 2: Transport - unlocking vehicle')
							RemoveNPC()
							UnlockTransportVehicle()
							currentMission.stage = 'pickup'
							DebugPrint('^2[TRACKER]^0 Stage changed to pickup')
						else
							DebugPrint('^1[TRACKER]^0 Dialog cancelled or closed')
						end
					end
				})

elseif currentMission.type == 3 then
				table.insert(options, {
					name = 'npc_stage3_info',
					label = '💬 Porozmawiaj z kontaktem',
					icon = 'fa-solid fa-wrench',
					distance = interactionDistance,
					onSelect = function()
						DebugPrint('^3[TRACKER DEBUG]^0 Stage 3 NPC interaction - showing dialog')

						if Config.RequireDismantleMinigame then
							local alert = lib.alertDialog({
								header = 'Zlecenie: Rozbiórka',
								content = 'Rozmontuj ten pojazd na części.\n\n🔨 Kliknij na każdą część pojazdu aby ją zdemontować\n📦 Załaduj części do busa\n💰 Dostarcz bus z częściami do punktu sprzedaży',
								centered = true,
								cancel = true,
								labels = {confirm = 'Rozumiem', cancel = 'Anuluj'}
							})

							DebugPrint('^3[TRACKER DEBUG]^0 Dialog response:', alert)

							if alert == 'confirm' then
								DebugPrint('^2[TRACKER]^0 Gracz potwierdził etap 3: Rozbiórka - enabling interactions')
								RemoveNPC()
								EnableDismantleInteractions()
								currentMission.stage = 'dismantle'
								DebugPrint('^2[TRACKER]^0 Stage changed to dismantle')
							else
								DebugPrint('^1[TRACKER]^0 Dialog cancelled or closed')
							end
						else
							DebugPrint('^2[TRACKER]^0 Config.RequireDismantleMinigame jest FALSE - pomijanie dialogu, aktywacja interakcji.')
							RemoveNPC()
							EnableDismantleInteractions()
							currentMission.stage = 'dismantle'
							DebugPrint('^2[TRACKER]^0 Stage changed to dismantle')
						end
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
		DebugPrint(string.format('^2[TRACKER CLIENT]^0 Mission Stage NPC ox_target added for stage %s', currentMission and currentMission.type or "unknown"))
	end
end

-- UWAGA: ShowNotification jest zdefiniowane w client/ui.lua

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


-- ZMIENIONY BLOK: Dodano RemoveAllBlips() do istniejącego handlera onResourceStop.
AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
        RemoveNPC()
        RemoveAllBlips()
    end
end)

-- UWAGA: Funkcje ShowNPCDialog i ShowStatsDialog zostały usunięte
-- ponieważ są nieużywane. System menu NPC działa przez
-- td_tracker:client:showMissionSelection event (linia 228)

-- ============================================
-- GŁÓWNA LOGIKA MISJI
-- ============================================

RegisterNetEvent('td_tracker:client:startMission', function(data)
	DebugPrint('^3[TRACKER CLIENT DEBUG]^0 Starting mission type:', data.type)
	DebugPrint('^3[TRACKER CLIENT DEBUG]^0 Data received:', json.encode(data))
	
	currentMission = data
	missionStartTime = GetGameTimer()
	
	if data.type == 1 then
		StartStage1(data)
	elseif data.type == 2 then
		StartStage2(data)
	elseif data.type == 3 then
		StartStage3(data)
	else
		DebugPrint('^1[TRACKER CLIENT ERROR]^0 Unknown mission type:', data.type)
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

	DebugPrint('^2[TRACKER CLIENT DEBUG]^0 Completing mission')

	local timeTaken = GetGameTimer() - missionStartTime
	local timeLimit = Config.MissionTimeLimit[currentMission.type]

	-- Zatrzymaj pościg NPC
	TriggerEvent('td_tracker:client:stopNPCChase', 'mission_completed')

	TriggerServerEvent('td_tracker:server:completeMission', currentMission.type, timeTaken, timeLimit)
	CleanupMission()
end

function FailMission(reason)
	if not currentMission or not currentMission.active then return end

	DebugPrint('^1[TRACKER CLIENT DEBUG]^0 Failing mission:', reason)

	-- Zatrzymaj pościg NPC
	TriggerEvent('td_tracker:client:stopNPCChase', 'mission_failed')

	TriggerServerEvent('td_tracker:server:failMission', currentMission.type, reason)

	local penalty = ConfigRewards.FailurePenalty[currentMission.type] or 20
	ShowNotification(string.format(ConfigTexts.Notifications.missionFailed.description, reason, penalty), ConfigTexts.Notifications.missionFailed.title, 'error')

	CleanupMission()
end

function CleanupMission()
	DebugPrint('^3[TRACKER CLIENT DEBUG]^0 Cleaning up mission')
	
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

			-- Sprawdź czy misja nadal aktywna
			if not currentMission or not currentMission.active then
				break
			end

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
	DebugPrint('^3[TRACKER CLIENT DEBUG]^0 Starting Stage 1')
	
	if not data.plate or not data.searchArea or not data.vehicles then
		DebugPrint('^1[TRACKER CLIENT ERROR]^0 Missing Stage 1 data!')
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
	DebugPrint('^3[TRACKER CLIENT DEBUG]^0 Spawning', #vehicles, 'vehicles')

	for _, veh in ipairs(vehicles) do
		local model = GetHashKey(veh.model)
		RequestModel(model)
		while not HasModelLoaded(model) do Wait(0) end

		-- Pobierz prawidłową wysokość terenu
		local groundZ = veh.coords.z
		local found, z = GetGroundZFor_3dCoord(veh.coords.x, veh.coords.y, veh.coords.z + 5.0, false)
		if found then
			groundZ = z
		end

		local vehicle = CreateVehicle(model, veh.coords.x, veh.coords.y, groundZ, veh.coords.w, true, false)
		SetVehicleNumberPlateText(vehicle, veh.plate)
		SetVehicleDoorsLocked(vehicle, 2)
		SetVehicleOnGroundProperly(vehicle)

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

	DebugPrint('^2[TRACKER CLIENT DEBUG]^0 Vehicles spawned successfully')
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
    DebugPrint('^3[TRACKER CLIENT DEBUG]^0 Starting Stage 2')
    DebugPrint('^3[TRACKER CLIENT DEBUG]^0 Data received:', json.encode(data))

    if not data.npcSpawn then
        DebugPrint('^1[TRACKER CLIENT ERROR]^0 Missing npcSpawn!')
        FailMission('Brak danych misji')
        return
    end

    if not data.spawnPoint then
        DebugPrint('^1[TRACKER CLIENT ERROR]^0 Missing spawnPoint!')
        FailMission('Brak danych misji')
        return
    end

    if not data.hideout then
        DebugPrint('^1[TRACKER CLIENT ERROR]^0 Missing hideout!')
        FailMission('Brak danych misji')
        return
    end

    if not data.vehicleModel then
        DebugPrint('^1[TRACKER CLIENT ERROR]^0 Missing vehicleModel!')
        FailMission('Brak danych misji')
        return
    end

    local npcSpawn = data.npcSpawn
    local vehicleSpawn = data.spawnPoint
    local hideout = data.hideout

    currentMission.stage = 'talk_to_npc'
    currentMission.active = true
    currentMission.deliveryPoint = hideout

    SpawnMissionNPC(vector3(npcSpawn.x, npcSpawn.y, npcSpawn.z), npcSpawn.w or 0.0)
    SpawnLockedTransportVehicle(vehicleSpawn, data.vehicleModel)

    DebugPrint('^2[TRACKER CLIENT DEBUG]^0 Stage 2 initialized - vehicle locked until NPC dialog')
end

function SpawnLockedTransportVehicle(spawn, model)
    DebugPrint('^3[TRACKER DEBUG]^0 SpawnLockedTransportVehicle called')
    DebugPrint('^3[TRACKER DEBUG]^0 spawn:', json.encode(spawn))
    DebugPrint('^3[TRACKER DEBUG]^0 model:', model)

    -- Usuń poprzedni pojazd jeśli istnieje
    if transportVehicle and DoesEntityExist(transportVehicle) then
        DebugPrint('^3[TRACKER DEBUG]^0 Removing previous transport vehicle')
        DeleteEntity(transportVehicle)
        transportVehicle = nil
    end

    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    -- Pobierz prawidłową wysokość terenu
    local groundZ = spawn.z
    local found, z = GetGroundZFor_3dCoord(spawn.x, spawn.y, spawn.z + 5.0, false)
    if found then
        groundZ = z
        DebugPrint('^3[TRACKER DEBUG]^0 Ground Z found:', groundZ, 'Original Z:', spawn.z)
    else
        DebugPrint('^3[TRACKER DEBUG]^0 Ground Z not found, using original Z:', spawn.z)
    end

    transportVehicle = CreateVehicle(hash, spawn.x, spawn.y, groundZ, spawn.w or 0.0, true, false)
    SetVehicleDoorsLocked(transportVehicle, 2)
    SetVehicleEngineOn(transportVehicle, false, true, false)
    SetVehicleOnGroundProperly(transportVehicle)

    currentMission.targetVehicle = transportVehicle
    DebugPrint('^2[TRACKER DEBUG]^0 Transport vehicle spawned (LOCKED) at:', GetEntityCoords(transportVehicle))
end

function UnlockTransportVehicle()
    if not transportVehicle or not DoesEntityExist(transportVehicle) then
        DebugPrint('^1[TRACKER ERROR]^0 No transport vehicle to unlock!')
        return
    end

    DebugPrint('^2[TRACKER DEBUG]^0 Unlocking transport vehicle:', transportVehicle)
    SetVehicleDoorsLocked(transportVehicle, 1)

    local hideout = currentMission.deliveryPoint

    CreateThread(function()
        while DoesEntityExist(transportVehicle) and currentMission and currentMission.stage == 'pickup' do
            Wait(500)

            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == transportVehicle then
                RemoveNPC()
                StartStage2Chase(hideout)
                break
            end
        end
    end)

    ShowNotification('Pojazd został odblokowany! Wsiądź i dostarcz go do kryjówki', 'Transport', 'success')
    DebugPrint('^2[TRACKER CLIENT DEBUG]^0 Transport vehicle unlocked and ready')
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
    DebugPrint('^3[TRACKER CLIENT DEBUG]^0 Starting Stage 3')

    if not data.npcSpawn or not data.vehicleSpawn or not data.busSpawn or not data.vehicleModel then
        DebugPrint('^1[TRACKER CLIENT ERROR]^0 Missing Stage 3 data!')
        FailMission('Błąd danych misji')
        return
    end

    local npcSpawn = data.npcSpawn
    local vehicleSpawn = data.vehicleSpawn
    local busSpawn = data.busSpawn
    local sellPoint = data.sellPoint

    currentMission.stage = 'talk_to_npc'
    currentMission.active = true
    currentMission.totalParts = #ConfigLocations.Stage3.parts
    currentMission.loadedParts = 0
    currentMission.sellPoint = sellPoint
    dismantledParts = {}

    SpawnMissionNPC(vector3(npcSpawn.x, npcSpawn.y, npcSpawn.z), npcSpawn.w or 0.0)
    SpawnDismantleVehiclesLocked(vehicleSpawn, busSpawn, data.vehicleModel)

    DebugPrint('^2[TRACKER CLIENT DEBUG]^0 Stage 3 initialized - vehicles spawned but interactions disabled')
end

function SpawnDismantleVehiclesLocked(vehicleSpawn, busSpawn, model)
    DebugPrint('^3[TRACKER DEBUG]^0 SpawnDismantleVehiclesLocked called')
    DebugPrint('^3[TRACKER DEBUG]^0 vehicleSpawn:', json.encode(vehicleSpawn))
    DebugPrint('^3[TRACKER DEBUG]^0 busSpawn:', json.encode(busSpawn))
    DebugPrint('^3[TRACKER DEBUG]^0 model:', model)

    -- Usuń poprzednie pojazdy jeśli istnieją
    if dismantleVehicle and DoesEntityExist(dismantleVehicle) then
        DebugPrint('^3[TRACKER DEBUG]^0 Removing previous dismantle vehicle')
        DeleteEntity(dismantleVehicle)
        dismantleVehicle = nil
    end

    if busVehicle and DoesEntityExist(busVehicle) then
        DebugPrint('^3[TRACKER DEBUG]^0 Removing previous bus vehicle')
        DeleteEntity(busVehicle)
        busVehicle = nil
    end

    local vehHash = GetHashKey(model)
    local busHash = GetHashKey(ConfigLocations.Stage3.busModel)

    RequestModel(vehHash)
    RequestModel(busHash)
    while not HasModelLoaded(vehHash) or not HasModelLoaded(busHash) do Wait(0) end

    -- Pobierz prawidłową wysokość terenu dla pojazdu do rozbiórki
    local vehGroundZ = vehicleSpawn.z
    local found1, z1 = GetGroundZFor_3dCoord(vehicleSpawn.x, vehicleSpawn.y, vehicleSpawn.z + 5.0, false)
    if found1 then
        vehGroundZ = z1
        DebugPrint('^3[TRACKER DEBUG]^0 Dismantle vehicle ground Z found:', vehGroundZ)
    end

    -- Pobierz prawidłową wysokość terenu dla busa
    local busGroundZ = busSpawn.z
    local found2, z2 = GetGroundZFor_3dCoord(busSpawn.x, busSpawn.y, busSpawn.z + 5.0, false)
    if found2 then
        busGroundZ = z2
        DebugPrint('^3[TRACKER DEBUG]^0 Bus ground Z found:', busGroundZ)
    end

    dismantleVehicle = CreateVehicle(vehHash, vehicleSpawn.x, vehicleSpawn.y, vehGroundZ, vehicleSpawn.w or 0.0, true, false)
    SetVehicleDoorsLocked(dismantleVehicle, 3)
    SetEntityInvincible(dismantleVehicle, true)
    SetVehicleOnGroundProperly(dismantleVehicle)
    DebugPrint('^2[TRACKER DEBUG]^0 Dismantle vehicle spawned (LOCKED) at:', GetEntityCoords(dismantleVehicle))

    busVehicle = CreateVehicle(busHash, busSpawn.x, busSpawn.y, busGroundZ, busSpawn.w or 0.0, true, false)
    SetVehicleDoorsLocked(busVehicle, 3)
    SetVehicleOnGroundProperly(busVehicle)
    DebugPrint('^2[TRACKER DEBUG]^0 Bus vehicle spawned (LOCKED) at:', GetEntityCoords(busVehicle))

    DebugPrint('^2[TRACKER CLIENT DEBUG]^0 Dismantle vehicles spawned - interactions disabled until NPC dialog')
end

function EnableDismantleInteractions()
    if not dismantleVehicle or not DoesEntityExist(dismantleVehicle) then
        DebugPrint('^1[TRACKER ERROR]^0 No dismantle vehicle to enable!')
        return
    end

    if not busVehicle or not DoesEntityExist(busVehicle) then
        DebugPrint('^1[TRACKER ERROR]^0 No bus vehicle to enable!')
        return
    end

    DebugPrint('^2[TRACKER DEBUG]^0 Enabling dismantle interactions')

    SetupDismantlePoints()
    SetupBusTarget()

    ShowNotification('Możesz teraz rozmontować pojazd! Kliknij na części pojazdu', 'Rozbiórka', 'success')
    DebugPrint('^2[TRACKER CLIENT DEBUG]^0 Dismantle interactions enabled')
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
                            return not dismantledParts[part.name] and currentMission and currentMission.active and currentPart == nil
                        end,
                        onSelect = function()
                            DismantlePart(part)
                        end
                    }
                }
            })
            
            table.insert(dismantleZones, zoneName)
        else
            DebugPrint('^1[TRACKER CLIENT ERROR]^0 Could not get coords for part:', part.name)
        end
    end
    
    DebugPrint('^2[TRACKER CLIENT DEBUG]^0 Setup', #dismantleZones, 'dismantle zones')
end

function DismantlePart(part)
    if dismantledParts[part.name] then return end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, dismantleVehicle, 1000)
    Wait(1000)

    if lib.progressBar({
        duration = Config.DismantleTime,
        label = string.format('Demontaż: %s', part.label),
        useWhileDead = false,
        canCancel = true,
        disable = {move = true, car = true, combat = true},
        anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'}
    }) then
        local success = true

        if Config.RequireDismantleMinigame then
            success = lib.skillCheck(Config.DismantleDifficulty, {'w', 'a', 's', 'd'})
        end

        if success then
            dismantledParts[part.name] = true
            RemovePart(part)
            AttachProp(part)
            ShowNotification(string.format('Zdemontowano: %s\nZaładuj do busa', part.label), 'Część zdemontowana', 'success')

            local count = 0
            for _ in pairs(dismantledParts) do count = count + 1 end
            DebugPrint('^3[TRACKER DEBUG]^0 Parts dismantled:', count, '/', currentMission.totalParts)
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
    -- Używamy kartonu zamiast worka na śmieci
    local model = GetHashKey('prop_cs_cardbox_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    -- Załaduj animację noszenia kartonu (dwuręczna)
    local animDict = 'anim@heists@box_carry@'
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(0) end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)

    -- Przyczepiamy karton do rąk (dwuręczna pozycja)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0, -0.2, 0.4, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    -- Uruchom animację noszenia kartonu
    TaskPlayAnim(ped, animDict, 'idle', 8.0, -8.0, -1, 50, 0, false, false, false)

    -- Zmniejsz prędkość gracza o 50%
    SetPedMoveRateOverride(ped, 0.5)

    currentPart = {prop = prop, data = part}

    DebugPrint('^2[TRACKER]^0 Part attached with cardboard box and slow movement')
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
        local ped = PlayerPedId()

        if DoesEntityExist(currentPart.prop) then
            DeleteEntity(currentPart.prop)
        end

        -- Przywróć normalną prędkość gracza
        SetPedMoveRateOverride(ped, 1.0)
        ClearPedTasks(ped)

        currentMission.loadedParts = (currentMission.loadedParts or 0) + 1
        ShowNotification(string.format('Załadowano %d/%d części', currentMission.loadedParts, currentMission.totalParts), 'Postęp', 'info')

        if currentMission.loadedParts >= currentMission.totalParts then
            AllPartsLoaded()
        end

        currentPart = nil
        DebugPrint('^2[TRACKER]^0 Part loaded, movement speed restored')
    end
end

function AllPartsLoaded()
    ShowNotification('Wszystkie części załadowane!\nJedź sprzedać bus z częściami', 'Gotowe', 'success')

    -- Odblokuj busa i włącz silnik
    if busVehicle and DoesEntityExist(busVehicle) then
        SetVehicleDoorsLocked(busVehicle, 1) -- Odblokuj
        SetVehicleEngineOn(busVehicle, false, true, false)
        DebugPrint('^2[TRACKER]^0 Bus unlocked and ready to drive')
    end

    local sell = currentMission.sellPoint or ConfigLocations.Stage3.sellPoints[math.random(#ConfigLocations.Stage3.sellPoints)]
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
    
    DebugPrint('^3[TRACKER CLIENT]^0 Stage 3 cleaned up')
end

-- ============================================
-- CLEANUP HANDLERS
-- ============================================

-- Obsługa śmierci gracza podczas misji
CreateThread(function()
    while true do
        Wait(1000)

        if currentMission and currentMission.active then
            local ped = PlayerPedId()

            if IsEntityDead(ped) then
                DebugPrint('^1[TRACKER]^0 Player died during mission - failing mission')

                -- Wyślij info do serwera o niepowodzeniu
                TriggerServerEvent('td_tracker:server:failMission', currentMission.type, 'Śmierć gracza')

                -- Natychmiastowe czyszczenie wszystkiego
                CleanupMission()

                -- Poczekaj aż gracz ożyje, zanim wznowimy sprawdzanie
                repeat
                    Wait(1000)
                until not IsEntityDead(PlayerPedId())

                DebugPrint('^3[TRACKER]^0 Player respawned - cleanup completed')
            end
        end
    end
end)

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
        DebugPrint('^1[TRACKER]^0 Player manually cancelled mission')
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

DebugPrint('^2[TRACKER CLIENT]^0 Main loaded with all stages')