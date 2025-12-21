with last_day as (
select
	MAX(bucket)::date as d
from
	daily_ohlc
),
roll as (
select
	d.security_code as symbol,
	d.bucket::date as trade_date,
	MAX(d.close) over w as max_close,
	MIN(d.close) over w as min_close,
	d.volume,
	d.value,
	AVG(d.volume) over w as avg_volume_prev,
	AVG(d.value) over w as avg_value_prev
from
	daily_ohlc d
join last_day ld on
	d.bucket::date <= ld.d
  window w as (
    partition by d.security_code
order by
	d.bucket
    range between interval '60 days' preceding and interval '1 day' preceding
  )
),
final as (
select
	symbol,
	trade_date,
	case
		when min_close > 0 then (max_close - min_close) / min_close
		else 0
	end as range_ratio,
	case
		when avg_volume_prev > 0 then volume / avg_volume_prev
		else 0
	end as volume_ratio,
	avg_value_prev
from
	roll
)
insert
	into
	sideways_state(symbol, trade_date, range_ratio, volume_ratio, is_sideways)
select
	f.symbol,
	f.trade_date,
	f.range_ratio,
	f.volume_ratio,
	coalesce(
    (f.range_ratio < 0.05 and f.volume_ratio < 0.20 and f.avg_value_prev > 1000000000),
    false
  ) as is_sideways
from
	final f
join (
	select
		d
	from
		last_day) x on
	f.trade_date = x.d
on
	conflict (symbol,
	trade_date) do
update
set
	range_ratio = EXCLUDED.range_ratio,
	volume_ratio = EXCLUDED.volume_ratio,
	is_sideways = EXCLUDED.is_sideways;
