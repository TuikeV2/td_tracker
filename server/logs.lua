-- ============================================
-- TD TRACKER - LOGS & COOLDOWN SYSTEM
-- TuikeDevelopments 2025
-- ============================================

print('^2[TD TRACKER]^0 Loading logs.lua...')

-- ============================================
-- KONFIGURACJA DISCORD WEBHOOKS
-- ============================================

local DiscordWebhooks = {
    enabled = false, -- Zmieniono na false - ustaw na true i dodaj webhooki aby włączyć

    webhooks = {
        missions = '', -- Webhook dla misji (start, sukces, porażka)
        reputation = '', -- Webhook dla zmian reputacji
        admin = '', -- Webhook dla akcji adminów
        errors = '' -- Webhook dla błędów systemu
    },

    -- KOLORY EMBEDÓW
    colors = {
        success = 65280, -- Zielony
        error = 16711680, -- Czerwony
        warning = 16776960, -- Żółty
        info = 3447003, -- Niebieski
        admin = 10181046 -- Fioletowy
    }
}

-- ============================================
-- FUNKCJE POMOCNICZE
-- ============================================

---Pobiera nazwę gracza z identyfikatora
---@param identifier string
---@return string playerName
local function GetPlayerNameFromIdentifier(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if xPlayer then
        return GetPlayerName(xPlayer.source) or 'Unknown'
    end
    return 'Offline Player'
end

---Pobiera Steam hex z identyfikatora
---@param identifier string
---@return string steamHex
local function GetSteamHexFromIdentifier(identifier)
    if identifier and identifier:find('steam:') then
        return identifier
    end
    return 'Unknown'
end

---Formatuje czas do czytelnej formy
---@param seconds number
---@return string formatted
local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format('%02d:%02d', minutes, secs)
end

-- ============================================
-- SYSTEM COOLDOWNÓW
-- ============================================

---Sprawdza czy gracz ma cooldown
---@param identifier string
---@return boolean hasCooldown
function IsOnCooldown(identifier)
    if not identifier then
        if Config.Debug then print('^1[TRACKER COOLDOWN ERROR]^0 Invalid identifier!') end -- POPRAWIONE
        return false
    end

    -- Jeśli cooldown jest wyłączony w konfiguracji
    if not Config.GlobalCooldown and Config.PersonalCooldownTime == 0 then
        return false
    end

    -- Sprawdź w bazie danych
    local result = MySQL.single.await([[
        SELECT expires_at
        FROM tracker_cooldowns
        WHERE identifier = ?
        AND cooldown_type = 'mission'
        AND expires_at > NOW()
        LIMIT 1
    ]], {identifier})

    if result then
        print(string.format('^3[TRACKER COOLDOWN]^0 %s is on cooldown until %s', identifier, result.expires_at))
        return true
    end

    return false
end

---Pobiera pozostały czas cooldownu w sekundach
---@param identifier string
---@return number seconds
function GetCooldownTime(identifier)
    if not identifier then
        return 0
    end

    local result = MySQL.single.await([[
        SELECT TIMESTAMPDIFF(SECOND, NOW(), expires_at) AS remaining
        FROM tracker_cooldowns
        WHERE identifier = ?
        AND cooldown_type = 'mission'
        AND expires_at > NOW()
        LIMIT 1
    ]], {identifier})

    if result and result.remaining then
        return math.max(0, result.remaining)
    end

    return 0
end

---Ustawia cooldown dla gracza
---@param identifier string
function SetCooldown(identifier)
    if not identifier then
        if Config.Debug then print('^1[TRACKER COOLDOWN ERROR]^0 Invalid identifier for cooldown!') end -- POPRAWIONE
        return
    end

    -- Jeśli cooldown jest wyłączony
    if Config.PersonalCooldownTime == 0 then
        if Config.Debug then print('^3[TRACKER COOLDOWN]^0 Cooldown disabled in config') end -- POPRAWIONE
        return
    end

    -- Usuń stare cooldowny dla tego gracza
    MySQL.query.await('DELETE FROM tracker_cooldowns WHERE identifier = ? AND cooldown_type = "mission"', {identifier})

    -- Dodaj nowy cooldown
    local cooldownSeconds = Config.PersonalCooldownTime
    MySQL.insert.await([[
        INSERT INTO tracker_cooldowns (identifier, cooldown_type, expires_at)
        VALUES (?, 'mission', DATE_ADD(NOW(), INTERVAL ? SECOND))
    ]], {identifier, cooldownSeconds})

    print(string.format('^2[TRACKER COOLDOWN]^0 Set %d second cooldown for %s', cooldownSeconds, identifier))

    -- Powiadom gracza
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if xPlayer then
        TriggerClientEvent('ox_lib:notify', xPlayer.source, {
            title = 'Cooldown',
            description = string.format('Kolejna misja dostępna za: %s', FormatDuration(cooldownSeconds)),
            type = 'info',
            duration = 5000
        })
    end
end

---Czyści wygasłe cooldowny (wywoływane co 5 minut)
function CleanExpiredCooldowns()
    local result = MySQL.query.await('DELETE FROM tracker_cooldowns WHERE expires_at < NOW()')
    if result and result.affectedRows > 0 then
        print(string.format('^3[TRACKER COOLDOWN]^0 Cleaned %d expired cooldowns', result.affectedRows))
    end
end

-- Automatyczne czyszczenie co 5 minut
CreateThread(function()
    while true do
        Wait(300000) -- 5 minut
        CleanExpiredCooldowns()
    end
end)

-- ============================================
-- SYSTEM LOGOWANIA
-- ============================================

---Loguje akcję do konsoli i opcjonalnie do Discord
---@param identifier string
---@param action string
---@param data table
function LogAction(identifier, action, data)
    if not identifier or not action then
        return
    end

    -- Format log message
    local logMessage = string.format('[TRACKER LOG] %s | %s | %s',
        identifier,
        action,
        json.encode(data or {})
    )

    -- Console log
    print(logMessage)

    -- Discord webhook (jeśli włączony)
    if DiscordWebhooks.enabled then
        SendDiscordLog(identifier, action, data)
    end
end

-- ============================================
-- DISCORD WEBHOOKS
-- ============================================

---Wysyła log do Discord
---@param identifier string
---@param action string
---@param data table
function SendDiscordLog(identifier, action, data)
    if not DiscordWebhooks.enabled then return end

    local webhook = nil
    local color = DiscordWebhooks.colors.info
    local title = ''
    local description = ''

    -- Określ webhook i formatowanie na podstawie akcji
    if action == 'mission_start' then
        webhook = DiscordWebhooks.webhooks.missions
        color = DiscordWebhooks.colors.info
        title = '🎯 Misja Rozpoczęta'
        description = string.format('**Gracz:** %s\n**Identifier:** %s\n**Etap:** %d\n**Czas:** %s',
            GetPlayerNameFromIdentifier(identifier),
            identifier,
            data.stage or 0,
            os.date('%Y-%m-%d %H:%M:%S')
        )

    elseif action == 'mission_complete' then
        webhook = DiscordWebhooks.webhooks.missions
        color = DiscordWebhooks.colors.success
        title = '✅ Misja Ukończona'
        description = string.format('**Gracz:** %s\n**Identifier:** %s\n**Etap:** %d\n**Nagrody:**\n- Pieniądze: $%d\n- Czarne pieniądze: $%d\n- Reputacja: +%d\n**Czas:** %s',
            GetPlayerNameFromIdentifier(identifier),
            identifier,
            data.stage or 0,
            data.reward and data.reward.money or 0,
            data.reward and data.reward.blackMoney or 0,
            data.reward and data.reward.reputation or 0,
            os.date('%Y-%m-%d %H:%M:%S')
        )

    elseif action == 'mission_fail' then
        webhook = DiscordWebhooks.webhooks.missions
        color = DiscordWebhooks.colors.error
        title = '❌ Misja Nieudana'
        description = string.format('**Gracz:** %s\n**Identifier:** %s\n**Etap:** %d\n**Powód:** %s\n**Czas:** %s',
            GetPlayerNameFromIdentifier(identifier),
            identifier,
            data.stage or 0,
            data.reason or 'Nieznany',
            os.date('%Y-%m-%d %H:%M:%S')
        )

    elseif action == 'reputation_change' then
        webhook = DiscordWebhooks.webhooks.reputation
        color = data.change > 0 and DiscordWebhooks.colors.success or DiscordWebhooks.colors.error
        title = data.change > 0 and '⬆️ Reputacja Zwiększona' or '⬇️ Reputacja Zmniejszona'
        description = string.format('**Gracz:** %s\n**Identifier:** %s\n**Zmiana:** %+d\n**Nowa reputacja:** %d\n**Czas:** %s',
            GetPlayerNameFromIdentifier(identifier),
            identifier,
            data.change or 0,
            data.newRep or 0,
            os.date('%Y-%m-%d %H:%M:%S')
        )

    elseif action == 'admin_action' then
        webhook = DiscordWebhooks.webhooks.admin
        color = DiscordWebhooks.colors.admin
        title = '👮 Akcja Admina'
        description = string.format('**Admin:** %s\n**Cel:** %s\n**Akcja:** %s\n**Dane:** %s\n**Czas:** %s',
            GetPlayerNameFromIdentifier(data.adminIdentifier or ''),
            GetPlayerNameFromIdentifier(identifier),
            data.action or 'Nieznana',
            json.encode(data.details or {}),
            os.date('%Y-%m-%d %H:%M:%S')
        )

    elseif action == 'error' then
        webhook = DiscordWebhooks.webhooks.errors
        color = DiscordWebhooks.colors.error
        title = '⚠️ Błąd Systemu'
        description = string.format('**Gracz:** %s\n**Identifier:** %s\n**Błąd:** %s\n**Szczegóły:** %s\n**Czas:** %s',
            GetPlayerNameFromIdentifier(identifier),
            identifier,
            data.error or 'Nieznany błąd',
            json.encode(data.details or {}),
            os.date('%Y-%m-%d %H:%M:%S')
        )
    end

    -- Wyślij webhook jeśli URL jest ustawiony
    if webhook and webhook ~= '' then
        PerformHttpRequest(webhook, function(err, text, headers)
            if err ~= 200 and err ~= 204 then
                print(string.format('^1[TRACKER DISCORD ERROR]^0 Failed to send webhook: %d', err))
            end
        end, 'POST', json.encode({
            username = 'TD Tracker',
            avatar_url = 'https://i.imgur.com/4M34hi2.png',
            embeds = {
                {
                    title = title,
                    description = description,
                    color = color,
                    footer = {
                        text = 'TD Tracker by TuikeDevelopments',
                        icon_url = 'https://i.imgur.com/4M34hi2.png'
                    },
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%S')
                }
            }
        }), {['Content-Type'] = 'application/json'})
    end
end

-- ============================================
-- FUNKCJE DODATKOWE
-- ============================================

---Loguje błąd do konsoli i Discord
---@param identifier string
---@param errorMsg string
---@param details table
function LogError(identifier, errorMsg, details)
    print(string.format('^1[TRACKER ERROR]^0 %s | %s | %s', identifier, errorMsg, json.encode(details or {})))

    if DiscordWebhooks.enabled then
        SendDiscordLog(identifier, 'error', {
            error = errorMsg,
            details = details or {}
        })
    end
end

---Loguje akcję admina
---@param adminIdentifier string
---@param targetIdentifier string
---@param action string
---@param details table
function LogAdminAction(adminIdentifier, targetIdentifier, action, details)
    print(string.format('^5[TRACKER ADMIN]^0 %s performed %s on %s | %s',
        adminIdentifier,
        action,
        targetIdentifier,
        json.encode(details or {})
    ))

    if DiscordWebhooks.enabled then
        SendDiscordLog(targetIdentifier, 'admin_action', {
            adminIdentifier = adminIdentifier,
            action = action,
            details = details or {}
        })
    end
end

---Pobiera ostatnie logi misji gracza
---@param identifier string
---@param limit number
---@return table logs
function GetPlayerMissionLogs(identifier, limit)
    limit = limit or 10

    local results = MySQL.query.await([[
        SELECT
            mission_type,
            status,
            reputation_gained,
            reward_money,
            reward_black_money,
            duration,
            completed_at
        FROM tracker_missions
        WHERE identifier = ?
        ORDER BY completed_at DESC
        LIMIT ?
    ]], {identifier, limit})

    return results or {}
end

---Czyści stare logi (starsze niż X dni)
---@param days number
function CleanOldLogs(days)
    days = days or 30

    local result = MySQL.query.await([[
        DELETE FROM tracker_missions
        WHERE completed_at < DATE_SUB(NOW(), INTERVAL ? DAY)
    ]], {days})

    if result and result.affectedRows > 0 then
        print(string.format('^3[TRACKER LOGS]^0 Cleaned %d old mission logs (older than %d days)',
            result.affectedRows, days))
    end
end

-- Automatyczne czyszczenie starych logów co 24h
CreateThread(function()
    while true do
        Wait(86400000) -- 24 godziny
        CleanOldLogs(30) -- Usuń logi starsze niż 30 dni
    end
end)

-- ============================================
-- TESTY I DEBUG
-- ============================================

---Testuje połączenie z Discord webhook
---@param webhookType string missions/reputation/admin/errors
function TestDiscordWebhook(webhookType)
    if not DiscordWebhooks.enabled then
        if Config.Debug then print('^1[TRACKER DISCORD]^0 Discord webhooks are disabled!') end -- POPRAWIONE
        return
    end

    local webhook = DiscordWebhooks.webhooks[webhookType]
    if not webhook or webhook == '' then
        print(string.format('^1[TRACKER DISCORD]^0 Webhook "%s" not configured!', webhookType))
        return
    end

    PerformHttpRequest(webhook, function(err, text, headers)
        if err == 200 or err == 204 then
            print(string.format('^2[TRACKER DISCORD]^0 Webhook "%s" test successful!', webhookType))
        else
            print(string.format('^1[TRACKER DISCORD]^0 Webhook "%s" test failed! Error code: %d', webhookType, err))
        end
    end, 'POST', json.encode({
        username = 'TD Tracker',
        embeds = {
            {
                title = '🧪 Test Webhooka',
                description = string.format('To jest testowa wiadomość dla webhook typu: **%s**\n\nJeśli widzisz tę wiadomość, webhook działa poprawnie!', webhookType),
                color = DiscordWebhooks.colors.info,
                footer = {
                    text = 'TD Tracker by TuikeDevelopments'
                },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%S')
            }
        }
    }), {['Content-Type'] = 'application/json'})
end

-- ============================================
-- KOMENDY DEBUG (tylko dla adminów)
-- ============================================

RegisterCommand('tracker:testwebhook', function(source, args)
    if source == 0 then -- Console
        local webhookType = args[1] or 'missions'
        TestDiscordWebhook(webhookType)
    else
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.getGroup() == 'admin' then
            local webhookType = args[1] or 'missions'
            TestDiscordWebhook(webhookType)
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Test Webhooka',
                description = 'Sprawdź konsolę serwera i Discord',
                type = 'info'
            })
        end
    end
end, false)

print('^2[TD TRACKER]^0 Logs & Cooldown system loaded successfully!')