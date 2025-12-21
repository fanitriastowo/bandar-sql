WITH daily AS (
    SELECT
        security_code,
        date(ts) AS trade_date,
        first(opening_price, ts) AS open,
        max(highest_price) AS high,
        min(lowest_price) AS low,
        last(close_price, ts) AS close,
        sum(trade_volume) AS volume,
        sum(trade_value) AS value
    FROM stock_summary
    GROUP BY security_code, date(ts)
),

last_day AS (
    SELECT MAX(trade_date) AS d
    FROM daily
),

roll AS (
    SELECT
        d.security_code AS symbol,
        d.trade_date,
        d.close,
        d.volume,
        d.value,

        -- RANGE 5 DAYS BEFORE TODAY
        MAX(d.close) OVER (
            PARTITION BY d.security_code ORDER BY d.trade_date
            RANGE BETWEEN INTERVAL '7 days' PRECEDING AND INTERVAL '1 day' PRECEDING
        ) AS max_close_prev,

        MIN(d.close) OVER (
            PARTITION BY d.security_code ORDER BY d.trade_date
            RANGE BETWEEN INTERVAL '7 days' PRECEDING AND INTERVAL '1 day' PRECEDING
        ) AS min_close_prev,

        AVG(d.volume) OVER (
            PARTITION BY d.security_code ORDER BY d.trade_date
            RANGE BETWEEN INTERVAL '7 days' PRECEDING AND INTERVAL '1 day' PRECEDING
        ) AS avg_volume_prev,

        AVG(d.value) OVER (
            PARTITION BY d.security_code ORDER BY d.trade_date
            RANGE BETWEEN INTERVAL '7 days' PRECEDING AND INTERVAL '1 day' PRECEDING
        ) AS avg_value_prev
    FROM daily d
    JOIN last_day ld ON d.trade_date <= ld.d
),

final AS (
    SELECT
        symbol,
        trade_date,
        (max_close_prev - min_close_prev) / NULLIF(min_close_prev, 0) AS range_ratio,
        volume / NULLIF(avg_volume_prev, 0) AS volume_ratio,
        avg_value_prev
    FROM roll
)

SELECT *
FROM final
WHERE trade_date = (SELECT d FROM last_day)

-- SIDEWAYS CONDITIONS
  AND range_ratio < 0.05             -- harga dalam range sempit
  AND volume_ratio < 0.20            -- volume turun
  AND avg_value_prev > 5000000000    -- > 1B liquidity
ORDER BY range_ratio ASC;