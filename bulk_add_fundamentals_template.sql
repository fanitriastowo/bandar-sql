-- Template for bulk-adding fundamentals data
-- Step 1: Run find_missing_fundamentals.sql to see which stocks need data
-- Step 2: Look up shares_outstanding for those stocks from IDX/company reports
-- Step 3: Fill in the VALUES below and run this script

-- Common large-cap Indonesian stocks (market cap > 25T IDR)
-- Update the shares_outstanding values with actual data from reliable sources

INSERT INTO public.stock_fundamentals (security_code, shares_outstanding, last_updated, source)
VALUES
    -- Banking (Big 4)
    ('BBRI', 124186187163, '2024-12-31', 'Annual Report 2024'),  -- Bank Rakyat Indonesia
    ('BBCA', 24217088667, '2024-12-31', 'Annual Report 2024'),   -- Bank Central Asia
    ('BMRI', 86034524425, '2024-12-31', 'Annual Report 2024'),   -- Bank Mandiri
    ('BBNI', 17392920370, '2024-12-31', 'Annual Report 2024'),   -- Bank Negara Indonesia

    -- Conglomerate/Automotive
    ('ASII', 40484000000, '2024-12-31', 'Annual Report 2024'),   -- Astra International
    ('UNTR', 3730313322, '2024-12-31', 'Annual Report 2024'),    -- United Tractors

    -- Telecommunication
    ('TLKM', 99766326000, '2024-12-31', 'Annual Report 2024'),   -- Telkom Indonesia
    ('EXCL', 26446363703, '2024-12-31', 'Annual Report 2024'),   -- XL Axiata

    -- Consumer Goods
    ('UNVR', 7630000000, '2024-12-31', 'Annual Report 2024'),    -- Unilever Indonesia
    ('ICBP', 3681231699, '2024-12-31', 'Annual Report 2024'),    -- Indofood CBP
    ('INDF', 8780426500, '2024-12-31', 'Annual Report 2024'),    -- Indofood Sukses Makmur

    -- Energy/Mining
    ('PTBA', 3230000000, '2024-12-31', 'Annual Report 2024'),    -- Bukit Asam
    ('ADRO', 31985962000, '2024-12-31', 'Annual Report 2024'),   -- Adaro Energy
    ('MEDC', 6617297013, '2024-12-31', 'Annual Report 2024'),    -- Medco Energi

    -- Technology
    ('GOTO', 75000000000, '2024-12-31', 'IPO Prospectus'),       -- GoTo Gojek Tokopedia

    -- Construction/Cement
    ('SMGR', 5931520000, '2024-12-31', 'Annual Report 2024'),    -- Semen Indonesia
    ('WIKA', 3355317800, '2024-12-31', 'Annual Report 2024'),    -- Wijaya Karya

    -- Retail
    ('MAPI', 1797341497, '2024-12-31', 'Annual Report 2024'),    -- MAP Aktif

    -- Plantation
    ('AALI', 551123000, '2024-12-31', 'Annual Report 2024'),     -- Astra Agro Lestari

    -- ADD MORE STOCKS HERE AS NEEDED
    -- Get shares_outstanding from:
    -- 1. https://www.idnfinancials.com/company/{CODE}
    -- 2. Company annual reports (Laporan Tahunan)
    -- 3. IDX website: https://www.idx.co.id/

    -- Template for adding new stocks:
    -- ('CODE', shares_outstanding_number, 'YYYY-MM-DD', 'Source Name'),

    ('AMMN', 7584000000, '2024-12-31', 'Annual Report 2024')     -- Amman Mineral (last entry, no comma)

ON CONFLICT (security_code) DO UPDATE SET
    shares_outstanding = EXCLUDED.shares_outstanding,
    last_updated = EXCLUDED.last_updated,
    source = EXCLUDED.source;

-- Verify the insertions
SELECT
    security_code,
    shares_outstanding,
    last_updated,
    source
FROM
    public.stock_fundamentals
ORDER BY
    security_code;
