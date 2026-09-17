--[[
    loe_hud / server
    Tek görev: aktif oyuncu sayısını GlobalState üzerinden clientlara yayınlamak.
    (ID, para, saat vb. client tarafında native/Qbox'tan okunur.)
]]

local function updatePlayerCount()
    GlobalState.loePlayers = #GetPlayers()
end

-- Bağlanma / ayrılma olaylarında sayacı tazele (kısa gecikme ile net sonuç)
AddEventHandler('playerJoining',  function() SetTimeout(500, updatePlayerCount) end)
AddEventHandler('playerDropped',  function() SetTimeout(500, updatePlayerCount) end)

-- Resource start + periyodik güvenlik tazelemesi
CreateThread(function()
    updatePlayerCount()
    while true do
        Wait(30000)
        updatePlayerCount()
    end
end)

