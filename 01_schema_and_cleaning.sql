

-- -------------------------------------------------
-- 1. TABEL UTAMA (hasil import dari CSV Kaggle)
-- -------------------------------------------------
-- Asumsi kolom sumber dari dataset Kaggle:
-- Ticker, Sector, Date, Open, High, Low, Close, Adj_Close, Volume
--
-- Tabel stock_prices_raw dibuat lewat proses import CSV
-- (pandas to_sql / DB Browser for SQLite / BULK INSERT, dst).
-- Di bawah ini skema referensinya jika ingin membuat manual:

DROP TABLE IF EXISTS stock_prices_raw;
CREATE TABLE stock_prices_raw (
    Ticker      TEXT,
    Sector      TEXT,
    Date        TEXT,     -- disimpan sbg TEXT saat import, dikonversi di staging
    Open        REAL,
    High        REAL,
    Low         REAL,
    Close       REAL,
    Adj_Close   REAL,
    Volume      INTEGER
);

-- -------------------------------------------------
-- 2. DATA QUALITY CHECK
-- -------------------------------------------------

-- 2a. Cek duplikat (ticker + tanggal seharusnya unik)
SELECT Ticker, Date, COUNT(*) AS jumlah
FROM stock_prices_raw
GROUP BY Ticker, Date
HAVING COUNT(*) > 1;

-- 2b. Cek missing value di kolom penting
SELECT
    SUM(CASE WHEN Ticker IS NULL THEN 1 ELSE 0 END)      AS null_ticker,
    SUM(CASE WHEN Date IS NULL THEN 1 ELSE 0 END)        AS null_date,
    SUM(CASE WHEN Close IS NULL THEN 1 ELSE 0 END)       AS null_close,
    SUM(CASE WHEN Volume IS NULL THEN 1 ELSE 0 END)      AS null_volume
FROM stock_prices_raw;

-- 2c. Cek harga tidak logis (High < Low, harga negatif, dst)
SELECT *
FROM stock_prices_raw
WHERE High < Low
   OR Open <= 0 OR High <= 0 OR Low <= 0 OR Close <= 0
   OR Volume < 0;

-- 2d. Cek rentang tanggal & jumlah hari trading per ticker
SELECT Ticker, MIN(Date) AS tanggal_awal, MAX(Date) AS tanggal_akhir,
       COUNT(*) AS jumlah_hari_trading
FROM stock_prices_raw
GROUP BY Ticker
ORDER BY Ticker;

-- -------------------------------------------------
-- 3. STAGING TABLE (data bersih & tipe data benar)
-- -------------------------------------------------
DROP TABLE IF EXISTS stock_prices;
CREATE TABLE stock_prices AS
SELECT
    TRIM(Ticker)                    AS ticker,
    TRIM(Sector)                    AS sector,
    DATE(Date)                      AS trade_date,
    ROUND(Open, 2)                  AS open,
    ROUND(High, 2)                  AS high,
    ROUND(Low, 2)                   AS low,
    ROUND(Close, 2)                 AS close,
    ROUND(Adj_Close, 2)             AS adj_close,
    CAST(Volume AS INTEGER)         AS volume
FROM stock_prices_raw
WHERE Ticker IS NOT NULL
  AND Date IS NOT NULL
  AND Close IS NOT NULL
  AND High >= Low                       -- buang baris harga tidak logis
  AND Open > 0 AND Close > 0;

-- Index untuk mempercepat query window function per ticker
CREATE INDEX idx_stock_prices_ticker_date ON stock_prices (ticker, trade_date);

-- Validasi akhir: jumlah baris sebelum vs sesudah cleaning
SELECT
    (SELECT COUNT(*) FROM stock_prices_raw) AS baris_sebelum,
    (SELECT COUNT(*) FROM stock_prices)     AS baris_sesudah;

