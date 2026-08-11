


-- =========================================================
-- QUERY 1: DAILY RETURN per ticker
-- Business question: seberapa besar pergerakan harian tiap saham?
-- =========================================================
DROP VIEW IF EXISTS v_daily_returns;
CREATE VIEW v_daily_returns AS
SELECT
    ticker,
    sector,
    trade_date,
    close,
    volume,
    LAG(close) OVER (PARTITION BY ticker ORDER BY trade_date) AS prev_close,
    ROUND(
        (close - LAG(close) OVER (PARTITION BY ticker ORDER BY trade_date))
        / LAG(close) OVER (PARTITION BY ticker ORDER BY trade_date) * 100
    , 4) AS daily_return_pct
FROM stock_prices;


-- =========================================================
-- QUERY 2: MOVING AVERAGE 20 & 50 hari
-- Business question: bagaimana tren harga jangka pendek vs menengah?
-- =========================================================
DROP VIEW IF EXISTS v_moving_averages;
CREATE VIEW v_moving_averages AS
SELECT
    ticker,
    trade_date,
    close,
    ROUND(AVG(close) OVER (
        PARTITION BY ticker ORDER BY trade_date
        ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
    ), 2) AS ma_20,
    ROUND(AVG(close) OVER (
        PARTITION BY ticker ORDER BY trade_date
        ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
    ), 2) AS ma_50
FROM stock_prices;

-- Sinyal golden cross / death cross sederhana (MA20 memotong MA50)
SELECT
    ticker, trade_date, close, ma_20, ma_50,
    CASE
        WHEN ma_20 > ma_50 THEN 'Bullish (MA20 > MA50)'
        WHEN ma_20 < ma_50 THEN 'Bearish (MA20 < MA50)'
        ELSE 'Netral'
    END AS sinyal_tren
FROM v_moving_averages
WHERE ma_50 IS NOT NULL
ORDER BY ticker, trade_date DESC;


-- =========================================================
-- QUERY 3: VOLATILITY (standar deviasi return) per ticker per bulan
-- Business question: saham mana yang paling fluktuatif / paling stabil?
-- =========================================================
DROP VIEW IF EXISTS v_monthly_volatility;
CREATE VIEW v_monthly_volatility AS
SELECT
    ticker,
    sector,
    strftime('%Y-%m', trade_date) AS bulan,
    COUNT(*)                       AS jumlah_hari,
    ROUND(AVG(daily_return_pct), 4)   AS rata2_return_pct,
    ROUND(
        SQRT(
            AVG(daily_return_pct * daily_return_pct) - AVG(daily_return_pct) * AVG(daily_return_pct)
        )
    , 4) AS volatilitas_pct   -- population stdev return harian dalam bulan tsb
FROM v_daily_returns
WHERE daily_return_pct IS NOT NULL
GROUP BY ticker, sector, strftime('%Y-%m', trade_date);

-- Ranking ticker paling volatile (rata-rata seluruh periode)
SELECT
    ticker, sector,
    ROUND(AVG(volatilitas_pct), 4) AS avg_volatility_pct,
    RANK() OVER (ORDER BY AVG(volatilitas_pct) DESC) AS ranking_volatilitas
FROM v_monthly_volatility
GROUP BY ticker, sector
ORDER BY avg_volatility_pct DESC;


-- =========================================================
-- QUERY 4: MAX DRAWDOWN per ticker
-- Business question: penurunan terburuk dari titik puncak (peak-to-trough)?
-- =========================================================
DROP VIEW IF EXISTS v_drawdown;
CREATE VIEW v_drawdown AS
WITH running_peak AS (
    SELECT
        ticker,
        trade_date,
        close,
        MAX(close) OVER (
            PARTITION BY ticker ORDER BY trade_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS peak_so_far
    FROM stock_prices
)
SELECT
    ticker,
    trade_date,
    close,
    peak_so_far,
    ROUND((close - peak_so_far) / peak_so_far * 100, 4) AS drawdown_pct
FROM running_peak;

-- Max drawdown (titik terburuk) per ticker
SELECT
    ticker,
    MIN(drawdown_pct) AS max_drawdown_pct,
    trade_date         AS tanggal_titik_terendah
FROM v_drawdown
GROUP BY ticker
HAVING drawdown_pct = MIN(drawdown_pct)
ORDER BY max_drawdown_pct ASC;


-- =========================================================
-- QUERY 5: MONTHLY RETURN & RANKING per kuartal
-- Business question: ticker mana yang paling untung/rugi tiap kuartal?
-- =========================================================
DROP VIEW IF EXISTS v_quarterly_return;
CREATE VIEW v_quarterly_return AS
WITH monthly_close AS (
    SELECT
        ticker,
        sector,
        strftime('%Y', trade_date) || '-Q' ||
            ((CAST(strftime('%m', trade_date) AS INTEGER) - 1) / 3 + 1) AS kuartal,
        trade_date,
        close,
        ROW_NUMBER() OVER (
            PARTITION BY ticker, strftime('%Y', trade_date) || '-Q' ||
                ((CAST(strftime('%m', trade_date) AS INTEGER) - 1) / 3 + 1)
            ORDER BY trade_date ASC
        ) AS rn_first,
        ROW_NUMBER() OVER (
            PARTITION BY ticker, strftime('%Y', trade_date) || '-Q' ||
                ((CAST(strftime('%m', trade_date) AS INTEGER) - 1) / 3 + 1)
            ORDER BY trade_date DESC
        ) AS rn_last
    FROM stock_prices
)
SELECT
    a.ticker,
    a.sector,
    a.kuartal,
    a.close AS harga_awal_kuartal,
    b.close AS harga_akhir_kuartal,
    ROUND((b.close - a.close) / a.close * 100, 2) AS return_kuartal_pct
FROM monthly_close a
JOIN monthly_close b
    ON a.ticker = b.ticker AND a.kuartal = b.kuartal
WHERE a.rn_first = 1 AND b.rn_last = 1;

-- Ranking return kuartal terbaik & terburuk
SELECT
    kuartal, ticker, sector, return_kuartal_pct,
    RANK() OVER (PARTITION BY kuartal ORDER BY return_kuartal_pct DESC) AS ranking_terbaik
FROM v_quarterly_return
ORDER BY kuartal, ranking_terbaik;


-- =========================================================
-- QUERY 6: VOLUME SPIKE DETECTION
-- Business question: kapan terjadi lonjakan volume tidak wajar (potensi berita besar)?
-- =========================================================
WITH volume_stats AS (
    SELECT
        ticker,
        trade_date,
        volume,
        AVG(volume) OVER (
            PARTITION BY ticker ORDER BY trade_date
            ROWS BETWEEN 29 PRECEDING AND 1 PRECEDING
        ) AS avg_volume_30d
    FROM stock_prices
)
SELECT
    ticker, trade_date, volume, ROUND(avg_volume_30d, 0) AS avg_volume_30d,
    ROUND(volume / avg_volume_30d, 2) AS rasio_terhadap_rata2
FROM volume_stats
WHERE avg_volume_30d IS NOT NULL
  AND volume > 2 * avg_volume_30d          -- volume > 2x rata-rata 30 hari
ORDER BY rasio_terhadap_rata2 DESC
LIMIT 20;


-- =========================================================
-- QUERY 7: KORELASI PERGERAKAN ANTAR SEKTOR (ringkasan)
-- Business question: sektor mana yang bergerak searah / berbeda arah?
-- =========================================================
SELECT
    sector,
    strftime('%Y-%m', trade_date) AS bulan,
    ROUND(AVG(daily_return_pct), 4) AS avg_return_pct
FROM v_daily_returns
WHERE daily_return_pct IS NOT NULL
GROUP BY sector, strftime('%Y-%m', trade_date)
ORDER BY bulan, sector;
