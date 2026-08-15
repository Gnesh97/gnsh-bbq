# mangal_script

Gelişmiş, çok yönlü ve framework esnekliği olan bir FiveM mangal sistemidir. Bu kaynak; mangal kurma, kömür ekleme, mangalı yakma, slot bazlı et yerleştirme, pişirme takibi, yelpazeleme ile ısı yönetimi, yanma riski, duman/ses efektleri ve isteğe bağlı NUI arayüzleri sunar.

Kaynak, hem **QBCore** hem de **standalone** kullanım senaryolarını destekleyecek şekilde tasarlanmıştır. Envanter, target, bildirim ve minigame tarafı da yapılandırma üzerinden değiştirilebilir.

## Özellikler

- Mangal kurma ve toplama komutları
- Kömür ekleme ve mangalı tutuşturma akışı
- Slot tabanlı ızgara sistemi
- 10 adede kadar pişirme slotu
- Pişirme ilerleme takibi ve yanma eşiği
- Pişirme aşamasına göre farklı sonuç ürünleri
- İsteğe bağlı baharat/marine sistemi
- Isı düşüşü, ısı artırma ve yelpazeleme minigame'i
- Mangal dumanı, pişmiş et dumanı ve yanık görünümü
- NUI tabanlı slot menüsü ve ısı HUD'u
- Çakışmayı önleyen mangal kullanım kilidi
- Under-cooked tüketimde zehirlenme etkisi

## Desteklenen Yapılar

- Framework: `qbcore` veya `standalone`
- Envanter: `qbcore` veya `ox_inventory`
- Target: `qb-target`, `ox_target` veya `none`
- Bildirim: `qbcore`, `ox_lib`, `gta` veya `none`
- Minigame: `standalone`, `qb-skillbar` veya `ox_lib`
- Ses motoru: `nui` veya `xsound`

## Gereksinimler

Bu kaynak, seçtiğiniz config'e göre aşağıdaki bağımlılıklarla çalışabilir:

- `qb-core`  
  Eğer `Config.Framework = 'qbcore'` kullanıyorsanız gereklidir.
- `ox_inventory`  
  Eğer `Config.Inventory = 'ox_inventory'` kullanıyorsanız gereklidir.
- `qb-target` veya `ox_target`  
  Eğer target sistemi açık olacaksa gereklidir.
- `ox_lib`  
  `Config.NotifyStyle = 'ox_lib'` veya `Config.MinigameSystem = 'ox_lib'` için gereklidir.
- `qb-skillbar`  
  `Config.MinigameSystem = 'qb-skillbar'` için gereklidir.
- `xsound`  
  `Config.SoundEngine = 'xsound'` seçilirse gereklidir.

Not: `Config.Framework = 'standalone'` kullanıldığında bazı entegrasyonlar devre dışı kalabilir; kaynak yine de temel mantığıyla çalışacak şekilde tasarlanmıştır.

## Kurulum

1. Kaynağı `resources/[standalone]/mangal_script` klasörüne yerleştirin.
2. Gerekli bağımlılıkları kurun ve çalıştırın.
3. `server.cfg` içine kaynağı ekleyin:

```cfg
ensure mangal_script
```

4. Kaynağın, envanter/target/notify gibi bağımlılıklardan sonra başlamasına dikkat edin.

## Yapılandırma

Ana ayarlar `config.lua` dosyasındadır.

### Temel Ayarlar

- `Config.Framework`  
  `qbcore` veya `standalone`
- `Config.Inventory`  
  `qbcore` veya `ox_inventory`
- `Config.TargetSystem`  
  `qb-target`, `ox_target` veya `none`
- `Config.EnableNotifications`  
  Bildirimleri aç/kapat
- `Config.NotifyStyle`  
  Bildirim stilini seçer
- `Config.UseNuiMenus`  
  Slot ve recipe seçim menülerini NUI ile gösterir
- `Config.UseNuiHeatHud`  
  Isı göstergesini NUI HUD olarak gösterir

### Komutlar

- `Config.BuildCommand = 'mangalkur'`
- `Config.RemoveCommand = 'mangaltopla'`

Varsayılan komutlar:

```text
/mangalkur
/mangaltopla
```

### Isı ve Pişirme

- `Config.DefaultHeat`  
  Başlangıç ısısı
- `Config.MinHeat` / `Config.MaxHeat`  
  Isı sınırları
- `Config.HeatDecayInterval` / `Config.HeatDecayAmount`  
  Zamanla ısı düşüşü
- `Config.LowHeatThreshold`, `Config.HighHeatThreshold`  
  Isı çarpanları için eşikler
- `Config.BurnThreshold`  
  Yanma eşiği
- `Config.BurnWarning`  
  Yanma uyarısının davranışı

### Mangal Etkileşimi

- `Config.InteractDistance`  
  Genel etkileşim mesafesi
- `Config.GrillInteractDistance`  
  Sunucu tarafı kesin mesafe kontrolü
- `Config.NuiMenuDistance`
  Açık NUI menüsünün mangaldan uzaklaşınca kapanacağı mesafe. Isı HUD'ının
  `Config.NuiHudDistance` ayarından bağımsızdır.
- `Config.PlacementRequestTimeout`  
  Mangal kurma istek süresi
- `Config.GrillUseLeaseMs` / `Config.GrillUseHeartbeatMs`  
  Mangal kullanım kilidi süreleri

### Ses ve Efektler

- `Config.EnableSound`  
  Cızırtı sesini aç/kapat
- `Config.SoundEngine`  
  `nui` veya `xsound`
- `Config.SoundFile`  
  Yerel ses dosyası veya URL
- `Config.EnableMeatSmoke`  
  Pişmiş et dumanını aç/kapat

## Kullanım

Örnek akış:

1. Oyuncu mangalı kurar.
2. Mangal üzerine kömür ekler.
3. Mangalı yakar.
4. Çiğ malzemeyi slotlara yerleştirir.
5. Isı durumuna göre yemek pişer.
6. Oyuncu pişmiş ürünü slotlardan toplar.
7. Gerekirse mangalı toplar.

Mangal kullanımında tek oyunculu kilit mantığı vardır. Bir oyuncu mangalı kullanırken başka bir oyuncu aynı anda aynı mangal üzerinde işlem yapamaz.

## Pişirme Tarifleri

`Config.Recipes` içinde tanımlı tarifler, çiğ ürünleri pişmiş veya yarı pişmiş çıktılara dönüştürür.

| Tarif | Çiğ Ürün | Sonuç | Açıklama |
|---|---|---|---|
| Sucuk | `raw_sausage` | `cooked_sausage` | Izgara sucuk |
| Tavuk | `raw_chicken` | `cooked_chicken` | Tavuk kanat |
| Dana | `raw_meat` | `cooked_meat` | Dana biftek |
| Balık | `raw_fish` | `cooked_fish` | Izgara balık |
| Köfte | `raw_meatball` | `cooked_meatball` | Mangal köfte |
| Mısır | `sweet_corn` | `grilled_corn` | Közde mısır |

Not: Yetersiz pişirme durumunda bazı ürünler `undercooked_*` formuna dönüşebilir, aşırı pişirme durumunda ise `burnt_meat` oluşur.

## Ek Envanter Öğeleri

`config.lua` içinde tanımlı örnek özel itemler:

- `raw_meatball`
- `cooked_meatball`
- `sweet_corn`
- `grilled_corn`
- `briket_komur`
- `baharat`

İsterseniz kendi envanter sisteminize göre bu itemleri çoğaltabilir veya mevcut item adlarını değiştirebilirsiniz. QBCore kullanılıyorsa, `Config.QBItemDefinitions` içindeki tanımlar başlangıçta canlı item tablosuna eklenir.

## Kömür ve Tutuşturma

Kömür ve ateşleme tarafı item bazlı çalışır:

- Kömür itemleri: `komur`, `coal`, `briket_komur`
- Tutuşturma itemleri: `cakmak`, `lighter`

`briket_komur`, normal kömüre göre daha yavaş tükenir ve daha hızlı ısınma avantajı sağlayabilir.

## Baharat Sistemi

Baharat, ete isteğe bağlı eklenen bir modifier olarak kullanılır.

- Örnek item: `baharat`
- Etkisi: açlık değeri üzerinde bonus ve güvenli pişirme sınırında küçük bir esneklik

## Bildirimler ve Hata Mesajları

Kaynak; mangal dolu, mangal kullanımda, malzeme eksik, envanter dolu, yanmış ürün gibi durumlar için Türkçe bildirimler içerir. Bildirim stilini `Config.NotifyStyle` ile değiştirebilirsiniz.

## Sorun Giderme

- Mangal hiç görünmüyorsa `Config.GrillModel` için kullanılan modelin açık olduğundan emin olun.
- Target menüsü çalışmıyorsa `Config.TargetSystem` ve ilgili resource durumunu kontrol edin.
- Bildirim gelmiyorsa `Config.EnableNotifications` ve `Config.NotifyStyle` ayarlarını kontrol edin.
- Ses çalmıyorsa `Config.SoundEngine` ve ses dosyasının yolunu kontrol edin.
- QBCore kullanırken `qb-core` başlamadan bu kaynak yüklenirse bridge bağlantısı hazır olmayabilir; start sırasını düzeltin.

## Lisans ve Sahiplik

Bu kaynak `author = 'Gnesh'` olarak tanımlanmıştır. Repo'ya eklerken kendi sunucunuzun ihtiyaçlarına göre yapılandırabilirsiniz.

---

İyi oyunlar.
