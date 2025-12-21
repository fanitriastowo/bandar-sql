WITH 
-- ================================================
-- CTE 1: Data Quality & Coverage Validation
-- ================================================
data_validation AS (
    SELECT 
        ho.code AS security_code,
        COUNT(DISTINCT ho.trade_date) AS trading_days_count,
        MIN(ho.trade_date) AS earliest_date,
        MAX(ho.trade_date) AS latest_date,
        sf.shares_outstanding IS NOT NULL AS has_shares_outstanding,
        sf.free_float_shares IS NOT NULL AS has_free_float,
        CASE 
            WHEN COUNT(DISTINCT ho.trade_date) >= 200 THEN 'Sufficient'
            WHEN COUNT(DISTINCT ho.trade_date) >= 100 THEN 'Limited'  
            ELSE 'Insufficient'
        END AS data_quality_status
    FROM history_ohlc ho
    LEFT JOIN stock_fundamentals sf ON ho.code = sf.security_code
    WHERE ho.trade_date >= CURRENT_DATE - INTERVAL '250 days'
    GROUP BY ho.code, sf.shares_outstanding, sf.free_float_shares
),

-- ================================================
-- CTE 2: Fundamental Metrics (Market Cap & Free Float)
-- ================================================
fundamental_metrics AS (
    SELECT 
        dv.security_code,
        hs.trade_date,
        hs.close AS current_price,
        hs.high AS day_high,
        hs.low AS day_low,
        hs.volume AS day_volume,
        hs.value AS day_value,
        
        -- Fundamental data
        sf.shares_outstanding,
        sf.free_float_shares,
        sf.free_float_percentage,
        
        -- Market calculations
        sf.shares_outstanding * hs.close AS market_cap_idr,
        sf.free_float_shares * hs.close AS free_float_market_cap_idr,
        
        -- Free float criteria
        CASE 
            WHEN sf.free_float_percentage < 40 THEN 1 ELSE 0 
        END AS free_float_criteria_met,
        
        -- Market cap criteria  
        CASE 
            WHEN sf.shares_outstanding * hs.close < 5000000000000 THEN 1 ELSE 0 
        END AS market_cap_criteria_met
        
    FROM data_validation dv
    JOIN history_ohlc hs ON dv.security_code = hs.code
    JOIN stock_fundamentals sf ON dv.security_code = sf.security_code
    WHERE dv.data_quality_status = 'Sufficient'
      AND hs.trade_date = (SELECT MAX(trade_date) FROM history_ohlc WHERE code = dv.security_code)
),

-- ================================================
-- CTE 3: Technical Indicators (Moving Averages)
-- ================================================
technical_indicators AS (
    SELECT 
        fm.security_code,
        fm.trade_date,
        fm.current_price,
        
        -- Moving averages using window functions
        AVG(fm.current_price) OVER (
            PARTITION BY fm.security_code 
            ORDER BY fm.trade_date 
            ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
        ) AS ma50,
        
        AVG(fm.current_price) OVER (
            PARTITION BY fm.security_code 
            ORDER BY fm.trade_date 
            ROWS BETWEEN 99 PRECEDING AND CURRENT ROW
        ) AS ma100,
        
        AVG(fm.current_price) OVER (
            PARTITION BY fm.security_code 
            ORDER BY fm.trade_date 
            ROWS BETWEEN 199 PRECEDING AND CURRENT ROW
        ) AS ma200,
        
        -- Volume moving averages
        AVG(fm.day_volume) OVER (
            PARTITION BY fm.security_code 
            ORDER BY fm.trade_date 
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS avg_volume_20,
        
        AVG(fm.day_volume) OVER (
            PARTITION BY fm.security_code 
            ORDER BY fm.trade_date 
            ROWS BETWEEN 59 PRECEDING AND CURRENT ROW
        ) AS avg_volume_60,
        
        -- Price ranges for 60-day period
        MAX(fm.current_price) OVER (
            PARTITION BY fm.security_code 
            ORDER BY fm.trade_date 
            ROWS BETWEEN 59 PRECEDING AND CURRENT ROW
        ) AS highest_60,
        
        MIN(fm.current_price) OVER (
            PARTITION BY fm.security_code 
            ORDER BY fm.trade_date 
            ROWS BETWEEN 59 PRECEDING AND CURRENT ROW
        ) AS lowest_60,
        
        -- Price ranges for 20-day period
        MAX(fm.current_price) OVER (
            PARTITION BY fm.security_code 
            ORDER BY fm.trade_date 
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS highest_20,
        
        -- Daily range calculation
        (fm.day_high - fm.day_low) / NULLIF(fm.current_price, 0) AS daily_range_percentage
        
    FROM fundamental_metrics fm
),

-- ================================================
-- CTE 4: RSI Implementation (14-period Wilder's Smoothing)
-- ================================================
rsi_calculation AS (
    -- Calculate price changes
    price_changes AS (
        SELECT 
            ti.security_code,
            ti.trade_date,
            ti.current_price,
            ti.current_price - LAG(ti.current_price) OVER (
                PARTITION BY ti.security_code 
                ORDER BY ti.trade_date
            ) AS price_change
        FROM technical_indicators ti
    ),
    
    -- Separate gains and losses
    gains_losses AS (
        SELECT 
            pc.security_code,
            pc.trade_date,
            pc.current_price,
            CASE WHEN pc.price_change > 0 THEN pc.price_change ELSE 0 END AS gain,
            CASE WHEN pc.price_change < 0 THEN ABS(pc.price_change) ELSE 0 END AS loss
        FROM price_changes pc
    ),
    
    -- Calculate 14-period averages using Wilder's smoothing
    rsi_averages AS (
        SELECT 
            gl.security_code,
            gl.trade_date,
            gl.current_price,
            AVG(gl.gain) OVER (
                PARTITION BY gl.security_code 
                ORDER BY gl.trade_date 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ) AS avg_gain,
            AVG(gl.loss) OVER (
                PARTITION BY gl.security_code 
                ORDER BY gl.trade_date 
                ROWS BETWEEN 13 PRECEDING AND CURRENT ROW
            ) AS avg_loss
        FROM gains_losses gl
    )
    
    SELECT 
        ra.security_code,
        ra.trade_date,
        ra.current_price,
        CASE 
            WHEN ra.avg_loss = 0 THEN 100
            ELSE 100 - (100 / (1 + (ra.avg_gain / NULLIF(ra.avg_loss, 0))))
        END AS rsi_14
    FROM rsi_averages ra
),

-- ================================================
-- CTE 5: Final Screening Logic (All Criteria Combined)
-- ================================================
swing_screening AS (
    SELECT 
        ti.security_code,
        ti.trade_date,
        ti.current_price,
        ti.ma50,
        ti.ma100,
        ti.ma200,
        ti.avg_volume_20,
        ti.avg_volume_60,
        ti.day_volume,
        ti.day_value,
        ti.highest_60,
        ti.lowest_60,
        ti.highest_20,
        ti.daily_range_percentage,
        rc.rsi_14,
        
        -- Fundamental criteria
        fm.market_cap_idr,
        fm.free_float_percentage,
        fm.free_float_criteria_met,
        fm.market_cap_criteria_met,
        
        -- Price trend criteria
        CASE 
            WHEN ti.current_price > ti.ma50 
             AND ti.ma50 > ti.ma100 
             AND ti.ma100 > ti.ma200 
            THEN 1 ELSE 0 
        END AS ma_trend_ok,
        
        -- Volume criteria
        CASE 
            WHEN ti.day_volume > ti.avg_volume_20 
             AND ti.avg_volume_20 > ti.avg_volume_60 
            THEN 1 ELSE 0 
        END AS volume_criteria_ok,
        
        -- Price range criteria
        CASE 
            WHEN ti.highest_60 / NULLIF(ti.lowest_60, 0) < 1.8 
             AND ti.current_price >= ti.highest_20 
            THEN 1 ELSE 0 
        END AS price_range_ok,
        
        -- Value criteria
        CASE 
            WHEN ti.day_value > 5000000000 
            THEN 1 ELSE 0 
        END AS value_criteria_ok,
        
        -- RSI criteria
        CASE 
            WHEN rc.rsi_14 > 55 AND rc.rsi_14 < 70 
            THEN 1 ELSE 0 
        END AS rsi_criteria_ok,
        
        -- MA200 ratio criteria
        CASE 
            WHEN ti.current_price / NULLIF(ti.ma200, 0) < 2 
            THEN 1 ELSE 0 
        END AS ma200_ratio_ok,
        
        -- Daily range criteria
        CASE 
            WHEN ti.daily_range_percentage < 0.12 
            THEN 1 ELSE 0 
        END AS daily_range_ok
        
    FROM technical_indicators ti
    JOIN fundamental_metrics fm ON ti.security_code = fm.security_code AND ti.trade_date = fm.trade_date  
    JOIN rsi_calculation rc ON ti.security_code = rc.security_code AND ti.trade_date = rc.trade_date
)

-- ================================================
-- FINAL SELECTION: Apply All Swing Trading Criteria
-- ================================================
SELECT 
    security_code,
    trade_date,
    current_price,
    ma50,
    ma100,
    ma200,
    rsi_14,
    market_cap_idr,
    free_float_percentage,
    day_volume,
    day_value,
    daily_range_percentage,
    
    -- Criteria scores for analysis
    free_float_criteria_met,
    market_cap_criteria_met,
    ma_trend_ok,
    volume_criteria_ok,
    price_range_ok,
    value_criteria_ok,
    rsi_criteria_ok,
    ma200_ratio_ok,
    daily_range_ok,
    
    -- Total score
    (free_float_criteria_met + market_cap_criteria_met + ma_trend_ok + 
     volume_criteria_ok + price_range_ok + value_criteria_ok + rsi_criteria_ok + 
     ma200_ratio_ok + daily_range_ok) AS total_criteria_met
     
FROM swing_screening
WHERE free_float_criteria_met = 1
  AND market_cap_criteria_met = 1
  AND ma_trend_ok = 1
  AND volume_criteria_ok = 1
  AND price_range_ok = 1
  AND value_criteria_ok = 1
  AND rsi_criteria_ok = 1
  AND ma200_ratio_ok = 1
  AND daily_range_ok = 1

ORDER BY trade_date DESC, total_criteria_met DESC, market_cap_idr DESC;