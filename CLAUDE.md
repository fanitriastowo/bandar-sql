# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Bandar** is a PostgreSQL-based stock trading strategy screening system for the Indonesian stock exchange (IDX). It uses pure SQL to identify trading opportunities through various technical analysis screeners and momentum indicators.

## Technology Stack

- **PostgreSQL** - Primary database for all market data and analysis
- **SQL** - Pure SQL-based screening and analysis (no application framework)
- **Data Sources**: Intraday and historical OHLC data, trades, and order book snapshots

## Core Database Tables

| Table | Purpose |
|-------|---------|
| `stock_summary` | Intraday stock data with OHLC, volume, and timestamps |
| `history_ohlc` | Historical daily OHLC data for technical analysis |
| `daily_ohlc` | Daily aggregated OHLC data (derived from snapshots) |
| `trades` | Individual trade transaction records |
| `orderbook` | Order book snapshots with bid/ask levels |
| `sideways_state` | Consolidation/sideways market state tracking |

### Table Structure Details

#### `stock_summary` (structures/stock_summary.sql)
Intraday snapshots captured at regular intervals throughout trading day.

| Column | Type | Notes |
|--------|------|-------|
| `data_date` | date | Trading date (format: YYYYMMDD) |
| `data_time` | time | Snapshot time (HHmmss format) |
| `ts` | timestamp | Full timestamp of snapshot |
| `security_code` | text | 4-letter stock ticker (e.g., BBRI, BBCA) |
| `board_code` | text | Market board (typically 'NG' for main board) |
| `opening_price` | numeric | Day's opening price |
| `highest_price` | numeric | Day's highest price so far |
| `lowest_price` | numeric | Day's lowest price so far |
| `close_price` | numeric | Current/snapshot price |
| `trade_volume` | bigint | Cumulative shares traded since market open |
| `trade_value` | bigint | Cumulative trade value in IDR since market open |
| `trade_frequency` | integer | Number of trades executed |
| `previous_price` | numeric | Previous trading day's close price |

**Key Usage**: Latest snapshot per stock retrieved using `DISTINCT ON (security_code) ORDER BY ts DESC`

#### `trades` (structures/trades.sql)
Individual trade transaction detail records.

| Column | Type | Notes |
|--------|------|-------|
| `trade_no` | bigint | Unique trade transaction ID (sequential) |
| `trade_date` | date | Trade execution date (YYYYMMDD format) |
| `trade_time` | time | Trade execution time (HHmmss format) |
| `ts` | timestamp | Full timestamp of trade |
| `security_code` | text | 4-letter stock ticker |
| `board_code` | text | Market board code |
| `price` | numeric | Trade execution price |
| `volume` | bigint | Shares traded in this transaction |

**Key Usage**: Granular transaction-level analysis, trade sequence analysis, volume reconstruction

#### `orderbook` (structures/orderbook.sql)
Order book snapshots showing bid/ask depth at specific moments.

| Column | Type | Notes |
|--------|------|-------|
| `ts` | timestamp | Snapshot timestamp |
| `security_code` | text | 4-letter stock ticker |
| `side` | char(1) | Order side: 'B' = Bid (buy), 'O' = Offer (sell) |
| `level` | integer | Depth level (1-10, where 1 is best bid/ask) |
| `frequency` | integer | Number of orders at this level |
| `price` | numeric | Price at this level |
| `volume` | bigint | Total shares at this price level |

**Key Usage**: Market depth analysis, liquidity assessment, support/resistance level detection

#### `sideways_state` (Created by per_night.sql)
Computed consolidation/sideways pattern detection state (upserted nightly).

| Column | Type | Notes |
|--------|------|-------|
| `symbol` | text | Stock ticker |
| `trade_date` | date | Analysis date |
| `range_ratio` | numeric | Price range over 60 days / lowest price |
| `volume_ratio` | numeric | Today's volume / 60-day avg volume |
| `is_sideways` | boolean | Consolidation flag (range < 5%, vol < 20% avg, value > Rp 1B) |

**Key Usage**: Filtering out low-volatility consolidating stocks from momentum strategies

#### `history_ohlc` & `daily_ohlc` (Referenced but not in structures folder)
Historical daily OHLC data - structure inferred from query usage:

| Column | Type | Notes |
|--------|------|-------|
| `code` / `symbol` | text | Stock ticker |
| `trade_date` / `bucket` | date | Trading date |
| `open` | numeric | Daily open price |
| `high` | numeric | Daily high price |
| `low` | numeric | Daily low price |
| `close` | numeric | Daily close price |
| `volume` | bigint | Daily volume |
| `value` | bigint | Daily trade value in IDR |

**Key Usage**: Rolling window calculations (MA5, MA20), historical comparisons, backtesting

## Directory Structure

- **`structures/`** - Database schema definitions for core tables
- **`operations/`** - Backtesting and simulation scripts
- **Root level SQL files** - Screening queries and analysis scripts organized by strategy type:
  - Momentum rebound strategies (`1.momentum-rebound*.sql`)
  - Daily trading screeners (`2.daily-trading-screener*.sql`)
  - Swing trading screeners (`swing-screening*.sql`)
  - Consolidation detection (`per_night.sql`, `per_7_days_stock_summary.sql`)
  - Utility queries (`ma5_from_history_ohlc.sql`, `count.sql`)

## Primary Screening Strategies

### 1. Momentum Rebound Strategy (`1.momentum-rebound.sql`)
Identifies intraday price rebounds from lows with strong volume signals. Uses 5 criteria:
- Price down ≥3% from open (bearish pressure)
- Long lower shadow (close - low ≥ 60% of candle range)
- Volume surge ≥1.5× 20-day average
- High liquidity (trade value ≥ Rp 5B)
- Support level confirmation (low near previous day's low)

**Key Data Sources**: `stock_summary` (intraday), `history_ohlc` (20-day averages)

### 2. Daily Trading Screener (`2.daily-trading-screener.sql`)
Day-trading strategy based on price-to-MA5 proximity and volume patterns:
- Price above/near 5-day moving average (MA5)
- Green candle with significant up move (≥5%)
- Volume surge with afternoon momentum
- Minimum liquidity threshold (Rp 5B)

**Key Data Sources**: `stock_summary` (intraday snapshots throughout day), `history_ohlc` (MA5)

### 3. Swing Trading Screener (`swing-screening-history-ohlc.sql`)
Mid-term swing opportunities from historical daily data with 7 criteria:
- Minimum liquidity and price thresholds
- Price positioning relative to MA20 (above trend, but not overextended)
- Volume analysis (current vs previous, vs MA20)

**Key Data Sources**: `history_ohlc` (daily 20-day rolling analysis)

### 4. Sideways/Consolidation Detection (`per_night.sql`)
Identifies stocks in low-volatility consolidation patterns:
- Price range < 5% over 60 days
- Volume < 20% of 60-day average
- Minimum value > Rp 1B (liquidity check)
- Results stored in `sideways_state` for tracking

**Key Data Sources**: `daily_ohlc` (daily aggregates), `sideways_state` (persistent state)

## Common Query Patterns

### Multiple Data Source Fallback
Queries use `COALESCE()` to prefer recent intraday data (`stock_summary`) over historical data (`history_ohlc`):
```sql
COALESCE(ss.previous_low, ho.previous_low) AS previous_low
```

### Latest Data Selection
Use `DISTINCT ON` with `ORDER BY` to get latest snapshot per stock (deterministic):
```sql
SELECT DISTINCT ON (security_code)
  ...
ORDER BY security_code, ts DESC
```

### Window Functions for Analysis
- `LAG()` - Previous period comparisons
- `AVG() OVER (RANGE BETWEEN INTERVAL...)` - Rolling window averages
- `MAX/MIN OVER (PARTITION BY ... ORDER BY ...)` - Range calculations

### Boolean Flag Calculation
Create explicit CASE statements for criteria evaluation (aids readability and debugging):
```sql
CASE
  WHEN (close - lowest) / (highest - lowest) >= 0.6 THEN 1
  ELSE 0
END AS long_lower_shadow
```

## Data Handling Best Practices

- **Null Safety**: Use `NULLIF()` before division to prevent errors (e.g., `AVG(volume) / NULLIF(prev_volume, 0)`)
- **Date Filtering**: Use `RANGE BETWEEN INTERVAL` for date-based windows (more efficient than date comparisons)
- **Validation**: Include minimum data point counts (e.g., `HAVING COUNT(*) >= 15`) before calculating averages
- **Liquidity Thresholds**: Enforce minimum trade value (Rp 5B) to avoid thinly-traded stocks

## Development Commands

There are no build scripts or test runners. To work with this project:

### Run a Screening Query
Connect to PostgreSQL and execute a SQL file directly:
```bash
psql -U <user> -d <database> -h <host> -f 1.momentum-rebound.sql
```

### Test Data Quality
Run the count utility to validate data availability:
```bash
psql -U <user> -d <database> -h <host> -f count.sql
```

### Run Backtesting/Simulation
Execute simulation for specific dates (check `operations/momentum_rebound_simulate_by_date.sql` for parameters):
```bash
psql -U <user> -d <database> -h <host> -f operations/momentum_rebound_simulate_by_date.sql
```

### Update Sideways State
Run nightly to recalculate consolidation patterns:
```bash
psql -U <user> -d <database> -h <host> -f per_night.sql
```

## Code Organization Notes

- **Multiple Versions**: Some strategies have multiple SQL files (e.g., `1.momentum-rebound.sql` vs `1. momentum-rebound-stocksummary.sql`). These represent different iterations or filtering variations.
- **Debug Variants**: Files with `-debug` suffix contain alternative implementations useful for troubleshooting.
- **Comments**: Strategies use inline comments in both English and Indonesian to explain trading logic and criteria.

## Performance Considerations

- Window functions are used extensively for efficiency (better than self-joins)
- `DISTINCT ON` with deterministic ordering provides efficient deduplication
- Queries filter by date using `RANGE BETWEEN INTERVAL` before aggregation
- Consider indexes on:
  - `stock_summary(data_date, security_code, ts)`
  - `history_ohlc(code, trade_date)`
  - `sideways_state(symbol, trade_date)`

## Extended Backtesting Query: `operations/momentum_rebound_simulate_by_date.sql`

This enhanced simulation query extends the momentum rebound strategy with 5 additional market microstructure criteria, leveraging orderbook data for deeper analysis.

### Extended Criteria (6-10)

**Criterion 6: Dominant Buy Pressure** (BuyVol > SellVol)
- Compares total bid-side volume vs offer-side volume from orderbook
- True when buy orders exceed sell orders
- Signals stronger demand than supply

**Criterion 7: Strong Buy/Sell Ratio** (>= 1.5)
- Buy volume ÷ Sell volume >= 1.5
- Indicates 50%+ more buying interest than selling pressure
- More stringent than criterion 6

**Criterion 8: Volume Not Overheated** (TodayVolume < Avg20 × 3)
- Prevents false breakouts from exhaustion moves
- Ensures volume is elevated but not panic-driven
- Avoids catching the end of a capitulation spike

**Criterion 9: Price Strengthening** (> 3% from previous close)
- Measures: (Current Price - Previous Close) / Previous Close × 100
- Current day must be up 3%+ from prior day's close
- Confirms momentum is building, not just intraday volatility

**Criterion 10: Bid > Ask at Best Price**
- Checks if best bid price > best ask price (unusual market condition)
- Typically bid ≤ ask (bid-ask spread is positive)
- Reversal indicates extreme buying pressure overcoming normal spread

### Output Scoring

- **original_criteria_met**: Count of original 5 criteria met (0-5)
- **total_criteria_met**: Count of all 10 criteria met (0-10)
- Results sorted by total score descending, then by trade_value

### How to Parameterize

Change the simulation date at line 36:
```sql
SELECT '2025-11-21'::DATE AS target_date  -- Change this date to backtest different trading days
```

### Data Sources for Extended Criteria

- `orderbook` table: Latest snapshot on simulation date provides buy/sell volumes and best bid/ask prices
- `stock_summary` table: Previous_price and current volume for price change and overheating checks

## Key Variables & Constants

- **Minimum Liquidity**: Rp 5B (trade_value threshold)
- **Minimum Price**: 100 IDR (for swing screener)
- **Volume Multipliers**: 1.5× (momentum), 1.2× (daily), 1.3× (swing) of reference averages
- **Time Windows**: 20-day rolling for averages, 60-day for sideways detection
- **Price Thresholds**: 3% down move, 5% up move, 3% strengthening (varies by strategy)
- **Consolidation Range**: < 5% price range over 60 days
- **Volume Overheating Limit**: 3× average volume (criterion 8)
- **Buy/Sell Ratio Threshold**: >= 1.5 (criterion 7)

## Indonesian Stock Exchange (IDX) Context

- Stock codes are 4-letter tickers (BBRI, BBCA, UNTR, SMGR, KLBF, CPIN, BMRI, BRPT, SMMA, etc.)
- Board code typically "NG" (Main Board)
- Trading value in Rupiah (IDR)
- Market hours: 09:00-16:00 WIB
- Intraday data captured at multiple timestamps, with final close at 16:00
