-- Debug query for daily trading strategy

-- 1. Check what's the latest date in stock_summary
SELECT
    'Latest stock_summary date' AS info,
    MAX(data_date) AS latest_date,
    COUNT(DISTINCT security_code) AS stock_count
FROM public.stock_summary;

-- 2. Check if CURRENT_DATE matches any data
SELECT
    'Current date match' AS info,
    CURRENT_DATE AS current_date,
    TO_CHAR(CURRENT_DATE, 'YYYYMMDD') AS formatted_current_date,
    COUNT(DISTINCT security_code) AS stock_count_today
FROM public.stock_summary
WHERE data_date = TO_CHAR(CURRENT_DATE, 'YYYYMMDD');

-- 3. Check MA5 calculation - how many stocks have valid MA5?
WITH ma5_calculation AS (
    SELECT
        code AS security_code,
        trade_date,
        "close" AS daily_close,
        AVG("close") OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) AS ma5,
        COUNT(*) OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) AS days_count
    FROM
        public.history_ohlc
    WHERE
        "close" IS NOT NULL
        AND volume IS NOT NULL
)
SELECT
    'MA5 stocks with 5 days data' AS info,
    COUNT(DISTINCT security_code) AS stock_count,
    MAX(trade_date) AS latest_ma5_date
FROM ma5_calculation
WHERE days_count = 5;

-- 4. Check latest snapshot - how many stocks in latest date?
WITH latest_snapshot AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        ts,
        data_date,
        data_time,
        opening_price,
        close_price AS current_price,
        trade_volume,
        trade_value,
        previous_price
    FROM
        public.stock_summary
    WHERE
        data_date = (SELECT MAX(data_date) FROM public.stock_summary)
    ORDER BY
        security_code,
        ts DESC
)
SELECT
    'Latest snapshot' AS info,
    COUNT(*) AS total_stocks,
    MAX(data_date) AS data_date,
    SUM(CASE WHEN current_price >= opening_price THEN 1 ELSE 0 END) AS green_candles,
    SUM(CASE WHEN current_price >= 1.05 * previous_price THEN 1 ELSE 0 END) AS up_5pct,
    SUM(CASE WHEN trade_value > 5000000000 THEN 1 ELSE 0 END) AS liquid_stocks
FROM latest_snapshot;

-- 5. Check afternoon volume trend - does it work?
WITH afternoon_volume_trend AS (
    SELECT
        security_code,
        MAX(CASE WHEN EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts) BETWEEN 870 AND 900
                 THEN trade_volume END) AS volume_1430_1500,
        MAX(CASE WHEN EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts) BETWEEN 900 AND 930
                 THEN trade_volume END) AS volume_1500_1530,
        MAX(CASE WHEN EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts) >= 930
                 THEN trade_volume END) AS volume_1530_close,
        CASE
            WHEN MAX(CASE WHEN EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts) >= 930
                         THEN trade_volume END) >
                 MAX(CASE WHEN EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts) BETWEEN 900 AND 930
                         THEN trade_volume END)
                 AND
                 MAX(CASE WHEN EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts) BETWEEN 900 AND 930
                         THEN trade_volume END) >
                 MAX(CASE WHEN EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts) BETWEEN 870 AND 900
                         THEN trade_volume END)
            THEN true
            ELSE false
        END AS is_volume_increasing
    FROM
        public.stock_summary
    WHERE
        data_date = (SELECT MAX(data_date) FROM public.stock_summary)
        AND (EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts)) >= 870
    GROUP BY
        security_code
)
SELECT
    'Afternoon volume trend' AS info,
    COUNT(*) AS total_stocks,
    SUM(CASE WHEN is_volume_increasing THEN 1 ELSE 0 END) AS stocks_with_increasing_volume
FROM afternoon_volume_trend;

-- 6. Sample: Show top 10 stocks from latest date with basic criteria
WITH
latest_ma5 AS (
    SELECT DISTINCT ON (code)
        code AS security_code,
        AVG("close") OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) AS ma5,
        trade_date,
        volume AS yesterday_volume
    FROM public.history_ohlc
    WHERE "close" IS NOT NULL AND volume IS NOT NULL
    ORDER BY code, trade_date DESC
),
latest_snapshot AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        data_date,
        opening_price,
        close_price AS current_price,
        trade_volume,
        trade_value,
        previous_price
    FROM public.stock_summary
    WHERE data_date = (SELECT MAX(data_date) FROM public.stock_summary)
    ORDER BY security_code, ts DESC
)
SELECT
    ls.security_code,
    ls.data_date,
    ls.current_price,
    ls.opening_price,
    ls.previous_price,
    ma5.ma5,
    ls.trade_volume AS today_volume,
    ma5.yesterday_volume,
    ls.trade_value AS today_value,

    CASE WHEN ls.current_price >= ma5.ma5 THEN '✓' ELSE '✗' END AS above_ma5,
    CASE WHEN ls.current_price >= 1.05 * ls.previous_price THEN '✓' ELSE '✗' END AS up_5pct,
    CASE WHEN ls.current_price >= ls.opening_price THEN '✓' ELSE '✗' END AS green,
    CASE WHEN ls.trade_volume >= 1.20 * ma5.yesterday_volume THEN '✓' ELSE '✗' END AS vol_up,
    CASE WHEN ls.trade_value > 5000000000 THEN '✓' ELSE '✗' END AS liquid

FROM latest_snapshot ls
LEFT JOIN latest_ma5 ma5 ON ls.security_code = ma5.security_code
ORDER BY ls.trade_value DESC
LIMIT 10;
