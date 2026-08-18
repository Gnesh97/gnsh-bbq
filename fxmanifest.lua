fx_version 'cerulean'
game 'gta5'

author 'Gnesh'
description 'QB-Core & Standalone Uyumlu Mangal Scripti'
version '1.0.0'

-- Varsayilan production profili: qb-core + ox_inventory + ox_target.
-- ox_inventory kendi manifestinde ox_lib'e bagimli olsa da burada da
-- eksik/yanlis baslatma sirasini erken yakalamak icin acikca belirtilir.
dependencies {
    'qb-core',
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/**' -- Yeni eklenen NUI varliklari otomatik dahil olsun
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'bridge_client.lua',
    'client.lua'
}

server_scripts {
    'bridge.lua',
    'server.lua'
}
