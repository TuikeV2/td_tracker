fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'TuikeDevelopments'
description 'System zlecen przestepczych z progresja'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config/*.lua'
}

client_scripts {
    'client/main.lua',
    'client/npc.lua',
    'client/blips.lua',
    'client/ui.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/reputation.lua',
    'server/logs.lua',
    'server/stages/*.lua',
    'server/main.lua',
    'server/commands.lua'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib',
    'ox_inventory',
    'ox_target'
}