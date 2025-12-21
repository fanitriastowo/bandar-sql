WITH last_day AS (
  SELECT MAX(trade_date)::date AS d
  FROM history_ohlc
),
base AS (
  SELECT 
    h.*,
    AVG(close) OVER (PARTITION BY code ORDER BY trade_date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS ma5,
    LAG(close)  OVER (PARTITION BY code ORDER BY trade_date) AS prev_close,
    LAG(volume) OVER (PARTITION BY code ORDER BY trade_date) AS prev_volume
  FROM history_ohlc h
)
SELECT
  code AS symbol,
  trade_date,
  open,
  close,
  high,
  low,
  volume,
  value,
  ma5,
  prev_close,
  prev_volume
FROM base b
JOIN last_day l ON b.trade_date = l.d
WHERE
  close > ma5                                       -- 1. close > MA5
  AND close >= prev_close * 1.05                    -- 2. >= 5%
  AND close >= open                                 -- 3. candle hijau
  AND volume >= prev_volume * 0.20                  -- 4. activity > 20% dari kemarin
  AND value > 5000000000                            -- 5. > 5 milyar
ORDER BY value DESC;
