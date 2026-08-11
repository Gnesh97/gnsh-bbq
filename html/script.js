// Kapanis animasyonu suresi (style.css -> hudSlideOut ile ayni olmali)
const HUD_HIDE_DURATION = 300;
let hudHideTimer = null;

function handleHudMessage(data) {
    if (!data) return;

    const hudContainer = document.getElementById('heat-hud-container');
    if (!hudContainer) return;

    if (data.action === 'openHeatHud' || data.action === 'updateHeatHud') {
        // Kapanis animasyonu sirasinda geri yaklasilirsa iptal et
        if (hudHideTimer !== null) {
            clearTimeout(hudHideTimer);
            hudHideTimer = null;
        }
        hudContainer.classList.remove('hiding');
        hudContainer.classList.add('active');

        if (data.action === 'updateHeatHud') {
            const heat = Math.min(100, Math.max(0, data.heat !== undefined ? data.heat : 50));
            const speedTextVal = data.speedText || '1.0x Normal';

            const heatBar = document.getElementById('heat-bar');
            const heatText = document.getElementById('heat-text');
            const speedText = document.getElementById('speed-text');
            const thermo = document.getElementById('thermo');

            // Dikey termometre: yukseklik ile dolar.
            // Hazne tupun alt ~%9'unu ortuyor, bu yuzden dusuk isilarda
            // dolgunun gorunur kalmasi icin taban %12'ye sabitlenir.
            if (heatBar) heatBar.style.height = (heat > 0 ? Math.max(12, heat) : 0) + '%';
            if (heatText) heatText.textContent = '%' + heat;
            if (speedText) speedText.textContent = speedTextVal;

            if (thermo) {
                thermo.classList.remove('heat-high', 'heat-normal', 'heat-low');

                if (heat >= 80) {
                    thermo.classList.add('heat-high');
                } else if (heat >= 40) {
                    thermo.classList.add('heat-normal');
                } else {
                    thermo.classList.add('heat-low');
                }
            }
        }
    } else if (data.action === 'closeHeatHud') {
        // Zaten kapali veya kapanmakta ise tekrar tetikleme
        if (!hudContainer.classList.contains('active')) return;
        if (hudContainer.classList.contains('hiding')) return;

        hudContainer.classList.add('hiding');
        hudHideTimer = setTimeout(function () {
            hudContainer.classList.remove('active', 'hiding');
            hudHideTimer = null;
        }, HUD_HIDE_DURATION);
    }
}

// ====================================================
// MANGAL MENUSU (Slot Kontrolu & Et Secimi)
// ====================================================
const MENU_HIDE_DURATION = 180;
const IS_PREVIEW = window.location.protocol === 'file:';

const RESOURCE_NAME = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : 'mangal_script';

let menuHideTimer = null;
let menuView = null;      // 'slots' | 'recipes'
let menuNetId = null;
let menuTargetSlot = null;
let menuSeasoningId = null; // secili baharat (recipes ekraninda), null = yok
let burnWarnedSlots = {}; // "netId:slotIndex" -> true (bip tekrarini onler)
let lastSlotsPayload = null;
let grillActionLocked = false;

function nuiPost(endpoint, payload) {
    if (IS_PREVIEW) {
        console.log('[preview] ' + endpoint, payload);
        return Promise.resolve();
    }
    return fetch('https://' + RESOURCE_NAME + '/' + endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {})
    }).catch(function () { /* NUI kapanmis olabilir, yut */ });
}

function el(id) { return document.getElementById(id); }

function statusInfo(status) {
    if (status === 'BURNT') return { cls: 'burnt', label: 'YANMIŞ' };
    if (status === 'COOKED') return { cls: 'cooked', label: 'PİŞMİŞ' };
    return { cls: 'raw', label: 'ÇİĞ' };
}

function buildSlotRow(slot, burnThreshold, canAddMeat, warnOptions) {
    const row = document.createElement('div');
    row.className = 'row' + (slot.occupied ? '' : ' is-empty');
    if (!slot.occupied && !canAddMeat) row.classList.add('is-disabled');
    row.dataset.slot = slot.index;
    row.dataset.occupied = slot.occupied ? '1' : '0';

    const main = document.createElement('div');
    main.className = 'row-main';

    const idx = document.createElement('span');
    idx.className = 'row-index';
    idx.textContent = slot.index;
    main.appendChild(idx);

    const text = document.createElement('div');
    text.className = 'row-text';

    const title = document.createElement('span');
    title.className = 'row-title';
    const sub = document.createElement('span');
    sub.className = 'row-sub';

    if (slot.occupied) {
        const st = statusInfo(slot.status);
        const shown = Math.min(100, slot.progress);

        const warnKey = warnOptions ? (warnOptions.netId + ':' + slot.index) : null;
        const isWarning = !!(warnOptions && st.cls !== 'burnt'
            && typeof warnOptions.percent === 'number' && slot.progress >= warnOptions.percent);

        title.textContent = slot.label;
        if (isWarning) {
            sub.textContent = warnOptions.text || 'DİKKAT, YANIYOR!';
            row.classList.add('burn-warning');
            if (!burnWarnedSlots[warnKey]) {
                burnWarnedSlots[warnKey] = true;
                if (warnOptions.sound) playBurnBeep();
            }
        } else {
            sub.textContent = st.cls === 'burnt'
                ? 'Yanmış - toplamak için tıkla'
                : 'Pişme %' + slot.progress + ' - toplamak için tıkla';
            if (warnKey) delete burnWarnedSlots[warnKey];
        }

        const pill = document.createElement('span');
        pill.className = 'pill ' + st.cls;
        pill.textContent = st.label;

        text.appendChild(title);
        text.appendChild(sub);
        main.appendChild(text);
        main.appendChild(pill);
        row.appendChild(main);

        // Pisme cubugu (+ %100 sonrasi yanma payi)
        const bar = document.createElement('div');
        bar.className = 'row-bar';

        const fill = document.createElement('div');
        fill.className = 'row-fill ' + (st.cls === 'raw' ? '' : st.cls);
        fill.style.width = shown + '%';
        bar.appendChild(fill);

        if (slot.progress > 100) {
            const burnSpan = Math.max(1, (burnThreshold || 180) - 100);
            const burnPct = Math.min(100, ((slot.progress - 100) / burnSpan) * 100);
            const burn = document.createElement('div');
            burn.className = 'row-burn';
            burn.style.width = burnPct + '%';
            bar.appendChild(burn);
        }

        row.appendChild(bar);
    } else {
        if (warnOptions) delete burnWarnedSlots[warnOptions.netId + ':' + slot.index];

        title.textContent = 'Boş Bölme';
        sub.textContent = canAddMeat ? 'Et eklemek için tıkla' : 'Et eklemek için mangalı yak';

        const pill = document.createElement('span');
        pill.className = 'pill';
        pill.textContent = 'BOŞ';

        text.appendChild(title);
        text.appendChild(sub);
        main.appendChild(text);
        main.appendChild(pill);
        row.appendChild(main);
    }

    row.addEventListener('click', function () {
        if (!slot.occupied && !canAddMeat) return;
        nuiPost('slotSelected', {
            slotIndex: slot.index,
            occupied: !!slot.occupied,
            status: slot.status
        });
    });

    return row;
}

function grillStateLabel(state) {
    if (state === 'LIT') return 'YANIYOR';
    if (state === 'HAS_COAL') return 'YAKILMADI';
    return 'KÖMÜR YOK';
}

function createGrillAction(action, icon, label, enabled, danger) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'grill-action' + (danger ? ' danger' : '') + (icon ? ' has-icon' : '');
    button.disabled = !enabled || grillActionLocked;
    button.innerHTML = (icon ? '<span class="grill-action-icon">' + icon + '</span>' : '')
        + '<strong>' + label + '</strong>';

    button.addEventListener('click', function () {
        if (button.disabled) return;
        grillActionLocked = true;
        renderGrillActions(lastSlotsPayload || {});
        nuiPost('grillAction', { action: action });

        setTimeout(function () {
            grillActionLocked = false;
            if (lastSlotsPayload) renderGrillActions(lastSlotsPayload);
        }, 1200);
    });

    return button;
}

function renderGrillActions(data) {
    const actions = el('menu-actions');
    const state = data.state || 'EMPTY';
    actions.style.display = 'grid';
    actions.innerHTML = '';
    actions.appendChild(createGrillAction('addCoal', null, 'Kömür Ekle', state === 'EMPTY', false));
    actions.appendChild(createGrillAction('light', null, 'Mangalı Yak', state === 'HAS_COAL', false));
    actions.appendChild(createGrillAction('fan', null, 'Yelpazele', state === 'LIT', false));
    actions.appendChild(createGrillAction('remove', '✕', 'Mangalı Topla', data.isOwner === true, true));
}

function buildRecipeRow(recipe, index) {
    const row = document.createElement('div');
    row.className = 'row';
    if (recipe.hasRawItem === true) row.classList.add('has-raw-item');

    const main = document.createElement('div');
    main.className = 'row-main';

    const idx = document.createElement('span');
    idx.className = 'row-index';
    idx.textContent = index;
    main.appendChild(idx);

    const text = document.createElement('div');
    text.className = 'row-text';

    const title = document.createElement('span');
    title.className = 'row-title';
    title.textContent = recipe.label;

    const sub = document.createElement('span');
    sub.className = 'row-sub';
    sub.textContent = recipe.cookTime + ' saniye pişirme süresi';

    text.appendChild(title);
    text.appendChild(sub);
    main.appendChild(text);
    row.appendChild(main);

    row.addEventListener('click', function () {
        nuiPost('recipeSelected', {
            recipeId: recipe.id,
            targetSlot: menuTargetSlot,
            seasoningId: menuSeasoningId
        });
    });

    return row;
}

function buildSeasoningBar(seasonings) {
    const bar = document.createElement('div');
    bar.className = 'seasoning-bar';

    function buildChip(id, label, disabled) {
        const chip = document.createElement('div');
        chip.className = 'seasoning-chip';
        if (id === menuSeasoningId) chip.classList.add('active');
        if (disabled) chip.classList.add('disabled');
        chip.textContent = label;

        chip.addEventListener('click', function () {
            if (disabled) return;
            menuSeasoningId = (menuSeasoningId === id) ? null : id;
            bar.querySelectorAll('.seasoning-chip').forEach(function (c) { c.classList.remove('active'); });
            if (menuSeasoningId === id) chip.classList.add('active');
        });

        return chip;
    }

    bar.appendChild(buildChip(null, 'Baharatsız', false));
    seasonings.forEach(function (seasoning) {
        bar.appendChild(buildChip(seasoning.id, seasoning.label, seasoning.hasItem !== true));
    });

    return bar;
}

function renderSlots(data) {
    lastSlotsPayload = data;
    menuView = 'slots';
    menuNetId = data.netId !== undefined ? data.netId : menuNetId;

    el('menu-title').textContent = data.title || 'IZGARA BÖLMELERİ';

    const slots = data.slots || [];
    const used = slots.filter(function (s) { return s.occupied; }).length;
    el('menu-subtitle').textContent = grillStateLabel(data.state) + ' · Isı %' + (data.heat || 0) + ' · ' + used + ' / ' + slots.length + ' bölme';
    renderGrillActions(data);

    const warnOptions = (typeof data.burnWarnPercent === 'number') ? {
        netId: data.netId,
        percent: data.burnWarnPercent,
        sound: data.burnWarnSound !== false,
        text: data.burnWarnText
    } : null;

    const body = el('menu-body');
    body.innerHTML = '';
    slots.forEach(function (slot) {
        body.appendChild(buildSlotRow(slot, data.burnThreshold, data.canAddMeat === true, warnOptions));
    });

    el('menu-back').classList.remove('visible');
}

function renderRecipes(data) {
    menuView = 'recipes';
    el('menu-actions').style.display = 'none';
    menuTargetSlot = data.targetSlot !== undefined ? data.targetSlot : null;
    menuSeasoningId = null;

    el('menu-title').textContent = data.title || 'ET SEÇİMİ';
    el('menu-subtitle').textContent = menuTargetSlot
        ? ('Bölme ' + menuTargetSlot + ' için bir et seç')
        : 'Bir et seç';

    const body = el('menu-body');
    body.innerHTML = '';

    const seasonings = data.seasonings || [];
    if (seasonings.length > 0) {
        body.appendChild(buildSeasoningBar(seasonings));
    }

    const recipes = data.recipes || [];
    if (recipes.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'menu-empty';
        empty.textContent = 'Üzerinizde pişirilecek çiğ malzeme yok.';
        body.appendChild(empty);
    } else {
        recipes.forEach(function (recipe, i) {
            body.appendChild(buildRecipeRow(recipe, i + 1));
        });
    }

    el('menu-back').classList.add('visible');
}

// ---------------- Menu Konumu (surukle-birak) ----------------
const MENU_POS_KEY = 'mangal_menu_pos';
const MENU_EDGE = 8; // ekran kenarindan birakilacak minimum bosluk

let dragState = null;
let menuPos = null; // { x, y } | null => ortalanmis

function loadMenuPos() {
    try {
        const raw = window.localStorage.getItem(MENU_POS_KEY);
        if (!raw) return null;
        const parsed = JSON.parse(raw);
        if (typeof parsed.x !== 'number' || typeof parsed.y !== 'number') return null;
        return parsed;
    } catch (e) {
        return null;
    }
}

function saveMenuPos(pos) {
    try {
        if (pos) {
            window.localStorage.setItem(MENU_POS_KEY, JSON.stringify(pos));
        } else {
            window.localStorage.removeItem(MENU_POS_KEY);
        }
    } catch (e) { /* localStorage kapaliysa oturum boyunca hafizada tutulur */ }
}

// Kart ekran disinda kalmasin: gorunur alana geri cek
function clampMenuPos(x, y) {
    const card = el('menu-card');
    const w = card.offsetWidth;
    const h = card.offsetHeight;
    const maxX = Math.max(MENU_EDGE, window.innerWidth - w - MENU_EDGE);
    const maxY = Math.max(MENU_EDGE, window.innerHeight - h - MENU_EDGE);

    return {
        x: Math.min(Math.max(MENU_EDGE, x), maxX),
        y: Math.min(Math.max(MENU_EDGE, y), maxY)
    };
}

function applyMenuPos() {
    const card = el('menu-card');

    if (!menuPos) {
        card.classList.remove('positioned');
        card.style.left = '';
        card.style.top = '';
        return;
    }

    // Kart yuksekligi goruntuye gore degistigi icin her acilista yeniden kirp
    card.classList.add('positioned');
    const safe = clampMenuPos(menuPos.x, menuPos.y);
    menuPos = safe;
    card.style.left = safe.x + 'px';
    card.style.top = safe.y + 'px';
}

function centerMenu() {
    menuPos = null;
    saveMenuPos(null);
    applyMenuPos();
}

function initMenuDrag() {
    const card = el('menu-card');
    const header = el('menu-header');

    header.addEventListener('mousedown', function (event) {
        if (event.button !== 0) return;
        if (event.target.closest('.menu-close')) return;

        const rect = card.getBoundingClientRect();

        // Ortalanmis durumdan mutlak konuma gec (kart yerinden oynamadan)
        card.classList.add('positioned');
        card.style.left = rect.left + 'px';
        card.style.top = rect.top + 'px';
        card.classList.add('dragging');

        dragState = {
            offsetX: event.clientX - rect.left,
            offsetY: event.clientY - rect.top
        };

        event.preventDefault();
    });

    header.addEventListener('dblclick', function (event) {
        if (event.target.closest('.menu-close')) return;
        centerMenu();
    });

    document.addEventListener('mousemove', function (event) {
        if (!dragState) return;

        const safe = clampMenuPos(
            event.clientX - dragState.offsetX,
            event.clientY - dragState.offsetY
        );

        menuPos = safe;
        card.style.left = safe.x + 'px';
        card.style.top = safe.y + 'px';
    });

    document.addEventListener('mouseup', function () {
        if (!dragState) return;
        dragState = null;
        card.classList.remove('dragging');
        saveMenuPos(menuPos);
    });

    window.addEventListener('resize', function () {
        if (menuPos) applyMenuPos();
    });
}

function showMenu() {
    const overlay = el('mangal-menu-overlay');
    if (menuHideTimer !== null) {
        clearTimeout(menuHideTimer);
        menuHideTimer = null;
    }
    overlay.classList.remove('hiding');
    overlay.classList.add('active');
    el('menu-body').scrollTop = 0;

    // Konum ancak kart gorunurken olculebilir
    applyMenuPos();
}

function hideMenu(notifyLua) {
    const overlay = el('mangal-menu-overlay');
    if (!overlay.classList.contains('active')) return;
    if (overlay.classList.contains('hiding')) return;

    overlay.classList.add('hiding');
    menuHideTimer = setTimeout(function () {
        overlay.classList.remove('active', 'hiding');
        menuHideTimer = null;
    }, MENU_HIDE_DURATION);

    menuView = null;
    menuTargetSlot = null;

    if (menuNetId !== null) {
        const prefix = menuNetId + ':';
        Object.keys(burnWarnedSlots).forEach(function (key) {
            if (key.indexOf(prefix) === 0) delete burnWarnedSlots[key];
        });
    }
    menuNetId = null;

    if (notifyLua) nuiPost('menuClosed', {});
}

function handleMenuMessage(data) {
    if (data.action === 'openSlotMenu') {
        renderSlots(data);
        showMenu();
    } else if (data.action === 'updateSlotMenu') {
        // Menu acikken canli guncelleme: sadece slot goruntusundeyken
        if (menuView === 'slots') renderSlots(data);
    } else if (data.action === 'openMeatMenu') {
        renderRecipes(data);
        showMenu();
    } else if (data.action === 'closeMangalMenu') {
        hideMenu(false);
    }
}

document.addEventListener('DOMContentLoaded', function () {
    menuPos = loadMenuPos();
    initMenuDrag();

    el('menu-close').addEventListener('click', function () {
        hideMenu(true);
    });

    el('menu-back').addEventListener('click', function () {
        if (lastSlotsPayload) {
            renderSlots(lastSlotsPayload);
            nuiPost('backToSlots', {});
        } else {
            hideMenu(true);
        }
    });

    el('mangal-menu-overlay').addEventListener('mousedown', function (event) {
        // Karta degil, disari tiklandiysa kapat
        if (event.target === el('mangal-menu-overlay')) hideMenu(true);
    });
});

document.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape' && event.key !== 'Backspace') return;
    const overlay = el('mangal-menu-overlay');
    if (!overlay.classList.contains('active')) return;

    if (event.key === 'Backspace' && menuView === 'recipes' && lastSlotsPayload) {
        renderSlots(lastSlotsPayload);
        nuiPost('backToSlots', {});
        return;
    }
    hideMenu(true);
});

// ====================================================
// YANMA UYARI SESI (WebAudio, harici dosya gerekmez)
// ====================================================
let burnAudioCtx = null;
function playBurnBeep() {
    try {
        if (!burnAudioCtx) burnAudioCtx = new (window.AudioContext || window.webkitAudioContext)();
        [0, 0.18].forEach(function (offset) {
            const osc = burnAudioCtx.createOscillator();
            const gain = burnAudioCtx.createGain();
            osc.type = 'square';
            osc.frequency.value = 880;
            gain.gain.value = 0.06;
            osc.connect(gain);
            gain.connect(burnAudioCtx.destination);
            const t = burnAudioCtx.currentTime + offset;
            osc.start(t);
            osc.stop(t + 0.09);
        });
    } catch (e) { /* AudioContext yoksa sessiz gec */ }
}

// ====================================================
// MANGAL SESI (Config.SoundEngine = 'nui')
// Lua mesafe/isiya gore ses seviyesini hesaplayip gonderir,
// burada sadece calma/durdurma ve seviye uygulanir.
// ====================================================
const GRILL_FADE_STEP_MS = 40;

let grillAudioSrc = null;
let grillTargetVolume = 0;
let grillFadeTimer = null;
let grillFadeMs = 800;
let grillMaxVolume = 1;   // Config.SoundVolume - fade adimi buna gore olceklenir

// Fade adimi tam ses araligina (0 -> SoundVolume) gore hesaplanir.
// Boylece SoundVolume 0.05 de olsa 1.0 da olsa fade ayni surede biter.
function grillFadeStep() {
    if (grillFadeMs <= 0) return 1;
    const span = grillMaxVolume > 0 ? grillMaxVolume : 1;
    return span * (GRILL_FADE_STEP_MS / grillFadeMs);
}

function stopGrillFadeLoop() {
    if (grillFadeTimer === null) return;
    clearInterval(grillFadeTimer);
    grillFadeTimer = null;
}

function startGrillFadeLoop() {
    if (grillFadeTimer !== null) return;

    grillFadeTimer = setInterval(function () {
        const audio = el('grill-audio');
        if (!audio) {
            stopGrillFadeLoop();
            return;
        }

        const step = grillFadeStep();
        const diff = grillTargetVolume - audio.volume;

        if (Math.abs(diff) <= step) {
            audio.volume = Math.max(0, Math.min(1, grillTargetVolume));

            // Hedefe ulasildi: sifirsa durdur, degilse dongude bekletme
            if (grillTargetVolume <= 0 && !audio.paused) audio.pause();
            stopGrillFadeLoop();
            return;
        }

        audio.volume = Math.max(0, Math.min(1, audio.volume + (diff > 0 ? step : -step)));
    }, GRILL_FADE_STEP_MS);
}

function handleGrillSound(data) {
    const audio = el('grill-audio');
    if (!audio) return;

    if (typeof data.fadeTime === 'number') grillFadeMs = Math.max(0, data.fadeTime);
    if (typeof data.maxVolume === 'number') grillMaxVolume = Math.max(0.0001, data.maxVolume);

    if (data.src && data.src !== grillAudioSrc) {
        grillAudioSrc = data.src;
        audio.src = data.src;
    }

    const volume = typeof data.volume === 'number' ? data.volume : 0;

    if (data.play && volume > 0 && grillAudioSrc) {
        grillTargetVolume = Math.max(0, Math.min(1, volume));

        if (audio.paused) {
            // Her zaman sessizlikten baslat ki giris de fade'li olsun
            audio.volume = 0;
            const playPromise = audio.play();
            // Autoplay engellenirse veya kaynak yuklenemezse sessizce gec
            if (playPromise && playPromise.catch) playPromise.catch(function () {});
        }
    } else {
        // Uzaklasma: anlik kesme yok, ayni surede 0'a in ve sonra durdur
        grillTargetVolume = 0;
    }

    if (grillFadeMs <= 0) {
        audio.volume = grillTargetVolume;
        if (grillTargetVolume <= 0 && !audio.paused) audio.pause();
        return;
    }

    startGrillFadeLoop();
}

// ====================================================
// YELPAZELEME MINIGAME (A/D bar doldurma)
// ====================================================
let fanResultTimer = null;

function handleFanMinigameMessage(data) {
    const overlay = el('fan-minigame-overlay');
    if (!overlay) return;

    if (data.action === 'openFanMinigame') {
        if (fanResultTimer !== null) {
            clearTimeout(fanResultTimer);
            fanResultTimer = null;
        }
        el('fan-bar-fill').style.width = '0%';
        el('fan-bar-fill').classList.remove('success', 'fail');
        el('fan-result').textContent = '';
        el('fan-result').className = 'fan-result';
        el('fan-key-a').classList.remove('pressed');
        el('fan-key-d').classList.remove('pressed');
        overlay.classList.add('active');
    } else if (data.action === 'updateFanMinigame') {
        const percent = Math.max(0, Math.min(100, data.percent || 0));
        el('fan-bar-fill').style.width = percent + '%';

        if (data.lastKey === 'a' || data.lastKey === 'd') {
            const pressedEl = el('fan-key-' + data.lastKey);
            pressedEl.classList.add('pressed');
            setTimeout(function () { pressedEl.classList.remove('pressed'); }, 120);
        }
    } else if (data.action === 'closeFanMinigame') {
        const fill = el('fan-bar-fill');
        const result = el('fan-result');
        if (data.success) {
            fill.classList.add('success');
            result.textContent = 'BAŞARILI';
            result.className = 'fan-result success';
        } else {
            fill.classList.add('fail');
            result.textContent = 'BAŞARISIZ';
            result.className = 'fan-result fail';
        }

        fanResultTimer = setTimeout(function () {
            overlay.classList.remove('active');
            fanResultTimer = null;
        }, 700);
    }
}

window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'grillSound') {
        handleGrillSound(data);
    } else if (data.action.indexOf('HeatHud') !== -1) {
        handleHudMessage(data);
    } else if (data.action.indexOf('FanMinigame') !== -1) {
        handleFanMinigameMessage(data);
    } else {
        handleMenuMessage(data);
    }
});

// Chrome / Browser Local File Preview Test
if (IS_PREVIEW) {
    document.addEventListener('DOMContentLoaded', function () {
        handleHudMessage({
            action: 'updateHeatHud',
            heat: 85,
            speedText: '1.75x Hızlı'
        });

        handleMenuMessage({
            action: 'openSlotMenu',
            title: 'IZGARA SLOTLARI',
            netId: 1,
            burnThreshold: 180,
            slots: [
                { index: 1, occupied: true,  label: 'Dana Biftek',  progress: 45,  status: 'RAW' },
                { index: 2, occupied: true,  label: 'Sucuk Izgara', progress: 100, status: 'COOKED' },
                { index: 3, occupied: true,  label: 'Tavuk Kanat',  progress: 145, status: 'COOKED' },
                { index: 4, occupied: true,  label: 'Izgara Balik', progress: 180, status: 'BURNT' },
                { index: 5, occupied: false },
                { index: 6, occupied: false }
            ]
        });
    });
}
