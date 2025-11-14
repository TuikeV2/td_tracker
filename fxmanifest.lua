fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'TuikeDevelopments'
description 'System zlecen przestepczych z progresja'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/blips.lua',
    'config/texts.lua'
}

client_scripts {
    'client/ui.lua',
    'client/blips.lua',
    'client/npc.lua',
    'client/police.lua',
    'client/admin.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',         -- Załaduj jako pierwszy (zarządza konfiguracją)
    'server/migrate_to_mysql.lua', -- Helper do migracji
    'server/reputation.lua',
    'server/logs.lua',
    'server/police.lua',
    'server/admin.lua',
    'server/main.lua',
    'server/commands.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib',
    'ox_inventory',
    'ox_target'
    -- Odkomentuj poniższą linię aby używać lb_tablet
    -- 'lb_tablet'
}