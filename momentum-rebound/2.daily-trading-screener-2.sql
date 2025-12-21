-- Production: Daily Trading Strategy Stock Screener

WITH
latest_ma5 AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        AVG("close_price") OVER (
            PARTITION BY security_code
            ORDER BY data_date
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) AS ma5,
        trade_volume AS yesterday_volume
    FROM public.stock_summary
    WHERE "close_price" IS NOT NULL 
        AND trade_volume IS NOT NULL
    ORDER BY security_code, data_date DESC
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
),

afternoon_volume_trend AS (
    SELECT
        security_code,
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
    FROM public.stock_summary
    WHERE data_date = (SELECT MAX(data_date) FROM public.stock_summary)
        AND (EXTRACT(HOUR FROM ts) * 60 + EXTRACT(MINUTE FROM ts)) >= 870
    GROUP BY security_code
)

SELECT
    ls.security_code,
    ls.current_price,
    ls.opening_price,
    ls.previous_price,
    ma5.ma5,
    ls.trade_volume,
    ls.trade_value,
    ROUND(((ls.current_price - ls.previous_price) / ls.previous_price * 100)::numeric, 2) AS pct_change
FROM latest_snapshot ls
INNER JOIN latest_ma5 ma5 ON ls.security_code = ma5.security_code
INNER JOIN afternoon_volume_trend avt ON ls.security_code = avt.security_code
WHERE ls.current_price >= ma5.ma5
    AND ls.current_price >= 1.05 * ls.previous_price
    AND ls.current_price >= ls.opening_price
    AND ls.trade_volume >= 1.20 * ma5.yesterday_volume
    AND ls.trade_value > 5000000000
    AND avt.is_volume_increasing = true
ORDER BY ls.trade_value DESC;