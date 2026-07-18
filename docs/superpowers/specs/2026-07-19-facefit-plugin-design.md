# FaceFit — Roblox Studio Plugin Design

**Tarih:** 2026-07-19
**Durum:** Taslak → Onay bekleniyor
**Yazar:** Claude (brainstorming session)

## Özet

FaceFit, Roblox Studio için bir plugin'dir. Kullanıcının kendi resmini Roblox karakter kafa modelinin yüz bölgesine düzgün şekilde yerleştirmesini, ölçeklendirmesini ve Roblox'a Decal olarak yüklemesini sağlar. Hem R6 (klasik) hem de R15 (modern) baş modellerini destekler. Tam iş akışı: 2D canvas üzerinde konumlandırma + 3D baş önizleme + PNG export + otomatik Roblox upload + Decal uygulama.

## Hedefler

1. Kullanıcının bir resmi (PNG/JPG) Roblox'un standart yüz texture boyutuna (512×512 veya 1024×1024) getirmek.
2. Resmi sürükle-bırak, zoom ve döndürme ile yüz bölgesine konumlandırmak.
3. 3D head preview ile sonucu Apply öncesi görmek.
4. Roblox AssetService üzerinden resmi Roblox'a yükleyip Decal olarak başa uygulamak.

## Kapsam Dışı

- Farklı vücut parçalarına (Torsı, Kol, Bacak) texture uygulama (sadece yüz).
- Animasyon veya 3D mesh manipülasyonu.
- Stok Roblox yüzlerini yönetme (sadece kullanıcı yüklemeleri).

## Mimari

**İki ana katman + iki UI yüzeyi:**

1. **Core Services katmanı** (`services/*.lua`) — UI'dan bağımsız, test edilebilir iş mantığı. AssetUploader ve DecalApplier bu katmanda yer alır ve doğrudan Roblox API'lerini çağırır (ayrı bir adaptör katmanı yoktur — sarmalama mantığı bu iki servistedir).
2. **UI katmanı** — `DockWidget` (sürekli açık, sağ panel) + `Preview Modal` (geçici, Apply öncesi 3D önizleme).

**Plugin context mimarisi (Roblox Plugin yaşam süresi):**
- `init.server.lua` Plugin'in **server context**'inde çalışır, DockWidgetPluginGui oluşturur, butonları bağlar.
- UI script'leri (`DockWidget.client.lua`, `PreviewModal.client.lua`) ilgili PluginGui'nin altına yerleştirilmiş **LocalScript**'lerdir ve **client context**'te çalışır. Kullanıcı etkileşimlerini (sürükle-bırak, slider) bunlar yönetir.
- Core Services script'leri (her ikisi tarafından da) `require()` ile yüklenir.

**Plugin akışı (yüksek seviye):**

```
Toolbar butonu (FaceFit ikonu)
    │
    ▼
DockWidget açılır (sağ panel)
    │
    ▼
Kullanıcı resim seçer → Canvas üzerinde konumlandırır (sürükle-bırak, zoom, rotation)
    │
    ▼
[Opsiyonel] Preview → Test Head spawn + 3D ViewportFrame göster
    │
    ▼
Apply → AssetService upload → Decal oluştur → Selection'daki Head'e uygula
```

## Bileşenler

### 1. `init.server.lua` — Plugin giriş noktası
- Toolbar butonu oluşturur (`Plugin:CreateToolbar()` + `CreateButton()`).
- Tıklanınca DockWidget'i açar/kapar (toggle).
- Plugin unload edilirse tüm instance referanslarını temizler (memory leak önleme).

### 2. `DockWidget.client.lua` — Ana UI scripti
Sağ panelde sabit dock widget (`Plugin:CreateDockWidgetPluginGui()`).

**UI öğeleri:**
- **Image picker butonu** — Studio file dialog (PNG/JPG filtreli).
- **Head type radio** — `R6` / `R15`. Varsayılan seçim: Selection'da Head varsa mesh tipinden otomatik algıla (ClassName == "MeshPart" ise R15, aksi halde R6). Algılama başarısızsa varsayılan R15 olur.
- **Resolution dropdown** — `512x512` / `1024x1024`.
- **Canvas** — 512×512 (veya 1024×1024) bir `ImageLabel`. Üzerinde:
  - Yarı-saydam ghost template (R6 veya R15, çözünürlüğe göre).
  - Kullanıcının resmi (sürüklenebilir).
- **Slider'lar** — Zoom (0.25–4), Offset X (-100..100), Offset Y (-100..100), Rotation (-180..180).
- **Grid snap toggle** — Açık (varsayılan) / kapalı. 16px snap.
- **Butonlar**:
  - `Reset` — Pozisyon state'ini sıfırla.
  - `Preview` — PreviewModal'ı aç.
  - `Export PNG` — Final texture'ı PNG olarak diske yaz.
  - `Upload & Apply` — AssetService upload + Decal uygulama (önce Preview açar).

### 3. `PreviewModal.client.lua` — 3D önizleme
Studio'nun ortasında modal pencere.

**İçerik:**
- Bir `ViewportFrame` (içinde Camera + Lighting).
- Test Head:
  - R6 seçildiyse: `ReplicatedStorage.ZombieTemplate.ZombieBase.Head` veya eşdeğer R6 Head mesh.
  - R15 seçildiyse: Modern R15 Head mesh.
- Background: beyaz.
- Butonlar:
  - `Cancel` — Test Head'i sil, modalı kapat.
  - `Apply to Selected Head` — AssetService upload + Selection'daki Head'e Decal uygula.
  - `Apply as New Decal Asset` — Sadece upload (Decal'i parent etmeden bırak, kullanıcı manuel kullanır).

**Test Head yaşam süresi:** Modal açıldığında `ServerStorage.FaceFitTestHeads` (runtime'da oluşturulan) içine spawn edilir ve ViewportFrame'e referansı verilir. Modal kapandığında veya Apply sonrası test head `Destroy()` edilir; klasör bir sonraki modal açılışında yeniden kullanılır veya boşsa silinir.

### 4. `services/FaceMapper.lua` — UV pozisyon hesaplama
- Giriş: `headType: HeadType`, `resolution: 512 | 1024`.
- Çıkış: `FaceRegion { x, y, width, height, centerX, centerY }`.
- Roblox standart yüz koordinatlarına göre sabit değerler döndürür.
- Bir kez hesaplanır, sonra sadece okunur (no side effects, saf fonksiyon).

### 5. `services/ImageProcessor.lua` — Canvas işlemleri
- Giriş:
  - `userImage: ImageData` (decoded).
  - `position: FacePosition { offsetX, offsetY, zoom, rotation }`.
  - `snapEnabled: boolean`.
  - `resolution: 512 | 1024`.
- Çıkış: `FaceRenderResult { pixels: buffer, width, height }` (RGBA).
- Sorumluluklar:
  - Zoom uygula (clamp 0.25–4).
  - Offset uygula (grid snap: 16px, snapEnabled ise).
  - Rotation uygula (pivot center, -180..180 wrap).
  - Final compositing: resim + saydam arka plan (RGBA, alpha=0 köşeler).
- Roblox `EditableImage` API kullanır (Studio'da mevcut).

### 6. `services/AssetUploader.lua` — Roblox upload
- Giriş: `FaceRenderResult` (pixel data).
- Çıkış: `assetId: string`.
- Sorumluluklar:
  - `AssetService:Upload()` ile resmi Roblox'a yükle.
  - Upload progress'i callback ile UI'a bildirir (progress bar).
  - Hata yönetimi (aşağıdaki hata bölümünde).
  - Best-effort cleanup: Upload başarısızsa partial asset'i sil.

### 7. `services/DecalApplier.lua` — Mesh'e decal uygulama
- Giriş: `targetHead: BasePart`, `assetId: string`, `headType: HeadType`, `mode: "replace" | "new"`.
- Çıkış: `Decal` instance.
- Sorumluluklar:
  - Selection'dan Head al (validate: IsA("BasePart") ve Name == "Head").
  - Mevcut Decal kontrolü:
    - Yoksa: yeni Decal oluştur.
    - Varsa ve mode == "replace": mevcut Decal'ı sil, yeni oluştur.
    - Varsa ve mode == "new": ek Decal olarak ekle (isim: `FaceFit_<timestamp>`).
  - Decal parent:
    - R6: Decal'ı doğrudan Head'e parent et, Face yüzeyine uygula (`Decal.Face = Enum.NormalId.Front`).
    - R15: Decal'ı uygun Attachment'a parent et (R15 head'in `FaceCenterAttachment` veya benzeri).
  - Decal.Texture = `rbxassetid://<assetId>`.

## Plugin Klasör Yapısı

```
ReplicatedStorage/
  Plugins/
    FaceFit/                          # Plugin objesi
      init.server.lua                 # Plugin server context (giriş)
      DockWidgetGui/                  # DockWidgetPluginGui (statik)
        DockWidget.client.lua         # LocalScript (dock UI mantığı)
        services/                     # Paylaşılan services
          FaceMapper.lua
          ImageProcessor.lua
          AssetUploader.lua
          DecalApplier.lua
      PreviewModalGui/                # Modal ScreenGui (runtime oluşturulur)
        PreviewModal.client.lua       # LocalScript (modal mantığı)
      presets/                        # Ghost template görselleri
        FaceTemplate_R6.png           # 512×512 R6
        FaceTemplate_R15.png          # 512×512 R15
        FaceTemplate_R6_HD.png        # 1024×1024 R6 HD
        FaceTemplate_R15_HD.png       # 1024×1024 R15 HD
      tests/
        FaceMapper.spec.lua
        ImageProcessor.spec.lua
        AssetUploader.spec.lua
        DecalApplier.spec.lua
```

**Notlar:**
- `DockWidgetGui` statik olarak plugin'e eklenir; `PreviewModalGui` ise `init.server.lua` tarafından runtime'da `Plugin:CreateDockWidgetPluginGui()` ile oluşturulur (her Apply öncesi taze modal).
- `services/` klasörü `DockWidgetGui` altında paylaşılır; her iki LocalScript de aynı servisleri `require()` ile yükler.
- `tests/` Studio plugin yüklendikten sonra manuel olarak veya TestEZ runner ile çalıştırılır.

## Veri Modelleri

```lua
-- Pozisyon state'i (DockWidget'ta tutulur)
type FacePosition = {
    offsetX: number,    -- piksel, -256..256 (512 için)
    offsetY: number,    -- piksel, -256..256
    zoom: number,       -- 0.25..4
    rotation: number,   -- derece, -180..180
    snapEnabled: boolean,
}

-- Head tipi
type HeadType = "R6" | "R15"

-- Face bölgesi
type FaceRegion = {
    x: number,        -- piksel
    y: number,
    width: number,
    height: number,
    centerX: number,
    centerY: number,
}

-- Render çıktısı
type FaceRenderResult = {
    pixels: buffer,        -- RGBA pixel data
    width: 512 | 1024,
    height: 512 | 1024,
}

-- Uygulama isteği
type ApplyRequest = {
    headType: HeadType,
    resolution: 512 | 1024,
    assetId: string,       -- Roblox upload sonrası
    targetHead: BasePart,  -- Selection'dan
    mode: "replace" | "new",
}
```

## Veri Akışı

**Ana iş akışı (Upload & Apply):**

```
[Kullanıcı resmi seçer]
   ↓
[ImagePicker] → decoded ImageData
   ↓
[DockWidget] pozisyon/zoom bilgisini tutar
   ↓ (her değişiklikte, debounced)
[ImageProcessor.render()] → EditableImage → Canvas ImageLabel'a basılır
   ↓
[Kullanıcı "Upload & Apply"a basar]
   ↓
[Preview Modal] açılır, test Head spawn edilir
   ↓
[ImageProcessor.render()] → EditableImage → Decal olarak test Head'e uygulanır
[3D Viewport'ta göster]
   ↓
[Kullanıcı onaylar: "Apply to Selected Head"]
   ↓
[AssetUploader.upload()] → assetId
   ↓
[DecalApplier.apply(selection.Head, assetId)]
   ↓
[Selection'daki Head'de Decal görünür]
   ↓
[Preview Modal kapanır, test Head silinir]
[Toast: "Yüz başarıyla uygulandı"]
```

**Senkronizasyon kuralları:**
- DockWidget pozisyon state'i **tek kaynak** (single source of truth).
- Preview Modal açıldığında state'i okur (read-only), değişiklik yapmaz.
- Apply başarılıysa toast bildirim, başarısızsa hata toast'u.

## Hata Yönetimi

**1. Dosya seçme hataları**
- Geçersiz format (PNG/JPG değil) → toast: "Sadece PNG/JPG destekleniyor".
- Dosya çok büyük (>10MB) → toast: "Dosya 10MB'dan küçük olmalı".
- Decode başarısız → toast: "Resim okunamadı".

**2. Canvas/Image işlem hataları**
- Zoom sınırı aşıldı → otomatik clamp (UI slider'da limit zaten var).
- Negatif boyut → sıfırla (savunma amaçlı).
- Memory limit (çok büyük decoded resim) → toast: "Resim çok büyük, lütfen küçültün".

**3. Upload hataları**
- AssetService izni yok → toast: "Roblox'a yükleme izni yok. Plugin ayarlarını kontrol edin".
- Network hatası → retry butonu (max 3 deneme, exponential backoff).
- Upload sırasında modal kapatılırsa → işlem iptal, partial asset temizlenir (best-effort).

**4. Decal uygulama hataları**
- Selection boş → "Apply" butonu disabled.
- Selection'daki obje Head değil → toast: "Lütfen bir Head seçin".
- Mevcut Decal var → modal sor: "Replace / Add New / Cancel".

**5. Plugin runtime hataları**
- `task.spawn` ile korunan kritik çağrılar → bir modül çökerse UI bozulmaz, sadece o işlem başarısız olur.
- State kayıpları tolere edilir (state per-session, disk'e yazılmaz).

**Hata UI'ı:**
- Projede zaten var olan toast sistemini kullan (ShopUI ile aynı pattern).
- Kritik hatalar: modal block (retry/cancel).
- Ufak hatalar: toast (auto-dismiss 3s).

## Test Stratejisi

**1. Unit testler (Studio dışında, Luau test framework)**
- `FaceMapper.spec.lua`:
  - R6 512×512 → beklenen face region (sabit değerler).
  - R15 512×512 → beklenen face region.
  - R6 1024×1024 → beklenen face region.
  - R15 1024×1024 → beklenen face region.
- `ImageProcessor.spec.lua`:
  - Zoom clamp (0.25 altı, 4 üstü).
  - Grid snap (16px grid'e yuvarlama).
  - Rotation sınırı (-180..180 wrap).
  - Final pixel data boyutu (her zaman resolution × resolution × 4 byte).
- Test kapsamı: Sadece saf Lua logic, hiçbir Roblox API çağrısı yok (mock gerektirmez).

**2. Integration testler (Studio içinde)**
- `AssetUploader.spec.lua`: Mock `AssetService` ile → assetId dönüyor mu.
- `DecalApplier.spec.lua`: Mock Head mesh → Decal oluştu mu, doğru Face yüzeyine mi.

**3. Manuel test (Play mode)**
- Gerçek resim seçme → canvas → preview → apply akışı.
- Farklı zoom/rotation kombinasları.
- Büyük/küçük resimlerle test.
- Hata senaryoları (çok büyük dosya, geçersiz format).

**4. Play test (subagent ile)**
- Studio play mode'da plugin çalıştır.
- Test zombie template'ine face uygula, görsel doğrula.

**Test kapsamı hedefi:**
- Unit testler: %80+ line coverage (Core Services).
- Integration: ana iş akışı (seç → render → upload → apply).
- Manuel: UI etkileşimleri, edge case'ler.

## Bağımlılıklar

- **Roblox Studio API** — `Plugin`, `AssetService`, `DockWidgetPluginGui`, `Selection`, `InsertService`, `EditableImage`.
- **Projede mevcut** — `ShopUI`'deki toast sistemi (reuse).
- **Test framework** — Luau unit test framework (Studio bundled veya TestEZ).

## Açık Sorular

- HD (1024×1024) desteği gerçekten gerekli mi? Roblox face texture slot'u genelde 512×512 kabul edip otomatik scale yapıyor.
- Test Head mesh'leri için hazır R6/R15 head'ler workspace'te mevcut mu? Yoksa test için ayrı mesh eklemek gerekecek.
- Toast sistemi için `ShopUI`'yi import etmek mi, yoksa plugin-local basit bir toast mu?

## Sonraki Adımlar

1. Spec onayı (kullanıcı review).
2. `writing-plans` skill'i ile implementasyon planı oluştur.
3. Plan onayı sonrası implementasyon başla.
