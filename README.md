# 📈 Stock Market Analysis — End-to-End Data Analyst Portfolio Project

Project analisis pasar saham end-to-end menggunakan **SQL** (data cleaning, window functions, CTE)
dan **Excel** (dashboard interaktif dengan formula & chart) berdasarkan dataset bergaya
[Kaggle Stock Market Dataset](https://www.kaggle.com/datasets/thesnak/stock-market-analysis).

> **Catatan:** data pada `data/stock_market_data.csv` adalah **data simulasi (synthetic)** yang
> meniru struktur & karakteristik dataset Kaggle asli (OHLCV harian, 8 ticker, 1 tahun), dibuat
> agar seluruh pipeline bisa didemokan end-to-end tanpa bergantung pada file eksternal. Untuk
> versi produksi, cukup ganti file CSV ini dengan hasil download dataset asli dari Kaggle —
> struktur kolom (`Ticker, Sector, Date, Open, High, Low, Close, Adj_Close, Volume`) sudah
> disesuaikan agar kompatibel langsung dengan seluruh script SQL & Excel di project ini.

---

## 🎯 Business Questions

1. Ticker/sektor mana yang paling **volatile** vs paling **stabil**?
2. Bagaimana tren **return per kuartal**, dan kapan **drawdown terbesar** terjadi?
3. Sektor mana yang cenderung bergerak **searah/berbeda arah** tiap bulan?
4. Kapan terjadi **lonjakan volume** yang mengindikasikan berita besar / anomali pasar?
5. Ticker mana yang paling **menguntungkan** secara total return selama periode analisis?

## 🧰 Tools

| Tahap | Tools |
|---|---|
| Data cleaning & staging | SQL (SQLite, portable ke PostgreSQL/MySQL) |
| Analisis (window functions, CTE, ranking) | SQL |
| Visualisasi & dashboard | Microsoft Excel (formula, PivotChart-style, conditional formatting) |
| Data generation (dataset simulasi) | Python (pandas, numpy) |

## 📁 Struktur Project

```
stock-portfolio/
├── README.md                          <- dokumentasi ini
├── data/
│   ├── stock_market_data.csv          <- dataset mentah (gaya Kaggle)
│   └── stock_market.db                <- database SQLite hasil load
├── sql/
│   ├── 01_schema_and_cleaning.sql     <- DDL, data quality check, staging table
│   └── 02_analysis_queries.sql        <- window functions: return, MA, volatility,
│                                          drawdown, ranking kuartal, volume spike
└── excel/
    └── stock_market_dashboard.xlsx    <- dashboard end-to-end
        ├── README        (cover & penjelasan)
        ├── Dashboard      (ringkasan visual + 4 chart + key insight cards)
        ├── Raw_Data       (data harian + kolom turunan berbasis formula)
        ├── Ticker_Summary (risk & return per ticker)
        ├── Quarterly_Return (return per kuartal + ranking)
        ├── Sector_Trend   (heatmap return bulanan per sektor)
        └── Volume_Spike   (deteksi anomali volume, hasil query SQL)
```

## 🔍 Alur Analisis (End-to-End)

### 1. Data Cleaning (SQL)
- Import CSV mentah ke tabel `stock_prices_raw`.
- Cek duplikat (`ticker + date`), missing value, dan harga tidak logis (`High < Low`, harga ≤ 0).
- Bangun tabel staging `stock_prices` yang sudah bersih & bertipe data benar, dengan index
  `(ticker, trade_date)` untuk mempercepat query window function.

### 2. Analisis SQL (`sql/02_analysis_queries.sql`)
- **Daily return** per ticker (`LAG()` window function).
- **Moving average 20 & 50 hari** + sinyal tren bullish/bearish sederhana.
- **Volatility bulanan** (standar deviasi return) + ranking ticker paling fluktuatif.
- **Max drawdown** (peak-to-trough) per ticker menggunakan running maximum.
- **Return & ranking per kuartal** menggunakan CTE + `ROW_NUMBER()`.
- **Volume spike detection**: hari dengan volume > 2x rata-rata 30 hari sebelumnya.
- **Tren rata-rata return per sektor** per bulan, untuk melihat korelasi pergerakan antar sektor.

### 3. Dashboard Excel (`excel/stock_market_dashboard.xlsx`)
- Seluruh angka analitik dibangun dengan **formula Excel** (bukan hasil hardcode), sehingga
  workbook otomatis recalculate jika data mentah di sheet `Raw_Data` diubah.
- 4 chart utama: tren harga vs moving average, ranking volatilitas, max drawdown, dan
  perbandingan return per kuartal antar ticker.
- Conditional formatting (color scale) pada return kuartal dan heatmap tren sektor.
- Key insight cards di sheet `Dashboard` otomatis menunjukkan ticker paling volatile/stabil,
  drawdown terdalam, dan return tertinggi menggunakan formula `INDEX/MATCH`.

## 📊 Key Insights (contoh temuan dari data simulasi)

- **TSLA** tercatat sebagai ticker paling volatile (volatilitas harian ± 3,5%) sekaligus
  mengalami max drawdown terdalam (~ -59%) — konsisten dengan karakteristik saham growth stock
  yang sensitif terhadap sentimen pasar.
- **KO** (Consumer Staples) adalah ticker paling stabil, mencerminkan sifat defensif sektor
  consumer staples yang cenderung tidak terlalu terpengaruh siklus pasar.
- **AAPL** mencatatkan total return tertinggi selama periode analisis di antara 8 ticker yang
  diamati.
- Sektor Technology secara umum menunjukkan rata-rata return bulanan yang lebih tinggi
  dibanding sektor defensif (Healthcare, Consumer Staples), namun dengan volatilitas yang
  juga lebih tinggi — trade-off klasik risk vs return.

*(Insight di atas otomatis mengikuti data pada sheet `Raw_Data`. Ganti dengan data riil dari
Kaggle untuk mendapatkan insight yang mencerminkan kondisi pasar sesungguhnya.)*

## ▶️ Cara Menjalankan Ulang Project

1. Download dataset dari Kaggle (atau gunakan `data/stock_market_data.csv` yang sudah tersedia).
2. Load ke SQLite (atau database lain):
   ```bash
   python3 -c "
   import sqlite3, pandas as pd
   df = pd.read_csv('data/stock_market_data.csv')
   conn = sqlite3.connect('data/stock_market.db')
   df.to_sql('stock_prices_raw', conn, if_exists='replace', index=False)
   "
   ```
3. Jalankan `sql/01_schema_and_cleaning.sql` lalu `sql/02_analysis_queries.sql` pada database
   tersebut (bisa via DB Browser for SQLite, DBeaver, atau CLI `sqlite3`).
2. Buka `excel/stock_market_dashboard.xlsx` — update sheet `Raw_Data` dengan data terbaru,
   seluruh formula & chart akan otomatis recalculate.

## 👤 Author

Portfolio project ini dibuat untuk menunjukkan kemampuan end-to-end data analyst:
data cleaning, SQL analytics (window functions & CTE), hingga membangun dashboard Excel
yang siap dipresentasikan ke stakeholder non-teknis.
