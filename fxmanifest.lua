fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'loe_hud'
author 'loe'
description 'Premium HUD (Qbox) — status / money / info / vehicle / minimap'
version '2.0.0'

ui_page 'html/index.html'

-- LOCAL DEGISIKLIK (bos test sunucusu): ox_lib yok.
-- cache.ped / cache.vehicle / cache.seat client/cl_hud.lua icinde native
-- karsiliklariyla degistirildi. Kodda hic 'lib.' cagrisi yoktu.
shared_scripts {
    'config.lua'
}

client_scripts {
    'client/cl_hud.lua',
    'client/clock.lua'
}

server_scripts {
    'server/sv_hud.lua',
    'server/clock.lua'
}

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/icons/*.svg'
}

-- LOCAL DEGISIKLIK: dependencies blogu kaldirildi. Duruyor olsa resource
-- qbx_core / ox_lib bulunamadigi icin HIC baslamazdi.
-- qbx_core cagrisi (qbx:GetPlayerData) zaten pcall icinde -- yoklugunda
-- cokmez, sadece para 0 ve aclik/susuzluk 100 gorunur.

