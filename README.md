# gnsh-bbq

<div align="center">

### FiveM için sunucu doğrulamalı, slot tabanlı mangal ve pişirme sistemi

QBCore ve seçilebilir envanter/target/minigame adaptörleriyle çalışan, NUI destekli
mangal etkileşimi.

**Sürüm:** `1.3.0` · **Varsayılan framework:** `qbcore` · **Varsayılan envanter:** `ox_inventory`

[Kurulum](#kurulum) · [Yapılandırma](#yapılandırma) · [Tarifler](#tarifler) · [Operasyon](#operasyon-ve-sürüm)

</div>

---

## Genel bakış

`gnsh-bbq`, oyuncunun mangal kurmasından ürünü envanterine almasına kadar olan akışı
yönetir:

1. Mangal kurulur ve sunucu tarafından kayıt altına alınır.
2. Kömür eklenir ve mangal yakılır.
3. Çiğ malzemeler ızgaradaki slotlara yerleştirilir.
4. Isı seviyesine göre pişirme ilerler; düşük/yüksek ısı pişirme hızını değiştirir.
5. Oyuncu ısıyı yelpazeleme minigame’iyle yönetir.
6. Çıktı, pişme durumuna göre çiğ, az pişmiş veya pişmiş ürün olarak alınır.

Grill durumu, ısı, slotlar, kullanım kilitleri ve geçici aksiyonlar çalışma sırasında
sunucu belleğinde tutulur. Kaynak yeniden başlatıldığında bu geçici durumlar kalıcı
olarak saklanmaz; kaynak kapanırken aktif mangal entity’leri temizlenir. Projede SQL
veya veritabanı migration dosyası yoktur.

## Özellikler

- Mangal kurma ve toplama komutları ile `mangal` usable item akışı.
- Kömür ekleme, tutuşturma, ısı düşüşü ve ısı sınırları.
- `Config.MaxSlots` ile yapılandırılabilen slot sistemi; mevcut varsayılan kapasite 10.
- Tarif bazlı pişirme; çiğ, az pişmiş, pişmiş ve yanmış slot durumları.
- Opsiyonel baharat modifier’ı: açlık bonusu ve zehirlenme riskinde azalma.
- Standalone A/D yelpazeleme minigame’i; alternatif olarak `qb-skillbar` veya `ox_lib`.
- NUI slot/tarif menüsü ve mangal ısı HUD’ı.
- `qb-target`, `ox_target` veya 3D yazı fallback’i.
- NUI ses motoru veya isteğe bağlı `xsound` entegrasyonu.
- Sunucu tarafı entity, model, mesafe, envanter, durum, cooldown ve kullanım kilidi
  doğrulamaları.
- Oyuncu kopması, kilit süresinin dolması ve resource stop durumları için geçici durum
  temizliği.

## Desteklenen entegrasyonlar

Config değerleri kaynakta mevcut adaptör yollarını belirler. Seçilen değer için ilgili
resource’un sunucuda çalışıyor olması gerekir.

| Alan | Desteklenen değerler | Depodaki varsayılan |
|---|---|---|
| Framework | `qbcore`, `standalone` | `qbcore` |
| Envanter | `qbcore`, `ox_inventory` | `ox_inventory` |
| Target | `qb-target`, `ox_target`, `none` | `qb-target` |
| Bildirim | `qbcore`, `ox_lib`, `gta`, `none` | `qbcore` |
| Yelpazeleme | `standalone`, `qb-skillbar`, `ox_lib` | `standalone` |
| Ses | `nui`, `xsound` | `nui` |
| Menü | NUI veya `qb-menu`/`ox_lib` fallback’i | NUI |

`standalone` seçimi temel kaynak akışını framework çağrılarından ayırır; ancak envanter
ve kullanılabilir item davranışı seçilen inventory adapter’ına bağlıdır. Üretim sunucusunda
seçtiğiniz kombinasyonu staging ortamında doğrulayın.

## Gereksinimler

### Kaynak bağımlılıkları

| Resource | Ne zaman gerekir? |
|---|---|
| `qb-core` | `Config.Framework = 'qbcore'` olduğunda; mevcut varsayılanda gereklidir. |
| `ox_inventory` | `Config.Inventory = 'ox_inventory'` olduğunda; mevcut varsayılanda gereklidir. |
| `qb-target` | `Config.TargetSystem = 'qb-target'` olduğunda. |
| `ox_target` | `Config.TargetSystem = 'ox_target'` olduğunda. |
| `ox_lib` | `NotifyStyle`, `MinigameSystem` veya fallback menü için seçildiğinde. |
| `qb-skillbar` | `Config.MinigameSystem = 'qb-skillbar'` olduğunda. |
| `qb-menu` | `Config.UseNuiMenus = false` ve QB menüsü fallback’i kullanılacaksa. |
| `xsound` | `Config.SoundEngine = 'xsound'` olduğunda. |

Kaynakta SQL dosyası bulunmadığı için ayrıca SQL import adımı yoktur. NUI HTML, CSS,
JavaScript ve `sizzling.ogg` dosyası kaynakla birlikte gelir; harici web arayüzü kurulumu
gerekmez.

### Envanter item’leri

Varsayılan akış için envanterinizde aşağıdaki item adları karşılıklandırılmalıdır:

| Amaç | Item’ler |
|---|---|
| Mangal kurma/toplama | `mangal` |
| Kömür | `komur`, `coal`, `briket_komur` |
| Tutuşturma | `cakmak`, `lighter` |
| Sucuk | `raw_sausage`, `undercooked_sausage`, `cooked_sausage` |
| Tavuk | `raw_chicken`, `undercooked_chicken`, `cooked_chicken` |
| Dana | `raw_meat`, `undercooked_meat`, `cooked_meat` |
| Balık | `raw_fish`, `undercooked_fish`, `cooked_fish` |
| Köfte | `raw_meatball`, `undercooked_meatball`, `cooked_meatball` |
| Mısır | `sweet_corn`, `undercooked_corn`, `grilled_corn` |
| Opsiyonel baharat | `baharat` |

`Config.Inventory = 'qbcore'` ve `Config.Framework = 'qbcore'` kullanıldığında kaynak,
`Config.QBItemDefinitions` içindeki eksik QBCore item’lerini başlangıçta kaydetmeyi dener.
`ox_inventory` item’leri ise inventory’nin kendi statik item tanımlarında bulunmalıdır.
Item adları `Config.Recipes`, `Config.CoalItems`, `Config.IgnitionItems` ve
`Config.Seasonings` ile birebir eşleşmelidir.

## Kurulum

1. Kaynağı `resources/[standalone]/gnsh-bbq` klasörüne yerleştirin. Klasör adını
   değiştirirseniz `server.cfg` içindeki `ensure` satırını da aynı resource adıyla
   güncelleyin.
2. Seçtiğiniz framework, inventory, target ve diğer adapter resource’larını kurup
   başlatın.
3. Yukarıdaki item’leri inventory sisteminizde tanımlayın. Özellikle `mangal`, seçilen
   kömür/tutuşturucu item’leri ve aktif tariflerin tüm çıktı item’leri mevcut olmalıdır.
4. `config.lua` içindeki entegrasyon ve oyun ayarlarını sunucunuza göre düzenleyin.
5. Bağımlılıkları önce, `gnsh-bbq` kaynağını sonra başlatın. Mevcut varsayılanlar için
   örnek sıra:

   ```cfg
   ensure qb-core
   ensure ox_inventory
   ensure qb-target
   ensure gnsh-bbq
   ```

   Sunucunuzun mevcut dependency sırasını koruyun; bu örnek kaynak manifestinde
   otomatik dependency tanımı olmadığı için açık bir başlangıç sırası gösterir.
6. Kaynak başlatıldıktan sonra staging ortamında temel akışları doğrulayın ve üretim dağıtımından önce kendi sunucu release sürecinizi tamamlayın.

## Yapılandırma

Ana ayar dosyası [`config.lua`](config.lua)’dır. Aşağıdaki değerler depodaki mevcut
varsayılanları gösterir.

### Framework, inventory ve etkileşim

| Ayar | Varsayılan | Açıklama |
|---|---:|---|
| `Config.Framework` | `qbcore` | `qbcore` veya `standalone`. |
| `Config.Inventory` | `ox_inventory` | `qbcore` veya `ox_inventory`; framework’ten bağımsız seçilir. |
| `Config.TargetSystem` | `qb-target` | `qb-target`, `ox_target` veya `none`. |
| `Config.Enable3DText` | `false` | Target kullanılmadığında fallback 3D metin akışını açar. |
| `Config.InteractDistance` | `2.5` | Genel client etkileşim mesafesi. |
| `Config.GrillInteractDistance` | `4.0` | Sunucunun kesin entity mesafesi doğrulaması. |
| `Config.OnlyOwnerCanRemove` | `false` | `true` yapılırsa yalnızca kuran oyuncu toplar. |
| `Config.UseNuiMenus` | `true` | Slot ve tarif menülerinde NUI kullanır. |
| `Config.UseNuiHeatHud` | `true` | Isı HUD’ını açar. |
| `Config.NuiHudDistance` | `1.3` | Isı HUD’ının görünürlük mesafesi. |
| `Config.NuiMenuDistance` | `4.0` | Açık NUI menüsünün mangaldan uzaklaşınca kapanacağı mesafe. HUD’dan bağımsızdır. |

`NuiMenuDistance` ile `NuiHudDistance` özellikle ayrı tutulur. Eğimi veya yükselti
farkı olan yerlerde açık menünün erken kapanmasını istemiyorsanız menü mesafesini
HUD mesafesinden bağımsız artırın.

### Komutlar ve süreler

| Ayar | Varsayılan | Açıklama |
|---|---:|---|
| `Config.BuildCommand` | `mangalkur` | `/mangalkur` ile kurulum isteği gönderir. |
| `Config.RemoveCommand` | `mangaltopla` | `/mangaltopla` ile yakındaki mangalı toplama isteği gönderir. |
| `Config.AddCoalTime` | `3000` ms | Kömür ekleme animasyonu/aksiyonu. |
| `Config.LightGrillTime` | `5000` ms | Mangal yakma animasyonu/aksiyonu. |
| `Config.PlacementRequestTimeout` | `15000` ms | Kurulum handshake isteğinin geçerlilik süresi. |
| `Config.GrillUseLeaseMs` | `10000` ms | Tek oyunculu kullanım kilidinin süresi. |
| `Config.GrillUseHeartbeatMs` | `3000` ms | Client kullanım kilidini yenileme aralığı. |

### Isı ve pişirme

| Ayar | Varsayılan | Açıklama |
|---|---:|---|
| `Config.DefaultHeat` | `50` | Mangal yakıldığında başlangıç ısısı. |
| `Config.MinHeat` / `Config.MaxHeat` | `0` / `100` | Isı sınırları. |
| `Config.HeatDecayInterval` | `10` sn | Isı düşüş periyodu. |
| `Config.HeatDecayAmount` | `5` | Her periyotta düşen ısı. |
| `Config.LowHeatThreshold` | `40` | Altında `LowHeatMultiplier` kullanılır. |
| `Config.HighHeatThreshold` | `80` | Üstünde `HighHeatMultiplier` kullanılır. |
| `Config.LowHeatMultiplier` | `0.5` | Düşük ısı pişirme çarpanı. |
| `Config.NormalHeatMultiplier` | `1.0` | Normal ısı pişirme çarpanı. |
| `Config.HighHeatMultiplier` | `1.75` | Yüksek ısı pişirme çarpanı. |
| `Config.BurnThreshold` | `180` | Pişirme ilerlemesi bu değere ulaştığında slot yanmış sayılır. |
| `Config.CookingTickMs` | `1000` ms | Sunucu pişirme döngüsünün tick aralığı. |

Yelpazeleme için `Config.FanHeatGain = 20`, `Config.FanHeatLossOnFail = 5` ve
`Config.FanCooldown = 5000` ms kullanılır. Başarılı yelpazeleme ısıyı artırır,
başarısız sonuç azaltır.

### Pişirme sonucu davranışı

`cookTime`, normal `1.0x` ısı çarpanında yüzde 100 pişmeye ulaşmak için kullanılan
temel süredir ve saniye cinsindendir. Gerçek süre, mangalın ısı seviyesi değiştiği için
yaklaşık olarak değişebilir.

- `cookProgress = 0`: çiğ item verilir.
- `0 < cookProgress < 100`: `undercookedItem` verilir.
- `cookProgress >= 100`: `cookedItem` verilir.
- `cookProgress >= BurnThreshold`: slot `BURNT` olur ve toplama sırasında yanmış içerik
  envantere verilmez; yanmış içerik atılır.

Az pişmiş ve çiğ ürünler kullanıldığında `Config.UndercookedPoisonChance` ve
`Config.RawPoisonChance` değerleri uygulanır. Baharat, `safeCookBonus` kadar risk azaltır
ve `hungerBonus` kadar açlık değerine ekler. Bu zehirlenme akışı varsayılan olarak QBCore
metadata hunger değerini günceller.

## Kullanım

1. Oyuncu üzerinde `mangal` item’i varken `/mangalkur` komutunu kullanır veya inventory
   usable item akışını çalıştırır.
2. Mangal üzerine kömür ekleyin. `Config.CoalItems` listesindeki ilk mevcut item kullanılır.
3. `Config.IgnitionItems` listesindeki bir item ile mangalı yakın.
4. Mangal yanarken target menüsünden et ekleyin veya `Config.UseNuiMenus` aktifse NUI
   slot/tarif menüsünü kullanın.
5. İsterseniz `baharat` gibi `Config.Seasonings` içinde tanımlı bir item’i ete ekleyin.
6. Isıyı takip edin; standalone minigame’de A/D tuşlarına sırayla basarak barı doldurun.
   Minigame sırasında hareket kontrolleri devre dışıdır ve asset yükleme aralığında ped
   sabit tutulur.
7. Pişen ürünü slot menüsünden alın. Mangal toplandığında yanmamış slot içerikleri ve
   mangal item’i envantere iade edilir; yanmış slotlar iade edilmez.

Target sistemi `none` ise `Config.Enable3DText = true` yaparak fallback etkileşimini
açabilirsiniz. `Config.UseNuiMenus = false` durumunda kaynak, mevcut resource durumuna
göre `qb-menu` veya `ox_lib` menülerine geçer.

## Yelpazeleme minigame’i

Varsayılan `standalone` minigame ayarları:

| Ayar | Varsayılan | Açıklama |
|---|---:|---|
| `Config.FanBarTimeLimit` | `6000` ms | Barı tamamlamak için toplam süre. |
| `Config.FanBarFillPerPress` | `9` | Doğru sıradaki basış başına ilerleme yüzdesi. |
| `Config.FanBarDecayPerSecond` | `7` | Basış yapılmadığında saniyelik azalma. |

İlk basış A veya D olabilir; sonraki basışlar sırayla değişmelidir. Alternatif minigame
seçenekleri `qb-skillbar` ve `ox_lib` olup ilgili resource’un çalışıyor olması gerekir.

## Tarifler

Tarifler `Config.Recipes` içinde tutulur. Mevcut tarifler:

| ID | Tarif | `cookTime` | Çiğ item | Az pişmiş item | Pişmiş item | Açlık |
|---|---|---:|---|---|---|---:|
| `sucuk` | Izgara Sucuk | 6 sn | `raw_sausage` | `undercooked_sausage` | `cooked_sausage` | 25 |
| `tavuk` | Tavuk Kanat | 8 sn | `raw_chicken` | `undercooked_chicken` | `cooked_chicken` | 35 |
| `et` | Dana Biftek | 12 sn | `raw_meat` | `undercooked_meat` | `cooked_meat` | 50 |
| `balik` | Izgara Balık | 10 sn | `raw_fish` | `undercooked_fish` | `cooked_fish` | 40 |
| `kofte` | Mangal Köfte | 10 sn | `raw_meatball` | `undercooked_meatball` | `cooked_meatball` | 45 |
| `misir` | Közde Mısır | 9 sn | `sweet_corn` | `undercooked_corn` | `grilled_corn` | 30 |

### Yeni tarif ekleme

Yeni bir item eklemek için tarif kaydı ile inventory tanımlarının birlikte hazırlanması
gerekir. Örnek:

```lua
{
    id = 'karides',
    label = 'Izgara Karides',
    cookTime = 7,
    rawItem = 'raw_shrimp',
    undercookedItem = 'undercooked_shrimp',
    cookedItem = 'cooked_shrimp',
    burntItem = 'burnt_meat',
    hungerAmount = 35,
    foodProp = `prop_cs_steak`
}
```

Ardından `raw_shrimp`, `undercooked_shrimp` ve `cooked_shrimp` item’lerini inventory
sisteminizde tanımlayın. QBCore inventory branch’i eksik tarif item’leri için varsayılan
tanım üretmeyi dener; `ox_inventory` için tanımlar `ox_inventory` item dosyasında
oluşturulmalıdır.

## Mimari ve entegrasyon sınırları

İstek akışı kısaca şöyledir:

```text
Target / NUI / command
        ↓
Client request
        ↓
Server validation: entity + model + distance + state + item + lock/cooldown
        ↓
In-memory grill state update
        ↓
Client state synchronization and visual feedback
```

| Dosya | Sorumluluk |
|---|---|
| `fxmanifest.lua` | FiveM manifest, version, NUI dosyaları ve script yükleme sırası. |
| `config.lua` | Framework, inventory, tarif, ısı, item, NUI ve efekt ayarları. |
| `client.lua` | Entity yerleştirme, target/NUI akışı, animasyon, efekt ve client state. |
| `server.lua` | Grill state, slotlar, pişirme döngüsü, item işlemleri, kilitler ve doğrulamalar. |
| `bridge.lua` | Server framework ve inventory soyutlaması. |
| `bridge_client.lua` | Client bildirim, progressbar ve minigame soyutlaması. |
| `html/` | Slot menüsü, ısı HUD’ı, fan minigame arayüzü ve ses dosyası. |

Kaynakta public resource export tanımı bulunmuyor. `Bridge.*`, `ClientBridge.*` ve
`mangal:*` network event’leri iç implementasyon yüzeyidir; başka script’lerin doğrudan
entegrasyon API’si olarak kullanılmamalıdır. Entegrasyon için config, usable item,
komutlar ve target akışı kullanılmalıdır.

## Sunucu doğrulama ve güvenlik sınırları

Kaynak, kritik işlem öncesinde sunucu tarafında aşağıdaki kontrolleri yapar:

- net ID’nin kayıtlı ve geçerli bir entity’ye ait olması,
- entity tipinin obje olması ve izin verilen mangal modellerinden birini kullanması,
- oyuncunun mangala `Config.GrillInteractDistance` içinde olması,
- mangal state’inin istenen işlemle uyumlu olması,
- çiğ malzeme, kömür, tutuşturucu ve opsiyonel baharat item’lerinin mevcut olması,
- işlem süresi, event cooldown’ı, slot busy durumu ve tek oyunculu kullanım lease’i,
- `Config.OnlyOwnerCanRemove` aktifse kuran oyuncu kimliği.

Bu kontroller güvenlik garantisi veya exploit’lere karşı mutlak koruma iddiası değildir.
Kaynakta özel bir `SECURITY.md` veya ayrı bir vulnerability reporting kanalı bulunmadığı
için üretim sunucusunun kendi raporlama sürecini ayrıca tanımlaması gerekir.

## Performans ve kalıcılık

Pişirme ve ısı döngüleri yalnızca aktif çalışma durumundaki mangallar için çalışır;
client tarafında target/NUI/HUD kontrolleri mesafe ve ayarlarla sınırlandırılır. Depoda
benchmark sonucu bulunmadığından sayısal performans iddiası yapılmamaktadır.

Grill state’i veritabanına yazılmaz. Resource restart, server restart veya kaynak stop
sonrasında önceki slot/ısı ilerlemesinin geri yüklenmesi beklenmemelidir.

## Proje yapısı

```text
gnsh-bbq/
├── fxmanifest.lua
├── config.lua
├── client.lua
├── server.lua
├── bridge_client.lua
├── bridge.lua
├── html/
│   ├── index.html
│   ├── script.js
│   ├── style.css
│   └── sizzling.ogg
├── .github/workflows/validate.yml
├── CHANGELOG.md
└── CONTRIBUTING.md
```

## Yerelleştirme

Oyuncuya gösterilen metinler `Config.Lang` içinde Türkçe olarak tutulur. Farklı bir dil
eklemek için bu tabloyu düzenleyebilir veya aynı anahtarları koruyan bir çeviri tablosu
oluşturabilirsiniz. Kaynakta ayrı bir locale loader bulunmuyor.

## Sorun giderme

| Belirti | Kontrol |
|---|---|
| Mangal kurulmamış veya hemen reddedilmiş | `mangal` item’ini, oyuncu mesafesini, model tanımını ve dependency sırasını kontrol edin. |
| Target seçenekleri görünmüyor | `Config.TargetSystem`, ilgili target resource’un state’i ve `Config.InteractDistance` değerini kontrol edin. Fallback için `Config.Enable3DText = true` kullanın. |
| NUI menüsü erken kapanıyor | `Config.NuiMenuDistance` menü için, `Config.NuiHudDistance` yalnızca HUD için kullanılır. |
| Tarif menüsünde ürün yok | Çiğ item’in envanterde bulunduğunu, `Config.Recipes` kaydını ve item adlarının birebir eşleştiğini kontrol edin. |
| Pişmiş item alınamıyor | Mangalın `LIT` state’inde olduğunu ve ilgili cooked/undercooked item’lerinin inventory’de tanımlı olduğunu kontrol edin. |
| Ses duyulmuyor | `Config.EnableSound`, `Config.SoundEngine`, `Config.SoundFile` ve `html/sizzling.ogg` dosyasını kontrol edin. `xsound` seçildiyse resource çalışıyor olmalıdır. |
| Bildirim görünmüyor | `Config.EnableNotifications`, `Config.NotifyStyle` ve seçilen bildirim resource’unu kontrol edin. |
| QBCore bağlantısı hazır değil | `qb-core` başlamadan kaynağı başlatmayın. QBCore restart sonrası bağlantı kurulamazsa kaynağı yeniden başlatın. |
| Restart sonrası eski mangal/slot bekleniyor | Kaynak kalıcılık sağlamaz; restart sonrası geçici entity ve state’in geri yüklenmesi desteklenmiyor. |

## Operasyon ve sürüm

- Mevcut resource sürümü `fxmanifest.lua` içinde `1.3.0` olarak tanımlıdır.
- Değişiklik geçmişi [`CHANGELOG.md`](CHANGELOG.md) içinde tutulur.
- Geliştirme ve release akışı [`CONTRIBUTING.md`](CONTRIBUTING.md) içindedir.
- Staging ve üretim öncesi doğrulama, sunucu yöneticisinin kendi dağıtım süreci içinde yapılmalıdır.
- CI workflow’ı Lua syntax, manifest varlığı ve yüksek güvenli credential pattern’leri
  için kontrol yapar: [`.github/workflows/validate.yml`](.github/workflows/validate.yml).
- `main` production, `dev` entegrasyon branch’i olarak dokümante edilmiştir. Üretim
  sunucusuna development branch’i doğrudan dağıtmayın.

README’de roadmap bölümü eklenmedi; repository’de doğrulanmış bir gelecek özellik listesi
bulunmuyor.
