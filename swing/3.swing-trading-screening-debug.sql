-- Debug version of swing trading query - test individual CTEs
-- Run this to validate each component before running full query

-- Test CTE 1: Data Quality Validation
WITH 
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
)
SELECT 
    security_code,
    trading_days_count,
    data_quality_status,
    has_shares_outstanding,
    has_free_float
FROM data_validation
WHERE has_shares_outstanding = TRUE 
   AND has_free_float = TRUE
ORDER BY trading_days_count DESC
LIMIT 10;

-- Test CTE 2: Fundamental Metrics
WITH 
data_validation AS (
    SELECT 
        ho.code AS security_code,
        COUNT(DISTINCT ho.trade_date) AS trading_days_count,
        sf.shares_outstanding IS NOT NULL AS has_shares_outstanding,
        sf.free_float_shares IS NOT NULL AS has_free_float,
        CASE 
            WHEN COUNT(DISTINCT ho.trade_date) >= 200 THEN 'Sufficient'
            ELSE 'Insufficient'
        END AS data_quality_status
    FROM history_ohlc ho
    LEFT JOIN stock_fundamentals sf ON ho.code = sf.security_code
    WHERE ho.trade_date >= CURRENT_DATE - INTERVAL '250 days'
    GROUP BY ho.code, sf.shares_outstanding, sf.free_float_shares
),
fundamental_metrics AS (
    SELECT 
        dv.security_code,
        hs.trade_date,
        hs.close AS current_price,
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
)
SELECT 
    security_code,
    current_price,
    market_cap_idr,
    free_float_percentage,
    free_float_criteria_met,
    market_cap_criteria_met,
    CASE 
        WHEN free_float_criteria_met = 1 AND market_cap_criteria_met = 1 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS fundamental_screening
FROM fundamental_metrics
ORDER BY market_cap_idr DESC
LIMIT 15;

-- Test CTE 3: Technical Indicators (MA50/MA100/MA200)
WITH 
data_validation AS (
    SELECT 
        ho.code AS security_code,
        COUNT(DISTINCT ho.trade_date) AS trading_days_count,
        sf.shares_outstanding IS NOT NULL AS has_shares_outstanding,
        sf.free_float_shares IS NOT NULL AS has_free_float,
        CASE 
            WHEN COUNT(DISTINCT ho.trade_date) >= 200 THEN 'Sufficient'
            ELSE 'Insufficient'
        END AS data_quality_status
    FROM history_ohlc ho
    LEFT JOIN stock_fundamentals sf ON ho.code = sf.security_code
    WHERE ho.trade_date >= CURRENT_DATE - INTERVAL '250 days'
    GROUP BY ho.code, sf.shares_outstanding, sf.free_float_shares
),
fundamental_metrics AS (
    SELECT 
        dv.security_code,
        hs.trade_date,
        hs.close AS current_price,
        hs.high AS day_high,
        hs.low AS day_low,
        hs.volume AS day_volume,
        hs.value AS day_value,
        sf.shares_outstanding,
        sf.free_float_shares,
        sf.free_float_percentage,
        sf.shares_outstanding * hs.close AS market_cap_idr,
        CASE 
            WHEN sf.free_float_percentage < 40 THEN 1 ELSE 0 
        END AS free_float_criteria_met,
        CASE 
            WHEN sf.shares_outstanding * hs.close < 5000000000000 THEN 1 ELSE 0 
        END AS market_cap_criteria_met
    FROM data_validation dv
    JOIN history_ohlc hs ON dv.security_code = hs.code
    JOIN stock_fundamentals sf ON dv.security_code = sf.security_code
    WHERE dv.data_quality_status = 'Sufficient'
      AND hs.trade_date = (SELECT MAX(trade_date) FROM history_ohlc WHERE code = dv.security_code)
),
technical_indicators AS (
    SELECT 
        fm.security_code,
        fm.trade_date,
        fm.current_price,
        fm.day_high,
        fm.day_low,
        fm.day_volume,
        
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
)
SELECT 
    security_code,
    trade_date,
    current_price,
    ma50,
    ma100,
    ma200,
    avg_volume_20,
    avg_volume_60,
    highest_60,
    lowest_60,
    highest_20,
    daily_range_percentage,
    
    -- MA trend check
    CASE 
        WHEN current_price > ma50 
         AND ma50 > ma100 
         AND ma100 > ma200 
        THEN 'MA_TREND_OK'
        ELSE 'MA_TREND_FAIL'
    END AS ma_trend_status,
    
    -- Volume check
    CASE 
        WHEN day_volume > avg_volume_20 
         AND avg_volume_20 > avg_volume_60 
        THEN 'VOLUME_OK'
        ELSE 'VOLUME_FAIL'
    END AS volume_status,
        
    -- Price range check
    CASE 
        WHEN highest_60 / NULLIF(lowest_60, 0) < 1.8 
         AND current_price >= highest_20 
        THEN 'PRICE_RANGE_OK'
        ELSE 'PRICE_RANGE_FAIL'
    END AS price_range_status
        
FROM technical_indicators
ORDER BY security_code, trade_date DESC
LIMIT 20;