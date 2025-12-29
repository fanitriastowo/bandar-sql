# AGENTS.md

PostgreSQL stock trading strategy repository for agentic coding agents.

## Commands

### Run single test/query
```bash
psql -U <user> -d <database> -h <host> -f <filename>.sql
```

### Test data quality
```bash
psql -U <user> -d <database> -h <host> -f count.sql
```

### Schema setup
```bash
psql -U <user> -d <database> -h <host> -f structures/stock_fundamentals.sql
```

## Database Schema (structures/)
- `market_cap`: Stock market capitalization data with UUID primary key
- `orderbook`: Real-time order book with timestamp, security code, side, price, volume
- `stock_fundamentals`: Company fundamentals (shares, free float, market cap ratios)
- `stock_summary`: EOD stock data (date, time, OHLC, volume, bid/ask)
- `trades`: Individual trade records with trade numbers and timestamps

## Code Style

### SQL conventions
- Use `COALESCE()` for data source fallback (intraday > historical)
- Use `DISTINCT ON` with deterministic ordering for latest records
- Use `NULLIF()` before division operations for null safety
- Use `CASE` statements for explicit boolean flag calculations
- Use window functions over self-joins for performance
- Include minimum data point validation before averages

### Naming & organization
- Tables: snake_case (stock_summary, history_ohlc)
- Columns: descriptive snake_case aliases
- Files: number-based strategy prefixes (1.*, 2.*), `-debug` suffix for debug files
- Schema files: place in `structures/` directory

### Data safety
- Enforce minimum liquidity thresholds (Rp 5B default)
- Use `RANGE BETWEEN INTERVAL` for efficient date queries
- Validate data availability with count queries
- Parameterize simulation dates in variables