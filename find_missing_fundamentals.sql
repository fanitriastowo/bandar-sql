-- Find stocks in history_ohlc that don't have fundamentals data
-- This helps identify which stocks need shares_outstanding to be added

-- Stocks that need fundamentals data added
SELECT DISTINCT
    ho.code AS security_code,
    COUNT(DISTINCT ho.trade_date) AS days_of_data,
    MAX(ho.trade_date) AS latest_date,
    MAX(ho.close) AS latest_close_price,
    AVG(ho.value) AS avg_daily_value,
    'MISSING - Add to stock_fundamentals table' AS status
FROM
    public.history_ohlc ho
    LEFT JOIN public.stock_fundamentals sf ON ho.code = sf.security_code
WHERE
    sf.security_code IS NULL  -- Not in fundamentals table
    AND ho.trade_date >= CURRENT_DATE - INTERVAL '30 days'  -- Active in last 30 days
    AND ho.value > 1000000000  -- At least 1B IDR daily value (filter low liquidity stocks)
GROUP BY
    ho.code
ORDER BY
    avg_daily_value DESC
LIMIT 50;

-- Summary statistics
SELECT
    COUNT(DISTINCT ho.code) AS total_stocks_in_history,
    COUNT(DISTINCT sf.security_code) AS stocks_with_fundamentals,
    COUNT(DISTINCT ho.code) - COUNT(DISTINCT sf.security_code) AS missing_fundamentals
FROM
    public.history_ohlc ho
    LEFT JOIN public.stock_fundamentals sf ON ho.code = sf.security_code
WHERE
    ho.trade_date >= CURRENT_DATE - INTERVAL '30 days';
