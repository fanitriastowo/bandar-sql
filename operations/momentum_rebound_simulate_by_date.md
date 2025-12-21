# Momentum Rebound Simulation by Date

## Overview

`momentum_rebound_simulate_by_date.sql` is a **backtesting and validation query** for the momentum rebound trading strategy. Unlike live screening queries that operate on the latest market data, this query tests the strategy against historical data for a **specific target date**, providing detailed criterion-by-criterion analysis for each candidate stock.

**Use Cases:**
- Validate strategy performance on past trading days
- Tune strategy parameters (thresholds, weights)
- Understand why specific stocks triggered signals
- Train traders on pattern recognition
- Measure historical accuracy and win rates

---

## Query Architecture

The query uses **8 Common Table Expressions (CTEs)** that progressively build analysis layers:

### CTE 1: `simulation_date` (line 7-9)
Stores the target backtest date as a single value.
```sql
SELECT '2025-11-25'::DATE AS target_date
```
**Why:** Allows parameterization—change one date to simulate different trading days.

### CTE 2: `daily_snapshots` (lines 12-37)
Extracts end-of-day snapshots for all trading days **up to and including** the simulation date.
- Gets latest snapshot per stock per day using `DISTINCT ON (security_code, data_date)`
- Ensures data quality: NOT NULL checks on price and volume
- Filters: `data_date <= target_date`

**Output:** Historical daily OHLC snapshots for trend analysis and volume averaging.

### CTE 3: `previous_day_data` (lines 40-53)
Retrieves the day **immediately before** the simulation date.
- Extracts: previous_low, prev_volume
- Used for: Support level confirmation (criterion 5)

**Output:** Support reference point for current day's low.

### CTE 4: `avg_volume_20d` (lines 56-69)
Calculates average volume across trading days **before** the simulation date.
- Minimum threshold: 6 trading days (relaxed from 20 for historical data)
- Excludes target date to prevent lookahead bias
- Groups by stock code

**Output:** 20-day rolling volume for surge detection (criteria 3, 8).

### CTE 5: `latest_snapshot` (lines 72-93)
Gets intraday snapshots for **exactly the simulation date** only.
- Latest timestamp per stock on that trading day
- Contains: OHLC prices, volume, trade value, timestamp

**Output:** The "test day" data for criterion evaluation.

### CTE 6: `orderbook_snapshot` (lines 96-110)
Extracts latest orderbook from the simulation date.
- Aggregates volumes by side: 'B' (Bid/Buy) and 'O' (Offer/Sell)
- Gets best price (level 1) for each side
- Filters to simulation date only

**Output:** Buy/sell volumes and best bid/ask prices.

### CTE 7: `buy_sell_analysis` (lines 113-126)
Calculates buy/sell volume ratios and matches bid/ask sides.
- Uses FULL OUTER JOIN to handle cases where one side is missing
- Computes: `buy_sell_ratio = buy_volume / sell_volume`
- Safe handling: Defaults to 0 if side is missing

**Output:** Balanced buy/sell metrics for microstructure criteria (6, 7, 10).

### CTE 8: `candle_analysis` (lines 129-241)
The core logic layer—combines all sources and calculates **all 10 criteria + supporting metrics**.

**Data Integration:**
- `latest_snapshot` → Current day OHLC
- `previous_day_data` → Support levels
- `avg_volume_20d` → Volume averages
- `buy_sell_analysis` → Market microstructure

**Calculated Metrics:**
- `price_to_open_ratio` = Current Price ÷ Opening Price
- `lower_shadow_ratio` = (Close - Low) ÷ (High - Low)
- `volume_to_avg_ratio` = Today's Volume ÷ 20-day Average
- `low_to_prev_low_ratio` = Today's Low ÷ Previous Low
- `price_change_pct` = ((Current - Previous) ÷ Previous) × 100

**Output:** All criteria flags and supporting metrics for final report.

---

## 10 Evaluation Criteria

### Original Criteria (1-5): Price Action & Volume

#### **Criterion 1: Price Down ≥ 3% from Opening**
**Formula:** `current_price <= 0.97 * opening_price`

**Signal:** Intraday selling pressure (bearish candle).
**Interpretation:** Price has declined from open, showing initial selling interest.
**Why:** Momentum rebound seeks reversal after intraday weakness.
**Example:** Opens at 3960, closes at 3884 (≤ 3960 × 0.97 = 3841.20) ✗ (not down enough)

---

#### **Criterion 2: Long Lower Shadow (Rebound Signal)**
**Formula:** `(current_price - lowest) >= 0.6 × (highest - lowest) AND current > lowest`

**Signal:** Strong intraday rebound from the day's low.
**Interpretation:** Close is in upper 40% of candle range (measured from low).
**Why:** Shows buyers defending the low price; reversal is in progress.
**Example:** High=4000, Low=3410, Close=3884
- Candle range = 590, Lower shadow = 474
- Ratio = 474/590 = 0.80 ✓ (exceeds 0.60 threshold)

---

#### **Criterion 3: Volume Surge (≥ 1.5× average)**
**Formula:** `trade_volume >= 1.5 * avg_volume_20d`

**Signal:** Abnormal trading activity (accumulation/interest).
**Interpretation:** 50%+ above average volume indicates institutional activity.
**Why:** Validates that buying interest is backed by volume.
**Example:** Today=388M shares, Average=250M shares
- Ratio = 388/250 = 1.55 ✓ (meets 1.5× threshold)

---

#### **Criterion 4: Liquidity Check (≥ Rp 5 billion)**
**Formula:** `trade_value >= 5000000000`

**Signal:** Stock is highly liquid (easy to enter/exit).
**Interpretation:** Trade value exceeds Rp 5B = large, established company.
**Why:** Avoids thin, low-volume stocks prone to slippage and manipulation.
**Example:** BBRI trade value = Rp 1.5 trillion ✓ (exceeds Rp 5B by large margin)

---

#### **Criterion 5: Low Near Previous Support (≤ 1.02 × previous low)**
**Formula:** `lowest_price <= 1.02 * previous_low`

**Signal:** Support level is holding (within 2% margin).
**Interpretation:** Today's low hasn't broken yesterday's low—support intact.
**Why:** Confirms reversal at established support, not a breakdown.
**Example:** Yesterday's low=3450, Today's low=3410
- Ratio = 3410/3450 = 0.988 ✓ (below 1.02 threshold)

---

### Extended Criteria (6-10): Market Microstructure

#### **Criterion 6: Dominant Buy Pressure (BuyVol > SellVol)**
**Formula:** `buy_volume > sell_volume`

**Signal:** Buyer interest exceeds seller pressure.
**Interpretation:** More shares bid for than offered in orderbook.
**Why:** Validates bullish sentiment at order book level (microstructure).
**Example:** Buy volume = 50M shares, Sell volume = 35M shares ✓

---

#### **Criterion 7: Strong Buy/Sell Ratio (≥ 1.5)**
**Formula:** `buy_sell_ratio >= 1.5` (where ratio = buy_volume / sell_volume)

**Signal:** 50%+ more buying interest than selling pressure.
**Interpretation:** Ratio of 1.5 means 1.5 buy orders for every sell order.
**Why:** More stringent than criterion 6; stronger bullish commitment.
**Example:** Buy = 50M, Sell = 30M
- Ratio = 50/30 = 1.67 ✓ (exceeds 1.5 threshold)

---

#### **Criterion 8: Volume Not Overheated (TodayVolume < Avg20 × 3)**
**Formula:** `trade_volume < avg_volume_20d * 3`

**Signal:** Volume is elevated but not exhaustion-level.
**Interpretation:** Today's volume < 3× average = normal activity range.
**Why:** Filters out panic spikes and capitulation moves that reverse quickly.
**Example:** Today = 388M, Average = 250M
- Check: 388 < (250 × 3 = 750) ✓ (not overheated)

---

#### **Criterion 9: Price Strengthening (> 3% from previous close)**
**Formula:** `current_price > previous_price * 1.03`

**Signal:** Intraday close is 3%+ above previous day's close.
**Interpretation:** Day-over-day momentum building (not just intraday volatility).
**Why:** Confirms sustained buying interest across two trading days.
**Example:** Previous close = 4115, Current close = 3884
- Change = (3884 - 4115) / 4115 = -5.6% ✗ (price declining, not strengthening)

---

#### **Criterion 10: Bid > Ask at Best Price (Extreme Demand)**
**Formula:** `best_bid > best_ask` (where bid = level 1 buy, ask = level 1 sell)

**Signal:** Abnormal market condition—bid exceeds ask.
**Interpretation:** Extreme buying pressure overcoming normal bid-ask spread.
**Why:** Rare condition indicating market urgency; strong conviction buying.
**Note:** Normally bid < ask (positive spread). Reversal is extraordinary.

---

## Output Structure

The query returns one row per candidate stock with these column groups:

### Price Data (9 columns)
```
security_code, data_date, data_time
current_price, opening_price, highest_price, lowest_price
previous_low, previous_price
```

### Volume Metrics (4 columns)
```
today_volume, today_value, avg_volume_20d, avg_days_count
```

### Market Microstructure (5 columns)
```
buy_volume, sell_volume, buy_sell_ratio, best_bid, best_ask
```

### Calculated Ratios (5 columns)
```
price_to_open_ratio, lower_shadow_ratio, volume_to_avg_ratio
low_to_prev_low_ratio, price_change_pct
```

### Candle Geometry (2 columns)
```
candle_range, lower_shadow
```

### Criteria Flags (10 columns)
```
"1_Down3%"          "2_LongShadow"      "3_VolSurge"        "3b_VolBelowAvg"    "4_Liquid"
"5_NearSupport"     "6_BuyPressure"     "7_BuySell>=1.5"    "8_NotOverheated"   "9_Price>3%"
"10_BidAboveAsk"
```
Each shows '✓' (pass) or '✗' (fail).

### Scoring (2 columns)
```
original_criteria_met (0-5), total_criteria_met (0-10)
```

---

## Output Interpretation Examples

### Example 1: Strong Setup (9/10 criteria)
```
BBRI | 2025-11-25 16:00 | 3884 | 3960 | 4000 | 3410 | 3450
1_Down3%=✓  2_LongShadow=✓  3_VolSurge=✓  4_Liquid=✓  5_NearSupport=✓
6_BuyPressure=✓  7_BuySell>=1.5=✓  8_NotOverheated=✓  9_Price>3%=✓  10_BidAboveAsk=✗
original_criteria_met=5/5, total_criteria_met=9/10
```
**Interpretation:** Excellent signal. All 5 original criteria passed + 4 of 5 microstructure criteria. Only missing extreme bid-above-ask (rare anyway).

### Example 2: Moderate Setup (6/10 criteria)
```
UNTR | 2025-11-25 15:30 | 27300 | 27800 | 27800 | 27000 | 27300
1_Down3%=✓  2_LongShadow=✓  3_VolSurge=✗  4_Liquid=✓  5_NearSupport=✓
6_BuyPressure=✓  7_BuySell>=1.5=✓  8_NotOverheated=✓  9_Price>3%=✗  10_BidAboveAsk=✗
original_criteria_met=4/5, total_criteria_met=6/10
```
**Interpretation:** Decent signal. Core setup (shadow + support + liquidity) passes, but volume not surging. Day-over-day momentum weak.

### Example 3: Poor Setup (2/10 criteria)
```
SMGR | 2025-11-25 14:00 | 2595 | 2605 | 2605 | 2550 | 2620
1_Down3%=✗  2_LongShadow=✓  3_VolSurge=✗  4_Liquid=✓  5_NearSupport=✗
6_BuyPressure=✗  7_BuySell>=1.5=✗  8_NotOverheated=✓  9_Price>3%=✗  10_BidAboveAsk=✗
original_criteria_met=1/5, total_criteria_met=2/10
```
**Interpretation:** Fails most criteria. Would be filtered out by WHERE clause anyway.

---

## Filtering & Sorting

### Minimum Requirements (WHERE clause)
```sql
WHERE has_long_lower_shadow = true AND is_liquid = true
```
**Only shows stocks with BOTH:**
- Long lower shadow (rebound signal)
- Rp 5B+ trade value (liquid)

### Sort Order
1. **Primary:** `total_criteria_met DESC` — Best signals first (10 down to 0)
2. **Secondary:** `trade_value DESC` — Highest trade value breaks ties

---

## How to Use for Backtesting

### 1. Test a Specific Date
Edit line 8:
```sql
SELECT '2025-11-21'::DATE AS target_date  -- Change to any trading date
```

### 2. Run the Query
```bash
psql -U username -d database -f momentum_rebound_simulate_by_date.sql
```

### 3. Analyze Results
- **High scores (8-10):** Strong setups—why did they succeed/fail?
- **Mid scores (5-7):** Marginal setups—identify weak criteria
- **Low scores (2-4):** Would be filtered anyway

### 4. Compare with Price Action
- Did high-scoring stocks actually rally the next day?
- Which criteria best predicted winners?
- Were losers identifiable by missing criteria?

### 5. Refine Parameters
- Increase volume surge: 1.5× → 2.0×
- Tighten support: 1.02× → 1.01×
- Require price strengthening as minimum
- Test different buy/sell thresholds

---

## Data Sources & Dependencies

| Data Source | Table | Used For |
|-------------|-------|----------|
| Current Day | `stock_summary` | OHLC, volume, prices (criteria 1-5) |
| Historical | `stock_summary` | Previous day low, close (criteria 5,9) |
| Rolling Avg | `stock_summary` | 20-day volume average (criteria 3,8) |
| Order Book | `orderbook` | Buy/sell volumes, bid/ask (criteria 6,7,10) |

---

## Quick Reference Table

| # | Name | Threshold | Type | Data Source |
|---|------|-----------|------|-------------|
| 1 | Down 3% | ≤ 0.97 × Open | Price | stock_summary |
| 2 | Long Shadow | ≥ 60% range | Price | stock_summary |
| 3 | Vol Surge | ≥ 1.5× avg | Volume | stock_summary |
| 4 | Liquidity | ≥ Rp 5B | Liquidity | stock_summary |
| 5 | Support | ≤ 1.02× prev | Support | stock_summary |
| 6 | Buy>Sell | buy > sell | Microstructure | orderbook |
| 7 | Buy/Sell | ≥ 1.5 ratio | Microstructure | orderbook |
| 8 | Not OHeat | < 3× avg | Volume | stock_summary |
| 9 | Price+3% | > prev × 1.03 | Price | stock_summary |
| 10 | Bid>Ask | bid > ask | Microstructure | orderbook |
