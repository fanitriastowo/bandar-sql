-- Momentum Rebound - New Criteria Strategy
-- Breakout momentum strategy with RSI confirmation
-- Modified criteria focusing on price breakout above previous high with volume and RSI

WITH
-- Fixed simulation date
simulation_date AS (
    SELECT '2025-12-08'::DATE AS target_date
),

range_window AS (
    SELECT INTERVAL '30 days' AS win  -- Extended window for RSI(14) calculation
),

-- Get end-of-day snapshots for each trading day (latest timestamp per day per stock)
daily_snapshots AS (
    SELECT DISTINCT ON (security_code, data_date)
        security_code,
        data_date,
        ts,
        data_time,
        opening_price AS open,
        highest_price AS high,
        lowest_price AS low,
        close_price AS close,
        trade_volume AS volume,
        trade_value AS value,
        previous_price
    FROM
        public.stock_summary
    WHERE
        lowest_price IS NOT NULL
        AND trade_volume IS NOT NULL
        AND close_price IS NOT NULL
        AND data_date::DATE >= (SELECT target_date FROM simulation_date) - (SELECT win FROM range_window)
        AND data_date::DATE <= (SELECT target_date FROM simulation_date)
    ORDER BY
        security_code,
        data_date DESC,
        ts DESC
),

-- Calculate daily price changes for RSI calculation
price_changes AS (
    SELECT
        security_code,
        data_date,
        open,
        high,
        low,
        close,
        volume,
        value,
        previous_price,
        close - LAG(close) OVER (PARTITION BY security_code ORDER BY data_date) AS price_change,
        CASE
            WHEN close - LAG(close) OVER (PARTITION BY security_code ORDER BY data_date) > 0
            THEN close - LAG(close) OVER (PARTITION BY security_code ORDER BY data_date)
            ELSE 0
        END AS gain,
        CASE
            WHEN close - LAG(close) OVER (PARTITION BY security_code ORDER BY data_date) < 0
            THEN ABS(close - LAG(close) OVER (PARTITION BY security_code ORDER BY data_date))
            ELSE 0
        END AS loss
    FROM
        daily_snapshots
),

-- Calculate RSI(14) using Wilder's smoothing method
rsi_calculation AS (
    SELECT
        security_code,
        data_date,
        open,
        high,
        low,
        close,
        volume,
        value,
        previous_price,
        price_change,
        gain,
        loss,
        -- Calculate 14-period average gain and loss
        AVG(gain) OVER (
            PARTITION BY security_code
            ORDER BY data_date
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) AS avg_gain,
        AVG(loss) OVER (
            PARTITION BY security_code
            ORDER BY data_date
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) AS avg_loss,
        -- Count available periods for validation
        COUNT(*) OVER (
            PARTITION BY security_code
            ORDER BY data_date
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
        ) AS periods_count
    FROM
        price_changes
),

-- Calculate final RSI value and 20-day volume SMA
technical_indicators AS (
    SELECT
        security_code,
        data_date,
        open,
        high,
        low,
        close,
        volume,
        value,
        previous_price,
        -- RSI formula: 100 - (100 / (1 + RS))
        -- RS = Average Gain / Average Loss
        CASE
            WHEN avg_loss = 0 THEN 100  -- If no losses, RSI = 100
            WHEN avg_gain = 0 THEN 0    -- If no gains, RSI = 0
            ELSE 100 - (100 / (1 + (avg_gain / NULLIF(avg_loss, 0))))
        END AS rsi_14,
        -- 20-day volume SMA
        AVG(volume) OVER (
            PARTITION BY security_code
            ORDER BY data_date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS sma_volume_20,
        -- Get previous day's high and RSI using LAG
        LAG(high) OVER (PARTITION BY security_code ORDER BY data_date) AS prev_high,
        LAG(
            CASE
                WHEN avg_loss = 0 THEN 100
                WHEN avg_gain = 0 THEN 0
                ELSE 100 - (100 / (1 + (avg_gain / NULLIF(avg_loss, 0))))
            END
        ) OVER (PARTITION BY security_code ORDER BY data_date) AS prev_rsi_14,
        -- Validation: ensure we have enough data
        periods_count,
        COUNT(*) OVER (
            PARTITION BY security_code
            ORDER BY data_date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS volume_periods_count
    FROM
        rsi_calculation
),

-- Filter for target date and apply criteria
target_date_analysis AS (
    SELECT
        security_code,
        data_date,
        open,
        high,
        low,
        close,
        volume,
        value,
        prev_high,
        rsi_14,
        prev_rsi_14,
        sma_volume_20,
        periods_count,
        volume_periods_count,

        -- Calculate metrics for criteria
        ROUND(((high - low) / NULLIF(low, 0))::numeric, 4) AS daily_range_pct,
        ROUND((volume::numeric / NULLIF(sma_volume_20, 0))::numeric, 2) AS volume_to_sma_ratio,

        -- Criterion 1: close > high[1] (breakout above previous high)
        CASE
            WHEN close > prev_high THEN true
            ELSE false
        END AS c1_close_above_prev_high,

        -- Criterion 2: close > open (green candle)
        CASE
            WHEN close > open THEN true
            ELSE false
        END AS c2_green_candle,

        -- Criterion 3: volume > sma(volume, 20) * 3 (3x volume surge)
        CASE
            WHEN volume > sma_volume_20 * 3 THEN true
            ELSE false
        END AS c3_volume_surge_3x,

        -- Criterion 4: (high - low) / low < 0.12 (daily range < 12%)
        CASE
            WHEN (high - low) / NULLIF(low, 0) < 0.12 THEN true
            ELSE false
        END AS c4_range_below_12pct,

        -- Criterion 5: rsi(14) > rsi(14)[1] (RSI increasing)
        CASE
            WHEN rsi_14 > prev_rsi_14 THEN true
            ELSE false
        END AS c5_rsi_increasing,

        -- Criterion 6: value > 1,500,000,000 (minimum Rp 1.5B liquidity)
        CASE
            WHEN value > 1500000000 THEN true
            ELSE false
        END AS c6_min_liquidity

    FROM
        technical_indicators
    WHERE
        data_date::DATE = (SELECT target_date FROM simulation_date)
        AND periods_count >= 14  -- Ensure enough data for RSI
        AND volume_periods_count >= 20  -- Ensure enough data for SMA
        AND prev_high IS NOT NULL
        AND prev_rsi_14 IS NOT NULL
)

-- Final output with all criteria details
SELECT
    security_code,
    data_date,

    -- Price data
    ROUND(open::numeric, 2) AS open,
    ROUND(high::numeric, 2) AS high,
    ROUND(low::numeric, 2) AS low,
    ROUND(close::numeric, 2) AS close,
    ROUND(prev_high::numeric, 2) AS prev_high,

    -- Volume data
    volume AS today_volume,
    ROUND(sma_volume_20::numeric, 0) AS sma_volume_20,
    volume_to_sma_ratio,

    -- Value (liquidity)
    value AS today_value,

    -- Technical indicators
    ROUND(rsi_14::numeric, 2) AS rsi_14,
    ROUND(prev_rsi_14::numeric, 2) AS prev_rsi_14,
    daily_range_pct,

    -- Criteria flags (use symbols for clarity)
    CASE WHEN c1_close_above_prev_high THEN '✓' ELSE '✗' END AS "1_Close>PrevHigh",
    CASE WHEN c2_green_candle THEN '✓' ELSE '✗' END AS "2_GreenCandle",
    CASE WHEN c3_volume_surge_3x THEN '✓' ELSE '✗' END AS "3_Vol>SMA*3",
    CASE WHEN c4_range_below_12pct THEN '✓' ELSE '✗' END AS "4_Range<12%",
    CASE WHEN c5_rsi_increasing THEN '✓' ELSE '✗' END AS "5_RSI_Rising",
    CASE WHEN c6_min_liquidity THEN '✓' ELSE '✗' END AS "6_Value>1.5B",

    -- Total criteria met (out of 6)
    (
        CASE WHEN c1_close_above_prev_high THEN 1 ELSE 0 END +
        CASE WHEN c2_green_candle THEN 1 ELSE 0 END +
        CASE WHEN c3_volume_surge_3x THEN 1 ELSE 0 END +
        CASE WHEN c4_range_below_12pct THEN 1 ELSE 0 END +
        CASE WHEN c5_rsi_increasing THEN 1 ELSE 0 END +
        CASE WHEN c6_min_liquidity THEN 1 ELSE 0 END
    ) AS total_criteria_met

FROM
    target_date_analysis

WHERE
    -- Filter: show only stocks meeting minimum criteria (adjust as needed)
    c6_min_liquidity = true  -- Must have minimum liquidity
    AND c2_green_candle = true  -- Must be green candle

ORDER BY
    (
        CASE WHEN c1_close_above_prev_high THEN 1 ELSE 0 END +
        CASE WHEN c2_green_candle THEN 1 ELSE 0 END +
        CASE WHEN c3_volume_surge_3x THEN 1 ELSE 0 END +
        CASE WHEN c4_range_below_12pct THEN 1 ELSE 0 END +
        CASE WHEN c5_rsi_increasing THEN 1 ELSE 0 END +
        CASE WHEN c6_min_liquidity THEN 1 ELSE 0 END
    ) DESC,
    value DESC;
