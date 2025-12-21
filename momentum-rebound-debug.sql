-- 1. Check latest stock_summary data
SELECT
    'stock_summary' AS table_name,
    COUNT(DISTINCT security_code) AS stock_count,
    MIN(data_date) AS earliest_date,
    MAX(data_date) AS latest_date,
    COUNT(*) AS total_records
FROM public.stock_summary;

-- 2. Check if we have TODAY's data in stock_summary
SELECT
    'today_stock_summary' AS table_name,
    COUNT(DISTINCT security_code) AS stock_count,
    COUNT(*) AS total_records
FROM public.stock_summary
WHERE data_date = TO_CHAR(CURRENT_DATE, 'YYYYMMDD');

-- 3. Check latest history_ohlc data
SELECT
    'history_ohlc' AS table_name,
    COUNT(DISTINCT code) AS stock_count,
    MIN(trade_date) AS earliest_date,
    MAX(trade_date) AS latest_date,
    COUNT(*) AS total_records
FROM public.history_ohlc;


-- 4. Sample of latest stock_summary data (top 10 stocks)
SELECT
    security_code,
    data_date,
    data_time,
    opening_price,
    highest_price,
    lowest_price,
    close_price,
    trade_volume,
    trade_value
FROM public.stock_summary
WHERE data_date = (SELECT MAX(data_date) FROM public.stock_summary)
ORDER BY trade_value DESC
LIMIT 10;

-- 5. Check if any stocks meet individual criteria (relaxed)
WITH latest_snapshot AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        data_date,
        opening_price,
        highest_price,
        lowest_price,
        close_price,
        trade_volume,
        trade_value
    FROM public.stock_summary
    ORDER BY security_code, ts DESC
)
SELECT
    COUNT(*) AS total_stocks,
    SUM(CASE WHEN close_price <= 0.97 * opening_price THEN 1 ELSE 0 END) AS down_3pct_count,
    SUM(CASE WHEN (close_price - lowest_price) >= 0.6 * (highest_price - lowest_price) AND close_price > lowest_price THEN 1 ELSE 0 END) AS long_shadow_count,
    SUM(CASE WHEN trade_value >= 5000000000 THEN 1 ELSE 0 END) AS liquid_count
FROM latest_snapshot
WHERE data_date = (SELECT MAX(data_date) FROM public.stock_summary);


-- 6. Show stocks with long lower shadow and liquidity (most likely candidates)
WITH latest_snapshot AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        data_date,
        opening_price,
        highest_price,
        lowest_price,
        close_price,
        trade_volume,
        trade_value,
        (close_price / NULLIF(opening_price, 0)) AS price_to_open,
        (close_price - lowest_price) / NULLIF(highest_price - lowest_price, 0) AS shadow_ratio
    FROM public.stock_summary
    ORDER BY security_code, ts DESC
)
SELECT
    security_code,
    opening_price,
    highest_price,
    lowest_price,
    close_price,
    trade_value,
    ROUND(price_to_open::numeric, 4) AS price_to_open_ratio,
    ROUND(shadow_ratio::numeric, 4) AS lower_shadow_ratio,
    CASE WHEN close_price <= 0.97 * opening_price THEN 'YES' ELSE 'NO' END AS down_3pct,
    CASE WHEN shadow_ratio >= 0.6 AND close_price > lowest_price THEN 'YES' ELSE 'NO' END AS long_shadow,
    CASE WHEN trade_value >= 5000000000 THEN 'YES' ELSE 'NO' END AS liquid
FROM latest_snapshot
WHERE
    trade_value >= 5000000000
    AND (close_price - lowest_price) >= 0.6 * (highest_price - lowest_price)
    AND close_price > lowest_price
ORDER BY trade_value DESC
LIMIT 20;
