-- PostgreSQL 17 Configuration for Momentum Rebound Query
-- Optimized for 4GB RAM, 4 CPU system
-- Apply this before running the optimized query

-- ====================================================================
-- MEMORY CONFIGURATION (Optimized for 4GB RAM)
-- ====================================================================

-- Main memory buffers (50% of RAM - conservative for 4GB system)
SET shared_buffers = 262144;          -- 2GB in 8KB blocks

-- Effective cache size (75% of total RAM)
SET effective_cache_size = 1966080;    -- 3GB in 8KB blocks

-- Work memory per operation (conservative for 4GB system)
SET work_mem = 16384;                   -- 128MB per operation

-- Maintenance work memory (25% of RAM)
SET maintenance_work_mem = 131072;       -- 1GB in 8KB blocks

-- ====================================================================
-- PARALLEL PROCESSING CONFIGURATION (Optimized for 4 CPUs)
-- ====================================================================

-- Maximum parallel workers per query (use 3 of 4 cores, leave 1 for system)
SET max_parallel_workers_per_gather = 3;

-- Total parallel workers available (1.5x physical cores)
SET max_parallel_workers = 6;

-- Cost adjustments to favor parallelism
SET parallel_tuple_cost = 0.1;
SET parallel_setup_cost = 1000.0;

-- ====================================================================
-- QUERY OPTIMIZER SETTINGS (PostgreSQL 17 Compatible)
-- ====================================================================

-- Enable hash-based operations for better parallel processing
SET enable_hashagg = on;
SET enable_hashjoin = on;
SET enable_mergejoin = on;

-- Cost-based optimization (assuming SSD storage)
SET random_page_cost = 1.1;
SET seq_page_cost = 1.0;
SET cpu_tuple_cost = 0.01;
SET cpu_index_tuple_cost = 0.005;

-- ====================================================================
-- LOCK AND TIMEOUT SETTINGS
-- ====================================================================

-- Prevent indefinite waiting
SET statement_timeout = '10min';
SET lock_timeout = '30s';
SET idle_in_transaction_session_timeout = '5min';

-- ====================================================================
-- STATISTICS AND PLANNING
-- ====================================================================

-- Force plan recalculation for this session
SET plan_cache_mode = 'force_generic_plan';

-- Show execution times for monitoring
SET log_min_duration_statement = 1000;   -- Log queries > 1 second
SET log_statement = 'none';               -- Don't log individual statements

-- ====================================================================
-- CONFIGURATION VALIDATION
-- ====================================================================

-- Display applied settings for verification
SELECT 
    'shared_buffers' as setting_name,
    (current_setting('shared_buffers')::int * 8192) / 1024 / 1024 as value_mb,
    '2GB (50% of 4GB RAM)' as description

UNION ALL

SELECT 
    'effective_cache_size' as setting_name,
    (current_setting('effective_cache_size')::int * 8192) / 1024 / 1024 as value_mb,
    '3GB (75% of 4GB RAM)' as description

UNION ALL

SELECT 
    'work_mem' as setting_name,
    current_setting('work_mem')::int / 1024 as value_mb,
    '128MB (per operation)' as description

UNION ALL

SELECT 
    'maintenance_work_mem' as setting_name,
    current_setting('maintenance_work_mem')::int / 1024 / 1024 as value_mb,
    '1GB (maintenance operations)' as description

UNION ALL

SELECT 
    'max_parallel_workers_per_gather' as setting_name,
    current_setting('max_parallel_workers_per_gather')::int as value_mb,
    '3 of 4 cores (1 reserved for system)' as description

ORDER BY setting_name;

-- Configuration application confirmation
RAISE NOTICE 'PostgreSQL 17 configuration applied for 4GB RAM, 4 CPU system';
RAISE NOTICE 'Memory optimized: shared_buffers=2GB, work_mem=128MB';
RAISE NOTICE 'Parallel processing enabled: max_parallel_workers_per_gather=3';
RAISE NOTICE 'Ready for optimized momentum rebound query execution';