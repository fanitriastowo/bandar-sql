-- Validation script for free float implementation
-- Run this after setting up the database connection

-- 1. Check if stock_fundamentals table exists and has new columns
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'stock_fundamentals' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check current free float data
SELECT 
    security_code,
    shares_outstanding,
    free_float_shares,
    free_float_percentage,
    last_updated,
    source
FROM stock_fundamentals
WHERE free_float_percentage IS NOT NULL
ORDER BY security_code;

-- 3. Validate free float calculations
SELECT 
    security_code,
    shares_outstanding,
    free_float_shares,
    free_float_percentage,
    CASE 
        WHEN free_float_shares IS NOT NULL AND shares_outstanding IS NOT NULL
        THEN ROUND((free_float_shares::NUMERIC / shares_outstanding::NUMERIC) * 100, 2)
        ELSE NULL
    END AS calculated_free_float_pct,
    free_float_percentage AS stored_free_float_pct,
    CASE 
        WHEN free_float_shares IS NOT NULL AND shares_outstanding IS NOT NULL
        AND ABS(ROUND((free_float_shares::NUMERIC / shares_outstanding::NUMERIC) * 100, 2) - free_float_percentage) > 0.1
        THEN 'MISMATCH'
        ELSE 'OK'
    END AS validation_status
FROM stock_fundamentals
WHERE free_float_shares IS NOT NULL
  AND shares_outstanding IS NOT NULL
ORDER BY security_code;

-- 4. Check for stocks missing free float data but have shares_outstanding
SELECT 
    COUNT(*) AS total_stocks_with_shares,
    COUNT(CASE WHEN free_float_percentage IS NULL THEN 1 END) AS missing_free_float,
    COUNT(CASE WHEN free_float_percentage IS NOT NULL THEN 1 END) AS has_free_float
FROM stock_fundamentals
WHERE shares_outstanding IS NOT NULL;

-- 5. Test sample swing trading calculation for one stock
WITH sample_calculation AS (
    SELECT 
        ho.code AS security_code,
        ho.trade_date,
        ho.close AS current_price,
        sf.shares_outstanding,
        sf.free_float_percentage,
        sf.shares_outstanding * ho.close AS market_cap_idr,
        
        -- Sample MA calculation (20-day)
        AVG(ho.close) OVER (
            PARTITION BY ho.code 
            ORDER BY ho.trade_date 
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS ma20_sample,
        
        -- Volume data check
        AVG(ho.volume) OVER (
            PARTITION BY ho.code 
            ORDER BY ho.trade_date 
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) AS avg_volume_20_sample
        
    FROM history_ohlc ho
    JOIN stock_fundamentals sf ON ho.code = sf.security_code
    WHERE ho.code = 'BBCA'  -- Test with BBCA
      AND ho.trade_date >= CURRENT_DATE - INTERVAL '30 days'
    ORDER BY ho.trade_date DESC
    LIMIT 5
)
SELECT * FROM sample_calculation;