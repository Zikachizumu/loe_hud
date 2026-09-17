-- ============================================================
-- loe HUD - VPS Saat Sunucusu (Tek Zaman Otoritesi)
-- VPS sistem saatini okur; dakika DEĞİŞTİĞİNDE tüm oyunculara bir kez
-- yayın yapar. Yeni katılan oyuncuya anlık (o oyuncuya özel) gönderir.
-- ============================================================

local cfg = Config.Clock
local lastMinute = -1 -- Son yayınlanan dakika (aynı dakikayı tekrar göndermemek için)

--- VPS sistem saatini saat ve dakika olarak döndürür.
--- os.date SUNUCU tarafında çalışır -> VPS'in gerçek sistem saatidir.
---@return integer hour, integer minute
local function getVpsTime()
    return tonumber(os.date('%H')), tonumber(os.date('%M'))
end

-- VPS saatini periyodik kontrol eden TEK thread (oyuncu sayısından bağımsız).
CreateThread(function()
    while true do
        local hour, minute = getVpsTime()
        -- Sadece dakika değiştiyse yayın yap -> dakikada tek broadcast.
        if minute ~= lastMinute then
            lastMinute = minute
            TriggerClientEvent(cfg.updateEvent, -1, hour, minute)
        end
        Wait(cfg.pollInterval)
    end
end)

-- Oyuncunun HUD'u hazır olduğunda saati ISTER; yalnızca o oyuncuya gönderilir.
-- Böylece yeni oyuncu bir sonraki dakikayı beklemeden doğru saati görür.
RegisterNetEvent(cfg.requestEvent, function()
    local src = source
    local hour, minute = getVpsTime()
    TriggerClientEvent(cfg.updateEvent, src, hour, minute)
end)

-- ------------------------------------------------------------------
-- Açıklama: Sunucu tek zaman otoritesidir. Ağ maliyeti = dakikada 1 broadcast
-- + oyuncu başına katılışta 1 tekil mesaj. Tek thread saniyede bir hafif kontrol
-- yapar ama paketi yalnızca dakika sınırında yollar. Bu sebeple 1000+ oyuncuda
-- bile CPU/ağ yükü minimumdur. Genişletme (tarih, uptime, timezone) için
-- getVpsTime yanına yeni alanlar eklenip aynı event ile gönderilebilir.

