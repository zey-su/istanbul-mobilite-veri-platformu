# İstanbul Mobilite Veri Platformu

Bu depo, Tech İstanbul Data Engineering Online Bootcamp'inin lab ortamını ve bitirme projesinin başlangıç iskeletini taşır. On oturum boyunca İstanbul'un toplu ulaşım ve trafik verisini işleyen uçtan uca bir veri platformunu bu depo üzerinde kurarsınız.

## Ortamın kurulması

Lab, GitHub Codespaces üzerinde tarayıcıda çalışır; bilgisayarınıza program kurmanız ya da yönetici yetkisi almanız gerekmez. Kurulum Oturum 1'de birlikte yapılır ve dört adımdan oluşur:

1. GitHub hesabınız yoksa github.com/signup adresinden kişisel bir hesap açıyorsunuz. Kayıt sırasında e-posta adresiniz doğrulanır.
2. github.com/settings/codespaces sayfasının alt bölümündeki "Default idle timeout" alanına 10 yazıp alanın yanındaki "Save" düğmesine basıyorsunuz. Ayar yalnızca bundan sonra açılan Codespace'lere uygulandığı için Codespace'ten önce yapılır.
3. Bu sayfanın üstündeki "Use this template" düğmesinden "Create a new repository" seçeneğine geçiyorsunuz. "Repository name" alanına `istanbul-mobilite-veri-platformu` yazıyor, "Owner" alanında kişisel hesabınızı ve görünürlükte "Public" seçeneğini bırakıp "Create repository" düğmesine basıyorsunuz. Yeni deponuzda "Code" düğmesinin altındaki "Codespaces" sekmesinden "Create codespace on main" düğmesine basıyorsunuz. İlk açılışta ortam kendini kurar ve kurulum bittiğinde terminalde "İlk kurulum tamamlandı." satırı görünür.
4. Terminalde sırayla `make veri`, `make kontrol` ve `make oturum N=01` komutlarını çalıştırıyorsunuz. `make veri` lab veri setlerini indirir ve doğrular. `make kontrol` ortamı on iki adımda sınar ve en altta TAMAM veren adımların sayısını 12/12 biçiminde yazar. `make oturum N=01` Oturum 1'in dosyalarını deponuza ekler.

Bitirme projesi herkese açık bir depo olarak teslim edildiği için depo baştan "Public" açılır. Depoya parola, kimlik bilgisi ya da kişisel veri girmez.

## Codespace'e dönüş ve çalışmanın kaydı

github.com/codespaces sayfası Codespace'lerinizi listeler. Deponuzun Codespace'inin adına tıkladığınızda Codespace tarayıcıda açılır; durmuşsa yeniden başlar. PostgreSQL ve Polaris her açılışta kendiliğinden başlar.

Codespace tek sekmede açık tutulur. VS Code, Codespace'in açık olduğu her sekme için yaklaşık 1 GB bellek tutan ayrı süreçler çalıştırır; ikinci bir sekme uygulamalardaki büyük sorgulara kalan belleği azaltır.

Codespace'teki değişiklikler yalnızca `git push` komutuyla GitHub'daki deponuza gider. GitHub, durdurulduktan sonra 30 gün açılmayan Codespace'i siler ve gönderilmemiş değişiklikler o Codespace'le birlikte kaybolur. Her çalışmanın sonunda değişiklikler commit edilip gönderilir.

## Komutlar

| Komut | İşlev |
|---|---|
| `make baslat` | PostgreSQL ve Polaris'i başlatır |
| `make durdur` | Çalışan lab servislerini durdurur |
| `make durum` | Servislerin durumunu gösterir |
| `make sql` | DuckDB'yi lab kataloğuna bağlı olarak açar |
| `make spark` | PySpark kabuğunu lab kataloğuna bağlı olarak açar |
| `make kafka-baslat` | Kafka'yı başlatır |
| `make kafka-durdur` | Kafka'yı durdurur |
| `make veri` | Lab veri setlerini indirir ve doğrular |
| `make kontrol` | Ortamı on iki adımda sınar |
| `make oturum N=01` | Oturumun başlangıç dosyalarını depoya ekler, var olan dosyalara dokunmaz |
| `make odev-kontrol N=01` | Oturumlar arası görevi sınar ve kanıt kodunu yazar |

Codespace her açıldığında PostgreSQL ve Polaris kendiliğinden başlar. Kafka belleği ilgili oturumlarda kullandığı için kendiliğinden açılmaz; `make kafka-baslat` komutu onu ayrıca başlatır.

## Klasörler

| Klasör | İçerik |
|---|---|
| `lab/` | Kurulum, servis, veri ve kontrol betikleri |
| `veri/` | `make veri` ile inen veri dosyaları |
| `lakehouse/` | Iceberg tablolarının veri ve metadata dosyaları |
| `.lab/` | Servislerin durum dosyaları ve bağlantı bilgileri |

Veri dosyaları ve parolalar depoya girmez: `.gitignore` dosyası `veri/`, `lakehouse/` ve `.lab/` klasörlerini depo dışında tutar.

## Sürümler

Lab sürümleri eğitim boyunca sabit kalır.

| Bileşen | Sürüm |
|---|---|
| Python | 3.13 |
| Java | 21 |
| PostgreSQL | 17 |
| DuckDB | 2.0.0 |
| Apache Iceberg | 1.12.0 |
| PyIceberg | 0.12.0 |
| Apache Polaris (REST katalog) | 1.9.0 |
| Apache Spark | 4.1.4 |
| Apache Kafka | 4.4.0 |
| Apache Airflow | 3.4.0 |
| dbt | 2.0.11 |
| dbt Core ve dbt-duckdb | 1.12.7 ve 1.11.1 |

Python paketlerinin tam listesi `lab/gereksinimler/` klasöründeki kilit dosyalarında durur.

## Veri ve lisans

Lab, İstanbul Büyükşehir Belediyesi Açık Veri Portalı'ndaki (data.ibb.gov.tr) iki veri setini kullanır:

- Saatlik Toplu Ulaşım Veri Seti: Ocak, Şubat ve Mart 2024
- Saatlik Trafik Yoğunluk Veri Seti: 2024 yılının on iki ayı

İBB bu veri setlerini İBB Açık Veri Lisansı ile yayımlar ve lisans kaynak gösterimini zorunlu tutar. Lab kopyası eğitim için yeniden düzenlendiğinden sonuçlar İBB'nin yayımladığı dosyalarla birebir örtüşmeyebilir. Ayrıntılar `veri/OKU-BENI.md` dosyasında yer alır.

## Codespaces kotası

Kişisel GitHub hesabı her ay 120 çekirdek-saat işlem ve 15 GB-ay depolama kotasıyla gelir. 2 çekirdekli lab makinesinde aylık işlem kotası 60 saatlik çalışmaya karşılık gelir. Hesapta ödeme yöntemi tanımlı değilse kota bittiğinde Codespaces durur ve ücret çıkmaz.

Kotayı üç kural korur:

- "Default idle timeout" değeri 10 dakikadır. Codespace 10 dakika işlem görmediğinde kendiliğinden durur.
- Çalışma bittiğinde github.com/codespaces sayfasında Codespace'in sağındaki "..." menüsünden "Stop codespace" seçilir.
- Eğitim boyunca tek bir Codespace kullanılır. Her yeni Codespace depolama kotasından ayrıca harcar; bozulan ortam yeni bir Codespace yerine komut paletindeki "Codespaces: Rebuild Container" komutuyla onarılır.

Kullanım miktarı github.com/settings/billing sayfasında görünür.

## Sorun giderme

`make kontrol` Polaris ve veri dosyaları adımlarında HATA satırına çözüm komutunu da yazar. Diğer durumların çözümü aşağıdaki tablodadır.

| Belirti | Çözüm |
|---|---|
| Codespace açılmıyor ya da bağlantı kopuyor | Kurumsal ağ Codespaces'in alan adlarını engelliyor olabilir. Aynı adımlar ev internetinde ya da telefonun internet paylaşımında denenir. Codespace bu ağlarda açılıyorsa tablonun altındaki alan adı listesi bilgi işlem birimine iletilir. |
| Codespace oluşturulurken hata veriyor | github.com/codespaces sayfasında yarım kalan Codespace "..." menüsünden silinir ve Codespace yeniden oluşturulur. |
| "İlk kurulum tamamlandı." satırı görünmüyor | Komut paletindeki (Ctrl+Shift+P, macOS'ta Cmd+Shift+P) "Codespaces: Rebuild Container" komutu kurulumu yeniden çalıştırır. |
| `make kontrol`: PostgreSQL ya da Polaris HATA | `make baslat` komutundan sonra `make kontrol` yeniden çalıştırılır. |
| `make kontrol`: Veri dosyaları HATA | `make veri` eksik ya da bozuk dosyayı yeniden indirir. |
| `make kontrol`: Kafka HATA | `make kafka-durdur` komutundan sonra `make kontrol` yeniden çalıştırılır. Betik Kafka'yı gerektiğinde kendisi başlatır ve sınamadan sonra durdurur. |
| `make kontrol`: Bellek ve disk HATA | Codespace 2 çekirdekli ve 8 GB bellekli makinede çalışmıyor olabilir. github.com/codespaces sayfasındaki "..." menüsünde "Change machine type" seçeneği makineyi değiştirir. |
| DuckDB sorgusu `Terminated` yazıp kapanıyor | Codespace'in belleği dolmuştur. VS Code, Codespace'in açık olduğu her sekme için yaklaşık 1 GB'lık ayrı süreçler çalıştırır. Codespace github.com/codespaces sayfasındaki "..." menüsünden "Stop codespace" ile durdurulur, tek sekmede yeniden açılır ve sorgu yeniden çalıştırılır. |
| Codespace kendiliğinden durdu | 10 dakikalık bekleme süresi doldu. Codespace github.com/codespaces sayfasından yeniden açılır ve servisler kendiliğinden başlar. |
| Codespaces kotası doldu | Kota yeni fatura döneminde yenilenir. Bu sürede oturumlar eğitmen ekranından izlenir ve uygulamalar sonra tamamlanır. |

Codespaces şu alan adlarını kullanır: github.com, *.github.com, *.github.dev, *.githubusercontent.com, *.visualstudio.com, *.vscode-webview.net, *.azureedge.net, *.msecnd.net, *.windows.net, *.microsoft.com. SSL incelemesi yapan kurumsal ağlarda *.github.dev ve *.visualstudio.com alan adları için inceleme muafiyeti gerekir.
