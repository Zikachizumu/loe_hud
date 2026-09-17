Config = {}

-- Hız birimi: 'kmh' | 'mph'
Config.SpeedUnit = 'kmh'

-- Güncelleme aralıkları (ms). Sadece veri değişince NUI güncellenir; bu sadece okuma sıklığı.
Config.StatusTick  = 300   -- can / zırh / açlık / susuzluk / para / bilgi / cadde
Config.VehicleTick = 90    -- araç paneli
Config.MinimapTick = 100   -- minimap görünürlük kontrolü (aşağıdaki SyncWithMinimap)

-- HUD'u minimap ile eşitle. Minimap gizlendiği her durumda (ESC duraklatma
-- menüsü, envanter/çanta açıkken, ölüm, ara sahne, DisplayRadar(false)) tüm
-- HUD panelleri de gizlenir; minimap geri gelince HUD da geri gelir.
-- IS_MINIMAP_RENDERING native'i bu durumların hepsini kapsar.
Config.SyncWithMinimap = true

-- Minimap yakınlaştırma: Z'ye basınca minimap KUTUSUNUN boyutu SABİT kalır,
-- sadece gösterdiği alan BİRAZ genişler (~2 katı; bigmap / M tuşundan
-- farklı — o ekran düzenini değiştirir). Config.MinimapZoom.duration kadar
-- (varsayılan 5sn) o şekilde kalır, sonra kendiliğinden normale döner —
-- tekrar basmaya gerek yok. Herkes için açık, yetki kontrolü yok.
-- zoomedValue: SET_RADAR_ZOOM_PRECISE değeri. Oyunda denenerek kalibre
-- edildi (~2 katı alan için 96 doğru değer çıktı).
Config.MinimapZoom = {
    enabled     = true,
    key         = 'Z',    -- basınca uzaklaştırır
    zoomedValue = 96.0,   -- ~2 kat alan
    duration    = 5000,   -- ms — bu sürenin sonunda otomatik normale döner
}

-- Görünürlük
Config.Show = {
    status  = true,   -- can / zırh / yemek / su (minimap yanı)
    money   = true,   -- bank / cash (sağ üst)
    info    = true,   -- ID + oyuncu + saat (sağ üst)
    street  = true,   -- cadde ismi (minimap üstü)
    vehicle = true,   -- araç paneli (sağ alt)
    wanted  = true,   -- polis yıldızları (sağ üst, cash ile saat arası)
    ammo    = true,   -- mermi sayacı (saat altı: çanta / şarjör) — ox_inventory
}

-- HUD saati — VPS sistem saatinden beslenir (oyun içi saatten DEĞİL).
-- Sunucu tek zaman otoritesidir: dakika değiştiğinde bir kez yayın yapar,
-- yeni katılan oyuncuya anlık tekil mesaj gönderir. İstemci hiç saat
-- hesaplamaz, sadece NUI'ye iletir. Bkz. server/clock.lua ve client/clock.lua.
Config.Clock = {
    -- Sunucu -> istemci saat yayını
    updateEvent  = 'loe_hud:client:clockUpdate',
    -- İstemci -> sunucu "saati şimdi gönder" isteği (katılış / resource restart)
    requestEvent = 'loe_hud:server:clockRequest',
    -- Sunucunun dakika değişimini kontrol etme sıklığı (ms).
    -- Paket yalnızca dakika sınırında gider, bu sadece kontrol aralığı.
    pollInterval = 1000,
}

-- Araç panelinde hangi ikonlar görünsün
Config.Vehicle = {
    seatbelt = true,  -- kemer (istemezsen false yap)
    engine   = true,  -- motor açık/kapalı
    lock     = true,  -- kapı kilidi
    cruise   = true,  -- hız sabitleme
    fuel     = true,  -- yakıt %
    health   = true,  -- hasar % (motor + gövde ortalaması)
}

-- Eşikler (%)
Config.FuelLowAt   = 15    -- altı kırmızı
Config.EngineLowAt = 30    -- altı kırmızı

-- Varsayılan GTA para HUD'ını (yeşil cash/bank) gizle — kendi paramız NUI'de
Config.HideDefaultCash = true

-- Varsayılan GTA silah + mermi + şarjör göstergesini gizle (sağ alt, minimap yakını)
Config.HideDefaultWeapon = true

-- Varsayılan GTA polis yıldızlarını gizle — NUI'de kendi 5 yıldızımızı çiziyoruz
-- (sağ üst kümede, cash ile saat arasında). Bkz. Config.Show.wanted
Config.HideDefaultWantedStars = true

-- Araca binince çıkan varsayılan araç adı/sınıfı yazısını gizle
Config.HideVehicleName = true

-- Bölge/mahalle adı (zone değişince çıkan yazı) gizle
Config.HideAreaNames = true

-- Minimap altındaki GTA can/zırh çubuklarını gizle (minimap boyutuna DOKUNMAZ)
Config.HideDefaultHealthArmor = true

-- Yakıt kaynakları (sırayla denenir; statebag/ox_fuel önceliklidir)
Config.FuelResources = { 'ox_fuel', 'cdn-fuel', 'ps-fuel', 'LegacyFuel' }

-- Elektrikli araçlarda (benzin deposu olmayan modeller) yakıt bidonu yerine
-- şimşek ikonu gösterilir. ox_fuel bu araçları takip etmediği için gerçek bir
-- şarj değeri yok — aşağıdaki sabit gösterilir.
-- İleride bir şarj sistemi Entity(veh).state.fuel'i doldurursa HUD otomatik
-- olarak onu kullanmaya başlar, burayı değiştirmene gerek kalmaz.
Config.ElectricCharge = 100

-- Şarjın okunduğu statebag anahtarı. loe_vehicles buraya yazar.
-- Bilerek 'fuel' DEĞİL: ox_fuel o anahtarı kullanıyor ve elektrikli araçlarda
-- değeri 100'e geri çekip şarj tüketimini eziyordu.
-- loe_vehicles/config.lua > electric.stateKey ile aynı olmalı.
Config.ElectricStateKey = 'charge'

-- Hız sabitleme statebag anahtarı (kendi cruise scriptin bunu set edebilir,
-- ya da exports.loe_hud:SetCruise(true/false) çağırabilirsin)
Config.CruiseStateKey = 'cruise'

