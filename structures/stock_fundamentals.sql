-- Stock Fundamentals Table
-- Contains shares outstanding for market cap calculations
-- Update this data quarterly or when corporate actions occur (stock splits, rights issues, etc.)

-- Create the table
CREATE TABLE IF NOT EXISTS public.stock_fundamentals (
    security_code TEXT PRIMARY KEY,
    shares_outstanding BIGINT NOT NULL,
    last_updated DATE NOT NULL,
    source TEXT  -- Optional: track where data came from
);

-- Insert sample data for major Indonesian stocks
-- IMPORTANT: Update these values with actual data from reliable sources
INSERT INTO public.stock_fundamentals (security_code, shares_outstanding, last_updated, source) VALUES
    -- Banking Sector
    ('BBRI', 124186187163, '2024-12-31', 'Annual Report 2024'),
    ('BBCA', 24217088667, '2024-12-31', 'Annual Report 2024'),
    ('BMRI', 86034524425, '2024-12-31', 'Annual Report 2024'),
    ('BBNI', 17392920370, '2024-12-31', 'Annual Report 2024'),

    -- Conglomerate/Automotive
    ('ASII', 40484000000, '2024-12-31', 'Annual Report 2024'),
    ('UNTR', 3730313322, '2024-12-31', 'Annual Report 2024'),

    -- Telecommunication
    ('TLKM', 99766326000, '2024-12-31', 'Annual Report 2024'),
    ('EXCL', 26446363703, '2024-12-31', 'Annual Report 2024'),

    -- Consumer Goods
    ('UNVR', 7630000000, '2024-12-31', 'Annual Report 2024'),
    ('ICBP', 3681231699, '2024-12-31', 'Annual Report 2024'),

    -- Energy/Mining
    ('PTBA', 3230000000, '2024-12-31', 'Annual Report 2024'),
    ('ADRO', 31985962000, '2024-12-31', 'Annual Report 2024'),

    -- Technology
    ('GOTO', 75000000000, '2024-12-31', 'IPO Prospectus'),

    -- Add more stocks as needed
    ('AMMN', 7584000000, '2024-12-31', 'Annual Report 2024')

ON CONFLICT (security_code) DO UPDATE SET
    shares_outstanding = EXCLUDED.shares_outstanding,
    last_updated = EXCLUDED.last_updated,
    source = EXCLUDED.source;

-- View to check market cap for all stocks with current prices
CREATE OR REPLACE VIEW v_current_market_cap AS
SELECT
    sf.security_code,
    sf.shares_outstanding,
    ss.close_price AS current_price,
    (sf.shares_outstanding * ss.close_price) AS market_cap_idr,
    ROUND((sf.shares_outstanding * ss.close_price)::numeric / 1000000000000, 2) AS market_cap_trillion_idr,
    ss.data_date,
    ss.ts AS price_timestamp,
    sf.last_updated AS fundamentals_updated
FROM
    public.stock_fundamentals sf
    INNER JOIN LATERAL (
        SELECT DISTINCT ON (security_code)
            security_code,
            close_price,
            data_date,
            ts
        FROM public.stock_summary
        WHERE security_code = sf.security_code
        ORDER BY security_code, ts DESC
    ) ss ON sf.security_code = ss.security_code
ORDER BY
    market_cap_idr DESC;
