# Gym Management System — SE 2230 Project

MySQL veritabanı (tablolar, fonksiyonlar, trigger'lar, view'lar, örnek veri) +
Flask tabanlı web arayüzü.

---

## Çalıştırmak için (TEK ADIM)

### Ön koşullar (bir kere kurulması yeterli)

1. **Python 3.10+** — [python.org](https://www.python.org/downloads/) (kurarken
   *"Add Python to PATH"* kutusu işaretli olsun)
2. **MySQL Server 8.x** — [dev.mysql.com/downloads/installer](https://dev.mysql.com/downloads/installer/)
   (kurulumda *"Server only"* yeterli; root şifresini belirleyin ve
   **unutmayın**)

> MySQL servisinin çalıştığından emin olun: Windows arama → **Services** →
> **MySQL80** (veya **MySQL84**) → sağ tık → *Start*

### Çalıştırma

#### Windows
```
.\start.bat
```

#### macOS / Linux
```
./start.sh
```

İlk açılışta script bir kere **MySQL root şifrenizi** soracak. Geri kalan her
şeyi (Python sanal ortam, pip paketleri, veritabanı kurulumu) otomatik yapar.

Tarayıcıda → **<http://127.0.0.1:5050>**

Kapatmak için terminalde **Ctrl + C**.

---

## Hata olursa

| Mesaj | Çözüm |
|---|---|
| *MySQL bulunamadi* | MySQL Server 8.x kurulu değil — yukarıdaki linkten kurun |
| *MySQL servisine baglanilamadi* | Services'tan MySQL80/MySQL84'ü başlatın |
| *MySQL sifresi yanlis* | Script otomatik olarak yeni şifre soracak, doğrusunu girin |
| *Python bulunamadi* | Python kurulu değil veya PATH'te değil — yeniden kurun, *Add to PATH* işaretleyin |

---

## Proje yapısı

```
GymManagementSystem/
├── start.bat / start.sh    # otomatik kurulum + başlatma
├── README.md
├── database/               # SQL dosyaları
│   ├── 01_schema.sql
│   ├── 02_data.sql
│   ├── 03_functions.sql
│   ├── 04_triggers.sql
│   ├── 05_views.sql
│   └── run_all.sql         # mysql interaktif modunda kullanılır (source run_all.sql)
└── app/                    # Flask web uygulaması
    ├── app.py
    ├── db.py
    ├── requirements.txt
    ├── .env.example
    ├── static/style.css
    └── templates/
```

## Veritabanı içeriği

* **12 tablo:** `membership_plans, trainers, classes, class_schedule, equipment,
  equipment_maintenance, class_equipment, members, health_metrics, payments,
  bookings, attendance`
* **Fonksiyonlar:** `available_spots`, `is_membership_active`,
  `member_total_revenue`, `plan_end_date`
* **Stored Procedure'ler:** `sp_book_class` (transactional booking — kapasite
  ve aktif üyelik kontrolü), `sp_check_in`
* **Trigger'lar:**
  * `members.membership_end_date` insert/update'te otomatik dolar
  * Sınıf dolu veya üyelik pasifse booking reddedilir
  * Attendance check-in tarihi, booking tarihinden önce olamaz (geç check-in serbest)
  * `equipment.status`: maintenance kaydı eklendiğinde `maintenance`'a, son
    kayıt silindiğinde `available`'a döner
  * `payments.next_billing_date` plan süresinden otomatik hesaplanır
* **View'lar:** `v_active_members, v_member_overview, v_class_schedule_full,
  v_member_bookings_summary, v_equipment_status, v_revenue_by_plan`

## Web arayüzü

Tüm tablolar için CRUD, dashboard, üye detay sayfası (plan, ödemeler,
rezervasyonlar, sağlık metrikleri geçmişi), ekipman bakım geçmişi.
Booking ve attendance işlemleri stored procedure üzerinden gider — geçersiz
işlemlerde MySQL'in `SIGNAL` mesajı flash alert olarak gösterilir.

---

## Manuel kurulum (script çalışmazsa)

```bash
# 1. Veritabanı — dosyaları sırayla yükle
cd database
mysql -u root -p < 01_schema.sql
mysql -u root -p < 03_functions.sql
mysql -u root -p < 04_triggers.sql
mysql -u root -p < 05_views.sql
mysql -u root -p < 02_data.sql

# 2. Uygulama
cd ../app
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env          # .env içindeki DB_PASSWORD'u kendi MySQL şifrenizle değiştirin
python app.py
```

> **Not:** `run_all.sql` mysql komut satırının interaktif modunda kullanılır
> (`mysql> source run_all.sql`). Yukarıdaki gibi `<` ile yönlendirme yapılırsa
> `SOURCE` komutu tanınmadığı için çalışmaz. start.sh / start.bat zaten bu
> dosyaları tek tek yüklüyor.
