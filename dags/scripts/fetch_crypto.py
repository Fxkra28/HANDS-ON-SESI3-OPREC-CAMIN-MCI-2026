"""
Task 1 dari pipeline crypto.

Mengambil data top 250 coin dari CoinGecko, melakukan null-handling,
lalu menyimpannya sebagai JSON di data_lake/crypto/.
CoinGecko public API dipakai langsung tanpa perlu API key.
"""

import requests
import json
import os
from datetime import datetime

API_URL = "https://api.coingecko.com/api/v3/coins/markets"
OUTPUT_DIR = "/opt/airflow/data_lake/crypto"
OUTPUT_FILE = f"{OUTPUT_DIR}/crypto_raw.json"

PARAMS = {
    "vs_currency"           : "usd",
    "order"                 : "market_cap_desc",
    "per_page"              : 250,
    "page"                  : 1,
    "sparkline"             : False,
    "price_change_percentage": "24h,7d"
}


def fetch_crypto():
    print("=" * 60)
    print("🚀 TASK 1: Mengambil data crypto dari CoinGecko")
    print("=" * 60)

    # Pastikan folder output sudah tersedia
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"📁 Folder output: {OUTPUT_DIR}")

    # Panggil API CoinGecko
    print(f"🌐 Memanggil endpoint: {API_URL}")
    print(f"📊 Mengambil top {PARAMS['per_page']} coins...")

    response = requests.get(API_URL, params=PARAMS, timeout=30)

    if response.status_code != 200:
        raise Exception(
            f"Permintaan API gagal. Status code: {response.status_code}\n"
            f"Response: {response.text[:200]}"
        )

    raw_data = response.json()
    print(f"✅ Berhasil mengambil {len(raw_data)} coins dari API")

    # Bersihkan data: setiap field yang berpotensi null diberi nilai default
    # supaya aman ketika diinsert ke ClickHouse.
    print("🧹 Melakukan pembersihan data dan menormalisasi nilai null...")
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

    cleaned = []
    for coin in raw_data:
        cleaned.append({
            "id"                    : coin.get("id", "unknown"),
            "symbol"                : coin.get("symbol", "").upper(),
            "name"                  : coin.get("name", "unknown"),
            "current_price"         : coin.get("current_price") or 0.0,
            "market_cap"            : coin.get("market_cap") or 0.0,
            "market_cap_rank"       : coin.get("market_cap_rank") or 0,
            "total_volume"          : coin.get("total_volume") or 0.0,
            "high_24h"              : coin.get("high_24h") or 0.0,
            "low_24h"               : coin.get("low_24h") or 0.0,
            "price_change_24h"      : coin.get("price_change_24h") or 0.0,
            "price_change_pct_24h"  : coin.get("price_change_percentage_24h") or 0.0,
            "price_change_pct_7d"   : coin.get("price_change_percentage_7d_in_currency") or 0.0,
            "circulating_supply"    : coin.get("circulating_supply") or 0.0,
            "ath"                   : coin.get("ath") or 0.0,
            "ath_change_pct"        : coin.get("ath_change_percentage") or 0.0,
            "fetched_at"            : timestamp
        })

    print(f"✅ {len(cleaned)} coins telah dinormalisasi dengan sukses")

    # Simpan ke data lake
    print(f"💾 Menyimpan hasil ke {OUTPUT_FILE}...")
    with open(OUTPUT_FILE, "w") as f:
        json.dump(cleaned, f, indent=2)

    size_kb = os.path.getsize(OUTPUT_FILE) / 1024
    print(f"✅ Berkas tersimpan. Ukuran: {size_kb:.1f} KB")

    # Pratinjau tiga data teratas sebagai sanity check
    print("\n📋 Pratinjau 3 data teratas:")
    for coin in cleaned[:3]:
        print(f"  {coin['market_cap_rank']:3}. {coin['symbol']:8} "
              f"${coin['current_price']:>12,.4f}  "
              f"MCap: ${coin['market_cap']:>15,.0f}  "
              f"24h: {coin['price_change_pct_24h']:+.2f}%")

    print("\n" + "=" * 60)
    print(f"✅ TASK 1 SELESAI — {len(cleaned)} coins berhasil tersimpan di data lake")
    print("=" * 60)


if __name__ == "__main__":
    # Untuk pengujian langsung tanpa Airflow
    fetch_crypto()
