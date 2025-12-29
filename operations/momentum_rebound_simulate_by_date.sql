-- Momentum Rebound - Trade-Based Simulation for 2025-12-22
-- Enhanced strategy using actual trades data instead of orderbook for better momentum signals
-- Optimized for 4CPU/4GB RAM server - eliminates 400M row orderbook bottleneck
-- Shows all 9 momentum criteria for each candidate stock

WITH
-- Fixed simulation date
simulation_date AS (
    SELECT '2025-12-23'::DATE AS target_date
),

range_window AS (
  SELECT INTERVAL '20 days' AS win
),

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
        previous_price,
        board_code
    FROM
        public.stock_summary
    WHERE
        board_code = 'RG'
        AND lowest_price IS NOT NULL
        AND trade_volume IS NOT NULL
        AND close_price IS NOT NULL
        AND data_date::DATE >= (SELECT target_date FROM simulation_date) - (SELECT win FROM range_window)
        AND data_date::DATE <= (SELECT target_date FROM simulation_date)
    ORDER BY
        security_code,
        data_date DESC,
        ts DESC
),

-- Get previous day's data (one day before target_date)
previous_day_data AS (
    SELECT DISTINCT ON (security_code)
        security_code,
        data_date AS prev_trade_date,
        lowest_price AS previous_low,
        trade_volume AS prev_volume
    FROM
        daily_snapshots
    WHERE
        data_date::DATE < (SELECT target_date FROM simulation_date)
    ORDER BY
        security_code,
        data_date DESC
),

-- Calculate average volume and price range over available trading days before target_date
avg_volume_20d AS (
    SELECT
        ds.security_code,
        AVG(ds.trade_volume) AS avg_volume_20d,
        MAX(ds.close_price) AS max_price_20d,
        MIN(ds.close_price) AS min_price_20d,
        COUNT(DISTINCT ds.data_date) AS days_count
    FROM
        daily_snapshots ds
    WHERE
        ds.data_date::DATE < (SELECT target_date FROM simulation_date)
    GROUP BY
        ds.security_code
    HAVING
        COUNT(DISTINCT ds.data_date) >= 0  -- At least available trading days of data
),

-- Get latest intraday snapshot for each stock on target_date
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
        board_code = 'RG'
        AND data_date::DATE = (SELECT target_date FROM simulation_date)
    ORDER BY
        security_code,
        ts DESC
),

-- NEW: Trade momentum analysis using actual executed trades
-- Step 1: Calculate window functions first (LAG requires window context)
trade_momentum_raw AS (
    SELECT
        security_code,
        price,
        volume,
        ts,
        -- Price direction compared to previous trade
        CASE 
            WHEN price > LAG(price) OVER (PARTITION BY security_code ORDER BY ts) THEN true
            ELSE false
        END AS is_price_up,
        CASE 
            WHEN price < LAG(price) OVER (PARTITION BY security_code ORDER BY ts) THEN true
            ELSE false
        END AS is_price_down
    FROM
        public.trades
    WHERE
        ts::DATE = (SELECT target_date FROM simulation_date)
        AND security_code IN (
            SELECT security_code FROM latest_snapshot
        )
),

-- Step 2: Apply aggregate functions to window function results
trade_momentum_analysis AS (
    SELECT
        security_code,
        -- Price momentum: last vs first trade of the day
        ROUND(((MAX(price) - MIN(price)) / NULLIF(MIN(price), 0)) * 100, 2) AS trade_price_momentum_pct,
        -- Trade count: activity level
        COUNT(*) AS total_trade_count,
        -- Volume-weighted average price (VWAP)
        ROUND(SUM(price * volume) / NULLIF(SUM(volume), 0), 2) AS vwap_price,
        -- Aggressive buying: trades at increasing prices
        SUM(CASE WHEN is_price_up THEN volume ELSE 0 END) AS aggressive_buy_volume,
        -- Total traded volume from trades table
        SUM(volume) AS total_trade_volume,
        -- Trade frequency: trades per hour approximation
        ROUND(COUNT(*)::numeric / NULLIF(
            EXTRACT(EPOCH FROM MAX(ts) - MIN(ts)) / 3600, 1
        ), 2) AS trades_per_hour,
        -- Price momentum direction: positive vs negative trades
        SUM(CASE WHEN is_price_up THEN 1 ELSE 0 END) - 
        SUM(CASE WHEN is_price_down THEN 1 ELSE 0 END) AS price_direction_score,
        -- Large trade dominance: trades above average volume (simplified)
        SUM(CASE WHEN volume >= 1000000 THEN volume ELSE 0 END) AS large_trade_volume
    FROM
        trade_momentum_raw
    GROUP BY
        security_code
    HAVING
        COUNT(*) >= 10  -- Minimum 10 trades for meaningful analysis
),

-- Calculate candle characteristics and trade-enhanced momentum analysis
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

        -- Average volume and 20-day price range
        av.avg_volume_20d,
        av.max_price_20d,
        av.min_price_20d,
        av.days_count AS avg_days_count,

        -- Trade momentum data
        COALESCE(tma.trade_price_momentum_pct, 0) AS trade_price_momentum_pct,
        COALESCE(tma.total_trade_count, 0) AS total_trade_count,
        COALESCE(tma.vwap_price, ls.current_price) AS vwap_price,
        COALESCE(tma.aggressive_buy_volume, 0) AS aggressive_buy_volume,
        COALESCE(tma.total_trade_volume, 0) AS total_trade_volume,
        COALESCE(tma.trades_per_hour, 0) AS trades_per_hour,
        COALESCE(tma.price_direction_score, 0) AS price_direction_score,
        COALESCE(tma.large_trade_volume, 0) AS large_trade_volume,

        -- Original Criterion 1: Price down ≥ 3% from opening
        ROUND((ls.current_price / NULLIF(ls.opening_price, 0))::numeric, 4) AS price_to_open_ratio,
        CASE
            WHEN ls.current_price <= 0.97 * ls.opening_price THEN true
            ELSE false
        END AS is_down_from_open,

        -- Original Criterion 2: Long lower shadow (rebound signal)
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

        -- Original Criterion 3: Volume surge (≥ 1.5× average)
        ROUND((ls.trade_volume::numeric / NULLIF(av.avg_volume_20d, 0))::numeric, 4) AS volume_to_avg_ratio,
        CASE
            WHEN av.avg_volume_20d IS NOT NULL AND ls.trade_volume >= 1.5 * av.avg_volume_20d THEN true
            ELSE false
        END AS has_volume_surge,

        -- Original Criterion 3b: Volume below average (< 1.0× average)
        CASE
            WHEN av.avg_volume_20d IS NOT NULL AND ls.trade_volume < av.avg_volume_20d THEN true
            ELSE false
        END AS volume_below_avg,

        -- Original Criterion 4: Liquidity check (≥ Rp 5 billion)
        CASE
            WHEN ls.trade_value >= 5000000000 THEN true
            ELSE false
        END AS is_liquid,

        -- Original Criterion 5: Low near previous support (≤ 1.02 × previous low)
        ROUND((ls.lowest_price / NULLIF(pd.previous_low, 0))::numeric, 4) AS low_to_prev_low_ratio,
        CASE
            WHEN pd.previous_low IS NOT NULL AND ls.lowest_price <= 1.02 * pd.previous_low THEN true
            ELSE false
        END AS is_near_support,

        -- NEW Criterion 6: Trade flow momentum (actual executed trade pressure)
        CASE
            WHEN tma.trade_price_momentum_pct >= 2.0 THEN true  -- 2% upward momentum
            ELSE false
        END AS has_trade_flow_momentum,

        -- NEW Criterion 7: Aggressive buying intensity (60% of volume in rising trades)
        CASE
            WHEN tma.total_trade_volume > 0 
                 AND (tma.aggressive_buy_volume::numeric / NULLIF(tma.total_trade_volume, 0)) >= 0.6 THEN true
            ELSE false
        END AS has_aggressive_buying,

        -- NEW Criterion 8: Volume not overheated (TodayVolume < Avg20 * 3)
        CASE
            WHEN av.avg_volume_20d IS NOT NULL AND ls.trade_volume < av.avg_volume_20d * 3 THEN true
            ELSE false
        END AS volume_not_overheated,

        -- NEW Criterion 9: Price strengthening (>3% from previous close)
        ROUND((((ls.current_price - ls.previous_price) / NULLIF(ls.previous_price, 0))::numeric) * 100, 2) AS price_change_pct,
        CASE
            WHEN ls.previous_price IS NOT NULL AND ls.current_price > ls.previous_price * 1.03 THEN true
            ELSE false
        END AS price_strengthening,

        -- NEW Criterion 11: Price increase below 10% over 20 days (not overextended)
        -- Kenaikan dibawah 10% untuk 20 hari terakhir
        ROUND((((ls.current_price - av.min_price_20d) / NULLIF(av.min_price_20d, 0))::numeric) * 100, 2) AS price_increase_20d_pct,
        CASE
            WHEN av.min_price_20d IS NOT NULL AND ls.current_price <= av.min_price_20d * 1.10 THEN true
            ELSE false
        END AS not_overextended,

        -- NEW Criterion 12: Price decrease less than 5% from 20-day high (not in downtrend)
        -- Penurunan kurang dari 5% untuk 20 hari terakhir
        ROUND((((av.max_price_20d - ls.current_price) / NULLIF(av.max_price_20d, 0))::numeric) * 100, 2) AS price_decrease_from_high_pct,
        CASE
            WHEN av.max_price_20d IS NOT NULL AND ls.current_price >= av.max_price_20d * 0.95 THEN true
            ELSE false
        END AS not_in_downtrend

    FROM
        latest_snapshot ls
        LEFT JOIN previous_day_data pd ON ls.security_code = pd.security_code
        LEFT JOIN avg_volume_20d av ON ls.security_code = av.security_code
        LEFT JOIN trade_momentum_analysis tma ON ls.security_code = tma.security_code
)

-- Show detailed breakdown for all candidates on target_date using trade-enhanced analysis
SELECT
    security_code,
    data_date,
    data_time,
    current_price,
    opening_price,
    highest_price,
    lowest_price,
    previous_low,
    previous_price,

    -- Transaction metrics from stock_summary
    trade_volume AS today_volume,
    trade_value AS today_value,
    ROUND(avg_volume_20d::numeric, 0) AS avg_volume_20d,
    avg_days_count,

    -- Trade analysis metrics
    total_trade_count,
    total_trade_volume AS trade_executed_volume,
    trades_per_hour,
    trade_price_momentum_pct,
    vwap_price,
    aggressive_buy_volume,
    price_direction_score,
    large_trade_volume,

    -- Calculated ratios
    price_to_open_ratio,
    lower_shadow_ratio,
    volume_to_avg_ratio,
    low_to_prev_low_ratio,
    price_change_pct,
    price_increase_20d_pct,
    price_decrease_from_high_pct,
    max_price_20d,
    min_price_20d,

    -- Candle details
    ROUND(candle_range::numeric, 2) AS candle_range,
    ROUND(lower_shadow::numeric, 2) AS lower_shadow,

    -- ORIGINAL Criteria flags (use symbols for clarity)
    CASE WHEN is_down_from_open THEN '✓' ELSE '✗' END AS "1_Down3%",
    CASE WHEN has_long_lower_shadow THEN '✓' ELSE '✗' END AS "2_LongShadow",
    CASE WHEN has_volume_surge THEN '✓' ELSE '✗' END AS "3_VolSurge",
    CASE WHEN volume_below_avg THEN '✓' ELSE '✗' END AS "3b_VolBelowAvg",
    CASE WHEN is_liquid THEN '✓' ELSE '✗' END AS "4_Liquid",
    CASE WHEN is_near_support THEN '✓' ELSE '✗' END AS "5_NearSupport",

    -- NEW Trade-based Criteria flags
    CASE WHEN has_trade_flow_momentum THEN '✓' ELSE '✗' END AS "6_TradeMomentum",
    CASE WHEN has_aggressive_buying THEN '✓' ELSE '✗' END AS "7_AggressiveBuy",
    CASE WHEN volume_not_overheated THEN '✓' ELSE '✗' END AS "8_NotOverheated",
    CASE WHEN price_strengthening THEN '✓' ELSE '✗' END AS "9_Price>3%",

    -- Additional Trend Analysis Criteria flags
    CASE WHEN not_overextended THEN '✓' ELSE '✗' END AS "11_NotExtended<10%",
    CASE WHEN not_in_downtrend THEN '✓' ELSE '✗' END AS "12_NotDown>5%",

    -- Complete signal strength (11 criteria - excluding 3b_VolBelowAvg)
    (
        CASE WHEN is_down_from_open THEN 1 ELSE 0 END +
        CASE WHEN has_long_lower_shadow THEN 1 ELSE 0 END +
        CASE WHEN has_volume_surge THEN 1 ELSE 0 END +
        CASE WHEN is_liquid THEN 1 ELSE 0 END +
        CASE WHEN is_near_support THEN 1 ELSE 0 END +
        CASE WHEN has_trade_flow_momentum THEN 1 ELSE 0 END +
        CASE WHEN has_aggressive_buying THEN 1 ELSE 0 END +
        CASE WHEN volume_not_overheated THEN 1 ELSE 0 END +
        CASE WHEN price_strengthening THEN 1 ELSE 0 END +
        CASE WHEN not_overextended THEN 1 ELSE 0 END +
        CASE WHEN not_in_downtrend THEN 1 ELSE 0 END
    ) AS total_criteria_met

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
        CASE WHEN is_near_support THEN 1 ELSE 0 END +
        CASE WHEN has_trade_flow_momentum THEN 1 ELSE 0 END +
        CASE WHEN has_aggressive_buying THEN 1 ELSE 0 END +
        CASE WHEN volume_not_overheated THEN 1 ELSE 0 END +
        CASE WHEN price_strengthening THEN 1 ELSE 0 END +
        CASE WHEN not_overextended THEN 1 ELSE 0 END +
        CASE WHEN not_in_downtrend THEN 1 ELSE 0 END
    ) DESC,
    trade_value DESC;