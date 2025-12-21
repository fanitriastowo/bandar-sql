-- Query to find "swing" stocks from history_ohlc
-- Criteria:
-- 1. Value >= 5,000,000,000 (5B IDR - liquid stock)
-- 2. Price > 100
-- 3. Price >= Price MA20 (above 1-month trend)
-- 4. Price >= 0.97 × Price MA20 (max 3% below MA20)
-- 5. Price <= 1.03 × Price MA20 (max 3% above MA20)
-- 6. Volume >= 1.30 × Previous Volume (30% volume increase from yesterday)
-- 7. Volume >= 1.50 × Volume MA20 (50% volume increase from 20-day average)

WITH stock_metrics AS (
    SELECT
        trade_date,
        code,
        "close" AS price,
        previous,
        "change",
        volume,
        value,
        freq,
        -- Calculate 20-day moving average for price
        AVG("close") OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS price_ma20,
        -- Calculate 20-day moving average for volume
        AVG(volume) OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS volume_ma20,
        -- Get previous day's volume
        LAG(volume, 1) OVER (
            PARTITION BY code
            ORDER BY trade_date
        ) AS previous_volume,
        -- Count how many days of data we have for this stock (for MA20 validity)
        COUNT(*) OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS days_count
    FROM
        public.history_ohlc
    WHERE
        "close" IS NOT NULL
        AND volume IS NOT NULL
        AND value IS NOT NULL
)
SELECT
    trade_date,
    code AS security_code,
    price,
    volume,
    value,
    freq AS frequency,
    ROUND(price_ma20, 2) AS price_ma20,
    ROUND(volume_ma20, 0) AS volume_ma20,
    previous_volume,
    -- Calculated ratios for verification
    ROUND(price / NULLIF(price_ma20, 0), 4) AS price_to_ma20_ratio,
    ROUND(volume / NULLIF(previous_volume, 0), 4) AS volume_to_previous_ratio,
    ROUND(volume / NULLIF(volume_ma20, 0), 4) AS volume_to_ma20_ratio
FROM
    stock_metrics
WHERE
    -- Ensure we have enough data for MA20 calculation
    days_count = 20
    -- Criterion 1: Value >= 5,000,000,000 (5B IDR)
    AND value >= 5000000000
    -- Criterion 2: Price > 100
    AND price > 100
    -- Criterion 3: Price >= Price MA20
    AND price >= price_ma20
    -- Criterion 4: Price >= 0.97 × Price MA20 (max 3% decline)
    AND price >= 0.97 * price_ma20
    -- Criterion 5: Price <= 1.03 × Price MA20 (max 3% increase)
    AND price <= 1.03 * price_ma20
    -- Criterion 6: Volume >= 1.30 × Previous Volume (30% increase)
    AND previous_volume IS NOT NULL
    AND volume >= 1.30 * previous_volume
    -- Criterion 7: Volume >= 1.50 × Volume MA20 (50% increase)
    AND volume >= 1.50 * volume_ma20
ORDER BY
    trade_date DESC,
    value DESC;
*/

-- Alternative: Get only the most recent trading day's results
-- Uncomment the query below if you only want the latest results

/*
WITH stock_metrics AS (
    SELECT
        trade_date,
        code,
        "close" AS price,
        previous,
        "change",
        volume,
        value,
        freq,
        AVG("close") OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS price_ma20,
        AVG(volume) OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS volume_ma20,
        LAG(volume, 1) OVER (
            PARTITION BY code
            ORDER BY trade_date
        ) AS previous_volume,
        COUNT(*) OVER (
            PARTITION BY code
            ORDER BY trade_date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS days_count,
        -- Get the max trade_date globally
        MAX(trade_date) OVER () AS latest_date
    FROM
        public.history_ohlc
    WHERE
        "close" IS NOT NULL
        AND volume IS NOT NULL
        AND value IS NOT NULL
)
SELECT
    trade_date,
    code AS security_code,
    price,
    volume,
    value,
    freq AS frequency,
    ROUND(price_ma20, 2) AS price_ma20,
    ROUND(volume_ma20, 0) AS volume_ma20,
    previous_volume,
    ROUND(price / NULLIF(price_ma20, 0), 4) AS price_to_ma20_ratio,
    ROUND(volume / NULLIF(previous_volume, 0), 4) AS volume_to_previous_ratio,
    ROUND(volume / NULLIF(volume_ma20, 0), 4) AS volume_to_ma20_ratio
FROM
    stock_metrics
WHERE
    -- Only most recent trading day
    trade_date = latest_date
    AND days_count = 20
    AND value >= 5000000000
    AND price > 100
    AND price >= price_ma20
    AND price >= 0.97 * price_ma20
    AND price <= 1.03 * price_ma20
    AND previous_volume IS NOT NULL
    AND volume >= 1.30 * previous_volume
    AND volume >= 1.50 * volume_ma20
ORDER BY
    value DESC;
*/