Config = {}

-- Altyapi Secimi ('qbcore' veya 'standalone')
Config.Framework = 'qbcore'

-- Envanter Sistemi ('qbcore' veya 'ox_inventory')
-- Framework'ten bagimsizdir: ornegin Framework='qbcore' + Inventory='ox_inventory'
-- (qb-core + ox_inventory) veya Framework='standalone' + Inventory='ox_inventory'
-- gibi kombinasyonlar desteklenir.
Config.Inventory = 'ox_inventory'

-- Bildirim Ayarlari (normal bildirimler bilerek kapali; durum NUI/menulerden takip edilir)
Config.EnableNotifications = false
Config.NotifyStyle = 'qbcore' -- Options: 'qbcore', 'ox_lib', 'gta', 'none'

-- Target Sistemi ('qb-target', 'ox_target' veya 'none')
Config.TargetSystem = 'ox_target'

-- 3D Yazi Metinlerini Gosterme (Target menusu kullandiginiz icin varsayilan: false)
Config.Enable3DText = false

-- Test ve Gozlem Icin Mangal Ustu 3D Yazi Gostergesi (Kapali)
Config.ShowHeatIndicator = false

-- Ozel Cam Efektli NUI Arayuz Gostergesi (UI HUD)
Config.UseNuiHeatHud = true

-- NUI Termometrenin ekranda belirdigi mesafe (metre) (1.3 altında çalışmıyor)
Config.NuiHudDistance = 1.3

-- NUI menusu acikken kullanilacak mesafe. HUD mesafesinden bagimsiz tutulur;
-- yokusta mangal ile oyuncu arasindaki yukseklik farki menuyu kapatmamali.
Config.NuiMenuDistance = 4.0

-- Mangal kullanim kilidi (tek oyuncu)
Config.GrillUseLeaseMs = 10000
Config.GrillUseHeartbeatMs = 3000

-- Slot ve Et Secimi menuleri icin ozel NUI arayuzu.
-- false yapilirsa eski qb-menu / ox_lib menuleri kullanilir.
Config.UseNuiMenus = true

-- Mangal Obje Modeli
Config.GrillModel = `prop_bbq_5`

-- Elde Tutulacak Prop Modeli
Config.HandPropModel = `prop_fish_slice_01`

-- Etkilesim Mesafesi
Config.InteractDistance = 2.5
Config.GrillInteractDistance = 4.0 -- Sunucu tarafli kesin mesafe kontrolu
Config.OnlyOwnerCanRemove = false
Config.PlacementRequestTimeout = 15000

-- Komutlar
Config.BuildCommand = 'mangalkur'
Config.RemoveCommand = 'mangaltopla'

-- Yakit ve Tutusturma Item Yapisi
Config.CoalItems = {'komur', 'coal', 'briket_komur'}
Config.IgnitionItems = {'cakmak', 'lighter'}

-- Komur Turleri: her item icin yanma hizi carpani (dusuk = yavas soner)
-- ve yakildiginda baslangic isisina eklenen bonus. Listede olmayan bir
-- komur itemi eklenirse varsayilan carpan 1.0 / bonus 0 kullanilir.
Config.CoalTypes = {
    komur        = { label = 'Normal Kömür', decayMultiplier = 1.0, igniteBonus = 0 },
    coal         = { label = 'Normal Kömür', decayMultiplier = 1.0, igniteBonus = 0 },
    briket_komur = { label = 'Briket Kömür', decayMultiplier = 0.6, igniteBonus = 15 }
}

-- Baharat / Marine Sistemi: ete opsiyonel eklenen tatlandirici.
-- hungerAmount uzerine bonus, ve yenirken gereken guvenli pisme yuzdesini
-- (safeCookBonus kadar) dusurur (marine et biraz daha az riskli sayilir).
Config.Seasonings = {
    baharat = { label = 'Baharat', hungerBonus = 5, safeCookBonus = 5 }
}

-- Slot Sistemi ve Izgara Kapasitesi Ayarlari
Config.MaxSlots = 10

-- Her slot icin mangal objesine gore bagil konum ve rotasyon (Relative Offset & Rotation)
-- pos: vector3(X [sol/sag], Y [ileri/geri], Z [yukseklik])
-- rot: vector3(RotX, RotY, RotZ) [Aci ayari]
Config.SlotOffsets = {
    [1] = { pos = vector3(-0.45, 0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [2] = { pos = vector3(-0.225, 0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [3] = { pos = vector3( 0.0, 0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [4] = { pos = vector3(0.225, 0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [5] = { pos = vector3( 0.43, 0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [6] = { pos = vector3( -0.45,-0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [7] = { pos = vector3( -0.225, -0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [8] = { pos = vector3( 0.0, -0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [9] = { pos = vector3( 0.225, -0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) },
    [10] = { pos = vector3( 0.43, -0.15, 0.93), rot = vector3(0.0, 0.0, 0.0) }
}

-- Pisme ve Yanma Ayarlari (%100 pisme, %180 ve uzeri yanik slot)
Config.BurnThreshold = 180

-- Yanma uyarisi: cookProgress bu yuzdeyi gecince slot menusunde
-- kirmizi titresim + kisa bip. BurnThreshold'dan kucuk olmali.
Config.BurnWarning = {
    Enabled = true,
    StartPercent = 150,
    Sound = true
}

Config.CookingTickMs = 1000

-- Az pismis etler envanterde tam stacklensin diye pickup aninda hicbir
-- pisme-yuzdesi metadatasi tutulmuyor -- ayni tarif+baharat kombinasyonu
-- her zaman ayni (bos) metadataya sahip, dolayisiyla tek stack'te birikir.
-- Bunun yerine az pismis et yenince sabit bir zehirlenme ihtimali (yuzde)
-- calisir -- deterministik esik yerine risk tabanli sistem.
Config.UndercookedPoisonChance = 50 -- az pismis et yenirse zehirlenme ihtimali (%)
Config.RawPoisonChance = 95 -- dogrudan cig et yenirse zehirlenme ihtimali (%)

Config.PoisonSettings = {
    HealthLoss = 15,
    Duration = 20,
    ApplyScreenEffect = true,
    TickInterval = 5,
    OnsetDelay = 5, -- yemek yendikten sonra mide bulantısının başlama gecikmesi (saniye)
    NauseaDuration = 4 -- mide bulantısı ile kusma animasyonu arasındaki süre (saniye)
}

-- HUD metinleri ve sunucu pisme hizi ayni esikleri kullanir.
Config.LowHeatThreshold = 40
Config.HighHeatThreshold = 80
Config.LowHeatMultiplier = 0.5
Config.NormalHeatMultiplier = 1.0
Config.HighHeatMultiplier = 1.75

-- Islem Sureleri (Milisaniye)
Config.AddCoalTime = 3000
Config.LightGrillTime = 5000

-- Isı Yönetimi & Yelpazeleme (Heat & Fanning System)
Config.MinigameSystem = 'standalone' -- Options: 'standalone', 'qb-skillbar', 'ox_lib'
Config.DefaultHeat = 50
Config.MinHeat = 0
Config.MaxHeat = 100
Config.HeatDecayInterval = 10 -- Her 10 saniyede bir ısı düşer
Config.HeatDecayAmount = 5    -- Her periyotta ısı %5 düşer
Config.FanHeatGain = 20       -- Başarılı yelpazelemede +%20 ısı
Config.FanHeatLossOnFail = 5  -- Başarısız yelpazelemede -%5 ısı
Config.FanCooldown = 5000     -- Yelpazeleme cooldown süresi (ms)
Config.FanMinimumDuration = 1000 -- Finish event'i icin minimum sunucu bekleme suresi
Config.FanPropModel = `prop_anim_newspaper`

-- 'standalone' minigame: A/D tuşlarına sırayla basarak barı doldurma
Config.FanBarTimeLimit = 6000     -- Bar doldurma icin toplam sure (ms)
Config.FanBarFillPerPress = 9     -- Dogru sirali her basista bar dolum yuzdesi
Config.FanBarDecayPerSecond = 7   -- Basilmadigi surece barin saniyede dusme yuzdesi

-- Partikul Efektleri (Ates & Duman)
Config.FireParticleDict = 'core'
Config.FireParticleName = 'fire_petrol_flex'
Config.SmokeParticleDict = 'core'
Config.SmokeParticleName = 'ent_amb_smoke_foundry'
Config.GrillSmokeScaleMultiplier = 0.45
Config.GrillSmokeAlpha = 0.50

-- Pismis / yanmis et duman efektleri
Config.EnableMeatSmoke = true
Config.MeatSmokeDistance = 25.0
Config.CookedMeatSmoke = {
    dict = Config.SmokeParticleDict,
    name = Config.SmokeParticleName,
    offset = vector3(0.0, 0.0, 0.06),
    rotation = vector3(0.0, 0.0, 0.0),
    scale = 0.10,
    alpha = 0.45,
    color = { r = 0.85, g = 0.85, b = 0.85 }
}
Config.BurntMeatSmoke = {
    dict = Config.SmokeParticleDict,
    name = Config.SmokeParticleName,
    offset = vector3(0.0, 0.0, 0.08),
    rotation = vector3(0.0, 0.0, 0.0),
    scale = 0.18,
    alpha = 0.75,
    color = { r = 0.25, g = 0.25, b = 0.25 }
}

-- Mangal Cizirti Sesi
Config.EnableSound = true

-- Ses Motoru:
--   'nui'    -> Scriptin kendi NUI sayfasi calar. Harici kaynak GEREKMEZ. (Onerilen)
--   'xsound' -> xsound kaynagini kullanir; sunucuda xsound kurulu olmalidir.
Config.SoundEngine = 'nui'

Config.SoundDistance = 12.0 -- Sesin duyulmaya basladigi/kesildigi mesafe (metre)
Config.SoundVolume = 0.025   -- Maksimum ses seviyesi (0.0 - 1.0)

-- Bu mesafeden yakinda ses tam seviyede calar; buradan SoundDistance'a
-- kadar dogrusal olarak kisilir. Yaklasirken ve uzaklasirken ayni egri.
Config.SoundFullVolumeDistance = 2.0

-- Fade suresi (ms). Ses bu surede 0'dan SoundVolume'a cikar,
-- uzaklasinca yine bu surede 0'a iner. 0 = anlik gecis.
Config.SoundFadeTime = 800

-- Ses Dosyasi:
--   Yerel dosya  -> html klasorune atip sadece adini yazin (Orn: 'sizzling.ogg')
--   Internet URL -> direkt MP3/OGG adresi (oyuncunun internetine bagimli olur)
Config.SoundFile = 'sizzling.ogg'



-- Pisirme Tarifleri
-- QBCore calisirken items.lua sonradan degistirildiyse, eksik yeni tarif
-- itemleri mangal_script baslangicinda canli item tablosuna kaydedilir.
Config.QBItemDefinitions = {
    raw_meatball = {
        name = 'raw_meatball',
        label = 'Çiğ Mangal Köftesi',
        weight = 200,
        type = 'item',
        image = 'raw_meatball.png',
        unique = false,
        useable = false,
        shouldClose = true,
        combinable = nil,
        description = 'Mangalda pişirilmeye hazır çiğ köfte'
    },
    cooked_meatball = {
        name = 'cooked_meatball',
        label = 'Mangal Köfte',
        weight = 200,
        type = 'item',
        image = 'cooked_meatball.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Mangalda pişirilmiş köfte'
    },
    sweet_corn = {
        name = 'sweet_corn',
        label = 'Süt Mısır',
        weight = 250,
        type = 'item',
        image = 'sweet_corn.png',
        unique = false,
        useable = false,
        shouldClose = true,
        combinable = nil,
        description = 'Mangalda közlenmeye hazır süt mısır'
    },
    grilled_corn = {
        name = 'grilled_corn',
        label = 'Közde Mısır',
        weight = 250,
        type = 'item',
        image = 'grilled_corn.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Mangalda közlenmiş mısır'
    },
    briket_komur = {
        name = 'briket_komur',
        label = 'Briket Kömür',
        weight = 500,
        type = 'item',
        image = 'briket_komur.png',
        unique = false,
        useable = false,
        shouldClose = true,
        combinable = nil,
        description = 'Normal kömürden daha yavaş tükenir, daha çabuk tutuşur'
    },
    baharat = {
        name = 'baharat',
        label = 'Baharat',
        weight = 50,
        type = 'item',
        image = 'baharat.png',
        unique = false,
        useable = false,
        shouldClose = true,
        combinable = nil,
        description = 'Et mangala konurken eklenir; lezzet ve pişirme güvenliğini artırır'
    }
}

Config.Recipes = {
    {
        id = 'sucuk',
        label = 'Izgara Sucuk',
        cookTime = 6,
        rawItem = 'raw_sausage',
        undercookedItem = 'undercooked_sausage',
        cookedItem = 'cooked_sausage',
        hungerAmount = 25,
        foodProp = `prop_cs_steak`
    },
    {
        id = 'tavuk',
        label = 'Tavuk Kanat',
        cookTime = 8,
        rawItem = 'raw_chicken',
        undercookedItem = 'undercooked_chicken',
        cookedItem = 'cooked_chicken',
        hungerAmount = 35,
        foodProp = `prop_turkey_leg_01`
    },
    {
        id = 'et',
        label = 'Dana Biftek',
        cookTime = 12,
        rawItem = 'raw_meat',
        undercookedItem = 'undercooked_meat',
        cookedItem = 'cooked_meat',
        hungerAmount = 50,
        foodProp = `prop_cs_steak`
    },
    {
        id = 'balik',
        label = 'Izgara Balık',
        cookTime = 10,
        rawItem = 'raw_fish',
        undercookedItem = 'undercooked_fish',
        cookedItem = 'cooked_fish',
        hungerAmount = 40,
        foodProp = `prop_fish_slice_01`
    },
    {
        id = 'kofte',
        label = 'Mangal Köfte',
        cookTime = 10,
        rawItem = 'raw_meatball',
        undercookedItem = 'undercooked_meatball',
        cookedItem = 'cooked_meatball',
        hungerAmount = 45,
        foodProp = `prop_cs_burger_01`
    },
    {
        id = 'misir',
        label = 'Közde Mısır',
        cookTime = 9,
        rawItem = 'sweet_corn',
        undercookedItem = 'undercooked_corn',
        cookedItem = 'grilled_corn',
        hungerAmount = 30,
        foodProp = `prop_cs_hotdog_01`
    }
}

-- Türkçe mesajlar
Config.Lang = {
    ['grill_in_use'] = '~r~Bu mangalı başka bir oyuncu kullanıyor.',
    ['grill_placed'] = '~g~Mangal başarıyla kuruldu!',
    ['grill_removed'] = '~g~Mangal toplandı ve envanterinize eklendi.',
    ['grill_removed_with_meat'] = '~g~Mangal ve üzerindeki %d parça et envanterinize eklendi.',
    ['grill_removed_with_meat_and_burnt'] = '~g~Mangal toplandı; %d parça et iade edildi, %d yanmış et atıldı.',
    ['grill_removed_with_burnt'] = '~g~Mangal toplandı; %d yanmış et atıldı.',
    ['grill_already_exists'] = '~r~Zaten yakınlarda aktif bir mangalınız var!',
    ['no_grill_nearby'] = '~r~Yakınınızda toplanacak bir mangal bulunamadı.',
    ['no_grill_item'] = '~r~Üzerinizde mangal yok!',
    ['invalid_grill'] = '~r~Bu mangal sunucu tarafında geçersiz veya artık mevcut değil.',
    ['not_grill_owner'] = '~r~Bu mangalı yalnızca kuran oyuncu toplayabilir.',
    ['grill_not_empty'] = '~r~Mangal üzerindeki etleri toplamadan mangalı kaldıramazsınız.',
    ['inventory_full'] = '~r~Envanteriniz dolu; eşya eklenemedi.',
    ['action_in_progress'] = '~r~Bu işlem zaten devam ediyor.',
    ['cannot_use_in_vehicle'] = '~r~Araçtayken mangal kuramazsınız!',
    ['framework_unavailable'] = '~r~QB-Core bağlantısı hazır değil. Lütfen yetkiliye bildirin.',
    ['no_raw_item_in_inventory'] = '~r~Üzerinizde pişirilecek çiğ malzeme yok!',
    ['cooking_started'] = '~y~%s pişirilmeye başlandı...',
    ['cooking_finished'] = '~g~Tebrikler! %s hazır, envanterinize eklendi!',
    ['grill_extinguished'] = '~r~Mangalın ısısı sıfıra düştü ve söndü! Yeniden yakmalısınız.',
    ['already_cooking'] = '~r~Bu mangalda zaten yemek pişiriliyor!',
    ['ate_food'] = '~g~%s yediniz. Açlığınız +%d yenilendi!',
    ['food_poisoned'] = 'Et yeterince pismedigi icin mideni bozdu ve zehirlendin!',
    ['food_nausea'] = 'Midesi bulaniyorsun...',
    -- Yakit & Tutusturma Mesajlari
    ['need_coal'] = '~r~Mangalda kömür yok! Önce kömür eklemelisiniz.',
    ['need_ignition'] = '~r~Mangalı yakmak için üzerinizde çakmak olmalı!',
    ['already_has_coal'] = '~r~Bu mangala zaten kömür eklenmiş!',
    ['already_lit'] = '~r~Bu mangal zaten yanıyor!',
    ['adding_coal'] = 'Kömür ekleniyor...',
    ['coal_added'] = '~g~Mangala kömür eklendi! Şimdi yakabilirsiniz.',
    ['lighting_grill'] = 'Mangal yakılıyor...',
    ['grill_lit'] = '~g~Mangal başarıyla yakıldı! Artık et pişirebilirsiniz.',
    ['action_cancelled'] = '~r~İşlem iptal edildi.',
    ['target_add_coal'] = 'Kömür Ekle',
    ['target_start'] = 'Mangala Başla',
    ['target_light_grill'] = 'Mangalı Yak',
    ['target_cook'] = 'Et Pişir / Ekle',
    ['target_slots'] = 'Izgarayı Kontrol Et / Et Topla',
    ['target_fan'] = 'Ateşi Yelpazele',
    ['target_remove'] = 'Mangalı Topla',
    ['heat_fanned'] = '~g~Ateşi harlandırdın! (Isı: %d%%)',
    ['heat_fan_failed'] = '~r~Yelpazeleme başarısız oldu! (Isı: %d%%)',
    ['fan_cooldown'] = '~r~Ateş henüz yeni yelpazelendi, biraz beklemelisin!',
    ['grill_full'] = '~r~Izgara tamamen dolu! En fazla: %d',
    ['no_empty_slot'] = '~r~Izgarada boş yer kalmadı!',
    ['meat_placed'] = '~g~%s ızgaraya koyuldu (Bölme %d)',
    ['meat_picked'] = '~g~Bölme %d üzerinden %s toplandı.',
    ['burnt_meat_discarded'] = '~r~Bölme %d üzerindeki yanmış et atıldı.',
    ['slot_busy'] = '~r~Bu bölmedeki et başka biri tarafından alınıyor!',
    ['prompt_empty'] = '~g~[E]~w~ Kömür Ekle  |  ~r~[G]~w~ Mangalı Topla',
    ['prompt_coal_out_with_meat'] = '~g~[E]~w~ Izgarayı Kontrol Et / Et Topla',
    ['prompt_has_coal'] = '~g~[E]~w~ Mangalı Yak  |  ~r~[G]~w~ Mangalı Topla',
    ['prompt_lit'] = '~g~[E]~w~ Et Ekle  |  ~r~[G]~w~ Mangalı Topla',
    -- Baharat Mesajlari
    ['no_seasoning_in_inventory'] = '~r~Üzerinizde bu baharattan yok!',
    ['seasoning_added'] = '~g~%s ete eklendi.',
    ['burn_warning_row'] = 'DİKKAT, YANIYOR! Hemen topla'
}
