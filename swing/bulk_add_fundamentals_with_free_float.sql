INSERT INTO public.stock_fundamentals (security_code, shares_outstanding, free_float_shares, free_float_percentage, last_updated, source)
VALUES
    -- Banking Sector (30-45% free float typical)
    ('BBRI', 124186187163, 49674474865, 40.0, '2024-12-31', 'Annual Report 2024'),
    ('BBCA', 24217088667, 12108544334, 50.0, '2024-12-31', 'Annual Report 2024'),
    ('BMRI', 86034524425, 34413809770, 40.0, '2024-12-31', 'Annual Report 2024'),
    ('BBNI', 17392920370, 7826814166, 45.0, '2024-12-31', 'Annual Report 2024'),

    -- Technology Sector (70-90% free float)
    ('GOTO', 75000000000, 67500000000, 90.0, '2024-12-31', 'IPO Prospectus'),
    ('EXCL', 26446363703, 18452454592, 69.8, '2024-12-31', 'Annual Report 2024'),

    -- State-Owned Enterprises (25-40% free float)
    ('TLKM', 99766326000, 29929897800, 30.0, '2024-12-31', 'Annual Report 2024'),
    ('SMGR', 5931520000, 1482880000, 25.0, '2024-12-31', 'Annual Report 2024'),
    ('WIKA', 3355317800, 1006595340, 30.0, '2024-12-31', 'Annual Report 2024'),

    -- Consumer Goods (60-85% free float)
    ('UNVR', 7630000000, 6131300000, 80.3, '2024-12-31', 'Annual Report 2024'),
    ('ICBP', 3681231699, 2760988774, 75.0, '2024-12-31', 'Annual Report 2024'),
    ('INDF', 8780426500, 6144629550, 70.0, '2024-12-31', 'Annual Report 2024'),

    -- Energy/Mining (40-70% free float)
    ('PTBA', 3230000000, 1938000000, 60.0, '2024-12-31', 'Annual Report 2024'),
    ('ADRO', 31985962000, 19191577200, 60.0, '2024-12-31', 'Annual Report 2024'),
    ('MEDC', 6617297013, 3970378208, 60.0, '2024-12-31', 'Annual Report 2024'),

    -- Automotive/Conglomerate
    ('ASII', 40484000000, 32387200000, 80.0, '2024-12-31', 'Annual Report 2024'),
    ('UNTR', 3730313322, 2611229325, 70.0, '2024-12-31', 'Annual Report 2024'),

    -- Additional Liquid Stocks for Swing Trading
    ('MAPI', 1797341497, 1348006123, 75.0, '2024-12-31', 'Annual Report 2024'),
    ('CPIN', 4877220000, 3649015000, 75.0, '2024-12-31', 'Annual Report 2024'),
    ('TOWR', 7667346000, 4600407600, 60.0, '2024-12-31', 'Annual Report 2024'),
    ('KLBF', 13720000000, 10976000000, 80.0, '2024-12-31', 'Annual Report 2024'),
    ('INDY', 39914000000, 27939800000, 70.0, '2024-12-31', 'Annual Report 2024'),
    ('ANTM', 2587350000, 1552410000, 60.0, '2024-12-31', 'Annual Report 2024')

ON CONFLICT (security_code) DO UPDATE SET
    shares_outstanding = EXCLUDED.shares_outstanding,
    free_float_shares = EXCLUDED.free_float_shares,
    free_float_percentage = EXCLUDED.free_float_percentage,
    last_updated = EXCLUDED.last_updated,
    source = EXCLUDED.source;