-- Panduan eksplorasi data crypto pada ClickHouse.
-- Sumber data: Top 250 cryptocurrency dari CoinGecko.


-- ## Bagian 0 — Navigasi dasar

-- Identifikasi seluruh database yang tersedia
SHOW DATABASES;

-- Masuk ke database analytics
USE analytics;

-- Daftar tabel pada database tersebut
SHOW TABLES;

-- Skema tabel: nama kolom dan tipe datanya
DESCRIBE crypto_prices;

-- Total baris yang sudah dikumpulkan oleh pipeline
SELECT COUNT(*) AS total_rows FROM crypto_prices;

-- Waktu fetch terbaru
SELECT MAX(fetched_at) AS last_updated FROM crypto_prices;

-- Jumlah siklus fetch yang sudah dijalankan sejauh ini
SELECT COUNT(DISTINCT fetched_at) AS total_fetch_cycles
FROM crypto_prices;


-- ## Bagian 1 — Eksplorasi awal data mentah

-- 10 baris pertama berdasarkan ranking market cap (snapshot terbaru)
SELECT
    market_cap_rank AS rank,
    symbol,
    name,
    current_price,
    price_change_pct_24h AS change_24h_pct,
    market_cap
FROM crypto_prices
ORDER BY market_cap_rank ASC
LIMIT 10;

-- Seluruh kolom untuk satu coin tertentu, contoh Bitcoin
SELECT *
FROM crypto_prices
WHERE symbol = 'BTC'
LIMIT 1;

-- Jumlah coin dengan harga di atas $1
SELECT COUNT(*) AS coins_above_1_dollar
FROM crypto_prices
WHERE current_price > 1;

-- Statistik harga: minimum, maksimum, dan rerata
SELECT
    MIN(current_price) AS harga_termurah,
    MAX(current_price) AS harga_termahal,
    AVG(current_price) AS rata_rata_harga
FROM crypto_prices;


-- ## Bagian 2 — Analisis market cap dan dominasi

-- Sepuluh coin teratas berdasarkan kapitalisasi pasar
SELECT
    market_cap_rank AS rank,
    symbol,
    name,
    ROUND(market_cap / 1e9, 2) AS market_cap_miliar_usd
FROM crypto_prices
ORDER BY market_cap DESC
LIMIT 10;

-- Akumulasi total market cap dari seluruh 250 coin
SELECT
    ROUND(SUM(market_cap) / 1e12, 3) AS total_market_cap_triliun_usd
FROM crypto_prices;

-- Dominasi Bitcoin dan Ethereum sebagai proporsi terhadap total market
SELECT
    symbol,
    name,
    ROUND(market_cap / (
        SELECT SUM(market_cap) FROM crypto_prices
    ) * 100, 2) AS market_dominance_pct
FROM crypto_prices
WHERE symbol IN ('BTC', 'ETH')
ORDER BY market_dominance_pct DESC;

-- Komparasi dominasi: kelompok Top 10 versus sisanya (Rank 11–250)
SELECT
    CASE
        WHEN market_cap_rank <= 10 THEN 'Top 10'
        ELSE 'Rank 11-250'
    END AS kategori,
    COUNT(*) AS jumlah_coin,
    ROUND(SUM(market_cap) / 1e9, 1) AS total_mcap_miliar,
    ROUND(SUM(market_cap) / (
        SELECT SUM(market_cap) FROM crypto_prices
    ) * 100, 1) AS dominance_pct
FROM crypto_prices
GROUP BY kategori
ORDER BY total_mcap_miliar DESC;


-- ## Bagian 3 — Perubahan harga (gainers & losers)

-- Sepuluh coin dengan kenaikan tertinggi dalam 24 jam terakhir
SELECT
    market_cap_rank AS rank,
    symbol,
    name,
    ROUND(current_price, 4) AS harga_sekarang,
    ROUND(price_change_pct_24h, 2) AS naik_pct_24h
FROM crypto_prices
WHERE price_change_pct_24h > 0
ORDER BY price_change_pct_24h DESC
LIMIT 10;

-- Sepuluh coin dengan penurunan paling tajam dalam 24 jam
SELECT
    market_cap_rank AS rank,
    symbol,
    name,
    ROUND(current_price, 4) AS harga_sekarang,
    ROUND(price_change_pct_24h, 2) AS turun_pct_24h
FROM crypto_prices
WHERE price_change_pct_24h < 0
ORDER BY price_change_pct_24h ASC
LIMIT 10;

-- Distribusi sentimen pasar: jumlah coin yang naik vs turun, dikategorikan berdasarkan magnitudo
SELECT
    CASE
        WHEN price_change_pct_24h > 5  THEN 'Naik >5%'
        WHEN price_change_pct_24h > 0  THEN 'Naik 0-5%'
        WHEN price_change_pct_24h = 0  THEN 'Flat'
        WHEN price_change_pct_24h > -5 THEN 'Turun 0-5%'
        ELSE 'Turun >5%'
    END AS kategori,
    COUNT(*) AS jumlah_coin
FROM crypto_prices
GROUP BY kategori
ORDER BY jumlah_coin DESC;

-- Komparasi performa horizon 24h vs 7d untuk identifikasi tren.
-- Pola 24h positif disertai 7d negatif lazim dimaknai sebagai sinyal pemulihan.
SELECT
    symbol,
    name,
    ROUND(price_change_pct_24h, 2) AS perubahan_24h_pct,
    ROUND(price_change_pct_7d, 2)  AS perubahan_7d_pct,
    CASE
        WHEN price_change_pct_24h > 0 AND price_change_pct_7d < 0
            THEN 'Pemulihan'
        WHEN price_change_pct_24h > 0 AND price_change_pct_7d > 0
            THEN 'Tren Naik'
        WHEN price_change_pct_24h < 0 AND price_change_pct_7d > 0
            THEN 'Koreksi'
        ELSE 'Tren Turun'
    END AS tren
FROM crypto_prices
ORDER BY market_cap_rank ASC
LIMIT 20;


-- ## Bagian 4 — Volume trading

-- Coin paling aktif diperdagangkan dalam 24 jam terakhir
SELECT
    market_cap_rank AS rank,
    symbol,
    name,
    ROUND(total_volume / 1e6, 1) AS volume_24h_juta_usd
FROM crypto_prices
ORDER BY total_volume DESC
LIMIT 10;

-- Rasio Volume/Market Cap sebagai indikator likuiditas relatif:
-- nilai yang lebih tinggi mengindikasikan aktivitas trading lebih intens dibanding ukuran kapitalisasinya.
SELECT
    symbol,
    name,
    ROUND(current_price, 4) AS harga,
    ROUND(total_volume / market_cap * 100, 2) AS volume_to_mcap_pct
FROM crypto_prices
WHERE market_cap > 0
ORDER BY volume_to_mcap_pct DESC
LIMIT 15;


-- ## Bagian 5 — Volatilitas

-- Volatilitas harian: selisih harga tertinggi dan terendah dalam 24 jam
SELECT
    market_cap_rank AS rank,
    symbol,
    name,
    ROUND(high_24h, 4)  AS high_hari_ini,
    ROUND(low_24h, 4)   AS low_hari_ini,
    ROUND((high_24h - low_24h) / low_24h * 100, 2) AS volatilitas_pct
FROM crypto_prices
WHERE low_24h > 0
ORDER BY volatilitas_pct DESC
LIMIT 15;

-- Coin dengan volatilitas terendah; kategori ini umumnya didominasi oleh stablecoin
SELECT
    symbol,
    name,
    ROUND(current_price, 4) AS harga,
    ROUND((high_24h - low_24h) / low_24h * 100, 4) AS volatilitas_pct
FROM crypto_prices
WHERE low_24h > 0
ORDER BY volatilitas_pct ASC
LIMIT 10;


-- ## Bagian 6 — Jarak dari All-Time High (ATH)

-- Posisi harga saat ini relatif terhadap ATH masing-masing coin
SELECT
    market_cap_rank AS rank,
    symbol,
    name,
    ROUND(current_price, 4) AS harga_sekarang,
    ROUND(ath, 4)           AS all_time_high,
    ROUND(ath_change_pct, 2) AS jarak_dari_ath_pct
FROM crypto_prices
ORDER BY market_cap_rank ASC
LIMIT 15;

-- Coin yang paling dekat dengan ATH-nya — kandidat potensial mencetak ATH baru.
-- Semakin mendekati 0%, semakin dekat ke ATH.
SELECT
    symbol,
    name,
    ROUND(current_price, 4)  AS harga_sekarang,
    ROUND(ath, 4)            AS all_time_high,
    ROUND(ath_change_pct, 2) AS jarak_pct
FROM crypto_prices
WHERE ath > 0
ORDER BY ath_change_pct DESC
LIMIT 10;

-- Coin yang paling jauh dari ATH — kerap dipandang sebagai aset paling "terdiskon".
-- Nilai paling negatif menandakan jarak terjauh dari ATH.
SELECT
    symbol,
    name,
    ROUND(current_price, 4)  AS harga_sekarang,
    ROUND(ath, 4)            AS all_time_high,
    ROUND(ath_change_pct, 2) AS jarak_pct
FROM crypto_prices
WHERE ath > 0 AND market_cap_rank <= 100
ORDER BY ath_change_pct ASC
LIMIT 10;


-- ## Bagian 7 — Time series (akumulasi data)
-- Query di sini mulai bermakna setelah pipeline berjalan beberapa siklus.

-- Tren harga Bitcoin pada setiap titik fetch yang sudah terekam
SELECT
    fetched_at,
    ROUND(current_price, 2) AS harga_btc_usd
FROM crypto_prices
WHERE symbol = 'BTC'
ORDER BY fetched_at ASC;

-- Pergerakan total market cap antar siklus fetch — mencerminkan napas pasar secara agregat
SELECT
    fetched_at,
    ROUND(SUM(market_cap) / 1e12, 3) AS total_mcap_triliun
FROM crypto_prices
GROUP BY fetched_at
ORDER BY fetched_at ASC;

-- Dinamika sentimen pasar lintas waktu: jumlah coin naik vs turun pada setiap siklus
SELECT
    fetched_at,
    COUNT(CASE WHEN price_change_pct_24h > 0 THEN 1 END) AS coin_naik,
    COUNT(CASE WHEN price_change_pct_24h < 0 THEN 1 END) AS coin_turun,
    COUNT(CASE WHEN price_change_pct_24h > 0 THEN 1 END)
        - COUNT(CASE WHEN price_change_pct_24h < 0 THEN 1 END) AS selisih
FROM crypto_prices
GROUP BY fetched_at
ORDER BY fetched_at ASC;


-- ## Bagian 8 — Subquery dan filter kompleks

-- Coin dengan market cap di atas rata-rata populasi
SELECT
    symbol,
    name,
    ROUND(market_cap / 1e9, 2) AS mcap_miliar
FROM crypto_prices
WHERE market_cap > (SELECT AVG(market_cap) FROM crypto_prices)
ORDER BY market_cap DESC;

-- Proporsi coin yang harganya di bawah $1
SELECT
    ROUND(
        COUNT(CASE WHEN current_price < 1 THEN 1 END) * 100.0 / COUNT(*),
        1
    ) AS pct_coin_dibawah_1_dolar
FROM crypto_prices;

-- Coin yang menunjukkan kenaikan konsisten — positif baik pada 24h maupun 7d
SELECT
    market_cap_rank AS rank,
    symbol,
    name,
    ROUND(price_change_pct_24h, 2) AS naik_24h,
    ROUND(price_change_pct_7d, 2)  AS naik_7d
FROM crypto_prices
WHERE price_change_pct_24h > 0
  AND price_change_pct_7d > 0
ORDER BY price_change_pct_24h DESC
LIMIT 15;

-- Untuk keluar dari ClickHouse client: exit
