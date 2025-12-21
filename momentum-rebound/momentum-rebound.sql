-- Momentum Rebound Screener Query
-- Strategy: Identify stocks rebounding from intraday lows with strong volume
--
-- Criteria:
-- 1. Price ≤ 0.97 × Open → harga turun ≥ 3% dari harga pembukaan
-- 2. Long lower shadow: (Close − Low) ≥ 0.6 × (High − Low) → ada pantulan nyata (Harga close > lower price)
-- 3. Vol(5m) ≥ 1.5 × AvgVol(5m,20) → volume pantulan kuat
-- 4. Value (hari ini) ≥ Rp5.000.000.000 → likuid
-- 5. Low hari ini mendekati support kemarin: Low ≤ Previous Low × 1.02
--
-- NOTE: history_ohlc data is only available until 2025-11-06
-- For recent dates, we use stock_summary data from previous trading day

WITH
-- Get previous day's data from stock_summary (most recent available)
-- This handles cases where history_ohlc is not yet updated
previous_day_from_summary AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        data_date,
        lowest_price AS previous_low,
        trade_volume AS prev_volume
    FROM
        public.stock_summary
    where
        data_date < TO_CHAR(CURRENT_DATE, 'YYYYMMDD')
        AND lowest_price IS NOT NULL
        AND trade_volume IS NOT NULL
    ORDER BY
        security_code,
        data_date DESC,
        ts DESC
),

-- Get previous day's data from history_ohlc (for older dates)
previous_day_from_history AS (
    SELECT DISTINCT ON (code)
        code AS security_code,
        trade_date AS prev_trade_date,
        low AS previous_low,
        volume AS prev_volume
    FROM
        public.history_ohlc
    WHERE
        "close" IS NOT NULL
        AND low IS NOT NULL
        AND volume IS NOT NULL
    ORDER BY
        code,
        trade_date DESC
),

-- Combine both sources, preferring stock_summary for recent data
previous_day_data AS (
    SELECT
        COALESCE(ss.security_code, ho.security_code) AS security_code,
        COALESCE(ss.previous_low, ho.previous_low) AS previous_low,
        COALESCE(ss.prev_volume, ho.prev_volume) AS prev_volume
    FROM
        previous_day_from_summary ss
        FULL OUTER JOIN previous_day_from_history ho ON ss.security_code = ho.security_code
),

-- Calculate average volume over last 20 days (5-minute equivalent would be ~20 trading days)
avg_volume_20d AS (
    SELECT
        code AS security_code,
        AVG(volume) AS avg_volume_20d,
        COUNT(*) AS days_count
    FROM
        public.history_ohlc
    WHERE
        volume IS NOT NULL
        AND trade_date >= CURRENT_DATE - INTERVAL '30 days'  -- Look back 30 days to ensure 20 trading days
    GROUP BY
        code
    HAVING
        COUNT(*) >= 20  -- Ensure we have at least 20 days of data
),

-- Get latest intraday snapshot for each stock
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
        previous_price,
        EXTRACT(HOUR FROM ts) AS snapshot_hour,
        EXTRACT(MINUTE FROM ts) AS snapshot_minute
    FROM
        public.stock_summary
    WHERE
        -- Only consider today's data
        data_date = TO_CHAR(CURRENT_DATE, 'YYYYMMDD')
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

        -- Previous day data
        pd.previous_low,
        pd.prev_volume,

        -- Average volume
        av.avg_volume_20d,

        -- Criterion 1: Price down ≥ 3% from opening
        ROUND((ls.current_price / NULLIF(ls.opening_price, 0))::numeric, 4) AS price_to_open_ratio,
        CASE
            WHEN ls.current_price <= 0.97 * ls.opening_price THEN true
            ELSE false
        END AS is_down_from_open,

        -- Criterion 2: Long lower shadow (rebound signal)
        -- (Close - Low) ≥ 0.6 × (High - Low)
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
            WHEN ls.trade_volume >= 1.5 * av.avg_volume_20d THEN true
            ELSE false
        END AS has_volume_surge,

        -- Criterion 4: Liquidity check (≥ Rp 5 billion)
        CASE
            WHEN ls.trade_value >= 5000000000 THEN true
            ELSE false
        END AS is_liquid,

        -- Criterion 5: Low near previous support (≤ 1.02 × previous low)
        ROUND((ls.lowest_price / NULLIF(pd.previous_low, 0))::numeric, 4) AS low_to_prev_low_ratio,
        CASE
            WHEN ls.lowest_price <= 1.02 * pd.previous_low THEN true
            ELSE false
        END AS is_near_support

    FROM
        latest_snapshot ls
        INNER JOIN previous_day_data pd ON ls.security_code = pd.security_code
        INNER JOIN avg_volume_20d av ON ls.security_code = av.security_code
)

-- Final selection: Apply all criteria
SELECT
    security_code,
    current_price,
    opening_price,
    highest_price,
    lowest_price,
    previous_low,
    data_time AS latest_time,

    -- Transaction metrics
    trade_volume AS today_volume,
    trade_value AS today_value,
    avg_volume_20d,

    -- Calculated ratios
    price_to_open_ratio,
    lower_shadow_ratio,
    volume_to_avg_ratio,
    low_to_prev_low_ratio,

    -- Candle details
    candle_range,
    lower_shadow,

    -- Criteria flags
    is_down_from_open AS "✓_down_3pct",
    has_long_lower_shadow AS "✓_long_shadow",
    has_volume_surge AS "✓_volume_surge",
    is_liquid AS "✓_liquid",
    is_near_support AS "✓_near_support",

    -- Signal strength (count of criteria met)
    (
        CASE WHEN is_down_from_open THEN 1 ELSE 0 END +
        CASE WHEN has_long_lower_shadow THEN 1 ELSE 0 END +
        CASE WHEN has_volume_surge THEN 1 ELSE 0 END +
        CASE WHEN is_liquid THEN 1 ELSE 0 END +
        CASE WHEN is_near_support THEN 1 ELSE 0 END
    ) AS criteria_met_count

FROM
    candle_analysis

WHERE
    -- All 5 criteria must be met
    is_down_from_open = true
    AND has_long_lower_shadow = true
    AND has_volume_surge = true
    AND is_liquid = true
    AND is_near_support = true

ORDER BY
    trade_value DESC,  -- Most liquid first
    volume_to_avg_ratio DESC;  -- Strongest volume surge first


-- Alternative: Relaxed criteria (4 out of 5 criteria met)
-- Uncomment to see near-matches

/*
SELECT
    security_code,
    current_price,
    opening_price,
    highest_price,
    lowest_price,
    previous_low,
    data_time AS latest_time,

    trade_volume AS today_volume,
    trade_value AS today_value,
    avg_volume_20d,

    price_to_open_ratio,
    lower_shadow_ratio,
    volume_to_avg_ratio,
    low_to_prev_low_ratio,

    candle_range,
    lower_shadow,

    is_down_from_open AS "✓_down_3pct",
    has_long_lower_shadow AS "✓_long_shadow",
    has_volume_surge AS "✓_volume_surge",
    is_liquid AS "✓_liquid",
    is_near_support AS "✓_near_support",

    (
        CASE WHEN is_down_from_open THEN 1 ELSE 0 END +
        CASE WHEN has_long_lower_shadow THEN 1 ELSE 0 END +
        CASE WHEN has_volume_surge THEN 1 ELSE 0 END +
        CASE WHEN is_liquid THEN 1 ELSE 0 END +
        CASE WHEN is_near_support THEN 1 ELSE 0 END
    ) AS criteria_met_count

FROM
    candle_analysis

WHERE
    (
        CASE WHEN is_down_from_open THEN 1 ELSE 0 END +
        CASE WHEN has_long_lower_shadow THEN 1 ELSE 0 END +
        CASE WHEN has_volume_surge THEN 1 ELSE 0 END +
        CASE WHEN is_liquid THEN 1 ELSE 0 END +
        CASE WHEN is_near_support THEN 1 ELSE 0 END
    ) >= 4  -- At least 4 out of 5 criteria

ORDER BY
    criteria_met_count DESC,
    trade_value DESC,
    volume_to_avg_ratio DESC;
*/
