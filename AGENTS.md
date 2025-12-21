# AGENTS.md

This file provides guidance for agentic coding agents working in this PostgreSQL-based stock trading strategy repository.

## Development Commands

### Test Data Quality
```bash
psql -U <user> -d <database> -h <host> -f count.sql
```

### Run Screening Queries
```bash
psql -U <user> -d <database> -h <host> -f 1.momentum-rebound.sql
psql -U <user> -d <database> -h <host> -f 2.daily-trading-screener.sql
psql -U <user> -d <database> -h <host> -f swing-screening-history-ohlc.sql
psql -U <user> -d <database> -h <host> -f swing-screener-advanced.sql
psql -U <user> -d <database> -h <host> -f 3.swing-trading-screening.sql
```

### Debug Advanced Queries
```bash
psql -U <user> -d <database> -h <host> -f swing-screener-advanced-debug.sql
```

### Setup Database Schema
```bash
psql -U <user> -d <database> -h <host> -f structures/stock_fundamentals.sql
```

### Run Backtesting/Simulation
```bash
psql -U <user> -d <database> -h <host> -f operations/momentum_rebound_simulate_by_date.sql
```

### Update Fundamentals Data
```bash
psql -U <user> -d <database> -h <host> -f bulk_add_fundamentals_with_free_float.sql
```

### Update Consolidation Patterns
```bash
psql -U <user> -d <database> -h <host> -f per_night.sql
```

## Code Style Guidelines

### SQL Conventions
- Use `COALESCE()` for data source fallback (intraday > historical)
- Use `DISTINCT ON` with deterministic ordering for latest records
- Use `NULLIF()` before division operations for null safety
- Use `CASE` statements for explicit boolean flag calculations
- Use window functions over self-joins for performance
- Include minimum data point validation before averages

### Naming & Organization
- Table names: snake_case (stock_summary, history_ohlc)
- Column aliases: descriptive snake_case
- File prefixes: number-based strategy grouping (1.*, 2.*, etc.)
- Debug files: use `-debug` suffix
- Schema files: place in `structures/` directory

### Data Safety
- Always enforce minimum liquidity thresholds (Rp 5B default)
- Use date ranges with `RANGE BETWEEN INTERVAL` for efficiency
- Validate data availability with count queries
- Parameterize simulation dates in dedicated variables