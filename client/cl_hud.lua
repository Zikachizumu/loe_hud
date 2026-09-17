--[[
    loe_hud / client
    Qbox (qbx_core) + ox_lib. Veriyi toplar, DEĞİŞTİĞİNDE NUI'ye yollar.
    FPS dostu: her tick sadece okur; NUI mesajı yalnızca bir grup değiştiyse gider.
]]

local qbx = exports.qbx_core

-- Son gönderilen değerler (change-detection)
local last = { status = {}, money = {}, info = {}, street = {}, vehicle = {}, wanted = {}, ammo = {} }

-- ------------------------------------------------------------------ helpers
local function round(v) return math.floor((v or 0) + 0.5) end
local function send(action, data) SendNUIMessage({ action = action, data = data }) end

-- LOCAL DEGISIKLIK (bos test sunucusu): ox_lib'in cache.* tablosu yok, native
-- karsiliklari kullaniliyor. Davranis ox_lib ile ayni tutuldu:
--   cache.vehicle -> araçta degilken nil (native 0 doner, nil'e ceviriyoruz)
--   cache.seat    -> yalnizca -1 (surucu) kontrolu icin kullaniliyordu
local function getVehicleAndSeat()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil, nil end
    return veh, (GetPedInVehicleSeat(veh, -1) == ped) and -1 or 0
end

-- İki düz tablonun alanları aynı mı?
local function same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

local function getPlayerData()
    local ok, pd = pcall(function() return qbx:GetPlayerData() end)
    if ok and type(pd) == 'table' then return pd end
    return nil
end

-- ------------------------------------------------------------------ elektrik
-- Elektrikli araçların benzin deposu yok: handling'deki fPetrolTankVolume 0.
-- Model listesi tutmaya gerek yok, kural genel. (Ölçüm: Khamelion -> depo 0.0,
-- native fuel 0.0, ox_fuel statebag'i nil.)
local fuelTypeCache = {}

-- Motoru olmayan araçlar: yakıt da şarj da göstermeyiz. Bisikletlerin benzin
-- deposu yok, o yüzden depo hacmi kuralına takılıp "elektrikli" görünüyorlardı.
local NO_FUEL_CLASSES = { [13] = true }   -- 13 = Cycles (bisikletler)

--- 'none' | 'electric' | 'petrol'
local function getFuelType(veh)
    local cached = fuelTypeCache[veh]
    if cached ~= nil then return cached end

    local result
    if NO_FUEL_CLASSES[GetVehicleClass(veh)] then
        result = 'none'
    elseif (GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume') or 0.0) <= 0.0 then
        result = 'electric'
    else
        result = 'petrol'
    end

    fuelTypeCache[veh] = result
    return result
end

-- Araç yok olunca önbelleği bırak, entity id'leri geri dönüştürülüyor.
AddEventHandler('entityRemoved', function(entity)
    fuelTypeCache[entity] = nil
end)

-- ------------------------------------------------------------------ fuel
local function getPetrolFuel(veh)
    local sb = Entity(veh).state.fuel
    if sb ~= nil then return sb + 0.0 end
    for _, res in ipairs(Config.FuelResources) do
        if res ~= 'ox_fuel' and GetResourceState(res) == 'started' then
            local ok, val = pcall(function() return exports[res]:GetFuel(veh) end)
            if ok and val then return val + 0.0 end
        end
    end
    return GetVehicleFuelLevel(veh) + 0.0
end

local function getFuel(veh, ftype)
    -- Elektrikli: ox_fuel bu araçları takip etmiyor, native de 0 döner.
    -- loe_vehicles şarjı statebag'e yazıyor; henüz yazmadıysa (araç ilk
    -- kez görülüyor) config'teki başlangıç değeri gösterilir.
    if ftype == 'electric' then
        -- Kendi anahtarımız — 'fuel' değil. ox_fuel elektrikli araçlarda
        -- 'fuel'i 100'e geri çekiyor ve tüketimi eziyordu.
        local sb = Entity(veh).state[Config.ElectricStateKey]
        if sb ~= nil then return sb + 0.0 end
        return Config.ElectricCharge + 0.0
    end

    return getPetrolFuel(veh)
end

-- Hız sabitleme: statebag'den oku (kendi cruise scriptin set edebilir)
local function getCruise()
    return LocalPlayer.state[Config.CruiseStateKey] == true
end
exports('SetCruise', function(v) LocalPlayer.state:set(Config.CruiseStateKey, v == true, true) end)

-- ------------------------------------------------------------------ STATUS loop
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pd  = getPlayerData()
        local meta = (pd and pd.metadata) or {}

        -- Can / zırh / yemek / su
        if Config.Show.status then
            local st = {
                health = round(((GetEntityHealth(ped) - 100) / 100) * 100), -- 100..200 -> 0..100
                armor  = round(GetPedArmour(ped)),
                hunger = round(meta.hunger or 100),
                thirst = round(meta.thirst or 100),
            }
            if st.health < 0 then st.health = 0 end
            if not same(st, last.status) then last.status = st; send('status', st) end
        end

        -- Para
        if Config.Show.money then
            local money = (pd and pd.money) or {}
            local m = { cash = round(money.cash or 0), bank = round(money.bank or 0) }
            if not same(m, last.money) then last.money = m; send('money', m) end
        end

        -- Bilgi: ID + aktif oyuncu + saat
        if Config.Show.info then
            local info = {
                id      = LocalPlayer.state.loeId or '—',
                players = GlobalState.loePlayers or 0,
                -- Saat bilerek burada YOK. #timeVal'i client/clock.lua besliyor
                -- (VPS sistem saati). Buradan oyun saatini de gönderirsek iki
                -- kaynak aynı alana yazar ve saat zıplar.
            }
            if not same(info, last.info) then last.info = info; send('info', info) end
        end

        -- Aranma seviyesi (yıldızlar) — feat/wanted-stars. Oyundan DOĞRUDAN
        -- okunur: hangi resource verirse versin (ev soygunu, banka, polise ateş)
        -- HUD'da görünür. GTA'nın kendi yıldızları Config.HideDefaultWantedStars
        -- ile gizli; burada NUI'de para ile saat arasında çiziliyor.
        -- Değişmedikçe NUI mesajı gitmez — ek yük yok.
        if Config.Show.wanted ~= false then
            local w = { level = GetPlayerWantedLevel(PlayerId()) }
            if not same(w, last.wanted) then last.wanted = w; send('wanted', w) end
        end

        -- Cadde ismi
        if Config.Show.street then
            local p = GetEntityCoords(ped)
            local s = GetStreetNameFromHashKey(GetStreetNameAtCoord(p.x, p.y, p.z))
            local street = { name = s ~= '' and s or '—' }
            if not same(street, last.street) then last.street = street; send('street', street) end
        end

        Wait(Config.StatusTick)
    end
end)

-- ------------------------------------------------------------------ VEHICLE loop
CreateThread(function()
    while true do
        local veh, seat = getVehicleAndSeat()
        local wait = Config.VehicleTick

        if Config.Show.vehicle and veh and seat == -1 then
            local mps   = GetEntitySpeed(veh)
            local speed = Config.SpeedUnit == 'mph' and (mps * 2.236936) or (mps * 3.6)
            local ftype = getFuelType(veh)

            local vd = {
                visible  = true,
                speed    = round(speed),
                unit     = Config.SpeedUnit,
                -- Kemer OYUNCUDA tutuluyor, araçta değil. Araç statebag'i
                -- kullanıldığında önceki sürücünün kemeri yeni binene ait
                -- görünüyor, yolcu ile sürücü de birbirini eziyordu.
                seatbelt = (LocalPlayer.state.seatbelt == true),
                engineOn = GetIsVehicleEngineRunning(veh) == 1 or GetIsVehicleEngineRunning(veh) == true,
                locked   = GetVehicleDoorLockStatus(veh) == 2,
                cruise   = getCruise(),
                fuel     = ftype ~= 'none' and round(getFuel(veh, ftype)) or 0,
                fuelType = ftype,
                -- Premium benzin: loe_gasstation araca yazıyor (premium alınca
                -- true; normal alınca / depo bitince false). Sadece benzinli araçta.
                premium  = ftype == 'petrol' and Entity(veh).state.premiumFuel == true,
                -- Hasar %: motor + gövde ortalaması. Sadece motor sağlığı kullanılırsa
                -- hafif çarpmalar (özellikle ön tampon) gövdeyi hasarlasa da motoru
                -- etkilemediği için yüzde hiç düşmüyordu (yön farkı bu yüzden vardı).
                health   = round(((GetVehicleEngineHealth(veh) + GetVehicleBodyHealth(veh)) / 2000) * 100),
            }
            if vd.health < 0 then vd.health = 0 end
            if vd.health > 100 then vd.health = 100 end
            if not same(vd, last.vehicle) then last.vehicle = vd; send('vehicle', vd) end
        else
            if last.vehicle.visible ~= false then
                last.vehicle = { visible = false }
                send('vehicle', { visible = false })
                wait = Config.StatusTick
            end
        end

        Wait(wait)
    end
end)

-- ------------------------------------------------------------------ AMMO loop
-- Saatin altında: "çantadaki toplam mermi / şarjördeki mermi"  (örn. 150 / 30)
-- Kaynak ox_inventory: mermi item olarak çantada tutulur, silaha yüklenen kısım
-- weapon.metadata.ammo'da. Silah çekili değilken (veya mermi almayan silah:
-- yumruk, bıçak, el bombası) satır gizlenir.
local function getAmmoInfo()
    if GetResourceState('ox_inventory') ~= 'started' then return nil end

    local ok, w = pcall(function() return exports.ox_inventory:getCurrentWeapon() end)
    if not ok or type(w) ~= 'table' or not w.ammo or not w.hash then return nil end

    local ped = PlayerPedId()

    -- Şarjör: namludaki mermi (canlı native değeri; ox metadata'sı geriden gelir)
    local _, clip = GetAmmoInClip(ped, w.hash)
    clip = clip or (w.metadata and w.metadata.ammo) or 0

    -- Çanta: aynı türden ox_inventory mermi item'ının toplam adedi (yüklü olan hariç)
    local reserve = 0
    local ok2, count = pcall(function() return exports.ox_inventory:Search('count', w.ammo) end)
    if ok2 and type(count) == 'number' then reserve = count end

    return reserve, clip
end

if Config.Show.ammo ~= false then
    CreateThread(function()
        while true do
            local wait = 500
            local reserve, clip = getAmmoInfo()
            if reserve then
                wait = 150   -- silah çekiliyken hızlı (ateş ederken şarjör düşüyor)
                local a = { visible = true, reserve = reserve, clip = clip }
                if not same(a, last.ammo) then last.ammo = a; send('ammo', a) end
            elseif last.ammo.visible ~= false then
                last.ammo = { visible = false }
                send('ammo', { visible = false })
            end
            Wait(wait)
        end
    end)
end

-- ------------------------------------------------------------------ HOTKEYS
-- Araç butonlarının altında gösterilen tuşlar. loe_vehicles yolluyor;
-- o resource yoksa hiçbir şey gelmez ve tuşlar gizli kalır.
-- Oyuncu tuşunu değiştirirse loe_vehicles güncelini tekrar gönderir.
AddEventHandler('loe_hud:hotkeys:set', function(keys)
    if type(keys) ~= 'table' then return end
    send('hotkeys', keys)
end)

-- ------------------------------------------------------------------ init
CreateThread(function()
    Wait(500)
    send('config', { show = Config.Vehicle, unit = Config.SpeedUnit,
                     fuelLow = Config.FuelLowAt, engLow = Config.EngineLowAt,
                     groups = Config.Show })

    -- Tuşları iste — HUD, loe_vehicles'tan sonra başlamış olabilir.
    TriggerEvent('loe_hud:hotkeys:request')
end)

-- Varsayılan GTA HUD parçalarını gizle (para + araç adı + bölge adı + silah + yıldız).
-- Kendi verimiz NUI'de.
if Config.HideDefaultCash or Config.HideVehicleName or Config.HideAreaNames
   or Config.HideDefaultWeapon or Config.HideDefaultWantedStars then
    CreateThread(function()
        while true do
            if Config.HideDefaultCash then
                HideHudComponentThisFrame(3)  -- HUD_CASH
                HideHudComponentThisFrame(4)  -- HUD_MP_CASH
            end
            if Config.HideVehicleName then
                HideHudComponentThisFrame(6)  -- HUD_VEHICLE_NAME
                HideHudComponentThisFrame(8)  -- HUD_VEHICLE_CLASS
            end
            if Config.HideAreaNames then
                HideHudComponentThisFrame(7)  -- HUD_AREA_NAME (bölge/mahalle)
            end
            if Config.HideDefaultWeapon then
                HideHudComponentThisFrame(2)  -- HUD_WEAPON_ICON (silah + mermi + şarjör)
            end
            if Config.HideDefaultWantedStars then
                HideHudComponentThisFrame(1)  -- HUD_WANTED_STARS (NUI'de kendimiz çiziyoruz)
            end
            Wait(0)
        end
    end)
end

-- GTA can/zırh çubuklarını gizle — minimap boyutuna dokunmaz (bigmap yenilemesi YOK)
if Config.HideDefaultHealthArmor then
    CreateThread(function()
        local mm = RequestScaleformMovie('minimap')
        while not HasScaleformMovieLoaded(mm) do Wait(0); mm = RequestScaleformMovie('minimap') end
        while true do
            BeginScaleformMovieMethod(mm, 'SETUP_HEALTH_ARMOUR')
            ScaleformMovieMethodAddParamInt(3)  -- 3 = can+zırh gizli
            EndScaleformMovieMethod()
            Wait(0)
        end
    end)
end

-- loe: let other resources (e.g. loe_spawn) hide the entire HUD.
-- Reuses the existing .hidden utility class on the #hud wrapper.
AddEventHandler('loe_hud:client:setVisible', function(visible)
    send('visible', { visible = visible ~= false })
end)

-- ------------------------------------------------------------------ MINIMAP SYNC
-- HUD'u minimap ile eşitle: minimap ekranda değilken (ESC duraklatma menüsü,
-- envanter/çanta açık, ölüm, ara sahne, DisplayRadar(false)) tüm HUD panellerini
-- gizle; minimap geri gelince göster.
--
-- IS_MINIMAP_RENDERING bu durumların hepsinde false döner. NUI'de ayrı bir
-- '.mm-hidden' sınıfı kullanılır — 'visible' (spawn ekranı) ve 'sectionVisible'
-- (cinematic) yollarıyla çakışmaz, hepsi bağımsız katman.
if Config.SyncWithMinimap then
    CreateThread(function()
        local shown = true   -- NUI'ye en son bildirilen durum
        local miss  = 0      -- üst üste "minimap kapalı" okuması (titreme filtresi)
        while true do
            local r = IsMinimapRendering()
            -- Minimap gerçekten ekranda mı? (DisplayRadar(false), HideHudAndRadar,
            -- envanter, ölüm, ara sahne → false. DisplayHud(false) → IsHudHidden.)
            local mapOn = (r == true or r == 1) and not IsHudHidden()

            if IsPauseMenuActive() then
                -- ESC menüsü: anında gizle (menü fade'iyle eş zamanlı, debounce yok)
                miss = 0
                if shown then shown = false; send('minimap', { visible = false }) end
            elseif mapOn then
                miss = 0
                if not shown then shown = true; send('minimap', { visible = true }) end
            else
                -- 1 tick'lik sahte "kapalı" okumasında titremeyi önlemek için
                -- üst üste 2 okuma bekle, sonra gizle.
                miss = miss + 1
                if shown and miss >= 2 then shown = false; send('minimap', { visible = false }) end
            end

            Wait(Config.MinimapTick or 100)
        end
    end)
end

-- ------------------------------------------------------------------ MINIMAP ZOOM
-- Z'ye basınca minimap BİRAZ uzaklaşır: kutunun boyutu SABİT kalır, sadece
-- gösterdiği alan genişler (bigmap/M tuşundan farklı — o ekran düzenini
-- değiştirir). Config.MinimapZoom.duration kadar (varsayılan 5sn) o şekilde
-- kalır, süre dolunca KENDİLİĞİNDEN normale döner — tekrar basmaya gerek
-- yok. Süre içinde tekrar basarsan süre yeniden 5sn'den başlar (uzatma).
--
-- SET_RADAR_ZOOM_PRECISE "ThisFrame" DEĞİL -- yani muhtemelen KALICI (sticky):
-- bir kere çağırınca o zoom'da kalır, sadece çağırmayı KESMEK yetmeyebilir.
-- Bu yüzden süre dolunca sadece durmuyoruz, SET_RADAR_ZOOM(0) ile kontrolü
-- oyuna AÇIKÇA geri veriyoruz -- 0, oyunun kendi (hıza bağlı) dinamik
-- zoom'una döndüğü değer. Zoom'lu süre boyunca yine de her frame
-- yeniden basıyoruz (garantiye almak için, zararı yok).
if Config.MinimapZoom.enabled then
    local zoomedOut = false
    local zoomUntil = 0
    local zoomValue = (Config.MinimapZoom.zoomedValue or 96.0) + 0.0

    RegisterCommand('loe_hud_minimapzoom', function()
        zoomedOut = true
        zoomUntil = GetGameTimer() + (Config.MinimapZoom.duration or 5000)
    end, false)
    RegisterKeyMapping('loe_hud_minimapzoom', 'Minimap: Uzaklaştır (5sn)', 'keyboard', Config.MinimapZoom.key)

    CreateThread(function()
        while true do
            if zoomedOut and GetGameTimer() < zoomUntil then
                SetRadarZoomPrecise(zoomValue)
                Wait(0)
            else
                if zoomedOut then
                    zoomedOut = false
                    SetRadarZoom(0)  -- kontrolü AÇIKÇA oyuna geri ver (bkz. yukarıdaki not)
                end
                Wait(250)   -- normaldeyken oyunun kendi zoom'u çalışır, biz karışmıyoruz
            end
        end
    end)
end

-- ------------------------------------------------------------------ loe_cinematic entegrasyonu
-- Artık hepsini birden değil, /cinesettings'te seçilen HUD gruplarına
-- göre BÖLÜM BÖLÜM gizliyoruz/gösteriyoruz. loe_cinematic kurulu
-- değilse bu event'ler hiç tetiklenmez, zararsız (fxmanifest'e
-- dependency olarak eklemiyoruz — opsiyonel entegrasyon).
local BH_GROUP_MAP = {
    hud_status  = 'status',
    hud_money   = 'money',
    hud_info    = 'info',
    hud_street  = 'street',
    hud_vehicle = 'vehicle',
}

local function ApplyHudGroupState(hidden)
    if type(hidden) ~= 'table' then return end
    for cinematicId, localSection in pairs(BH_GROUP_MAP) do
        send('sectionVisible', { section = localSection, visible = hidden[cinematicId] ~= true })
    end
end

AddEventHandler('loe_cinematic:hudGroupsChanged', function(hidden)
    ApplyHudGroupState(hidden)
end)

AddEventHandler('loe_cinematic:started', function()
    local ok, hidden = pcall(function() return exports.loe_cinematic:GetHudGroupsHidden() end)
    if ok then ApplyHudGroupState(hidden) end
end)

AddEventHandler('loe_cinematic:stopped', function()
    -- Cinematic mod komple bitince kontrolü loe_hud'un kendi
    -- Config.Show ayarlarına geri bırak — hepsini görünür yap.
    for _, localSection in pairs(BH_GROUP_MAP) do
        send('sectionVisible', { section = localSection, visible = true })
    end
end)

-- loe_hud, sinematik mod ZATEN aktifken (yeniden) başlarsa
-- (örn. canlı restart), mevcut durumla senkronize ol.
CreateThread(function()
    Wait(500)
    if GetResourceState('loe_cinematic') ~= 'started' then return end
    local ok, isCinematic = pcall(function() return exports.loe_cinematic:IsCinematicMode() end)
    if ok and isCinematic then
        local ok2, hidden = pcall(function() return exports.loe_cinematic:GetHudGroupsHidden() end)
        if ok2 then ApplyHudGroupState(hidden) end
    end
end)

