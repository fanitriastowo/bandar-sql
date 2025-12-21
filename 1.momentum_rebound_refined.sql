-- Detailed Analysis (Using stock_summary only)
-- Shows all criteria for each candidate stock
-- No dependency on stock_summary table

WITH
-- Get end-of-day snapshots for each trading day (latest timestamp per day per stock)
daily_snapshots AS (
    SELECT DISTINCT ON (security_code, data_date)
        security_code,
        data_date,
        ts,
        data_time,
        opening_price,
        highest_price,
        lowest_price,
        close_price,
        trade_volume,
        trade_value,
        trade_frequency,
        previous_price
    FROM
        public.stock_summary
    WHERE
        lowest_price IS NOT NULL
        AND trade_volume IS NOT NULL
        AND close_price IS NOT NULL
    ORDER BY
        security_code,
        data_date DESC,
        ts DESC
),

-- Get the latest trading date available
latest_trading_date AS (
    SELECT MAX(data_date::DATE) AS max_date
    FROM public.stock_summary
),

-- Get previous day's data (one day before the latest)
previous_day_data AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        data_date AS prev_trade_date,
        lowest_price AS previous_low,
        trade_volume AS prev_volume
    FROM
        daily_snapshots
    WHERE
        data_date::DATE < (SELECT max_date FROM latest_trading_date)
    ORDER BY
        security_code,
        data_date DESC
),

-- Calculate average volume over available trading days from stock_summary
avg_volume_20d AS (
    SELECT
        ds.security_code,
        AVG(ds.trade_volume) AS avg_volume_20d,
        COUNT(DISTINCT ds.data_date) AS days_count
    FROM
        daily_snapshots ds
    WHERE
        ds.data_date::DATE < (SELECT max_date FROM latest_trading_date)  -- Exclude today
    GROUP BY
        ds.security_code
    HAVING
        COUNT(DISTINCT ds.data_date) >= 5  -- At least 5 trading days of data (reduced from 15)
),

-- Get latest intraday snapshot for each stock (today's data)
latest_snapshot AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        ts,
        data_date,
        data_time,
        opening_price,
        highest_price,
        lowest_price,
        close_price AS current_price,
        trade_volume,
        trade_value,
        trade_frequency,
        previous_price
    FROM
        public.stock_summary
    WHERE
        data_date::DATE = (SELECT max_date FROM latest_trading_date)
    ORDER BY
        security_code,
        ts DESC
),

-- Calculate candle characteristics and volume analysis
candle_analysis AS (
    SELECT
        ls.security_code,
        ls.current_price,
        ls.opening_price,
        ls.highest_price,
        ls.lowest_price,
        ls.trade_volume,
        ls.trade_value,
        ls.previous_price,
        ls.data_time,
        ls.data_date,

        -- Previous day data
        pd.previous_low,
        pd.prev_volume,

        -- Average volume
        av.avg_volume_20d,
        av.days_count AS avg_days_count,

        -- Criterion 1: Price down ≥ 3% from opening
        ROUND((ls.current_price / NULLIF(ls.opening_price, 0))::numeric, 4) AS price_to_open_ratio,
        CASE
            WHEN ls.current_price <= 0.97 * ls.opening_price THEN true
            ELSE false
        END AS is_down_from_open,

        -- Criterion 2: Long lower shadow (rebound signal)
        (ls.highest_price - ls.lowest_price) AS candle_range,
        (ls.current_price - ls.lowest_price) AS lower_shadow,
        CASE
            WHEN (ls.highest_price - ls.lowest_price) > 0 THEN
                ROUND(((ls.current_price - ls.lowest_price) / NULLIF(ls.highest_price - ls.lowest_price, 0))::numeric, 4)
            ELSE 0
        END AS lower_shadow_ratio,
        CASE
            WHEN (ls.current_price - ls.lowest_price) >= 0.6 * (ls.highest_price - ls.lowest_price)
                 AND ls.current_price > ls.lowest_price
            THEN true
            ELSE false
        END AS has_long_lower_shadow,

        -- Criterion 3: Volume surge (≥ 1.5× average)
        ROUND((ls.trade_volume::numeric / NULLIF(av.avg_volume_20d, 0))::numeric, 4) AS volume_to_avg_ratio,
        CASE
            WHEN av.avg_volume_20d IS NOT NULL AND ls.trade_volume >= 1.5 * av.avg_volume_20d THEN true
            ELSE false
        END AS has_volume_surge,

        -- Criterion 3b: Volume below average (< 1.0× average) - indicates low volume today
        CASE
            WHEN av.avg_volume_20d IS NOT NULL AND ls.trade_volume < av.avg_volume_20d THEN true
            ELSE false
        END AS volume_below_avg,

        -- Criterion 4: Liquidity check (≥ Rp 5 billion)
        CASE
            WHEN ls.trade_value >= 5000000000 THEN true
            ELSE false
        END AS is_liquid,

        -- Criterion 5: Low near previous support (≤ 1.02 × previous low)
        ROUND((ls.lowest_price / NULLIF(pd.previous_low, 0))::numeric, 4) AS low_to_prev_low_ratio,
        CASE
            WHEN pd.previous_low IS NOT NULL AND ls.lowest_price <= 1.02 * pd.previous_low THEN true
            ELSE false
        END AS is_near_support

    FROM
        latest_snapshot ls
        LEFT JOIN previous_day_data pd ON ls.security_code = pd.security_code
        LEFT JOIN avg_volume_20d av ON ls.security_code = av.security_code
)

-- Show detailed breakdown for all candidates
SELECT
    security_code,
    data_date,
    data_time,
    current_price,
    opening_price,
    highest_price,
    lowest_price,
    previous_low,

    -- Transaction metrics
    trade_volume AS today_volume,
    trade_value AS today_value,
    ROUND(avg_volume_20d::numeric, 0) AS avg_volume_20d,
    avg_days_count,

    -- Calculated ratios
    price_to_open_ratio,
    lower_shadow_ratio,
    volume_to_avg_ratio,
    low_to_prev_low_ratio,

    -- Candle details
    ROUND(candle_range::numeric, 2) AS candle_range,
    ROUND(lower_shadow::numeric, 2) AS lower_shadow,

    -- Criteria flags (use symbols for clarity)
    CASE WHEN is_down_from_open THEN '✓' ELSE '✗' END AS "1_Down3%",
    CASE WHEN has_long_lower_shadow THEN '✓' ELSE '✗' END AS "2_LongShadow",
    CASE WHEN has_volume_surge THEN '✓' ELSE '✗' END AS "3_VolSurge",
    CASE WHEN volume_below_avg THEN '✓' ELSE '✗' END AS "3b_VolBelowAvg",
    CASE WHEN is_liquid THEN '✓' ELSE '✗' END AS "4_Liquid",
    CASE WHEN is_near_support THEN '✓' ELSE '✗' END AS "5_NearSupport",

    -- Signal strength (count of criteria met)
    (
        CASE WHEN is_down_from_open THEN 1 ELSE 0 END +
        CASE WHEN has_long_lower_shadow THEN 1 ELSE 0 END +
        CASE WHEN has_volume_surge THEN 1 ELSE 0 END +
        CASE WHEN is_liquid THEN 1 ELSE 0 END +
        CASE WHEN is_near_support THEN 1 ELSE 0 END
    ) AS criteria_met

FROM
    candle_analysis

WHERE
    -- Show stocks with at least long lower shadow and liquidity
    has_long_lower_shadow = true
    AND is_liquid = true

ORDER BY
    (
        CASE WHEN is_down_from_open THEN 1 ELSE 0 END +
        CASE WHEN has_long_lower_shadow THEN 1 ELSE 0 END +
        CASE WHEN has_volume_surge THEN 1 ELSE 0 END +
        CASE WHEN is_liquid THEN 1 ELSE 0 END +
        CASE WHEN is_near_support THEN 1 ELSE 0 END
    ) DESC,
    trade_value DESC;