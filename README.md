# loe_hud

Qbox için premium, modüler, FPS dostu HUD. Tamamen şeffaf paneller, altın (#D4AF37)
vurgular, Inter fontu. NUI yalnızca **veri değiştiğinde** güncellenir.

## Bileşenler

- **Sağ üst:** ID + aktif oyuncu sayısı (insan ikonu) → Bank / Cash (sadece ikon + tutar) → saat
- **Sol alt (minimap yanı):** can (kırmızı) · zırh (yeşil) · yemek (turuncu) · su (mavi) — ikon + altında %
- **Sol alt (minimap üstü):** okunabilir cadde ismi
- **Sağ alt (araç):** premium cam **hız göstergesi** — 4 yükselen segment (0-100 beyaz, 101-200 yeşil, 201-300 sarı, 301+ kırmızı, yaylı doluş), ortada büyük hız, altında 6 cam gösterge: motor · kemer · kapı kilidi · hız sabitleme · yakıt % · motor sağlığı %
  - Motor: çalışıyor yeşil / kapalı gri · Kemer: takılı yeşil, değil kırmızı, >60 km/s takılı değilse yavaş yanıp söner
  - Kilit: kilitli mavi / açık turuncu · Cruise: aktif teal
  - Yakıt: <%20 pulse, <%10 kırmızı flash · Motor sağlığı: >70 yeşil, 30-70 sarı, <30 kırmızı + titreme

## Gereksinimler

- `qbx_core`, `ox_lib`
- (opsiyonel) yakıt kaynağı: `ox_fuel` / `cdn-fuel` / `ps-fuel` / `LegacyFuel`
- (opsiyonel) `pma-voice`

## Klasör yapısı

```
loe_hud/
├── fxmanifest.lua
├── config.lua
├── client/cl_hud.lua
├── server/sv_hud.lua        # aktif oyuncu sayısı (GlobalState)
└── html/
    ├── index.html
    ├── css/style.css
    ├── js/app.js
    └── icons/*.svg           # mask ile renklenen ikonlar
```

## Kurulum

`server.cfg` (bağımlılıklardan sonra):
```
ensure ox_lib
ensure qbx_core
ensure loe_hud
```

## Ayarlar (`config.lua`)

| Ayar | Açıklama |
|------|----------|
| `Config.SpeedUnit` | `kmh` / `mph` |
| `Config.StatusTick` / `VehicleTick` | okuma sıklığı (ms) |
| `Config.Show` | bölüm görünürlüğü |
| `Config.Vehicle` | araç ikonları (örn. `seatbelt=false` ile kemeri kapat) |
| `Config.FuelLowAt` / `EngineLowAt` | kırmızıya döneceği % eşiği |

## Veri kaynakları

- Can/zırh: native · açlık/susuzluk: `qbx_core` metadata · para: `qbx_core` money
- ID: server ID · oyuncu sayısı: `server/sv_hud.lua` → GlobalState · saat: oyun saati
- Araç: `ox_lib` cache; motor aç/kapa, kapı kilidi, motor sağlığı native; yakıt statebag/kaynak
- **Hız sabitleme:** statebag. Kendi cruise scriptinden:
  `exports.loe_hud:SetCruise(true/false)`
- **Kemer:** `Entity(veh).state:set('seatbelt', true, true)`

## Konum ince ayarı

Durum göstergeleri ve cadde plakası minimap'e göre konumlanır. Çözünürlüğünde kayarsa
`css/style.css` içindeki değişkenleri ayarla:
`--status-left`, `--status-bottom`, `--street-left`, `--street-bottom`.

## Güncelleme (git)

Masaüstünde commit + push → VPS'te:
```
cd .../resources/'[loe]' && git pull
```
sonra konsolda `restart loe_hud` (NUI değişince restart gerekir).

