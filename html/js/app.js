/* ============================================================
   loe_hud — app.js
   Sadece veri değişince DOM güncellenir. requestAnimationFrame yok,
   sürekli döngü yok; her şey gelen mesajla tetiklenir (FPS dostu).
   ============================================================ */
(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const nf = new Intl.NumberFormat('tr-TR');

  // Eşikler (config'ten güncellenir)
  let fuelLow = 15, engLow = 30;

  // Yakıt göstergesi config'te açık mı? Araç bazlı gizleme (bisiklet) bu
  // ayarı geçersiz kılmamalı — kapalıysa kapalı kalsın.
  let fuelEnabled = true;

  // Para fade için son değerler
  let shownCash = null, shownBank = null;

  // Aranma yıldızı — en son gösterilen seviye (yeni yanan yıldıza pulse için)
  let shownWanted = 0;

  const pad2 = (n) => String(n).padStart(2, '0');

  const setMoney = (el, value, prev) => {
    el.textContent = nf.format(value);
    if (prev !== null && prev !== value) {
      el.classList.remove('fade'); void el.offsetWidth; el.classList.add('fade');
    }
  };

  // Hız sayısı için kısa ölçek darbesi
  let bumpT;
  const bump = (el) => { el.classList.add('bump'); clearTimeout(bumpT); bumpT = setTimeout(() => el.classList.remove('bump'), 150); };

  // Segment aralıkları (KM/H)
  const SEG_RANGES = [[0,100],[100,200],[200,300],[300,400]];
  const SEG_COLORS = ['#f4f6fb','#4fd08a','#f2c94c','#eb5757'];

  window.addEventListener('message', (ev) => {
    const { action, data } = ev.data || {};
    if (!action) return;

    // loe: global show/hide, used by loe_spawn during the spawn screen.
    if (action === 'visible') {
      document.getElementById('hud').classList.toggle('hidden', data && data.visible === false);
      return;
    }

    // Minimap ile eşitleme: minimap ekranda değilken (ESC menü, envanter, vb.)
    // tüm HUD gizlenir. Ayrı sınıf — 'visible'/'sectionVisible' ile çakışmaz.
    if (action === 'minimap') {
      document.getElementById('hud').classList.toggle('mm-hidden', data && data.visible === false);
      return;
    }

    // ---------------- loe_cinematic: bölüm bölüm göster/gizle ----------------
    // Yukarıdaki 'config' handler'daki kalıcı gizlemeden ayrı tutuluyor —
    // o tek seferlik/kalıcı, bu ise cinematic moda girip çıkarken geri
    // alınabilir olmalı. display='' ile bırakınca, o bölümün kendi normal
    // (data/vehicle-varlığı bazlı) görünürlük mantığı devreye giriyor.
    if (action === 'sectionVisible') {
      const { section, visible } = data || {};
      const map = {
        status: () => [$('status')],
        street: () => [$('street')],
        vehicle: () => [$('vehicle')],
        money: () => Array.from(document.querySelectorAll('[data-group="money"]')),
        info: () => Array.from(document.querySelectorAll('[data-group="info"]')),
      };
      const getEls = map[section];
      if (getEls) getEls().forEach((el) => { if (el) el.style.display = visible === false ? 'none' : ''; });
      return;
    }

    // ---------------- config: görünürlük + eşikler ----------------
    if (action === 'config') {
      fuelLow = data.fuelLow ?? fuelLow;
      engLow  = data.engLow ?? engLow;

      // Bölüm görünürlüğü
      const g = data.groups || {};
      if (g.status === false)  $('status').style.display = 'none';
      if (g.street === false)  $('street').style.display = 'none';
      if (g.vehicle === false) $('vehicle').style.display = 'none';
      if (g.money === false) document.querySelectorAll('[data-group="money"]').forEach((e) => e.style.display = 'none');
      if (g.info === false)  document.querySelectorAll('[data-group="info"]').forEach((e) => e.style.display = 'none');
      // Aranma yıldızı satırı 'info' grubunda (data-group="info") — saat ile
      // birlikte gizlenir. Ayrıca kendi Config.Show.wanted anahtarıyla da kapatılır.
      if (g.wanted === false) { const s = $('wantedRow'); if (s) s.style.display = 'none'; }
      // Mermi sayacı da 'info' grubunda; kendi Config.Show.ammo anahtarıyla kapatılır.
      if (g.ammo === false) { const s = $('ammoRow'); if (s) s.style.display = 'none'; }

      // Araç ikon görünürlüğü
      const v = data.show || {};
      const map = { seatbelt:'tgBelt', engine:'tgEngine', lock:'tgLock', cruise:'tgCruise', fuel:'mtFuel', health:'mtHealth' };
      for (const key in map) {
        if (v[key] === false) { const el = $(map[key]); if (el) el.style.display = 'none'; }
      }
      fuelEnabled = v.fuel !== false;

      $('speedUnit').textContent = data.unit === 'mph' ? 'MPH' : 'KM/H';
      return;
    }

    // ---------------- hotkeys: araç butonlarının altındaki tuşlar ----------------
    // loe_vehicles gönderir. Oyuncu tuşunu değiştirdiğinde güncellenir.
    if (action === 'hotkeys') {
      const map = { engine:'hkEngine', seatbelt:'hkBelt', cruise:'hkCruise', lock:'hkLock' };
      for (const name in map) {
        const el = $(map[name]);
        if (!el) continue;
        const key = data && data[name];
        el.textContent = key || '';
        el.classList.toggle('show', !!key);
      }
      return;
    }

    // ---------------- durum: can / zırh / yemek / su ----------------
    if (action === 'status') {
      $('status').classList.remove('hidden');
      $('healthPct').textContent = data.health + '%';
      $('armorPct').textContent  = data.armor + '%';
      $('hungerPct').textContent = data.hunger + '%';
      $('thirstPct').textContent = data.thirst + '%';
      return;
    }

    // ---------------- aranma yıldızları (feat/wanted-stars) ----------------
    // GTA'nın kendi yıldızları gizli; burada para ile saat arasında 5 ★ var.
    // level 0 -> satır .hidden (akıştan çıkar), saat yukarı kayar (HUD eski hâli).
    // level 1..5 -> satır görünür (saati flex akışı bir satır aşağı iter),
    //               DOM'daki ilk N yıldız 'on' (altın). CSS row-reverse ile
    //               DOM 1. yıldız EN SAĞDA → yıldızlar SAĞDAN SOLA dolar.
    //               Seviye ARTINCA yeni yanan yıldız bir kez 'pulse' atar.
    if (action === 'wanted') {
      const lvl = Math.max(0, Math.min(5, parseInt(data && data.level, 10) || 0));
      const row = $('wantedRow');
      if (row) {
        row.classList.toggle('hidden', lvl === 0);
        row.querySelectorAll('.star').forEach((el, i) => {
          const on = i < lvl;
          el.classList.toggle('on', on);
          if (on && i >= shownWanted) {
            // yeni yanan yıldız — pulse'ı yeniden tetikle
            el.classList.remove('pulse'); void el.offsetWidth; el.classList.add('pulse');
          } else if (!on) {
            el.classList.remove('pulse');
          }
        });
        shownWanted = lvl;
      }
      return;
    }

    // ---------------- mermi: çanta toplamı / şarjör (saat altı) ----------------
    // Silah çekiliyken görünür. data.reserve = çantadaki toplam, data.clip = şarjör.
    if (action === 'ammo') {
      const row = $('ammoRow');
      if (!row) return;
      if (!data || data.visible === false) { row.classList.add('hidden'); return; }
      row.classList.remove('hidden');
      $('ammoReserve').textContent = data.reserve;
      $('ammoClip').textContent = data.clip;
      return;
    }

    // ---------------- para: bank / cash ----------------
    if (action === 'money') {
      $('cluster').classList.remove('hidden');
      setMoney($('bankVal'), data.bank, shownBank); shownBank = data.bank;
      setMoney($('cashVal'), data.cash, shownCash); shownCash = data.cash;
      return;
    }

    // ---------------- bilgi: ID + oyuncu + saat ----------------
    if (action === 'info') {
      $('cluster').classList.remove('hidden');
      $('idVal').textContent = data.id;
      $('playersVal').textContent = data.players;
      return;
    }

    // ---------------- saat: VPS sistem saati ----------------
    // Tek kaynak client/clock.lua. 'info' bilerek saate dokunmuyor —
    // iki kaynak aynı alana yazarsa saat oyun saati ile zıplar.
    if (action === 'clock') {
      $('timeVal').textContent = pad2(data.hour) + ':' + pad2(data.minute);
      return;
    }

    // ---------------- cadde ----------------
    if (action === 'street') {
      $('street').classList.remove('hidden');
      $('streetVal').textContent = data.name;
      return;
    }

    // ---------------- araç (segmentli hız göstergesi) ----------------
    if (action === 'vehicle') {
      const veh = $('vehicle');
      if (!data.visible) { veh.classList.add('hidden'); return; }
      veh.classList.remove('hidden');

      const speed = data.speed;

      // Merkez hız + renk (aktif üst segment) + ölçek darbesi
      const sEl = $('speedVal');
      sEl.textContent = speed;
      const top = speed > 300 ? 3 : speed > 200 ? 2 : speed > 100 ? 1 : 0;
      sEl.style.color = SEG_COLORS[top];
      bump(sEl);
      $('speedUnit').textContent = data.unit === 'mph' ? 'MPH' : 'KM/H';

      // 4 segment: soldan sağa dolar (scaleX), her biri kendi aralığında
      for (let i = 0; i < 4; i++) {
        const [lo, hi] = SEG_RANGES[i];
        const f = Math.max(0, Math.min(1, (speed - lo) / (hi - lo)));
        $('seg' + i).style.transform = 'scaleX(' + f.toFixed(3) + ')';
      }

      // Toggle'lar: aktifken altın sarı (motor / kemer / kilit / cruise)
      $('tgEngine').classList.toggle('on', data.engineOn);
      $('tgBelt').classList.toggle('on', data.seatbelt);
      $('tgLock').classList.toggle('on', data.locked);
      $('tgCruise').classList.toggle('on', data.cruise);

      // Yakıt ve motor sağlığı: %25 altında kırmızı
      $('fuelVal').textContent = data.fuel + '%';
      $('mtFuel').classList.toggle('crit', data.fuel < 25);
      // Premium benzinli araç: pompa ikonu pembe (bkz. style.css .ind.fuel.premium)
      $('mtFuel').classList.toggle('premium', data.premium === true);

      // Yakıt türü: 'petrol' bidon, 'electric' şimşek, 'none' hiç gösterme.
      // 'none' bisiklet gibi motoru olmayan araçlar için — onların deposu da
      // yok, o yüzden depo hacmi kuralına takılıp elektrikli görünüyorlardı.
      const ftype = data.fuelType || 'petrol';
      $('mtFuel').style.display = (fuelEnabled && ftype !== 'none') ? '' : 'none';

      const fuelIcon = $('mtFuel').querySelector('.ic');
      if (fuelIcon) {
        fuelIcon.classList.toggle('ic-electric', ftype === 'electric');
        fuelIcon.classList.toggle('ic-fuel', ftype === 'petrol');
      }
      $('healthVal').textContent = data.health + '%';
      $('mtHealth').classList.toggle('crit', data.health < 25);
      return;
    }
  });
})();

