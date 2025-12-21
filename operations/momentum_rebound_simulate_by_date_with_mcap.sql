-- Momentum Rebound - Simulation with Market Cap Filter
-- Extended version with Market Cap > 25 Trillion IDR criterion
-- Shows all criteria for each candidate stock on a specific date

WITH
-- Fixed simulation date
simulation_date AS (
    SELECT '2025-12-03'::DATE AS target_date
),

range_window AS (
  SELECT INTERVAL '20 days' AS win
),

-- Market Cap Data Source
-- Uses stock_fundamentals table (create using structures/stock_fundamentals.sql)
market_cap_data AS (
    SELECT
        sf.security_code,
        sf.shares_outstanding,
        sf.shares_outstanding * latest_price.close_price AS market_cap_idr
    FROM
        public.stock_fundamentals sf
        CROSS JOIN LATERAL (
            SELECT close_price
            FROM public.stock_summary
            WHERE stock_summary.security_code = sf.security_code
              AND data_date::DATE = (SELECT target_date FROM simulation_date)
            ORDER BY ts DESC
            LIMIT 1
        ) latest_price
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
        previous_price
    FROM
        public.stock_summary
    WHERE
        lowest_price IS NOT NULL
        AND trade_volume IS NOT NULL
        AND close_price IS NOT NULL
        AND data_date::DATE >= (SELECT target_date FROM simulation_date) - (SELECT win FROM range_window)
        AND data_date::DATE <= (SELECT target_date FROM simulation_date)  -- Only data up to simulation date
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

-- Calculate average volume over available trading days
avg_volume_20d AS (
    SELECT
        ds.security_code,
        AVG(ds.trade_volume) AS avg_volume_20d,
        COUNT(DISTINCT ds.data_date) AS days_count
    FROM
        daily_snapshots ds
    WHERE
        ds.data_date::DATE < (SELECT target_date FROM simulation_date)  -- Exclude target date
    GROUP BY
        ds.security_code
    HAVING
        COUNT(DISTINCT ds.data_date) >= 0  -- At least 7 trading days of data
),

-- Get latest intraday snapshot for each stock on target date
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
        data_date::DATE = (SELECT target_date FROM simulation_date)
    ORDER BY
        security_code,
        ts DESC
),

-- Get latest orderbook snapshot for buy/sell volume analysis
orderbook_snapshot AS (
  SELECT
	  security_code,
	  side,
	  SUM(volume) AS side_volume,
	  MAX(CASE WHEN level = 1 THEN price END) AS best_price
  FROM
	  public.orderbook
  WHERE
	  ts::DATE = (SELECT target_date FROM simulation_date)
	  AND ts = (
		  SELECT MAX(ts) FROM public.orderbook
		  WHERE ts::DATE = (SELECT target_date FROM simulation_date)
	  )
  GROUP BY
	  security_code,
	  side
),

-- Calculate buy/sell volume ratios
buy_sell_analysis AS (
    SELECT
        COALESCE(b.security_code, s.security_code) AS security_code,
        COALESCE(b.side_volume, 0) AS buy_volume,
        COALESCE(s.side_volume, 0) AS sell_volume,
        b.best_price AS best_bid,
        s.best_price AS best_ask,
        ROUND((COALESCE(b.side_volume, 0)::numeric / NULLIF(COALESCE(s.side_volume, 1), 0))::numeric, 4) AS buy_sell_ratio
    FROM
        (SELECT security_code, side_volume, best_price FROM orderbook_snapshot WHERE side = 'B') b
        FULL OUTER JOIN
        (SELECT security_code, side_volume, best_price FROM orderbook_snapshot WHERE side = 'O') s
        ON b.security_code = s.security_code
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

        -- Buy/Sell volume data
        COALESCE(bsa.buy_volume, 0) AS buy_volume,
        COALESCE(bsa.sell_volume, 0) AS sell_volume,
        bsa.best_bid,
        bsa.best_ask,
        bsa.buy_sell_ratio,

        -- Market cap data
        mc.market_cap_idr,

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

        -- Original Criterion 3b: Volume below average (< 1.0× average) - indicates low volume today
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

        -- NEW Criterion 6: Dominant buy pressure (BuyVol > SellVol)
        CASE
            WHEN bsa.buy_volume > bsa.sell_volume THEN true
            ELSE false
        END AS dominant_buy_pressure,

        -- NEW Criterion 7: Buy/Sell ratio >= 1.5
        CASE
            WHEN bsa.buy_sell_ratio >= 1.5 THEN true
            ELSE false
        END AS strong_buy_ratio,

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

        -- NEW Criterion 10: Bid > Ask at best price (strong demand)
        CASE
            WHEN bsa.best_bid IS NOT NULL AND bsa.best_ask IS NOT NULL AND bsa.best_bid > bsa.best_ask THEN true
            ELSE false
        END AS bid_above_ask,

        -- NEW Criterion 11: Market Cap > 25 Trillion IDR
        CASE
            WHEN mc.market_cap_idr IS NOT NULL AND mc.market_cap_idr > 25000000000000 THEN true
            ELSE false
        END AS market_cap_above_25t

    FROM
        latest_snapshot ls
        LEFT JOIN previous_day_data pd ON ls.security_code = pd.security_code
        LEFT JOIN avg_volume_20d av ON ls.security_code = av.security_code
        LEFT JOIN buy_sell_analysis bsa ON ls.security_code = bsa.security_code
        LEFT JOIN market_cap_data mc ON ls.security_code = mc.security_code
)

-- Show detailed breakdown for all candidates on target date
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

    -- Market cap
    ROUND(market_cap_idr::numeric / 1000000000000, 2) AS market_cap_trillion_idr,

    -- Transaction metrics
    trade_volume AS today_volume,
    trade_value AS today_value,
    ROUND(avg_volume_20d::numeric, 0) AS avg_volume_20d,
    avg_days_count,

    -- Buy/Sell pressure
    buy_volume,
    sell_volume,
    buy_sell_ratio,
    best_bid,
    best_ask,

    -- Calculated ratios
    price_to_open_ratio,
    lower_shadow_ratio,
    volume_to_avg_ratio,
    low_to_prev_low_ratio,
    price_change_pct,

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

    -- NEW Criteria flags
    CASE WHEN dominant_buy_pressure THEN '✓' ELSE '✗' END AS "6_BuyPressure",
    CASE WHEN strong_buy_ratio THEN '✓' ELSE '✗' END AS "7_BuySell>=1.5",
    CASE WHEN volume_not_overheated THEN '✓' ELSE '✗' END AS "8_NotOverheated",
    CASE WHEN price_strengthening THEN '✓' ELSE '✗' END AS "9_Price>3%",
    CASE WHEN bid_above_ask THEN '✓' ELSE '✗' END AS "10_BidAboveAsk",
    CASE WHEN market_cap_above_25t THEN '✓' ELSE '✗' END AS "11_MCap>25T",

    -- Extended signal strength (11 criteria)
    (
        CASE WHEN is_down_from_open THEN 1 ELSE 0 END +
        CASE WHEN has_long_lower_shadow THEN 1 ELSE 0 END +
        CASE WHEN has_volume_surge THEN 1 ELSE 0 END +
        CASE WHEN is_liquid THEN 1 ELSE 0 END +
        CASE WHEN is_near_support THEN 1 ELSE 0 END +
        CASE WHEN dominant_buy_pressure THEN 1 ELSE 0 END +
        CASE WHEN strong_buy_ratio THEN 1 ELSE 0 END +
        CASE WHEN volume_not_overheated THEN 1 ELSE 0 END +
        CASE WHEN price_strengthening THEN 1 ELSE 0 END +
        CASE WHEN bid_above_ask THEN 1 ELSE 0 END +
        CASE WHEN market_cap_above_25t THEN 1 ELSE 0 END
    ) AS total_criteria_met

FROM
    candle_analysis

WHERE
    -- Show stocks with at least long lower shadow, liquidity, AND market cap > 25T
    has_long_lower_shadow = true
    AND is_liquid = true
    AND market_cap_above_25t = true

ORDER BY
    (
        CASE WHEN is_down_from_open THEN 1 ELSE 0 END +
        CASE WHEN has_long_lower_shadow THEN 1 ELSE 0 END +
        CASE WHEN has_volume_surge THEN 1 ELSE 0 END +
        CASE WHEN is_liquid THEN 1 ELSE 0 END +
        CASE WHEN is_near_support THEN 1 ELSE 0 END +
        CASE WHEN dominant_buy_pressure THEN 1 ELSE 0 END +
        CASE WHEN strong_buy_ratio THEN 1 ELSE 0 END +
        CASE WHEN volume_not_overheated THEN 1 ELSE 0 END +
        CASE WHEN price_strengthening THEN 1 ELSE 0 END +
        CASE WHEN bid_above_ask THEN 1 ELSE 0 END +
        CASE WHEN market_cap_above_25t THEN 1 ELSE 0 END
    ) DESC,
    trade_value DESC;
