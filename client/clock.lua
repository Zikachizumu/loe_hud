-- ============================================================
-- loe HUD - VPS Saat İstemcisi (Sadece İletici)
-- İstemci ASLA saat hesaplamaz/üretmez. Sunucudan geleni NUI'ye iletir.
-- ============================================================

local cfg = Config.Clock

-- Sunucudan gelen saat/dakika değerini olduğu gibi NUI'ye ilet.
RegisterNetEvent(cfg.updateEvent, function(hour, minute)
    SendNUIMessage({
        action = 'clock',
        data   = { hour = hour, minute = minute },
    })
end)

-- HUD/oyuncu hazır olduğunda sunucudan anlık saati iste (dakikayı bekleme).
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent(cfg.requestEvent)
end)

-- Resource canlı yeniden başlatılırsa saatin hemen dolması için.
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    TriggerServerEvent(cfg.requestEvent)
end)

-- ------------------------------------------------------------------
-- Açıklama: İstemcide zamanlayıcı, döngü veya saniye sayacı YOKTUR.
-- os.time/os.date/GetClockHours kullanılmaz. Oyuncunun Windows saati, tarihi
-- veya timezone'u değişse bile HUD etkilenmez; değer tamamen sunucudan gelir.
-- İstemci yalnızca bir "köprü"dür ve NUI'ye 'clock' action'ı ile iletir.

