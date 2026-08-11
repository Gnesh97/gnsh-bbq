fx_version 'cerulean'
game 'gta5'

author 'Gnesh'
description 'QB-Core & Standalone Uyumlu Mangal Scripti'
version '1.3.0'

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
