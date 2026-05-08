# 🪙 Crypto Real-Time Data Pipeline

> Materi Hands-On Pelatihan Big Data Lab MCI 2026 · ClickHouse & Metabase Session

Proyek ini mendemonstrasikan rangkaian *real-time data pipeline* yang menarik harga **250 cryptocurrency** dari **CoinGecko API**, mengalirkannya ke **ClickHouse** sebagai gudang data berorientasi kolom, lalu menyajikannya dalam bentuk visual melalui **Metabase**. Keseluruhan alur diorkestrasikan oleh **Apache Airflow** dan dikemas dalam satu konfigurasi Docker yang reproducible.

Pendekatan yang diterapkan adalah **micro-batching** dengan interval 10 menit, dipadukan dengan pola **TRUNCATE-INSERT**. Konsekuensinya, setiap kali dashboard diakses, yang ditampilkan selalu merupakan snapshot terbaru — bukan data yang sudah usang.

---

## 🏗️ Arsitektur Sistem

```
CoinGecko API
     ↓  (250 coins / 10 menit)
[Ingestion — fetch_crypto.py]
     ↓  simpan .json
[Data Lake — folder lokal]
     ↓  baca & load
[Load — load_to_clickhouse.py]
     ↓  truncate-insert via TCP (clickhouse_driver)
[Data Warehouse — ClickHouse]
     ↓  koneksi langsung
[Dashboard — Metabase]

↻  Seluruh siklus diatur oleh Apache Airflow
```

**Lima dimensi analisis utama yang akan dibahas:**
- **Top 10 Market Cap** — coin dengan kapitalisasi pasar terbesar pada periode pengamatan
- **Gainers & Losers** — coin dengan kenaikan dan penurunan harga paling signifikan dalam 24 jam
- **Volatilitas** — magnitudo fluktuasi harga harian, diukur dari selisih high dan low
- **Volume Trading** — peringkat coin berdasarkan intensitas transaksi pada hari berjalan
- **Jarak dari ATH** — posisi harga saat ini relatif terhadap All-Time High masing-masing coin


## 🛠️ Tech Stack

| Komponen | Teknologi |
|----------|-----------|
| Orchestration | Apache Airflow 2.9 |
| Data Source | CoinGecko Public API (tanpa API key) |
| Connection Method | TCP Native port 9000 via `clickhouse_driver` |
| Data Warehouse | ClickHouse (column-oriented OLAP) |
| BI & Dashboard | Metabase |
| Infrastructure | Docker & Docker Compose |
| Language | Python 3.11 |


## 📂 Struktur Proyek

```
crypto-pipeline/
├── dags/
│   ├── scripts/
│   │   ├── fetch_crypto.py            # Task 1: Ekstraksi API → Data Lake
│   │   └── load_to_clickhouse.py      # Task 2: Data Lake → ClickHouse
│   └── crypto_dag.py                  # Definisi DAG Airflow
├── data_lake/
│   └── crypto/                        # Penyimpanan sementara .json (auto-hapus)
├── docker-compose.yml                 # Konfigurasi seluruh service
├── Dockerfile                         # Custom Airflow image
├── requirements.txt                   # Dependensi Python
├── .gitignore
├── sql-cliclhouse.sql                 # Referensi queries ClickHouse (25+ queries)
└── sql-metabase.sql                   # Referensi queries Metabase dashboard
```

---

## 🚀 Tutorial

### Prasyarat
Terdapat dua kebutuhan minimal yang perlu disiapkan terlebih dahulu sebelum memasuki tahap pertama:
- [Docker Desktop](https://docs.docker.com/get-docker/) — telah terinstal dan dapat dijalankan tanpa kendala
- Akses terminal — Git Bash pada Windows, Terminal bawaan pada macOS, atau shell apa pun pada distribusi Linux

---

### Step 1 — Penyusunan Struktur Direktori

Pekerjaan dimulai dari penyiapan direktori utama yang akan menampung seluruh komponen proyek.

```bash
mkdir crypto-pipeline
cd crypto-pipeline
```

Selanjutnya, kita bentuk dua subdirektori yang berbeda peran: satu untuk artefak DAG Airflow, satu lainnya untuk data lake lokal.

```bash
mkdir -p dags/scripts data_lake/crypto
```

Sebagai penutup tahap ini, kita pratulis seluruh berkas dalam keadaan kosong. Pengisian kontennya akan dilakukan pada Step 2.

```bash
touch docker-compose.yml Dockerfile requirements.txt .gitignore
touch dags/crypto_dag.py
touch dags/scripts/fetch_crypto.py
touch dags/scripts/load_to_clickhouse.py
```

> `dags/` → dipindai otomatis oleh Airflow untuk mendaftar jadwal serta alur kerja  
> `dags/scripts/` → tempat tinggal logika utama kedua task (Task 1 dan Task 2)  
> `data_lake/crypto/` → lokasi transit `.json` hasil ingest; berkas dihapus otomatis setelah Task 2 menyelesaikan eksekusinya

---

### Step 2 — Pengisian Berkas Konfigurasi & Kode

Tabel berikut merangkum peran masing-masing berkas. Konten dapat disalin langsung dari repository ini ke berkas kosong yang sudah disiapkan pada Step 1:

| Berkas | Peran |
|------|--------|
| `requirements.txt` | Manifesto library Python — `requests`, `clickhouse-driver`, `pandas` |
| `Dockerfile` | Resep pembangun image Airflow lengkap dengan dependensi tambahan |
| `docker-compose.yml` | Orkestrator seluruh service; urutan startup: Postgres → Airflow → ClickHouse → Metabase |
| `fetch_crypto.py` | Mengekstrak 250 coins dari CoinGecko API dan menulisnya sebagai `.json` di `data_lake/` |
| `load_to_clickhouse.py` | Membaca berkas `.json`, menjalankan TRUNCATE, INSERT data baru, kemudian membersihkan berkas mentah |
| `crypto_dag.py` | Definisi DAG Airflow yang mengatur jadwal serta urutan eksekusi task |

> ⚠️ **Catatan arsitektural**  
> Isi `crypto_dag.py` dibatasi pada **kerangka dan jadwal**; logika transformasi data tidak boleh menyusup ke berkas ini.  
> Seluruh logika ETL ditempatkan secara eksklusif pada `dags/scripts/` untuk menjaga separation of concerns.

---

### Step 3 — Eksekusi Docker

Tahap berikut adalah pembangunan image. Sebelum perintah dijalankan, Docker Desktop harus berada dalam keadaan aktif.

```bash
docker-compose build
```

Setelah image berhasil dibangun, jalankan service inisialisasi untuk menyiapkan skema database Airflow.

```bash
docker-compose up airflow-init
```

Apabila proses inisialisasi telah rampung, seluruh service dapat diangkat secara serempak dalam mode detached.

```bash
docker-compose up -d
```

> Berikan jeda sekitar 1–2 menit untuk seluruh container menyelesaikan booting, kemudian akses **http://localhost:8080**

---

### Step 4 — Aktivasi Pipeline pada Airflow

1. Buka **http://localhost:8080** dan lakukan otentikasi dengan kredensial `admin` / `admin`
2. Identifikasi DAG bernama **`crypto_realtime_pipeline`**, kemudian aktifkan dengan menggeser sakelar pada baris DAG tersebut
3. Untuk memicu eksekusi seketika tanpa menunggu jadwal berikutnya, tekan tombol ▶️ **Trigger DAG**

**Skema kerja yang berjalan di balik layar:**

```
[Trigger]
    ↓
[Task 1: fetch_crypto]  →  CoinGecko API → 250 coins → simpan .json ✅
    ↓
[Task 2: load_to_clickhouse]  →  baca .json → TRUNCATE → INSERT ClickHouse → hapus .json ✅
    ↓
[Menunggu 10 menit berikutnya...]
```

### Step 5 — Validasi Data pada ClickHouse

Tahap validasi diawali dengan identifikasi container ClickHouse yang sedang berjalan.

```bash
docker ps
```

Selanjutnya, masuk ke ClickHouse client melalui `docker exec`. Pastikan nama container disesuaikan dengan keluaran perintah `docker ps`.

```bash
docker exec -it <nama-container-clickhouse> \
  clickhouse-client --user admin --password rahasia
```

Setelah berada di dalam client, lakukan inspeksi awal terhadap database dan struktur tabel.

```sql
SHOW DATABASES;
USE analytics;

DESCRIBE analytics.crypto_prices;
SELECT COUNT(*) FROM analytics.crypto_prices;
```

Sebagai latihan analitik pertama, ambil 10 coin teratas berdasarkan kapitalisasi pasar saat ini.

```sql
SELECT market_cap_rank AS rank, symbol, name,
       ROUND(current_price, 4) AS price_usd,
       ROUND(price_change_pct_24h, 2) AS change_24h_pct,
       ROUND(market_cap / 1e9, 2) AS mcap_miliar_usd
FROM analytics.crypto_prices
ORDER BY market_cap_rank ASC
LIMIT 10;
```

Berikutnya, query untuk mengidentifikasi coin dengan kenaikan tertinggi pada periode 24 jam terakhir.

```sql
SELECT symbol, name,
       ROUND(price_change_pct_24h, 2) AS naik_pct_24h
FROM analytics.crypto_prices
WHERE price_change_pct_24h > 0
ORDER BY price_change_pct_24h DESC
LIMIT 10;
```

Sebagai contoh analisis lanjutan, hitung proporsi dominasi Bitcoin dan Ethereum terhadap total kapitalisasi pasar.

```sql
SELECT symbol,
       ROUND(market_cap / (SELECT SUM(market_cap) FROM crypto_prices) * 100, 2)
       AS dominance_pct
FROM analytics.crypto_prices
WHERE symbol IN ('BTC', 'ETH')
ORDER BY dominance_pct DESC;
```

Setelah eksplorasi dirasa cukup, keluar dari ClickHouse client dengan perintah berikut.

```sql
exit
```

---

### Step 6 — Visualisasi melalui Metabase

1. Akses **http://localhost:3000** dan lengkapi formulir registrasi awal (data dummy diperbolehkan untuk keperluan pelatihan)
2. Pada halaman **Add your data**, pilih ClickHouse sebagai sumber data, kemudian masukkan parameter koneksi berikut:

| Field | Value |
|-------|-------|
| Database type | ClickHouse |
| Display name | Crypto Data Warehouse |
| Host | `clickhouse-server` |
| Port | `8123` |
| Database name | `analytics` |
| Username | `admin` |
| Password | `rahasia` |

3. Pilih menu **+ New → Question**, kemudian pilih tabel **crypto_prices**, dan akhiri dengan klik **Visualize**
4. Tentukan jenis visualisasi yang paling sesuai dengan karakteristik data (Bar Chart, Pie Chart, Line Chart, dan sebagainya)
5. Pilih **+ New → Dashboard**, sertakan beberapa Question yang telah dibuat, lalu susun tata letaknya sesuai kebutuhan analisis
6. Aktifkan **Auto-Refresh: 10 minutes** agar dashboard senantiasa selaras dengan ritme pipeline Airflow

---

### Step 7 — Penutupan Infrastruktur

Apabila seluruh aktivitas eksplorasi telah usai, hentikan semua service dengan satu perintah berikut.

```bash
docker-compose down
```

---

## 🔐 Layanan

| Layanan | URL | Username | Password |
|---------|-----|----------|----------|
| Apache Airflow | http://localhost:8080 | `admin` | `admin` |
| Metabase | http://localhost:3000 | *(buat saat setup)* | — |
| ClickHouse HTTP | http://localhost:8123 | `admin` | `rahasia` |
| ClickHouse TCP | `localhost:9000` | `admin` | `rahasia` |

---

*Dibuat untuk keperluan Pelatihan Data Engineering & Big Data Analytics — Big Data Lab MCI 2026.*
