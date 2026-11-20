# Follower Watch Desktop — macOS MVP

Ücretsiz, yerel çalışan macOS takipçi karşılaştırma uygulaması.

## Gereksinimler
- macOS 13 veya üstü
- Xcode Command Line Tools veya Xcode
- Swift 5.9+

## Çalıştırma
Terminal'de bu klasöre girin:

```bash
swift run
```

## Özellikler
- Birden fazla profil
- Instagram JSON / CSV / TXT içe aktarma
- Takipçi ve takip edilen listeleri
- İki son tarama arasında yeni/kaybolan kullanıcı karşılaştırması
- Arama, Instagram profilini açma
- Tarama geçmişi ve JSON yedeği
- Veriler Mac'te Application Support/FollowerWatchMac/data.json içinde tutulur.

## Instagram verisini hazırlama
Instagram > Hesaplar Merkezi > Bilgilerin ve izinlerin > Bilgilerini indir bölümünden
takipçiler ve takip edilenler verilerini JSON biçiminde indirin. Uygulamada ilgili liste
sayfasındayken **Veri içe aktar** düğmesini kullanın.

MVP notu: Her tarama için önce Takipçiler dosyasını, ardından Takip Edilenler dosyasını seçip içe aktarın. Uygulama iki dosyayı birleştirerek tek bir tarama kaydı oluşturur.
Bu prototip Instagram'a otomatik bağlanmaz; şifre veya oturum bilgisi istemez.
Instagram arayüzü ve dışa aktarma biçimleri değişebileceğinden gerçek dosyalarla test
edilmesi gerekir. Bu proje Follower Watch'ın bağımsız bir uygulama olarak yeniden
uygulamasıdır; orijinal ürünün kodunu veya markalı varlıklarını kopyalamaz.
