CREATE TABLE IF NOT EXISTS public.stock_fundamentals (
    security_code VARCHAR(10) PRIMARY KEY,
    shares_outstanding BIGINT NOT NULL,
    free_float_shares BIGINT,              -- NEW: Free floating shares
    free_float_percentage DECIMAL(5,2),    -- NEW: Free float % (0.00-100.00)
    last_updated DATE NOT NULL DEFAULT CURRENT_DATE,
    source TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_free_float_percentage 
        CHECK (free_float_percentage IS NULL OR (free_float_percentage >= 0 AND free_float_percentage <= 100)),
    CONSTRAINT valid_shares_outstanding 
        CHECK (shares_outstanding > 0),
    CONSTRAINT valid_free_float_shares 
        CHECK (free_float_shares IS NULL OR free_float_shares >= 0)
);

-- Trigger to update timestamp
CREATE OR REPLACE FUNCTION update_fundamentals_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_fundamentals_timestamp
    BEFORE UPDATE ON public.stock_fundamentals
    FOR EACH ROW EXECUTE FUNCTION update_fundamentals_timestamp();

-- Index for performance
CREATE INDEX idx_stock_fundamentals_security_code ON public.stock_fundamentals(security_code);