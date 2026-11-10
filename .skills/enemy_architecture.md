# Canavar (Düşman) Sistemi Mimarisi

Bu projede sunucu performansını maksimuma çıkarmak ve gecikmeleri (lag) sıfırlamak için özel bir sunucu-istemci ayrımı mimarisi uygulanmıştır. Kod yazarken veya güncellerken bu mimariye sadık kalınmalıdır:

## 1. Sunucu Tarafı (Server-Side)
- **Sunucuda Humanoid Yoktur:** Canavarların sunucu modelinde (workspace.Enemies altındaki modeller) `Humanoid` nesnesi **kesinlikle bulunmaz**.
- **Tek Parça Fizik (Hitbox):** Canavarlar sunucuda sadece `HumanoidRootPart` ve zemin çarpışması için ona kaynaklanmış (welded) görünmez bir `CollisionPart` nesnesinden ibarettir.
- **Hareket Sistemi (Fizik Tabanlı):** Canavarlar sunucuda `Humanoid:Move()` ile değil, `AssemblyLinearVelocity` (yatayda hız) ve `UprightGyro` (dikey duruş sabitleme) kullanılarak fizik motoru üzerinden hareket ettirilir.
- **Can ve Hasar Yönetimi:** Canavarların sağlığı `Humanoid.Health` ile değil, modelin altındaki `Health` isimli bir `NumberValue` ile kontrol edilir. Hasar kontrolü `CombatManager` ve `EnemyManager` içindeki bu değerler üzerinden yürütülür.

## 2. İstemci Tarafı (Client-Side Visuals)
- **Görsel Modelleme ve Animasyon:** Canavarların gerçek 3D modelleri, parçaları, efektleri ve animasyonları istemciye (`EnemyVisualsController.client.lua`) aittir.
- **Klonlama ve Animasyon:** Sunucudan bir canavar replike edildiğinde, istemci `ReplicatedStorage.Assets.Enemies` altındaki ilgili modeli klonlar, parçalarını unanchor eder ve sunucu hitbox'ına kaynaklar. İstemci kendi oluşturduğu local `Humanoid` üzerinden yürüyüş animasyonlarını yerel olarak oynatır.
- **Prosedürel Görsel Fallback (Örn: Slime):** Eğer `ReplicatedStorage` içinde ilgili düşman tipi için bir model bulunamazsa, istemci kendi içerisinde prosedürel olarak 3D görsel oluşturabilir (örneğin Slime için parlayan yeşil jöle gövdesi ve gözler). Bu tarz animasyonsuz tek parça modeller `EnemyVisualsController.client.lua` içerisindeki `RenderStepped` döngüsünde tamamen matematiksel formüllerle (Squash & Stretch) 60 FPS'te akıcı bir şekilde anime edilir.

## 🔴 Kritik Kurallar (Geliştiriciler İçin)
1. **Sunucuya Asla Humanoid Ekleme:** `EnemyManager.server.lua` üzerinde canavarlar için `Humanoid` nesnesi yaratma veya arama işlemi yapmayın. Canavarın hareketini fizik hızlarıyla yönetin.
2. **Sağlık Kontrolleri:** Sunucu canavar durumunu sorgularken `enemy:FindFirstChild("Health")` NumberValue değerini kontrol edin. `enemy:FindFirstChild("Humanoid")` kontrolü sunucuda her zaman nil dönecektir.
3. **Özel Model Desteği:** `Slime` veya benzeri prosedürel modeller, `ReplicatedStorage.Assets.Enemies` altına aynı isimle bir model yerleştirilirse otomatik olarak o modelle ezilir. Bu yüzden prosedürel kodlar her zaman fallback olarak çalışmalıdır.

## 3. Çarpışma (Collision) ve Tırmanma (Climb) Standartları
- **Fiziksel Çarpışma (CanCollide):** Canavarların birbirlerinin içinden geçmesini engellemek için sunucu tarafındaki `HumanoidRootPart` ve `CollisionPart` parçalarının `CanCollide` değeri `true` yapılmıştır ve `Enemies` çarpışma grubu kendi kendisiyle çarpışacak şekilde (`true`) ayarlanmıştır. Script tabanlı herhangi bir yapay itme (separation) kodu kullanılmaz.
- **Kısa Raycast ile Megabonk Tarzı Tırmanma (Climb):** Canavarlar önlerine gelen duvar veya engelleri aşmak için ayak hizasından çok kısa bir raycast (`steerDir * (1.6 * scale)`) atarlar. Engel tespit edildiğinde dikey bir `ClimbBV` (BodyVelocity) ile `20 * scale` hızında pürüzsüzce yukarı kaydırılırlar. Engel aşıldığı an raycast kesilir ve dikey itme kaldırılır.
- **Zemin Hizalama (Doğuş Yüksekliği):** Canavarın bitiş doğuş konumu (`spawnPos.Y`) tam olarak `actualGroundY + scale` olarak hesaplanarak zeminle mükemmel hizalanma sağlanır.
