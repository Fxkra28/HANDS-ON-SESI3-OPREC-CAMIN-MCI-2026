-- Kumpulan query untuk dashboard Metabase.
-- Cara pakai: salin tiap query ke Metabase → New → Question → SQL Editor.


-- Q1. Top 10 coin berdasarkan market cap.
-- Visualisasi: Horizontal Bar Chart (X: market_cap_miliar_usd, Y: name).
SELECT
    name,
    symbol,
    ROUND(market_cap / 1e9, 2) AS market_cap_miliar_usd
FROM crypto_prices
ORDER BY market_cap DESC
LIMIT 10;


-- Q2. Sentimen pasar — naik vs turun.
-- Visualisasi: Pie Chart (group: kategori, value: jumlah_coin).
SELECT
    CASE
        WHEN price_change_pct_24h > 5  THEN 'Naik > 5%'
        WHEN price_change_pct_24h > 0  THEN 'Naik 0-5%'
        WHEN price_change_pct_24h > -5 THEN 'Turun 0-5%'
        ELSE 'Turun > 5%'
    END AS kategori,
    COUNT(*) AS jumlah_coin
FROM crypto_prices
GROUP BY kategori
ORDER BY jumlah_coin DESC;


-- Q3. Top gainers 24h.
-- Visualisasi: Bar Chart palet hijau (X: name, Y: naik_pct_24h).
SELECT
    symbol,
    name,
    ROUND(price_change_pct_24h, 2) AS naik_pct_24h,
    ROUND(current_price, 4)        AS harga_sekarang
FROM crypto_prices
WHERE price_change_pct_24h > 0
ORDER BY price_change_pct_24h DESC
LIMIT 10;


-- Q4. Top losers 24h.
-- Visualisasi: Bar Chart palet merah (X: name, Y: turun_pct_24h).
SELECT
    symbol,
    name,
    ROUND(price_change_pct_24h, 2) AS turun_pct_24h,
    ROUND(current_price, 4)        AS harga_sekarang
FROM crypto_prices
WHERE price_change_pct_24h < 0
ORDER BY price_change_pct_24h ASC
LIMIT 10;


-- Q5. Volume leaders.
-- Visualisasi: Horizontal Bar Chart.
-- Memetakan coin yang paling aktif diperdagangkan dalam 24 jam.
SELECT
    symbol,
    name,
    ROUND(total_volume / 1e6, 1)    AS volume_24h_juta_usd,
    ROUND(market_cap / 1e9, 2)      AS market_cap_miliar_usd,
    ROUND(total_volume / market_cap * 100, 2) AS volume_ratio_pct
FROM crypto_prices
WHERE market_cap > 0
ORDER BY total_volume DESC
LIMIT 15;


-- Q6. Volatilitas Top 50.
-- Visualisasi: Bar Chart.
-- Menampilkan coin paling volatile pada hari berjalan.
SELECT
    symbol,
    name,
    ROUND((high_24h - low_24h) / low_24h * 100, 2) AS volatilitas_pct,
    ROUND(high_24h, 4) AS high,
    ROUND(low_24h, 4)  AS low
FROM crypto_prices
WHERE low_24h > 0
  AND market_cap_rank <= 50
ORDER BY volatilitas_pct DESC
LIMIT 15;


-- Q7. Jarak dari ATH.
-- Visualisasi: Bar Chart.
-- Menggambarkan seberapa jauh harga saat ini dari rekor tertingginya.
SELECT
    symbol,
    name,
    ROUND(current_price, 4)  AS harga_sekarang,
    ROUND(ath, 4)            AS all_time_high,
    ROUND(ath_change_pct, 2) AS jarak_dari_ath_pct
FROM crypto_prices
WHERE market_cap_rank <= 20
ORDER BY market_cap_rank ASC;


-- Q8. Metrik ringkas untuk metric cards di dashboard.
-- Setiap query di bawah dimaksudkan untuk satu metric card terpisah.

-- Total coin yang dipantau saat ini
SELECT COUNT(*) AS total_coins FROM crypto_prices;

-- Total market cap seluruh coin
SELECT
    CONCAT('$', toString(ROUND(SUM(market_cap) / 1e12, 2)), 'T')
    AS total_market_cap
FROM crypto_prices;

-- Jumlah coin yang menguat hari ini
SELECT COUNT(*) AS coins_naik
FROM crypto_prices
WHERE price_change_pct_24h > 0;

-- Jumlah coin yang melemah hari ini
SELECT COUNT(*) AS coins_turun
FROM crypto_prices
WHERE price_change_pct_24h < 0;

-- Bitcoin dominance — kontribusi BTC terhadap total kapitalisasi pasar
SELECT
    ROUND(
        MAX(CASE WHEN symbol = 'BTC' THEN market_cap ELSE 0 END)
        / SUM(market_cap) * 100, 1
    ) AS btc_dominance_pct
FROM crypto_prices;
