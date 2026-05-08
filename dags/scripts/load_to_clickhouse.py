"""
Task 2 dari pipeline crypto.

Membaca crypto_raw.json hasil Task 1, melakukan TRUNCATE pada tabel target,
lalu INSERT data terbaru ke ClickHouse melalui clickhouse_driver (TCP port 9000).
"""

import json
import os
from datetime import datetime
from clickhouse_driver import Client

CLICKHOUSE_HOST = "clickhouse-server"
CLICKHOUSE_USER = "admin"
CLICKHOUSE_PASSWORD = "rahasia"

INPUT_FILE = "/opt/airflow/data_lake/crypto/crypto_raw.json"


def load_to_clickhouse():
    print("=" * 60)
    print("🚀 TASK 2: Memuat data crypto ke ClickHouse")
    print("=" * 60)

    # Baca berkas JSON dari data lake
    print(f"📂 Membaca berkas: {INPUT_FILE}")
    if not os.path.exists(INPUT_FILE):
        raise FileNotFoundError(
            f"Berkas tidak ditemukan: {INPUT_FILE}\n"
            "Pastikan Task 1 (fetch_crypto.py) telah berjalan dengan sukses sebelum task ini."
        )

    with open(INPUT_FILE, "r") as f:
        coins = json.load(f)

    print(f"✅ Berhasil memuat {len(coins)} coins dari data lake")

    # Bangun koneksi ke ClickHouse via TCP
    print("🔌 Membangun koneksi ke ClickHouse...")
    client = Client(
        host=CLICKHOUSE_HOST,
        user=CLICKHOUSE_USER,
        password=CLICKHOUSE_PASSWORD
    )
    print("✅ Koneksi terbentuk dengan baik")

    # Pastikan database dan tabel target tersedia (idempotent)
    print("🔧 Memverifikasi keberadaan database 'analytics'...")
    client.execute("CREATE DATABASE IF NOT EXISTS analytics")
    print("✅ Database 'analytics' siap digunakan")

    print("🔧 Menyiapkan tabel crypto_prices...")
    client.execute("""
        CREATE TABLE IF NOT EXISTS analytics.crypto_prices (
            id                   String,
            symbol               String,
            name                 String,
            current_price        Float64,
            market_cap           Float64,
            market_cap_rank      UInt32,
            total_volume         Float64,
            high_24h             Float64,
            low_24h              Float64,
            price_change_24h     Float64,
            price_change_pct_24h Float64,
            price_change_pct_7d  Float64,
            circulating_supply   Float64,
            ath                  Float64,
            ath_change_pct       Float64,
            fetched_at           DateTime
        ) ENGINE = MergeTree()
        ORDER BY (fetched_at, market_cap_rank)
    """)
    print("✅ Tabel crypto_prices siap menerima data")

    # Pola TRUNCATE-INSERT: kosongkan tabel lebih dahulu, lalu sisipkan data terbaru.
    # Hasilnya tabel selalu mencerminkan snapshot teranyar.
    print("🗑️  Menjalankan TRUNCATE pada tabel...")
    count_before = client.execute("SELECT COUNT(*) FROM analytics.crypto_prices")[0][0]
    print(f"   Jumlah baris sebelum truncate: {count_before}")
    client.execute("TRUNCATE TABLE analytics.crypto_prices")
    print("✅ Tabel berhasil dikosongkan")

    # Kemas data menjadi list of tuples agar kompatibel dengan clickhouse_driver
    print(f"📥 Menyisipkan {len(coins)} baris ke ClickHouse...")
    data_tuples = []
    for c in coins:
        data_tuples.append((
            str(c["id"]),
            str(c["symbol"]),
            str(c["name"]),
            float(c["current_price"]),
            float(c["market_cap"]),
            int(c["market_cap_rank"]),
            float(c["total_volume"]),
            float(c["high_24h"]),
            float(c["low_24h"]),
            float(c["price_change_24h"]),
            float(c["price_change_pct_24h"]),
            float(c["price_change_pct_7d"]),
            float(c["circulating_supply"]),
            float(c["ath"]),
            float(c["ath_change_pct"]),
            datetime.strptime(c["fetched_at"], "%Y-%m-%d %H:%M:%S")
        ))

    if data_tuples:
        client.execute(
            "INSERT INTO analytics.crypto_prices VALUES",
            data_tuples
        )

    count_after = client.execute("SELECT COUNT(*) FROM analytics.crypto_prices")[0][0]
    print(f"✅ INSERT selesai. Total baris saat ini: {count_after}")

    # Hapus berkas sementara. Pakai try/except untuk menghindari race condition (TOCTOU)
    # — berkas bisa saja sudah hilang antara pemeriksaan dan penghapusan.
    print(f"🗑️  Menghapus berkas sementara: {INPUT_FILE}")
    try:
        os.remove(INPUT_FILE)
        print("✅ Berkas sementara berhasil dihapus")
    except FileNotFoundError:
        print("⚠️  Berkas sudah tidak tersedia; proses penghapusan dilewati")

    # Pratinjau Top 5 sebagai validasi akhir
    print("\n📋 Pratinjau Top 5 coins yang baru dimuat:")
    results = client.execute("""
        SELECT market_cap_rank, symbol, current_price,
               price_change_pct_24h, market_cap
        FROM analytics.crypto_prices
        ORDER BY market_cap_rank ASC
        LIMIT 5
    """)
    for rank, sym, price, chg, mcap in results:
        print(f"  {rank:3}. {sym:8} "
              f"${price:>12,.4f}  "
              f"24h: {chg:+.2f}%  "
              f"MCap: ${mcap:>15,.0f}")

    print("\n" + "=" * 60)
    print(f"✅ TASK 2 SELESAI — {count_after} coins tersimpan rapi di ClickHouse")
    print("=" * 60)


if __name__ == "__main__":
    # Untuk pengujian langsung tanpa Airflow
    load_to_clickhouse()
